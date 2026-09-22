---- MODULE ConnCodes ----
\* §4.7 Connection Error Codes — the MUST-emit reason-code contract, added at 0.8.2's
\* second gate audit. This module exists because §4.7 was listed in COVERAGE-MATRIX.md as
\* "Apalache-only" coverage when in fact NOTHING modeled it: the only §4.7 mention in the
\* whole repo was the far end of a SECTION RANGE in a comment in ConnApalache.tla, written
\* with a sigil on both ends, which the citation-derived coverage grid counted as a claim.
\* See COVERAGE-MATRIX.md section 3a-b.
\*
\* WHAT §4.7 SAYS. The table is "a normative MUST-emit contract: clients key error handling
\* off `result.data.code`, so the code and status for each failure are fixed across
\* implementations (an impl that collapses several of these to one code, or returns a
\* different status, is non-conformant)." So there are exactly two ways to be wrong, and
\* §4.7 names both — which is why this module has exactly two ordinary negative controls.
\*
\* This is the same theorem shape as Bounds.tla's ReasonCodesDistinct (§4.10(b) Ruling 3:
\* the capability-chain brake and the continuation brake MUST NOT share a reason string).
\* §4.7 generalizes it across the whole connect handshake.
\*
\* ===================================================================================
\* THE FINDING (routed to entity-core-protocol; see ../docs/status/ and PROPERTIES.md §D)
\* ===================================================================================
\* §4.7's table gives TWO DIFFERENT normative answers for one input, and a third and fourth
\* site restate it inconsistently. An `authenticate` frame arriving before any hello nonce
\* was issued:
\*
\*   §4.6 step 1 (normative, explicit): "A mismatch — or an `authenticate` received before
\*     any hello nonce was issued — MUST be rejected with status 401 `invalid_nonce`."
\*   §4.7 table ROW 6 (normative): "Nonce mismatch / absent / PRE-HELLO (§4.6 step 1) |
\*     `invalid_nonce` | 401".
\*   §4.7 table ROW 10 (normative): "Out-of-order operation (e.g., authenticate before
\*     hello) | `connection_sequence_error` | 400".
\*   §5.2a (normative enumeration): lists "Connect-time (§4.6) | Nonce mismatch | 401" and
\*     drops "absent / pre-hello" altogether.
\*
\* Rows 6 and 10 are in the SAME TABLE, so "follow §4.7" is not a well-defined position —
\* an implementer reading it top-to-bottom hits row 6, then row 10 four rows later. All are
\* MUSTs, all name this exact input, and they disagree on BOTH the code and the status class
\* (401 authentication boundary vs 400 client-correctable). §4.7's own preamble forbids the
\* divergence it creates: an impl "returns a different status" is non-conformant, so
\* whichever reading an implementation picks, another row calls it non-conformant. This is
\* precisely the cross-impl divergence §4.7 exists to prevent, on the field clients are told
\* to key off — and it HAS diverged: four distinct behaviours across the 46-peer keystone
\* cohort and the three ground-up impls, two of them outside the spec's own answer set.
\*
\* NOTE ON THE FRAMING. Through 2026-08-30 this header, PROPERTIES.md §D.1 and the CHANGELOG
\* all said "§4.6 step 1 vs §4.7 row 10" and did not notice row 6 — even though the row-6
\* text, "pre-hello" included, is transcribed verbatim in ../spin/conncodes.pml's R6_NONCE
\* comment. The weaker framing points at the wrong fix (reconcile two sections) when the
\* defect is row 10's PARENTHETICAL alone; row 6 already defers to §4.6 by citation and the
\* contradiction survives that. Narrowing four words is the whole remedy.
\*
\* The model checks BOTH readings rather than picking one: `PreHelloAuthRow` is the contested
\* cell, and ConnCodesSeqReadingBug.cfg selects §4.7's reading. Its "defect" is not a bug we
\* injected — it is a conformant reading of the spec, and that is the point. Under it,
\* PreHelloAuthIsInvalidNonce (a direct transcription of §4.6 step 1) is violated.
\*
\* MODEL SHAPE (D11 — what is and is not here). A structural model of the responder's
\* connect-handshake reject paths, in the same abstraction ConnApalache.tla uses: no FIFO
\* inbox, no interleaving, no time. At any point the (possibly adversarial) initiator may
\* send a hello or an authenticate, and the responder reacts per phase. ABSTRACTED AWAY:
\* §4.6 steps 0/2/3 (key-type support, proof-of-possession, identity binding) and their codes
\* `unsupported_key_type` / `authentication_failed` / `identity_mismatch` — those are the
\* §7.3 crypto wall and Tamarin's (tamarin/Binding.*). §4.7's four version/key-type
\* negotiation codes are likewise out: they are settled before any phase this model has,
\* and naming their own sections here would mint a citation for a section this model makes
\* no claim about (COVERAGE-MATRIX.md section 3b). What is modeled
\* is the three rows a phase machine can reach.
\*
\* HONESTY (PROPERTIES.md §C). The distinctness and status properties are assertions over the
\* code assignment, which is a function of the constants — so their content is (a) that each
\* §4.7 row is REACHABLE at all, which is what ConnCodesWitness.cfg establishes, and (b) that
\* the assignment can be broken, which is what the two controls establish. This is the same
\* shape, and the same honest limit, as Bounds.tla's reason-code result.
EXTENDS Naturals, FiniteSets

CONSTANTS
  CollapseCodes,   \* FALSE = §4.7: each failure row has its own code. CORRECT.
                   \* TRUE  = neg control, named by §4.7 itself: "an impl that collapses
                   \*         several of these to one code ... is non-conformant".
  WrongStatus,     \* FALSE = §4.7: the status for each code is fixed. CORRECT.
                   \* TRUE  = neg control, the other half of §4.7's sentence: "or returns a
                   \*         different status".
  PreHelloAuthRow  \* WHICH §4.7 row an `authenticate` before any issued nonce falls in.
                   \* "r6_nonce" = §4.6 step 1's explicit MUST -> 401 invalid_nonce.
                   \* "r10_seq"  = §4.7 table row 10's parenthetical -> 400 sequence error.
                   \* The spec says both. See THE FINDING above.

\* The §4.7 rows this phase machine can reach. Row ids are positional in §4.7's table.
Rows == {"r6_nonce", "r9_already", "r10_seq"}

\* The responder's reject triggers — distinct FAILURES, which §4.7 maps onto rows.
Triggers == {"second_hello", "hello_on_established", "bad_nonce",
             "prehello_auth", "auth_on_established"}

Phases == {"new", "hello_done", "established"}

VARIABLES
  phase,    \* §4.1 per-connection phase
  emitted   \* subset of Triggers: which reject paths have actually fired

vars == << phase, emitted >>

\* ---- §4.7: trigger -> table row ----
\* Only `prehello_auth` is contested; every other assignment is unambiguous in the table.
RowOf(tr) ==
  CASE tr = "second_hello"         -> "r10_seq"
    [] tr = "hello_on_established" -> "r9_already"
    [] tr = "bad_nonce"            -> "r6_nonce"
    [] tr = "auth_on_established"  -> "r9_already"
    [] OTHER                       -> PreHelloAuthRow      \* the contested cell

\* ---- §4.7: row -> emitted code ----
\* CollapseCodes is the non-conformance §4.7 names in its own preamble.
CodeOfRow(r) ==
  IF CollapseCodes THEN "connection_sequence_error"
  ELSE CASE r = "r6_nonce"   -> "invalid_nonce"
         [] r = "r9_already" -> "connection_already_established"
         [] OTHER            -> "connection_sequence_error"

CodeOf(tr) == CodeOfRow(RowOf(tr))

\* ---- §4.7: the NORMATIVE status per code, transcribed from the table ----
\* This is the spec's fixed mapping and must NOT depend on any constant — it is what the
\* emitted status is checked against.
NormativeStatus(c) ==
  CASE c = "invalid_nonce"                  -> 401
    [] c = "connection_already_established" -> 409
    [] OTHER                                -> 400

\* ---- what the responder actually emits ----
StatusOf(tr) == IF WrongStatus THEN 400 ELSE NormativeStatus(CodeOf(tr))

\* ===== transitions =====
Init ==
  /\ phase   = "new"
  /\ emitted = {}

\* §4.1 hello. From "new" it issues the echo nonce and advances. Otherwise it is a reject:
\* on an established connection §4.7 row 9 (409, no token reissue); from hello_done it is an
\* out-of-order operation, §4.7 row 10.
DoHello ==
  \/ /\ phase = "new"
     /\ phase' = "hello_done"
     /\ UNCHANGED emitted
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \cup {"second_hello"}
     /\ UNCHANGED phase
  \/ /\ phase = "established"
     /\ emitted' = emitted \cup {"hello_on_established"}
     /\ UNCHANGED phase

\* §4.6 authenticate. Accepted only from hello_done with the issued nonce echoed (the
\* §4.6 step-1 bind that Conn.tla / ConnApalache.tla already prove). The three reject paths
\* are what §4.7 governs.
DoAuth ==
  \/ /\ phase = "hello_done"                       \* good nonce -> established, no code
     /\ phase' = "established"
     /\ UNCHANGED emitted
  \/ /\ phase = "hello_done"                       \* §4.7 row 6: nonce mismatch
     /\ emitted' = emitted \cup {"bad_nonce"}
     /\ UNCHANGED phase
  \/ /\ phase = "new"                              \* THE CONTESTED CELL: pre-hello auth
     /\ emitted' = emitted \cup {"prehello_auth"}
     /\ UNCHANGED phase
  \/ /\ phase = "established"                      \* §4.7 row 9
     /\ emitted' = emitted \cup {"auth_on_established"}
     /\ UNCHANGED phase

Next == DoHello \/ DoAuth \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

TypeOK == phase \in Phases /\ emitted \subseteq Triggers

\* SAFETY — §4.7: "an impl that collapses several of these to one code ... is
\* non-conformant." Two failures that the table puts in DIFFERENT rows MUST NOT emit the
\* same code. Note the quantifier is over ROWS, not triggers: §4.7 row 6 deliberately covers
\* "nonce mismatch / absent / pre-hello" as one row, and row 10 covers out-of-order
\* operations generally, so two triggers sharing a row legitimately share a code.
ReasonCodesDistinct ==
  \A t1, t2 \in emitted : (CodeOf(t1) = CodeOf(t2)) => (RowOf(t1) = RowOf(t2))

\* SAFETY — §4.7: "or returns a different status, is non-conformant." Every emitted code
\* carries the status the table fixes for it.
StatusMatchesCode ==
  \A t \in emitted : StatusOf(t) = NormativeStatus(CodeOf(t))

\* SAFETY — §4.6 step 1, transcribed verbatim as a property: "A mismatch — or an
\* `authenticate` received before any hello nonce was issued — MUST be rejected with status
\* 401 `invalid_nonce`." VIOLATED under §4.7 table row 10's reading. That violation is THE
\* FINDING, not an injected defect. See the header.
PreHelloAuthIsInvalidNonce ==
  ("prehello_auth" \in emitted) => (CodeOf("prehello_auth") = "invalid_nonce")

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / ConnCodesWitness.cfg). Asserted as an invariant
\* that MUST FAIL: a violation exhibits a reachable state in which EVERY §4.7 row this model
\* covers has actually been emitted — so the properties above are not vacuously true of a
\* responder that never rejects anything. This matters more here than elsewhere: the code
\* assignment is a function of the constants, so reachability of each row IS the model's
\* content. Expected verdict: VIOLATION.
WitnessAllRowsEmitted == ~(\A r \in Rows : \E t \in emitted : RowOf(t) = r)
====
