---- MODULE IdentityRecovery ----
\* IDENTITY TRACK, second model. §9.4 compromise-recovery validation (MUST) -- the contact-side
\* rule that decides whether an identity whose controller key has been stolen can get itself
\* back.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin. Cross-track references write the sigil first (§ATTEST:8, §QUORUM:3.3) and are
\* EXCLUDED from every track's coverage set.
\*
\* ── WHY THIS MODULE WAS SPECIFIED BEFORE THE TRACK EXISTED ──────────────────────────────────
\* `TRACKS.toml`'s identity note and docs/status/SCOPING-2026-09-06-IDENTITY-ATTESTATION.md §3.3
\* both name this section, before a line was modeled, as the one thing to be careful about:
\*
\*   "the cross-peer recovery rule is a NEGATIVE REACHABILITY claim ('fail-closed if no
\*    quorum-publish is cached'), which is the highest vacuity risk there is -- a peer that does
\*    nothing satisfies it. WRITE THE WITNESS BEFORE THE PROHIBITION."
\*
\* That instruction is followed here literally, and following it is what produced the finding.
\* `RecoveryFailClosed` -- the prohibition, transcribed -- is GREEN. `RecoveryAttainable` -- the
\* witness, written as a positive claim so it can be checked rather than hoped for -- is
\* VIOLATED under §6.3 as written. The prohibition holds BECAUSE THE ACCEPTING PATH IS
\* UNREACHABLE, which is the exact failure mode the pre-model note predicted, arriving through a
\* door nobody was watching: not because §9.4 is too strong, but because §6.3 never lets the
\* cache be filled.
\*
\* A pre-model hypothesis is worth writing down precisely so you can find out how it was wrong,
\* and this one was not wrong -- it was right and under-specific. It said the risk was a model
\* with no paths. The risk was a SPEC with no paths.
\*
\* ── WHAT §9.4 SAYS ──────────────────────────────────────────────────────────────────────────
\*   "When `process_attestation` handles an arriving `identity-rotation-recovery` for a
\*    handle-bearing cert, it MUST validate the K-of-N signatures against the cached
\*    `quorum-publish` attestation for the identity. If no `quorum-publish` is cached ... the
\*    recovery rotation MUST be rejected (fail-closed). Recovery rotations cannot be accepted on
\*    the strength of arbitrary signatures; the contact's prior cached signer set is the trust
\*    anchor."
\*   "The cache lookup uses the `identity-rotation-recovery`'s `properties.old_handle`
\*    (hex-encoded) as the key: `contacts/{old_handle_hex}/quorum-publish`."
\* and §5.1's retention floor, which §9.4 cites as governing that entry's lifetime:
\*   "the previous-handle cache entry at `contacts/{old_handle_hex}/quorum-publish` MUST be
\*    retained at least through the in-flight window (UNTIL THE VERIFIER ACCEPTS THE NEW
\*    HANDLE). ... The retention requirement ensures the §9.4 fail-closed validation has a trust
\*    anchor available."
\*
\* and the only thing that fills that cache: §6.3's phase-2 dispatch row
\* `(quorum-publish, *) -> seed_contacts_cache`, which `IdentityProcess` shows phase 1 makes
\* unreachable. This module is that finding's consequence, measured.
\*
\* ── THE FOUR FINDINGS ───────────────────────────────────────────────────────────────────────
\*
\*  R1. `SeedFollowsArrival`. A genuine `quorum-publish` for the identity arrives at the contact
\*      and reaches `process_attestation`, and the cache is still empty afterwards -- §6.3 phase
\*      1 rejected it at `not_identity_attestation` and phase 2a unbound it.
\*
\*  R2. `RecoveryAttainable`, AND IT IS THE ONE TO READ. A genuine compromise-recovery, K-of-N
\*      signed by the identity's real quorum, delivered to a contact that has received that
\*      identity's genuine `quorum-publish`, is REJECTED. §9.4's fail-closed branch fires because
\*      the anchor it looks for was never stored. **Compromise recovery -- the property section 7.1's
\*      whole three-key custody model exists to provide, and section 9.6's only stated remedy for a
\*      stolen controller key -- does not complete on the pinned text.** No attacker is needed
\*      for this row; the attacker is what makes it matter.
\*
\*  R3. `AnchorWasValidated`. §9.4 calls the cached entry "the trust anchor" and neither §9.4 nor
\*      §6.3 says anything about validating what enters it. One of the three implementations
\*      therefore validates nothing on the way in.
\*
\*  R4. `RecoveryIdempotent`, and this one is about a floor set one instant too early. §5.1's
\*      retention requirement ends "until the verifier accepts the new handle" -- so at the
\*      moment of accept the anchor may be dropped, and §6.3's `update_handle_cache_to` side
\*      effect is unspecified enough that dropping it is the natural implementation (Go does
\*      exactly `Set(new); Remove(old)`). A DUPLICATE DELIVERY of the same recovery attestation
\*      then keys on `old_handle`, finds nothing, and fail-closes. §6.3's phase-3 note states an
\*      idempotent semantic as desired ("identical events at the same instant collapse to the
\*      same path -- desired idempotent semantic") and cross-peer sync does not promise
\*      exactly-once delivery. Two deliveries of one attestation, two different verdicts.
\*      NOTE WHAT THIS IS NOT: it is not a finding against Go. Removal AT accept satisfies
\*      "retained until accept" literally. The floor is the defect.
\*
\* ── THE COHORT, MEASURED BEFORE ANY IMPACT CLAIM ────────────────────────────────────────────
\* The seeding path splits three ways -- see `IdentityProcess`'s header for the code. What that
\* split means HERE is that §9.4's trust anchor is filled by different rules on each peer:
\*   entity-core-go    never seeds from `process_attestation`; defers to "quorum's sync hook".
\*                     A Go contact's anchor is empty unless something else fills it, so a Go
\*                     contact fail-closes on a recovery a Rust contact accepts.
\*   entity-core-rust  seeds unconditionally and WITHOUT validating -- `seed_contact_quorum_
\*                     publish_cache` runs before phase 1 and returns ok. R3 is about this.
\*   entity-core-py    validates via `process_quorum_attestation` first, seeds on success,
\*                     fail-closed-unbinds on failure. This is the behaviour §9.4 needs.
\* This is NOT the usual "three authors derived the same unwritten rule". It is three
\* incompatible answers to a question the spec does not ask, on the surface §2 of the quorum
\* spec calls "the only mechanism that distinguishes quorum from a regular peer node".
\*
\* ── THE ADVERSARY, DECLARED (D11) ───────────────────────────────────────────────────────────
\* One adversary action is modeled and it is the weakest one that reaches the property: the
\* attacker can cause a `quorum-publish` naming a signer set of its choosing to ARRIVE at the
\* contact, and can sign a rotation-recovery with that set. It cannot forge a signature from the
\* identity's real quorum. That arrival is not a modeling convenience -- §ATTEST:8 permits raw
\* `tree:put` to attestation paths (the already-routed Q5), and section 5.2's two-tier sync delivers to
\* `system/quorum/{trusts_quorum}/...` from the network. NOT modeled: key compromise thresholds
\* (section 9.7), the K-of-N arithmetic itself (that is §QUORUM:4.1 and QuorumKofN), replay
\* windows, and any notion of time.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): ABSTRACTED AWAY -- signature cryptography
\* entirely (a signer set is a generation number and "verifies" is equality), the K-of-N count
\* and threshold, `properties.old_handle` hex encoding and every other path construction, the
\* handle-bearing determination (this module assumes the recovery IS handle-bearing, which is
\* §9.4's own antecedent), the TTL garbage-collection clause, multiple contacts, multiple
\* identities, and the whole cert graph (that is IdentityCertChain). Those sentences carry no §
\* sigil deliberately -- a scope disclaimer that cites a section was being counted as coverage
\* of it (../docs/COVERAGE-MATRIX.md section 3b).
EXTENDS Naturals

CONSTANTS SeedEnabled,   \* does an arriving `quorum-publish` reach §6.3's
                         \* `(quorum-publish, *) -> seed_contacts_cache` row?
                         \* FALSE = §6.3 AS WRITTEN (phase 1 rejects it first).
                         \* TRUE  = the pre-phase-1 branch Rust and Python added.
          SeedValidates, \* does the seeding path validate the `quorum-publish` before caching?
                         \* TRUE  = Python. FALSE = Rust. The spec says NOTHING either way,
                         \* which is finding R3.
          FailClosed,    \* §9.4's MUST: reject when no `quorum-publish` is cached.
                         \* FALSE is a negative control -- "accepted on the strength of
                         \* arbitrary signatures", which §9.4 names and forbids.
          AnchorIsCachedPublish, \* §9.4: "the contact's prior cached signer set is the trust
                                 \* anchor". FALSE is a negative control and it is a rule with a
                                 \* NAMED wrong answer -- §QUORUM:3.3 says the K-of-N validation
                                 \* MUST use the prior publish's snapshot directly, "NOT
                                 \* `current_signer_set` resolved at the time of the prior
                                 \* publish". FALSE validates against the freshest set seen
                                 \* instead of the cached one.
          AnchorDroppedOnAccept  \* §5.1's retention floor ends "until the verifier accepts the
                                 \* new handle", so dropping the `old_handle` entry AT accept is
                                 \* conformant. TRUE is that reading; finding R4 is about it.

\* Signer-set generations. TWO suffice and the second one is the adversary's: `TrueQuorum` is
\* the identity's real K-of-N set, `Rogue` is a set the attacker holds. A recovery "verifies
\* against" an anchor exactly when their generations are equal.
TrueQuorum == 1
Rogue      == 2
Gens       == {TrueQuorum, Rogue}
NULL       == 0

\* One delivery is the ordinary case; TWO is the smallest model on which §6.3's stated
\* idempotent semantic can be checked at all.
MaxDeliveries == 2

VARIABLES anchor,      \* generation at contacts/{old_handle_hex}/quorum-publish; NULL if absent
          anchorOk,    \* was that entry VALIDATED on its way into the cache? (§6.3 is silent)
          lastSeen,    \* the freshest arrived quorum-publish generation, cached or not. Only
                       \* the AnchorIsCachedPublish = FALSE control reads this; it exists to
                       \* give the named wrong answer something to be wrong about.
          qpArrived,   \* a quorum-publish for this identity reached process_attestation
          qpGenuine,   \* ...and it was signed by the identity's real quorum
          recSg,       \* which signer set signed the arriving identity-rotation-recovery
          delivered,   \* how many times that recovery has been delivered (0..MaxDeliveries)
          v1, v2,      \* the verdict of each delivery: 0 = not yet, 1 = accepted, 2 = rejected
          trusted,     \* the contact's handle cache now points at the recovery's `attested`
          acceptedBare,\* an accept happened with NO cached anchor -- §9.4's forbidden outcome
          rejGenuine   \* a GENUINE recovery was fail-closed at a moment when the contact had
                       \* already received the identity's GENUINE quorum-publish. This is the
                       \* variable finding R2 is stated over, and it exists because the naive
                       \* form of that invariant is order-sensitive: a recovery delivered
                       \* BEFORE the publish arrives is rightly rejected, and an invariant that
                       \* could not tell the two apart would have reported a defect on an
                       \* ordinary out-of-order delivery.

vars == << anchor, anchorOk, lastSeen, qpArrived, qpGenuine, recSg,
           delivered, v1, v2, trusted, acceptedBare, rejGenuine >>

\* ---------------------------------------------------------------------------------------
\* §9.4's validation decision, transcribed. The `~FailClosed` disjunct is the control's
\* behaviour and is what §9.4's second sentence forbids in so many words.
\* ---------------------------------------------------------------------------------------
Validates == IF AnchorIsCachedPublish
             THEN \/ (anchor # NULL /\ recSg = anchor)
                  \/ (~FailClosed /\ anchor = NULL)
             ELSE \/ (lastSeen # NULL /\ recSg = lastSeen)
                  \/ (~FailClosed /\ lastSeen = NULL)

\* ---------------------------------------------------------------------------------------
\* ACTIONS
\* ---------------------------------------------------------------------------------------

\* A `quorum-publish` for this identity arrives at the contact and reaches §6.3
\* `process_attestation`. `gen` FALSE is the declared adversary action: an arrival the
\* identity's real quorum did not sign, which §ATTEST:8's permitted raw `tree:put` and §5.2's
\* two-tier sync both make available.
ArriveQuorumPublish ==
  /\ ~qpArrived
  /\ \E g \in Gens :
       LET gen == (g = TrueQuorum)
           \* Python's gate: a forged publish is rejected and fail-closed-unbound, so it never
           \* becomes the anchor. Rust has no gate. §6.3 as written never gets here at all.
           seeds == SeedEnabled /\ (SeedValidates => gen)
       IN /\ qpArrived'  = TRUE
          /\ qpGenuine'  = gen
          /\ lastSeen'   = g
          /\ anchor'     = IF seeds THEN g ELSE anchor
          /\ anchorOk'   = IF seeds THEN SeedValidates ELSE anchorOk
  /\ UNCHANGED << recSg, delivered, v1, v2, trusted, acceptedBare, rejGenuine >>

\* A handle-bearing `identity-rotation-recovery` is delivered. Delivering it a second time is
\* the duplicate cross-peer sync delivers without promising not to.
DeliverRecovery ==
  /\ delivered < MaxDeliveries
  /\ LET ok == Validates IN
       /\ delivered'    = delivered + 1
       /\ v1'           = IF delivered = 0 THEN (IF ok THEN 1 ELSE 2) ELSE v1
       /\ v2'           = IF delivered = 1 THEN (IF ok THEN 1 ELSE 2) ELSE v2
       /\ trusted'      = (trusted \/ ok)
       /\ acceptedBare' = (acceptedBare \/ (ok /\ anchor = NULL))
       /\ rejGenuine'   = (rejGenuine \/ (~ok /\ qpArrived /\ qpGenuine
                                          /\ recSg = TrueQuorum))
       \* §6.3's `(identity-rotation-recovery, *) -> update_handle_cache_to`, under §5.1's
       \* retention floor: the old-handle entry is needed UNTIL accept and no longer.
       /\ anchor'       = IF ok /\ AnchorDroppedOnAccept THEN NULL ELSE anchor
  /\ UNCHANGED << anchorOk, lastSeen, qpArrived, qpGenuine, recSg >>

\* ---------------------------------------------------------------------------------------
\* THE FINDINGS. Each asserted in a config where the constants say which document is on trial;
\* every cfg on this track states that in its first line (tla/Makefile TLC_FINDING header).
\* ---------------------------------------------------------------------------------------

\* FINDING R1. §6.3's seed row is the only thing that fills §9.4's anchor, and phase 1 makes it
\* unreachable, so a genuine quorum-publish arrives and the cache stays empty.
SeedFollowsArrival == (qpArrived /\ qpGenuine) => anchor # NULL

\* FINDING R2, THE HEADLINE. The witness, written as a positive claim so a machine can check it.
\* A genuine compromise-recovery delivered to a contact that HAS received the identity's genuine
\* quorum-publish is accepted. Under §6.3 as written it is not: §9.4 fail-closes on an anchor
\* that §6.3 never stored. This is the sentence "write the witness before the prohibition" was
\* asking for, and it is the one that fails.
RecoveryAttainable == ~rejGenuine

\* FINDING R3. §9.4 calls the cached entry the trust anchor; nothing in §9.4 or §6.3 says what
\* may become one.
AnchorWasValidated == anchor # NULL => anchorOk

\* FINDING R4. §6.3 states an idempotent semantic as desired and §5.1's retention floor expires
\* at the instant of accept, so a duplicate delivery of ONE attestation gets two verdicts.
\*
\* STATED AS MONOTONICITY, AND THE FIRST DRAFT WAS WRONG. It read `(v1 # 0 /\ v2 # 0) => v1 = v2`
\* -- "two deliveries, one verdict" -- and the GREEN cfg violated it immediately, on a behaviour
\* that is entirely correct: deliver before the quorum-publish has arrived (fail-closed, rightly),
\* the publish arrives, deliver again (accepted, rightly). Verdicts differ and nothing is wrong.
\* What §6.3's idempotent semantic actually asks for is that acceptance is not TAKEN BACK by
\* replaying the same attestation, which is the one-directional form below. Reading the invariant
\* did not catch it; running it did -- the same corollary this repo has now recorded four times.
RecoveryIdempotent == (v1 = 1 /\ v2 # 0) => v2 = 1

\* ---------------------------------------------------------------------------------------
\* THE GREENS.
\* ---------------------------------------------------------------------------------------

\* §9.4 GREEN -- THE PROHIBITION, AND READ THE NEXT SENTENCE BEFORE QUOTING IT. "Recovery
\* rotations cannot be accepted on the strength of arbitrary signatures." It holds. It also
\* holds, VACUOUSLY, under §6.3 as written, where nothing is ever accepted at all -- which is
\* why FINDING R2 exists and why this green is worth exactly as much as the witness beside it.
\* A negative-reachability claim that passes is not evidence until something reaches.
\* Control: FailClosed = FALSE.
RecoveryFailClosed == ~acceptedBare

\* §9.4 GREEN, and the one with the security content. Whatever the contact ends up trusting as
\* the identity's new handle was authorized by the identity's REAL quorum -- not by whoever most
\* recently pushed a quorum-publish at it. Two independent ways to break it, and the cfg headers
\* say which is which: a negative control (AnchorIsCachedPublish = FALSE -- the wrong answer
\* §QUORUM:3.3 names) and a finding (SeedValidates = FALSE -- the silence R3 is about).
AcceptedRecoveryIsQuorumSigned == trusted => recSg = TrueQuorum

\* §9.4 GREEN. The anchor is consulted, not bypassed: nothing is accepted without one while the
\* fail-closed rule is in force. Weaker than RecoveryFailClosed (which is about the outcome) and
\* stated separately because it is the sentence §9.4 writes about the MECHANISM.
AcceptRequiresAnchor == (FailClosed /\ AnchorIsCachedPublish /\ trusted) => qpArrived

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Asserted in order to be VIOLATED. On a module whose headline finding
\* IS a vacuity, these are not a formality.
\* ---------------------------------------------------------------------------------------

\* The anchor is ever non-empty.
WitnessAnchorSeeded == anchor = NULL

\* A recovery is ever ACCEPTED. If this comes back clean, every green above is a statement about
\* a contact that rejects everything -- which is precisely the state §6.3 as written leaves it in.
WitnessRecoveryAccepted == ~trusted

\* The fail-closed branch is ever TAKEN: a recovery delivered before any quorum-publish arrived.
\* Without it, RecoveryFailClosed could hold on a model that never exercises the rule.
WitnessFailClosedFires == ~(v1 = 2 \/ v2 = 2)

\* ---------------------------------------------------------------------------------------
\* Init / Next. `recSg` is chosen once -- it is a property of the attestation the attacker or
\* the identity produced, not something that changes under it.
\* ---------------------------------------------------------------------------------------
Init == /\ anchor       = NULL
        /\ anchorOk     = FALSE
        /\ lastSeen     = NULL
        /\ qpArrived    = FALSE
        /\ qpGenuine    = FALSE
        /\ recSg        \in Gens
        /\ delivered    = 0
        /\ v1           = 0
        /\ v2           = 0
        /\ trusted      = FALSE
        /\ acceptedBare = FALSE
        /\ rejGenuine   = FALSE

\* The stutter disjunct is unconditional: this is a safety/reachability module with no temporal
\* property in any cfg, so a terminal self-loop is the intended shape and TLC's deadlock check
\* has nothing to say about it.
Next == \/ ArriveQuorumPublish
        \/ DeliverRecovery
        \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == /\ anchor    \in Gens \cup {NULL}
          /\ lastSeen  \in Gens \cup {NULL}
          /\ recSg     \in Gens
          /\ delivered \in 0..MaxDeliveries
          /\ v1        \in 0..2
          /\ v2        \in 0..2
          /\ anchorOk     \in BOOLEAN
          /\ qpArrived    \in BOOLEAN
          /\ qpGenuine    \in BOOLEAN
          /\ trusted      \in BOOLEAN
          /\ acceptedBare \in BOOLEAN
          /\ rejGenuine   \in BOOLEAN
====
