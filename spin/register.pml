/*
 * register.pml — INDEPENDENT Promela re-encoding of the V7 §6.1 / §6.2 / §6.6 handler
 * registration + index↔tree coherence design. Cross-check #B for the TLA+ `Register` model
 * (tla/Register.tla).
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): written FROM the V7 §6.2 design — two
 * registrars installing/removing handlers concurrently via the register/unregister lifecycle,
 * while the §6.6 dispatch index must stay coherent with the tree (the source of truth) at every
 * observable state — NOT translated from the .tla.
 *
 * Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the five §6.2 writes are abstracted to a
 * single tree "fullness" facet count (empty / partial / full); their byte content, the grant
 * attenuation chain (Lean), and grant-signature crypto (Tamarin) are abstracted. What is modeled
 * is presence/atomicity w.r.t. dispatch. The §6.6 dispatch index is a cache (`disp`); the
 * tree-walk it must equal is captured by `tree[h] == FULL`. Same abstraction the TLA+ model makes.
 *
 * NB (handoff section 6): IndexMatchesTree / atomicity are *relational/structural* — the genuinely
 * awkward-in-Spin case (Alloy would model the index↔tree-walk relation natively). With the cache
 * abstraction the coherence reduces to the per-handler bi-implication `disp[h] <=> tree[h]==FULL`,
 * which Spin checks cleanly as a state assertion after every atomic mutation; a full relational
 * treatment (Alloy) remains an optional Track-C follow-on (see docs/NEXT-PHASES.md).
 *
 * PROPERTIES checked:
 *   SAFETY   NoPartialResidue     tree[h] in {empty, full}                  (§6.2 atomicity)
 *   SAFETY   RegisterAllOrNothing disp[h] => tree[h]==full                  (§6.2 all-or-nothing)
 *   SAFETY   IndexMatchesTree     disp[h] <=> tree[h]==full                 (§6.6 cache coherence)
 *   SAFETY   NoUserAtSystem       user handler never present at system/*    (§6.2 guard)
 *   LIVENESS RegisterSettles      every registrar reaches gone | rejected   (§6.2 progress)
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)      fix: all properties hold.
 *   -DNOATOMIC     Atomic=FALSE — register publishes to the index with only manifest+iface
 *                  written (grant/sig/types land later) -> a half-built handler is dispatch-
 *                  visible: NoPartialResidue / RegisterAllOrNothing / IndexMatchesTree VIOLATED
 *                  (TLA+ RegisterAtomicBug).
 *   -DNOSYSGUARD   GuardSystem=FALSE — a user handler registers at a system/* path ->
 *                  NoUserAtSystem VIOLATED (TLA+ RegisterSysGuardBug).
 *   -DWEDGE        WedgeReg=TRUE — a live handler never tears down/settles -> RegisterSettles
 *                  (liveness) FAILS; safety still holds (TLA+ RegisterWedgeBug).
 *
 * Build/run (from spin/): safety compiles the ltl claim OUT (-DNOCLAIM); liveness runs -a -f:
 *   safety:   make verify MODEL=register [DEFS=-DNOATOMIC|-DNOSYSGUARD]  (expect errors: 0 / assertion)
 *   liveness: make ltl    MODEL=register [DEFS=-DWEDGE]                  (expect errors: 0 / accept cycle)
 */

#define hLocal 0      /* user handler at a domain path (legitimate) */
#define hSys   1      /* user handler at a system/* path (must be rejected, §6.2) */

/* tree "fullness" (§6.2 five writes abstracted to a facet count): empty | partial | full. */
#define EMPTY    0
#define PARTIAL  1     /* only manifest+iface written — dispatch-visible without its grant */
#define FULL     5     /* all five §6.2 facets present -> §6.6 dispatchable */

/* SEQUENCED WRITES (0.8.3-dev) — retiring a near-tautological positive.
 *
 * Until 0.8.3 both this model and the TLA+ one wrote all five §6.2 facets in ONE step, which
 * made `tree[h] in {EMPTY, FULL}` unfalsifiable: it restated the assignment. All the teeth
 * were on the control side (../docs/PROPERTIES.md §C.4).
 *
 * With sequencing the four non-committing facets land ONE PER TRANSITION, so the tree really
 * does pass through partial counts, and what keeps the §6.2/§6.6 invariants true is a
 * DISCIPLINE: the fifth write and the index publish are one atomic commit. `NoPartialResidue`
 * is therefore rescoped to SETTLED handlers — a partial tree in flight is the model working,
 * a partial tree at rest is the defect. */
#define WRITING       7
#define UNWRITING     8
#define settled(h)    (rphase[h] != WRITING && rphase[h] != UNWRITING && \
                       rphase[h] != REGISTERING && rphase[h] != UNREGISTERING)

/* lifecycle phases (§6.2). */
#define INIT          0
#define REGISTERING   1
#define LIVE          2
#define UNREGISTERING 3
#define GONE          4
#define REJECTED      5
#define WEDGED        6

/* §6.2 system-path guard switch (compile-time). */
#ifdef NOSYSGUARD
  #define GUARD false
#else
  #define GUARD true
#endif

/* hSys is the user-at-system handler the guard must reject (Who=user, Where=system). */
#define isSysUser(h) (h == hSys)

byte tree[2]   = EMPTY;   /* §6.1 source of truth: facet fullness per handler path */
bool disp[2]   = false;   /* §6.6 in-memory dispatch index (cache of dispatchable handlers) */
byte rphase[2] = INIT;

/* §6.2/§6.6 invariants, checked at every observable (post-mutation) state — global over both
 * handlers, so asserting after any single atomic mutation validates the new state. */
inline checkInv() {
  /* NoPartialResidue (§6.2): a SETTLED handler is fully present or fully absent. Scoped to
   * settled phases because sequenced writes make the in-flight partial states real — the
   * property §6.2 states is that a handler never comes to REST half-built. */
  assert(!settled(hLocal) || tree[hLocal] == EMPTY || tree[hLocal] == FULL);
  assert(!settled(hSys)   || tree[hSys]   == EMPTY || tree[hSys]   == FULL);
  /* RegisterAllOrNothing (§6.2): nothing dispatch-visible is missing its grant. */
  assert(!disp[hLocal] || tree[hLocal] == FULL);
  assert(!disp[hSys]   || tree[hSys]   == FULL);
  /* IndexMatchesTree (§6.6): the index equals the tree-walk — no stale +/- entries. */
  assert(disp[hLocal] == (tree[hLocal] == FULL));
  assert(disp[hSys]   == (tree[hSys]   == FULL));
  /* NoUserAtSystem (§6.2): the user-at-system handler is never present. */
  assert(tree[hSys] == EMPTY);
}

/* Each handler's registrar runs its register -> unregister lifecycle concurrently with the other. */
proctype reg(byte h) {
  /* RReg (§6.2): guard first (user MUST NOT register at system/*), then the writes. */
  if
  :: (GUARD && isSysUser(h)) ->
       atomic { rphase[h] = REJECTED; checkInv() }            /* §6.2 rejected — no tree writes */
  :: else ->
#ifdef NOATOMIC
       /* NEG CONTROL: publish to the index with only manifest+iface; grant/sig/types land in
        * RFinish -> the handler is dispatch-visible without its grant. */
       atomic { tree[h] = PARTIAL; disp[h] = true; rphase[h] = REGISTERING; checkInv() }
#else
       /* §6.2 SEQUENCED: the four non-committing facets land one per transition, each its own
        * observable state, with the handler deliberately NOT in the index throughout. */
       atomic { rphase[h] = WRITING; checkInv() };
       do
       :: (tree[h] < FULL - 1) -> atomic { tree[h]++; checkInv() }
       :: (tree[h] == FULL - 1) -> break
       od;
       /* THE COMMIT POINT (§6.2/§6.6): final write + index publish, atomic w.r.t. dispatch.
        * This single step is what makes RegisterAllOrNothing and IndexMatchesTree hold; split
        * it and both fail, which is exactly the -DNOATOMIC control above. */
       atomic { tree[h] = FULL; disp[h] = true; rphase[h] = LIVE; checkInv() }
#endif
  fi;
  /* RFinish: the late grant/sig/types writes land (only in the non-atomic path). */
  if
  :: rphase[h] == REGISTERING ->
       atomic { tree[h] = FULL; rphase[h] = LIVE; checkInv() }
  :: else -> skip
  fi;
  /* RUnreg (§6.2): unregister reverses all five; atomic w.r.t. dispatch (mirror of register). */
  if
  :: rphase[h] == LIVE ->
#ifdef WEDGE
       atomic { rphase[h] = WEDGED; checkInv() }              /* LIVENESS NEG CONTROL: never settles */
#elif defined(NOATOMIC)
       /* NEG CONTROL: drop grant/sig first but leave dispatch-visible -> stale-positive. */
       atomic { tree[h] = PARTIAL; rphase[h] = UNREGISTERING; checkInv() }
#else
       /* DECOMMIT (§6.2), the exact mirror of the commit: leaving the index and dropping the
        * first facet are one atomic step. Teardown is where the stale-POSITIVE hazard lives —
        * dispatching a handler whose grant is already gone — so the order is reversed. */
       atomic { tree[h] = FULL - 1; disp[h] = false; rphase[h] = UNWRITING; checkInv() };
       do
       :: (tree[h] > EMPTY) -> atomic { tree[h]--; checkInv() }
       :: (tree[h] == EMPTY) -> break
       od;
       atomic { rphase[h] = GONE; checkInv() }
#endif
  :: else -> skip
  fi;
  /* RUFinish: complete the teardown (only in the non-atomic path). */
  if
  :: rphase[h] == UNREGISTERING ->
       atomic { tree[h] = EMPTY; disp[h] = false; rphase[h] = GONE; checkInv() }
  :: else -> skip
  fi
}

init {
  atomic { run reg(hLocal); run reg(hSys) }
}

/* LIVENESS §6.2: every registration settles — each handler reaches a terminal outcome (torn
 * down, or rejected by the system-path guard) rather than hanging mid-lifecycle. Needs weak
 * fairness (pan -a -f). Holds in the fix; under -DWEDGE the live handler parks in "wedged" and
 * never settles -> claim violated. Mirrors TLA+ RegisterSettles. */
#define settledLocal (rphase[hLocal] == GONE || rphase[hLocal] == REJECTED)
#define settledSys   (rphase[hSys]   == GONE || rphase[hSys]   == REJECTED)
ltl RegisterSettles { <> settledLocal && <> settledSys }
