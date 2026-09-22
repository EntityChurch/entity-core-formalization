# The assumption ledger — what the models take on faith, and who discharges it

Every model in this repo verifies a *model*. Each one reaches its result partly by
**abstracting something away**: the capability-chain verdict becomes an opaque predicate,
the path matcher becomes an uninterpreted function, a signature becomes a symbolic term.
That is legitimate and necessary — a model that abstracted nothing would not be checkable.

It is only *sound*, though, if the property each model **assumes** of its abstraction is a
property something else actually **proves**. `docs/ASSURANCE-MAP.md` divides that labour in
prose: the Lean authority proof owns the authority-logic interior, TLA+ owns concurrency,
Tamarin/ProVerif own the active attacker. Prose is not a check. This file is the artifact
that makes the division inspectable: **one row per abstraction, stating the proposition
relied on and naming what discharges it — or recording that nothing does.**

This is discipline **D11** (declare the inventory boundary) applied to the *seam between*
tools rather than separately inside each one. It is the half of the fidelity story that the
per-tool reports structurally cannot tell, because each report can only see its own side.

> **Read `docs/COVERAGE-MATRIX.md` for what is verified and by which engine.** This file is
> the complement: what is *not* verified anywhere, deliberately, and what the verified
> results rest on. A row here is not a gap in coverage — it is a load-bearing assumption,
> which is a different and less visible thing.

---

## 0. How to read a row

Each row names the **model site** (symbol + path — never a line number, which rots), states
the **proposition the model relies on** as a proposition, and gives a **verdict**:

| Verdict | Meaning |
|---|---|
| **CLOSED** | Something proves the assumed proposition, or something stronger, with no hypothesis the model does not itself establish. |
| **CLOSED-MODULO-H** | Discharged only under a further hypothesis **H** that neither side proves. The row states H. |
| **OPEN** | The model relies on the proposition and nothing anywhere checks it. |
| **BY-DESIGN** | Deliberately unowned. No tool in this ecosystem reaches it; the row names who would. |

A **CLOSED-MODULO-H** row is not a defect. It is the honest form of a result whose
hypothesis is discharged somewhere outside formal methods — by a conformance vector, by
code review, or by nothing yet. What makes it useful is that the hypothesis is *written
down and countable*, instead of living in the gap between two green reports.

**Class L** rows face the Lean authority proof in the keystone peer. **Class T** rows are
internal to this repo — a TLA+ or Spin model assuming what a Tamarin/ProVerif theory
proves. **Class O** rows face nothing.

### Citing the Lean side

Lean citations are `(theorem, file, sha256)`. The digest — not a commit — is the pin, for
the same reason `spec-data/` pins by digest: a published document must cite something that
resolves for a reader outside this ecosystem, and a digest does. `make leanseam` checks
every digest and every cited name against a local keystone checkout; §5 states exactly what
that check does and does not assert.

Files pinned by this ledger, at the revision the correspondences below were derived from:

| File | sha256 |
|---|---|
| `protocol-generator/lean/proofs/EntityCoreProofs/CapabilityProofs.lean` | `78a157cdad043c4cab305636abd9aefe2a89cb8e98f6df456c07494aa567a1f8` |
| `protocol-generator/lean/src/EntityCore/Capability.lean` | `dcba5d3442e32b64a289057c8d503502fedd83ad173ba892b1f6e3d6a52eccfc` |

> **These two digests were WRONG from 2026-09-06 to 2026-09-09, with `make leanseam` green
> every day, and the mechanism is this repo's own headline class.** The gate parses the
> `leanseam-pins` block in §5 and nothing else. When keystone adopted the routed §5.5a packet
> and both files changed, commit `42ac3e4` updated the **pin block** — correctly, and the gate
> refused the re-declare until each new theorem was read — and left **this table**, which
> restates the same two facts in prose, at the superseded values. So the document told a reader
> the digest *is* the pin and that `make leanseam` checks every digest, while displaying two
> digests `make leanseam` has never read.
>
> That is the *unread facet* shape one level over: not a second clause in a gated sentence, but
> a **second copy of a gated fact in a different notation** — a table beside a code block. It
> is also D14's "a corrected defect survives longest somewhere that does not look like prose":
> a 64-hex string does not read as a claim, so the session that fixed the pin did not think of
> this as a site.
>
> **Fixed both ways.** The values above are current, and `tools/lean-seam.py` now scans the
> whole ledger for any 64-hex digest outside the pin block and fails when one is not a declared
> pin — so a third copy in a fourth notation cannot go stale silently either. Teeth-tested by
> reverting this table and confirming the failure names both files.

Both are core-Lean (no mathlib), toolchain `leanprover/lean4:v4.29.1`, and every theorem
cited below sits under a `#print axioms` honesty gate in its own file — so a `sorry` would
be visible rather than silent. `make leanseam` re-checks that gate per cited name.

**Visible to whom, though.** Until 2026-08-30 that sentence was doing more work than it had
earned: the gate makes a hole visible *in the output of a build*, and nothing in either repo
ran that build. `make leanproof` now does, and asserts the axiom set each gate reports —
§7. Read the two together: `leanseam` says the cited text has not moved, `leanproof` says
what it says is proved without a hole. Neither says the correspondence is the right one.

---

## 1. Class L — the Lean-facing seam

### L1 · The structural chain verdict is a pure function of the chain

- **Model site:** `ChainValid` in `tla/Revoke.tla`; the same abstraction in `spin/revoke.pml`.
- **Assumed:** the §5.5/§5.6 structural verdict is a total function of the resolved chain —
  in particular it does not vary with the per-verdict evaluation timestamp `t` except
  through the links' own declared temporal bounds, and it holds the **same value at peer A
  and peer B**. The model pins it to the constant `TRUE` and checks the §5.10 layer around it.
- **Discharged (time half):** `verifyChain_time_stable` and its corollary
  `verifyChain_time_independent` — `CapabilityProofs.lean`. Lean's result is the *stronger*
  of the pair: the model needs determinism only at equal `t`, Lean proves it across **any**
  two times agreeing on each link's temporal predicate.
- **H (peer half):** `verifyChain` takes `localPeer` as an argument and the verdict is
  therefore **not** peer-independent in general — `verifyChain_foreign_root` proves the
  extreme case, where a non-local single-sig root denies outright. Holding `ChainValid` equal
  at A and B is sound only for a restricted class of chains. `Revoke.tla` does not state the
  restriction, and §5.10's determinism MUST is scoped to "cross-peer-relevant chains", which
  is exactly the class where it needs saying.
- **Where the peer-dependence actually lives — corrected 2026-09-06, and this row had the
  mechanism wrong.** It said `localPeer` reaches the verdict through *"the §5.5a granter-frame
  canonicalization"*. **§5.5a granter frames are the one part that is not `localPeer`.**
  `edgeOk` (`Capability.lean:344`) derives `cf`/`pf` from `child.granterPeer` /
  `parent.granterPeer` — from the chain — and `grantSubset` passes those to the **resources**
  dimension only. The resources dimension is therefore already peer-independent. `localPeer`
  reaches the verdict through the *other three* dimensions:
  - **handlers and operations** — `scopeSubset localPeer localPeer`, so a **relative** pattern
    in either is canonicalized in the evaluating peer's own frame and can differ at A and B.
  - **peers** — `scopeSubset localPeer localPeer`, *and* the scope itself defaults to
    `{ incl := [localPeer] }` when a grant omits it. That is a peer-dependent **value**, not a
    frame, so no canonicalization result can repair it: where exactly one of child/parent
    omits `peers`, the comparison is against a different set at each peer.
- **A hypothesis we tested and refuted, recorded because forming it was the risk.** L12's
  frame-independence result looked like it might discharge this H: §5.5a *requires* cross-peer
  authority to be absolute, absolute patterns canonicalize identically in any frame, so for
  exactly the class §5.10 cares about the frames need not agree. **Reading the definitions
  refuted it twice** — the theorem aims at the resources dimension, which was never the source
  of the peer-dependence, and the three dimensions that are the source are untouched by it
  (the `peers` default is not a framing question at all). *This is the L7 error's exact shape —
  a mechanism assembled from a theorem that agreed with a hypothesis already formed — caught
  this time by reading `grantSubset` before writing the row down.*
- **Verdict: CLOSED-MODULO-H**, unchanged, with H now correctly located: the restriction is
  "every handlers/operations pattern in the chain is absolute, **and** `peers` is declared
  rather than defaulted", not "the two peers' frames agree." → work-item,
  `docs/STATUS.md` §Next.
- **H is narrower than this row states, AS SPECIFIED — conditionally, 2026-09-10 (K1).**
  Two of the three dimensions named above are **id-scope** (`operations`, `peers`), and §3.6's
  normative grammar — at our pin, 0.8.1 F40 — matches those **literally, with no frame at all**.
  A literal match is peer-independent by construction, so **as the spec specifies it** the
  residual reduces to **`handlers` alone, plus the `peers` DEFAULT value** — which was never a
  framing question and is the half this row already identified as unrepairable by
  canonicalization.
  **Stated as conditional and deliberately not folded into the verdict**, because the row cites
  an artifact rather than the spec: keystone's `scopeSubset` **is** untyped, so in the
  development this row actually rests on `operations` really is frame-dependent, and H reads
  correctly against what ships. *The residual is smaller than stated in the specified system and
  exactly as stated in the implemented one* — which is the seam this whole ledger exists to keep
  visible, arriving inside a single row. The row moves when K1 does.
  `docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md` §4.

### L2 · The verdict is computable before handler entry

- **Model site:** `Gate(p)` in `tla/Reentry.tla`; `Honored(p)` in `tla/Core.tla`;
  the gate in `spin/reentry.pml` and `spin/core.pml`.
- **Assumed:** the verdict is a **total** predicate — it terminates on every chain, and it
  can be evaluated *before* the handler runs. The §6.5 ordering property the models check
  is meaningless if the gate can diverge.
- **Discharged:** by construction. `walk` and `verifyChain` (`Capability.lean`) are total
  `def`s over structural recursion on the link list, with no `partial` — Lean's termination
  checker discharges the obligation at definition time, so there is no separate theorem to
  cite and none is needed.
- **Verdict: CLOSED** (by construction, not by theorem — stated so a reader does not go
  looking for a theorem name).

### L3 · An authority holding no grants covers nothing

- **Model site:** `Covers` in `tla/Authority.tla` / `tla/AuthorityApalache.tla`, specifically
  the `OTHER -> FALSE` arm; the same two-point scope in `spin/authority.pml`.
- **Assumed:** `Covers("absent", r) = FALSE` for every `r` — deny-by-default at the §5.2
  dispatch gate.
- **Discharged:** `checkPermission_no_grants_deny` — `CapabilityProofs.lean`. Vocabulary
  differs (the model calls it an empty authority slot, Lean calls it a token with
  `grantsOfToken token = []`); the proposition is the same, and Lean's is about the real
  `checkPermission` rather than an abstraction of it.
- **Verdict: CLOSED.**

> **Not a row: `checkResourceScope_no_targets_deny`.** An earlier survey paired this theorem
> with `Authority.tla`'s resource gate. It does not discharge anything here. Lean's theorem
> is about a resource object that is *present but names no targets*; `Authority.tla` models
> only "names a resource" (`r1`/`r2`) versus "names none" (`none`), and per §5.2 — "the
> condition is the field, `resource is not null`" — the latter correctly does not trigger the
> resource check. The present-but-empty case is **unmodeled in this repo**. Recorded here
> because a correspondence that does not exist is worth stating once, so it is not
> re-proposed. See §4.

### L4 · The depth brake is pure structure, and runs before the authz work

- **Model site:** `PresentDeeperChain` / `CapDepthCode` in `tla/Bounds.tla`; `spin/bounds.pml`.
- **Assumed:** the §4.10(b) chain-depth test is a function of the chain's *shape* alone, so
  it can be gated ahead of any signature or authorization work and report `400
  chain_depth_exceeded` distinctly from a `403`.
- **Discharged:** `chainExceedsDepth_iff` — `CapabilityProofs.lean` — which proves
  `chainExceedsDepth rc = true ↔ rc.links.length > 65`: a length test, no crypto, no walk.
- **Scope note (not a residual):** the model treats the limit as a constant `MaxCapDepth`
  and proves the brake fires for any value; Lean fixes the peer's configured maximum at
  64 delegation hops (`links.length > 65` — a 65-link chain is a root plus 64 hops). §4.10(b)
  makes the value implementation-defined with 64 the required default, so both are
  conformant and neither claims the other's ground. The `> 65` / "max depth (64)" pairing in
  the Lean source reads as an off-by-one until you count the root link; noted here so the
  next reader does not re-derive it.
- **Verdict: CLOSED.**

### L5 · Attenuation composes along a chain

- **Model site:** `narrow/1` in `tamarin/NoEscalation.spthy` and `tamarin/NoEscalation.pv`,
  with the verifier's two valid-child arms (identity, or strict `narrow`).
- **Assumed:** per-link attenuation **composes** — a chain of per-link checks yields
  leaf ⊆ root, so authority strictly above the root is unreachable.
- **Why this is the sharpest row in the ledger.** In the symbolic model `narrow` is a *free
  unary function*, so composition is free: no equation lets a term climb back up, and
  `no_escalation` follows from the term algebra. In the real system attenuation is a subset
  relation over path patterns, and its transitivity is a **substantial theorem** — without
  it, Tamarin's lemma is a true statement about `narrow` and says nothing about the protocol.
- **Discharged:** `isAttenuated_trans`, via `grantSubset_trans` → `scopeSubset_trans` →
  **`matchesSegNM_trans`** (was `matchesSeg_trans` until 2026-09-15) — all in
  `CapabilityProofs.lean`, and the expiry conjunct (a finite parent forbids an infinite
  child) proved inline in `isAttenuated_trans`. ⛔ **"No residual hypotheses beyond the two
  premises" was true until 2026-09-15 and is not true now** — see the next two notes. The
  sentence is left visible rather than silently replaced, because it is the claim that moved.

- **Scope note, 2026-09-10 — what the transitivity is transitivity OF (K1), and it is not a
  drift note.** §3.6's **id-scope pattern grammar is normative at OUR OWN PIN** (0.8.1, F40):
  `operations` and `peers` match the raw value **literally**, with none of the §5.4 path
  transforms. Lean's `scopeSubset` takes no `ScopeKind` and canonicalizes all four dimensions,
  so it does not implement that rule for two of them — **machine-checked**, `#eval` over nine
  pattern pairs, two disagreeing **in opposite directions**: parent `operations = ["/*/get"]`
  *admits* child `["/other/get"]` (over-grant), and parent `["*"]` *fails to cover* the same
  child (fail-closed). Spec 0.8.2.16 is confirmation, not the source — it repaired the §5.2/§5.6
  pseudocode that had been contradicting §3.6.
  This does **not** touch the row's proposition: transitivity of the untyped relation is as true
  as transitivity of a typed one, and `isAttenuated_trans` is unaffected. What it qualifies is
  the **discharge**: Tamarin's `no_escalation` is conditional on `narrow` being the real subset
  relation, and the function proved about is not that relation on two of four dimensions.
  **Verdict stays CLOSED — the row is about composition and composition holds — and the "strongest
  single link" claim now carries a named boundary rather than none.** Routed as K1,
  `docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md`.
- **And K2 reaches this row through the same function, 2026-09-10.** `scopeSubset_trans` →
  `matchesSeg_trans` is the chain that discharges Tamarin's `no_escalation` condition, and
  `matchesSeg` is **not** §5.4's matcher (L6, K2). So the condition is discharged for a matcher
  strictly more permissive than the specified one, on `resources` — the dimension this row's
  Tamarin models actually frame. **Two independent routes now qualify the same discharge**: K1
  (wrong matcher applied to id dimensions) and K2 (wrong matcher on the path dimension itself).
  The theorems remain true and `make lean` remains green; what is qualified is what they are
  theorems *about*.
- **⛔ T5a IS CONDITIONAL NOW, 2026-09-15, AND THE VERDICT MOVES WITH IT.** Keystone landed
  this repo's `K-6` and `K-7` at `fee2e422` and **told us the cost in the same packet**
  (`entity-core-keystone/docs/status/ROUTING-2026-09-15-b-…`, §3a). `scopeSubset` is now typed
  by `ScopeKind`; its `.id` branch compares with §3.6's literal `matchesIdPattern`, and the
  transitivity of *that* matcher is carried as an explicit undischarged hypothesis:

  > `abbrev IdPatternTrans : Prop := ∀ x y z : String, matchesIdPattern x y = true → matchesIdPattern y z = true → matchesIdPattern x z = true`

  So `isAttenuated_trans` composes **unconditionally** on the two **path** dimensions
  (`handlers`, `resources` — via `matchesSegNM_trans`) and on the **whole expiry half**, and
  composes **through `IdPatternTrans`** on the two **id** dimensions (`operations`, `peers`).
  Their source records the argument that the hypothesis holds — `z = "*"` immediate, `z`
  literal forces equality, `z = Q ++ "/*"` a prefix argument with the `y = "*"` case vacuous
  on a length bound — and declines to derive it because `String.startsWith` routes through the
  `ForwardPattern` typeclass and it becomes a from-scratch string theory. **That is the same
  boundary `grantPattern_namespace_isolation` declines by name (L7's H), for the same reason,
  in the same file.**
- **The trade is in the spec's favour and saying so is part of the row.** Before F50 this
  theorem was **unconditional** — and it was, for two of four dimensions, a theorem about a
  matcher §3.6 calls non-conformant. **Conditional-and-about-the-right-function is strictly
  better than unconditional-and-about-the-wrong-one**, which is keystone's own framing and is
  correct. ⭐ **And that is exactly what this row's K1 note asked for**: K1 said the discharge
  was "for a function that is not that relation on two of four dimensions." It now is that
  relation on all four. **K1 is CLOSED** — see L6.
- ⚠ **What this costs us, stated as a decision we owe rather than a fact we observed.**
  Keystone asked, in that packet, whether we want `IdPatternTrans` discharged, and named three
  ways: mathlib in `proofs/`, a hand-rolled prefix lemma in their tree, or **this seat proving
  it and them citing it**. They have no preference and will not pick unilaterally. Our own
  `A-3` answer — *"not worth the mathlib dependency for one decidable check"* — is now
  **load-bearing on whether this stays a hypothesis**, which it was not when we gave it.
  Routed back in
  `docs/status/ROUTING-2026-09-15-b-entity-core-keystone-t5a-is-conditional-the-capstone-carries-three-hypotheses-and-we-are-not-picking-the-discharge-for-you.md`;
  the row stays CLOSED-MODULO-H until one of the three lands.
- **Verdict: CLOSED-MODULO-H.** **H = `IdPatternTrans`** — transitivity of §3.6's id-scope
  literal matcher, undischarged in either tree. Scope of H, because it is narrow and the row
  should not read as weaker than it is: **`resources` is the dimension the nine `tamarin/`
  theories at this row's model site actually frame, it is path-scope, and it composes
  unconditionally.** H reaches `operations` and `peers`.
  **The END-TO-END form (`allowed_chain_leaf_atten_root`, pinned below, the declaration that
  folds this row through L11 into "a leaf's authority is a subset of the root's") carries two
  further conditions**, and they are named here rather than left in the Lean: `IdPatternRefl`
  — the same boundary as H, reflexivity instead of transitivity, used only at the induction's
  base — and `entityMatchable`, a side condition excluding capabilities with an unmatchable
  path pattern. ⭐ **The second one is not a residual**: read against `spec-data/v0.8.2.25`
  §5.4 it excludes exactly the capabilities the spec rules **INVALID `[MUST]`**, include and
  exclude arrays alike, scoped to the same two path dimensions. **Verified here rather than
  taken from the packet** — see L11 — so it does not enter H.
  *(Previously CLOSED, on the strength of a theorem with no hypotheses. The change is in the
  Lean text, not in anything here, and the second half of `make lean` is what refused to
  accept it silently.)*
  **This is still the strongest single link in the whole assurance map**, and the shape is
  unchanged — *the Tamarin result is conditional, and Lean is what discharges the condition* —
  with one word added: **Lean discharges it for the dimension those theories frame, and names
  its own hypothesis for the other two.** A link whose residual is written down is stronger
  than one whose residual is a phrase in a different file, which is the whole argument for
  this ledger and is worth having a row demonstrate.

### L6 · The path matcher is reflexive and transitive; excludes override includes

- **Model site:** `canon/2` and `covok/2` in `tamarin/ChainTopology.pv` (`Canon`/`Cov` facts
  in `ChainTopology.spthy`); the same abstraction in `tamarin/DeepChain.pv`,
  `tamarin/DeepChainN.pv`; `theScope` in `tamarin/Caveats.pv`.
- **Assumed:** the §5.4 segment matcher is reflexive and transitive, and a value inside a
  scope's exclude set is not matched regardless of the includes (deny-override).
- **Discharged:** `matchesSeg_refl`, `matchesSeg_trans`, `matchesScope_excl_override`, and —
  separately, because 0.8.1 F40 makes the two matchers distinct —
  `matchesScope_id_excl_override` and `matchesIdPattern_literal`, all in
  `CapabilityProofs.lean`.
- **K2, 2026-09-10 — `matchesSeg` IS NOT §5.4's `matches_pattern`, and this row assumes it is.**
  §5.4's matcher has exactly four arms: bare `*`; a **leading** `/*/` peer wildcard that strips one
  segment and recurses; a trailing `/*` prefix match; otherwise **exact equality**. **There is no
  interior-wildcard arm.** `matchesSeg` recurses structurally over both segment lists, so its
  `| _ :: ps, "*" :: pt` arm fires at **every** position — measured: `/peerL/*/b` matches
  `/peerL/a/b` in Lean (**true**), and falls to exact equality in §5.4 (**false**), in
  keystone's own generated Go, and in its generated Rust. Controls in both directions agree.
  **This row's assumed proposition — reflexivity and transitivity of *the §5.4 matcher* — is
  discharged by theorems about a DIFFERENT, more permissive function.** `matchesSeg_refl` and
  `matchesSeg_trans` are true; they are not about §5.4. The direction is the dangerous one: a more
  permissive matcher inside `scopeSubset` admits child patterns **that the parent does not
  authorize under §5.4**, and unlike K1 this is on **`resources`** — a genuine path-scope
  dimension, and the one nine `tamarin/` theories abstract as `canon`/`covok`.
  *(That scope qualifier was added 2026-09-10 and it is a correction, not a clarification — **R12**.
  The sentence stood unscoped and read as an escalation claim. It is not one: `Chain.lean` measures
  that a keystone peer's attenuation check implies containment under the matcher that same peer
  dispatches with, so no peer hands out authority its own root lacks. The over-grant is relative to
  §5.4's reading of the parent's grant, which makes K2 a cross-implementation ALLOW divergence and
  not an internal escalation.)* **Verdict held at CLOSED pending keystone's
  ruling (K-4a), because which side is wrong is a spec question as much as a code one — but this
  row should be read as OPEN-in-effect until it is answered.** Routed:
  `docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md` §10.
- **The divergence is now BOUNDED from both sides, 2026-09-10 — and the bound is where this row's
  own models live.** `make leanlemma` (`lean/lemmas/StarFree.lean`) proves
  `matchesSeg_starFree`: on a **star-free** pattern `matchesSeg` *is* list equality, at any
  length, because on that class neither wildcard arm is reachable. The differential behind it,
  now gated, measures the complement: **all 108 disagreements over 3276 pairs fall inside the 624
  interior-`*` pairs**, and the two matchers agree on all 1521 star-free and all 2652 edge-only-`*`
  pairs. **So the residue this row carries is exactly: a pattern with a `*` in an interior
  segment.** That does not close K-4a and does not change the verdict — the theorems are still
  about a function that is not §5.4's on that class — but it says how large the gap is, which
  "discharged by a different function" alone does not. **Read it as a limit on the row's exposure,
  not as a repair**: the nine `tamarin/` theories abstract the matcher entirely, so whether any of
  their `canon`/`covok` instances is an interior-`*` pattern is a separate question, and it is the
  K2 chain measurement on `docs/STATUS.md` §Next.
- **THE CHAIN MEASUREMENT IS DONE, 2026-09-10, and it relocates this row's exposure rather than
  closing or widening it.** `lean/lemmas/Chain.lean` (`make leanlemma`) asks the question this row
  actually turns on: does the divergence compose? **No.** Both admission relations are
  transitively closed — two admitted links reach exactly the pairs one link reaches
  (`chainNewKS=0`, `chainEsc=0`, with `reach2KS=591=admitKS` so the zero is not vacuous), which on
  the keystone side is `matchesSeg_trans` lifted by their own `scopeSubset_trans` and therefore holds for multi-pattern scopes and the exclude direction too.
  **Three things follow for this row.** (1) §5.6's *"widens authority down a delegation chain,
  where nobody re-checks"* is not where this bites — the over-grant is complete at the **first**
  link, 147 of 591 admitted pairs. (2) `ksSoundKS=0` and `specSoundSpec=0`: each peer's attenuation
  check implies containment under the matcher that peer dispatches with, so **neither escalates
  against itself** and the divergence is strictly cross-semantics. (3) The exposure is bounded:
  an over-grant requires a **parent pattern with an interior `*`** in 147/147 and 30/30 cases, and
  never requires an unusual child (0/147) — so a peer that issues no interior-`*` grant pattern is
  unexposed, today, without K-4a. Full result and its stated limits (bounded target set, absolute
  patterns only, includes only):
  `docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md` §15.
- **Scope note, 2026-09-09 — every theorem here is about the §5.2 side (K1).** This row has
  carried *"0.8.1 F40 makes the two matchers distinct"* since the ledger was written, and all
  five cited theorems are about `matchesScope` / `matchesIdPattern` — the **dispatch** check.
  **Nothing here is about the id matcher on the SUBSET path**, because in that file there is no
  such function to prove anything about: `scopeSubset` takes no `ScopeKind`. Spec 0.8.2.16 now
  requires the same split in §5.6, so the distinction this row names holds on one of the two
  sites the spec applies it to. No verdict changes — the theorems cited are true and discharge
  what the row claims — but the row's *reach* is half of what the phrase "the two matchers are
  distinct" suggests, and that is worth having written down where the phrase is.
  **Recorded plainly: this row named the distinction and nobody here followed it into §5.6 for
  three days, eleven lines away in a file we had read for another reason.** K1 —
  `docs/status/ROUTING-2026-09-09-KEYSTONE-SCOPE-SUBSET-TYPING.md`.
- **⭐ K1 IS CLOSED, 2026-09-15 — ADOPTED, AND THE SENTENCE ABOVE IS NOW FALSE OF THE LIVE
  TREE.** *"`scopeSubset` takes no `ScopeKind`"* was the finding; at keystone's `fee2e422` it
  takes one, dispatching `.id` for `operations`/`peers` and `.path` for `handlers`/`resources`,
  with `grantSubset` naming the kind per dimension and **no default** — because, in their own
  note at the site, a default is how the next dimension inherits the wrong matcher silently,
  which is the original F40 defect. The two `#eval` divergences this row published (parent
  `operations = ["/*/get"]` admitting child `["/other/get"]`; parent `["*"]` failing to cover
  it) are both repaired by construction: neither operand reaches `canonSegs` any more.
  **The scope note above is left standing unedited** — it was true of the tree it was written
  against, and per `FINDINGS-INDEX.md` §7 a finding retires when the measurement is re-run,
  which is this bullet, not when the amendment lands.
- **⭐ K2 SURVIVES, AND IT IS MEASURED RATHER THAN INFERRED, 2026-09-15.** The obvious reading
  of the same commit is that a typed `scopeSubset` repairs this row too. It does not, and the
  gate is what says so: `matchesSeg` itself is **byte-unchanged** — keystone kept its clause
  order deliberately, because six `rfl`-level arm-characterization lemmas are facts about that
  order — and `resources` is `.path`, so the interior-`*` arm still fires at every position on
  the one dimension nine `tamarin/` theories frame. `make leanlemma` re-ran `lean/lemmas/Chain.lean`
  against the new tree and **every published K2 figure reproduces exactly**: `ksSoundKS=0`,
  `specSoundSpec=0`, `ksSoundSpec=147`, `escReal=147`, `escParentInterior=147`,
  `escChildInterior=0`, `chainNewKS=0`, `chainEsc=0`, `admitKS=591`, `reach2KS=591`.
  **`K-4a` remains the open ask.** *This is the reason that gate carries every published figure
  one-to-one rather than a summary: "the definition moved and the result is unchanged" is a
  measurement, and reading the diff would have given an opinion.*
- **What DID move here is the matcher on the ATTENUATION path, and it moved toward the spec.**
  `scopeSubset` now calls **`matchesSegNM`**, the §5.4-guarded wrapper, in both arms — this
  repo's `K-6`, adopted verbatim with the reasoning quoted at the site. So §5.4's *"`NEVER_MATCH`
  never matches, in either operand"* is enforced on the subset path as well as the dispatch
  path, closing a bypass that ran in the **permissive** direction. The new lemma
  `matchesSegNM_trans` is what made that possible without disturbing L5's proof surface, and it
  is pinned below. **This row's five cited theorems are unchanged and its verdict does not
  move**; what changed is that the function they sit beside is closer to §5.4 than it was, in
  one respect and not in the one K2 names.
- **Verdict: CLOSED.**

### L7 · Canonicalization roots a relative pattern at the granter's namespace

- **Model site:** the `canon(star, fr) = awild(fr)` reduction in `tamarin/ChainTopology.pv`
  (and the `Canon` fact in `ChainTopology.spthy`, `DeepChain*`); `NoUserAtSystem` in
  `tla/Register.tla` and `spin/register.pml`.
- **Assumed:** a bare peer-relative pattern `*`, canonicalized in frame `p`, denotes exactly
  `/{p}/*` — hence a grant issued by peer `p` cannot cover a resource in another peer's
  namespace. This is §5.5a/§6.2 namespace isolation, and it is what makes the §5.8
  cross-peer topology lemmas mean anything.
- **Discharged:** `grantPattern_namespace_isolation` — `CapabilityProofs.lean` — proves
  exactly this **conclusion**.
- **H:** the theorem takes the framing as a *hypothesis*:
  `hframed : ∀ p ∈ pats, (canonSegs granterPeer p).head? = some granterPeer`. Lean proves
  the security logic (framing ⇒ isolation) and declines to prove `hframed` itself from
  `canonSegs`' string operations, calling it mechanical stdlib plumbing.
- **What `hframed` actually excludes — corrected 2026-08-30, and the first version of this
  row got it wrong.** `hframed` is **not an unproved lemma; it is false in general.**
  `canonSegs` has two branches (`Capability.lean:118-119`) and only the *relative* one
  frames: an absolute pattern passes through `splitSegs` untouched, so `canonSegs "P" "/Q/*"
  = ["Q","*"]` and the head is `Q`, not the granter. That is not a defect — **§5.5a
  (line 2729) says the absolute form is how cross-peer authority MUST be expressed.** So
  `hframed` is a *scope restriction*: it confines the theorem to §5.5a's **peer-relative**
  pattern fragment and excludes every cross-peer grant.
- **The residual is discharged — 2026-09-06, `absolutePattern_names_one_peer`.** The ask went
  to `entity-core-keystone` and was adopted. §5.5a's **absolute named form** (`/{q}/…` reaches
  exactly `q`) now has its own theorem, with `frame` universally quantified and never
  constrained — which is the frame-independence of L12 carried into the matcher. Read against
  the model site: our `canon(awild(p), fr) = awild(p)` equation is exactly this pair of claims,
  and both halves now have a theorem (L12 for the equation, this row for what it buys).
  Keystone re-derived our counterexample by evaluation rather than accepting it, and
  witness-checked the new theorem for non-vacuity — the absolute-form denial denies a foreign
  namespace **while still covering `q`'s own**, so it is not a deny-everything triviality.
- **Verdict: CLOSED.** All three §5.5a pattern forms now carry a theorem apiece — relative
  (`grantPattern_namespace_isolation`, this row), absolute named
  (`absolutePattern_names_one_peer`, this row), absolute wildcard
  (`wildcardPattern_peer_agnostic`, **L13**) — matching the three `canon` equations our
  symbolic models carry, one for one.
- **A cost claim of ours that was wrong, and measuring it is what showed that.** This row said
  the relative half was *"genuinely mechanical (`¬p.startsWith "/"` + a `/`-free peer-id frame
  ⇒ head = frame)"*, and we routed an ask to discharge `hframed` on that basis. **Keystone
  declined it with a measurement, and the measurement is right:** in the pinned mathlib-free
  toolchain, core ships `String.splitOn` and `String.splitOnAux` and **zero theorems about
  either**; `splitOnAux` is `@[irreducible]`, well-founded over raw byte positions, with
  `extract` cutting a `ByteArray` under a UTF-8 validity proof. Discharging `hframed`
  syntactically is a from-scratch string theory, not plumbing. **We criticised their comment
  for being wrong about `hframed`'s scope and then repeated its error about `hframed`'s cost**
  — a cost estimate published without measuring it, which is D15's shape in prose rather than
  in a number. The ask stays open only as the mathlib question in `docs/STATUS.md` §Next.
- **Superseded claim, kept visible rather than deleted.** This row previously read: *"the
  ProVerif/Tamarin side does not independently establish `hframed` either. It assumes the
  same thing by equation — `canon(star, fr) = awild(fr)` is `hframed`, written as a rewrite
  rule. Two engines, one shared undischarged assumption."* **That was wrong in both halves**
  — see §4.1.

### L8 · A satisfied multi-sig root means a real quorum, including this peer

- **Model site:** the K-of-N acceptance rules in `tamarin/Multisig.{pv,spthy}` and
  `tamarin/MultisigKN.{pv,spthy}` (root content abstracted to a signed constant `rootC`).
- **Assumed:** acceptance of a §3.6 multi-sig root implies at least `threshold` **distinct**
  signers signed, and the local peer is among the signer set — the model's `threshold`
  lemmas are about the protocol only if the implementation's root check cannot be satisfied
  below quorum. (Distinctness is structural in the symbolic models: each signer is set up
  once, pinned by a `OnlyS<n>` restriction.)
- **Discharged:** `multiSigRootOk_quorum` — `CapabilityProofs.lean` — yielding both quorum
  conjuncts (`k ≤ signed count` and `signers.any isLocal`).
- **Precision note, and the kind of thing this ledger exists to catch:** the theorem's
  *conclusion* does not mention distinctness. That comes from the `noDupKeys signers`
  conjunct of `multiSigRootOk` itself (`Capability.lean`), which the theorem's hypothesis
  `multiSigRootOk signers k pn = true` carries but does not export. A reader chasing only the
  theorem name would not find it, and would be entitled to think the distinctness half was
  unproved. It is not — it is one projection away — but the row has to say so.
- **Verdict: CLOSED.**

### L9 · A foreign-rooted single-sig chain is denied outright

- **Model site:** the root-framing setup in `tamarin/Unforge.{pv,spthy}` and
  `tamarin/ChainTopology.{pv,spthy}` — the verifier's own root `P` is the only honest root.
- **Assumed:** a chain whose single-sig root granter is not the local peer cannot be
  accepted, independently of `t`. Without this the topology lemmas are about a
  configuration, not a rule.
- **Discharged:** `verifyChain_foreign_root` — `CapabilityProofs.lean`.
- **Verdict: CLOSED.**

### L10 · Expiry composes downward

- **Model site:** the `le/2` ordering abstraction in `tamarin/Expiry.pv` /
  `tamarin/Expiry.spthy` — `expires_at` arithmetic reduced to the order.
- **Assumed:** a child's expiry never exceeds its parent's, and a parent with a finite
  expiry forbids a child with none.
- **Discharged:** the expiry conjunct of `isAttenuated_trans` — `CapabilityProofs.lean` —
  which proves exactly the `{finite < ∞}` lattice step, `none` as top.
- **This row did NOT move with L5 on 2026-09-15, and that is worth one line rather than
  silence.** `isAttenuated_trans` became conditional on `IdPatternTrans` at keystone's
  `fee2e422`, and L5 is CLOSED-MODULO-H because of it. **The expiry conjunct is explicitly
  unconditional** — keystone's own note says so (*"the expiry half is unconditional"*) and the
  proof is the `≤` step in the finite-or-∞ lattice, which touches no matcher. A reader who saw
  L5's verdict move and assumed the whole theorem weakened would be wrong about this row.
  *Two rows citing one theorem can have different verdicts once that theorem grows a
  hypothesis, and only reading which conjunct the hypothesis reaches tells you which.*
- **Verdict: CLOSED.**

### L11 · The verdict actually enforces the per-edge check

- **Model site:** implicit in every model that treats an `allow` as evidence the chain was
  walked — `Gate`/`Honored` (L2), and the acceptance events in every Tamarin theory.
- **Assumed:** an `allow` verdict cannot be reached while skipping a link's attenuation
  check. L5's transitivity is worthless if the walk can decline to apply it per edge.
- **Discharged:** `walk_allow_cons` and `walk_allow_leaf_attenuated` —
  `CapabilityProofs.lean` — extracting `edgeOk` (and hence `isAttenuated`) from an allowing
  walk, plus `walk_allow_head`, `walk_allow_link_facts`, `edgeOk_atten`, `edgeOk_caveats`.
- **⚠ THE END-TO-END CAPSTONE GAINED THREE HYPOTHESES ON 2026-09-15, AND KEYSTONE'S PACKET
  NAMED ONE. This row's own six theorems did not move.** `allowed_chain_leaf_atten_root` — the
  declaration that folds L11's per-edge extraction through L5's transitivity into *"a leaf
  capability's authority is a subset of the root's"* — now reads
  `(hid : IdPatternTrans) (hidr : IdPatternRefl) … (∀ l ∈ chain, ∀ f, l.granterPeer = some f → entityMatchable lp f l.entity)`.
  Their `ROUTING-2026-09-15-b` §3a announces `IdPatternTrans` and lists four changed
  signatures; the capstone is not among them, and the third condition is a **different species**
  from the other two — not a lemma about a matcher but a **semantic side condition on the
  capabilities in the chain**, used only at the induction's base, where the statement degenerates
  to *"the leaf is an attenuation of itself"*. It is needed because `K-6`'s guard makes
  self-subset FALSE for a capability carrying an unmatchable path pattern.
- **We checked their justification instead of taking it, and it holds.** They argue the
  condition *"excludes exactly the capabilities the spec excludes."* Read against
  `spec-data/v0.8.2.25/ENTITY-CORE-PROTOCOL.md` §5.4: *"a capability any of whose `handlers`
  or `resources` scope patterns canonicalizes to `NEVER_MATCH` MUST be refused … at mint, at
  delegation, and at chain verification"*, scoped to path-scope at 0.8.2.24 and explicitly **not
  reaching `operations` or `peers`**. `grantMatchable` quantifies over exactly `handlers` and
  `resources`, and `scopeMatchable` over both the include and the exclude array — which is what
  *"any of whose … patterns"* says. **Sound, and the alignment is the finding's absence rather
  than the finding.**
- **The transferable piece, because it is not about this capstone.** ⭐ *A counterpart's
  enumeration of what changed is an INPUT SET, and it can be narrower than the diff.* Their
  packet is careful, correct in every claim we checked, and volunteers the cost — and it still
  under-reports, because §3a's subject was *"signatures your `make leanproof` should refuse to
  accept silently"* and the capstone's axiom set did not move, so it was not in that frame.
  **Reading the diff is what found it**; the gate went red on a different declaration entirely.
  This is D15's mechanism — *what is the input set* — asked of a packet rather than of a glob,
  and it is the counterpart of the rung we routed to keystone as `K-5` (*ask of a packet which
  of its claims were executed and which were read*), now pointed the other way: **ask of a
  packet which of the changes it enumerates, and re-derive the set yourself.**
- **Verdict: CLOSED.** Cited explicitly because it is the row a reader forgets: L5 proves
  the step composes, L11 proves the step is taken. **The six theorems this row cites are
  byte-unchanged and carry no new hypothesis** — the capstone that consumes them is where the
  conditions landed, and the ledger's own convention of citing the narrowest theorem that
  discharges a row is why this row holds while L5 moves.

### L12 · An absolute pattern denotes the same thing in any frame

- **Model site:** the `canon(awild(p), fr) = awild(p)` equation in `tamarin/ChainTopology.pv`,
  `DeepChain*.pv` and the corresponding `Canon` facts in the `.spthy` theories — the second of
  the three `canon` equations, and the one whose right-hand side **discards the frame**.
- **Assumed:** an absolute pattern is frame-independent — it means the same thing at the
  granter and at the verifier. Our theories encode this as a rewrite and rely on it whenever a
  chain compares an absolute pattern under two different granter frames, which
  `ChainTopology`'s three-principal topology does by construction.
- **Discharged:** `canonSegs_absolute_frame_independent` — `CapabilityProofs.lean` —
  `canonSegs f1 p = canonSegs f2 p` for any `p` beginning `/`, with both frames universally
  quantified. Keystone's note that it needs no `splitOn` reasoning at all is worth carrying:
  both branches reduce to `splitSegs p`, which is why this half was provable while the
  relative half is not.
- **Why this is a row and not a footnote to L7:** §5.5a makes the absolute form the **required**
  way to express cross-peer authority, so frame-independence is what makes a cross-peer grant
  well-defined at all. It is also live on a real path today — keystone reports `verifyChain`
  runs before the dispatch address check and `grantSubset` passes per-link granter frames to
  the resources dimension, so absolute patterns are compared under two different frames on
  every request presenting a delegated capability.
- **Verdict: CLOSED.** Added 2026-09-06; keystone proved it unprompted alongside the ask we
  did make.

### L13 · The wildcard form is peer-agnostic by design, not by omission

- **Model site:** the `canon(allp, fr) = allp` equation — the third `canon` equation in the
  same theories.
- **Assumed:** for a pattern whose canonical head is `*`, coverage does not depend on the
  target's peer segment. Our models encode this as a frame-discarding rewrite exactly as for
  L12, but the property it buys is the **opposite** one: universality rather than isolation.
- **Discharged:** `wildcardPattern_peer_agnostic` — `CapabilityProofs.lean` — the two sides
  agree for any two peer segments. Witness-checked by keystone for the failure mode that
  matters here: both sides evaluate **true** on a match, so this is agreement on coverage and
  not vacuous agreement on a universal failure.
- **Why it earns a row rather than being left implicit.** This is the one §5.5a form where the
  secure reading is "covers everything", so an absent theorem looks identical to a satisfied
  one — the shape §C.4 of `docs/PROPERTIES.md` calls vacuity, in the ledger instead of in a
  model. Stating it as a theorem is what distinguishes *"we checked and it is deliberately
  universal"* from *"nobody looked at this form."* We had neither a row nor a theorem for it
  before 2026-09-06, which is the more honest way to say we had not looked.
- **Verdict: CLOSED.**

---

## 2. Class T — the internal seam (TLA+/Spin assuming what the provers prove)

These are not Lean-facing, and they are cheap to close because both sides live in this repo.
They are listed for the same reason as Class L: a green TLA+ result that abstracts crypto is
sound only if a prover result covers the abstracted part, and nothing else says so.

| # | Model site | Assumed | Discharged by | Verdict |
|---|---|---|---|---|
| T1 | `tla/Conn.tla`, `spin/conn.pml` — §4.6 signatures / PoP abstracted; the nonce-echo check modeled as state | An attacker cannot produce a valid signed handshake response binding a nonce it did not receive | `tamarin/Binding.{pv,spthy}` (channel binding), `tamarin/BindingReplay.{pv,spthy}` (replay) | **CLOSED** |
| T2 | `tla/Register.tla`, `spin/register.pml` — grant-signature crypto abstracted | A handler grant cannot be forged | `tamarin/Unforge.{pv,spthy}` | **CLOSED** |
| T3 | `tla/Store.tla`, `spin/store.pml` — crypto abstracted; payload size / chain depth symbolic over/under-limit | The over/under-limit distinction is what the §4.9/§4.10 rules turn on, not the magnitudes | — (modelling choice, declared in the module header; no proposition to discharge) | **N/A — device** |
| T4 | `tla/Core.tla` — `Honored` = the composed verdict | The composed verdict is the conjunction the component modules check separately | `tla/RefMap.tla` (the mapping), `CoreRefines.cfg` (implication), `CoreMapFree*.cfg` (the classifier) — **and the runs refute the assumption**: 1 of 6 component invariants is carried, 5 are manufactured by the mapping | **CLOSED — ASSUMPTION FALSE** |
| T5 | `tla/Authority.tla` — `Covers` two-point scope, deliberately **disjoint** | Nothing about the protocol. Disjointness is a modelling device that makes consulting the wrong authority observable | — | **N/A — device** |

**T4 was the one that mattered, and it closed on 2026-09-06 by being refuted.** It was
recorded here because "the composed model is checked and the components are checked" reads,
wrongly, as "the composition is verified." That inference is now measured, and it is worse
than the row feared: the composed model carries **one** of the six component invariants of
`Conn` and `Store`.

### T4 — what was run, and why the answer is a refutation rather than a proof

**Refinement was attempted and does not hold, for a structural reason.** `Core` collapses
§4.6's handshake into one step (`conn[p] := "established"`); `Conn` runs new → hello_done →
established as two. A refinement mapping lets the abstract spec *stutter* while the concrete
one moves — it does not let one concrete step perform two abstract ones. So no mapping of
`Core` onto `Conn`'s phase satisfies `Conn`'s next-state relation, and **`Core` is not a
refinement of `Conn`**. For `Store` it is starker: `Core` has no counterpart for the
refcount, the referrer set, the write critical section or the admission state. The
checkpoint that scoped this predicted the shape for `Revoke` and it generalizes.

**So the weaker claim was run instead: invariant implication under an explicit mapping**
(`tla/RefMap.tla`). The component modules are `INSTANCE`d through it, so what is asserted is
each component's **own invariant text**, not a transcription of it into `Core`'s vocabulary.
*These are not the same claim as refinement and this ledger does not blur them: implication
says the reachable states satisfy the invariant, not that the composition preserves
behaviour.*

**And the implication result is worth nothing without the classifier, which is the real
contribution.** A mapping that sends a component variable to a constant makes that
component's invariant a tautology, and TLC reports the identical green for *"Core enforces
this"* and *"the mapping asserts it"* — `StoreBounded`'s vacuity reproduced inside the fix
for the composition gap. `tla/CoreMapFree.tla` therefore runs each mapped invariant against
**every type-correct valuation** rather than the reachable ones, one graded cfg each:

| component invariant | § | verdict | why |
|---|---|---|---|
| `Conn!DispatchedImpliesEstablished` | §4.2 | **CARRIED** | a type-correct valuation violates it, so the mapping does not force it — `Core`'s green is a fact about its dispatch gate |
| `Conn!TokenBounded` | §4.2 | MANUFACTURED | `Core` models no token issuance; the mapping's range is `{0,1}` |
| `Conn!NoEstablishWithoutNonce` | §4.6 | MANUFACTURED | `Core` has no nonce (row T1) |
| `Store!StoreRaceFree` | §4.8 | MANUFACTURED | `Core` has no write critical section |
| `Store!NoUseAfterFree` | §4.8 | MANUFACTURED | `Core` has no refcount or referrer set |
| `Store!ResourceBounded` | §4.9(b) | MANUFACTURED | the same shape `Core.tla` already removed as vacuous |
| `Store!CleanReject` | §4.10 | MANUFACTURED | `Core` has no admission state |

**TLC confirmed part of this independently, and the part it missed is the argument for the
classifier.** Running the seven mapped invariants over `Core`, TLC warned that two are
"constant-level formula[s] … evaluate[d] to TRUE". Only **two of the six** — the other four
mention a `Core` variable through the mapping and are still unfalsifiable;
`NoUseAfterFree` reads `store` yet cannot fail because the referrer set is constant. **A
syntactic constant-level check catches vacuity visible in the formula, not vacuity
manufactured by the mapping.** "The tool would have told us" is false here.

**Scope, stated rather than left to be assumed.** This is a **TLA+-only** result; `spin/core.pml`
is dropped from the row because Spin has no instantiation mechanism to state it with, so the
composition claim is unexamined on that track. The mapping covers `Conn` and `Store` — the
two the scoping named as the clean candidates. `Reentry` and `Revoke` are **not** mapped:
`Revoke`'s `Verdict1` is a function of three inputs that `Core` abstracts to `~revoked`, so
its invariants would be manufactured for the same reason `Store`'s are, and running them
would add rows without adding information. That is a judgement, not a measurement, and it is
the one thing here that is asserted rather than run.

**What this row now says.** The composed model is a real, checked artifact — its own
invariants (`FramesNotInterleaved`, `DispatchNeedsEstablished`, `ServeNeedsEstablished`,
`NoServeWhenRevoked`, `EventuallyResolved`) hold, with controls and a witness, and nothing
about that changed. What is *not* true, and was quietly assumed before today, is that
checking it also checks the components. It checks §4.2's dispatch gate and nothing else they
own.

**Ledger state — derived, and now gated.** As of 2026-09-15, the ledger is **42 rows**
(13 Class L, 5 Class T, 24 Class O): **14 CLOSED**, 3 CLOSED — ASSUMPTION FALSE (L7's row, O21
and O22), 2 CLOSED — ASSUMPTION ISOLATED (O6, O20), 1 CLOSED — ASSUMPTION ISOLATED AND CORRECTED
(O10), **2 CLOSED-MODULO-H (L1, and L5 as of 2026-09-15)**, 2 N/A — device, 3 BY-DESIGN, and
**15 OPEN**.

> **The 15 → 14 is L5, and it moved because a COUNTERPART COMMITTED, not because anything here
> changed.** Keystone adopted this repo's `K-6`/`K-7` packet; the adoption typed `scope_subset`
> and left `isAttenuated_trans` — T5a, the theorem `L5` discharges Tamarin's `no_escalation`
> condition with — conditional on an undischarged `IdPatternTrans`. **The row got weaker and the
> result got better**: the theorem is now about the function §3.6 requires instead of one it
> calls non-conformant. *A verdict moving down is not always a regression, and a ledger that
> could not express that would be pressure to leave the verdict alone.*

> **O23 is the newest row and it is a different species from every other one here.** Each of
> O1–O22 is an abstraction somebody *chose* and wrote down — the ledger's whole purpose. O23 is
> an abstraction nobody noticed making, found only when a counterpart shipped a fix for a
> **live capability forgery** that exploits it. *"A declared abstraction is a to-do list, not an
> absolution"* (O9's lesson) has a prior: **an undeclared one is not even a to-do list.** The
> instrument that now looks for this class is `make obligations`, whose denominator is the
> pin's normative surface rather than our citations.
**O20 is the row a new rule went looking for**, not one a model produced: `AGENTS.md` D15's
tenth shape says a model's unconditional `Init` restriction is a claim and must be a constant
with a control or an OPEN row here. Enumerating that class across all nine extension models
found exactly one unbooked site, and it is `QuorumSignerSet`'s — the identical assumption to the
one that had just been measured and found mis-stated on `AttestRevoke`. **It closed the next
day, by the experiment the row asked for** (`tla/QuorumSignerSetApalache.tla`), and the answer
was not `AttestRevoke`'s: on one relation, acyclicity IS enough, and the index order the model
hard-coded was strictly stronger than §4.2 needs. A rule that produces a row, a row that
produces an experiment, and an experiment that produces a finding (**Q8**) in two days is the
ratchet doing the thing it is for.
The Class-O rows went from four to ten in three commits on 2026-09-07, then to fifteen in three
more, then to nineteen with the identity track the same day, because a new track arrives with
its abstractions undischarged — the normal state, not a regression. The thirteen OPEN ones are
O5, O7, O8, O9, O11, O12, O13, O14, O15, O16, O17, O18 and O19; O6 closed the same day it
was opened, by being measured rather than argued, **O10 closed on 2026-09-08 the same way —
with the difference that measuring it showed the row had named the WRONG ASSUMPTION** — and
**O20 closed on 2026-09-09**, where measuring it showed the row had named an assumption
STRONGER than the section needs. **O22 closed on 2026-09-09** by the port its own row named
(`tla/IdentityProcessApalache.tla`), and it makes the tally **four rows closed by running, three
of which had to be restated to close**. A verdict column is not the only thing a ledger row can
get wrong, and the statement column has now been wrong three times as often.

**O11 was RESTATED on 2026-09-09 without closing, which is a fourth outcome and worth naming.**
O6, O10, O20 and O22 all closed by being measured. O11 was measured, its proposition survived, and
its **strength** was wrong: the closure it names is READ-side (only validated entries are
readable) and what §QUORUM:4.2 needs is WRITE-side (the readable set changes only through
validate-accept). The two coincide exactly as long as the tree only grows, which is what the model
that produced the row could represent. It stays **OPEN** — nothing discharges it either way — and
the verdict column deliberately does NOT say "RESTATED", because a new OPEN variant would split
the count every other document keys on. `make ledgercount` refused the attempt, which is the gate
behaving correctly on its author.

**O22's restatement is a different KIND of wrong from O10's and O20's, and it is the one to
watch for.** Those two named an assumption that was too STRONG or too WEAK — an error in the
proposition. O22's proposition was exactly right; what was wrong was the *consequence a reader
would draw from it*. "Nothing accumulated across arrivals is in reach" reads as a coverage gap —
a class of properties we had not got to yet. It is not: the accumulation is where §3.6 steps 2
and 3 get their INPUT, so the restriction did not merely hide properties, it made the validator's
own data source unrepresentable. **A row can be true and still mis-price itself**, and the price
is what decides whether anyone runs the experiment.

**Three things to read off the Class-O column rather than the row count.** First, **O5, O14 and
O19 are the same gap on three tracks**: no extension track has any prover model, so the
adversarial property each substrate exists to provide — an attestation was validly signed; K
distinct keys signed; a cert carries the signatures its topology demands — is discharged by
nothing here. Every green on all three tracks is a statement about structure, made on the
assumption that signatures work. They are counted per track rather than merged, deliberately:
merging would hide that the gap grew twice.

Second, **O15 is the row that was not visible until a second track existed**: two modules each
declared the other's dimension abstracted, both disclosures were honest, and the composition
nobody wrote is where a real interaction turned out to live (O12). That is O9's lesson — a
declared abstraction is a to-do list, not an absolution — arriving a second time from a
direction nobody was watching.

Third, **O16 is a new SHAPE of row and the one to read before starting a fifth track.** The
other eighteen say "no tool here reaches this". O16 says something sharper: the abstraction is
`QUORUM §4.2`'s resolver, this repo has already MEASURED it and found it defective (Q1), and the
identity models assume it works anyway. That is not an oversight — modelling identity on
§4.2-as-written would have re-derived Q1–Q7 wearing identity section numbers and routed them
twice. What makes it a ledger row rather than a footnote is that the assumption is a **constant
with a negative control** (`IdentityCertChainSubstrateBug`), so the gate table shows what the
identity greens rest on. **When a track consumes another track's known-defective output, make
the assumption a constant and control it, then open the row.** The prior checkpoint predicted
that this choice would otherwise be invisible afterwards; it was right, and this is the shape
that keeps it visible.

Those figures are produced by `make ledgercount`, which parses this file and fails if any
declared prose site disagrees. It exists because **this count has been published wrong four
times** — "eleven CLOSED rows" across five files, the Class-L verdicts in the tier audit,
"21 of 23 rows … the two open ones are L1 and L7" (every number wrong and the attribution
too), and "14 CLOSED … 2 OPEN" written two hours before O4 closed. `leanseam` and
`leanproof` print *theorem* counts and say nothing about rows or verdicts, so until now
nothing tied this. It asserts the counts and the row structure; it does **not** assert that
any verdict is correct.

The prior scoping, including the prediction that `Core` may not be a refinement at all, is in
`docs/status/CHECKPOINT-2026-09-06-WORKLIST-T4-NEXT.md` §4 — it was right.

---

## 3. Class O — declared unowned

No tool in this repo, and no Lean theorem, reaches these. Each names who would.

| # | Abstraction | Model sites | Owner, if anyone | Verdict |
|---|---|---|---|---|
| O1 | CBOR decoding — the hostile byte space | `tamarin/Malformed.{pv,spthy}` (`tbad` is an opaque constant, not a decode) | Conformance suite + fuzzing; `entity-core-keystone` type-system work | **BY-DESIGN** |
| O2 | Entity content, hashing, content-addressing | `tla/Emit.tla`, `spin/emit.pml` — opaque hash tokens | Type system + conformance vectors | **BY-DESIGN** |
| O3 | Computational crypto (§7.3) | every Tamarin/ProVerif theory — symbolic `sign`/`verify` | Nobody. A computational-model result would need CryptoVerif; `docs/STATUS.md` §Next | **BY-DESIGN** |
| O4 | Wall-clock skew tolerance `δ` (§5.10, W7 Knob 3) | ~~unmodeled~~ — **now modeled** in `tla/Revoke.tla`, `tla/RevokeApalache.tla` and `spin/revoke.pml` | this repo | **CLOSED** (2026-09-06) |
| O5 | **Attestation signature validity** — that a `system/attestation` bound in the tree was validly signed by its `attesting` party | `tla/AttestIndex.tla` — an attestation is an opaque name; binding is unconditional, no signature is modeled | Nobody yet. This is a Dolev-Yao question and the **attestation track has no prover model at all** — `MultisigKN.{pv,spthy}` proves K-of-N for the core capability surface, not for `ATTEST §4.1`/`§4.2`'s validators | **OPEN** |
| O6 | **Supersedes-chain acyclicity** — that `ATTEST §5.2`'s `walk_supersedes_chain` terminates. *Scope note added 2026-09-08: this row is about §5.2's WALK and remains correct. It is NOT the assumption §4.3's liveness needs — see O10, which was written by analogy with this row and had to be corrected.* | ~~not modeled~~ — **now modeled** in `tla/AttestLive.tla` (`BackWalkBoundedWhenAcyclic` green, `BackWalkBoundedAlways` violated) | **Nobody, and the assumption is now isolated rather than suspected.** The walk terminates exactly when the supersedes relation is acyclic; acyclicity itself follows from `supersedes` holding a content hash, which is O3's territory (computational crypto, owned by no tool here) and is **stated in no section of the spec** | **CLOSED — ASSUMPTION ISOLATED** |
| O8 | **`ATTEST §5.3` `find_live_head` computes its own stated contract** | `tla/AttestLive.tla` — `SpecHeadFindsLiveHead` asserted and **violated** on a three-link chain; `DagHeadFindsLiveHead` green for the algorithm all three implementations run instead | Nobody — and this is not an abstraction the model relies on, it is the model REFUTING a spec claim. Routed to `entity-system-architecture`; until it is ruled, any consumer calling `find_live_head` directly rests on an algorithm that returns null where a head exists | **OPEN** |
| O9 | **What `ATTEST §4.3`'s `is_self_revoked` means** | `tla/AttestRevoke.tla` — both readings computed side by side; `SelfRevReadingsAgree` and `LiveReadingsAgree` both **violated** | Nobody, and nothing here can: the helper is **used in normative pseudocode and defined nowhere in the document**, so there is no text to be faithful to. Not an abstraction the model relies on — the model shows the choice is observable in `is_attestation_live`'s answer. Routed | **OPEN** |
| O10 | ~~**Revocation-graph acyclicity**~~ → **JOINT ORDER over the supersedes AND revocation relations** — what `ATTEST §4.3`'s liveness recursion actually needs in order to denote a function at all | ~~assumed, not checked~~ — **now modeled** in `tla/AttestRevokeApalache.tla`, which makes the two restrictions separate constants (`SupOrdered`, `RevOrdered`) and encodes §4.3 as its defining equation, so "does this predicate have a value" is directly checkable: `LadderIsFixedPointRec` + `FixedPointUniqueRec` green under the joint order, **violated under either half alone** | **Nobody, and the row's own statement of the assumption was WRONG until it was run.** It said revocation-graph acyclicity, by analogy with O6 one relation over. It is not that: the recursion ALTERNATES (`is_attestation_live → has_live_transitive_descendant → is_self_revoked → is_attestation_live`), so the dependency is the COMPOSITION of the two relations, and the equation has two solutions on a configuration where **both graphs are acyclic** (supersedes `2→3→4→1`, revocations `3⊣1`, `4⊣1`; `f[4] = f[3] \/ f[4]`). §4.3's `visited` set guards one hop of two. What discharges it in a deployed system is content addressing — both pointers name an entity that must already exist, so both point backward in creation order — which is O3's territory and is **stated in no section**. Routed as F5, amended | **CLOSED — ASSUMPTION ISOLATED AND CORRECTED** |
| O11 | **The arrival-time closure** — that every path binding a `system/quorum` event into the tree also validates it, which is what `QUORUM §4.2`'s "trusted on subsequent reads" rests on. **RESTATED 2026-09-09: the closure is about WRITES, not about reads** | `tla/QuorumTrust.tla` — `CacheMatchesValidated` green **only** under `WalkClosedOverValidated`, and asserted-and-violated without it, in a two-step trace. **`tla/QuorumTrustApalache.tla` (2026-09-09) lifts three restrictions that model could not express** — §4.2.1 TRIGGER 3 had no action at all, the tree was monotone, and an attestation arrived once — with 9 greens, 3 finding rows, 4 controls and 6 witnesses | Nobody, and the document argues against itself. `QUORUM §4.2`'s cold-start posture asserts the closure outright ("tree-bound only on validation success"); `QUORUM §4.2.1` non-trigger 1 says a K-of-N failure "may sit in the tree at a structurally-valid path", and `QUORUM §8` permits raw `tree:put`. Neither is filtered out on the read side — the walk is the `ATTEST §5.4` index, which `ATTEST §5.7` I4 keeps unfiltered by design. Routed. **The row's statement was the right proposition at the wrong strength**: a READ-side closure (only validated entries are readable) makes every claim green in a model whose tree only grows, and `QUORUM §8` permits `tree:put(path, null)` in the same sentence as the additive form. With unbinds admitted, the read-side closure holds and the cache still goes stale, because non-trigger 2 forbids invalidating on the write that removed the entry. What §4.2 needs is that **the readable set changes only through validate-accept** — a constraint on operations, not on reads. O20's shape, third time | **OPEN** |
| O12 | **What `ATTEST §4.3`'s `not_expired` means** — O9's sibling helper, and the one with a consumer-visible consequence | `tla/QuorumSignerSet.tla` — both readings computed side by side; `NotExpiredReadingsAgree` **violated** on a two-node chain with a scheduled successor | Nobody, same as O9: used in normative pseudocode, defined nowhere. Under the literal reading (the `expires_at` check, which is what the name says and what §4.3 writes four lines above as a *separate* check from `not_before`) a not-yet-effective successor kills its predecessor without being usable itself, and `QUORUM §4.2` drops to the genesis roster. All three implementations read it the other way. Routed | **OPEN** |
| O13 | **`quorum-update` chain shape** — that a quorum's update graph is a single linear chain | `tla/QuorumSignerSet.tla` — `WellFormedChain` is the ANTECEDENT of both cohort greens, so off that shape they assert nothing | Nobody. `QUORUM §3.2` describes the shape in prose ("supersedes the previous `quorum-update` for the same quorum"); `QUORUM §6.2` validates `new_threshold` and **not** the shape, and `supersedes` is an optional caller-supplied hash. Off it the three implementations resolve differently from each other. Same standing as O6/O10: an unstated structural assumption a walk depends on | **OPEN** |
| O14 | **K-of-N signature unforgeability** for `QUORUM §4.1` — that `verify_k_of_n_signatures` cannot be satisfied without K distinct private keys | `tla/QuorumKofN.tla` — whether a peer's signature verifies is a per-peer boolean; nothing is forged, nothing is signed | Nobody. O5 one track over, and the same reason: **the quorum track has no prover model either.** `QUORUM §2` calls this validator "the only mechanism that distinguishes quorum from a regular peer node", and its adversarial property is discharged by nothing in this repo | **OPEN** |
| O15 | **Revocation and the clock, together** — that `ATTEST §4.3`'s revocation recursion does not interact with `not_before`/`expires_at`/`as_of` | Nowhere, and that is the row: `tla/AttestRevoke.tla` models revocation with the clock collapsed to one flag; `tla/QuorumSignerSet.tla` models the clock with revocation omitted. **No model covers both** | Nobody. Opened by noticing that `DescReadingsCoincide` — AttestRevoke's cohort green — is scoped to a model in which `not_before` does not exist, and O12 shows the two descendant readings separate precisely when it does. So the green is true and its scope is narrower than it reads. The composed model is the cheapest open item on either extension track | **OPEN** |
| O7 | **The reading of `ATTEST §5.7` I2 that the model encodes** | `tla/AttestIndex.tla` — `IndexAllOrNothing` is over the entity's ELIGIBLE index set, not over all four indexes | Nobody, and nothing could: this is a human reading of spec prose, which is the 5th wall itself rather than a seam between tools | **OPEN** |
| O16 | **`QUORUM §4.2 current_signer_set` returns the roster its own normative sentence asks for** — the input every K-of-N verdict in `IDENT §3.6` is taken against | `tla/IdentityCertChain.tla` — a CONSTANT (`SignerSetIsSound`), TRUE in the green sweep and FALSE in `IdentityCertChainSubstrateBug`, whose violation of `KofNAnswerIsTrustworthy` exhibits what identity's greens rest on | Nobody, and the assumption is known to be FALSE on the pinned text: this is the already-routed Q1, where §4.2 hands back the creation-time roster on a plain chain of three updates. **Held as a control rather than an identity finding on purpose** — re-routing Q1 wearing an identity section number would double-count it. The row exists so that the choice is visible in the gate table instead of invisible in a fidelity note, which is exactly what the prior checkpoint warned would otherwise happen | **OPEN** |
| O17 | **Identity's authority-logic predicates** — `identity_confers_function` and `identity_is_authorized_revoker` (`IDENT §3.6`) compute the authority they claim to | `tla/IdentityCertChain.tla` — neither is modeled; topology dispatch is what is under test and the predicates are assumed | Nobody, **and deliberately not the keystone sibling's Lean.** This was the track's first Class-L question and it was asked before a model reduced anything: keystone's Lean owns CAPABILITY-CHAIN attenuation, and `IDENT §2.2` / `§12.3` make identity attestations a structurally distinct validation class from capability tokens with "no shared validator". Routing these to that layer would be the conflation `IDENT §9.1` calls "the natural implementation mistake". So Class L does not grow and this stays unowned | **OPEN** |
| O18 | **That an arriving attestation reaches `IDENT §6.3 process_attestation` at all** — the premise under every finding on the identity track | `tla/IdentityProcess.tla` — the model begins at "an arrival that reaches `process_attestation`"; the hook that gets it there is read as prose and carries no sigil | Nobody, and the text is weaker than the models need. `IDENT §6.3` calls itself "the convergence point for any identity-context attestation entering the local tree at the named subtrees, regardless of source", but the sync hook that fires it is a **SHOULD** in `IDENT §10.2`, not a MUST. **Both branches lead to the same place**, which is why the findings survive the gap: with the hook installed, phase 1 rejects and phase 2a unbinds; without it, phase 2 never runs and the contacts cache is never seeded either way. Stated because a premise that holds by luck on both branches is still a premise | **OPEN** |
| O19 | **Identity attestation signature validity** — that a cert, handoff, recovery or retirement bound in the tree carries the signatures `IDENT §3.6`'s topology dispatch demands | `tla/IdentityCertChain.tla`, `tla/IdentityRecovery.tla` — topology is dispatched and the signatures it names are never checked; in `IdentityRecovery` a signer set is a generation number and "verifies" is equality | Nobody. **O5 and O14 a third time**: the identity track has no prover model either, so all three extension tracks now share one undischarged adversarial premise. Counted per track rather than merged, because merging it would hide that the gap grew | **OPEN** |
| O20 | **`QUORUM §4.2`'s update-chain order** — that a `quorum-update`'s `supersedes` pointer names an update that already exists, so the chain the resolver walks is ordered | `tla/QuorumSignerSet.tla` — was assumed, not checked: `Init` restricted `sup[x]` to lower indices UNCONDITIONALLY, with no constant and no control. **`tla/QuorumSignerSetApalache.tla` (2026-09-09) makes it the constant `SupOrdered` and lifts it**, with five green rows and two finding rows on the lifted cinit | Nobody — and the experiment says the row named an assumption STRONGER than §4.2 needs. **Four of the resolver's five checked properties are unaffected by the lifted order; one is not.** `CohortNeverSilentlyRevertsWhenAcyclic` is GREEN and `CohortNeverSilentlyReverts` unguarded is VIOLATED, so what the index order was standing in for is **acyclicity of the supersedes relation** — nothing more. On a two-node cycle §4.2 returns the roster frozen at `:create` while a `quorum-update` sits in the tree inside its validity window (**Q8**), because a node on a cycle is its own transitive descendant and §ATTEST:4.3 calls any attestation with a live descendant dead. §6.2 validates `new_threshold` and not the chain shape, §3.2 describes it only in prose, and `supersedes` is an optional caller-supplied hash — so **content addressing is the discharge and no sentence of either document states it**, exactly as at O6. This row is CLOSED in the same sense O6 is: measured, isolated, named, discharged by nobody. O13 is its sibling in the same module, one shape over, and is still OPEN | **CLOSED — ASSUMPTION ISOLATED** |

| O21 | **`IDENT §9.4`'s two cache keys are the same handle** — that the `published_handle` §5.1 writes the anchor under is the `old_handle` §9.4 reads it under | `tla/IdentityRecovery.tla` — the cache was ONE SLOT WITH NO KEY, and the header declared the abstraction ("`properties.old_handle` hex encoding and every other path construction"). **`tla/IdentityRecoveryApalache.tla` (2026-09-09) makes the cache a function over handles and makes rotation an action**, with two finding rows on the lifted domain and two greens on the candidate repair | Nobody, and the assumption is FALSE on the pinned text. A section 13.3 routine rotation moves `old_handle` and produces no `quorum-publish`, so the anchor stays at the pre-rotation key and §9.4 fail-closes on the identity's only compromise-recovery path (**N1**); §6.3's `update_handle_cache_to`, which could carry the entry across, is named in the dispatch table and defined in no section, and its two readings each satisfy one of two properties the spec states (**N2**). **The restriction was NOT in `Init`** — it was in the shape of a variable and the absence of an action, which is why D15's tenth-shape enumeration walked right past this module and recorded it as "not in the class". That is what promoted the candidate rule to **D18** | **CLOSED — ASSUMPTION FALSE** |
| O22 | **That `IDENT §6.3`'s dispatch is a function of ONE arrival** — that no property of the arrival path depends on what arrived before | `tla/IdentityProcess.tla` — three variables (`kind`, `src`, `hfail`) and no history; the model cannot represent a second arrival. **`tla/IdentityProcessApalache.tla` (2026-09-09) makes arrivals an unbounded sequence and gives phase 2's handlers and phase 2a's unbind state the NEXT arrival's phase 1 reads**, with 9 greens, 5 finding rows, 4 controls and 6 witnesses | Nobody, and the assumption is FALSE on the pinned text — twice, in the two directions the loop runs. §3.6 step 3 READS revocations out of the tree that phase 2a DELETED them from, so a cert the peer has been told to reject is admitted on every later arrival and section 6.4's convergence window — which that section explicitly bounds by sync latency — never closes (**N3**). And §6.3 phase 2 dispatches per `(kind, function)` consulting no state, so a re-arriving cert re-issues the local cap an `identity-retirement` removed (**N4**); §4.5 says nothing about liveness and §ATTEST:4.3's liveness is supersedes plus revocation, so phase 1 lets it back through. **N4 is violated under `ConstInitOK`, which on this track is the UNION of all three implementations' repairs** — no workaround in the cohort touches it. Both repairs for each finding are measured green rather than proposed. **The row's statement was RIGHT and its scope was too narrow**: it said "nothing accumulated across arrivals is in reach", which reads as a completeness gap; what the lift found is that the accumulation is where §3.6's own validator gets its INPUT | **CLOSED — ASSUMPTION FALSE** |
| O23 | **ENTITY RESOLUTION — that an entity used in an authority decision is the entity its address names.** §5.2/§5.5/§5.5a resolve the author, the capability, the chain root granter, each link's signer and each grantee **by key** out of `envelope.included`; `§1.8`/`§3.1` at 0.8.2.23 make verifying that key a `[MUST]` | **Nowhere, in any engine, on any track.** Every Tamarin/ProVerif theory takes capabilities and chain links as TERMS off `In(...)`, so *"resolve entity by address"* has no representation and there is no address to forge: `content_hash` occurs **0 times** across the 60 files in `tamarin/`, and in `tla/` only as an attestation tie-break key. §1.8 is cited by **0** model files; §3.1 by **0** core models | **Nobody, and this row exists because the abstraction was UNDECLARED, not because it is unowned.** Opened 2026-09-14 after `entity-core-protocol` 0.8.2.23 closed a **capability and identity forgery** exploiting exactly this indirection — an observer of any capability chain could mint a leaf off it up to the parent's scope, without the grantee's key. **The enabling obligation was in our pin** (`spec-data/v0.8.2` §3.1, *"The content_hash MUST match the map key"*, with no enforcing operation and no vector — D17's shape, never run on core). Every active-attacker result in `docs/PROPERTIES.md` is **conditional on this row**, and said so nowhere until now. Closing it is a modelling task, not a routing one: give the adversary the ADDRESS as well as the term, in `tamarin/Binding.{pv,spthy}` and `tamarin/ChainTopology.{pv,spthy}`, with a `*Bug` control that omits the binding check. **Until that runs, the honest statement is "outside our domain", NOT "we would have found it"** | **OPEN** |

| O24 | **PRE-ADMISSION REFUSAL — that a frame refused BEFORE it becomes an admitted request cannot cost an already-admitted request its response.** `0.8.2.25` §4.11's conformance arm, and it is the one arm the section says *"cannot be inferred from the others"*: *"a pre-admission refusal arriving while an admitted request is in flight on the same connection MUST NOT cost that request its response."* §4.9(c)'s deliver-or-signal rule is scoped to *"every request the peer admits"* and therefore reaches none of this class | **`tla/Reentry.tla`, `spin/reentry.pml` — and the gap is the model's SHAPE, not a constant.** There is no refusal path at all: the dispatch gate is `Gate(p) == TRUE` (disclosed in `docs/PROPERTIES.md`), every frame in the model is an admitted request, and the §6.11(a′) frame-write lock is the only contention modeled. **So the model cannot represent a frame that is refused, which is the precondition of the entire claim** — not a weakened property, an inexpressible one | **This repo, and nobody has started.** Opened 2026-09-15 on vendoring `v0.8.2.25`, **before** any modelling, because D18's question is *what legal state can this model not represent* and answering it after the fact is how O22 came to be mis-priced. ⚠ **The claim is not wire-decidable**: it quantifies over **interleavings** and its failure is a **LOST response**, which no finite probe distinguishes from a slow one — `entity-system-architecture` carries it as `KC-2` and records that it **has never been driven anywhere**, by any instrument in the ecosystem. That makes it the clearest case this repo has of a floor obligation only an engine here can reach, and it is `entity-system-conformance`'s `F-2`/`F-3` question in concrete form. **Blocked on nothing except the work**; the snapshot is vendored | **OPEN** |

O4 was found while writing L1: §5.10's cross-clock temporal model makes `δ` a declared
Layer-1 input alongside `t`, and the determinism argument is stated in terms of both.
`Revoke.tla` modeled `t` and not `δ` — so the module's determinism invariant was an
accidentally-true statement about a model that **could not express the case it was guarding**.

**Closed 2026-09-06, on all three engines.** `δ` is a per-peer declared tolerance; the
temporal check is the clause's two DENY rules negated (`expires_at + δ < t`, `t + δ <
not_before`); and `VerdictFnOfLayer1`'s antecedent now carries `delta["A"] = delta["B"]`,
because §5.10 puts it there. Apalache proves the strengthened invariant **inductive**, so this
is unbounded in steps rather than bounded-exhaustive. Three runs earn their place:

- **`RevokeDeltaBlindBug`** (negative control) — the pre-0.8.3 antecedent, blind to `δ`. The
  defect it names is a verifier that *applies* a tolerance without *declaring* it, which is
  the only condition §5.10 attaches to `δ` ("it introduces no concealed state"). Must be
  violated, and is.
- **`RevokeDeltaWitness`** (non-vacuity) — `δ` actually decides a verdict, all other Layer-1
  inputs equal. **Its first draft did not pin `revObserved`**, and TLC satisfied it with a
  state where the peers differed on *observed revocation* and `δ` differed only incidentally —
  a witness firing for a claim it does not support. Caught by reading the counterexample
  trace, not the exit status. A firing witness looks like success, which is what makes this
  failure mode worse than a control's.
- **`RevokeDeltaZero`** (green) — the clause states *"`δ = 0` reproduces today's exact
  behavior"*, so that equivalence is run rather than read. A sign error or a one-sided
  tolerance passes the default green (which expects a wider window) and fails here.


### O5–O8 — the attestation track's rows, and why two of them are worth more than the models that produced them

O5–O7 were added 2026-09-07 with `tla/AttestIndex.tla`, the attestation track's first module,
all three **OPEN** — the honest state for a one-module-old track, stated rather than softened.
`tla/AttestLive.tla` landed the same day and moved two of them: **O6 is CLOSED** (the
assumption is isolated, not discharged — read the row) and **O8 is new**, and O8 is not an
abstraction this repo relies on at all. It is the one row here that records the model
*refuting* the spec rather than depending on it.

`tla/AttestRevoke.tla` followed and added **O9** and **O10**, and O9 is a fourth kind again.
O5 is "nothing discharges this". O6 was "the assumption is unstated". O8 is "the algorithm is
wrong". **O9 is *there is no text*** — `is_self_revoked` is used in §4.3's normative pseudocode
and defined nowhere in the document, so fidelity is not achievable rather than merely unchecked,
and the model's contribution is to show that the choice is observable: the two natural readings
give `is_attestation_live` different answers about the same attestation. That is worth
distinguishing from O7, which is a reading of prose that EXISTS.

**How O9 was found is the transferable part.** `AttestLive` declared self-revocation abstracted
to a flag, in a D11 inventory-boundary note. Going back to close a declared abstraction — rather
than moving on to the next section — is what surfaced it. A declared boundary is a to-do list,
not an absolution, and this is the first time in this repo that reading one back has paid.

**O5 is the shape of the whole track's gap.** `AttestIndex` proves things about *index
bookkeeping* while treating the attestation itself as an opaque name that is simply bound. Every
security property of the substrate — that the `attesting` party actually signed, that a
revocation was authorized, that a K-of-N quorum attestation carries K real signatures — is
outside it, and unlike the core track there is **no prover model on this track to hand it to**.
Core's equivalent rows are BY-DESIGN because Tamarin/ProVerif own them; this one is OPEN
because nobody does.

**O6 was found by reading; it was CHANGED by running, and the change is the point.**
`ATTEST §5.1`'s `walk_attesting_chain` takes `max_depth: uint = 32` and returns null when it is
exceeded. Four sections later, `§5.2`'s `walk_supersedes_chain` is `while current.supersedes is
not null` and `§5.3`'s `find_live_head` is `while True` — **neither has a depth bound, a visited
set, or any other termination argument**. The reading-stage conclusion was "both rest on
acyclicity, which is unstated". `tla/AttestLive.tla` was written to check that, and it holds
for **one** of the two:

- **§5.2 does rest on it, exactly.** `BackWalkBoundedWhenAcyclic` is green over every graph on
  three nodes, cyclic ones included; `BackWalkBoundedAlways` is violated. So the assumption is
  not merely suspected, it is *isolated* — the walk terminates iff the relation is acyclic, and
  nothing weaker will do. That is what moves the row to CLOSED: not "we proved it terminates"
  but "we found precisely what its termination is, and named who owns that" (nobody here; it is
  the content-hash argument, which is O3's territory).
- **§5.3 does NOT rest on it, and the reading-stage conclusion was wrong about why.**
  `SpecWalkNeverExhausts` is green: the `while True` cannot iterate twice, because stepping to
  a live successor proves that successor has no live successor of its own. The loop is bounded
  by an accident of the predicate it filters on. **That is worse news than an unbounded loop,
  and it is what turned into O8** — the same filter that bounds the walk also stops it
  traversing, so §5.3 cannot reach a head three links away. A missing bound was the hypothesis;
  a wrong answer was the defect. Reading found the smell and got the mechanism backwards;
  only running it separated the two.

**O7 records that the model encodes a READING.** §5.7 I2 forbids "partial-index states (entity
in one index but not another)", and §5.7 I5 requires that a kind-less attestation appear in
*no* kind index. Taken literally, I2's parenthetical forbids the state I5 requires. The model
reads I2 as atomicity over the entity's **eligible** set and I5 as determining eligibility —
which is almost certainly what is meant, and is a reading nonetheless. If it is wrong, every
invariant in `AttestIndex` is measuring the wrong thing and **no gate in this repo would say
so**: this is the 5th wall, not a seam between tools, and the only thing that closes it is a
human reading the spec against the model or the spec being sharpened. Routed as a wording
question rather than a defect, because the intent is clear and only the sentence is loose.

---

## 4. What building this ledger found

Four things, none of which a per-tool report could have surfaced, and none of which the
prose division of labour showed.

### 4.1 Two engines, two *different* assumptions — and Lean's is the stronger one (L7)

> **This section was rewritten on 2026-08-30. The first version claimed the opposite and was
> wrong.** It is corrected in place rather than quietly amended, and the superseded claim is
> quoted below, because a ledger that silently rewrites its own findings is worth less than
> one that shows where it was mistaken. What it said: *"the two independent engines that both
> 'cover' §5.5a rest on the **same** unproved proposition, stated in two notations … route
> upstream a proposal to discharge `hframed` from `canonSegs` — the one change that would
> close L7 on both sides at once."* Neither the diagnosis nor the disposition survived a
> second reading.

`§5.5a` namespace isolation is covered by ProVerif/Tamarin (`ChainTopology`, `DeepChain*`)
*and* by Lean (`grantPattern_namespace_isolation`). Reading them together **properly**:

- **Lean** proves **framing ⇒ isolation**, taking framing as the hypothesis `hframed`.
  `hframed` is not merely underived — it is **false** for §5.5a's absolute form
  (`canonSegs "P" "/Q/*" = ["Q","*"]`, head `Q`), which §5.5a line 2729 makes the *required*
  form for cross-peer authority. So `hframed` scopes the theorem to the **peer-relative
  fragment**.
- **ProVerif/Tamarin** carry **three** canonicalization equations, not one
  (`DeepChain.pv:47-52`, `ChainTopology.pv:69-75`, `ChainTopology.spthy:70,91`):
  `canon(star, fr) = awild(fr)` · `canon(awild(p), fr) = awild(p)` · `canon(allp, fr) = allp`
  — the peer-relative, absolute-named and open-access forms respectively. **The second is the
  negation of `hframed` for absolute patterns.** The symbolic side does not assume framing
  universally; it models all three §5.5a forms.

**How the error was made, because the shape of it is the transferable part.** The first pass
quoted **one equation out of three** — the one that looked like `hframed` — and concluded a
shared assumption. The other two equations are four lines below it in the same file. A single
matching line is not a reading of the model; it is a grep result that agreed with a hypothesis
already formed.

**The real asymmetry, which is the finding that survives:** our symbolic models represent all
three §5.5a pattern forms; **Lean's isolation theorem covers one of them.** The absolute
named form — `/{q}/…` reaches exactly `q`'s namespace, frame-independently — is the half
§5.5a *mandates* for cross-peer authority, and it has no Lean theorem. That is a smaller and
more actionable gap than the one first reported, and it points the other way.

This still makes the ledger's original point, and makes it better: a coverage matrix counted
by *engine* cannot see this, and neither can a ledger counted by *assumption* if the
assumptions are read one line at a time. §5.5a has two engines, **three** pattern forms, and
theorem coverage on one of them.

**Disposition — closed 2026-09-06, and the asymmetry is gone.** Routed to
`entity-core-keystone` as three asks: (a) discharge the relative half from a syntactic
side-condition, (b) add the companion theorem for the absolute form, (c) correct the source
comment calling `hframed` "mechanical stdlib plumbing." **No ask on the ProVerif/Tamarin side;
there was never anything wrong with it.** Outcome (`8156792`):

- **(b) and (c) adopted, and (c) sharpened past what we asked.** §5.5a now has a theorem per
  pattern form — `grantPattern_namespace_isolation` (relative), `absolutePattern_names_one_peer`
  (absolute named), `wildcardPattern_peer_agnostic` (wildcard) — plus
  `canonSegs_absolute_frame_independent` for the frame-independence the second form rests on.
  **Three forms, three theorems, matching our three equations one for one.** The finding that
  survived the correction was the right one, and it is now closed rather than routed.
- **(a) declined, with a measurement that corrects us in turn.** We wrote above that the
  relative half is mechanical. It is not: the pinned mathlib-free toolchain has
  `String.splitOn`/`splitOnAux` and **zero theorems about either**, `splitOnAux` is
  `@[irreducible]` over raw byte positions, and `extract` cuts a `ByteArray` under a UTF-8
  validity proof. **We diagnosed their comment as wrong about scope and then reproduced its
  error about cost** — the same sentence, failing the same way, one clause over. §4.1 is
  therefore a section that has now been wrong twice about the same four words, in opposite
  directions, and the second time it was our own claim rather than theirs.

**What generalizes, and it is not "read three equations instead of one."** Both errors here
were *confident readings of a text nobody re-derived*. What broke the first was reading the
other two equations; what broke the second was keystone **running the environment query**
instead of estimating. The ledger's §5 disclaimer — that every row is a human reading — is not
boilerplate; this section is two instances of exactly the failure it warns about, and neither
was caught by a gate.

### 4.2 A correspondence that does not exist

`checkResourceScope_no_targets_deny` was previously listed as discharging `Authority.tla`'s
resource gate. It does not — it is about a resource present with no targets, a state
`Authority.tla` does not represent (see the note under L3). Nothing was weakened by the
mistake, because the model never relied on the theorem; but a ledger that lists a phantom
discharge is worse than one that lists none.

### 4.3 The invariant names in the earlier survey were not the invariants

That survey named `Revoke.InvDet`, `Authority.InvGrantless`, `Authority.InvResource`,
`Bounds`. The actual symbols are `VerdictFnOfLayer1`, `NoGrantlessAllow`,
`ResourceAuthorized`, and `Bounds.tla` has no invariant of that name at all (the §4.10(b)
one is the `capdepth` arm of `PresentDeeperChain`). Every row was written from recollection
rather than from the file — **D12**, in the one place the repo could least afford it, since
the whole point of the exercise was checking a correspondence.

### 4.4 The peer-relativity of the chain verdict (L1) and the missing `δ` (O4)

Both are model-scope statements that were simply absent, found by asking what the model
assumes rather than what it checks. Neither is a protocol finding.

**No protocol finding.** As with the last three audits, everything found is in the
verification.

---

## 5. The gate — `make leanseam`

**What it asserts.** For every Lean file this ledger pins: the file in a local
`entity-core-keystone` checkout is **byte-identical** to the text these correspondences were
derived from. For every theorem this ledger cites: that name still exists in the file it is
cited from, and still sits under a `#print axioms` gate there. And that the ledger's prose
citations and its machine-readable pin block name **exactly** the same set — neither may
drift from the other.

That last check has teeth, and it bit on its first run: it caught
`checkResourceScope_no_targets_deny` named in the prose (§4.2) as a correspondence that does
**not** hold, which the sync check could not distinguish from a real citation. The fix was
not to loosen the check but to make a rejected correspondence a **first-class pin** —
so "we considered this pairing and it discharges nothing" is now a recorded, checked claim
rather than an aside, and a rejection whose theorem later disappears goes stale visibly.

**What else satisfies it — the D13 question, answered honestly.** The digest check asserts
*the cited text has not changed*. It does **not** assert that the correspondence is correct;
that is a human reading, and it is the thing that must be re-done when a digest breaks. The
name and axiom-gate checks assert nothing the digest check does not already imply — they
exist to make a failure *diagnosable* (did the theorem vanish, or did the file merely move
around it?), and they are labelled as triage rather than as assertion. A green `leanseam` is
therefore exactly one claim: **nothing on the Lean side has moved under us.** It is not a
claim that the seam is closed. §1 is that claim, and a human wrote it.

**Why it is not in `make matrix`.** `make matrix` must run on a bare clone with nothing but
`make` and `podman`. `leanseam` requires a sibling checkout that a fresh clone does not
have. Folding it in would mean a target that silently skips when the sibling is absent —
the precise "gate that asserts nothing" failure the D13 audits exist to remove, and a skip
counts as a failure here. So it is a separate top-level target that **fails loudly** when
the sibling is missing, rather than a conditional one that passes quietly.

```
make leanseam                      # sibling at ../entity-core-keystone
make leanseam KEYSTONE=/path/to/entity-core-keystone
```

**When it goes red:** re-read the changed Lean text against the affected rows, update the
verdicts, then re-pin the digest. Re-pinning without re-reading defeats the whole file.

### Machine-readable pins

`tools/lean-seam.py` parses the block below. Every `theorem` line must have a prose row
above; every prose citation must have a line here.

> **RE-PINNED 2026-09-14, and this note is the re-read that licenses it.** `make leanseam`
> went red on `src/EntityCore/Capability.lean`; keystone's commit *"sentinel: fortran lean cobol
> unison apl"* landed the `0.8.2.20`/`.21` `NEVER_MATCH` work — `canonSegs` is now **total**
> (reserved `./`, `../` and `*/` prefixes return `neverMatch`), a `matchesSegNM` **wrapper**
> carries §5.4's *"never matches in either operand"* rule, `covered` calls the wrapper, and
> `matchesScope` gains `excludeUnmatchable`. **Re-pinning alone would defeat the ledger**, so
> every row citing this file was re-read against the new text before the digest moved:
>
> - **L1, L12, L13** — unaffected. The frame/absolute-pattern facts are about `canonSegs`'
>   absolute branch, which is byte-identical.
> - **L5, L6** — verdicts stand, **and the re-read produced a finding**. The sentinel rule was
>   implemented as a **wrapper** rather than as a first arm of `matchesSeg`, deliberately, to
>   preserve the T5a proof surface — and `scopeSubset` is the one call site that still calls
>   `matchesSeg` raw. Measured, not inferred: on `("../x", "/*")` the L1/L2 route answers
>   **false** and the L3/L4 route answers **true**. `scopeSubset` also still runs the id-scope
>   dimensions through the path matcher, which `0.8.2.22` now forbids in the imperative at
>   **both** matchers. Routed — `docs/status/ROUTING-2026-09-14-KEYSTONE-SCOPESUBSET-HALF-ADOPTED.md`.
> - **The `0.8.1 F40` typed matcher we routed as K1 is now IN this file** (`ScopeKind`,
>   `matchesIdPattern`, `coveredId`) with an attribution comment naming this repo. That half of
>   K1 is adopted; the `scopeSubset` half is not.

```leanseam-pins
file  proofs/EntityCoreProofs/CapabilityProofs.lean  78a157cdad043c4cab305636abd9aefe2a89cb8e98f6df456c07494aa567a1f8
file  src/EntityCore/Capability.lean                 dcba5d3442e32b64a289057c8d503502fedd83ad173ba892b1f6e3d6a52eccfc

theorem  verifyChain_time_stable          proofs/EntityCoreProofs/CapabilityProofs.lean  L1
theorem  verifyChain_time_independent     proofs/EntityCoreProofs/CapabilityProofs.lean  L1
theorem  verifyChain_foreign_root         proofs/EntityCoreProofs/CapabilityProofs.lean  L1,L9
theorem  checkPermission_no_grants_deny   proofs/EntityCoreProofs/CapabilityProofs.lean  L3
theorem  chainExceedsDepth_iff            proofs/EntityCoreProofs/CapabilityProofs.lean  L4
theorem  isAttenuated_trans               proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L10
theorem  grantSubset_trans                proofs/EntityCoreProofs/CapabilityProofs.lean  L5
theorem  scopeSubset_trans                proofs/EntityCoreProofs/CapabilityProofs.lean  L5
theorem  matchesSeg_trans                 proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L6
theorem  matchesSegNM_trans               proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L6
theorem  matchesSeg_refl                  proofs/EntityCoreProofs/CapabilityProofs.lean  L6
theorem  matchesScope_excl_override       proofs/EntityCoreProofs/CapabilityProofs.lean  L6
theorem  matchesScope_id_excl_override    proofs/EntityCoreProofs/CapabilityProofs.lean  L6
theorem  matchesIdPattern_literal         proofs/EntityCoreProofs/CapabilityProofs.lean  L6
theorem  grantPattern_namespace_isolation proofs/EntityCoreProofs/CapabilityProofs.lean  L7
theorem  absolutePattern_names_one_peer   proofs/EntityCoreProofs/CapabilityProofs.lean  L7
theorem  canonSegs_absolute_frame_independent proofs/EntityCoreProofs/CapabilityProofs.lean  L12
theorem  wildcardPattern_peer_agnostic    proofs/EntityCoreProofs/CapabilityProofs.lean  L13
theorem  multiSigRootOk_quorum            proofs/EntityCoreProofs/CapabilityProofs.lean  L8
theorem  walk_allow_cons                  proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  walk_allow_leaf_attenuated       proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  walk_allow_head                  proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  walk_allow_link_facts            proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  edgeOk_atten                     proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  edgeOk_caveats                   proofs/EntityCoreProofs/CapabilityProofs.lean  L11
theorem  allowed_chain_leaf_atten_root    proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L11

# A `rejected` pin is a correspondence that was CONSIDERED AND DOES NOT HOLD — a Lean
# theorem that discharges nothing here. Pinning it is deliberate: it is what lets the
# sync check tell a phantom citation from a real one, and it means re-proposing the
# pairing later runs into a written record rather than an absence. See §4.2.
rejected checkResourceScope_no_targets_deny proofs/EntityCoreProofs/CapabilityProofs.lean L3
```

---

## 6. What this ledger does not do

- **It does not close the 5th wall.** Spec↔model fidelity is still a human reading of the
  pinned snapshot against each model (`docs/ASSURANCE-MAP.md`). This file closes a
  *different* wall — model↔model — that was previously not even named.
- **It does not machine-check any correspondence.** Every verdict in §1 is a human's reading
  of two texts. The gate detects when one of those texts changes; it cannot tell you the
  reading was right. Differential trace checking — replaying Apalache `.itf.json`
  counterexamples through the Lean executable model and asserting the abstract predicate's
  value matches — is the first thing on this list that would put a machine on it, and it is
  on the work-list rather than done.
- **It does not cover bounds.** The peer bounds (2 everywhere, 2 and 3 for `Reentry`/`Core`),
  the TLC state-space limits and the
  bounded-liveness results are scope limits, not assumptions about an abstraction. They live
  in `docs/COVERAGE-MATRIX.md` and `docs/PROPERTIES.md`.
- **It is not a claim that the Lean proof is correct.** It is a claim about which Lean
  theorem *would* discharge each assumption. Lean's own honesty gates (`#print axioms`, no
  `sorry`) are that proof's business — but **whether anyone runs them is now ours**, and
  since 2026-08-30 `make leanproof` does: §7. What that adds is narrow and worth stating
  precisely. It establishes that each cited theorem is proved from Lean's three standard
  axioms and nothing else. It does not establish that the theorem *says* what the row above
  claims it says, and no gate in either repo does.

---

## 7. The second gate — `make leanproof`, and the build nobody ran

§5's gate detects that the cited Lean **text** moved. This one checks that the text still
**proves what it claims**. It was added on 2026-08-30, after the obvious question — *who
runs the proofs?* — turned out to have the answer *nobody*.

### 7.1 What the search found

`lake build EntityCoreProofs` is described as the proof check in **five** places in the
keystone peer:

- `protocol-generator/lean/lakefile.lean`, on the `EntityCoreProofs` target: *"the build IS
  the proof check (a `sorry` or failed proof fails the build)"*;
- `proofs/EntityCoreProofs.lean`, the library root, in the same words;
- `protocol-generator/lean/profile.toml`, in the peer's `[testing]` contract: *"Track B
  proofs are their own gate … `#print axioms` guards against accidental sorry"* — which names
  exactly the right mechanism, and is the site worth reading twice: the gate it points at is
  real and nothing reads its output;
- `status/PHASE-S2.md` and `status/PHASE-S3.md`, which report the track as green on it.

It is invoked by **no Makefile, script, or CI workflow in that repository** — searched
exhaustively over the tree on 2026-08-30 (`EntityCoreProofs`, `lake build`, `lake env`,
`elan` across every Makefile, `*.mk`, `*.sh`, `*.yml`, `*.py` and Containerfile; the only
`lake build` invocation anywhere is `run-s4.sh`'s `lake build host`, the peer binary).
Keystone's Lean container image exists and is pinned; nothing points it at the proofs.

**Ten rows of §1 cite a Lean theorem by name** and rest on those proofs — Class L is eleven
rows, nine CLOSED and two CLOSED-MODULO-H, with L2 closed by construction (Lean's
termination checker) and therefore the one row with no theorem to run. *(An earlier draft of
this section, and of four other files, said "eleven CLOSED rows". Nine are CLOSED; the count
that matters for this gate is the ten that name a theorem. Corrected in the session audit —
a gate justified by a miscounted number is the shape D15 exists for, even when the
conclusion survives.)* They were checked when they were written
and by nothing since — including through the `hframed` re-reading in §4.1, which changed
what this ledger claims about them.

### 7.2 The claim in the lakefile is false, and that is the interesting part

*"A `sorry` or failed proof fails the build."* Half of that is true. Each case was **built**
rather than reasoned about (the D15 corollary — teeth-test a gate, do not argue about it):

| injected into a cited theorem | `lake build EntityCoreProofs` |
|---|---|
| a `sorry` | **exit 0**, prints `Build completed successfully`; one `warning: declaration uses 'sorry'` |
| an `axiom` standing in for the proof | **exit 0**, `Build completed successfully`, **no warning at all** |
| a proof that does not type-check | exit 1, `error: build failed` |

**A `sorry` is a warning in Lean, not an error.** So a gate on `lake build`'s exit status —
had one existed — would have caught one failure mode in three, and missed precisely the two
a proof check exists to catch. This is D13 in a new medium: not a grader in this repo, but
*a grader claimed by a sibling repo and never wired up*, whose claim does not hold even if
it had been.

A third observation, from the same runs: the `sorry` propagated **two hops** —
`matchesSeg_refl` → `EntityCore.Capability.Proofs.isAttenuated_refl` →
`EntityCore.Capability.Proofs.allowed_chain_leaf_atten_root` — so three declarations reported
`sorryAx`, not one. The axiom check therefore catches transitive contamination, which a
per-theorem review of the edited file would not.

*(Those two are written fully qualified on purpose. They are not ledger citations — no row
relies on them — and §5's sync check correctly rejects a bare backticked theorem name that
is neither pinned nor rejected. It caught this paragraph on its first run, which is the
check doing its job on the document that describes it.)*

### 7.3 What `make leanproof` asserts

The assertion is made against the **axiom sets**, because that is the only place the two
invisible failures show up. `lean/proof-gate.expect` declares all **37** `#print axioms`
gates in the peer's proof track with the axiom set each must report, and the run must
produce exactly that set — no more, no less, both directions:

1. **Toolchain** — the Lean version the image resolves equals keystone's own
   `lean-toolchain` pin. Proving with a different compiler than the peer ships is not
   proving the peer.
2. **Build** — exit 0, no `error:` line, and the positive completion line present.
3. **Axiom sets** — every gated declaration reports a subset of Lean's three standard
   axioms (`propext`, `Classical.choice`, `Quot.sound`) *and* exactly its declared set. A
   row of `proof-gate.expect` may not declare an untrusted axiom: the file is rejected at
   parse time if it does, because a hole you can declare away is not a hole that was caught.
4. **The ledger tie** — all 27 theorems pinned in §5's block (26 discharging + the one
   pinned as **rejected**) are among the declarations that reported. This is what makes the
   gate about *this ledger* rather than about "some proofs built".
5. **Warnings** — a Lean warning fails the build unless declared with an owner. One is
   declared, 2026-09-15: Lean's linter reporting an unused `simp` argument inside
   `matchesSegNM_trans`, new at keystone's `fee2e422`, in the proofs file this ledger pins.
   Not a hole — that declaration's axiom set is graded standard on its own row — and not ours
   to fix, since the keystone Lean tree is read-only input here. **Routed** rather than
   tolerated, with the row's own retirement condition written into it, and declared in **both**
   `lean/proof-gate.expect` and `lean/lemma-gate.expect` because the lemma tier builds our
   files inside a copy of their tree and sees the same warning.
   *(A previous row here was a deprecated `String.dropRight` call in the same file; keystone
   landed the fix on 2026-09-06 and the row was deleted, which is the pattern this one follows.)*

Five negative controls, each required to fail for its **own** declared reason, **on the
declarations it names**:

| control | injects | must produce |
|---|---|---|
| `neg-sorry` | `sorry` in `matchesSeg_refl` (row L6) | `SORRY_WARNING`×1, `SORRY_AX`×3 |
| `neg-axiom` | an `axiom` replacing that proof | `UNTRUSTED_AXIOM`×3 |
| `neg-ungate` | deletes the `#print axioms` line | `MISSING_GATE` + `LEDGER_UNCOVERED`, both naming `matchesSeg_refl` |
| `neg-dropfile` | drops `import EntityCoreProofs.SortProofs` from the library root | `MISSING_GATE` naming all three `SortProofs` declarations — and **no** `LEDGER_UNCOVERED`, since no ledger row cites them |
| `neg-broken` | a proof that does not type-check | `BUILD_ERROR` pinned to the file **and** `Type mismatch`, + `NO_COMPLETION` |

`neg-ungate` is the one worth pausing on: it is the move that would silence a grader built
on `grep -c sorryAx` over the build log — no gate line, no `sorryAx` to find, green. It
fails here because the *names* are declared, which is the same rule the prover tables carry.
And the two `×3` counts above were **declared as 2 and measured as 3** on the first run;
they are in the table because a count that is asserted is a count that cannot drift.

The green gate was itself teeth-tested three ways, by breaking it: removing the declared
warning row (→ `UNDECLARED_WARNING`, red), declaring `sorryAx` for a theorem (→ the expect
file is rejected at parse), and pointing it at a tree whose `lean-toolchain` names a
different Lean (→ toolchain mismatch, red).

### 7.4 The boundary, stated as sharply as the rows are

`make leanproof` green means: **the Lean side is sound** — the cited theorems are proved,
from Lean's standard axioms, by the compiler the peer pins, with no `sorry` and no added
axiom anywhere in the track. It does **not** mean the seam is closed. §1's verdicts are a
human's reading of two texts in two languages, and that reading is exactly what was found
wrong in §4.1. Nothing here checks it. **Differential trace checking** — replaying Apalache
`.itf.json` counterexamples through the Lean executable model — is still the only proposal
on the table that would put a machine on that half, and it is still on the work-list rather
than done.

Six runs (1 green + 5 controls), not counted in `make matrix`'s 258 for the reason §5
gives: they need a sibling checkout, and every published number here has to be reproducible
from a bare clone.
