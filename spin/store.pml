/*
 * store.pml — INDEPENDENT Promela re-encoding of the V7 §4.8 / §4.9 / §4.10
 * store-safety / resilience / admission design. Cross-check #B for the TLA+
 * `Store` model (tla/Store.tla).
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): this is written FROM the V7
 * §4.8-§4.10 design — a single peer dispatching NReq concurrent per-request
 * activities against one shared content store behind an admission gate — NOT by
 * translating the .tla line-by-line. The whole point of the cross-check is an
 * independent formalism (Promela processes + atomic guards) reaching the SAME
 * verdict TLA+ did, so that a shared transcription error is unlikely to survive
 * in both.
 *
 * Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the verdict / attenuation
 * arithmetic and crypto are abstracted (Lean / Tamarin own them). Payload size
 * (§4.10a) and chain depth (§4.10b) are symbolic over/under-limit choices — the
 * normative contract is "enforce a finite declared bound and reject over-limit
 * cleanly," not the 16 MiB / 64 numbers, so symbolic ok/over is the faithful
 * abstraction (same call the TLA+ model makes). The store data-race (§4.8) is
 * modeled as concurrent occupancy of the write critical section (writers > 1);
 * the single-writer discipline is the entry gate `atomic { writers==0; ... }`.
 *
 * PROPERTIES checked:
 *   SAFETY   StoreRaceFree   writers <= 1 always (§4.8) — assert in crit section.
 *   SAFETY   ResourceBounded pending <= MaxPending && store <= MaxStore
 *                            (§4.9b / §4.10) — assert at admission + after write.
 *   LIVENESS Responsive      admitted ~> responded (§4.9a/c) — LTL never claim.
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)      fix: all three properties hold.
 *   -DNOSERIALIZE  drop the single-writer entry gate  -> StoreRaceFree VIOLATED
 *                  (matches TLA+ Serialize = FALSE).
 *   -DNOADMIT      drop the admission bound (always admit) -> ResourceBounded
 *                  VIOLATED (matches TLA+ Admit = FALSE).
 *   -DSILENTDROP   an admitted req in WCommit may leave the crit section without
 *                  responding and leak its pending slot -> Responsive (liveness)
 *                  FAILS (matches TLA+ SilentDrop = TRUE).
 *
 * Build / run (from spin/, image entity-spin):
 *   safety:    spin -a [DEFS] store.pml
 *              gcc -O2 -DNOCLAIM -o pan pan.c && ./pan           (expect errors: 0 / violation)
 *   liveness:  spin -a [DEFS] store.pml
 *              gcc -O2 -o pan pan.c && ./pan -a -f               (expect errors: 0 / accept cycle)
 *   NOTE: the ltl{} never claim disables invalid-end / assert detection in the
 *   default pan run, so the safety build compiles the claim OUT (-DNOCLAIM) and
 *   the liveness build runs it with -a -f (weak fairness).
 */

#define NReq        3      /* concurrent per-request dispatch activities (small -> exhaustive) */
#define MaxPending  2      /* §4.9(b)/§4.10: admitted-not-yet-responded bound */
#define MaxStore    1      /* §4.8/§4.9(b): live-key bound (single shared key "k") */

/* Shared peer state (§4.8 content store + §4.9 in-flight accounting). */
byte store   = 0;          /* live-key count of the shared store (one key "k") */
byte writers = 0;          /* requests currently inside the write critical section */
byte pending = 0;          /* §4.9(c): admitted requests not yet responded */

/* Per-request lifecycle observable for the liveness claim:
 *   0 new   1 rej413   2 rej400   3 ref503   4 admitted   5 writing
 *   6 responded   7 dropped (SILENTDROP neg control only) */
byte rstate[NReq] = 0;

/* ---- LTL helper macros (§4.9a/c: admitted work eventually responds) ----
 * Responsive: for each request, [](admitted -> <>responded). Because rstate is
 * monotone toward a terminal state and "admitted" is left only by becoming
 * "writing"->"responded" (or, in the defect, "dropped"), this captures
 * deliver-or-signal. We check request 0 as the representative concurrent
 * activity; symmetry of the processes makes per-request coverage equivalent and
 * keeps the claim small. */
#define adm0   (rstate[0] == 4)
#define resp0  (rstate[0] == 6)

ltl Responsive { [] (adm0 -> <> resp0) }

/*
 * One independent concurrent dispatch activity (§4.8: inbound frames processed
 * concurrently). A possibly-adversarial caller chooses payload size + depth.
 */
proctype req(byte id)
{
  bool payload_over;   /* §4.10(a): wire size exceeds configured max */
  bool depth_over;     /* §4.10(b): chain depth exceeds configured max */

  /* Pick: caller offers some payload size and chain depth. */
  if :: payload_over = true :: payload_over = false fi;
  if :: depth_over   = true :: depth_over   = false fi;

  /* AdmitStep (§4.10 admission, in order): over-size -> 413; else over-depth ->
   * 400; else back-pressure when in-flight bound reached -> 503; else admit. The
   * admission decision must be a single atomic step so pending++ races cannot
   * overshoot the bound (the gate is the whole point of §4.9b). */
  atomic {
    if
    :: payload_over ->
         rstate[id] = 1;                         /* §4.10(a) 413 payload_too_large */
    :: else ->
       if
       :: depth_over ->
            rstate[id] = 2;                       /* §4.10(b) 400 chain_depth_exceeded */
       :: else ->
#ifdef NOADMIT
          /* NEG CONTROL (TLA+ Admit=FALSE): no admission bound — always admit. */
          rstate[id] = 4;
          pending++;                              /* unbounded -> ResourceBounded breaks */
#else
          if
          :: pending >= MaxPending ->
               rstate[id] = 3;                    /* §4.9(b)/§4.10(c) clean 503 refusal */
          :: else ->
               rstate[id] = 4;                    /* §4.9(c): admitted -> owes a response */
               pending++;
          fi;
#endif
       fi;
    fi;
    /* §4.9(b): the admission gate is exactly what keeps pending bounded. */
    assert(pending <= MaxPending);
  }

  /* WBegin (§4.8): admitted requests enter the write critical section under the
   * single-writer discipline. The fix gates entry on an empty section; the neg
   * control drops the gate so two writers can occupy it at once. */
  if
  :: rstate[id] == 4 ->
#ifdef NOSERIALIZE
       /* NEG CONTROL (TLA+ Serialize=FALSE): unsynchronized — no entry gate.
        * writers++ is still atomic (a read-modify-write), but with no await two
        * requests can both be inside the section -> writers reaches 2. */
       atomic { writers++; rstate[id] = 5; }
#else
       atomic { writers == 0; writers++; rstate[id] = 5; }  /* await empty, then enter */
#endif
  :: else -> skip
  fi;

  /* WCommit: mutate the bounded store, respond, leave the crit section. §4.9(c):
   * every admitted request is delivered (responded), never silently dropped. */
  if
  :: rstate[id] == 5 ->
       /* §4.8 store-safety lives here: assert single-writer occupancy while in
        * the critical section. writers > 1 == data race == crash (§4.9d). */
       assert(writers <= 1);
#ifdef SILENTDROP
       /* LIVENESS NEG CONTROL (TLA+ SilentDrop=TRUE): the request may instead be
        * silently dropped — it leaves the crit section but never responds and its
        * pending slot is leaked (the "admit and discard" the spec calls the
        * sharpest single violation). */
       if
       :: atomic {
            store = (store < MaxStore -> store + 1 : store);  /* idempotent on key "k" */
            writers--; pending--; rstate[id] = 6;             /* responded */
            assert(store <= MaxStore);
          }
       :: atomic {
            writers--; rstate[id] = 7;                        /* dropped: no response, slot leaked */
          }
       fi;
#else
       atomic {
         /* store holds a single shared key "k": writing it is idempotent, so the
          * count never exceeds MaxStore (§4.9b live-key bound). */
         store = (store < MaxStore -> store + 1 : store);
         writers--;
         pending--;
         rstate[id] = 6;                                      /* §4.9(c) responded */
         assert(store <= MaxStore);                           /* §4.9(b) store bound */
       }
#endif
  :: else -> skip
  fi;
}

init {
  atomic {
    byte i = 0;
    do
    :: i < NReq -> run req(i); i++
    :: else -> break
    od;
  }
}
