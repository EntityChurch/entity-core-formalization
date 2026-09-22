#!/usr/bin/env python3
"""retractcheck — no live document may still state a claim this repo has withdrawn.

Why this exists, and why it is not "allow more than one anchor per file"
------------------------------------------------------------------------
On 2026-09-09 two documents still stated the pre-2026-09-09 engine position --
`docs/STATUS.md`'s proof-tracks table ("TLC on all three; Apalache on §4.1 and §4.2") and
`docs/COVERAGE-MATRIX.md` §3c ("all six quorum and identity modules are TLC-only") -- while
`make runcount` and `make enginecount` were green over both.

The obvious diagnosis was "each gate anchors one site per file". It is wrong, and checking
rather than assuming is the only reason this tool has the shape it has: `enginecount` already
collects EVERY window matching its anchor, and already validates every `N of M` pair whose
denominator is ours. What defeated it is that §3c's sentence contains no `N of M` and no
anchor phrase. **It is a paraphrase**, and a gate that derives a number cannot see a sentence
that states the same fact in words.

So this is the other half, and it is D14's own stated enforcement point finally becoming a
program rather than the word "grep":

    "A withdrawn claim has a shape, and the shape is its PHRASING, not its subject --
     grep the retracted words, because the row name appears in every site including the
     corrected ones and finds nothing."          (docs/DISCIPLINE-CHARTER.md, D14, earned 2026-08-30)

D13 -- what does this assert, and what else satisfies it?
---------------------------------------------------------
It asserts: for every declared retraction, its `pattern` occurs ZERO times across the live
document set, and at least once at its declared `witness`.

What else would satisfy a naive version, and is therefore rejected here:

  * **An empty registry.** A tripwire over nothing is green forever, which is the `scoped`
    gate's failure (D15 seventh shape: a gate whose input set went to zero). `MIN_ROWS`
    makes that a failure with a message saying so.
  * **A pattern that matches nothing anywhere** -- a typo, a phrasing mis-remembered, a
    regex that never compiled to what its author meant. It reports a clean pass forever.
    Hence `witness`: every row names a file that MUST still contain the retracted words,
    normally the dated `docs/status/` note or the `AGENTS.md` paragraph that records the
    retraction. That is a positive control per row, which is this repo's own rule -- run a
    term you know is present before believing a zero (D15, ninth shape) -- applied to each
    row rather than to the tool once.
  * **A registry that quietly narrows its own scan set.** The live set is derived from
    `git ls-files` (recursive, and it agrees with what is actually committed) rather than
    from a glob, for the reason `trackcheck` exists.

What it does NOT assert, stated rather than left to be assumed: that the retraction registry
is COMPLETE. Nothing can derive the set of claims we have withdrawn; that is a human reading
and every row is added by hand when a retraction happens. A withdrawn claim with no row here
is invisible to this gate exactly as it was before this gate existed.

Usage:
  tools/retractcheck.py
  tools/retractcheck.py --list
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = "docs/RETRACTIONS.toml"

# A registry that has gone empty asserts nothing. Any value > 0 works; this is set to the
# count at the time the tool was written so that DELETING rows to go green is also a failure.
MIN_ROWS = 9

# What counts as a LIVE document. Everything else in the tree is either dated history, a
# frozen pin, or generated.
#
#   docs/status/**   dated snapshots -- immutable once written, and the place a retracted
#                    claim SHOULD survive verbatim so the record of the error is not erased.
#
#                    THE KNOWN GAP HERE IS CLOSED, 2026-09-17, AND NOT BY THIS FILE.
#                    What this comment used to say: the prefix conflates two kinds of
#                    document -- a dated CHECKPOINT/HANDOFF really is immutable history,
#                    but a **ROUTING note is neither dated-immutable nor internal**, it is
#                    an ACTIVE OUTBOUND PACKET read by a counterpart repo. R11's withdrawn
#                    reachability bound sat in a routing note's own HEADER TABLE, as a live
#                    claim, and this scan was "structurally incapable of seeing it".
#                    It was fixed by MOVING THE PACKETS, not by editing the exclusion: the
#                    doc standard puts sent packets in `docs/outbox/`, which is not excluded,
#                    so 23 of them entered the live set in one commit. D15's own mechanism
#                    running forward for once -- a gate's input set is a claim, and this one
#                    WIDENED by an ordinary reorganisation elsewhere.
#                    The result is worth recording because the prediction was exactly right
#                    and the magnitude was not: this comment said "routing notes legitimately
#                    quote their own retracted phrasings in correction sections, so EVERY ONE
#                    would fire." Four of twenty-three fired, all four genuinely
#                    quoted-as-history, and **none asserts a retracted claim**. The
#                    distinction the comment asked for -- quoted-as-history vs asserted --
#                    did not need inventing: `allow` is per-(row, file) and already expresses
#                    it. What it needed was the reason written at each entry, which is how
#                    docs/RETRACTIONS.toml's four new allows are written, including the one
#                    (R8) that is an assertion rather than a quote and says so.
#                    A packet is immutable once delivered: editing one rewrites what a
#                    counterpart already read. So an allow, not a correction, is right here.
#   docs/archive/**  same, by the archive-do-not-delete rule.
#   spec-data/**     vendored, SHA-pinned, never edited.
LIVE_SUFFIXES = (".md", ".toml", ".tla", ".pml", ".spthy", ".pv", ".mk", "Makefile")
EXCLUDE_PREFIXES = ("docs/status/", "docs/archive/", "spec-data/", "METHODOLOGY.md",
                    "AGENTS-STANDARD.md")


def tracked_files() -> list[str]:
    """Every tracked file, from git. Not a glob: the same reason `trackcheck` walks git."""
    out = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True,
                         check=True).stdout
    return [p for p in out.splitlines() if p]


def live_files() -> list[str]:
    keep = []
    for p in tracked_files():
        if p == REGISTRY or p.startswith(EXCLUDE_PREFIXES):
            continue
        if p.endswith(LIVE_SUFFIXES) or os.path.basename(p) == "Makefile":
            keep.append(p)
    return sorted(keep)


def read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
        return fh.read()


def normalize(text: str) -> str:
    """Blockquote markers off, whitespace collapsed, comment sigils off.

    Same trap `driftclaim` hit and the same fix: a retracted sentence re-wrapped by an editor,
    or carried inside a `\\*`-prefixed TLA+ comment block, is the SAME claim. Matching raw
    text would let a line break launder it.
    """
    # Stripped REPEATEDLY, because comment sigils stack: a struck claim inside a TLA+ header
    # is written `\* !! …`, and removing only `\*` leaves the `!!` sitting between two words
    # of the quoted sentence once whitespace collapses. That is a launder-by-formatting the
    # first draft shipped -- R5's own witness failed on it, which is precisely what the
    # per-row positive control exists to catch.
    prev = None
    t = text
    while t != prev:
        prev = t
        t = re.sub(r"^[ \t]*(>|\\\*|\*/|/\*|\*|//|#+|!!)[ \t]?", "", t, flags=re.M)
    return re.sub(r"\s+", " ", t)


def load() -> list[dict]:
    with open(os.path.join(ROOT, REGISTRY), "rb") as fh:
        rows = tomllib.load(fh).get("retraction", [])
    required = ("id", "retired", "pattern", "claim", "why", "witness")
    for i, r in enumerate(rows):
        missing = [k for k in required if not r.get(k)]
        if missing:
            raise SystemExit(f"{REGISTRY}: row {i} ({r.get('id', '?')}) is missing "
                             f"{', '.join(missing)}")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--list", action="store_true", help="print the registry and exit")
    args = ap.parse_args()

    rows = load()
    if args.list:
        for r in rows:
            print(f"{r['id']:5} retired {r['retired']}  {r['claim']}")
            print(f"      why:     {r['why']}")
            print(f"      pattern: {r['pattern']}")
            print(f"      witness: {r['witness']}")
        return 0

    problems: list[str] = []
    if len(rows) < MIN_ROWS:
        problems.append(
            f"{REGISTRY} has {len(rows)} row(s), fewer than the {MIN_ROWS} it had when this "
            f"gate was written. A tripwire registry that shrinks is a tripwire that stops "
            f"asserting -- rows are retired by deleting the CLAIM from the tree, never by "
            f"deleting the row.")

    files = live_files()
    cache = {p: normalize(read(p)) for p in files}
    hits_total = 0

    for r in rows:
        try:
            pat = re.compile(r["pattern"])
        except re.error as exc:
            problems.append(f"{r['id']}: pattern does not compile ({exc})")
            continue

        # 1. the positive control: the retracted words must still exist SOMEWHERE.
        try:
            wtext = normalize(read(r["witness"]))
        except OSError as exc:
            problems.append(f"{r['id']}: witness {r['witness']} cannot be read ({exc})")
        else:
            if not pat.search(wtext):
                problems.append(
                    f"{r['id']}: pattern matches nothing at its witness {r['witness']}. "
                    f"A tripwire whose phrasing occurs nowhere cannot fire and will report "
                    f"a clean pass forever -- fix the pattern, or repoint the witness at a "
                    f"document that still quotes the withdrawn claim.")

        # 2. the assertion: zero occurrences anywhere live.
        # The witness is IMPLICITLY allowed. A retraction is recorded by quoting the words
        # that were withdrawn -- that is the whole point of "keep it struck, not deleted" --
        # so the one document guaranteed to contain the phrasing is the one proving the
        # pattern is real. Requiring it to be listed twice is a trap for whoever adds row 12.
        allow = set(r.get("allow", [])) | {r["witness"]}
        for p in files:
            if p in allow:
                continue
            for m in pat.finditer(cache[p]):
                hits_total += 1
                ctx = cache[p][max(0, m.start() - 70):m.end() + 70].strip()
                problems.append(
                    f"{r['id']}: RETRACTED CLAIM still live in {p}\n"
                    f"        withdrawn {r['retired']} — {r['why']}\n"
                    f"        …{ctx}…")

    print("== retracted claims, checked against every live document ==")
    print(f"  registry     {len(rows)} row(s)  ({REGISTRY})")
    print(f"  live set     {len(files)} tracked file(s)")
    print(f"  occurrences  {hits_total}")

    if problems:
        print(f"\nFAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        print("\nA withdrawn claim has a shape, and the shape is its PHRASING, not its")
        print("subject (docs/DISCIPLINE-CHARTER.md D14). Correct the sentence — do NOT add an `allow` entry")
        print("unless the site is a genuinely dated historical statement, and say so there.")
        return 1

    print(f"\nOK -- no live document states any of {len(rows)} withdrawn claims, and every")
    print("pattern was positively controlled against a witness that still quotes it.")
    print("This does NOT assert the registry is COMPLETE: nothing can derive the set of")
    print("claims we have withdrawn. A retraction with no row here is invisible, exactly as")
    print("it was before this gate existed. Add the row in the session that retracts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
