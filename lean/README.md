# The Lean seam tier — do the proofs this repo leans on still hold?

This directory holds **no Lean source**, and that is deliberate.

Eleven rows of `docs/LEAN-SEAM.md` say that an abstraction in one of our models — the
capability-chain verdict as an opaque predicate in TLA+, `narrow` as a free function symbol
in Tamarin — is sound because the **Lean authority proof in the `entity-core-keystone`
peer** discharges the proposition the model assumes. **Ten of the eleven cite a named
theorem** (nine rows CLOSED, two CLOSED-MODULO-H; the eleventh, L2, is closed by
construction — Lean's termination checker, no theorem to run). Those rows are what make the
division of labour between this repo and the Lean proof more than prose.

They rest on the Lean side being sound. This tier is what checks that it is.

```
make lean            # the whole tier: text unmoved + proofs hold + controls catch
make lean-image      # build entity-lean (the one network step)
make leanproof       # green: 1 run
make leanproof-neg   # the five negative controls
make leanseam        # the older half: has the cited TEXT moved? (host python3 only)
```

## What was here before, and what was missing

`make leanseam` pins every cited Lean file by sha256 and every cited theorem by name, and
fails when one moves. It answers **"is the ledger still about the current text?"**

It cannot answer **"does that text still prove what the ledger says it proves"** — and
nothing else did either. In the keystone peer, `lake build EntityCoreProofs` is called *the
proof check* in five places — the lakefile ("a `sorry` or failed proof fails the build"), the
proof-library root, the peer profile's testing contract and two status documents. It is
invoked by **no Makefile, script or CI workflow in that tree** — which has no CI directory
at all (exhaustive search, 2026-08-30). The proofs our ledger cites were checked when they were
written and by nothing since.

So the seam had a gate on the *text* and none on the *content*.

## What the gate asserts — and what else would satisfy it

The house rule (`AGENTS.md` D13) is that a gate must assert the outcome it claims, not a
symptom of it, and that the question *"what else satisfies this?"* is answered by
**building the alternatives**, not by reasoning about them. All four were built:

| variant | what it does | `lake build` says |
|---|---|---|
| green | keystone's proofs, unmodified | exit 0, `Build completed successfully` |
| `neg-sorry` | a `sorry` in a cited theorem | **exit 0, `Build completed successfully`** |
| `neg-axiom` | an `axiom` standing in for the proof | **exit 0, and no warning at all** |
| `neg-broken` | a proof that does not type-check | exit 1 |

**A `sorry` is a warning in Lean, not an error.** Lake prints the same success line and
returns the same status as a clean build. So the lakefile's claim is false as written, and
an exit-status gate — had one existed — would have caught one failure mode out of three,
missing exactly the two a proof check is for.

The assertion is therefore made against the **axiom sets**. Every declaration in the peer's
proof track sits under a `#print axioms` honesty gate; `lean/proof-gate.expect` declares
what each of those 37 gates must report, and the run must produce exactly that set — no
more, no less, in both directions. Concretely, `make leanproof` asserts:

1. **Toolchain.** The Lean version the image resolves equals the one keystone's own
   `lean-toolchain` pins. Verifying with a different compiler than the peer ships is not
   verifying the peer.
2. **Build.** Exit 0, no `error:` line, and the positive completion line present.
3. **Axiom sets.** Every gated declaration reports a subset of Lean's three standard axioms
   (`propext`, `Classical.choice`, `Quot.sound`) **and** exactly its declared set. `sorryAx`
   or a hand-written `axiom` is a failure; so is a gate that appears, disappears, or changes.
4. **The ledger tie.** Every theorem `docs/LEAN-SEAM.md` pins — including the one pinned as a
   *rejected* correspondence — is among the declarations that reported.
5. **Warnings.** A Lean warning fails the build unless declared in `proof-gate.expect` with
   an owner. One is declared today (a deprecated stdlib call in the shipping peer), and it
   is routed to keystone rather than tolerated.

Two of the five controls are about silencing the gate rather than breaking a proof.
`neg-ungate` deletes a `#print axioms` line — the move that beats any grader built on
`grep -c sorryAx`, since no gate line means no `sorryAx` to find. `neg-dropfile` drops a
whole proof file from the library root: it builds clean, gates nothing, and — the reason it
needs its own control — produces **no** `LEDGER_UNCOVERED`, because the file it drops
carries no ledger row. Both fail because the *names* are declared, which is the same rule
the prover tables carry: an undeclared gate is an ungraded gate.

And each control is graded on **which** declarations carry each failure, not how many. The
first draft declared counts (`SORRY_AX`×3); a count cannot distinguish the three
declarations we contaminated from three others, which is the mistake this repo has already
paid for on its Tamarin controls. Caught in the session audit and corrected.

## What it does not assert

**That any correspondence in the ledger is correct.** That a Lean theorem, proved, is the
proposition our model assumes is a human reading of two texts (`docs/LEAN-SEAM.md` §1), and
this gate can no more check it than `make leanseam` can. Read together the two say: *the
cited text has not moved, and what it says is proved with no hole in it.* Whether it is the
**right** theorem for the row is still a claim a person made.

It also says nothing about the rest of the Lean peer — the shipping `EntityCore` library,
the conformance harness, the transport — only the proof track, which is the only part the
seam cites.

## Why the source is not vendored here

A fork would make the ledger a statement about **our copy**, which nothing gates, rather
than about the peer that ships and that the conformance suite runs. The whole value of the
seam is that the theorems are about that code. So keystone's tree is mounted **read-only**,
copied into `_work/<variant>/` (gitignored), and built there; a gate run cannot write into
the sibling repo. The negative controls mutate the scratch copy, and each is pinned to an
exact anchor in the source — if that text changes, the control refuses to apply and says so
rather than quietly mutating something else.

## Why it is not in `make matrix`

`make matrix` must run on a bare clone with only `make` + `podman`. This tier needs a
keystone checkout that a fresh clone does not have. A gate folded into the matrix that
*skips* when its input is absent asserts nothing — the precise failure D13 exists to
remove — so this one **fails loudly** on a missing sibling and lives at `make lean`. The
matrix run count (258) is deliberately not inflated by these 6 runs, because they are not
reproducible from a bare clone and every published number here has to be.
