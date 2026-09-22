/*
 * conncodes.pml — INDEPENDENT Promela re-encoding of §4.7 Connection Error Codes and
 * §4.11 Pre-admission refusals. Cross-check #B for the TLA+ `ConnCodes` model.
 *
 * ══════════════════════════════════════════════════════════════════════════════════════
 * MODELING-PIN-OVERRIDE: v0.8.2.25
 * ══════════════════════════════════════════════════════════════════════════════════════
 * ⛔ THIS FILE DOES NOT TRANSCRIBE THE TRACK PIN. `spec-data/MODELING-PIN` names `v0.8.2`;
 * this is a statement about `spec-data/v0.8.2.25/ENTITY-CORE-PROTOCOL.md`, because §4.11 does
 * not exist at the pin and §4.7's out-of-order row carries a different status there.
 * Declared in `TRACKS.toml` under `[track.core.model_pins]`, gated both directions by
 * `make trackcheck`. Retargeted TOGETHER with tla/ConnCodes.tla and tla/ConnCodesApalache.tla
 * — three engines checking three different texts would be one reading per snapshot presented
 * as agreement, which is the opposite of what `docs/CORROBORATION.md` credits this subject
 * for. See tla/ConnCodes.tla's header.
 * ══════════════════════════════════════════════════════════════════════════════════════
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM the §4.7 table, the §4.11
 * cause table and the §4.6 numbered steps — which failure lands in which row, which code that
 * row emits, and which status that code carries — NOT by translating the .tla.
 *
 * WHY IT EXISTS. §4.7 showed in COVERAGE-MATRIX.md as an "Apalache-only" row while in fact
 * NOTHING modeled it: the sole §4.7 mention in the repo was the far end of a SECTION RANGE
 * in a comment, written with a sigil on both ends, which the citation-derived coverage grid
 * counted as a claim. See tla/ConnCodes.tla's header and COVERAGE-MATRIX.md section 3a-b.
 *
 * THE CONTRACT UNDER TEST, verbatim from §4.7:
 *   "This table is a normative MUST-emit contract: clients key error handling off
 *    result.data.code, so the code and status for each failure are fixed across
 *    implementations (an impl that collapses several of these to one code, or returns a
 *    different status, is non-conformant)."
 * Two ways to be wrong, both named by the spec, hence exactly two ordinary controls for it.
 *
 * ⭐ THE FINDING THIS FILE CARRIED IS CLOSED — ADOPTED UPSTREAM. At the v0.8.2 pin, §4.7's
 * table gave two normative answers for a pre-hello `authenticate`: row 6 said 401
 * `invalid_nonce` (citing §4.6 step 1), row 10's parenthetical said 400
 * `connection_sequence_error`. This repo routed it arguing row 10's PARENTHETICAL ALONE was
 * the defect (docs/PROPERTIES.md §D.1), and 0.8.2.1 (FM-1) narrowed exactly those four words.
 * At .25 the row reads "**Not** a pre-hello `authenticate` (see below)". So -DSEQREADING
 * DEMOTES from "a conformant reading of the spec" to an ordinary injected defect, and the
 * finding retires by the text moving to where we argued it should.
 *
 * WHAT ELSE .25 ADDED, all encoded below:
 *   - `connection_sequence_error` is 409, not 400 (0.8.2.4) — a state conflict is the same
 *     class as `connection_already_established` directly above it in the table.
 *   - A NEW row: an operation name the responder does not implement, IN ANY STATE, is
 *     `invalid_request` 400. It split out of the out-of-order row because "it exists in no
 *     state, so reporting connection_sequence_error points the caller at its ordering when
 *     the defect is its operation name".
 *   - The HALF-OPEN state (0.8.2.8): past `hello`, before `authenticate`, NOT established.
 *     A connect operation arriving there is the out-of-order row — 409.
 *   - Address before authentication (0.8.2.6): a pre-establishment EXECUTE naming a FOREIGN
 *     namespace is `invalid_request` 400 at EVERY pre-established phase. That is a
 *     phase-independence claim, which is the one thing here a phase machine can really check.
 *   - §4.11: a pre-admission refusal MUST put a coded EXECUTE_RESPONSE on the wire; the close
 *     is optional; DROPPING and CLOSING-WITHOUT-A-FRAME are two DISTINCT non-conformances.
 *
 * ⛔ WHAT IS NOT ENCODED, AND IT IS THE INTERESTING ARM. §4.11's conformance paragraph names
 * arm (f): "a pre-admission refusal arriving while an admitted request is in flight on the
 * same connection MUST NOT cost that request its response." That is a claim about
 * INTERLEAVINGS on a multiplexed connection; this model has one process, one connection and
 * no admitted requests. It is spin/reentry.pml's subject and docs/LEAN-SEAM.md O24. Said here
 * so a reader does not infer coverage of it from a §4.11 citation.
 *
 * VARIANTS (select via -D<NAME>):
 *   (default)     §4.7 rows distinct, statuses per the table, §4.11 coded — all hold.
 *   -DCOLLAPSE    every reject emits connection_sequence_error -> distinctness VIOLATED
 *   -DWRONGSTATUS right codes, uniform 400 -> status contract VIOLATED
 *   -DSEQREADING  pre-hello auth routed to the out-of-order row -> §4.6 step 1 VIOLATED
 *   -DAUTHFIRST   authentication state consulted before the address -> phase-independence
 *                 VIOLATED
 *   -DDROP        §4.11 non-conformance #1: no response, no close -> NoSilentDrop VIOLATED
 *   -DBARECLOSE   §4.11 non-conformance #2: close, no frame -> NoBareCloseOnly VIOLATED
 *   -DECFFRAMING  non_canonical_ecf on the framing arm -> FramingIsNotEcf VIOLATED
 *
 * Fidelity (5th wall): §4.6 steps 0/2/3 (key-type support, proof-of-possession, identity
 * binding) as HANDSHAKE STEPS are the §7.3 crypto wall — Tamarin's (tamarin/Binding.*), not
 * modeled here. §4.7's four version/key-type negotiation codes are settled before any phase
 * this model has, and naming their own sections would mint a citation for a section this
 * model makes no claim about (COVERAGE-MATRIX.md section 3b). §4.11's `payload_too_large`
 * and `hash_mismatch` rows are transcribed as TABLE ROWS; nothing here models size accounting
 * or entity resolution, and transcribing the hash_mismatch ROW is not modelling its
 * ENFORCEMENT — that absence at the pin is what produced the 0.8.2.23 forgery
 * (docs/LEAN-SEAM.md O23). As in the TLA+ model, the content is the REACHABILITY of each row
 * plus the code/status assignment; this is stated rather than implied (docs/PROPERTIES.md §C).
 *
 * Build / run (from spin/, image entity-spin):
 *   safety: make verify MODEL=conncodes [DEFS=-DCOLLAPSE]   (expect errors: 0 / assertion)
 */

/* §4.7 table rows this phase machine can reach. Ids are by CONTENT, not by position: the
 * table's row ORDER changed at 0.8.2.4 when the out-of-order row split in two, and
 * positional ids would have silently re-pointed at a different row. */
#define R_NONE        0
#define R_NONCE       1    /* Nonce mismatch / absent / pre-hello (§4.6 step 1)     401 */
#define R_ALREADY     2    /* Connection already established                        409 */
#define R_SEQ         3    /* Out-of-order operation — a state conflict             409 */
#define R_UNKNOWN_OP  4    /* Unknown connect operation — exists in no state        400 */
#define R_ADDR_FOREIGN 5   /* Pre-establishment EXECUTE, foreign namespace          400 */
#define R_ADDR_OWN    6    /* Pre-establishment EXECUTE, own namespace, non-connect 401 */
#define NROW          7

/* §4.7 reason codes. */
#define C_NONE      0
#define C_NONCE     1      /* invalid_nonce */
#define C_ALREADY   2      /* connection_already_established */
#define C_SEQ       3      /* connection_sequence_error */
#define C_INVREQ    4      /* invalid_request */
#define C_AUTHFAIL  5      /* authentication_failed */

/* §4.1 connection phases. `P_HELLO` is the HALF-OPEN state named at 0.8.2.8: past hello,
 * before authenticate, and NOT established. */
#define P_NEW    0
#define P_HELLO  1
#define P_ESTAB  2

/* Reject triggers — distinct FAILURES, which §4.7 maps onto rows. */
#define T_SECOND_HELLO   0
#define T_HELLO_ESTAB    1
#define T_BAD_NONCE      2
#define T_PREHELLO_AUTH  3
#define T_AUTH_ESTAB     4
#define T_HALFOPEN_OP    5
#define T_UNKNOWN_OP     6
#define T_FOREIGN_NS     7
#define T_OWN_NS         8
#define NTRIG            9

/* Which row does a pre-hello `authenticate` fall in? SETTLED at 0.8.2.1 — the out-of-order
 * row says "**Not** a pre-hello `authenticate`" and a following paragraph pins it to 401 by
 * §4.2, §4.6 step 1 and the nonce row. -DSEQREADING is now an ordinary injected defect. */
#ifdef SEQREADING
  #define PREHELLO_ROW R_SEQ
#else
  #define PREHELLO_ROW R_NONCE
#endif

/* 0.8.2.6 — which row does a FOREIGN-namespace pre-establishment EXECUTE fall in? The
 * address answers first, at every phase. -DAUTHFIRST consults authentication state instead,
 * which §4.7 rules out because the resulting 401 "names a remedy that does not exist". */
#ifdef AUTHFIRST
  #define FOREIGN_ROW R_ADDR_OWN
#else
  #define FOREIGN_ROW R_ADDR_FOREIGN
#endif

/* §4.11 pre-admission causes. */
#define X_CONNECT_AUTH  0
#define X_OVERSIZE      1
#define X_HASH_MISMATCH 2
#define X_FRAMING       3
#define X_BAD_ROOT      4
#define NCAUSE          5

/* §4.11 pre-admission codes (the two above are reused; these are the ones only §4.11 has). */
#define C_TOOLARGE  6      /* payload_too_large */
#define C_HASHMM    7      /* hash_mismatch */
#define C_ECF       8      /* non_canonical_ecf — NOT conformant on the framing arm */

/* §4.11: what actually reaches the wire. THREE values, not a boolean: the section says the
 * two failures "are distinct failures rather than one", and a boolean cannot say that. */
#define W_CODED   0
#define W_CLOSE   1        /* close with no coded frame — looks like a network fault */
#define W_NOTHING 2        /* dropped — unobservable to every instrument */

#ifdef DROP
  #define WIRE W_NOTHING
#elif defined(BARECLOSE)
  #define WIRE W_CLOSE
#else
  #define WIRE W_CODED
#endif

byte phase = P_NEW;
/* The wire behaviour as a VARIABLE rather than the macro inline, so each §4.11
 * assertion names it. Asserted directly on the macro, the two controls produced
 * `(2==2)` and `(1==1)` after preprocessing — unique enough for a gate to match and
 * meaningless to read, and silently re-pointed if the #defines were ever reordered.
 * `wire` is constant per build, so it costs no states. */
byte wire = WIRE;
bool fired[NTRIG];         /* which reject paths have actually run */
byte rowOf[NTRIG];         /* the §4.7 row each fired trigger landed in */
byte codeOf[NTRIG];        /* the code it emitted */
short statOf[NTRIG];       /* the status it emitted */

bool refused[NCAUSE];      /* which §4.11 pre-admission refusals have fired */
byte rcodeOf[NCAUSE];
short rstatOf[NCAUSE];

/* §4.7: row -> code, AS THE TABLE FIXES IT. Constant-free: this is the spec's assignment and
 * it is what an emitted code is checked AGAINST. Keeping it apart from what the responder
 * emits is what stops the distinctness assertion below from being a tautology. */
inline norm_code(r, out) {
  if
  :: (r == R_NONCE)        -> out = C_NONCE;
  :: (r == R_ALREADY)      -> out = C_ALREADY;
  :: (r == R_UNKNOWN_OP)   -> out = C_INVREQ;
  :: (r == R_ADDR_FOREIGN) -> out = C_INVREQ;
  :: (r == R_ADDR_OWN)     -> out = C_AUTHFAIL;
  :: else                  -> out = C_SEQ;
  fi;
}

/* What the responder emits. COLLAPSE is the non-conformance §4.7 names in its own preamble. */
inline code_for(r, out) {
#ifdef COLLAPSE
  out = C_SEQ;             /* DEFECT: "collapses several of these to one code" */
#else
  norm_code(r, out);
#endif
}

/* §4.7: the NORMATIVE status per code, transcribed from the table. This is what emitted
 * statuses are CHECKED AGAINST, so it must not vary with any variant macro.
 * NOTE 0.8.2.4: connection_sequence_error is 409. A state conflict is 409 and an unknown
 * operation is 400 — which is why the old single row had to split before the status could be
 * fixed: one row cannot carry two statuses. */
inline norm_status(c, out) {
  if
  :: (c == C_NONCE)    -> out = 401;
  :: (c == C_AUTHFAIL) -> out = 401;
  :: (c == C_ALREADY)  -> out = 409;
  :: (c == C_SEQ)      -> out = 409;
  :: else              -> out = 400;
  fi;
}

inline emit(t, r) {
  byte cc; short ss;
  code_for(r, cc);
#ifdef WRONGSTATUS
  ss = 400;                /* DEFECT: "or returns a different status" */
#else
  norm_status(cc, ss);
#endif
  atomic {
    fired[t] = true; rowOf[t] = r; codeOf[t] = cc; statOf[t] = ss;
  }
}

/* §4.11: "the frame obligation belongs to the class; the CODE belongs to the cause [MUST]." */
inline refuse(x) {
  byte rc; short rs;
  if
  :: (x == X_CONNECT_AUTH)  -> rc = C_AUTHFAIL; rs = 401;
  :: (x == X_OVERSIZE)      -> rc = C_TOOLARGE; rs = 413;
  :: (x == X_HASH_MISMATCH) -> rc = C_HASHMM;   rs = 400;
  :: (x == X_FRAMING)       ->
#ifdef ECFFRAMING
       rc = C_ECF;          /* DEFECT: §5.4 of ENTITY-CBOR-ENCODING defines this code for
                             * CBOR TAG-POLICY violations; "your bytes are truncated" is not
                             * "re-encode without the tag". §4.11 rules it NOT conformant. */
#else
       rc = C_INVREQ;
#endif
       rs = 400;
  :: else                   -> rc = C_INVREQ; rs = 400;   /* X_BAD_ROOT — §3.3 */
  fi;
  atomic { refused[x] = true; rcodeOf[x] = rc; rstatOf[x] = rs; }
}

active proctype responder()
{
  byte i, j, x; short want; byte nc1, nc2;

  do
  :: /* §4.1 hello */
     if
     :: (phase == P_NEW)   -> phase = P_HELLO;                    /* accepted, no code */
     :: (phase == P_HELLO) -> emit(T_SECOND_HELLO, R_SEQ);
     :: (phase == P_ESTAB) -> emit(T_HELLO_ESTAB, R_ALREADY);
     fi;
  :: /* §4.6 authenticate */
     if
     :: (phase == P_HELLO) -> phase = P_ESTAB;                    /* good nonce, no code */
     :: (phase == P_HELLO) -> emit(T_BAD_NONCE, R_NONCE);
     :: (phase == P_NEW)   -> emit(T_PREHELLO_AUTH, PREHELLO_ROW);
     :: (phase == P_ESTAB) -> emit(T_AUTH_ESTAB, R_ALREADY);
     fi;
  :: /* 0.8.2.8 — a connect operation on the HALF-OPEN connection. Named in §4.7 because
      * "two adjacent rules each LOOK like they cover it and neither does". */
     (phase == P_HELLO) -> emit(T_HALFOPEN_OP, R_SEQ);
  :: /* 0.8.2.4 — an operation name the responder does not implement, in ANY state.
      * Deliberately unguarded on phase: that is the row's own justification. */
     emit(T_UNKNOWN_OP, R_UNKNOWN_OP);
  :: /* 0.8.2.6 — a pre-establishment EXECUTE. Reachable from BOTH P_NEW and P_HELLO, which
      * is what makes the phase-independence assertion below checkable rather than vacuous. */
     if
     :: (phase != P_ESTAB) -> emit(T_FOREIGN_NS, FOREIGN_ROW);
     :: (phase != P_ESTAB) -> emit(T_OWN_NS, R_ADDR_OWN);
     fi;
  :: /* §4.11 — a pre-admission refusal of any cause, at any phase. */
     if
     :: x = X_CONNECT_AUTH;
     :: x = X_OVERSIZE;
     :: x = X_HASH_MISMATCH;
     :: x = X_FRAMING;
     :: x = X_BAD_ROOT;
     fi;
     refuse(x);
  :: /* ---- the properties ----
      * WRAPPED IN `d_step`, AND THAT IS A RESOURCE FACT WORTH RECORDING RATHER THAN A
      * STYLE CHOICE. The pin's version of this model had 5 triggers and no §4.11 causes;
      * .25 takes it to 9 triggers and 5 causes, so the nested i/j scan went from 25 to 81
      * iterations and each intermediate value of the loop counters is part of the state
      * vector. Unwrapped, this OOM-KILLED at the 2 GB cap in caps.mk after 14M states —
      * which reads like a model too big to check and is nothing of the kind: the reachable
      * configuration space is 2^9 x 3 x 2^5, well under 50k. The assertions are pure reads
      * of already-committed state, so collapsing them into one step changes no verdict and
      * removes the intermediate states entirely. `d_step` rather than `atomic` because the
      * block is fully deterministic and non-blocking, which is the stronger claim and the
      * one the compiler checks. */
     d_step {
     /* §4.7: two failures the table assigns DIFFERENT codes MUST NOT emit the same code.
      * Note it is NOT "all rows differ": the unknown-operation row and the foreign-address
      * row both carry invalid_request BY DESIGN — §4.7 says the code names "a request it
      * could not take as one" and that extensions "MUST NOT mint a synonym". So the
      * comparison is against norm_code, which no variant macro can move. */
     i = 0;
     do
     :: (i < NTRIG) ->
          j = 0;
          do
          :: (j < NTRIG) ->
               norm_code(rowOf[i], nc1);
               norm_code(rowOf[j], nc2);
               assert(!(fired[i] && fired[j] && nc1 != nc2 && codeOf[i] == codeOf[j]));
               j++;
          :: else -> break
          od;
          /* §4.7: the status for each code is fixed by the table. */
          norm_status(codeOf[i], want);
          assert(!(fired[i] && statOf[i] != want));
          /* 0.8.2.4: a state conflict is 409. */
          assert(!(fired[i] && (rowOf[i] == R_SEQ || rowOf[i] == R_ALREADY)
                   && statOf[i] != 409));
          i++;
     :: else -> break
     od;
     /* §4.6 step 1 / the nonce row: a pre-hello authenticate is 401 invalid_nonce.
      * VIOLATED under -DSEQREADING, which at .25 is an injected defect and not a reading. */
     assert(!(fired[T_PREHELLO_AUTH] && codeOf[T_PREHELLO_AUTH] != C_NONCE));
     /* 0.8.2.6: the address answers first, so a foreign namespace gets the same verdict at
      * every pre-established phase. VIOLATED under -DAUTHFIRST. */
     assert(!(fired[T_FOREIGN_NS]
              && (codeOf[T_FOREIGN_NS] != C_INVREQ || statOf[T_FOREIGN_NS] != 400)));
     /* §4.11: a pre-admission refusal MUST put a CODED EXECUTE_RESPONSE on the wire. The two
      * non-conformances are asserted SEPARATELY because the section says they are "distinct
      * failures rather than one" — a single assertion could not tell -DDROP from -DBARECLOSE. */
     x = 0;
     do
     :: (x < NCAUSE) ->
          assert(!(refused[x] && wire == W_NOTHING));     /* NoSilentDrop */
          assert(!(refused[x] && wire == W_CLOSE));       /* NoBareCloseOnly */
          x++;
     :: else -> break
     od;
     /* §4.11: the cause table. */
     assert(!(refused[X_OVERSIZE]
              && (rcodeOf[X_OVERSIZE] != C_TOOLARGE || rstatOf[X_OVERSIZE] != 413)));
     assert(!(refused[X_HASH_MISMATCH]
              && (rcodeOf[X_HASH_MISMATCH] != C_HASHMM || rstatOf[X_HASH_MISMATCH] != 400)));
     assert(!(refused[X_CONNECT_AUTH]
              && (rcodeOf[X_CONNECT_AUTH] != C_AUTHFAIL || rstatOf[X_CONNECT_AUTH] != 401)));
     assert(!(refused[X_BAD_ROOT]
              && (rcodeOf[X_BAD_ROOT] != C_INVREQ || rstatOf[X_BAD_ROOT] != 400)));
     /* §4.11: "400 non_canonical_ecf is NOT conformant on the framing arm [MUST]."
      * VIOLATED under -DECFFRAMING. Asserted on its own — the cause table above deliberately
      * omits the framing row so this control breaks exactly one assertion. */
     assert(!(refused[X_FRAMING] && rcodeOf[X_FRAMING] == C_ECF));
     }
  od;
}
