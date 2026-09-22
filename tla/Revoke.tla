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
          DeltaVals,         \* §5.10 (0.8.1, W7 Knob 3) — the set of skew tolerances a peer may
                             \* DECLARE, in the same unit as `t`. Symbolic rather than a fixed
                             \* pair: the clause makes `δ` a deployment declaration with a
                             \* default of 0 and no normative ceiling, so pinning one value
                             \* would prove a property of our chosen number. {0} reproduces
                             \* pre-0.8.3 behaviour exactly (RevokeDeltaZero); {0,1} is the
                             \* smallest set that lets two peers declare DIFFERENT tolerances,
                             \* which is the case the determinism clause is actually about.
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
  \* --- §5.10 cross-clock temporal model (0.8.1, W7 Knob 3), NEW at 0.8.3-dev ---
  \* Each peer's DECLARED skew tolerance. Sampled once per peer, not once per verdict: `t` is
  \* sampled per verdict, `delta` is a deployment declaration that holds across them. The spec
  \* is explicit that this is "a Layer-1 input alongside `t` (it introduces no concealed
  \* state)", which is exactly why it belongs in the determinism antecedent below and not in
  \* the Layer-2 policy state that `banned` models.
  delta       = [p \in Peers |-> 0],
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

  \* §5.10: the cap's own declared window. Fixed in this model (one cap, minted once); `t` and
  \* `delta` are what vary. NotBefore = ExpiresAt = 1 keeps the pre-0.8.3 boundary exactly:
  \* valid at t=1, expired at t=2.
  NotBefore == 1
  ExpiresAt == 1

  \* §5.10 cross-clock temporal model (0.8.1, W7 Knob 3), transcribed from the clause verbatim:
  \*   "applied symmetrically at the boundary: `expires_at + δ < t → DENY`,
  \*    `t + δ < not_before → DENY`. The effective validity window ... is
  \*    `[not_before − δ, expires_at + δ]`."
  \* Written as the negation of the two DENY rules, so the transcription is checkable against
  \* the clause line by line rather than against the window summary.
  \*
  \* NOTE the clause's own conformance check on this transcription: "`δ = 0` reproduces today's
  \* exact behavior." At delta = 0 this reduces to `1 <= t[p] /\ t[p] <= 1`, i.e. `t[p] = 1` —
  \* which is the pre-0.8.3 definition character for character. That equivalence is not left as
  \* a reading: `RevokeDeltaZero.cfg` pins every peer to delta = 0 and re-runs the whole green
  \* invariant set, so a transcription that widened the window would fail there.
  TTLok(p) == /\ NotBefore <= t[p] + delta[p]    \* ~(t + δ < not_before)
              /\ t[p] <= ExpiresAt + delta[p]    \* ~(expires_at + δ < t)

  \* §5.10 Layer-1 verdict: a function of (chain, `t`, observed revocations) only. The HonorRevocation
  \* and LeakLayer1 switches drive the two negative controls; in the correct model the verdict is
  \* ChainValid /\ TTLok /\ ~observed-revocation, with the local banlist (Layer 2) having NO effect.
  Verdict1(p) == /\ ChainValid
                 /\ TTLok(p)
                 /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
                 /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)

  \* §5.1/§6.8: once a peer has observed the revocation, the cap fails every subsequent check.
  RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)

  \* §5.10: the cross-peer determinism MUST — same Layer-1 inputs => identical verdict. Async
  \* divergence on DIFFERENT observed state, DIFFERENT `t` or DIFFERENT declared `delta` is
  \* permitted (antecedent false), so it is guarded out.
  \*
  \* `delta` is in the antecedent because §5.10 (W7 Knob 3) puts it there: "two peers with
  \* different declared `δ` may permissibly differ at the boundary, the same way different `t`
  \* does." Before 0.8.3-dev this conjunct was absent and the model had no `delta` at all —
  \* which made the invariant an accidentally-true statement about a model that could not
  \* express the case it was guarding. `RevokeDeltaBlindBug` is that omission, run as a control.
  VerdictFnOfLayer1 ==
    (t["A"] = t["B"] /\ delta["A"] = delta["B"] /\ revObserved["A"] = revObserved["B"])
      => (Verdict1("A") = Verdict1("B"))

  \* NEGATIVE CONTROL (§5.10 W7 Knob 3) — the defect is a verifier that APPLIES a skew
  \* tolerance without DECLARING it as a Layer-1 input. The clause admits `δ` only on the
  \* condition that "it introduces no concealed state"; a peer whose `δ` is not a declared
  \* input has made its verdict a function of hidden state, which is precisely what §5.10's
  \* determinism MUST forbids. This is that invariant — the pre-0.8.3 antecedent, blind to
  \* `delta` — and it MUST be violated once `delta` can differ.
  \*
  \* D13, asked of this control: what else satisfies it? A violation means two peers agreeing
  \* on `t` and on observed-revocation state still disagreed. With `delta` pinned equal the
  \* full invariant above holds (that is `RevokeDeltaZero` and the green run), so `delta` is
  \* the only remaining degree of freedom — but that is an argument, and the witness below is
  \* the measurement, requiring `delta` to differ IN THE VIOLATING STATE rather than inferring it.
  VerdictFnOfLayer1_DeltaBlind ==
    (t["A"] = t["B"] /\ revObserved["A"] = revObserved["B"]) => (Verdict1("A") = Verdict1("B"))

  \* NON-VACUITY WITNESS — `delta` actually changes a verdict, ALL ELSE EQUAL. Asserted as an
  \* invariant that MUST FAIL: a violation exhibits two peers agreeing on every other Layer-1
  \* input — same `t`, same observed-revocation state — declaring DIFFERENT `delta`, and
  \* reaching DIFFERENT verdicts. Without this, adding `delta` to the model could be inert: a
  \* variable that widens the state space and decides nothing, which is the shape §C.4 of
  \* docs/PROPERTIES.md exists to catch.
  \*
  \* THE `revObserved` CONJUNCT IS THE WHOLE WITNESS, and its first draft did not have it.
  \* Without it TLC satisfies the property immediately with a state where the two peers differ
  \* on OBSERVED REVOCATION and `delta` differs only incidentally — a real divergence that
  \* `delta` had no part in. That draft "passed" as a witness for a claim it does not support,
  \* and it was caught by reading the counterexample trace rather than the exit status: state 5
  \* of the first run had `revObserved = [A |-> TRUE, B |-> FALSE]`.
  \*
  \* This is the D13 question asked of a WITNESS: it fired, but for what reason? A witness that
  \* fires for the wrong reason is exactly as useless as a control that does, and it is harder
  \* to notice because a firing witness looks like success.
  WitnessDeltaDivergence ==
    ~(/\ t["A"] = t["B"]
      /\ revObserved["A"] = revObserved["B"]
      /\ delta["A"] # delta["B"]
      /\ Verdict1("A") # Verdict1("B"))

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
    with tv \in {1, 2}, bv \in {TRUE, FALSE}, dv \in DeltaVals do
      t[self] := tv || banned[self] := bv || delta[self] := dv;
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
\* BEGIN TRANSLATION (chksum(pcal) = "693bcbc" /\ chksum(tla) = "12f23b63")
VARIABLES pc, markerWritten, revObserved, t, banned, delta, clock, markerAt, 
          obsAt

(* define statement *)
ChainValid == TRUE




NotBefore == 1
ExpiresAt == 1













TTLok(p) == /\ NotBefore <= t[p] + delta[p]
            /\ t[p] <= ExpiresAt + delta[p]




Verdict1(p) == /\ ChainValid
               /\ TTLok(p)
               /\ (IF HonorRevocation THEN ~revObserved[p] ELSE TRUE)
               /\ (IF LeakLayer1      THEN ~banned[p]      ELSE TRUE)


RevokedNeverPasses == \A p \in Peers : revObserved[p] => ~Verdict1(p)










VerdictFnOfLayer1 ==
  (t["A"] = t["B"] /\ delta["A"] = delta["B"] /\ revObserved["A"] = revObserved["B"])
    => (Verdict1("A") = Verdict1("B"))













VerdictFnOfLayer1_DeltaBlind ==
  (t["A"] = t["B"] /\ revObserved["A"] = revObserved["B"]) => (Verdict1("A") = Verdict1("B"))


















WitnessDeltaDivergence ==
  ~(/\ t["A"] = t["B"]
    /\ revObserved["A"] = revObserved["B"]
    /\ delta["A"] # delta["B"]
    /\ Verdict1("A") # Verdict1("B"))




BoundHonored ==
  (markerWritten /\ clock > markerAt + PropBound) => (\A p \in Peers : revObserved[p])







ExposureBounded ==
  \A p \in Peers : (markerWritten /\ Verdict1(p)) => (clock <= markerAt + PropBound)


vars == << pc, markerWritten, revObserved, t, banned, delta, clock, markerAt, 
           obsAt >>

ProcSet == (Peers) \cup {"rev"} \cup {"clk"}

Init == (* Global variables *)
        /\ markerWritten = FALSE
        /\ revObserved = [p \in Peers |-> FALSE]
        /\ t = [p \in Peers |-> 1]
        /\ banned = [p \in Peers |-> FALSE]
        /\ delta = [p \in Peers |-> 0]
        /\ clock = 0
        /\ markerAt = 0
        /\ obsAt = [p \in Peers |-> 0]
        /\ pc = [self \in ProcSet |-> CASE self \in Peers -> "PSample"
                                        [] self = "rev" -> "RWrite"
                                        [] self = "clk" -> "Tick"]

PSample(self) == /\ pc[self] = "PSample"
                 /\ \E tv \in {1, 2}:
                      \E bv \in {TRUE, FALSE}:
                        \E dv \in DeltaVals:
                          /\ banned' = [banned EXCEPT ![self] = bv]
                          /\ delta' = [delta EXCEPT ![self] = dv]
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
               /\ UNCHANGED << markerWritten, t, banned, delta, clock, 
                               markerAt >>

peerproc(self) == PSample(self) \/ PSync(self)

RWrite == /\ pc["rev"] = "RWrite"
          /\ /\ markerAt' = clock
             /\ markerWritten' = TRUE
          /\ pc' = [pc EXCEPT !["rev"] = "Done"]
          /\ UNCHANGED << revObserved, t, banned, delta, clock, obsAt >>

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
        /\ UNCHANGED << markerWritten, revObserved, t, banned, delta, markerAt, 
                        obsAt >>

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
