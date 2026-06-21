/*
 * reentry.pml — INDEPENDENT Promela re-encoding of the V7 §6.11 Transport Reentry
 * Contract (Class-G deadlock surface). Cross-check #B for the TLA+ `Reentry`/`Core`
 * models (tla/Reentry.tla).
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): this is written FROM the V7 §6.11
 * design — two peers sharing a pooled connection, each running a client AND a server
 * activity, the per-connection write mutex held across send+recv in the defect — NOT by
 * translating the .tla. The point is an independent paradigm (Promela channels/atomics
 * vs PlusCal) reaching the SAME verdict, so a shared transcription error is unlikely.
 *
 * Two variants (mirrors the TLA+ Serialized switch):
 *   fix     (default):     make verify MODEL=reentry
 *   defect  (-DSERIALIZED): make verify MODEL=reentry DEFS=-DSERIALIZED
 *
 * §6.11(a): in the DEFECT the client holds the per-connection write mutex across the
 * recv; the peer's server handler needs that same mutex to write the response -> circular
 * wait across both peers = the Class-G deadlock (Spin: "invalid end state").
 * §6.11(a)+(b) FIX: mutex spans the write only; recv is correlated by request_id on a
 * reader task and does not hold the mutex -> no circular wait.
 *
 * Fidelity (5th wall): the cap-chain VERDICT is abstracted to gate==true (Lean owns it),
 * exactly as in the TLA+ model — this checks the protocol AROUND the verdict.
 */

#define A 0
#define B 1
#define other(p)  (1 - p)

bool mtx_free[2] = true;   /* per-peer pooled-connection write mutex (§6.11(a)) */
bool inReq[2]    = false;  /* an inbound request awaits peer p's server */
bool resp[2]     = false;  /* a response has been delivered back to peer p's client */
byte store[2]    = 0;      /* §4.8 live-key store count a handler has written */
byte cstate[2]   = 0;      /* client: 0=init 1=sent 2=done */
byte sstate[2]   = 0;      /* server: 0=idle 1=serving 2=done */

#define MAXLIVE 2          /* §4.9(b) store bound */

/* LTL predicates (§4.9(a) — every admitted request eventually resolves) */
#define sentA  (cstate[A] == 1)
#define doneA  (cstate[A] == 2)
#define sentB  (cstate[B] == 1)
#define doneB  (cstate[B] == 2)

/* Client(p): originate an EXECUTE to other(p), await the correlated response. */
proctype client(byte p) {
  /* CSend — acquire the write mutex, write the request. */
  atomic {
    mtx_free[p];                 /* acquire (await free) */
#ifdef SERIALIZED
    mtx_free[p] = false;         /* §6.11(a) VIOLATED: keep holding across the recv */
#else
    mtx_free[p] = true;          /* §6.11(a)+(b) FIX: release right after the write */
#endif
    inReq[other(p)] = true;      /* deliver request to the peer's server */
    cstate[p] = 1;               /* sent */
  }
  /* CRecv — await the response (DEFECT: still holding mtx). */
  atomic {
    resp[p];                     /* await correlated response */
    mtx_free[p] = true;          /* release (no-op in the fix; client->free in the defect) */
    cstate[p] = 2;               /* done */
  }
}

/* Server(q): serve the inbound request for peer q; the handler reenters / writes the
 * response, which needs peer q's write mutex (§6.11 reentry). */
proctype server(byte q) {
  /* SWait */
  inReq[q];
  /* SGate — §6.5: the dispatch gate runs before the handler (verdict abstracted true). */
  sstate[q] = 1;                 /* serving */
  /* SHandle — reenter, write store, write the response: needs the write mutex free. */
  atomic {
    mtx_free[q];                 /* acquire the write mutex for the response */
    store[q]++;                  /* §4.8 bounded store write */
    assert(store[q] <= MAXLIVE); /* SAFETY §4.9(b): store never exceeds its bound */
    resp[other(q)] = true;       /* respond to the requesting client */
    sstate[q] = 2;               /* done */
  }
}

/* SAFETY §6.5 (NoDispatchWithoutGate): the handler's effects (SHandle) are sequenced
 * strictly after SGate within server(q), so a handler never runs pre-gate by
 * construction — the structural analog of the TLA+ check (gate verdict abstracted true). */

init {
  atomic {
    run client(A); run client(B);
    run server(A); run server(B);
  }
}

/* LIVENESS §4.9(a): every admitted (sent) request eventually resolves (done). THE
 * property nothing else in the assurance stack proves. Needs weak fairness (pan -f).
 * Holds in the fix; in the defect the deadlock makes it FAIL (and pan also reports the
 * invalid end state). Mirrors TLA+ EventuallyResolved. */
ltl resolve { [] ((sentA -> <> doneA) && (sentB -> <> doneB)) }
