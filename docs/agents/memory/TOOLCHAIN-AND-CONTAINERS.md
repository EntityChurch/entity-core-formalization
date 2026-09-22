# Toolchain and containers — the failures that read like model failures

**Symptom that brings you here:** Apalache dies mid-sweep with `Configuration error: Could
not find or create directory`; a container survives a `timeout`; Tamarin complains about
its rewriting backend; or a run is killed at the memory cap and you want to know whether
that is the model or the envelope.

The operative rules are in `AGENTS.md` §Setup. This file is why each one is the rule.

## The bind-mount relabel flag — `:z` on shared directories, `:Z` only on private ones

Uppercase `:Z` relabels a volume *private to one container*, so on a directory shared by
two images the second image's relabel invalidates the first's. Apalache then dies
mid-sweep with `Configuration error: Could not find or create directory`, **which reads
like a model failure and is not one.**

Shared here: `tla/` (TLC + Apalache) and `tamarin/` (ProVerif + Tamarin) — both `:z`.
Private: `spin/` — `:Z`.

*This line said "bind mounts use `:Z`" until 2026-08-30, and `tla/Makefile` carried "drop
to `:z` if shared across containers" directly above a `:Z` that had been shared since
Apalache was added.*

## Serial execution — the rule survived, its reason did not

Run the three toolchains serially. **The reason given used to be "concurrent `:Z` relabel
races cause transient file-not-found"** — that was a symptom of the shared-mount flag bug
above, now fixed. Serial execution remains the rule for **resource-cap** reasons only.

D14's fifth instance was earned on exactly this correction: the fix reached the two
`MOUNT` lines and left the retracted *reason* standing in five places, including
`docs/CROSSCHECK-RESULTS.md`'s copy-pasteable reproduce command, which handed a reader
`-v "$PWD":/work:Z` on the exact directory and image the bug involved. **A corrected
defect survives longest in a command a reader runs.**

## Hung containers

`RevokeMech.spthy` is genuinely non-terminating and is excluded from `make matrix` by
design. Reclaim a hung container with `podman kill` — **a `timeout podman run` only kills
the client, not the detached container.**

## Resource caps

`caps.mk`, included by the root and sub-Makefiles. `CAP_MEM=2g` with `CAP_SWAP ==
CAP_MEM`, so the container is OOM-killed cleanly at the cap instead of dragging the host
into swap-thrash. `caps.local.mk` is gitignored for per-host overrides.

An OOM kill at the cap is usually an encoding problem, not a size problem — see
`APALACHE-ENCODING.md`.

## Maude

Maude 3.4 is Tamarin's required rewriting backend and is pinned via a Tamarin-blessed
prebuilt binary in `tamarin/Containerfile.tamarin`. **apt's 3.2 is too old.**

## The lean tier's run count is hand-maintained, and its prose has been wrong

`make lean` needs the keystone sibling checkout, so it is **excluded from `make matrix`**
rather than skipped inside it, and its runs are outside `runcount`'s `DERIVATION` by
construction.

⛔ *Three live sites said the lean tier's runs are counted separately from **"the 277"** —
`AGENTS.md`, `docs/PROPERTIES.md`, `docs/STATUS.md` — with `make runcount` green at all
eight of its declared sites throughout, while the total went 277 → 641. Nothing was
mis-derived and no matcher was wrong: the gate reads the canonical phrasing (`**N-run**
matrix`), and "separately from the 277" is a **paraphrase with the number embedded as a
definite noun**, which no declared-site list can reach.* All three now name `make
matrix`'s total as a subject and let the gate own the value. The full account, including
the two candidate gates that were measured and rejected, is in
`docs/DISCIPLINE-CHARTER.md` (D15, fifth shape).

**`leanproof` grades THEIR proofs; `leanlemma` grades OURS** (`lean/lemmas/`, built inside
a copy of their tree against their own definitions) — two claims about two trees,
deliberately two targets, so a typo of ours cannot redden the gate whose only job is
reporting movement in a tree we do not control.
