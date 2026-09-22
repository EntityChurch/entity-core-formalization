# Attestation Extension — Normative Specification

**Version**: 1.3

**Status**: Active
**Depends**: ENTITY-CORE-PROTOCOL.md (v7.40+)
**Related**: EXTENSION-QUORUM.md (consumes; quorum self-events are attestations); EXTENSION-IDENTITY.md (consumes; identity certs are attestations); future consumers — group, VC, reputation, provenance, cluster, transaction, governance, audit
**Synthesis**: SYSTEM-IDENTITY-COMPOSITION.md (single-entry-point overview of the three-extension layering); EXPLORATION-IDENTITY-LENSES-AND-CONVERGENCE.md §4a.13–§4a.15 (the design path)

---

> **Path notation.** Paths in this document use peer-relative notation (without leading `/{peer_id}/`). All peer-relative paths resolve to the local peer's namespace. See `ENTITY-CORE-PROTOCOL.md` §1.4 for the path model.

---

## 1. Overview

The attestation primitive — "Peer A asserts that B has property X" — is the **edge type in the system's signed graph**. Hash-addressable entities form nodes; signed claims (attestations) form edges. Generic graph operations (single-sig validation, supersedes walking, liveness checks, revocation lookups, attesting-chain walks with consumer-supplied terminate predicates) live in this primitive. Consumer extensions add semantic interpretation via `properties.kind` conventions, topology rules, storage paths, and lifecycle semantics.

This extension defines:

- One entity type: `system/attestation` (the edge in the signed graph).
- Two signature-validation helpers: `verify_attestation_signature` (default single-sig), `verify_specific_signer` (consumers compose for multi-sig topologies).
- One composite liveness check: `is_attestation_live` (expiration + supersession + self-revocation; `as_of?` parameter for time-traveling validation).
- Six graph operations (parameterized): `walk_attesting_chain` (with normative `default_find_authorizing`), `walk_supersedes_chain`, `find_live_head`, `find_attestations_targeting`, `find_attestations_by`, `find_revocations_for`.
- Four handler operations: `system/attestation:create`, `:supersede`, `:revoke`, `:verify`.
- One universal `properties.kind` value: `"revocation"`. All other kinds belong to consumer extensions.
- Index invariants on `attesting`, `attested`, and `properties.kind` fields.

This extension does **not** define:
- Storage path conventions (consumers choose).
- K-of-N multi-sig validation (lives in `EXTENSION-QUORUM.md`).
- Cap-layer multi-sig validation (lives in V7's `verify_capability_chain` via `system/capability/multi-granter`).
- Authority-revocation rules (consumer-specific; primitive provides the lookup; consumer applies the rule).
- Trust framework semantics (deferred; concrete demand has not emerged).

---

## 2. The principle

The system is fundamentally a **signed-graph substrate**. Hash-addressable entities form nodes; signed claims form edges. K-of-N consensus (quorum) is a special node type. Identity, group, VC, reputation, provenance, cluster, transaction, governance, audit — all are conventions for using this substrate.

**Attestations form the edge type.** A `system/attestation` entity is an edge from `attesting` (signer) to `attested` (subject) with a `properties` payload describing the claim. The data shape is universal; the semantic interpretation is consumer-specific.

**Generic graph operations live in this primitive.** Walking via `attesting`, walking via `supersedes`, finding revocations, checking liveness — these are mechanical operations any consumer needs. By providing them as parameterized operations (predicate-supplied where interpretation matters), the primitive stays unopinionated while being rich enough that consumers don't reimplement.

**Consumer extensions add semantic interpretation.** They define their own `properties.kind` values, their own validation rules (topology requirements, authority rules), their own storage paths, their own lifecycle semantics. They call into the attestation primitive's helpers for the mechanics.

### 2.1 Layering against multi-sig (informative)

Three structurally distinct entity-validation paths exist in the system; they share signature-counting at a low level but maintain type-level distinction:

- **Multi-sig core (cap layer):** K-of-N at the cap-issuance layer; root caps with polymorphic `granter` of `system/capability/multi-granter` shape; lives inside V7's `verify_capability_chain`.
- **EXTENSION-QUORUM (entity layer):** K-of-N over an attestation entity's `content_hash`; lives in EXTENSION-QUORUM's `verify_k_of_n_signatures`.
- **EXTENSION-ATTESTATION (this primitive):** the substrate that supports both — provides `verify_specific_signer` (used by quorum to count K-of-N over an attestation entity) and the data shape (`system/attestation`) that quorum's self-events use.

**Three-parallel-mechanisms invariant.** Three structurally distinct entity types — V7 capability tokens (validated by `verify_capability_chain`, includes multi-sig caps), `system/attestation` entities (validated by helpers in §4 + consumer rules), `system/quorum` entities (validated by `verify_k_of_n_signatures`). No shared validator. Implementations MUST NOT attempt to unify multi-sig cap validation with quorum's K-of-N validation at the spec layer; future refactor opportunity exists for sharing the underlying signature-counting helper, but the type-level distinction MUST be preserved.

---

## 3. Type definition

### 3.1 `system/attestation`

The signed-claim entity. The edge in the system's signed graph.

```
system/attestation := {
  fields: {
    attesting:   {type_ref: "system/hash"}
                                                  ; who's making the claim (peer hash;
                                                  ; or quorum hash for K-of-N attestations
                                                  ; — the consumer applies the K-of-N rule)
    attested:    {type_ref: "system/hash"}
                                                  ; what's being claimed about (any
                                                  ; hash-addressable entity: peer, quorum,
                                                  ; content, service, software binary, ...)
    properties:  {map_of: {type_ref: "primitive/any"}}
                                                  ; claim payload; consumer-defined shape
                                                  ; (recommended: include `kind` key for
                                                  ; consumer dispatch — see §3.2)
    supersedes:  {type_ref: "system/hash", optional: true}
                                                  ; previous attestation this one supersedes
                                                  ; (forms a chain; per-consumer keying rules)
    not_before:  {type_ref: "primitive/uint", optional: true}
                                                  ; epoch ms; attestation invalid before
    expires_at:  {type_ref: "primitive/uint", optional: true}
                                                  ; epoch ms; attestation invalid after
  }
}
```

The attestation entity is signed (single-sig by `attesting` per default validation; or multi-sig per consumer rules — see §4).

### 3.2 The `properties` map and `kind` convention

`properties` is a consumer-extensible map. The attestation primitive doesn't interpret keys.

**Strongly recommended convention: include a `kind` key** that consumers use to dispatch interpretation.

**`properties.kind` is an OPEN VOCABULARY.** EXTENSION-ATTESTATION does not enumerate valid `kind` values. Each consumer extension defines its own set of kinds in its own spec, along with:

- The required `properties` shape for each kind it defines
- The signature topology that kind requires (single-sig, K-of-N, dual-sig, etc.)
- The storage path convention for attestations of that kind
- The handler operations to produce attestations of that kind

The only kind EXTENSION-ATTESTATION defines itself is `"revocation"` (per §3.3) — it's the universal mechanism for revoking an attestation, generic enough to live in the primitive. All other kinds belong to consumer extensions.

**Kind ownership table (current and known-future consumers):**

| Kind | Owned by | Spec section |
|---|---|---|
| `"revocation"` | EXTENSION-ATTESTATION | This spec §3.3 |
| `"quorum-update"` | EXTENSION-QUORUM | EXTENSION-QUORUM.md §3.2 |
| `"quorum-publish"` | EXTENSION-QUORUM | EXTENSION-QUORUM.md §3.3 |
| `"identity-cert"` | EXTENSION-IDENTITY | EXTENSION-IDENTITY.md §4.2 |
| `"identity-rotation-handoff"` | EXTENSION-IDENTITY | EXTENSION-IDENTITY.md §4.3 |
| `"identity-rotation-recovery"` | EXTENSION-IDENTITY | EXTENSION-IDENTITY.md §4.4 |
| `"identity-retirement"` | EXTENSION-IDENTITY | EXTENSION-IDENTITY.md §4.5 |

Future extensions (VC, reputation, provenance, cluster, transaction, governance, audit) define their own kinds in their own specs.

**Within an extension's storage paths, kinds MUST be unambiguous** (the extension's validator dispatches on kind for entities at its own paths; ambiguity would break dispatch).

**Across extensions, kinds MAY collide.** Disambiguation comes from storage path (each consumer's entities live under its own path subtree) and from each consumer's validator only processing entities at its own paths. If a future extension wants `"retirement"` for its own lifecycle (different shape, different topology, stored at its own paths), the path scoping prevents conflict — the other extension's validator only sees its own retirements.

**MUST use namespaced kind names when registering in the kind-ownership table (normative).** Generic tooling (graph explorers, cross-extension dashboards, global queries) that scans `system/attestation` entities across multiple paths needs kind names that uniquely identify the owning extension. Convention: prefix the kind with the extension domain (e.g., `"identity-cert"` not `"cert"`; `"quorum-update"` not `"update"`). Kinds registered in the kind-ownership table without a namespace prefix MUST be rejected at registration. The single exception is `"revocation"` — the universal substrate kind that intentionally stays unnamespaced because it is generic across all consumers. Existing kinds in this spec stack already follow this convention.

Within-extension internal kinds (not in the kind-ownership table; not intended for cross-extension visibility) MAY use unnamespaced names. Kinds intended for cross-extension visibility — in particular kinds that consumer extensions or generic tooling outside the owning extension may dispatch on — MUST be namespaced.

**No central kind registry.** The protocol does not enforce a global kind table. Consumers coordinate naming via spec convention and by checking the kind-ownership table (above) when defining new kinds. Path-scoping is the actual correctness mechanism.

Consumers that don't follow the `kind` convention can still use the primitive (the `properties` map is unconstrained); the convention exists so consumer-internal validators can dispatch and so generic tooling can dispatch optionally.

### 3.3 Revocation as attestation

A revocation IS an attestation. There is NO separate `system/attestation-revocation` type. To revoke attestation X, produce an attestation:

```
{
  attesting:  <revoker peer hash>
  attested:   <X's content hash>
  properties: {kind: "revocation", reason: "..."}
  ...
}
```

The attestation primitive validates the signature on the revocation. Whether the revoker has authority to revoke X is consumer-specific (see §4.4).

---

## 4. Validation helpers

### 4.0 Operations the validators need (normative interface contract)

The validators in §4 and graph operations in §5 are specified as pseudocode against an abstract context `ctx`. The context is a contract surface, not a binding shape — implementations satisfy it through whatever language-specific structure fits (a context object passing references; separate parameters; a global registry; etc.). The cross-impl test vectors are keyed on tree state and inputs, not on context shape.

The contract surface is:

| Operation | Signature | Behavior |
|---|---|---|
| `ctx.content_store.get(hash)` | `hash → entity or null` | Returns the entity stored at `hash` in the content store, or null if absent. |
| `ctx.entity_tree.get(path)` | `path → entity or null` | Returns the entity bound at `path` in the local peer's tree, or null if absent. |
| `ctx.query.find_entities_by_field(type, field, value)` | `(type_name, field_name, value) → [entity]` | Returns all entities of the given type whose field matches the value, using the impl's index (per §9.1 invariants). |
| `resolve_peer(peer_hash, ctx)` | `peer_hash → peer_entity or null` | Returns the `system/peer` entity (V7's peer-keypair entity, NOT EXTENSION-IDENTITY's identity layer) for the given peer_hash, or null if absent. |
| `find_signature_by_signer(target_hash, signer_hash, ctx)` | `(target_hash, signer_hash, ctx) → signature_entity or null` | Looks up the signature at the V7 invariant pointer path; behavior pinned below. |
| `verify_signature(sig_entity, peer_entity)` | `(signature, peer) → bool` | Verifies the signature using the algorithm declared in `sig_entity.algorithm`; behavior pinned below. |

Implementations MAY expose these as a single context object (Python-style) or as separate parameters (Go-style) or via global registries (Rust-style); the contract is on input/output behavior, not on the binding shape.

**Naming disambiguation (informative).** The `system/peer` entity referenced here is V7's peer-keypair entity (the entity holding a peer's public key, defined in ENTITY-CORE-PROTOCOL.md §3.5). It is distinct from `EXTENSION-IDENTITY` (the identity-layer handler extension). The substrate has no dependency on EXTENSION-IDENTITY; signature verification operates against V7-level peer entities only.

`find_signature_by_signer` and `verify_signature` are NOT optional helpers — they are the substrate-level signature primitives that single-sig validation, dual-sig validation, and K-of-N validation all reduce to. Implementations MUST provide both with the behavior below.

```
find_signature_by_signer(target_hash, signer_hash, ctx) → signature_entity or null
  ; Looks up the signature at the V7 invariant pointer path:
  ;   /{signer_peer_id}/system/signature/{hex(target_hash)}
  ; where signer_peer_id is recovered from the system/peer entity at signer_hash
  ; (via resolve_peer).
  ; Returns null when no signature is bound at that path.

  signer_peer = resolve_peer(signer_hash, ctx)
  if signer_peer is null: return null
  signer_peer_id = signer_peer.peer_id
  path = "/" + signer_peer_id + "/system/signature/" + hex(target_hash)
  return ctx.entity_tree.get(path)

verify_signature(sig_entity, peer_entity) → bool
  ; Returns true iff sig_entity.signature is a valid signature, under the
  ; algorithm named in sig_entity.algorithm, over sig_entity.target (the
  ; content_hash bytes of the target entity), produced by the private key
  ; whose public component is in peer_entity.public_key.
  ;
  ; Returns false if sig_entity.algorithm is not supported by this peer
  ; (unknown or unregistered). Supported algorithm names correspond to
  ; key_type allocations in V7 §1.5 — e.g. "ed25519" (key_type=0x01) and
  ; "ed448" (key_type=0x02); additional algorithms register their verifier
  ; as part of their allocation.

  verifier = lookup_signature_verifier(sig_entity.algorithm)
  if verifier is null: return false
  return verifier(
    public_key = peer_entity.public_key,
    message    = sig_entity.target,
    signature  = sig_entity.signature
  )
```

### 4.1 `verify_attestation_signature` — single-sig validation

```
verify_attestation_signature(att, ctx) → bool
  ; Validates that att is signed by att.attesting.
  ; Locates the signature via V7 invariant pointer pattern:
  ;   {att.attesting}/system/signature/{att.content_hash_hex}

  sig = find_signature_by_signer(att.content_hash, att.attesting, ctx)
  if sig is null: return false
  attesting_peer = resolve_peer(att.attesting, ctx)
  if attesting_peer is null: return false
  return verify_signature(sig, attesting_peer)
```

This is the default single-sig validator. Used by consumers when the attestation's expected topology is single-sig from `attesting`.

### 4.2 `verify_specific_signer` — verify a specific signer signed

```
verify_specific_signer(att, expected_signer, ctx) → bool
  ; Verify att has a valid signature from expected_signer specifically.
  ; Used by consumers for multi-sig topologies (dual-sig, etc.) without
  ; baking multi-sig semantics into the primitive.

  sig = find_signature_by_signer(att.content_hash, expected_signer, ctx)
  if sig is null: return false
  signer_peer = resolve_peer(expected_signer, ctx)
  if signer_peer is null: return false
  return verify_signature(sig, signer_peer)
```

Identity uses this for `identity-rotation-handoff` (calls twice, once per signer in the dual-sig pair). Consumers needing K-of-N call `EXTENSION-QUORUM.verify_k_of_n_signatures` instead (which is essentially "verify K of N specific signers each signed").

### 4.3 `is_attestation_live` — composite liveness check

```
is_attestation_live(att, ctx, as_of?: uint) → bool
  ; Composite check: not expired; not superseded (transitive); not self-revoked.
  ; Optional as_of parameter (epoch ms) for time-traveling validation;
  ; defaults to current time.

  now = as_of or current_time()

  ; Expiration check
  if att.expires_at is not null and now >= att.expires_at: return false
  if att.not_before is not null and now < att.not_before: return false

  ; Supersession check (transitive)
  ; att is superseded iff any non-revoked, non-expired transitive descendant
  ; (any node reachable forward through the supersedes graph) exists.
  ; Implementations walk forward through the entire forward DAG; the bound is
  ; max_chain_depth (informative default: 256).
  if has_live_transitive_descendant(att, ctx, as_of=now): return false

  ; Self-revocation check
  ; If att.attesting issued a revocation attestation targeting att, att is dead.
  revocations = find_revocations_for(att.content_hash, ctx)
  for rev in revocations:
    if rev.attesting == att.attesting and is_attestation_live(rev, ctx, as_of=now):
      return false

  return true

has_live_transitive_descendant(att, ctx, as_of) → bool
  ; Forward walk: returns true iff any descendant of att in the supersedes
  ; graph is non-revoked AND non-expired AT as_of. Walks all branches (BFS or
  ; DFS); cycle-safe via a visited-set on content_hash.

  visited = {}
  frontier = find_attestations_with_supersedes(att.content_hash, ctx)
  while frontier is not empty:
    next = pop(frontier)
    if next.content_hash in visited: continue
    visited.add(next.content_hash)
    ; Liveness check on this descendant restricted to expiration + self-revocation
    ; (NOT recursive supersession to avoid the bistable bug).
    if not_expired(next, as_of) and not is_self_revoked(next, ctx, as_of):
      return true
    frontier.extend(find_attestations_with_supersedes(next.content_hash, ctx))
  return false
```

**Self-revocation only** in the primitive's liveness check. Authority-revocation (where a non-self peer revokes the attestation) is consumer-specific — consumers apply their own authority rules via `find_revocations_for` + their own revoker-authority predicate.

**Signature validation is not part of liveness.** `is_attestation_live` checks structural state (expiration, supersession, self-revocation). Signature validation is consumer-supplied per topology — the substrate exposes `verify_attestation_signature` (single-sig) and `verify_specific_signer` (per-signer) as helpers; consumers compose these per their topology rules. Identity's `identity_verify_cert` (per `EXTENSION-IDENTITY.md` §3.6) is the canonical example. K-of-N validation is in `EXTENSION-QUORUM.md` §4.1.

**Predecessor-revival semantics (normative).** The transitive supersession check has a designed consequence: revoking the only descendant of an attestation in a supersedes chain restores the predecessor to live state. Concretely, for chain `a0 → a1` (a1 supersedes a0): if a1 is revoked and no other descendant exists, a0 becomes live again. This is intentional. The semantics of "live" is "current authoritative version"; if the rotation that replaced a0 is itself revoked, a0 is the current authoritative version. Revocation and supersession are orthogonal signals: revocation says "this attestation is invalid"; supersession says "there's a newer version." An attestation is live iff (no live descendant supersedes it) AND (no live revocation targets it). Consumers wanting "once-superseded-stays-dead" semantics issue an explicit revocation against the predecessor at supersession time, OR use a retirement-style kind that itself stays live in the chain (identity's `identity-retirement` is the canonical example).

### 4.4 Authority-revocation pattern (for consumers)

Consumers that need authority-revocation rules layer on top:

```
# Pseudocode for a consumer:
def consumer_check_authority_revocations(att, ctx):
    revocations = ATTESTATION.find_revocations_for(att.content_hash, ctx)
    for rev in revocations:
        if not ATTESTATION.is_attestation_live(rev, ctx):
            continue
        if consumer_revoker_has_authority(rev.attesting, att, ctx):
            return REVOKED
    return OK
```

Identity says "the quorum has authority to revoke its own certs" (and walks the chain to verify); reputation might say "self-revocation only"; etc. The primitive provides the lookup; the consumer applies the rules.

---

## 5. Graph operations (parameterized)

### 5.1 `walk_attesting_chain` — chain-walk with consumer-supplied terminate predicate

```
walk_attesting_chain(
    start,
    terminate_predicate,
    ctx,
    find_authorizing_fn?: function = default_find_authorizing,
    max_depth: uint = 32
) → chain or null
  ; Walks back via attesting until terminate_predicate matches.
  ; Returns the chain [start, ..., terminating_attestation] or null if not found.
  ; max_depth bounds the walk to prevent unbounded traversal.

  chain = [start]
  current = start
  depth = 0

  while depth < max_depth:
    if terminate_predicate(current, ctx):
      return chain

    ; Find the attestation that grants authority to current.attesting.
    ; The chain link is: current is signed by current.attesting; we look up
    ; the attestation that authorizes current.attesting itself.
    parent = find_authorizing_fn(current.attesting, ctx)
    if parent is null:
      return null  ; chain doesn't terminate at predicate within max_depth

    chain.append(parent)
    current = parent
    depth += 1

  return null  ; max_depth exceeded
```

**The terminate_predicate is consumer-supplied.** Identity passes "is this attesting a quorum_id?"; reputation passes "is this in my trust root set?"; provenance passes "is this the original creator?". The primitive provides the walk mechanics; the consumer provides the termination condition.

**Termination semantics (normative).** When `terminate_predicate(current, ctx)` returns true, the chain terminates with `current` included as the last element. Concretely: `chain[-1]` IS the cert at which the predicate matched; `chain[-1].attesting` is the predicate's target value (e.g., the `quorum_id` for identity's `identity_is_quorum_link` predicate). The walker does NOT advance one further step after the predicate matches.

**The default `find_authorizing_fn` is normative.** Implementations MUST provide this default behavior; consumers MAY pass `find_authorizing_fn` to override for non-standard authorization graphs (e.g., reputation systems with transitive trust).

```
default_find_authorizing(peer_hash, ctx) → attestation or null
  ; Returns the attestation that grants authority to peer_hash within
  ; the attestation graph, or null if none exists.
  ;
  ; Algorithm (normative):
  ; 1. Find all attestations where attested == peer_hash (via the
  ;    `attested` index per §9.1).
  ; 2. Filter to those that are live (per is_attestation_live).
  ;    Note: liveness does NOT include signature validation. Consumers requiring
  ;    signature-aware authorization SHOULD pass a custom find_authorizing_fn
  ;    that layers topology-appropriate signature validation, OR validate via
  ;    the consumer's orchestration entry point (e.g., identity's
  ;    identity_verify_cert) downstream of the chain walk.
  ; 3. If none: return null.
  ; 4. If multiple: select the most recent live head of any supersedes chain
  ;    (via find_live_head); break ties deterministically by lowest content_hash.
  ; 5. Return the selected attestation.

  candidates = ATTESTATION.find_attestations_targeting(
    peer_hash,
    predicate=lambda a, _: true,
    ctx=ctx
  )
  live = [a for a in candidates if is_attestation_live(a, ctx)]
  if len(live) == 0: return null

  ; Resolve to live head per supersedes-chain semantics
  heads = []
  for a in live:
    head = find_live_head(a, ctx)
    if head is not null and head not in heads:
      heads.append(head)

  if len(heads) == 0: return null
  if len(heads) == 1: return heads[0]

  ; Multiple distinct live heads — deterministic tie-break by lowest content_hash
  return min(heads, key=lambda a: a.content_hash)
```

This default matches the cert-chain pattern (find the cert where `attested` is this peer); it's the right default for identity, group, VC issuance, and most consumers. Cross-impl behavior is pinned: Go, Python, and Rust all produce the same chain for the same input.

Consumers with non-standard graphs (transitive trust, multi-party authorization patterns) override via `find_authorizing_fn`.

**Multi-context peers note.** Consumers whose topologies do not guarantee a unique authorizing attestation per peer SHOULD provide a custom `find_authorizing_fn` that filters by consumer-specific kind/path scoping. Concretely: a peer P may be a controller in identity A AND an agent in identity B simultaneously — two unrelated live attestations target P (`A_quorum_id → P` as controller cert; `B_controller → P` as agent cert). The default tie-break (lowest content_hash) picks one deterministically, but a chain-walk starting from a downstream cert through P may then traverse the "wrong" identity's chain and fail to terminate at the expected quorum. The failure mode is detectable (the consumer's terminate predicate fails; `walk_attesting_chain` returns null and the caller surfaces e.g. `chain_to_quorum_not_found`), but the error is cryptic. Consumers expecting multi-context peers SHOULD pass a `find_authorizing_fn` that filters by their own context (e.g., identity passes a predicate restricting to attestations whose path is under the same identity's storage subtree, or whose `properties.kind` matches a specific identity-cert chain). The default behavior is correct for single-context graphs; it is not wrong for multi-context graphs but may not match consumer intent.

**Cross-impl test vectors (normative).** Implementations MUST pass the following vectors for `default_find_authorizing` to demonstrate behavior parity:

| Vector | Setup | Input | Expected output |
|---|---|---|---|
| TV-A1 | Single live attestation at peer P | peer_hash = P | The attestation |
| TV-A2 | No attestations targeting P | peer_hash = P | null |
| TV-A3 | Three live attestations targeting P, all in distinct supersedes chains | peer_hash = P | The one with lowest content_hash (deterministic tie-break) |
| TV-A4 | Three attestations forming a supersedes chain (A → A' → A''), all live | peer_hash = P (A.attested) | A'' (live head, walked via find_live_head) |
| TV-A5 | Two distinct supersedes chains: {A, A'} (A' supersedes A) and {B} | peer_hash = P (both target P) | Comparison of A' and B by content_hash; lowest wins |
| TV-A6 | Attestation A targets P; A is expired (expires_at < now) | peer_hash = P | null (A is not live) |
| TV-A7 | Attestation A targets P; self-revocation R targets A; both signed correctly | peer_hash = P | null (A is self-revoked) |
| TV-A8 | Attestation A targets P; A's signature is invalid (raw `tree:put` bypassed `:create` validation) | peer_hash = P | A (substrate is signature-agnostic; consumers layer signature validation per topology — identity's `identity_verify_cert` rejects A at topology-dispatch step) |
| TV-A9 | `as_of` parameter set to a timestamp before A's `not_before` | peer_hash = P | null (A not yet effective) |
| TV-A10 | Attestation A targets P with `properties.kind = "reputation"` (not authorization-conferring) | peer_hash = P | A (default behavior is kind-agnostic; consumer's `find_authorizing_fn` override would filter by kind if needed) |
| TV-A11 | Multi-context peer P: live attestation A1 (`attesting=A_quorum_id`, kind=`identity-cert`, function=`controller`, stored under identity A's path) AND live attestation B1 (`attesting=B_controller_keypair`, kind=`identity-cert`, function=`agent`, stored under identity B's path); both target P | peer_hash = P; default `find_authorizing_fn` | One of {A1, B1} per content_hash tie-break (deterministic); a custom `find_authorizing_fn` filtering by storage-path prefix or by `attesting`-quorum-membership returns the consumer-intended chain |

These vectors live in `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` (architecture-team-owned); each impl's test suite MUST include them.

### 5.2 `walk_supersedes_chain`

```
walk_supersedes_chain(start, ctx) → chain
  ; Walks supersedes back to oldest version.
  ; Returns chain [start, prev, prev_prev, ..., original].

  chain = [start]
  current = start
  while current.supersedes is not null:
    prev = ctx.entity_tree.get(current.supersedes)
    if prev is null: break  ; chain broken; return what we have
    chain.append(prev)
    current = prev
  return chain
```

### 5.3 `find_live_head`

```
find_live_head(start, ctx) → attestation or null
  ; Walks supersedes chain forward to find current live head.
  ; "Forward" means finding attestations that supersede this one.
  ; Returns the most recent live attestation in the chain.

  current = start
  while True:
    successors = find_attestations_with_supersedes(current.content_hash, ctx)
    live_successors = [s for s in successors if is_attestation_live(s, ctx)]
    if len(live_successors) == 0:
      return current if is_attestation_live(current, ctx) else null
    if len(live_successors) > 1:
      ; Multiple live successors — ambiguity; consumer-defined resolution
      ; Default: most recent by not_before (or by content_hash for determinism)
      current = max(live_successors, key=lambda s: (s.not_before or 0, s.content_hash))
    else:
      current = live_successors[0]
```

### 5.4 `find_attestations_targeting`

```
find_attestations_targeting(entity_hash, predicate, ctx) → [attestation]
  ; Returns all attestations where attested == entity_hash matching predicate.
  ; Predicate is consumer-supplied for filtering by properties.kind, etc.

  candidates = ctx.query.find_entities_by_field(
    type="system/attestation",
    field="attested",
    value=entity_hash
  )
  return [a for a in candidates if predicate(a, ctx)]
```

Implementation-defined how to find candidates efficiently; impls MUST maintain an index on `attested` for performance per §9.1.

### 5.5 `find_attestations_by`

```
find_attestations_by(peer_hash, predicate, ctx) → [attestation]
  ; Returns all attestations where attesting == peer_hash matching predicate.
  ; Used by consumers to find all claims a particular peer has made.

  ; Same shape as find_attestations_targeting; field is "attesting" instead.
```

### 5.6 `find_revocations_for`

```
find_revocations_for(attestation_hash, ctx) → [attestation]
  ; Returns all attestations with properties.kind == "revocation"
  ; targeting this attestation_hash.
  ; Consumer applies its own authority rules to determine which
  ; revocations are valid.

  return find_attestations_targeting(
    attestation_hash,
    predicate=lambda a, _: a.properties.get("kind") == "revocation",
    ctx=ctx
  )
```

Convenience wrapper over `find_attestations_targeting` for the common revocation-lookup case.

### 5.6a `find_attestations_with_supersedes`

```
find_attestations_with_supersedes(predecessor_hash, ctx) → [attestation]
  ; Returns all live or non-live attestations whose `supersedes` field equals
  ; predecessor_hash. Used by liveness checks and forward-chain walks
  ; (find_live_head, is_attestation_live).
  ;
  ; This is the inverse of the supersedes pointer — given an attestation,
  ; find its successors. Implemented as an indexed lookup on the
  ; `supersedes` field.

  return ctx.query.find_entities_by_field(
    type="system/attestation",
    field="supersedes",
    value=predecessor_hash
  )
```

Implementations MUST maintain an index on the `supersedes` field per §9.1 to make this lookup efficient (it's invoked recursively from `is_attestation_live`).

### 5.6b `find_attestations_with_kind`

```
find_attestations_with_kind(kind_value, ctx) → [attestation]
  ; Returns all attestations whose `properties.kind` equals kind_value.
  ; Used by generic tooling and consumers querying by kind across paths.
  ;
  ; Implemented as an indexed lookup on `properties.kind` (per §9.1).
  ; Attestations without a `kind` key are NOT returned (per I5).

  return ctx.query.find_entities_by_field(
    type="system/attestation",
    field="properties.kind",
    value=kind_value
  )
```

Convenience wrapper over the `properties.kind` index. Equivalent to scanning all `system/attestation` entities and filtering by `properties.kind == kind_value`, but uses the required index for efficiency.

### 5.7 Index invariants (normative)

Implementations MUST maintain indexes on `attesting`, `attested`, `properties.kind`, and `supersedes` per §9.1. The indexes have observable semantics that the cross-impl test suite verifies:

**I1 (Index entry presence after write).** When `system/attestation:create` (or `:supersede`, `:revoke`, or any operation that writes a `system/attestation` entity to the tree) completes successfully, the entity MUST appear in the `attesting`, `attested`, `properties.kind`, and `supersedes` indexes (the latter only when the attestation has a non-null `supersedes` field) before the next `find_attestations_*` call from the same handler invocation can return. Within a single handler invocation, write-then-read consistency is REQUIRED.

**I2 (Atomicity with handler completion).** Index updates MUST be atomic with the handler's tree write. If the handler fails (returns an error), the entity MUST NOT appear in any index. Partial-index states (entity in one index but not another) are NOT permitted.

**I3 (Cross-handler consistency).** After a handler invocation that writes an attestation completes successfully, all subsequent handler invocations on the same peer MUST see the entity in all relevant indexes. Multi-peer sync consistency is governed by V7's sync semantics, not by this primitive.

**I4 (Index entry retention after revocation).** When an attestation is revoked (via a revocation attestation per §3.3) or superseded (via a successor in its supersedes chain), the entity itself remains in the tree and in the indexes. `find_attestations_*` continues to return the entity; consumers use `is_attestation_live` to determine current liveness. Indexes do NOT filter by liveness.

**I5 (`properties.kind` index entry per attestation).** Each `system/attestation` entity has at most ONE entry in the `properties.kind` index (the value of its `properties.kind` key). Attestations without a `kind` key MUST NOT appear in the `properties.kind` index; such attestations are still indexed by `attesting` and `attested`.

**Cross-impl test vectors (normative):**

| Vector | Setup | Action | Expected observable behavior |
|---|---|---|---|
| TV-I1 | Empty tree | `:create` attestation A; immediately `find_attestations_targeting(A.attested)` | A is returned |
| TV-I2 | Empty tree | `:create` attestation A that fails validation | A NOT in any index; `find_attestations_*` returns empty |
| TV-I3 | Two attestations A, B with same `attesting` but different `attested` | `find_attestations_by(A.attesting)` | Returns both A and B |
| TV-I4 | Attestation A; revocation R targets A | `find_attestations_targeting(A.attested)` | Returns A (revocation does NOT remove A from index); `is_attestation_live(A)` returns false |
| TV-I5 | Attestation A with `properties.kind = "foo"`; B with `properties.kind = "foo"`; C with no `kind` key | `find_attestations_with_kind("foo")` | Returns A, B; C not included |

Implementations MAY use any indexing strategy (in-memory map, on-disk B-tree, etc.) that satisfies these invariants.

**Relationship to EXTENSION-QUERY (informative).** The required indexes on `attesting`, `attested`, `properties.kind`, and `supersedes` are substrate-level requirements — they serve attestation's own helper operations (`find_attestations_by`, `find_attestations_targeting`, etc.) and consumer extensions that depend on attestation (identity, quorum, group, future VC / reputation / provenance / cluster / transaction / governance / audit). The substrate primitive must function independently of any higher-layer extension; this is why attestation mandates the indexes itself rather than declaring them as an EXTENSION-QUERY dependency.

EXTENSION-QUERY provides a general-purpose field-indexing framework for application-level queries on arbitrary entity types and fields. The two are complementary, not redundant: ATTESTATION's four required indexes are a fixed minimal substrate commitment; QUERY's configured field indexes are an app-level extensibility surface. When EXTENSION-QUERY is installed, implementations MAY satisfy ATTESTATION's required indexes by registering them as configured field indexes inside QUERY's framework — the I1–I5 observable contract is identical regardless of mechanism.

**Persistence and rebuild (informative).** The required indexes are derived state: they are functions of the authoritative tree state, not independently authoritative. Implementations MUST guarantee that index lookups are consistent with current tree state across process restarts, peer-state imports, and any other event that invalidates in-memory state. Per `SYSTEM-COMPOSITION.md` §6.7.4 (Startup hydration), persistence rehydrates the content store and tree on peer initialization; query indexes and other derived state — including ATTESTATION's required indexes — rebuild after hydration completes. The mechanism is implementation-defined: persist indexes alongside tree state and reload (with verify-or-rebuild on startup); rebuild by walking `system/attestation` entities in the tree after hydration; or any equivalent. Implementations MUST NOT permit indexes to drift from tree state in observable ways: any `find_attestations_*` call MUST return a result consistent with the tree state at the moment of the call.

---

## 6. Handler operations

**Path-as-resource (MUST).** All four handler operations follow path-as-resource per `ENTITY-CORE-PROTOCOL.md` §3.2 (architectural-side MUST). The operation's resource targets the tree binding location for the attestation entity; the params carry the attestation fields. Calling `system/attestation:create` (or `:supersede` / `:revoke`) without a resource MUST return **`400 path_required`** (`GUIDE-EXTENSION-DEVELOPMENT.md` §171 is the authority for this code). Content-store-only writes (rare; use cases include test fixtures and staging-without-tree-binding) use the V7 kernel's `tree:put` operation directly with a content-store-only flag, NOT the substrate's `:create` operation.

### 6.1 `system/attestation:create`

Produce an attestation entity.

**Params:** `{attesting: hash, attested: hash, properties: map, supersedes?: hash, not_before?: uint, expires_at?: uint}`
**Result:** `{attestation_hash: hash}`

Validates structural invariants (`attesting` and `attested` are valid hashes; `properties` is a map; `supersedes` if present points to a `system/attestation` entity). Returns the unsigned attestation hash; signature gathering is the caller's responsibility (V7 patterns; per `envelope.included` or local signing).

The handler does NOT validate the signature — that's `verify_attestation_signature`. The handler does NOT validate authority — that's the consumer's domain.

### 6.2 `system/attestation:supersede`

Produce an attestation that supersedes a previous one. Convenience wrapper over `:create`.

**Params:** `{previous_hash: hash, properties: map, expires_at?: uint, ...}`
**Result:** `{attestation_hash: hash}`

Looks up `previous_hash`; copies its `attesting` and `attested` (must match the new attestation's `attesting`/`attested`); sets `supersedes = previous_hash`. New `properties` replace previous; new `expires_at` if provided.

### 6.3 `system/attestation:revoke`

Produce a revocation attestation. Convenience wrapper over `:create` for the common revocation case.

**Params:** `{target_hash: hash, reason?: string, attesting: hash}`
**Result:** `{revocation_hash: hash}`

Equivalent to:
```
:create({
  attesting: <revoker peer hash>,
  attested: target_hash,
  properties: {kind: "revocation", reason: reason}
})
```

Provided as a convenience for the common pattern; consumers MAY also use `:create` directly with the revocation properties shape.

### 6.4 `system/attestation:verify`

Orchestration helper that wraps signature + liveness checks.

**Params:** `{attestation_hash: hash, as_of?: uint}`
**Result:** `{valid: bool, reason?: string}`

Returns `{valid: true}` if the attestation has a valid signature from `attesting` AND is live (per `is_attestation_live`). Otherwise returns `{valid: false, reason: <reason>}`.

Does NOT validate consumer-specific authority rules (topology, function-specific, authority-revocation) — those are the consumer's responsibility. Use this as the first gate; layer consumer-specific validation on top.

---

## 7. Storage

**The attestation primitive does NOT mandate a storage path.** Consumer extensions choose where attestations of their domain live.

Examples:
- Identity stores its attestations under `system/identity/internal/cert/{h}`, `system/identity/public/cert/{h}`, `system/identity/relationships/{c}/cert/{h}` per audience tier.
- Quorum stores its self-event attestations under `system/quorum/{q}/event/{h}`.
- A VC issuer extension might store under `system/vc/issued/{h}`.
- Cluster might store under `system/cluster/{c}/votes/{h}`.
- Provenance might store under `system/provenance/by-creator/{creator_h}/{h}`.

The attestation primitive provides the entity TYPE; the consumer provides the storage CONVENTION.

**Closed-namespace ownership (normative).** When a consumer extension chooses paths under its own subtree (e.g., EXTENSION-IDENTITY chooses `system/identity/...`; EXTENSION-QUORUM chooses `system/quorum/...`; future EXTENSION-VC may choose `system/vc/...`), that subtree is OWNED by the consumer. Other extensions MUST NOT bind paths inside another consumer's subtree. Extensions that need to track state derived from a quorum, identity, or other consumer-owned entity MUST use their own top-level namespace (`system/history/...`, `system/role/...`, etc.), NOT nest inside the source consumer's subtree. Path-scoping is the correctness mechanism for kind disambiguation (per §3.2); namespace ownership extends the same principle to the path tree itself.

**Why no mandatory path:** different consumers want different access patterns. Identity wants per-audience-tier paths for sync scoping. Quorum wants per-quorum paths for self-event grouping. VC ecosystems might want per-issuer or per-subject indexes. Forcing a single canonical path would either constrain consumers or duplicate writes (each consumer storing at both the canonical and their preferred path).

**Lookup helpers (§5.4, §5.5)** assume implementations maintain indexes on `attesting` and `attested` fields regardless of storage path. This makes graph operations efficient even when attestations are scattered across many consumer-defined paths.

---

## 8. Coherent capability

`system/attestation:create` / `:supersede` / `:revoke` are the proper authorized path for instantiating attestation entities. Direct `tree:put` to attestation paths is permitted (V7 kernel exposes `tree:put` by design) but bypasses the attestation handler's validation. Application-level capability grants SHOULD cover the `system/attestation:*` operations rather than raw `tree:put`. Follows the Coherent Capability principle (`PROPOSAL-COHERENT-CAPABILITY-AUTHORITY.md` §2 R0).

---

## 9. Conformance

### 9.1 MUST

- Implementations MUST provide the `system/attestation` entity type per §3.
- Implementations MUST provide the validation helpers per §4 (signature, specific-signer, liveness with `as_of`).
- Implementations MUST provide the graph operations per §5 (chain walks, lookups, revocation search, `find_attestations_with_supersedes`, `find_attestations_with_kind`) with consumer-supplied predicate parameters where applicable.
- Implementations MUST provide `default_find_authorizing` per §5.1 and pass the cross-impl test vectors TV-A1 through TV-A11, including the transitive-supersession vectors TV-A4a through TV-A4d (per `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` Category A).
- Implementations MUST treat revocation as `properties.kind == "revocation"` attestations (not a separate entity type).
- Implementations MUST provide handler operations per §6. All `system/attestation:*` ops follow path-as-resource (ENTITY-CORE-PROTOCOL.md §3.2 MUST); `:create` / `:supersede` / `:revoke` without a resource target MUST return **`400 path_required`** (authority: `GUIDE-EXTENSION-DEVELOPMENT.md` §171).
- **Handler-op type registration:** the four `system/attestation:*` ops register `input_type` / `output_type` per ENTITY-CORE-PROTOCOL.md §3.7 convention (`{handler-path}/{op-name}-request` / `-result`). Type definitions MUST be installed at `system/type/{type_name}` during handler installation.
- **Signature ingestion:** signatures arriving in `envelope.included` are bound at V7 invariant pointer paths by the dispatcher per ENTITY-CORE-PROTOCOL.md §6.5 (envelope-unwrap ingestion). `system/attestation:verify` and other validation paths MUST find ingested signatures via the standard `find_signature_by_signer` lookup; no attestation-specific ingestion surface is required.
- Implementations MUST maintain indexes on `attesting`, `attested`, `properties.kind`, and `supersedes` fields for `find_attestations_*` performance and `properties.kind` dispatch performance. Identity v3.2 dispatches on `properties.kind` for every attestation it processes; without an index this is a full-scan per validation. The `supersedes` index supports forward-chain walks (`find_live_head`) and recursive liveness (`is_attestation_live`).
- Implementations MUST satisfy the index invariants I1–I5 per §5.7 and pass the cross-impl test vectors TV-I1 through TV-I5.
- Implementations MUST support the `as_of` parameter on liveness checks for time-traveling validation (used by cap chain validation against historical state).
- Implementations MUST NOT route attestation entities through V7's `verify_capability_chain` machinery — attestations are non-cap entities validated by the helpers in §4.
- The primitive MUST NOT impose a canonical storage path for attestation entities; consumer extensions choose their own paths.

### 9.2 SHOULD

- Implementations SHOULD provide bounded-depth chain walks (default `max_depth: 32`) to prevent unbounded traversal.

### 9.3 MAY

- Implementations MAY provide additional convenience operations (e.g., `system/attestation:list_by_kind`, `system/attestation:get_chain`) beyond §6's required set.
- Consumers MAY define their own validation orchestration layered on top of `system/attestation:verify`.

---

## 10. Cross-extension invariants

- **Three-parallel-mechanisms invariant (normative).** Three structurally distinct entity-validation classes — V7 capability tokens (validated by `verify_capability_chain`), `system/attestation` entities (validated by EXTENSION-ATTESTATION helpers + consumer rules), `system/quorum` entities (validated by EXTENSION-QUORUM's `verify_k_of_n_signatures`). Cap-chain verification MAY read attestation state via the `IdentityBindingChecker` hook (read-only; for grantee-binding lookup); cap-chain verification MUST NOT validate attestations as caps. Attestation validation MUST NOT call `verify_capability_chain`. Quorum validation MUST NOT call `verify_capability_chain`. No shared validator across the three classes. See §2.1 and `SYSTEM-IDENTITY-COMPOSITION.md` §5.
- **No path mandate.** This primitive does not mandate paths; consumers choose. Generic graph operations work regardless of storage path because they index by entity field (`attesting`, `attested`, `properties.kind`).
- **Authority-revocation is consumer-supplied.** The primitive does the lookup (`find_revocations_for`); consumers apply their own authority predicate per §4.4.

---

## 11. Document history

| Version | Notes |
|---|---|
| 1.2 | Substrate cleanup pass per the system-peer-rename / substrate-cleanup work (Revision 3). **PR-2** §4.0/§4.1/§4.2/§5.1: `resolve_peer_pubkey(peer_hash, ctx)` → `resolve_peer(peer_hash, ctx)`; return-value description tightened (returns `system/peer` entity, V7's peer-keypair entity, NOT EXTENSION-IDENTITY's identity layer); function name now matches return-type semantics post-V7 rename. **PR-3** §7 added "Closed-namespace ownership" normative paragraph: when a consumer extension chooses paths under its own subtree (e.g., `system/identity/...`, `system/quorum/...`, `system/vc/...`), that subtree is OWNED by the consumer; cross-extension path-injection is not the supported pattern. Closes the R-7' class of namespace collisions. **PR-7** §3.2 promoted "namespaced kind names" from SHOULD to MUST when registering kinds in the kind-ownership table; kinds intended for cross-extension visibility MUST be namespaced; `revocation` stays unnamespaced as the universal substrate kind. Within-extension internal kinds MAY use unnamespaced names. Companion: V7 v7.40 (the V7 type rename PR-1 + PR-8 cap-resource); EXTENSION-QUORUM v1.2 (substrate cleanup PR-4/PR-5/PR-6). No wire-format change. |
| 1.1 (Amendment 1) | Per the IDENTITY v3.2 migration-fixes Amendment 1 (second-round cross-impl feedback). §9.1 conformance gains two pointer lines: handler-op type registration per V7 §3.7 convention (SPEC-24); signature ingestion delegated to V7 §6.5 dispatcher-level (SPEC-25). Substantive normative text lives in V7 v7.37; this spec inherits via pointers. **Supplementary clarifications** also added to §5.7: relationship to EXTENSION-QUERY (substrate-level required indexes vs app-level configured indexes; complementary not redundant; impls MAY satisfy MUSTs via QUERY's framework when installed); persistence + rebuild posture (indexes are derived state; rebuild via SYSTEM-COMPOSITION §6.7.4 startup hydration; mechanism implementation-defined). No version bump (v1.1 absorbs Amendment 1; spec just landed and no impl has shipped against v1.1 final). |
| 1.1 | Cross-impl-feedback batch (IDENTITY v3.2 migration fixes). Items: SI-1 (substrate stays signature-agnostic; §4.3 + §5.1 informative notes; TV-A8 expected = "A"); SI-2 (transitive supersession ratified; predecessor-revival semantics documented); SI-3 (§4.0 abstract operations contract); SI-4 (§4.0 inline `find_signature_by_signer` + `verify_signature` pseudocode); SI-7 (§6 path-as-resource MUST; `:create` / `:supersede` / `:revoke` without resource MUST return `path_required`); SI-8 (§5.1 `chain[-1]` termination semantics added); SI-17 (`ctx.resolve_identity` → `resolve_peer_pubkey` rename in §4.1, §4.2); SI-21 (§10 three-parallel-mechanisms wording tightened — cap-chain MAY read attestation state via hook; MUST NOT validate as caps). Conformance: TV-A4a–TV-A4d added (transitive supersession scenarios incl. predecessor-revival); TV-A8 expected output revised. No wire-format change. |
| 1.0 (Amendment 1) | **Amendment absorbing Go team round-2 landed-review feedback and architecture-team review pass**. (a) Added §5.1 "Multi-context peers note" — consumers expecting peers with multiple unrelated authorizing attestations (e.g., a peer that is a controller in identity A and an agent in identity B) SHOULD provide a custom `find_authorizing_fn` filtering by consumer-specific kind/path scoping. Added TV-A11. (b) Added §5.6a `find_attestations_with_supersedes` and §5.6b `find_attestations_with_kind` definitions — both were referenced from §4.3 (`is_attestation_live`), §5.3 (`find_live_head`), and TV-I5 but never specified. (c) Promoted `supersedes` to a MUST-indexed field per §5.7 / §9.1; updated I1 invariant to include the new index. (d) Conformance §9.1 line updated `TV-A1 through TV-A10` → `TV-A1 through TV-A11`. No version bump (v1.0 absorbs); spec just landed and no impl has shipped against it. |
| 1.0 | Initial spec, promoted from the attestation-primitive extraction proposal. Substrate primitive for the signed-graph; consumed by EXTENSION-QUORUM and EXTENSION-IDENTITY. |
