/-
  entity-core-formalization — KS-9c: is canonicalizing a capability's `resources` patterns
  at MINT extensionally equivalent to canonicalizing them at MATCH?

  THE ASK. `entity-system-architecture`
  `ROUTING-2026-09-12-e-…-the-frame-equivalence-is-the-highest-value-thing-you-can-model-…`
  §1: *"Prove or refute: canonicalizing a capability's `resources` patterns at MINT is
  extensionally equivalent to canonicalizing them at MATCH, across the whole scope algebra."*
  Their ruling (`DESIGN-REGISTER` CP-16) is that the two are equivalent and mint-time is the
  better design; it rests on a seven-case hand analysis, **one row of the first such analysis
  was wrong**, and the change is scheduled. Their §4 is five places to attack, written as a
  target list rather than a confirmation list. This file is the answer to items 2, 3 and 4.

  THE INFORMAL ARGUMENT WE WERE ASKED TO CHECK. The frame is a pure function of
  `(pattern, granter)`; `granter` is a content hash, hence frozen when the capability is
  signed; so match-time canonicalization *recomputes a constant*, and equivalence is the
  statement that recomputing a constant yields the constant.

  WHAT IS MEASURED HERE, AND ON WHOSE DEFINITIONS. Everything below runs against
  `EntityCore.Capability` — keystone's OWN functions, imported from the peer's tree and
  elaborated by the Lean the peer pins, inside a COPY of that tree (`tools/lean-lemma.py`).
  `canonSegs`, `matchesSeg`, `matchesSegNM`, `covered`, `matchesScope`, `scopeSubset` are
  theirs. `mint`, `joinAbs` and the sweeps are ours.

  WHAT IS *NOT* MEASURED, STATED FIRST BECAUSE THE PACKET ASKED US TO (§6a — *"a model should
  say what it does not range over"*, the standing correction arch owed us after citing the
  A-31 differential past its domain):

    * **Their §4 item 1 — the multi-granter root — is NOT decided here.** §5.5a canonicalizes
      *"against the granter's `peer_id`"* and `system/capability/multi-granter` has no
      `peer_id` field. That is a question about WHICH frame, and every sweep below is
      parameterised over the frame and therefore says nothing about how it is chosen. What
      this file does contribute is the shape of the answer: the results are **frame-agnostic**
      (`Q1`), so if a frame exists at all, equivalence does not depend on which one.
    * **Their §4 item 5 — identity rotation — is NOT decided here.** It asks whether a
      capability's namespace may follow a rotated identity, which is a property of
      `EXTENSION-IDENTITY`'s key lifecycle and of `granter`'s immutability, not of the matcher.
      Routed as a question, not answered as a measurement.
    * **`operations` and `peers` are out of frame by construction** — id-scope patterns are
      never put through the §5.4 transforms (§5.2, 0.8.2.24's scoping of the sentinel), so
      "canonicalize at mint" is not a thing that happens to them. Q4 measures that rather than
      assuming it.
    * The pattern alphabet is an INPUT SET and therefore a claim. `Q5` is the control that
      says so out loud, in the shape this repo learned on A-31: narrow the alphabet to the
      forms everyone writes tests for and the sweep reports clean while asserting nothing.
-/
import EntityCoreProofs.CapabilityProofs

namespace EntityCoreFormalization.KS9c

open EntityCore.Capability

-- ── the two readings ────────────────────────────────────────────────────────────────

/-- Render canonical segments back to the absolute string a mint-time implementation would
store and sign. Inverse of `splitSegs` on every value `canonSegs` produces (checked by `Q0`,
not assumed — `splitSegs` drops a leading empty and keeps a trailing one, so the round trip
is a fact about that asymmetry rather than an identity). -/
def joinAbs (segs : List String) : String := "/" ++ String.intercalate "/" segs

/-- MINT-TIME (proposed): canonicalize once, against the granter, at `request`/`delegate`
admission. The stored pattern is absolute and carries no frame. -/
def mint (granter p : String) : String := joinAbs (canonSegs granter p)

-- MATCH-TIME (shipped, §5.5a) needs no definition: the pattern is stored as written and
-- canonicalized against the granter at every evaluation, which is what keystone's functions
-- already do. Every sweep below calls them directly for that arm.

/-- A minted pattern is refused at admission when it canonicalizes to the sentinel
(§5.4, 0.8.2.21, scoped to path-scope 0.8.2.24) — the capability never exists. Under
match-time the same pattern exists and is refused at evaluation. Arch's §4 item 3 asks
whether those are ever different verdicts; `Q3` measures it. -/
def refusedAtMint (granter p : String) : Bool := canonSegs granter p == neverMatch

-- ── the alphabet, and it is an input set ────────────────────────────────────────────

/-- Path-scope operand forms. The first five are the §5-census cells (`concrete`,
`trailing/*`, `/*/interior`, `bare *`, `NEVER_MATCH`); the rest are the shapes that make the
frame visible — relative vs absolute spellings of the same intent, the trailing-slash listing
marker, the empty pattern, and both reserved prefixes. -/
def patterns : List String :=
  [ "tree/get", "/pA/tree/get", "/pB/tree/get"
  , "tree/*", "/pA/tree/*"
  , "*", "/*", "/pA/*"
  , "*/apply", "/pA/*/apply"
  , "tree/", "", "../x", "./x", "*/secret" ]

/-- Distinct frames: two granters and a third, unrelated peer used to show that a MINTED
pattern's verdict does not depend on the frame supplied at evaluation. -/
def frames : List String := ["pA", "pB"]
def alienFrame : String := "pZ"

def targets : List String :=
  [ "/pA/tree/get", "/pB/tree/get", "/pA/tree/", "/pA/tree/get/deep"
  , "/pA/apply", "/pA/compute/apply", "/pA/*", "/never-match" ]

/-- Witness lines are declared in `lean/lemma-gate.expect` one-to-one, so an empty list must
print a stable token rather than a trailing space -- otherwise the declaration and the output
differ by whitespace and the gate reports a mismatch that is about formatting. -/
def witnesses (label : String) (xs : List String) : String :=
  label ++ ": " ++ (if xs.isEmpty then "none" else String.intercalate " " xs)

-- ── Q0. does a minted pattern round-trip? ───────────────────────────────────────────

/-- The kernel of claim E: re-canonicalizing a minted pattern under ANY frame returns the
segments minting produced. If this ever fails, mint-time and match-time are not the same
function and nothing below matters. -/
def roundTrips (evalFrame granter p : String) : Bool :=
  canonSegs evalFrame (mint granter p) == canonSegs granter p

def q0 : List (String × String × String) :=
  (frames.flatMap fun g => (alienFrame :: frames).flatMap fun f =>
    patterns.filterMap fun p => if roundTrips f g p then none else some (g, f, p))

#eval s!"Q0 round-trip      pairs={patterns.length * frames.length * (frames.length+1)} fail={q0.length}"
#eval witnesses "Q0 witnesses" (q0.map fun t => s!"{t.1}/{t.2.1}:{t.2.2}")

-- ── Q1. L1/L2 — `matchesScope` under both readings ──────────────────────────────────

def mintScope (granter : String) (s : Scope) : Scope :=
  { incl := s.incl.map (mint granter), excl := s.excl.map (mint granter) }

/-- Match-time: the local peer is the frame `matchesScope` uses (keystone transcribes §5.2's
loop literally). Mint-time: the patterns are already absolute, and we deliberately evaluate
them under `alienFrame` — if the reading is equivalent, an unrelated frame cannot matter. -/
def q1 : List (String × String × String) :=
  frames.flatMap fun g =>
    patterns.flatMap fun ip =>
      targets.filterMap fun tgt =>
        let s : Scope := { incl := [ip], excl := [] }
        let matchT := matchesScope g tgt s ScopeKind.path
        let mintT  := matchesScope alienFrame tgt (mintScope g s) ScopeKind.path
        if matchT == mintT then none else some (g, ip, tgt)

#eval s!"Q1 L1/L2 include   pairs={frames.length * patterns.length * targets.length} disagree={q1.length}"
#eval witnesses "Q1 witnesses" (q1.map fun t => s!"{t.1}|{t.2.1}|{t.2.2}")

/-- The exclude side of the same layer. Arch §4 item 4: *"model the exclude side; it is where
every defect in this arc has been."* -/
def q1x : List (String × String × String) :=
  frames.flatMap fun g =>
    patterns.flatMap fun xp =>
      targets.filterMap fun tgt =>
        let s : Scope := { incl := ["/*"], excl := [xp] }
        let matchT := matchesScope g tgt s ScopeKind.path
        let mintT  := matchesScope alienFrame tgt (mintScope g s) ScopeKind.path
        if matchT == mintT then none else some (g, xp, tgt)

#eval s!"Q1x L1/L2 exclude  pairs={frames.length * patterns.length * targets.length} disagree={q1x.length}"
#eval witnesses "Q1x witnesses" (q1x.map fun t => s!"{t.1}|{t.2.1}|{t.2.2}")

-- ── Q2. L3/L4 — `scope_subset` with per-link frames ─────────────────────────────────

/-- Arch §4 item 2, and the one they said to take if we only took one: under match-time each
link's subset check canonicalizes each side against THAT LINK's granter; under mint-time both
sides are already absolute. Every (child pattern × parent pattern × child frame × parent
frame) combination, both arms. -/
def q2 : List (String × String × String × String) :=
  frames.flatMap fun cf =>
    frames.flatMap fun pf =>
      patterns.flatMap fun cp =>
        patterns.filterMap fun pp =>
          let c : Scope := { incl := [cp], excl := [] }
          let p : Scope := { incl := [pp], excl := [] }
          let matchT := scopeSubset cf pf c p
          let mintT  := scopeSubset alienFrame alienFrame (mintScope cf c) (mintScope pf p)
          if matchT == mintT then none else some (cf, pf, cp, pp)

#eval s!"Q2 L3/L4 include   pairs={frames.length^2 * patterns.length^2} disagree={q2.length}"
#eval witnesses "Q2 witnesses" (q2.map fun t => s!"{t.1}/{t.2.1}|{t.2.2.1}<={t.2.2.2}")

def q2x : List (String × String × String × String) :=
  frames.flatMap fun cf =>
    frames.flatMap fun pf =>
      patterns.flatMap fun cp =>
        patterns.filterMap fun pp =>
          let c : Scope := { incl := [], excl := [cp] }
          let p : Scope := { incl := [], excl := [pp] }
          let matchT := scopeSubset cf pf c p
          let mintT  := scopeSubset alienFrame alienFrame (mintScope cf c) (mintScope pf p)
          if matchT == mintT then none else some (cf, pf, cp, pp)

#eval s!"Q2x L3/L4 exclude  pairs={frames.length^2 * patterns.length^2} disagree={q2x.length}"
#eval witnesses "Q2x witnesses" (q2x.map fun t => s!"{t.1}/{t.2.1}|{t.2.2.1}<={t.2.2.2}")

-- ── Q3. the sentinel: same verdict, different route? ────────────────────────────────

/-- Arch §4 item 3. Under mint-time an unmatchable pattern is caught at admission and the
capability never exists; under match-time it exists and is refused at evaluation. Two
questions, and only the second is about the matcher:
  (a) does the sentinel SURVIVE minting — i.e. does a pattern that is unmatchable at match
      time also refuse at mint, and vice versa? If the two sets differ, the readings refuse
      different capabilities.
  (b) for patterns that mint successfully, is the matcher's verdict the same? That is Q1/Q2. -/
def q3Disagree : List (String × String) :=
  frames.flatMap fun g =>
    patterns.filterMap fun p =>
      -- match-time "unmatchable" == the sentinel reached at evaluation under the granter frame
      let matchUnmatchable := canonSegs g p == neverMatch
      if matchUnmatchable == refusedAtMint g p then none else some (g, p)

def q3Refused : List (String × String) :=
  frames.flatMap fun g => patterns.filterMap fun p =>
    if refusedAtMint g p then some (g, p) else none

#eval s!"Q3 sentinel        refused-at-mint={q3Refused.length} set-differs={q3Disagree.length}"
#eval witnesses "Q3 refused-at-mint set" (q3Refused.map fun t => s!"{t.1}|{t.2}")

-- ── Q4. id-scope is out of frame by construction ────────────────────────────────────

/-- 0.8.2.24 N2 scopes `NEVER_MATCH` to path-scope, and §5.2's id-scope grammar forbids the
§5.4 transforms. So for `operations`/`peers` there is nothing to canonicalize and the two
readings are the same evaluation. Measured rather than assumed: `matchesScope … .id` must be
frame-independent for every pattern in the alphabet. -/
def q4 : List (String × String) :=
  patterns.flatMap fun ip =>
    targets.filterMap fun tgt =>
      let s : Scope := { incl := [ip], excl := [] }
      if matchesScope "pA" tgt s ScopeKind.id == matchesScope "pB" tgt s ScopeKind.id
      then none else some (ip, tgt)

#eval s!"Q4 id-scope frame-independent  pairs={patterns.length * targets.length} frame-sensitive={q4.length}"

-- ── Q5. the control: narrow the alphabet, get a clean answer to a smaller question ──

/-- `neg-eval`'s shape, inline. Restricted to the operand forms everyone writes tests for —
no reserved prefix, no leading `*`, no absolute spelling — every sweep above reports zero, and
that zero asserts nothing. This row exists so a future reader cannot mistake a clean headline
for a covered domain. It is the A-31 lesson: *the pair list of a differential is an input set,
and the bound you read off it is a claim.* -/
def plainPatterns : List String := ["tree/get", "tree/*", "*", "tree/"]

def q5 : Nat :=
  (frames.flatMap fun cf => frames.flatMap fun pf =>
    plainPatterns.flatMap fun cp => plainPatterns.filterMap fun pp =>
      let c : Scope := { incl := [cp], excl := [] }
      let p : Scope := { incl := [pp], excl := [] }
      if scopeSubset cf pf c p ==
         scopeSubset alienFrame alienFrame (mintScope cf c) (mintScope pf p)
      then none else some ()).length

#eval s!"Q5 control (plain alphabet)    pairs={frames.length^2 * plainPatterns.length^2} disagree={q5}"

-- ── Q6. THE POSITIVE CONTROL, and it is the row that makes Q0-Q5 mean anything ──────

/-- Every sweep above reports **zero**, and a differential that reports zero is
indistinguishable from a differential that is not comparing anything. `Q5` cannot close that
— it narrows the alphabet and also reports zero, so it demonstrates nothing here (unlike
A-31, where the full sweep found 108 and the narrowed one found 0).

So: mint against the WRONG frame. §5.5a names *canon-against-wrong-frame* as one of its two
separately-named defective architectures; this is that defect, injected. The sweep MUST report
a non-zero count, and if it ever reports zero, `Q0`–`Q5`'s zeros are worthless and this file
is measuring nothing. -/
def mintWrongFrame (_granter p : String) : String := joinAbs (canonSegs alienFrame p)

def mintScopeWrong (g : String) (s : Scope) : Scope :=
  { incl := s.incl.map (mintWrongFrame g), excl := s.excl.map (mintWrongFrame g) }

def q6 : Nat :=
  (frames.flatMap fun cf => frames.flatMap fun pf =>
    patterns.flatMap fun cp => patterns.filterMap fun pp =>
      let c : Scope := { incl := [cp], excl := [] }
      let p : Scope := { incl := [pp], excl := [] }
      if scopeSubset cf pf c p ==
         scopeSubset alienFrame alienFrame (mintScopeWrong cf c) (mintScopeWrong pf p)
      then none else some ()).length

def q6L1 : Nat :=
  (frames.flatMap fun g => patterns.flatMap fun ip => targets.filterMap fun tgt =>
    let s : Scope := { incl := [ip], excl := [] }
    if matchesScope g tgt s ScopeKind.path
       == matchesScope alienFrame tgt (mintScopeWrong g s) ScopeKind.path
    then none else some ()).length

#eval s!"Q6 POSITIVE CONTROL wrong-frame mint  L3/L4={q6} (MUST be > 0)  L1/L2={q6L1} (MUST be > 0)"

end EntityCoreFormalization.KS9c
