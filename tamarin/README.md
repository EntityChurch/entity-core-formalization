# Spike B — Tamarin / ProVerif (de-risk spike)

**Goal:** find out whether an active-attacker unforgeability proof on a minimal
cap-chain fragment closes **automatically** or needs heavy hand-holding. This spike
exists to *price the proof-termination curve* before anyone commits to a full model.
Expect it to be harder than Spike A — that's the point.

## Setup — make + podman only (no host installs)

**Build discipline: all toolchains run in podman, driven by `make`.** Neither prover
is installed on the host (confirmed absent), and both have notoriously fiddly installs
(Tamarin: GHC/Haskell-stack + Maude; ProVerif: OCaml/opam). Both live in the
`entity-tamarin` image (`Containerfile`) and are invoked via `Makefile` targets — the
host stays clean and the toolchain version is reproducible.

```
make image                      # build the entity-tamarin image (Spike-B kickoff)
make smoke                      # gate zero: both provers resolve in the container
make proverif THEORY=Unforge    # ProVerif on Unforge.pv (lead — more automated)
make tamarin  THEORY=Unforge    # Tamarin auto-prove on Unforge.spthy (fallback/compare)
make tamarin-interactive THEORY=Unforge   # hand-guided proof when auto-prove stalls
```

Run both on the same fragment; report which closes our lemma cleaner. **Both images are
built and proven** (`entity-proverif` = opam 2.05; `entity-tamarin` = pinned 1.12.0
prebuilt binary + Maude). Spike B is **complete**: both tools close the unforgeability
lemma automatically and agree, and both find the attack in the negative control — see
`FORMALIZATION-REPORT.md`.

## The modeling target — capability unforgeability

Source: `../spec-data/v0.8.0/ENTITY-CORE-PROTOCOL.md` §5 (capability: §5.4 pattern
match, §5.5 chain verification + root-granter-local, §5.5a granter-frame
canonicalization, §5.6 attenuation) + §7.3/§7.4 (signatures) + §1.5 (peer-id).

**Model (smallest faithful fragment):**
- Rules: **issuance** (an honest granter signs a cap for a grantee), **delegation**
  (attenuate + re-sign down a chain), **verify** (the acceptance predicate:
  signatures valid + chain linked + root granter = the verifier's peer).
- Crypto: symbolic `sign`/`verify` function symbols with the standard equational
  theory — this **is** our wall-#1 trust boundary, so no fidelity loss.
- Adversary: the built-in Dolev-Yao network attacker (intercept/inject/replay).

**The lemma (state exactly one for the spike):**
- *Unforgeability:* there is no trace in which the verifier accepts a cap chain
  rooted at an honest peer P, where P never issued/delegated that authority. I.e.
  acceptance implies a genuine delegation path from P.

## Go/no-go gate (what the report must answer)

1. Does ProVerif and/or Tamarin **prove the lemma automatically**, or does it need
   source/reuse lemmas + interactive guidance? (This is the cost driver for Phase 1.)
2. Which tool was cleaner on our fragment — and did ProVerif report any *false*
   attacks (over-approximation) that Tamarin resolved?
3. How faithful is the fragment to §5.5/§5.5a/§5.6 (cite section numbers in comments)?
4. Recommendation: is a full attacker model (replay/reflection/escalation/
   confused-deputy lemmas) a days, weeks, or months effort — and is it worth it?

**Stretch (only if the base lemma closes fast):** add a *no-escalation* lemma (a
delegated cap can never verify for authority beyond its grant — the symbolic mirror
of Lean's `isAttenuated_trans`) and a *no-replay* lemma. Don't reach for these until
unforgeability closes.

Write the result to a `FORMALIZATION-REPORT`-style note in this directory.
