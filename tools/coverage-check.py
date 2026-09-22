#!/usr/bin/env python3
"""coverage-check — is the coverage claim in COVERAGE-MATRIX.md what the models actually say?

Why this exists
---------------
Matrix A in `docs/COVERAGE-MATRIX.md` is *derived* from the `§`-citations the models carry,
rather than from a list someone chose, precisely so the coverage number cannot drift from the
work. Deriving it is not the same as checking it: the derivation was done by hand, by grep,
and then written into prose that nothing re-reads.

Two audits running found what that allows. §4.7 sat in the grid as an "Apalache-only" result
when NOTHING modeled it — the only §4.7 mention in the repo was the far end of a section
range in one comment. §6.9 sat there as a "TLC-only" result when both of its mentions were
DISCLAIMERS saying bootstrap handlers are not modeled. Two phantom rows, both counted.

The general failure is D13 asked of a derived metric instead of a gate: **what does this
number assert, and what else produces it?** A `§` mention is not a claim of coverage. At
least four things produce one, and only the last is a claim:

  1. a section RANGE written with a sigil on both ends -- the endpoint scans as a citation
  2. an out-of-scope DISCLAIMER -- "§X is not modeled here"
  3. a cross-reference to another DOCUMENT's section -- "handoff §6"
  4. an actual claim about the section

TRACKS: the fifth producer, added 2026-09-06 before it could bite
-----------------------------------------------------------------
`§(\\d+\\.\\d+)` is DOCUMENT-BLIND. `EXTENSION-ATTESTATION §5.7` (the attestation index
invariants) and core `§5.7` (delegation caveats) produce the identical token, and core already
has a `5.7` row -- so the first extension model's citations would have been absorbed into a
CORE coverage claim and this gate would have reported OK. A phantom row arriving *through* the
gate built to stop phantom rows.

The second half was quieter: this file globbed `tla/*.tla` NON-RECURSIVELY, so moving models
into `tla/attestation/` -- the obvious first reorganization -- would have made them invisible
here while the gate stayed green. Both halves are closed by reading `TRACKS.toml` for the file
list instead of globbing, and by deriving every number PER TRACK.

What this asserts, per modeled protocol track
---------------------------------------------
  A. The set of `§N.M` sections cited by THAT TRACK'S models EXACTLY equals the set of rows in
     that track's grid section. Neither may drift: a model that starts citing a section
     without a grid row fails, and a grid row with no citation behind it fails.
  B. The coverage COUNT stated in that track's prose equals the size of that set, and the
     denominator equals the number of numbered sections in THAT TRACK'S pinned primary spec.
  C. Neither tripwire fires: no `§X-§Y` range form, and no `§` inside a scope disclaimer.
  D. Every cross-track citation prefix names a track that exists.

What this does NOT assert
-------------------------
The ENGINE COLUMNS. Which of TLC / Apalache / Spin / ProVerif / Tamarin covers each section
is still hand-maintained, because "this model checks a property of §X" is not recoverable
from a citation -- the citation only says the model is *about* §X. Said plainly here rather
than left for a reader to assume the whole grid is machine-checked.

Nor that a file is on the right TRACK -- that is `make trackcheck`'s subject, and even there
it is a human's declaration.

Usage:
  tools/coverage-check.py
  tools/coverage-check.py --tracks TRACKS.toml

Exit status: 0 iff every check above passes. Suitable as a gate.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tomllib

# A citation of a numbered spec subsection. `(?![\d.])` stops `§4.10` matching as `§4.1`;
# the optional trailing letter is resolved by `fold()` below, not dropped here.
CITATION = re.compile(r"§\s*(\d+\.\d+[a-z]?)(?![\d.])")
# A CROSS-TRACK citation: `§CORE:6.2` inside an attestation model. Captured separately and
# deliberately EXCLUDED from every track's coverage set -- it is a cross-reference, not a claim
# that the cited section is verified here. Same disposition the §3b taxonomy already gives
# "a cross-reference to another DOCUMENT's section", one spec body over.
#
# THE SIGIL COMES FIRST, AND THAT IS A FIX, NOT A STYLE CHOICE. The first draft of this
# notation was `CORE §6.2` -- prefix, space, sigil -- matched by `\b([A-Z][A-Z0-9]{2,11})\s+§`.
# Running it produced 23 false hits across 12 model files, because ordinary prose puts
# capitalized words before a citation all the time: `WHAT §6.9 SAYS`, `LIVENESS §4.1`,
# `THE §5.8`, and every Spin `-D` macro name (`DSERIALIZED §6.11`). Each false hit was then
# EXCLUDED from the bare citation set for its line -- so the tripwire built to stop citations
# being miscredited was silently DROPPING them instead. The published count stayed 28 only
# because every affected section happens to be cited on some other line too; had `§6.9`'s only
# citation been on the `WHAT §6.9 SAYS` line, coverage would have quietly fallen to 27 and the
# grid check would have called it a phantom row. Reading the regex did not catch this; running
# it did (D15's corollary, again).
#
# `§X:N.M` cannot collide: a bare citation is `§` + digit, and the existing intra-document
# forms in this repo are `§C.4` / `§D` -- a DOT or nothing, never a colon.
PREFIXED = re.compile(r"§([A-Z][A-Z0-9]{1,11}):(\d+\.\d+[a-z]?)(?![\d.])")
# A row of Matrix A: `| 4.7 | topic | ... |`, with optional ** bolding on the section cell.
GRID_ROW = re.compile(r"^\|\s*\*{0,2}(\d+\.\d+[a-z]?)\*{0,2}\s*\|", re.M)
# "**Coverage: 29 of 91 numbered `§N.M` sections (32%).**"
COUNT = re.compile(r"Coverage:\s*\*{0,2}(\d+)\*{0,2}\s+of\s+\*{0,2}(\d+)\*{0,2}\s+numbered")
# A numbered heading in a pinned spec: `### 4.7 Connection Error Codes`, or `### 5.2a
# Verdict-to-status enumeration`. `####` is excluded -- a fourth-level heading is a
# SUBSECTION of the section above it, not a section of its own.
#
# THE LETTER SUFFIX WAS EXCLUDED HERE UNTIL 2026-09-07, AND THAT WAS TWO ERRORS.
# (1) The denominator silently dropped every lettered section: SIX of them in core
#     (`1.2a`, `1.5a`, `4.5a`, `5.2a`, `6.9a`, `9.5a`) and two in attestation (`5.6a`,
#     `5.6b`). "28 of 85" was a fraction over a section set that omitted normative
#     sections for no stated reason -- D15's own subject, the input set a number is
#     derived over, asked of the DENOMINATOR rather than the numerator.
# (2) Worse, `CITATION` dropped the letter too, so a citation of `§5.2a` (the
#     verdict-to-status enumeration) was credited to `§5.2` (the verification
#     algorithm) -- two different `###` sections, 320 lines apart. That is the §4.7
#     miscredit mechanism in a new shape: not a range endpoint, a letter suffix.
#
# And `tools/spec-drift.py` had it RIGHT the whole time (`[a-z]?` in both its heading
# and citation patterns), which is why it reports 30 cited sections where this tool
# reported 28. Two gates over one artifact, disagreeing by two, with both numbers
# published in the same documents and neither reconciled to the other. The convention
# is spec-drift's now, in both tools.
SPEC_HEADING = re.compile(r"^#{2,3}\s+(\d+\.\d+[a-z]?)\s+\S", re.M)


# ── WHERE THE COVERAGE NUMBERS ARE CLAIMED OUTSIDE THE GRID ─────────────────────────────
# Added 2026-09-07, and the reason is that it was needed: the letter-suffix fix moved core
# from "28 of 85" to "29 of 91", and this tool checked ONE site -- the `Coverage:` line inside
# the grid section it derives from. README.md's headline, docs/STATUS.md's pointer and
# COVERAGE-MATRIX §5's complement ("N of M sections are not cited by any model") all stated
# the old pair, and all three were found BY GREP. A number this repo publishes is checked;
# these were published and unchecked, which is exactly the hole `make runcount` was built to
# close for the run total, one artifact over.
#
# Each row is (track, file, description, pattern with two capture groups, kind). `pair` means
# the groups are (numerator, denominator); `complement` means they are (uncited, denominator),
# i.e. the same claim stated from the other end -- which is its own staleness risk, because a
# reader checks the two against each other and neither against the models.
#
# A pattern that matches NOTHING is a failure, same as runcount: a site that stops making the
# claim is how a number goes stale unnoticed. And the cost is stated: this asserts the
# ANCHORED sites. A new prose site quoting a coverage pair and not listed here is unchecked,
# and nothing detects that.
COVERAGE_PROSE_SITES = [
    ("core", "README.md", "the coverage headline",
     r"Coverage: (\d+) of (\d+) numbered spec sections", "pair"),
    ("core", "docs/STATUS.md", "the pointer to COVERAGE-MATRIX.md",
     r"Headline: \*\*(\d+) of (\d+) numbered sections", "pair"),
    ("core", "docs/COVERAGE-MATRIX.md", "the section-5 not-covered complement",
     r"\*\*(\d+) of (\d+) sections are not cited by any model\.\*\*", "complement"),
    # FOURTH SITE, ADDED 2026-09-07, AND IT WAS ALREADY STALE WHEN ADDED. docs/STATUS.md
    # §Next item 1 said "they reach **28 of the 85 numbered sections**" -- the pre-letter-suffix
    # pair, left behind by the fix that moved core to 29 of 91 and corrected three other sites.
    # It survived because it is phrased differently from all three of those ("they reach", not
    # "Coverage:"), so the grep that found them missed it and this table did not list it.
    # That is precisely the cost this table's own header declares: "A new prose site quoting a
    # coverage pair and not listed here is unchecked, and nothing detects that." The declaration
    # was accurate and the hole was real for a day. Worth noting the shape rather than only the
    # fix: a stale number hides best in a sentence that states it in DIFFERENT WORDS from the
    # canonical one, because every search for the staleness is a search for the canonical
    # phrasing. Same mechanism as D14's retracted-phrasing rule, inverted.
    ("core", "docs/STATUS.md", "the coverage-breadth item in §Next",
     r"they reach \*\*(\d+) of (\d+) numbered sections", "pair"),
]


def check_coverage_prose(root: str, derived: dict[str, tuple[int, int]]) -> list[str]:
    out: list[str] = []
    for track, rel, what, pat, kind in COVERAGE_PROSE_SITES:
        if track not in derived:
            continue                      # track not modeled in this run; nothing to compare
        num, denom = derived[track]
        want = (denom - num, denom) if kind == "complement" else (num, denom)
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            out.append(f"{rel}: {what}: file not found")
            continue
        m = re.search(pat, re.sub(r"\s+", " ", read(path)))
        if not m:
            out.append(
                f"{rel}: {what} no longer states the coverage pair"
                "\n      -> restore the claim, or drop the row from COVERAGE_PROSE_SITES."
            )
            continue
        got = (int(m.group(1)), int(m.group(2)))
        if got != want:
            out.append(f"{rel}: {what} states {got[0]} of {got[1]};"
                       f" derived {want[0]} of {want[1]} for track `{track}`")
    return out


def fold(tok: str, spec: set[str]) -> str:
    """A cited token, resolved against the track's own section set.

    `§5.2a` is a section of core and stays `5.2a`. `§5.5a` is a `####` SUBSECTION of
    `§5.5` and folds to it. `§4.9a` is not a heading at all -- it is clause (a) inside
    §4.9's prose -- and folds the same way. So the rule is one line: keep the letter if
    the spec has that section, otherwise it names something inside its parent.

    When the spec is unreadable the set is empty and every lettered token folds. That is
    the pre-2026-09-07 behavior, and it is the safe direction: folding can understate
    coverage, keeping can mint a row for a section that does not exist.
    """
    return tok if tok in spec else re.sub(r"[a-z]$", "", tok)

# Tripwire 1: a section range written with a sigil on BOTH ends mints a phantom endpoint.
RANGE_FORM = re.compile(r"§ ?\d+(?:\.\d+)*[a-z]? *[-–—] *§")
# Tripwire 2: a `§` inside a sentence that declares something out of scope.
DISCLAIMER = re.compile(r"(not modeled|are abstracted|bypass(?:es)?\b|out of scope)", re.I)


def read(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def section_block(text: str, heading: str) -> str | None:
    """The doc text under `heading`, down to the next heading of the same or higher level.

    Scoping the grid to the track's own section is what stops two tracks' matrices being
    read as one -- the whole point of deriving per track rather than per file.
    """
    m = re.search(rf"^(#{{1,6}})\s+.*{re.escape(heading)}.*$", text, re.M)
    if not m:
        return None
    level = len(m.group(1))
    nxt = re.search(rf"^#{{1,{level}}}\s+\S", text[m.end():], re.M)
    return text[m.start(): m.end() + nxt.start()] if nxt else text[m.start():]


def pin_dir(root: str, pin_file: str) -> str | None:
    """First non-comment, non-blank line of a pin file — the same parse spec-drift.py does."""
    path = os.path.join(root, pin_file)
    if not os.path.isfile(path):
        return None
    for line in read(path).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            return os.path.join("spec-data", line)
    return None


def skey(s: str) -> list[int]:
    """Sort key. A lettered section sorts immediately after its parent: 5.2 < 5.2a < 5.3."""
    m = re.fullmatch(r"([\d.]+?)([a-z]?)", s)
    head, suffix = (m.group(1), m.group(2)) if m else (s, "")
    return [int(x) for x in head.split(".")] + [ord(suffix) if suffix else 0]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--tracks", default="TRACKS.toml")
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = args.root

    with open(os.path.join(root, args.tracks), "rb") as fh:
        cfg = tomllib.load(fh)
    tracks: dict[str, dict] = cfg.get("track", {})
    prefixes = {t.get("cite_prefix"): n for n, t in tracks.items() if t.get("cite_prefix")}

    problems: list[str] = []
    modeled = [
        (n, t) for n, t in sorted(tracks.items())
        if t.get("kind") == "protocol" and t.get("status") == "modeled"
    ]
    if not modeled:
        print("FAIL -- TRACKS.toml declares no modeled protocol track", file=sys.stderr)
        return 1

    total_cited = 0
    derived: dict[str, tuple[int, int]] = {}
    for name, t in modeled:
        files = [os.path.join(root, f) for f in t.get("models", [])]
        missing = [f for f in files if not os.path.isfile(f)]
        if missing:
            # `trackcheck` owns this failure; fail here too rather than silently scanning less.
            problems.append(
                f"track {name}: {len(missing)} declared model file(s) do not exist"
                f" (first: {missing[0]}) -- run `make trackcheck`"
            )
            print(f"  MISSING   track {name}: {len(missing)} declared file(s) absent")
            continue

        print(f"== track `{name}` — cited §N.M sections vs its grid rows ==")

        # The track's own section set, read here rather than at the denominator check
        # below, because `fold()` needs it to tell `§5.2a` (a section) from `§5.5a` (a
        # subsection) from `§4.9a` (a clause inside one). Same file, read once.
        pin = pin_dir(root, t.get("pin_file", ""))
        primary = os.path.join(root, pin, t["primary_spec"]) if pin else None
        spec = set(SPEC_HEADING.findall(read(primary))) if primary and \
            os.path.isfile(primary) else set()

        # ---- pin-overridden models -------------------------------------------------
        # Declared in `[track.<name>.model_pins]`, gated both directions by `make trackcheck`.
        # A model transcribing a newer snapshot is NOT evidence about the pin, so its
        # citations are held out of the coverage pair exactly as a cross-track reference is.
        #
        # ⛔ THE CONSEQUENCE IS VISIBLE AND IT IS SUPPOSED TO BE. Retargeting a module REMOVES
        # its sections from the pin's coverage claim wherever no pin-targeting model also
        # cites them -- the published `N of M` goes DOWN. That is the honest reading: nothing
        # now verifies those sections AS THE PIN STATES THEM. A header-sentence override would
        # have left the number untouched and the claim false, which is why the override is a
        # registry fact with a gate rather than prose (AGENTS.md D15's eleventh shape).
        overrides: dict[str, str] = t.get("model_pins", {}) or {}
        ospec: dict[str, set[str]] = {}
        for snap in sorted(set(overrides.values())):
            p = os.path.join(root, "spec-data", snap, t["primary_spec"])
            ospec[snap] = set(SPEC_HEADING.findall(read(p))) if os.path.isfile(p) else set()

        # ---- gather citations, splitting cross-track references out ---------------
        cited: dict[str, set[str]] = {}
        offpin: dict[str, set[str]] = {}
        crossrefs: dict[str, list[str]] = {}
        bad_prefix: list[str] = []
        for f in files:
            rel = os.path.relpath(f, root)
            # `fold()` needs the section set of the text THIS FILE transcribes, so that
            # `§5.2a` is read as a heading where it is one. Using the pin's set for an
            # overridden file is how a lettered clause gets credited to the wrong parent.
            fspec = ospec.get(overrides.get(rel), spec) if rel in overrides else spec
            sink = offpin if rel in overrides else cited
            for n, line in enumerate(read(f).splitlines(), 1):
                pref = {(p, s) for p, s in PREFIXED.findall(line)}
                for p, s in pref:
                    if p in prefixes:
                        crossrefs.setdefault(prefixes[p], []).append(f"{rel}:{n} {p} §{s}")
                    else:
                        bad_prefix.append(f"{rel}:{n}: {p} §{s}")
                # No exclusion needed: a bare citation is `§` + digit and a cross-track one is
                # `§` + letter, so the two patterns are disjoint by construction. The first
                # draft subtracted the prefixed sections from this line's bare set, which is
                # what turned 23 false prefix hits into 23 silently dropped citations.
                for s in CITATION.findall(line):
                    sink.setdefault(fold(s, fspec), set()).add(rel)

        if bad_prefix:
            problems.append(
                f"track {name}: citation prefix names no declared track:\n      "
                + "\n      ".join(bad_prefix)
                + "\n      -> use a cite_prefix from TRACKS.toml, or drop the prefix if the"
                  "\n         citation is about this track's own spec."
            )
            for b in bad_prefix:
                print(f"  BADPREFIX {b}")

        # ---- A. cited set == grid set, both directions ----------------------------
        matrix_path = os.path.join(root, t.get("coverage_doc", ""))
        block = section_block(read(matrix_path), t.get("coverage_heading", "")) if \
            os.path.isfile(matrix_path) else None
        if block is None:
            problems.append(
                f"track {name}: no grid section {t.get('coverage_heading')!r}"
                f" in {t.get('coverage_doc')}"
            )
            print(f"  NOGRID    track {name}")
            continue
        grid = set(GRID_ROW.findall(block))

        only_cited = sorted(set(cited) - grid, key=skey)
        only_grid = sorted(grid - set(cited), key=skey)
        if only_cited:
            problems.append(
                f"track {name}: cited by a model but absent from its grid: "
                + ", ".join(f"§{s} ({', '.join(sorted(cited[s]))})" for s in only_cited)
                + "\n      -> either add the row, or -- if the citation is a range endpoint, a"
                  "\n         disclaimer or a cross-reference to another document -- drop the sigil."
                  "\n         If it is another TRACK's section, prefix it (e.g. `§CORE:6.2`)."
            )
            for s in only_cited:
                print(f"  UNGRIDDED §{s:6s} {', '.join(sorted(cited[s]))}")
        if only_grid:
            problems.append(
                f"track {name}: in the grid but cited by no model: "
                + ", ".join(f"§{s}" for s in only_grid)
                + "\n      -> a phantom row. This is exactly how §4.7 and §6.9 got in."
            )
            for s in only_grid:
                print(f"  PHANTOM   §{s}")
        if not only_cited and not only_grid:
            print(f"  ok        {len(grid)} sections, both directions ({len(files)} model files)")
        for tgt, refs in sorted(crossrefs.items()):
            print(f"  crossref  {len(refs)} citation(s) to track `{tgt}` "
                  f"(excluded from both tracks' coverage sets)")

        # ---- A2. the off-pin grid, both directions ---------------------------------
        # Held out of the pair above, and therefore needing its own declared home: an
        # excluded set that is reported and nowhere published is a set nobody reads. Same
        # both-directions rule as Matrix A, against the track's `offpin_heading`.
        if offpin:
            # A section cited by BOTH an overridden and a pin-targeting model stays in the
            # pin's claim -- some model really does transcribe the pin's text for it -- so
            # only the sections NO pin model cites are off-pin.
            only_off = {s: v for s, v in offpin.items() if s not in cited}
            ohead = t.get("offpin_heading", "")
            print(f"\n== track `{name}` — sections cited ONLY by pin-overridden models ==")
            if not ohead:
                problems.append(
                    f"track {name}: declares model_pins but no `offpin_heading`."
                    "\n      -> a set held out of the coverage pair needs a published home, or"
                    "\n         it is a silent exclusion -- which is the thing this gate is for."
                )
                print("  NOHEADING no offpin_heading declared")
            else:
                oblock = section_block(read(matrix_path), ohead)
                if oblock is None:
                    problems.append(
                        f"track {name}: no off-pin grid section {ohead!r} in"
                        f" {t.get('coverage_doc')}"
                    )
                    print(f"  NOGRID    {ohead!r}")
                else:
                    ogrid = set(GRID_ROW.findall(oblock))
                    oc = sorted(set(only_off) - ogrid, key=skey)
                    og = sorted(ogrid - set(only_off), key=skey)
                    for s in oc:
                        problems.append(
                            f"track {name}: §{s} cited only by a pin-overridden model and"
                            f" absent from the off-pin grid ({', '.join(sorted(only_off[s]))})"
                        )
                        print(f"  UNGRIDDED §{s:6s} {', '.join(sorted(only_off[s]))}")
                    for s in og:
                        problems.append(
                            f"track {name}: §{s} is in the off-pin grid but cited by no"
                            " pin-overridden model -- a phantom row, off-pin edition"
                        )
                        print(f"  PHANTOM   §{s}")
                    if not oc and not og:
                        print(f"  ok        {len(ogrid)} off-pin section(s), both directions")
            shared = sorted(set(offpin) & set(cited), key=skey)
            if shared:
                print(f"  shared    §{', §'.join(shared)} — also cited by a pin-targeting "
                      f"model, so they stay in the pin's claim above")

        # ---- B. the stated count ---------------------------------------------------
        print(f"\n== track `{name}` — the count stated in prose ==")
        m = COUNT.search(block)
        if not m:
            problems.append(
                f"track {name}: no `Coverage: N of M numbered ...` line in its grid section"
            )
            print("  MISSING   no coverage claim found")
        else:
            stated, denom = int(m.group(1)), int(m.group(2))
            if stated != len(cited):
                problems.append(
                    f"track {name}: stated coverage {stated} != {len(cited)} sections cited"
                )
                print(f"  WRONG     stated {stated}, actual {len(cited)}")
            else:
                print(f"  ok        {stated} cited")

            # `pin`, `primary` and `spec` were computed above, before the citation pass.
            if not spec:
                # D13: a check that cannot run is a FAILURE, not a silent pass. The denominator
                # is the honest half of "28 of 85" and dropping it quietly is how the numerator
                # ends up quoted against a number nobody verified.
                problems.append(
                    f"track {name}: cannot check the denominator: no readable"
                    f" {t.get('primary_spec')} at {pin or t.get('pin_file')}"
                    f" (prose claims {denom})"
                )
                print(f"  UNCHECKED denominator {denom}: no spec at {pin!r}")
            elif len(spec) != denom:
                problems.append(
                    f"track {name}: stated denominator {denom} != {len(spec)} numbered"
                    f" §N.M headings in {pin}/{t['primary_spec']}"
                )
                print(f"  WRONG     denominator stated {denom}, actual {len(spec)}")
            else:
                print(f"  ok        denominator {denom} matches {pin}/{t['primary_spec']}")

        # ---- C. the two tripwires --------------------------------------------------
        print(f"\n== track `{name}` — tripwires (what else produces a citation) ==")
        ranges: list[str] = []
        disclaimers: list[str] = []
        for f in files:
            rel = os.path.relpath(f, root)
            for n, line in enumerate(read(f).splitlines(), 1):
                if RANGE_FORM.search(line):
                    ranges.append(f"{rel}:{n}: {line.strip()[:110]}")
                if "§" in line and DISCLAIMER.search(line) and CITATION.search(line):
                    disclaimers.append(f"{rel}:{n}: {line.strip()[:110]}")
        if ranges:
            problems.append(
                f"track {name}: section RANGE written with a sigil on both ends (mints a"
                " phantom endpoint; write `§4.1–4.7`):\n      " + "\n      ".join(ranges)
            )
            for r in ranges:
                print(f"  RANGE     {r}")
        else:
            print("  ok        no §X-§Y range forms")
        if disclaimers:
            # Not fatal on its own -- a disclaimer may legitimately sit in a file that DOES
            # claim the section. Report for review rather than fail; A catches the real damage.
            print(f"  review    {len(disclaimers)} § inside a scope-disclaimer sentence:")
            for d in disclaimers:
                print(f"            {d}")
            print("            (not a failure: check A confirms every one has a real claim behind")
            print("             it. Flagged because a disclaimer-only citation is a phantom row.)")
        else:
            print("  ok        no § inside a scope disclaimer")
        print()
        total_cited += len(cited)
        derived[name] = (len(cited), len(spec))

    prose = check_coverage_prose(root, derived)
    if prose:
        print("== the coverage pair as claimed outside the grid ==")
        for pr in prose:
            print(f"  WRONG     {pr.splitlines()[0]}")
        print()
        problems.extend(prose)
    else:
        print("== the coverage pair as claimed outside the grid ==")
        print(f"  ok        {len(COVERAGE_PROSE_SITES)} declared site(s) agree\n")

    scoped = [n for n, t in sorted(tracks.items())
              if t.get("kind") == "protocol" and t.get("status") == "scoped"]
    if scoped:
        print(f"== not checked here: {len(scoped)} scoped track(s) — {', '.join(scoped)} ==")
        print("  Declared in TRACKS.toml with a landed spec and a VENDORED snapshot but no pin and")
        print("  no model -- vendoring is not pinning, and only a pinned track publishes results,")
        print("  so these publish no coverage claim. `make trackcheck` keeps that true:")
        print("  a scoped track that acquires a model file fails until it is promoted with a pin.")
        print()

    if problems:
        print(f"FAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(
        f"OK -- {total_cited} sections cited across {len(modeled)} modeled track(s); each grid in\n"
        "sync, each count and denominator verified against that track's own pin.\n"
        "This asserts the SECTION SET and the COUNT, per track. The engine columns are still\n"
        "hand-maintained -- a citation says a model is ABOUT a section, not which engine\n"
        "verifies what. Nor does it assert a file is on the right track (`make trackcheck`).\n"
        "There is deliberately NO repo-wide coverage number: averaging a verified protocol\n"
        "with unmodeled ones produces a figure that is true of nothing."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
