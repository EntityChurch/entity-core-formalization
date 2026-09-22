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
| `protocol-generator/lean/proofs/EntityCoreProofs/CapabilityProofs.lean` | `715687f4505e0e7639b47fd34977375b6bf3a652bf5458d9231d507d0f64d029` |
| `protocol-generator/lean/src/EntityCore/Capability.lean` | `c16a2f7c6c3e4351d974d8de57a476a577add9a5f098d788767c80169b6a1a93` |

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
  `matchesSeg_trans` — all in `CapabilityProofs.lean`, no residual hypotheses beyond the two
  premises, and the expiry conjunct (a finite parent forbids an infinite child) proved
  inline in `isAttenuated_trans`.
- **Verdict: CLOSED.** This is the strongest single link in the whole assurance map, and
  worth stating in exactly this shape: *the Tamarin result is conditional, and Lean is what
  discharges the condition.*

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
- **Verdict: CLOSED.**

### L11 · The verdict actually enforces the per-edge check

- **Model site:** implicit in every model that treats an `allow` as evidence the chain was
  walked — `Gate`/`Honored` (L2), and the acceptance events in every Tamarin theory.
- **Assumed:** an `allow` verdict cannot be reached while skipping a link's attenuation
  check. L5's transitivity is worthless if the walk can decline to apply it per edge.
- **Discharged:** `walk_allow_cons` and `walk_allow_leaf_attenuated` —
  `CapabilityProofs.lean` — extracting `edgeOk` (and hence `isAttenuated`) from an allowing
  walk, plus `walk_allow_head`, `walk_allow_link_facts`, `edgeOk_atten`, `edgeOk_caveats`.
- **Verdict: CLOSED.** Cited explicitly because it is the row a reader forgets: L5 proves
  the step composes, L11 proves the step is taken.

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
| T4 | `tla/Core.tla`, `spin/core.pml` — `Honored` = the composed verdict | The composed verdict is the conjunction the component modules check separately | **nothing** — the composition is asserted, not proved. `Core` and the per-subsystem modules are checked independently; no refinement proof links them | **OPEN** |
| T5 | `tla/Authority.tla` — `Covers` two-point scope, deliberately **disjoint** | Nothing about the protocol. Disjointness is a modelling device that makes consulting the wrong authority observable | — | **N/A — device** |

**T4 is the one that matters** and it is already on the work-list as the refinement-proof
item (`docs/STATUS.md` §Next). It is recorded here because "the composed model is checked
and the components are checked" reads, wrongly, as "the composition is verified."

---

## 3. Class O — declared unowned

No tool in this repo, and no Lean theorem, reaches these. Each names who would.

| # | Abstraction | Model sites | Owner, if anyone | Verdict |
|---|---|---|---|---|
| O1 | CBOR decoding — the hostile byte space | `tamarin/Malformed.{pv,spthy}` (`tbad` is an opaque constant, not a decode) | Conformance suite + fuzzing; `entity-core-keystone` type-system work | **BY-DESIGN** |
| O2 | Entity content, hashing, content-addressing | `tla/Emit.tla`, `spin/emit.pml` — opaque hash tokens | Type system + conformance vectors | **BY-DESIGN** |
| O3 | Computational crypto (§7.3) | every Tamarin/ProVerif theory — symbolic `sign`/`verify` | Nobody. A computational-model result would need CryptoVerif; `docs/STATUS.md` §Next | **BY-DESIGN** |
| O4 | Wall-clock skew tolerance `δ` (§5.10, W7 Knob 3) | ~~unmodeled~~ — **now modeled** in `tla/Revoke.tla`, `tla/RevokeApalache.tla` and `spin/revoke.pml` | this repo | **CLOSED** (2026-09-06) |

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

```leanseam-pins
file  proofs/EntityCoreProofs/CapabilityProofs.lean  3a123b2a746f11dd37e39550d8e81b2389dbce6adf9aed31c20cd6236ec12ab4
file  src/EntityCore/Capability.lean                 c99d1067ca08a44cd9c22c67d6517d38932c3be161443b5fc74f5e957ab4672a

theorem  verifyChain_time_stable          proofs/EntityCoreProofs/CapabilityProofs.lean  L1
theorem  verifyChain_time_independent     proofs/EntityCoreProofs/CapabilityProofs.lean  L1
theorem  verifyChain_foreign_root         proofs/EntityCoreProofs/CapabilityProofs.lean  L1,L9
theorem  checkPermission_no_grants_deny   proofs/EntityCoreProofs/CapabilityProofs.lean  L3
theorem  chainExceedsDepth_iff            proofs/EntityCoreProofs/CapabilityProofs.lean  L4
theorem  isAttenuated_trans               proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L10
theorem  grantSubset_trans                proofs/EntityCoreProofs/CapabilityProofs.lean  L5
theorem  scopeSubset_trans                proofs/EntityCoreProofs/CapabilityProofs.lean  L5
theorem  matchesSeg_trans                 proofs/EntityCoreProofs/CapabilityProofs.lean  L5,L6
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
- **It does not cover bounds.** `Peers = {A,B}`, the TLC state-space limits and the
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
4. **The ledger tie** — all 25 theorems pinned in §5's block (24 discharging + the one
   pinned as **rejected**) are among the declarations that reported. This is what makes the
   gate about *this ledger* rather than about "some proofs built".
5. **Warnings** — a Lean warning fails the build unless declared with an owner. One is
   declared: a deprecated `String.dropRight` call in the shipping peer's
   `src/EntityCore/Capability.lean` — inside the text this ledger pins by digest — whose
   replacement returns a different type. Not ours to fix; **routed** to keystone rather than
   tolerated, and the row disappears when they land it.

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
