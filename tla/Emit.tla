---- MODULE Emit ----
\* Phase 1 — increment 4: Emit pathway (V7 §6.10), per PHASE1-SCOPE.md subsystem D.
\* The emit primitive is the atomic state crossing of up to two steps — Store (write entity to
\* the content store) and Bind (update the tree binding at a path) — each firing an event ONLY
\* when it does real work. This module checks the event-iff-real-work contract and the
\* event_type derivation (including the v7.74 B2 deletion-marker carve-out).
\*
\* Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): entity content / hashing / CBOR are
\* abstracted to opaque hash tokens (type system + conformance own them). Modeled: the
\* store-membership and binding *state transitions* and the event-firing *decisions* they
\* drive. Core-only scope (§6.10 final para): a core peer's emit pathway has NO consumers, so
\* consumer cascade / async delivery / convergence (SYSTEM-COMPOSITION) is deferred to Phase 2.
\* Bind/store-write atomicity (§6.10 "atomic at the binding level") is the §4.8 single-writer
\* property already checked in increment 2 (Store.tla) — not re-modeled here. Every element
\* cites its V7 §ref.
EXTENDS Naturals

CONSTANTS Fire,           \* TRUE  = §6.10 event fires iff real work; FALSE = negative control:
                          \*         fire unconditionally (events on re-put / re-bind no-ops).
          MarkerDeletes,  \* FALSE = §6.10 v7.74 B2: bind to a deletion-marker fires "modified";
                          \*         TRUE = negative control: marker-bind fires "deleted".
          MaxOps,         \* bound on the emit-operation sequence (keep small for TLC).
          StallEmit       \* FALSE = the emit pathway always completes; TRUE = LIVENESS negative
                          \*         control: emit may halt early (ops < MaxOps) -> EmitTerminates fails.

Hashes == {"h1", "h2", "marker"}   \* "marker" stands for a system/deletion-marker entity (§6.10)
NULL   == "null"

\* The operations that drive emit: content_store.put (Store step only), tree_put (Store+Bind),
\* tree:delete (Bind to null). Single path — event semantics are per-path; multi-path is trivial.
Ops == {[kind |-> "cput", h |-> x] : x \in Hashes}
         \cup {[kind |-> "tput", h |-> x] : x \in Hashes}
         \cup {[kind |-> "tdel"]}

\* §6.10 event_type derivation: deleted if new is null; created if prev was null; else modified.
DerivedType(prev, new) ==
  IF new = NULL THEN "deleted"
  ELSE IF prev = NULL THEN "created" ELSE "modified"

(*--algorithm emit
variables
  store   = {},        \* content store: set of hashes present (§6.10 Store step domain)
  bound   = NULL,      \* tree binding at the path (§6.10 Bind step domain): a hash or NULL
  ops     = 0,
  \* ghosts recording the emit DECISION of the most recent step, for the iff-invariants:
  sEvt    = FALSE,     \* did the Store step fire a content-store event this step?
  tEvt    = FALSE,     \* did the Bind step fire a tree-change event this step?
  etype   = "none",    \* the event_type the Bind step would carry
  hashNew = FALSE,     \* (pre-state) was the stored hash new to the store?
  changed = FALSE,     \* (pre-state) did the binding at the path change?
  lastPrev = NULL,     \* prev_hash of the most recent Bind (for the event_type check)
  lastNew  = NULL,     \* new_hash of the most recent Bind
  halted   = FALSE;    \* liveness neg control: emit halted early

define
  \* §6.10: a content-store event fires IFF the hash was new; a tree-change event fires IFF the
  \* binding changed. The exact firing contract — the core of the emit pathway.
  EventIffRealWork == (sEvt = hashNew) /\ (tEvt = changed)

  \* §6.10: re-put of an existing hash, or re-bind to the current hash, fires no event (the
  \* no-op direction stated explicitly).
  NoEventOnNoop == (~hashNew => ~sEvt) /\ (~changed => ~tEvt)

  \* §6.10 (incl. v7.74 B2): when a tree-change event fires, its event_type matches the
  \* created/modified/deleted derivation — and a bind to a deletion-marker is "modified", not
  \* "deleted" (the marker's listing-visibility role is decoupled from emit semantics).
  EventTypeCorrect == tEvt => (etype = DerivedType(lastPrev, lastNew))
end define;

fair process emitter = "e"
begin
  Emit:
    while ops < MaxOps /\ ~halted do
      either
       with op \in Ops do
        if op.kind = "cput" then
          \* §6.10 Store step only: fire a content-store event iff the hash is new.
          hashNew  := (op.h \notin store) ||
          changed  := FALSE ||
          etype    := "none" ||
          lastPrev := bound || lastNew := bound ||
          sEvt     := IF Fire THEN (op.h \notin store) ELSE TRUE ||
          tEvt     := FALSE ||
          store    := store \cup {op.h} ||
          ops      := ops + 1;
        elsif op.kind = "tput" then
          \* §6.10 Store step then Bind step: content-store event iff hash new; tree-change
          \* event iff binding changed; event_type per derivation (marker -> modified, not deleted).
          hashNew  := (op.h \notin store) ||
          changed  := (bound # op.h) ||
          etype    := IF MarkerDeletes /\ op.h = "marker"
                         THEN "deleted"
                         ELSE DerivedType(bound, op.h) ||
          lastPrev := bound || lastNew := op.h ||
          sEvt     := IF Fire THEN (op.h \notin store) ELSE TRUE ||
          tEvt     := IF Fire THEN (bound # op.h) ELSE TRUE ||
          store    := store \cup {op.h} ||
          bound    := op.h ||
          ops      := ops + 1;
        else  \* tdel — §6.10 Bind to null (operational unbind): event_type "deleted".
          hashNew  := FALSE ||
          changed  := (bound # NULL) ||
          etype    := DerivedType(bound, NULL) ||
          lastPrev := bound || lastNew := NULL ||
          sEvt     := FALSE ||
          tEvt     := IF Fire THEN (bound # NULL) ELSE TRUE ||
          bound    := NULL ||
          ops      := ops + 1;
        end if;
       end with;
      or
        \* LIVENESS NEG CONTROL: emit halts before completing its op sequence.
        await StallEmit;
        halted := TRUE;
      end either;
    end while;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "909e77d3" /\ chksum(tla) = "fca59f2c")
VARIABLES pc, store, bound, ops, sEvt, tEvt, etype, hashNew, changed, 
          lastPrev, lastNew, halted

(* define statement *)
EventIffRealWork == (sEvt = hashNew) /\ (tEvt = changed)



NoEventOnNoop == (~hashNew => ~sEvt) /\ (~changed => ~tEvt)




EventTypeCorrect == tEvt => (etype = DerivedType(lastPrev, lastNew))


vars == << pc, store, bound, ops, sEvt, tEvt, etype, hashNew, changed, 
           lastPrev, lastNew, halted >>

ProcSet == {"e"}

Init == (* Global variables *)
        /\ store = {}
        /\ bound = NULL
        /\ ops = 0
        /\ sEvt = FALSE
        /\ tEvt = FALSE
        /\ etype = "none"
        /\ hashNew = FALSE
        /\ changed = FALSE
        /\ lastPrev = NULL
        /\ lastNew = NULL
        /\ halted = FALSE
        /\ pc = [self \in ProcSet |-> "Emit"]

Emit == /\ pc["e"] = "Emit"
        /\ IF ops < MaxOps /\ ~halted
              THEN /\ \/ /\ \E op \in Ops:
                              IF op.kind = "cput"
                                 THEN /\ /\ changed' = FALSE
                                         /\ etype' = "none"
                                         /\ hashNew' = (op.h \notin store)
                                         /\ lastNew' = bound
                                         /\ lastPrev' = bound
                                         /\ ops' = ops + 1
                                         /\ sEvt' = IF Fire THEN (op.h \notin store) ELSE TRUE
                                         /\ store' = (store \cup {op.h})
                                         /\ tEvt' = FALSE
                                      /\ bound' = bound
                                 ELSE /\ IF op.kind = "tput"
                                            THEN /\ /\ bound' = op.h
                                                    /\ changed' = (bound # op.h)
                                                    /\ etype' = (IF MarkerDeletes /\ op.h = "marker"
                                                                    THEN "deleted"
                                                                    ELSE DerivedType(bound, op.h))
                                                    /\ hashNew' = (op.h \notin store)
                                                    /\ lastNew' = op.h
                                                    /\ lastPrev' = bound
                                                    /\ ops' = ops + 1
                                                    /\ sEvt' = IF Fire THEN (op.h \notin store) ELSE TRUE
                                                    /\ store' = (store \cup {op.h})
                                                    /\ tEvt' = IF Fire THEN (bound # op.h) ELSE TRUE
                                            ELSE /\ /\ bound' = NULL
                                                    /\ changed' = (bound # NULL)
                                                    /\ etype' = DerivedType(bound, NULL)
                                                    /\ hashNew' = FALSE
                                                    /\ lastNew' = NULL
                                                    /\ lastPrev' = bound
                                                    /\ ops' = ops + 1
                                                    /\ sEvt' = FALSE
                                                    /\ tEvt' = IF Fire THEN (bound # NULL) ELSE TRUE
                                                 /\ store' = store
                         /\ UNCHANGED halted
                      \/ /\ StallEmit
                         /\ halted' = TRUE
                         /\ UNCHANGED <<store, bound, ops, sEvt, tEvt, etype, hashNew, changed, lastPrev, lastNew>>
                   /\ pc' = [pc EXCEPT !["e"] = "Emit"]
              ELSE /\ pc' = [pc EXCEPT !["e"] = "Done"]
                   /\ UNCHANGED << store, bound, ops, sEvt, tEvt, etype, 
                                   hashNew, changed, lastPrev, lastNew, halted >>

emitter == Emit

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == emitter
           \/ Terminating

Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(emitter)

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION

\* ===== Liveness (trivial for core-only emit — see header; consumers are Phase 2) =====

\* §6.10: the emit pathway always completes its work; a core-only peer has no consumers, so
\* there is no cascade/convergence obligation — this just confirms emit does not wedge.
EmitTerminates == <>(ops = MaxOps)
====
