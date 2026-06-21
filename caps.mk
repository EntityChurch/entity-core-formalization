# ============================================================================
# Podman resource caps — entity-systems standard
# (see [internal] docs/release-readiness/RESOURCE-CAPS.md).
#
# Shared by the root Makefile AND every per-engine Makefile (tla/, spin/,
# tamarin/) so EVERY podman build/run in this repo carries a hard ceiling and a
# runaway model-checker (Spin/Apalache/Tamarin can otherwise grab a large share
# of host RAM via the JVM/SMT/Haskell heaps) dies cleanly at the cap instead of
# thrashing the host into a freeze.
#
# Tune the COMMITTED defaults below for THIS project; override per-machine
# WITHOUT editing this file via env vars or an untracked caps.local.mk.
#
#   Precedence (highest first):  env var  >  caps.local.mk  >  defaults below
#   CAP_SWAP == CAP_MEM  =>  zero swap: the container is OOM-killed cleanly at
#   the cap instead of dragging the host into swap-thrash.
#
# Sizing (measured on Fedora 43, podman 5.8.2 — see RELEASE-READINESS.md):
#   heaviest CHECK   peak RSS ~ 0.40 GB  (Apalache/Z3 inductive step)
#   heaviest BUILD   peak RSS ~ 0.92 GB  (ProVerif opam/OCaml compile)
#   committed CAP_MEM = 2g: covers the 0.92 GB build with headroom for brief
#   linker/parallel spikes, ~5x the heaviest check, and still OOM-kills a runaway
#   JVM/Z3/Haskell heap (which could otherwise grab >12 GB of host RAM) cleanly.
# ============================================================================

# untracked per-machine overrides, always resolved next to THIS file (repo root)
# regardless of which Makefile includes it or the working directory.
CAPS_LOCAL := $(dir $(lastword $(MAKEFILE_LIST)))caps.local.mk
-include $(CAPS_LOCAL)

CAP_MEM           ?= 2g         # hard memory ceiling per container (build + run)
CAP_SWAP          ?= $(CAP_MEM) # keep == CAP_MEM (no swap); raise only deliberately
CAP_PIDS          ?= 2048       # max procs/threads (RUN only) — stops fork bombs
CAP_CPUS          ?= 4          # CPU cores at runtime (RUN only; fractional ok)
CAP_CGROUP_PARENT ?=            # optional host slice to nest under, e.g. dev-heavy.slice

_cap_cgp := $(if $(strip $(CAP_CGROUP_PARENT)),--cgroup-parent=$(CAP_CGROUP_PARENT),)

# podman BUILD accepts --memory/--memory-swap/--cgroup-parent (NOT --cpus/--pids-limit)
PODMAN_BUILD_CAPS := --memory=$(CAP_MEM) --memory-swap=$(CAP_SWAP) $(_cap_cgp)
# podman RUN accepts the full set
PODMAN_RUN_CAPS   := --memory=$(CAP_MEM) --memory-swap=$(CAP_SWAP) \
                     --pids-limit=$(CAP_PIDS) --cpus=$(CAP_CPUS) $(_cap_cgp)
