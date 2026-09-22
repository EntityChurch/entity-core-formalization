/-
  entity-core-formalization — A-31 / K2: the star-free result, and the differential
  behind it, in a form that can be re-run.

  WHAT THIS IS FOR. `entity-system-architecture` held the R11 sentinel fold behind K2 on
  the premise that *"a never-match sentinel is safe only if no matcher arm can match it,
  and K2 is a report of a matcher with an interior-wildcard arm §5.4 doesn't define."*
  On 2026-09-10 that was answered with an exhaustive differential over 1–3 segments
  (3276 pairs, 108 disagreements, all one-directional; star-free patterns 1521/1521
  agree) — and the sweep was run in a scratch directory and never committed, so the
  measurement arch has now folded against was not reproducible from this tree. Both
  halves live here now: the sweep, and the THEOREM that retires its length bound.

  WHAT IS PROVED, AND ON WHOSE DEFINITION. `matchesSeg_starFree` is about
  `EntityCore.Capability.matchesSeg` — keystone's OWN function, imported from the peer's
  own tree, elaborated by the Lean the peer pins. It is not a transcription of it. That
  matters: K2 is a claim about that function, so a theorem about a copy of it would be a
  theorem about us. The gate builds this file inside a COPY of the peer's tree
  (`tools/lean-lemma.py`); the peer's own tree is read-only input and is never written to.

  WHAT IS *NOT* PROVED, AND SAYING SO IS THE POINT (D11, and `docs/LEAN-SEAM.md` §5).
  `mp54` below IS a transcription — ours, of §5.4 `matches_pattern` in
  `spec-data/v0.8.2/ENTITY-CORE-PROTOCOL.md` — so every claim that mentions it carries
  the 5th wall in full. Its controls are the spec's own worked examples and nothing
  stronger. A theorem here and a sentence there are not the same kind of object, and the
  packet must not blur them.

  THE THREE RESULTS, in the order they answer arch:

    1. `matchesSeg_starFree`     — on a star-free pattern, keystone's matcher IS list
                                   equality. All lengths, no bound. This is the half that
                                   was bounded to 1–3 segments yesterday.
    2. `starFree_matches_only_itself`
                                 — the sentinel corollary: a star-free pattern matches
                                   exactly itself, so a star-free pattern that is not a
                                   constructible path matches NOTHING.
    3. `mp54_literal`            — the §5.4 side: a pattern that is not `*`, does not
                                   start `/*/` and does not end `/*` reduces to string
                                   equality. Also unbounded.

  THE JOIN BETWEEN 1 AND 3 IS NOT A THEOREM AND MUST NOT BE QUOTED AS ONE. What is
  missing is the bridge *a star-free pattern satisfies §5.4's three guards*, which is a
  fact about `String.startsWith`/`endsWith` on a string with no `'*'` in it. Core Lean
  has no substring reasoning to hand and this peer is deliberately mathlib-free
  (keystone's A-3, declined 2026-09-06), so proving it would cost a dependency the
  shipping peer does not want. Instead: §5.4 inspects `*` in exactly three places — the
  whole pattern, a `/*/` prefix, a `/*` suffix — so a pattern with no `*` fails all three
  by inspection, and `starFreeGuards` below CHECKS that by evaluation over every one of
  the sweep's 84 patterns. Decidable per-sentinel; not general. Booked as such.
-/
import EntityCoreProofs.CapabilityProofs

namespace EntityCoreFormalization.A31

open EntityCore.Capability
open EntityCore.Capability.Proofs

-- ── 1. The theorem: star-free ⇒ keystone's matcher is equality ───────────────────────

/-- A pattern is *star-free* when no segment is the wildcard `"*"`.

Segment-level, because that is the level `matchesSeg` tests at: its three wildcard-
sensitive arms (`["*"]`, `"*" :: pt`) branch on a segment being exactly `"*"`, never on a
`'*'` character inside one. So `"a*b"` is star-free here and that is correct — it is a
literal to this matcher. -/
def starFree (pt : List String) : Bool := pt.all (fun s => s != "*")

/-- **The A-31 headline, unbounded.** On a star-free pattern, `matchesSeg` is exactly list
equality — for paths and patterns of ANY length, not the 1–3 segments the differential
covered.

Every arm of `matchesSeg` collapses: arm 1 (`["*"]`) and arm 5 (`"*" :: pt`) cannot fire,
because no pattern segment is `"*"`; arms 2–4 are the equality/length cases; arm 6 is
literal equality, and it is the only recursive one left. So the interior-wildcard arm that
K2 is ABOUT is unreachable here, which is why the divergence with §5.4 vanishes on this
class and only on this class. -/
theorem matchesSeg_starFree :
    ∀ (path pt : List String), starFree pt = true → matchesSeg path pt = (path == pt) := by
  intro path
  induction path with
  | nil =>
    intro pt _
    cases pt with
    | nil => rfl
    | cons b bs => rw [matchesSeg_nil_cons]; simp
  | cons a as ih =>
    intro pt h
    cases pt with
    -- `matchesSeg (a :: as) [] = false` (arm 3) and `(a :: as == []) = false`, definitionally.
    | nil => rfl
    | cons b bs =>
      have h' : (b != "*") = true ∧ starFree bs = true := by
        simpa [starFree, List.all_cons, Bool.and_eq_true] using h
      have hb : b ≠ "*" := by simpa using h'.1
      -- `ms_lit` is keystone's own arm characterization: with a non-`*` pattern head,
      -- neither wildcard arm fires and the match is `head equality && recurse`.
      rw [ms_lit hb, ih bs h'.2]
      simp

/-- **The sentinel corollary — what arch actually asked.** A star-free pattern matches
exactly itself and nothing else. So if the sentinel is star-free and is not a constructible
path, no path matches it: under keystone's matcher, with its extra interior-wildcard arm,
just as under §5.4. The premise *"a never-match sentinel is safe only if no matcher arm can
match it"* is true and is not binding here, because on this class no wildcard arm is
reachable at all. -/
theorem starFree_matches_only_itself (path pt : List String)
    (hsf : starFree pt = true) (hm : matchesSeg path pt = true) : path = pt := by
  rw [matchesSeg_starFree path pt hsf] at hm
  exact eq_of_beq hm

/-- The same, as an iff, for a reader who wants the shape rather than the use. -/
theorem matchesSeg_starFree_iff (path pt : List String) (hsf : starFree pt = true) :
    matchesSeg path pt = true ↔ path = pt := by
  rw [matchesSeg_starFree path pt hsf]
  exact ⟨eq_of_beq, fun h => by simp [h]⟩

#print axioms matchesSeg_starFree
#print axioms starFree_matches_only_itself
#print axioms matchesSeg_starFree_iff

-- ── 2. `mp54` — OUR transcription of §5.4 `matches_pattern` ──────────────────────────

/-
  Transcribed line by line from `spec-data/v0.8.2/ENTITY-CORE-PROTOCOL.md` §5.4
  (`matches_pattern`, at the pin). The spec's four arms, in the spec's order:

      if pattern == "*": return true
      if pattern starts with "/*/":  remainder = pattern[3:]
                                     second_slash = index_of(path[1:], "/")
                                     if second_slash < 0: return false
                                     path_rest = path[second_slash + 2:]
                                     return matches_pattern(path_rest, remainder)
      if pattern ends with "/*":     prefix = pattern without trailing "*"
                                     return path starts with prefix
      return path == pattern

  Two encoding notes, each stated because a transcription is where fidelity is lost:

  * FUEL, and why the exhaustion case is MEASURED rather than assumed. §5.4's recursion
    is on a strictly shorter pattern, but Lean wants a termination argument and the
    core-Lean string lemmas for it are not to hand. Fuel instead — and a fuel bound is a
    CLAIM, exactly like an Apalache ladder depth (AGENTS.md). So the result is
    `Option Bool` and `none` means *the fuel ran out and this row asserts nothing*; the
    sweep reports the exhaustion count and it must be 0. A silently-`false` exhausted row
    would read as "the spec says no".
  * `String.ofList`/`String.toList` rather than `String.drop`, which returns a
    `String.Slice` in the Lean this peer pins (4.29.1), and rather than the deprecated
    `String.mk`/`String.data` — a deprecation warning is a build failure in this gate.
    The third arm keeps `String.startsWith`, because §5.4's subtree arm is a LITERAL
    STRING prefix test, not a segment test. That distinction is load-bearing and
    flattening it into segments would be the transcription silently answering the
    question the differential exists to ask.
-/

/-- §5.4 `matches_pattern`, with fuel. `none` = fuel exhausted (asserts nothing). -/
def mp54? : Nat → String → String → Option Bool
  | 0, _, _ => none
  | fuel + 1, path, pattern =>
    if pattern == "*" then some true
    else if pattern.startsWith "/*/" then
      let remainder := String.ofList (pattern.toList.drop 3)
      match (path.toList.drop 1).findIdx? (· == '/') with
      | none => some false
      | some i => mp54? fuel (String.ofList (path.toList.drop (i + 2))) remainder
    else if pattern.endsWith "/*" then
      some (path.startsWith (String.ofList pattern.toList.dropLast))
    else
      some (path == pattern)

/-- Enough fuel for the sweep's 1–3 segment patterns; the sweep reports 0 exhaustions. -/
def fuelN : Nat := 8

/-- **The §5.4 side, unbounded.** A pattern §5.4 has no wildcard arm for — not `*`, no
`/*/` prefix, no `/*` suffix — reduces to exact string equality. Definitional: with all
three guards false the algorithm falls through to its last line. -/
theorem mp54_literal (fuel : Nat) (path pattern : String)
    (h1 : (pattern == "*") = false)
    (h2 : pattern.startsWith "/*/" = false)
    (h3 : pattern.endsWith "/*" = false) :
    mp54? (fuel + 1) path pattern = some (path == pattern) := by
  simp [mp54?, h1, h2, h3]

#print axioms mp54_literal

/-- The bridge `mp54_literal` needs, as a DECIDABLE CHECK rather than a theorem: does this
pattern string trip any of §5.4's three wildcard guards? Evaluated over the whole sweep
below. See the header for why this is not proved from "the pattern contains no `'*'`". -/
def starFreeGuards (pattern : String) : Bool :=
  !(pattern == "*") && !pattern.startsWith "/*/" && !pattern.endsWith "/*"

-- ── 3. The differential — the A-31 sweep, reproducible ───────────────────────────────

/-- Path alphabet: two ordinary segments and a peer-shaped one. -/
def pathAlpha : List String := ["a", "b", "p"]

/-- Pattern alphabet: the same, plus the wildcard segment. -/
def patAlpha : List String := ["a", "b", "p", "*"]

/-- Every segment list of length 1, 2 or 3 over `alpha`. -/
def segsUpTo (alpha : List String) : List (List String) :=
  let l1 := alpha.map (fun a => [a])
  let l2 := alpha.flatMap (fun a => alpha.map (fun b => [a, b]))
  let l3 := alpha.flatMap (fun a => alpha.flatMap (fun b => alpha.map (fun c => [a, b, c])))
  l1 ++ l2 ++ l3

def pathsAll : List (List String) := segsUpTo pathAlpha
def patsAll : List (List String) := segsUpTo patAlpha

/-- Segments → the absolute path string the same segments canonicalize FROM:
`canonSegs f "/a/b" = ["a","b"]`, so this is the inverse on the absolute forms and the two
matchers are being fed the same input in their own representations. -/
def joinAbs (segs : List String) : String := "/" ++ String.intercalate "/" segs

/-- A star only in the first segment or only as the whole last segment — the class §5.4
DOES define an arm for (`/*/rest`, trailing `/*`). Its complement is the interior-`*`
class, which is what K2 is about. -/
def edgeOnlyStar (pt : List String) : Bool :=
  pt.zipIdx.all (fun (s, i) => s != "*" || i == 0 || i + 1 == pt.length)

structure Tally where
  pairs : Nat := 0
  disagree : Nat := 0
  leanOverGrants : Nat := 0
  leanUnderGrants : Nat := 0
  exhausted : Nat := 0
  deriving Repr

def tallyOver (pats : List (List String)) : Tally :=
  pathsAll.foldl (fun acc path =>
    pats.foldl (fun acc pat =>
      let lean := matchesSeg path pat
      match mp54? fuelN (joinAbs path) (joinAbs pat) with
      | none => { acc with pairs := acc.pairs + 1, exhausted := acc.exhausted + 1 }
      | some spec =>
        let acc := { acc with pairs := acc.pairs + 1 }
        if lean == spec then acc
        else if lean then
          { acc with disagree := acc.disagree + 1,
                     leanOverGrants := acc.leanOverGrants + 1 }
        else
          { acc with disagree := acc.disagree + 1,
                     leanUnderGrants := acc.leanUnderGrants + 1 }) acc) {}

def full : Tally := tallyOver patsAll
def starFreeOnly : Tally := tallyOver (patsAll.filter (fun p => starFree p))
def edgeOnly : Tally := tallyOver (patsAll.filter (fun p => edgeOnlyStar p))
def interiorOnly : Tally := tallyOver (patsAll.filter (fun p => !edgeOnlyStar p))

/-- Every star-free pattern in the sweep also clears §5.4's three guards — the bridge
`mp54_literal` needs, checked rather than proved. Must be 0. -/
def starFreeGuardMisses : Nat :=
  (patsAll.filter (fun p => starFree p)).countP (fun p => !starFreeGuards (joinAbs p))

/-- CONTROLS FIRST — a differential with no controls asserts nothing (D13). The first two
rows are §5.4's own worked examples, quoted from the section; then equality, inequality,
the trailing-`/*` subtree form, and the bare `*`. Reported as a miss COUNT that must be 0,
with each row's verdict printed beside it so a reader can check the transcription rather
than trust the count. -/
def controls : List (String × String × Bool) :=
  [ ("/p/a", "/*/*", true)          -- §5.4: the peer wildcard, then the subtree arm
  , ("/p/x/y", "/*/x/*", true)      -- §5.4: strip the peer, then prefix-match
  , ("/a/b", "/a/b", true)          -- exact equality
  , ("/a/b", "/a/c", false)         -- inequality
  , ("/a/b/c", "/a/*", true)        -- trailing `/*` is a literal string prefix
  , ("/a/b", "*", true)             -- bare `*`
  , ("/a", "/a/*", false)           -- prefix `/a/` does not cover `/a` itself
  ]

def controlMisses : Nat :=
  controls.countP (fun (path, pat, want) => mp54? fuelN path pat != some want)

/-- The two K2 witnesses, in-tree so the finding reproduces: keystone's matcher admits an
interior wildcard, §5.4 (as transcribed) does not. Both must read `lean=true spec=false`. -/
def k2Witnesses : List (List String × List String) :=
  [ (["peerL", "a", "b"], ["peerL", "*", "b"])
  , (["peerL", "x", "y", "z"], ["peerL", "x", "*", "z"])
  ]

def k2Line : String :=
  String.intercalate " " (k2Witnesses.map (fun (p, q) =>
    s!"[{joinAbs q}]lean={matchesSeg p q},spec={(mp54? fuelN (joinAbs p) (joinAbs q)).getD false}"))

/-- One line, graded by `tools/lean-lemma.py` against `lean/lemma-gate.expect`. Every
number the A-31 packet publishes is here and nowhere else in this tree. -/
def report : String :=
  s!"A31 pairs={full.pairs} disagree={full.disagree} over={full.leanOverGrants} " ++
  s!"under={full.leanUnderGrants} exhausted={full.exhausted} " ++
  s!"starfree={starFreeOnly.pairs}/{starFreeOnly.disagree} " ++
  s!"edgeonly={edgeOnly.pairs}/{edgeOnly.disagree} " ++
  s!"interior={interiorOnly.pairs}/{interiorOnly.disagree} " ++
  s!"guardmisses={starFreeGuardMisses} controlmisses={controlMisses}"

#eval report
#eval k2Line

end EntityCoreFormalization.A31
