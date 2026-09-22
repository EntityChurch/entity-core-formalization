---- MODULE Store ----
\* Phase 1 — increment 2: Store-safety / resilience / admission (V7 §4.8, §4.9, §4.10),
\* per PHASE1-SCOPE.md subsystem C. A single peer serving NReq concurrent per-request
\* dispatch activities against a shared content store / tree index, with an admission gate.
\*
\* 0.8.2 RE-TARGET. Transcribed from spec-data/v0.8.2/. Two changes over the v0.8.0 model:
\*
\*   (1) §4.8 "Store-safety under concurrent dispatch" gained a normative sentence naming
\*       the content-store LIFETIME REFERENCE COUNT as in-scope (0.8.1, RT-13a): "on a
\*       manually-memory-managed substrate this specifically includes the reference count
\*       used for content-store lifetime: an unsynchronized refcount decrement from
\*       concurrent dispatch is a use-after-free, i.e. the §4.9 no-crash class". The v0.8.0
\*       model abstracted refcounts away entirely, so it could not express this. `rc` /
\*       `holders` / NoUseAfterFree below close that gap. See SyncRefs.
\*
\*   (2) The store is now MULTI-KEY. The v0.8.0 model used a single shared key, which made
\*       `Cardinality(store) <= MaxStore` unfalsifiable by construction (a one-element set
\*       cannot exceed 2) — a vacuous conjunct disclosed in PROPERTIES.md §C.4 and never
\*       fixed. With 3 distinct keys and MaxStore = 2 the bound is a real constraint, and
\*       the thing that DISCHARGES it is the refcount: a key is live exactly while some
\*       request holds a reference, so the §4.9(b) live-key bound now genuinely depends on
\*       §4.8 refcount correctness. Leak the refcount and the bound breaks — which is the
\*       composition the spec actually asserts.
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the verdict/attenuation arithmetic and
\* crypto are abstracted (Lean/Tamarin own them). Payload size and chain depth are modeled
\* symbolically ("ok"/"over") — §4.10 names recommended defaults (16 MiB / 64) but the
\* normative contract is "enforce a finite *declared* bound and reject over-limit cleanly,"
\* not the numbers, so the symbolic over/under-limit choice is the faithful abstraction.
\* The store data-race (§4.8) is modeled as concurrent occupancy of the write critical
\* section (writers > 1); the single-writer discipline is the await-guard on entry.
\*
\* ABSTRACTION BOUNDARY for the refcount (D11 — state what is NOT in the model):
\* `holders` is GROUND TRUTH (who actually still references the entity) and is always
\* updated atomically; `rc` is the IMPLEMENTATION'S COUNTER and is the only racy object.
\* This is deliberate: the defect the spec names is not "the set of referrers is wrong,"
\* it is "the counter diverges from the truth and the entity is freed under a live
\* referrer." Modeling the counter as racy and the truth as exact is what makes that
\* divergence expressible at all. Byte-level memory reuse after the free is NOT modeled —
\* `k \notin store /\ holders[k] # {}` is the use-after-free predicate, not a simulation
\* of the corrupted read that follows it.
\*
\* Every state element cites the V7 §ref it transcribes from spec-data/v0.8.2/.
EXTENDS Naturals, FiniteSets

CONSTANTS NReq,        \* number of concurrent per-request dispatch activities (keep small for TLC)
          MaxPending,  \* §4.9(b)/§4.10: admission bound on admitted-not-yet-responded requests
          MaxStore,    \* §4.8/§4.9(b): live-key bound on the content store
          Serialize,   \* TRUE = §4.8 single-writer store-safety discipline;
                       \* FALSE = negative control: unsynchronized store -> data race
          Admit,       \* TRUE = §4.10/§4.9(b) admission control enforced;
                       \* FALSE = negative control: no admission bound -> unbounded pending
          SilentDrop,  \* FALSE = §4.9(c) deliver-or-signal honored (admitted work always responds);
                       \* TRUE = LIVENESS negative control: admitted work may be silently dropped
                       \*        (no response, pending leaked) -> Responsive + Recovers fail.
          SyncRefs     \* §4.8 (0.8.1, RT-13a). TRUE = the content-store lifetime refcount is
                       \* synchronized: its read-modify-write is ONE atomic step, so the counter
                       \* never diverges from the live-referrer set.
                       \* FALSE = negative control: the RMW is split (read; then write back
                       \*        read+/-1), so a concurrent update is LOST. That is the
                       \*        "unsynchronized refcount decrement" §4.8 names -> the entity
                       \*        is freed under a live referrer (use-after-free) and/or the
                       \*        key leaks -> NoUseAfterFree / ResourceBounded VIOLATED.

Reqs   == 1..NReq

\* §4.8 content store keys. THREE distinct keys against MaxStore = 2 is what makes the
\* live-key bound falsifiable (the v0.8.0 single-key model could not exceed any bound >= 1).
StoreKeys == {"k1", "k2", "k3"}

\* Which key each request touches. Requests 1 and 2 SHARE "k1" — that shared entity is the
\* refcount contention point (two concurrent referrers to one entity is the minimum shape
\* that can produce a premature free). Requests 3 and 4 hold distinct keys so the live set
\* can grow past the bound when refcounts leak. Fixed for the modeled bound NReq = 4.
Key(r) == CASE r <= 2 -> "k1"
            [] r  = 3 -> "k2"
            [] OTHER  -> "k3"

(*--algorithm store
variables
  store    = {},                          \* §4.8 content store / tree index (set of LIVE keys)
  rc       = [k \in StoreKeys |-> 0],      \* §4.8 (RT-13a) lifetime refcount — the racy counter
  holders  = [k \in StoreKeys |-> {}],     \* ground truth: requests still referencing k
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

  \* §4.8 (0.8.1, RT-13a) — THE USE-AFTER-FREE PREDICATE. A key absent from the store has
  \* been freed; if any request still holds a reference to it, that reference is dangling.
  \* On a manually-memory-managed substrate this is the double-free / use-after-free the
  \* §7b concurrency gate observed, and §4.8 classes it as a crash == a §4.9 violation.
  NoUseAfterFree    == \A k \in StoreKeys : (k \notin store) => (holders[k] = {})

  \* §4.9(b)/§4.10: resource use is bounded under load. pending never exceeds the admission
  \* bound; the LIVE-key set never exceeds its bound. With 3 keys and MaxStore = 2 this is a
  \* real constraint, discharged by the refcount actually freeing keys (§4.8) — a leaked
  \* refcount keeps a dead key live and breaks it.
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
variables tmp = 0;   \* local: the value read from rc during a SPLIT (unsynchronized) RMW
begin
  Pick:
    \* The environment / caller offers this request with some size + chain depth.
    with p \in {"ok", "over"}, d \in {"ok", "over"} do
      payload[self] := p || depth[self] := d;
    end with;
  AdmitStep:
    \* §4.10 admission control, in order: over-size -> 413; else over-depth -> 400; else
    \* §4.9(b) back-pressure when the in-flight bound is reached -> 503 refusal; else admit.
    \*
    \* On ADMIT this step also ACQUIRES the request's content-store reference (§4.8, RT-13a).
    \* Acquire-on-admit / release-on-respond is what ties the reference lifetime to the
    \* ADMITTED lifetime, and that coupling is what makes the §4.9(b) live-key bound follow
    \* from the admission bound: a key is live only while some admitted request references it,
    \* so |live keys| <= |admitted| <= MaxPending. A refcount defect breaks the coupling and
    \* therefore breaks the bound — the composition §4.8 asserts and the v0.8.0 model could
    \* not express.
    \*
    \* `holders` (truth) and `store` (liveness) move atomically here; the COUNTER is the only
    \* racy object. Under SyncRefs its read-modify-write is part of this same atomic step;
    \* otherwise we merely READ it here and write back at RefAcqCommit — the split that loses
    \* a concurrent update.
    if payload[self] = "over" then
      rstate[self] := "rej413";                       \* §4.10(a) 413 payload_too_large
    elsif depth[self] = "over" then
      rstate[self] := "rej400";                       \* §4.10(b) 400 chain_depth_exceeded
    elsif Admit /\ pending >= MaxPending then
      rstate[self] := "ref503";                       \* §4.9(b)/§4.10(c) clean back-pressure refusal
    else
      rstate[self] := "admitted" || pending := pending + 1 ||   \* §4.9(c): admitted -> owes a response
      holders[Key(self)] := holders[Key(self)] \cup {self} ||
      store := store \cup {Key(self)} ||
      rc := IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ + 1] ELSE rc ||
      tmp := rc[Key(self)];
    end if;
  RefAcqCommit:
    \* Write-back half of the SPLIT acquire (no-op when synchronized). If a second request
    \* read the same value before this write lands, that increment is LOST and the counter
    \* now UNDERCOUNTS the live referrers — the precondition for the premature free below.
    if rstate[self] = "admitted" /\ ~SyncRefs then
      rc[Key(self)] := tmp + 1;
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
    \* Mutate the bounded store, respond, leave the critical section, and RELEASE the §4.8
    \* reference. §4.9(c): every admitted request is delivered (responded), never silently
    \* dropped. Under SyncRefs the decrement and the free-decision are in this same atomic
    \* step as the truth update, so `rc = 0` and `holders = {}` cannot disagree.
    if rstate[self] = "writing" then
      if SilentDrop then
        \* LIVENESS NEG CONTROL (§4.9c): the request may instead be silently dropped — it leaves
        \* the critical section but never responds and its pending slot is leaked (the "admit and
        \* discard with no response" the spec calls the sharpest single violation). The reference
        \* is still released: the defect under test here is the lost RESPONSE, not a lost ref.
        either
          wrote[self] := TRUE ||
          writers := writers - 1 || pending := pending - 1 || rstate[self] := "responded" ||
          holders[Key(self)] := holders[Key(self)] \ {self} ||
          rc := IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc ||
          store := IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store ||
          tmp := rc[Key(self)];
        or
          writers := writers - 1 || rstate[self] := "dropped" ||   \* no response; pending NOT released
          holders[Key(self)] := holders[Key(self)] \ {self} ||
          rc := IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc ||
          store := IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store ||
          tmp := rc[Key(self)];
        end either;
      else
        wrote[self] := TRUE ||
        writers := writers - 1 ||
        pending := pending - 1 ||
        rstate[self] := "responded" ||
        holders[Key(self)] := holders[Key(self)] \ {self} ||
        rc := IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc ||
        store := IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store ||
        tmp := rc[Key(self)];
      end if;
    end if;
  RefRelCommit:
    \* Write-back half of the SPLIT release, and FREE when the counter says zero. This is the
    \* exact sentence §4.8 adds at 0.8.1: the free is driven by the COUNTER, so once the
    \* counter has lost an update it reads zero while a referrer is still live and the entity
    \* is freed under that referrer. NoUseAfterFree catches it. The mirror interleaving loses
    \* a DECREMENT instead, the counter never reaches zero, the key never leaves the live set,
    \* and ResourceBounded catches that.
    if ~SyncRefs /\ rstate[self] \in {"responded", "dropped"} then
      rc[Key(self)] := IF tmp > 0 THEN tmp - 1 ELSE 0 ||
      store := IF tmp - 1 <= 0 THEN store \ {Key(self)} ELSE store;
    end if;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "7d171691" /\ chksum(tla) = "ccdb922")
VARIABLES pc, store, rc, holders, writers, pending, rstate, payload, depth, 
          wrote

(* define statement *)
StoreRaceFree     == writers <= 1





NoUseAfterFree    == \A k \in StoreKeys : (k \notin store) => (holders[k] = {})





ResourceBounded   == /\ pending <= MaxPending
                     /\ Cardinality(store) <= MaxStore




CleanReject       ==
  /\ \A r \in Reqs : wrote[r] => rstate[r] \in {"writing", "responded"}
  /\ \A r \in Reqs : (payload[r] = "over") => rstate[r] \in {"new", "rej413"}
  /\ \A r \in Reqs : (payload[r] = "ok" /\ depth[r] = "over")
                        => rstate[r] \in {"new", "rej400"}

VARIABLE tmp

vars == << pc, store, rc, holders, writers, pending, rstate, payload, depth, 
           wrote, tmp >>

ProcSet == (Reqs)

Init == (* Global variables *)
        /\ store = {}
        /\ rc = [k \in StoreKeys |-> 0]
        /\ holders = [k \in StoreKeys |-> {}]
        /\ writers = 0
        /\ pending = 0
        /\ rstate = [r \in Reqs |-> "new"]
        /\ payload = [r \in Reqs |-> "ok"]
        /\ depth = [r \in Reqs |-> "ok"]
        /\ wrote = [r \in Reqs |-> FALSE]
        (* Process req *)
        /\ tmp = [self \in Reqs |-> 0]
        /\ pc = [self \in ProcSet |-> "Pick"]

Pick(self) == /\ pc[self] = "Pick"
              /\ \E p \in {"ok", "over"}:
                   \E d \in {"ok", "over"}:
                     /\ depth' = [depth EXCEPT ![self] = d]
                     /\ payload' = [payload EXCEPT ![self] = p]
              /\ pc' = [pc EXCEPT ![self] = "AdmitStep"]
              /\ UNCHANGED << store, rc, holders, writers, pending, rstate, 
                              wrote, tmp >>

AdmitStep(self) == /\ pc[self] = "AdmitStep"
                   /\ IF payload[self] = "over"
                         THEN /\ rstate' = [rstate EXCEPT ![self] = "rej413"]
                              /\ UNCHANGED << store, rc, holders, pending, tmp >>
                         ELSE /\ IF depth[self] = "over"
                                    THEN /\ rstate' = [rstate EXCEPT ![self] = "rej400"]
                                         /\ UNCHANGED << store, rc, holders, 
                                                         pending, tmp >>
                                    ELSE /\ IF Admit /\ pending >= MaxPending
                                               THEN /\ rstate' = [rstate EXCEPT ![self] = "ref503"]
                                                    /\ UNCHANGED << store, rc, 
                                                                    holders, 
                                                                    pending, 
                                                                    tmp >>
                                               ELSE /\ /\ holders' = [holders EXCEPT ![Key(self)] = holders[Key(self)] \cup {self}]
                                                       /\ pending' = pending + 1
                                                       /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ + 1] ELSE rc
                                                       /\ rstate' = [rstate EXCEPT ![self] = "admitted"]
                                                       /\ store' = (store \cup {Key(self)})
                                                       /\ tmp' = [tmp EXCEPT ![self] = rc[Key(self)]]
                   /\ pc' = [pc EXCEPT ![self] = "RefAcqCommit"]
                   /\ UNCHANGED << writers, payload, depth, wrote >>

RefAcqCommit(self) == /\ pc[self] = "RefAcqCommit"
                      /\ IF rstate[self] = "admitted" /\ ~SyncRefs
                            THEN /\ rc' = [rc EXCEPT ![Key(self)] = tmp[self] + 1]
                            ELSE /\ TRUE
                                 /\ rc' = rc
                      /\ pc' = [pc EXCEPT ![self] = "WBegin"]
                      /\ UNCHANGED << store, holders, writers, pending, rstate, 
                                      payload, depth, wrote, tmp >>

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
                /\ UNCHANGED << store, rc, holders, pending, payload, depth, 
                                wrote, tmp >>

WCommit(self) == /\ pc[self] = "WCommit"
                 /\ IF rstate[self] = "writing"
                       THEN /\ IF SilentDrop
                                  THEN /\ \/ /\ /\ holders' = [holders EXCEPT ![Key(self)] = holders[Key(self)] \ {self}]
                                                /\ pending' = pending - 1
                                                /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc
                                                /\ rstate' = [rstate EXCEPT ![self] = "responded"]
                                                /\ store' = (IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store)
                                                /\ tmp' = [tmp EXCEPT ![self] = rc[Key(self)]]
                                                /\ writers' = writers - 1
                                                /\ wrote' = [wrote EXCEPT ![self] = TRUE]
                                          \/ /\ /\ holders' = [holders EXCEPT ![Key(self)] = holders[Key(self)] \ {self}]
                                                /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc
                                                /\ rstate' = [rstate EXCEPT ![self] = "dropped"]
                                                /\ store' = (IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store)
                                                /\ tmp' = [tmp EXCEPT ![self] = rc[Key(self)]]
                                                /\ writers' = writers - 1
                                             /\ UNCHANGED <<pending, wrote>>
                                  ELSE /\ /\ holders' = [holders EXCEPT ![Key(self)] = holders[Key(self)] \ {self}]
                                          /\ pending' = pending - 1
                                          /\ rc' = IF SyncRefs THEN [rc EXCEPT ![Key(self)] = @ - 1] ELSE rc
                                          /\ rstate' = [rstate EXCEPT ![self] = "responded"]
                                          /\ store' = (IF SyncRefs /\ rc[Key(self)] - 1 = 0 THEN store \ {Key(self)} ELSE store)
                                          /\ tmp' = [tmp EXCEPT ![self] = rc[Key(self)]]
                                          /\ writers' = writers - 1
                                          /\ wrote' = [wrote EXCEPT ![self] = TRUE]
                       ELSE /\ TRUE
                            /\ UNCHANGED << store, rc, holders, writers, 
                                            pending, rstate, wrote, tmp >>
                 /\ pc' = [pc EXCEPT ![self] = "RefRelCommit"]
                 /\ UNCHANGED << payload, depth >>

RefRelCommit(self) == /\ pc[self] = "RefRelCommit"
                      /\ IF ~SyncRefs /\ rstate[self] \in {"responded", "dropped"}
                            THEN /\ /\ rc' = [rc EXCEPT ![Key(self)] = IF tmp[self] > 0 THEN tmp[self] - 1 ELSE 0]
                                    /\ store' = (IF tmp[self] - 1 <= 0 THEN store \ {Key(self)} ELSE store)
                            ELSE /\ TRUE
                                 /\ UNCHANGED << store, rc >>
                      /\ pc' = [pc EXCEPT ![self] = "Done"]
                      /\ UNCHANGED << holders, writers, pending, rstate, 
                                      payload, depth, wrote, tmp >>

req(self) == Pick(self) \/ AdmitStep(self) \/ RefAcqCommit(self)
                \/ WBegin(self) \/ WCommit(self) \/ RefRelCommit(self)

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

\* §4.8/§4.9(e) NON-VACUITY WITNESS (see PROPERTIES.md §C.4 and StoreWitness.cfg). TLC has no
\* ProVerif-style reachability query, so a witness is expressed as an invariant that MUST be
\* violated: if the store ever actually goes live, `store = {}` fails and TLC reports a
\* counterexample. Checking it GREEN would mean nothing in this model ever wrote — i.e. the
\* safety results above were vacuously true. Expected verdict: VIOLATION.
WitnessStoreLive == store = {}
====
