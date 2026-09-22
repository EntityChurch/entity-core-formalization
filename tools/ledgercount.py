#!/usr/bin/env python3
"""ledgercount — derive the assumption ledger's row and verdict counts, and check the prose.

Why this exists (D15)
---------------------
`docs/LEAN-SEAM.md` is the assumption ledger. Its shape -- how many rows, in which class,
with which verdicts -- is quoted in prose across this repo, and it has been quoted WRONG in
a published file FOUR times:

  1. "eleven CLOSED rows of the ledger rested on a build nobody ran", in five files. Class L
     was eleven rows: nine CLOSED, two CLOSED-MODULO-H. The conclusion survived; the figure
     was recalled rather than counted.
  2. The Class-L verdicts in docs/status/AUDIT-2026-08-30-LEAN-TIER.md, same session.
  3. "21 of 23 rows are CLOSED and the two open ones (L1, L7) are both §5.5a granter-framing"
     -- every number wrong AND the attribution wrong: L1/L7 were CLOSED-MODULO-H, a different
     verdict, and the genuinely OPEN rows were T4 and O4.
  4. "14 CLOSED ... 2 OPEN (T4, O4)" in docs/STATUS.md -- written two hours before O4 closed
     in the same session, correct when written, stale on the next commit.

Every one was caught by a human re-deriving by hand, which is the mechanism that failed the
other four times. `make leanseam` and `make leanproof` print THEOREM counts and say nothing
about rows or verdicts, so nothing tied this. This is that gate, built on the `runcount`
template for exactly the same reason.

What this asserts
-----------------
  1. DERIVATION  every ledger row and its verdict, parsed from docs/LEAN-SEAM.md itself --
                 Class L from its `### L<n>` sections and their `**Verdict: X**` lines,
                 Class T and O from their tables' last column.
  2. STRUCTURE   the row ids are contiguous from 1 per class with no gaps or duplicates, so
                 a row silently deleted or renumbered is a failure rather than a smaller
                 count that still looks tidy.
  3. PROSE       every declared site states the derived totals.

What this does NOT assert
-------------------------
That any verdict is CORRECT. A row saying CLOSED that should say OPEN is exactly as green
here as an honest one -- the ledger is a human reading of two texts and `make leanseam` says
so in its own output. This counts what the file claims; it does not audit the claims. That
distinction is the same one `coverage` draws about the engine columns, and it is the reason
neither tool is allowed to read as "the ledger is verified".

Usage:  tools/ledgercount.py [--verbose]
Exit status: 0 iff the derivation, the structure check and every declared site agree.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = "docs/LEAN-SEAM.md"

# Class L rows are prose sections; Class T and O are tables. Parsed differently on purpose --
# guessing one shape for both is how a parser quietly drops a class.
L_HEADING = re.compile(r"^### (L\d+)\s*[·.]", re.M)
L_VERDICT = re.compile(r"^-\s+\*\*Verdict:\s*([A-Z][A-Za-z0-9 /—–-]*?)\.?\*\*", re.M)
TO_ROW = re.compile(r"^\|\s*([TO]\d+)\s*\|.*\|\s*\*\*(.+?)\*\*[^|]*\|\s*$", re.M)

# ── WHERE THE LEDGER'S SHAPE IS CLAIMED IN PROSE ────────────────────────────────────────
# Same anchored-pattern discipline as runcount: the CURRENT claim is declared by anchor, and
# history is out of scope by construction. This file is dense with true statements about
# past counts ("Class L was eleven rows on 2026-08-30", left there deliberately), and a gate
# that made you delete accurate history to go green would be worse than no gate.
# ROW COUNTS ARE NOT THE NUMBER THAT KEEPS GOING WRONG -- the VERDICT BREAKDOWN is. All four
# published errors were verdicts ("eleven CLOSED", "21 of 23 ... the two open ones",
# "14 CLOSED ... 2 OPEN"), and the row total was right in three of them. The first draft of
# this gate anchored `rows` and `class_L` only, which would have gone green on every one of
# those four. Teeth-tested by flipping a verdict in the ledger and watching it pass -- so
# `closed` and `open` are anchored too, and `open` is anchored NUMERICALLY (a prose "no row
# is OPEN" is unmatchable and a site that stops saying it must fail).
PROSE_SITES = [
    (LEDGER, "the Class-T closing note", "rows",
     r"the ledger is \*\*(\d+) rows\*\*"),
    (LEDGER, "the Class-T closing note", "closed",
     r"\*\*(\d+) CLOSED\*\*"),
    (LEDGER, "the Class-T closing note", "open",
     r"\*\*(\d+) OPEN\*\*"),
    ("docs/STATUS.md", "the ledger-shape note in §Next", "rows",
     r"the ledger is \*\*(\d+) rows\*\*"),
    ("docs/STATUS.md", "the ledger-shape note in §Next", "closed",
     r"of which \*\*(\d+) CLOSED"),
    ("docs/STATUS.md", "the ledger-shape note in §Next", "open",
     r"\*\*(\d+) OPEN\*\*"),
    ("AGENTS.md", "the LEAN-SEAM paragraph", "rows",
     r"it is (\d+) rows / \d+ Class L"),
    # D14, same afternoon: the AGENTS.md instance was not the only site whose sentence
    # states more facets than the gate reads. Both of these spell out the CLASS BREAKDOWN
    # ("13 Class L, 5 Class T, 22 Class O") beside a gated row total, and none of the three
    # was declared. They were correct when checked -- which is the point: an unread facet is
    # not a wrong number, it is a number nothing will notice going wrong.
    (LEDGER, "the Class-T closing note", "class_L",
     r"the ledger is \*\*\d+ rows\*\* \((\d+) Class L"),
    (LEDGER, "the Class-T closing note", "class_T",
     r"the ledger is \*\*\d+ rows\*\* \(\d+ Class L, (\d+) Class T"),
    (LEDGER, "the Class-T closing note", "class_O",
     r"the ledger is \*\*\d+ rows\*\* \(\d+ Class L, \d+ Class T, (\d+) Class O"),
    ("docs/STATUS.md", "the ledger-shape note in §Next", "class_L",
     r"\*\*\d+ rows\*\* — (\d+) Class L"),
    # `\d+ rows`, NOT the literal `40` this pattern carried until 2026-09-14. Anchoring a
    # matcher on the CURRENT value of the number it watches means the pattern stops matching
    # exactly when that number moves, and the tool then reports "the site went silent" instead
    # of "the site is stale" -- a true message pointing at the wrong defect. Found when O23
    # took the ledger to 41. The sibling LEDGER patterns above were already written this way.
    ("docs/STATUS.md", "the ledger-shape note in §Next", "class_T",
     r"\*\*\d+ rows\*\* — \d+ Class L, (\d+) Class T"),
    ("docs/STATUS.md", "the ledger-shape note in §Next", "class_O",
     r"\*\*\d+ rows\*\* — \d+ Class L, \d+ Class T, (\d+) Class O"),
    ("AGENTS.md", "the LEAN-SEAM paragraph", "class_L",
     r"it is \d+ rows / (\d+) Class L"),
    # Added 2026-09-09, and the figure it now checks was WRONG when the row was added.
    # This site's sentence states three facets -- rows, Class L, and OPEN -- and only the
    # first two were declared, so `14 OPEN` sat beside a gated `40 rows` and a gated
    # `13 Class L` while the ledger held 13 OPEN. The gate was green over it because a
    # gate that reads SOME facets of a claim asserts nothing about the rest, and the
    # unchecked facet is the one that moves. Same shape as spec-drift anchoring the
    # section COUNT while the live VERSION beside it went stale, found the same afternoon.
    #
    # The paragraph this appears in is the one that says "Do not trust a count of the
    # ledger's rows that you did not derive ... a recalled figure has been published wrong
    # here FOUR times." It was the fifth.
    ("AGENTS.md", "the LEAN-SEAM paragraph", "open",
     r"it is \d+ rows / \d+ Class L, \*\*(\d+) OPEN\*\*"),
    # Added 2026-09-09, and it had been stale for a day: this table said "14 of 38" when the
    # ledger was 13 of 40. Its own header says "do not quote these from here" -- which is a
    # DISCLAIMER, and a disclaimer is not a gate. It reads as though the risk has been handled,
    # which is why the stale figure survived a session that re-derived every other number.
    ("docs/status/FINDINGS-INDEX.md", "the open-work table", "open",
     r"Assumption-ledger rows OPEN \|[^|]*\| \*\*(\d+) of \d+\*\*"),
    ("docs/status/FINDINGS-INDEX.md", "the open-work table", "rows",
     r"Assumption-ledger rows OPEN \|[^|]*\| \*\*\d+ of (\d+)\*\*"),
]


class Fail(Exception):
    pass


def read(rel: str) -> str:
    with open(os.path.join(HERE, rel), encoding="utf-8") as fh:
        return fh.read()


def normalize(text: str) -> str:
    """Blockquote markers off, whitespace collapsed, so an anchor survives re-wrapping.

    `make driftclaim` learned this the hard way an hour earlier: its first draft matched raw
    text and failed six of nine sites purely on where markdown lines had been broken. A gate
    whose green depends on an author's line breaks asserts the line breaks, not the claim.
    Applied here from the start rather than after the same failure -- D14, on a mechanism
    rather than on a defect.
    """
    return re.sub(r"\s+", " ", re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.M))


def derive(verbose: bool) -> dict:
    text = read(LEDGER)

    l_ids = L_HEADING.findall(text)
    l_verdicts = [v.strip() for v in L_VERDICT.findall(text)]
    if len(l_ids) != len(l_verdicts):
        raise Fail(
            f"{LEDGER}: {len(l_ids)} Class-L sections but {len(l_verdicts)} "
            f"'**Verdict: ...**' lines. Every L row must carry exactly one, or the count "
            f"below is silently wrong -- which is the failure this tool exists for."
        )

    rows = list(zip(l_ids, l_verdicts)) + [(i, v.strip()) for i, v in TO_ROW.findall(text)]

    # STRUCTURE: contiguous ids per class. A deleted row otherwise just makes a smaller
    # number that still looks self-consistent.
    for cls in ("L", "T", "O"):
        nums = sorted(int(i[1:]) for i, _ in rows if i[0] == cls)
        if nums != list(range(1, len(nums) + 1)):
            raise Fail(f"{LEDGER}: Class {cls} row ids are {nums} -- expected 1..{len(nums)} "
                       f"with no gaps or duplicates")

    verdicts: dict[str, int] = {}
    for _, v in rows:
        verdicts[v] = verdicts.get(v, 0) + 1

    out = {
        "rows": len(rows),
        "class_L": sum(1 for i, _ in rows if i[0] == "L"),
        "class_T": sum(1 for i, _ in rows if i[0] == "T"),
        "class_O": sum(1 for i, _ in rows if i[0] == "O"),
        "verdicts": verdicts,
        # "CLOSED" exactly -- NOT CLOSED-MODULO-H and NOT CLOSED - ASSUMPTION FALSE. Those
        # are distinct verdicts and collapsing them is precisely the error published as
        # "21 of 23 rows are CLOSED", where two CLOSED-MODULO-H rows were counted as CLOSED
        # and then described as OPEN in the same sentence.
        "closed": verdicts.get("CLOSED", 0),
        "open": sum(n for v, n in verdicts.items() if v.upper() == "OPEN"),
    }
    if verbose:
        print(f"  rows                       {out['rows']:4}")
        print(f"  Class L / T / O            {out['class_L']:4} / {out['class_T']} / {out['class_O']}")
        for v, n in sorted(verdicts.items()):
            print(f"    {v:32} {n}")
    return out


def check_prose(derived: dict) -> list[str]:
    problems = []
    for site, what, key, pattern in PROSE_SITES:
        want = derived[key]
        found = [int(m.group(1)) for m in re.finditer(pattern, normalize(read(site)))]
        if not found:
            problems.append(
                f"{site}: {what} no longer states the {key} count (pattern did not match). "
                f"A site that goes silent is how the number goes stale unnoticed -- restore "
                f"the claim or drop the row from PROSE_SITES deliberately."
            )
        elif set(found) != {want}:
            problems.append(f"{site}: {what} states {key}={sorted(set(found))}, derived {want}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verbose", action="store_true")
    ap.parse_args()
    try:
        print("== assumption ledger, derived from docs/LEAN-SEAM.md (not from prose) ==")
        derived = derive(True)
        problems = check_prose(derived)
    except (Fail, OSError) as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1

    print()
    if problems:
        print(f"FAIL -- {len(problems)} disagreement(s) between the ledger and the prose:")
        for p in problems:
            print(f"  - {p}")
        print("\nThe ledger is the source of truth. Fix the prose, not this script -- and do")
        print("not recall the number, which is how it has gone wrong four times.")
        return 1
    print(f"OK -- {derived['rows']} rows ({derived['class_L']} L / {derived['class_T']} T / "
          f"{derived['class_O']} O), {derived['open']} OPEN; "
          f"{len(PROSE_SITES)} prose claims agree.")
    print("This asserts the COUNTS and the row structure. It does NOT assert that any")
    print("verdict is correct -- the ledger is a human reading of two texts, and a row that")
    print("says CLOSED when it should say OPEN passes here exactly as an honest one does.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
