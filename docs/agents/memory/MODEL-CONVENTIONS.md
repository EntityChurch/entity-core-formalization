# Model conventions — citations, globs, and the track registry

**Symptom that brings you here:** you are about to write a model file, cite a spec section
from inside one, move model files into a subdirectory, or promote a track — and you want
to know which of those silently changes a published number.

The operative rules are in `AGENTS.md` §Proof tracks. This file is the evidence behind
them; every one was a gate going green while asserting less than it said.

## The `§N.M` citation pattern is document-blind

`EXTENSION-ATTESTATION §5.7` and core `§5.7` are the same token, and core already has that
row — so extension citations would have been absorbed into a **core** coverage claim with
`make coverage` green.

Hence the rule: a bare `§N.M` means a section of **your own track's** `primary_spec`; a
cross-track reference writes the sigil first (**`§CORE:6.2`** inside an attestation model)
and is excluded from every track's coverage set.

**The sigil-first order is a bug fix, not a style call.** The draft form `CORE §6.2`
matched **23 lines of ordinary prose** (`WHAT §6.9 SAYS`, `LIVENESS §4.1`, `THE §5.8`,
every Spin `-D` macro name) and then excluded each from that line's citation set: a guard
against citations being *miscredited* that silently **dropped** them. `§` followed by a
digit cannot collide. *Reading the regex did not catch it; running it did.*

## The file globs were non-recursive

`tla/*.tla` does not reach `tla/attestation/`. Moving models into per-track subdirectories
would have hidden them from `coverage` and `specdrift` **while both stayed green.**
`trackcheck` walks recursively and cross-checks against git, which is why per-track
subdirectories are a later step, deliberately taken *after* the gate exists.

Related, same mechanism, opposite direction: `tla/*.tla` also matches the hundreds of
gitignored `_TTrace_` specs TLC drops beside the real ones, so `spec-drift` published
**"15/1169 model files"** for a release. It is 15/24.

## A gate whose input set has gone empty has stopped asserting

**With `identity` promoted, the `scoped` gate has no subject.** It fired as designed twice
— `quorum` on 2026-09-07 and `identity` the same day, each forced to write its
`MODELING-PIN-*` before a model file could be declared — and it now asserts nothing about
the live registry, because there is nothing left in that state. Its teeth-test lives in
`tools/trackcheck.py`'s own test path, not in `TRACKS.toml`.

Every other instance of this mechanism was an input set silently **narrowed**. This one
went to **zero**, by an ordinary and correct addition elsewhere, and nothing failed. **Ask
of a gate not only "what is in its input set" but "can that set become empty, and would
anything say so."** Recorded before the fifth track is scoped, not after.

## `scoped` is gated, not decorative

A scoped track must have no models and no pin, so adding a model file fails until the
track is promoted **with** a pin. That promotion is where someone says which snapshot the
results are about, and it is not skippable by adding a file.

## `model_pins` is a dimension of the registry, so every gate reading `models` is a site

`[track.<name>.model_pins]` lets a single model transcribe a newer snapshot than its
track's pin. When it was added, `coverage-check.py` was written with the partition and
`obligations.py` — two days older, and the tool whose whole reason to exist is a
denominator that is **not** ours — was not. So it went on counting §4.7's *pin*
obligations as "inside a section a model cites" for a day after `make coverage` had
removed §4.7 from Matrix A and said out loud that nothing verifies it as the pin states
it. Two gates over one artifact, one excluding off-pin citations and one including them,
both green, published one paragraph apart.

**When you add a field to `TRACKS.toml`, grep `tools/` for `["models"]` before you add the
first row.**

Two rules came with the mechanism, both learned in the hour it was built:

1. **Retarget a whole SUBJECT, never one file.** `docs/CORROBORATION.md` credits
   `conncodes` to three engines; three engines on three different texts is one reading per
   snapshot presented as agreement, which is worse than one engine honestly scoped.
2. **Expect the coverage number to fall and do not argue with it.** Retargeting removed
   §4.7 and §5.2a from core's pair, so it fell — and that is the true statement: nothing
   now verifies those sections *as the pin states them*. The rejected alternative was a
   paragraph in each module header, which would have left the old number standing and made
   it false.
