---- MODULE ConnCodesApalache ----
\* Apalache (SMT) cross-check of tla/ConnCodes.tla — §4.7 Connection Error Codes and §4.11
\* Pre-admission refusals.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* MODELING-PIN-OVERRIDE: v0.8.2.25
\* ══════════════════════════════════════════════════════════════════════════════════════
\* ⛔ RETARGETED WITH ITS TLC PEER, AND NOT RETARGETING IT WOULD HAVE BEEN THE DEFECT.
\* `docs/CORROBORATION.md` credits `conncodes` to three engines. Three engines checking
\* THREE DIFFERENT TEXTS is not corroboration — it is one reading per snapshot, presented as
\* agreement. So the override covers `tla/ConnCodes.tla`, this file and `spin/conncodes.pml`
\* together, declared as one block in `TRACKS.toml`. See ConnCodes.tla's header for why the
\* override is a registry fact rather than a paragraph.
\* ══════════════════════════════════════════════════════════════════════════════════════
\*
\* WHY THIS EXISTS. §4.7 appeared in COVERAGE-MATRIX.md as an "Apalache-only" row, which was
\* wrong twice over: nothing modeled §4.7 at all (the row came from a range endpoint in a
\* comment — see ConnCodes.tla's header), and the fix for a genuinely single-tool row is to
\* add engines, not to leave the claim standing. ConnCodes is therefore checked by all three
\* from the day it lands: TLC bounded-exhaustive, this port inductive, spin/conncodes.pml as
\* an independent re-encoding.
\*
\* ⛔ WHAT THIS PORT USED TO BUY AND NO LONGER DOES, STATED RATHER THAN QUIETLY DROPPED.
\* At the v0.8.2 pin `PreHelloAuthRow` was a SYMBOLIC constant here, ranged over BOTH readings
\* the spec's two clauses permitted, so the inductive result was "for every row assignment the
\* spec permits, the §4.7 contracts hold" — the honest shape for a property whose input is a
\* spec ambiguity. **0.8.2.1 resolved the ambiguity** (row 10 now says "**Not** a pre-hello
\* `authenticate`"), so there is one permitted assignment and that quantification has no
\* subject left. The constant is a plain boolean defect switch now.
\*
\* *That is a gate losing its subject by an upstream fix rather than by a local edit, which is
\* docs/DISCIPLINE-CHARTER.md D15's seventh shape — the `scoped` track gate going empty. Recorded at the site,
\* because the thing that makes it invisible is that everything stays green.*
\*
\* WHAT IT STILL BUYS: the invariants are proved INDUCTIVE rather than bounded. TLC checks the
\* reachable states of a phase machine; this checks `IndInit /\ Next => Inv'` over every typed
\* state satisfying `Inv`, including ones no execution reaches.
\*
\* NO STRENGTHENING IS NEEDED. `emitted` and `refused` only grow and every property is a
\* pointwise statement about their members, so the invariants are already inductive over the
\* typed domain — stated explicitly because "no strengthening" is usually a sign the invariant
\* is too weak to be interesting, and here it is instead a consequence of the model being
\* monotone. `make apalache-closure` therefore has nothing to check beyond `Inv` itself, which
\* is the degenerate-but-honest case of that gate.
EXTENDS Integers

CONSTANTS
  \* @type: Bool;
  CollapseCodes,
  \* @type: Bool;
  WrongStatus,
  \* @type: Bool;
  SeqReadingBug,
  \* @type: Bool;
  AuthBeforeAddress,
  \* @type: Str;
  RefusalMode,
  \* @type: Bool;
  EcfOnFraming

VARIABLES
  \* @type: Str;
  phase,
  \* @type: Set(Str);
  emitted,
  \* @type: Set(Str);
  refused

vars == << phase, emitted, refused >>

Rows == {"r_nonce", "r_already", "r_seq", "r_unknown_op", "r_addr_foreign", "r_addr_own"}
Triggers == {"second_hello", "hello_on_established", "bad_nonce",
             "prehello_auth", "auth_on_established",
             "op_on_halfopen", "unknown_connect_op",
             "foreign_ns_execute", "own_ns_execute"}
Phases == {"new", "hello_done", "established"}
Causes == {"connect_auth", "oversize", "hash_mismatch", "framing", "bad_root"}

\* ----- the §4.7 mapping, transcribed from ConnCodes.tla -----
RowOf(tr) ==
  IF tr = "second_hello" THEN "r_seq"
  ELSE IF tr = "hello_on_established" THEN "r_already"
  ELSE IF tr = "bad_nonce" THEN "r_nonce"
  ELSE IF tr = "auth_on_established" THEN "r_already"
  ELSE IF tr = "op_on_halfopen" THEN "r_seq"
  ELSE IF tr = "unknown_connect_op" THEN "r_unknown_op"
  ELSE IF tr = "foreign_ns_execute"
       THEN (IF AuthBeforeAddress THEN "r_addr_own" ELSE "r_addr_foreign")
  ELSE IF tr = "own_ns_execute" THEN "r_addr_own"
  ELSE (IF SeqReadingBug THEN "r_seq" ELSE "r_nonce")

\* The table's own assignment, constant-free — what an emitted code is checked AGAINST.
NormativeCodeOfRow(r) ==
  IF r = "r_nonce" THEN "invalid_nonce"
  ELSE IF r = "r_already" THEN "connection_already_established"
  ELSE IF r = "r_unknown_op" THEN "invalid_request"
  ELSE IF r = "r_addr_foreign" THEN "invalid_request"
  ELSE IF r = "r_addr_own" THEN "authentication_failed"
  ELSE "connection_sequence_error"

CodeOfRow(r) ==
  IF CollapseCodes THEN "connection_sequence_error" ELSE NormativeCodeOfRow(r)

CodeOf(tr) == CodeOfRow(RowOf(tr))

NormativeStatus(c) ==
  IF c = "invalid_nonce" THEN 401
  ELSE IF c = "authentication_failed" THEN 401
  ELSE IF c = "connection_already_established" THEN 409
  ELSE IF c = "connection_sequence_error" THEN 409
  ELSE 400

StatusOf(tr) == IF WrongStatus THEN 400 ELSE NormativeStatus(CodeOf(tr))

\* ----- §4.11 -----
RefusalCode(c) ==
  IF c = "connect_auth" THEN "authentication_failed"
  ELSE IF c = "oversize" THEN "payload_too_large"
  ELSE IF c = "hash_mismatch" THEN "hash_mismatch"
  ELSE IF c = "framing"
       THEN (IF EcfOnFraming THEN "non_canonical_ecf" ELSE "invalid_request")
  ELSE "invalid_request"

RefusalStatus(c) ==
  IF c = "connect_auth" THEN 401
  ELSE IF c = "oversize" THEN 413
  ELSE 400

Wire ==
  IF RefusalMode = "coded" THEN "coded_response"
  ELSE IF RefusalMode = "bare_close" THEN "close_only"
  ELSE "nothing"

\* ----- the invariants (transcribed from ConnCodes.tla) -----
ReasonCodesDistinct ==
  \A t1 \in emitted : \A t2 \in emitted :
    (NormativeCodeOfRow(RowOf(t1)) /= NormativeCodeOfRow(RowOf(t2)))
      => (CodeOf(t1) /= CodeOf(t2))

StatusMatchesCode ==
  \A t \in emitted : StatusOf(t) = NormativeStatus(CodeOf(t))

StateConflictsAre409 ==
  \A t \in emitted : (RowOf(t) \in {"r_seq", "r_already"}) => (StatusOf(t) = 409)

AddressVerdictPhaseIndependent ==
  ("foreign_ns_execute" \in emitted) =>
    (CodeOf("foreign_ns_execute") = "invalid_request"
     /\ StatusOf("foreign_ns_execute") = 400)

PreHelloAuthIsInvalidNonce ==
  ("prehello_auth" \in emitted) => (CodeOf("prehello_auth") = "invalid_nonce")

\* §4.11's invariant as the section states it — one obligation over the class.
PreAdmissionRefusalIsCoded == (refused /= {}) => (Wire = "coded_response")

\* And the same fact split into the two failures §4.11 says are "distinct failures rather than
\* one". Logically the conjunction of these IS the invariant above; they are separate
\* declarations so each control can name the one it breaks, which is the difference between a
\* control that fails and a control that fails FOR ITS STATED REASON.
NoSilentDrop    == (refused /= {}) => (Wire /= "nothing")
NoBareCloseOnly == (refused /= {}) => (Wire /= "close_only")

RefusalCodeMatchesCause ==
  \A c \in refused :
    /\ (c = "connect_auth")  => (RefusalCode(c) = "authentication_failed" /\ RefusalStatus(c) = 401)
    /\ (c = "oversize")      => (RefusalCode(c) = "payload_too_large"     /\ RefusalStatus(c) = 413)
    /\ (c = "hash_mismatch") => (RefusalCode(c) = "hash_mismatch"         /\ RefusalStatus(c) = 400)
    /\ (c = "bad_root")      => (RefusalCode(c) = "invalid_request"       /\ RefusalStatus(c) = 400)

FramingIsNotEcf ==
  ("framing" \in refused) => (RefusalCode("framing") /= "non_canonical_ecf")

\* `\in SUBSET` rather than `\subseteq`: Apalache reads `x \in S` in an init predicate as an
\* ASSIGNMENT, and IndInit must assign every variable. `emitted \subseteq Triggers` is the same
\* proposition but gives the assignment finder nothing to bind, which is a 255 config error
\* rather than a counterexample — the exact confusion `apalache-neg`'s EXITCODE check exists
\* to keep out of the grading.
TypeOK ==
  /\ phase \in Phases
  /\ emitted \in SUBSET Triggers
  /\ refused \in SUBSET Causes

Inv ==
  /\ TypeOK
  /\ ReasonCodesDistinct
  /\ StatusMatchesCode
  /\ StateConflictsAre409
  /\ AddressVerdictPhaseIndependent
  /\ PreHelloAuthIsInvalidNonce
  /\ NoSilentDrop
  /\ NoBareCloseOnly
  /\ RefusalCodeMatchesCause
  /\ FramingIsNotEcf

\* ----- transitions (mirror of ConnCodes.tla) -----
Init ==
  /\ phase = "new"
  /\ emitted = {}
  /\ refused = {}

DoHello ==
  \/ /\ phase = "new"
     /\ phase' = "hello_done"
     /\ UNCHANGED << emitted, refused >>
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \union {"second_hello"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "established"
     /\ emitted' = emitted \union {"hello_on_established"}
     /\ UNCHANGED << phase, refused >>

DoAuth ==
  \/ /\ phase = "hello_done"
     /\ phase' = "established"
     /\ UNCHANGED << emitted, refused >>
  \/ /\ phase = "hello_done"
     /\ emitted' = emitted \union {"bad_nonce"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "new"
     /\ emitted' = emitted \union {"prehello_auth"}
     /\ UNCHANGED << phase, refused >>
  \/ /\ phase = "established"
     /\ emitted' = emitted \union {"auth_on_established"}
     /\ UNCHANGED << phase, refused >>

DoOpOnHalfOpen ==
  /\ phase = "hello_done"
  /\ emitted' = emitted \union {"op_on_halfopen"}
  /\ UNCHANGED << phase, refused >>

DoUnknownOp ==
  /\ emitted' = emitted \union {"unknown_connect_op"}
  /\ UNCHANGED << phase, refused >>

DoExecute ==
  /\ phase /= "established"
  /\ \/ emitted' = emitted \union {"foreign_ns_execute"}
     \/ emitted' = emitted \union {"own_ns_execute"}
  /\ UNCHANGED << phase, refused >>

DoRefuse ==
  /\ \E c \in Causes : refused' = refused \union {c}
  /\ UNCHANGED << phase, emitted >>

Next == DoHello \/ DoAuth \/ DoOpOnHalfOpen \/ DoUnknownOp \/ DoExecute \/ DoRefuse
        \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the invariant -----
IndInit == Inv

\* ----- constant inits -----
\* CORRECT: §4.7's two contracts and §4.11's emission obligation and cause table.
ConstInitOK ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: §4.7's own named non-conformance — several failures collapsed to one code.
ConstInitBugCollapse ==
  /\ CollapseCodes = TRUE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: the other half of §4.7's sentence — a code returned with a different status.
ConstInitBugStatus ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = TRUE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: a pre-hello `authenticate` routed to the out-of-order row. At the v0.8.2 pin
\* this was a CONFORMANT READING of §4.7 and was a finding row, not a control; 0.8.2.1 (FM-1)
\* narrowed row 10's parenthetical exactly as this repo argued, so it is now an ordinary
\* injected defect. See ConnCodesSeqReadingBug.cfg's header.
ConstInitSeqReading ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = TRUE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: 0.8.2.6 — authentication state consulted before the address.
ConstInitBugAddressOrder ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = TRUE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: §4.11's first named non-conformance — the frame is dropped.
ConstInitBugDrop ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "drop"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: §4.11's second, and DISTINCT from the first by construction — a bare close
\* with no coded frame.
ConstInitBugBareClose ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "bare_close"
  /\ EcfOnFraming = FALSE

\* NEG CONTROL: §4.11 — `non_canonical_ecf` on the framing arm, which that section rules NOT
\* conformant: the code selects the caller's remedy, and "your bytes are truncated" is not
\* "re-encode without the tag".
ConstInitBugEcf ==
  /\ CollapseCodes = FALSE
  /\ WrongStatus = FALSE
  /\ SeqReadingBug = FALSE
  /\ AuthBeforeAddress = FALSE
  /\ RefusalMode = "coded"
  /\ EcfOnFraming = TRUE
====
