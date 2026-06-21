/*
 * conn.pml — INDEPENDENT Promela re-encoding of the V7 §4.1–4.7 connection-lifecycle
 * handshake. Cross-check Track B (docs/HANDOFF-CROSSCHECK.md) for the TLA+ `Conn`
 * model (tla/Conn.tla).
 *
 * DISCIPLINE: this is written FROM the V7 §4 design — a responder reacting to a
 * nondeterministic frame stream from a possibly-adversarial initiator that chooses
 * frame order + nonces — NOT by translating the .tla line-by-line. The point of the
 * cross-check is an independent paradigm (Promela channels + a do-loop responder vs
 * PlusCal processes) reaching the SAME verdict TLA+ did, so a shared transcription
 * error is unlikely.
 *
 * Fidelity (5th wall): crypto (signatures / PoP, §4.6 steps 2–3) is abstracted —
 * Tamarin/Lean own it. The nonce-echo CHECK (§4.6 step 1) is modeled as state: the
 * responder issues nonce N1 in its hello reply and later compares the auth frame's
 * echoed nonce against it. Exactly the abstraction the TLA+ model uses.
 *
 * Variants (mirror the TLA+ Enforce / DropFrame negative controls), selected via
 * #ifdef so a single source covers fix + both defects:
 *   fix       (default):    §4-correct responder; all properties hold.
 *   -DNOENFORCE:            responder skips hello-before-auth ordering + issued-nonce
 *                           bind (accepts auth whenever nonce==N1, any phase) ->
 *                           NoEstablishWithoutNonce is VIOLATED.   (TLA+ Enforce=FALSE)
 *   -DDROPFRAME:            responder may halt with frames still unanswered (reaching
 *                           its end cleanly, not deadlocking) -> AllAnswered FAILS.
 *                                                                 (TLA+ DropFrame=TRUE)
 *
 * Build/run (see HANDOFF; an `ltl {}` claim disables invalid-end detection in the
 * default pan run, so safety uses -DNOCLAIM + plain ./pan and liveness uses ./pan -a -f):
 *   safety :  spin -a [DEFS] conn.pml ; gcc -O2 -DNOCLAIM -o pan pan.c ; ./pan
 *   live   :  spin -a [DEFS] conn.pml ; gcc -O2 -o pan pan.c ; ./pan -a -f
 */

#define MaxFrames 3        /* §: bound on env-submitted frames; small => Spin stays exhaustive */

/* Frame kinds the (possibly adversarial) initiator may submit, in any order, repeats ok. */
#define HELLO        0     /* §4.1 connect: hello(nonce=none) */
#define AUTH_GOOD    1     /* §4.6: auth echoing the issued nonce N1 */
#define AUTH_WRONG   2     /* §4.6: auth with a stale/guessed nonce */
#define NONCONNECT   3     /* §4.2: a non-connect EXECUTE (needs an established connection) */

/* Per-connection phases (§4.1). */
#define NEW          0
#define HELLO_DONE   1
#define ESTABLISHED  2

/* Issued-nonce state (§4.6 step 1): NONE until the responder replies to hello. */
#define NONE         0
#define N1           1

/* ---- responder state ---------------------------------------------------- */
byte phase        = NEW;
byte issuedNonce  = NONE;
byte tokensIssued = 0;         /* §4.2: capability tokens minted here; MUST stay <= 1 */
bool everEstablished = false;
bool dispatched   = false;     /* a non-connect EXECUTE was admitted to dispatch */

/* ---- frame transport + accounting --------------------------------------- */
chan inbox = [MaxFrames] of { byte };   /* the initiator's frame stream to the responder */
byte submitted = 0;
byte answered  = 0;
bool respHalted = false;       /* liveness neg control: responder stopped serving early */

/* LTL liveness predicate (§4.1): every submitted frame is eventually answered. */
#define allAnswered (answered == MaxFrames)

/*
 * Initiator / environment: submits up to MaxFrames frames, each chosen
 * nondeterministically (out-of-order arrival + an attacker guessing the nonce).
 */
active proctype initiator() {
  do
  :: submitted < MaxFrames ->
       if
       :: inbox ! HELLO
       :: inbox ! AUTH_GOOD
       :: inbox ! AUTH_WRONG
       :: inbox ! NONCONNECT
       fi;
       submitted++
  :: else -> break
  od
}

/*
 * Responder: processes one inbound frame per atomic step per the §4 dispatch rules.
 * Each branch consumes exactly one frame and counts it as answered (§4.1: every frame
 * gets a response, even error responses like 401/403/409).
 */
active proctype responder() {
  byte f;
  do
  :: (answered < MaxFrames && !respHalted) ->
       if
       :: atomic {
            inbox ? f;                     /* take the next frame (FIFO order from env) */
            if
            /* ---- hello (§4.1 connect) ---- */
            :: f == HELLO ->
                 if
                 :: phase == NEW ->
                      phase = HELLO_DONE;
                      issuedNonce = N1       /* §4.6 step 1: issue the echo nonce */
                 :: else ->
                      skip                   /* hello_done: 400 seq; established: 409, no reissue */
                 fi

            /* ---- auth (§4.6 authenticate) ---- */
            :: (f == AUTH_GOOD || f == AUTH_WRONG) ->
#ifdef NOENFORCE
                 /* NEGATIVE CONTROL (Enforce=FALSE): skip the hello-before-auth ordering
                  * and the issued-nonce bind; accept auth purely on a matching nonce
                  * value, from ANY phase (so it can establish with issuedNonce still NONE). */
                 if
                 :: f == AUTH_GOOD ->
                      phase = ESTABLISHED;
                      tokensIssued++;
                      everEstablished = true
                 :: else -> skip
                 fi
#else
                 /* §4.6 (Enforce): accept auth ONLY from hello_done AND only when the
                  * echoed nonce equals the issued nonce. */
                 if
                 :: (phase == HELLO_DONE && f == AUTH_GOOD && issuedNonce == N1) ->
                      phase = ESTABLISHED;
                      tokensIssued++;
                      everEstablished = true
                 :: else ->
                      skip                   /* 401 invalid_nonce / 400 seq */
                 fi
#endif

            /* ---- non-connect EXECUTE (§4.2) ---- */
            :: f == NONCONNECT ->
                 if
                 :: phase == ESTABLISHED ->
                      dispatched = true
                 :: else ->
                      skip                   /* §4.2: 403 pre-auth, NOT dispatched */
                 fi
            fi;
            answered++;

            /* SAFETY assertions, checked at every answered frame. */
            /* §4.1/§4.6 NoEstablishWithoutNonce: cannot be established unless a nonce
             * was issued (hello must have run first). */
            assert(phase != ESTABLISHED || issuedNonce == N1);
            /* §4.2 DispatchedImpliesEstablished: no non-connect dispatched pre-auth. */
            assert(!dispatched || everEstablished);
            /* §4.2 TokenBounded: no token reissue on reconnect. */
            assert(tokensIssued <= 1)
          }
#ifdef DROPFRAME
       /* LIVENESS NEG CONTROL (DropFrame=TRUE): the responder may stop serving with
        * frames still unanswered. It exits the loop cleanly (reaches its end state),
        * so AllAnswered fails as a temporal property — this is NOT a deadlock. */
       :: atomic { respHalted = true }
#endif
       fi
  :: else -> break
  od
}

/*
 * LIVENESS §4.1: every submitted frame is eventually answered (the handshake settles;
 * no frame is silently dropped). Needs weak fairness (pan -a -f). Holds in the fix;
 * under -DDROPFRAME the responder can halt early so allAnswered is never reached and
 * the claim is violated (acceptance cycle). Mirrors TLA+ AllAnswered.
 */
ltl AllAnswered { <> allAnswered }
