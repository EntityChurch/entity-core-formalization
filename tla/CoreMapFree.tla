---- MODULE CoreMapFree ----
\* T4, HALF TWO — the classifier. This module answers the only question that makes the
\* refinement result worth anything: for each component invariant that holds under the
\* mapping, is it true BECAUSE OF CORE, or true because the mapping made it true?
\*
\* THE METHOD. Core's reachable states are a subset of its type-correct ones. So:
\*
\*   * if a mapped component invariant is violated by SOME type-correct valuation, then the
\*     mapping does not force it, and its holding over Core's REACHABLE states is a fact
\*     about Core's behaviour. Call it CARRIED.
\*   * if it holds over EVERY type-correct valuation, it is a tautology of the mapping. Core
\*     could do anything at all and it would still be green. Call it MANUFACTURED.
\*
\* This module has the same variables the mapping reads, an `Init` that admits every
\* type-correct valuation of them, and `Next == UNCHANGED vars`. TLC therefore checks each
\* invariant against the FULL type space and nothing else. There is no behaviour here on
\* purpose — this is a question about the mapping, not about a protocol.
\*
\* HOW EACH VERDICT IS GRADED (D13). A run here asserts nothing by its exit status, exactly
\* as everywhere else in this repo: a CARRIED row is a cfg whose invariant TLC must REPORT
\* AS VIOLATED, and a MANUFACTURED row is a cfg whose invariant TLC must report as holding.
\* The two are opposite verdicts on the same kind of object, so each cfg declares which it
\* expects and `tla/Makefile` grades it (TLC_NEG for the carried rows, since "must be
\* violated" is the negative-control grader; TLC_GREEN for the manufactured ones).
\*
\* THE INVERSION IS DELIBERATE AND IS THE POINT. Here a VIOLATION is the good news: it means
\* the composed model is really carrying the component's property. A clean green means the
\* mapping is doing the work and Core is not. Anyone reading these rows in the gate table
\* should read them that way round, and the cfg comments say so individually.
\*
\* WHY NOT JUST READ THE MAPPING AND REASON ABOUT IT. Because that is what was done for
\* `StoreBounded` for two releases, and for the first draft of the Spin failure-signature
\* check, and for the delta witness that fired on the wrong state. D15's corollary: teeth-test
\* a gate rather than reasoning about it. Every classification below is a run.
EXTENDS Naturals, FiniteSets, RefMap

CONSTANT N
Peers == 1..N

\* Only the Core variables the mapping actually READS are free here. Adding the rest would
\* multiply the state space by a large factor to no purpose: an invariant's classification
\* cannot depend on a variable the mapping never looks at.
VARIABLES conn, cstate, store

vars == << conn, cstate, store >>

\* Every type-correct valuation, from Core.tla's own declarations:
\*   conn   = [p \in Peers |-> "new"]   with "established" reachable via the link process
\*   cstate = [p \in Peers |-> "init"]  with "sent" / "done" reachable via the client process
\*   store  = [p \in Peers |-> {}]      with {"k"} reachable via the server's handler write
Init ==
  /\ conn   \in [Peers -> {"new", "established"}]
  /\ cstate \in [Peers -> {"init", "sent", "done"}]
  /\ store  \in [Peers -> SUBSET {"k"}]

Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ conn   \in [Peers -> {"new", "established"}]
  /\ cstate \in [Peers -> {"init", "sent", "done"}]
  /\ store  \in [Peers -> SUBSET {"k"}]

\* ============================================================================
\* The component modules, under the mapping, per peer
\* ============================================================================
\* RefPeer is which peer's projection is under test. The mapping is per-connection because
\* Conn models ONE responder's connection; Core runs N of them on a ring. Checking peer 1 is
\* sufficient and the models are symmetric in it, which the CoreRefines rows in Core.tla
\* check across ALL peers rather than assuming.
CONSTANT RefPeer

CONN == INSTANCE Conn WITH
  MaxFrames       <- 1,
  Enforce         <- TRUE,
  DropFrame       <- FALSE,
  pc              <- MapConnPc,
  phase           <- MapPhase(conn[RefPeer]),
  issuedNonce     <- MapIssuedNonce(conn[RefPeer]),
  tokensIssued    <- MapTokens(conn[RefPeer]),
  everEstablished <- MapEver(conn[RefPeer]),
  dispatched      <- MapDispatched(cstate[RefPeer]),
  inbox           <- MapInbox,
  submitted       <- MapSubmitted,
  answered        <- MapAnswered,
  respHalted      <- MapRespHalted

STORE == INSTANCE Store WITH
  NReq            <- 1,
  MaxPending      <- 2,
  MaxStore        <- 2,
  Serialize       <- TRUE,
  Admit           <- TRUE,
  SilentDrop      <- FALSE,
  SyncRefs        <- TRUE,
  pc              <- MapStorePc,
  store           <- MapStoreSet(store[RefPeer]),
  rc              <- MapRc,
  holders         <- MapHolders,
  writers         <- MapWriters,
  pending         <- MapPending,
  rstate          <- MapRstate,
  payload         <- MapPayload,
  depth           <- MapDepth,
  wrote           <- MapWrote,
  \* `tmp` is a PlusCal scratch variable the translation emits for Store's `with` binding.
  \* No invariant mentions it; substituted only because INSTANCE requires every variable.
  tmp             <- 0

\* ============================================================================
\* The classification obligations — one cfg each, each with a DECLARED verdict
\* ============================================================================
\* Conn (§4.1-4.7). Expected: 1 carried, 2 manufactured.

\* EXPECT VIOLATED -> CARRIED. A type-correct valuation with cstate[RefPeer] = "sent" and
\* conn[RefPeer] = "new" falsifies it, so the mapping does NOT force it. Core's green on
\* this invariant is therefore a statement about Core's §4.2 gate, and it is the SAME
\* predicate Core states for itself as DispatchNeedsEstablished — reached here through
\* Conn's own text rather than a transcription of it.
FreeConnDispatched  == CONN!DispatchedImpliesEstablished

\* EXPECT HELD -> MANUFACTURED. MapTokens has range {0,1}, so `tokensIssued <= 1` is true of
\* the mapping and not of Core. Core models no token issuance whatever; §4.2's
\* no-reissue-on-reconnect rule is Conn's result alone.
FreeConnTokens      == CONN!TokenBounded

\* EXPECT HELD -> MANUFACTURED. MapIssuedNonce returns "N1" on exactly the states where
\* MapPhase returns "established", so the implication is true by construction of the
\* mapping. Core has no nonce; §4.6 step 1 is Conn's and Tamarin's (ledger row T1).
FreeConnNonce       == CONN!NoEstablishWithoutNonce

\* Store (§4.8-4.10). Expected: 0 carried, 3 manufactured — every one of Store's invariants
\* rests on state Core does not have. Core's own header already names these as structural
\* exclusions; these runs are what turn that disclosure into a measurement.

\* EXPECT HELD -> MANUFACTURED. MapWriters is the constant 0.
FreeStoreRaceFree   == STORE!StoreRaceFree

\* EXPECT HELD -> MANUFACTURED. MapHolders is constantly empty, so the use-after-free
\* predicate's consequent is unconditionally true. This is §4.8's RT-13a refcount clause,
\* and the composed model cannot express it.
FreeStoreUAF        == STORE!NoUseAfterFree

\* EXPECT HELD -> MANUFACTURED. MapPending is 0 <= 2, and MapStoreSet has range
\* {{}, {"k1"}} so its cardinality is 0 or 1 against a bound of 2. This is the SAME shape as
\* the vacuous `StoreBounded` Core.tla removed — which is the corroboration that matters:
\* the classifier independently rediscovers a vacuity this repo had already found by hand.
FreeStoreBounded    == STORE!ResourceBounded

\* EXPECT HELD -> MANUFACTURED. MapWrote is constantly FALSE and MapPayload / MapDepth are
\* constantly "ok", so all three conjuncts are vacuously satisfied.
FreeStoreReject     == STORE!CleanReject
====
