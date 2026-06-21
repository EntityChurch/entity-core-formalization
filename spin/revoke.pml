/*
 * revoke.pml — INDEPENDENT Promela re-encoding of the V7 §5.1 / §5.10 revocation +
 * cross-peer verdict-determinism design. Cross-check #B for the TLA+ `Revoke` model
 * (tla/Revoke.tla). It corroborates BOTH the two §5.1/§5.10 safety invariants AND the
 * §5.10 RevocationConverges liveness property that Apalache (safety-only) cannot reach.
 *
 * DISCIPLINE (docs/HANDOFF-CROSSCHECK.md, Track B): written FROM the V7 §5.1/§5.10 design —
 * two conformant peers evaluating the same capability chain, a revoker writing the marker,
 * each peer sampling its per-verdict timestamp `t` + a (Layer-2) local banlist bit and
 * asynchronously observing the marker — NOT translated from the .tla. The point of the
 * cross-check is an independent paradigm reaching the SAME verdict, so a shared transcription
 * error is unlikely to survive in both.
 *
 * Fidelity (5th wall, ../docs/ASSURANCE-MAP.md): the chain's STRUCTURAL validity (§5.5/§5.6
 * attenuation, signatures) is Lean's — abstracted to the opaque always-true `ChainValid`.
 * What is modeled is the §5.10 TEMPORAL/OBSERVATION layer around the verdict: `t` as a declared
 * per-verdict input (boundary at 1: valid at t==1, expired at t==2), revocation as a convergent
 * async-observed Layer-1 input, and the Layer-1/Layer-2 separation. Both peers pinned to the
 * supports_revocation=full tier. Same abstraction the TLA+ model makes.
 *
 * PROPERTIES checked:
 *   SAFETY   RevokedNeverPasses  revObserved[p] => !verdict(p)             (§5.1/§6.8)
 *   SAFETY   VerdictFnOfLayer1   same t & same observed-rev => same verdict (§5.10 determinism MUST)
 *   LIVENESS RevocationConverges markerWritten ~> all peers observe         (§5.10 convergence)
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)     fix: all three properties hold.
 *   -DNOHONOR     HonorRevocation=FALSE — an observed revocation is ignored -> RevokedNeverPasses
 *                 VIOLATED (matches TLA+ RevokeIgnoreBug).
 *   -DLEAKL1      LeakLayer1=TRUE — a local banlist (Layer 2) modulates the Layer-1 verdict ->
 *                 VerdictFnOfLayer1 VIOLATED (matches TLA+ RevokeLeakBug).
 *   -DNOCONVERGE  NoConverge=TRUE — a peer may finish blind, never observing the marker ->
 *                 RevocationConverges (liveness) FAILS (matches TLA+ RevokeNoConvergeBug).
 *
 * Build/run (from spin/, image entity-spin): the ltl{} claim disables invalid-end/assert
 * detection in a default pan run, so safety compiles the claim OUT (-DNOCLAIM) and liveness
 * runs it under weak fairness (-a -f):
 *   safety:   make verify MODEL=revoke [DEFS=-DNOHONOR|-DLEAKL1]   (expect errors: 0 / assertion)
 *   liveness: make ltl    MODEL=revoke [DEFS=-DNOCONVERGE]         (expect errors: 0 / accept cycle)
 */

#define A 0
#define B 1

/* §5.1 HonorRevocation switch (compile-time). */
#ifdef NOHONOR
  #define HONORREV false
#else
  #define HONORREV true
#endif

/* §5.10 LeakLayer1 switch (compile-time): does the local banlist modulate the Layer-1 verdict? */
#ifdef LEAKL1
  #define LEAK true
#else
  #define LEAK false
#endif

bool markerWritten = false;   /* §5.1: revocation marker written (put(path,null)) */
bool revObserved[2] = false;  /* §5.10: has peer p OBSERVED the marker? (async-convergent) */
byte t[2] = 1;                /* §5.10: each peer's per-verdict evaluation timestamp (init 1) */
bool banned[2] = false;       /* §5.10 Layer-2: a purely-local banlist bit (policy state) */

/* §5.10 Layer-1 verdict: ChainValid (abstract true) /\ TTLok(t==1) /\ honor-revocation /\
 * (only under the LEAK defect) the local banlist. Promela conditional-expr form (c -> a : b). */
#define verdict(p) ( (t[p] == 1) \
                     && (HONORREV -> (!revObserved[p]) : true) \
                     && (LEAK     -> (!banned[p])      : true) )

/* §5.1/§6.8: once observed, the cap fails every check. §5.10: same Layer-1 inputs => same verdict
 * (written as !antecedent || consequent). Checked at every state mutation. */
inline checkInv() {
  assert( (!revObserved[A] || !verdict(A)) && (!revObserved[B] || !verdict(B)) );
  assert( t[A] != t[B] || revObserved[A] != revObserved[B] || (verdict(A) == verdict(B)) );
}

/* Each peer samples its per-verdict `t` + (Layer-1-irrelevant) local policy, then asynchronously
 * observes the revocation marker once it exists (§5.10 convergent input). */
proctype peer(byte id) {
  /* PSample (§5.10): pick this verdict's timestamp and the local banlist bit. */
  atomic {
    if :: t[id] = 1 :: t[id] = 2 fi;
    if :: banned[id] = true :: banned[id] = false fi;
    checkInv();
  }
  /* PSync (§5.10): observation is async — converges once the marker exists. */
#ifdef NOCONVERGE
  if
  :: atomic { markerWritten -> revObserved[id] = true; checkInv() }
  :: skip   /* NEG CONTROL: peer finishes blind, never observing the marker (non-convergent) */
  fi
#else
  atomic { markerWritten -> revObserved[id] = true; checkInv() }
#endif
}

/* The revoker writes the revocation marker (§5.1 put(path,null)); both peers converge on it. */
proctype revoker() {
  atomic { markerWritten = true; checkInv() }
}

init {
  atomic {
    run peer(A); run peer(B); run revoker();
  }
}

/* LIVENESS §5.10: revocation is a CONVERGENT input — a written marker is eventually observed by
 * every verifier in the same tier. Needs weak fairness (pan -a -f). Holds in the fix; under
 * -DNOCONVERGE a peer can finish blind so it is never observed -> claim violated (accept cycle).
 * Mirrors TLA+ RevocationConverges. */
#define converged (revObserved[A] && revObserved[B])
ltl RevocationConverges { [] (markerWritten -> <> converged) }
