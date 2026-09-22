---- MODULE Authority ----
\* NEW MODULE at 0.8.2 — V7 §5.2 dispatch authority and resource binding.
\* Transcribed from spec-data/v0.8.2/ENTITY-CORE-PROTOCOL.md §5.2 (`check_permission`).
\*
\* WHY THIS MODULE EXISTS. 0.8.2 added three normative rules to §5.2, all of them about the
\* SHAPE of the authorization input rather than its arithmetic. They are structural claims —
\* "these two states must not share a spelling", "this check binds this dispatch", "this
\* field must not be inherited" — and a structural claim is exactly what a state-machine
\* model can falsify. Verbatim from §5.2:
\*
\*   (1) "THE AUTHORITY IS THREE-VALUED, NOT OPTIONAL (normative, 0.8.2). Modeling the
\*        dispatch authority as an optional capability collapses two states that MUST stay
\*        distinct, and either default is a defect:
\*          (a) SELF  — the peer dispatching as itself at wire entry...
\*          (b) GRANT — an in-process sub-dispatch... the executing handler's grant
\*          (c) ABSENT — a sub-dispatch whose parent holds no handler grant and for which
\*              no explicit capability was supplied. This MUST deny (403).
\*        An implementation that represents this as `Option<Capability>` has one spelling
\*        for (a) and (c). Defaulting the empty case to allow authorizes every grantless
\*        sub-dispatch; defaulting it to deny breaks entry dispatch."
\*
\*   (2) "THE CONDITION IS THE FIELD, NOT THE DOOR (normative, 0.8.2). This check binds
\*        EVERY dispatch that carries a resource target — wire entry and handler-to-handler
\*        (in-process) sub-dispatch alike. There is no wire-entry predicate and no
\*        is_sub_dispatch flag... A sub-dispatch path that skips it leaves `register`
\*        authorized by nothing."
\*
\*   (3) "A sub-dispatch that names NO resource has NO resource (normative, 0.8.2). The
\*        child MUST NOT inherit the parent's resource targets... Inheritance manufactures a
\*        target the caller never named."
\*
\* Rule (1) is the sharp one: it is a claim that NO two-valued encoding can be correct, which
\* is a statement about a pair of properties no single Option default satisfies. That is a
\* theorem, and this module checks it — the two Option negative controls each satisfy one
\* property and break the other, while the three-valued model satisfies both.
\*
\* THIS ALSO RETIRES A KNOWN THIN POSITIVE. tla/Reentry.tla abstracts the dispatch gate to
\* `Gate(p) == TRUE`, so denial is inexpressible there and NoDispatchWithoutGate cannot fail
\* (disclosed in PROPERTIES.md). Here denial is a reachable outcome and the gate is
\* load-bearing: three of the four properties below are violated by some control.
\*
\* MODEL SHAPE (D11 — what is and is not here). This is a STRUCTURAL model of the dispatch
\* tree, not a concurrency model: there is no interleaving, no time, no attacker. It builds a
\* bounded tree of dispatches (one wire entry + up to two in-process sub-dispatches) and
\* checks the authorization decision at each node. ABSTRACTED AWAY: signature verification,
\* chain walking, attenuation arithmetic and revocation — §5.2 steps 1-4 are Lean's and
\* Tamarin's, and this module starts after them, at `check_permission`. Grant coverage is an
\* abstract two-point scope (Covers below), because the rules under test are about WHICH
\* authority is consulted and WHETHER it is consulted, never about what a grant contains.
EXTENDS Naturals, FiniteSets

CONSTANTS
  AuthorityModel,    \* "three"        = §5.2 three-valued authority (SELF / GRANT / ABSENT). CORRECT.
                     \* "option-allow" = neg control: Option<Capability> over the handler grant,
                     \*                  empty case defaults to ALLOW. §5.2: "authorizes every
                     \*                  grantless sub-dispatch".
                     \* "option-deny"  = neg control: same collapse, empty case defaults to DENY.
                     \*                  §5.2: "breaks entry dispatch".
  CheckSubDispatch,  \* TRUE  = §5.2 "the condition is the field, not the door": the resource
                     \*         check binds sub-dispatches too. CORRECT.
                     \* FALSE = neg control: a wire-entry predicate / is_sub_dispatch flag, so a
                     \*         sub-dispatch's resource target is never checked.
  InheritResource    \* FALSE = §5.2 "a sub-dispatch that names NO resource has NO resource". CORRECT.
                     \* TRUE  = neg control: the child inherits the parent's resource targets,
                     \*         "manufactur[ing] a target the caller never named".

\* Three dispatch slots: slot 1 is the wire-entry EXECUTE; slots 2 and 3 are in-process
\* sub-dispatches of an already-allowed dispatch. Bounded and small — the rules under test are
\* per-node structural properties, so depth 3 exercises entry, sub-of-entry and sub-of-sub.
D == 1..3

\* Two resource targets, plus the "names no resource" case §5.2 calls out explicitly.
Resources == {"none", "r1", "r2"}

\* Abstract grant coverage. The caller capability (SELF) covers r1; the executing handler's
\* grant (GRANT) covers r2; ABSENT covers nothing. Deliberately DISJOINT so that consulting
\* the wrong authority is observable — that disjointness is the whole point of the abstraction.
Covers(a, r) ==
  CASE a = "self"  -> r = "r1"
    [] a = "grant" -> r = "r2"
    [] OTHER       -> FALSE

VARIABLES
  kind,      \* D -> {"unused","entry","sub"}   the dispatch's origin
  parent,    \* D -> 0..3   the dispatch that spawned it (0 = none / wire entry)
  hasGrant,  \* D -> BOOLEAN   does the handler executing this sub-dispatch hold a §6.8 grant?
  res,       \* D -> Resources   the resource target this dispatch NAMES (§5.2: what its caller named)
  outcome    \* D -> {"pending","allow","deny"}   the check_permission verdict

vars == << kind, parent, hasGrant, res, outcome >>

\* ---- §5.2(1): the three-valued dispatch authority ----
\* At wire entry the authority is the caller capability on the envelope (SELF) — "supplied
\* explicitly, never inferred". For an in-process sub-dispatch it is the executing handler's
\* grant (GRANT) if it holds one, and otherwise ABSENT, which MUST deny.
AuthOf(d) ==
  CASE kind[d] = "entry" -> "self"
    [] hasGrant[d]       -> "grant"
    [] OTHER             -> "absent"

\* ---- §5.2(3): the resource target the check actually receives ----
\* Correct: exactly what this dispatch named. Negative control: a child that named nothing
\* inherits its parent's target — a target its own caller never named.
EffRes(d) ==
  IF InheritResource /\ res[d] = "none" /\ parent[d] # 0
    THEN res[parent[d]]
    ELSE res[d]

\* ---- §5.2(2): is the resource condition even consulted for this dispatch? ----
\* Correct: the condition is the FIELD (`resource is not null`), so it binds every dispatch.
\* Negative control: the condition is the DOOR (a wire-entry predicate), so sub-dispatches skip it.
Consulted(d) == CheckSubDispatch \/ kind[d] = "entry"

\* ---- the check_permission verdict under each authority encoding ----
\* THREE-VALUED: ABSENT denies outright (§5.2(c) "MUST deny (403)"); otherwise the named
\* resource, when present and consulted, must be covered by THIS dispatch's authority.
DecideThree(d) ==
  IF AuthOf(d) = "absent" THEN "deny"
  ELSE IF Consulted(d) /\ EffRes(d) # "none" /\ ~Covers(AuthOf(d), EffRes(d)) THEN "deny"
  ELSE "allow"

\* OPTION<CAPABILITY>: the slot holds the executing handler's grant, so it is EMPTY both at
\* wire entry (there is no handler grant — the authority is the envelope's caller capability)
\* and at a grantless sub-dispatch. One spelling, two meanings. The implementation therefore
\* CANNOT branch on which one it is; the empty case gets one uniform default, and `dflt` is
\* that default. Encoding the collapse honestly is the point: an Option model that could tell
\* the two apart would not be collapsed.
DecideOption(d, dflt) ==
  IF AuthOf(d) = "grant"
    THEN (IF Consulted(d) /\ EffRes(d) # "none" /\ ~Covers("grant", EffRes(d)) THEN "deny" ELSE "allow")
    ELSE dflt

Decide(d) ==
  CASE AuthorityModel = "three"        -> DecideThree(d)
    [] AuthorityModel = "option-allow" -> DecideOption(d, "allow")
    [] OTHER                           -> DecideOption(d, "deny")

\* ===== transitions =====
Init ==
  /\ kind     = [d \in D |-> "unused"]
  /\ parent   = [d \in D |-> 0]
  /\ hasGrant = [d \in D |-> FALSE]
  /\ res      = [d \in D |-> "none"]
  /\ outcome  = [d \in D |-> "pending"]

\* A wire-entry EXECUTE arrives at slot 1, naming some resource target (or none). It carries
\* no handler grant: at entry the authority is the caller capability (§5.2(a)).
Arrive ==
  /\ kind[1] = "unused"
  /\ \E r \in Resources :
       /\ kind'  = [kind  EXCEPT ![1] = "entry"]
       /\ res'   = [res   EXCEPT ![1] = r]
  /\ UNCHANGED << parent, hasGrant, outcome >>

\* An allowed dispatch spawns an in-process sub-dispatch. The executing handler may or may
\* not hold a §6.8 handler grant, and the child names its own resource target (or none).
Spawn(d) ==
  /\ kind[d] = "unused"
  /\ \E p \in D :
       /\ p < d
       /\ outcome[p] = "allow"
       /\ \E g \in BOOLEAN : \E r \in Resources :
            /\ kind'     = [kind     EXCEPT ![d] = "sub"]
            /\ parent'   = [parent   EXCEPT ![d] = p]
            /\ hasGrant' = [hasGrant EXCEPT ![d] = g]
            /\ res'      = [res      EXCEPT ![d] = r]
  /\ UNCHANGED outcome

\* Run check_permission on a dispatch that has arrived but not yet been decided.
Check(d) ==
  /\ kind[d] # "unused"
  /\ outcome[d] = "pending"
  /\ outcome' = [outcome EXCEPT ![d] = Decide(d)]
  /\ UNCHANGED << kind, parent, hasGrant, res >>

Next ==
  \/ Arrive
  \/ \E d \in D : (Spawn(d) \/ Check(d))
  \/ UNCHANGED vars      \* stuttering: the tree may stop growing at any size

Spec == Init /\ [][Next]_vars

\* ===== Properties =====

\* SAFETY — §5.2(c): "a sub-dispatch whose parent holds no handler grant and for which no
\* explicit capability was supplied... MUST deny (403)." This is the SECURITY half of the
\* three-valued claim. Violated by option-allow, which "authorizes every grantless
\* sub-dispatch".
NoGrantlessAllow ==
  \A d \in D : (kind[d] = "sub" /\ ~hasGrant[d]) => outcome[d] # "allow"

\* SAFETY — §5.2(a): a wire-entry dispatch whose caller capability covers what it named must
\* not be refused. This is the AVAILABILITY half of the three-valued claim. Violated by
\* option-deny, which "breaks entry dispatch".
\*
\* Together with NoGrantlessAllow this is the theorem: the two properties are jointly
\* satisfiable ONLY by an encoding that distinguishes (a) from (c). Neither Option default
\* holds both — which is precisely what §5.2 asserts and why the third state is normative.
EntryNotSpuriouslyDenied ==
  \A d \in D : (kind[d] = "entry" /\ (res[d] = "none" \/ Covers("self", res[d])))
                 => outcome[d] # "deny"

\* SAFETY — §5.2(2) "the condition is the field, not the door": no dispatch is ever allowed
\* while carrying a resource target its own authority does not cover — sub-dispatches
\* included. Violated by CheckSubDispatch = FALSE, which is the case §5.2 describes as
\* leaving `register` "authorized by nothing".
ResourceAuthorized ==
  \A d \in D : (outcome[d] = "allow" /\ EffRes(d) # "none")
                 => Covers(AuthOf(d), EffRes(d))

\* SAFETY — §5.2(3) "a sub-dispatch that names NO resource has NO resource": the target the
\* check receives is always the target this dispatch actually named. Violated by
\* InheritResource = TRUE, which "manufactures a target the caller never named".
NoManufacturedTarget ==
  \A d \in D : EffRes(d) = res[d]

\* NON-VACUITY WITNESS (PROPERTIES.md §C.4 / AuthorityWitness.cfg). Asserted as an invariant
\* that MUST FAIL: a violation exhibits a reachable state in which a sub-dispatch was actually
\* ALLOWED, proving the properties above are not vacuously true of a model in which nothing is
\* ever authorized. Expected verdict: VIOLATION.
WitnessSubAllowed == ~(\E d \in D : kind[d] = "sub" /\ outcome[d] = "allow")
====
