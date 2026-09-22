#!/usr/bin/env python3
"""obligations — how much of the pinned spec's NORMATIVE SURFACE is outside the models,
enumerated section by section, with a written disposition for every obligation-bearing
section no model cites.

WHY THIS EXISTS
---------------
On 2026-09-14 `entity-core-protocol` 0.8.2.23 closed a **capability/identity forgery**: every
authority lookup resolved an entity by a wire-supplied `included` map key that nothing verified.
The enabling text was **in this repo's pin**. `spec-data/v0.8.2` §3.1 says *"The content_hash
MUST match the map key"* -- a MUST with no enforcing operation and no vector, which is exactly
the shape `AGENTS.md` **D17** was ratified to report as a finding in its own right. D17 had never
been pointed at the core track. Meanwhile `docs/PROPERTIES.md` and
`docs/FINAL-ASSURANCE-SUMMARY.md` both published that the pinned design admits no *"forgery,
escalation, replay ... under an active attacker, at the modeled bound."*

Every gate in this repo was green throughout, and each of them was doing its job:

  coverage    the cited section set == the grid rows, both directions
  runcount    the run total == the gate tables
  ledgercount the ledger's rows/verdicts == the prose
  enginecount the engine sets == the green tables
  specdrift   which CITED sections moved
  trackcheck  every model file belongs to exactly one track
  specfreeze  no snapshot has moved

Read that list as one sentence: **every denominator in it is an artifact of ours.** `coverage`
comes closest -- it does divide by the spec's section count -- and it is the one that shows the
limit most clearly, because its unit is the SECTION and the unit of a defect is the OBLIGATION.
A section counts as covered when any model cites it for any reason, so §5.2 carries engine dots
while nine of its MUSTs are unmodeled, and §3.1 -- two MUSTs, one of them the forgery's -- is
simply not a row.

This tool supplies the missing denominator: **the spec's own obligations**, counted from the pin,
with the sections no model cites listed by name and each one carrying a written disposition. It
is the `runcount`/`enginecount` shape pointed one artifact further out.

WHAT THIS ASSERTS
-----------------
Per modeled track, against that track's own pinned primary spec:

  1. COUNTS      the obligation totals in `docs/OBLIGATIONS.toml` equal the derived ones --
                 total, the count inside sections a model of that track cites, and the count
                 inside sections none does.
  2. DISPOSITION every section that carries >=1 obligation and is cited by NO model of its
                 track has a row saying what was decided about it, from a closed vocabulary:
                   modeled-elsewhere  another track's models cover it (names which)
                   out-of-scope       named, with the reason -- not a shrug
                   UNEXAMINED         nobody has read it against the models. HONEST, and the
                                      whole point: it is a published count, not a silence
  3. NO STALE    every declared row still names a section that exists in the pin and still
                 carries at least one obligation. A row whose section lost its MUSTs is a
                 disposition of nothing.
  4. SITES       every declared prose site still states the derived pair. Deleting the claim
                 fails too -- silence is not a way to go green.

WHAT THIS DOES *NOT* ASSERT, AND THE GAP IS THE POINT
-----------------------------------------------------
  * NOT that any obligation is verified. A section can be cited, carry engine dots in Matrix A,
    and have every one of its MUSTs outside every model -- which is what happened. This tool
    measures the surface OUTSIDE the models; it says nothing about the inside.
  * NOT that the MUST count is the obligation count. One sentence can carry several obligations
    and one obligation can be restated in three sentences. `entity-system-conformance` is
    minting stable ids for the core tier (`ECP-R1..R98`); when those land they are a better
    denominator than this regex and this tool should consume them. Until then the count is a
    LOWER BOUND on the surface and an UPPER BOUND on nothing.
  * NOT that `UNEXAMINED` is safe. It is the honest state, not an acceptable one.

A PIN-OVERRIDDEN MODEL IS NOT EVIDENCE ABOUT THE PIN, AND THIS TOOL SAID IT WAS
------------------------------------------------------------------------------
Until 2026-09-16 `measure()` walked `track["models"]` entire. `coverage-check.py` does not: a
file declared in `[track.<name>.model_pins]` transcribes a NEWER snapshot, so its citations are
held out of the pin's coverage pair and pushed into the off-pin grid -- the whole reason the
published core pair fell 29 -> 27 on 2026-09-15. This tool credited those same citations AGAINST
THE PIN'S OBLIGATION DENOMINATOR, so retargeting three modules to `v0.8.2.25` left §4.7's and
§5.2a's PIN obligations counted as "inside a section a model cites" while no model here
transcribes that text any more. Two gates over one artifact, one excluding off-pin citations and
one including them, both green, published one paragraph apart.

That is D15's own rule going unapplied INSIDE the tool built to supply a denominator from the
pin: *when two tools derive a number from the same input, make them disagree out loud or make
them share the definition.* They share it now -- the partition is the same `model_pins` lookup
-- and the split is printed rather than folded away, because a silent exclusion is how the
first version of this went wrong in the other direction.

The correction moves the number the WRONG WAY ON PURPOSE: the published hole goes 120 -> 122,
because §4.7 stops counting as examined-at-the-pin. A gate whose fix makes its own headline
worse is the gate behaving correctly. The off-pin split is printed beside the headline and
every section in it must carry a note -- see `check_decl` -- so the exclusion is stated in this
repo's own file rather than inferred from two gates disagreeing.

D13 -- what else satisfies a green here? A tree where every uncited obligation-bearing section
is dispositioned `UNEXAMINED`. That is deliberately allowed and deliberately loud: the tool
prints the UNEXAMINED obligation count as its headline, so the number a reader sees is the size
of the hole and not the fact that it has been written down.

Usage:
    tools/obligations.py                  # report + gate
    tools/obligations.py --report         # report only, never fails (for triage)
    tools/obligations.py --emit           # print a skeleton OBLIGATIONS.toml for the live pin
"""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRACKS = ROOT / "TRACKS.toml"
DECL = ROOT / "docs" / "OBLIGATIONS.toml"

# MUST and MUST NOT only. SHOULD/MAY are not obligations; REQUIRED and SHALL do not occur as
# normative keywords in these documents (checked: `grep -c '\bSHALL\b'` == 0 at the pin), and
# adding them speculatively would make the denominator unreproducible against a future text.
OBLIGATION = re.compile(r"\bMUST(?:\s+NOT)?\b")

# A numbered section heading at any depth: `## 4. Connections`, `### 5.2 ...`, `### 5.5a ...`.
HEADING = re.compile(r"^(#+)\s*(\d+(?:\.\d+)?[a-z]?)\.?\s", re.M)

# A `§N.M` citation that is NOT cross-track (`§CORE:6.2` -- sigil first, per AGENTS.md).
CITATION = re.compile(r"(?<![A-Za-z:])§(\d+(?:\.\d+)?[a-z]?)")

DISPOSITIONS = {"modeled-elsewhere", "out-of-scope", "UNEXAMINED"}


def die(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def sections(text: str) -> dict[str, str]:
    """Section number -> its full text, including nested sub-headings."""
    heads = [(m.start(), len(m.group(1)), m.group(2)) for m in HEADING.finditer(text)]
    out: dict[str, str] = {}
    for i, (start, level, num) in enumerate(heads):
        end = len(text)
        for start2, level2, _ in heads[i + 1 :]:
            if level2 <= level:
                end = start2
                break
        out.setdefault(num, text[start:end])
    return out


def load_tracks() -> dict:
    with TRACKS.open("rb") as fh:
        return tomllib.load(fh)["track"]


def measure(track_name: str, track: dict) -> dict:
    """Derive the obligation split for one track from its pin and its own models."""
    pin_dir = track.get("vendored")
    if not pin_dir:
        return {}
    spec = ROOT / "spec-data" / pin_dir / track["primary_spec"]
    if not spec.exists():
        die(f"track {track_name!r}: pinned spec {spec} is missing")
    text = spec.read_text(encoding="utf-8")
    secs = {n: t for n, t in sections(text).items() if re.match(r"^\d+\.\d+", n)}

    # A pin-overridden model transcribes a different snapshot, so its citations are evidence
    # about THAT text and not about this one. Same partition, same source of truth, as
    # `coverage-check.py` -- see the module docstring for what happened when they differed.
    overrides: dict[str, str] = track.get("model_pins", {}) or {}

    cited: set[str] = set()
    offpin: set[str] = set()
    missing_models = []
    for rel in track.get("models", []):
        p = ROOT / rel
        if not p.exists():
            missing_models.append(rel)
            continue
        sink = offpin if rel in overrides else cited
        for m in CITATION.finditer(p.read_text(encoding="utf-8", errors="ignore")):
            sink.add(m.group(1))
    # Reported, not merged: a section cited by BOTH an on-pin and an off-pin model is examined
    # at the pin, and only the off-pin-ONLY set is the exclusion this partition creates.
    offpin_only = offpin - cited
    if missing_models:
        die(
            f"track {track_name!r}: {len(missing_models)} declared model file(s) do not exist "
            f"-- {missing_models[:3]}. Run `make trackcheck`."
        )

    rows = {n: len(OBLIGATION.findall(t)) for n, t in secs.items()}
    cited_secs = {n: c for n, c in rows.items() if n in cited}
    uncited = {n: c for n, c in rows.items() if n not in cited and c > 0}
    return {
        "spec": str(spec.relative_to(ROOT)),
        "sections": len(rows),
        "total": sum(rows.values()),
        "cited_sections": len(cited_secs),
        "cited_obligations": sum(cited_secs.values()),
        "uncited_sections": len(uncited),
        "uncited_obligations": sum(uncited.values()),
        "uncited": dict(sorted(uncited.items(), key=lambda kv: (-kv[1], kv[0]))),
        "offpin_only": sorted(s for s in offpin_only if rows.get(s, 0) > 0),
        "offpin_obligations": sum(rows.get(s, 0) for s in offpin_only),
    }


def emit(measured: dict[str, dict]) -> None:
    print("# docs/OBLIGATIONS.toml -- SKELETON, generated by tools/obligations.py --emit.")
    print("# Every `UNEXAMINED` below is a real hole. Change one only by doing the reading.\n")
    for name, m in measured.items():
        print(f"[track.{name}]")
        print(f'spec                 = "{m["spec"]}"')
        print(f"total                = {m['total']}")
        print(f"cited_obligations    = {m['cited_obligations']}")
        print(f"uncited_obligations  = {m['uncited_obligations']}\n")
        for sec, count in m["uncited"].items():
            print(f"[[track.{name}.uncited]]")
            print(f'section     = "{sec}"')
            print(f"obligations = {count}")
            print('disposition = "UNEXAMINED"')
            print('note        = ""\n')


# TWO numbers, and they are not the same claim -- so they get two phrasings and two checks.
# `uncited` is the surface outside the models; `UNEXAMINED` is the part of it nobody has read.
# Writing both as "N of M core obligations" is how a gate comes to read one facet of a sentence
# that states two, which is the failure this whole tool was built after (D15's thirteenth shape,
# and the `ledgercount` 14-vs-13 error before it). The phrasings are deliberately not
# interchangeable and the site check requires the UNEXAMINED one by name.
# `[^.]` rather than `[^.\n]`: a claim sentence wraps across markdown lines, and matching raw
# text line-by-line is exactly how `driftclaim`'s first draft failed six of nine sites. Excluding
# only the period still keeps the match inside one sentence.
SITE_UNEXAMINED = re.compile(r"(\d+) of (\d+) core obligations[^.]{0,48}?\bUNEXAMINED\b", re.I)
SITE_OUTSIDE = re.compile(
    r"(\d+) of (\d+) core obligations[^.]{0,48}?\bsections no model cites\b", re.I
)


def check_sites(decl: dict, measured: dict[str, dict], unexamined: dict[str, int]) -> list[str]:
    """Declared prose sites must state the UNEXAMINED pair, by that name.

    A site MAY additionally state the wider `outside the models` pair; if it does, that one is
    checked too. What a site may NOT do is state a bare `N of M core obligations` with neither
    qualifier -- two derived numbers fit that sentence and only one of them is right.
    """
    problems = []
    core = measured.get("core")
    if core is None:
        return problems
    want_unex = f"{unexamined.get('core', 0)} of {core['total']}"
    want_out = f"{core['uncited_obligations']} of {core['total']}"

    for rel in decl.get("claim_sites", []):
        p = ROOT / rel
        if not p.exists():
            problems.append(f"declared claim site {rel} does not exist")
            continue
        body = p.read_text(encoding="utf-8", errors="ignore")

        unex = SITE_UNEXAMINED.findall(body)
        if not unex:
            problems.append(
                f"{rel}: never states the UNEXAMINED obligation pair. The claim was deleted, "
                f"or the phrasing moved -- silence fails here by design (D15's eleventh shape). "
                f"Expected a sentence carrying '{want_unex} core obligations ... UNEXAMINED'."
            )
        for a, b in unex:
            if f"{a} of {b}" != want_unex:
                problems.append(
                    f"{rel}: claims '{a} of {b}' UNEXAMINED, derived '{want_unex}'"
                )
        for a, b in SITE_OUTSIDE.findall(body):
            if f"{a} of {b}" != want_out:
                problems.append(
                    f"{rel}: claims '{a} of {b}' outside the models, derived '{want_out}'"
                )

        # The unqualified form: a pair that neither regex above claimed.
        claimed = {(a, b) for a, b in unex} | set(SITE_OUTSIDE.findall(body))
        for a, b in re.findall(r"(\d+) of (\d+) core obligations", body):
            if (a, b) not in claimed:
                problems.append(
                    f"{rel}: states '{a} of {b} core obligations' with no qualifier. Two "
                    f"derived numbers fit that sentence ({want_unex} UNEXAMINED, {want_out} "
                    f"outside the models) -- say which."
                )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true", help="report only; never fail")
    ap.add_argument("--emit", action="store_true", help="print a skeleton declaration")
    args = ap.parse_args()

    tracks = load_tracks()
    modeled = {n: t for n, t in tracks.items() if t.get("status") == "modeled"}
    measured = {n: measure(n, t) for n, t in sorted(modeled.items())}
    measured = {n: m for n, m in measured.items() if m}

    if args.emit:
        emit(measured)
        return 0

    print("obligations -- the normative surface OUTSIDE the models, per track\n")
    problems: list[str] = []
    unexamined: dict[str, int] = {}

    decl = {}
    if DECL.exists():
        with DECL.open("rb") as fh:
            decl = tomllib.load(fh)
    elif not args.report:
        die(f"{DECL.relative_to(ROOT)} does not exist. Run `tools/obligations.py --emit`.")

    for name, m in measured.items():
        print(f"== track `{name}` == ({m['spec']})")
        print(
            f"  {m['sections']} numbered sections, {m['total']} MUST/MUST NOT obligations"
        )
        print(
            f"  inside sections a model cites : {m['cited_obligations']:4d}  "
            f"({m['cited_sections']} sections)"
        )
        print(
            f"  inside sections NO model cites: {m['uncited_obligations']:4d}  "
            f"({m['uncited_sections']} sections)"
        )

        d = decl.get("track", {}).get(name)
        if d is None:
            problems.append(f"track {name!r} is modeled and has no declaration in {DECL.name}")
            print("  DECLARATION MISSING\n")
            continue

        for key in ("total", "cited_obligations", "uncited_obligations"):
            if d.get(key) != m[key]:
                problems.append(
                    f"track {name!r}: declared {key}={d.get(key)}, derived {m[key]}"
                )

        declared_rows = {r["section"]: r for r in d.get("uncited", [])}
        for sec, count in m["uncited"].items():
            row = declared_rows.get(sec)
            if row is None:
                problems.append(
                    f"track {name!r}: §{sec} carries {count} obligation(s), is cited by no "
                    f"model, and has no disposition row"
                )
                continue
            if row.get("obligations") != count:
                problems.append(
                    f"track {name!r}: §{sec} declares {row.get('obligations')} obligation(s), "
                    f"derived {count}"
                )
            disp = row.get("disposition")
            if disp not in DISPOSITIONS:
                problems.append(
                    f"track {name!r}: §{sec} disposition {disp!r} is not one of "
                    f"{sorted(DISPOSITIONS)}"
                )
            if disp in ("modeled-elsewhere", "out-of-scope") and not row.get("note"):
                problems.append(
                    f"track {name!r}: §{sec} is dispositioned {disp!r} with no note. That "
                    f"disposition is a claim and has to say why."
                )
            # A SECTION A PIN-OVERRIDDEN MODEL CITES MUST SAY SO, whatever its disposition.
            # There is deliberately NO `offpin-modeled` disposition: the vocabulary's unit is
            # the SECTION and a retarget covers some of a section's obligations and not others
            # -- §3.5 carries ten MUSTs and `Resolution.*` transcribes exactly one of them --
            # so a whole-section "modeled, just off-pin" label would inflate the examined set
            # by the same reasoning D19 was written to refuse (*a section is not an
            # obligation*). These rows stay `UNEXAMINED`, which is the true statement: nothing
            # here verifies them AS THE PIN STATES THEM, which is the identical sentence
            # `docs/COVERAGE-MATRIX.md` §3f uses about the coverage pair. What is REQUIRED is
            # the note, so a reader is not left to infer that nobody looked.
            if sec in m.get("offpin_only", []) and not row.get("note"):
                problems.append(
                    f"track {name!r}: §{sec} is cited ONLY by a pin-overridden model and its "
                    f"row has no note. The retarget took this section out of the pin's "
                    f"examined set; say which model, which snapshot, and what it does cover."
                )
        for sec in declared_rows:
            if sec not in m["uncited"]:
                problems.append(
                    f"track {name!r}: §{sec} has a disposition row but is now either cited by "
                    f"a model or carries no obligations -- the row is stale, remove it"
                )

        if m.get("offpin_only"):
            print(
                f"  of those, OFF-PIN MODELED    : {m['offpin_obligations']:4d}   "
                f"in §{', §'.join(m['offpin_only'])}"
            )
            print(
                "     (a model covers these against a NEWER snapshot, so nothing here verifies"
                "\n      them as the PIN states them -- the same exclusion `make coverage` makes)"
            )
        unex = sum(
            r.get("obligations", 0)
            for r in d.get("uncited", [])
            if r.get("disposition") == "UNEXAMINED"
        )
        unexamined[name] = unex
        print(f"  of those, UNEXAMINED          : {unex:4d}   <-- the hole, published")
        print()

    problems += check_sites(decl, measured, unexamined)

    print(
        "This asserts the obligation surface OUTSIDE the models is enumerated and every\n"
        "obligation-bearing section none of them cites carries a written disposition.\n"
        "It does NOT assert that any obligation is VERIFIED -- a cited section can carry\n"
        "engine dots in Matrix A with every one of its MUSTs outside every model. That is\n"
        "the gap that produced this tool (docs/status/AUDIT-2026-09-14-*).\n"
        "The MUST count is a regex over the pin, not an obligation id. When\n"
        "`entity-system-conformance`'s ECP-R ids land, consume those instead."
    )

    if args.report:
        return 0
    if problems:
        print(f"\nFAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        print("\nThe measurement is the source of truth. Fix the declaration, not this tool.")
        return 1
    print("\nOK -- every track's obligation split matches its declaration, and every")
    print("obligation-bearing section no model cites has a disposition.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
