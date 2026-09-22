---- MODULE Bounds ----
\* NEW MODULE at 0.8.2 — V7 §5.9 Bounds Propagation and §4.10(b) capability-chain depth.
\* Transcribed from spec-data/v0.8.2/ENTITY-CORE-PROTOCOL.md §5.9 and §4.10.
\*
\* WHY THIS MODULE EXISTS. 0.8.1/0.8.2 turned three previously-implicit bound behaviours into
\* normative rules, all of them about how TWO SEPARATE BRAKES relate to each other. Verbatim:
\*
\*   (1) §5.9 — "`ttl` and the continuation `chain_depth` ceiling... MUST be distinct
\*       magnitudes with `chain_depth` ceiling <= `ttl` seed, chosen so the deterministic
\*       depth brake engages before the TTL backstop under the peer's worst-case sub-dispatch
\*       fan-out... The conformance requirement is the PROPERTY, not the number: the depth
\*       brake, not TTL, is what terminates a runaway chain, and equal magnitudes (both were
\*       64) violate it by letting TTL mask the deterministic brake — the '9-vs-64' cross-peer
\*       bound divergence this pins out (0.8.1)."
\*
\*   (2) §5.9 Ruling 1 — "TTL is the resource backstop, decremented ONCE PER DISPATCH
\*       (including internal sub-dispatches), NEVER DOUBLE-COUNTED — a single dispatch MUST
\*       NOT be decremented at ingress *and* again on forward. It is fan-out-sensitive... and
\*       ORTHOGONAL to `chain_depth`: one dispatch advances `chain_depth` by at most one
\*       causal level but may spend several TTL across its sub-dispatches."
\*
\*   (3) §4.10(b) Ruling 3 — "this `chain_depth_exceeded` (400) is the CAPABILITY-chain depth
\*       limit and is distinct from the CONTINUATION causal-depth brake, which suspends with
\*       `bounds_exceeded` (429...). Two mechanisms, two reason codes — they MUST NOT share a
\*       reason string."
\*
\* All three are properties of a runaway chain's TERMINATION — which brake fires, how much it
\* charged, and what it says — so the model is a single chain advancing until something stops
\* it, with each brake independently switchable to its defect.
\*
\* MODEL SHAPE (D11 — what is and is not here). This is an ARITHMETIC/ORDERING model of one
\* causal chain, not a concurrency or attacker model: no interleaving, no peers, no crypto.
\* ABSTRACTED AWAY: what a dispatch actually does, the identity of the handlers, and the
\* content of the capability chain — §4.10(b)'s cost argument is O(depth) signature
\* verifications and the depth is all that matters here. The numbers are SCALED DOWN from the
\* spec's informative defaults (ceiling 64 / seed 512) to keep TLC exhaustive; §4.10 says
\* explicitly "the contract is 'enforce a finite *declared* bound'... never 'pick this
\* number'", so the ratio, not the magnitude, is the modeled content. See BoundsRatioBug.cfg
\* for what the model says about the recommended 8x ratio at worst-case fan-out.
EXTENDS Naturals

CONSTANTS
  TtlSeed,          \* §5.9 the TTL seed applied once at chain origin, then decremented
  DepthCeiling,     \* §5.9 the continuation causal-depth ceiling (the DETERMINISTIC brake)
  MaxFanout,        \* the peer's worst-case sub-dispatch fan-out: TTL spent per causal level
  MaxCapDepth,      \* §4.10(b) the peer's configured max presented CAPABILITY-chain depth
  DoubleCount,      \* FALSE = §5.9 Ruling 1: TTL decremented once per dispatch. CORRECT.
                    \* TRUE  = neg control: decremented at ingress AND again on forward.
  ShareReasonCode   \* FALSE = §4.10(b) Ruling 3: the two brakes use distinct reason strings.
                    \* TRUE  = neg control: the continuation brake also reports
                    \*         "chain_depth_exceeded", conflating it with the §4.10(b) limit.

\* Bound the explored magnitudes so TLC stays exhaustive.
MaxSpend == TtlSeed + (2 * MaxFanout) + 2

VARIABLES
  depth,       \* §5.9 continuation causal depth — inherited + incremented per causal advancement
  ttl,         \* §5.9 the resource backstop, decremented per dispatch, never refilled
  capDepth,    \* §4.10(b) depth of the capability chain presented on the current dispatch
  spent,       \* total TTL charged so far (for the double-count check)
  dispatches,  \* total dispatches performed so far (ditto)
  halt,        \* "running" | "depth" (continuation brake) | "ttl" | "capdepth"
  code         \* the reason string emitted at halt

vars == << depth, ttl, capDepth, spent, dispatches, halt, code >>

\* §5.9 / §4.10(b) reason strings. The continuation causal-depth brake SUSPENDS with
\* `bounds_exceeded` (429); the capability-chain depth limit REJECTS with
\* `chain_depth_exceeded` (400). The negative control makes the first borrow the second's
\* string — the exact conflation Ruling 3 forbids.
DepthBrakeCode == IF ShareReasonCode THEN "chain_depth_exceeded" ELSE "bounds_exceeded"
CapDepthCode   == "chain_depth_exceeded"

Init ==
  /\ depth      = 0
  /\ ttl        = TtlSeed        \* §5.9: "the only seed is the initial default, applied once
  /\ capDepth   = 0              \*        at chain origin, then decremented. Not refilled."
  /\ spent      = 0
  /\ dispatches = 0
  /\ halt       = "running"
  /\ code       = "none"

\* §4.10(b): the presented capability chain grows and is rejected once it exceeds the peer's
\* configured maximum — "reject a presented chain exceeding its configured maximum depth with
\* 400 chain_depth_exceeded rather than walking an attacker-controlled chain unboundedly".
\* This brake is INDEPENDENT of the causal-depth brake: a chain can be deep in capability
\* links while shallow in causal advancement, and vice versa.
PresentDeeperChain ==
  /\ halt = "running"
  /\ capDepth < MaxCapDepth + 1
  /\ capDepth' = capDepth + 1
  /\ IF capDepth + 1 > MaxCapDepth
       THEN /\ halt' = "capdepth"
            /\ code' = CapDepthCode
       ELSE /\ halt' = "running"
            /\ code' = "none"
  /\ UNCHANGED << depth, ttl, spent, dispatches >>

\* §5.9 causal advancement. One causal level: chain_depth advances by exactly one, and the
\* level's sub-dispatch fan-out spends that many TTL. The DETERMINISTIC brake is checked on
\* advancement — "Exceeding the peer's uniform ceiling suspends with reason: bounds_exceeded
\* (429) — not chain_depth_exceeded (§4.10(b), the capability-chain limit)."
Advance ==
  /\ halt = "running"
  /\ IF depth + 1 > DepthCeiling
       THEN \* the deterministic depth brake engages — this is what SHOULD stop a runaway chain
            /\ halt' = "depth"
            /\ code' = DepthBrakeCode
            /\ UNCHANGED << depth, ttl, spent, dispatches >>
       ELSE \E f \in 1..MaxFanout :          \* this level's sub-dispatch fan-out
              LET charge == IF DoubleCount THEN 2 * f ELSE f   \* Ruling 1: once per dispatch
              IN /\ spent' = spent + charge
                 /\ dispatches' = dispatches + f
                 /\ IF ttl - charge <= 0
                      THEN \* the TTL backstop fired first — the chain terminated on the
                           \* resource brake rather than the deterministic one
                           /\ halt' = "ttl"
                           /\ code' = "ttl_exhausted"
                           /\ ttl' = 0
                           /\ UNCHANGED depth
                      ELSE /\ ttl' = ttl - charge
                           /\ depth' = depth + 1
                           /\ halt' = "running"
                           /\ code' = "none"
  /\ UNCHANGED capDepth

Next ==
  \/ Advance
  \/ PresentDeeperChain
  \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

\* SAFETY — §5.9: "the depth brake, not TTL, is what terminates a runaway chain". A chain that
\* runs away must be stopped by the DETERMINISTIC causal-depth ceiling, never by the TTL
\* backstop; equal magnitudes "violate it by letting TTL mask the deterministic brake".
\* Holds exactly when DepthCeiling * MaxFanout < TtlSeed — see BoundsEqualBug / BoundsRatioBug.
DepthBrakeFirst == halt # "ttl"

\* SAFETY — §5.9 Ruling 1: TTL is "decremented once per dispatch... never double-counted".
\* The total charged equals the number of dispatches performed, no more.
TtlNotDoubleCounted == spent = dispatches

\* SAFETY — §5.9 / §4.10(b) Ruling 3: "Two mechanisms, two reason codes — they MUST NOT share
\* a reason string." The continuation causal-depth brake suspends with bounds_exceeded (429);
\* the capability-chain depth limit rejects with chain_depth_exceeded (400).
ReasonCodesDistinct ==
  /\ (halt = "depth")    => code = "bounds_exceeded"
  /\ (halt = "capdepth") => code = "chain_depth_exceeded"

\* SAFETY — §5.9: chain_depth and TTL are ORTHOGONAL magnitudes. "one dispatch advances
\* chain_depth by at most one causal level but may spend several TTL across its
\* sub-dispatches" — so causal depth never exceeds the TTL actually charged, and (the
\* fan-out-sensitivity claim) may be strictly less than it.
DepthBoundedBySpend == depth <= spent

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / BoundsWitness.cfg). Asserted as an invariant that
\* MUST FAIL: a violation exhibits a reachable state in which the deterministic depth brake
\* actually fired, proving DepthBrakeFirst is not vacuously true of a chain that never runs
\* far enough to brake at all. Expected verdict: VIOLATION.
WitnessDepthBrakeFires == halt # "depth"
====
