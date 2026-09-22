---- MODULE QuorumKofN ----
\* QUORUM TRACK, third model. §4.1 `verify_k_of_n_signatures` — the primitive that is, in §2's
\* own words, "the only mechanism that distinguishes quorum from a regular peer node" — together
\* with the two sections that decide what it is called with.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin.
\*
\* WHAT §4.1 SAYS.
\*     signed = empty set
\*     for candidate in signer_set:
\*       if candidate in signed: continue                       ; defensive dedupe
\*       sig = find_signature_by_signer(entity_hash, candidate, ctx)
\*       if sig is null: continue
\*       candidate_peer = resolve_peer(candidate, ctx)
\*       if candidate_peer is null: continue
\*       if verify_signature(sig, candidate_peer):
\*         signed.add(candidate)
\*         if len(signed) >= threshold: return true
\*     return len(signed) >= threshold
\*
\* Three of its lines are load-bearing and are checked here as greens with controls: the
\* defensive dedupe (one peer cannot fill two slots), the `resolve_peer` null check (a signature
\* from a peer this node cannot resolve never counts), and the final threshold comparison.
\*
\* THE TWO FINDINGS ARE BOTH ABOUT THE ARGUMENTS, NOT THE ALGORITHM.
\*
\*  A. `threshold = 0` AUTHORIZES ANYTHING. The last line is `return len(signed) >= threshold`,
\*     which at threshold 0 is `0 >= 0` — true, with no signatures found, no peer resolved and
\*     nothing verified. So the question is whether a quorum can carry threshold 0, and the
\*     document answers it inconsistently:
\*       - §6.2 `:update` DOES constrain it: "Validates structural invariants (`new_threshold >=
\*         1`; `new_threshold <= |new_signers|`)."
\*       - §6.1 `:create` does NOT. Its whole normative content is params, result, and "Writes
\*         the `system/quorum` entity at `system/quorum/{quorum_id_hex}`."
\*       - §3.1's type gives `threshold: {type_ref: "primitive/uint"}` — and 0 is a uint.
\*       - the conformance MUST list in section 9.1 constrains neither. (No sigil on that one:
\*         this module makes no checked claim about the conformance section, and a citation
\*         where there is no claim is how a phantom grid row gets minted -- COVERAGE-MATRIX §3a.)
\*     The constraint exists for the operation that CHANGES a roster and not for the one that
\*     CREATES it. `KofNRequiresASignature` is asserted under each reading.
\*
\*  B. §6.2 VALIDATES THE THRESHOLD AGAINST THE WRONG N. `new_threshold <= |new_signers|` counts
\*     the entries of the signers ARRAY. In a resolution mode other than `concrete` — the
\*     `identity-resolved` mode §5.2 exists to register — each entry is a reference resolved to a
\*     peer hash, and two references can resolve to the SAME peer. §4.1's dedupe then counts that
\*     peer once, correctly. The effective N is the number of DISTINCT resolved peers, which the
\*     validated bound never sees. A quorum that passes every stated check can therefore be
\*     unable to reach its own threshold, permanently and by construction.
\*     `ThresholdAttainable`.
\*
\* THE COHORT, MEASURED. On A: all three implementations reject threshold 0 at the create path —
\* entity-core-go's `validateQuorum`, entity-core-rust's `handler.rs` (`threshold == 0 ||
\* threshold > signers.len()`), entity-core-py's `:create` — i.e. all three independently supply
\* the constraint §6.1 omits. Go's comment attributes it to "the §3.1 invariants", and §3.1
\* states no such invariant; the rule the cohort agrees on is written down for `:update` only.
\* Meanwhile entity-core-py's `verify_k_of_n_signatures` opens with `if threshold <= 0: return
\* True` — FAIL-OPEN, faithfully reproducing §4.1's last line. So the validator itself still
\* behaves as written; only the doors in front of it were closed, and only by convention.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- cryptography entirely
\* (whether a signature verifies is a per-peer boolean; unforgeability is a Dolev-Yao question
\* and this track has NO prover model at all, which docs/LEAN-SEAM.md O5 records as discharged
\* by nobody), the signature LOOKUP path and its invariant-pointer construction, the chain walk
\* and the cache (`QuorumSignerSet` and `QuorumTrust` model those), the resolver's own recursion
\* -- its depth bound and cycle detection are a graph-walk question this module does not open,
\* and the resolution map here is an arbitrary total function, which is strictly more permissive
\* than any bounded resolver could produce. Those sentences carry no § sigil deliberately -- a
\* scope disclaimer that cites a section was being counted as coverage of it
\* (../docs/COVERAGE-MATRIX.md §3b).
EXTENDS Naturals, FiniteSets

CONSTANTS NS,             \* entries in the §3.1 `signers` array -- the SLOTS. Three is enough
                          \* for two of them to collapse onto one peer and leave a third.
          NP,             \* distinct peers a slot can resolve to
          CreateValidates,\* TRUE  = the constraint all three implementations supply and §6.2
                          \*         writes for `:update`: threshold >= 1.
                          \* FALSE = §6.1 and §3.1 AS WRITTEN: `threshold` is a uint and 0 is a
                          \*         uint. This is the spec's own reading, not a weakening.
          DedupeByPeer,   \* TRUE  = §4.1's "defensive dedupe" as written: `signed` is a SET of
                          \*         candidates, so one peer counts once however many slots
                          \*         resolve to it.
                          \* FALSE = negative control: count slots.
          ResolveChecked  \* TRUE  = §4.1 as written: `if candidate_peer is null: continue`.
                          \* FALSE = negative control: drop the resolve_peer null check.

Slots == 1..NS
Peers == 1..NP

VARIABLES res,        \* §5.1 / §5.2: slot -> resolved peer hash. The identity map is `concrete`
                      \* mode; a non-injective map is what `identity-resolved` can produce.
          k,          \* §3.1 threshold
          sig,        \* find_signature_by_signer found a signature from this peer AND
                      \* verify_signature accepted it
          resolvable  \* resolve_peer returned non-null for this peer

vars == << res, k, sig, resolvable >>

\* The distinct peers the roster actually resolves to. §6.2's `|new_signers|` is NOT this
\* number -- it is Cardinality(Slots).
Resolved   == {res[s] : s \in Slots}
EffectiveN == Cardinality(Resolved)

\* §4.1's loop body, as a set. A candidate contributes iff a verified signature was found for it
\* and it resolves. Under the control the resolve check is dropped.
Contributes(p) == /\ sig[p]
                  /\ ResolveChecked => resolvable[p]

\* `signed` at the end of the loop. §4.1 accumulates into a SET keyed on the candidate, which is
\* the dedupe; the control counts slots instead, which is the same algorithm with `signed` as a
\* list.
Counted == IF DedupeByPeer
           THEN Cardinality({p \in Resolved : Contributes(p)})
           ELSE Cardinality({s \in Slots : Contributes(res[s])})

\* §4.1's return value, both exits -- the early `return true` and the final comparison compute
\* the same predicate, so one expression is faithful to both.
Verify == Counted >= k

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES
\* ---------------------------------------------------------------------------------------

\* §4.1 / §6.1 GREEN under CreateValidates, FINDING without it. A successful K-of-N check rests
\* on at least one peer having actually signed. At threshold 0 the final line returns true over
\* an empty `signed` set, and §6.1 -- unlike §6.2 -- writes no constraint that excludes it.
KofNRequiresASignature == Verify => Counted >= 1

\* §4.1 GREEN. The "defensive dedupe" line: whatever the roster looks like, the count never
\* exceeds the number of DISTINCT peers behind it. One key cannot fill two slots.
\* Control: DedupeByPeer = FALSE.
DedupeCountsPeersOnce == Counted <= EffectiveN

\* §4.1 GREEN. The `resolve_peer` null check: a peer this node cannot resolve contributes
\* nothing, even when a signature from it is present. This is the line that keeps the count over
\* peers the verifier actually knows.
\* Control: ResolveChecked = FALSE.
UnresolvableNeverCounts ==
  (\A p \in Resolved : sig[p] /\ ~resolvable[p]) => Counted = 0

\* §6.2 / §5.2 FINDING. §6.2 validates `new_threshold <= |new_signers|` -- the length of the
\* signers ARRAY. The attainable maximum is the number of distinct RESOLVED peers, which is
\* smaller whenever two references resolve to one peer. A quorum can pass every stated check and
\* still be unable to reach its own threshold, for as long as the resolution holds.
ThresholdAttainable == k <= EffectiveN

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Each asserted in order to be VIOLATED; the violation is the pass.
\* ---------------------------------------------------------------------------------------

\* K-of-N actually SUCCEEDS somewhere, with a threshold above zero and a real signature behind
\* it. Without this every green above holds over a model in which nothing ever verifies, and
\* `KofNRequiresASignature` in particular would be an implication with a false antecedent.
WitnessKofNPasses == ~(\E p \in Resolved : sig[p] /\ resolvable[p] /\ Verify /\ k >= 1)

\* Two slots resolve to ONE peer -- the state FINDING B is about, and the only state in which
\* the dedupe green says anything.
WitnessResolutionCollapses == ~(EffectiveN < NS)

\* A signature exists from a peer that does not resolve. Without this,
\* `UnresolvableNeverCounts` is satisfied by a model in which resolve_peer never fails.
WitnessUnresolvableSigner == ~(\E p \in Resolved : sig[p] /\ ~resolvable[p])

\* ---------------------------------------------------------------------------------------
\* The space: every resolution map over the slots, every threshold the relevant reading admits,
\* and every combination of who signed and who resolves.
\* ---------------------------------------------------------------------------------------
Init == /\ res \in [Slots -> Peers]
        /\ sig \in [Peers -> BOOLEAN]
        /\ resolvable \in [Peers -> BOOLEAN]
        \* `k <= NS` is §6.2's second conjunct and holds by the domain here; the half that
        \* CreateValidates supplies is `k >= 1`, which is exactly the half §6.1 omits.
        /\ k \in 0..NS
        /\ CreateValidates => k >= 1

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ res \in [Slots -> Peers]
          /\ sig \in [Peers -> BOOLEAN]
          /\ resolvable \in [Peers -> BOOLEAN]
          /\ k \in 0..NS
====
