/*
 * reentry.pml — INDEPENDENT Promela re-encoding of the V7 §6.11 Transport Reentry
 * Contract (Class-G deadlock surface, plus §6.11(a′) frame-write atomicity).
 * Cross-check #B for the TLA+ `Reentry`/`Core` models (tla/Reentry.tla).
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): this is written FROM the V7 §6.11
 * design — two peers sharing a pooled connection, each running a client AND a server
 * activity, the per-connection write lock held across send+recv in the defect — NOT by
 * translating the .tla. The point is an independent paradigm (Promela channels/atomics
 * vs PlusCal) reaching the SAME verdict, so a shared transcription error is unlikely.
 *
 * 0.8.2 RE-TARGET (spec-data/v0.8.2/). §6.11 gained sub-clause (a′) FRAME-WRITE ATOMICITY
 * (0.8.1, RT-13b): "each wire frame MUST be written to the connection atomically with
 * respect to other frames — the bytes of two distinct frames MUST NOT interleave... This
 * does not reintroduce the (a) prohibition — the write serialization is held only for the
 * duration of one frame's bytes, never across the await."
 *
 * (a) and (a′) pull in opposite directions, so there is ONE lock here and the variants
 * select its HOLD DURATION. The default build must satisfy BOTH properties at once — that
 * joint satisfiability is the claim (a′)'s last sentence makes:
 *
 *   (default)      lock held for exactly one frame -> no deadlock AND no interleaving
 *   -DSERIALIZED   lock held across send+recv      -> Class-G DEADLOCK    (a  violated)
 *   -DNOATOMICFRAME  no per-frame lock at all      -> INTERLEAVED frames  (a′ violated)
 *
 * A frame is modeled as TWO chunks — the minimum granularity at which "two frames' bytes
 * interleaved" is expressible. The receiver's decode is NOT modeled: this proves the writes
 * do not interleave, not that the decoder would fail if they did.
 *
 * Fidelity (5th wall): the cap-chain VERDICT is abstracted to gate==true (Lean owns it),
 * exactly as in the TLA+ model — this checks the protocol AROUND the verdict.
 */

#define A 0
#define B 1
#define other(p)  (1 - p)

/* Per-peer pooled-connection write lock (§6.11(a)/(a′)). Tracks the OWNER, not just a free
 * bit, because a writer must release only a lock it actually holds — under the fix the
 * client releases at end-of-frame, so by the time its response arrives the lock may belong
 * to this peer's own server, mid-frame. 0 = free, 1 = client, 2 = server. */
byte wlock[2] = 0;
#define WFREE   0
#define WCLIENT 1
#define WSERVER 2
bool inReq[2]    = false;   /* an inbound request awaits peer p's server */
bool resp[2]     = false;   /* a response has been delivered back to peer p's client */
byte store[2]    = 0;       /* §4.8 live-key store count a handler has written */
byte cstate[2]   = 0;       /* client: 0=init 1=sent 2=done */
byte sstate[2]   = 0;       /* server: 0=idle 1=serving 2=done */

/* §6.11(a′): how many writers currently hold a PARTIALLY WRITTEN frame on peer p's
 * connection. A writer is counted between its first and last chunk. */
byte midframe[2] = 0;
/* §6.11(a′) violation flag, latched — the corruption is not undone by finishing the
 * frame. Set when a writer begins or ends a frame while another writer is mid-frame. */
bool interleaved = false;


/* LTL predicates (§4.9(a) — every admitted request eventually resolves) */
#define sentA  (cstate[A] == 1)
#define doneA  (cstate[A] == 2)
#define sentB  (cstate[B] == 1)
#define doneB  (cstate[B] == 2)

/* Client(p): originate an EXECUTE to other(p), await the correlated response. */
proctype client(byte p) {
  /* --- Frame chunk 1 of the request frame (§6.11(a′)) --- */
  atomic {
#ifndef NOATOMICFRAME
    wlock[p] == WFREE;           /* (a′): take the write lock for this frame's bytes */
    wlock[p] = WCLIENT;
#endif
    /* beginning a frame while another writer is mid-frame IS an interleave */
    if :: midframe[p] > 0 -> interleaved = true;
       :: else -> skip
    fi;
    midframe[p]++;
  }
  /* --- Frame chunk 2 of the same frame; then deliver --- */
  atomic {
    /* if another writer began a frame since our chunk 1, our bytes are not contiguous */
    if :: midframe[p] > 1 -> interleaved = true;
       :: else -> skip
    fi;
    midframe[p]--;
    inReq[other(p)] = true;      /* the complete frame reaches the peer's server */
    cstate[p] = 1;               /* sent */
    /* END OF FRAME — release here. This is the (a′)-conformant hold duration.
     * SERIALIZED defect (§6.11(a) violated): keep holding it across the recv. */
#ifndef NOATOMICFRAME
#ifndef SERIALIZED
    wlock[p] = WFREE;            /* §6.11(a)+(b) FIX: released before the await */
#endif
#endif
  }
  /* CRecv — await the response (DEFECT: still holding the lock).
   * RELEASE ONLY A LOCK WE HOLD. Under the fix the client already released at end-of-frame,
   * so the lock may now belong to this peer's own server mid-frame; freeing it here would
   * release another writer's lock. (Found by tla/ReentryApalache.tla's inductive step —
   * invisible to both bounded checkers because no third writer exists at this bound to
   * exploit the stolen lock.) */
  atomic {
    resp[p];                     /* await correlated response */
    if
    :: wlock[p] == WCLIENT -> wlock[p] = WFREE;   /* the SERIALIZED defect's hold ends here */
    :: else -> skip
    fi;
    cstate[p] = 2;               /* done */
  }
}

/* Server(q): serve the inbound request for peer q; the handler reenters / writes the
 * response frame on peer q's SAME pooled connection (§6.11 reentry). */
proctype server(byte q) {
  /* SWait */
  inReq[q];
  /* SGate — §6.5: the dispatch gate runs before the handler (verdict abstracted true). */
  sstate[q] = 1;                 /* serving */
  /* --- Frame chunk 1 of the response frame --- */
  atomic {
#ifndef NOATOMICFRAME
    wlock[q] == WFREE;           /* acquire the write lock for the response frame */
    wlock[q] = WSERVER;
#endif
    if :: midframe[q] > 0 -> interleaved = true;
       :: else -> skip
    fi;
    midframe[q]++;
    store[q]++;                  /* §4.8 handler store write */
    /* No §4.9(b) bound assert — it was VACUOUS here (one write per server against MAXLIVE=2,
     * so it could not fail) and is removed to match Reentry.tla. store.pml owns the bound. */
  }
  /* --- Frame chunk 2; then deliver and release --- */
  atomic {
    if :: midframe[q] > 1 -> interleaved = true;
       :: else -> skip
    fi;
    midframe[q]--;
    resp[other(q)] = true;       /* respond to the requesting client */
    sstate[q] = 2;               /* done */
#ifndef NOATOMICFRAME
    wlock[q] = WFREE;            /* END OF FRAME */
#endif
    /* SAFETY §6.11(a′): the bytes of two distinct frames never interleaved. */
    assert(!interleaved);
  }
}

/* SAFETY §6.5 (NoDispatchWithoutGate): the handler's effects are sequenced strictly after
 * SGate within server(q), so a handler never runs pre-gate by construction — the structural
 * analog of the TLA+ check (gate verdict abstracted true). */

init {
  atomic {
    run client(A); run client(B);
    run server(A); run server(B);
  }
}

/* LIVENESS §4.9(a): every admitted (sent) request eventually resolves (done). THE
 * property nothing else in the assurance stack proves. Needs weak fairness (pan -f).
 * Holds in the fix; in the SERIALIZED defect the deadlock makes it FAIL (and pan also
 * reports the invalid end state). Mirrors TLA+ EventuallyResolved. */
ltl resolve { [] ((sentA -> <> doneA) && (sentB -> <> doneB)) }
