---- MODULE ConnCodesApalache ----
\* NEW at 0.8.2's second gate audit — Apalache (SMT) cross-check of tla/ConnCodes.tla
\* (V8 §4.7 Connection Error Codes).
\*
\* WHY THIS EXISTS. §4.7 appeared in COVERAGE-MATRIX.md as an "Apalache-only" row, which was
\* wrong twice over: nothing modeled §4.7 at all (the row came from a range endpoint in a
\* comment — see ConnCodes.tla's header), and the fix for a genuinely single-tool row is to
\* add engines, not to leave the claim standing. ConnCodes is therefore checked by all three
\* from the day it lands: TLC bounded-exhaustive, this port inductive, spin/conncodes.pml as
\* an independent re-encoding.
\*
\* WHAT THIS BUYS over TLC. `PreHelloAuthRow` is a SYMBOLIC constant here, ranged over both
\* readings of the contested §4.6-step-1-vs-§4.7-row-10 cell rather than fixed to one. So the
\* inductive result is: for EVERY row assignment the spec's two clauses permit, the §4.7
\* distinctness and status contracts hold. That is the honest shape for a property whose
\* input is a spec ambiguity — checking one reading would beg the question the finding raises.
\* The §4.6-step-1 property itself is NOT in Inv for the same reason: it is false under one of
\* the two permitted assignments, which is the finding (`ConstInitSeqReading` below).
\*
\* NO STRENGTHENING IS NEEDED. `emitted` only grows and every property is a pointwise
\* statement about its members, so the invariants are already inductive over the typed domain
\* — stated explicitly because "no strengthening" is usually a sign the invariant is too weak
\* to be interesting, and here it is instead a consequence of the model being monotone.
EXTENDS Integers

CONSTANTS
  \* @type: Bool;
  CollapseCodes,
  \* @type: Bool;
  WrongStatus,
  \* @type: Str;
  PreHelloAuthRow

VARIABLES
  \* @type: Str;
  phase,
  \* @type: Set(Str);
  emitted

vars == << phase, emitted >>

Rows == {"r6_nonce", "r9_already", "r10_seq"}
Triggers == {"second_hello", "hello_on_established", "bad_nonce",
             "prehello_auth", "auth_on_established"}
Phases == {"new", "hello_done", "established"}

\* ----- the §4.7 mapping, transcribed from ConnCodes.tla -----
RowOf(tr) ==
  IF tr = "second_hello" THEN "r10_seq"
  ELSE IF tr = "hello_on_established" THEN "r9_already"
  ELSE IF tr = "bad_nonce" THEN "r6_nonce"
  ELSE IF tr = "auth_on_established" THEN "r9_already"
  ELSE PreHelloAuthRow

CodeOfRow(r) ==
  IF CollapseCodes THEN "connection_sequence_error"
  ELSE IF r = "r6_nonce" THEN "invalid_nonce"
  ELSE IF r = "r9_already" THEN "connection_already_established"
  ELSE "connection_sequence_error"

CodeOf(tr) == CodeOfRow(RowOf(tr))

NormativeStatus(c) ==
  IF c = "invalid_nonce" THEN 401
  ELSE IF c = "connection_already_established" THEN 409
  ELSE 400

StatusOf(tr) == IF WrongStatus THEN 400 ELSE NormativeStatus(CodeOf(tr))

\* ----- the invariants (transcribed from ConnCodes.tla) -----
ReasonCodesDistinct ==
  \A t1 \in emitted : \A t2 \in emitted :
    (CodeOf(t1) = CodeOf(t2)) => (RowOf(t1) = RowOf(t2))

StatusMatchesCode ==
  \A t \in emitted : StatusOf(t) = NormativeStatus(CodeOf(t))

\* §4.6 step 1. Deliberately NOT part of Inv — see the header.
PreHelloAuthIsInvalidNonce ==
  ("prehello_auth" \in emitted) => (CodeOf("prehello_auth") = "invalid_nonce")

\* `\in SUBSET` rather than `\subseteq`: Apalache reads `x \in S` in an init predicate as an
\* ASSIGNMENT, and IndInit must assign every variable. `emitted \subseteq Triggers` is the same
\* proposition but gives the assignment finder nothing to bind, which is a 255 config error
\* rather than a counterexample — the exact confusion `apalache-neg`'s EXITCODE check exists
\* to keep out of the grading.
TypeOK ==
  /\ phase \in Phases
  /\ emitted \in SUBSET Triggers

Inv == TypeOK /\ ReasonCodesDistinct /\ StatusMatchesCode

\* ----- transitions (mirror of ConnCodes.tla) -----
Init ==
  /\ phase = "new"
  /\ emitted = {}

DoHello ==
  \/ /\ phase = "new"
     /\ phase' = "hello_done"
     /\ UNCHANGED emitted
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \union {"second_hello"}
     /\ UNCHANGED phase
  \/ /\ phase = "established"
     /\ emitted' = emitted \union {"hello_on_established"}
     /\ UNCHANGED phase

DoAuth ==
  \/ /\ phase = "hello_done"
     /\ phase' = "established"
     /\ UNCHANGED emitted
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \union {"bad_nonce"}
     /\ UNCHANGED phase
  \/ /\ phase = "new"
     /\ emitted' = emitted \union {"prehello_auth"}
     /\ UNCHANGED phase
  \/ /\ phase = "established"
     /\ emitted' = emitted \union {"auth_on_established"}
     /\ UNCHANGED phase

Next == DoHello \/ DoAuth \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the invariant -----
IndInit == Inv

\* ----- constant inits -----
\* CORRECT: §4.7's two contracts, checked over BOTH permitted readings of the contested cell.
ConstInitOK ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ PreHelloAuthRow \in {"r6_nonce", "r10_seq"}

\* NEG CONTROL: §4.7's own named non-conformance — several failures collapsed to one code.
ConstInitBugCollapse ==
  /\ CollapseCodes = TRUE
  /\ WrongStatus = FALSE
  /\ PreHelloAuthRow = "r6_nonce"

\* NEG CONTROL: the other half of §4.7's sentence — a code returned with a different status.
ConstInitBugStatus ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = TRUE
  /\ PreHelloAuthRow = "r6_nonce"

\* THE FINDING, as a control: §4.7 table ROW 10's reading of a pre-hello `authenticate`,
\* against §4.6 step 1 transcribed as PreHelloAuthIsInvalidNonce — which §4.7's own ROW 6
\* restates verbatim ("Nonce mismatch / absent / pre-hello (§4.6 step 1) | invalid_nonce |
\* 401"). Rows 6 and 10 are in the same table and both are normative MUSTs naming the same
\* input, so the contradiction is INTERNAL to §4.7, not merely §4.6-vs-§4.7. Expected:
\* counterexample. See ConnCodes.tla's header.
ConstInitSeqReading ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ PreHelloAuthRow = "r10_seq"
====
