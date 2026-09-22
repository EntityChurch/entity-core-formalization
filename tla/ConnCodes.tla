---- MODULE ConnCodes ----
\* §4.7 Connection Error Codes + §4.11 Pre-admission refusals — the MUST-emit reason-code
\* contract. Originally added at 0.8.2's second gate audit because §4.7 was listed in
\* COVERAGE-MATRIX.md as "Apalache-only" coverage when in fact NOTHING modeled it: the only
\* §4.7 mention in the whole repo was the far end of a SECTION RANGE in a comment in
\* ConnApalache.tla, written with a sigil on both ends, which the citation-derived coverage
\* grid counted as a claim. See COVERAGE-MATRIX.md section 3a-b.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* MODELING-PIN-OVERRIDE: v0.8.2.25
\* ══════════════════════════════════════════════════════════════════════════════════════
\* ⛔ THIS MODULE DOES NOT TRANSCRIBE THE TRACK PIN. `spec-data/MODELING-PIN` names `v0.8.2`
\* and every other core model here is a statement about it. This one is a statement about
\* `spec-data/v0.8.2.25/ENTITY-CORE-PROTOCOL.md` and nothing else, because §4.11 DOES NOT
\* EXIST at the pin and §4.7's out-of-order row carries a different status there.
\*
\* The override is declared in `TRACKS.toml` under `[track.core.model_pins]` and gated by
\* `make trackcheck` in BOTH directions: a row with no marker in this file fails, and this
\* marker with no row fails. `make specdrift` measures this file against `v0.8.2.25`, and
\* `make coverage` holds its citations OUT of core's pin coverage pair — so retargeting this
\* module REMOVED §4.7 and §5.2a from the published `N of M`, because after it nothing
\* verifies those sections as the PIN states them. That drop is the honest reading and it is
\* the reason the override is a registry fact rather than a paragraph here: a header sentence
\* would have left the coverage number untouched and the claim false. docs/DISCIPLINE-CHARTER.md D15's
\* eleventh shape — a disclaimer is not a gate.
\* ══════════════════════════════════════════════════════════════════════════════════════
\*
\* WHAT §4.7 SAYS. The table is "a normative MUST-emit contract: clients key error handling
\* off `result.data.code`, so the code and status for each failure are fixed across
\* implementations (an impl that collapses several of these to one code, or returns a
\* different status, is non-conformant)." So there are exactly two ways to be wrong, and
\* §4.7 names both — which is why this module carries exactly two ordinary negative controls
\* for that contract.
\*
\* This is the same theorem shape as Bounds.tla's ReasonCodesDistinct (§4.10(b) Ruling 3:
\* the capability-chain brake and the continuation brake MUST NOT share a reason string).
\* §4.7 generalizes it across the whole connect handshake.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* THE FINDING IS CLOSED — ADOPTED UPSTREAM, AND RETARGETING IS HOW IT GETS BANKED
\* ══════════════════════════════════════════════════════════════════════════════════════
\* At the pin, §4.7's table gave TWO different normative answers for one input — an
\* `authenticate` arriving before any hello nonce was issued. Row 6 said `invalid_nonce` 401
\* (citing §4.6 step 1); row 10's parenthetical said `connection_sequence_error` 400. Both
\* MUSTs, same table, disagreeing on the code AND the status class. This repo routed it
\* (docs/PROPERTIES.md §D.1) arguing that row 10's PARENTHETICAL alone was the defect —
\* narrowing four words, not reconciling two sections.
\*
\* ⭐ `0.8.2.1` (FM-1) ADOPTED EXACTLY THAT, and at `.25` the row reads:
\*     "Out-of-order operation — a connect operation the responder implements, arriving in a
\*      state that forbids it (e.g. a second `hello` after `hello_done`). **Not** a pre-hello
\*      `authenticate` (see below)"
\* with a following paragraph pinning the pre-hello case to 401 `invalid_nonce` by §4.2, §4.6
\* step 1 and row 6, and naming the replayed-`authenticate` case as the reason.
\*
\* ⇒ SO THE CONTESTED CELL COLLAPSES. There is no `PreHelloAuthRow` constant any more, and
\* `ConnCodesSeqReadingBug.cfg` DEMOTES: at the pin its "defect" was a conformant reading of
\* the spec and that was the whole point; at `.25` it is an ordinary injected defect, because
\* the text now forbids it in the row itself. The cfg header says so. **Banking an adopted
\* argument as a plain negative control is the deliverable** — a finding row that goes green
\* is retired, not repaired (tla/Makefile TLC_FINDING's retirement condition), and this one
\* retires by the spec moving to where we argued it should be.
\*
\* WHAT ELSE MOVED IN §4.7, and all of it is modeled here (the pin's version of this module
\* modeled three rows; this models five):
\*   - `connection_sequence_error` is **409**, not 400 (0.8.2.4). A state conflict is 409;
\*     the row is "the same class as `connection_already_established` directly above it".
\*   - A NEW row splits out of the old one: an operation name the responder does not
\*     implement, in any state, is **`invalid_request` 400** — "not out of order at all; it
\*     exists in no state, so reporting `connection_sequence_error` points the caller at its
\*     ordering when the defect is its operation name."
\*   - The HALF-OPEN state is named (0.8.2.8): a connection past `hello` but before
\*     `authenticate` is not established, and a connect operation arriving on it is the
\*     out-of-order row — **409**. §4.7 says all three ground-up implementations already
\*     answer 409 "by construction" and the row exists so the behaviour is pinned by text
\*     rather than by three independent derivations.
\*   - ADDRESS IS EVALUATED BEFORE AUTHENTICATION (0.8.2.6). A pre-establishment EXECUTE
\*     naming a FOREIGN namespace is `invalid_request` 400 at every phase; one naming the
\*     peer's own namespace is `authentication_failed` 401. The spec's argument is that a
\*     401 "names a remedy that does not exist" for a foreign address, so the answer must not
\*     depend on authentication state — which is a phase-INDEPENDENCE claim and therefore
\*     something a phase machine can actually check. `AddressVerdictPhaseIndependent`.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* §4.11 — PRE-ADMISSION REFUSALS (new section at 0.8.2.25)
\* ══════════════════════════════════════════════════════════════════════════════════════
\* §4.11 states one invariant over a class §4.9(c) cannot reach (its deliver-or-signal rule
\* is scoped to "every request the peer admits"):
\*
\*   "A peer that refuses a frame pre-admission MUST put a coded EXECUTE_RESPONSE on the
\*    wire [MUST] — correlated by `request_id` where the id is available, and otherwise as a
\*    best-effort coded frame carrying no correlation. Whether the peer closes the connection
\*    afterwards is its own choice."
\*
\* TWO NON-CONFORMANCES, DISTINCT (this is the part a single boolean would lose):
\*   - DROPPING the frame — no response and no close. Unobservable to every instrument.
\*   - CLOSING with no coded frame — "indistinguishable from a network fault", and the two
\*     remedies are opposite.
\* Hence `RefusalMode` has THREE values rather than a `Conformant` boolean, and two separate
\* controls. A model that could not tell a drop from a bare close would satisfy §4.11's own
\* sentence that they "are distinct failures rather than one".
\*
\* AND THE CODE BELONGS TO THE CAUSE [MUST], not to the class — five rows, transcribed.
\* Note that TWO of them share a code (`invalid_request` for the framing arm and for a
\* non-EXECUTE root), which is why the distinctness property here is stated over CAUSES that
\* the table separates rather than as "all causes have different codes": §4.11 assigns those
\* two the same code deliberately, and an invariant saying otherwise would be a claim about a
\* table this section does not have.
\*
\* ⛔ WHAT IS NOT MODELED HERE, AND IT IS THE INTERESTING ARM. §4.11's conformance paragraph
\* names arm (f): "a pre-admission refusal arriving while an admitted request is in flight on
\* the same connection MUST NOT cost that request its response." That quantifies over
\* INTERLEAVINGS on a multiplexed connection and this module has no concurrency, no second
\* request and no connection multiplexing — it is a phase machine. It is `tla/Reentry.tla`'s
\* subject and it is booked as docs/LEAN-SEAM.md **O24**. Stating it here rather than leaving
\* the reader to infer coverage from a §4.11 citation: this module checks the TABLE and the
\* EMISSION obligation, and says nothing whatever about the multiplexed arm.
\*
\* MODEL SHAPE (D11 — what is and is not here). A structural model of the responder's
\* connect-handshake reject paths, in the same abstraction ConnApalache.tla uses: no FIFO
\* inbox, no interleaving, no time. At any point the (possibly adversarial) initiator may
\* send a hello, an authenticate, an unknown connect operation or a non-connect EXECUTE, and
\* the responder reacts per phase. ABSTRACTED AWAY: §4.6 steps 0/2/3 (key-type support,
\* proof-of-possession, identity binding) and their codes `unsupported_key_type` /
\* `authentication_failed` / `identity_mismatch` as HANDSHAKE STEPS — those are the §7.3
\* crypto wall and Tamarin's (tamarin/Binding.*). (`authentication_failed` DOES appear below,
\* but only as the address table's own-namespace verdict, which is a routing answer and not a
\* signature check.) §4.7's four version/key-type negotiation codes are likewise out: they
\* are settled before any phase this model has, and naming their own sections here would mint
\* a citation for a section this model makes no claim about (COVERAGE-MATRIX.md section 3b).
\* §4.11's `payload_too_large` and `hash_mismatch` rows ARE in the cause table — they are
\* rows of a table this module transcribes — but nothing here models size accounting or
\* entity resolution, and in particular the `hash_mismatch` row is the obligation whose
\* absence of an enforcing operation at the pin produced the 0.8.2.23 forgery
\* (docs/LEAN-SEAM.md O23). Transcribing its ROW is not modelling its ENFORCEMENT.
\*
\* HONESTY (PROPERTIES.md §C). The distinctness and status properties are assertions over the
\* code assignment, which is a function of the constants — so their content is (a) that each
\* row is REACHABLE at all, which is what ConnCodesWitness.cfg establishes, and (b) that the
\* assignment can be broken, which is what the controls establish. This is the same shape,
\* and the same honest limit, as Bounds.tla's reason-code result.
EXTENDS Naturals, FiniteSets

CONSTANTS
  CollapseCodes,   \* FALSE = §4.7: each failure row has its own code. CORRECT.
                   \* TRUE  = neg control, named by §4.7 itself: "an impl that collapses
                   \*         several of these to one code ... is non-conformant".
  WrongStatus,     \* FALSE = §4.7: the status for each code is fixed. CORRECT.
                   \* TRUE  = neg control, the other half of §4.7's sentence: "or returns a
                   \*         different status".
  SeqReadingBug,   \* FALSE = §4.7 at .25: a pre-hello `authenticate` is row 6, 401
                   \*         `invalid_nonce`. CORRECT.
                   \* TRUE  = neg control: route it to the out-of-order row instead. At the
                   \*         v0.8.2 pin this was a CONFORMANT READING and the finding; at
                   \*         .25 the row itself says "**Not** a pre-hello `authenticate`",
                   \*         so it is now an ordinary injected defect. See the header.
  AuthBeforeAddress, \* FALSE = §4.7 (0.8.2.6): the address answers first, at every phase.
                   \*         CORRECT.
                   \* TRUE  = neg control: consult authentication state first, so a foreign
                   \*         namespace gets 401 before establishment. The spec's own words
                   \*         for why this is wrong: the 401 "names a remedy that does not
                   \*         exist" at any authentication state.
  RefusalMode,     \* §4.11. "coded" = MUST-emit satisfied. CORRECT.
                   \* "drop"       = neg control, §4.11's first named non-conformance.
                   \* "bare_close" = neg control, §4.11's second. DISTINCT from "drop".
  EcfOnFraming     \* FALSE = §4.11: the framing arm is `invalid_request`. CORRECT.
                   \* TRUE  = neg control: emit `non_canonical_ecf`, which §4.11 rules
                   \*         NOT CONFORMANT on this arm — ENTITY-CBOR-ENCODING §5.4 defines
                   \*         that code for CBOR tag-policy violations, and "your bytes are
                   \*         truncated" is not "re-encode without the tag".

\* ───────────────────────── §4.7: the connect-handshake table ─────────────────────────
\* Row ids are by CONTENT, not by position: §4.7's row order changed at 0.8.2.4 when the
\* out-of-order row split in two, and positional ids would have silently re-pointed.
Rows == {"r_nonce", "r_already", "r_seq", "r_unknown_op", "r_addr_foreign", "r_addr_own"}

\* The responder's reject triggers — distinct FAILURES, which §4.7 maps onto rows.
Triggers == {"second_hello", "hello_on_established", "bad_nonce",
             "prehello_auth", "auth_on_established",
             "op_on_halfopen",      \* 0.8.2.8 — the half-open state, named explicitly
             "unknown_connect_op",  \* 0.8.2.4 — an operation that exists in no state
             "foreign_ns_execute",  \* 0.8.2.6 — the address table
             "own_ns_execute"}

Phases == {"new", "hello_done", "established"}

\* §4.11 pre-admission causes, transcribed from its cause -> code table.
Causes == {"connect_auth", "oversize", "hash_mismatch", "framing", "bad_root"}

VARIABLES
  phase,    \* §4.1 per-connection phase
  emitted,  \* subset of Triggers: which §4.7 reject paths have actually fired
  refused   \* subset of Causes: which §4.11 pre-admission refusals have actually fired

vars == << phase, emitted, refused >>

\* ---- §4.7: trigger -> table row ----
RowOf(tr) ==
  CASE tr = "second_hello"         -> "r_seq"
    [] tr = "hello_on_established" -> "r_already"
    [] tr = "bad_nonce"            -> "r_nonce"
    [] tr = "auth_on_established"  -> "r_already"
    [] tr = "op_on_halfopen"       -> "r_seq"
    [] tr = "unknown_connect_op"   -> "r_unknown_op"
    [] tr = "foreign_ns_execute"   -> IF AuthBeforeAddress THEN "r_addr_own"
                                      ELSE "r_addr_foreign"
    [] tr = "own_ns_execute"       -> "r_addr_own"
    [] OTHER                       -> IF SeqReadingBug THEN "r_seq" ELSE "r_nonce"

\* ---- §4.7: row -> code, AS THE TABLE FIXES IT ----
\* Constant-free by construction: this is the spec's assignment and it is what an emitted
\* code is checked AGAINST. Keeping it separate from what the responder emits is what stops
\* `ReasonCodesDistinct` below from being a tautology — see the note there.
NormativeCodeOfRow(r) ==
  CASE r = "r_nonce"        -> "invalid_nonce"
    [] r = "r_already"      -> "connection_already_established"
    [] r = "r_unknown_op"   -> "invalid_request"
    [] r = "r_addr_foreign" -> "invalid_request"
    [] r = "r_addr_own"     -> "authentication_failed"
    [] OTHER                -> "connection_sequence_error"

\* ---- what the responder actually emits ----
\* CollapseCodes is the non-conformance §4.7 names in its own preamble.
CodeOfRow(r) ==
  IF CollapseCodes THEN "connection_sequence_error" ELSE NormativeCodeOfRow(r)

CodeOf(tr) == CodeOfRow(RowOf(tr))

\* ---- §4.7: the NORMATIVE status per code, transcribed from the table ----
\* This is the spec's fixed mapping and must NOT depend on any constant — it is what the
\* emitted status is checked against.
\* NOTE 0.8.2.4: `connection_sequence_error` is 409, not 400. A state conflict is 409 and an
\* unknown operation is 400, which is why the old single row had to split before the status
\* could be fixed: one row cannot carry two statuses.
NormativeStatus(c) ==
  CASE c = "invalid_nonce"                  -> 401
    [] c = "authentication_failed"          -> 401
    [] c = "connection_already_established" -> 409
    [] c = "connection_sequence_error"      -> 409
    [] OTHER                                -> 400

\* ---- what the responder actually emits ----
StatusOf(tr) == IF WrongStatus THEN 400 ELSE NormativeStatus(CodeOf(tr))

\* ───────────────────────── §4.11: the pre-admission cause table ─────────────────────────
\* "The frame obligation belongs to the class; the CODE belongs to the cause [MUST]."
RefusalCode(c) ==
  CASE c = "connect_auth"  -> "authentication_failed"
    [] c = "oversize"      -> "payload_too_large"
    [] c = "hash_mismatch" -> "hash_mismatch"
    [] c = "framing"       -> IF EcfOnFraming THEN "non_canonical_ecf" ELSE "invalid_request"
    [] OTHER               -> "invalid_request"          \* "bad_root" — §3.3

RefusalStatus(c) ==
  CASE c = "connect_auth"  -> 401
    [] c = "oversize"      -> 413
    [] OTHER               -> 400

\* §4.11's emission obligation, as the observable it actually is: what reaches the wire.
\* THREE values, not a boolean — §4.11 states the two failures are "distinct failures rather
\* than one", and a model that collapsed them could not express that sentence.
\*
\* D11: this is a property of the PEER, not of the cause — the model has one refusal mode for
\* all five rows, so it cannot represent a peer that codes some causes and drops others.
\* §4.11 states its obligation over the class ("a peer that refuses a frame pre-admission"),
\* so a uniform mode is the right shape for the invariant; a per-cause mode would be the
\* right shape for a CONFORMANCE SUITE, which is not what this is.
Wire ==
  CASE RefusalMode = "coded"      -> "coded_response"
    [] RefusalMode = "bare_close" -> "close_only"
    [] OTHER                      -> "nothing"           \* "drop"

\* ===== transitions =====
Init ==
  /\ phase   = "new"
  /\ emitted = {}
  /\ refused = {}

\* §4.1 hello. From "new" it issues the echo nonce and advances. Otherwise it is a reject:
\* on an established connection §4.7's `connection_already_established` row (409, no token
\* reissue); from hello_done it is an out-of-order operation.
DoHello ==
  \/ /\ phase = "new"
     /\ phase' = "hello_done"
     /\ UNCHANGED << emitted, refused >>
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \cup {"second_hello"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "established"
     /\ emitted' = emitted \cup {"hello_on_established"}
     /\ UNCHANGED << phase, refused >>

\* §4.6 authenticate. Accepted only from hello_done with the issued nonce echoed (the
\* §4.6 step-1 bind that Conn.tla / ConnApalache.tla already prove). The three reject paths
\* are what §4.7 governs.
DoAuth ==
  \/ /\ phase = "hello_done"                       \* good nonce -> established, no code
     /\ phase' = "established"
     /\ UNCHANGED << emitted, refused >>
  \/ /\ phase = "hello_done"                       \* nonce mismatch
     /\ emitted' = emitted \cup {"bad_nonce"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "new"                              \* pre-hello auth — 401, settled at .25
     /\ emitted' = emitted \cup {"prehello_auth"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "established"
     /\ emitted' = emitted \cup {"auth_on_established"}
     /\ UNCHANGED << phase, refused >>

\* 0.8.2.8 — the HALF-OPEN state. `hello_done` is past hello and before authenticate, so it
\* is not established; a connect operation the responder implements, arriving here, is the
\* out-of-order row. §4.7 states this because "two adjacent rules each LOOK like they cover
\* it and neither does": the `invalid_nonce` row is scoped to a pre-HELLO authenticate, and
\* the pre-authorized-connect exception is scoped to an ESTABLISHED connection.
DoOpOnHalfOpen ==
  /\ phase = "hello_done"
  /\ emitted' = emitted \cup {"op_on_halfopen"}
  /\ UNCHANGED << phase, refused >>

\* 0.8.2.4 — an operation name the responder does not implement, in ANY state. Deliberately
\* unguarded on phase: "it exists in no state" is the row's own justification for why it is
\* not an ordering failure.
DoUnknownOp ==
  /\ emitted' = emitted \cup {"unknown_connect_op"}
  /\ UNCHANGED << phase, refused >>

\* 0.8.2.6 — the address table. A PRE-ESTABLISHMENT EXECUTE naming some path. Guarded to
\* `phase # "established"` because that is the table's own scope; the foreign-namespace
\* answer must then be the same at "new" and at "hello_done", which is the property.
DoExecute ==
  /\ phase # "established"
  /\ \/ emitted' = emitted \cup {"foreign_ns_execute"}
     \/ emitted' = emitted \cup {"own_ns_execute"}
  /\ UNCHANGED << phase, refused >>

\* §4.11 — a pre-admission refusal of any cause, at any phase. Pre-admission is by definition
\* before the frame becomes a request, so it is not gated on the handshake.
DoRefuse ==
  /\ \E c \in Causes : refused' = refused \cup {c}
  /\ UNCHANGED << phase, emitted >>

Next == DoHello \/ DoAuth \/ DoOpOnHalfOpen \/ DoUnknownOp \/ DoExecute \/ DoRefuse
        \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

TypeOK == phase \in Phases /\ emitted \subseteq Triggers /\ refused \subseteq Causes

\* SAFETY — §4.7: "an impl that collapses several of these to one code ... is
\* non-conformant." Two failures that the table puts in DIFFERENT rows MUST NOT emit the
\* same code. Note the quantifier is over ROWS, not triggers: the `invalid_nonce` row
\* deliberately covers "nonce mismatch / absent / pre-hello" as one row and the out-of-order
\* row covers state conflicts generally, so two triggers sharing a row legitimately share a
\* code.
\*
\* ⚠ AND IT IS NOT "ALL ROWS HAVE DIFFERENT CODES" EITHER, which the pin's version could get
\* away with and .25's cannot: `r_unknown_op` and `r_addr_foreign` both carry
\* `invalid_request` BY DESIGN — §4.7 says the code names "a request it could not take as
\* one" and that extensions "MUST NOT mint a synonym". So the property is stated over the
\* rows the table SEPARATES BY CODE, which is what the contract actually promises.
\* ⚠ AND THE FIRST DRAFT OF THIS INVARIANT WAS A TAUTOLOGY, caught before it ran. It read
\* `CodeOf(t1) = CodeOf(t2) => (RowOf(t1) = RowOf(t2) \/ CodeOfRow(RowOf(t1)) =
\* CodeOfRow(RowOf(t2)))`, whose right disjunct IS the antecedent written out — true of
\* every model, including a completely collapsed one. It is recorded here rather than
\* quietly fixed because it is the exact failure this module's own honesty note is about:
\* an assertion over a function of the constants is only as good as its comparison to
\* something the constants cannot move, and the fix is to compare against
\* `NormativeCodeOfRow`, which they cannot.
ReasonCodesDistinct ==
  \A t1, t2 \in emitted :
    (NormativeCodeOfRow(RowOf(t1)) # NormativeCodeOfRow(RowOf(t2)))
      => (CodeOf(t1) # CodeOf(t2))

\* SAFETY — §4.7: "or returns a different status, is non-conformant." Every emitted code
\* carries the status the table fixes for it.
StatusMatchesCode ==
  \A t \in emitted : StatusOf(t) = NormativeStatus(CodeOf(t))

\* SAFETY — §4.6 step 1 / §4.7's `invalid_nonce` row, transcribed: "A mismatch — or an
\* `authenticate` received before any hello nonce was issued — MUST be rejected with status
\* 401 `invalid_nonce`." At the v0.8.2 pin this was VIOLATED by a conformant reading of §4.7
\* row 10 and that violation was THE FINDING. At .25 the row says "**Not** a pre-hello
\* `authenticate`", so this is an ordinary invariant and `SeqReadingBug` is an ordinary
\* injected defect.
PreHelloAuthIsInvalidNonce ==
  ("prehello_auth" \in emitted) => (CodeOf("prehello_auth") = "invalid_nonce")

\* SAFETY — 0.8.2.4: a state conflict is 409. Both rows in that class carry it, and the
\* unknown-operation row — which split OUT of the out-of-order row precisely because it is
\* not a state conflict — carries 400.
StateConflictsAre409 ==
  \A t \in emitted :
    (RowOf(t) \in {"r_seq", "r_already"}) => (StatusOf(t) = 409)

\* SAFETY — 0.8.2.6, and this is the one property here that is about ORDERING rather than a
\* lookup. "Authentication state cannot change the answer, so evaluating it first can only
\* mislead." A foreign-namespace pre-establishment EXECUTE gets the same verdict whichever
\* pre-established phase it arrives in — which is only checkable because the model reaches
\* that trigger from both "new" and "hello_done".
AddressVerdictPhaseIndependent ==
  ("foreign_ns_execute" \in emitted) =>
    (CodeOf("foreign_ns_execute") = "invalid_request" /\ StatusOf("foreign_ns_execute") = 400)

\* ───────────────────────── §4.11 ─────────────────────────
\* SAFETY — the section's single invariant: "A peer that refuses a frame pre-admission MUST
\* put a coded EXECUTE_RESPONSE on the wire [MUST]". Whether it closes afterwards is its own
\* choice, so the property is about the FRAME and not about the close.
PreAdmissionRefusalIsCoded ==
  (refused # {}) => (Wire = "coded_response")

\* SAFETY — and this is the half a single boolean would lose. §4.11: the two failures "are
\* distinct failures rather than one". Stated separately so a control that produces a bare
\* close does NOT satisfy a property written about dropping, and vice versa.
NoSilentDrop     == (refused # {}) => (Wire # "nothing")
NoBareCloseOnly  == (refused # {}) => (Wire # "close_only")

\* SAFETY — the cause table, every row. "The frame obligation belongs to the class; the CODE
\* belongs to the cause [MUST] ... A single code for the class would answer an honest caller
\* under the wrong reason and send them to the wrong layer."
RefusalCodeMatchesCause ==
  \A c \in refused :
    /\ (c = "connect_auth")  => (RefusalCode(c) = "authentication_failed" /\ RefusalStatus(c) = 401)
    /\ (c = "oversize")      => (RefusalCode(c) = "payload_too_large"     /\ RefusalStatus(c) = 413)
    /\ (c = "hash_mismatch") => (RefusalCode(c) = "hash_mismatch"         /\ RefusalStatus(c) = 400)
    /\ (c = "bad_root")      => (RefusalCode(c) = "invalid_request"       /\ RefusalStatus(c) = 400)

\* SAFETY — "`400 non_canonical_ecf` is NOT conformant on the framing arm [MUST]." Stated as
\* its own invariant rather than folded into the one above, because it is a PROHIBITION on a
\* specific wrong answer and §4.11 argues it from the remedy the code selects, not from the
\* code being in the wrong family.
\*
\* ⚠ THE `framing` ROW IS DELIBERATELY ABSENT FROM `RefusalCodeMatchesCause` ABOVE, and that
\* is a grading decision rather than an oversight. `EcfOnFraming` is the control for THIS
\* invariant; if the table property also covered the framing code, that control would violate
\* two invariants and TLC reports whichever it reaches first — so the declared expected
\* verdict would be a coin flip between two true statements. D13's rule is that a control
\* fails for its STATED reason, and one constant per rule is how this repo keeps that true.
FramingIsNotEcf ==
  ("framing" \in refused) => (RefusalCode("framing") # "non_canonical_ecf")

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / ConnCodesWitness.cfg). Asserted as an invariant
\* that MUST FAIL: a violation exhibits a reachable state in which EVERY §4.7 row this model
\* covers has actually been emitted AND every §4.11 cause has fired — so the properties above
\* are not vacuously true of a responder that never rejects anything. This matters more here
\* than elsewhere: the code assignment is a function of the constants, so reachability of each
\* row IS the model's content. Expected verdict: VIOLATION.
WitnessAllRowsEmitted ==
  ~( /\ \A r \in Rows : \E t \in emitted : RowOf(t) = r
     /\ refused = Causes )
====
