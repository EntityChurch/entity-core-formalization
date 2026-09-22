/-
  entity-core-formalization — K2, the CHAIN question.

  WHAT THIS ANSWERS. K2 is a machine-checked divergence between two functions: keystone's
  `matchesSeg` admits an interior `*` segment that §5.4's `matches_pattern` has no arm for,
  and `StarFree.lean` bounds it (all 108 disagreements over 3276 pairs are interior-`*`).
  What nobody had measured is whether that divergence **widens authority end to end** —
  §5.6's own comment says canonicalizing a dimension here *"widens authority DOWN A
  DELEGATION CHAIN, which is where nobody re-checks"*, and `docs/LEAN-SEAM.md` L5 is the row
  that discharges Tamarin's `no_escalation` condition through exactly this function. A
  differential between two functions is not a claim about authority; this file is the bridge.

  THE QUESTION, STATED SO IT CAN COME OUT EITHER WAY. §5.6 checks *pattern cover*: every
  child include pattern must be matched by some parent include pattern, with the child
  pattern read as a PATH. What anyone cares about is *extensional containment*: is the set of
  targets the child authorizes a subset of the set the parent authorizes? Those are different
  propositions and the entire security argument is that the first implies the second. Three
  soundness questions, not one:

      subKS  → ext ⊆ ext   in KEYSTONE semantics   — does their check imply containment
                                                     under their own matcher?
      sub54  → ext ⊆ ext   in SPEC semantics       — does §5.6's check imply containment
                                                     under §5.4? ABOUT THE SPEC ALONE, and
                                                     nobody had asked it.
      subKS  → ext ⊆ ext   in SPEC semantics       — K2's cost: a link keystone admits,
                                                     priced in the spec's meaning.

  and the chain question on top: does composing two admitted links reach a (leaf, root) pair
  that one link could not?

  WRITE THE WITNESS BEFORE THE PROHIBITION. "No chain is constructible" is a NEGATIVE
  REACHABILITY claim, the highest-vacuity shape this repo has (§IDENT:9.4's
  `RecoveryFailClosed` was green because the accepting path was unreachable). So
  `ksSoundSpec` is a POSITIVE claim that must find something, `admit*` and `reach2*` are
  vacuity guards on every zero, and all of them are gate rows.

  ── THE DOMAIN IS THE CLAIM, AND THE FIRST DRAFT OF THIS FILE GOT IT WRONG ────────────────

  D18. The first draft drew targets from {a, b, p} — no `*` — and measured that EVERY
  keystone-admitted over-grant had a parent whose §5.4 extension was empty, i.e. that the
  divergence only ever involved parent grants meaning nothing to a conformant peer. That
  reads as a severity downgrade and it was **an artifact of the target alphabet**:
  `ENTITY-CORE-PROTOCOL` §1.4 says *"All other UTF-8 characters are valid in path
  segments"*, so a path segment may be **literally `*`**. Under §5.4 an interior-`*` pattern
  falls through to exact string equality — and a path that literally equals it is a legal
  path. Excluding `*` from targets excluded exactly the paths that make those patterns mean
  something. The negative was about our alphabet, not about the protocol.

  So this runs on TWO domains and reports both, which is also the sensitivity check:

    * `general`  — patterns and targets both over {a, b, p, *}, 1–3 segments. Targets
                   include literal-`*` segments, per §1.4.
    * `peerlike` — the faithful shape: a TARGET is a tree path, so `validate_absolute_path`
                   requires its first segment to be a real peer id (never `*`, never a
                   pattern); a PATTERN may lead with a peer id or the `/*/` peer wildcard.
                   Targets: `p` then {a, b, *}. Patterns: {p, *} then {a, b, *}.

  What both domains still exclude, stated rather than discovered later:
    * EXTENSION IS BOUNDED. "⊆" means over that domain's target list. A containment that
      holds on all of them and fails at 4 segments is not visible.
    * ABSOLUTE PATTERNS ONLY, so `canonSegs`' frame is irrelevant (keystone's own
      `canonSegs_absolute_frame_independent`) and the §5.5a per-side granter frames cannot
      matter. Relative patterns — where the frames DO differ per link — are excluded, and
      that is the exclusion most likely to hide something: L7/L1 are the rows about it.
    * INCLUDES ONLY. §5.6's exclude half runs containment the other way (the child must
      inherit every parent exclude), so a more permissive matcher there is more RESTRICTIVE.
      Excluded deliberately, and the direction is why.
    * SINGLE-PATTERN SCOPES, for the matrices. This is NOT load-bearing for the chain
      conclusion: keystone's own `all_any_compose` lifts a transitive pairwise relation
      through the `all`/`any` shape `scopeSubset` is written in, and `scopeSubset_trans`
      proves the multi-pattern case including excludes. The pairwise measurement is what
      that lemma needs as input.
-/
import EntityCoreProofs.StarFree

namespace EntityCoreFormalization.K2Chain

open EntityCore.Capability
open EntityCoreFormalization.A31

def mp (path pattern : String) : Bool := (mp54? fuelN path pattern).getD false

/-- Segment lists of length 1–3 whose FIRST segment comes from `heads` and whose remaining
segments come from `tail`. One constructor for both domains so the two cannot drift. -/
def listsOver (heads tail : List String) : List (List String) :=
  let l1 := heads.map (fun h => [h])
  let l2 := heads.flatMap (fun h => tail.map (fun a => [h, a]))
  let l3 := heads.flatMap (fun h => tail.flatMap (fun a => tail.map (fun b => [h, a, b])))
  l1 ++ l2 ++ l3

structure Dom where
  name : String
  pats : Array (List String)
  tgts : Array (List String)

def general : Dom :=
  { name := "general"
    pats := (listsOver ["a", "b", "p", "*"] ["a", "b", "p", "*"]).toArray
    -- §1.4: a path segment may be literally `*`, so targets use the same alphabet.
    tgts := (listsOver ["a", "b", "p", "*"] ["a", "b", "p", "*"]).toArray }

def peerlike : Dom :=
  { name := "peerlike"
    -- A pattern may lead with a peer id or the `/*/` peer wildcard (§5.4).
    pats := (listsOver ["p", "*"] ["a", "b", "*"]).toArray
    -- A TARGET is a tree path: `validate_absolute_path` requires a real peer id first.
    tgts := (listsOver ["p"] ["a", "b", "*"]).toArray }

/-- `child ⊑ parent` as §5.6 checks it: the CHILD PATTERN, read as a path, matched against
the parent pattern — keystone's `scopeSubset` include half with equal frames, verbatim. -/
def subKS (d : Dom) : Array (Array Bool) :=
  d.pats.map (fun c => d.pats.map (fun p => matchesSeg c p))

/-- The same check with §5.4's matcher: `scope_subset`'s `matches_pattern(cc, cpp)` line
from `spec-data/v0.8.2` §5.6. Same shape, different matcher. -/
def sub54 (d : Dom) : Array (Array Bool) :=
  d.pats.map (fun c => d.pats.map (fun p => mp (joinAbs c) (joinAbs p)))

/-- Which targets does this pattern authorize? Keystone semantics, then §5.4. -/
def extKS (d : Dom) : Array (Array Bool) :=
  d.pats.map (fun p => d.tgts.map (fun t => matchesSeg t p))

def ext54 (d : Dom) : Array (Array Bool) :=
  d.pats.map (fun p => d.tgts.map (fun t => mp (joinAbs t) (joinAbs p)))

structure M where
  d : Dom
  sKS : Array (Array Bool)
  s54 : Array (Array Bool)
  eKS : Array (Array Bool)
  e54 : Array (Array Bool)

def build (d : Dom) : M := ⟨d, subKS d, sub54 d, extKS d, ext54 d⟩

def nPat (m : M) : Nat := m.d.pats.size
def nTgt (m : M) : Nat := m.d.tgts.size

def extSub (m : M) (ext : Array (Array Bool)) (c p : Nat) : Bool :=
  (List.range (nTgt m)).all (fun t => !(ext[c]!)[t]! || (ext[p]!)[t]!)

def pairs (m : M) : List (Nat × Nat) :=
  (List.range (nPat m)).flatMap (fun c => (List.range (nPat m)).map (fun p => (c, p)))

def nonEmpty (m : M) (ext : Array (Array Bool)) (p : Nat) : Bool :=
  (List.range (nTgt m)).any (fun t => (ext[p]!)[t]!)

/-- Reachable in two admitted links. -/
def reach2 (m : M) (rel : Array (Array Bool)) (l r : Nat) : Bool :=
  (List.range (nPat m)).any (fun x => (rel[l]!)[x]! && (rel[x]!)[r]!)

def report (m : M) : String :=
  let ps := pairs m
  -- CONTROL. Keystone's check must imply containment under keystone's own matcher: that is
  -- `matchesSeg_trans` lifted to extensions, so it must be 0, and a non-zero would mean this
  -- file disagrees with a theorem `make leanproof` grades as proved.
  let ksSoundKS := ps.countP (fun (c, p) => (m.sKS[c]!)[p]! && !extSub m m.eKS c p)
  -- THE SPEC ALONE. Does §5.6's cover check imply containment under §5.4?
  let specSoundSpec := ps.countP (fun (c, p) => (m.s54[c]!)[p]! && !extSub m m.e54 c p)
  -- K2's cost at ONE link, and the non-vacuity witness for every zero here.
  let esc := ps.filter (fun (c, p) => (m.sKS[c]!)[p]! && !extSub m m.e54 c p)
  -- Of those, the ones whose parent authorizes something REAL under §5.4. The first draft
  -- measured this as 0 and it was the target alphabet, not the protocol — see the header.
  let escReal := esc.countP (fun (_, p) => nonEmpty m m.e54 p)
  -- Exposure bound: `StarFree` proves the matchers agree on a star-free parent and the A-31
  -- sweep measures agreement on edge-only-`*` parents, so an over-grant should REQUIRE an
  -- interior-`*` parent. Measured, not inferred.
  let escPI := esc.countP (fun (_, p) => !edgeOnlyStar m.d.pats[p]!)
  let escCI := esc.countP (fun (c, _) => !edgeOnlyStar m.d.pats[c]!)
  -- THE CHAIN QUESTION: a (leaf, root) pair two admitted links reach that one link would
  -- not admit. Every such pair is authority that COMPOSITION created.
  let chainNewKS := ps.countP (fun (l, r) => reach2 m m.sKS l r && !(m.sKS[l]!)[r]!)
  let chainNew54 := ps.countP (fun (l, r) => reach2 m m.s54 l r && !(m.s54[l]!)[r]!)
  let chainEsc := ps.countP (fun (l, r) =>
    reach2 m m.sKS l r && !(m.sKS[l]!)[r]! && !extSub m m.e54 l r)
  -- VACUITY GUARDS. `specSoundSpec=0` would read identically if `sub54` admitted nothing,
  -- and `chainNewKS=0` would read identically if nothing composed.
  let admitKS := ps.countP (fun (c, p) => (m.sKS[c]!)[p]!)
  let admit54 := ps.countP (fun (c, p) => (m.s54[c]!)[p]!)
  let properKS := ps.countP (fun (c, p) => c != p && (m.sKS[c]!)[p]!)
  let proper54 := ps.countP (fun (c, p) => c != p && (m.s54[c]!)[p]!)
  let r2KS := ps.countP (fun (l, r) => reach2 m m.sKS l r)
  let r254 := ps.countP (fun (l, r) => reach2 m m.s54 l r)
  s!"K2CHAIN[{m.d.name}] pats={nPat m} tgts={nTgt m} ksSoundKS={ksSoundKS} " ++
  s!"specSoundSpec={specSoundSpec} ksSoundSpec={esc.length} escReal={escReal} " ++
  s!"escParentInterior={escPI} escChildInterior={escCI} chainNewKS={chainNewKS} " ++
  s!"chainNew54={chainNew54} chainEsc={chainEsc} admitKS={admitKS}/{properKS} " ++
  s!"admit54={admit54}/{proper54} reach2KS={r2KS} reach2_54={r254}"

/-- Witnesses from the HARD class — parent authorizes real targets under §5.4 and the child
escapes it anyway — so the strong case is exhibited rather than counted. `parent54=` is how
many targets the parent authorizes under §5.4, i.e. proof it is not a meaningless grant. -/
def hardWitness (m : M) : String :=
  let hits := (pairs m).filter (fun (c, p) =>
    (m.sKS[c]!)[p]! && !extSub m m.e54 c p && nonEmpty m m.e54 p)
  match hits with
  | [] => s!"[{m.d.name}] NONE -- every over-grant has a parent authorizing nothing under 5.4"
  | _ =>
    s!"[{m.d.name}] " ++ String.intercalate " " ((hits.take 3).map (fun (c, p) =>
      let t := (List.range (nTgt m)).find? (fun t => (m.e54[c]!)[t]! && !(m.e54[p]!)[t]!)
      let pe := (List.range (nTgt m)).countP (fun t => (m.e54[p]!)[t]!)
      match t with
      | none => "?"
      | some ti =>
        s!"{joinAbs m.d.pats[c]!}<={joinAbs m.d.pats[p]!}@{joinAbs m.d.tgts[ti]!}(parent54={pe})"))

def mGeneral : M := build general
def mPeerlike : M := build peerlike

#eval report mGeneral
#eval report mPeerlike
#eval hardWitness mGeneral
#eval hardWitness mPeerlike

end EntityCoreFormalization.K2Chain
