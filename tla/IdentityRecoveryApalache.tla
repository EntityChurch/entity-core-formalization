---- MODULE IdentityRecoveryApalache ----
\* IDENTITY TRACK — Apalache (SMT) second engine on tla/IdentityRecovery.tla (§9.4
\* compromise-recovery validation), and the one place on that subject where a second engine was
\* worth the most: docs/CORROBORATION.md ranked it FIRST of the three single-engine rows because
\* the result it carries is a NEGATIVE REACHABILITY claim, which is the weakest shape published
\* here — `RecoveryFailClosed` is green precisely because the accepting path does not exist.
\*
\* TRACK: `identity` (TRACKS.toml). A bare §N.M means a section of EXTENSION-IDENTITY.md at this
\* track's pin (spec-data/ext-identity-v3.10). Cross-track references write the sigil first
\* (§ATTEST:8, §QUORUM:3.3) and are EXCLUDED from every track's coverage set.
\*
\* ── WHAT A SECOND ENGINE WAS POINTED AT, AND WHY IT IS NOT THE INVARIANTS ────────────────────
\* D16's generalization, earned twice already on this repo (AttestRevokeApalache, then
\* QuorumSignerSetApalache): **point the second engine at the first one's `Init`, not at its
\* invariants.** An invariant re-checked is a second opinion on a question already asked; a
\* domain restriction lifted is a question the first model could not pose.
\*
\* `tla/IdentityRecovery.tla` carries THREE restrictions, and none of them is in `Init` — which
\* is itself worth recording, because D15's tenth-shape enumeration (AGENTS.md) walked the nine
\* extension models' `Init` predicates and this module's row reads "Init is a concrete start
\* state, not a domain restriction". That was true and it was not the whole site class:
\*
\*   (a) THE CACHE HAS NO KEY. `anchor` is one slot. §5.1 writes the entry at
\*       `contacts/{published_handle_hex}/quorum-publish` — keyed by the quorum-publish's OWN
\*       `properties.published_handle` — and §9.4 reads it at `contacts/{old_handle_hex}/
\*       quorum-publish`, keyed by the RECOVERY's `properties.old_handle`. A keyless model
\*       assumes those two are the same handle. The header of the TLC module declares the
\*       abstraction in plain terms ("`properties.old_handle` hex encoding and every other path
\*       construction" are abstracted away) — and O9's lesson is that **a declared abstraction is
\*       a to-do list, not an absolution**.
\*   (b) THE HANDLE NEVER MOVES. There is no §4.3 handoff action, so the model cannot represent
\*       the one ordinary event that changes which key `old_handle` will name.
\*   (c) DELIVERY IS BOUNDED AT TWO (`MaxDeliveries == 2`, with `v1`/`v2` as separate variables).
\*       §6.3's idempotent semantic is checked over exactly two deliveries.
\*
\* This module lifts all three: the cache is a function over handles, rotations are actions, and
\* delivery is unbounded (the inductive obligations below hold for runs of ANY length, so
\* "replayed once" and "replayed forever" are the same claim here).
\*
\* ── WHAT THAT BOUGHT: A DEFECT THE FIRST ENGINE COULD NOT SEE ────────────────────────────────
\* Third consecutive time a lifted restriction has found something, and the third time the
\* written-down expectation was right about WHERE to look and wrong about WHAT is there.
\*
\*  N1. **A ROUTINE HANDLE ROTATION DISABLES COMPROMISE RECOVERY.** Section 13.3's ceremony (privacy
\*      hygiene, no compromise) rotates the handle by dual-signed `identity-rotation-handoff`:
\*      "The quorum doesn't sign this." No `quorum-publish` is produced and no section requires
\*      one afterwards — §3.3 leaves publication timing to the identity in so many words ("the
\*      identity's contribution is choosing WHEN to call them and what `published_handle` value
\*      to use"). The contact's §9.4 anchor therefore stays keyed at the PRE-rotation handle,
\*      while a later §4.4 recovery carries `old_handle` = the POST-rotation handle. §9.4 looks
\*      up a key nothing ever wrote, and fail-closes. Section 9.6 names compromise recovery as
\*      the only remedy for a stolen controller key; a preventive privacy rotation removes it.
\*      Rows: `AnchorSurvivesHandoff` (the mechanism) and `HandoffKeepsRecoveryAvailable` (the
\*      consequence, carrying every antecedent an objection needs), both under
\*      `ConstInitRotations`, where NOTHING ELSE IS WEAKENED — the constants are the cohort's
\*      repairs, exactly the green sweep's. Both are GREEN under `ConstInitHandoffRekey`, which
\*      is the first of the two candidate repairs, checked rather than suggested.
\*      `RecoveryAttainable` is NOT one of these rows and the reason is worth reading before
\*      adding a row here: see its own comment at `rejGenuine`.
\*
\*  N2. **`update_handle_cache_to` is named in a normative dispatch table, defined nowhere, and
\*      its two readings each satisfy one of two properties the spec states — neither satisfies
\*      both.** §6.3 dispatches `(identity-rotation-recovery, *) -> update_handle_cache_to`.
\*      That handler's effect on the §9.4 cache is written in no section.
\*        · MOVE the entry to the new handle (`ConstInitGo`): a SECOND recovery finds its anchor,
\*          and a duplicate delivery of the FIRST one does not — `RecoveryIdempotent` breaks,
\*          which is already-routed I7 arriving through a different door.
\*        · RETAIN it at the old handle (`ConstInitRustPy`): duplicate delivery is idempotent,
\*          and the second recovery in a chain has no anchor — `SecondRecoveryHasAnchor` breaks.
\*      **The remedy is checkable and it is checked**: COPY to the new key and KEEP the old one
\*      (`ConstInitRekeyRetain`) satisfies both, and `WitnessChainedAccept` exhibits a run where
\*      two recoveries in a row are accepted. A remedy that is measured rather than proposed is
\*      the thing this repo got wrong once already (docs/PROPERTIES.md §D.1: our source census
\*      was upheld and our REMEDY was not), so it is stated as a gate row and not as prose.
\*
\* ── THE COHORT, MEASURED BEFORE ANY IMPACT CLAIM (docs/PROPERTIES.md §D.1) ───────────────────
\* Read from source at the sibling checkouts, not from memory. Three implementations, three
\* different answers to N2 — a C3 row (`docs/status/CONFORMANCE-DIVERGENCE-REGISTER.md`), which
\* crosses a peer boundary:
\*   entity-core-go    MOVES it. `ext/identity/ops.go`, KindIdentityRotationRecovery:
\*                     `LocationIndex.Set(contactsQuorumPublishPath(a.Attested), oldEntry)` then
\*                     `Remove(contactsQuorumPublishPath(*props.OldHandle))`.
\*   entity-core-rust  EXPLICIT NO-OP with a written rationale.
\*                     `extensions/identity/src/ops/process_attestation.rs`,
\*                     `update_handle_cache_on_recovery`: "old cache entry is retained per §5.1
\*                     ... The cache update happens when the next quorum-publish for the new key
\*                     fires seed_contact_quorum_publish_cache." Nothing requires that publish.
\*   entity-core-py    ABSENT. `HANDLER_ID_UPDATE_HANDLE_CACHE_TO` is defined at
\*                     `packages/entity-handlers/src/entity_handlers/identity.py` and referenced
\*                     nowhere; `_apply_post_validation_side_effects` has branches for
\*                     `(identity-cert, controller)` and `identity-retirement` only.
\* On N1 the cohort is UNANIMOUS and unanimously exposed, which is the C2 shape (the peers follow
\* the text faithfully and nothing protects the field): no implementation re-keys the anchor on a
\* handoff. Go says so in a comment — KindIdentityRotationHandoff: "No additional caches to
\* update" — and Rust and Python have no handoff cache branch at all.
\*
\* ── WHAT THIS MODULE DOES *NOT* BUY (D16's counter-clause, stated at the site) ────────────────
\* Not independence from the transcription. This is the same author's reading of the same pinned
\* text as `IdentityRecovery.tla`; a misreading survives both engines. Not a different QUESTION
\* either — TLC and Apalache are both checkers over TLA+ semantics. What moved here is the
\* DOMAIN, not the engine's power: N1 and N2 would be visible to TLC on this module too. That is
\* the honest statement of the result, and it is why `docs/CORROBORATION.md` records "2" as a
\* count and not as a grade.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the abstraction boundary is IdentityRecovery's,
\* minus the three restrictions above. Still ABSTRACTED AWAY — signature cryptography entirely (a
\* signer set is a generation number, "verifies" is equality), the K-of-N count and threshold
\* (that is §QUORUM:4.1 / QuorumKofN), hex encoding and path construction below the level of
\* "which handle keys the entry", the TTL garbage-collection clause, multiple contacts, multiple
\* identities, and the cert graph (that is IdentityCertChain). Handles are an ordered chain of at
\* most three because §9.4's question is about the SUCCESSOR relation between them, not about
\* their values; a fourth adds no shape.
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  SeedEnabled,           \* §6.3: does an arriving `quorum-publish` reach the phase-2 row
                         \* `(quorum-publish, *) -> seed_contacts_cache`? FALSE = §6.3 AS
                         \* WRITTEN (phase 1 rejects it first) = finding I1/R1.
  \* @type: Bool;
  SeedValidates,         \* does the seeding path validate before caching? TRUE = python,
                         \* FALSE = rust. The spec says nothing either way = finding I6/R3.
  \* @type: Bool;
  FailClosed,            \* §9.4's MUST: reject when no `quorum-publish` is cached at the
                         \* lookup key. FALSE is a negative control.
  \* @type: Bool;
  AnchorIsCachedPublish, \* §9.4: "the contact's prior CACHED signer set is the trust anchor".
                         \* FALSE is a negative control with a NAMED wrong answer — §QUORUM:3.3
                         \* forbids resolving against the freshest set seen.
  \* @type: Bool;
  AnchorDroppedOnAccept, \* §5.1's retention floor ends "until the verifier accepts the new
                         \* handle", so dropping the old-handle entry AT accept is conformant.
                         \* Finding I7/R4 is about that instant.
  \* @type: Bool;
  RotationsEnabled,      \* LIFTS restriction (b). FALSE reproduces IdentityRecovery.tla's
                         \* domain: no §4.3 handoff, and at most the single §4.4 recovery that
                         \* model represents. TRUE admits the routine rotation of section 13.3 and a
                         \* chain of recoveries.
  \* @type: Bool;
  RecoveryRekeysAnchor,  \* §6.3 `update_handle_cache_to`, READING 1: the cached quorum-publish
                         \* is COPIED to the new handle's key (entity-core-go).
  \* @type: Bool;
  HandoffRekeysAnchor    \* §6.3 `handle_dual_sig_handoff`: same question on the §4.3 path. No
                         \* implementation does this and no sentence asks for it; TRUE is the
                         \* reading in which N1 does not arise.

\* Signer-set generations. TWO suffice and the second is the adversary's, exactly as in the TLC
\* module: `TrueQuorum` is the identity's real K-of-N set, `Rogue` is one the attacker holds. A
\* recovery "verifies against" an anchor exactly when the generations are equal.
NULL       == 0
TrueQuorum == 1
Rogue      == 2
Gens       == {TrueQuorum, Rogue}

\* The handle chain. Handle h is rotated to handle h+1, by §4.3 handoff or by §4.4 recovery.
Handles == {1, 2, 3}

VARIABLES
  \* @type: Int;
  handle,        \* the identity's CURRENT handle. A recovery signed now carries
                 \* `properties.old_handle` = this.
  \* @type: Int -> Int;
  anchor,        \* §5.1's cache: handle |-> generation of the quorum-publish stored at
                 \* `contacts/{that handle}/quorum-publish`. NULL = no entry at that key.
  \* @type: Int -> Bool;
  anchorOk,      \* was that entry VALIDATED on its way in? §6.3 is silent (finding I6/R3).
  \* @type: Int -> Bool;
  genuineSeen,   \* a quorum-publish naming this handle, signed by the identity's REAL quorum,
                 \* reached the contact's process_attestation.
  \* @type: Int;
  lastSeen,      \* generation of the most recent arriving publish, cached or not. Only the
                 \* AnchorIsCachedPublish = FALSE control reads it — it exists to give the
                 \* named wrong answer something to be wrong about.
  \* @type: Int -> Int;
  rec,           \* rec[h] = the signer generation of the `identity-rotation-recovery`
                 \* attestation carrying old_handle = h, or NULL if no such attestation exists.
  \* @type: Int -> Bool;
  hoff,          \* hoff[h] = a §4.3 dual-signed handoff from handle h to h+1 was processed.
  \* @type: Int -> Bool;
  acceptedRec,   \* acceptedRec[h] = the recovery for old_handle h was ACCEPTED at the contact.
  \* @type: Bool;
  trusted,       \* some recovery was accepted (the contact's cached handle moved).
  \* @type: Bool;
  trustedRogue,  \* ...and one of them was not signed by the identity's real quorum.
  \* @type: Bool;
  acceptedBare,  \* an accept happened with NO entry at the lookup key — §9.4's forbidden
                 \* outcome, stated over the OUTCOME rather than over the rule.
  \* @type: Bool;
  rejGenuine,    \* a GENUINE recovery for old_handle h was fail-closed while the contact had
                 \* already received the identity's GENUINE quorum-publish NAMING THAT HANDLE.
                 \* The keyed generalization of the TLC module's `qpArrived /\ qpGenuine`, and
                 \* deliberately unforgiving in one direction: a recovery rejected before any
                 \* publish arrived is rightly rejected and does not set it.
                 \*
                 \* AND THE FIRST DRAFT READ `\E k \in Handles : genuineSeen[k]` — "the contact
                 \* has SOME genuine publish" — which is the same sentence in the keyless world
                 \* and a much weaker claim in this one. It was violated under
                 \* `ConstInitRotations`, and reading the trace (rather than the exit code)
                 \* showed `handoffSeen = FALSE`: the run was SignRecovery, then a publish
                 \* naming the NEW handle, then delivery of the recovery for the old one. A true
                 \* instance of "no anchor at the lookup key", already covered by I1/R1, and NOT
                 \* the handoff mechanism the row was added to exhibit. Tightened to
                 \* `genuineSeen[h]`; N1 is carried by the two rows that name their mechanism.
                 \* Sixth consecutive session in which reading a result rather than its exit
                 \* status is what caught something (D15's corollary).
  \* @type: Bool;
  handoffSeen,   \* a §4.3 routine rotation happened in this run. Used only to separate N1's
                 \* counterexample from every other way `rejGenuine` can be reached.
  \* @type: Bool;
  idemBroken     \* a recovery that was accepted was later REJECTED on re-delivery. §6.3's
                 \* phase-3 note states the idempotent semantic as desired; §5.2's sync
                 \* promises nothing about exactly-once delivery.

vars == << handle, anchor, anchorOk, genuineSeen, lastSeen, rec, hoff, acceptedRec,
           trusted, trustedRogue, acceptedBare, rejGenuine, handoffSeen, idemBroken >>

\* ---------------------------------------------------------------------------------------
\* §9.4's validation decision, transcribed — now READING AT A KEY. The `~FailClosed` disjunct
\* is the control's behaviour and is what §9.4's second sentence forbids in so many words.
\* ---------------------------------------------------------------------------------------
Validates(h) ==
  IF AnchorIsCachedPublish
  THEN \/ (anchor[h] # NULL /\ rec[h] = anchor[h])
       \/ (~FailClosed /\ anchor[h] = NULL)
  ELSE \/ (lastSeen # NULL /\ rec[h] = lastSeen)
       \/ (~FailClosed /\ lastSeen = NULL)

\* ---------------------------------------------------------------------------------------
\* ACTIONS
\* ---------------------------------------------------------------------------------------

\* §4.4 (ceremony: section 13.2): the identity's real quorum signs a compromise-recovery for the CURRENT handle,
\* which is what `properties.old_handle` names. Signing it rotates the identity (section 9.6: "cached
\* handle updates to the new key"); whether the CONTACT accepts is decided by DeliverRecovery.
\* With RotationsEnabled = FALSE the `handle = 1` guard leaves exactly one recovery attestation
\* in the model, which is IdentityRecovery.tla's world.
SignRecovery ==
  /\ RotationsEnabled \/ handle = 1
  /\ handle + 1 \in Handles
  /\ rec[handle] = NULL
  /\ rec'    = [rec EXCEPT ![handle] = TrueQuorum]
  /\ handle' = handle + 1
  /\ UNCHANGED << anchor, anchorOk, genuineSeen, lastSeen, hoff, acceptedRec,
                  trusted, trustedRogue, acceptedBare, rejGenuine, handoffSeen, idemBroken >>

\* §4.3 (ceremony: section 13.3): ROUTINE HANDLE ROTATION. Dual-signed by the old and new handle keys; "the
\* quorum doesn't sign this". No quorum-publish is produced. §6.3 dispatches
\* `(identity-rotation-handoff, *) -> handle_dual_sig_handoff`, a handler named in the table and
\* defined in no section — `HandoffRekeysAnchor` is the reading in which it moves the §9.4
\* anchor to the new key. No implementation reads it that way.
RotateHandoff ==
  /\ RotationsEnabled
  /\ handle + 1 \in Handles
  /\ ~hoff[handle]
  /\ hoff'        = [hoff EXCEPT ![handle] = TRUE]
  /\ handle'      = handle + 1
  /\ handoffSeen' = TRUE
  \* The copy is conditional on there BEING an entry to copy, which is how a move is written
  \* where one exists: entity-core-go's recovery arm is `if oldEntry, ok := Get(old); ok { … }`.
  \* Unconditional assignment would let a re-key ERASE an entry at the new key, which no reading
  \* of the handler proposes and which would have made the strengthening below false for a
  \* reason that is an artifact of this module.
  /\ anchor'      = IF HandoffRekeysAnchor /\ anchor[handle] # NULL
                    THEN [anchor EXCEPT ![handle + 1] = anchor[handle]]
                    ELSE anchor
  /\ anchorOk'    = IF HandoffRekeysAnchor /\ anchor[handle] # NULL
                    THEN [anchorOk EXCEPT ![handle + 1] = anchorOk[handle]]
                    ELSE anchorOk
  /\ UNCHANGED << genuineSeen, lastSeen, rec, acceptedRec,
                  trusted, trustedRogue, acceptedBare, rejGenuine, idemBroken >>

\* THE DECLARED ADVERSARY (D11), unchanged from the TLC module and no stronger: the attacker can
\* cause an attestation naming a signer set of its choosing to ARRIVE, and can sign with that
\* set. It cannot forge a signature from the identity's real quorum. §ATTEST:8 permits raw
\* `tree:put` to attestation paths (the already-routed Q5) and §5.2's two-tier sync delivers to
\* `system/quorum/{trusts_quorum}/...` from the network.
ForgeRecovery ==
  /\ \E h \in Handles :
       /\ rec[h] = NULL
       /\ rec'   = [rec EXCEPT ![h] = Rogue]
  /\ UNCHANGED << handle, anchor, anchorOk, genuineSeen, lastSeen, hoff, acceptedRec,
                  trusted, trustedRogue, acceptedBare, rejGenuine, handoffSeen, idemBroken >>

\* A `quorum-publish` naming `properties.published_handle` = h arrives at the contact and reaches
\* §6.3 `process_attestation`. THE WRITE KEY IS h — §5.1's `contacts/{published_handle_hex}/
\* quorum-publish` — which is the whole point of this module: §9.4 reads at a key derived from a
\* different attestation. A genuine publish names the identity's CURRENT handle; a forged one may
\* name anything. Re-publication is unrestricted: nothing here bounds how many arrive.
Publish ==
  /\ \E h \in Handles, g \in Gens :
       /\ (g = TrueQuorum) => (h = handle)
       /\ LET seeds == SeedEnabled /\ (SeedValidates => (g = TrueQuorum)) IN
            /\ lastSeen'    = g
            /\ genuineSeen' = IF g = TrueQuorum
                              THEN [genuineSeen EXCEPT ![h] = TRUE] ELSE genuineSeen
            /\ anchor'      = IF seeds THEN [anchor EXCEPT ![h] = g] ELSE anchor
            /\ anchorOk'    = IF seeds THEN [anchorOk EXCEPT ![h] = SeedValidates] ELSE anchorOk
  /\ UNCHANGED << handle, rec, hoff, acceptedRec,
                  trusted, trustedRogue, acceptedBare, rejGenuine, handoffSeen, idemBroken >>

\* A handle-bearing `identity-rotation-recovery` is delivered to the contact. UNBOUNDED: the same
\* attestation may be delivered any number of times, which is what §5.2's sync surface permits
\* and what the TLC module could only represent twice.
DeliverRecovery ==
  /\ \E h \in Handles :
       /\ rec[h] # NULL
       /\ LET ok  == Validates(h)
              \* §6.3 `(identity-rotation-recovery, *) -> update_handle_cache_to`, both readings.
              \* Copy-to-new is entity-core-go's `Set(new, oldEntry)`; drop-old is its `Remove`,
              \* which §5.1's floor permits because the floor expires AT accept.
              moved == IF RecoveryRekeysAnchor /\ (h + 1 \in Handles) /\ anchor[h] # NULL
                       THEN [anchor EXCEPT ![h + 1] = anchor[h]]
                       ELSE anchor
              movedOk == IF RecoveryRekeysAnchor /\ (h + 1 \in Handles) /\ anchor[h] # NULL
                         THEN [anchorOk EXCEPT ![h + 1] = anchorOk[h]]
                         ELSE anchorOk
          IN
          /\ trusted'      = (trusted \/ ok)
          /\ trustedRogue' = (trustedRogue \/ (ok /\ rec[h] # TrueQuorum))
          /\ acceptedBare' = (acceptedBare \/ (ok /\ anchor[h] = NULL))
          /\ acceptedRec'  = IF ok THEN [acceptedRec EXCEPT ![h] = TRUE] ELSE acceptedRec
          /\ idemBroken'   = (idemBroken \/ (~ok /\ acceptedRec[h]))
          /\ rejGenuine'   = (rejGenuine \/ (~ok /\ rec[h] = TrueQuorum /\ genuineSeen[h]))
          /\ anchor'       = IF ok /\ AnchorDroppedOnAccept
                             THEN [moved EXCEPT ![h] = NULL] ELSE (IF ok THEN moved ELSE anchor)
          /\ anchorOk'     = IF ok /\ AnchorDroppedOnAccept
                             THEN [movedOk EXCEPT ![h] = FALSE]
                             ELSE (IF ok THEN movedOk ELSE anchorOk)
  /\ UNCHANGED << handle, genuineSeen, lastSeen, rec, hoff, handoffSeen >>

Init ==
  /\ handle       = 1
  /\ anchor       = [h \in Handles |-> NULL]
  /\ anchorOk     = [h \in Handles |-> FALSE]
  /\ genuineSeen  = [h \in Handles |-> FALSE]
  /\ lastSeen     = NULL
  /\ rec          = [h \in Handles |-> NULL]
  /\ hoff         = [h \in Handles |-> FALSE]
  /\ acceptedRec  = [h \in Handles |-> FALSE]
  /\ trusted      = FALSE
  /\ trustedRogue = FALSE
  /\ acceptedBare = FALSE
  /\ rejGenuine   = FALSE
  /\ handoffSeen  = FALSE
  /\ idemBroken   = FALSE

\* The stutter disjunct is unconditional: this is a safety/reachability module with no temporal
\* property, so a terminal self-loop is the intended shape.
Next == \/ SignRecovery
        \/ RotateHandoff
        \/ ForgeRecovery
        \/ Publish
        \/ DeliverRecovery
        \/ UNCHANGED vars

\* `\in [_ -> _]` rather than a pointwise conjunction: Apalache reads `x \in S` in an init
\* predicate as an ASSIGNMENT, and IndInit must assign every variable. (Convention inherited
\* from ConnCodesApalache.tla via AttestIndexApalache.tla.)
TypeOK ==
  /\ handle       \in Handles
  /\ anchor       \in [Handles -> {NULL, TrueQuorum, Rogue}]
  /\ anchorOk     \in [Handles -> BOOLEAN]
  /\ genuineSeen  \in [Handles -> BOOLEAN]
  /\ lastSeen     \in {NULL, TrueQuorum, Rogue}
  /\ rec          \in [Handles -> {NULL, TrueQuorum, Rogue}]
  /\ hoff         \in [Handles -> BOOLEAN]
  /\ acceptedRec  \in [Handles -> BOOLEAN]
  /\ trusted      \in BOOLEAN
  /\ trustedRogue \in BOOLEAN
  /\ acceptedBare \in BOOLEAN
  /\ rejGenuine   \in BOOLEAN
  /\ handoffSeen  \in BOOLEAN
  /\ idemBroken   \in BOOLEAN

\* ---------------------------------------------------------------------------------------
\* THE GREENS — each proved INDUCTIVE (base + step + strengthening closure), so they hold for
\* runs of any length and any number of re-deliveries.
\* ---------------------------------------------------------------------------------------

\* §9.4 GREEN — THE PROHIBITION, AND READ THE NEXT SENTENCE BEFORE QUOTING IT. "Recovery
\* rotations cannot be accepted on the strength of arbitrary signatures." It holds. It also holds
\* VACUOUSLY under §6.3 as written, where nothing is ever accepted at all — which is why the
\* finding rows and `WitnessRecoveryAccepted` exist. A negative-reachability claim that passes is
\* not evidence until something reaches. Control: FailClosed = FALSE.
RecoveryFailClosed == ~acceptedBare

\* §9.4 GREEN, and the one with the security content. Whatever the contact ends up trusting as
\* the identity's new handle was authorized by the identity's REAL quorum — not by whoever most
\* recently pushed a quorum-publish at it. THIS IS THE ROW THAT SURVIVES THE LIFT: it is green
\* under `ConstInitRotations` too, so N1 costs AVAILABILITY and not AUTHENTICITY, and saying so
\* requires the green (O20's lesson — without the greens, a lifted restriction is only "removing
\* an assumption broke something", which is not a measurement).
AcceptedRecoveryIsQuorumSigned == ~trustedRogue

\* §6.3 GREEN under the retain reading. An acceptance is never TAKEN BACK by re-delivering the
\* same attestation — the one-directional form, because verdicts legitimately differ when the
\* first delivery precedes the anchor's arrival (the TLC module's first draft asserted the
\* symmetric form and was violated by correct behaviour).
RecoveryIdempotent == ~idemBroken

\* §9.4 GREEN. Nothing enters the trust anchor unvalidated. Green only where the seeding path
\* validates (python); finding I6/R3 is that no section says it must.
AnchorWasValidated == \A h \in Handles : anchor[h] # NULL => anchorOk[h]

\* ---------------------------------------------------------------------------------------
\* THE FINDINGS. Each asserted in a config whose constants say which document is on trial; the
\* cinit's own comment states that, per tla/Makefile's TLC_FINDING / APALACHE_FINDING headers.
\* ---------------------------------------------------------------------------------------

\* FINDING I1/R1 (ported): §6.3's seed row is the only thing that fills §9.4's anchor, and phase
\* 1 makes it unreachable, so a genuine quorum-publish arrives and the cache stays empty.
SeedFollowsArrival == \A h \in Handles : genuineSeen[h] => anchor[h] # NULL

\* FINDING I2/R2 (ported, and the carrier of N1): a genuine compromise-recovery, delivered to a
\* contact that HAS received the identity's genuine quorum-publish, is rejected.
RecoveryAttainable == ~rejGenuine

\* FINDING N1, THE MECHANISM. §4.3's routine rotation moves the handle that §9.4 will look up
\* and leaves the anchor at the handle §5.1 wrote it under. Stated over the KEY rather than over
\* the outcome, so the counterexample exhibits the cause rather than one of its effects — the
\* QuorumSignerSetApalache lesson (a general row's counterexample was not the one worth routing,
\* so the mechanism-specific row was added beside it and both are kept).
AnchorSurvivesHandoff ==
  \A h \in Handles :
    (hoff[h] /\ (h + 1 \in Handles) /\ anchor[h] # NULL) => anchor[h + 1] # NULL

\* FINDING N1, THE CONSEQUENCE, with every antecedent the objection needs. The contact holds the
\* identity's GENUINE quorum-publish for the handle it knew (section 13.1's provisioning
\* ceremony, step 4); the routine rotation of section 13.3 moved the handle; the quorum has
\* SIGNED the §4.4 recovery for the new one (section 13.2, step 9). §9.4 has nothing at the key
\* it is told to read. Two things could have kept it
\* — `handle_dual_sig_handoff` re-keying the entry, or a fresh `quorum-publish` naming the new
\* handle — and the spec requires NEITHER: §6.3 leaves the handler undefined, and §3.3 leaves
\* publication timing to the identity ("choosing WHEN to call them and what `published_handle`
\* value to use"). Green under `ConstInitHandoffRekey`, which is what makes the first of those
\* two a checked remedy rather than a suggestion.
HandoffKeepsRecoveryAvailable ==
  \A h \in Handles :
    (hoff[h] /\ (h + 1 \in Handles) /\ genuineSeen[h] /\ rec[h + 1] = TrueQuorum)
      => anchor[h + 1] # NULL

\* FINDING N2, THE MECHANISM, RETAIN SIDE. Once the contact has accepted the recovery for handle
\* h, the identity's handle is h+1; if the quorum has signed the next recovery, §9.4 will look it
\* up at h+1. Under the retain reading of `update_handle_cache_to` (rust, python) there is
\* nothing there, so compromise recovery works exactly ONCE per published handle.
SecondRecoveryHasAnchor ==
  \A h \in Handles :
    (acceptedRec[h] /\ (h + 1 \in Handles) /\ rec[h + 1] = TrueQuorum) => anchor[h + 1] # NULL

\* FINDING I6/R3 (ported): §9.4 calls the cached entry the trust anchor; nothing in §9.4 or §6.3
\* says what may become one. Same operator as the green above, different cinit.

\* FINDING I7/R4 (ported, MOVE side of N2): §5.1's floor expires at the instant of accept, so a
\* duplicate delivery of ONE attestation gets two verdicts. Same operator as
\* `RecoveryIdempotent`, different cinit — and note this now holds for UNBOUNDED replay rather
\* than for the two deliveries `MaxDeliveries` allowed.

\* ---------------------------------------------------------------------------------------
\* NON-VACUITY WITNESSES. Asserted in order to be VIOLATED. On a module whose headline finding
\* IS a vacuity, these are not a formality: without them every green above is a statement about
\* a contact that rejects everything.
\* ---------------------------------------------------------------------------------------

\* The §9.4 trust anchor is ever non-empty.
WitnessAnchorSeeded == \A h \in Handles : anchor[h] = NULL

\* A recovery is ever ACCEPTED. The row the pre-model note asked for by name.
WitnessRecoveryAccepted == ~trusted

\* The fail-closed branch is ever TAKEN — a recovery delivered before anything was cached.
WitnessFailClosedFires ==
  \A h \in Handles : ~(rec[h] # NULL /\ anchor[h] = NULL /\ ~acceptedRec[h])

\* TWO recoveries in a row are ever accepted — the witness for N2's remedy. Under
\* `ConstInitRekeyRetain` this is violated (i.e. the chain completes); it is what makes
\* "copy and keep" a MEASURED remedy rather than a proposed one.
WitnessChainedAccept == ~(acceptedRec[1] /\ acceptedRec[2])

\* ---------------------------------------------------------------------------------------
\* THE STRENGTHENINGS, and what each one is FOR. A strengthening that is never named is a
\* strengthening nobody can check (AttestIndexApalache's header), and `make apalache-closure`
\* additionally requires each to preserve ITSELF — without that, the base and step rows prove
\* preservation FROM strengthened states and nothing shows a run stays in them (D13, eighth
\* instance).
\* ---------------------------------------------------------------------------------------

\* For `AcceptedRecoveryIsQuorumSigned`: where the seeding path validates, nothing but the real
\* quorum's publish is ever at a key, so §9.4's equality test can only be satisfied by a
\* genuinely-signed recovery. Guarded by the constant because under SeedValidates = FALSE it is
\* FALSE — which is finding I6/R3, not a modelling failure.
AnchorGenuine ==
  SeedValidates => (\A h \in Handles : anchor[h] # NULL => anchor[h] = TrueQuorum)

\* For `RecoveryIdempotent`: an accepted recovery's key still holds the generation it matched,
\* so a re-delivery takes the same branch. Guarded by the constants that make it true — the drop
\* reading is exactly what breaks it (finding I7/R4).
AcceptedKeepsAnchor ==
  (~AnchorDroppedOnAccept /\ SeedValidates /\ AnchorIsCachedPublish)
    => (\A h \in Handles : acceptedRec[h] => (anchor[h] # NULL /\ rec[h] = anchor[h]))

\* For `AnchorWasValidated`: nothing enters a key without its validation flag agreeing with the
\* seeding rule in force.
AnchorFlagSound ==
  SeedValidates => (\A h \in Handles : anchor[h] # NULL => anchorOk[h])

\* For `RecoveryAttainable` and for `SeedFollowsArrival` — the two rows that are FINDINGS under
\* §6.3 as written and GREENS under the cohort's repairs. Where the seed row is reached, every
\* genuine publish has left an entry at its own key, and nothing removes one. Guarded by the
\* three constants that make it true; under any of their negations it is exactly the finding.
AnchorFollowsPublish ==
  (SeedEnabled /\ SeedValidates /\ ~AnchorDroppedOnAccept)
    => (\A h \in Handles : genuineSeen[h] => anchor[h] # NULL)

IndInitRec == TypeOK /\ AnchorGenuine /\ AcceptedKeepsAnchor /\ AnchorFlagSound
              /\ AnchorFollowsPublish
              /\ RecoveryFailClosed /\ AcceptedRecoveryIsQuorumSigned
              /\ RecoveryIdempotent /\ RecoveryAttainable /\ SeedFollowsArrival

\* THE MODEL'S OWN EVENT ORDER, needed only by the two REPAIR rows and stated separately so it
\* cannot quietly strengthen the rows above. Both facts hold by construction — a rotation is
\* signed for the CURRENT handle and then advances it, and a genuine publish names the current
\* handle — but Apalache's inductive step starts from an ARBITRARY typed state, where "the
\* handoff happened before the publish that names the handle it rotated away from" is
\* expressible and unreachable. Without them the repair rows fail for a reason that is about the
\* arbitrary start state and not about §6.3.
EventOrder ==
  /\ \A h \in Handles : hoff[h] => h < handle
  /\ \A h \in Handles : rec[h] = TrueQuorum => h < handle
  /\ \A h \in Handles : genuineSeen[h] => h <= handle

\* For the two N1 REPAIR rows: `handle_dual_sig_handoff` re-keys, so the anchor tracks the
\* handle §9.4 will look up.
IndInitHandoff == IndInitRec /\ EventOrder
                  /\ AnchorSurvivesHandoff /\ HandoffKeepsRecoveryAvailable

\* ---------------------------------------------------------------------------------------
\* CONSTANT INITS. Each says which document is on trial. Three shapes appear here and the
\* tla/Makefile TLC_FINDING header is the canonical statement of them: a control WEAKENS the
\* model; a finding weakens NOTHING (or flips a constant TOWARD the spec, or toward one
\* implementation where the spec is silent).
\* ---------------------------------------------------------------------------------------

\* GREEN SWEEP. The cohort's repairs (§6.3 as written seeds nothing — that is finding I1), with
\* python's validating admission rule, the retention reading §5.1 permits, and NO ROTATIONS —
\* which is IdentityRecovery.tla's domain exactly. This cinit is where the second engine
\* CORROBORATES rather than extends: the same claims, decided by SMT over unbounded runs.
ConstInitOK ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = FALSE /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* THE LIFT (N1). `ConstInitOK` with the handle allowed to move. Nothing is weakened: §4.3 is a
\* normative kind of the pinned spec and section 13.3 is its ceremony (cited without a sigil:
\* nothing here verifies the Examples chapter -- see docs/COVERAGE-MATRIX.md section 3e). The greens that survive this are
\* listed in APALACHE_GREEN and are half the result.
ConstInitRotations ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = TRUE  /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* N1's REPAIR, for contrast: if `handle_dual_sig_handoff` re-keyed the anchor, the mechanism
\* row would hold. No implementation does this and no sentence asks for it; the row exists so
\* the finding names a fix that is checked rather than imagined.
ConstInitHandoffRekey ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = TRUE  /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = TRUE

\* N2, READING 1 — entity-core-go. `update_handle_cache_to` MOVES the entry: copy to the new
\* handle, remove the old. Chained recovery works; duplicate delivery does not (I7/R4).
ConstInitGo ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = TRUE
  /\ RotationsEnabled = TRUE  /\ RecoveryRekeysAnchor = TRUE  /\ HandoffRekeysAnchor = FALSE

\* N2, READING 2 — entity-core-rust (explicit no-op) and entity-core-py (no branch at all). The
\* entry is retained at the old key and nothing is written at the new one. Duplicate delivery is
\* idempotent; the second recovery in a chain has no anchor.
ConstInitRustPy ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = TRUE  /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* N2's REMEDY, MEASURED. Copy to the new key AND keep the old one. Satisfies both properties the
\* two shipped readings each satisfy one of.
ConstInitRekeyRetain ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = TRUE  /\ RecoveryRekeysAnchor = TRUE  /\ HandoffRekeysAnchor = FALSE

\* FINDING I1/R1 — §6.3 AS WRITTEN. Phase 1 runs identity_verify_cert, whose step 1 rejects
\* kind="quorum-publish", so the phase-2 seed row never runs. Nothing else is weakened.
ConstInitFindingSeed ==
  /\ SeedEnabled = FALSE /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = FALSE /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* FINDING I6/R3 — entity-core-rust's admission rule, which the spec neither requires nor
\* forbids because it defines none. The finding is not against rust: there is no validation step
\* to omit, because none is written.
ConstInitFindingAnchor ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = FALSE /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = FALSE /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* NEG CONTROL — §9.4's MUST removed. A recovery is accepted with no cached quorum-publish at
\* all: "accepted on the strength of arbitrary signatures", which §9.4 names and forbids.
ConstInitBugOpen ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = FALSE
  /\ AnchorIsCachedPublish = TRUE  /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = FALSE /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE

\* NEG CONTROL with a NAMED wrong answer — §QUORUM:3.3 forbids validating against the freshest
\* set seen instead of the one cached. Python's admission gate is in force here and the wrong
\* reading defeats it anyway, by not reading the cache.
ConstInitBugFresh ==
  /\ SeedEnabled = TRUE  /\ SeedValidates = TRUE  /\ FailClosed = TRUE
  /\ AnchorIsCachedPublish = FALSE /\ AnchorDroppedOnAccept = FALSE
  /\ RotationsEnabled = FALSE /\ RecoveryRekeysAnchor = FALSE /\ HandoffRekeysAnchor = FALSE
====
