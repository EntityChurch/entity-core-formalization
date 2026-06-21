---- MODULE Store ----
\* Phase 1 — increment 2: Store-safety / resilience / admission (V7 §4.8, §4.9, §4.10),
\* per PHASE1-SCOPE.md subsystem C. A single peer serving NReq concurrent per-request
\* dispatch activities against a shared content store / tree index, with an admission gate.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the verdict/attenuation arithmetic and
\* crypto are abstracted (Lean/Tamarin own them). Payload size and chain depth are modeled
\* symbolically ("ok"/"over") — §4.10 names recommended defaults (16 MiB / 64) but the
\* normative contract is "enforce a finite *declared* bound and reject over-limit cleanly,"
\* not the numbers, so the symbolic over/under-limit choice is the faithful abstraction.
\* The store data-race (§4.8) is modeled as concurrent occupancy of the write critical
\* section (writers > 1); the single-writer discipline is the await-guard on entry. Every
\* state element cites the V7 §ref it transcribes from spec-data/v0.8.0/.
EXTENDS Naturals, FiniteSets

CONSTANTS NReq,        \* number of concurrent per-request dispatch activities (keep small for TLC)
          MaxPending,  \* §4.9(b)/§4.10: admission bound on admitted-not-yet-responded requests
          MaxStore,    \* §4.8/§4.9(b): live-key bound on the content store
          Serialize,   \* TRUE = §4.8 single-writer store-safety discipline;
                       \* FALSE = negative control: unsynchronized store -> data race
          Admit,       \* TRUE = §4.10/§4.9(b) admission control enforced;
                       \* FALSE = negative control: no admission bound -> unbounded pending
          SilentDrop   \* FALSE = §4.9(c) deliver-or-signal honored (admitted work always responds);
                       \* TRUE = LIVENESS negative control: admitted work may be silently dropped
                       \*        (no response, pending leaked) -> Responsive + Recovers fail.

Reqs   == 1..NReq
StoreKey == "k"   \* §4.8 single shared key — strongest concurrent-mutation contention point

(*--algorithm store
variables
  store    = {},                          \* §4.8 content store / tree index (set of live keys)
  writers  = 0,                            \* requests currently inside the write critical section
  pending  = 0,                            \* §4.9(c): admitted requests not yet responded
  rstate   = [r \in Reqs |-> "new"],       \* per-request lifecycle (see Pick/Admit/WBegin/WCommit)
  payload  = [r \in Reqs |-> "ok"],        \* §4.10(a): "ok" | "over" (wire size vs configured max)
  depth    = [r \in Reqs |-> "ok"],        \* §4.10(b): "ok" | "over" (chain depth vs configured max)
  wrote    = [r \in Reqs |-> FALSE];       \* did this request mutate the store? (clean-reject check)

define
  \* §4.8 store-safety: at most one request mutating the store at a time (the single-writer
  \* discipline). writers > 1 is a data race == a crash == a §4.9(d) resilience violation.
  StoreRaceFree     == writers <= 1

  \* §4.9(b)/§4.10: resource use is bounded under load. pending never exceeds the admission
  \* bound; the store never exceeds its live-key bound. A per-request leak would break this.
  ResourceBounded   == /\ pending <= MaxPending
                       /\ Cardinality(store) <= MaxStore

  \* §4.10 clean reject: an over-limit request is rejected with the right coded outcome and
  \* never reaches dispatch / mutates the store; a request only ever wrote if it was admitted
  \* (writing/responded). Payload-too-large precedes chain-depth (admission order, §4.10(a) then (b)).
  CleanReject       ==
    /\ \A r \in Reqs : wrote[r] => rstate[r] \in {"writing", "responded"}
    /\ \A r \in Reqs : (payload[r] = "over") => rstate[r] \in {"new", "rej413"}
    /\ \A r \in Reqs : (payload[r] = "ok" /\ depth[r] = "over")
                          => rstate[r] \in {"new", "rej400"}
end define;

\* Each request is an independent concurrent dispatch activity (§4.8: inbound frames processed
\* concurrently). A possibly-adversarial caller chooses its payload size and chain depth.
fair process req \in Reqs
begin
  Pick:
    \* The environment / caller offers this request with some size + chain depth.
    with p \in {"ok", "over"}, d \in {"ok", "over"} do
      payload[self] := p || depth[self] := d;
    end with;
  AdmitStep:
    \* §4.10 admission control, in order: over-size -> 413; else over-depth -> 400; else
    \* §4.9(b) back-pressure when the in-flight bound is reached -> 503 refusal; else admit.
    if payload[self] = "over" then
      rstate[self] := "rej413";                       \* §4.10(a) 413 payload_too_large
    elsif depth[self] = "over" then
      rstate[self] := "rej400";                       \* §4.10(b) 400 chain_depth_exceeded
    elsif Admit /\ pending >= MaxPending then
      rstate[self] := "ref503";                       \* §4.9(b)/§4.10(c) clean back-pressure refusal
    else
      rstate[self] := "admitted" || pending := pending + 1;   \* §4.9(c): admitted -> owes a response
    end if;
  WBegin:
    \* §4.8 store-safety: enter the write critical section under the single-writer discipline.
    \* Serialize=TRUE gates entry on an empty section; the negative control drops the gate.
    if rstate[self] = "admitted" then
      if Serialize then
        await writers = 0;
      end if;
      writers := writers + 1 || rstate[self] := "writing";
    end if;
  WCommit:
    \* Mutate the bounded store, respond, and leave the critical section. §4.9(c): every
    \* admitted request is delivered (responded), never silently dropped.
    if rstate[self] = "writing" then
      if SilentDrop then
        \* LIVENESS NEG CONTROL (§4.9c): the request may instead be silently dropped — it leaves
        \* the critical section but never responds and its pending slot is leaked (the "admit and
        \* discard with no response" the spec calls the sharpest single violation).
        either
          store := store \cup {StoreKey} || wrote[self] := TRUE ||
          writers := writers - 1 || pending := pending - 1 || rstate[self] := "responded";
        or
          writers := writers - 1 || rstate[self] := "dropped";   \* no response; pending NOT released
        end either;
      else
        store := store \cup {StoreKey} ||
        wrote[self] := TRUE ||
        writers := writers - 1 ||
        pending := pending - 1 ||
        rstate[self] := "responded";
      end if;
    end if;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "b95119cc" /\ chksum(tla) = "d37f6bb1")
VARIABLES pc, store, writers, pending, rstate, payload, depth, wrote

(* define statement *)
StoreRaceFree     == writers <= 1



ResourceBounded   == /\ pending <= MaxPending
                     /\ Cardinality(store) <= MaxStore




CleanReject       ==
  /\ \A r \in Reqs : wrote[r] => rstate[r] \in {"writing", "responded"}
  /\ \A r \in Reqs : (payload[r] = "over") => rstate[r] \in {"new", "rej413"}
  /\ \A r \in Reqs : (payload[r] = "ok" /\ depth[r] = "over")
                        => rstate[r] \in {"new", "rej400"}


vars == << pc, store, writers, pending, rstate, payload, depth, wrote >>

ProcSet == (Reqs)

Init == (* Global variables *)
        /\ store = {}
        /\ writers = 0
        /\ pending = 0
        /\ rstate = [r \in Reqs |-> "new"]
        /\ payload = [r \in Reqs |-> "ok"]
        /\ depth = [r \in Reqs |-> "ok"]
        /\ wrote = [r \in Reqs |-> FALSE]
        /\ pc = [self \in ProcSet |-> "Pick"]

Pick(self) == /\ pc[self] = "Pick"
              /\ \E p \in {"ok", "over"}:
                   \E d \in {"ok", "over"}:
                     /\ depth' = [depth EXCEPT ![self] = d]
                     /\ payload' = [payload EXCEPT ![self] = p]
              /\ pc' = [pc EXCEPT ![self] = "AdmitStep"]
              /\ UNCHANGED << store, writers, pending, rstate, wrote >>

AdmitStep(self) == /\ pc[self] = "AdmitStep"
                   /\ IF payload[self] = "over"
                         THEN /\ rstate' = [rstate EXCEPT ![self] = "rej413"]
                              /\ UNCHANGED pending
                         ELSE /\ IF depth[self] = "over"
                                    THEN /\ rstate' = [rstate EXCEPT ![self] = "rej400"]
                                         /\ UNCHANGED pending
                                    ELSE /\ IF Admit /\ pending >= MaxPending
                                               THEN /\ rstate' = [rstate EXCEPT ![self] = "ref503"]
                                                    /\ UNCHANGED pending
                                               ELSE /\ /\ pending' = pending + 1
                                                       /\ rstate' = [rstate EXCEPT ![self] = "admitted"]
                   /\ pc' = [pc EXCEPT ![self] = "WBegin"]
                   /\ UNCHANGED << store, writers, payload, depth, wrote >>

WBegin(self) == /\ pc[self] = "WBegin"
                /\ IF rstate[self] = "admitted"
                      THEN /\ IF Serialize
                                 THEN /\ writers = 0
                                 ELSE /\ TRUE
                           /\ /\ rstate' = [rstate EXCEPT ![self] = "writing"]
                              /\ writers' = writers + 1
                      ELSE /\ TRUE
                           /\ UNCHANGED << writers, rstate >>
                /\ pc' = [pc EXCEPT ![self] = "WCommit"]
                /\ UNCHANGED << store, pending, payload, depth, wrote >>

WCommit(self) == /\ pc[self] = "WCommit"
                 /\ IF rstate[self] = "writing"
                       THEN /\ IF SilentDrop
                                  THEN /\ \/ /\ /\ pending' = pending - 1
                                                /\ rstate' = [rstate EXCEPT ![self] = "responded"]
                                                /\ store' = (store \cup {StoreKey})
                                                /\ writers' = writers - 1
                                                /\ wrote' = [wrote EXCEPT ![self] = TRUE]
                                          \/ /\ /\ rstate' = [rstate EXCEPT ![self] = "dropped"]
                                                /\ writers' = writers - 1
                                             /\ UNCHANGED <<store, pending, wrote>>
                                  ELSE /\ /\ pending' = pending - 1
                                          /\ rstate' = [rstate EXCEPT ![self] = "responded"]
                                          /\ store' = (store \cup {StoreKey})
                                          /\ writers' = writers - 1
                                          /\ wrote' = [wrote EXCEPT ![self] = TRUE]
                       ELSE /\ TRUE
                            /\ UNCHANGED << store, writers, pending, rstate, 
                                            wrote >>
                 /\ pc' = [pc EXCEPT ![self] = "Done"]
                 /\ UNCHANGED << payload, depth >>

req(self) == Pick(self) \/ AdmitStep(self) \/ WBegin(self) \/ WCommit(self)

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == (\E self \in Reqs: req(self))
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ \A self \in Reqs : WF_vars(req(self))

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (checked as PROPERTY; needs the WF supplied by `fair process`) =====

\* §4.9(a) stay responsive + §4.9(c) deliver-or-signal: every admitted request eventually
\* responds — the peer keeps making progress, no admitted work deadlocks/livelocks/vanishes.
Responsive == \A r \in Reqs : (rstate[r] = "admitted") ~> (rstate[r] = "responded")

\* §4.9(e) recover: when offered load subsides (all requests reach a terminal outcome), the
\* in-flight count drains back to zero and stays there — no wedged/permanently-degraded state.
Recovers == <>[](pending = 0)
====
