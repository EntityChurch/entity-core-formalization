---- MODULE Conn ----
\* Phase 1 — increment 1: Connection lifecycle (V7 §4.1–4.7), per PHASE1-SCOPE.md subsystem A.
\* A responder's per-connection handshake state machine reacting to a nondeterministic frame
\* stream (the environment / a possibly-adversarial initiator chooses frame order + nonces).
\* Crypto (signatures/PoP, §4.6 step 2-3) is abstracted — Tamarin/Lean own it; the nonce-echo
\* CHECK (§4.6 step 1) is modeled as state. Every element cites its V7 §ref (5th-wall fidelity).
EXTENDS Naturals, Sequences

CONSTANTS MaxFrames,   \* bound on environment-submitted frames (keep small for TLC)
          Enforce,     \* TRUE = §4-correct responder; FALSE = ordering-bug negative control
          DropFrame    \* FALSE = §4.1 every frame is answered; TRUE = LIVENESS negative control:
                       \*         the responder may consume a frame without answering -> AllAnswered fails

(*--algorithm conn
variables
  phase           = "new",     \* §4.1 per-connection phase: new -> hello_done -> established
  issuedNonce     = "none",    \* §4.6 step 1: nonce the responder issued in its hello reply
  tokensIssued    = 0,         \* §4.2: capability tokens minted on this connection (MUST stay <=1)
  everEstablished = FALSE,
  dispatched      = FALSE,     \* a non-connect EXECUTE was admitted to dispatch
  inbox           = << >>,
  submitted       = 0,
  answered        = 0,
  respHalted      = FALSE;     \* liveness neg control: responder stopped serving early

define
  \* §4.2: a new capability token MUST NOT be issued on reconnect — at most one ever.
  TokenBounded               == tokensIssued <= 1
  \* §4.1/§4.6: cannot be established without a nonce having been issued (hello ran first).
  NoEstablishWithoutNonce    == (phase = "established") => (issuedNonce = "N1")
  \* §4.2: no non-connect EXECUTE is dispatched before the connection is established (403 pre-auth).
  DispatchedImpliesEstablished == dispatched => everEstablished
end define;

\* Environment / initiator: submits up to MaxFrames frames in any order, with any nonce
\* (modeling out-of-order arrival and an attacker guessing the nonce).
fair process env = "env"
begin
  Submit:
    while submitted < MaxFrames do
      with f \in { [kind |-> "hello",      nonce |-> "none"],
                   [kind |-> "auth",       nonce |-> "N1"],     \* echoes the issued nonce
                   [kind |-> "auth",       nonce |-> "wrong"],  \* stale/guessed nonce
                   [kind |-> "nonconnect", nonce |-> "none"] } do
        inbox := Append(inbox, f) || submitted := submitted + 1;
      end with;
    end while;
end process;

\* Responder: processes one inbound frame per atomic step per the §4 dispatch rules.
fair process resp = "resp"
begin
  Serve:
    while answered < MaxFrames /\ ~respHalted do
      await Len(inbox) > 0;
      either
       with f = Head(inbox) do
        if f.kind = "hello" then
          if phase = "new" then
            phase := "hello_done" || issuedNonce := "N1" ||
            inbox := Tail(inbox) || answered := answered + 1;
          else
            \* established -> 409 (no token reissue); hello_done -> sequence error. Phase unchanged.
            inbox := Tail(inbox) || answered := answered + 1;
          end if;
        elsif f.kind = "auth" then
          if Enforce then
            \* §4.6: accept authenticate only from hello_done AND with the issued nonce echoed.
            if phase = "hello_done" /\ f.nonce = issuedNonce then
              phase := "established" || tokensIssued := tokensIssued + 1 ||
              everEstablished := TRUE || inbox := Tail(inbox) || answered := answered + 1;
            else
              inbox := Tail(inbox) || answered := answered + 1;   \* 401 invalid_nonce / 400 seq
            end if;
          else
            \* NEGATIVE CONTROL: responder skips the hello-before-auth ordering + issued-nonce bind.
            if f.nonce = "N1" then
              phase := "established" || tokensIssued := tokensIssued + 1 ||
              everEstablished := TRUE || inbox := Tail(inbox) || answered := answered + 1;
            else
              inbox := Tail(inbox) || answered := answered + 1;
            end if;
          end if;
        else \* nonconnect
          if phase = "established" then
            dispatched := TRUE || inbox := Tail(inbox) || answered := answered + 1;
          else
            inbox := Tail(inbox) || answered := answered + 1;   \* §4.2: 403 pre-auth, not dispatched
          end if;
        end if;
       end with;
      or
        \* LIVENESS NEG CONTROL: the responder stops serving with frames still unanswered (it
        \* reaches Done cleanly, so AllAnswered fails as a temporal property — not a deadlock).
        await DropFrame;
        respHalted := TRUE;
      end either;
    end while;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "83a4038a" /\ chksum(tla) = "2711f8b2")
VARIABLES pc, phase, issuedNonce, tokensIssued, everEstablished, dispatched, 
          inbox, submitted, answered, respHalted

(* define statement *)
TokenBounded               == tokensIssued <= 1

NoEstablishWithoutNonce    == (phase = "established") => (issuedNonce = "N1")

DispatchedImpliesEstablished == dispatched => everEstablished


vars == << pc, phase, issuedNonce, tokensIssued, everEstablished, dispatched, 
           inbox, submitted, answered, respHalted >>

ProcSet == {"env"} \cup {"resp"}

Init == (* Global variables *)
        /\ phase = "new"
        /\ issuedNonce = "none"
        /\ tokensIssued = 0
        /\ everEstablished = FALSE
        /\ dispatched = FALSE
        /\ inbox = << >>
        /\ submitted = 0
        /\ answered = 0
        /\ respHalted = FALSE
        /\ pc = [self \in ProcSet |-> CASE self = "env" -> "Submit"
                                        [] self = "resp" -> "Serve"]

Submit == /\ pc["env"] = "Submit"
          /\ IF submitted < MaxFrames
                THEN /\ \E f \in { [kind |-> "hello",      nonce |-> "none"],
                                   [kind |-> "auth",       nonce |-> "N1"],
                                   [kind |-> "auth",       nonce |-> "wrong"],
                                   [kind |-> "nonconnect", nonce |-> "none"] }:
                          /\ inbox' = Append(inbox, f)
                          /\ submitted' = submitted + 1
                     /\ pc' = [pc EXCEPT !["env"] = "Submit"]
                ELSE /\ pc' = [pc EXCEPT !["env"] = "Done"]
                     /\ UNCHANGED << inbox, submitted >>
          /\ UNCHANGED << phase, issuedNonce, tokensIssued, everEstablished, 
                          dispatched, answered, respHalted >>

env == Submit

Serve == /\ pc["resp"] = "Serve"
         /\ IF answered < MaxFrames /\ ~respHalted
               THEN /\ Len(inbox) > 0
                    /\ \/ /\ LET f == Head(inbox) IN
                               IF f.kind = "hello"
                                  THEN /\ IF phase = "new"
                                             THEN /\ /\ answered' = answered + 1
                                                     /\ inbox' = Tail(inbox)
                                                     /\ issuedNonce' = "N1"
                                                     /\ phase' = "hello_done"
                                             ELSE /\ /\ answered' = answered + 1
                                                     /\ inbox' = Tail(inbox)
                                                  /\ UNCHANGED << phase, 
                                                                  issuedNonce >>
                                       /\ UNCHANGED << tokensIssued, 
                                                       everEstablished, 
                                                       dispatched >>
                                  ELSE /\ IF f.kind = "auth"
                                             THEN /\ IF Enforce
                                                        THEN /\ IF phase = "hello_done" /\ f.nonce = issuedNonce
                                                                   THEN /\ /\ answered' = answered + 1
                                                                           /\ everEstablished' = TRUE
                                                                           /\ inbox' = Tail(inbox)
                                                                           /\ phase' = "established"
                                                                           /\ tokensIssued' = tokensIssued + 1
                                                                   ELSE /\ /\ answered' = answered + 1
                                                                           /\ inbox' = Tail(inbox)
                                                                        /\ UNCHANGED << phase, 
                                                                                        tokensIssued, 
                                                                                        everEstablished >>
                                                        ELSE /\ IF f.nonce = "N1"
                                                                   THEN /\ /\ answered' = answered + 1
                                                                           /\ everEstablished' = TRUE
                                                                           /\ inbox' = Tail(inbox)
                                                                           /\ phase' = "established"
                                                                           /\ tokensIssued' = tokensIssued + 1
                                                                   ELSE /\ /\ answered' = answered + 1
                                                                           /\ inbox' = Tail(inbox)
                                                                        /\ UNCHANGED << phase, 
                                                                                        tokensIssued, 
                                                                                        everEstablished >>
                                                  /\ UNCHANGED dispatched
                                             ELSE /\ IF phase = "established"
                                                        THEN /\ /\ answered' = answered + 1
                                                                /\ dispatched' = TRUE
                                                                /\ inbox' = Tail(inbox)
                                                        ELSE /\ /\ answered' = answered + 1
                                                                /\ inbox' = Tail(inbox)
                                                             /\ UNCHANGED dispatched
                                                  /\ UNCHANGED << phase, 
                                                                  tokensIssued, 
                                                                  everEstablished >>
                                       /\ UNCHANGED issuedNonce
                          /\ UNCHANGED respHalted
                       \/ /\ DropFrame
                          /\ respHalted' = TRUE
                          /\ UNCHANGED <<phase, issuedNonce, tokensIssued, everEstablished, dispatched, inbox, answered>>
                    /\ pc' = [pc EXCEPT !["resp"] = "Serve"]
               ELSE /\ pc' = [pc EXCEPT !["resp"] = "Done"]
                    /\ UNCHANGED << phase, issuedNonce, tokensIssued, 
                                    everEstablished, dispatched, inbox, 
                                    answered, respHalted >>
         /\ UNCHANGED submitted

resp == Serve

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == env \/ resp
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(env)
        /\ WF_vars(resp)

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION 

\* LIVENESS — §4.1: every submitted frame is eventually answered (handshake settles; no frame
\* is silently dropped — "every EXECUTE receives an EXECUTE_RESPONSE"). Needs weak fairness.
AllAnswered == <>(answered = MaxFrames)
====
