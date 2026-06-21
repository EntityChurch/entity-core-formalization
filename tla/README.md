# Spike A — TLA+ (lead spike)

**Goal:** in days, not weeks — model ONE concurrency slice, state one safety + one
liveness property, run TLC, report the go/no-go. The lead spike because setup is
near-zero and the odds of a fast real result are highest.

## Setup — make + podman only (no host Java, no loose jar)

**Build discipline: all toolchains run in podman, driven by `make`.** The JRE +
`tla2tools.jar` are baked into the `entity-tla` image (`Containerfile`) and invoked
via `Makefile` targets — the host's `java` is never used and no jar is downloaded by
hand. This keeps the toolchain version inside the reproducibility envelope (mirrors
the `spec-data/` SHA-pin discipline).

```
# from this directory
make image     # build the entity-tla podman image (baked JRE + pinned tla2tools v1.8.0)
make smoke     # gate zero: containerized TLC runs (TLC -help)
```

Then the model loop (defaults to SPEC=Reentry; override with SPEC=<Module>):
```
make translate SPEC=Reentry   # PlusCal → TLA+ (pcal.trans, writes back through the mount)
make sany      SPEC=Reentry   # parse/typecheck only (fast feedback)
make tlc       SPEC=Reentry   # model-check against Reentry.cfg
make check     SPEC=Reentry   # translate + tlc
make repl                     # shell into the toolchain container
make clean                    # remove TLA+ scratch artifacts
```

**Toolchain proven:** `make image`/`smoke`/`translate`/`tlc` all green
end-to-end; a negative-control check confirmed TLC emits a full counterexample trace
on a violated invariant — the "model finds the bug" mechanism this spike depends on.
`tla2tools.jar` and TLC scratch are gitignored (never commit binaries). The TLA+
Toolbox GUI is optional; command-line TLC via `make` is enough for the spike.

## The modeling target — §6.11 reentry

Source: `../spec-data/v0.8.0/ENTITY-CORE-PROTOCOL.md` §6.11 (handler-initiated
outbound dispatch / reentry) + §4.8 (store-safety) + §4.9 (resilience under load).
Background: the deadlock surface is catalogued as **Class G** in V7 §6.11's rationale
("transports that serialize per-connection deadlock under bidirectional symmetric
load"); the sustained-load store-leak/runaway is the §7b-gate bug class hit
empirically during the Lean build.

**Model (smallest faithful slice):**
- 2 peers, each with an inbox + one pooled connection.
- A request from A to B; B's handler dispatches an outbound request back to A over
  the same pooled connection (the reentry).
- The store as an abstract map; writes bounded by live keys.
- Cap-verify = an **abstract operator** returning a Boolean. **Do NOT model §5.4/§5.6
  attenuation — Lean owns that.** The point is the protocol *around* the verdict.

**Properties (state exactly one of each for the spike):**
- *Safety:* `StoreBounded` — store size never exceeds the number of live keys
  (surfaces the leak class); and/or `NoDispatchWithoutGate` — no request is
  delivered to a handler without the gate predicate having held.
- *Liveness:* `EventuallyResolved` — every accepted request eventually reaches a
  response or a clean failure (no deadlock, no livelock). Needs a weak-fairness
  condition on the dispatch/serve step.

## Go/no-go gate (what the report must answer)

1. Did TLC check the safety invariant green at a 2–3 peer bound — or produce a
   **real counterexample trace**? (A counterexample that matches the known Class-G
   deadlock / runaway is the *success* outcome — "the model found the bug.")
2. Did the liveness property check (with fairness), or expose a livelock?
3. How painful was the modeling (hours? days?) and is the model–code gap acceptable
   at this altitude?
4. Recommendation: proceed to a Phase-1 comprehensive concurrency model, or stop.

Write the result to a `FORMALIZATION-REPORT`-style note in this directory
(properties / counterexamples / scope / on-ramp pain / recommendation).
