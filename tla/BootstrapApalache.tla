---- MODULE BootstrapApalache ----
\* NEW at 0.8.2's second gate audit — Apalache (SMT) cross-check of tla/Bootstrap.tla
\* (V8 §6.9 Bootstrap).
\*
\* WHY THIS EXISTS. §6.9 showed in COVERAGE-MATRIX.md as a single-tool ("TLC-only") result
\* while nothing modeled it at all — both §6.9 citations in the repo were DISCLAIMERS in
\* Register.tla's header saying bootstrap handlers are not modeled. Adding the module and
\* then leaving it on one engine would repeat the shape the audit was closing, so Bootstrap
\* lands on all three: TLC bounded-exhaustive, this port inductive, spin/bootstrap.pml as an
\* independent re-encoding.
\*
\* THE STRENGTHENING is `BootAllOrNothing` — nothing is dispatch-visible before all of its
\* facets exist. Neither NoRegistrationBeforeBootstrap nor ConnectPreAuthorized is inductive
\* without it: both guards test DISPATCHABILITY (`h \in disp`) while both properties assert
\* EXISTENCE (`Live(facets[h])`), and an arbitrary typed state may have those disagree. That
\* gap between "the index says it is there" and "it is there" is precisely the §6.9 hazard
\* the module exists for, so it is fitting that it is also what makes the proof go through.
EXTENDS Integers

CONSTANTS
  \* @type: Bool;
  AtomicPublish,
  \* @type: Bool;
  GateAll,
  \* @type: Bool;
  GateConnect

VARIABLES
  \* @type: Str -> Set(Str);
  facets,
  \* @type: Set(Str);
  disp,
  \* @type: Bool;
  registered,
  \* @type: Bool;
  established

vars == << facets, disp, registered, established >>

FACETS == {"manifest", "types", "grant", "sig", "iface"}
EARLY  == {"manifest", "iface"}
Boot   == {"tree", "handler", "connect"}

Live(s) == s = FACETS

\* ----- the invariants (transcribed from Bootstrap.tla) -----
BootAllOrNothing == \A h \in disp : Live(facets[h])

NoRegistrationBeforeBootstrap ==
  registered => (\A h \in Boot : Live(facets[h]))

ConnectPreAuthorized == established => Live(facets["connect"])

TypeOK ==
  /\ facets \in [Boot -> SUBSET FACETS]
  /\ disp \in SUBSET Boot
  /\ registered \in BOOLEAN
  /\ established \in BOOLEAN

InvAllOrNothing == TypeOK /\ BootAllOrNothing
InvRegGate      == TypeOK /\ BootAllOrNothing /\ NoRegistrationBeforeBootstrap
InvConnect      == TypeOK /\ BootAllOrNothing /\ ConnectPreAuthorized

\* ----- transitions (mirror of Bootstrap.tla) -----
Init ==
  /\ facets = [h \in Boot |-> {}]
  /\ disp = {}
  /\ registered = FALSE
  /\ established = FALSE

InstallBoot(h) ==
  /\ facets[h] = {}
  /\ IF AtomicPublish
       THEN /\ facets' = [facets EXCEPT ![h] = FACETS]
            /\ disp' = disp \union {h}
       ELSE /\ facets' = [facets EXCEPT ![h] = EARLY]
            /\ disp' = disp \union {h}
  /\ UNCHANGED << registered, established >>

InstallFinish(h) ==
  /\ facets[h] = EARLY
  /\ facets' = [facets EXCEPT ![h] = FACETS]
  /\ UNCHANGED << disp, registered, established >>

RegReady ==
  IF GateAll THEN \A h \in Boot : h \in disp
             ELSE "handler" \in disp

Register ==
  /\ ~registered
  /\ RegReady
  /\ registered' = TRUE
  /\ UNCHANGED << facets, disp, established >>

Establish ==
  /\ ~established
  /\ (GateConnect => "connect" \in disp)
  /\ established' = TRUE
  /\ UNCHANGED << facets, disp, registered >>

Next ==
  \/ \E h \in Boot : (InstallBoot(h) \/ InstallFinish(h))
  \/ Register
  \/ Establish
  \/ UNCHANGED vars

\* ----- inductive-step inits -----
IndInitAllOrNothing == InvAllOrNothing
IndInitRegGate      == InvRegGate
IndInitConnect      == InvConnect

\* ----- constant inits -----
ConstInitOK ==
  /\ AtomicPublish = TRUE /\ GateAll = TRUE /\ GateConnect = TRUE

\* NEG CONTROL: the index built from the step-4 manifests, before the step-6 grants.
ConstInitBugEarlyIndex ==
  /\ AtomicPublish = FALSE /\ GateAll = TRUE /\ GateConnect = TRUE

\* NEG CONTROL: registration admitted once system/handler is dispatchable, not once all
\* three bootstrap handlers exist.
ConstInitBugGate ==
  /\ AtomicPublish = TRUE /\ GateAll = FALSE /\ GateConnect = TRUE

\* NEG CONTROL: connections served before system/protocol/connect is installed.
ConstInitBugConnect ==
  /\ AtomicPublish = TRUE /\ GateAll = TRUE /\ GateConnect = FALSE
====
