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
- **H (peer half):** *both peers evaluate within the root granter's frame.*
  `verifyChain` takes `localPeer` as an argument, and the §5.5a granter-frame
  canonicalization threads it through `walk → edgeOk → isAttenuated → grantSubset`. The
  verdict is therefore **not** peer-independent in general — `verifyChain_foreign_root`
  proves the extreme case, where a non-local single-sig root denies outright. Holding
  `ChainValid` equal at A and B is sound only for chains where the two peers' frames agree.
  `Revoke.tla` does not state this restriction, and §5.10's determinism MUST is scoped to
  "cross-peer-relevant chains", which is exactly the class where it needs saying.
- **Verdict: CLOSED-MODULO-H.** → work-item, `docs/STATUS.md` §Next.

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
  the security logic (framing ⇒ isolation) and explicitly declines to prove `hframed` itself
  from `canonSegs`' string operations, calling it mechanical stdlib plumbing.
- **Verdict: CLOSED-MODULO-H — and this is the finding.** See §4.1: the ProVerif/Tamarin
  side does not independently establish `hframed` either. It *assumes the same thing by
  equation* — `canon(star, fr) = awild(fr)` is `hframed`, written as a rewrite rule. Two
  engines, one shared undischarged assumption.

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
| O4 | Wall-clock skew tolerance `δ` (§5.10, W7 Knob 3) | unmodeled — `tla/Revoke.tla` models `t` but not `δ` | Nobody yet | **OPEN** |

O4 was found while writing L1 and is new: §5.10's cross-clock temporal model makes `δ` a
declared Layer-1 input alongside `t`, and the determinism argument is stated in terms of
both. `Revoke.tla` models `t` and not `δ`. Two peers with different declared `δ` may
permissibly differ, exactly as with different `t` — so the shape is already in the model and
the extension is small. Recorded, not fixed.

---

## 4. What building this ledger found

Four things, none of which a per-tool report could have surfaced, and none of which the
prose division of labour showed.

### 4.1 Two engines, one shared undischarged assumption (L7)

`§5.5a` namespace isolation is covered by ProVerif/Tamarin (`ChainTopology`, `DeepChain*`)
*and* by Lean (`grantPattern_namespace_isolation`). Reading them together:

- Lean proves **framing ⇒ isolation**, taking framing as the hypothesis `hframed`, and says
  in the source that it declines to prove `hframed` from `canonSegs`' string operations.
- ProVerif encodes framing as the **rewrite rule** `canon(star, fr) = awild(fr)` — which is
  `hframed`, asserted rather than derived.

So the two independent engines that both "cover" §5.5a rest on the **same** unproved
proposition, stated in two notations. The redundancy is real for everything else in that
section and worth nothing for this particular step.

This is the specific reason a coverage matrix counted by *engine* cannot substitute for a
ledger counted by *assumption*. The audit that "closed every single-tool coverage gap" was
right about engines and could not have seen this: §5.5a has two engines and one assumption.

**Disposition:** route upstream to `entity-core-keystone` as a proposal to discharge
`hframed` from `canonSegs` — the one change that would close L7 on both sides at once. Not
a defect in either artifact; both disclose what they assume, and neither could see the other.

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
make leanseam                      # sibling at ../../entity-core-keystone
make leanseam KEYSTONE=/path/to/entity-core-keystone
```

**When it goes red:** re-read the changed Lean text against the affected rows, update the
verdicts, then re-pin the digest. Re-pinning without re-reading defeats the whole file.

### Machine-readable pins

`tools/lean-seam.py` parses the block below. Every `theorem` line must have a prose row
above; every prose citation must have a line here.

```leanseam-pins
file  proofs/EntityCoreProofs/CapabilityProofs.lean  715687f4505e0e7639b47fd34977375b6bf3a652bf5458d9231d507d0f64d029
file  src/EntityCore/Capability.lean                 c16a2f7c6c3e4351d974d8de57a476a577add9a5f098d788767c80169b6a1a93

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
  `sorry`) are that proof's business, and the keystone peer's report is where they are
  stated.
