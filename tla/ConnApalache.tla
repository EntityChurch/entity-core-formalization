---- MODULE ConnApalache ----
\* Apalache (SMT) cross-check of the Conn module (tla/Conn.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of the §4.1-§4.7 connection-lifecycle
\* responder state machine: the phase (new -> hello_done -> established), the issued nonce
\* (§4.6 step 1), the token count (§4.2), and the dispatch flag (§4.2).
\*
\* The frame transport / FIFO inbox is abstracted to nondeterministic responder steps — at any
\* point the responder may process a hello, an auth (with a good or guessed nonce), or a
\* non-connect frame, exactly the adversarial frame stream the TLA+ env process supplies. The
\* invariants are state predicates over the responder state, so this is faithful.
\*
\* What this buys over TLC: TLC ENUMERATES at the bound; Apalache proves NoEstablishWithoutNonce
\* INDUCTIVE via Z3 (base Init=>Inv, step Inv/\Next=>Inv'), holding for EVERY reachable state.
\* The proof needs a strengthening — HelloImpliesNonce (phase past `new` => the nonce was issued)
\* — because NoEstablishWithoutNonce alone is not inductive (an arbitrary hello_done state with no
\* issued nonce could step to established). The neg control (Enforce=FALSE) is caught symbolically
\* exactly where TLC's ConnBug is.
EXTENDS Integers

CONSTANTS
  \* @type: Bool;
  Enforce       \* TRUE = §4.6 hello-before-auth ordering + issued-nonce bind; FALSE = neg control

\* Phases (§4.1) and issued-nonce states (§4.6 step 1) as string tags.
\* phase  \in {"new", "hello_done", "established"}
\* nonce  \in {"none", "N1"}

VARIABLES
  \* @type: Str;
  phase,
  \* @type: Str;
  issuedNonce,
  \* @type: Bool;
  everEstablished,
  \* @type: Bool;
  dispatched

\* §4.2 TokenBounded (no token reissue) is left to TLC + Spin: its inductive invariant needs a
\* phase<->token-count link that adds no fidelity to the NoEstablishWithoutNonce result proved
\* here, so the token counter is omitted from this port (abstraction stated, 5th wall).
vars == << phase, issuedNonce, everEstablished, dispatched >>

\* ----- the safety invariants (transcribed from Conn.tla's define block) -----
\* §4.1/§4.6: cannot be established without a nonce having been issued (hello ran first).
NoEstablishWithoutNonce == (phase = "established") => (issuedNonce = "N1")
\* §4.2: no non-connect EXECUTE dispatched before the connection is established.
DispatchedImpliesEstablished == dispatched => everEstablished

\* ----- type/domain + inductive strengthening -----
\* NoEstablishWithoutNonce is NOT inductive on its own; the strengthening is that ANY phase past
\* "new" implies the nonce was issued (so the established transition, which requires hello_done,
\* starts from issuedNonce = "N1"). That, plus the typed domain, is the inductive invariant.
HelloImpliesNonce == (phase \in {"hello_done", "established"}) => (issuedNonce = "N1")

TypeOK ==
  /\ phase \in {"new", "hello_done", "established"}
  /\ issuedNonce \in {"none", "N1"}
  /\ everEstablished \in BOOLEAN
  /\ dispatched \in BOOLEAN

\* Inv proves the strengthening; NoEstablishWithoutNonce is its immediate consequence (also
\* asserted directly so the check verifies the named property, not just the strengthening).
Inv == TypeOK /\ HelloImpliesNonce /\ NoEstablishWithoutNonce

\* ----- transitions (data layer of Conn.tla's Serve dispatch branches) -----
Init ==
  /\ phase = "new"
  /\ issuedNonce = "none"
  /\ everEstablished = FALSE
  /\ dispatched = FALSE

\* hello (§4.1 connect): from "new", issue the echo nonce N1 and move to hello_done; otherwise
\* (409 on established / 400 seq on hello_done) the phase is unchanged.
DoHello ==
  \/ /\ phase = "new"
     /\ phase' = "hello_done"
     /\ issuedNonce' = "N1"
     /\ UNCHANGED << everEstablished, dispatched >>
  \/ /\ phase # "new"
     /\ UNCHANGED vars

\* auth (§4.6 authenticate). The (possibly adversarial) initiator presents a good or guessed nonce.
\* Enforce=TRUE: accept ONLY from hello_done AND when the echoed nonce equals the issued nonce.
\* Enforce=FALSE (neg control): accept on a matching nonce value from ANY phase, skipping the
\* ordering + issued-nonce bind — so it can establish straight from "new" with issuedNonce "none".
DoAuth ==
  \E echoed \in {"N1", "wrong"} :
    \/ /\ Enforce
       /\ phase = "hello_done" /\ echoed = issuedNonce
       /\ phase' = "established" /\ everEstablished' = TRUE
       /\ UNCHANGED << issuedNonce, dispatched >>
    \/ /\ Enforce
       /\ ~(phase = "hello_done" /\ echoed = issuedNonce)
       /\ UNCHANGED vars                                  \* 401 invalid_nonce / 400 seq
    \/ /\ ~Enforce
       /\ echoed = "N1"
       /\ phase' = "established" /\ everEstablished' = TRUE
       /\ UNCHANGED << issuedNonce, dispatched >>
    \/ /\ ~Enforce
       /\ echoed # "N1"
       /\ UNCHANGED vars

\* non-connect EXECUTE (§4.2): dispatched only once established; otherwise 403 pre-auth.
DoNonConnect ==
  \/ /\ phase = "established"
     /\ dispatched' = TRUE
     /\ UNCHANGED << phase, issuedNonce, everEstablished >>
  \/ /\ phase # "established"
     /\ UNCHANGED vars

Next == DoHello \/ DoAuth \/ DoNonConnect \/ UNCHANGED vars

\* ----- inductive-step init: arbitrary typed state satisfying the (strengthened) invariant -----
IndInit == TypeOK /\ HelloImpliesNonce /\ NoEstablishWithoutNonce

\* ----- constant inits (correct model + the negative control) -----
ConstInitOK  == Enforce = TRUE    \* §4.6 ordering + issued-nonce bind enforced
ConstInitBug == Enforce = FALSE   \* neg ctrl: auth accepted with no hello / no issued nonce
====
