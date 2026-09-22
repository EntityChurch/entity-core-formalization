---- MODULE AuthoritySelect ----
\* §6.8 HANDLER AUTHORITY MODEL — *WHICH* AUTHORITY THE HANDLER-LEVEL CHECK RUNS AGAINST.
\* Transcribed from spec-data/v0.8.2.25/ENTITY-CORE-PROTOCOL.md §6.8 (the three-row selection
\* table), §6.3 (`check_path_permission`, `filter_listing`) and §6.7 (the execution context).
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* MODELING-PIN-OVERRIDE: v0.8.2.25
\* ══════════════════════════════════════════════════════════════════════════════════════
\* ⛔ THIS MODULE DOES NOT TRANSCRIBE THE TRACK PIN, AND THE REASON IS NOT A PREFERENCE:
\* THE RULE IT MODELS DOES NOT EXIST AT `spec-data/v0.8.2`. At the pin, §6.8 carries exactly
\* ONE direction of the selection — "Propagated caller capability is not a dispatch gate",
\* i.e. row 2 — and describes the caller-specified-path check as one "a handler performs
\* VOLUNTARILY". There is no three-row table, no `[MUST]`, no discriminator, and no converse
\* rule. Every one of those arrived after the pin:
\*
\*   0.8.2.20  the caller-specified-path check is promoted from defence-in-depth to THE
\*             enforcement, and made act-neutral (the measured harm was a `get`, not a write)
\*   0.8.2.21  the three-row table lands as a MUST; the discriminator is "who NAMED the path"
\*   0.8.2.22  THE DISCRIMINATOR IS CORRECTED to "whether the access SERVES A LIVE CALLER'S
\*             REQUEST"; derivation is explicitly named as NOT the test; row 1's converse is
\*             stated ("a handler MUST NOT substitute its own grant for the caller's
\*             capability on a path whose result reaches the caller")
\*   0.8.2.24  row 1's ceiling is pinned to the executing handler's OWN GRANT and declared
\*             never absent — EXTENSION-TREE section 8.5's `max_scope` reduction does NOT reduce it
\*
\* The override is declared in `TRACKS.toml` under `[track.core.model_pins]` and gated by
\* `make trackcheck` in BOTH directions. `make specdrift` measures this file against
\* `v0.8.2.25`; `make coverage` holds its citations OUT of core's pin coverage pair.
\*
\* ⛔ AND THE SUBJECT IS RETARGETED, NOT THE FILE. `docs/CORROBORATION.md` carries this as its
\* own subject (`authority-select`) with both of its files at `v0.8.2.25`. It is deliberately
\* NOT added to the existing `authority` subject, whose three engines are all statements about
\* §5.2 AT THE PIN: three engines over two different texts is one reading per snapshot
\* presented as agreement, which is the failure mode AGENTS.md's retarget rule names.
\* ══════════════════════════════════════════════════════════════════════════════════════
\*
\* WHY THIS MODULE EXISTS, AND WHY IT IS A TLA+ SUBJECT SPECIFICALLY. §6.8 says of its own
\* defect, verbatim: "the defect is wire-invisible, because both readings produce a
\* well-formed response and differ only in which authority was consulted." A conformance
\* vector grades a response. So the section states, in the document, that no wire probe can
\* decide it — which leaves a machine-checked model of the dispatch chain as the only
\* instrument that reaches it, and `entity-system-conformance`'s `GUIDE-CONFORMANCE` §5.2a
\* names exactly that gap (`ECP-R24`'s shape: a binding MUST that is not wire-decidable).
\*
\* And the discriminator is a MULTI-STEP STATE question rather than a property of any single
\* value, which is the other half of the argument. §6.8's own measurement: on a continuation's
\* standing leg the value arriving at `system/tree:put` was the INBOX DELIVER TOKEN
\* (`handlers:[system/inbox]`, `operations:[receive]`), four hops after the delivery that
\* minted it, because `caller_capability` propagates unchanged FOR ATTRIBUTION. Whether an
\* access serves a live caller's request is a fact about the hop, not about the capability
\* sitting in the context field — and §6.3's parameter, named only `capability` through
\* 0.8.2.20, cannot tell them apart.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* WHAT §6.8 SAYS — the three rows, verbatim in substance:
\*
\*   ROW 1  a path in service of the caller's request — one the caller NAMED (resource
\*          target, URI suffix, a `params` path), OR one the handler DERIVED within that
\*          request (a listing entry, an extract or snapshot binding, a merge expansion, a
\*          subscription payload)
\*             -> the caller's verified capability (§6.7), AND the executing handler's own
\*                grant as an additional ceiling. BOTH MUST PASS `[MUST]`
\*   ROW 2  a path the handler touches on its own behalf, serving no caller request — an
\*          autonomous write, a continuation's onward leg, a write to the handler's own
\*          managed namespace
\*             -> the executing handler's own grant, and only that `[MUST]`
\*   ROW 3  a peer-root dispatch — the peer acting as tree owner
\*             -> NO CHECK. "checking it would make the handler-level check stricter than
\*                the dispatch-level one for the same dispatch"
\*
\* "The two rules are duals and both are live." Row 2 is the confused-deputy rule. Row 1 is
\* its converse. The section is explicit that an exclusive three-row table can state only one
\* of them and that the landed model is not exclusive.
\* ══════════════════════════════════════════════════════════════════════════════════════
\*
\* MODEL SHAPE (D11 — what is and is not here). A STRUCTURAL model of authority SELECTION at
\* the handler-level check. It builds a bounded chain of up to three dispatch hops, each
\* touching one path, and asks which authority the check consults and what it decides.
\*
\* IN THE MODEL: the three rows; the discriminator and two refuted readings of it; the
\* propagated `caller_capability` and its staleness on a chain the caller did not originate;
\* row 1's ceiling and its absence; whether row 3 is checked.
\*
\* ABSTRACTED AWAY, and each of these is somebody else's instrument:
\*   - `matches_scope` / `canonicalize` / the §5.4 path matcher. Grant coverage here is an
\*     abstract five-point relation (`Covers` below), DELIBERATELY OVERLAPPING RATHER THAN
\*     NESTED so that consulting the wrong authority is observable in BOTH directions — a
\*     path the caller covers and the grant does not, and the converse. That asymmetry is the
\*     whole point of the abstraction: a nested one (grant always broader) would make the
\*     row-1 converse unfalsifiable. The matcher itself is Lean's (`docs/LEAN-SEAM.md` L5/L6).
\*   - signature verification, chain walking, attenuation arithmetic, revocation — §5.2 steps
\*     1-4, which are Tamarin's and Lean's. This module starts after them.
\*   - `handler_pattern`, the §6.3 frame. That is a DIFFERENT question about the same call —
\*     *which frame* rather than *which authority* — and it is routed as `P-6`/`D28`, open.
\*     A model that conflated them would answer neither.
\*   - the dispatch-level check (§5.2 `check_permission`). `tla/Authority.tla` is that
\*     subject, at the pin, and the two are deliberately separate modules.
\*   - EXTENSION-TREE sections 8.1/8.5 view trees and `max_scope`. Not vendored here; §6.8's
\*     0.8.2.24 clause is transcribed from the CORE text's own statement of what that section does
\*     and does not reduce, and the reduction is modeled as the `caller-only` reading rather
\*     than by transcribing an extension this repo does not hold.
\*
\* ⛔ WHAT LEGAL STATE THIS MODEL CANNOT REPRESENT (D18, and the row that says so is
\* `docs/LEAN-SEAM.md` O25). A hop's origin is chosen FREELY rather than inherited from the
\* hop that spawned it, so the model admits a caller-serving hop beneath an autonomous one,
\* which no implementation can produce. That is a WIDENING, taken on purpose: every property
\* here is per-hop, so the extra states cost nothing and cannot manufacture a counterexample
\* — each one the checker returns is a single hop, realizable at the first slot under any
\* origin. What the widening DOES cost is a claim the model cannot make: it says nothing
\* about whether a chain's origins are consistent along it, which is where a real
\* implementation's context-propagation bug would live.
EXTENDS Naturals, FiniteSets

CONSTANTS
  AuthoritySource,   \* WHERE the check's `authority` argument comes from.
                     \* "selected"   = §6.8: selected per hop by the three-row rule. CORRECT.
                     \* "propagated" = neg control: `authority := ctx.caller_capability`,
                     \*                always. §6.3: "The parameter was called `capability`
                     \*                through 0.8.2.20 and TWO SEATS FILLED IT FROM the
                     \*                propagated caller_capability, which is ATTRIBUTION and
                     \*                can be a token four hops old with unrelated scopes."
                     \* "grant"      = neg control: `authority := ctx.handler_grant`, always.
                     \*                §6.8 0.8.2.22: "Flattening the intersection made a
                     \*                handler grant — broad by construction — the authority
                     \*                for listing entries and merge expansions, which makes
                     \*                the listing filter vacuous."
  Discriminator,     \* WHICH TEST decides row 1 vs row 2.
                     \* "serves"     = §6.8 at 0.8.2.22: whether the access SERVES A LIVE
                     \*                CALLER'S REQUEST. CORRECT.
                     \* "derivation" = neg control: the 0.8.2.21 wording, "by who NAMED the
                     \*                path". 0.8.2.22 names this as one of the things the
                     \*                rule is NOT: "Derivation is not the discriminator. A
                     \*                path the handler derived is still the caller's access
                     \*                when its existence, its content, or its effect reaches
                     \*                the caller."
                     \* "initiator"  = neg control: "who initiated the chain", which §6.8
                     \*                also names explicitly as NOT the test. This is what an
                     \*                implementation keyed on DYNAMIC EXTENT computes (a
                     \*                thread-local current-caller): it gets the
                     \*                caller-directed case right and misses every standing
                     \*                one. §3.1's authority-provenance rule makes the same
                     \*                point one layer down.
  Row1Authorities,   \* HOW MANY authorities row 1 actually consults.
                     \* "both"        = §6.8 row 1 at 0.8.2.24: the caller's verified
                     \*                 capability AND the executing handler's own grant,
                     \*                 BOTH MUST PASS, and the ceiling "is never absent".
                     \*                 CORRECT.
                     \* "caller-only" = ⭐ NOT A CONTROL — A FINDING ROW. This is the shape
                     \*                 §6.3's OWN SIGNATURE forces: `check_path_permission`
                     \*                 takes ONE `authority` argument, `filter_listing`
                     \*                 passes ONE and calls the check ONCE, and the
                     \*                 EXTENSION-SUBSCRIPTION section 2.3 call §6.3 quotes
                     \*                 APPROVINGLY passes `caller_capability` and nothing
                     \*                 else. See the finding block below.
                     \* "grant-only"  = neg control: the same single call with the handler's
                     \*                 grant — the flattened reading 0.8.2.22 fixed.
  PeerRootChecked    \* FALSE = §6.8 row 3: a peer-root dispatch gets NO CHECK. CORRECT.
                     \* TRUE  = neg control: the handler-level check is applied to the peer
                     \*         acting as tree owner, which §6.8 says would "make the
                     \*         handler-level check stricter than the dispatch-level one for
                     \*         the same dispatch".

\* ══════════════════════════════════════════════════════════════════════════════════════
\* ⭐ THE FINDING THIS MODULE EXISTS TO MEASURE — ROW 1'S CONJUNCTION HAS NO EXPRESSION IN
\* THE ALGORITHM THAT MUST SATISFY IT.
\*
\* §6.8 row 1 is a `[MUST]` over TWO authorities: "the caller's verified capability (§6.7) —
\* AND the executing handler's own grant as an additional ceiling. Both MUST pass `[MUST]`",
\* strengthened at 0.8.2.24 to "never absent".
\*
\* The check that carries it out is §6.3's:
\*
\*     check_path_permission(operation, path, authority, handler_pattern, local_peer_id)
\*
\* ONE `authority`. It walks `authority.data.grants` and returns ALLOW on the first grant
\* entry matching all three dimensions. A single call cannot express a conjunction over two
\* capabilities, and nothing in §6.3 or §6.8 says to call it twice.
\*
\* Nor is that hypothetical. §6.3's two worked call sites each pass one authority:
\*   - `filter_listing(listing, operation, prefix, authority, handler_pattern, local_peer_id)`
\*     — the LISTING FILTER, whose own prose one paragraph above says "The authority is §6.8
\*     ROW 1 — the caller's verified capability, with the executing handler's grant as a
\*     ceiling; BOTH MUST PASS" — calls `check_path_permission` ONCE, with ONE `authority`.
\*   - EXTENSION-SUBSCRIPTION section 2.3, quoted in §6.3 as already stating the rule "in the
\*     imperative", passes `caller_capability` and no ceiling.
\*
\* So the constant `Row1Authorities = "caller-only"` is not a weakening of the model. It is
\* the spec's own algorithm, and it FLIPS TOWARD THE SPEC while failing the spec's MUST —
\* the second shape in `tla/Makefile:TLC_FINDING`'s header, the one the quorum track earned.
\*
\* This is D17's first shape (an obligation whose enforcing operation cannot enforce it) and
\* it is `P-6`'s twin one rule over: P-6 found §5.5a's granter-frame MUST in no pseudocode in
\* the document; this is §6.8's ceiling MUST unreachable from inside the pseudocode that must
\* satisfy it. Same call, same document, three parameters apart.
\*
\* ⛔ AND THE TWO DEFECTS COMPOSE, WHICH IS THE PART NEITHER IS VISIBLE FROM.
\* With the ceiling PRESENT, getting the discriminator wrong is FAIL-CLOSED: row 1 requires
\* strictly more than row 2, so misclassifying a row-2 access into row 1 can only DENY
\* something that should have been allowed. `MisclassificationCostsAvailabilityOnly` is that
\* claim and it is GREEN. With the ceiling ABSENT — the single-authority shape — the same
\* misreading becomes an ESCALATION: the caller's capability alone authorizes a write the
\* handler's grant does not cover, which is the confused deputy §6.8 forbids by name.
\* `AuthoritySelectDeputy` is that row. NEITHER constant alone produces it.
\* ══════════════════════════════════════════════════════════════════════════════════════

\* Three dispatch hops: hop 1 originates, hops 2 and 3 are in-process sub-dispatches of an
\* already-allowed hop. Bounded and small — every rule under test is a per-hop structural
\* property, so depth 3 exercises origin, sub-of-origin and sub-of-sub.
H == 1..3

\* The hop's ORIGIN — where its authority context came from. This is the state the §6.8
\* discriminator is a question about, and collapsing it into a capability is the defect.
\*   "caller"     — this hop serves a LIVE external caller's request. `ctx.caller_capability`
\*                  is that caller's verified capability.
\*   "standing"   — inside a chain a live caller DID originate, but this hop serves no live
\*                  caller's request: a continuation's onward leg, an autonomous write made
\*                  along the way. `ctx.caller_capability` still holds the originating
\*                  caller's capability, unchanged, FOR ATTRIBUTION (§6.8 context
\*                  propagation). This is the classic confused-deputy hop.
\*   "autonomous" — a chain no external caller originated: a subscription delivery, a timer,
\*                  a standing continuation firing on a fresh trigger (§3.11 roots it at 0).
\*                  `ctx.caller_capability` holds whatever token ARMED it — §6.8's measured
\*                  case, the inbox deliver token with `handlers:[system/inbox]`.
\*   "peerroot"   — the peer acting as tree owner, outside the dispatch chain (§6.8
\*                  "Peer-level writes"). Row 3.
Origins == {"unused", "caller", "standing", "autonomous", "peerroot"}

\* The PROVENANCE of the path this hop is about to touch — §6.8 row 1's two halves and row 2.
\*   "named"   — the caller named it: resource target, URI suffix, a `params` path
\*   "derived" — the handler derived it WITHIN the caller's request: a listing entry, an
\*               extract or snapshot binding, a merge expansion, a subscription payload
\*   "own"     — the handler's own managed namespace / an autonomous write
Provs == {"none", "named", "derived", "own"}

\* Abstract path coverage. Five points, chosen so the two authorities OVERLAP WITHOUT EITHER
\* CONTAINING THE OTHER — that is what makes both directions of §6.8's dual observable.
\*   "pc" — the caller's capability covers it; the handler's grant does NOT
\*   "pg" — the handler's grant covers it; the caller's capability does NOT
\*   "pb" — both cover it
\*   "ps" — only the STALE propagated token covers it (the deliver token's own namespace)
\*   "pn" — nothing covers it
Paths == {"pc", "pg", "pb", "ps", "pn"}

\* @type: (Str, Str) => Bool;
Covers(a, p) ==
  CASE a = "caller" -> p \in {"pc", "pb"}
    [] a = "grant"  -> p \in {"pg", "pb"}
    [] a = "stale"  -> p = "ps"
    [] OTHER        -> FALSE

VARIABLES
  origin,   \* H -> Origins    where this hop's authority context came from
  prov,     \* H -> Provs      how the path this hop touches arose
  path,     \* H -> Paths      the path itself (drawn from effective_targets, §5.2)
  outcome   \* H -> {"pending","allow","deny"}   the check_path_permission verdict

vars == << origin, prov, path, outcome >>

Live(h)  == origin[h] = "caller"                              \* a live caller's request
Ext(h)   == origin[h] \in {"caller", "standing"}              \* externally initiated chain

\* The value sitting in `ctx.caller_capability` at this hop. §6.8: propagated UNCHANGED
\* through the chain, for attribution. On a chain the caller originated it is that caller's
\* capability; on one a delivery originated it is the arming token, which §6.8 measured
\* arriving at `system/tree:put` four hops later.
PropAt(h) == IF Ext(h) THEN "caller" ELSE "stale"

\* ---- §6.8's discriminator, and the two readings the section names as NOT the test ----
Row1Under(disc, h) ==
  CASE disc = "serves"     -> Live(h) /\ prov[h] \in {"named", "derived"}
    [] disc = "derivation" -> prov[h] = "named"
    [] OTHER               -> Ext(h)

\* ---- WHICH AUTHORITIES the handler-level check consults for this hop ----
\* An empty set means the check does not run at all (row 3). Otherwise EVERY member must
\* cover the path — that is what "both MUST pass" means, and what a one-argument call
\* cannot say.
AuthSetUnder(src, disc, r1, h) ==
  IF origin[h] = "peerroot" /\ ~PeerRootChecked
    THEN {}
    ELSE CASE src = "propagated" -> {PropAt(h)}
           [] src = "grant"      -> {"grant"}
           [] OTHER ->
                IF Row1Under(disc, h)
                  THEN (CASE r1 = "both"        -> {"caller", "grant"}
                          [] r1 = "caller-only" -> {"caller"}
                          [] OTHER              -> {"grant"})
                  ELSE {"grant"}

DecideUnder(src, disc, r1, h) ==
  IF \A a \in AuthSetUnder(src, disc, r1, h) : Covers(a, path[h])
    THEN "allow" ELSE "deny"

AuthSet(h) == AuthSetUnder(AuthoritySource, Discriminator, Row1Authorities, h)
Decide(h)  == DecideUnder(AuthoritySource, Discriminator, Row1Authorities, h)

\* The three readings named side by side, so the witnesses below can compare them without
\* re-running the model under different constants. §6.8's wire-invisibility claim is about
\* two readings of ONE run, which is why these are operators and not cfgs.
SpecVerdict(h) == DecideUnder("selected",   "serves",     "both", h)
SpecAuths(h)   == AuthSetUnder("selected",  "serves",     "both", h)
V21Verdict(h)  == DecideUnder("selected",   "derivation", "both", h)
PropVerdict(h) == DecideUnder("propagated", "serves",     "both", h)
PropAuths(h)   == AuthSetUnder("propagated","serves",     "both", h)

\* ===== transitions =====
Init ==
  /\ origin  = [h \in H |-> "unused"]
  /\ prov    = [h \in H |-> "none"]
  /\ path    = [h \in H |-> "pn"]
  /\ outcome = [h \in H |-> "pending"]

\* The chain starts: an external EXECUTE, a delivery, a continuation advance, or the peer
\* acting as tree owner. The hop touches one path, of some provenance.
Originate ==
  /\ origin[1] = "unused"
  /\ \E o \in Origins \ {"unused"} : \E v \in Provs \ {"none"} : \E p \in Paths :
       /\ origin' = [origin EXCEPT ![1] = o]
       /\ prov'   = [prov   EXCEPT ![1] = v]
       /\ path'   = [path   EXCEPT ![1] = p]
  /\ UNCHANGED outcome

\* An allowed hop dispatches a sub-request. The child's origin is chosen freely — see the
\* D18 note in the header for what that widening does and does not buy.
Spawn(h) ==
  /\ origin[h] = "unused"
  /\ \E q \in H :
       /\ q < h
       /\ outcome[q] = "allow"
       /\ \E o \in Origins \ {"unused"} : \E v \in Provs \ {"none"} : \E p \in Paths :
            /\ origin' = [origin EXCEPT ![h] = o]
            /\ prov'   = [prov   EXCEPT ![h] = v]
            /\ path'   = [path   EXCEPT ![h] = p]
  /\ UNCHANGED outcome

\* Run the handler-level check on a hop that has arrived but not yet been decided.
Check(h) ==
  /\ origin[h] # "unused"
  /\ outcome[h] = "pending"
  /\ outcome' = [outcome EXCEPT ![h] = Decide(h)]
  /\ UNCHANGED << origin, prov, path >>

Next ==
  \/ Originate
  \/ \E h \in H : (Spawn(h) \/ Check(h))
  \/ UNCHANGED vars      \* stuttering: the chain may stop growing at any length

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

\* Does this hop's access serve a live caller's request? §6.8's discriminator, as corrected
\* at 0.8.2.22. Every property below is stated against THIS, never against the constant —
\* a property that quantified over `Discriminator` would be true of whichever reading the
\* run happened to use, which is no property at all.
Serves(h) == Live(h) /\ prov[h] \in {"named", "derived"}

\* The hops §6.8 requires a handler-level check for: everything that has arrived except a
\* peer-root dispatch, which is row 3's "no check". NOT "the hops this model checked" —
\* under the `PeerRootChecked` control the model checks one of these anyway, and
\* `PeerRootNeverDenied` is the property that catches it.
InScope(h) == origin[h] # "unused" /\ origin[h] # "peerroot"

\* SAFETY — §6.8 ROW 2, the confused-deputy rule. "A handler MUST NOT substitute the
\* propagated caller capability for its own grant on a path it touches on its own behalf."
\* This is the ONLY direction that exists at the core pin, and it is the SECURITY half.
\* Violated by AuthoritySource = "propagated" — both through a live caller's (broader)
\* capability on a standing leg, and through a delivery token on an autonomous one.
NoDeputySubstitution ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ ~Serves(h))
                 => Covers("grant", path[h])

\* SAFETY — §6.8 ROW 1'S CONVERSE, new at 0.8.2.22 and the half an exclusive table cannot
\* state. "A handler MUST NOT substitute its own grant for the caller's capability on a path
\* whose result reaches the caller." Violated by AuthoritySource = "grant" (the flattened
\* reading, which makes the listing filter vacuous) and by Discriminator = "derivation" (the
\* superseded 0.8.2.21 reading, on exactly the derived paths 0.8.2.22 enumerates).
CallerFacingNeedsCaller ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ Serves(h))
                 => Covers("caller", path[h])

\* SAFETY — §6.8 ROW 1'S CEILING, pinned at 0.8.2.24: the executing handler's own grant,
\* "and it is never absent". The literal transcription of the clause. Violated by
\* Row1Authorities = "caller-only", which is §6.3's own single-`authority` call shape.
Row1CeilingHolds ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ Serves(h))
                 => Covers("grant", path[h])

\* SAFETY — THE DERIVED FORM, and the one worth having. Rows 1 and 2 both require the
\* executing handler's own grant, so under §6.8 as written the handler's grant is a ceiling
\* on EVERY authorized access, whichever row applies. That is what makes the next property
\* true, and it is what the single-authority call shape removes.
HandlerGrantIsAlwaysCeiling ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h)) => Covers("grant", path[h])

\* SAFETY — ⭐ WHY THE CEILING IS LOAD-BEARING FOR THE DISCRIMINATOR. Because row 1 demands
\* strictly MORE than row 2, misclassifying an own-behalf access into row 1 can only refuse
\* something; it can never authorize one. So a peer that reads §6.8's discriminator wrongly
\* — the failure the section itself corrected at 0.8.2.22, and the one an implementation
\* keyed on dynamic extent makes — pays in AVAILABILITY and not in AUTHORITY. Stated as: an
\* allowed access is covered by the grant no matter which reading selected the row.
\*
\* READ THE QUANTIFIER, BECAUSE IT IS WHAT THIS PROPERTY ASSERTS AND `HandlerGrantIsAlways-
\* Ceiling` DOES NOT. That one is about `outcome` — the verdict this run recorded under this
\* run's constants. This one is about the RULE: it ranges over ALL THREE discriminator
\* readings at once, so its green says no reading of the discriminator, right or refuted, can
\* authorize an access the executing handler's grant does not cover. The two are therefore
\* broken by the same constant (`Row1Authorities`) and by nothing else — the discriminator
\* cannot break either. That is precisely the composition claim, in one formula: the ceiling
\* is what makes the discriminator's errors one-directional, and `AuthoritySelectDeputy` is
\* the row where removing it turns the same misreading into an escalation.
MisclassificationCostsAvailabilityOnly ==
  \A h \in H :
    \A d \in {"serves", "derivation", "initiator"} :
      (DecideUnder("selected", d, Row1Authorities, h) = "allow" /\ InScope(h))
        => Covers("grant", path[h])

\* SAFETY — §6.3: "`authority` is NOT 'the capability on the request' (0.8.2.21)", and §6.8:
\* the propagated `caller_capability` exists for exactly two purposes, neither of which is
\* being the check's authority. Under a correct selection the stale arming token is never
\* consulted at all; this states that structurally rather than through its consequences.
\* Violated by AuthoritySource = "propagated" on any chain no live caller originated.
NoStaleTokenAuthority ==
  \A h \in H : (origin[h] # "unused") => ("stale" \notin AuthSet(h))

\* SAFETY — THE AVAILABILITY HALF, and the reason "propagated" is not merely insecure.
\* An own-behalf access the executing handler's own grant covers is exactly what row 2
\* authorizes, and it MUST NOT be refused. Violated by AuthoritySource = "propagated" (the
\* arming token does not cover the handler's own namespace) and by Discriminator =
\* "initiator" (the access is misfiled into row 1 and the caller's capability does not cover
\* the handler's namespace).
\*
\* Together with NoDeputySubstitution this is the theorem, and it is `tla/Authority.tla`'s
\* shape one section over: the two properties are jointly satisfiable ONLY by a reading that
\* SELECTS per hop. Neither fixed source holds both.
OwnBehalfNotSpuriouslyDenied ==
  \A h \in H : (origin[h] # "unused" /\ InScope(h) /\ ~Serves(h) /\ Covers("grant", path[h]))
                 => outcome[h] # "deny"

\* SAFETY — §6.8 ROW 3. A peer-root dispatch is the peer acting as tree owner and gets no
\* handler-level check; §6.8 says applying one "would make the handler-level check stricter
\* than the dispatch-level one for the same dispatch". Violated by PeerRootChecked = TRUE.
PeerRootNeverDenied ==
  \A h \in H : (origin[h] = "peerroot") => outcome[h] # "deny"

\* ===== NON-VACUITY WITNESSES (PROPERTIES.md §C.4) — each MUST be VIOLATED =====

\* The derived-path case is reachable and authorized. Without this the row-1 converse above
\* is true of a model in which no handler ever derives a path, which is the half of §6.8 the
\* 0.8.2.22 correction is entirely about.
WitnessDerivedAllowed ==
  ~(\E h \in H : prov[h] = "derived" /\ Serves(h) /\ outcome[h] = "allow")

\* A standing leg is reached and decided — a hop inside a caller-originated chain that
\* serves no live caller. This is the state §6.8's own measurement is about, and if it were
\* unreachable every row-2 result here would be vacuous.
WitnessStandingLeg ==
  ~(\E h \in H : origin[h] = "standing" /\ outcome[h] # "pending")

\* ⭐ THE WIRE-INVISIBILITY WITNESS, AND IT IS THE MEASUREMENT `ECP-R24`'s SHAPE ASKS FOR.
\* §6.8: "the defect is wire-invisible, because both readings produce a well-formed response
\* and differ only in which authority was consulted." Its violation exhibits a hop where the
\* CORRECT reading and the propagated-field reading BOTH ALLOW — same verdict, same
\* response, nothing for an oracle to grade — while consulting DIFFERENT authorities. That
\* is the sentence, machine-checked, and it is why a conformance vector cannot close this.
WitnessSilentSubstitution ==
  ~(\E h \in H :
      /\ origin[h] # "unused"
      /\ SpecVerdict(h) = "allow"
      /\ PropVerdict(h) = "allow"
      /\ SpecAuths(h) # PropAuths(h))

\* The 0.8.2.21 -> 0.8.2.22 discriminator correction was SEMANTIC, not editorial: there is a
\* reachable access on which the two readings return different verdicts. Worth asserting
\* because this repo's own §Next worklist carried the superseded wording for weeks, and a
\* model transcribed from it would have gone green on the refuted rule (D12).
WitnessReadingsDiverge ==
  ~(\E h \in H : origin[h] # "unused" /\ SpecVerdict(h) # V21Verdict(h))
====
