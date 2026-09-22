# Quorum Extension — Normative Specification

**Version**: 1.2
**Status**: Active
**Depends**: ENTITY-CORE-PROTOCOL.md (v7.40+); EXTENSION-ATTESTATION.md (v1.2+)
**Related**: EXTENSION-IDENTITY.md (consumes; identity quorums use the `concrete` mode by default; identity registers `identity-resolved` mode for group-style consumers); future consumers — group, cluster, transaction, governance, multi-sig committee
**Synthesis**: SYSTEM-IDENTITY-COMPOSITION.md (single-entry-point overview of the three-extension layering); EXPLORATION-IDENTITY-LENSES-AND-CONVERGENCE.md §4a.11–§4a.15 (the design path)

---

> **Path notation.** Paths in this document use peer-relative notation (without leading `/{peer_id}/`). All peer-relative paths resolve to the local peer's namespace. See `ENTITY-CORE-PROTOCOL.md` §1.4 for the path model.

---

## 1. Overview

K-of-N consensus over an entity is a **primitive authorization pattern**, not an identity-specific feature. EXTENSION-QUORUM defines the K-of-N node type in the system's signed-graph substrate.

This extension defines:
1. The `system/quorum` entity (the K-of-N node — a signer roster + threshold).
2. The K-of-N validation primitive (`verify_k_of_n_signatures`) callable on any entity.
3. The current-signer-set resolver (`current_signer_set`) that walks quorum-update attestations to determine the live signer set.
4. Conventions for quorum self-events (`quorum-update`, `quorum-publish`) as `system/attestation` entities per `EXTENSION-ATTESTATION.md`.
5. A pluggable signer-resolution interface (`concrete` built in; consumers MAY register additional modes such as `identity-resolved`).
6. Four handler operations: `system/quorum:create`, `:update`, `:publish`, `:verify`.

The quorum primitive is genuinely thin: one entity type, two helpers, two attestation conventions, pluggable signer-resolution. Identity, group, cluster, transaction, governance, and any K-of-N-needing extension consume it directly.

This extension does **not** define:
- Identity semantics (lives in `EXTENSION-IDENTITY.md`).
- The cap-layer multi-sig primitive (lives in V7 / `PROPOSAL-MULTISIG-CORE-PRIMITIVE.md`; separate K-of-N at the cap-issuance layer).
- Trust framework semantics (deferred).

---

## 2. The principle

The `system/quorum` entity is a **special node in the signed graph** — it doesn't have a single keypair; its "signature" is K signatures from N constituent peers. The validator (`verify_k_of_n_signatures`) is the only mechanism that distinguishes quorum from a regular peer node.

**Quorum self-events (update, publish) are attestations.** A `quorum-update` is an attestation by the quorum about itself ("the quorum's membership changes to this"); a `quorum-publish` is an attestation by the quorum about itself ("the quorum's current state is this"). Both fit the attestation primitive's data shape; their `properties.kind` distinguishes them; their K-of-N signature topology is applied by quorum's validator.

---

## 3. Type definitions

### 3.1 `system/quorum`

The K-of-N signing node entity.

```
system/quorum := {
  fields: {
    signers:           {array_of: {type_ref: "system/hash"}}
                                                  ; constituent peer identity hashes
                                                  ; (or, in identity-resolved mode,
                                                  ; references to public identities)
    threshold:         {type_ref: "primitive/uint"}
                                                  ; K
    signer_resolution: {type_ref: "primitive/string", optional: true}
                                                  ; resolver-mode identifier; "concrete" (default)
                                                  ; or any mode registered by another extension
                                                  ; via the resolver-registration hook (§5.2)
    name:              {type_ref: "primitive/string", optional: true}
    metadata:          {type_ref: "primitive/any", optional: true}
  }
}
```

Stored at: `system/quorum/{quorum_id_hex}` (where `quorum_id` is the entity's content hash).

The quorum entity is structural and is not itself signed. Authorization for the quorum's role flows from its constituents collectively K-of-N-signing other entities (top-level identity certs; quorum-update attestations; quorum-publish attestations; cluster votes; transaction approvals; etc.).

### 3.2 The `quorum-update` attestation convention

**`"quorum-update"` is a `properties.kind` value owned by THIS extension** (EXTENSION-QUORUM). Per the kind-ownership table in `EXTENSION-ATTESTATION.md` §3.2.

Consumers (identity, group, cluster, etc.) that need to update a quorum's membership do so by calling EXTENSION-QUORUM's operations on the relevant `quorum_id`, NOT by minting their own quorum-update-shaped attestations. Within `system/quorum/{q}/event/...` paths the kind name MUST be unambiguous so quorum's validators dispatch correctly.

A `quorum-update` is a `system/attestation` entity (per `EXTENSION-ATTESTATION.md`) with this shape:

```
system/attestation {
  attesting:  <quorum_id>                          ; self-attestation: the quorum
  attested:   <quorum_id>                          ; self-attestation: same value
  properties: {
    kind:           "quorum-update",
    new_signers:    [<peer_hash>, ...],            ; new constituent set
    new_threshold:  <K>,                            ; new K
  }
  supersedes: <previous_quorum_update_hash>?      ; per-quorum supersedes chain
  not_before: ...?
  expires_at: ...?
}
```

**Signed K-of-N by the current effective quorum constituents** (per `current_signer_set`).

Stored at: `system/quorum/{quorum_id_hex}/event/{hash_hex}` per §7.

The supersedes chain is per-quorum: a `quorum-update` supersedes the previous `quorum-update` for the same quorum (or carries `supersedes: null` as the initial entry). The effective signer set after a `quorum-update` is `(new_signers, new_threshold)`.

### 3.3 The `quorum-publish` attestation convention

**`"quorum-publish"` is a `properties.kind` value owned by THIS extension** (EXTENSION-QUORUM). Per kind-ownership rules in `EXTENSION-ATTESTATION.md` §3.2.

A `quorum-publish` is a `system/attestation` entity with this shape:

```
system/attestation {
  attesting:  <quorum_id>                          ; self-attestation: the quorum
  attested:   <quorum_id>                          ; self-attestation: same value
  properties: {
    kind:               "quorum-publish",
    signers:            [<peer_hash>, ...],        ; snapshot of current effective signers
    threshold:          <K>,                        ; current K
    published_handle:   <peer_hash>?,              ; optional; consumer-extension hook
                                                    ; for publishing a primary peer-hash that
                                                    ; consumers' clients cache as the consumer's
                                                    ; published handle. Substrate-neutral —
                                                    ; consumer extensions define semantics within
                                                    ; their own framework.
    ...                                            ; additional consumer-extension keys
                                                    ; (extensible per consumer needs)
  }
  supersedes: <previous_quorum_publish_hash>?
  not_before: ...?
  expires_at: ...?
}
```

**Signed K-of-N. Initial publication:** by the current quorum constituents. **Supersede:** by the *previous* quorum (so the supersedes chain remains validatable against consumers' cached prior state). This rule is invariant: superseding `quorum-publish` attestations are always signed by the signer set in effect at the previous publish, NOT by the current signer set.

**"Previous quorum" pinning (normative).** For supersede `quorum-publish` attestations, the K-of-N validation MUST use the prior publish's `properties.signers` snapshot directly — NOT `current_signer_set` resolved at the time of the prior publish. Concretely: to validate `publish_v2 supersedes publish_v1`, the verifier reads `publish_v1.properties.signers` and `publish_v1.properties.threshold` and verifies K-of-N over `publish_v2.content_hash` against that exact snapshot. This pins the supersede chain to cached prior state and is independent of intervening `quorum-update` events.

Stored at: `system/quorum/{quorum_id_hex}/event/{hash_hex}` per §7.

The previous-quorum-signs-supersedes rule is generic (not identity-specific): any consumer that caches prior `quorum-publish` state externally needs the cryptographic continuity to validate successor publishes.

The `published_handle` and other extra `properties` keys are consumer-extension hooks. EXTENSION-QUORUM doesn't interpret them; consumer extensions define semantics within their own framework (e.g., a consumer may use `published_handle` to record a primary peer-hash that consumers' clients cache as the consumer's published handle). Substrate stays neutral on the field's meaning.

### 3.4 Closed-namespace ownership (normative)

The `system/quorum/...` subtree is owned by EXTENSION-QUORUM. Quorum entities bind at `system/quorum/{quorum_id_hex}`; quorum self-events (`quorum-update`, `quorum-publish` per §3.2 / §3.3) bind at `system/quorum/{quorum_id_hex}/event/{hash_hex}` per §7. Other extensions MUST NOT bind paths inside `system/quorum/...`. Extensions consuming a quorum (e.g., EXTENSION-HISTORY tracking transitions for a quorum, EXTENSION-ROLE referencing a quorum's authority) MUST use their own top-level namespace (`system/history/...`, `system/role/...`, etc.), NOT nest under `system/quorum/{q}/`. Mirrors the closed-namespace invariant in EXTENSION-ATTESTATION.md §7.

---

## 4. Validation helpers

### 4.1 `verify_k_of_n_signatures`

```
verify_k_of_n_signatures(entity_hash, signer_set, threshold, ctx) → bool
  ; Find all signature entities targeting entity_hash.
  ; For each candidate signer in signer_set, verify their signature via
  ; ATTESTATION.verify_signature (algorithm dispatched per sig_entity.algorithm).
  ; Return true once threshold valid signatures have been counted.

  signed = empty set
  for candidate in signer_set:
    if candidate in signed: continue                       ; defensive dedupe
    sig = find_signature_by_signer(entity_hash, candidate, ctx)
    if sig is null: continue
    candidate_peer = resolve_peer(candidate, ctx)
    if candidate_peer is null: continue
    if verify_signature(sig, candidate_peer):
      signed.add(candidate)
      if len(signed) >= threshold: return true
  return len(signed) >= threshold
```

`find_signature_by_signer`, `resolve_peer`, and `verify_signature` are defined in `EXTENSION-ATTESTATION.md` §4.0. `find_signature_by_signer` looks up signatures at the V7 invariant pointer path; `resolve_peer` returns the `system/peer` entity (V7's peer-keypair entity, NOT EXTENSION-IDENTITY's identity layer) for a given peer hash; `verify_signature` performs Ed25519 verification.

This is the K-of-N validator. Consumers (including `EXTENSION-IDENTITY.md` for top-level certs and EXTENSION-QUORUM itself for `quorum-update` / `quorum-publish` attestations) call this when their topology rule is "K of N must sign."

### 4.2 `current_signer_set`

```
current_signer_set(quorum_id, ctx, as_of?: uint) → (signers, threshold)
  ; Walk the live (per as_of) quorum-update attestation chain to determine
  ; the effective signer set + threshold at the as_of timestamp.
  ; Default behavior (as_of unset): return the current state at the current time.
  ; Historical behavior (as_of specified): return the state that was live at as_of.

  quorum = ctx.entity_tree.get("system/quorum/" + quorum_id_hex)
  if quorum is null: return error("quorum_not_found")

  signers   = quorum.data.signers
  threshold = quorum.data.threshold

  ; Find the live (non-superseded at as_of) quorum-update head, if any.
  ; Quorum-update attestations are stored at system/quorum/{quorum_id}/event/...
  ; Filter by properties.kind == "quorum-update".
  updates = EXTENSION_ATTESTATION.find_attestations_targeting(
    quorum_id,
    predicate=lambda a, _: a.properties.get("kind") == "quorum-update",
    ctx=ctx
  )
  if updates is not empty:
    ; Find the live head of the supersedes chain (per as_of).
    head = EXTENSION_ATTESTATION.find_live_head(updates[0], ctx, as_of=as_of)
    if head is not null:
      signers   = head.properties.new_signers
      threshold = head.properties.new_threshold

  ; Resolution-mode dispatch (pluggable; §5.1, §5.2). Resolver receives as_of.
  resolver = lookup_resolver(quorum.data.signer_resolution)
  if resolver is not null:
    signers = [resolver(s, ctx, as_of=as_of) for s in signers]

  return (signers, threshold)
```

The walk uses EXTENSION-ATTESTATION's lookup helpers (`find_attestations_targeting`, `find_live_head`); no quorum-specific traversal logic needed. The K-of-N validation of the quorum-update itself (must be signed by the previous signer set) is handled at validation time per §3.2.

**Historical-state resolution (normative).** Implementations MUST fully implement historical-state resolution. When `as_of` is specified, `current_signer_set` MUST return the signer set + threshold that was live at the `as_of` timestamp — i.e., the most recent `quorum-update` whose `not_before <= as_of` (or the quorum entity's initial signers if no such update exists), with no successor that was itself live at `as_of`. The resolver hook MUST honor `as_of` correspondingly: in `identity-resolved` mode, the resolver returns the controller live at `as_of`, not the current controller. `find_live_head` already takes `as_of` (per `EXTENSION-ATTESTATION.md` §5.3); the historical walk reuses its existing semantics.

The use case: group quorums in `identity-resolved` mode with mid-flight signing across a controller rotation. A `quorum-update` signed by an identity's prior controller would fail K-of-N validation after that identity rotates, unless the validator resolves the constituent at the timestamp of the update being validated. Without `as_of` propagation, this is a hidden invariant break.

**Trust model (normative).** Each `quorum-update` is validated against the predecessor's signer set at the moment it enters the local tree (via §4.2.1 validate-accept). Validated `quorum-update` attestations are trusted on subsequent reads; `current_signer_set` walks the live chain head and trusts cached prior validation. End-to-end re-validation of the chain on every `current_signer_set` call is NOT performed and is NOT required. Re-validation occurs only on explicit cache invalidation (per §4.2.1 triggers) or on cold start when the cache is empty.

**Cold-start posture.** On cold start (process restart, fresh peer-state import), the cache is empty. The first call to `current_signer_set(quorum_id, ctx)` walks the chain. Each `quorum-update` in the chain, at this point, has already been validated at arrival time (per §4.2.1) and tree-bound only on validation success — so the walk trusts the existing tree state. Implementations MAY revalidate on cold-start as a defense-in-depth measure but MUST NOT require it for conformance.

#### 4.2.1 Cache invalidation contract (normative)

Implementations MUST cache `current_signer_set` results per `quorum_id` and invalidate per the rules below. The cache is per-peer (cross-peer sync invalidations apply at the receiving peer's cache, not the sender's).

**Invalidation triggers (MUST):**

1. **Successful local op completion.** When `system/quorum:update` (per §6.2) or `system/quorum:publish` (per §6.3) completes successfully on this peer for `quorum_id`, the cache entry for `quorum_id` MUST be invalidated.
2. **Validated attestation arrival.** When a `system/attestation` entity with `properties.kind` in {`"quorum-update"`, `"quorum-publish"`} and `attesting == quorum_id` enters the local tree at `system/quorum/{quorum_id_hex}/event/...` AND passes structural + signature validation (per `EXTENSION-ATTESTATION.md` §4 + this spec's K-of-N topology check), the cache entry for `quorum_id` MUST be invalidated. This applies regardless of source — local handler op, cross-peer sync, `envelope.included` ingestion, or L0 bootstrap path. The invalidation is on the `process_attestation`-style validate-and-accept moment, NOT on the raw tree-write.
3. **Authority-revocation arrival.** When a live revocation attestation targeting a `quorum-update` or `quorum-publish` previously seen for `quorum_id` arrives and passes validation, the cache entry for `quorum_id` MUST be invalidated.

**Invalidation NON-triggers (MUST NOT invalidate):**

1. **Failed validation.** A `quorum-update` or `quorum-publish` that fails K-of-N validation (insufficient signatures, signatures from wrong signer set, etc.) MUST NOT invalidate the cache. The attestation may sit in the tree at a structurally-valid path without being authoritative.
2. **Tree-write without acceptance.** Raw `tree:put` to a `system/quorum/{q}/event/{h}` path that bypasses handler validation MUST NOT invalidate the cache. The cache reflects validated quorum state, not raw tree state.
3. **Other quorums.** Activity on `quorum_id_other` MUST NOT invalidate the cache for `quorum_id`. Cache entries are independently scoped per `quorum_id`.

**Recompute on next call.** After invalidation, the next call to `current_signer_set(quorum_id, ctx)` walks the chain fresh and re-populates the cache.

**Mechanism is implementation-defined.** The cache-invalidation contract is on post-state, not implementation. Implementations satisfy the validate-accept invariant via either:

- **(A) Sync-hook pattern.** A handler hook fires on every tree-write of a `system/attestation` entity at `system/quorum/{q}/event/...` whose `properties.kind ∈ {"quorum-update", "quorum-publish"}`. The hook validates K-of-N inline against the predecessor's signer set; on success, invalidates the cache; on failure, leaves the cache untouched. Independent of source path (sync arrival, `envelope.included` ingestion, L0 bootstrap, local handler op).
- **(B) Single-handler-op routing pattern.** All sync arrivals and ingestion paths are required to route through a `process_quorum_attestation`-equivalent handler op, which performs validation + invalidation atomically. The sync extension and envelope-ingestion path MUST NOT bypass this routing for relevant attestation kinds.

Both produce equivalent post-state. Implementations choose one and document it in their conformance report. Cross-impl wire conformance does not depend on the choice; per-impl unit tests verify the chosen path satisfies §4.2.1.

**Cross-impl test vectors:**

| Vector | Setup | Action | Expected behavior |
|---|---|---|---|
| TV-QF12 | Cache populated for `quorum_id` from prior call | Successful `system/quorum:update` for `quorum_id` | Cache invalidated; next `current_signer_set` walks fresh |
| TV-QF13 | Cache populated for `quorum_id` | Cross-peer sync delivers a valid `quorum-update` attestation for `quorum_id`; passes K-of-N validation | Cache invalidated on validate-accept (NOT on raw tree-write) |
| TV-QF14 | Cache populated for `quorum_id` | Cross-peer sync delivers a `quorum-update` for `quorum_id` that FAILS K-of-N (wrong signer set) | Cache NOT invalidated; entry persists |
| TV-QF15 | Cache populated for both `quorum_id_A` and `quorum_id_B` | Successful `system/quorum:update` for `quorum_id_A` only | `quorum_id_A` cache invalidated; `quorum_id_B` cache untouched |

These vectors live in `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` Category Q.

### 4.3 `is_quorum_id` — quorum identification (normative)

Identity (and other consumers) call `is_quorum_id(hash, ctx)` to test whether a given hash refers to a `system/quorum` entity. Identity uses this in chain-walk terminate predicates and topology dispatch (per `EXTENSION-IDENTITY.md` §3.6).

```
is_quorum_id(hash, ctx) → bool
  ; Returns true iff `hash` refers to a system/quorum entity locally known to ctx.

  ; Path-based lookup at the canonical quorum path.
  q = ctx.entity_tree.get("system/quorum/" + hex(hash))
  if q is null: return false
  if q.type != "system/quorum": return false
  return true
```

**Algorithm pinned (normative):**

- The lookup is **path-based at `system/quorum/{hex(hash)}`** (the canonical storage path per §7), NOT a content-store-only lookup. This pins the relationship between the entity's content_hash and its storage location for identification purposes: a quorum is "known" only if it is bound at its canonical path on the local tree.
- `hex(hash)` is the lowercase hex encoding of the full `system/hash` byte sequence (algorithm-byte prefix + digest), per §7's hash-segment encoding.
- The lookup returns `false` if the entity is absent, if it is bound at the path but is of a different type, or if the hash is malformed.

**Cross-peer scope.** The lookup queries the local peer's tree. Cross-peer quorum references (e.g., a group quorum whose constituents in `identity-resolved` mode reference identities living on remote peers) are resolved through the resolver hook (§5.2), NOT through `is_quorum_id` directly. `is_quorum_id` is the local-tree primitive; consumer extensions handle cross-peer resolution by their own conventions.

**Race semantics during bootstrap / sync catch-up.** If a cert validation runs before the relevant quorum entity has been written to the local tree (bootstrap ordering; sync catch-up where the cert arrives before its quorum), `is_quorum_id` returns `false` and dispatch falls through accordingly. For identity-context dispatch (per `EXTENSION-IDENTITY.md` §3.6), this means a candidate top-level controller cert is treated as a sub-controller cert candidate (single-sig from `attesting`), which subsequently fails because `attesting` is the not-yet-known quorum_id and no live cert authorizes it. The validator returns the appropriate failure (e.g., `chain_to_quorum_not_found`). Implementations MAY retry validation after observing a `system/quorum` write to the relevant path, but MUST NOT cache "not a quorum" status across writes — `is_quorum_id` is stateless and re-evaluates at each call.

**Cross-impl test vectors:**

| Vector | Setup | Input | Expected output |
|---|---|---|---|
| TV-Q6 | Quorum entity Q stored at `system/quorum/{hex(Q.hash)}` | hash = Q.hash | true |
| TV-Q7 | No entity at `system/quorum/{hex(H)}` | hash = H | false |
| TV-Q8 | Entity at `system/quorum/{hex(H)}` of type `system/identity/peer-config` (path-name collision; pathologically malformed tree) | hash = H | false (type mismatch) |
| TV-Q9 | Cert validation runs for top-level controller cert before Q is written to tree | hash = Q.hash | false at first call; true after Q is written and validation re-runs |

These vectors live in `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` Category Q.

---

## 5. Pluggable signer resolution

### 5.1 Built-in `concrete` mode

When `signer_resolution = "concrete"` (or absent — `concrete` is the default), each entry in `signers` is a specific peer-identity hash. Signature verification matches against that exact identity. Rotation of a constituent's keypair invalidates that constituent's slot until an explicit `quorum-update` swaps in the new hash.

This mode requires no other extension. EXTENSION-QUORUM provides it built in. Identity quorums (where the signers are typically cold-stored backup keys) and most general use cases fit this profile.

### 5.2 Resolver registration hook

Other extensions MAY register additional resolution modes via:

```
system/quorum:register_resolver(mode_name, resolver_handler) → ()
  ; mode_name: string, becomes a valid value for system/quorum.signer_resolution
  ; resolver_handler: (signer_ref, ctx, as_of?: uint) → resolved_peer_hash
  ;   When as_of is specified, the resolver MUST return the signer that was
  ;   live at as_of (e.g., for identity-resolved mode, the controller at that
  ;   timestamp). When as_of is unset, returns current.
```

The resolver handler MUST be deterministic and side-effect-free. The handler is invoked at signature-verification time per signer in the quorum's `signers` array. The output is a peer hash that participates in the K-of-N count exactly as a `concrete` signer would.

**Multi-registration semantics (normative).** Calling `system/quorum:register_resolver(mode_name, ...)` for a `mode_name` that has already been registered MUST return `error: resolver_already_registered`. Implementations MUST NOT silently replace, override, or stack handlers. Re-registration of the SAME handler (idempotent) is implementation-defined; SHOULD be permitted as a no-op for hot-reload scenarios. Replacement of a previously-registered handler with a different handler requires explicit unregistration first; an `unregister_resolver(mode_name)` op is OUT OF SCOPE for v2 (no current consumer needs it).

**EXTENSION-IDENTITY registers `identity-resolved` mode** via this hook. Each entry in `signers` is a reference to a public identity; the resolver looks up the identity's controller (live at `as_of`, or current if `as_of` is unset) and returns that controller's peer hash. Used by group quorums whose constituents are themselves identity-bearing peers.

**Resolves the cyclic-dependency risk.** EXTENSION-QUORUM does not depend on EXTENSION-IDENTITY. EXTENSION-IDENTITY depends on EXTENSION-QUORUM (and EXTENSION-ATTESTATION). The `identity-resolved` mode is registered by identity at install time; if identity is not installed, that mode is unavailable.

**Recursion bound (normative).** Resolver handlers MAY recursively look up downstream identities (e.g., `identity-resolved` mode resolves an identity reference to its current controller, which itself may live in another identity). To prevent unbounded recursion and cycles in identity-resolved chains, the resolver registration interface enforces a maximum depth.

**Default bound:** `max_resolver_depth = 8`. The default applies when a resolver-mode does not declare its own bound. Implementations MUST track resolution depth per `current_signer_set` invocation; on exceeding `max_resolver_depth` MUST return error `identity_resolver_max_depth_exceeded`.

**Cycle detection.** Implementations MUST track visited identity references during a single resolution invocation (a `visited` set keyed on the identity ref). On revisiting MUST return error `identity_resolver_cycle`. Cycles indicate either a malformed identity-resolved configuration (rare) or a malicious construction; failing-closed prevents resource exhaustion.

**Cross-impl test vectors:**

| Vector | Setup | Expected |
|---|---|---|
| TV-Q-V-IDENTITY-2 | Group quorum Q_a uses `identity-resolved` mode; signers reference identities A, B; A's controller reference recurses through 9 nested identity-resolved quorums | `current_signer_set(Q_a)` returns `error: identity_resolver_max_depth_exceeded` after 8 levels |
| TV-Q-V-IDENTITY-2-cycle | Identity A's controller resolves to identity B; B's controller resolves to A | `current_signer_set` over a quorum with `identity-resolved: A` returns `error: identity_resolver_cycle` |

### 5.3 Resolver lookup ordering

`lookup_resolver(mode_name)` returns the registered resolver for `mode_name`, or null if no resolver is registered. The default `concrete` mode is implicit and bypasses the lookup.

### 5.3.1 Fail-closed observable cases (normative)

Validation behavior for `signer_resolution` modes is one of four observable cases. Implementations MUST handle each case as specified for cross-impl behavior parity:

| Case | Setup | Required behavior |
|---|---|---|
| **C1: mode known + resolver registered** | quorum specifies a known mode (e.g., `"identity-resolved"` with EXTENSION-IDENTITY installed) | Resolve each `signers[i]` through the resolver; verify K-of-N against resolved peer hashes. Validation proceeds normally. |
| **C2: mode known + resolver registers later** | quorum specifies `"identity-resolved"`; verifier evaluates BEFORE EXTENSION-IDENTITY's `configure` has registered the resolver (e.g., during early-boot ordering) | MUST return error `quorum_resolver_unavailable`. Implementations MAY recheck on a subsequent validation attempt (after registration completes), but MUST NOT cache "resolver missing" status across registration events. |
| **C3: mode known + resolver never registered** | quorum specifies `"identity-resolved"` but EXTENSION-IDENTITY is not installed on this peer | MUST return error `quorum_resolver_unavailable`. The verifier MUST NOT silently fall back to `concrete` mode (which would mis-interpret identity references as peer references). |
| **C4: mode unknown** | quorum specifies a mode string that no extension has registered (typo, future mode, malicious) | MUST return error `quorum_resolver_unavailable`. Same fail-closed semantics as C3. |

**Error envelope.** The `quorum_resolver_unavailable` error MUST include:
- `quorum_id`: the quorum entity hash
- `mode_name`: the requested `signer_resolution` value
- `available_modes`: array of currently-registered mode names (for diagnostic clarity)

This lets callers distinguish "I need to install another extension" (C3) from "the quorum entity has bad data" (C4) at runtime.

**Cross-impl test vectors:**

| Vector | Setup | Action | Expected result |
|---|---|---|---|
| TV-Q1 | Quorum with `signer_resolution = "concrete"` | Validate K-of-N against this quorum | Validation proceeds (concrete is built-in) |
| TV-Q2 | Quorum with `signer_resolution = "identity-resolved"`; EXTENSION-IDENTITY installed and configured | Validate K-of-N | Resolution succeeds; validation proceeds |
| TV-Q3 | Quorum with `signer_resolution = "identity-resolved"`; EXTENSION-IDENTITY NOT installed | Validate K-of-N | Error `quorum_resolver_unavailable` with `mode_name="identity-resolved"` and `available_modes=["concrete"]` |
| TV-Q4 | Quorum with `signer_resolution = "future-mode-xyz"` | Validate K-of-N | Error `quorum_resolver_unavailable` |
| TV-Q5 | Quorum at boot before EXTENSION-IDENTITY's configure has run | Validate K-of-N referencing identity-resolved mode | Error C2 path; subsequent retry after configure succeeds |

---

## 6. Handler operations

**Path-as-resource (MUST).** All four handler operations follow path-as-resource per `ENTITY-CORE-PROTOCOL.md` §3.2 (architectural-side MUST). The operation's resource targets the tree binding location; the params carry the operation fields. Calling `system/quorum:create` (or `:update` / `:publish`) without a resource MUST return **`400 path_required`** (`GUIDE-EXTENSION-DEVELOPMENT.md` §171 is the authority for this code). Content-store-only writes use the V7 kernel's `tree:put` operation directly with a content-store-only flag, NOT the substrate's handler ops.

### 6.1 `system/quorum:create`

Instantiate a quorum entity.

**Params:** `{signers: [hash], threshold: uint, signer_resolution?: string, name?: string, metadata?: any}`
**Result:** `{quorum_id: hash}`

Writes the `system/quorum` entity at `system/quorum/{quorum_id_hex}`. The quorum entity is structural (not signed). Authorization for `:create` is per coherent-capability §8.

### 6.2 `system/quorum:update`

Produce a `quorum-update` attestation per §3.2.

**Params:** `{quorum_id: hash, new_signers: [hash], new_threshold: uint, supersedes?: hash}`
**Result:** `{update_hash: hash}`

Validates structural invariants (`new_threshold ≥ 1`; `new_threshold ≤ |new_signers|`). Delegates to `EXTENSION-ATTESTATION:create` with the quorum-update properties shape:

```
EXTENSION_ATTESTATION.create({
  attesting:  quorum_id,
  attested:   quorum_id,
  properties: {
    kind:           "quorum-update",
    new_signers:    new_signers,
    new_threshold:  new_threshold
  },
  supersedes: supersedes
})
```

Returns the unsigned attestation hash; signature gathering (K-of-N from the current signer set) is the caller's responsibility per V7 patterns.

### 6.3 `system/quorum:publish`

Produce a `quorum-publish` attestation per §3.3.

**Params:** `{quorum_id: hash, signers: [hash], threshold: uint, published_handle?: hash, properties?: map, supersedes?: hash}`
**Result:** `{publish_hash: hash}`

Validates `signers` and `threshold` match `current_signer_set(quorum_id)` for the initial publish (no supersedes). Delegates to `EXTENSION-ATTESTATION:create` with the quorum-publish properties shape (merging `published_handle` and consumer-supplied `properties` into the attestation's properties map):

```
EXTENSION_ATTESTATION.create({
  attesting:  quorum_id,
  attested:   quorum_id,
  properties: merge({
    kind:               "quorum-publish",
    signers:            signers,
    threshold:          threshold,
    published_handle:   published_handle  ; if provided
  }, consumer_properties),
  supersedes: supersedes
})
```

Subsequent publishes signed by the previous quorum per §3.3.

### 6.4 `system/quorum:verify`

Validate K-of-N signatures against a quorum (helper-wrapping op).

**Params:** `{entity_hash: hash, quorum_id: hash}`
**Result:** `{valid: bool, signed_by: [hash]}` — `signed_by` is the set of constituents whose signatures were verified

Wraps `current_signer_set` + `verify_k_of_n_signatures` for callers that don't want to call the helpers directly.

### 6.5 Who calls quorum operations? (consumer-extension boundary)

Quorum operations are NOT identity-specific. Any consumer extension that needs to manage a quorum calls EXTENSION-QUORUM's operations directly. Specifically:

- **Identity** (per `EXTENSION-IDENTITY.md`): when an identity's quorum membership changes (e.g., the user adds a new backup key or rotates an existing one), the identity's controller (or a tool acting on the identity's behalf) calls `system/quorum:update` on the identity's `trusts_quorum`. Identity does NOT define its own quorum-update kind.
- **Group** (per future EXTENSION-GROUP v1.5): when a group's quorum membership changes (e.g., admins add a new admin or remove a departing one), the group's controller calls `system/quorum:update` on the group's quorum. Same operation; same kind.
- **Cluster** (planned): when a cluster's voter set changes, calls `system/quorum:update` on the cluster's quorum.
- **Standalone use** (e.g., a multi-sig committee with no identity wrapper): the committee's authorized caller invokes `system/quorum:update` directly.

In all cases, the K-of-N authorization rule is the same (current quorum constituents must sign K-of-N over the new quorum-update attestation). The CALLER varies; the OPERATION and the KIND are uniform.

**For constituent key rotation specifically:**
- In `concrete` resolution mode (default): a constituent's slot is pinned to a specific peer hash. If that peer rotates their keypair (their peer hash changes), the slot is invalidated. To recover: do a `system/quorum:update` swapping the old peer hash for the new one.
- In `identity-resolved` resolution mode (typical for group quorums): a constituent's slot is pinned to an identity reference. The identity's underlying controller rotation is absorbed transparently by the resolver (per §5.2). No quorum-update needed for constituent key rotation.

Choice of mode is per-quorum (set on the `signer_resolution` field at quorum creation).

---

## 7. Storage

```
system/quorum/
   {quorum_id_hex}                          ← quorum entity (structural; not signed)
   {quorum_id_hex}/event/{hash_hex}         ← quorum-update + quorum-publish
                                              attestations under this quorum
                                              (per EXTENSION-ATTESTATION; this is
                                               EXTENSION-QUORUM's storage convention)
```

**Hash-segment encoding.** All hash-typed segments encode as the lowercase hex string of the full `system/hash` byte sequence (algorithm-byte prefix + digest).

**Hash-segment disposition (`SPECIFICATION-FORMAT.md` §8.4.6, `[normative]`).** Both segments above are **`[hold-and-fetch]` — format-free.** `{quorum_id_hex}` is the quorum entity's own `content_hash` and `{hash_hex}` is the attestation's; a consumer reaches this subtree holding the hash already (from `peer-config.trusts_quorum`, from the attestation that arrived, or from the entity it just fetched). **Use them verbatim at whatever width their own format byte implies** — do not re-derive either under the local format, and do not state or assume a width. Neither is a value two parties compute independently, so neither is pinned: a quorum running a non-floor home format addresses its own events in its own space, coherently.

Consumer extensions reference `system/quorum/{quorum_id_hex}` directly when they need to point at a quorum (e.g., identity's `peer-config.trusts_quorum` field).

The `system/quorum/{quorum_id_hex}/event/...` subtree holds the quorum's self-event attestations. EXTENSION-QUORUM's storage convention (per the principle in `EXTENSION-ATTESTATION.md` §7 that consumers choose paths). This subtree is the canonical location for `current_signer_set` to walk.

---

## 8. Coherent capability

`system/quorum:create` / `:update` / `:publish` are the proper authorized path for instantiating and updating quorum entities. Direct `tree:put` to `system/quorum/...` paths is permitted but bypasses the quorum handler's validation. Application-level capability grants SHOULD cover the `system/quorum:*` operations rather than raw `tree:put`. Follows the Coherent Capability principle.

---

## 9. Conformance

### 9.1 MUST

- Implementations MUST provide the `system/quorum` type per §3.1.
- Implementations MUST provide `verify_k_of_n_signatures` and `current_signer_set` per §4.
- Implementations MUST treat `quorum-update` and `quorum-publish` as `system/attestation` entities with the conventions in §3.2 and §3.3 (NOT as separate entity types).
- Implementations MUST provide the `concrete` signer-resolution mode per §5.1.
- Implementations MUST provide the resolver-registration hook per §5.2.
- Implementations MUST fail-closed (reject with `quorum_resolver_unavailable`) when a quorum specifies a `signer_resolution` mode for which no resolver is registered, per §5.3.1, and pass cross-impl test vectors TV-Q1 through TV-Q5.
- Implementations MUST store quorum entities and self-event attestations at the paths defined in §7.
- Implementations MUST NOT route quorum entities through V7's `verify_capability_chain` machinery — quorum entities are non-cap entities.
- Implementations MUST maintain an index for `quorum-update` / `quorum-publish` attestation lookup (per `current_signer_set`'s walk via `find_attestations_targeting`). Per `EXTENSION-ATTESTATION.md` §9.1, the `attested` and `properties.kind` indexes provide this.
- Implementations MUST cache `current_signer_set` results per `quorum_id` and satisfy the cache-invalidation contract per §4.2.1 (invalidate on successful local op completion AND on validated attestation arrival; do NOT invalidate on failed validation or raw `tree:put` bypass). MUST pass cross-impl test vectors TV-QF12 through TV-QF15. Implementations MUST document which mechanism (A or B per §4.2.1) they use to satisfy the validate-accept invariant; the cross-impl conformance harness verifies the post-state contract via TV-QF12–TV-QF15 regardless of mechanism choice.
- Implementations MUST provide `is_quorum_id(hash, ctx)` per §4.3 with path-based lookup at `system/quorum/{hex(hash)}`. MUST pass cross-impl test vectors TV-Q6 through TV-Q9.
- Implementations MUST fully implement historical-state resolution per §4.2: `current_signer_set(quorum_id, ctx, as_of)` MUST return the signer set + threshold live at the `as_of` timestamp; the resolver hook MUST honor `as_of` correspondingly. MUST pass cross-impl test vectors TV-Q-V16a through TV-Q-V16c.
- Implementations MUST enforce `max_resolver_depth = 8` and cycle detection on resolver handlers per §5.2. MUST return `identity_resolver_max_depth_exceeded` on depth exceedance and `identity_resolver_cycle` on cycle detection. MUST pass TV-Q-V-IDENTITY-2 and TV-Q-V-IDENTITY-2-cycle.
- All `system/quorum:*` handler ops follow path-as-resource (ENTITY-CORE-PROTOCOL.md §3.2 MUST); `:create` / `:update` / `:publish` without a resource target MUST return **`400 path_required`** (authority: `GUIDE-EXTENSION-DEVELOPMENT.md` §171).
- **Handler-op type registration:** the four `system/quorum:*` ops register `input_type` / `output_type` per ENTITY-CORE-PROTOCOL.md §3.7 convention (`{handler-path}/{op-name}-request` / `-result`). Type definitions MUST be installed at `system/type/{type_name}` during handler installation.
- **Signature ingestion:** signatures arriving in `envelope.included` are bound at V7 invariant pointer paths by the dispatcher per ENTITY-CORE-PROTOCOL.md §6.5. `verify_k_of_n_signatures` MUST find ingested signatures via the standard `find_signature_by_signer` lookup; no quorum-specific ingestion surface is required.

### 9.2 SHOULD

- Implementations SHOULD expose all four handler operations per §6.

### 9.3 MAY

- Implementations MAY accept additional `metadata` fields on quorum entities per §3.1.
- Implementations MAY accept additional `properties` keys on `quorum-update` / `quorum-publish` attestations beyond the conventions in §3.2 / §3.3 (consumer-extension hooks).

---

## 10. Cross-extension invariants

- **Three-parallel-mechanisms invariant (normative).** Three structurally distinct entity-validation classes — V7 capability tokens (validated by `verify_capability_chain`), `system/attestation` entities (validated per `EXTENSION-ATTESTATION.md` §4 + consumer rules), `system/quorum` entities (validated per this spec's §4). Cap-chain verification MAY read attestation state via the `IdentityBindingChecker` hook (read-only; for grantee-binding lookup); cap-chain verification MUST NOT validate attestations as caps. Attestation validation MUST NOT call `verify_capability_chain`. Quorum validation MUST NOT call `verify_capability_chain`. No shared validator across the three classes. See `SYSTEM-IDENTITY-COMPOSITION.md` §5.
- **Quorum self-events are attestations.** `quorum-update` and `quorum-publish` are NOT independent entity types; they are `system/attestation` entities with kind-discriminated semantics per §3.2 and §3.3.
- **No cyclic dependency on identity.** EXTENSION-QUORUM has no compile-time dependency on EXTENSION-IDENTITY. Identity-resolved mode is registered at runtime via §5.2.

---

## 11. Document history

| Version | Date | Notes |
|---|---|---|
| 1.2 | — | Substrate cleanup pass per `proposals/implemented/PROPOSAL-SYSTEM-PEER-RENAME-AND-SUBSTRATE-CLEANUP.md` (Revision 3). **PR-4** §3.3: `published_handle` prose abstracted — drops the "identity-layer" residue (was: "consumer-extension hook (e.g., identity sets to controller's key in 3-key default or identifier's key in 4-key advanced)"); now reads as a generic consumer-extension hook for publishing a primary peer-hash, with substrate neutrality on field semantics (each consumer extension defines what `published_handle` means within its own framework). Future consumers (group, cluster, VC) use the field with their own semantics without inheriting identity's connotations. **PR-5** §3.4 added: "Closed-namespace ownership" normative paragraph — the `system/quorum/...` subtree is owned by EXTENSION-QUORUM; quorum entities + self-events bind there; consuming extensions (history tracking transitions, role referencing authority) MUST use their own top-level namespace, NOT nest inside `system/quorum/{q}/`. Mirrors EXTENSION-ATTESTATION §7. Closes R-7' (the surfaced namespace collision). **PR-6** §5.2 added: "Multi-registration semantics" — `register_resolver(mode_name, ...)` for an already-registered `mode_name` MUST return `error: resolver_already_registered`; no silent override or stack; idempotent same-handler re-registration is impl-defined; replacement requires explicit unregistration first; `unregister_resolver` is OUT OF SCOPE for v2. Pins fail-closed semantics consistent with §5.3.1 cases C2/C3/C4. Companion: V7 v7.40 (PR-1 V7 type rename + PR-8 cap-resource); EXTENSION-ATTESTATION v1.2 (substrate cleanup PR-2/PR-3/PR-7). No wire-format change. |
| 1.1 (Amendment 1) | — | Per `proposals/implemented/PROPOSAL-IDENTITY-V3.2-MIGRATION-FIXES.md` Amendment 1 (second-round cross-impl feedback). §9.1 conformance gains two pointer lines: handler-op type registration per V7 §3.7 convention (SPEC-24); signature ingestion delegated to V7 §6.5 dispatcher-level (SPEC-25) — `verify_k_of_n_signatures` finds ingested signatures via standard `find_signature_by_signer`. Substantive normative text lives in V7 v7.37. No version bump. |
| 1.1 | — | Cross-impl-feedback batch (`proposals/implemented/PROPOSAL-IDENTITY-V3.2-MIGRATION-FIXES.md`). Items: SI-6 (§4.2.1 mechanism options — sync-hook OR routing; both produce equivalent post-state); SI-7/SI-22 (§6 path-as-resource MUST); SI-12 (§3.3 `quorum-publish` "previous" pinning — prior snapshot, not resolved); SI-15 (§4.2 trust model: validate-once-on-arrival; cold-start posture); SI-16 (§4.2 + §5.2 `as_of` parameter; full historical-state resolution MUST); SI-17 (`ctx.resolve_identity` → `resolve_peer_pubkey` rename in §4.1); SI-21 (§10 three-parallel-mechanisms wording tightened); IDENTITY-2 (§5.2 `max_resolver_depth = 8` + cycle detection). Conformance: TV-Q-V16a–c, TV-Q-V-IDENTITY-2, TV-Q-V-IDENTITY-2-cycle added. No wire-format change. |
| 1.0 (Amendment 1) | — | **Amendment absorbing Go team round-2 landed-review feedback** (`entity-core-go/docs/reviews/FEEDBACK-IDENTITY-FOUNDATIONS-LANDED-REVIEW.md` §2.1, §2.3). Two HIGH/MEDIUM items: **§4.2.1 cache invalidation contract** added — invalidation MUST happen on successful local op completion AND on validated attestation arrival; MUST NOT happen on failed validation or raw `tree:put` bypass; cross-impl test vectors TV-QF12–TV-QF15. **§4.3 `is_quorum_id` defined** — path-based lookup at `system/quorum/{hex(hash)}` with cross-peer scope, race semantics during bootstrap/sync catch-up; cross-impl test vectors TV-Q6–TV-Q9. Both items fill spec gaps that EXTENSION-IDENTITY §3.6 and §4.2 referenced without defining. No version bump (v1.0 absorbs); spec just landed and no impl has shipped against it. |
| 1.0 | — | Initial spec, promoted from `PROPOSAL-EXTRACT-QUORUM-PRIMITIVE.md`. Standalone primitive for K-of-N node + validator + lifecycle attestation conventions; consumed by EXTENSION-IDENTITY and future K-of-N consumers. |
