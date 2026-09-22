/*
 * core.pml — INDEPENDENT Promela re-encoding of the COMPOSED multi-peer Core model.
 * Cross-check #B for the TLA+ `Core` model (tla/Core.tla).
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM the composed design — two
 * peers running connection lifecycle (§4.1-4.7), reentrant cross-peer dispatch (§6.5/§6.11
 * incl. (a′) frame-write atomicity), bounded store writes from handlers (§4.8/§4.9) and a
 * revocation/verdict gate (§5.1/§5.10/§6.5) CONCURRENTLY and bidirectionally — NOT by
 * translating the .tla.
 *
 * WHY THIS EXISTS. Until the 0.8.2 audit, `Core` was the ONLY module with single-tool
 * coverage of the whole-protocol composition: TLC alone, no independent re-encoding and no
 * unbounded proof. That is the worst place in the repo to have it, because `Core` is
 * precisely where the CROSS-SUBSYSTEM interleavings live — revoke during reentry, dispatch
 * before establishment, symmetric bidirectional reentry — which no standalone module can
 * exhibit and therefore no other model corroborates. An independent encoding of the
 * composition is the corroboration that was missing.
 *
 * PROPERTIES checked:
 *   SAFETY   DispatchNeedsEstablished §4.2 no dispatch before the connection is established
 *   SAFETY   ServeNeedsEstablished    §6.5 no handler entry before establishment
 *   SAFETY   NoServeWhenRevoked       §5.1/§6.8 no store write under an observed revocation
 *   SAFETY   FramesNotInterleaved     §6.11(a′) two frames' bytes never interleave
 *   LIVENESS EventuallyResolved       §4.9(a) every dispatched request resolves (Class-G)
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)        all six hold.
 *   -DSERIALIZED     §6.11(a) write lock held across send+recv -> Class-G DEADLOCK
 *                    (invalid end state), and EventuallyResolved fails under -a -f.
 *   -DNOATOMICFRAME  §6.11(a′) dropped -> FramesNotInterleaved VIOLATED, no deadlock.
 *   -DNOESTABGATE    §4.2 establishment gate dropped -> DispatchNeedsEstablished VIOLATED.
 *   -DNOREVGATE      §5.1 revocation gate dropped -> NoServeWhenRevoked VIOLATED.
 *
 * Fidelity (5th wall): each subsystem is its minimal composed essence — the handshake is the
 * established-precondition; the verdict is the opaque "not revoked" gate (the structural
 * chain verdict is Lean's, and revocation OBSERVATION/convergence is revoke.pml's); the store
 * write is a bounded counter. Per-subsystem teeth live in the standalone models; what THIS
 * model owns is the composition.
 *
 * Build / run (from spin/, image entity-spin):
 *   safety:   make verify MODEL=core [DEFS=-DSERIALIZED]
 *   liveness: make ltl    MODEL=core
 */

#define A 0
#define B 1
#define other(p)  (1 - p)

/* Per-peer pooled-connection write lock (§6.11(a)/(a′)) — tracks the OWNER, because a writer
 * releases only a lock it holds (see the same note in reentry.pml; found by
 * tla/ReentryApalache.tla's inductive step). */
#define WFREE   0
#define WCLIENT 1
#define WSERVER 2
byte wlock[2] = WFREE;

bool established[2] = false;  /* §4: per-connection phase */
bool inReq[2]       = false;  /* an inbound request awaits peer p's server */
bool resp[2]        = false;  /* §6.11(b) a demuxed response routed back to p's client */
byte store[2]       = 0;      /* §4.8 bounded content store written by handlers */
byte cstate[2]      = 0;      /* client: 0=init 1=sent 2=done */
byte sstate[2]      = 0;      /* server: 0=idle 1=serving 2=done */
bool revoked        = false;  /* §5.1 a revocation marker, consulted by the dispatch gate */
bool servedRevoked  = false;  /* ghost: a handler wrote under a cap it observed revoked */

/* §6.11(a′) partially-written-frame bookkeeping, per connection. */
byte midframe[2] = 0;
bool interleaved = false;

/* §6.5/§5.10 verdict gate (abstracted): honored iff not revoked. */
#ifdef NOREVGATE
  #define honored  true          /* DEFECT: serve regardless of the revocation verdict */
#else
  #define honored  (!revoked)
#endif

/* LTL predicates (§4.9(a)). */
#define sentA (cstate[A] == 1)
#define doneA (cstate[A] == 2)
#define sentB (cstate[B] == 1)
#define doneB (cstate[B] == 2)

ltl EventuallyResolved { [] ((sentA -> <> doneA) && (sentB -> <> doneB)) }

/* §4: the connection handshake completes — the precondition for any dispatch. */
proctype link(byte p) {
  established[p] = true;
}

/* §5.1: a revocation may or may not occur, concurrently with in-flight dispatch. */
proctype revoker() {
  if :: revoked = true; :: skip fi;
}

/* Client(p): once established, originate a reentrant cross-peer EXECUTE and await the
 * demuxed response. */
proctype client(byte p) {
#ifndef NOESTABGATE
  established[p];               /* §4.2: no dispatch pre-establishment */
#endif
  /* --- request frame, chunk 1 (§6.11(a′)) --- */
  atomic {
#ifndef NOATOMICFRAME
    wlock[p] == WFREE;
    wlock[p] = WCLIENT;
#endif
    if :: midframe[p] > 0 -> interleaved = true; :: else -> skip fi;
    midframe[p]++;
  }
  /* --- chunk 2; deliver; release at END OF FRAME (or hold it, the §6.11(a) defect) --- */
  atomic {
    if :: midframe[p] > 1 -> interleaved = true; :: else -> skip fi;
    midframe[p]--;
    inReq[other(p)] = true;
    cstate[p] = 1;              /* sent */
#ifndef NOATOMICFRAME
#ifndef SERIALIZED
    wlock[p] = WFREE;
#endif
#endif
    assert(!interleaved);                       /* §6.11(a′) */
    /* §4.2 DispatchNeedsEstablished. NOTE the assert is NOT compiled out by -DNOESTABGATE:
     * a negative control that removes both the gate AND its detector reports errors: 0 and
     * looks like a pass. That mistake was made here during the 0.8.2 audit and caught by
     * the control failing to fail. Only the GATE is variant-conditional. */
    assert(established[p]);
  }
  /* CRecv — release only a lock we hold. */
  atomic {
    resp[p];
    if :: wlock[p] == WCLIENT -> wlock[p] = WFREE; :: else -> skip fi;
    cstate[p] = 2;             /* done */
  }
}

/* Server(q): serve the inbound request; the handler reenters to write the response frame on
 * peer q's SAME pooled connection. Composes the establishment gate, the verdict gate and the
 * bounded store write. */
proctype server(byte q) {
  inReq[q];
#ifndef NOESTABGATE
  established[q];              /* §4 + §6.5 gate precondition */
#endif
  sstate[q] = 1;               /* serving — sequenced strictly after the gates above, so
                                * "no handler entry pre-gate" holds by construction here and
                                * the establishment half is asserted explicitly below */
  /* --- response frame, chunk 1: verdict gate + store write stay in ONE atomic step --- */
  atomic {
#ifndef NOATOMICFRAME
    wlock[q] == WFREE;         /* §6.11 reentry write lock — deadlock point if SERIALIZED */
    wlock[q] = WSERVER;
#else
    skip;
#endif
    if :: midframe[q] > 0 -> interleaved = true; :: else -> skip fi;
    midframe[q]++;
    if
    :: honored ->
         store[q]++;                            /* §4.8 handler store write */
         if :: revoked -> servedRevoked = true; :: else -> skip fi;
    :: else -> skip
    fi;
    /* NO §4.9(b) STORE-BOUND ASSERT HERE — deliberately, matching Core.tla. It used to read
     * `assert(store[q] <= MAXKEYS)`, and the write above used to be a SATURATING one that
     * clamped at MAXKEYS. The assertion was therefore enforced by the statement three lines
     * above it: no -D control, and no interleaving, could ever violate it. That is the same
     * defect as the -DNOESTABGATE control that compiled out its own detector (see the note in
     * client() above) — an assertion whose detector is disabled by construction — and it sat
     * 30 lines below that note. The store bound is store.pml's; here the write is only the
     * observable the revocation gate protects. */
    assert(!servedRevoked);                     /* §5.1/§6.8 NoServeWhenRevoked */
    assert(established[q]);                     /* §6.5 ServeNeedsEstablished (see note above) */
  }
  /* --- chunk 2; respond either way (§4.9(c) deliver-or-signal); release --- */
  atomic {
    if :: midframe[q] > 1 -> interleaved = true; :: else -> skip fi;
    midframe[q]--;
    resp[other(q)] = true;
    sstate[q] = 2;             /* done */
#ifndef NOATOMICFRAME
    wlock[q] = WFREE;
#endif
    assert(!interleaved);                       /* §6.11(a′) FramesNotInterleaved */
  }
}

init {
  atomic {
    run link(A); run link(B);
    run revoker();
    run client(A); run client(B);
    run server(A); run server(B);
  }
}
