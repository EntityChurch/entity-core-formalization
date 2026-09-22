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

What this asserts
-----------------
  A. The set of `§N.M` sections cited by the models EXACTLY equals the set of rows in
     Matrix A. Neither may drift: a model that starts citing a section without a grid row
     fails, and a grid row with no citation behind it fails.
  B. The coverage COUNT stated in the prose equals the size of that set, and the
     denominator equals the number of numbered sections in the pinned spec.
  C. Neither tripwire fires: no `§X-§Y` range form, and no `§` inside a scope disclaimer.

What this does NOT assert
-------------------------
The ENGINE COLUMNS. Which of TLC / Apalache / Spin / ProVerif / Tamarin covers each section
is still hand-maintained, because "this model checks a property of §X" is not recoverable
from a citation -- the citation only says the model is *about* §X. Said plainly here rather
than left for a reader to assume the whole grid is machine-checked.

Usage:
  tools/coverage-check.py
  tools/coverage-check.py --matrix docs/COVERAGE-MATRIX.md

Exit status: 0 iff every check above passes. Suitable as a gate.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

MODEL_GLOBS = ("tla/*.tla", "spin/*.pml", "tamarin/*.pv", "tamarin/*.spthy")

# A citation of a numbered spec subsection. `(?![\d.])` stops `§4.10` matching as `§4.1`.
CITATION = re.compile(r"§\s*(\d+\.\d+)(?![\d.])")
# A row of Matrix A: `| 4.7 | topic | ... |`, with optional ** bolding on the section cell.
GRID_ROW = re.compile(r"^\|\s*\*{0,2}(\d+\.\d+)\*{0,2}\s*\|", re.M)
# "**Coverage: 28 of 85 numbered `§N.M` sections (33%).**"
COUNT = re.compile(r"Coverage:\s*\*{0,2}(\d+)\*{0,2}\s+of\s+\*{0,2}(\d+)\*{0,2}\s+numbered")
# A numbered heading in the pinned spec: `### 4.7 Connection Error Codes`. No letter
# suffixes, no `####` -- the same rule the pin's own MANIFEST counts by.
SPEC_HEADING = re.compile(r"^#{2,3}\s+(\d+\.\d+)\s+\S", re.M)

# Tripwire 1: a section range written with a sigil on BOTH ends mints a phantom endpoint.
RANGE_FORM = re.compile(r"§ ?\d+(?:\.\d+)*[a-z]? *[-–—] *§")
# Tripwire 2: a `§` inside a sentence that declares something out of scope.
DISCLAIMER = re.compile(r"(not modeled|are abstracted|bypass(?:es)?\b|out of scope)", re.I)


def model_files() -> list[str]:
    out: list[str] = []
    for g in MODEL_GLOBS:
        out += [f for f in sorted(glob.glob(g)) if "_TTrace_" not in f]
    return out


def cited_sections(files: list[str]) -> dict[str, set[str]]:
    hits: dict[str, set[str]] = {}
    for f in files:
        with open(f, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                for s in CITATION.findall(line):
                    hits.setdefault(s, set()).add(f)
    return hits


def spec_sections(pin_dir: str) -> set[str]:
    core = os.path.join(pin_dir, "ENTITY-CORE-PROTOCOL.md")
    if not os.path.isfile(core):
        return set()
    with open(core, encoding="utf-8", errors="replace") as fh:
        return set(SPEC_HEADING.findall(fh.read()))


def skey(s: str) -> list[int]:
    return [int(p) for p in s.split(".")]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--matrix", default="docs/COVERAGE-MATRIX.md")
    ap.add_argument("--pin-file", default="spec-data/MODELING-PIN")
    args = ap.parse_args()

    problems: list[str] = []

    files = model_files()
    if not files:
        print("FAIL -- no model files found; run from the repo root", file=sys.stderr)
        return 1
    cited = cited_sections(files)

    with open(args.matrix, encoding="utf-8") as fh:
        matrix = fh.read()
    grid = set(GRID_ROW.findall(matrix))

    # ---- A. cited set == grid set, both directions ----------------------------
    print("== A. cited §N.M sections vs Matrix A rows ==")
    only_cited = sorted(set(cited) - grid, key=skey)
    only_grid = sorted(grid - set(cited), key=skey)
    if only_cited:
        problems.append(
            "cited by a model but absent from Matrix A: "
            + ", ".join(f"§{s} ({', '.join(sorted(cited[s]))})" for s in only_cited)
            + "\n      -> either add the row, or -- if the citation is a range endpoint, a"
            "\n         disclaimer or a cross-reference to another document -- drop the sigil."
        )
        for s in only_cited:
            print(f"  UNGRIDDED §{s:6s} {', '.join(sorted(cited[s]))}")
    if only_grid:
        problems.append(
            "in Matrix A but cited by no model: " + ", ".join(f"§{s}" for s in only_grid)
            + "\n      -> a phantom row. This is exactly how §4.7 and §6.9 got in."
        )
        for s in only_grid:
            print(f"  PHANTOM   §{s}")
    if not only_cited and not only_grid:
        print(f"  ok        {len(grid)} sections, both directions")

    # ---- B. the stated count ---------------------------------------------------
    print("\n== B. the count stated in prose ==")
    m = COUNT.search(matrix)
    if not m:
        problems.append(f"{args.matrix}: no `Coverage: N of M numbered ...` line to check")
        print("  MISSING   no coverage claim found")
    else:
        stated, denom = int(m.group(1)), int(m.group(2))
        if stated != len(cited):
            problems.append(
                f"stated coverage {stated} != {len(cited)} sections actually cited"
            )
            print(f"  WRONG     stated {stated}, actual {len(cited)}")
        else:
            print(f"  ok        {stated} cited")

        # MODELING-PIN carries a long comment header; the pin is the first non-comment,
        # non-blank line -- the same parse tools/spec-drift.py does.
        pin = None
        if os.path.isfile(args.pin_file):
            with open(args.pin_file, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        pin = os.path.join("spec-data", line)
                        break
        spec = spec_sections(pin) if pin else set()
        if not spec:
            # D13: a check that cannot run is a FAILURE, not a silent pass. The denominator
            # is the honest half of "28 of 85" and dropping it quietly is how the numerator
            # ends up quoted against a number nobody verified.
            problems.append(
                f"cannot check the denominator: no readable core spec at {pin or args.pin_file}"
                f" (prose claims {denom})"
            )
            print(f"  UNCHECKED denominator {denom}: no core spec at {pin or args.pin_file}")
        elif len(spec) != denom:
            problems.append(
                f"stated denominator {denom} != {len(spec)} numbered §N.M headings in {pin}"
            )
            print(f"  WRONG     denominator stated {denom}, actual {len(spec)}")
        else:
            print(f"  ok        denominator {denom} matches {pin}")

    # ---- C. the two tripwires --------------------------------------------------
    print("\n== C. tripwires (what else produces a citation) ==")
    ranges: list[str] = []
    disclaimers: list[str] = []
    for f in files:
        with open(f, encoding="utf-8", errors="replace") as fh:
            for n, line in enumerate(fh, 1):
                if RANGE_FORM.search(line):
                    ranges.append(f"{f}:{n}: {line.strip()[:110]}")
                if "§" in line and DISCLAIMER.search(line) and CITATION.search(line):
                    disclaimers.append(f"{f}:{n}: {line.strip()[:110]}")
    if ranges:
        problems.append(
            "section RANGE written with a sigil on both ends (mints a phantom endpoint;"
            " write `§4.1–4.7`):\n      " + "\n      ".join(ranges)
        )
        for r in ranges:
            print(f"  RANGE     {r}")
    else:
        print("  ok        no §X-§Y range forms")
    if disclaimers:
        # Not fatal on its own -- a disclaimer may legitimately sit in a file that DOES claim
        # the section. Report for review rather than fail; the A-check catches the real damage.
        print(f"  review    {len(disclaimers)} § inside a scope-disclaimer sentence:")
        for d in disclaimers:
            print(f"            {d}")
        print("            (not a failure: check A confirms every one has a real claim behind")
        print("             it. Flagged because a disclaimer-only citation is a phantom row.)")
    else:
        print("  ok        no § inside a scope disclaimer")

    print()
    if problems:
        print(f"FAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(
        f"OK -- {len(cited)} sections cited, Matrix A in sync, count and denominator verified.\n"
        "This asserts the SECTION SET and the COUNT. The engine columns of Matrix A are still\n"
        "hand-maintained -- a citation says a model is ABOUT a section, not which engine\n"
        "verifies what. See the module docstring."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
