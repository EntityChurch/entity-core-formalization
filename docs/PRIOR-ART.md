# Prior art + learning resources

Curated starting points so the spike team isn't climbing the curve from zero. Pull
the ones that match our fragments; don't read exhaustively.

## TLA+ (Spike A)

**Learn:**
- Lamport's *TLA+ Video Course* + *Specifying Systems* (the book, free PDF) — the
  canonical on-ramp. Watch the first ~5 lectures before modeling.
- *Learn TLA+* (learntla.com) — PlusCal-first, practical, fastest path to a running
  TLC check. Start here for the spike.
- *Practical TLA+* (Hillel Wayne) — concurrency + liveness examples close to ours.

**Industrial precedent (same use case — concurrent/distributed correctness):**
- AWS used TLA+ on S3, DynamoDB, EBS — the "Use of Formal Methods at Amazon"
  paper is the reference for "model-checking found real bugs at the design level."
- Azure Cosmos DB (consistency levels), MongoDB (Raft / replication) — both public.

**For our model specifically:**
- Model the §6.11 reentry as a small message-passing state machine. The canonical
  shape is two processes sharing a resource (the pooled connection) with a request
  that reenters — this is structurally the classic deadlock example. Liveness via a
  weak-fairness condition on the dispatch step.
- Keep cap-verify abstract (a TLA+ operator returning a Boolean over the modeled
  state). Do not model §5.4/§5.6 — Lean owns that.

## Tamarin / ProVerif (Spike B)

**Learn:**
- Tamarin Prover manual (tamarin-prover.github.io) — the multiset-rewriting model +
  the lemma language. Read the "first example" + "modeling" chapters.
- ProVerif manual (Blanchet) — applied-pi-calculus surface, often more automated.
- Bruno Blanchet's survey on symbolic protocol verification — frames the
  Dolev-Yao model and the auto-vs-interactive trade-off.

**Comparable protocol models to borrow structure from:**
- **TLS 1.3** — the canonical large Tamarin model (Cremers et al.); the reference
  for authentication + secrecy lemmas at scale.
- **Noise Protocol Framework** — smaller, cleaner, closer to a from-scratch model.
- **5G-AKA, EMV** — Tamarin; **OAuth, Kerberos** — have ProVerif/Tamarin models
  (the authorization-flow angle).
- **Authorization-logic angle:** SPKI/SDSI and **macaroons** — delegated-authority /
  capability-attenuation reasoning, the closest conceptual match to V7's cap chains.

**For our model specifically:**
- Issuance rule (granter signs a cap for a grantee), delegation rule (attenuate +
  re-sign), verify rule (the predicate). Adversary gets the built-in network
  control. The unforgeability lemma: no trace where the verifier accepts a chain
  rooted at an honest peer that the honest peer never issued/delegated.
- Symbolic sign/verify as function symbols with the standard equational theory —
  this IS our crypto trust boundary, so no fidelity loss there.

## Cross-cutting

- Both tools verify a **model**. The art is choosing the altitude: high enough to be
  tractable, faithful enough that the result means something about V7. The vendored
  `spec-data/v0.8.0/` is the fidelity anchor — cite spec section numbers in the model
  comments so a reviewer can check the transcription.
