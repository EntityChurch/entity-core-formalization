/*
 * emit.pml — INDEPENDENT Promela re-encoding of the V7 §6.10 emit pathway. Cross-check #B
 * for the TLA+ `Emit` model (tla/Emit.tla).
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): written FROM the V7 §6.10 design — the
 * emit primitive as the atomic state crossing of up to two steps (Store: write entity to the
 * content store; Bind: update the tree binding at a path), each firing an event ONLY when it
 * does real work — NOT translated from the .tla. An independent paradigm reaching the SAME
 * verdict makes a shared transcription error unlikely.
 *
 * Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): entity content / hashing / CBOR are abstracted
 * to opaque hash tokens (type system + conformance own them). Modeled: store-membership and
 * binding state transitions and the event-firing DECISIONS they drive. Core-only scope (§6.10
 * final para): a core peer's emit has no consumers, so cascade/convergence is out of scope.
 *
 * PROPERTIES checked:
 *   SAFETY   EventIffRealWork  (sEvt == hashNew) && (tEvt == changed)          (§6.10)
 *   SAFETY   NoEventOnNoop     re-put / re-bind fires no event                 (§6.10)
 *   SAFETY   EventTypeCorrect  tEvt => etype == DerivedType(prev,new); marker  (§6.10 + v7.74 B2)
 *                              binds "modified", not "deleted"
 *   LIVENESS EmitTerminates    the emit pathway always completes its ops       (§6.10)
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)     fix: all properties hold.
 *   -DEMITFIRE    Fire=FALSE — every step fires an event unconditionally (event on a re-put /
 *                 re-bind no-op) -> EventIffRealWork / NoEventOnNoop VIOLATED (TLA+ EmitFireBug).
 *   -DEMITMARKER  MarkerDeletes=TRUE — a bind to a deletion-marker fires event_type "deleted"
 *                 instead of "modified" -> EventTypeCorrect VIOLATED (TLA+ EmitMarkerBug).
 *   -DEMITSTALL   StallEmit=TRUE — emit may halt before completing its ops -> EmitTerminates
 *                 (liveness) FAILS (TLA+ EmitStallBug).
 *
 * Build/run (from spin/): safety compiles the ltl claim OUT (-DNOCLAIM); liveness runs -a -f:
 *   safety:   make verify MODEL=emit [DEFS=-DEMITFIRE|-DEMITMARKER]   (expect errors: 0 / assertion)
 *   liveness: make ltl    MODEL=emit [DEFS=-DEMITSTALL]               (expect errors: 0 / accept cycle)
 */

#define MAXOPS  3

/* Hash tokens + the NULL binding (§6.10 Store/Bind domains). "marker" = a deletion-marker entity. */
#define H1      0
#define H2      1
#define MARKER  2
#define NULLB   3      /* the NULL binding (no hash bound at the path) */

/* event_type values (§6.10 derivation). */
#define NONE      0
#define CREATED   1
#define MODIFIED  2
#define DELETED   3

/* §6.10 Fire switch + v7.74 B2 MarkerDeletes switch (compile-time). */
#ifdef EMITFIRE
  #define FIRE false
#else
  #define FIRE true
#endif
#ifdef EMITMARKER
  #define MARKERDEL true
#else
  #define MARKERDEL false
#endif

/* §6.10 event_type derivation: deleted if new is NULL; created if prev was NULL; else modified. */
#define derived(prev, nw) ( (nw == NULLB) -> DELETED : ( (prev == NULLB) -> CREATED : MODIFIED ) )

bool present[3] = false;   /* content store: is hash h present? (§6.10 Store step domain) */
byte bound = NULLB;        /* tree binding at the path (§6.10 Bind step domain): a hash or NULL */
byte ops = 0;
bool halted = false;       /* liveness neg control: emit halted early */

/* ghost decision vars recording the most recent step's emit decision, for the iff-invariants. */
bool sEvt = false;         /* did the Store step fire a content-store event this step? */
bool tEvt = false;         /* did the Bind step fire a tree-change event this step? */
byte etype = NONE;         /* the event_type the Bind step would carry */
bool hashNew = false;      /* (pre-state) was the stored hash new to the store? */
bool changed = false;      /* (pre-state) did the binding at the path change? */
byte lastPrev = NULLB;     /* prev binding of the most recent Bind */
byte lastNew  = NULLB;     /* new binding of the most recent Bind */

/* §6.10: event fires iff real work; no event on a no-op; event_type matches the derivation. */
inline checkInv() {
  assert( (sEvt == hashNew) && (tEvt == changed) );
  /* NoEventOnNoop: (~hashNew => ~sEvt) /\ (~changed => ~tEvt), i.e. sEvt=>hashNew & tEvt=>changed. */
  assert( (hashNew || !sEvt) && (changed || !tEvt) );
  assert( !tEvt || (etype == derived(lastPrev, lastNew)) );
}

/* §6.10 Store step only (content_store.put): content-store event iff the hash is new. */
inline cput(h) {
  hashNew  = !present[h];
  sEvt     = (FIRE -> (!present[h]) : true);
  changed  = false;
  tEvt     = false;
  etype    = NONE;
  lastPrev = bound;
  lastNew  = bound;
  present[h] = true;
  ops++;
  checkInv();
}

/* §6.10 Store then Bind step (tree_put): content-store event iff hash new; tree-change event iff
 * binding changed; event_type per derivation (marker binds "modified", not "deleted"). */
inline tput(h) {
  hashNew  = !present[h];
  changed  = (bound != h);
  sEvt     = (FIRE -> (!present[h]) : true);
  tEvt     = (FIRE -> (bound != h)  : true);
  etype    = ( (MARKERDEL && (h == MARKER)) -> DELETED : derived(bound, h) );
  lastPrev = bound;
  lastNew  = h;
  present[h] = true;
  bound = h;
  ops++;
  checkInv();
}

/* §6.10 Bind to null (tree:delete / operational unbind): event_type "deleted". */
inline tdel() {
  hashNew  = false;
  changed  = (bound != NULLB);
  sEvt     = false;
  tEvt     = (FIRE -> (bound != NULLB) : true);
  etype    = derived(bound, NULLB);
  lastPrev = bound;
  lastNew  = NULLB;
  bound = NULLB;
  ops++;
  checkInv();
}

proctype emitter() {
  do
  :: (ops < MAXOPS && !halted) ->
       if
       :: atomic { cput(H1) }
       :: atomic { cput(H2) }
       :: atomic { cput(MARKER) }
       :: atomic { tput(H1) }
       :: atomic { tput(H2) }
       :: atomic { tput(MARKER) }
       :: atomic { tdel() }
#ifdef EMITSTALL
       :: atomic { halted = true }   /* LIVENESS NEG CONTROL: halt before completing the ops */
#endif
       fi
  :: else -> break
  od
}

init { run emitter() }

/* LIVENESS §6.10: the emit pathway always completes its work (a core-only peer has no consumers,
 * so there is no cascade obligation — this just confirms emit does not wedge). Needs weak
 * fairness (pan -a -f). Holds in the fix; under -DEMITSTALL emit can halt early so ops never
 * reaches MAXOPS -> claim violated. Mirrors TLA+ EmitTerminates. */
#define alldone (ops == MAXOPS)
ltl EmitTerminates { <> alldone }
