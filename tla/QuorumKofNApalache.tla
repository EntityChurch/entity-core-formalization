---- MODULE QuorumKofNApalache ----
\* QUORUM TRACK — Apalache (SMT) cross-check of tla/QuorumKofN.tla: §4.1
\* `verify_k_of_n_signatures`, the primitive §2 calls "the only mechanism that distinguishes
\* quorum from a regular peer node", plus the two sections that decide what it is called with.
\*
\* **THIS IS THE FIRST SECOND-ENGINE MODULE ON THE QUORUM TRACK.** Until 2026-09-08 all three
\* quorum modules and all three identity modules rested on TLC alone; `docs/COVERAGE-MATRIX.md`
\* section 3d states the live count and this file does not restate it.
\*
\* TRACK: `quorum` (TRACKS.toml). A bare §N.M means a section of EXTENSION-QUORUM.md at this
\* track's pin.
\*
\* WHAT A SECOND ENGINE BUYS HERE. `QuorumKofN` is an enumeration model, not a concurrency one:
\* `Next` is `UNCHANGED vars` and the state space IS the space of (resolution map, threshold,
\* who-signed, who-resolves) configurations. TLC enumerates it; Apalache answers one SMT query
\* over it. Independent METHOD, same transcription — a defect in either engine's search is
\* visible to the other, and a shared misreading of §4.1 survives both. That is the 5th wall
\* (../docs/ASSURANCE-MAP.md) and no engine moves it.
\*
\* WHAT IT DOES NOT BUY, AND THIS ONE MATTERS MORE HERE THAN ON THE ATTESTATION TRACK.
\* **Cryptography is abstracted away in both engines.** Whether a signature verifies is a
\* per-peer boolean; nothing is forged and nothing is signed. §4.1's adversarial property —
\* that the check cannot be satisfied without K distinct private keys — is a Dolev-Yao question
\* and **this track still has no prover model at all** (docs/LEAN-SEAM.md O14). Two engines on a
\* structural model is two engines on a structural model. Do not let this file be read as
\* corroborating the security of §4.1.
\*
\* THE TWO FINDINGS ARE REPRODUCED, NOT RE-DERIVED. `KofNRequiresASignature` (Q6) and
\* `ThresholdAttainable` (Q7) are checked in configs that expect a COUNTEREXAMPLE, exactly as
\* `QuorumKofNThreshold.cfg` / `QuorumKofNAttainable.cfg` do under TLC. Retirement condition is
\* the usual one: a green means the section was amended upstream and the row is RETIRED, not
\* repaired.
\*
\* NOTE WHICH DIRECTION Q6's CONSTANT FLIPS. `ConstInitFindingThreshold` sets
\* `CreateValidates = FALSE`, which moves the model **toward the specification**, not away from
\* it: §6.1 and §3.1 as written place no lower bound on `threshold`, and the bound the green
\* sweep runs is the one all three implementations supply and only §6.2 writes down. That is
\* `TLC_FINDING`'s second shape (see its header, which is the canonical statement) and it is why
\* this row is a finding rather than a negative control even though the grading is identical.
\*
\* ENCODER NOTES. This module needs no unrolling — §4.1 has no recursion, which is why it is the
\* cheapest of the six remaining extension modules to carry to a second engine and why it went
\* first. Two rewrites were still needed and are flagged at their sites: `Cardinality` over a set
\* built by image comprehension is replaced by a count over the DOMAIN with an explicit
\* first-occurrence test, because `{res[s] : s \in Slots}` is a set-valued term the encoder must
\* construct and then measure; and the counting itself is a fold rather than a `Cardinality` of a
\* filtered set. Both are places a transcription can drift, so `CountAgreesWithCardinality` is a
\* green row asserting the rewrite computes what the original does.
\*
\* Fidelity (5th wall): QuorumKofN.tla's abstraction boundary, unchanged — cryptography entirely,
\* the signature LOOKUP path, the chain walk and the cache (QuorumSignerSet and QuorumTrust model
\* those), and the resolver's own recursion, whose depth bound and cycle detection this module
\* does not open; the resolution map here is an arbitrary total function, strictly more
\* permissive than any bounded resolver could produce. Those sentences carry no § sigil
\* deliberately (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals, FiniteSets, Apalache

CONSTANTS
  \* @type: Int;
  NS,
  \* @type: Int;
  NP,
  \* @type: Bool;
  CreateValidates,
  \* @type: Bool;
  DedupeByPeer,
  \* @type: Bool;
  ResolveChecked

VARIABLES
  \* §5.1 / §5.2: slot -> resolved peer hash. The identity map is `concrete` mode; a
  \* non-injective map is what `identity-resolved` can produce.
  \* @type: Int -> Int;
  res,
  \* §3.1 threshold
  \* @type: Int;
  k,
  \* find_signature_by_signer found a signature from this peer AND verify_signature accepted it
  \* @type: Int -> Bool;
  sig,
  \* resolve_peer returned non-null for this peer
  \* @type: Int -> Bool;
  resolvable

vars == << res, k, sig, resolvable >>

Slots == 1..NS
Peers == 1..NP

\* ---------------------------------------------------------------------------------------
\* §4.1's loop body and its accumulator.
\* ---------------------------------------------------------------------------------------

\* A candidate contributes iff a verified signature was found for it and it resolves. Under the
\* control the resolve check is dropped.
Contributes(p) == /\ sig[p]
                  /\ ResolveChecked => resolvable[p]

\* "p is in the image of the resolution map", i.e. `p \in Resolved` without building `Resolved`.
IsResolvedTo(p) == \E s \in Slots : res[s] = p

\* The distinct peers the roster actually resolves to. §6.2's `|new_signers|` is NOT this number
\* — it is Cardinality(Slots), and the gap between them is finding Q7.
\*
\* Written as a fold over `Peers` with a membership test rather than as
\* `Cardinality({res[s] : s \in Slots})`: the image comprehension is a set-valued term the
\* encoder must construct before it can be measured, and every use of it in this module is a
\* count or a quantifier. `CountAgreesWithCardinality` below is the check that the rewrite is
\* faithful — this is the kind of substitution that reads as obviously equivalent and is exactly
\* where a transcription drifts.
EffectiveN == ApaFoldSet(LAMBDA a, p: IF IsResolvedTo(p) THEN a + 1 ELSE a, 0, Peers)

\* `signed` at the end of the loop. §4.1 accumulates into a SET keyed on the candidate, which is
\* the dedupe; the control counts SLOTS instead, which is the same algorithm with `signed` as a
\* list.
CountedPeers == ApaFoldSet(LAMBDA a, p: IF IsResolvedTo(p) /\ Contributes(p) THEN a + 1 ELSE a,
                           0, Peers)
CountedSlots == ApaFoldSet(LAMBDA a, s: IF Contributes(res[s]) THEN a + 1 ELSE a, 0, Slots)

Counted == IF DedupeByPeer THEN CountedPeers ELSE CountedSlots

\* §4.1's return value. The early `return true` and the final comparison compute the same
\* predicate, so one expression is faithful to both.
Verify == Counted >= k

\* ---------------------------------------------------------------------------------------
\* THE ENCODING'S OWN OBLIGATION — a green row, and the premise of the four below it.
\* ---------------------------------------------------------------------------------------

\* The fold-based counts agree with the set-cardinality forms QuorumKofN.tla uses. Asserted
\* rather than argued: this is the only difference between the two transcriptions, so if it does
\* not hold, the two engines are checking two different models and the corroboration claim is
\* false. The set forms appear ONLY here, where their cost is paid once.
CountAgreesWithCardinality ==
  /\ EffectiveN   = Cardinality({res[s] : s \in Slots})
  /\ CountedPeers = Cardinality({p \in {res[s] : s \in Slots} : Contributes(p)})
  /\ CountedSlots = Cardinality({s \in Slots : Contributes(res[s])})

\* ---------------------------------------------------------------------------------------
\* THE PROPERTIES — transcribed from QuorumKofN.tla, same names, same readings.
\* ---------------------------------------------------------------------------------------

\* §4.1 / §6.1 GREEN under CreateValidates, FINDING (Q6) without it. A successful K-of-N check
\* rests on at least one peer having actually signed. At threshold 0 §4.1's final line returns
\* true over an empty `signed` set, and §6.1 — unlike §6.2 — writes no constraint that excludes
\* it.
KofNRequiresASignature == Verify => Counted >= 1

\* §4.1 GREEN. The "defensive dedupe" line: whatever the roster looks like, the count never
\* exceeds the number of DISTINCT peers behind it. One key cannot fill two slots.
\* Control: DedupeByPeer = FALSE.
DedupeCountsPeersOnce == Counted <= EffectiveN

\* §4.1 GREEN. The `resolve_peer` null check: a peer this node cannot resolve contributes
\* nothing, even when a signature from it is present.
\* Control: ResolveChecked = FALSE.
UnresolvableNeverCounts ==
  (\A p \in Peers : IsResolvedTo(p) => (sig[p] /\ ~resolvable[p])) => Counted = 0

\* §6.2 / §5.2 FINDING (Q7). §6.2 validates `new_threshold <= |new_signers|` — the length of the
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
WitnessKofNPasses ==
  ~(\E p \in Peers : IsResolvedTo(p) /\ sig[p] /\ resolvable[p] /\ Verify /\ k >= 1)

\* Two slots resolve to ONE peer — the state Q7 is about, and the only state in which the dedupe
\* green says anything.
WitnessResolutionCollapses == ~(EffectiveN < NS)

\* A signature exists from a peer that does not resolve. Without this,
\* `UnresolvableNeverCounts` is satisfied by a model in which resolve_peer never fails.
WitnessUnresolvableSigner == ~(\E p \in Peers : IsResolvedTo(p) /\ sig[p] /\ ~resolvable[p])

\* ---------------------------------------------------------------------------------------
\* The space: every resolution map over the slots, every threshold the relevant reading admits,
\* and every combination of who signed and who resolves. `Init` IS the model; `Next` stutters,
\* because §4.1 is a pure function and pretending there is a transition system would be the
\* wrong model of one. Every check runs at --length=0.
\* ---------------------------------------------------------------------------------------
TypeOK == /\ res        \in [Slots -> Peers]
          /\ sig        \in [Peers -> BOOLEAN]
          /\ resolvable \in [Peers -> BOOLEAN]
          /\ k \in 0..NS

Init == /\ res \in [Slots -> Peers]
        /\ sig \in [Peers -> BOOLEAN]
        /\ resolvable \in [Peers -> BOOLEAN]
        \* `k <= NS` is §6.2's second conjunct and holds by the domain here; the half
        \* CreateValidates supplies is `k >= 1`, which is exactly the half §6.1 omits.
        /\ k \in 0..NS
        /\ CreateValidates => k >= 1

Next == UNCHANGED vars

\* ----- constant inits -----
\* Parity with the TLC green sweep: QuorumKofN.cfg's constants exactly.
ConstInitOK ==
  NS = 3 /\ NP = 3 /\ CreateValidates = TRUE /\ DedupeByPeer = TRUE /\ ResolveChecked = TRUE

\* FINDING Q6 — CreateValidates = FALSE restores §6.1 and §3.1 AS WRITTEN (threshold is a uint
\* and 0 is a uint). The constant moves TOWARD the spec; see the header.
\* Expected: counterexample on KofNRequiresASignature.
ConstInitFindingThreshold ==
  NS = 3 /\ NP = 3 /\ CreateValidates = FALSE /\ DedupeByPeer = TRUE /\ ResolveChecked = TRUE

\* FINDING Q7 — nothing is weakened; these are the green sweep's constants.
\* Expected: counterexample on ThresholdAttainable.
ConstInitFindingAttainable == ConstInitOK

\* NEG CONTROL — §4.1's defensive dedupe dropped, so `signed` counts slots.
\* Expected: counterexample on DedupeCountsPeersOnce.
ConstInitBugDedupe ==
  NS = 3 /\ NP = 3 /\ CreateValidates = TRUE /\ DedupeByPeer = FALSE /\ ResolveChecked = TRUE

\* NEG CONTROL — §4.1's `resolve_peer` null check dropped.
\* Expected: counterexample on UnresolvableNeverCounts.
ConstInitBugResolve ==
  NS = 3 /\ NP = 3 /\ CreateValidates = TRUE /\ DedupeByPeer = TRUE /\ ResolveChecked = FALSE
====
