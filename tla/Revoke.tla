---- MODULE Revoke ----
\* Phase 1 — increment 5: Revocation + verdict determinism (V7 §5.1, §5.10), per
\* PHASE1-SCOPE.md subsystem F. Two conformant peers evaluate the same capability chain. The
\* module checks (1) the §5.1 revocation contract — once a revocation marker is observed the
\* cap never passes again — and (2) the §5.10 cross-peer determinism MUST — the Layer-1 verdict
\* is a function of (chain, evaluation timestamp `t`, observed revocations) ONLY, identical
\* across peers given the same Layer-1 state and the same `t`; no Layer-2 local policy may
\* modulate it.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the chain's STRUCTURAL validity (§5.5 linkage,
\* §5.6 attenuation, §5.7 caveats, signatures) is Lean's — abstracted here as the opaque
\* predicate `ChainValid`. What is modeled is the TEMPORAL/OBSERVATION layer §5.10 puts around
\* that verdict: `t` as a declared per-verdict input, revocation as a convergent (async-observed)
\* Layer-1 input, and the Layer-1/Layer-2 separation. Both peers are pinned to the
\* `supports_revocation = true` (full) tier; the core tier (treats observed set as empty, §5.1)
\* is noted, not modeled (PHASE1-SCOPE section 7). Every element cites its V7 §ref.
EXTENDS Naturals

CONSTANTS HonorRevocation,   \* TRUE = §5.1: an observed revocation makes the cap fail every
                             \*        check; FALSE = negative control: revocation ignored.
          LeakLayer1,        \* FALSE = §5.10: Layer-1 verdict ignores local policy; TRUE =
                             \*         negative control: a local banlist (Layer 2) modulates
                             \*         the Layer-1 verdict -> cross-peer determinism breaks.
          NoConverge,        \* FALSE = §5.10: a written marker is eventually observed by all peers;
                             \*         TRUE = LIVENESS negative control: a peer never observes the
                             \*         marker (non-convergent) -> RevocationConverges fails.
          PropBound,         \* §5.10 (0.8.1, W7 Knob 2) B — the declared
                             \* `revocation_propagation_bound`, in ticks.
          MaxTick,           \* clock horizon (keeps TLC exhaustive)
          BoundedPropagation \* TRUE  = §5.10: the peer HAS, DECLARES and HONORS a finite
                             \*         revocation_propagation_bound — its sync/subscription
                             \*         cadence observes a marker within B of the marker
                             \*         becoming observable at its authoritative source.
                             \* FALSE = negative control: no declared/honored bound. §5.10:
                             \*         "The window... is otherwise UNBOUNDED". Such a peer is
                             \*         `supports_revocation`-tier-floor only and "MUST NOT
                             \*         advertise reason-about-able revocation" — so asserting
                             \*         the exposure-window property against it FAILS, which is
                             \*         exactly the point of the declaration requirement.

Peers == {"A", "B"}

(*--algorithm revoke
variables
  markerWritten = FALSE,                  \* §5.1: a revocation marker has been written (put(path,null))
  revObserved = [p \in Peers |-> FALSE],  \* §5.10: has peer p OBSERVED the marker? (async-convergent)
  t           = [p \in Peers |-> 1],      \* §5.10: each peer's once-per-verdict evaluation timestamp
  banned      = [p \in Peers |-> FALSE],  \* §5.10 Layer-2: a purely-local banlist bit (policy state)
  \* --- §5.10 revocation-propagation bound (0.8.1, W7 Knob 2), NEW at 0.8.2 ---
  \* NOTE these are a DIFFERENT time axis from `t` above, and the spec treats them as
  \* different things: `t` is the per-verdict evaluation timestamp (a Layer-1 INPUT, sampled
  \* once per verdict), while `clock` measures PROPAGATION LATENCY — how long a marker takes
  \* to reach a peer. Conflating them is the mistake the two names exist to prevent.
  clock       = 0,                        \* discrete propagation clock
  markerAt    = 0,                        \* tick at which the marker became observable at source
  obsAt       = [p \in Peers |-> 0];      \* tick at which peer p observed it

define
  \* §5.5/§5.6 structural verdict — Lean's, abstracted as an opaque always-valid chain here
  \* (the structural-invalid case is Lean's domain; this module models the layer around it).
  ChainValid == TRUE

  \* §5.10: TTL evaluated against the per-verdict timestamp `t` (a Layer-1 input). Boundary at 1:
  \* valid at t=1, expired at t=2. Two peers at different `t` near the boundary may differ — legitimate.
  TTLok(p) == t[p] = 1

  \* §5.10 Layer-1 verdict: a function of (chain, `t`, observed revocations) only. The HonorRevocation
  \* and LeakLayer1 switches drive the two negative controls; in the correct model the verdict is
  \* ChainValid /\ TTLok /\ ~observed-revocation, with the local banlist (Layer 2) having NO effect.
  Verdict1(p) == /\ ChainValid
                 /\ TTLok(p)
                 /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
                 /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)

  \* §5.1/§6.8: once a peer has observed the revocation, the cap fails every subsequent check.
  RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)

  \* §5.10: the cross-peer determinism MUST — same `t` and same observed-revocation state (same
  \* tier, pinned full here) => identical verdict. Async divergence on DIFFERENT observed state or
  \* DIFFERENT `t` is permitted (antecedent false), so it is guarded out.
  VerdictFnOfLayer1 ==
    (t["A"] = t["B"] /\ revObserved["A"] = revObserved["B"]) => (Verdict1("A") = Verdict1("B"))

  \* §5.10 (0.8.1, W7 Knob 2) — THE BOUND IS HONORED. Once the marker is observable at its
  \* authoritative source, every peer that declares a finite bound B has observed it by B
  \* ticks later. This is the "and honor" half of "have, declare, and honor a finite bound".
  BoundHonored ==
    (markerWritten /\ clock > markerAt + PropBound) => (\A p \in Peers : revObserved[p])

  \* §5.10 — THE EXPOSURE WINDOW IS REASON-ABOUT-ABLE. "Given a declared bound B, the
  \* revocation exposure window for a cap verified at this peer is min(TTL_granularity, B) —
  \* a reason-about-able quantity." A revoked cap can still pass at a peer only inside that
  \* window: the B term is the clock bound below; the TTL_granularity term is TTLok, which
  \* Verdict1 already carries. Without a declared bound the window is unbounded and this
  \* fails — which is why §5.10 makes declaring one the floor.
  ExposureBounded ==
    \A p \in Peers : (markerWritten /\ Verdict1(p)) => (clock <= markerAt + PropBound)
end define;

\* Each peer samples its per-verdict `t` and its (irrelevant-to-Layer-1) local policy state, then
\* asynchronously observes the revocation marker once it is written (the §5.10 convergent input).
fair process peerproc \in Peers
begin
  PSample:
    with tv \in {1, 2}, bv \in {TRUE, FALSE} do
      t[self] := tv || banned[self] := bv;
    end with;
  PSync:
    either
      await markerWritten;            \* §5.10: observation is async — converges once the marker exists
      revObserved[self] := TRUE ||    \* monotonic: once observed, stays observed (markers are content-addressed)
      obsAt[self] := clock;           \* §5.10: record WHEN, for the propagation-bound check
    or
      await NoConverge;               \* LIVENESS NEG CONTROL: peer finishes blind, never observing the marker
      skip;
    end either;
end process;

\* The revoker writes the revocation marker (§5.1 put(path,null)); both peers converge on it.
\* markerAt records the tick at which it becomes observable AT ITS AUTHORITATIVE SOURCE —
\* the start of the §5.10 propagation window.
fair process revoker = "rev"
begin
  RWrite:
    markerWritten := TRUE || markerAt := clock;
end process;

\* §5.10 propagation clock (0.8.1, W7 Knob 2), NEW at 0.8.2.
\*
\* MODELING NOTE (D11 — declare the device): a DEADLINE in an untimed TLA+ model is expressed
\* by refusing to advance the clock past it. The guard below says: while a peer that declares
\* and honors a finite bound B still has not observed a marker that became observable B ticks
\* ago, time cannot pass — i.e. the peer's sync/subscription cadence is what makes the bound
\* real. This models a peer that HONORS its declared bound; it does not prove any particular
\* cadence achieves it, which is a deployment property outside the protocol.
\* With BoundedPropagation = FALSE the guard is absent and the clock runs freely, which is
\* precisely §5.10's "otherwise unbounded" window.
fair process ticker = "clk"
begin
  Tick:
    while clock < MaxTick do
      await ~(BoundedPropagation /\ markerWritten
              /\ clock >= markerAt + PropBound
              /\ \E p \in Peers : ~revObserved[p]);
      clock := clock + 1;
    end while;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "3b28d39d" /\ chksum(tla) = "ee47eb5")
VARIABLES pc, markerWritten, revObserved, t, banned, clock, markerAt, obsAt

(* define statement *)
ChainValid == TRUE



TTLok(p) == t[p] = 1




Verdict1(p) == /\ ChainValid
               /\ TTLok(p)
               /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
               /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)


RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)




VerdictFnOfLayer1 ==
  (t["A"] = t["B"] /\ revObserved["A"] = revObserved["B"]) => (Verdict1("A") = Verdict1("B"))




BoundHonored ==
  (markerWritten /\ clock > markerAt + PropBound) => (\A p \in Peers : revObserved[p])







ExposureBounded ==
  \A p \in Peers : (markerWritten /\ Verdict1(p)) => (clock <= markerAt + PropBound)


vars == << pc, markerWritten, revObserved, t, banned, clock, markerAt, obsAt
        >>

ProcSet == (Peers) \cup {"rev"} \cup {"clk"}

Init == (* Global variables *)
        /\ markerWritten = FALSE
        /\ revObserved = [p \in Peers |-> FALSE]
        /\ t = [p \in Peers |-> 1]
        /\ banned = [p \in Peers |-> FALSE]
        /\ clock = 0
        /\ markerAt = 0
        /\ obsAt = [p \in Peers |-> 0]
        /\ pc = [self \in ProcSet |-> CASE self \in Peers -> "PSample"
                                        [] self = "rev" -> "RWrite"
                                        [] self = "clk" -> "Tick"]

PSample(self) == /\ pc[self] = "PSample"
                 /\ \E tv \in {1, 2}:
                      \E bv \in {TRUE, FALSE}:
                        /\ banned' = [banned EXCEPT ![self] = bv]
                        /\ t' = [t EXCEPT ![self] = tv]
                 /\ pc' = [pc EXCEPT ![self] = "PSync"]
                 /\ UNCHANGED << markerWritten, revObserved, clock, markerAt, 
                                 obsAt >>

PSync(self) == /\ pc[self] = "PSync"
               /\ \/ /\ markerWritten
                     /\ /\ obsAt' = [obsAt EXCEPT ![self] = clock]
                        /\ revObserved' = [revObserved EXCEPT ![self] = TRUE]
                  \/ /\ NoConverge
                     /\ TRUE
                     /\ UNCHANGED <<revObserved, obsAt>>
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << markerWritten, t, banned, clock, markerAt >>

peerproc(self) == PSample(self) \/ PSync(self)

RWrite == /\ pc["rev"] = "RWrite"
          /\ /\ markerAt' = clock
             /\ markerWritten' = TRUE
          /\ pc' = [pc EXCEPT !["rev"] = "Done"]
          /\ UNCHANGED << revObserved, t, banned, clock, obsAt >>

revoker == RWrite

Tick == /\ pc["clk"] = "Tick"
        /\ IF clock < MaxTick
              THEN /\ ~(BoundedPropagation /\ markerWritten
                        /\ clock >= markerAt + PropBound
                        /\ \E p \in Peers : ~revObserved[p])
                   /\ clock' = clock + 1
                   /\ pc' = [pc EXCEPT !["clk"] = "Tick"]
              ELSE /\ pc' = [pc EXCEPT !["clk"] = "Done"]
                   /\ clock' = clock
        /\ UNCHANGED << markerWritten, revObserved, t, banned, markerAt, obsAt >>

ticker == Tick

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == revoker \/ ticker
           \/ (\E self \in Peers: peerproc(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Peers : WF_vars(peerproc(self))
        /\ WF_vars(revoker)
        /\ WF_vars(ticker)

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (checked as PROPERTY; needs the WF supplied by `fair process`) =====

\* §5.10: revocation is a CONVERGENT input — a written marker is eventually observed by every
\* verifier in the same tier. Once the marker exists, both peers converge on observing it.
RevocationConverges == markerWritten ~> (\A p \in Peers : revObserved[p])

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / RevokeWitness.cfg). Asserted as an invariant that
\* MUST FAIL: a violation exhibits a reachable state in which a marker was actually written and
\* observed by every peer, proving the revocation properties above are not vacuously true of a
\* model in which nothing is ever revoked. Expected verdict: VIOLATION.
WitnessRevocationObserved == ~(markerWritten /\ \A p \in Peers : revObserved[p])
====
