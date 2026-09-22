#!/usr/bin/env python3
"""runcount — derive the matrix run total from the gate tables, and check the prose.

Why this exists (D15)
---------------------
`make matrix` runs N model-checker invocations. N appears in prose in several files, and
until now it was **hand-derived**: someone counted the gate tables, wrote the number down,
and every later change to a table meant remembering to edit every site. That went wrong
three times in one week -- 238 -> 242 -> 258 across two commits, four sites hand-edited each
time, and two sites missed entirely (`docs/PROPERTIES.md`'s grader inventory sat at 238 for
two matrix growths; `CANONICAL-DOCS.toml`'s capstone blurb sat at 203).

D15 says a derived number is a claim, and a claim needs a gate. This is that gate.

What this asserts
-----------------
  1. DERIVATION  the per-target run counts computed from the gate tables in tla/, spin/ and
                 tamarin/Makefile, and their total.
  2. PROSE       every declared site (below) states that same total.
  3. SLICES      docs/STATUS.md's per-slice table sums to the total AND each row matches the
                 derived per-target figure.

What this does NOT assert
-------------------------
That the runs pass -- that is `make matrix`. That the counted rows are the RIGHT rows: this
counts the declaration tables, so a run that exists but is in no table is invisible here
exactly as it is invisible to the matrix (that failure mode is real -- `BindingReplayBug`
was on disk and in no gate list for a release -- and it is the reason the tables are the
source of truth rather than the file system). And it says nothing about the Lean seam tier,
which is deliberately NOT in the matrix total (docs/LEAN-SEAM.md section 5).

Usage:  tools/runcount.py [--verbose]
Exit status: 0 iff the derivation and every declared site agree.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── HOW EACH TARGET'S RUN COUNT IS DERIVED ──────────────────────────────────────────────
# (label, makefile, variable, how to count, runs per row, note)
#
# "runs per row" is where a table row is not one invocation: an Apalache row is checked
# twice (base case and inductive step), and a Spin green module is run twice (safety, then
# LTL). Those factors are the only hand-entered numbers here and each is stated on the
# target that implements it.
DERIVATION = [
    ("tlc-green (modules)",   "tla/Makefile",     "TLC_GREEN",         "words", 1),
    ("tlc-green (N-peer)",    "tla/Makefile",     "TLC_GREEN_PAIRS",   "rows",  1),
    ("tlc-green (StoreLive)", None,                None,               "const", 1),
    ("tlc-neg",               "tla/Makefile",     "TLC_NEG",           "rows",  1),
    ("tlc-witness",           "tla/Makefile",     "TLC_WITNESS",       "rows",  1),
    ("apalache-green",        "tla/Makefile",     "APALACHE_GREEN",    "rows",  2),
    ("apalache-neg",          "tla/Makefile",     "APALACHE_NEG",      "rows",  1),
    ("spin green (safety+LTL)", "spin/Makefile",  "SPIN_GREEN",        "words", 2),
    ("spin green (safety)",   "spin/Makefile",    "SPIN_GREEN_SAFETY", "words", 1),
    ("spin green (N=3)",      "spin/Makefile",    "SPIN_GREEN_N3",     "rows",  2),
    ("spin neg",              "spin/Makefile",    "SPIN_NEG",          "rows",  1),
    ("proverif-green",        "tamarin/Makefile", "PV_GREEN",          "words", 1),
    ("proverif-neg",          "tamarin/Makefile", "PV_NEG",            "words", 1),
    ("tamarin-green",         "tamarin/Makefile", "TM_GREEN",          "words", 1),
    ("tamarin-neg",           "tamarin/Makefile", "TM_NEG",            "words", 1),
]

# `tlc-green` runs one row that is in no variable: Store's liveness slice, invoked by name
# in the recipe because it is the only module whose safety and liveness bounds differ (TLC's
# liveness graph exhausts the 2 GB cap at Store's safety bound). Declared here rather than
# silently added, and asserted to still exist in the recipe below.
STORELIVE_MARKER = "StoreLive.cfg"

# ── WHERE THE TOTAL IS CLAIMED IN PROSE ─────────────────────────────────────────────────
# Each row is (file, description, pattern with exactly one capture group). The captured
# number must equal the derived total, and a pattern that matches NOTHING is a failure: a
# site that stops making the claim is exactly how a number goes stale unnoticed.
#
# WHY ANCHORED PATTERNS AND NOT "any 3-digit number near the word runs". Asked of the FIRST
# draft of this gate -- what does it assert, and what else satisfies it? -- and run: it
# flagged three files, all three FALSELY. `AGENTS.md` says "62 of 203 runs", `PROPERTIES.md`
# says "204 runs at the time", `STATUS.md` says "matrix 238 -> 242". Every one is a true
# statement about the past, and a gate that cannot tell a live claim from a historical one
# would have had us delete accurate history to go green -- the worst possible failure for a
# repo whose whole practice is keeping superseded claims visible. So the CURRENT claim is
# declared, by anchor, and history is out of scope by construction rather than by luck.
#
# The cost is stated too: this asserts the anchored sites only. A new prose site that quotes
# a total and is not listed here is not checked, and nothing detects that -- the same class
# of hole as `make coverage` not asserting the engine columns.
PROSE_SITES = [
    ("README.md", "the `make matrix` line in the build block",
     r"negative controls \+ non-vacuity witnesses \((\d+) runs\)"),
    ("README.md", "the docs/ layout tree",
     r"capstone: what was proved \+ the (\d+)-run matrix"),
    ("AGENTS.md", "the Status paragraph",
     r"\*\*(\d+)-run\*\* `make matrix` is the gate"),
    ("docs/STATUS.md", "the headline claim",
     r"\*\*The full matrix is (\d+) runs\*\*"),
    ("docs/STATUS.md", "the per-slice table footer",
     r"\| \*\*total\*\* \| \*\*(\d+)\*\* \|"),
    ("docs/PROPERTIES.md", "the grader inventory header",
     r"targets decide the (\d+) runs"),
    ("docs/FINAL-ASSURANCE-SUMMARY.md", "the control-matrix headline",
     r"\*\*(\d+) runs in one `make matrix`"),
    ("CANONICAL-DOCS.toml", "the capstone blurb",
     r"the (\d+)-run re-verification matrix"),
]


class Fail(Exception):
    pass


def read(rel: str) -> str:
    with open(os.path.join(HERE, rel), encoding="utf-8") as fh:
        return fh.read()


def block(rel: str, var: str) -> str:
    """The full (line-continued) right-hand side of a make variable."""
    out, grab = [], False
    for line in read(rel).splitlines():
        if not grab and re.match(rf"^{var} *:?=", line):
            grab, line = True, re.sub(rf"^{var} *:?=", "", line)
            out.append(line)
        elif grab:
            out.append(line)
        if grab and not line.rstrip().endswith("\\"):
            break
    if not out:
        raise Fail(f"{rel}: no variable {var} -- the derivation names a table that is gone")
    return "\n".join(out)


def count(rel: str, var: str, how: str) -> int:
    b = block(rel, var)
    if how == "rows":                       # quoted "…" rows
        return len(re.findall(r'"[^"]+"', b))
    return len([w for w in b.replace("\\", " ").split() if not w.startswith("#")])


def derive(verbose: bool) -> tuple[int, dict[str, int]]:
    per: dict[str, int] = {}
    for label, rel, var, how, factor in DERIVATION:
        if how == "const":
            n = factor
            if STORELIVE_MARKER not in read("tla/Makefile"):
                raise Fail(
                    f"{label}: this run is declared as a constant because it is invoked by "
                    f"name in the recipe, and {STORELIVE_MARKER!r} is no longer in "
                    f"tla/Makefile. Either the run is gone (drop the row) or it moved."
                )
        else:
            n = count(rel, var, how) * factor
        per[label] = n
        if verbose:
            src = f"{rel}:{var}" if var else "tla/Makefile recipe"
            print(f"  {label:26} {n:4}   ({src}{'' if factor == 1 else f' x{factor}'})")
    return sum(per.values()), per


def check_prose(total: int) -> list[str]:
    problems = []
    for site, what, pattern in PROSE_SITES:
        found = [int(m.group(1)) for m in re.finditer(pattern, read(site))]
        if not found:
            problems.append(
                f"{site}: {what} no longer states a run total (pattern did not match). "
                f"A site that goes silent is how the number goes stale unnoticed -- either "
                f"restore the claim or drop the row from PROSE_SITES deliberately."
            )
        elif set(found) != {total}:
            problems.append(f"{site}: {what} states {sorted(set(found))}, derived {total}")
    return problems


def check_status_slices(total: int, per: dict[str, int]) -> list[str]:
    """docs/STATUS.md's per-slice table is the reader-facing breakdown; check it sums AND
    that each row matches the derivation rather than only agreeing with itself."""
    rows = re.findall(r"^\| (?!\*\*total)([^|]+?) *\| *(\d+) *\|$", read("docs/STATUS.md"), re.M)
    if not rows:
        return ["docs/STATUS.md: the per-slice run table is gone"]
    got = {label.strip(): int(n) for label, n in rows}
    problems = []
    if sum(got.values()) != total:
        problems.append(f"docs/STATUS.md slice table sums to {sum(got.values())}, derived {total}")
    expect = {
        "TLC green": per["tlc-green (modules)"] + per["tlc-green (N-peer)"]
        + per["tlc-green (StoreLive)"],
        "TLC negative controls": per["tlc-neg"],
        "TLC non-vacuity witnesses": per["tlc-witness"],
        "Apalache inductive": per["apalache-green"],
        "Apalache negative controls": per["apalache-neg"],
        "Spin green": per["spin green (safety+LTL)"] + per["spin green (safety)"]
        + per["spin green (N=3)"],
        "Spin negative controls": per["spin neg"],
        "ProVerif": per["proverif-green"] + per["proverif-neg"],
        "Tamarin": per["tamarin-green"] + per["tamarin-neg"],
    }
    for prefix, want in expect.items():
        match = [n for label, n in got.items() if label.startswith(prefix)]
        if not match:
            problems.append(f"docs/STATUS.md: no slice row starting {prefix!r}")
        elif match[0] != want:
            problems.append(f"docs/STATUS.md slice {prefix!r}: says {match[0]}, derived {want}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verbose", action="store_true", help="show the per-target derivation")
    args = ap.parse_args()
    try:
        print("== run total, derived from the gate tables (not from prose) ==")
        total, per = derive(args.verbose or True)
        print(f"  {'TOTAL':26} {total:4}")
        problems = check_prose(total) + check_status_slices(total, per)
    except Fail as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1

    print()
    if problems:
        print(f"FAIL -- {len(problems)} disagreement(s) between the tables and the prose:")
        for p in problems:
            print(f"  - {p}")
        print("\nThe tables are the source of truth. Fix the prose, not this script -- unless")
        print("a gate table genuinely changed, in which case the new number is the answer and")
        print("every site above states it.")
        return 1
    print(f"OK -- {total} runs derived from the gate tables; {len(PROSE_SITES)} prose sites")
    print("and the STATUS slice table all state it.")
    print("This asserts the COUNT, not that the runs pass (that is `make matrix`) and not")
    print("that every run is in a table (a run in no table is invisible to both).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
