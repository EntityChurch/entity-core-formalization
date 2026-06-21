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
\* is noted, not modeled (PHASE1-SCOPE §7). Every element cites its V7 §ref.
EXTENDS Naturals

CONSTANTS HonorRevocation,   \* TRUE = §5.1: an observed revocation makes the cap fail every
                             \*        check; FALSE = negative control: revocation ignored.
          LeakLayer1,        \* FALSE = §5.10: Layer-1 verdict ignores local policy; TRUE =
                             \*         negative control: a local banlist (Layer 2) modulates
                             \*         the Layer-1 verdict -> cross-peer determinism breaks.
          NoConverge         \* FALSE = §5.10: a written marker is eventually observed by all peers;
                             \*         TRUE = LIVENESS negative control: a peer never observes the
                             \*         marker (non-convergent) -> RevocationConverges fails.

Peers == {"A", "B"}

(*--algorithm revoke
variables
  markerWritten = FALSE,                  \* §5.1: a revocation marker has been written (put(path,null))
  revObserved = [p \in Peers |-> FALSE],  \* §5.10: has peer p OBSERVED the marker? (async-convergent)
  t           = [p \in Peers |-> 1],      \* §5.10: each peer's once-per-verdict evaluation timestamp
  banned      = [p \in Peers |-> FALSE];  \* §5.10 Layer-2: a purely-local banlist bit (policy state)

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
      revObserved[self] := TRUE;      \* monotonic: once observed, stays observed (markers are content-addressed)
    or
      await NoConverge;               \* LIVENESS NEG CONTROL: peer finishes blind, never observing the marker
      skip;
    end either;
end process;

\* The revoker writes the revocation marker (§5.1 put(path,null)); both peers converge on it.
fair process revoker = "rev"
begin
  RWrite:
    markerWritten := TRUE;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "e47bf580" /\ chksum(tla) = "9bba7e95")
VARIABLES pc, markerWritten, revObserved, t, banned

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


vars == << pc, markerWritten, revObserved, t, banned >>

ProcSet == (Peers) \cup {"rev"}

Init == (* Global variables *)
        /\ markerWritten = FALSE
        /\ revObserved = [p \in Peers |-> FALSE]
        /\ t = [p \in Peers |-> 1]
        /\ banned = [p \in Peers |-> FALSE]
        /\ pc = [self \in ProcSet |-> CASE self \in Peers -> "PSample"
                                        [] self = "rev" -> "RWrite"]

PSample(self) == /\ pc[self] = "PSample"
                 /\ \E tv \in {1, 2}:
                      \E bv \in {TRUE, FALSE}:
                        /\ banned' = [banned EXCEPT ![self] = bv]
                        /\ t' = [t EXCEPT ![self] = tv]
                 /\ pc' = [pc EXCEPT ![self] = "PSync"]
                 /\ UNCHANGED << markerWritten, revObserved >>

PSync(self) == /\ pc[self] = "PSync"
               /\ \/ /\ markerWritten
                     /\ revObserved' = [revObserved EXCEPT ![self] = TRUE]
                  \/ /\ NoConverge
                     /\ TRUE
                     /\ UNCHANGED revObserved
               /\ pc' = [pc EXCEPT ![self] = "Done"]
               /\ UNCHANGED << markerWritten, t, banned >>

peerproc(self) == PSample(self) \/ PSync(self)

RWrite == /\ pc["rev"] = "RWrite"
          /\ markerWritten' = TRUE
          /\ pc' = [pc EXCEPT !["rev"] = "Done"]
          /\ UNCHANGED << revObserved, t, banned >>

revoker == RWrite

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == revoker
           \/ (\E self \in Peers: peerproc(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Peers : WF_vars(peerproc(self))
        /\ WF_vars(revoker)

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (checked as PROPERTY; needs the WF supplied by `fair process`) =====

\* §5.10: revocation is a CONVERGENT input — a written marker is eventually observed by every
\* verifier in the same tier. Once the marker exists, both peers converge on observing it.
RevocationConverges == markerWritten ~> (\A p \in Peers : revObserved[p])
====
