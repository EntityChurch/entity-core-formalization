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
| **TLC** | model checker (explicit-state) | *Does any interleaving of concurrent activities break this property, at a small fixed size?* | Enumerates **every reachable state** of the model at a bound (2 peers, 3–4 requests) and checks each one. | Say anything beyond the bound. A defect needing 3 peers is invisible. |
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

Derived from the `§`-citations the models themselves carry, not from prose. Reproduce with
`make specdrift` (which reads the same citations) or by grepping `§` in `tla/`, `spin/`,
`tamarin/`.

**Coverage: 28 of 85 numbered `§N.M` sections (33%).** Read by area, not as one number —
see §5 for why the zeros are zeros.

| § | Topic | Property class verified | TLC | Apalache | Spin | ProVerif | Tamarin |
|---|---|---|---|---|---|---|---|
| 1.7 | peer identity | identity binding under attacker | | | | ● | ● |
| 3.3 | wire frame | frame structure (as (a′) subject) | ● | | | | |
| 3.6 | multi-granter threshold | K-of-N cannot be bypassed | | | | ● | ● |
| 4.1 | connection establishment | handshake ordering | ● | ● | ● | | |
| 4.2 | pre-auth gate | no dispatch pre-establishment | ● | ● | ● | | |
| 4.6 | nonce handshake | no establish without issued nonce | ● | ● | ● | | |
| **4.7** | **connection error codes** | **MUST-emit reason-code contract; status per code** | ● | ● | ● | | |
| **4.8** | **store safety + refcount** | **data race; use-after-free** | ● | ● | ● | | |
| 4.9 | resilience under load | responsive; deliver-or-signal; recover | ● | ● | ● | | |
| 4.10 | resource bounds / admission | clean reject; bounded in-flight; chain depth | ● | ● | ● | | |
| 5.1 | revocation | revoked never passes | ● | ● | ● | ● | ● |
| **5.2** | **verification + dispatch authority** | **three-valued authority; resource binding** | ● | ● | ● | ● | ● |
| 5.4 | pattern matching | no escalation via attenuation | | | | ● | ● |
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

### 3a. One row is single-engine — and the other two were never covered at all

The "every module is checked by all three engines of its family" claim in §1 and §4 is about
**modules**, and it holds. At **section** granularity one row still rests on one engine:

| § | Only engine | What that means |
|---|---|---|
| 3.3 | TLC (`Reentry.tla`) | §3.3 is not modeled *as* a wire-frame property. It appears only as the **subject** of §6.11(a′) — "these bytes are what must not interleave". The frame's own structure is the CBOR spec's and the conformance vectors', per §5(a). Not a gap in this repo's surface; a row that looks thinner than the claim behind it. |

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
**normative contradiction in the spec** (§4.6 step 1 vs §4.7 table row 10); see
`docs/PROPERTIES.md` §D. So the grid's 28 is right today and was wrong before: it was 26.

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

---

## 4. Matrix B — the corroboration grid

Matrix A shows *what* is covered. This shows *how independently* — the answer to "who
checks the checker". **Every module is covered by all three engines of its family.**

### Concurrency family (TLA+ / Promela)

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

Conflating these is how a coverage number becomes dishonest. **57 of 85 sections are not
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
| `EXTENSION-*` protocols | continuation, subscription, compute, role, identity | **hard-gated**: not in `spec-data/`. Modeling from changelog mentions would violate the model-against-vendored-spec discipline. |

---

## 6. The limits and bounds of every result

The precise ceiling on each claim. Nothing here is hidden in a footnote elsewhere.

| Result class | Exact bound | What that excludes |
|---|---|---|
| TLC safety | 2 peers; 3–4 concurrent requests; 3 store keys; 3 dispatch slots | a defect first appearing at 3+ peers or 5+ requests |
| TLC liveness | same, and `Store` liveness runs at `NReq = 3` where safety runs at 4 | TLC's liveness graph exhausts the 2 GB cap at 4 — stated in both cfg headers |
| Spin | same bounds, independent encoding; `-DNFAIR=3` for 8-process fairness | same as TLC; Spin adds independence, not reach |
| Apalache | **unbounded in steps**, over the module's fixed peer/request set | not unbounded in *peers* — `Peers = {A,B}` is fixed, as in every module |
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
- **Known and open:** `Register`'s correct-model atomicity is near-tautological; it has teeth
  on the control side only. This is the last one.
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
```

`make matrix` asks three questions, and passing all three is what the numbers in
`docs/STATUS.md` refer to:

1. **green** — does every modeled property hold?
2. **negative controls** — could it have failed? Every control *must* fail; a green control
   is a build failure.
3. **witnesses** — does the model reach an interesting state at all? Every witness *must* be
   violated; a clean witness is a build failure.

Per-engine: `make -C tla matrix`, `make -C spin green && make -C spin neg`,
`make -C tamarin matrix`. Run the three **serially** — concurrent `:Z` bind-mount relabels
race on SELinux hosts.

---

*Scorecard of proven-vs-modeled per property: `docs/PROPERTIES.md`. Where this repo sits
among the other assurance layers: `docs/ASSURANCE-MAP.md`. Cross-check detail:
`docs/CROSSCHECK-RESULTS.md`. Current state and backlog: `docs/STATUS.md`.*
