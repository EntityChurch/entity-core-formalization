/*
 * authority.pml — INDEPENDENT Promela re-encoding of V8 §5.2 dispatch authority and
 * resource binding. Cross-check #B for the TLA+ `Authority` model (tla/Authority.tla).
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM the §5.2 text — the
 * three-valued authority, "the condition is the field, not the door", and "a sub-dispatch
 * that names NO resource has NO resource" — NOT by translating the .tla. Added at 0.8.2
 * because `Authority` shipped with TLC coverage only, which the audit flagged: single-tool
 * coverage is the thing the cross-check exists to prevent.
 *
 * WHAT IS DIFFERENT ABOUT THIS ONE. Every other Promela model here re-encodes a CONCURRENCY
 * property, and Spin's value there is interleaving search. §5.2 is a STRUCTURAL property of
 * a dispatch tree — no interleaving, no time. So Spin's contribution here is not scheduling:
 * it is that an independently-written enumerator over the same rule space reaches the same
 * verdicts. That is a weaker kind of corroboration than the concurrency modules get, and it
 * is named here rather than left for a reader to assume.
 *
 * PROPERTIES checked (assertions, after each check_permission decision):
 *   NoGrantlessAllow         §5.2(c) a grantless sub-dispatch MUST deny (403)
 *   EntryNotSpuriouslyDenied §5.2(a) a covered wire-entry dispatch is not refused
 *   ResourceAuthorized       §5.2   "the condition is the field, not the door"
 *   NoManufacturedTarget     §5.2   the child MUST NOT inherit the parent's resource
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)     three-valued authority, sub-dispatches checked, no inheritance — all hold.
 *   -DOPTALLOW    Option<Capability>, empty case defaults to ALLOW
 *                 -> NoGrantlessAllow VIOLATED   (matches TLA+ AuthorityOptAllowBug)
 *   -DOPTDENY     Option<Capability>, empty case defaults to DENY
 *                 -> EntryNotSpuriouslyDenied VIOLATED (matches AuthorityOptDenyBug)
 *   -DNOSUBCHECK  resource check gated on a wire-entry predicate
 *                 -> ResourceAuthorized VIOLATED (matches AuthoritySubGateBug)
 *   -DINHERITRES  child inherits the parent's resource targets
 *                 -> NoManufacturedTarget VIOLATED (matches AuthorityInheritBug)
 *
 * Fidelity (5th wall): §5.2 steps 1-4 (hash, signature, chain, revocation) are Lean's and
 * Tamarin's; this model starts at check_permission. Grant coverage is an abstract two-point
 * scope (SELF covers r1, GRANT covers r2) — deliberately DISJOINT so that consulting the
 * wrong authority is observable, exactly as in the TLA+ model.
 *
 * Build / run (from spin/, image entity-spin):
 *   safety: make verify MODEL=authority [DEFS=-DOPTALLOW]   (expect errors: 0 / assertion)
 */

#define NSLOT 3

/* resource targets */
#define NONE 0
#define R1   1
#define R2   2

/* dispatch origin */
#define UNUSED 0
#define ENTRY  1
#define SUB    2

/* check_permission verdict */
#define PENDING 0
#define ALLOW   1
#define DENY    2

/* §5.2 the THREE-VALUED authority. Three distinct values, not an Option. */
#define AUTH_ABSENT 0    /* (c) grantless sub-dispatch — MUST deny */
#define AUTH_SELF   1    /* (a) wire entry — the caller capability on the envelope */
#define AUTH_GRANT  2    /* (b) in-process sub-dispatch — the executing handler's grant */

byte kind[NSLOT]    = UNUSED;
byte parent[NSLOT]  = 0;        /* 0 = no parent; otherwise slot index + 1 */
bool hasGrant[NSLOT] = false;
byte res[NSLOT]     = NONE;     /* the resource this dispatch NAMES */
byte outcome[NSLOT] = PENDING;

/* Abstract grant coverage — SELF covers r1, GRANT covers r2, ABSENT covers nothing. */
#define covers(a, r)  ( ((a) == AUTH_SELF && (r) == R1) || ((a) == AUTH_GRANT && (r) == R2) )

/* §5.2(1): which of the three authorities governs this dispatch. */
#define authof(d)  ( kind[d] == ENTRY -> AUTH_SELF \
                     : (hasGrant[d] -> AUTH_GRANT : AUTH_ABSENT) )

/* §5.2(3): the resource target the check actually receives. */
#ifdef INHERITRES
  /* DEFECT: a child that named nothing inherits its parent's target — "manufactures a
   * target the caller never named". */
  #define effres(d)  ( (res[d] == NONE && parent[d] > 0) -> res[parent[d] - 1] : res[d] )
#else
  #define effres(d)  res[d]
#endif

/* §5.2(2): is the resource condition consulted for this dispatch at all? */
#ifdef NOSUBCHECK
  /* DEFECT: the condition is the DOOR (a wire-entry predicate), so sub-dispatches skip it. */
  #define consulted(d)  (kind[d] == ENTRY)
#else
  /* CORRECT: the condition is the FIELD — it binds every dispatch carrying a target. */
  #define consulted(d)  true
#endif

active proctype dispatchtree()
{
  byte d, p, a, er, verdict;

  /* --- a wire-entry EXECUTE arrives at slot 0, naming some resource (or none) --- */
  if :: res[0] = NONE :: res[0] = R1 :: res[0] = R2 fi;
  kind[0] = ENTRY;
  hasGrant[0] = false;          /* at entry there is no handler grant; authority is the caller cap */

  d = 0;
  do
  :: d < NSLOT ->
       /* --- check_permission on slot d, if it has arrived and is undecided --- */
       if
       :: (kind[d] != UNUSED && outcome[d] == PENDING) ->
            a  = authof(d);
            er = effres(d);
#if defined(OPTALLOW) || defined(OPTDENY)
            /* Option<Capability> over the HANDLER GRANT: empty both at wire entry (there is
             * no handler grant — the authority is the envelope's caller capability) and at a
             * grantless sub-dispatch. One spelling, two meanings, so the implementation
             * cannot branch on which; the empty case gets one uniform default. */
            if
            :: a == AUTH_GRANT ->
                 if
                 :: (consulted(d) && er != NONE && !covers(AUTH_GRANT, er)) -> verdict = DENY;
                 :: else -> verdict = ALLOW;
                 fi;
            :: else ->
#ifdef OPTALLOW
                 verdict = ALLOW;   /* "authorizes every grantless sub-dispatch" */
#else
                 verdict = DENY;    /* "breaks entry dispatch" */
#endif
            fi;
#else
            /* CORRECT: three-valued. ABSENT denies outright (§5.2(c) MUST deny 403). */
            if
            :: a == AUTH_ABSENT -> verdict = DENY;
            :: else ->
                 if
                 :: (consulted(d) && er != NONE && !covers(a, er)) -> verdict = DENY;
                 :: else -> verdict = ALLOW;
                 fi;
            fi;
#endif
            outcome[d] = verdict;

            /* ---- the four §5.2 properties ---- */
            /* §5.2(c): a sub-dispatch whose parent holds no handler grant MUST deny. */
            assert(!(kind[d] == SUB && !hasGrant[d] && outcome[d] == ALLOW));
            /* §5.2(a): a covered wire-entry dispatch is not spuriously refused. */
            assert(!(kind[d] == ENTRY && (res[d] == NONE || covers(AUTH_SELF, res[d]))
                     && outcome[d] == DENY));
            /* §5.2: no dispatch allowed while carrying a target its authority does not cover. */
            assert(!(outcome[d] == ALLOW && effres(d) != NONE && !covers(authof(d), effres(d))));
            /* §5.2: the target the check receives is the one this dispatch actually named. */
            assert(effres(d) == res[d]);

            /* --- an ALLOWED dispatch may spawn an in-process sub-dispatch --- */
            if
            :: (outcome[d] == ALLOW && d + 1 < NSLOT) ->
                 p = d + 1;
                 kind[p] = SUB;
                 parent[p] = d + 1;                 /* slot index + 1 */
                 if :: hasGrant[p] = true :: hasGrant[p] = false fi;
                 if :: res[p] = NONE :: res[p] = R1 :: res[p] = R2 fi;
            :: else -> skip
            fi;
       :: else -> skip
       fi;
       d++;
  :: else -> break
  od;
}
