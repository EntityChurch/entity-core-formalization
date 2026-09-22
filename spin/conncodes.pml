/*
 * conncodes.pml — INDEPENDENT Promela re-encoding of V8 §4.7 Connection Error Codes.
 * Cross-check #B for the TLA+ `ConnCodes` model (tla/ConnCodes.tla).
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM the §4.7 table and the
 * §4.6 numbered steps — which failure lands in which row, which code that row emits, and
 * which status that code carries — NOT by translating the .tla.
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
 * Two ways to be wrong, both named by the spec, hence exactly two ordinary controls.
 *
 * THE FINDING (routed to entity-core-protocol; see ../docs/PROPERTIES.md §D). §4.7's table
 * gives TWO DIFFERENT normative answers for the same input — an `authenticate` arriving
 * before any hello nonce was issued:
 *   §4.6 step 1: "... or an `authenticate` received before any hello nonce was issued —
 *     MUST be rejected with status 401 `invalid_nonce`."
 *   §4.7 ROW 6:  "Nonce mismatch / absent / pre-hello (§4.6 step 1) | `invalid_nonce` | 401"
 *     — that is §4.6 step 1, restated inside the table. It is transcribed verbatim as the
 *     R6_NONCE comment below.
 *   §4.7 ROW 10: "Out-of-order operation (e.g., authenticate before hello) |
 *     `connection_sequence_error` | 400".
 * Rows 6 and 10 are in the SAME TABLE. All are MUSTs, they disagree on the code AND the
 * status class, and §4.7's own preamble makes each reading non-conformant by the other's
 * lights — so "follow §4.7" is not a well-defined position. -DSEQREADING runs row 10's
 * reading; the assertion it breaks is §4.6 step 1 / row 6 transcribed. That "defect" is a
 * conformant reading of the spec, not something injected here — which is why it is called
 * out separately from the two real controls.
 *
 * (Through 2026-08-30 this block said "§4.6 step 1 vs §4.7 row 10" and missed row 6 —
 * whose text was sitting four lines below, on R6_NONCE. The weaker framing points at the
 * wrong remedy: row 6 already defers to §4.6 by citation and the contradiction survives
 * that, so the defect is row 10's parenthetical alone.)
 *
 * VARIANTS (select via -D<NAME>):
 *   (default)     §4.7 rows distinct, statuses per the table, §4.6 step 1 honored — all hold.
 *   -DCOLLAPSE    every reject emits connection_sequence_error -> distinctness VIOLATED
 *   -DWRONGSTATUS right codes, uniform 400 -> status contract VIOLATED
 *   -DSEQREADING  §4.7 row 10's reading of a pre-hello auth -> §4.6 step 1 VIOLATED (THE FINDING)
 *
 * Fidelity (5th wall): §4.6 steps 0/2/3 (key-type support, proof-of-possession, identity
 * binding) and their codes are the §7.3 crypto wall — Tamarin's (tamarin/Binding.*), not
 * modeled here. §4.7's four version/key-type negotiation codes are settled before any phase
 * this model has, and naming their own sections would mint a citation for a section this
 * model makes no claim about (COVERAGE-MATRIX.md section 3b).
 * What is encoded is the three rows a connect phase machine can reach. As in the
 * TLA+ model, the content is the REACHABILITY of each row plus the code/status assignment;
 * this is stated rather than implied (docs/PROPERTIES.md §C).
 *
 * Build / run (from spin/, image entity-spin):
 *   safety: make verify MODEL=conncodes [DEFS=-DCOLLAPSE]   (expect errors: 0 / assertion)
 */

/* §4.7 table rows this phase machine can reach (row ids positional in the table). */
#define R_NONE     0
#define R6_NONCE   1       /* Nonce mismatch / absent / pre-hello (§4.6 step 1) */
#define R9_ALREADY 2       /* Connection already established */
#define R10_SEQ    3       /* Out-of-order operation */

/* §4.7 reason codes. */
#define C_NONE      0
#define C_NONCE     1      /* invalid_nonce */
#define C_ALREADY   2      /* connection_already_established */
#define C_SEQ       3      /* connection_sequence_error */

/* §4.1 connection phases. */
#define P_NEW    0
#define P_HELLO  1
#define P_ESTAB  2

/* Reject triggers — distinct FAILURES, which §4.7 maps onto rows. */
#define T_SECOND_HELLO   0
#define T_HELLO_ESTAB    1
#define T_BAD_NONCE      2
#define T_PREHELLO_AUTH  3
#define T_AUTH_ESTAB     4
#define NTRIG            5

/* Which §4.7 row does a pre-hello `authenticate` fall in? THE CONTESTED CELL. */
#ifdef SEQREADING
  /* §4.7 table row 10's reading: "out-of-order operation". */
  #define PREHELLO_ROW R10_SEQ
#else
  /* §4.6 step 1's explicit reading: 401 invalid_nonce. */
  #define PREHELLO_ROW R6_NONCE
#endif

byte phase = P_NEW;
bool fired[NTRIG];         /* which reject paths have actually run */
byte rowOf[NTRIG];         /* the §4.7 row each fired trigger landed in */
byte codeOf[NTRIG];        /* the code it emitted */
short statOf[NTRIG];       /* the status it emitted */

/* §4.7: row -> code. COLLAPSE is the non-conformance §4.7 names in its own preamble. */
inline code_for(r, out) {
#ifdef COLLAPSE
  out = C_SEQ;             /* DEFECT: "collapses several of these to one code" */
#else
  if
  :: (r == R6_NONCE)   -> out = C_NONCE;
  :: (r == R9_ALREADY) -> out = C_ALREADY;
  :: else              -> out = C_SEQ;
  fi;
#endif
}

/* §4.7: the NORMATIVE status per code, transcribed from the table. This is what emitted
 * statuses are CHECKED AGAINST, so it must not vary with any variant macro. */
inline norm_status(c, out) {
  if
  :: (c == C_NONCE)   -> out = 401;
  :: (c == C_ALREADY) -> out = 409;
  :: else             -> out = 400;
  fi;
}

/* What the responder actually emits. */
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

active proctype responder()
{
  byte i, j; short want;

  do
  :: /* §4.1 hello */
     if
     :: (phase == P_NEW)   -> phase = P_HELLO;                    /* accepted, no code */
     :: (phase == P_HELLO) -> emit(T_SECOND_HELLO, R10_SEQ);
     :: (phase == P_ESTAB) -> emit(T_HELLO_ESTAB, R9_ALREADY);
     fi;
  :: /* §4.6 authenticate */
     if
     :: (phase == P_HELLO) -> phase = P_ESTAB;                    /* good nonce, no code */
     :: (phase == P_HELLO) -> emit(T_BAD_NONCE, R6_NONCE);
     :: (phase == P_NEW)   -> emit(T_PREHELLO_AUTH, PREHELLO_ROW); /* CONTESTED */
     :: (phase == P_ESTAB) -> emit(T_AUTH_ESTAB, R9_ALREADY);
     fi;
  :: /* ---- the properties ---- */
     /* §4.7: two failures the table puts in DIFFERENT rows MUST NOT share a code. The
      * quantifier is over ROWS, not triggers: row 6 deliberately covers "nonce mismatch /
      * absent / pre-hello" as one row, so two triggers sharing a row may share a code. */
     i = 0;
     do
     :: (i < NTRIG) ->
          j = 0;
          do
          :: (j < NTRIG) ->
               assert(!(fired[i] && fired[j] && codeOf[i] == codeOf[j]
                        && rowOf[i] != rowOf[j]));
               j++;
          :: else -> break
          od;
          /* §4.7: the status for each code is fixed by the table. */
          norm_status(codeOf[i], want);
          assert(!(fired[i] && statOf[i] != want));
          i++;
     :: else -> break
     od;
     /* §4.6 step 1, transcribed: a pre-hello authenticate MUST be 401 invalid_nonce.
      * VIOLATED under -DSEQREADING. That violation is THE FINDING, not an injected bug. */
     assert(!(fired[T_PREHELLO_AUTH] && codeOf[T_PREHELLO_AUTH] != C_NONCE));
  od;
}
