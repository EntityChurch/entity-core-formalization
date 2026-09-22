---- MODULE AuthoritySelectApalache ----
\* Apalache (SMT) second engine on tla/AuthoritySelect.tla — §6.8's authority-selection MUST.
\*
\* ══════════════════════════════════════════════════════════════════════════════════════
\* MODELING-PIN-OVERRIDE: v0.8.2.25
\* ══════════════════════════════════════════════════════════════════════════════════════
\* Same override, same reason, and the SUBJECT is what carries it: `docs/CORROBORATION.md`
\* holds `authority-select` with BOTH of its files at `v0.8.2.25`. Retargeting one file of a
\* multi-engine subject would publish two engines over two texts as agreement, which is the
\* failure AGENTS.md's retarget rule names. See AuthoritySelect.tla's header for why the rule
\* modeled here does not exist at the core pin at all.
\* ══════════════════════════════════════════════════════════════════════════════════════
\*
\* WHAT THE SECOND ENGINE BUYS, AND WHAT IT DOES NOT.
\*
\* BUYS: §6.8's rows are STRUCTURAL claims about which authority a check consults, and a
\* structural claim should hold for a dispatch chain of ANY length, not just the 3-hop chain
\* TLC enumerates. `MisclassificationCostsAvailabilityOnly` is the one that most wants this:
\* it quantifies over all three readings of the discriminator, and as a bounded result it is a
\* statement about chains of three. Proved inductive it is a statement about the rule.
\*
\* DOES NOT BUY: independence from the transcription. This is the same author's reading of the
\* same §6.8 text as the TLC module, so a misreading survives both (`docs/CORROBORATION.md`,
\* AGENTS.md D16's counter-clause). It also does not buy a second READER, and it cannot reach
\* the 5th wall — whether the three rows as transcribed are what the section means.
\*
\* ⭐ AND D16'S OWN ADVICE WAS FOLLOWED AND CAME BACK EMPTY, WHICH IS WORTH RECORDING RATHER
\* THAN OMITTING. The rule is "point the second engine at the first one's `Init`, not at its
\* invariants" — five times now that has found what the first engine structurally could not.
\* Here it finds nothing, because `AuthoritySelect.tla`'s `Init` restricts NOTHING: the chain
\* starts empty and each hop's origin, provenance and path are chosen freely, which is already
\* wider than any implementation. The domain restriction this module DOES carry is the hop
\* COUNT, and that is exactly what induction removes. A session that reports only the times the
\* technique paid is reporting a selected sample.
\*
\* THE STRENGTHENING is `DecisionSound`: a decided hop carries exactly the verdict `Decide`
\* computes for it, and an undecided hop is untouched. It is sound because a hop's inputs
\* (origin / prov / path) never change once it has arrived — `Check` writes only `outcome`.
\* It is also STRONG ENOUGH ON ITS OWN: every property here follows from it, because each is a
\* statement about what `Decide` returns. So `IndInit` is `TypeOK /\ DecisionSound` for every
\* row rather than one strengthened init per invariant, and ONE closure row covers them all.
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Str;
  AuthoritySource,   \* "selected" | "propagated" | "grant"
  \* @type: Str;
  Discriminator,     \* "serves" | "derivation" | "initiator"
  \* @type: Str;
  Row1Authorities,   \* "both" | "caller-only" | "grant-only"
  \* @type: Bool;
  PeerRootChecked    \* §6.8 row 3: FALSE = no check, which is the rule

H       == {1, 2, 3}
Origins == {"unused", "caller", "standing", "autonomous", "peerroot"}
Provs   == {"none", "named", "derived", "own"}
Paths   == {"pc", "pg", "pb", "ps", "pn"}
Outcomes == {"pending", "allow", "deny"}

\* Abstract path coverage — overlapping, NOT nested, so both directions of §6.8's dual are
\* observable. See the TLC module's header for why a nested relation would make row 1's
\* converse unfalsifiable.
\* @type: (Str, Str) => Bool;
Covers(a, p) ==
  IF a = "caller" THEN p \in {"pc", "pb"}
  ELSE IF a = "grant" THEN p \in {"pg", "pb"}
  ELSE IF a = "stale" THEN p = "ps"
  ELSE FALSE

VARIABLES
  \* @type: Int -> Str;
  origin,
  \* @type: Int -> Str;
  prov,
  \* @type: Int -> Str;
  path,
  \* @type: Int -> Str;
  outcome

\* The annotation is REQUIRED here and is not boilerplate: all four variables have the same
\* type, so Snowcat cannot tell a 4-tuple from a `Seq` and refuses the module ("Found 2
\* matching operator signatures"). tla/AuthorityApalache.tla needs no such line only because
\* its five variables happen to have mixed types.
\* @type: <<Int -> Str, Int -> Str, Int -> Str, Int -> Str>>;
vars == << origin, prov, path, outcome >>

\* @type: Int => Bool;
Live(h) == origin[h] = "caller"
\* @type: Int => Bool;
Ext(h) == origin[h] \in {"caller", "standing"}

\* The value in `ctx.caller_capability` at this hop — propagated unchanged, for attribution.
\* @type: Int => Str;
PropAt(h) == IF Ext(h) THEN "caller" ELSE "stale"

\* @type: (Str, Int) => Bool;
Row1Under(disc, h) ==
  IF disc = "serves" THEN (Live(h) /\ prov[h] \in {"named", "derived"})
  ELSE IF disc = "derivation" THEN prov[h] = "named"
  ELSE Ext(h)

\* @type: (Str, Str, Str, Int) => Set(Str);
AuthSetUnder(src, disc, r1, h) ==
  IF origin[h] = "peerroot" /\ ~PeerRootChecked
    THEN {}
  ELSE IF src = "propagated" THEN {PropAt(h)}
  ELSE IF src = "grant" THEN {"grant"}
  ELSE IF Row1Under(disc, h)
    THEN (IF r1 = "both" THEN {"caller", "grant"}
          ELSE IF r1 = "caller-only" THEN {"caller"}
          ELSE {"grant"})
  ELSE {"grant"}

\* @type: (Str, Str, Str, Int) => Str;
DecideUnder(src, disc, r1, h) ==
  IF \A a \in AuthSetUnder(src, disc, r1, h) : Covers(a, path[h])
    THEN "allow" ELSE "deny"

\* @type: Int => Set(Str);
AuthSet(h) == AuthSetUnder(AuthoritySource, Discriminator, Row1Authorities, h)
\* @type: Int => Str;
Decide(h) == DecideUnder(AuthoritySource, Discriminator, Row1Authorities, h)

\* @type: Int => Str;
SpecVerdict(h) == DecideUnder("selected", "serves", "both", h)
\* @type: Int => Set(Str);
SpecAuths(h) == AuthSetUnder("selected", "serves", "both", h)
\* @type: Int => Str;
V21Verdict(h) == DecideUnder("selected", "derivation", "both", h)
\* @type: Int => Str;
PropVerdict(h) == DecideUnder("propagated", "serves", "both", h)
\* @type: Int => Set(Str);
PropAuths(h) == AuthSetUnder("propagated", "serves", "both", h)

\* @type: Int => Bool;
Serves(h) == Live(h) /\ prov[h] \in {"named", "derived"}
\* @type: Int => Bool;
InScope(h) == origin[h] # "unused" /\ origin[h] # "peerroot"

\* ----- the §6.8 properties (transcribed from AuthoritySelect.tla) -----
NoDeputySubstitution ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ ~Serves(h))
                 => Covers("grant", path[h])

CallerFacingNeedsCaller ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ Serves(h))
                 => Covers("caller", path[h])

Row1CeilingHolds ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h) /\ Serves(h))
                 => Covers("grant", path[h])

HandlerGrantIsAlwaysCeiling ==
  \A h \in H : (outcome[h] = "allow" /\ InScope(h)) => Covers("grant", path[h])

\* Quantified over all three readings of the discriminator, so its green is a claim about the
\* RULE rather than about this run's constant — and unbounded here rather than over chains of
\* three, which is the row this port most wanted.
MisclassificationCostsAvailabilityOnly ==
  \A h \in H :
    \A d \in {"serves", "derivation", "initiator"} :
      (DecideUnder("selected", d, Row1Authorities, h) = "allow" /\ InScope(h))
        => Covers("grant", path[h])

NoStaleTokenAuthority ==
  \A h \in H : (origin[h] # "unused") => ("stale" \notin AuthSet(h))

OwnBehalfNotSpuriouslyDenied ==
  \A h \in H : (origin[h] # "unused" /\ InScope(h) /\ ~Serves(h) /\ Covers("grant", path[h]))
                 => outcome[h] # "deny"

PeerRootNeverDenied ==
  \A h \in H : (origin[h] = "peerroot") => outcome[h] # "deny"

\* ----- non-vacuity witnesses (each asserted IN ORDER TO BE VIOLATED) -----
WitnessDerivedAllowed ==
  ~(\E h \in H : prov[h] = "derived" /\ Serves(h) /\ outcome[h] = "allow")

WitnessStandingLeg ==
  ~(\E h \in H : origin[h] = "standing" /\ outcome[h] # "pending")

\* §6.8's own wire-invisibility sentence: both readings allow, and differ only in which
\* authority was consulted.
WitnessSilentSubstitution ==
  ~(\E h \in H :
      /\ origin[h] # "unused"
      /\ SpecVerdict(h) = "allow"
      /\ PropVerdict(h) = "allow"
      /\ SpecAuths(h) # PropAuths(h))

WitnessReadingsDiverge ==
  ~(\E h \in H : origin[h] # "unused" /\ SpecVerdict(h) # V21Verdict(h))

\* ----- the inductive strengthening -----
\* A decided hop carries exactly the verdict the rule computes for it; an unused slot is
\* undecided and carries the defaults. Sound because `Check` writes only `outcome`, and
\* `Decide(h)` reads only slot h's own inputs — so no transition can change the verdict owed
\* to a hop that has already been decided.
DecisionSound ==
  /\ \A h \in H : (outcome[h] # "pending") => (outcome[h] = Decide(h))
  /\ \A h \in H : (origin[h] = "unused") => (outcome[h] = "pending")
  /\ \A h \in H : (origin[h] = "unused") => (prov[h] = "none" /\ path[h] = "pn")
  /\ \A h \in H : (origin[h] # "unused") => (prov[h] # "none")

TypeOK ==
  /\ origin  \in [H -> Origins]
  /\ prov    \in [H -> Provs]
  /\ path    \in [H -> Paths]
  /\ outcome \in [H -> Outcomes]

IndInit == TypeOK /\ DecisionSound

\* ----- transitions -----
Init ==
  /\ origin  = [h \in H |-> "unused"]
  /\ prov    = [h \in H |-> "none"]
  /\ path    = [h \in H |-> "pn"]
  /\ outcome = [h \in H |-> "pending"]

Originate ==
  /\ origin[1] = "unused"
  /\ \E o \in Origins \ {"unused"} : \E v \in Provs \ {"none"} : \E p \in Paths :
       /\ origin' = [origin EXCEPT ![1] = o]
       /\ prov'   = [prov   EXCEPT ![1] = v]
       /\ path'   = [path   EXCEPT ![1] = p]
  /\ UNCHANGED outcome

Spawn(h) ==
  /\ origin[h] = "unused"
  /\ \E q \in H :
       /\ q < h
       /\ outcome[q] = "allow"
       /\ \E o \in Origins \ {"unused"} : \E v \in Provs \ {"none"} : \E p \in Paths :
            /\ origin' = [origin EXCEPT ![h] = o]
            /\ prov'   = [prov   EXCEPT ![h] = v]
            /\ path'   = [path   EXCEPT ![h] = p]
  /\ UNCHANGED outcome

Check(h) ==
  /\ origin[h] # "unused"
  /\ outcome[h] = "pending"
  /\ outcome' = [outcome EXCEPT ![h] = Decide(h)]
  /\ UNCHANGED << origin, prov, path >>

Next ==
  \/ Originate
  \/ \E h \in H : (Spawn(h) \/ Check(h))
  \/ UNCHANGED vars

\* ----- constant inits -----
\* §6.8 as written at v0.8.2.25.
ConstInitOK ==
  /\ AuthoritySource = "selected" /\ Discriminator = "serves"
  /\ Row1Authorities = "both"     /\ PeerRootChecked = FALSE

\* Controls — each weakens the model AWAY from §6.8, and each names a reading the section or
\* §6.3 records somebody holding.
ConstInitBugPropagated ==
  /\ AuthoritySource = "propagated" /\ Discriminator = "serves"
  /\ Row1Authorities = "both"       /\ PeerRootChecked = FALSE
ConstInitBugGrant ==
  /\ AuthoritySource = "grant" /\ Discriminator = "serves"
  /\ Row1Authorities = "both"  /\ PeerRootChecked = FALSE
ConstInitBugDerivation ==
  /\ AuthoritySource = "selected" /\ Discriminator = "derivation"
  /\ Row1Authorities = "both"     /\ PeerRootChecked = FALSE
ConstInitBugInitiator ==
  /\ AuthoritySource = "selected" /\ Discriminator = "initiator"
  /\ Row1Authorities = "both"     /\ PeerRootChecked = FALSE
ConstInitBugFlat ==
  /\ AuthoritySource = "selected"   /\ Discriminator = "serves"
  /\ Row1Authorities = "grant-only" /\ PeerRootChecked = FALSE
ConstInitBugPeerRoot ==
  /\ AuthoritySource = "selected" /\ Discriminator = "serves"
  /\ Row1Authorities = "both"     /\ PeerRootChecked = TRUE

\* FINDING cinits — NOT controls. `caller-only` is the shape §6.3's own single-`authority`
\* signature forces, so it flips the model TOWARD the spec's algorithm and away from the
\* spec's prose. See AuthoritySelectRow1Signature.cfg and AuthoritySelectDeputy.cfg for the
\* full statement and the retirement conditions.
ConstInitFindingSignature ==
  /\ AuthoritySource = "selected"    /\ Discriminator = "serves"
  /\ Row1Authorities = "caller-only" /\ PeerRootChecked = FALSE
ConstInitFindingDeputy ==
  /\ AuthoritySource = "selected"    /\ Discriminator = "initiator"
  /\ Row1Authorities = "caller-only" /\ PeerRootChecked = FALSE
====
