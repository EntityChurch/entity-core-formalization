# Coverage matrix — what is verified, by which tool, and how far it reaches

**entity-core-formalization · pinned at `spec-data/v0.8.2/`**

This document answers one question in a form you can check: **for each part of the Entity
Core Protocol, what has been formally verified, by which tool, and what are the limits of
that result?**

It exists because the obvious objection to a formal-methods repo is the right one:

> *"You formalized the protocol. Who formalizes the formalization?"*

The answer here is **the other tools do** — four engines in two families, each able to
falsify the others' results, with every module checked by at least two. That answer is only
worth anything if the redundancy is real and the gaps are named, so both are below.

---

## 1. The four engines — what each one actually is

You do not need to know these tools to read the matrix; you do need to know what question
each one answers, because **the tools are not interchangeable and none of them subsumes
another.**

| Engine | Family | The question it answers | How it works | What it CANNOT do |
|---|---|---|---|---|
| **TLC** | model checker (explicit-state) | *Does any interleaving of concurrent activities break this property, at a small fixed size?* | Enumerates **every reachable state** of the model at a bound (2 peers — 2 and 3 for `Reentry`/`Core` — 3–4 requests) and checks each one. | Say anything beyond the bound. A defect needing 4 peers, or 3 on a non-ring topology, is invisible. |
| **Apalache** | model checker (symbolic, SMT/Z3) | *Does the property hold in **every** reachable state, for runs of **any** length?* | Proves it **inductive**: `Init ⇒ Inv` and `Inv ∧ Next ⇒ Inv'`. If both discharge, no counterexample can exist. | **Liveness.** It does safety and induction by construction. Deadlock-freedom is not expressible. |
| **Spin** | model checker (explicit-state, different formalism) | *Does an **independently written** model of the same design agree?* | Promela processes + C verifier. Models here are written **from the spec**, not translated from the TLA+. | Same bound limitation as TLC. Its value is independence, not reach. |
| **ProVerif** | protocol verifier (symbolic, Dolev–Yao) | *Can an **active network attacker** with unbounded sessions produce a forgery/escalation/replay?* | Resolution over Horn clauses; unbounded sessions, attacker controls the network. | Crypto is **perfect and symbolic**. No bit-level cryptanalysis. Concurrency/liveness out of scope. |
| **Tamarin** | protocol verifier (symbolic, Dolev–Yao) | Same question, **different proof engine** | Multiset-rewriting + constraint solving; backward search. | Same crypto boundary. Some theories do not terminate (see §6). |

### Why more than one, concretely

Redundancy is only worth its cost if the tools can actually catch each other. During the
0.8.2 work they did, three times, and these are the specific reasons the matrix is built the
way it is:

1. **Apalache caught a defect TLC could not.** `Reentry`'s client released the connection
   write lock unconditionally on receiving a response — including when the lock was held by
   that peer's **own server, mid-frame**. A writer releasing a lock it does not hold. TLC
   found nothing, correctly: at the 2-peer bound no third writer exists to exploit the
   stolen lock, so it has no observable consequence. Apalache's inductive step starts from
   *arbitrary* states rather than reachable ones and found it immediately. Fixed in
   `Reentry.tla`, `Core.tla` and `reentry.pml`.
2. **ProVerif and Tamarin disagreed, and the disagreement was the signal.** A hand-written
   Tamarin lemma for §5.8 quantified over a variable never bound to the verifier it named,
   so it asserted far less than it appeared to. ProVerif's equivalent lemma behaved
   differently on the same negative control. Fixed; both then agreed exactly.
3. **A negative control that could not fail.** The Spin `-DNOESTABGATE` control compiled out
   the establishment gate *and* the assertion that detects its absence — reporting
   `errors: 0`, indistinguishable from a pass. Caught only because a control that does not
   fail is itself a failure signal.
4. **Tamarin said the results might be wrong, and the gate said green.** Tamarin exits 0 when
   every lemma verifies even if its own wellformedness checks failed, printing `WARNING: N
   wellformedness check failed! The analysis results might be wrong!` on the way out. Four
   green theories were shipping that warning unread. Two were substantive: `DeepChainN` had a
   **free variable in a rule conclusion** — the delegatee was never bound by any premise, so
   the backward search could instantiate it at will — and `Malformed` used the name `Repr` at
   two different arities, colliding an action label with the fact that carries its entire
   §5.6 representability encoding. A wellformedness failure is now a build failure.

5. **The gate itself could not tell a verified run from one that verified nothing.** After
   the pass that fixed (3) and (4), a sweep of *every* grading target — asking of each "what
   does this assert, and what else satisfies it?" — found **62 of the 203 runs** still graded
   by a criterion blind to the outcome claimed. `proverif-green` graded on ProVerif's exit
   status, and **ProVerif exits 0 with a false query**; `proverif-neg` required "some result
   is false", which is also what a *reachable* non-vacuity query reports, so the secure
   theory satisfied its own control's criterion; `apalache-neg` and `tlc-witness` graded on
   exit status with output discarded, so a config error (`255` / `151`) scored as a caught
   defect. Both provers now grade against declared per-query and per-lemma verdict tables.

None of these were protocol defects. All five were defects **in the verification**, which
is exactly what the question at the top of this page is about. Four of the five are the same
shape — *a green that means less than it appears* — which is why the gate now checks not only
that each control fails, but that it fails **for the reason it exists to demonstrate** (see
§6).

---

## 2. The three strengths of result

Every row in the matrix carries one of these. They are not interchangeable and the
difference is the whole point.

| Strength | Means | Produced by |
|---|---|---|
| **PROVEN (unbounded)** | Holds in every reachable state, for runs of any length. Not "no counterexample found" — *no counterexample can exist*. | Apalache (inductive) |
| **MODELED (bounded-exhaustive)** | Every behaviour enumerated, but only at a tight finite bound. Sound within it; silent beyond it. | TLC, Spin |
| **MODELED (symbolic, Dolev–Yao)** | Holds against an unbounded active attacker, over **perfect** symbolic crypto. | ProVerif, Tamarin |

---

## 3. Matrix A — protocol section × property class × engine

### Which protocol this matrix is about

**4 proof tracks** are declared in `TRACKS.toml` — **4 modeled**, **0 scoped** — and
**Matrix A is the `core` track's matrix and only that.** The `attestation`, `quorum` and
`identity` tracks have their own grids and their own denominators in **§3c**, **§3d** and **§3e**
below. A modeled track with no grid section fails `make trackcheck`, which is how a track cannot
quietly acquire coverage nobody published — and with `identity` promoted there is no `scoped`
track left, so that half of the gate now has no subject in this registry.

This distinction is load-bearing rather than tidy. The grid below is derived from a
**document-blind** citation pattern: `EXTENSION-ATTESTATION §5.7` (the attestation index
invariants) and core `§5.7` (delegation caveats) produce the identical token, and row `5.7`
already exists. Absent a track dimension, the first extension model's citations would be
credited to *this* matrix and `make coverage` would report OK — §3b's failure again, one spec
body over, and arriving through the gate rather than past it. So citations are extracted
**per track**, and a bare `§N.M` in a model means a section of *its own* track's spec. A
cross-track claim carries the target's prefix (`§CORE:6.2` inside an attestation model);
`TRACKS.toml` §"The citation convention" is the whole rule.

### The matrix

Derived from the `§`-citations the `core` models themselves carry, not from prose. Reproduce
with `make specdrift` (which reads the same citations) or by grepping `§` in the files
`TRACKS.toml` assigns to `core`.

**Coverage: 27 of 91 numbered `§N.M` sections (30%).** Read by area, not as one number —
see §5 for why the zeros are zeros. **This is a statement about the `core` track**; there is
no repo-wide coverage number and there deliberately will not be one, because averaging a
verified protocol with three unmodeled ones produces a figure that is true of nothing.

| § | Topic | Property class verified | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| 1.7 | peer identity | identity binding under attacker | | | | ● | ● |
| 3.3 | wire frame | frame structure (as (a′) subject) | ● | | | | |
| 3.6 | multi-granter threshold | K-of-N cannot be bypassed | | | | ● | ● |
| 4.1 | connection establishment | handshake ordering | ● | ● | ● | | |
| 4.2 | pre-auth gate | no dispatch pre-establishment | ● | ● | ● | | |
| 4.6 | nonce handshake | no establish without issued nonce | ● | ● | ● | | |
| **4.8** | **store safety + refcount** | **data race; use-after-free** | ● | ● | ● | | |
| 4.9 | resilience under load | responsive; deliver-or-signal; recover | ● | ● | ● | | |
| 4.10 | resource bounds / admission | clean reject; bounded in-flight; chain depth | ● | ● | ● | | |
| 5.1 | revocation | revoked never passes | ● | ● | ● | ● | ● |
| **5.2** | **verification + dispatch authority** | **three-valued authority; resource binding** | ● | ● | ● | ● | ● |
| 5.4 | pattern matching | **abstracted — cited only as a declared boundary (§3a)** | | | | | |
| 5.5 | chain verification | linkage; unforgeability; caveats | ● | | ● | ● | ● |
| **5.6** | **attenuation + temporal ingest** | **expiry; malformed-field fail-open** | ● | | ● | ● | ● |
| 5.7 | delegation caveats | caveat enforcement | ● | | | ● | ● |
| **5.8** | **chain inclusion + topology** | **cross-peer provenance at a 3rd-party verifier** | | | | ● | ● |
| **5.9** | **bounds propagation** | **depth brake before TTL; single decrement** | ● | ● | ● | | |
| 5.10 | verdict determinism | Layer-1 determinism; propagation bound | ● | ● | ● | ● | ● |
| 6.1 | handler registration | atomicity; index↔tree coherence | ● | ● | ● | | |
| 6.2 | system handlers | system-namespace guard | ● | ● | ● | ● | ● |
| 6.5 | dispatch chain | no handler entry pre-gate | ● | ● | ● | | |
| 6.6 | handler resolution | longest-prefix dispatch | ● | | ● | | |
| 6.8 | handler grant | confused deputy; persistent re-check | ● | ● | ● | ● | ● |
| **6.9** | **bootstrap** | **pre-loaded handler safety; registration precondition** | ● | ● | ● | | |
| 6.10 | event emission | event iff real work; correct type | ● | ● | ● | | |
| **6.11** | **transport reentry** | **Class-G deadlock; frame-write atomicity** | ● | ● | ● | | |
| 7.3 | signatures | signature verification (as crypto wall) | | | | ● | ● |

**Bold** rows are the surface added or sharpened at 0.8.1/0.8.2.


### 3a. One row is single-engine, one is ZERO-engine — and two others were never covered at all

The "every module is checked by all three engines of its family" claim in §1 and §4 is about
**modules**, and it holds. At **section** granularity one row still rests on one engine:

| § | Only engine | What that means |
|---|---|---|
| 3.3 | TLC (`Reentry.tla`) | §3.3 is not modeled *as* a wire-frame property. It appears only as the **subject** of §6.11(a′) — "these bytes are what must not interleave". The frame's own structure is the CBOR spec's and the conformance vectors', per §5(a). Not a gap in this repo's surface; a row that looks thinner than the claim behind it. |

**And one row now carries no engine at all — §5.4, corrected 2026-09-12.** It read
`| 5.4 | pattern matching | no escalation via attenuation | | | | ● | ● |`, crediting ProVerif
and Tamarin. **All nine model files citing §5.4 cite it as an abstraction boundary**, in those
words — *"the §5.4 path matcher stays abstract (the Canon/Cov fact tables)"* (`ChainTopology.*`),
*"The §5.4 path-segment matcher is Lean's / abstracted; we model the FRAME … the §5.5a
load-bearing bit"* (`DeepChain*`), *"The §5.4 pattern-match arithmetic … is Lean's / abstracted
here (verdict-interior wall); we model the order RELATION … (§5.6 `is_attenuated`)"*
(`NoEscalation*`). Checked at the source, not from the comments: `NoEscalation.pv` gives `scope` a
two-point abstract order (`fun narrow(scope)`) with no path structure; `DeepChain.pv` declares
`fun canon(bitstring, pkey)` with three frame-resolution equations and an opaque `covok`.

Two things were wrong, not one. The **engines** were credited for a section every citing file
declares out of scope — and the **property class** named was *"no escalation via attenuation"*,
which is **§5.6's order relation**, already credited to the same two engines by §5.6's own row one
line below. So the grid counted one property twice and attributed half of it to the wrong section.

**This is the §4.7 / §6.9 phantom shape** — the pair of rows D15 was written about — arriving in
the one dimension `make coverage` says in its own output it does *not* assert: *"the engine
columns are still hand-maintained — a citation says a model is ABOUT a section, not which engine
verifies what."* The disclaimers were accurate and explicit for the life of the grid; nothing read
them. **The numerator does not move and the row is not deleted:** `make coverage` asserts the
cited set equals the grid rows in *both* directions, so while nine files cite §5.4 the row must
exist. What was wrong is exactly the hand-maintained part. Found while classifying §5.4's
0.8.2.20 movement (`docs/SPEC-DRIFT-ASSESSMENT.md` §1b) — i.e. **by the drift gate firing on a
sibling's commit**, which is not a mechanism anyone designed to catch this.

*Contrast §7.3, which keeps its two dots and is honest: its property class says **"(as crypto
wall)"** — the abstraction is in the label, and signatures are genuinely carried as an opaque
primitive the theories reason with. The distinction worth keeping is not "abstract or not" but
**whether the row's stated property is the one the engines actually establish.***

**§4.7 and §6.9 used to sit in that table, described as "real single-tool results". They were
not single-tool results. They were not results.** Both rows came from a `§`-mention that was
never a claim of coverage:

- **§4.7** — the sole §4.7 citation in the entire repo was the *range endpoint* of
  `§4.1-§4.7` in a header comment in `ConnApalache.tla`. Five other files write the same
  range as `§4.1–4.7` (no second `§`), which the extractor reads as citing only §4.1. The row
  showed "Apalache-only" because of one file's punctuation. Nothing modeled §4.7, and §4.7 is
  not "connection teardown" — the label was wrong too. It is the **connection error-code
  table**.
- **§6.9** — both §6.9 citations were **disclaimers** in `Register.tla`'s header: *"Bootstrap
  handlers (§6.9) bypass registration and are not modeled"* and *"System bootstrap handlers
  bypass registration (§6.9)"*. An out-of-scope declaration was counted as coverage.

Both are now genuinely modeled, by all three engines, in modules of their own —
`ConnCodes` / `conncodes.pml` and `Bootstrap` / `bootstrap.pml`. Modeling §4.7 surfaced a
**normative contradiction in the spec** — §4.7 table row 6 vs row 10, with §4.6 step 1 and
§5.2a as the third and fourth sites; see `docs/PROPERTIES.md` §D. So the grid's 28 is right
today and was wrong before: it was 26.

### 3b. The class: what does a `§`-citation assert, and what else produces one?

This is **D13** asked of a *derived metric* instead of a gate, and the answer is the same
shape: the criterion was blind to the outcome it claimed. Matrix A is derived from the
models' own `§`-citations precisely so it is not a list someone chose — but the extractor
counts *mentions*, and a mention is not a claim. Four things produce one:

| Producer | Instances found | Disposition |
|---|---|---|
| **A range endpoint** `§X-§Y` | 2 — `ConnApalache.tla` `§4.1-§4.7`, `store.pml` `§4.8-§4.10` | The first was the phantom §4.7. The second is benign: §4.10 is independently cited 11 more times in the same file and genuinely modeled. |
| **An out-of-scope disclaimer** | 2 — both §6.9 citations in `Register.tla` | Was the phantom §6.9. |
| **A cross-reference to another DOCUMENT's section** | 5 — `COVERAGE-MATRIX.md §6`, `handoff §6` ×2, `PHASE1-SCOPE §7`, keystone's `§7b` | Harmless for the grid, which counts only `§N.M`, so bare `§6`/`§7`/`§7b` never entered it. Named because the same extractor feeds `make specdrift`'s dependency set, where they *are* counted. |
| **A genuine claim** | everything else | — |

*Enforcement — `make coverage`, and it is a gate, not a grep.* Every `§` mention in a model
was re-read against this taxonomy, not just the two that failed (D14 — the class, not the
instance), and the result is now checked on every `make check` / `make matrix`:

| `tools/coverage-check.py` asserts | |
|---|---|
| **A** | the cited `§N.M` set **equals** Matrix A's rows, in **both** directions — a new citation with no row fails, and a row with no citation behind it fails (that is how §4.7 and §6.9 got in) |
| **B** | the stated numerator equals that set's size, and the denominator equals the pinned spec's numbered-section count |
| **C** | neither tripwire fires: no `§X-§Y` range form, no `§` inside a scope-disclaimer sentence |

It does **not** assert the engine columns. A citation says a model is *about* a section, not
which engine verifies what; those are still hand-maintained and the tool says so rather than
letting a reader assume the whole grid is machine-checked. All five failure modes were
teeth-tested by breaking them.

**The rule caught its own author within the hour.** The two new modules written to close
§4.7 and §6.9 shipped three fresh phantoms — `§1.2`, `§1.5` and `§2.11`, every one of them
inside an out-of-scope note ("§4.7's four §1.2/§1.5 negotiation codes are settled before any
phase this model has"). The count went 28 → 31 while genuine coverage went 26 → 28. That is
the argument for the gate rather than the discipline alone: knowing the rule, having just
written it down, and violating it in the same session is the normal case.

**A model must cite a section only where it makes a claim about it.** A section it
deliberately does *not* model is named in prose without the `§` sigil.

### 3b′. The unit of this grid is the SECTION. The unit of a defect is the OBLIGATION.

**Everything in §3b hardens the numerator and leaves the unit alone**, and the unit is where
the next failure came from. A row of Matrix A says *some model cites this section*. It cannot
say *which of this section's obligations any model ranges over* — so §5.2 carries engine dots
with **9** MUSTs inside it, and a section carrying a MUST that no model cites is not a row at
all, which is not the same statement as a row with no dots.

That is not a hypothetical. On 2026-09-14 `entity-core-protocol` 0.8.2.23 closed a **capability
and identity forgery**: every authority lookup resolved an entity through a wire-supplied
`included` map key that nothing verified. The enabling text is **in our pin** —
`spec-data/v0.8.2` §3.1: *"The content_hash MUST match the map key"* — a MUST with **no
enforcing operation and no vector**, which is exactly what `AGENTS.md` **D17** was ratified to
report as a finding in its own right. §3.1 and §1.8, the two sections that carry it, are cited
by **zero** core models; §5.5, where the precondition now lands, is cited by **39**. Every gate
in this repo was green throughout, and `make coverage` was among them, correctly: the cited set
did equal the grid rows, in both directions. **A grid that is exactly right about its own
numerator says nothing about a denominator it does not have.**

**`make obligations` (`tools/obligations.py`, `docs/OBLIGATIONS.toml`) supplies that
denominator**, counted from each track's own pin rather than from our citations:

| track | obligations in the pin | inside sections a model cites | inside sections none cites | of those, **UNEXAMINED** |
|---|---|---|---|---|
| `core` | 365 | 237 | 128 (34 sections) | **120 UNEXAMINED** |
| `attestation` | 37 | 16 | 21 (5 sections) | 5 |
| `identity` | 86 | 59 | 27 (14 sections) | 27 |
| `quorum` | 60 | 23 | 37 (5 sections) | 11 |

Two of those rows deserve to be read twice. **On `quorum` and `attestation` more of the
normative surface sits outside the models than inside** — and those are the tracks this repo
originated findings on, which is the argument against reading a productive track as a covered
one. The gate requires a written disposition for every uncited obligation-bearing section from
a closed vocabulary (`modeled-elsewhere` / `out-of-scope` with a reason / `UNEXAMINED`), and it
prints the **UNEXAMINED** total as its headline so the number a reader sees is the size of the
hole rather than the fact that someone wrote it down. On `core`, **130 of 365 core obligations
sit in sections no model cites**. Of those, **122 of 365 core obligations are UNEXAMINED**; the
remaining 8 are §9.1, an index that restates obligations stated normatively elsewhere.

**What it still does not assert, stated here because that is the whole lesson of this
subsection:** that any obligation is *verified*. It measures the surface **outside** the
models and says nothing about the inside — a cited section can carry engine dots with every
one of its MUSTs unmodeled. Closing that needs per-obligation citations in the models, which
needs stable obligation ids; `entity-system-conformance` is minting them for the core tier
(`ECP-R1..R98`) and this tool should consume them when they land. Until then its MUST count is
a regex over the pin: a **lower bound** on the surface and an upper bound on nothing.

Audit: `docs/status/AUDIT-2026-09-14-THE-DENOMINATOR-WAS-OUR-OWN-CITATIONS.md`.

---

## 3f. Matrix A-OFFPIN — sections modeled against a NEWER snapshot than the core pin

⛔ **These rows are NOT part of the coverage pair above, and the pair went DOWN because of
them.** **Thirteen** model files transcribe **`spec-data/v0.8.2.25`** rather than the core pin
`v0.8.2` — `tla/ConnCodes.tla`, `tla/ConnCodesApalache.tla` and `spin/conncodes.pml` (the
`conncodes` subject, 2026-09-15), the eight `tamarin/Resolution*` files (the `resolution`
subject, 2026-09-16) and `tla/AuthoritySelect.tla` + `tla/AuthoritySelectApalache.tla` (the
`authority-select` subject, 2026-09-16). Each is declared in `TRACKS.toml` under
`[track.core.model_pins]`, marked in the file itself, and gated by `make trackcheck` §E in both
directions. `make coverage` holds their citations out of Matrix A and requires them here
instead; `make specdrift` measures them against `.25`.

⛔ **Do not read a count off this paragraph that you did not derive.** It said `Eleven` for one
day, because a third subject retargeted. The live figure is
`python3 -c "import tomllib;print(len(tomllib.load(open('TRACKS.toml','rb'))['track']['core']['model_pins']))"`,
and `make trackcheck` §E is what asserts the set — not this sentence.

**Why they moved off the pin — and the three subjects moved for THREE different reasons.** For
`conncodes` a section MOVED: §4.11 does not exist at `v0.8.2`, and §4.7's out-of-order row
carries a different status there (400 at the pin, **409** since 0.8.2.4). For `resolution` an
obligation DID NOT EXIST: §3.1 at the pin states the map-key binding as a property of the
ENVELOPE and names no operation on the receiver, and the receiver's obligation — with the two
mechanisms that discharge it — arrived as §1.8 item 1 at 0.8.2.23. For `authority-select` a
whole RULE did not exist: §6.8 at the pin carries one direction of the selection — the
confused-deputy prohibition — and describes the caller-specified-path check as one a handler
performs *"voluntarily"*. The three-row table, the `[MUST]`, the discriminator, its 0.8.2.22
correction and row 1's ceiling all arrive after the pin. Either way a model cannot transcribe
both texts, and a model transcribing the newer one is not evidence about the older.

⭐ **The cost is the honest part. §4.7 and §5.2a were Matrix A rows until 2026-09-15 and are
not any more**, because no pin-targeting model cites either — so after the retarget **nothing
in this repo verifies those two sections as the PIN states them**, and the published pair fell
from 29 to 27. The alternative on the table was a sentence in each module header saying which
snapshot it targeted, which would have left the 29 standing and made it false. `AGENTS.md`
D15's eleventh shape: *a disclaimer is not a gate, and it is worse than nothing because it
reads as though the risk was handled.*

| § | area | property class | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| **1.1** | **entity structure** | **the materialized form `{type, data, content_hash}` a (b)-mechanism peer ingests** | | | | ● | ● |
| **1.2** | **content addressing** | **the address is `h({type, data})`; `content_hash` itself is not hashed** | | | | ● | ● |
| **1.8** | **entity fidelity — RESOLUTION INTEGRITY** | **an entity used in an authority decision is resolved only through an address verified against its content; BOTH conformant mechanisms, each with its own control** | | | | ● | ● |
| **3.1** | **envelope / `included` map** | **the map-key ↔ `content_hash` binding, as a property an ACTIVE ATTACKER cannot violate** | | | | ● | ● |
| **3.5** | **`system/peer`, `system/signature`** | **the normative `signer` check is address-level and is NOT a defence against entity substitution** | | | | ● | ● |
| **4.7** | **connection error codes** | **MUST-emit reason-code contract; status per code; state conflict is 409; address before authentication** | ● | ● | ● | | |
| **4.11** | **pre-admission refusals** | **the coded-frame obligation; drop and bare-close as DISTINCT failures; cause → code** | ● | ● | ● | | |
| **3.11** | **bounds context / `chain_depth`** | **a standing continuation firing on a fresh trigger is a NEW chain root, not a continuation of the caller's** | ● | ● | | | |
| **5.2a** | **verdict-to-status enumeration** | **reason codes distinct** | ● | ● | ● | | |
| **6.3** | **`check_path_permission` / the listing filter** | **the call the §6.8 rule is carried out by — its ONE `authority` argument, and the listing filter's single call** | ● | ● | | | |
| **6.7** | **handler execution context** | **the context supplies BOTH the handler's own grant and the caller's verified capability, which is what makes row 1 implementable at all** | ● | ● | | | |

⭐ **The five §1/§3 rows are the `resolution` subject, added 2026-09-16, and they are the first
rows in this document that exist because a defect was found by somebody else.** `0.8.2.23`
closed a capability and identity forgery that turned on the `included`-map indirection; no
model here could see it, because every prover theory took capabilities and chain links as TERMS
off `In(...)` and there was therefore no address to forge (`docs/LEAN-SEAM.md` **O23**).
`tamarin/Resolution.{pv,spthy}` and `tamarin/ResolutionDiscard.{pv,spthy}` give the adversary
the ADDRESS as well as the term, one per conformant mechanism, each with its own control.

⛔ **What these rows do NOT credit, stated here because §3a is the record of what happens when a
row's label outruns its models.** They say nothing about SCOPE — that the leaf an attacker can
mint is worth minting is §5.6's property and `NoEscalation`'s — nothing about §5.5's MULTI-SIG
arms, whose per-constituent `included[candidate]` lookups are in this defect's class and are
**not modeled**, and nothing about the local content-store arm of the resolver. The §1.8 row's
two dots are two engines on two mechanisms, not five lookup sites on a whole section.

⛔ **§6.8 HAS NO ROW HERE AND THAT IS THE GATE'S RULE, NOT AN OVERSIGHT — BUT READ WHAT IT
COSTS.** `make coverage` keeps a section cited by BOTH a pin model and an overridden one in the
pin's claim, because some model really does transcribe the pin's text for it. §6.8 is such a
section: Matrix A row §6.8 is five dots for *"confused deputy; persistent re-check"*, and those
dots are earned — ten models consume §6.8's byte-identical *"a revoked capability never passes
a check"* clause at the pin.

**They say nothing about authority SELECTION**, which is `tla/AuthoritySelect.tla`'s subject
and does not exist in the pinned §6.8 at all. So the §6.8 row now carries two engines nobody can
see and three property classes under one label — ⭐ *is the row's stated property the one these
engines establish?*, which §3a says is the question to ask, answered here BEFORE the row misleads
someone rather than after. The selection rule's engines are TLC and Apalache, its snapshot is
`v0.8.2.25`, and `docs/CORROBORATION.md`'s `authority-select` subject is where that is stated in
a form a gate reads.

⛔ **§4.11 arm (f) is NOT in the row above.** The conformance paragraph names *"a pre-admission
refusal arriving while an admitted request is in flight on the same connection MUST NOT cost
that request its response"* — a claim about interleavings on a multiplexed connection, which
`ConnCodes` is structurally incapable of stating: it is a phase machine with one connection and
no admitted requests. It is `tla/Reentry.tla`'s subject and `docs/LEAN-SEAM.md` **O24**. The
dot in the §4.11 row credits the TABLE and the EMISSION obligation and nothing else — which is
exactly the §5.4 mistake §3a records, so it is written down before anyone can make it again.

## 3c. Matrix A-ATT — attestation section × property class × engine

**Track `attestation`, pinned at `spec-data/ext-attestation-v1.3/`** — a different protocol
and a different denominator from Matrix A above. `EXTENSION-ATTESTATION.md` is owned by
`entity-system-architecture`; its pin is `spec-data/MODELING-PIN-ATTESTATION` and moves
independently of core's.

**Coverage: 9 of 25 numbered `§N.M` sections (36%).** This track is three modules old. The
number is low because the work is three modules old, not because 16 sections were judged out of
scope — do not read it as the core grid's is read.

| § | Topic | Property class verified | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| 3.1 | attestation entity shape | which fields are optional, hence which indexes are conditional | ● | ● | | | |
| 3.2 | the `properties.kind` convention | `kind` is a recommended key, not a required field | ● | ● | | | |
| 3.3 | revocation as attestation | only a matching-`attesting` revocation affects liveness in the primitive | ● | | | | |
| 4.3 | `is_attestation_live` | transitive supersession; a live attestation has no live descendant; a dead revocation does not kill; **`is_self_revoked` is undefined and its two readings disagree — finding** | ● | ● | | | |
| 4.4 | authority-revocation is the consumer's | the substrate does self-revocation only; a third party's revocation does not kill | ● | ● | | | |
| 5.1 | `default_find_authorizing` | the head-resolution step is an identity map over the live candidates | ● | ● | | | |
| 5.2 | `walk_supersedes_chain` | terminates **iff** the supersedes graph is acyclic — the assumption isolated | ● | ● | | | |
| 5.3 | `find_live_head` | the forward walk cannot traverse a chain of three; **finding**, see below | ● | ● | | | |
| **5.7** | **index invariants I1–I5** | **write-then-read; all-or-nothing across the eligible index set; no residue on handler failure; retention under revocation; kind-index eligibility** | ● | ● | | | |

### Four rows carry FINDINGS, not coverage — read them that way

`§5.2` and `§5.3` are cited because `tla/AttestLive.tla` makes claims about them, which is
what puts a row here. But two of those claims are **negative**, and a grid cell is a poor
place to say so:

- **§5.3 `find_live_head` does not compute its own stated contract.** It filters successors by
  the full `is_attestation_live` predicate, and that predicate is false for any attestation
  that *has* a live descendant — so the link that leads to the head is never itself "live" and
  the walk cannot pass through it. On a three-link chain it returns null where the head is the
  third link. `SpecHeadFindsLiveHead` is asserted and violated, on a model with nothing
  weakened. Routed to `entity-system-architecture`; `docs/LEAN-SEAM.md` O8.
- **§4.3's `is_self_revoked` is used and never defined.** One occurrence in the document, and
  it is the use site inside `has_live_transitive_descendant`; `not_expired` likewise. The two
  natural readings — the main path's recursive one, and the structural "a matching revocation
  exists" — give `is_attestation_live` **different answers about the same attestation**.
  `SelfRevReadingsAgree` and `LiveReadingsAgree` are both asserted and violated. This is the
  class v1.0 Amendment 1 already fixed twice in this same function. `docs/LEAN-SEAM.md` O9.
- **§5.1's head-resolution step is an identity map.** `default_find_authorizing` filters
  candidates to live ones and *then* resolves each through `find_live_head` — but a live
  attestation has no live descendant, so the resolution returns its input every time.
  `HeadResolutionIsIdentity` is green, and the green is the finding. This is why the
  cross-impl vectors do not catch the bullet above: the composite gets the right answer
  because the liveness filter already did the work, and the broken step is invisible from
  outside. Row T4's lesson, on a different composition.

**A cohort result, and it is green.** `DescReadingsCoincide` proves that the descendant check
one implementation computes (any *fully live* descendant, walking past dead links) and the one
§4.3 words (any *weakly live* descendant) are the same predicate on every acyclic graph. It is
a checked invariant rather than a paragraph of reasoning deliberately: §D.1 is the record of
this repo reasoning its way to an impact claim about an implementation cohort and being wrong.

**Two engines on all three modules, as of 2026-09-08 — and the arithmetic is still the point.**
`AttestIndex`, `AttestLive` and `AttestRevoke` are each checked by TLC *and* Apalache
(`tla/AttestIndexApalache.tla`, `tla/AttestLiveApalache.tla`, `tla/AttestRevokeApalache.tla`).
**This was the only extension track where that was true until 2026-09-09**; all six quorum and
identity modules have since gained an Apalache port too, so **every extension module on all
three tracks now carries two engines** (§4, `make enginecount`). There is still no Spin
re-encoding on any of the nine and **no prover model at all** (`docs/LEAN-SEAM.md` O5), so the
Dolev-Yao gap is untouched and §1's corroboration argument, which is written about a
three-engine family, still does not cover these rows.

*This paragraph read "**This is the only extension track where that is true** — all six quorum
and identity modules are TLC-only" until 2026-09-09, one day after it became false.*
**`make enginecount` was green over it**, because it anchors on one declared site per file and
this file's declared site is §4. A second statement of the same fact, in different words, in the
same file, is invisible to the gate that derives it — D14's sixth instance again, on the document
in which that instance was first recorded.

What the second engine bought, stated narrowly: `IndexExactOnBound` and the rest of §5.7's
contract are now proved **inductive** — true for runs of any length, not only within TLC's
bound — **F1 is confirmed by a second, structurally different method** (TLC enumerates the
graph space; Apalache answers one SMT query over it), and **F5 stopped being a reading**
(below). What it did **not** buy is independence from the transcription: these files are the
same author's reading of the same spec text, so a shared misreading survives both. Adding
engines does not move the 5th wall.

**F5 IS NOW MACHINE-CHECKED, AND THE PORT REFUTED THE READING-STAGE VERSION OF IT.** F5 was
filed as *"§4.3 defends one of its two recursions against cycles"*, with the inference that
termination therefore rests on the **revocation graph** being acyclic — the unstated assumption
`LEAN-SEAM.md` O6 records for the supersedes side, one relation over. `AttestRevoke.tla` could
not check it, because its `Init` restricts **both** pointers to lower-numbered indices; its
header says so, and that restriction is what makes its recursion terminate.
`AttestRevokeApalache.tla` makes the two restrictions separate constants and lifts them one at
a time, and the first row run said something stronger and different: **per-relation acyclicity
is not enough.** With the supersedes order lifted and the revocation order kept,
`FixedPointUniqueRec` is violated on a configuration where **both graphs are acyclic** —
supersedes `2 → 3 → 4 → 1`, revocations `3 ⊣ 1` and `4 ⊣ 1` — because the dependency
`4 --supersedes-reach--> 1 --revoked-by--> 4` closes a loop across the *composition* of the two
relations. §4.3's `visited` set lives inside `has_live_transitive_descendant` and the recursion
alternates (`is_attestation_live → has_live_transitive_descendant → is_self_revoked →
is_attestation_live`), so the one stated defence does not span the hop that closes it. What
§4.3 actually needs is a **common order over both relations** — which content addressing
supplies in a deployed system and which no sentence of the document states. Eight
`APALACHE_ENUM_FINDING` rows carry this and the two F4 rows; the routing note's §F5 is
rewritten around the counterexample.

**And one green is part of that finding.** `ConstInitSupUnordered / FixedPointUniqueStruct`
**holds** where its `Rec` sibling does not: under the *structural* reading of the undefined
`is_self_revoked`, liveness stays well defined on the same configuration. So F4's undefined
helper does not only change §4.3's **answer** (which is what `LiveReadingsAgree` says) — one
reading **has** an answer there and the other does not. Read that row with F5.

Scope, so the rows are not read as more than they are: each Apalache module runs at **parity
with its TLC twin and no further** — N = 3 for `AttestLive`, N = 4 for `AttestRevoke`. Larger N
is the one thing the symbolic engine could give that the enumerator cannot, and the unrolling
ladders are cut to what those bounds need because the deeper ones exceed the 2 GB cap.
`ConstInitLadderShort` is the control that makes each bound fail loudly one node past it rather
than silently truncating; on `AttestRevokeApalache` it guards **two** ladders, reachability and
liveness. `AttestLive` remains an enumeration over every graph on **three** nodes and
`AttestRevoke` over every graph on **four** — small enough to be complete, small enough that a
defect needing one more node is invisible.

**The Apalache port of `AttestRevoke` has an obligation its TLC twin does not, and it is in the
green table for a reason.** Apalache has no `RECURSIVE`, and §4.3's four mutually recursive
operators expand to |Nodes|^(2k) leaf copies if written as nested operator definitions — that
draft OOM-killed the 2 GB cap on every invariant using the recursive reading, while the
structural reading (where the descendant path does not recurse) ran in 22 seconds in the same
file. So the ladder is built as a chain of **state variables**, one application of §4.3's
equation each. That trades a depth claim for a well-definedness claim: `LadderIsFixedPointRec` /
`…Struct` assert the ladder's top **satisfies** the equation (deep enough, and a solution
exists), and `FixedPointUniqueRec` / `…Struct` assert there is only one (so the solver was not
free to pick). Neither failure would have produced an error message — a short ladder computes a
wrong Boolean silently, and a second solution is chosen silently. That is why they are rows and
not a paragraph.

**Not modeled at all:** the §4 validation helpers and their signature checks (a prover-track
question, and this track has no prover — `docs/LEAN-SEAM.md` O5), `§5.1`'s `walk_attesting_chain`
itself as opposed to the head-resolution step inside it, and the §6 handler operations beyond
the index effects of a write.

**One of those gaps has since been closed from the other side, and it mattered.** This list
read "the `as_of` time-travel parameter and the `not_before` clock it orders" until 2026-09-07,
when the quorum track modeled that clock because §QUORUM:4.2 makes a normative MUST out of it.
With `not_before` present, §4.3's undefined `not_expired` separates into two readings that
disagree — and `DescReadingsCoincide` above, which is green, is scoped to a model in which
`not_before` does not exist and does **not** cover the separated case. A declared abstraction is
a to-do list, not an absolution (`docs/LEAN-SEAM.md` O9), and here the to-do was discharged by a
different track. See §3d and `tla/QuorumSignerSet.tla`.

**A reading, not a fact.** §5.7's I2 says partial-index states are "NOT permitted", with the
parenthetical "entity in one index but not another". Taken literally that forbids the state
I5 *requires* for a kind-less attestation. The model reads I2 as atomicity of one write
transaction over the entity's **eligible** set, and I5 as determining eligibility. That
reading is stated in `tla/AttestIndex.tla`'s header and is the first thing a reviewer should
push on; if it is wrong, the module is measuring the wrong thing and no gate here would say so.

## 3d. Matrix A-QRM — quorum section × property class × engine

**Track `quorum`, pinned at `spec-data/ext-quorum-v1.2/`** — a third protocol and a third
denominator. `EXTENSION-QUORUM.md` is owned by `entity-system-architecture`; its pin is
`spec-data/MODELING-PIN-QUORUM` and moves independently of core's and of attestation's.

**Coverage: 8 of 18 numbered `§N.M` sections (44%).** This track is three modules and one day
old. Read the number the way the attestation one is read, not the way the core one is: the
uncited half is uncited because nobody has modeled it, not because it was judged out of scope.

| § | Topic | Property class verified | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| 3.1 | `system/quorum` entity shape | `threshold` is typed `primitive/uint` and constrained nowhere — the input to the finding below | ● | ● | | | |
| 3.2 | the `quorum-update` convention | the per-quorum supersedes chain, and that its single-chain shape is a convention no operation enforces — **and, from 2026-09-09, that its ACYCLICITY is a second such convention (Q8)** | ● | ● | | | |
| 4.1 | `verify_k_of_n_signatures` | the defensive dedupe (one key cannot fill two slots); the `resolve_peer` null check; **threshold 0 authorizes with no signature — finding** | ● | ● | | | |
| **4.2** | **`current_signer_set` + the §4.2.1 cache contract** | **the invalidation trigger/non-trigger set is exactly sufficient *given* validated-only reads; per-quorum scoping; and five findings — see below** | ● | ● | | | |
| 5.1 | built-in `concrete` mode | resolution as the identity map — the case in which the dedupe and soundness greens are unconditional | ● | ● | | | |
| 5.2 | resolver registration | a non-injective resolution collapses the effective N below the validated bound | ● | ● | | | |
| 6.1 | `system/quorum:create` | states no structural validation — the other half of the threshold finding | ● | ● | | | |
| 6.2 | `system/quorum:update` | validates `new_threshold >= 1` and `<= |new_signers|`, against the pre-resolution array length — and neither the chain shape nor its acyclicity | ● | ● | | | |

### Nine rows carry FINDINGS, not coverage — read them that way

This track's first three modules produced more findings than results, and the grid cell is a
poor place to say which is which.

- **§4.2 returns the creation-time roster while a membership change is in force.** When
  `find_live_head` yields null, §4.2 does not error and does not return empty — `signers` still
  holds `quorum.data.signers`. On a plain chain of three updates with nothing expired and
  nothing scheduled, that is what happens. `SpecNeverSilentlyReverts`, violated on a model with
  nothing weakened.
- **§4.2's answer depends on index iteration order.** It walks from `updates[0]`, and
  §ATTEST:5.4 returns a list out of a field index with no stated order. Composed with the
  §ATTEST:5.3 defect this repo already routed, different elements give different rosters.
  `ResultIndependentOfProbe`.
- **§4.2's algorithm does not compute §4.2's own normative sentence.** The MUST names "the most
  recent `quorum-update` whose `not_before <= as_of` … with no successor that was itself live";
  the algorithm is `find_live_head(updates[0])` with a silent fall-through.
  `SpecMatchesNormative`.
- **A scheduled membership change destroys the current signer set** — under the literal reading
  of §ATTEST:4.3's undefined `not_expired`. `NotExpiredReadingsAgree`. This is the routed
  attestation finding F4 with a consumer-level consequence attached.
- **§4.2.1's own sentence "the cache reflects validated quorum state, not raw tree state" is
  false of §4.2's algorithm.** Two steps: an attestation that fails K-of-N is tree-bound
  (§4.2.1 permits it explicitly), and the next read walks the index and caches it as
  authoritative. `CacheMatchesValidated`, violated with §8's `tree:put` bypass switched **off**.
- **§4.1 with `threshold = 0` returns true over an empty signature set**, and §6.1 — unlike
  §6.2 — writes no constraint excluding it. `KofNRequiresASignature`.
- **On a `supersedes` cycle, §4.2 hands back the creation-time roster** — every probe returns
  null because a node on a cycle is its own transitive descendant. `CohortNeverSilentlyReverts`
  under `ConstInitSupUnordered`, added 2026-09-09 (Q8). Read it with the green beside it:
  `CohortNeverSilentlyRevertsWhenAcyclic` holds on the same cinit, so the assumption §4.2 needs
  is acyclicity and not the index order `QuorumSignerSet.tla`'s `Init` hard-codes. **The
  configuration is not constructible under content addressing**, which is the argument no
  sentence of either document makes.

### Two greens here are cohort results, not spec results

*(And from 2026-09-09 a third kind sits beside them: five rows are green **on a weakened
domain** — `ConstInitSupUnordered`, the index order lifted. They are not cohort results and not
spec results; they are the measurement that says which of §4.2's properties depend on the
ordering assumption and which do not. `tla/Makefile`'s `APALACHE_ENUM_GREEN` header names them
and says why deleting them as redundant would delete the result.)*

`CohortMatchesNormativeOnChain` and `CohortNeverSilentlyReverts` are checked under constants
that describe what `entity-core-{go,rust,py}` each independently implemented, **not** what the
document says. All three probe every candidate rather than `updates[0]`; all three read
`not_expired` as full temporal validity. The spec's own constants are checked in the finding
configs, where they fail. Same disposition as `DescReadingsCoincide` in §3c, and stated here
because a green whose constants are not the spec's would otherwise be read as one that is.

### What is not covered

**Two engines on ALL THREE modules, as of 2026-09-09.** `tla/QuorumKofNApalache.tla` carried §4.1
first — §4.1 has no recursion and is the cheapest port on this track, and it is the validator §2
calls "the only mechanism that distinguishes quorum from a regular peer node".
`tla/QuorumSignerSetApalache.tla` (§4.2, and the experiment behind Q8) and
`tla/QuorumTrustApalache.tla` (§4.2/§4.2.1, which corrected a published sufficiency claim and
amended Q5) followed. **No module here has a Spin encoding, and there is no prover** on this
track. *(This paragraph said "`QuorumSignerSet` and `QuorumTrust` remain TLC-only" until
2026-09-09, and the first half of that had already been false for a day — the D14 quantifier
lesson landing on a sentence that names modules instead of counting them.)*

That last gap is the one to weigh, because it is exactly where §4.1 lives: it is a K-of-N
*signature* validator and its unforgeability is a Dolev–Yao question **neither** engine touches
(`docs/LEAN-SEAM.md` O14). Cryptography is a per-peer boolean in both transcriptions. A second
engine on a structural model is a second engine on a structural model, and this row is the one
most likely to be misread as more. `MultisigKN.{pv,spthy}` proves
K-of-N for the **core capability** surface, which is a different validator over different
inputs.

**Not modeled at all:** §3.3 / §3.4 (`quorum-publish` and its previous-quorum pinning rule,
closed-namespace ownership), §4.3 `is_quorum_id`, §5.3 and its fail-closed resolver cases,
§6.3–§6.5, and the whole of the conformance and cross-extension-invariant sections. The
resolver's own recursion — the depth bound and cycle detection §5.2 makes normative — is named
in `tla/QuorumKofN.tla`'s scope note and **not** modeled; the resolution map there is an
arbitrary total function, which is strictly more permissive than a bounded resolver, so the
greens hold over it but nothing checks the bound itself.

## 3e. Matrix A-IDN — identity section × property class × engine

**Track `identity`, pinned at `spec-data/ext-identity-v3.10/`** — a fourth protocol and a fourth
denominator. `EXTENSION-IDENTITY.md` is owned by `entity-system-architecture`; its pin is
`spec-data/MODELING-PIN-IDENTITY` and moves independently of the other three. It is the last
track `TRACKS.toml` had scoped, so **no `scoped` track remains** and that gate now has no
subject in the live registry.

**Coverage: 22 of 73 numbered `§N.M` sections (30%).** Three modules and one day old. Read the
number the way the attestation and quorum ones are read, not the way the core one is: the uncited
three-quarters is uncited because nobody has modeled it.

**The citation set was audited down before it was published.** The first pass cited **30**
sections; nine of those were background, impact or scope-disclaimer mentions — the shape §6.9
had in the core grid, which is what `make coverage` exists to catch. Sections 3.2, 5.2, 7.1, 7.2,
9.6, 9.7, 10.2, 11.3 and 12.4 are now named **without the sigil** in the model headers, because
nothing here verifies them. Two that look like the same shape were kept: 6.0b and 6.0c are cited
because the claim "no operation validates §4.3's `attesting = target.attested`" is modeled as a
constant (`HandoffIdentityEnforced`), which is the same disposition §6.1 already has on the
quorum grid.

| § | Topic | Property class verified | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| 2.2 | three entity-validation classes | identity does not dispatch side effects for a kind it does not own | ● | | | | |
| 2.3 | function correspondence | who signs each cert kind — the input to the §9.2 finding | ● | ● | | | |
| 3.3 | identity attestation conventions | the four owned kinds, and that `revocation` / `quorum-*` are not among them | ● | ● | | | |
| **3.6** | **the validators** | **`identity_verify_cert` step 1's gate, `identity_topology_for` arm by arm; three findings — see below** | ● | ● | | | |
| 4.1 | kind table | the signature topology column, per kind | ● | ● | | | |
| 4.2 | `identity-cert` + valid-modes table | the per-function admissible (function, mode) set — one cell of it contradicts §9.2 | ● | ● | | | |
| 4.2a | publication modes | mode as the storage-path selector; `agent` + `public` is the contested cell | ● | ● | | | |
| 4.2b | sub-controller chains | a sub-controller cert dispatches single-sig, not a second K-of-N | ● | ● | | | |
| 4.3 | `identity-rotation-handoff` | dual-sig; and the unenforced `attesting = target.attested` — **finding** | ● | ● | | | |
| 4.4 | `identity-rotation-recovery` | K-of-N from quorum, always; the §9.4 antecedent | ● | ● | | | |
| 4.5 | `identity-retirement` | K-of-N from quorum, always | ● | ● | | | |
| 4.6 | `revocation` | identity's authority-revocation rules — and that the kind cannot arrive — **finding** | ● | ● | | | |
| 5.1 | path layout + cache lifetime | where each kind is stored; the retention floor that ends at accept — **finding** | ● | ● | | | |
| 5.2 | audience and sync | *(cited for the tier separation only; no ordering property is verified)* | ● | ● | | | |
| 5.3 | canonical storage path | the `public/` question only — whether a cert's mode puts it there | ● | ● | | | |
| 6.0b | `:supersede_attestation` | the REBIND_KINDS split, as the other half of "nothing validates the handoff identity" | ● | | | | |
| 6.0c | `:create_attestation` | validates (kind, function, mode) and the required properties fields — and not that identity | ● | ● | | | |
| **6.3** | **`process_attestation`** | **phase 1 / phase 2a / phase 2 dispatch / phase 3 emission; three findings — see below, plus N2 on a phase-2 handler the table names and no section defines** | ● | ● | | | |
| 9.2 | operational-key confinement | the MUST, over exactly the cert shapes §4.2 admits — **finding** | ● | ● | | | |
| **9.4** | **compromise-recovery validation** | **fail-closed holds, INDUCTIVELY; and it holds vacuously — two findings, plus N1 on the key it reads** | ● | ● | | | |
| 10.1 | MUST-implement list | topology-first dispatch; dual-sig handoff; the phase-2a scope rule | ● | ● | | | |
| 12.3 | three algorithms, one direction | the no-shared-validator wall at the arrival path | ● | | | | |

### Nine rows carry FINDINGS, not coverage — read them that way

Like the quorum track, this one produced more findings than results, and a grid cell is a poor
place to say which is which.

- **§6.3's phase-2 dispatch table has a row phase 1 makes unreachable.** Phase 1 is unconditional
  `identity_verify_cert`, whose step 1 admits four kinds; the table has seven rows and one names
  `quorum-publish`. `SeedRowReachable`, violated with nothing weakened.
- **A `revocation` arriving over sync is unbound by phase 2a** — while §4.6 gives identity
  authority rules over the kind, §5.1 stores it at synced paths, and §3.6 step 3 reads it back
  out of the tree. `RevocationSurvivesArrival`.
- **A `quorum-update` arriving over sync is unbound by phase 2a**, at the path §5.1 gives it.
  Composed with the routed Q1, the roster cannot change because the updates do not survive to be
  walked. `QuorumUpdateSurvivesArrival`.
- **§9.4's fail-closed rule is satisfied vacuously.** The anchor it requires is filled only by the
  unreachable dispatch row above, so a genuine compromise-recovery signed by the identity's real
  quorum is rejected at a contact that has received that identity's genuine `quorum-publish`.
  `RecoveryAttainable`. **`RecoveryFailClosed` is green on the same constants** — which is the
  whole point of the pair.
- **Nothing says what may become §9.4's trust anchor.** §9.4 names the cache "the trust anchor"
  and neither it nor §6.3 specifies validation on the way in. `AnchorWasValidated`, and its
  security consequence `AcceptedRecoveryIsQuorumSigned`.
- **§5.1's retention floor ends one instant too early.** "Retained at least ... until the verifier
  accepts the new handle" expires at accept, so a duplicate delivery of one recovery attestation
  gets a second, different verdict. `RecoveryIdempotent`.
- **§9.2's MUST and §4.2's valid-modes table cannot both be satisfied** in the three-key default:
  an `agent` cert at `mode="public"` is signed by the controller and lives under `public/`, which
  §9.2 requires rejecting. `PublicPathNeverControllerSigned`.
- **§3.6's handoff arm dereferences an unresolved target**, in the same section where
  `identity_confers_function` guards the same helper. `HandoffTargetGuarded`.
- **§9.4's anchor is keyed by a handle that moves** (N1, added 2026-09-09 by the second engine).
  §5.1 writes the entry under the `quorum-publish`'s `published_handle`; §9.4 reads it under the
  recovery's `old_handle`. A §4.3 routine rotation moves the second, produces no publish, and no
  section requires a re-key or a re-publish — so a preventive privacy rotation removes the only
  compromise-recovery path. `AnchorSurvivesHandoff` and `HandoffKeepsRecoveryAvailable`, violated
  with nothing weakened; both **green** under the candidate repair.
- **§6.3's `update_handle_cache_to` is defined in no section** (N2, same date), and its two
  readings each satisfy one of two properties the spec states — neither satisfies both.
  `RecoveryIdempotent` under the move reading and `SecondRecoveryHasAnchor` under the retain
  reading. The three implementations answer three ways.

**One of these is cross-spec and exists only in a pair of documents.** `EXTENSION-ATTESTATION`'s
TV-A8 delegates the rejection of an invalid-signature revocation to *"identity's
`identity_verify_cert` … at topology-dispatch step"*, and `identity_verify_cert` rejects every
`kind="revocation"` before topology dispatch is reached. Neither document is wrong read alone.
`RevocationReachesTopology`.

### One green here is a declared assumption about another track

`KofNAnswerIsTrustworthy` says every K-of-N verdict identity reaches is taken against whatever
`§QUORUM:4.2 current_signer_set` hands back — and its negative control
(`IdentityCertChainSubstrateBug`, `SignerSetIsSound = FALSE`) is the already-routed Q1. It is a
control rather than a finding on purpose: re-routing Q1 wearing an identity section number would
be a double-count. `docs/LEAN-SEAM.md` O16 is the row.

### What is not covered

**Two engines on ALL THREE modules, as of 2026-09-09**, and read what that does and does not
mean. `tla/IdentityCertChainApalache.tla` came first (§3.6 topology dispatch and §9.2
confinement, where every K-of-N verdict in this extension is dispatched);
`tla/IdentityRecoveryApalache.tla` and `tla/IdentityProcessApalache.tla` followed on 2026-09-09.
**This track has no single-engine subject left, and that is a smaller claim than it sounds.**
Both engines are checkers over the same TLA+ transcription — same author, same reading — so a
misreading survives both, and neither can express unforgeability. What the two later ports
actually bought was not corroboration: each lifted a **domain restriction** the first model had
hard-coded, and each produced findings (N1/N2, then N3/N4) that the first engine could not have
seen at any depth. `docs/CORROBORATION.md` records `n` as a count and not as a grade.
No Spin encoding, and **no prover**: `docs/LEAN-SEAM.md` O19's gap is untouched, so every
finding on this track — including I5's "an unsigned revocation is honoured" — is a statement
about which code path is reached and not a Dolev-Yao result. Identity's authority-logic
predicates (`identity_confers_function`, `identity_is_authorized_revoker`) are *not* discharged by
the keystone sibling's Lean and deliberately so — §2.2 and §12.3 make identity attestations a
structurally distinct validation class from capability tokens, so routing them to the layer that
owns cap-chain attenuation would be the conflation §9.1 calls "the natural implementation
mistake". O17 is that row.

**Not modeled at all:** §3.1, §3.2 (`resolve_controller_for_grants` and its content-hash
tie-break), §3.4, §3.5, §4.2c, §5.1.1, §5.4, §6 and §6.0a / §6.0d / §6.0e / §6.0f / §6.1 / §6.2 /
§6.4, §7 and its custody variants, §8, §9.1 / §9.3 / §9.5 / §9.6 / §9.7, §10.2–§10.4, all of §11,
§12.1 / §12.2 / §12.4 / §12.5, and §13–§15. **§6.4 is in that list and is named repeatedly in
`ROUTING-2026-09-09-IDENTITY-ARRIVAL-PATH-STATE.md`**, because finding N3 is that §6.4's
convergence-window bound is computed against a window §6.3's arrival path never closes. Nothing
here verifies §6.4's cascade, so the models cite it without a `§` sigil and it stays uncovered —
the §3e discipline applied to a section a finding *argues from* rather than *checks*. The recursive chain walk in `identity_verify_cert`
step 5 and its depth bound are named in `tla/IdentityCertChain.tla`'s scope note and **not**
modeled — that is `DeepChain`/`Bounds`' question and it is not re-asked here.

## 4. Matrix B — the corroboration grid

Matrix A shows *what* is covered. This shows *how independently* — the answer to "who
checks the checker". **Every `core` CONCURRENCY/STRUCTURAL module that Spin re-encodes is
covered by all three engines of its family — and as of 2026-09-16 that is no longer every
`core` module.**

**Read BOTH qualifiers, because each was added the day a quantifier here went false.**
*`core`* was not there until 2026-09-07; without it the sentence read *"Every module is covered
by all three engines of its family"*, unqualified, written when `core` was the only track.
⛔ *The clause about Spin* was added **2026-09-16**, when `tla/AuthoritySelect.tla` +
`tla/AuthoritySelectApalache.tla` landed as a core subject on **TLC + Apalache and no Spin**
(§6.8's authority-selection MUST; `docs/CORROBORATION.md` `authority-select`). The previous
sentence quantified over *core modules* and the new one is a core module, so it was false the
moment that subject was declared — **`make enginecount` was GREEN throughout**, correctly, because
it reads the declared per-subject engine sets and never reads this sentence. D14's sixth instance
exactly: *a bare universal quantifier over your own artifacts, whose set someone else grew.*
Recorded rather than quietly re-worded, and the repair deliberately NAMES the module that fails
the old quantifier instead of widening the count to twelve.

**THE APALACHE COLUMNS ON THE THREE EXTENSION GRIDS WERE RE-DERIVED FROM THE MODELS' OWN
CITATIONS ON 2026-09-08, AND SOME OF THEM WERE ALREADY STALE.** `make coverage` asserts the
section SET and the counts and says in its own output that it does **not** assert the engine
columns — those are hand-maintained. When the first two Apalache modules landed earlier the same
day, several rows they cite (`ATTEST §3.1`, `§3.2`, `§5.1`, `§5.2`) kept a blank Apalache cell,
because a hand-maintained column is updated by whoever remembers to. The columns are now set by
comparing each grid's `§` rows against the `§` citations in that track's Apalache modules.
**That is a derivation, not a gate** — nothing re-runs it, and it will go stale again the next
time a module lands. Recorded here rather than left to be re-discovered, and it is the obvious
next thing for `coverage-check.py` to take over.

*Live count — **derived by `make enginecount`, not stated by hand**, since 2026-09-09:* there are
nine extension subjects on three tracks, of which **9 of 9** have a second engine — every
module on all three tracks carries TLC and Apalache, and none is TLC-only.
None has a third engine, and none has a prover model. The quantifier is stated as a count here,
deliberately: the last time this sentence carried a bare universal it went false the day someone
else grew the set, and a number goes stale visibly where "every" does not.

**And a number stated by hand goes stale invisibly, which is what happened next.** The count in
this paragraph and its twin in `AGENTS.md` were both written on 2026-09-08 and were both wrong
by the following morning. `docs/CORROBORATION.md` is now the per-subject ledger, `make
enginecount` derives the pair from the **green** gate tables, and every site that states it —
including this one — fails the build when it drifts. **The engine COLUMNS in the grids above are
still hand-maintained**; the gate counts engines per subject and does not check which section a
column dot sits on, so the paragraph above this one still describes live work.

Since 2026-09-07 the position was that **every extension module was TLC-only** — no Apalache,
no Spin, no prover. Each track's own grid (§3c, §3d, §3e) said "one engine" plainly; this
headline did not, and a reader arriving here first would have taken the strongest corroboration
claim in the repo as covering modules it does not.

Nothing was mis-derived: Matrix B has no row for any extension module and is accurate line by
line. **The defect is in a summary sentence that quantifies over a set that grew underneath
it** — the D15 mechanism (the input set is the claim) in prose rather than in a tool, and found
by re-reading rather than by a gate, because no gate reads this sentence. The corroboration gap
is `docs/LEAN-SEAM.md` O5, O14 and O19 and is item 2 on `docs/STATUS.md` §Next.

### Concurrency family (TLA+ / Promela) — `core` track

| Module | Protocol surface | TLC (bounded) | Apalache (unbounded) | Spin (independent) |
|---|---|---|---|---|
| `Reentry` | §6.11 reentry + (a′) | ● safety + liveness | ● `FramesNotInterleaved` | ● |
| `Conn` | §4.1–4.7 handshake | ● safety + liveness | ● handshake invariant | ● |
| `Store` | §4.8–4.10 store/admission | ● safety + liveness | ● race, bound, **use-after-free** | ● |
| `Revoke` | §5.1/§5.10 revocation | ● safety + liveness | ● determinism, revoked-never-passes | ● |
| `Emit` | §6.10 events | ● safety + liveness | ● event-iff-work, type | ● |
| `Register` | §6.1/§6.2 registration | ● safety + liveness | ● system guard | ● |
| `Core` | **composition of all of the above** | ● safety + liveness | ● **composed conjunction** | ● |
| `Authority` | §5.2 dispatch authority | ● safety | ● all four §5.2 rules | ● (structural) |
| `Bounds` | §5.9/§4.10(b) | ● safety | ● **over symbolic constants** | ● (structural) |

Two rows deserve a note:

- **`Core` — the composed conjunction was the last deferred item in the repo and is now
  proved.** It had been carried since Phase 1 as "consciously deferred, lowest value", on
  the reasoning that each invariant is proven separately and Spin corroborates the deadlock.
  The 0.8.2 audit rejected that: *"each invariant is proven separately"* is exactly what a
  composition invariant is **not**, and the deadlock in question is liveness, which Apalache
  cannot prove either way. Nothing is deferred now.
- **`Bounds` — the Apalache proof is over SYMBOLIC constants.** TLC checks the depth-brake
  property at one scaled-down configuration (ceiling 4, fan-out 2, seed 16). Apalache proves
  it for **every** `TtlSeed`/`DepthCeiling`/`MaxFanout` satisfying §5.9's ratio condition.
  Since §5.9 explicitly makes the numbers non-normative and states the requirement as a
  property, the symbolic result is the one that matches the claim.

### Active-attacker family (Dolev–Yao)

Both provers close **every** lemma but one (`RevokeMech`, §6). `BindingReplay` is a ProVerif
file with no Tamarin twin because Tamarin proves the same property — no-replay — *inside*
`Binding.spthy`, via a linear consumed-nonce fact; ProVerif's tables are not atomic under
replication, so it uses a separate challenge-response theory instead. The 15-vs-14 count is
that packaging difference, not a coverage gap. `RevokeMech`'s ProVerif column below likewise
refers to `Revoke.pv`'s private-channel token — there is no `RevokeMech.pv`.

| Theory | Property | ProVerif | Tamarin |
|---|---|---|---|
| `Unforge` | capability unforgeability | ● | ● |
| `NoEscalation` | no escalation via attenuation | ● | ● |
| `Binding` / `BindingReplay` | request binding; no replay/reflection | ● / ● | ● / — |
| `Caveats` | caveat enforcement | ● | ● |
| `DepthBound` / `DeepChain` / `DeepChainN` | depth bound; deep-chain frame integrity | ● | ● |
| `Expiry` | expiry honored | ● | ● |
| **`Malformed`** | **§5.6 CAP-6a — unrepresentable temporal field refused, never read as absent** | ● | ● |
| **`ChainTopology`** | **§5.8 — provenance at a NON-ISSUING third-party verifier** | ● | ● |
| `Multisig` / `MultisigKN` | K-of-N threshold | ● | ● |
| `Revoke` | revocation under attacker | ● | ● |
| `PersistentRecheck` | no trusted-forever fail-open | ● | ● |
| `RevokeMech` | mechanistic linear-token revocation | ● | **does not terminate** (§6) |

---

## 5. What is NOT covered — three different kinds of "no"

Conflating these is how a coverage number becomes dishonest. **64 of 91 sections are not
cited by any model.** They fall into three groups and only the third is a backlog.

### (a) Out of scope by design — another layer owns it

These belong to other rows of `docs/ASSURANCE-MAP.md`, not to this repo. Verifying them here
would duplicate an owner, not add assurance.

| Sections | Why not here | Who owns it |
|---|---|---|
| §2.x (11 sections) — type system | Type-system soundness is not a concurrency or attacker property | `ENTITY-NATIVE-TYPE-SYSTEM.md`, implementations |
| §3.x mostly (11 of 13) — encoding, type definitions | Wire encoding correctness is a serialization property | CBOR spec + conformance vectors |
| §7.x mostly (5 of 6) — algorithms | Hashing/canonicalization interiors; §7.3 signatures enter only as the **crypto wall** | Lean (authority logic), crypto primitives |
| §8.x (5 sections) — constants | Constants have no behaviour to verify | — |
| §9.x (6 sections) — conformance profiles | "Does an implementation conform" is a test question, not a model question | `entity-core-keystone` validate-peer |
| §1.x mostly (10 of 11) — foundations, principles | Framing and design principles; §1.7 peer identity is the modelable part | — |

### (b) Tool-limited — cannot be reached by these methods

| What | Why |
|---|---|
| **Liveness beyond the bound** | Apalache does safety/induction only. Every liveness result (deadlock-freedom, eventual settling, revocation convergence, emit progress) is **bounded-exhaustive**, never unbounded. |
| **`RevokeMech` in Tamarin** | Mechanistic linear-token revocation loops Tamarin's backward search on a regenerated `Valid` fact. It stays ProVerif's lane; Tamarin uses a terminating trace-restriction idiom. Irreducible tool asymmetry, excluded from `make check`. |
| **Bit-level cryptanalysis** | Both provers model sign/verify as perfect symbolic primitives. A broken hash or signature scheme is invisible here — that is the crypto wall, shared with Lean's axioms. |
| **The receiver's decode** | §6.11(a′) says interleaved frames "corrupt the receiver's decode". The models prove the writes do not interleave; they do not model the decoder that would fail if they did. |
| **Byte-level memory reuse** | §4.8's use-after-free is modeled as "freed while a referrer is live", not as a simulation of the corrupted read that follows. |

### (c) Genuine backlog — modelable, not yet modeled

| Sections | What is there | Status |
|---|---|---|
| §4.3, §4.4, §4.5 | connection-lifecycle detail beyond the modeled handshake | open |
| §5.3 | capability structure detail | open |
| §6.3, §6.4, §6.7 | handler context, params, internal scope | open |
| §6.12, §6.13 | per-request transport error codes; handler origination path | open |
| §3.5, §3.11, §3.12, §3.13 | discovery locality, chain_id/depth wire fields | partly reachable via §5.9 |
| §6.11(c) | per-request deadlines | **named**: this is what would make Class-G a *liveness* bug rather than a crash |
| `EXTENSION-*` protocols | 26 extension specs; `attestation` and `quorum` are **modeled** (§3c and §3d above), `identity` is `scoped` | **Not a gap in this matrix — a different track.** They are separate tracks in `TRACKS.toml`, not uncovered core sections, and each gets its own grid when it gets a model. All three are **vendored** (`spec-data/ext-attestation-v1.3`, `ext-quorum-v1.2`, `ext-identity-v3.10`) and pin independently of core. *(This cell said "nothing is vendored because `spec-data/` is held at the core pin until the keystone sibling converges, and the extension snapshots ride along with that re-vendoring pass" until 2026-09-07. That was an inference nobody checked: each extension spec's `Depends` on the core protocol is a FLOOR the held pin already clears. Core's pin is still parked on keystone and that was never a constraint here.)* Modeling against a live checkout instead of a pinned snapshot is what the discipline forbids, and that has not changed — which is why vendoring came first. |

---

## 6. The limits and bounds of every result

The precise ceiling on each claim. Nothing here is hidden in a footnote elsewhere.

| Result class | Exact bound | What that excludes |
|---|---|---|
| TLC safety | 2 peers (**2 and 3** for `Reentry`/`Core`, directed ring); 3–4 concurrent requests; 3 store keys; 3 dispatch slots | a defect first appearing at 4+ peers, at 3 on a non-ring topology, or at 5+ requests |
| TLC liveness | same, and `Store` liveness runs at `NReq = 3` where safety runs at 4 | TLC's liveness graph exhausts the 2 GB cap at 4 — stated in both cfg headers |
| Spin | same bounds, independent encoding; `-DNFAIR=3` for 8-process fairness | same as TLC; Spin adds independence, not reach |
| Apalache | **unbounded in steps**, over the module's fixed peer/request set | not unbounded in *peers* — the set is fixed at 2, or at 2 **and** 3 for `Reentry`/`Core` |
| Apalache (`Bounds` only) | **also unbounded over the constants**, constrained only by §5.9's ratio | the one place the numbers are symbolic rather than chosen |
| ProVerif / Tamarin | unbounded sessions, unbounded attacker, **perfect symbolic crypto** | cryptanalysis; timing/side channels; implementation bugs |
| All of it | a property of a **model**, relative to the **5th wall** | see below |

### The 5th wall — the deepest limit, which no tool here closes

Every result is a property of a *model*, true only insofar as the model faithfully
transcribes `spec-data/v0.8.2/`. **No engine checks that correspondence.** The mitigations
are real but partial: every modeled element carries a `§`-citation; every secure result has a
negative control reproducing a *named* defect; every TLC module carries a non-vacuity
witness; two independent formalisms and two independent provers must agree. That narrows the
wall. It does not close it. **Human review against the vendored spec owns it.**

### Vacuity — the failure mode where green means nothing

A property that *cannot fail* reports the same green as one that holds. This repo has been
bitten by it and treats it as a first-class hazard:

- **Fixed at 0.8.2:** `Store`'s live-key bound was vacuous (one key against a bound of 2).
  Now multi-key and falsifiable.
- **Fixed at 0.8.2:** the TLA+ track had **no** non-vacuity assertions at all. Every TLC
  module now carries a **witness** — an invariant asserted in order to be *violated*.
  `make -C tla tlc-witness` fails loudly if a witnessed state becomes unreachable.
- **Fixed after 0.8.2:** `Reentry`'s and `Core`'s `StoreBounded` were vacuous conjuncts (one
  literal key written once, against a bound ≥ 1), and `Core`'s was carried into the composed
  Apalache conjunction, making it look one term stronger than it was. The Spin counterpart
  was worse still: `core.pml` clamped the store write at `MAXKEYS` and then asserted
  `store[q] <= MAXKEYS` — an assertion enforced by the statement three lines above it.
  **Removed**, not patched: the bound has no content in models whose servers serve once, so
  giving it teeth would mean duplicating `Store`. Declared as a structural exclusion in each
  model. It had been disclosed as vacuous twice without being fixed.
- **~~Known and open:~~ Retired 2026-09-06.** `Register`'s correct-model atomicity was
  near-tautological — five §6.2 writes in one assignment, so the invariant restated it. The
  four non-committing facets now land one per transition with the fifth write and the index
  publish as a single atomic commit, and `RegisterSeqWitness` asserts the *pre-0.8.3* invariant
  and requires it to be **violated** — so the sequencing is proven reached, not just written.
  `RegisterAllOrNothing` is additionally proven **inductive** by Apalache, which was not worth
  doing while it was a tautology. **No thin positive remains.**
- **A trap in the tooling:** a bounded Apalache negative control that is too *short* to reach
  its defect reports `NoError`, which is textually identical to "the invariant holds". One
  control was observed passing at length 4 and failing at 5. Lengths in `tla/Makefile` now
  carry margin, and the trap is documented there.
- **The gate now checks *why* a control fails.** `tlc-neg` used to grade on TLC's exit status
  alone, with output discarded — and TLC exits non-zero for a parse error exactly as it does
  for a caught defect, so a control broken by a typo, or one that had drifted onto a different
  property than the one it targets, scored "failed as required". All 30 rows now declare the
  verdict line they must produce and a mismatch fails the build. Spin's controls must report a
  positive `errors: N`; Spin's green runs must report an explicit `errors: 0`; Tamarin runs
  must be wellformed. The rule behind all of it: **absence of a pass is not evidence of a
  catch.**
- **…and then the same question had to be asked of the other four graders.** Fixing three left
  **62 of 203 runs** graded by a blind criterion: `proverif-green` on an exit status ProVerif
  returns as `0` for a *false* query; `proverif-neg` on "some result is false", which is also
  how a passing non-vacuity query reports, so 13 of 15 secure theories satisfied their own
  control's criterion; `apalache-neg` and `tlc-witness` on exit status with output discarded,
  where a configuration error (`255` / `151`) is indistinguishable from a caught defect. Both
  provers are now graded against **declared verdict tables** — every query and lemma states
  the verdict it must produce and the run must produce exactly that set, so an added or
  dropped query fails too. **No verdict moved**; all 203 were re-derived by hand and match the
  reports. The gate's ability to notice if one ever moved is what was missing.
- **~~Three negative controls break the model, not only the property.~~ Narrowed, all three.**
  Pinning Tamarin per lemma exposed that `ChainTopologyBug`, `DeepChainBug` and
  `DeepChainNBug` each reported `falsified - no trace found` on its own reachability lemma:
  the honest path was gone in the variant, so the run could not show *which* lemma the defect
  had broken. Each was an honest consequence of the injected defect and each was still a bad
  control. **§5.5a gives two pattern forms and only the peer-relative one has a frame to get
  wrong** — an absolute `/{p}/` + wildcard canonicalizes to itself in every frame. All three
  theories now carry an absolute-form leaf alongside the bare-`*` one, byte-identical in the
  green twin and the control, so each control still differs from its green by exactly the
  injected defect while the honest path survives it. All three report their reachability
  lemma `verified` and falsify their target alone.
- **Two ProVerif theories had no non-vacuity query.** `Unforge.pv` and `Binding.pv` are pure
  correspondence lemmas, which a model that can never accept satisfies vacuously — and their
  Tamarin twins both carried an `exists-trace` lemma the ProVerif side lacked. The flagship
  unforgeability result was the un-witnessed one. Queries added; both fire.

---

## 7. Reproducing any of it

```
make build      # build all five toolchain images (the only network step)
make matrix     # THE GATE: green + negative controls + non-vacuity witnesses
make check      # the green-only slice (does NOT answer "could it have failed?")
make specdrift  # is the pin still the live spec?
make trackcheck # which proof track is each model file on? (TRACKS.toml)
```

`make matrix` asks three questions, and passing all three is what the numbers in
`docs/STATUS.md` refer to:

1. **green** — does every modeled property hold?
2. **negative controls** — could it have failed? Every control *must* fail; a green control
   is a build failure.
3. **witnesses** — does the model reach an interesting state at all? Every witness *must* be
   violated; a clean witness is a build failure.

Per-engine: `make -C tla matrix`, `make -C spin green && make -C spin neg`,
`make -C tamarin matrix`. Run the three **serially** — each engine runs under the `caps.mk`
memory ceiling, and three concurrent sweeps contend for it.

*(This paragraph gave a different reason until 2026-09-06: "concurrent `:Z` bind-mount
relabels race on SELinux hosts." That race was real but it was **our bug, not the platform's**
— `tla/` and `tamarin/` are each mounted by two images, and uppercase `:Z` relabels a volume
private to one container, so the second image's relabel invalidated the first's. Fixed
2026-08-30 by dropping those two mounts to lowercase `:z`; `spin/` is owned by one image and
correctly stays `:Z`. Serial execution survives the fix for the resource reason above.)*

---

*Scorecard of proven-vs-modeled per property: `docs/PROPERTIES.md`. Where this repo sits
among the other assurance layers: `docs/ASSURANCE-MAP.md`. Cross-check detail:
`docs/CROSSCHECK-RESULTS.md`. Current state and backlog: `docs/STATUS.md`.*
