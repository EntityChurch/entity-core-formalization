/*
 * bootstrap.pml — INDEPENDENT Promela re-encoding of V8 §6.9 Bootstrap.
 * Cross-check #B for the TLA+ `Bootstrap` model (tla/Bootstrap.tla).
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM §6.9's text — which three
 * handlers MUST exist, what "before any handler registration can occur" constrains, and what
 * the normative post-initialization observable state is — NOT by translating the .tla.
 *
 * WHY IT EXISTS. §6.9 showed in COVERAGE-MATRIX.md as a single-tool ("TLC-only") result
 * while nothing modeled it: both §6.9 citations in the repo were DISCLAIMERS in
 * tla/Register.tla's header — two sentences saying bootstrap handlers bypass registration
 * and are NOT modeled. The citation-derived coverage grid counted an out-of-scope
 * declaration as a claim. See COVERAGE-MATRIX.md section 3a-b.
 *
 * THE RULES UNDER TEST, verbatim from §6.9:
 *   "Three handlers MUST exist from system initialization, BEFORE ANY HANDLER REGISTRATION
 *    CAN OCCUR" — system/tree, system/handler, system/protocol/connect.
 *   "The observable state after initialization is normative: bootstrap handler manifests
 *    exist at their pattern paths, their types exist ..., their grants exist ..., interface
 *    entities exist ..., and DISPATCH RESOLVES THEM."
 *   "Connect | system/protocol/connect | Connection establishment — PRE-AUTHORIZED"
 *
 * THE HAZARD. §6.9's informative sequence puts "6. Create capability grants" before
 * "7. Build dispatch index". Publishing the index first — natural, since step 4 already
 * installed the manifests — makes a bootstrap handler dispatchable before its grant exists.
 * That is §6.2's "manifest without grant" hazard (register.pml's all-or-nothing) on the one
 * path that bypasses the §6.2 register lifecycle, which is why §6.9 needs its own model.
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)      grants before index; all three gated; connect pre-authorized — all hold.
 *   -DEARLYINDEX   index built from the step-4 manifests -> all-or-nothing VIOLATED
 *   -DGATEONE      registration admitted once system/handler is up, not all three ->
 *                  the "before any handler registration" precondition VIOLATED
 *   -DNOCONNGATE   connections served before system/protocol/connect exists -> VIOLATED
 *
 * Fidelity (5th wall): facet identity is shared with register.pml on purpose — the point is
 * that the SAME all-or-nothing property must hold on the bootstrap path. Facet byte content,
 * the type/grant entity structure and all crypto are abstracted. §6.9's optional fourth
 * handler (system/type, a SHOULD gated on the type-system spec's Level 2+) is not modeled;
 * the MUST is the three. That gating section carries no sigil for the same reason a
 * disclaimer must not: it would mint a citation for a section this model does not claim.
 As in the TLA+ model this is a structural model with no interleaving, so Spin's
 * contribution here is an independently-written enumerator agreeing on the verdicts, not
 * interleaving search.
 *
 * Build / run (from spin/, image entity-spin):
 *   safety: make verify MODEL=bootstrap [DEFS=-DEARLYINDEX]  (expect errors: 0 / assertion)
 */

/* §6.9's three MUST-exist handlers. */
#define H_TREE    0
#define H_HANDLER 1
#define H_CONNECT 2
#define NBOOT     3

/* Facet-set states, same abstraction as register.pml: the five §6.2 writes reduced to how
 * much of the handler exists. EARLY = manifest + iface only (what steps 4-5 leave behind). */
#define F_NONE  0
#define F_EARLY 1
#define F_FULL  2

byte facets[NBOOT];        /* how much of each bootstrap handler exists */
bool inIndex[NBOOT];       /* the §6.6 dispatch index */
bool registered = false;   /* a non-bootstrap handler registered through system/handler */
bool established = false;  /* a connection established through system/protocol/connect */

active proctype boot()
{
  byte h, i, j;

  do
  :: /* System initialization installs one bootstrap handler. */
     if
     :: (facets[H_TREE]    == F_NONE) -> h = H_TREE;
     :: (facets[H_HANDLER] == F_NONE) -> h = H_HANDLER;
     :: (facets[H_CONNECT] == F_NONE) -> h = H_CONNECT;
     fi;
     atomic {
#ifdef EARLYINDEX
       /* DEFECT: the index is built from the step-4 manifests, so the handler becomes
        * dispatchable before its step-6 grant exists. */
       facets[h] = F_EARLY; inIndex[h] = true;
#else
       /* §6.9 post-state: dispatchable only once every facet exists. */
       facets[h] = F_FULL; inIndex[h] = true;
#endif
     }

  :: /* The late grant/sig/types writes, in the early-index variant. */
     if
     :: (facets[H_TREE]    == F_EARLY) -> facets[H_TREE]    = F_FULL;
     :: (facets[H_HANDLER] == F_EARLY) -> facets[H_HANDLER] = F_FULL;
     :: (facets[H_CONNECT] == F_EARLY) -> facets[H_CONNECT] = F_FULL;
     fi;

  :: /* §6.9: "before any handler registration can occur".
      *
      * NB the whole precondition is ONE guard, not `(!registered) -> (index...) ->`. A
      * do-option's selectability is decided by its FIRST statement only, so a two-stage
      * guard commits to the option on `!registered` and then BLOCKS on the index test —
      * which Spin reports as an invalid end state, not as the assertion this option exists
      * to reach. Written that way, -DGATEONE and -DNOCONNGATE both "failed" without ever
      * touching their defect: a control failing for the wrong reason, which `errors: 1`
      * cannot distinguish from one failing for the right one (D13). */
#ifdef GATEONE
     /* DEFECT: only the handler doing the work is checked. It can be dispatchable while
      * system/tree — which the registration writes to — is still installing. */
     (!registered && inIndex[H_HANDLER]) -> registered = true;
#else
     (!registered && inIndex[H_TREE] && inIndex[H_HANDLER] && inIndex[H_CONNECT]) ->
       registered = true;
#endif

  :: /* §6.9: system/protocol/connect is pre-authorized — present from initialization. */
#ifdef NOCONNGATE
     (!established) -> established = true;    /* DEFECT: served before the handler exists */
#else
     (!established && inIndex[H_CONNECT]) -> established = true;
#endif

  :: /* ---- the properties ---- */
     /* §6.9 post-state: nothing is dispatch-visible before all of its facets exist. This is
      * §6.2's all-or-nothing on the path that BYPASSES the register lifecycle. */
     i = 0;
     do
     :: (i < NBOOT) -> assert(!(inIndex[i] && facets[i] != F_FULL)); i++;
     :: else -> break
     od;
     /* §6.9: all THREE must exist before any registration — not just the one serving it. */
     j = 0;
     do
     :: (j < NBOOT) -> assert(!(registered && facets[j] != F_FULL)); j++;
     :: else -> break
     od;
     /* §6.9: connect is pre-authorized. */
     assert(!(established && facets[H_CONNECT] != F_FULL));
  od;
}
