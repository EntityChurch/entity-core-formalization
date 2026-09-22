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

# A citation of a numbered spec subsection. `(?![\d.])` stops `§4.10` matching as `§4.1`.
CITATION = re.compile(r"§\s*(\d+\.\d+)(?![\d.])")
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
PREFIXED = re.compile(r"§([A-Z][A-Z0-9]{1,11}):(\d+\.\d+)(?![\d.])")
# A row of Matrix A: `| 4.7 | topic | ... |`, with optional ** bolding on the section cell.
GRID_ROW = re.compile(r"^\|\s*\*{0,2}(\d+\.\d+)\*{0,2}\s*\|", re.M)
# "**Coverage: 28 of 85 numbered `§N.M` sections (33%).**"
COUNT = re.compile(r"Coverage:\s*\*{0,2}(\d+)\*{0,2}\s+of\s+\*{0,2}(\d+)\*{0,2}\s+numbered")
# A numbered heading in a pinned spec: `### 4.7 Connection Error Codes`. No letter
# suffixes, no `####` -- the same rule the pin's own MANIFEST counts by.
SPEC_HEADING = re.compile(r"^#{2,3}\s+(\d+\.\d+)\s+\S", re.M)

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
    return [int(p) for p in s.split(".")]


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

        # ---- gather citations, splitting cross-track references out ---------------
        cited: dict[str, set[str]] = {}
        crossrefs: dict[str, list[str]] = {}
        bad_prefix: list[str] = []
        for f in files:
            rel = os.path.relpath(f, root)
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
                    cited.setdefault(s, set()).add(rel)

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

            pin = pin_dir(root, t.get("pin_file", ""))
            primary = os.path.join(root, pin, t["primary_spec"]) if pin else None
            spec = set(SPEC_HEADING.findall(read(primary))) if primary and \
                os.path.isfile(primary) else set()
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

    scoped = [n for n, t in sorted(tracks.items())
              if t.get("kind") == "protocol" and t.get("status") == "scoped"]
    if scoped:
        print(f"== not checked here: {len(scoped)} scoped track(s) — {', '.join(scoped)} ==")
        print("  Declared in TRACKS.toml with a landed spec, no vendored snapshot and no model,")
        print("  so they publish no coverage claim. `make trackcheck` is what keeps that true:")
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
