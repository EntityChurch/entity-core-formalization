/-
  entity-core-formalization — A-4, and what `K-7` actually closed.

  WHAT THIS ANSWERS. `entity-core-keystone` ask **A-4** (their tracker, from their
  `ROUTING-2026-09-10-b` §2) says: *"R11's witness does not construct — restore the bound it
  withdrew."* Our R11 retraction withdrew the bound *"K1's divergence requires an id-scope
  value carrying path syntax — a leading `/`"* on the strength of a witness: parent
  `operations = ["*/apply"]` admitting child `["compute/apply"]` under `scopeSubset`, with no
  leading `/` anywhere. Their refutation was that §5.4 `canonicalize` **rejects** `*/`-leading
  patterns before any matcher sees them, so the witness cannot be built.

  OUR 2026-09-10 ANSWER WAS THAT THE BOUND IS PER-ARTIFACT, AND THIS FILE IS WHY IT IS NOW
  WORTH RE-DERIVING RATHER THAN RESTATING. They argued from the SPEC's `canonicalize`. The
  artifact our ledger pins — `EntityCore.Capability` in their own tree — did not implement that
  rejection when they argued it, and implements it now. Two separate commits did it, neither of
  them the argument:

    * `0c4a537b` (2026-09-14) gave `canonSegs` its two reserved arms, including
      `path.startsWith "*/" → neverMatch`. Five days AFTER the A-4 packet.
    * `fee2e422` (2026-09-15) gave `scopeSubset` a `ScopeKind` parameter, so `operations` and
      `peers` reach `matchesIdPattern` and never touch the §5.4 transforms at all. That is
      their `K-7` closure, which is our own finding coming back.

  So the question A-4 asks has a measurable answer and it is not "you were right" or "we were
  right": the witness constructed on the artifact as it stood, it does not construct on the
  artifact as it stands, and it is closed TWICE OVER by two repairs that landed after the
  disagreement. This file measures that instead of asserting it.

  ── THE "BEFORE" IS TRANSCRIBED FROM THE COMMIT, NOT REMEMBERED ───────────────────────────

  D12 — cite canonical sources by `(symbol, path, commit)`. `canonSegsPre` and
  `scopeSubsetPre` below are byte-faithful transcriptions of

      canonSegs, scopeSubset
      protocol-generator/lean/src/EntityCore/Capability.lean:118,184
      entity-core-keystone @ 97bf1a05   (2026-09-09 — keystone's HEAD on the day R11 was
                                         measured and the day before A-4 was written)

  read out of `git show`, not reconstructed from this repo's notes about them. A reconstructed
  "before" would make the whole differential a claim about our memory of their tree.

  ── WHY THE CONTROLS ARE THE POINT ────────────────────────────────────────────────────────

  Every headline row here is a **false** — the witness does not construct, three ways. A sweep
  reporting `false` everywhere is indistinguishable from one that is not comparing anything;
  that is `neg-eval`'s whole lesson, already paid for in `StarFree.lean`. So:

    * `r11Pre` is a POSITIVE control and MUST be `true`. If the pre-fix route ever stops
      exhibiting the over-grant, this file has stopped measuring the thing it names.
    * `plain` is a MUST-AGREE control — the five-element star-free, slash-free alphabet on
      which `pre` and `.id` must give identical verdicts on all 25 pairs. It is the alphabet
      keystone's own comment says every hand-tried example lived in, which is why F50 survived
      three revisions.
    * the sweep MUST find disagreements. A zero is a failure of the alphabet, not a result.

  ── WHAT THIS DOES NOT ASSERT ─────────────────────────────────────────────────────────────

  * Nothing about `handlers`/`resources`. Those stay `.path` and keep the interior-`*`
    divergence, which is **K2** and is measured in `StarFree.lean`/`Chain.lean`. K-7 does not
    touch them and neither does this file.
  * Nothing about the A-upper-end severity grade. Our position on it never rested on the
    witness constructing — see `TRACKER-entity-core-keystone.md` A-4 — so a measurement of the
    witness cannot move it in either direction. Stated here because the two are easy to
    conflate and A-4 conflates them.
  * Nothing about whether `.id` is the RIGHT semantics. It is §3.6's, and that this artifact
    now implements §3.6 is a fidelity claim a human made by reading two texts (`K1`), not
    something this sweep checks.
  * ⛔ **Nothing about the EXCLUDE side's semantics.** `exclSweep` exists and its tally is the
    exact TRANSPOSE of `inclSweep` — `scopeSubset`'s exclude arm evaluates the same matcher
    with the operands swapped (`parent.excl` covered by `child.excl`), so sweeping all ordered
    pairs of a single-pattern alphabet cannot produce a different number. It is a consistency
    check that the exclude arm reaches the same matcher, and **it is not independent evidence
    and must not be quoted as a second measurement.** The pin's own §3.6 asserts a
    *semantically* different failure on that side — *"over-grants on `include` path-form
    patterns and **inverts the intent** on `exclude`"* — and that is a claim about what an
    unmatched exclude MEANS (it carves out nothing, so the grant is wider than written), which
    lives a level above this function and is measured nowhere here.

  ── WHERE THE CLASSES COME FROM ───────────────────────────────────────────────────────────

  `starpos` and `slash` are not invented for this sweep. `spec-data/v0.8.2`
  `ENTITY-CORE-PROTOCOL.md:1035` (§3.6, *id-scope pattern grammar (normative — 0.8.1, F40)*)
  names both: exactly two wildcard forms are grammatical (bare `*`, trailing `/*`), and

      "A pattern carrying that path syntax (`/*/get`, `/{peer}/op`, `/*/*`) is therefore
       matched only as a literal string and does not match a bare identifier value."

  So a leading-`/` `operations` pattern is a legal pattern that the grammar says is a literal
  — which is why `/abs/op` is in the alphabet rather than being an artifact of it. `other`
  exists so the partition is exhaustive: a disagreement the two named classes do not explain
  would be a result, and it must be read as one rather than absorbed.
-/
import EntityCoreProofs.CapabilityProofs

namespace EntityCoreFormalization.A4

open EntityCore.Capability

-- ── 1. The artifact as it stood, transcribed from 97bf1a05 ───────────────────────────────

/-- `canonSegs` @ `97bf1a05`, `Capability.lean:118`. One line, no reserved arms: every
pattern canonicalizes, nothing is ever refused. This is the function our 2026-09-10 answer
described as *"prepends the local frame and rejects nothing"* — accurate then, false now. -/
def canonSegsPre (frame : String) (path : String) : List String :=
  if path.startsWith "/" then splitSegs path else splitSegs ("/" ++ frame ++ "/" ++ path)

/-- `scopeSubset` @ `97bf1a05`, `Capability.lean:184`. No `ScopeKind` (pre-K-7), and raw
`matchesSeg` rather than the `matchesSegNM` wrapper (pre-K-6). All four dimensions came
through here. -/
def scopeSubsetPre (childFrame parentFrame : String) (child parent : Scope) : Bool :=
  child.incl.all (fun cp =>
    let cc := canonSegsPre childFrame cp
    parent.incl.any (fun pp => matchesSeg cc (canonSegsPre parentFrame pp)))
  && parent.excl.all (fun pe =>
       let cpe := canonSegsPre parentFrame pe
       child.excl.any (fun ce => matchesSeg cpe (canonSegsPre childFrame ce)))

-- ── 2. R11's witness, on the real call path, in three eras ───────────────────────────────

def frame : String := "pA"

def scopeI (p : String) : Scope := { incl := [p], excl := [] }

/-- R11's witness exactly as published: parent `operations = ["*/apply"]`, child
`["compute/apply"]`, no leading `/`. -/
def r11Child : Scope := scopeI "compute/apply"
def r11Parent : Scope := scopeI "*/apply"

/-- POSITIVE CONTROL — MUST be `true`. The over-grant on the 2026-09-09 artifact. -/
def r11Pre : Bool := scopeSubsetPre frame frame r11Child r11Parent

/-- The same pair on today's `operations` dimension: `.id`, so `matchesIdPattern` compares
literally and `*/apply` is an ordinary (non-matching) identifier. Closed by `fee2e422`. -/
def r11Id : Bool := scopeSubset .id frame frame r11Child r11Parent

/-- The same pair routed as PATH scope on today's definitions: `canonSegs` maps `*/apply` to
`neverMatch` and `matchesSegNM` refuses it in either operand. Closed by `0c4a537b`, and this
row is what shows the two repairs are INDEPENDENT — either one alone kills the witness. -/
def r11Path : Bool := scopeSubset .path frame frame r11Child r11Parent

/-- The same witness one level up, where a capability actually carries it: two grants
differing only in `operations`. `grantSubset` names `.id` for that dimension, so this is the
call path a real chain takes rather than a direct call chosen to prove a point. -/
def grantOf (ops : Scope) : Grant :=
  { handlers := scopeI "*", resources := scopeI "*", operations := ops, peers := none }

def r11Grant : Bool :=
  grantSubset frame frame frame (grantOf r11Child) (grantOf r11Parent)

-- ── 3. The sweep — what K-7 changed on an id-scope alphabet ──────────────────────────────

/-- An operation-name alphabet in §3.6's shape: ordinary namespaced and bare identifiers, the
two wildcard forms the id grammar DOES define (`*`, trailing `/*`), the two it does not
(`*/`-leading and interior), and one carrying path syntax. Twelve patterns; `scopeSubset`
compares pattern to pattern, so both sides draw from the same list. -/
def opAlpha : List String :=
  [ "tree/get", "tree/put", "compute/apply", "get", "apply"
  , "*", "tree/*", "compute/*"
  , "*/apply", "*/get", "tree/*/deep"
  , "/abs/op" ]

/-- §3.6's id grammar admits exactly two wildcard forms. Everything else containing a `*` is
a literal identifier that happens to have a star in it. -/
def idGrammarWildcard (p : String) : Bool :=
  p == "*" || (p.length ≥ 2 && p.endsWith "/*")

def hasStar (p : String) : Bool := p.any (· == '*')

/-- The three disagreement classes, disjoint and exhaustive over `opAlpha`. -/
def classOf (cp pp : String) : String :=
  if (hasStar pp && !idGrammarWildcard pp) || (hasStar cp && !idGrammarWildcard cp)
    then "starpos"
  else if cp.startsWith "/" || pp.startsWith "/" then "slash"
  else "other"

structure Tally where
  pairs : Nat := 0
  disagree : Nat := 0
  /-- `pre` admitted and `.id` refuses — K-7 NARROWED the delegation check here. -/
  narrowed : Nat := 0
  /-- `.id` admits and `pre` refused — K-7 WIDENED the delegation check here. **Not assumed to
  be zero, and it is not zero.** A repair sold as "stop over-granting" moving one row in the
  permissive direction is the thing a summary loses; §3.6 says a bare `*` matches ANY value,
  so the widening is toward the grammar and the pre-fix refusal was the defect — but "K-7
  narrows" is false of 1 of 3 disagreeing rows and nobody should read it off the headline. -/
  widened : Nat := 0
  starpos : Nat := 0
  slash : Nat := 0
  other : Nat := 0
  deriving Repr

/-- `mk` builds the two single-pattern scopes for a pair; `scopeI` puts the pattern in the
include list, `scopeE` in the exclude list.

⛔ The `scopeE` run is the TRANSPOSE of the `scopeI` run, not a second experiment — see the
header. `scopeSubset`'s exclude arm is `parent.excl.all (pe => child.excl.any (ce => m pe ce))`,
which on singletons is `m pp cp`, so over all ordered pairs the tally is identical by
construction. It is kept because "the exclude arm reaches the same matcher" is worth checking
and is cheap, and it is LABELLED because an identical pair of numbers reads as corroboration. -/
def sweep (mk : String → Scope) (alpha : List String) : Tally :=
  alpha.foldl (fun acc cp =>
    alpha.foldl (fun acc pp =>
      let c := mk cp
      let p := mk pp
      let pre := scopeSubsetPre frame frame c p
      let now := scopeSubset .id frame frame c p
      let acc := { acc with pairs := acc.pairs + 1 }
      if pre == now then acc
      else
        let k := classOf cp pp
        { acc with
            disagree := acc.disagree + 1,
            narrowed := acc.narrowed + (if pre then 1 else 0),
            widened  := acc.widened  + (if now then 1 else 0),
            starpos  := acc.starpos  + (if k == "starpos" then 1 else 0),
            slash    := acc.slash    + (if k == "slash" then 1 else 0),
            other    := acc.other    + (if k == "other" then 1 else 0) }) acc) {}

def scopeE (p : String) : Scope := { incl := [], excl := [p] }

/-- MUST-AGREE CONTROL. The star-free, slash-free alphabet — five ordinary operation names,
25 pairs. `pre` and `.id` must agree on every one. This is the alphabet keystone's own
`scopeSubset` comment says every hand-tried example lived in, and it is why `F50` survived
three spec revisions and a cohort. A non-zero here means the two functions differ on
ORDINARY input, which would be a much larger finding than A-4. -/
def plainAlpha : List String := opAlpha.filter (fun p => !hasStar p && !p.startsWith "/")

def inclSweep : Tally := sweep scopeI opAlpha
def exclSweep : Tally := sweep scopeE opAlpha
def plainSweep : Tally := sweep scopeI plainAlpha

/-- Every disagreeing include pair, printed. A count is a summary; these are the rows, so a
reader checks the transcription rather than trusting the arithmetic. -/
def inclWitnesses : String :=
  let rows := opAlpha.flatMap (fun cp => opAlpha.filterMap (fun pp =>
    let c := scopeI cp
    let p := scopeI pp
    let pre := scopeSubsetPre frame frame c p
    let now := scopeSubset .id frame frame c p
    if pre == now then none
    else some s!"{cp}<={pp}(pre={pre},id={now},{classOf cp pp})"))
  if rows.isEmpty then "none" else String.intercalate " " rows

def report : String :=
  s!"A4 r11Pre={r11Pre} r11Id={r11Id} r11Path={r11Path} r11Grant={r11Grant}"

def sweepLine (name : String) (t : Tally) : String :=
  s!"A4 {name} pairs={t.pairs} disagree={t.disagree} narrowed={t.narrowed} " ++
  s!"widened={t.widened} starpos={t.starpos} slash={t.slash} other={t.other}"

#eval report
#eval sweepLine "incl " inclSweep
#eval sweepLine "excl " exclSweep
#eval sweepLine "plain" plainSweep
#eval "A4 incl witnesses: " ++ inclWitnesses

end EntityCoreFormalization.A4
