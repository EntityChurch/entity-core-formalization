---- MODULE EmitApalache ----
\* Apalache (SMT) cross-check of the Emit module (tla/Emit.tla), cross-check #A per
\* docs/HANDOFF-CROSSCHECK.md Track A. A typed HAND-PORT of the §6.10 emit data layer — the
\* content store, the tree binding, and the per-step emit-decision ghosts (sEvt / tEvt / etype /
\* hashNew / changed / lastPrev / lastNew). The op-sequence counter (liveness only) is abstracted
\* away — Apalache proves SAFETY inductive over unbounded steps; EmitTerminates stays TLC + Spin.
\*
\* What this buys over TLC: TLC ENUMERATES at the bound; Apalache proves EventIffRealWork and
\* EventTypeCorrect INDUCTIVE via Z3 (base Init=>Inv, step Inv/\Next=>Inv'), holding for EVERY
\* reachable state. Each emit step re-establishes the ghosts consistently by construction, so
\* TypeOK is the only strengthening needed. The neg controls (Fire=FALSE / MarkerDeletes=TRUE) are
\* caught symbolically exactly where TLC's EmitFireBug / EmitMarkerBug are.
EXTENDS Naturals

CONSTANTS
  \* @type: Bool;
  Fire,           \* TRUE = §6.10 event fires iff real work; FALSE = neg control (fire unconditionally)
  \* @type: Bool;
  MarkerDeletes   \* FALSE = §6.10 v7.74 B2 (marker binds "modified"); TRUE = neg control ("deleted")

Hashes == {"h1", "h2", "marker"}   \* "marker" stands for a system/deletion-marker entity (§6.10)
NULL   == "null"

\* §6.10 event_type derivation: deleted if new is null; created if prev was null; else modified.
\* @type: (Str, Str) => Str;
DerivedType(prev, new) ==
  IF new = NULL THEN "deleted" ELSE IF prev = NULL THEN "created" ELSE "modified"

VARIABLES
  \* @type: Set(Str);
  store,
  \* @type: Str;
  bound,
  \* @type: Bool;
  sEvt,
  \* @type: Bool;
  tEvt,
  \* @type: Str;
  etype,
  \* @type: Bool;
  hashNew,
  \* @type: Bool;
  changed,
  \* @type: Str;
  lastPrev,
  \* @type: Str;
  lastNew

vars == << store, bound, sEvt, tEvt, etype, hashNew, changed, lastPrev, lastNew >>

\* ----- the safety invariants (transcribed from Emit.tla's define block) -----
EventIffRealWork == (sEvt = hashNew) /\ (tEvt = changed)                       \* §6.10
EventTypeCorrect == tEvt => (etype = DerivedType(lastPrev, lastNew))           \* §6.10 + v7.74 B2

\* ----- type/domain invariant (the only strengthening needed) -----
Binds == Hashes \cup {NULL}
TypeOK ==
  /\ store \in SUBSET Hashes
  /\ bound \in Binds
  /\ sEvt \in BOOLEAN /\ tEvt \in BOOLEAN /\ hashNew \in BOOLEAN /\ changed \in BOOLEAN
  /\ etype \in {"none", "created", "modified", "deleted"}
  /\ lastPrev \in Binds
  /\ lastNew \in Binds

InvIff  == TypeOK /\ EventIffRealWork
InvType == TypeOK /\ EventTypeCorrect

\* ----- transitions (data layer of Emit.tla's cput / tput / tdel) -----
Init ==
  /\ store = {}
  /\ bound = NULL
  /\ sEvt = FALSE
  /\ tEvt = FALSE
  /\ etype = "none"
  /\ hashNew = FALSE
  /\ changed = FALSE
  /\ lastPrev = NULL
  /\ lastNew = NULL

\* §6.10 Store step only: fire a content-store event iff the hash is new.
CPut(h) ==
  /\ hashNew' = (h \notin store)
  /\ sEvt' = (IF Fire THEN (h \notin store) ELSE TRUE)
  /\ changed' = FALSE
  /\ tEvt' = FALSE
  /\ etype' = "none"
  /\ lastPrev' = bound
  /\ lastNew' = bound
  /\ store' = store \cup {h}
  /\ bound' = bound

\* §6.10 Store then Bind step: content-store event iff hash new; tree-change event iff binding
\* changed; event_type per derivation (marker binds "modified", not "deleted").
TPut(h) ==
  /\ hashNew' = (h \notin store)
  /\ changed' = (bound # h)
  /\ sEvt' = (IF Fire THEN (h \notin store) ELSE TRUE)
  /\ tEvt' = (IF Fire THEN (bound # h) ELSE TRUE)
  /\ etype' = (IF MarkerDeletes /\ h = "marker" THEN "deleted" ELSE DerivedType(bound, h))
  /\ lastPrev' = bound
  /\ lastNew' = h
  /\ store' = store \cup {h}
  /\ bound' = h

\* §6.10 Bind to null (operational unbind): event_type "deleted".
TDel ==
  /\ hashNew' = FALSE
  /\ changed' = (bound # NULL)
  /\ sEvt' = FALSE
  /\ tEvt' = (IF Fire THEN (bound # NULL) ELSE TRUE)
  /\ etype' = DerivedType(bound, NULL)
  /\ lastPrev' = bound
  /\ lastNew' = NULL
  /\ store' = store
  /\ bound' = NULL

Next == (\E h \in Hashes : CPut(h) \/ TPut(h)) \/ TDel \/ UNCHANGED vars

\* ----- inductive-step inits: arbitrary typed state satisfying the invariant -----
IndInitIff  == TypeOK /\ EventIffRealWork
IndInitType == TypeOK /\ EventTypeCorrect

\* ----- constant inits (correct model + the two negative controls) -----
ConstInitOK        == Fire = TRUE  /\ MarkerDeletes = FALSE   \* §6.10 + v7.74 B2 honored
ConstInitBugFire   == Fire = FALSE /\ MarkerDeletes = FALSE   \* neg ctrl: event on no-op
ConstInitBugMarker == Fire = TRUE  /\ MarkerDeletes = TRUE    \* neg ctrl: marker fires "deleted"
====
