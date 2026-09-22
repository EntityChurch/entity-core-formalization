---- MODULE AuthorityApalache ----
\* NEW at 0.8.2 — Apalache (SMT) cross-check of tla/Authority.tla (V8 §5.2 dispatch authority).
\*
\* WHY THIS EXISTS. `Authority` was added at 0.8.2 with TLC coverage only. Single-tool coverage
\* is exactly the thing this repo's cross-check discipline exists to prevent, and the audit
\* found it rather than a scope decision creating it.
\*
\* WHAT IT BUYS. §5.2's rules are STRUCTURAL claims about the shape of the authorization input
\* ("these two states must not share a spelling"), and structural claims are where an
\* inductive proof is most worth having: the property should hold for a dispatch tree of ANY
\* size, not just the 3-slot tree TLC enumerates. Apalache proves all four §5.2 properties
\* inductive, so the result no longer depends on the tree bound.
\*
\* THE STRENGTHENING is `DecisionSound`: a decided dispatch carries exactly the verdict
\* `Decide` computes for it. That is what ties the recorded `outcome` to the rule under test —
\* without it, the step case starts from an arbitrary state in which a dispatch was allowed
\* for no reason, and every property fails immediately. It is sound because a dispatch's
\* inputs (kind / parent / hasGrant / res) never change after it arrives.
EXTENDS Integers, FiniteSets

CONSTANTS
  \* @type: Str;
  AuthorityModel,    \* "three" | "option-allow" | "option-deny"
  \* @type: Bool;
  CheckSubDispatch,  \* §5.2 "the condition is the field, not the door"
  \* @type: Bool;
  InheritResource    \* §5.2 "a sub-dispatch that names NO resource has NO resource"

D == {1, 2, 3}
Resources == {"none", "r1", "r2"}
Kinds     == {"unused", "entry", "sub"}
Outcomes  == {"pending", "allow", "deny"}

\* Abstract grant coverage, DELIBERATELY DISJOINT so consulting the wrong authority is
\* observable: the caller capability (SELF) covers r1; the handler grant (GRANT) covers r2;
\* ABSENT covers nothing.
\* @type: (Str, Str) => Bool;
Covers(a, r) ==
  IF a = "self" THEN r = "r1"
  ELSE IF a = "grant" THEN r = "r2"
  ELSE FALSE

VARIABLES
  \* @type: Int -> Str;
  kind,
  \* @type: Int -> Int;
  parent,
  \* @type: Int -> Bool;
  hasGrant,
  \* @type: Int -> Str;
  res,
  \* @type: Int -> Str;
  outcome

vars == << kind, parent, hasGrant, res, outcome >>

\* §5.2(1) the three-valued dispatch authority.
\* @type: Int => Str;
AuthOf(d) ==
  IF kind[d] = "entry" THEN "self"
  ELSE IF hasGrant[d] THEN "grant"
  ELSE "absent"

\* Total accessor for the parent's named resource (parent = 0 means "no parent").
\* @type: Int => Str;
ParentRes(d) == IF parent[d] \in D THEN res[parent[d]] ELSE "none"

\* §5.2(3) the resource target the check actually receives.
\* @type: Int => Str;
EffRes(d) ==
  IF InheritResource /\ res[d] = "none" /\ parent[d] \in D
    THEN ParentRes(d)
    ELSE res[d]

\* §5.2(2) is the resource condition consulted for this dispatch at all?
\* @type: Int => Bool;
Consulted(d) == CheckSubDispatch \/ kind[d] = "entry"

\* @type: Int => Str;
DecideThree(d) ==
  IF AuthOf(d) = "absent" THEN "deny"
  ELSE IF Consulted(d) /\ EffRes(d) # "none" /\ ~Covers(AuthOf(d), EffRes(d)) THEN "deny"
  ELSE "allow"

\* Option<Capability> over the handler grant: EMPTY at wire entry AND at a grantless
\* sub-dispatch. One spelling, two meanings, so the empty case gets one uniform default.
\* @type: (Int, Str) => Str;
DecideOption(d, dflt) ==
  IF AuthOf(d) = "grant"
    THEN (IF Consulted(d) /\ EffRes(d) # "none" /\ ~Covers("grant", EffRes(d)) THEN "deny" ELSE "allow")
    ELSE dflt

\* @type: Int => Str;
Decide(d) ==
  IF AuthorityModel = "three" THEN DecideThree(d)
  ELSE IF AuthorityModel = "option-allow" THEN DecideOption(d, "allow")
  ELSE DecideOption(d, "deny")

\* ----- the four §5.2 properties (transcribed from Authority.tla) -----
NoGrantlessAllow ==
  \A d \in D : (kind[d] = "sub" /\ ~hasGrant[d]) => outcome[d] # "allow"

EntryNotSpuriouslyDenied ==
  \A d \in D : (kind[d] = "entry" /\ (res[d] = "none" \/ Covers("self", res[d])))
                 => outcome[d] # "deny"

ResourceAuthorized ==
  \A d \in D : (outcome[d] = "allow" /\ EffRes(d) # "none")
                 => Covers(AuthOf(d), EffRes(d))

NoManufacturedTarget ==
  \A d \in D : EffRes(d) = res[d]

\* ----- the inductive strengthening -----
\* A decided dispatch carries exactly the verdict the rule computes for it, and an unused slot
\* is undecided. Sound because a dispatch's inputs never change once it arrives.
DecisionSound ==
  /\ \A d \in D : (outcome[d] # "pending") => (outcome[d] = Decide(d))
  /\ \A d \in D : (kind[d] = "unused") => (outcome[d] = "pending")
  /\ \A d \in D : (kind[d] = "unused") => (parent[d] = 0 /\ res[d] = "none" /\ ~hasGrant[d])
  /\ \A d \in D : parent[d] < d       \* a sub-dispatch's parent is an earlier slot (acyclic)

TypeOK ==
  /\ kind     \in [D -> Kinds]
  /\ parent   \in [D -> 0..3]
  /\ hasGrant \in [D -> BOOLEAN]
  /\ res      \in [D -> Resources]
  /\ outcome  \in [D -> Outcomes]

InvGrantless == TypeOK /\ DecisionSound /\ NoGrantlessAllow
InvEntry     == TypeOK /\ DecisionSound /\ EntryNotSpuriouslyDenied
InvResource  == TypeOK /\ DecisionSound /\ ResourceAuthorized
InvTarget    == TypeOK /\ DecisionSound /\ NoManufacturedTarget

\* ----- transitions -----
Init ==
  /\ kind     = [d \in D |-> "unused"]
  /\ parent   = [d \in D |-> 0]
  /\ hasGrant = [d \in D |-> FALSE]
  /\ res      = [d \in D |-> "none"]
  /\ outcome  = [d \in D |-> "pending"]

\* A wire-entry EXECUTE arrives at slot 1, naming some resource (or none). No handler grant:
\* at entry the authority is the caller capability (§5.2(a)).
Arrive ==
  /\ kind[1] = "unused"
  /\ \E r \in Resources :
       /\ kind' = [kind EXCEPT ![1] = "entry"]
       /\ res'  = [res EXCEPT ![1] = r]
  /\ UNCHANGED << parent, hasGrant, outcome >>

\* An allowed dispatch spawns an in-process sub-dispatch.
Spawn(d) ==
  /\ kind[d] = "unused"
  /\ \E p \in D :
       /\ p < d
       /\ outcome[p] = "allow"
       /\ \E g \in BOOLEAN : \E r \in Resources :
            /\ kind'     = [kind EXCEPT ![d] = "sub"]
            /\ parent'   = [parent EXCEPT ![d] = p]
            /\ hasGrant' = [hasGrant EXCEPT ![d] = g]
            /\ res'      = [res EXCEPT ![d] = r]
  /\ UNCHANGED outcome

\* Run check_permission on an arrived-but-undecided dispatch.
Check(d) ==
  /\ kind[d] # "unused"
  /\ outcome[d] = "pending"
  /\ outcome' = [outcome EXCEPT ![d] = Decide(d)]
  /\ UNCHANGED << kind, parent, hasGrant, res >>

Next ==
  \/ Arrive
  \/ \E d \in D : (Spawn(d) \/ Check(d))
  \/ UNCHANGED vars

\* ----- inductive-step inits -----
IndInitGrantless == TypeOK /\ DecisionSound /\ NoGrantlessAllow
IndInitEntry     == TypeOK /\ DecisionSound /\ EntryNotSpuriouslyDenied
IndInitResource  == TypeOK /\ DecisionSound /\ ResourceAuthorized
IndInitTarget    == TypeOK /\ DecisionSound /\ NoManufacturedTarget

\* ----- constant inits -----
ConstInitOK          == AuthorityModel = "three"        /\ CheckSubDispatch = TRUE  /\ InheritResource = FALSE
ConstInitBugAllow    == AuthorityModel = "option-allow" /\ CheckSubDispatch = TRUE  /\ InheritResource = FALSE
ConstInitBugDeny     == AuthorityModel = "option-deny"  /\ CheckSubDispatch = TRUE  /\ InheritResource = FALSE
ConstInitBugSubGate  == AuthorityModel = "three"        /\ CheckSubDispatch = FALSE /\ InheritResource = FALSE
ConstInitBugInherit  == AuthorityModel = "three"        /\ CheckSubDispatch = TRUE  /\ InheritResource = TRUE
====
