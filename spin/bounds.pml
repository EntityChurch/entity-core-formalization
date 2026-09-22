/*
 * bounds.pml — INDEPENDENT Promela re-encoding of V8 §5.9 Bounds Propagation and
 * §4.10(b) capability-chain depth. Cross-check #B for the TLA+ `Bounds` model
 * (tla/Bounds.tla).
 *
 * DISCIPLINE (docs/CROSSCHECK-RESULTS.md, Track B): written FROM the §5.9 / §4.10(b) text —
 * two separate brakes on a runaway chain, which one fires first, how much each charges, and
 * what each says — NOT by translating the .tla. Added at 0.8.2 because `Bounds` shipped with
 * TLC coverage only, which the audit flagged.
 *
 * THE THREE RULES UNDER TEST, verbatim from the spec:
 *   §5.9  "the depth brake, not TTL, is what terminates a runaway chain, and equal magnitudes
 *          (both were 64) violate it by letting TTL mask the deterministic brake"
 *   §5.9  Ruling 1 — TTL is "decremented ONCE PER DISPATCH... NEVER DOUBLE-COUNTED"
 *   §4.10(b) Ruling 3 — "Two mechanisms, two reason codes — they MUST NOT share a reason
 *          string" (continuation brake = bounds_exceeded 429; capability-chain limit =
 *          chain_depth_exceeded 400)
 *
 * VARIANTS (mirror the TLA+ negative controls; select via -D<NAME>):
 *   (default)      ceiling 4, worst-case fan-out 2, seed 16 -> 4*2 = 8 < 16, all hold.
 *   -DEQUALMAG     seed == ceiling (the "9-vs-64" divergence) -> DepthBrakeFirst VIOLATED
 *   -DRATIOBOUND   seed == ceiling * fanout exactly (no margin) -> DepthBrakeFirst VIOLATED
 *   -DDOUBLECOUNT  charged at ingress AND on forward -> TtlNotDoubleCounted VIOLATED
 *   -DSHARECODE    the continuation brake borrows chain_depth_exceeded -> codes VIOLATED
 *
 * Fidelity (5th wall): magnitudes are scaled down from §4.10's informative defaults
 * (64 / 512). §4.10 states the contract is "enforce a finite *declared* bound... never
 * 'pick this number'", so the RATIO is the modeled content, not the magnitude. Note the TLA+
 * side goes further: tla/BoundsApalache.tla proves the brake property over SYMBOLIC
 * constants constrained only by the ratio condition, so it covers every conforming
 * deployment. This model checks one concrete configuration exhaustively; that difference in
 * reach between the two tools is real and is recorded in docs/COVERAGE-MATRIX.md.
 *
 * Build / run (from spin/, image entity-spin):
 *   safety: make verify MODEL=bounds [DEFS=-DEQUALMAG]   (expect errors: 0 / assertion)
 */

/* §5.9 magnitudes. */
#ifdef EQUALMAG
  #define TTLSEED 4        /* equal magnitudes: TTL cannot outlast the depth brake */
#else
#ifdef RATIOBOUND
  #define TTLSEED 8        /* ceiling * fanout EXACTLY — the boundary, no margin */
#else
  #define TTLSEED 16       /* 4 * 2 = 8 < 16: the brake engages strictly first */
#endif
#endif

#define CEILING   4        /* §5.9 continuation causal-depth ceiling (the DETERMINISTIC brake) */
#define MAXFANOUT 2        /* the peer's worst-case sub-dispatch fan-out */
#define MAXCAPD   3        /* §4.10(b) max presented CAPABILITY-chain depth */

/* halt states */
#define RUNNING  0
#define H_DEPTH  1         /* the continuation causal-depth brake engaged */
#define H_TTL    2         /* the TTL backstop fired */
#define H_CAPD   3         /* §4.10(b) capability-chain depth limit */

/* reason strings */
#define C_NONE      0
#define C_BOUNDS    1      /* bounds_exceeded (429) — the continuation brake */
#define C_TTLEXH    2      /* ttl_exhausted */
#define C_CHAINDEP  3      /* chain_depth_exceeded (400) — the capability-chain limit */

#ifdef SHARECODE
  /* DEFECT: the continuation brake borrows the capability-chain limit's reason string. */
  #define DEPTHBRAKECODE C_CHAINDEP
#else
  #define DEPTHBRAKECODE C_BOUNDS
#endif

byte depth      = 0;       /* §5.9 continuation causal depth */
byte ttl        = TTLSEED; /* §5.9 the resource backstop; seeded once at chain origin */
byte capDepth   = 0;       /* §4.10(b) presented capability-chain depth */
byte spent      = 0;       /* total TTL charged */
byte dispatches = 0;       /* total dispatches performed */
byte halt       = RUNNING;
byte code       = C_NONE;

active proctype chain()
{
  byte f, charge;

  do
  :: (halt == RUNNING) ->
       if
       /* ---- §5.9 causal advancement ---- */
       :: (depth + 1 > CEILING) ->
            /* the DETERMINISTIC brake engages — this is what SHOULD stop a runaway chain */
            atomic { halt = H_DEPTH; code = DEPTHBRAKECODE; }
       :: (depth + 1 <= CEILING) ->
            /* this level's sub-dispatch fan-out */
            if :: f = 1 :: f = 2 fi;
#ifdef DOUBLECOUNT
            charge = 2 * f;      /* DEFECT: charged at ingress AND again on forward */
#else
            charge = f;          /* §5.9 Ruling 1: once per dispatch */
#endif
            atomic {
              spent = spent + charge;
              dispatches = dispatches + f;
              if
              :: (ttl <= charge) ->
                   /* the TTL backstop fired FIRST — the chain terminated on the resource
                    * brake rather than the deterministic one */
                   halt = H_TTL; code = C_TTLEXH; ttl = 0;
              :: (ttl > charge) ->
                   ttl = ttl - charge;
                   depth = depth + 1;
              fi;
            }
       /* ---- §4.10(b) an independent, deeper capability chain is presented ---- */
       :: (capDepth < MAXCAPD + 1) ->
            atomic {
              capDepth++;
              if
              :: (capDepth > MAXCAPD) -> halt = H_CAPD; code = C_CHAINDEP;
              :: else -> skip
              fi;
            }
       fi;

       /* ---- the properties ---- */
       /* §5.9: the depth brake, not TTL, terminates a runaway chain. */
       assert(halt != H_TTL);
       /* §5.9 Ruling 1: TTL charged once per dispatch, never double-counted. */
       assert(spent == dispatches);
       /* §4.10(b) Ruling 3: two mechanisms, two reason strings. */
       assert(!(halt == H_DEPTH && code != C_BOUNDS));
       assert(!(halt == H_CAPD  && code != C_CHAINDEP));
       /* §5.9: chain_depth and TTL are orthogonal — depth never exceeds the TTL charged. */
       assert(depth <= spent);
  :: (halt != RUNNING) -> break
  od;
}
