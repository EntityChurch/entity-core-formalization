# Identity Extension — Normative Specification

**Version**: 3.10

**Status**: Active
**Depends**: ENTITY-CORE-PROTOCOL.md (v7.40+); EXTENSION-ATTESTATION.md (v1.2+); EXTENSION-QUORUM.md (v1.2+)
**Related**: EXTENSION-ROLE.md (consumes the controller's authority via the local peer→controller cap), EXTENSION-NETWORK.md (sync conventions), EXTENSION-GROUP.md (consumes identity as a building block; group quorums use `signer_resolution: "identity-resolved"` mode registered by this extension), PLAN-REGISTRY-AND-DISCOVERY-LANDSCAPE.md (registry layer used for `public/` attestation broadcast)
**Synthesis**: SYSTEM-IDENTITY-COMPOSITION.md (single-entry-point overview of the three-extension layering); EXPLORATION-IDENTITY-LENSES-AND-CONVERGENCE.md (the design path that drove the substrate split); EXPLORATION-IDENTITY-CONSOLIDATED-REVIEW.md (the v2.0 unified-attestation key-graph design that v3.2 carries forward)
**Encoding**: ENTITY-CBOR-ENCODING.md (ECF)

---

> **Path notation.** Paths in this document use peer-relative notation (without leading `/{peer_id}/`). All peer-relative paths resolve to the local peer's namespace: `system/identity/internal/cert/{h}` means `/{local_peer_id}/system/identity/internal/cert/{h}`. Every path in the entity tree is absolute at rest — rooted at a peer identity. See `ENTITY-CORE-PROTOCOL.md` §1.4 for the path model. Cross-peer examples use absolute paths with explicit peer identities.

> **Notation policy.** This spec uses cryptographic-structural vocabulary. Peers are denoted `P_a`, `P_b`, `P_c`. When a peer's function-in-graph matters: `P_quorum`, `P_controller`, `P_agent`, `P_identifier`. Keys are denoted `K_a`, `K_b`, etc. for the cryptographic-substrate level (the keypair of peer `P_x`). Quorums are `Q_a`, `Q_b`. Generic abstract entities use `X`, `Y`, `Z`. Narrative party names (Alice, Bob) appear only in user-facing guides, not in this spec body.

> **"Role" reserved for `EXTENSION-ROLE.md`.** The noun "role" refers exclusively to RBAC-style capability-grant template assignment per `EXTENSION-ROLE.md` ("admin role", "guest role"). The identity-side concept — a peer's structural position in the identity graph — uses the noun **"function"** (controller function, agent function, identifier function, etc.), or names the specific function directly. The two are orthogonal: a peer can be the controller of an identity AND hold the admin role on a peer. See §14.5 disambiguation notes.

> **Vocabulary note.** This extension models identity as a **cert-chain framework**: a quorum sits at the structural root, certs confer functions (controller / agent / identifier / app-defined) to specific peers, and lifecycle events (`identity-rotation-handoff`, `identity-rotation-recovery`, `identity-retirement`) maintain the cert tree. Quorum self-events (`quorum-update`, `quorum-publish`) live in `EXTENSION-QUORUM.md`. NOT `delegation` — V7 reserves "delegation" for capability-token chain links; identity uses `cert` for structural certification. Every kind name in §4 is namespace-prefixed with `"identity-"` to avoid collisions with V7's vocabulary table and with kinds defined by other consumer extensions. Standard cert function names align with established literature (DID controllers; OCAP agents; PKI/DID identifiers).

---

## 1. Overview

The identity extension provides multi-peer identity management on top of V7. **An identity is a peer graph rooted at a quorum, with certs (function-discriminated) conferring authority to peers and lifecycle events maintaining the cert tree.** A K-of-N quorum (per `EXTENSION-QUORUM.md`) sits at the structural root; controllers are certified by the quorum; agents (per-device daemons) are certified by a controller; optionally a separate identifier peer is certified by a controller for hygiene-rotation independence.

Identity v3.2 is a **structured composition layer** over the substrate primitives `EXTENSION-ATTESTATION` and `EXTENSION-QUORUM`. The mechanics (signature validation, supersedes chains, liveness checks, K-of-N validation, signer-set resolution) live in the primitives; identity actively composes them — registering an `identity-resolved` resolver against EXTENSION-QUORUM at install time; defining four `identity-*` `properties.kind` values; defining validators (`identity_topology_for`, `identity_is_quorum_link`, `identity_is_authorized_revoker`, `identity_verify_cert`) that orchestrate substrate helpers under identity-specific topology rules; and orchestrating substrate ops + V7 cap-layer ops + sync-hook side effects in single user-visible flows like `:configure` and `:create_attestation`. Identity contributes:

- The convention for `properties.kind` and `properties.function` on identity-context attestations.
- The validation predicates and topology rules identity imposes (`identity_topology_for`, `identity_is_quorum_link`, `identity_is_authorized_revoker`, `identity_verify_cert`).
- The chain-walking semantics (walk attesting back to a quorum).
- The handle-bearing-cert distinction and contact-side caching semantics.
- The publication-mode semantics for agent certs (internal / public / per-relationship / embedded).
- Sub-controller chains (recursive controller certs).
- Lifecycle event semantics specific to identity.
- Recovery flow logic.
- Storage path conventions (per audience tier).
- Sync surface declaration (dual-subtree: `system/identity/public/...` AND `system/quorum/{trusts_quorum}/...`).
- Registration of `identity-resolved` signer-resolution mode against `EXTENSION-QUORUM`'s hook.

This extension defines:
- Two identity-owned types: `system/identity/peer-config` (per-agent local state) and `system/identity/identity-binding` (helper inner type).
- Four `properties.kind` values for identity-context `system/attestation` entities: `"identity-cert"` (with `properties.function`), `"identity-rotation-handoff"`, `"identity-rotation-recovery"`, `"identity-retirement"`. Plus identity-specific authority rules over the universal `"revocation"` kind.
- Standard cert functions: `controller` (authority to delegate), `agent` (authority to act on behalf), `identifier` (IS the identity from outside; 4-key only). App-defined functions allowed.
- Sub-controller chains: a controller cert can authorize another controller cert; chain terminates at the quorum.
- Seven handler operations: `configure`, `create_quorum`, `create_attestation`, `supersede_attestation`, `revoke_attestation`, `publish_attestation`, `process_attestation`.
- Identity-specific validators (orchestration + predicates per §3.6).
- Path conventions establishing audience separation (`internal/`, `public/`, `relationships/{contact_id}/`, `contacts/`, `peer-config`).

This extension does **not** define:
- The `system/attestation` entity type or its mechanics (lives in `EXTENSION-ATTESTATION.md`).
- The `system/quorum` entity type, K-of-N validator, or quorum lifecycle events (lives in `EXTENSION-QUORUM.md`).
- V7 chain verification changes — chains stay pure V7.
- Permission grants to others (that's `system/role`).
- Multi-user logical groups (that's `system/group`).
- Coordinated peer clusters with leader election or replication (that's `system/cluster`, planned).

### 1.1 Configuration progression

The identity extension is opt-in. Layered configurations form a continuum:

1. **V7-only** (don't install this extension): each peer has a self-rooted identity (peer's keypair = peer's identity). Single-device, single-key, no recovery, no rotation. Valid when those features are not wanted.
2. **1-of-1 quorum**: structurally complete, but provides no recovery. Useful when the architectural shape is wanted but recovery is not.
3. **Three-key default** (RECOMMENDED): K-of-N quorum + controller + agents. Recovery + multi-device + stable cross-peer recognition.
4. **Multi-key advanced (four-key)**: adds an identifier peer for hygiene-rotation independence (controller rotates frequently without contacts re-validating).
5. **Multi-binding**: an agent participates in multiple distinct identities (e.g., personal + service-account on the same machine).
6. **Concurrent multi-controller**: multiple controllers live concurrently under the same quorum (desktop + phone deployments).
7. **Sub-controller chains**: controller certs issued by another controller (delegated management hierarchies).
8. **App-defined functions**: app-specific authority via custom function values.
9. **Parent-managed**: controller keys held by parents; subject acquires own keys over time via `quorum-update` ceremonies.

See §11 for full configurations.

---

## 2. The peer graph

The identity-graph view: peers are nodes; certs are directed edges. A quorum is a special node type (per `EXTENSION-QUORUM.md` §3.1) whose authority is collective K-of-N rather than single-key.

### 2.0 Substrate

**Everything is a peer; identity assigns functions to peers via attestations.** A peer is the substrate (a keypair + its tree); a function (controller, agent, identifier, app-defined) is structural — established by an `identity-cert` attestation referencing the peer. Quorums sit at the structural root and confer authority via K-of-N signed certs. Functions emerge from graph position; they are not stored on peers.

### 2.1 Identity is a cert-chain framework

The identity graph terminates at the quorum. Every cert in the graph chains via `attesting` references back to a top-level cert whose `attesting = quorum_id`. The verifier walks this chain to validate any cert. Sub-controller chains permit intermediate controllers; chain depth is bounded (`EXTENSION-ATTESTATION.md` §5.1 `walk_attesting_chain` defaults `max_depth: 32`; identity sub-controller chains are typically shallow).

### 2.2 Three structurally distinct entity-validation classes

Identity maintains the **three-parallel-mechanisms invariant**:

1. V7 capability tokens (validated by V7's `verify_capability_chain`; includes multi-sig caps).
2. `system/attestation` entities (validated by `EXTENSION-ATTESTATION` helpers + identity's predicates per §3.6).
3. `system/quorum` entities (validated by `EXTENSION-QUORUM`'s `verify_k_of_n_signatures`).

All three classes are structurally distinct entity types. No shared validation path. Identity attestations are NEVER routed through V7's `verify_capability_chain`; quorum entities are NEVER routed through it either. See §12.3.

### 2.3 Function correspondence

| Function | Established by | Custody profile (typical) |
|---|---|---|
| **quorum constituent** | Direct membership in `system/quorum.signers` (no attestation kind) | Cold-stored — hardware token, paper, secondary device, trusted holder |
| **controller** | `identity-cert` with `function="controller"`. Top-level controller: `attesting = quorum_id`, K-of-N signed. Sub-controller: `attesting = another controller's key`, single-sig. | Hot, encrypted at rest |
| **agent** | `identity-cert` with `function="agent"`. `attesting` is the issuing controller (3-key) or identifier (4-key). | Hot, on each running device daemon |
| **identifier** (4-key only) | `identity-cert` with `function="identifier"`. `attesting` is the controller. | Hot, encrypted at rest; rotates rarely |
| `<app-defined>` | `identity-cert` with `function=<custom>`. `attesting` is the controller. | Per app convention |

In the **three-key default**, the controller also serves as the identifier (no separate identifier function); the controller's key IS the contact-side handle. In the **four-key advanced** shape, the identifier function is filled by a separate peer; contacts cache the identifier's key as the handle, allowing the controller to rotate without contact disturbance.

---

## 3. Type definitions

### 3.1 Quorum reference

Identity does NOT define a quorum type. It references `system/quorum` (per `EXTENSION-QUORUM.md` §3.1) directly. An identity's quorum lives at `system/quorum/{quorum_id_hex}` like any other quorum. Identity quorums typically use `signer_resolution: "concrete"` (the default) — constituents are pinned to specific peer hashes.

### 3.2 Peer-config

```
system/identity/peer-config := {
  fields: {
    trusts_quorum:        {type_ref: "system/hash"}
                                                  ; reference to the system/quorum entity
                                                  ; this agent trusts as its identity authority
                                                  ; (resolves via EXTENSION-QUORUM)
    controller_grants:    {array_of: {type_ref: "system/capability/grant-entry"}}
                                                  ; what the controller's key is authorized
                                                  ; to do on this peer (used to issue the
                                                  ; local peer→controller cap)
    bindings:             {array_of: {type_ref: "system/identity/identity-binding"},
                           optional: true}
    metadata:             {type_ref: "primitive/any", optional: true}
  }
}
```

The `trusts_quorum` field references a `system/quorum` entity at `system/quorum/{trusts_quorum_hex}`. A host machine MAY operate as multiple agents (one per identity it serves); each agent has its own peer-config in its own namespace; peer-configs MUST NOT share state across identities.

**`controller_grants` resolution rule under sub-controller chains (normative).** With sub-controller chains (per §4.2c), an identity has a top-level controller cert (signed K-of-N by the quorum) plus zero or more sub-controller certs (each signed by a higher controller). The `controller_grants` field on `peer-config` describes what the controller's key is authorized to do on this peer (used to issue the local peer→controller cap during `configure`).

When sub-controller chains are present, `controller_grants` applies to the **top-level controller cert** only — the cert whose `attesting` is the trusted quorum. Resolution algorithm:

```
resolve_controller_for_grants(peer_config, ctx) → cert or null
  ; Returns the live top-level controller cert this peer's controller_grants apply to.

  ; Walk attesting chains from any candidate controller cert back to the quorum
  ; per peer_config.trusts_quorum; return the cert that terminates at the quorum
  ; (i.e., the cert whose attesting is the trusted quorum_id).

  trusted_quorum = peer_config.trusts_quorum
  candidates = ATTESTATION.find_attestations_targeting(
    peer_hash=<this peer's keypair hash>,
    predicate=lambda a, _:
      a.properties.get("kind") == "identity-cert"
      and a.properties.get("function") == "controller"
      and a.attesting == trusted_quorum,
    ctx=ctx
  )
  live = [c for c in candidates if ATTESTATION.is_attestation_live(c, ctx)]
  if len(live) == 0: return null
  if len(live) > 1:
    ; Multi-controller deployments per §11.6; return the head per ATTESTATION's
    ; deterministic tie-break (lowest content_hash).
    return min(live, key=lambda c: c.content_hash)
  return live[0]
```

**Sub-controllers do NOT inherit `controller_grants`.** Each sub-controller cert is issued by a higher controller for delegated management within the identity's namespace; what a sub-controller is authorized to do on local peers is determined by the V7 caps the sub-controller's signing keypair holds (issued by the local peer when it accepts the sub-controller cert), not by the top-level `controller_grants`. If an application wants sub-controllers to have the same local-peer authority as the top-level controller, the local peer issues equivalent V7 caps to each sub-controller's keypair separately.

This resolution rule means:
- `controller_grants` describes top-level-controller capability scope only.
- Sub-controllers are managed via V7 caps on their own keypairs, separate from `controller_grants`.
- Multi-controller (concurrent top-level controllers under same quorum, per §11.6) all share the same `controller_grants` scope.

### 3.3 Identity attestation conventions

Identity does NOT define an attestation entity type. It uses `system/attestation` (per `EXTENSION-ATTESTATION.md`) directly with identity-specific `properties` shape.

**`properties.kind` values used by identity** (registered in the `EXTENSION-ATTESTATION.md` §3.2 kind-ownership table):
- `"identity-cert"` — active certification of a peer for a function
- `"identity-rotation-handoff"` — graceful key roll (dual-sig)
- `"identity-rotation-recovery"` — compromise-recovery key replacement (K-of-N)
- `"identity-retirement"` — explicit cert retirement (K-of-N)

Within identity's storage paths (`system/identity/internal/...`, `system/identity/public/...`, `system/identity/relationships/...`), these kinds MUST be unambiguous (identity's validator dispatches on them). All identity-specific kinds are namespace-prefixed with `"identity-"` to avoid potential collisions with kinds defined by other extensions; this is best practice for consumer-extension kind naming per `EXTENSION-ATTESTATION.md` §3.2.

**Kinds identity DOES NOT define:**
- `"revocation"` — owned by `EXTENSION-ATTESTATION` (universal mechanism per §3.3 of that spec). Identity USES revocation by applying its authority-revocation rules (§3.6) on top of the generic primitive.
- `"quorum-update"`, `"quorum-publish"` — owned by `EXTENSION-QUORUM`. When an identity's quorum membership changes, the identity's controller calls `EXTENSION-QUORUM`'s `system/quorum:update` operation on the identity's `trusts_quorum`. Identity is a CONSUMER of these operations; it does not duplicate the kind definitions or the operations.

**Operations on the identity's quorum live in `EXTENSION-QUORUM`, not here.** Examples:
- Add a backup key to the identity's quorum: call `QUORUM.system/quorum:update(quorum_id=trusts_quorum, new_signers=[...], new_threshold=...)`. Gather K-of-N signatures from current constituents. Submit.
- Publish the identity's current quorum state for contacts: call `QUORUM.system/quorum:publish(quorum_id=trusts_quorum, signers=[...], threshold=..., properties={published_handle: <handle>})`. Gather K-of-N. Submit.

These flow through `EXTENSION-QUORUM`'s handler ops; identity's contribution is choosing WHEN to call them and what `published_handle` value to use.

**For `kind="identity-cert"`:**
- `properties.function`: `"controller"` | `"agent"` | `"identifier"` | `<app-defined>` (REQUIRED)
- `properties.mode`: `"internal"` | `"public"` | `"per-relationship"` | `"embedded"` (REQUIRED on ALL identity-certs, not just agents — explicit audience indication eliminates the runtime shape lookup; valid modes per function in §4.2)
- `properties.contact_id` (when `mode="per-relationship"`): peer hash of the named contact (REQUIRED)

**For `kind="identity-rotation-handoff"`, `kind="identity-rotation-recovery"`, `kind="identity-retirement"`:**
- `properties.target_cert`: hash of the cert being rotated/recovered/retired (REQUIRED)
- `properties.old_handle` (when target is handle-bearing): prior handle hash (REQUIRED for `identity-rotation-recovery` on handle-bearing certs; OPTIONAL for others)

**For `kind="revocation"`:**
- Per `EXTENSION-ATTESTATION.md` §3.3 generic revocation; identity applies its authority-revocation rules per §3.6 (`identity_is_authorized_revoker`).

### 3.4 Identity-binding

Helper inner type used in `peer-config.bindings`. Records this agent's role in one identity.

```
system/identity/identity-binding := {
  fields: {
    handle_cert:                 {type_ref: "system/hash"}
                                                  ; hash of the cert that pins
                                                  ; the contact-side handle for this identity
                                                  ; (in 3-key default: the controller cert;
                                                  ;  in 4-key advanced: the identifier cert)
    agent_cert:                  {type_ref: "system/hash"}
                                                  ; hash of the cert(function=agent)
                                                  ; for this agent peer under this identity
    label:                       {type_ref: "primitive/string", optional: true}
    metadata:                    {type_ref: "primitive/any", optional: true}
  }
}
```

A field-only inner type (lives inside `peer-config.bindings`); not stored as an independent entity. Both `handle_cert` and `agent_cert` are content hashes of `system/attestation` entities at identity's storage paths.

**v3.3 runtime behavior (normative).** Implementations MUST accept and store `bindings` array entries on `peer-config` configure / supersede / publish round-trips. Field round-trips MUST be exact (byte-equivalent on canonical encoding). Implementations MUST NOT interpret `bindings` for runtime dispatch in v3.3 — the multi-identity mechanism in v3.3 is per-peer-namespace peer-configs (per §11.5), not bindings. Apps reading `bindings` for application-level logic do so at their own risk; the field is reserved for normative extension in a future spec version.

### 3.5 Helpers (delegated to primitives)

Identity calls primitives for all generic mechanics:

```
# Signature validation
ATTESTATION.verify_attestation_signature(att, ctx)
ATTESTATION.verify_specific_signer(att, expected_signer, ctx)

# Liveness
ATTESTATION.is_attestation_live(att, ctx, as_of?)

# Graph walks (parameterized)
ATTESTATION.walk_attesting_chain(start, terminate_predicate, ctx)
ATTESTATION.walk_supersedes_chain(start, ctx)
ATTESTATION.find_live_head(start, ctx)

# Lookups
ATTESTATION.find_attestations_targeting(entity_hash, predicate, ctx)
ATTESTATION.find_attestations_by(peer_hash, predicate, ctx)
ATTESTATION.find_revocations_for(attestation_hash, ctx)

# K-of-N validation
QUORUM.verify_k_of_n_signatures(entity_hash, signers, threshold, ctx)
QUORUM.current_signer_set(quorum_id, ctx)

# Quorum identification (per EXTENSION-QUORUM §4.3)
QUORUM.is_quorum_id(hash, ctx)
```

Identity does NOT define duplicate versions of any of these.

### 3.6 Identity-specific validators (orchestration + predicates)

The identity layer contributes the following helpers and validators. Helpers are pure and cheap; validators compose primitive helpers plus identity rules.

**Identity-specific helpers (defined here):**

```
valid_functions() → set[string]
  ; The set of standard cert function values identity recognizes.
  ; App-defined functions are accepted via the "any string" fallback;
  ; this set is for the structural-validation reject-on-unknown check
  ; in identity_verify_cert.
  return {"controller", "agent", "identifier"}
  ; App-defined functions (per §4.2 row 5) are NOT in this set;
  ; identity_verify_cert's check is "function is in valid_functions()
  ; OR function is an app-defined string". Apps that ship custom
  ; function values declare them in their own validator extension.

identity_lifecycle_kinds() → set[string]
  ; The set of identity-context attestation kinds that are NOT
  ; identity-cert kinds. Used by identity_verify_cert's
  ; structural-validation gate.
  return {
    "identity-rotation-handoff",
    "identity-rotation-recovery",
    "identity-retirement",
  }
  ; Note: "revocation" is NOT in this set — it's the universal kind
  ; (per EXTENSION-ATTESTATION.md §3.3); identity validators dispatch
  ; revocation handling separately via authority-revocation rules.

lookup_target_cert(target_ref, ctx) → attestation or null
  ; Resolves a `properties.target_cert` reference (from a lifecycle event
  ; attestation: identity-rotation-handoff, identity-rotation-recovery,
  ; identity-retirement) to the cert entity it targets. The target_ref
  ; is a content_hash of a system/attestation entity; the lookup uses
  ; the local content store + storage path index.
  ;
  ; Two equivalent inputs are accepted:
  ;   - lookup_target_cert(att, ctx)               where att is a lifecycle attestation;
  ;                                                 reads att.properties.target_cert
  ;   - lookup_target_cert(target_hash, ctx)        where target_hash is the cert hash directly

  if target_ref is an attestation entity:
    target_hash = target_ref.properties.target_cert
  else:
    target_hash = target_ref

  if target_hash is null: return null
  return ctx.content_store.get(target_hash)

identity_confers_function(att, function_name, ctx) → bool
  ; Returns true iff att confers function_name on att.attested.
  ; Handles both identity-cert (direct function field) and lifecycle kinds
  ; (function inherited from target_cert).

  match att.properties.kind:
    "identity-cert":
      return att.properties.function == function_name

    "identity-rotation-handoff", "identity-rotation-recovery":
      ; Rotation kinds confer the same function as the cert they're rotating.
      target = lookup_target_cert(att.properties.target_cert, ctx)
      if target is null: return false
      ; Recurse to handle handoff-of-handoff / recovery-of-handoff cases
      return identity_confers_function(target, function_name, ctx)

    "identity-retirement":
      ; Retirement kinds RETIRE the function; the chain ends here as dead.
      ; A retired cert does not confer the function.
      return false

    _:
      return false

walk_cert_chain_to_current_controller(identity_ref, ctx) → cert or null
  ; Used by the `identity-resolved` resolver registered with EXTENSION-QUORUM
  ; (per §6.1). Given a reference to an identity (typically a hash of the
  ; identity's quorum, since the identity is keyed by its trusts_quorum),
  ; walks the cert graph to find the current live top-level controller cert
  ; for that identity, and returns it.
  ;
  ; The "current" choice resolves multi-controller deployments
  ; deterministically: identity §3.2's resolve_controller_for_grants
  ; algorithm picks the live cert with the lowest content_hash when
  ; multiple top-level controllers are concurrent.

  ; Treat identity_ref as a quorum_id (the canonical handle for an identity
  ; in identity-resolved mode is the trusts_quorum hash).
  quorum_id = identity_ref

  ; Find certs whose attesting == quorum_id and which confer function=controller.
  ; The lookup uses the `attesting` index per EXTENSION-ATTESTATION §9.1.
  candidates = ATTESTATION.find_attestations_by(
    peer_hash=quorum_id,
    predicate=lambda a, _:
      identity_confers_function(a, "controller", ctx),
    ctx=ctx
  )

  live = [c for c in candidates if ATTESTATION.is_attestation_live(c, ctx)]
  if len(live) == 0: return null
  if len(live) == 1: return live[0]

  ; Multi-controller — deterministic tie-break by lowest content_hash
  return min(live, key=lambda c: c.content_hash)
```

**Identity-specific validators:**

```
identity_topology_for(att, ctx) → {mode, signer/signers, threshold?, expected_signer?}
  ; Dispatch on att.properties.kind and att.properties.function
  ; to determine signature topology requirements.

  match (att.properties.kind, att.properties.function, QUORUM.is_quorum_id(att.attesting, ctx)):
    ("identity-cert", "controller", true):
      ; Top-level controller cert: K-of-N from quorum
      (signers, threshold) = QUORUM.current_signer_set(att.attesting, ctx)
      return {mode: "k-of-n", signers: signers, threshold: threshold}

    ("identity-cert", "controller", false):
      ; Sub-controller cert: single-sig from issuing controller
      return {mode: "single", expected_signer: att.attesting}

    ("identity-cert", "agent", _):
      ; Agent cert: single-sig from issuing controller (3-key) or identifier (4-key)
      return {mode: "single", expected_signer: att.attesting}

    ("identity-cert", "identifier", _):
      ; Identifier cert: single-sig from issuing controller
      return {mode: "single", expected_signer: att.attesting}

    ("identity-cert", _, _):
      ; App-defined function: single-sig from attesting (default; pinned in v3.3).
      ; Apps requiring custom topology MUST wrap identity_verify_cert in a
      ; consumer-supplied validator; v3.3 does not specify an in-spec override hook.
      return {mode: "single", expected_signer: att.attesting}

    ("identity-rotation-handoff", _, _):
      ; Dual-sig from old + new key
      target = lookup_target_cert(att, ctx)
      return {mode: "dual", signers: [target.attested, att.attested]}
      ; (att.attesting is old key = target.attested; att.attested is new key)

    ("identity-rotation-recovery", _, _):
      ; K-of-N from quorum (recovery is always quorum-driven)
      (signers, threshold) = QUORUM.current_signer_set(att.attesting, ctx)
      return {mode: "k-of-n", signers: signers, threshold: threshold}

    ("identity-retirement", _, _):
      ; K-of-N from quorum (retirement is always quorum-driven)
      (signers, threshold) = QUORUM.current_signer_set(att.attesting, ctx)
      return {mode: "k-of-n", signers: signers, threshold: threshold}

identity_is_quorum_link(att, ctx) → bool
  ; Terminate predicate for chain walks.
  ; Returns true if att is a top-level cert (attesting is a quorum_id).
  return QUORUM.is_quorum_id(att.attesting, ctx)

identity_is_authorized_revoker(revoker, target_cert, ctx) → bool
  ; Returns true if revoker has authority to revoke target_cert per identity's rules.
  ; Identity rule: only the quorum at the root of target_cert's chain can revoke it.
  ; (Plus self-revocation, which is handled at the primitive layer.)

  ; Walk target_cert's chain to find the quorum
  chain = ATTESTATION.walk_attesting_chain(
    target_cert,
    terminate_predicate=identity_is_quorum_link,
    ctx=ctx
  )
  if chain is null: return false

  quorum_id = chain[-1].attesting
  ; revoker must be the quorum_id (or a constituent K-of-N signing on its behalf)
  return revoker == quorum_id

identity_verify_cert(att, ctx) → bool or error
  ; Orchestration entry point. Composes primitive helpers + identity rules.
  ; Topology dispatch precedes signature validation; signatures are validated
  ; in the topology-appropriate variant.

  ; 1. Identity-specific structural validation
  if att.properties.kind != "identity-cert" and \
     att.properties.kind not in identity_lifecycle_kinds():
    return error("not_identity_attestation")
  if att.properties.kind == "identity-cert" and \
     att.properties.function not in valid_functions() and \
     not is_app_defined_function(att.properties.function):
    return error("invalid_function")

  ; 2. Liveness check (primitive; no signature dependency)
  if not ATTESTATION.is_attestation_live(att, ctx):
    return error("not_live")

  ; 3. Authority-revocation check (identity-specific authority rules)
  revocations = ATTESTATION.find_revocations_for(att.content_hash, ctx)
  for rev in revocations:
    if ATTESTATION.is_attestation_live(rev, ctx) and \
       identity_is_authorized_revoker(rev.attesting, att, ctx):
      return error("authority_revoked")

  ; 4. Topology dispatch + topology-appropriate signature validation
  topology = identity_topology_for(att, ctx)
  match topology.mode:
    "k-of-n":
      if not QUORUM.verify_k_of_n_signatures(
          att.content_hash, topology.signers, topology.threshold, ctx):
        return error("k_of_n_failed")
    "single":
      if att.attesting != topology.expected_signer:
        return error("wrong_signer")
      if not ATTESTATION.verify_attestation_signature(att, ctx):
        return error("invalid_signature")
    "dual":
      for signer in topology.signers:
        if not ATTESTATION.verify_specific_signer(att, signer, ctx):
          return error(f"missing_dual_sig: {signer}")

  ; 5. Chain walk back to quorum (for non-top-level certs)
  if not identity_is_quorum_link(att, ctx):
    chain = ATTESTATION.walk_attesting_chain(
      att,
      terminate_predicate=identity_is_quorum_link,
      ctx=ctx
    )
    if chain is null:
      return error("chain_to_quorum_not_found")
    for link in chain[1:]:  ; chain[0] is `att` itself, already validated
      if identity_verify_cert(link, ctx) is error:
        return error("chain_link_invalid")

  return OK
```

**Self-revocation and authority-revocation overlap (informative).** For quorum-issued certs (`att.attesting = quorum_id`), a revocation by the quorum (`rev.attesting = quorum_id`) satisfies BOTH the substrate's self-revocation rule (per `EXTENSION-ATTESTATION.md` §4.3 — `rev.attesting == att.attesting`) and identity's authority-revocation rule (`identity_is_authorized_revoker` returns true because the chain walks back to the quorum). Both rules return the same result (revoked); the order of checks affects only the error reason returned. The substrate's self-revocation check fires first (it is part of `is_attestation_live`), so the resulting error reason is `"not_live"`. Implementations MAY surface the more-specific `"authority_revoked"` reason by checking authority-revocation first; cross-impl conformance does not require a specific reason when both rules apply.

The identity layer's verify is ~60 lines of orchestration + dispatch + identity-specific predicates. The MECHANICS (signature verify, liveness, chain walk, K-of-N, revocation lookup) are all primitive calls.

**Operational invariant (MUST):** identity attestations are NOT routed through V7's `verify_capability_chain` machinery. They are validated by `identity_verify_cert` (which composes attestation + quorum primitive helpers). The three-parallel-mechanisms invariant (§2.2) MUST be preserved.

---

## 4. Identity attestation kinds

### 4.1 Kind table summary

| `properties.kind` | Category | Sig topology | Storage tier | Spec section |
|---|---|---|---|---|
| `"identity-cert"` (function=controller, top-level) | Active cert | K-of-N from quorum | public (3-key) or internal (4-key) | §4.2 |
| `"identity-cert"` (function=controller, sub-controller) | Active cert | single-sig from issuing controller | internal | §4.2 |
| `"identity-cert"` (function=agent) | Active cert | single-sig from controller (3-key) or identifier (4-key) | per `properties.mode` (§4.2a) | §4.2 |
| `"identity-cert"` (function=identifier) | Active cert | single-sig from controller | internal | §4.2 |
| `"identity-cert"` (function=app-defined) | Active cert | per app rules; default single-sig | per app | §4.2 |
| `"identity-rotation-handoff"` | Cert lifecycle | dual-sig (old + new) | same audience tier as target | §4.3 |
| `"identity-rotation-recovery"` | Cert lifecycle | K-of-N from quorum | same audience tier as target | §4.4 |
| `"identity-retirement"` | Cert lifecycle | K-of-N from quorum | same audience tier as target | §4.5 |
| `"revocation"` | Generic (per `EXTENSION-ATTESTATION.md`) | per consumer rule (identity: authority chain) | same audience tier as target | §4.6 |

### 4.2 `"identity-cert"` attestations

The active certification primitive. Confers a function (controller / agent / identifier / app-defined) to a peer under the identity. Verifier walks the cert chain back to the quorum to validate.

`system/attestation` with:
- `properties.kind`: `"identity-cert"`
- `properties.function`: `"controller"` | `"agent"` | `"identifier"` | `<app-defined>` (REQUIRED)
- `properties.mode`: `"internal"` | `"public"` | `"per-relationship"` | `"embedded"` (REQUIRED; per-function constraints below)
- `properties.contact_id` (when mode=per-relationship): peer hash of named contact (REQUIRED)
- `attesting`: quorum_id (top-level) OR controller peer's key (sub-controller-issued)
- `attested`: the peer's key being certified for the function

**Per-function valid modes (normative):**

| Function | Valid modes | Typical | Notes |
|---|---|---|---|
| `controller` (top-level) | `"public"` OR `"internal"` | `"public"` (3-key default; controller IS the handle) OR `"internal"` (4-key advanced; controller is internal management) | Author chooses at create-time based on intended deployment shape. The choice is fixed for this cert's lifetime; future shape changes (issuing identifier cert) don't move this cert. |
| `controller` (sub-controller) | `"internal"` only | `"internal"` | Sub-controllers are always internal management hierarchy. |
| `agent` | any of the four | per use case | `internal` default per privacy-first; `public` for service infrastructure; `per-relationship` for selective disclosure; `embedded` for cap-hand-off scenarios. |
| `identifier` (4-key only) | `"internal"` only | `"internal"` | Cert itself is internal; identifier peer's KEY is the contact-facing handle, surfaced via the agent certs the identifier signs. |
| `<app-defined>` | per app convention | per app | App SHOULD document valid modes for its function values. Default: `"internal"`. |
| `encryption` *(app-defined; registered)* | `"internal"`, `"public"`, `"per-relationship"` | `"public"` for the discoverable handle | **Registrant: `EXTENSION-ENCRYPTION` Tier C** (§4.3/§4.4), its sole owner. `embedded` has no tree path and is out of scope. Certs land at the ordinary mode-derived `system/identity/{audience}/cert/{h}` — ENCRYPTION defines **no** path under `system/identity/` and a sender finds an encryption cert by **filtering `properties.function == "encryption"`**, never by a path segment. |

**Registered app-defined function values.** `<app-defined>` is an open vocabulary: two extensions can adopt the same string with different semantics and nothing detects the collision. A value in use by a landed extension is therefore recorded in the table above with its registrant, and this table is the authority for that vocabulary. `encryption` is the first such registration.

Function-specific semantics:
- **`controller`**: authority to delegate; issues other certs. Top-level (attesting=quorum_id) or sub-controller (attesting=another controller's key).
- **`agent`**: authority to act on behalf of the identity in cross-peer interactions. Signs V7 capability tokens.
- **`identifier`**: IS the identity from outside. 4-key advanced only; in 3-key default the controller IS the identifier.
- **`<app-defined>`**: app-specific authority under the identity. App interprets semantics; identity ensures cert chain to quorum.

**Why `mode` is on all cert kinds (not just agents).** Earlier drafts used a runtime `is_handle_bearing_in_current_shape` lookup to determine controller cert paths based on whether the identity was in 3-key or 4-key shape at validation time. This created a race: during in-flight rotation (transitioning from 3-key to 4-key by issuing a new identifier cert), an existing controller cert's "handle-bearing-ness" could ambiguously change. v3.2 eliminates the race by making the audience explicit at create-time. Each cert's path is fixed when written; subsequent shape changes don't move existing certs. The cert author chooses the mode based on intended deployment.

**`properties.mode` normative job (per PI-12).** The `properties.mode` field is a **storage-path selector**. The (kind, function, mode, [contact_id]) tuple deterministically computes the canonical storage path per §5.3.

Audience semantics (who can read), sync semantics (who receives via subscription/continuation), and handle-bearing semantics (whether this cert participates in handle resolution) are **derived from path namespace and (kind, function)**, NOT from `mode` independently. The derivation table:

| Path namespace | Audience | Sync | Handle-bearing |
|---|---|---|---|
| `system/identity/internal/cert/...` | Identity's own agents only | None (internal) | iff `function=identifier` (4-key advanced) OR `function=controller` sub-controller chains terminate here |
| `system/identity/public/cert/...` | All contacts via registry/two-tier sync | Two-tier | iff `function=controller` (3-key default) |
| `system/identity/relationships/{c}/cert/...` | Named contact only | Three-tier (bilateral subscription) | No (relationship-mode certs are not handles) |
| `embedded` (no tree path) | Holders of the cap that embeds the cert | None | No (embedded certs are ephemeral) |

The four-job overloading of `mode` (path / audience / sync / behavior) is closed at the spec level by this pin: only the path job is normative on `mode` directly; the other three jobs are derived. v3 may refactor `mode` into separate fields; v2 ships with the overloading scoped to the path-selector job.

**Worked examples.**

*3-key default deployment.* Founder quorum (Alice, Bob, Carol; 2-of-3) → controller-cert (function=controller, mode=public) at `system/identity/public/cert/{c}`. Per the derivation table: audience = all contacts via registry (the public path is the registry-broadcast surface); sync = two-tier (contacts pull from `system/identity/public/...`); handle-bearing = YES (function=controller AND under `public/cert/...` → 3-key default; controller IS the contact-side handle). The controller's pubkey IS the user's published handle. Contacts cache it.

*4-key advanced deployment.* Founder quorum → identifier-cert (function=identifier, mode=internal) at `system/identity/internal/cert/{i}`; founder quorum → controller-cert (function=controller, mode=internal, attesting=identifier_hash) at `system/identity/internal/cert/{c}`. Per the table: identifier-cert audience = identity's own agents, sync = none (internal), handle-bearing = YES (function=identifier, 4-key advanced); controller-cert audience = identity's own agents, sync = none (internal), handle-bearing = NO (function=controller under internal namespace; in 4-key the identifier IS the handle, controller is internal management). The identifier's pubkey is what contacts cache as the handle. Controller rotates without contact disturbance. The identifier-cert may publish to `system/identity/public/cert/{i}` separately if/when contacts need to discover it.

### 4.2a Publication modes for agent certs

The same agent cert lives at different paths to express different audiences:

| Mode | Path | Audience | Notes |
|---|---|---|---|
| **internal** (default) | `system/identity/internal/cert/{hash_hex}` | Identity's agents only | Default per §10.2 — privacy by default |
| **public** | `system/identity/public/cert/{hash_hex}` | All contacts via the registry | Public-facing infrastructure |
| **per-relationship** | `system/identity/relationships/{contact_id_hex}/cert/{hash_hex}` | One named contact only | Privacy-preserving sharing |
| **embedded** | inside cap envelopes (no tree path) | Holders of the cap | Time-bounded grants; hand-offs |

An agent peer can have agent certs in multiple modes simultaneously (same `attested` key; different `properties.mode` and storage paths).

### 4.2b Sub-controller chains

A controller cert can be issued by another controller (rather than the quorum directly), enabling delegated management hierarchies. The chain MUST terminate at a top-level controller cert whose `attesting = quorum_id`. Useful for organizations with department-level delegation: a top-level controller issues sub-controller certs to per-department peers; sub-controllers issue agent certs within their scope.

Sub-controller certs always have `properties.mode = "internal"`; they live in `system/identity/internal/cert/{hash_hex}`. The chain-walk via `ATTESTATION.walk_attesting_chain` with `identity_is_quorum_link` as terminate predicate finds the chain's quorum root for any cert (including sub-controller-issued agent certs).

Per-cert authority for sub-controllers is governed by V7 caps on the sub-controller's signing keypair, not by the top-level `peer-config.controller_grants` (per §3.2 resolution rule).

### 4.3 `"identity-rotation-handoff"` attestations

Routine cert rotation when the old cert's key is still available. Used for graceful key roll of any cert (controller, agent, identifier, app-defined).

`system/attestation` with:
- `properties.kind`: `"identity-rotation-handoff"`
- `properties.target_cert`: hash of the cert being rotated (REQUIRED)
- `attesting`: old key (the key being rotated out)
- `attested`: new key (the key being rotated in)
- **Signed dual-sig**: both `attesting` (old) and `attested` (new) keypairs sign

Stored at the same audience tier as the target cert (per §5.3).

**Function inheritance from target_cert (normative).** A handoff/recovery attestation does NOT carry its own `properties.function` field; it inherits the function from the target cert via `properties.target_cert`. Chain-walk predicates filtering by function MUST resolve target_cert to determine the conferred function (per `identity_confers_function` in §3.6). After a handoff `att(old_key → new_key, target=cert_X)`, the chain entry for `new_key`'s function is the handoff itself; the next chain link via `att.attesting = old_key` returns to the prior cert chain. No fresh `identity-cert` issuance is required after a handoff for the new key to be chain-walkable. The same rule applies to `identity-rotation-recovery`. `identity-retirement` does NOT confer the function (per `identity_confers_function`); it terminates the chain dead.

### 4.4 `"identity-rotation-recovery"` attestations

Compromise-recovery cert rotation when the old cert's key is unavailable or compromised. Quorum K-of-N signs to recover.

`system/attestation` with:
- `properties.kind`: `"identity-rotation-recovery"`
- `properties.target_cert`: hash of the cert being recovered (REQUIRED)
- `properties.old_handle`: prior handle (REQUIRED for handle-bearing target certs)
- `attesting`: quorum_id
- `attested`: new key (replacement)
- **Signed K-of-N** by quorum constituents

When a contact's peer processes a handle-bearing rotation-recovery, it MUST validate the K-of-N signatures against the cached `quorum-publish` for the identity (per §9.4 — fail-closed if no `quorum-publish` is cached).

### 4.5 `"identity-retirement"` attestations

Retires a cert without rotation (no replacement). K-of-N from quorum.

`system/attestation` with:
- `properties.kind`: `"identity-retirement"`
- `properties.target_cert`: hash of the cert being retired (REQUIRED)
- `properties.final_supersedes` (optional): references the last live cert in the supersedes chain
- `attesting`: quorum_id
- `attested`: the retired key
- **Signed K-of-N** by quorum constituents

### 4.6 `"revocation"` attestations (generic per `EXTENSION-ATTESTATION.md`)

Per `EXTENSION-ATTESTATION.md` §3.3 generic revocation. Identity applies its authority-revocation rules:

- **Self-revocation** (issuer revokes own attestation): always valid per attestation primitive.
- **Authority revocation** (quorum revokes a cert authorized under it): valid per identity's `identity_is_authorized_revoker` (§3.6).

Cascade revocation is automatic via chain walking (per `identity_verify_cert`).

---

## 5. Path conventions

### 5.1 Path layout

```
system/quorum/                                    ← (per EXTENSION-QUORUM)
   {quorum_id_hex}                                  ← quorum entity for the identity
   {quorum_id_hex}/event/{hash_hex}                 ← quorum-update, quorum-publish
                                                      attestations (per EXTENSION-QUORUM
                                                      attestation conventions)

system/identity/                                  ← identity-extension paths
   internal/
       cert/{hash_hex}                              ← internal identity attestations:
                                                      • identity-cert (function=controller,
                                                        4-key advanced; not handle-bearing)
                                                      • identity-cert (function=identifier,
                                                        4-key advanced; cert is internal even
                                                        though identifier peer's KEY is handle)
                                                      • identity-cert (function=controller,
                                                        sub-controller; always internal)
                                                      • identity-cert (function=agent, mode=internal)
                                                      • identity-rotation-handoff (target internal)
                                                      • identity-rotation-recovery (target internal)
                                                      • identity-retirement (target internal)
                                                      • revocation (target internal)
       proposals/{kind}-{id}                        ← (informative) async signature gathering
                                                      staging area; see §8
   public/
       cert/{hash_hex}                              ← public/handle-bearing identity attestations:
                                                      • identity-cert (function=controller,
                                                        3-key default; handle-bearing)
                                                      • identity-cert (function=agent, mode=public)
                                                      • identity-rotation-handoff (target handle-bearing)
                                                      • identity-rotation-recovery (target handle-bearing)
                                                      • identity-retirement (target public)
                                                      • revocation (target public)
   relationships/
       {contact_id_hex}/
           cert/{hash_hex}                          ← per-relationship identity attestations:
                                                      • identity-cert (function=agent,
                                                        mode=per-relationship)
                                                      • lifecycle events for per-relationship certs
   contacts/
       {published_handle_hex}/
           quorum-publish                           ← cached `system/attestation` (kind=quorum-publish)
                                                      for a contact identity (TOFU'd or
                                                      sync-mediated; trust anchor for
                                                      compromise-recovery validation)
   peer-config                                      ← per-agent local config
```

**Hash-segment dispositions (`SPECIFICATION-FORMAT.md` §8.4.6, `[normative]`).** Every hash segment above is one of the two dispositions, and this section states which:

- **`{contact_id_hex}` is `[derive-to-meet]` — pinned to the ECFv1-SHA-256 floor**, whatever any peer's home format. It is the contact's `system/peer` identity hash, and `relationships/{contact_id_hex}/` is a path the **named contact must construct for itself** (§5.2's bilateral tier). A home-format derivation would have the two ends of one relationship build different paths and never meet, silently. Pinned by the same ruling that pins the identity entity itself (§8.4.6's second worked example).
- **`{quorum_id_hex}`, `{hash_hex}`, `{published_handle_hex}` are `[hold-and-fetch]` — format-free.** Each is read off an entity that travelled: the quorum entity, the attestation, and `quorum-publish.published_handle` respectively. Use them verbatim at whatever width their own format byte implies; do not re-derive them and do not assume a width.

`identity-cert (function=agent)` attestations also appear embedded inside cap envelopes (mode=embedded; per §4.2a); not at any tree path.

The v3.0 `system/identity/quorum/...` subtree is gone. Top-level controller certs route to `internal/cert/{h}` or `public/cert/{h}` per their handle-bearing status.

**Cache lifetime across rotations.** When a `"identity-rotation-recovery"` arrives for a handle-bearing cert, the previous-handle cache entry at `contacts/{old_handle_hex}/quorum-publish` MUST be retained at least through the in-flight window (until the verifier accepts the new handle). Implementations MAY garbage-collect older entries beyond a configurable TTL. The retention requirement ensures the §9.4 fail-closed validation has a trust anchor available.

### 5.1.1 Implementation indexes (informative)

Implementations SHOULD maintain impl-private indexes for performance — peer→attestation, quorum→cert, contact_id→relationship, kind+function→cert. These are impl-private and not part of the on-the-wire protocol surface. The `EXTENSION-ATTESTATION.md` §9.1 indexes (`attesting`, `attested`, `properties.kind`) are the MUST baseline; additional identity-specific indexes are SHOULD.

### 5.2 Audience and sync

The tier separation describes external sync exposure, not which agents hold what.

| Path subtree | Held by | Visible externally to | External propagation mechanism |
|---|---|---|---|
| `system/quorum/{trusts_quorum}/...` | All agents of the identity | All contacts | Two-tier sync (contacts pull); identity declares the quorum subtree as part of its public surface |
| `system/identity/internal/...` | All agents of the identity | None | Internal sync only — never crosses fleet boundary |
| `system/identity/public/...` | All agents of the identity | All contacts | Two-tier sync (contacts pull) |
| `system/identity/relationships/{contact_id}/...` | All agents of the identity AND the named contact | The named contact only | Three-tier sync (bilateral subscription per contact) |
| `system/identity/contacts/...` | The local agent only | None | No external propagation; local cache |
| `system/identity/peer-config` | The single agent it belongs to | None | No propagation; peer-local |

**Two-tier sync, dual-subtree.** External contacts subscribe to two subtrees on the identity's peer:
1. `system/identity/public/...` — identity's public certs and lifecycle events
2. `system/quorum/{trusts_quorum}/...` — quorum state (quorum entity + `quorum-update` + `quorum-publish` events)

The identity's sync-policy hook (called by sync extension at TOFU / first-contact) returns both subtrees as the contact-facing surface. Contacts find the `trusts_quorum` value by walking any cert chain back to the quorum (top-level cert's `attesting` field is the quorum_id) and subscribing to that quorum's subtree.

### 5.3 Canonical storage path (normative)

Path resolution is purely a function of the attestation's own `properties` — no runtime shape lookup. The cert author sets `properties.mode` explicitly at create-time per §4.2 valid-modes-per-function table.

```
canonical_storage_path(att, ctx) → string
  ; att is a system/attestation entity in identity context.
  ; (Identity context = att.properties.kind in identity-relevant kinds.)
  hash_hex = hex(att.content_hash)

  match att.properties.kind:
    "identity-cert":
      return canonical_cert_path(att, ctx)  ; per-mode dispatch (see below)

    "identity-rotation-handoff", "identity-rotation-recovery", "identity-retirement", "revocation":
      ; Same audience tier as the target cert
      target = lookup_target_cert(att.properties.target_cert, ctx)
      if target is null: return error("target_cert_not_found")
      return same_tier_path(target, hash_hex)

canonical_cert_path(att, ctx) → string
  ; Per-mode dispatch. Mode is REQUIRED on all identity-certs per §4.2.
  ; Function-specific mode constraints are enforced by the create_attestation
  ; validator, not by path resolution.
  hash_hex = hex(att.content_hash)
  mode = att.properties.mode

  match mode:
    "internal":
      return "system/identity/internal/cert/" + hash_hex
    "public":
      return "system/identity/public/cert/" + hash_hex
    "per-relationship":
      return "system/identity/relationships/"
             + hex(att.properties.contact_id)
             + "/cert/" + hash_hex
    "embedded":
      return null  ; embedded in cap envelope; no tree path

same_tier_path(target_att, hash_hex) → string
  ; Returns the path for an attestation operating on target_att,
  ; in the same audience tier as target_att.
  ; Lifecycle events (identity-rotation-*, identity-retirement, revocation) inherit
  ; their target cert's mode for path resolution.
  target_path = canonical_cert_path(target_att, ctx)
  tier_prefix = target_path before "/cert/"
  return tier_prefix + "/cert/" + hash_hex
```

**Hash-segment encoding.** All hash-typed segments encode as the lowercase hex string of the full `system/hash` byte sequence.

**No runtime shape lookup.** Path resolution depends only on the cert's own `properties.mode` (set explicitly by the author at create-time per §4.2). This eliminates the in-flight-rotation race that a runtime shape lookup would create. A controller cert created with `mode="public"` stays in the public subtree forever; subsequent issuance of an identifier cert (transitioning the identity to 4-key shape) doesn't move it. New certs created during a shape transition are written per their author's intent.

### 5.4 Index reconciliation contract (normative)

Identity composition reads two indexes maintained by lower layers, and the contract between them is normative:

- **Location index** (read by V7 `system/tree:get`) is the **source of truth** for tree-bound entities. A path is bound iff the location index records a binding at that path.
- **Attestation index** (read by `EXTENSION-ATTESTATION`'s `find_attestations_*` and `enumerate_live_*` walks) is **derived from location-index bindings** via dispatcher-driven indexing. An attestation is enumerable as live iff it is currently bound at a tree path that the indexer observes.

The contract:

- **Phase 2a unbind** (per §6.3) MUST affect both indexes simultaneously when it fires. Failing to do so produces the divergence Go's Tier 3 ceremony surfaced: an entity is no longer in the location index but `enumerate_live_*` (which walks the attestation index) still returns it.
- **Local create writes** populate both indexes immediately and atomically: a successful local-handler write (`:create_attestation`, `:supersede_attestation`, etc.) MUST result in both indexes reflecting the new binding before the handler returns.
- **Sync-driven arrivals** populate both indexes immediately on bind; phase 2a (when triggered by validation failure) MUST unbind both atomically.
- **Cap revocation cascades and identity-retirement cascades** MUST affect both indexes — revoking a cap (per §6.4) MUST remove the cap entity from both location and attestation indexes; retiring a cert (`identity-retirement`) MUST update both indexes such that subsequent `enumerate_live_*` walks no longer return the retired cert as live.

Prose throughout this spec uses "is bound" to mean "present in the location index" and "is live" to mean "is bound AND passes liveness predicates per `EXTENSION-ATTESTATION.md` §4.3"; the two indexes agree by construction under the contract above.

---

## 6. Handler operations

The seven identity handler operations preserve their external surface from v3.0:

| Op | Purpose | Resource target |
|---|---|---|
| `configure` | Bind peer-config to a trusted quorum + initial bindings | `system/identity/peer-config` |
| `create_quorum` | Create a new quorum entity (delegates to `EXTENSION-QUORUM`) + initialize peer-config | `system/quorum/{q_hex}` |
| `create_attestation` | Create any-kind identity attestation (handler dispatches per kind+function+mode) | per kind/function/mode (§5.3) |
| `supersede_attestation` | Replace a live attestation with a successor | new attestation's canonical path |
| `revoke_attestation` | Remove an attestation's tree binding | attestation's stored path |
| `publish_attestation` | Promote/demote a `cert(function=agent)` attestation across modes | new mode's canonical path |
| `process_attestation` | Validate and apply state updates for an attestation entering the named subtrees | attestation's stored path |

**All ops follow path-as-resource per ENTITY-CORE-PROTOCOL.md §3.2 (architectural-side MUST).**

Internal implementations:

- **`create_quorum`:** delegates to `QUORUM.system/quorum:create`; additionally writes `system/identity/peer-config.trusts_quorum` referencing the new quorum_id. Bootstrap-scope; existing trusted quorum mutates only via `QUORUM.system/quorum:update` calls (per `EXTENSION-QUORUM.md` §6.5).
- **`configure`:** registers `identity-resolved` signer-resolution mode against `EXTENSION-QUORUM`'s hook (§6.1). Configures peer-config from the supplied quorum reference and initial bindings. Configure with bindings requires complete (validatable) attestations; staging happens at the configure-binding level via `bindings: optional`, not at the binding-field level. The full ordered-phase algorithm is normative — see "§6.0a `:configure` ordered phases" below.

- **`create_attestation`:** see "§6.0c `:create_attestation` mode-branch behavior" below.

- **`supersede_attestation`:** see "§6.0b `:supersede_attestation` substrate dispatch" below.

- **`revoke_attestation`:** see "§6.4 `:revoke_attestation` cap cascade" below.

- **`publish_attestation`:** see "§6.0d `:publish_attestation` MOVE semantics" below.

- **`process_attestation`:** the convergence point for any identity-context attestation entering the local tree at the named subtrees, regardless of source (sync, local create_attestation, local supersede_attestation, L0). Validates via `identity_verify_cert`; applies state updates (cap revocations on retirements; cap issuance on agent certs; handle cache updates for handle-bearing rotations); seeds `contacts/{published_handle_hex}/quorum-publish` cache when arriving `quorum-publish` attestations target an identity. Algorithm pinned in §6.3.

### 6.0a `:configure` ordered phases (normative, per PI-2)

Phases execute in order; failure at phase N short-circuits subsequent phases. Phases are NOT factored into separate user-visible ops in v2; sub-step contracts are named so impls can't drift.

```
:configure(trusts_quorum, bindings, ctx)

Phase 1: validate_inputs (structural — does NOT reference phase 2 output)
  - Validate trusts_quorum is bound at system/quorum/{q_hex}
  - If bindings is empty: phase 1 passes; phases 2-4 still execute (caps issued
    for live controllers); phase 5 persists peer_config with bindings: [].
    Empty bindings is a valid configure shape — peer is bound to a quorum and
    has controller caps but no specific (handle_cert, agent_cert) bindings yet.
  - For each binding[i]:
      Validate binding[i].handle_cert and .agent_cert are non-zero hashes
      Validate each resolves to a system/attestation
      Validate kind/function shape matches expected (handle_cert is a
        function=controller or function=identifier cert; agent_cert is a
        function=agent cert)
  - On failure:
      400 binding_missing_handle_cert (zero-hash)
      400 binding_missing_agent_cert (zero-hash)
      400 binding_cert_wrong_kind (resolves but kind/function mismatch)
      404 binding_cert_not_found (non-zero hash, no entity)

Phase 2: enumerate_live_controller_certs(trusts_quorum) AND validate binding-chain
  - Walk attestations targeting trusts_quorum (via
    ATTESTATION.find_attestations_targeting with predicate filtering on
    kind=identity-cert, function=controller)
  - For each: filter via ATTESTATION.is_attestation_live (substrate)
  - Filter superseded predecessors per supersede chain
  - Output: live_controller_certs = list of live controller-cert hashes
  - Then for each binding[i]:
      Validate binding[i].agent_cert.attesting (or its chain via walk_attesting_chain)
        resolves to a controller in live_controller_certs.
      A binding referencing a non-live or non-existent controller is a hard
        error here (post-enumeration). Prevents bindings to retired controllers.
  - On failure:
      400 binding_controller_not_live (agent_cert chains to non-live controller)

Phase 3: verify_each_controller_cert
  - For each live controller-cert: QUORUM.verify_k_of_n_signatures
    (top-level controllers) OR ATTESTATION.verify_attestation_signature
    (sub-controller chains; single-sig)
  - On failure of any: 403 controller_invalid; configure aborts

Phase 4: issue_local_caps
  - **De-duplicate by controller identity (v3.7, A.4).** Implementations MUST
    issue one local-peer→controller capability per **distinct verified controller**,
    not one per verified controller-cert / attestation. A controller is one
    logical authority regardless of its quorum's member count; iterating over
    live attestations without de-duplicating by controller cert identity
    produces N-1 orphaned capabilities at the same canonical path on every
    ceremony re-run (PERSISTENCE-FEEDBACK Finding 1 Q1).
        distinct_controllers = dedupe(verified_certs, by: controller_cert_identity)
  - For each verified controller in distinct_controllers:
      cap = mint local-peer→controller cap (V7 §5.5)
      bind cap entity at
        system/capability/grants/identity/peer-to-controller/{controller_hex} (PI-9)
      sign cap.content_hash with local peer keypair
      bind signature entity at /{local_peer_id}/system/signature/{cap_content_hash_hex}
        (V7 invariant pointer per §6.0e + V7 §3.5 v7.44; v3.6 replaced the prior
         sibling-path PI-10 convention)
  - Output: list of (controller_hex, cap_hash, cap_path)

Phase 5: register_bindings
  - For each binding: append to peer_config.bindings
  - Persist peer_config at system/identity/peer-config

Result: {
  peer_config_path: <abs path per V7 §1.4>,
  caps: [{controller_hex, cap_hash, cap_path: <abs path>}]
}
```

**Binding validation error contract (normative, per v2.0 PR-8.4 — integrated into phase 1 above).** Phase 1 yields `404 binding_cert_not_found` when a `handle_cert` or `agent_cert` hash does not resolve to a present `system/attestation` entity in the local content store or the wire envelope's `included` map. This pins the error code for binding-target unresolvability — semantically the binding is a pointer to an entity that does not exist; 404 is the correct HTTP-style response. Distinct error subcodes apply to the two adjacent failure modes: `400 binding_missing_handle_cert` / `400 binding_missing_agent_cert` for a binding entry with a zero hash (structurally empty rather than referencing an unresolvable entity); `400 binding_cert_wrong_kind` for a hash that resolves but the resolved entity has the wrong attestation kind/function. The 404 vs 400 split lets SDK consumers writing recovery logic distinguish "the entity is missing entirely" from "the entity is present but the request is structurally malformed." Surfaced by Go's Tier 3 fixture (`acme_configure_with_bindings`); cross-impl test vector is TV-CONFIGURE-BINDING-404 in `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` §9.5.

### 6.0b `:supersede_attestation` substrate dispatch (normative, per PI-1)

`system/identity:supersede_attestation` does not unconditionally wrap substrate's `system/attestation:supersede`. Substrate's `:supersede` is a strict-by-design wrapper that copies the predecessor's `attesting`/`attested` (correct for kinds where supersession on the same subject by the same attester is the semantics — VC, reputation, audit, provenance). Identity controller rotation legitimately changes both `attesting` and `attested` (new controller key replaces old, attesting changes), so substrate's `:supersede` would block rotation.

The fix is a normative property list of identity-context kinds where supersession may legitimately rebind `attesting`/`attested`:

**REBIND_KINDS (normative property list):**
- `identity-cert`

(Future identity-context kinds requiring the same treatment are added to this list via spec amendment. Kinds NOT in this list use substrate `:supersede` and preserve attesting/attested per substrate semantics.)

```
:supersede_attestation(predecessor_hash, new_properties, ctx)

  predecessor = ATTESTATION.lookup(predecessor_hash, ctx)
  if predecessor is null: return 404 attestation_not_found

  REBIND_KINDS = {"identity-cert"}    ; per the property list above

  if predecessor.properties.kind in REBIND_KINDS:
    ; Rotation case: attesting/attested may legitimately differ
    ; Caller supplies new attesting (e.g., quorum_id for top-level rotation;
    ;   issuing controller for sub-controller rotation) and new attested
    ;   (the new keypair).
    return ATTESTATION.create({
      attesting: <caller-supplied>,
      attested:  <caller-supplied>,
      properties: new_properties,
      supersedes: predecessor_hash
    }, ctx)
  else:
    ; Non-rebind kinds (e.g., identity-rotation-handoff, retirement, revocation)
    ; preserve attesting/attested per substrate semantics.
    return ATTESTATION.supersede(predecessor_hash, new_properties, ctx)
```

Substrate stays clean (no kind-conditional carve-out at the substrate layer); the kind-conditional dispatch lives in the identity composition.

### 6.0c `:create_attestation` mode-branch behavior (normative, per PI-4)

```
:create_attestation(kind, function, mode, attesting, attested, properties, ctx)

Phase 1: validate_inputs
  - (kind, function, mode) valid per per-function valid-modes table (§4.2)
  - On invalid: 400 invalid_mode_for_function (per PI-11)
      Error envelope includes `function`, `attempted_mode`, and
      `valid_modes_for_function` (array) for diagnostic clarity.
  - properties contains required fields per kind/function (per §3.3)

Phase 2: compose_substrate_attestation
  - Call ATTESTATION.create with identity-specific properties shape
  - Re-encoding integrity: input attesting/attested fields MUST round-trip
    byte-equivalent through the call (per P-4'; no silent canonicalization)

Phase 3: per-mode dispatch
  if mode in {internal, public, per-relationship}:
    - canonical_path = canonical_storage_path(att, mode) per §5.3
    - bind(canonical_path, attestation_entity)
    - return {attestation_hash: <non-zero>, attestation_path: <abs>}
  if mode == embedded:
    - DO NOT bind to tree
    - return {attestation_hash: <zero>, embedded_attestation: <entity>}

Result shape differs per mode; zero attestation_hash signals not-bound.
```

The `400 invalid_mode_for_function` error closes per-function mode enforcement (PI-11): combinations such as `function=controller, mode=per-relationship` and `function=identifier, mode=public` are rejected at create time per the §4.2 valid-modes table.

### 6.0d `:publish_attestation` MOVE semantics (normative, per PI-3)

```
:publish_attestation(attestation_hash, target_mode, ctx)
  ; Promotes/demotes a kind=identity-cert, function=agent attestation across modes.

Phase 1: validate_input
  - attestation_hash resolves to a kind=identity-cert, function=agent attestation
  - target_mode ∈ {internal, public, per-relationship}    ; embedded not movable
  - On failure:
      404 attestation_not_found
      400 invalid_target_mode (target_mode == embedded)
      400 not_publishable_kind (not kind=identity-cert OR not function=agent)

Phase 2: compute_paths
  - old_path = canonical_storage_path(attestation, current mode) per §5.3
  - new_path = canonical_storage_path(attestation, target_mode) per §5.3
  - Both MUST be absolute per V7 §1.4
  - new_path.hash_segment MUST equal attestation_hash
    (content-hash invariant under move)

Phase 3: move (tombstone-style recovery)
  - bind(new_path, attestation_entity)
  - unbind(old_path)
  - Implementations MAY use atomic two-path binding primitives where available.
    Implementations without such primitives execute the bind+unbind sequentially.

  On bind(new_path) failure:
  - Old path remains bound. Surface error to caller.
  - No tombstone needed (no inconsistent state).

  On unbind(old_path) failure (after bind(new_path) succeeded):
  - SHOULD retry unbind once.
  - On retry failure: emit a controller-event entity (per §6.3 / PI-5) with
    event_subkind="recovery_signal" at
      system/identity/events/{timestamp_ms}/publish_attestation/{attestation_hash}/{event_content_hash}
    describing the orphaned binding (entity bound at both paths). The entity
    remains discoverable via attestation index (substrate). Per §6.3 retention
    policy, this recovery_signal event MUST NOT be pruned until cleared. The
    peer's controller can re-run :publish_attestation after investigating, OR
    explicitly system/tree:put(old_path, null) to complete the unbind.

  No "atomic OR fail" guarantee — impls without atomic primitives complete the
  move best-effort and emit a recovery_signal event for any inconsistency. The
  tombstone is the recovery signal.

Result: {new_path: <abs>, attestation_hash}
```

### 6.0e Cap binding and signature paths (normative, per PI-9 + PI-10)

**Cap binding path.** Caps issued by `:configure` (or any other handler-driven path) for the local-peer→controller chain bind at:

```
system/capability/grants/identity/peer-to-controller/{controller_hex}
```

where `{controller_hex}` is the lowercase hex of the controller's identity hash. Multi-controller deployments produce multiple distinct caps at distinct keyed slots in the same subtree.

**Cap signature.** For any cap issued by a handler-driven path (including `:configure`), the granter's self-signature on the cap's content_hash binds at the **V7 invariant pointer path** `/{granter_peer_id}/system/signature/{cap_content_hash_hex}` (per ENTITY-CORE-PROTOCOL.md §3.5 v7.44 + this spec §6.2). Downstream chain-validation walks discover signatures at this canonical path; **no extension-private sibling-path convention**. Symmetric to ROLE v2.0 Amendment 3 (CP-3 in the continuation cross-peer seam sweep) — both extensions bind chain-participating cap signatures at the V7 invariant pointer rather than at an extension-private sibling, eliminating the path-construction-against-extension-private-scheme defect class ENTITY-CORE-PROTOCOL.md §3.5 v7.45 "discovery locality" calls out. Aligns with §6.2 (signatures at invariant pointer), §7 K-of-N convention (L1221 — V7's invariant pointer pattern for final signatures is normative), and §10.4 no-mirror-writes policy (L1342).

### 6.0f Startup boundary (normative, per PI-7)

Startup is the period from peer instantiation through the first `system/identity:configure` call that succeeds and issues at least one local-peer→controller cap. During startup, operations that establish initial peer state (the first `:create_quorum`, the first `:create_attestation` calls producing top-level controller certs, the initial `:configure`) run via the SDK's L0 direct-store path — peer-owner authority, no dispatch authorization required (no authority chain has been provisioned yet). After startup completes, all dispatched EXECUTEs require capability validation per ENTITY-CORE-PROTOCOL.md §5.

**Terminology disambiguation (informative).** "Startup" in this section refers to the identity-layer authority-bootstrapping period (when no cap chain is provisioned yet). It is DISTINCT from V7's "bootstrap types" terminology (ENTITY-CORE-PROTOCOL.md §2 — the type-registration table loaded at peer instantiation). The two concepts overlap in time (both happen at peer initialization) but address different surfaces: V7 bootstrap types are the type-system foundation; identity startup is the authority-chain provisioning period. V7's "bootstrap types" terminology is also slated for future cleanup (architecture-team-flagged; out of scope this round); a future V7 sweep round may rename it consistently. Implementers absorbing both this proposal and the companion system-peer-rename / substrate-cleanup work see two terminologies during the absorption window.

### 6.1 `identity-resolved` resolver registration

On `configure`, the identity handler registers:

```
QUORUM.register_resolver("identity-resolved", resolve_identity_to_current_controller)

resolve_identity_to_current_controller(identity_ref, ctx) → peer_hash:
  ; Look up the identity referenced by identity_ref
  ; Return its current controller's peer hash (per cert chain walk)
  ; identity_ref in identity-resolved mode is the trusts_quorum hash for the
  ; referenced identity (the canonical handle for an identity in this mode).
  current_controller_cert = walk_cert_chain_to_current_controller(identity_ref, ctx)
  if current_controller_cert is null: return error("identity_not_found_or_no_controller")
  return current_controller_cert.attested  ; the controller peer's hash
```

`walk_cert_chain_to_current_controller` is defined in §3.6 (identity-specific helpers). It returns the live top-level controller cert for the identity rooted at the given quorum, with deterministic tie-break across multi-controller deployments per §3.2's `resolve_controller_for_grants`.

This closes the cyclic-dependency concern: `EXTENSION-QUORUM` has no compile-time dependency on `EXTENSION-IDENTITY`; it just provides a hook. `EXTENSION-IDENTITY` supplies the resolver at runtime.

### 6.2 Signature ingestion (delegated to V7)

Signatures arriving in `envelope.included` are ingested by the V7 dispatcher and bound at V7 invariant pointer paths (`/{signer_peer_id}/system/signature/{target_hash_hex}`) BEFORE any handler op is dispatched, per `ENTITY-CORE-PROTOCOL.md` §6.5 (Envelope.included signature ingestion). Identity handler ops do not perform their own signature ingestion — they look up signatures via `find_signature_by_signer` (per `EXTENSION-ATTESTATION.md` §4.0) and find them already bound at canonical paths by the time they run, regardless of whether the signature arrived via envelope-ingestion or cross-peer sync.

The dispatcher-level scope is uniform: the same V7 ingestion step applies to kernel ops (`system/tree:put`), substrate ops (`system/attestation:verify`, `system/quorum:verify`), identity ops (`create_attestation`, `supersede_attestation`, `process_attestation`), and any other handler op. No per-extension ingestion surface is needed.

### 6.3 `process_attestation` algorithm (normative, per PI-5)

`process_attestation` is the convergence point for any identity-context attestation entering the local tree at the named subtrees, regardless of source (sync, local `:create_attestation`, local `:supersede_attestation`, L0 startup, envelope.included ingestion). The algorithm splits cleanly into validation, side-effect dispatch (pluggable, per (kind, function); failures isolated), and FAILURE-only controller-events emission.

**v2 scope: failure-subset.** v2 ships with FAILURE events MUST emit. Informational events (success-path observability) are OUT OF SCOPE for v2 and are deferred to v2.x; impls MUST NOT emit success events during v2 to keep the surface predictable. The minimal handler-id set is the seven (kind, function) handlers in the dispatch table below.

```
:process_attestation(attestation, path, ctx)

Phase 1: validate
  - identity_verify_cert(attestation, ctx) — pure; returns ok or error
  - On error:
      Cross-peer arrival path: phase-2a unbind (per scope rule below)
      Local-create path: return error to caller; do NOT unbind

Phase 2: dispatch_side_effects (pluggable, per (kind, function))
  - For each registered handler matching the attestation's (kind, function):
      run handler; capture result independently
      handler failure MUST NOT propagate or affect other handlers' execution
  - Standard registered handlers (dispatch table):
      (identity-cert, agent)              → maybe_issue_local_cap
      (identity-cert, controller)         → maybe_issue_local_controller_cap
      (identity-cert, identifier)         → maybe_update_identifier_handle
      (identity-rotation-handoff, *)      → handle_dual_sig_handoff
      (identity-rotation-recovery, *)     → update_handle_cache_to
                                            (post-§9.4-validate)
      (identity-retirement, *)            → revoke_local_caps_for_attested
      (quorum-publish, *)                 → seed_contacts_cache
                                            (consumes EXTENSION-QUORUM kind)

Phase 3: emit_controller_events (FAILURE-only in v2)
  - For any phase-2 handler failure:
      determine event_subkind:
        "recovery_signal"     if the failure left orphaned/inconsistent state
                              (e.g., partial cap cleanup; orphaned binding)
        "failure_observation" if the failure left consistent state
                              (handler errored but no orphan)
      construct event entity:
        type: system/identity/event
        data: {
          event_subkind:    <"recovery_signal" | "failure_observation">,
          handler_id:       <string>,
          attestation_hash: <hash>,
          attestation_kind: <string>,
          error_code:       <string>,
          error_detail:     <string>,
          timestamp_ms:     <epoch_ms>
        }
      bind at:
        system/identity/events/{timestamp_ms}/{handler_id}/{attestation_hash}/{event_content_hash}
  - The trailing {event_content_hash} segment makes the path unique by definition
    (any change to the event entity's content produces a different hash;
    identical events at the same instant collapse to the same path — desired
    idempotent semantic).
  - v2 scope: phase 3 MUST emit on phase-2 handler failure. Informational events
    on phase-2 success are OUT OF SCOPE for v2 (impls MUST NOT emit success
    events during v2; v2.x may add).

Result: ok or error per phase 1; phase-2 outcomes captured in events stream.
```

**Phase 2a fail-closed-unbind scope (normative, per v2.0 PR-8.3 follow-up; integrated as a sub-rule of phase 1).** Phase 2a fail-closed unbind applies to attestations arriving via **cross-peer sync** (or any non-local-handler path that produces a tree binding). For attestations newly written by a local handler op (`:create_attestation`, `:supersede_attestation`, `:revoke_attestation`, etc.), phase 2a MUST be skipped — the local op's caller is responsible for providing the necessary signatures via `envelope.included` per ENTITY-CORE-PROTOCOL.md §6.5 dispatcher-level signature ingestion (SPEC-25). If validation fails during phase 1 for a local-create attestation (e.g., the caller didn't include sufficient signatures to satisfy K-of-N or single-sig requirements), the implementation MUST return the validation error to the caller without unbinding the entity. The local op's response handler decides whether to retry (re-submit with corrected signatures) or roll back (explicit `system/tree:put(path, null)`).

Rationale: a local-create write produces a binding that is the intended observable result of the caller's action. Fail-closed unbind on a local create defeats the create — the caller sees a `200` from `:create_attestation` (because the entity was successfully bound at write time) followed by a phantom `404` on read (because the sync hook unbound it before validation could complete). Cross-peer arrivals are different: signatures should be present per V7 SPEC-25's dispatcher-level ingestion before the sync hook fires; if validation fails on arrival, the entity is malformed and unbinding it prevents downstream consumers (e.g., `:configure`'s `enumerate_live_*` walks against the *attestation index*, not the location index) from treating it as live.

Implementations MUST distinguish the two cases. Two recognized patterns:

- **Op-string discrimination.** The sync hook receives the op-string identifying the producing operation; phase 2a skips for known local-handler op-strings (`attestation-create`, `attestation-supersede`, etc.); fires for sync arrivals (`advance`, `deliver`) and other non-local paths.
- **Caller-context tag.** The local emit context carries a `local_handler_origin: bool` (or equivalent) field; phase 2a checks this and skips when true.

Either is conformant; the observable outcome is the same. Surfaced by Go's `acme_14_1_configure_ceremony` Tier 3 fixture where `system/tree:get` returned 404 post-`:create_attestation` because the sync hook unbound a freshly-created internal-cert before its signatures had been ingested. Cross-impl test vector: TV-IF-INTERNAL-CERT-READABLE in `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` §9.5 verifies the local-create case (post-`:create_attestation`, `system/tree:get` at the canonical path returns the bound entity); a sync-arrival fail-closed test vector is implicit in the existing cross-peer convergence test surface.

**Event subkinds (normative).** v2 events are categorized by whether they require controller intervention:

- **Recovery-signal events.** Emitted when an op produced inconsistent state requiring controller action — e.g., PI-3 publish-MOVE rebind failure (orphaned binding); PI-13 cap-cleanup partial failure (cascade incomplete). These are tombstones — the event IS the recovery signal.
- **Failure-observation events.** Emitted when a phase-2 handler (cap-issuance, handle-cache-update, etc.) returned an error but the post-state is consistent (no orphaned state; just a side-effect that didn't apply). The controller MAY act for completeness; not strictly required.

The event entity carries a normative `event_subkind: "recovery_signal" | "failure_observation"` field. v2 emits these subkinds; v2.x may add `informational` for success-path observability.

**Retention policy (normative).** Controller-events retention is implementation-defined for `failure_observation` subkind events: implementations SHOULD provide pruning per local policy (TTL, count cap, or external controller-action).

Controller-events retention is **constrained** for `recovery_signal` subkind events: implementations MUST NOT prune `recovery_signal` events until either (a) the controller has acted on the orphaned state (resolution recorded via a clearing event — see v2.x roadmap below), OR (b) the implementation surfaces the events to a controller-equivalent operator interface and the operator explicitly clears them. Aggressive pruning of `recovery_signal` events defeats the PI-3 / PI-13 recovery contracts (the tombstone IS the signal; pruning it loses the signal).

Retention is NOT synchronized across peers; controller-events are local-only (not part of the cross-peer sync surface in §5.2).

**v2.x roadmap.** `informational` event subkind for success-path observability; **clearing events** (an entity type that references a `recovery_signal` event by content_hash and records that the controller has resolved the underlying issue — pairs with the recovery_signal in retention policy: clearing-event-paired tombstones become prunable per impl policy); richer handler-id namespace; structured query over the events subtree (composes with EXTENSION-QUERY); cross-peer event subscription if a use case emerges.

### 6.4 `:revoke_attestation` cap cascade (normative, per PI-13)

When `system/identity:revoke_attestation` succeeds, the implementation MUST cascade cap cleanup: walk `system/capability/grants/identity/peer-to-controller/*` and unbind caps whose `grantee` matches the revoked controller's `attested`. Cap signature siblings at `{cap_path}/signature` MUST be unbound alongside the cap entity.

**Convergence framing.** This describes the ideal-state behavior when state is fully propagated. In a distributed deployment, peers converge toward this state through normal message exchange — a peer that has observed the revocation cascades locally; a peer that has not yet observed it will cascade when the revocation arrives via sync. Cap chains issued by stale peers in the convergence window remain validatable until the revocation propagates; this is consistent with V7's general "caps are revoked at the cap layer" model — the revocation entity arriving is what triggers the cap-layer cleanup.

**The convergence window is an adversarial surface.** A peer that has observed a controller-cert but not yet its revocation will validate caps the controller can no longer authorize. The window's bound is the convergence latency (cross-peer sync delay; subscription / continuation propagation time). For deployments with low-threat models (small fleets; trusted peers; tight network) this is acceptable. For deployments with higher-threat models (compromise scenarios where the revoked controller key may be in adversarial hands; multi-tenant infrastructure; short-RTO compliance) the window matters.

**Optional redundant checks (informative).** Deployments wanting stricter enforcement MAY layer capability-validation-time re-checks: on each EXECUTE, re-resolve the cap chain's controller-cert and reject if revocation is observable. This trades performance for tighter window bounds. The base cascade behavior is sufficient for the convergence-tolerant case; redundant checks are the lever for deployments where the convergence window is too long for the threat model. Pinning this as MAY (not SHOULD) reflects that the cost-vs-window tradeoff is a deployment-policy decision, not a protocol-level mandate. Redundant-check surface is a candidate for a future deployment-pattern guide rather than EXTENSION-IDENTITY normative text.

Surfaced by Go's Tier 3 fixture (`acme_14_1_controller_revocation`). Cross-impl validation of cascade behavior joins Bucket C alongside cross-peer cert sync, compromise-recovery flow, and multi-peer founders.

---

## 7. Custody

### 7.1 Default three-key custody

The three-key default uses three peer functions:

- **Quorum constituents** — N peers, K-of-N threshold. Held in cold custody (paper, secondary device, hardware token, trusted holder). Used rarely (recovery; quorum updates; issuance of new controller certs).
- **Controller** — hot, encrypted at rest. Signs internal-management entities (peer-config writes, role-assignment records, agent certs). Contacts cache this as the identity's handle in the three-key default (controller IS the identifier).
- **Agents** — one per device daemon. Hot, on each running device. Sign cross-peer caps (V7 standard); the controller authorizes them via agent certs.

This is the recommended default for users wanting recovery + multi-device + stable cross-peer recognition.

### 7.2 Multi-key advanced (four-key)

Adds a fourth peer function:

- **Identifier peer** — held similarly to the controller (hot, encrypted at rest). Signs agent certs contacts care about. Rotates rarely (only on compromise of the identifier itself). The controller signs an identifier cert establishing the binding.

In this configuration:
- The controller rotates frequently (hygiene; per-incident; policy-driven) WITHOUT contacts re-validating.
- The identifier is what contacts cache; its rotation requires `identity-rotation-handoff` (routine) or `identity-rotation-recovery` (compromise).
- Agent certs are signed by the identifier (not the controller), since contacts cache the identifier's key as the identity's handle.

Most users don't need this. Document it as an opt-in for users specifically wanting hygiene-rotation independence.

### 7.3 Variants

- **Hardware-backed quorum constituents.** Quorum constituents live on hardware tokens (YubiKey, etc.). Pro: keys never enter general-purpose memory. Con: hardware-token UX for K-of-N signing ceremonies.
- **Hardware-backed controller.** Same tradeoff applied to the controller's key.
- **1-of-1 quorum.** Quorum has one constituent; threshold = 1. Structurally complete (cert lifecycle works mechanically) but provides no recovery (loss of the one quorum constituent = catastrophic loss). Useful when a user wants the architectural shape but accepts no recovery.
- **Concurrent multi-controller.** Multiple controllers live concurrently under the same quorum. Each agent holds one local cap per live controller. Useful for desktop + phone deployments where each device has its own controller.
- **Sub-controller chains.** A controller cert can be issued by another controller (not just the quorum), enabling delegated management. The chain MUST terminate at a top-level controller cert whose `attesting = quorum_id`. Useful for orgs with department-level delegation (per §4.2b).
- **App-defined functions.** Apps can issue certs with custom function values for app-specific authority (e.g., `function="audit-log-signer"`, `function="service-account"`). Standard cert lifecycle events apply uniformly.
- **Multi-binding.** An agent participates in multiple distinct identities (e.g., personal + service-account on the same machine). Each identity has its own peer-config record and its own binding chain.
- **Parent-managed.** Controller keys held by parents; the subject (a child) uses agents but the controller signatures come from parental hardware. Subject acquires their own keys over time via `quorum-update` ceremonies.

### 7.4 Custody transitions

Custody transitions (who holds which keys) compose from existing primitives. Two recurring patterns:

**Pattern A — Subject transitions to self-custody.** Initial state: quorum constituents are parental peers. Over time, the subject's peers are added (via `QUORUM.system/quorum:update`), the threshold is adjusted, and parental constituents are eventually removed. Each transition is a `quorum-update` attestation produced by the previous quorum signing the new structure. Standard mechanism.

**Pattern B — Controller transitions within an existing identity.** A second controller is added (new `identity-cert` with `function="controller"`, `supersedes: null`); both controllers hold authority concurrently; eventually the original is retired (`identity-retirement` referencing the original's controller cert). Standard mechanism. The "two controllers concurrent" interim is normal in multi-device deployments.

Each transition produces a new `quorum-publish` attestation (signed by the previous quorum) so contacts processing the supersedes chain see the transition as a sequence of attestation updates. No out-of-band coordination required for the identity-recognition surface.

---

## 8. Async signature gathering

K-of-N attestations require multiple signatures. The signatures don't need to all be produced at the same moment.

**Convention (informative).** A draft attestation entity is published at a tree path under `system/identity/internal/proposals/{kind}-{id}`. Each constituent comes online at their convenience, signs the entity (producing a signature entity at `{constituent_peer_id}/system/signature/{draft_hash_hex}` per V7's invariant pointer pattern), and publishes the signature.

Once K valid signatures are present, the attestation is "complete" — application code (or a continuation) can move it to its final canonical path (e.g., `system/identity/public/cert/{hash_hex}` for a top-level controller cert with `mode="public"`) and trigger `process_attestation`.

**Signature storage.** All signatures (single-sig, dual-sig, K-of-N) live in the signer's namespace per V7's invariant pointer pattern: `{signer_peer_id}/system/signature/{target_hash_hex}`. K-of-N validation walks the constituent list and looks each constituent's signature up at its expected path. This is V7-standard; the identity extension does not invent a parallel signature-storage convention.

**Signature ingress paths.** Signatures arrive at the canonical V7 invariant pointer paths via two equivalent routes:
- **Cross-peer sync** (production flow): a constituent's peer writes its signature at `/{constituent_peer_id}/system/signature/{target_hex}` on its own tree. Sync propagates the binding to verifying peers' trees at the same path.
- **`envelope.included` ingestion** (single-peer / SDK flow per §6.2): the SDK or orchestrator bundles K signature entities in the request envelope; the receiving handler ingests them and binds at the same V7 paths within its own tree.

Both produce identical post-state. The verifier does not distinguish — `find_signature_by_signer` (per `EXTENSION-ATTESTATION.md` §4) walks the tree path on the local peer's tree and finds the signature regardless of how it arrived.

This convention is informative; specific implementations may use different paths for the proposals workflow, but the threshold-based completion model and V7's invariant pointer pattern for final signatures are normative.

---

## 9. Security considerations

### 9.1 Three parallel mechanisms enforced

V7 caps for permission chains (chain-walked by `verify_capability_chain`); `system/attestation` entities for signed claims (entity-validated by `EXTENSION-ATTESTATION` helpers + identity's `identity_verify_cert`); `system/quorum` entities for K-of-N consensus (entity-validated by `EXTENSION-QUORUM`'s `verify_k_of_n_signatures`). They share no validator. See §2.2 invariant block and §12.3.

The natural implementation mistake — reusing cap-chain walkers for "anything multi-signed" — is explicitly forbidden. Three distinct validators, three distinct entity classes, three distinct dispatch paths.

### 9.2 Controller confinement to internal flows

Controller signatures appear ONLY on entities under `system/identity/internal/` (identifier certs; agent certs in mode=internal; sub-controller certs) or, in the four-key advanced shape, on agent certs the identifier's key signs (no controller signature on `public/` paths in either three-key default or four-key advanced). This invariant is structural: implementations **MUST** reject attestations under `system/identity/public/` carrying signatures from any currently-live controller of the trusted quorum (defense-in-depth against sync attacks or buggy peers publishing controller-signed entities to public paths). The MUST level matches §10.1's conformance commitment.

**Implementation note (informative).** §9.2 enforcement requires the live-controller key set of the trusted quorum on every `public/` attestation arrival. Implementations MAY maintain an impl-private live-controller cache to avoid repeated subtree scans; the cache is invalidated by `process_attestation` on `kind="identity-cert", function="controller"` (insert) and `kind="identity-retirement"` for controller certs (remove). The cache is impl-private and not part of the on-the-wire protocol surface. This is one concrete instance of the broader §5.1.1 implementation-index recommendation.

### 9.3 Replay protection

Attestation entities include `not_before` / `expires_at` fields where applicable. The `supersedes` chain on each kind provides ordering: a fresh attestation must reference the previous live one for the same chain-key, OR carry `supersedes: null` for kinds and circumstances where introducing a new concurrent attestation is valid (e.g., a second controller cert under a multi-controller deployment).

**Temporal validity (MUST).** Implementations MUST check `now ∈ [not_before, expires_at]` on every attestation processed via `process_attestation`. An expired attestation is treated as not-live; a future-dated attestation MUST be rejected. The `EXTENSION-ATTESTATION.md` §4.3 `is_attestation_live` helper enforces this; identity wraps it via `identity_verify_cert`.

### 9.4 Compromise-recovery validation (MUST)

When `process_attestation` handles an arriving `identity-rotation-recovery` for a handle-bearing cert, it MUST validate the K-of-N signatures against the cached `quorum-publish` attestation for the identity. If no `quorum-publish` is cached (e.g., the contact never received one because the identity opted out of publication), the recovery rotation MUST be rejected (fail-closed). Recovery rotations cannot be accepted on the strength of arbitrary signatures; the contact's prior cached signer set is the trust anchor.

The cache lookup uses the `identity-rotation-recovery`'s `properties.old_handle` (hex-encoded) as the key: `contacts/{old_handle_hex}/quorum-publish`. The previous-handle cache entry's lifetime is governed by §5.1's "Cache lifetime across rotations" paragraph (entries MUST be retained at least through the in-flight window; impls MAY garbage-collect older entries beyond a TTL).

Deployments that opted out of `quorum-publish` publication fall back to out-of-band re-establishment for compromise-recovery (the user sends contacts a fresh signed introduction; contacts TOFU-accept the new identity). This degradation is by design — privacy and recovery-ergonomics trade off.

### 9.5 Long-lived third-party-held cap survival across rotation

Long-lived caps held by third parties die when the keys authorizing their issuance are retired. This is a direct consequence of V7 chain validity + identity rotation.

Concretely:
- When a **controller** is retired (via `identity-retirement` referencing the controller cert), the local peer→controller cap for that controller's key is revoked, and any caps issued by agents under that controller's authorization lose their authorizing chain at the agent's cap-issuance step.
- When an **agent** is retired (via `identity-retirement` referencing the agent cert, OR `revoke_attestation` for local removal), contacts no longer recognize that agent as part of the identity; cross-peer caps signed by that agent continue to fail verification at the contact's cap-chain check (the agent's signing identity is no longer attested).
- When a **sub-controller** is retired, all certs that sub-controller issued cascade-fail at chain validation (the chain breaks at the retired sub-controller link).

Mitigation is the rotating peer's responsibility — re-issue outstanding grants from new authority and push to consuming peers via the consuming extension's normal flow — NOT the consuming extension's. Consuming extensions stay rotation-agnostic.

This applies to subscription deliver tokens, continuation dispatch caps, inbox dispatch caps, compute installation grants, future extensions holding cross-peer caps. The property is documented here once at the right layer rather than pushed into each consuming extension.

Deployment patterns (informative): **short-TTL pattern** (recommended default — keep delivery / dispatch / install grants short-lived; natural renewal cycles cover rotation events), **SDK-tracked re-issuance pattern** (for long-lived flows, use the SDK helper to re-issue on rotation), and **accept-loss pattern** (for low-stakes flows, accept that rotation kills outstanding subscriptions/dispatches; clients re-establish on next interaction).

### 9.6 Compromise of identifier / controller

If the identifier's key (four-key) or controller's key (three-key default) is compromised, the attacker can sign new agent certs claiming arbitrary peers as authorized. Contacts processing these update their address book, potentially trusting attacker-controlled agents.

Recovery: quorum signs an `identity-rotation-recovery` attestation per §4.4 and §9.4. Contacts process the rotation (validating quorum's K-of-N signatures against cached `quorum-publish`); cached handle updates to the new key. Compromised key's attestations are no longer authoritative.

The window between compromise and recovery is the same as for V7 cap revocation propagation — a real exposure that the architecture bounds rather than eliminates.

### 9.7 Quorum compromise

If more than N-K of the quorum's keys are compromised simultaneously, the attacker has K-of-N and can sign any quorum-authorized attestation. Identity is fully compromised. The architecture mitigates by encouraging geographic distribution and K<N defaults; it cannot eliminate.

---

## 10. Conformance

### 10.1 MUST implement

- Both identity-owned types (§3): `system/identity/peer-config` and `system/identity/identity-binding` (helper inner type).
- Identity-context `system/attestation` conventions (§3.3): the four kinds (`"identity-cert"`, `"identity-rotation-handoff"`, `"identity-rotation-recovery"`, `"identity-retirement"`) plus identity-specific authority rules over the universal `"revocation"` kind.
- The four function values (§4.2): `"controller"`, `"agent"`, `"identifier"`, plus app-defined.
- The four publication modes for agent certs (§4.2a): `"internal"`, `"public"`, `"per-relationship"`, `"embedded"`.
- The identity-specific validators (§3.6): `identity_topology_for`, `identity_is_quorum_link`, `identity_is_authorized_revoker`, `identity_verify_cert`.
- Path conventions (§5.1) for the four subtrees (`internal/`, `public/`, `relationships/`, `contacts/`) and `peer-config`. The `system/quorum/{q}/...` subtree is owned by `EXTENSION-QUORUM` and consumed by identity for the dual-subtree sync surface.
- Audience separation (§5.2) — tier separation describes external sync exposure, not which agents hold what.
- Handler operations (§6) at `system/identity` with the manifest: `configure`, `create_quorum`, `create_attestation`, `supersede_attestation`, `revoke_attestation`, `publish_attestation`, `process_attestation`. **All ops follow path-as-resource** per ENTITY-CORE-PROTOCOL.md §3.2 (architectural-side MUST).
- Path resolution from `properties.mode` only — no runtime "current shape" lookup (§5.3).
- Signing-pattern enforcement (per §4.1 kind table): operational keys never sign attestations under `public/` paths; `identity-rotation-handoff` is dual-signed (old + new); `identity-rotation-recovery` and `identity-retirement` are K-of-N signed by quorum.
- Replay protection: `supersedes` chain validation per kind; rejection of attestations that don't supersede the live entity for the same chain-key (or carry valid `supersedes: null` per kind semantics).
- **Compromise-recovery validation (§9.4):** when processing an `identity-rotation-recovery` attestation, MUST validate K-of-N signatures against the cached `quorum-publish` attestation for the identity. MUST reject if no `quorum-publish` is cached (fail-closed).
- **Three parallel mechanisms enforced (§2.2 invariant):** identity attestations MUST be validated only by `identity_verify_cert` (composing primitive helpers); MUST NOT be processed through ENTITY-CORE-PROTOCOL.md §5.5 chain validation; MUST be reached via `system/identity` dispatch ops, never via cap-token verification. Quorum entities MUST NOT be routed through V7's `verify_capability_chain` either.
- **Per-runtime-peer-identity peer-config (§3.2):** a host machine MAY operate as multiple agents (one per identity it serves); each agent has its own peer-config in its own namespace; peer-configs MUST NOT share state across identities.
- **`controller_grants` resolution under sub-controller chains (§3.2):** implementations MUST implement the `resolve_controller_for_grants` algorithm per §3.2's normative rule: identify the live top-level controller cert (cert whose `attesting == trusted_quorum_id`); under multi-controller deployments (multiple concurrent live top-level controllers), MUST tie-break deterministically by lowest content_hash. Sub-controllers MUST NOT inherit the top-level `controller_grants`.
- **Index reliance — `attesting` field:** identity's `walk_cert_chain_to_current_controller` (§3.6) and chain walks call `find_attestations_targeting` with predicates filtering by `attesting`. Implementations MUST rely on `EXTENSION-ATTESTATION.md` §9.1 indexes; identity SHOULD additionally maintain a per-quorum `(quorum_id → controller-cert hashes)` index (per §5.1.1) for `walk_cert_chain_to_current_controller` performance.
- **Temporal validity (§9.3):** `now ∈ [not_before, expires_at]` MUST be checked on every attestation processed.
- **Operational-key confinement (§9.2):** structural enforcement of operational-key signatures restricted to `internal/` paths.
- **Dependency on EXTENSION-ATTESTATION + EXTENSION-QUORUM:** implementations MUST also implement these substrate primitives. Identity-context attestations are `system/attestation` entities (per `EXTENSION-ATTESTATION.md`); identity quorums are `system/quorum` entities (per `EXTENSION-QUORUM.md`).
- **Resolver registration:** implementations MUST register the `identity-resolved` signer-resolution mode against `EXTENSION-QUORUM`'s hook on identity-handler `configure` (§6.1).
- **Dual-subtree sync surface:** implementations MUST expose both `system/identity/public/...` AND `system/quorum/{trusts_quorum}/...` as the contact-facing sync surface for the identity (per §5.2).
- **Index reliance:** implementations MUST rely on `EXTENSION-ATTESTATION.md` §9.1 indexes (`properties.kind`, `attesting`, `attested`) for identity dispatch performance.
- **`process_attestation` algorithm (§6.3):** implementations MUST follow the validate-then-side-effects ordering of §6.3; on validation failure MUST unbind the path (fail-closed). Side-effect ordering across kinds is normative (per §6.3 match block); ordering of independent side effects within a kind is implementation-defined.
- **`identity_verify_cert` topology-first dispatch (§3.6):** implementations MUST dispatch on topology BEFORE running signature validation; signature validation runs in the topology-appropriate variant (single-sig via `verify_attestation_signature`; dual-sig via `verify_specific_signer` per signer; K-of-N via `QUORUM.verify_k_of_n_signatures`). MUST NOT run a single-sig check upfront on attestations whose `attesting` is a quorum_id.
- **Lifecycle kinds in chain walks (§3.6, §4.3):** implementations MUST use `identity_confers_function` (or equivalent semantics) when chain-walk predicates filter by function. Handoff and recovery kinds inherit function from `target_cert`; retirement kinds terminate the chain dead.
- **Signature ingestion (§6.2):** delegated to ENTITY-CORE-PROTOCOL.md §6.5 (dispatcher-level envelope.included ingestion). Identity handler ops MUST NOT implement their own signature-ingestion surface — they rely on V7 having bound signatures at their canonical paths before dispatch.
- **Handler-op type registration:** identity's seven handler ops (per §6) register `input_type` / `output_type` per ENTITY-CORE-PROTOCOL.md §3.7 convention (`{handler-path}/{op-name}-request` / `-result`). Type definitions MUST be installed at `system/type/{type_name}` during handler installation.
- **`bindings` runtime (§3.4):** implementations MUST round-trip `bindings` array entries byte-equivalent on canonical encoding. Implementations MUST NOT interpret `bindings` for runtime dispatch in v3.3.

### 10.2 SHOULD implement

- Async signature gathering (§8) via the proposals subtree convention.
- Default agent custody as a separate per-device key (§7.1); document variants as configuration options.
- Tiered sync (§5.2) granting contacts read access only to `public/` and the appropriate `relationships/{contact_id}/`.
- Default mode for new agent certs: **internal** (privacy by default; promotion to other modes via `publish_attestation`).
- Sync-hook on `public/cert/`, `relationships/*/cert/`, and `system/quorum/*/event/` paths invoking `process_attestation` on arrivals (per §6).
- Impl-private indexes (§5.1.1) for performance: peer→cert, quorum→cert, contact_id→relationship, kind+function→cert.

### 10.3 MAY implement

- Hardware-backed quorum constituents or controller key (§7.3 variants).
- Privacy opt-out for `quorum-publish` publication (compromise-recovery falls back to out-of-band re-establishment).
- The four-key advanced shape (§7.2). Implementations MAY ship without it; the three-key default covers the load-bearing identity properties.
- Convenience wrappers around quorum operations exposed via the identity handler (callers can also invoke `system/quorum:update` / `:publish` directly).

### 10.4 Compatibility

- **Wire break vs v3.0 / v2.x.** v3.2 entity types and storage paths differ structurally from v3.0 / v2.x. A peer at v3.0 cannot share identity data with a peer at v3.2. Greenfield is acceptable here because no implementation has shipped against v3.0 (v3.0 was a paper transition). Currently-implementing impls (Go at v2.2; Python and Rust at unknown state) jump v2.2 → v3.2 in one coordinated cross-impl pass per the substrate proposal stack (`PROPOSAL-EXTRACT-ATTESTATION-PRIMITIVE.md`, `PROPOSAL-EXTRACT-QUORUM-PRIMITIVE.md`, `PROPOSAL-MINIMIZE-EXTENSION-IDENTITY.md`, `PROPOSAL-MULTIKEY-MULTIHASH-ALIGNMENT.md` Change A).
- **No backward compatibility window.** Per project policy: clean breaking change. No legacy-path acceptors, dual-kind acceptance, or mirror-writes. Implementations target v3.2 directly.
- **Backward compatible with V7.** This extension adds no entity types beyond `peer-config` and `identity-binding`; identity-context attestations are `system/attestation` (per the substrate primitive). V7 chain verification is unchanged. Existing extensions (role, continuation, subscription, compute, etc.) consume identity at the cap layer (local peer→controller caps per §6); no V7-chain disruption.

---

## 11. Configurations

The progression in §1.1 maps to concrete configurations along a continuum. This section enumerates the supported variants.

### 11.1 V7-only (don't install this extension)

V7 alone gives each peer a self-rooted identity (peer's keypair = peer's identity). Single-device, single-key, no recovery, no rotation. Valid configuration when those features are not wanted. The identity extension is opt-in.

### 11.2 1-of-1 quorum

Quorum has one constituent; threshold = 1. Structurally complete but provides no recovery. Useful when a user wants the architectural shape but accepts no recovery property.

### 11.3 Three-key default (recovery + multi-device)

Quorum (K-of-N, K ≥ 2 typically), one controller, M agents. Recovery + multi-device + stable cross-peer recognition, all enabled. **The recommended default.**

### 11.4 Multi-key advanced (four-key)

Adds an identifier peer to §11.3 for hygiene-rotation independence. Controller rotates frequently (without contact disturbance); identifier rotates rarely (only on compromise). See §7.2.

### 11.5 Multi-binding (one agent in multiple identities)

A single host machine MAY operate as multiple agents (one per identity it serves). Each agent has its own peer-config in its own peer namespace; peer-configs MUST NOT share state across identities (per §3.2 invariant). When the host operates as a multi-binding agent, the runtime selects which peer-config to load per dispatched handler invocation by inspecting the local peer ID active for that invocation (each agent runs as a distinct local peer, though they may share a host process).

**Resolution model (normative).** The peer-config-per-identity rule is structural: a peer-config's `trusts_quorum`, `controller_grants`, and `bindings` apply to ONE identity. An agent peer at peer-ID `P_A_alice` (Alice's identity) has its peer-config at `/{P_A_alice}/system/identity/peer-config` with Alice's `trusts_quorum`. The same host-machine running as `P_A_service` (a service-account identity) has a separate peer-config at `/{P_A_service}/system/identity/peer-config` with the service-account's `trusts_quorum`. Dispatch resolves the peer-config by the local-peer namespace context that hosts the handler invocation; there is no cross-identity peer-config lookup.

**Why peer-config-per-identity (not one peer-config with multiple bindings).** The `bindings` array describes which certs an agent has been issued under each identity; it does NOT generalize the singletons (`trusts_quorum`, `controller_grants`) to multi-valued. Generalizing those would require: (1) per-identity controller-grant scoping (resolved via the binding's `agent_cert` walk to its identity's quorum); (2) per-identity authority cache invalidation; (3) per-identity dispatch in every handler. Keeping peer-configs partitioned by local-peer namespace lets each identity's agent run as a fully isolated unit, avoiding these complications. The `bindings` field is reserved for a future expansion (e.g., representing an agent's view of multiple identities it observes) but in v3.2 it is not the multi-identity mechanism — separate peer-IDs per identity are.

**Practical deployment.** A user running both their personal identity and a service-account identity on the same laptop runs two agent processes (or two daemon sessions in one process) with two distinct keypairs and two peer-IDs. Each has its own peer-config; each runs `configure` independently; cap chains per identity stay independent.

### 11.6 Concurrent multi-controller

Multiple controllers live concurrently under the same quorum. Each agent holds one local cap per live controller. Used for desktop + phone deployments where each device holds its own controller.

### 11.7 Sub-controller chains

A controller cert can be issued by another controller (rather than the quorum directly), enabling delegated management hierarchies. The chain MUST terminate at a top-level controller cert whose `attesting = quorum_id`. Useful for organizations with department-level delegation: a top-level controller issues sub-controller certs to per-department peers; sub-controllers issue agent certs within their scope. See §4.2b for chain semantics.

### 11.8 App-defined cert functions

Apps may issue certs with custom `function` values for app-specific authority (e.g., `function="audit-log-signer"`, `function="service-account"`, `function="backup-verifier"`). Standard cert lifecycle events (`identity-rotation-handoff`, `identity-rotation-recovery`, `identity-retirement`) apply uniformly across standard and app-defined functions.

### 11.9 Parent-managed

Controller keys held by parents; the subject uses agents but controller signatures come from parental hardware. Subject acquires own keys over time via `quorum-update` ceremonies. See §7.4 Pattern A.

### 11.10 What is NOT supported

- **Federated identity (multiple quorums for the same human user).** `peer-config.trusts_quorum` is a single hash; an agent trusts one quorum. If a user wants entirely separate identity spheres, each sphere needs its own agents. Sharing agents across quorums is `system/group` territory.
- **Skipping the controller layer.** The structural chain is quorum → controller → agent. A configuration with no controller layer (quorum directly issuing agent certs) is not in scope. The controller is the layer that enables agent certs under non-K-of-N topologies.
- **A peer recognized by multiple unrelated users.** Each agent is in one peer-config and trusts one quorum. A "shared device" used by multiple people requires each user to run their own agent (separate process / browser session / etc.). Note that a single host machine MAY operate as multiple agents (one per identity it serves) per §3.2 — that is a different shape and IS supported.
- **Cross-identity certs at the cert layer.** Identity A's certs cover A's peers only. Cross-identity vouching (Alice grants Bob a role under her identity) is what `EXTENSION-ROLE.md` and `EXTENSION-GROUP.md` provide — different layers.

---

## 12. Cross-extension invariants

Five invariants run through the identity / role / multi-sig / group stack. Future extensions touching this surface MUST preserve them.

### 12.1 ENTITY-CORE-PROTOCOL.md §5.5 line 1968 generalized

"Root capabilities MUST be granted by the local peer." Single-sig caps satisfy this when granter = local peer. Multi-sig caps (per `PROPOSAL-MULTISIG-CORE-PRIMITIVE.md` M6) generalize it to "local peer in signers AND signed." Identity preserves it: caps to contacts root at agent keys, not at controller keys, identifier keys, or quorums. Role preserves it: derived caps root at the issuing agent.

Future extensions issuing caps at any peer MUST preserve this invariant.

### 12.2 Controllers never appear in cap chains

Controllers sign attestations (controller certs they receive from the quorum or parent controller authorize them; agent certs and identifier certs they themselves produce; sub-controller certs in delegated hierarchies). Controllers never sign V7 capabilities that enter cross-peer chains. Bob's peer never sees a controller's key as a granter in any cap chain it processes.

V7 caps are signed by agent keys; controllers authorize the agent to issue them via the local peer→controller cap. Future extensions implementing similar internal-authorization patterns MUST preserve this separation.

### 12.3 Three algorithms with one direction of dependency

V7 capabilities (chain-verified by `verify_capability_chain`); `system/attestation` entities (entity-validated by `EXTENSION-ATTESTATION` helpers + identity's `identity_verify_cert`); `system/quorum` entities (entity-validated by `EXTENSION-QUORUM`'s `verify_k_of_n_signatures`). Three structurally distinct entity-validation classes with three structurally distinct validators. Cap-chain verification MAY read attestation state via the `IdentityBindingChecker` hook (read-only; for grantee-binding lookup); cap-chain verification MUST NOT validate attestations as caps. Attestation validation MUST NOT call `verify_capability_chain`. Quorum validation MUST NOT call `verify_capability_chain`. No shared validator across the three classes. The wall is structural at the algorithm level: cap-chain READS attestation state via the hook but does not VALIDATE attestations as caps; the validation paths remain distinct.

**Layer 2 hook (per ENTITY-CORE-PROTOCOL.md §5.10).** The `IdentityBindingChecker` is a **Layer 2 post-gate** per ENTITY-CORE-PROTOCOL.md §5.10. It MAY consult local identity-cert binding state (a local-only signal). It MUST NOT modulate the Layer 1 cap-chain verdict; concretely:

- **Scope (v3.8).** The hook applies only to caps whose grantee is a **local identity** — an identity whose binding is tracked in the local identity tree (an agent or sub-controller per §3, §6.3), where the lookup is a meaningful liveness/revocation check on that binding. It MUST NOT be applied to a **cross-peer dispatch capability** whose grantee is a remote peer (the dispatching host peer, `EXTENSION-CONTINUATION.md` §4.2): such a grantee's authenticity is established by the ENTITY-CORE-PROTOCOL.md §4.1 connection handshake and the signed capability chain, not by a local identity-cert binding — so rejecting it for lacking one would both defeat cross-peer dispatch and add no security.

- **Determinism (v3.9, now per ENTITY-CORE-PROTOCOL.md §5.10).** The hook MUST NOT cause a peer to accept or reject a cross-peer-relevant cap chain differently than another conformant peer would. Identity revocation that must invalidate caps cross-peer propagates via the cap-layer revocation mechanism (ENTITY-CORE-PROTOCOL.md §5.5 reverse-index, visible to all peers), not via the local binding hook.

The hook remains a deployment **MAY** for purely-local enforcement (e.g. a fast-path refusal to wield its own local agent's cap after revoking that agent's binding). Its scope excludes cross-peer-relevant grantees and intermediates *regardless of policy*, so a peer that enforces the hook strictly and a peer that omits it interoperate. See `GUIDE-EXTENSION-DEVELOPMENT.md §4.8` for the worked `X→agent(local-to-X)→Y` example and the broader extension-author checklist.

Future extensions needing K-of-N signing MUST pick the appropriate mechanism, not introduce a fourth. If the K-of-N is over a capability chain root, use the multi-sig primitive (cap layer). If it's over an attestation entity, use `EXTENSION-QUORUM`'s `verify_k_of_n_signatures` (entity layer). Don't introduce a hybrid validator.

### 12.4 TOFU + supersedes for cross-peer attestations

Cross-peer trust is established by Trust On First Use at first contact; subsequent updates chain via `supersedes` references signed by the previous-authoritative party. Used for the identity's handle (controller in 3-key, identifier in 4-key), agent certs, and `quorum-publish` attestations.

Future extensions introducing cross-peer attestations MUST follow the same pattern: TOFU at first contact; supersedes chains for updates; signatures over content_hash by the previous-authoritative key (or quorum, for K-of-N kinds).

### 12.5 Bootstrap exemption is L0; runtime is dispatched

Operations that establish initial peer state (this extension's `configure`, the initial `create_quorum`, initial `create_attestation`) run via the SDK's L0 direct-store path — peer-owner authority, no dispatch authorization required, since no authority chain has been provisioned yet. After bootstrap, all operations require dispatched EXECUTEs with proper capabilities.

**Conformance is observed via post-state, not wire trace.** Bootstrap is internal to the peer — there is no wire marker distinguishing an L0 write from a dispatched EXECUTE; the difference is which code path the peer's own runtime took. Cross-implementation conformance for bootstrap is "does the post-bootstrap tree state look correct?" verifiable via standard tree:get queries — NOT "did the wire trace show an L0 marker." Implementations MUST NOT add a wire-level marker for bootstrap operations.

---

## 13. Examples

### 13.1 Provision an identity (three-key default)

P_a opens its provisioning flow on the laptop. The provisioning code:

1. Generates 3 keypairs for the quorum: K_qm1, K_qm2, K_qm3.
2. Calls `QUORUM.system/quorum:create` with `{signers: [hash(K_qm1), hash(K_qm2), hash(K_qm3)], threshold: 2, signer_resolution: "concrete"}`. Stored at `system/quorum/{quorum_id_hex}`.
3. Generates the controller keypair K_ctrl. Builds an `identity-cert` attestation: `{kind: "identity-cert", function: "controller", mode: "public", attesting: quorum_id, attested: hash(K_ctrl)}`. K=2 of [K_qm1, K_qm2, K_qm3] sign it. `create_attestation` persists at `system/identity/public/cert/{cert_hash_hex}` (the controller IS the handle in 3-key default — `mode="public"`).
4. Calls `QUORUM.system/quorum:publish` with `{quorum_id: quorum_id, signers: [...], threshold: 2, properties: {published_handle: hash(K_ctrl)}}`. K=2 of [K_qm1, K_qm2, K_qm3] sign (typically the same signing session). The quorum-publish attestation persists at `system/quorum/{quorum_id_hex}/event/{publish_hash_hex}`.
5. Generates the agent keypair K_rt for the laptop. Builds an `identity-cert` attestation: `{kind: "identity-cert", function: "agent", mode: "internal", attesting: hash(K_ctrl), attested: hash(K_rt)}`. K_ctrl signs. `create_attestation` persists at `system/identity/internal/cert/{rt_hash_hex}`.
6. Calls `configure` with `{trusts_quorum: quorum_id, controller_grants: [...], bindings: [{handle_cert: cert_hash, agent_cert: rt_hash}]}`. (In three-key default, `handle_cert` references the controller cert. In multi-key advanced, `handle_cert` would reference an identifier cert instead.)
7. Configure handler validates everything (quorum K-of-N via `QUORUM.verify_k_of_n_signatures`, controller cert K-of-N via `identity_verify_cert`, quorum-publish K-of-N, agent cert single-sig), persists peer-config, issues local V7 cap from K_rt to K_ctrl. (`configure` also registers the `identity-resolved` signer-resolution mode against EXTENSION-QUORUM's hook per §6.1; the resolver is not exercised in this single-identity ceremony — its purpose is to resolve identity references when this peer participates as a constituent in another peer's quorum that uses `signer_resolution="identity-resolved"`, e.g., a group quorum.)
8. User backs up K_qm2 and K_qm3 (paper, secondary device).

The identity exists. The laptop is its first agent (internal mode). When the user later wants Bob to recognize the laptop, they promote the agent cert to public, per-relationship, or embedded mode via `publish_attestation`.

### 13.2 Controller compromise → recovery (3-key default)

K_ctrl is compromised. The user gathers K_qm2 + K_qm3.

1. Generate K_ctrl_v2 (fresh keypair).
2. K_qm2 + K_qm3 collaboratively sign an `identity-retirement` attestation for K_ctrl: `{kind: "identity-retirement", attesting: quorum_id, attested: hash(K_ctrl), properties: {target_cert: cert_hash}}`. Async signature gathering per §8.
3. `create_attestation` persists at `system/identity/public/cert/{ret_hash_hex}` (target cert is `mode="public"` so retirement co-locates).
4. K_qm2 + K_qm3 sign a fresh `identity-cert` attestation for K_ctrl_v2: `{kind: "identity-cert", function: "controller", mode: "public", attesting: quorum_id, attested: hash(K_ctrl_v2), supersedes: null}`. (`supersedes: null` because we're introducing a new controller key, not superseding K_ctrl's cert — that one is being retired by the retirement attestation in step 2.)
5. `create_attestation` persists at `system/identity/public/cert/{cert2_hash_hex}`.
6. Sync propagates retirement and new cert to other agents.
7. Each agent's `process_attestation` runs: revokes the local peer→K_ctrl cap (on retirement); issues a new local peer→K_ctrl_v2 cap (on cert).
8. In 3-key default, the contact-face IS the controller's key, so K_ctrl compromise IS a contact-handle compromise. Contacts must process an `identity-rotation-recovery` attestation to update.

Step 9: K_qm2 + K_qm3 sign an `identity-rotation-recovery` attestation: `{kind: "identity-rotation-recovery", attesting: quorum_id, attested: hash(K_ctrl_v2), properties: {target_cert: cert_hash, old_handle: hash(K_ctrl)}}`. `create_attestation` persists at `system/identity/public/cert/{rec_hash_hex}`. Sync propagates to contacts.

Step 10: each contact's `process_attestation` validates the recovery against the cached `quorum-publish` attestation (per §9.4 fail-closed); on success updates the cached handle to K_ctrl_v2.

In four-key advanced, steps 1–7 stay internal (controller rotation); contacts don't see anything because the identifier's key is unchanged. Only steps 9–10 happen if the contact-face (identifier) itself was compromised.

### 13.3 Routine handle rotation (privacy hygiene)

The user wants a fresh contact-face (no compromise; preventive rotation).

1. Generate the new handle key (in three-key default: a new controller key K_ctrl_v2 paired with quorum re-certification; in four-key advanced: a new identifier key K_id_v2).
2. Both old and new handle keypairs sign an `identity-rotation-handoff` attestation: `{kind: "identity-rotation-handoff", attesting: hash(K_old), attested: hash(K_new), properties: {target_cert: old_cert_hash}}`. Dual-signed.
3. `create_attestation` persists at `system/identity/public/cert/{rot_hash_hex}` (or `internal/cert/...` if target is internal).
4. Sync propagates to contacts.
5. Each contact's `process_attestation` validates the dual signature; updates cached handle to K_new.

The quorum doesn't sign this — the old handle's signature alone authorizes (proves the user holds K_old; new key's signature proves possession). Compromise-recovery is the K-of-N path; routine rotation is dual-sig.

### 13.4 Agent peer compromise → revoke_attestation

The laptop is stolen. K_rt (the laptop's agent keypair) is now in attacker hands. The laptop had an `identity-cert (function=agent)` attestation in mode=per-relationship for Bob and another in mode=internal for the identity's fleet.

1. The user (using K_ctrl via the phone) calls `revoke_attestation` with resource = `system/identity/relationships/{bob_id_hex}/cert/{rt_per_rel_hash_hex}`.
2. Handler removes the per-relationship binding. Bob's three-tier sync of the relationship namespace picks up the deletion.
3. The user calls `revoke_attestation` again with resource = `system/identity/internal/cert/{rt_internal_hash_hex}`.
4. Handler removes the internal binding. K_rt is no longer trusted within the fleet.
5. Bob's peer no longer has an agent cert for K_rt; subsequent caps from K_rt fail verification.

The user provisions a new agent (new laptop) with a fresh `identity-cert (function=agent)`, promotes it to per-relationship mode for Bob, and continues. Per-mode revocation lets the user manage exposure granularly.

### 13.5 Compromise-recovery rotation → quorum-publish validation

The user's identifier key is unavailable (lost device + corrupted backup). Recovery uses the quorum.

1. The user generates a new identifier key (K_id_v2) on the phone.
2. K=2 quorum constituents (K_qm2 + K_qm3) sign an `identity-rotation-recovery` attestation: `{kind: "identity-rotation-recovery", attesting: quorum_id, attested: hash(K_id_v2), properties: {target_cert: id_cert_hash, old_handle: hash(K_id_old)}}`.
3. `create_attestation` persists at `system/identity/public/cert/{rec_hash_hex}`. Sync propagates to contacts.
4. Bob's peer (via sync of `public/`) sees the new attestation and runs `process_attestation`.
5. `process_attestation` notices `kind == "identity-rotation-recovery"` and validates K-of-N against the cached `quorum-publish` attestation (per §9.4).
6. Validation passes (K_qm2 + K_qm3 are 2-of-3 of [K_qm1, K_qm2, K_qm3] per the cached signer set); Bob's address book updates to K_id_v2.

Without the cached `quorum-publish`, Bob's verifier rejects the rotation (fail-closed). The user would then need out-of-band re-establishment.

---

## 14. Glossary

### 14.1 Identity functions

A peer's function in an identity graph is determined by the attestations referring to it. Functions are not stored on peers; they emerge from graph position.

| Function | Description | Established by | Custody profile (typical) |
|---|---|---|---|
| **quorum constituent** | Member of the K-of-N quorum that holds the identity's structural root authority | Direct membership in `system/quorum.signers` (no attestation kind) | Cold-stored — hardware token, paper, secondary device, trusted holder |
| **controller** | Signs identity-internal management entities (peer-config writes, certs for agents / identifiers / sub-controllers) | `identity-cert (function="controller")` from the quorum (top-level) or another controller (sub-controller) | Hot, encrypted at rest |
| **identifier** | What external contacts cache as the identity's handle (multi-key advanced shape only) | `identity-cert (function="identifier")` from the controller | Hot, encrypted at rest; rotates rarely |
| **agent** | Signs cross-peer V7 capabilities from a running daemon | `identity-cert (function="agent")` from the controller (3-key) or identifier (4-key) | Hot, on each running device daemon |

In the **three-key default**, the controller also serves as the identifier (no separate identifier function). In the **four-key advanced** shape, the identifier function is filled by a separate peer.

### 14.2 Identity-context attestation kinds (v3.2)

| Kind | Function established / event expressed | Attesting | Attested | Sig topology |
|---|---|---|---|---|
| `identity-cert` (function=controller, top-level) | Establishes controller function | quorum | controller peer | K-of-N |
| `identity-cert` (function=controller, sub-controller) | Establishes sub-controller function | another controller | controller peer | single-sig |
| `identity-cert` (function=agent) | Establishes agent function | controller (3-key) or identifier (4-key) | agent peer | single-sig from attesting |
| `identity-cert` (function=identifier) | Establishes identifier function (4-key only) | controller | identifier peer | single-sig from controller |
| `identity-cert` (function=&lt;app-defined&gt;) | App-specific authority | controller | peer | single-sig from controller |
| `identity-rotation-handoff` | Graceful cert rotation (old key still available) | old key | new key | dual-sig (old + new) |
| `identity-rotation-recovery` | Compromise-recovery cert rotation (old unavailable) | quorum | new key | K-of-N from quorum |
| `identity-retirement` | Retires a cert (any function) | quorum | retired key | K-of-N from quorum |
| `revocation` (per `EXTENSION-ATTESTATION.md` §3.3) | Retracts an attestation; identity applies authority rule per §3.6 | revoker | target attestation | per `EXTENSION-ATTESTATION.md` |

Quorum self-events (`quorum-update`, `quorum-publish`) live in `EXTENSION-QUORUM.md` §3.2 / §3.3 and are NOT identity-owned kinds.

### 14.3 Handler operations

| Op | Purpose | Resource target |
|---|---|---|
| `configure` | Bind peer-config to a trusted quorum + initial bindings; register `identity-resolved` resolver | `system/identity/peer-config` |
| `create_quorum` | Create a new quorum entity (delegates to `EXTENSION-QUORUM`) + initialize peer-config | `system/quorum/{q_hex}` |
| `create_attestation` | Create any-kind identity attestation (handler dispatches per kind+function+mode) | per kind/function/mode (§5.3) |
| `supersede_attestation` | Replace a live attestation with a successor | new attestation's canonical path |
| `revoke_attestation` | Remove an attestation's tree binding | attestation's stored path |
| `publish_attestation` | Promote/demote a `cert(function=agent)` attestation across modes | new mode's canonical path |
| `process_attestation` | Validate and apply state updates for an attestation entering the named subtrees | attestation's stored path |

### 14.4 Concept index

- **Handle** — the peer key external contacts cache as the identity's identifier. In the three-key default, the controller's key. In the multi-key advanced shape, the identifier's key. Stored at the cached `quorum-publish.published_handle`.
- **Identity-binding** — `peer-config.bindings[i]` records this agent's role in one identity (which handle cert, which agent cert). An agent may participate in multiple identities; each identity gets its own binding.
- **Three parallel mechanisms** — V7 capabilities (chain-walked by `verify_capability_chain`); `system/attestation` entities (entity-validated by `EXTENSION-ATTESTATION` + identity's predicates); `system/quorum` entities (entity-validated by `EXTENSION-QUORUM`). Three classes share no validator. See §2.2 invariant block; §12.3.
- **TOFU + supersedes** — Trust On First Use establishes the initial cross-peer trust anchor; subsequent updates chain via `supersedes` references signed by the previous-authoritative party. See §12.4.
- **K-of-N entity-level validation** — verification of multi-signer attestation entities; lives in `EXTENSION-QUORUM.md` §4.1; distinct from V7's chain-level cap validation and from the cap-layer multi-sig primitive.
- **Audience separation** — `internal/` / `public/` / `relationships/{contact_id_hex}/` path subtrees describe external sync exposure, not which agents hold what. See §5.2.
- **Convergence point** — `process_attestation` is the single seed/dispatch point for any identity-context attestation entering the local tree at the named subtrees, regardless of source (sync, local writes, L0). See §6.

### 14.5 Disambiguation notes

- **"Role" reserved for `EXTENSION-ROLE.md`.** `system/role` provides RBAC-style capability-grant assignment ("admin role", "guest role"). The identity-side concept is **"function"** (a peer's structural position in the identity graph). The two are orthogonal — a peer can be the controller of an identity AND hold the admin role on a peer.
- **"Quorum" is one primitive serving two operational profiles.** Identity quorums are typically defensive (cold-stored, rare-use, `signer_resolution: "concrete"`). Group quorums (per `EXTENSION-GROUP.md`) are typically active (live identities, ongoing decisions, `signer_resolution: "identity-resolved"`). Same primitive (per `EXTENSION-QUORUM.md`), same K-of-N validation; different operational profile.
- **"Cert" (kind term) vs "attestation" (entity type).** The entity type is `system/attestation` (per `EXTENSION-ATTESTATION.md`; every signed claim is an attestation entity). The identity-context kind `identity-cert` discriminates within the type as the active certificate — confers a function to a peer. Identity v3.2 uses one cert kind with a `function` property; uniform across standard and app-defined functions.
- **"`identity-retirement`" (kind) vs `revoke_attestation` (op).** `identity-retirement` is a quorum-K-of-N attestation that retires a cert (any function). `revoke_attestation` is the generic handler op that removes any attestation's tree binding. Both reduce trust but at different layers — `identity-retirement` is a structural change to the identity graph (signed and propagated); `revoke_attestation` is a tree-level binding removal (local-only effect; useful for revoking a per-relationship agent cert without quorum involvement).
- **Cert-chain framework.** Identity is structurally a cert-chain framework with a self-sovereign root (the quorum). Verifier walks: leaf cert → chain via `attesting` → terminate at quorum. The mechanism is similar to X.509 / PGP cert chains while remaining self-sovereign.
- **DID / OCAP lineage.** Standard cert functions align with established literature: **controller** (DID — entity with authority over the identifier); **agent** (OCAP — entity acting on behalf of a principal); **identifier** (DID + general identity — IS the canonical reference). Cert IS a capability conferral in the OCAP sense (unforgeable; attenuable via sub-controller chains; revocable via `identity-retirement`). See `EXPLORATION-IDENTITY-LENSES-AND-CONVERGENCE.md` §4a for detailed comparison.

---

## 15. Document history

- **v3.3 Amendment 1 — second-round cross-impl feedback:** Absorbs the IDENTITY v3.2 migration fixes (Amendment 1; sources SPEC-24 / SPEC-25 from the cross-impl migration spec-issues round). Two cross-cutting items moved to V7 v7.37: SPEC-24 (handler-op type registration convention now in V7 §3.7); SPEC-25 (envelope.included signature ingestion now dispatcher-level in V7 §6.5). §6.2 reduced to a one-line pointer at V7 §6.5 (ingestion is no longer identity-owned; substrate and kernel ops also see ingested signatures uniformly). §10.1 conformance updated: SI-11 ingestion MUST replaced with V7 pointer + identity ops MUST NOT implement their own ingestion surface; new SPEC-24 conformance MUST added. Rust's TV-A4 wire-conformance gap (Reading B of §6.2) closes after Rust moves ingestion to dispatcher level. No version bump on identity (v3.3 absorbs); the substantive change lives in V7 v7.37.

- **v3.3 — cross-impl-feedback batch (IDENTITY v3.2 migration fixes):** Items: SI-5 (§3.6 `walk_cert_chain_to_current_controller` helper fix — `find_attestations_targeting` → `find_attestations_by`); SI-9 (§3.6 self/authority-revocation overlap documented); SI-10 (§6.3 `process_attestation` algorithm — validate → fail-closed unbind → side-effect dispatch); SI-11 (§6.2 `envelope.included` signature ingestion sharpened to MUST with binding semantics); SI-13 (§3.6 `identity_confers_function` helper added; §4.3 function inheritance from `target_cert` for handoff/recovery; retirement terminates dead); SI-14 (§3.6 "may override" removed from app-defined topology — single-sig pinned for v3.3); SI-20 (§3.4 `bindings` v3.3 runtime — accept-and-store + round-trip; not interpreted for dispatch); SI-21 (§12.3 three-parallel-mechanisms wording tightened — cap-chain MAY read attestation state via hook; MUST NOT validate as caps); SI-23 (§3.6 `identity_verify_cert` rewrite — topology-first dispatch; signature validation in topology-appropriate variant). Conformance §10.1 expanded with five new MUSTs covering §6.3 ordering, topology-first dispatch, lifecycle-kinds chain walks, envelope ingestion, and `bindings` round-trip. No wire-format change; algorithm + vocabulary only.

- **v3.2 Amendment 1 — Go team round-2 landed-review feedback absorbed + architecture-team review pass:** Items: (a) **§11.5 Multi-binding** rewritten to clarify the resolution model: a host machine running as multiple agents (one per identity it serves) has one peer-config per identity in distinct local-peer namespaces. Generalizing peer-config to hold multiple identities' singletons was considered and rejected. (b) **§3.6 identity-specific helpers defined** — `valid_functions()`, `identity_lifecycle_kinds()`, `lookup_target_cert(target_ref, ctx)`, `walk_cert_chain_to_current_controller(identity_ref, ctx)` were referenced from §3.6 validators and §6.1 resolver but never specified. Added explicit pseudocode for each, with deterministic tie-break aligned with §3.2's `resolve_controller_for_grants`. (c) §3.5 imports `QUORUM.is_quorum_id`; §3.6 call sites updated. (d) **§6.1 resolver** narrative tightened to call `walk_cert_chain_to_current_controller` correctly and return the controller's peer hash via `cert.attested`. (e) §13.1 step 7 narration of `identity-resolved` registration clarified — the resolver is registered but not exercised in the single-identity ceremony; its purpose is for THIS peer to participate as a constituent in another peer's identity-resolved quorum. (f) §10.1 conformance MUST added for §3.2's `resolve_controller_for_grants` algorithm + deterministic tie-break; identity-side `(quorum_id → controller-cert)` impl-index SHOULD added. (g) §2.1 reference fix: `§5.1.1 of EXTENSION-ATTESTATION.md` → `§5.1 walk_attesting_chain`. Companion amendments to substrate specs same-day: EXTENSION-ATTESTATION (multi-context peers note + TV-A11; `find_attestations_with_supersedes` and `find_attestations_with_kind` definitions; `supersedes` index promoted to MUST; TV-A11 added to conformance), EXTENSION-QUORUM (`is_quorum_id` definition + cache-invalidation contract). No version bump (v3.2 absorbs); spec just landed and no impl has shipped against it.

- **v3.2 — substrate-extraction rewrite:** Per the attestation-primitive extraction, quorum-primitive extraction, and minimize-EXTENSION-IDENTITY proposals. Identity becomes a convention layer over the substrate primitives `EXTENSION-ATTESTATION` and `EXTENSION-QUORUM`. **Type changes:** `system/identity/quorum` → `system/quorum` (moved to EXTENSION-QUORUM); `system/identity/attestation` removed entirely (identity uses `system/attestation` directly with identity-specific properties); identity owns only `peer-config` and `identity-binding` (helper inner type). **Kind renames:** `cert` → `identity-cert` (namespace prefix for global-tooling clarity; same shape, same `properties.function`); `cert-rotation-handoff` → `identity-rotation-handoff`; `cert-rotation-recovery` → `identity-rotation-recovery`; `cert-retirement` → `identity-retirement`. Quorum self-events (`quorum-update`, `quorum-publish`) move to EXTENSION-QUORUM. **Storage path changes:** `system/identity/quorum/{q}/...` subtree gone; quorum entities at `system/quorum/{q}`; quorum self-events at `system/quorum/{q}/event/{h}`; identity certs and lifecycle events at `system/identity/{audience}/cert/{h}` per `properties.mode`. **Path resolution:** `properties.mode` is now REQUIRED on ALL identity-cert kinds (not just agents). The runtime `is_handle_bearing_in_current_shape` lookup is removed — eliminates the in-flight rotation race. Each cert's path is fixed at create-time per its author's intent. **Validator changes:** `verify_k_of_n_signatures` and `current_signer_set` move to EXTENSION-QUORUM; `verify_attestation_signature`, supersedes-walking, liveness checks move to EXTENSION-ATTESTATION. Identity contributes `identity_topology_for`, `identity_is_quorum_link`, `identity_is_authorized_revoker`, `identity_verify_cert` (orchestration + predicates). **Signer resolution:** identity registers `identity-resolved` mode against EXTENSION-QUORUM's hook on `configure`. **Sync surface:** identity exposes dual-subtree (`system/identity/public/...` AND `system/quorum/{trusts_quorum}/...`). **Cross-extension invariant extended:** two-parallel-mechanisms → three-parallel-mechanisms (V7 caps; `system/attestation`; `system/quorum`). **Wire break vs v3.0; greenfield (no impl shipped against v3.0).** Cross-impl coordinated pass: jump v2.2 → v3.2 directly per substrate proposals' rollout. Companion artifacts: `SYSTEM-IDENTITY-COMPOSITION.md` (single-entry-point overview); `VALIDATION-MATRIX-IDENTITY-FOUNDATIONS.md` (~50 cross-impl test vectors); `PROPOSAL-IDENTITY-INFRASTRUCTURE.md` v4.0 (architecture overview); `PLAN-EXTENSION-LANDSCAPE.md` (refreshed dependency picture); `PROPOSAL-MULTIKEY-MULTIHASH-ALIGNMENT.md` Change A (varint hygiene; bundled in same cross-impl pass; V7 §1.5 / §7.3 / §7.4 / §1.6 amendments). EXTENSION-GROUP v1.5 sweep follows after substrate stabilizes.

- **v3.0 — cert/function reorganization (since superseded):** Per the IDENTITY v2 vocabulary-and-fixes work (Amendment 3). 8 attestation kinds → 6: three cert kinds (certification/runtime/contact-face) collapsed into one `cert` kind with `function` discriminator; cert lifecycle events renamed with `cert-` prefix. New structural capabilities: sub-controller chains; app-defined functions. Standard cert functions named per literature precedent: controller (DID); agent (OCAP); identifier (DID + general identity). Superseded by v3.2 substrate split.

- **v2.0–v2.3 (history folded into v3.0):** Complete rewrite around the unified-attestation key-graph design. Entity types reduced from 9 to 3 primary + 1 helper. All relational attestations unified under `system/identity/attestation` with kind-dispatched validation. v2.1 added cross-impl-feedback pass (R1–R7). v2.2 added vocabulary cleanup ("peer graph"; runtime rename; current_signer_set helper; structural invariants; canonical_storage_path; convergence point; cache lifetime; producer signing rule; embedded mode resource exception). v2.3 added §6.4a signature ingestion. v3.0 reorganized cert/function. v3.2 split into substrate primitives.

- **v1.2 absorption (since superseded):** v1.2 absorbed the IDENTITY-ARC-FIXES identity-side items.

- **Earlier history.** v1.0 → v1.1 (recovery, coherence, disclosure absorption), v1.0 origin. Full history preserved in archived v1.2.
