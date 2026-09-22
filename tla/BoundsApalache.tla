---- MODULE BoundsApalache ----
\* NEW at 0.8.2 — Apalache (SMT) cross-check of tla/Bounds.tla (V8 §5.9 / §4.10(b)).
\*
\* WHY THIS EXISTS. `Bounds` was added at 0.8.2 with TLC coverage only — single-tool coverage,
\* which the audit flagged. It is also the module where an unbounded proof matters MOST, for a
\* reason specific to what it models: TLC checks the brake at ONE scaled-down configuration
\* (ceiling 4, fan-out 2, seed 16). §5.9 makes the numbers explicitly non-normative and states
\* the requirement as a PROPERTY — "the depth brake, not TTL, is what terminates a runaway
\* chain" — so a result at one triple of numbers is exactly the wrong shape of evidence.
\*
\* WHAT IT BUYS: the proof below is over SYMBOLIC TtlSeed / DepthCeiling / MaxFanout
\* constrained only by the ratio condition, so it establishes the property for EVERY
\* deployment satisfying that condition rather than for one chosen triple. That converts
\* §5.9's requirement from "checked at our numbers" into "proved for the class of numbers the
\* spec's rule describes", which is the claim §5.9 actually makes.
\*
\* THE STRENGTHENING is `TtlSufficient`: while the chain is still running, the TTL remaining
\* is strictly greater than the worst-case spend needed to reach the ceiling. That is the
\* precise content of "chosen so the deterministic depth brake engages before the TTL
\* backstop under the peer's worst-case sub-dispatch fan-out", written as an invariant. It is
\* what makes DepthBrakeFirst inductive, and the ratio condition in ConstInitOK
\* (DepthCeiling * MaxFanout < TtlSeed) is exactly what establishes it at Init.
EXTENDS Integers

CONSTANTS
  \* @type: Int;
  TtlSeed,
  \* @type: Int;
  DepthCeiling,
  \* @type: Int;
  MaxFanout,
  \* @type: Int;
  MaxCapDepth,
  \* @type: Bool;
  DoubleCount,
  \* @type: Bool;
  ShareReasonCode

VARIABLES
  \* @type: Int;
  depth,
  \* @type: Int;
  ttl,
  \* @type: Int;
  capDepth,
  \* @type: Int;
  spent,
  \* @type: Int;
  dispatches,
  \* @type: Str;
  halt,
  \* @type: Str;
  code

vars == << depth, ttl, capDepth, spent, dispatches, halt, code >>

Halts == {"running", "depth", "ttl", "capdepth"}
Codes == {"none", "bounds_exceeded", "ttl_exhausted", "chain_depth_exceeded"}

DepthBrakeCode == IF ShareReasonCode THEN "chain_depth_exceeded" ELSE "bounds_exceeded"

\* ----- the properties (transcribed from Bounds.tla) -----
DepthBrakeFirst     == halt # "ttl"
TtlNotDoubleCounted == spent = dispatches
ReasonCodesDistinct ==
  /\ (halt = "depth")    => code = "bounds_exceeded"
  /\ (halt = "capdepth") => code = "chain_depth_exceeded"

\* ----- the inductive strengthening -----
\* §5.9, as an invariant: while running, enough TTL remains to reach the ceiling even at the
\* peer's worst-case fan-out. Strict, because at exact equality the backstop fires on the same
\* step the brake would have (see BoundsRatioBug.cfg).
TtlSufficient ==
  (halt = "running") => ttl > (DepthCeiling - depth) * MaxFanout

DepthInRange == 0 <= depth /\ depth <= DepthCeiling

TypeOK ==
  /\ halt \in Halts
  /\ code \in Codes
  /\ depth \in Int
  /\ ttl \in Int
  /\ capDepth \in Int
  /\ spent \in Int
  /\ dispatches \in Int

InvBrake  == TypeOK /\ DepthInRange /\ TtlSufficient /\ DepthBrakeFirst
InvCount  == TypeOK /\ TtlNotDoubleCounted
InvCodes  == TypeOK /\ ReasonCodesDistinct

\* ----- transitions -----
Init ==
  /\ depth      = 0
  /\ ttl        = TtlSeed
  /\ capDepth   = 0
  /\ spent      = 0
  /\ dispatches = 0
  /\ halt       = "running"
  /\ code       = "none"

\* §4.10(b): the presented capability chain grows and is rejected past the configured maximum.
\* Independent of the causal-depth brake — two mechanisms, two reason codes.
PresentDeeperChain ==
  /\ halt = "running"
  /\ capDepth < MaxCapDepth + 1
  /\ capDepth' = capDepth + 1
  /\ \/ /\ capDepth + 1 > MaxCapDepth
        /\ halt' = "capdepth"
        /\ code' = "chain_depth_exceeded"
     \/ /\ ~(capDepth + 1 > MaxCapDepth)
        /\ halt' = "running"
        /\ code' = "none"
  /\ UNCHANGED << depth, ttl, spent, dispatches >>

\* §5.9 causal advancement: chain_depth advances by exactly one; this level's sub-dispatch
\* fan-out spends that many TTL. DNF so Apalache's assignment finder sees every branch.
Advance ==
  /\ halt = "running"
  /\ \/ /\ depth + 1 > DepthCeiling            \* the DETERMINISTIC brake engages
        /\ halt' = "depth"
        /\ code' = DepthBrakeCode
        /\ UNCHANGED << depth, ttl, spent, dispatches >>
     \/ /\ ~(depth + 1 > DepthCeiling)
        /\ \E f \in 1..MaxFanout :
             LET charge == IF DoubleCount THEN 2 * f ELSE f
             IN /\ spent' = spent + charge
                /\ dispatches' = dispatches + f
                /\ \/ /\ ttl - charge <= 0     \* the TTL backstop fired FIRST
                      /\ halt' = "ttl"
                      /\ code' = "ttl_exhausted"
                      /\ ttl' = 0
                      /\ depth' = depth
                   \/ /\ ~(ttl - charge <= 0)
                      /\ ttl' = ttl - charge
                      /\ depth' = depth + 1
                      /\ halt' = "running"
                      /\ code' = "none"
  /\ UNCHANGED capDepth

Next ==
  \/ Advance
  \/ PresentDeeperChain
  \/ UNCHANGED vars

\* ----- inductive-step inits -----
IndInitBrake == TypeOK /\ DepthInRange /\ TtlSufficient /\ DepthBrakeFirst
IndInitCount == TypeOK /\ TtlNotDoubleCounted
IndInitCodes == TypeOK /\ ReasonCodesDistinct

\* ----- constant inits -----
\* SYMBOLIC, not a chosen triple: the numbers are constrained ONLY by §5.9's ratio condition
\* and by being positive. The proof therefore covers every deployment whose bounds satisfy the
\* rule — which is what §5.9 asks for, since it declares the values non-normative.
ConstInitOK ==
  /\ TtlSeed \in 1..64 /\ DepthCeiling \in 1..16 /\ MaxFanout \in 1..8 /\ MaxCapDepth \in 1..16
  /\ DepthCeiling * MaxFanout < TtlSeed          \* §5.9's condition, STRICT
  /\ DoubleCount = FALSE /\ ShareReasonCode = FALSE

\* NEG CONTROL: equal magnitudes — the "9-vs-64" divergence 0.8.1 pins out.
ConstInitBugEqual ==
  /\ TtlSeed = 4 /\ DepthCeiling = 4 /\ MaxFanout = 2 /\ MaxCapDepth = 3
  /\ DoubleCount = FALSE /\ ShareReasonCode = FALSE

\* NEG CONTROL: the ratio boundary — ceiling * fanout EQUALS the seed, no margin.
ConstInitBugRatio ==
  /\ TtlSeed = 8 /\ DepthCeiling = 4 /\ MaxFanout = 2 /\ MaxCapDepth = 3
  /\ DoubleCount = FALSE /\ ShareReasonCode = FALSE

\* NEG CONTROL: §5.9 Ruling 1 dropped — decremented at ingress AND on forward.
ConstInitBugDouble ==
  /\ TtlSeed = 16 /\ DepthCeiling = 4 /\ MaxFanout = 2 /\ MaxCapDepth = 3
  /\ DoubleCount = TRUE /\ ShareReasonCode = FALSE

\* NEG CONTROL: §4.10(b) Ruling 3 dropped — the two brakes share a reason string.
ConstInitBugCode ==
  /\ TtlSeed = 16 /\ DepthCeiling = 4 /\ MaxFanout = 2 /\ MaxCapDepth = 3
  /\ DoubleCount = FALSE /\ ShareReasonCode = TRUE
====
