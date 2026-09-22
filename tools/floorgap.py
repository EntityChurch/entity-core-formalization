#!/usr/bin/env python3
"""floorgap -- which of the core specification's obligations sit in sections that NO §9.1
conformance-floor row reaches.

WHY THIS EXISTS
---------------
`entity-system-conformance` `CQ-36` asks `entity-system-architecture` one question:

    0.8.2.22-.24 added at least six cross-peer-observable [MUST]s and §9 gained no row for
    any of them -- are they floor, or a declared non-floor?

They found those six by diffing three revisions, and they say so: *"building a worklist
outward from a diff is AP-2/D13 exactly. The diff selects where to start reading; it must
never select where to stop."* This tool answers the general form of their question over the
whole document, because it is the same measurement `tools/obligations.py` already makes with
a different divisor -- there, sections no MODEL cites; here, sections no FLOOR ROW cites.

It is also the reconciliation `docs/DISCIPLINE-CHARTER.md` D15 demands of the pair. Two seats now derive a
normative-surface count from one byte-identical snapshot and get different numbers: **365**
MUST/MUST NOT by our regex, **98** floor-row ids by their positional allocation. *"When two
tools derive a number from the same input, make them disagree out loud or make them share the
definition."* This tool does both -- it imports `obligations.py`'s obligation and heading
regexes rather than re-typing them, and it cross-checks its own §9 reading against their
`ECP-INDEX.md` and prints any disagreement as a finding rather than resolving it silently.

WHAT THIS ASSERTS
-----------------
  1. The snapshot it measures is byte-identical to the one `entity-system-conformance` pins,
     so the result is directly comparable rather than approximately so. A digest mismatch is
     a refusal, not a warning.
  2. Every numbered section carrying >=1 MUST/MUST NOT is classified FLOORED or UNFLOORED by
     whether any §9.1 row cites it.
  3. The extraction still works: named control sections that are certainly floored must come
     back FLOORED. If §1.6 -- whose floor row is the literal first bullet of §9.1, `Wire
     framing (§1.6)` -- reports UNFLOORED, the citation scan has broken and every other row
     is noise. **A tool whose failure mode is "report a very large gap" needs a control more
     than most**, because a broken run and a major finding look identical.
  4. Our §9 reading and their `ECP-INDEX.md` agree on which sections the floor cites.

WHAT THIS DOES *NOT* ASSERT, AND THE DIRECTION OF EVERY ERROR
--------------------------------------------------------------
  * NOT that an UNFLOORED obligation SHOULD be on the floor. Plenty should not be: a MUST
    inside a worked example, a MUST restating another section's rule, a MUST about a
    non-observable internal. Deciding is arch's, which is exactly what `CQ-36` asks of them.
    This says where to look.
  * NOT that a FLOORED obligation is TESTED. §3.1 -- which carries the `content_hash MUST
    match the map key` obligation that enabled the 0.8.2.23 capability forgery -- is FLOORED,
    by `ECP-R7`. It had a floor row, an id, and an authored requirement file, and the forgery
    shipped anyway. **A floor row is not a vector, and this tool cannot tell them apart.**
    That is the sharpest single thing it has to say and it limits its own result.
  * NOT a count of obligations "missing from the floor". The unit is the SECTION, one level
    coarser than the obligation, for the same reason `coverage`'s unit was too coarse: a floor
    row citing §5.2 makes all of §5.2's MUSTs FLOORED here, and §5.2 has dozens. **Every error
    this tool makes is therefore in the direction of UNDER-reporting the gap.** The number it
    prints is a floor on the floor gap.
  * NOT gated, deliberately. One input is a sibling tree, so it is the `driftclaim` class by
    construction (D15): nothing that runs on our diffs can see their index change. Run it when
    a packet cites it, not in `check`.

Usage:
    tools/floorgap.py                 # the measurement
    tools/floorgap.py --sections      # also list every UNFLOORED section, not just the top
    tools/floorgap.py --no-crosscheck # skip the sibling index comparison
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

# SHARE THE DEFINITION rather than re-typing it. If `obligations.py`'s notion of an obligation
# or a heading ever changes, this tool moves with it -- which is half of D15's prescription for
# two tools over one input. The other half is the crosscheck below.
from obligations import HEADING, OBLIGATION, sections  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / "spec-data" / "v0.8.2.24" / "ENTITY-CORE-PROTOCOL.md"

# `entity-system-conformance` pins the same revision. Both paths are read; neither is written.
SIBLING = ROOT.parent / "entity-system-conformance"
SIBLING_SNAPSHOT = SIBLING / "spec-data" / "entity-core-protocol" / "v0.8.2.24" / "ENTITY-CORE-PROTOCOL.md"
SIBLING_INDEX = SIBLING / "requirements" / "ECP-INDEX.md"

# A `§N` or `§N.M` reference inside a floor row. Deliberately WIDER than obligations.py's
# CITATION: a floor row writes `§4` for the whole connection chapter and `§5.5a` for a lettered
# sibling, and both bind. The negative lookbehind keeps `§CORE:6.2`-style cross-track forms out,
# though none occur in this document.
SECREF = re.compile(r"(?<![A-Za-z:])§(\d+(?:\.\d+)?[a-z]?)")

# Sections whose floor row is not in doubt -- the anti-vacuity control. §1.6 is the literal
# first bullet of §9.1; §3.1 is `ECP-R7`; §5.2 is cited by four separate rows. If the scan
# stops working these are the first things to go silently wrong.
CONTROL_FLOORED = ["1.6", "3.1", "5.2", "7.3"]


def die(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def block(text: str, start_pat: str, end_pat: str) -> str:
    """The text between two headings, exclusive of the second."""
    m = re.search(start_pat, text, re.M)
    if not m:
        die(f"heading {start_pat!r} not found in the snapshot -- the document reorganized")
    rest = text[m.start():]
    m2 = re.search(end_pat, rest[1:], re.M)
    return rest[: m2.start() + 1] if m2 else rest


def parent_of(sec: str) -> str:
    """`5.2a` -> `5.2`; `5.2` -> `5`. A floor row citing a parent reaches its children."""
    return sec.split(".")[0] if "." in sec else sec


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sections", action="store_true", help="list every UNFLOORED section")
    ap.add_argument("--no-crosscheck", action="store_true", help="skip the sibling index")
    args = ap.parse_args()

    if not SNAPSHOT.exists():
        die(f"{SNAPSHOT.relative_to(ROOT)} is missing")
    text = SNAPSHOT.read_text(encoding="utf-8")
    ours = digest(SNAPSHOT)

    print("floorgap -- obligations in sections NO §9.1 conformance-floor row cites\n")
    print(f"  snapshot      {SNAPSHOT.relative_to(ROOT)}")
    print(f"  sha256        {ours}")

    # (1) The comparability claim. Without this the result is about OUR copy of a revision and
    #     the packet quoting it is making a weaker statement than it sounds like.
    if SIBLING_SNAPSHOT.exists():
        theirs = digest(SIBLING_SNAPSHOT)
        if theirs != ours:
            die(
                "the `entity-system-conformance` snapshot of this revision is NOT byte-identical "
                f"to ours ({theirs[:16]}… vs {ours[:16]}…). Two seats are measuring two texts; "
                "reconcile the vendor before quoting any number below."
            )
        print("  comparable    BYTE-IDENTICAL to entity-system-conformance's pin of this revision")
    else:
        print("  comparable    UNKNOWN -- sibling snapshot not present; result is about OUR copy")

    floor = block(text, r"^### 9\.1 ", r"^### 9\.2 ")
    whole9 = block(text, r"^## 9\. ", r"^## 10\. ")

    floored = {m.group(1) for m in SECREF.finditer(floor)}
    floored_any9 = {m.group(1) for m in SECREF.finditer(whole9)}

    rows = len([ln for ln in floor.splitlines() if ln.startswith("- ")])
    print(f"  §9.1 rows     {rows}   citing {len(floored)} distinct section(s)")

    # (3) Anti-vacuity. Run BEFORE the measurement is printed, so a broken scan cannot be read
    #     as a large finding.
    broken = [s for s in CONTROL_FLOORED if s not in floored]
    if broken:
        die(
            f"CONTROL FAILED -- §{', §'.join(broken)} must be FLOORED and the scan says otherwise. "
            "The §9.1 citation extraction is broken; every UNFLOORED row below would be noise. "
            "This is the failure mode that looks like a major finding."
        )
    print(f"  control       OK -- §{', §'.join(CONTROL_FLOORED)} all FLOORED, as they must be\n")

    secs = {n: t for n, t in sections(text).items() if re.match(r"^\d+\.\d+", n)}
    bearing = {n: len(OBLIGATION.findall(t)) for n, t in secs.items()}
    bearing = {n: c for n, c in bearing.items() if c > 0}

    # EXCLUDE §9 ITSELF, and this was a first-draft defect rather than a design choice.
    # The first run reported §9.1 as the single largest UNFLOORED section, at 16 obligations,
    # with §9.0, §9.5 and §9.5a behind it -- 31 of the 83 it printed. Every one is the
    # conformance chapter stating the floor, so "no floor row cites it" is true, vacuous and
    # exactly backwards: a MUST inside §9.1 IS a floor row. Left recorded because the shape is
    # this repo's own D15 -- the input set of a measurement is a claim -- and because the
    # artifact sat at the TOP of the output, where a number is least likely to be questioned.
    selfref = sorted(n for n in bearing if parent_of(n) == "9")
    bearing = {n: c for n, c in bearing.items() if parent_of(n) != "9"}

    def is_floored(sec: str) -> bool:
        return sec in floored or parent_of(sec) in floored

    unfloored = {n: c for n, c in bearing.items() if not is_floored(n)}
    unfloored_9 = {
        n: c for n, c in bearing.items()
        if not (n in floored_any9 or parent_of(n) in floored_any9)
    }

    total = sum(bearing.values())
    gap = sum(unfloored.values())
    gap9 = sum(unfloored_9.values())

    print(
        f"  excluded      §{', §'.join(selfref)} -- the conformance chapter itself. A MUST "
        f"inside §9 IS a floor row"
    )
    print(f"  {len(bearing)} obligation-bearing sections, {total} MUST/MUST NOT obligations")
    print(f"  no §9.1 FLOOR row cites the section : {gap:4d}  ({len(unfloored)} sections)")
    print(f"  no §9 row AT ALL cites the section  : {gap9:4d}  ({len(unfloored_9)} sections)")
    print(f"  ratio                               : {gap / total:.0%} of the obligation surface\n")

    top = sorted(unfloored.items(), key=lambda kv: (-kv[1], kv[0]))
    shown = top if args.sections else top[:15]
    print(f"  {'UNFLOORED section':<20}{'obligations':>12}")
    for sec, count in shown:
        mark = "  <- also no §9 row anywhere" if sec in unfloored_9 else ""
        print(f"  §{sec:<19}{count:>12}{mark}")
    if not args.sections and len(top) > len(shown):
        print(f"  … {len(top) - len(shown)} more; `--sections` for all")
    print()

    # (4) Two derivations of one fact, made to disagree out loud.
    if not args.no_crosscheck and SIBLING_INDEX.exists():
        idx = SIBLING_INDEX.read_text(encoding="utf-8")
        theirs_cited: set[str] = set()
        for line in idx.splitlines():
            if not line.startswith("| `ECP-R") or "§9.1" not in line:
                continue
            theirs_cited |= {m.group(1) for m in SECREF.finditer(line)} - {"9.1"}
        only_ours = sorted(floored - theirs_cited - {"9.1"})
        only_theirs = sorted(theirs_cited - floored)
        print("  crosscheck vs entity-system-conformance requirements/ECP-INDEX.md")
        print(f"    their §9.1 rows cite {len(theirs_cited)} distinct section(s)")
        if not only_ours and not only_theirs:
            print("    AGREE -- both derivations name the same floor-cited section set")
        else:
            print(f"    ⚠ DISAGREE -- ours only: {only_ours or '-'}")
            print(f"                  theirs only: {only_theirs or '-'}")
            print("    Their index is DERIVED and says so; ours reads §9.1 directly. A")
            print("    disagreement is a finding about one of the two derivations, and it is")
            print("    reported rather than reconciled here on purpose -- silently taking one")
            print("    side is how a two-seat number becomes a one-seat number.")
        print()

    print(
        "This is the `CQ-36` question asked of the WHOLE document rather than of a revision\n"
        "diff. It does NOT say an UNFLOORED obligation belongs on the floor -- that ruling is\n"
        "`entity-system-architecture`'s, and it is what CQ-36 asks for. It does NOT say a\n"
        "FLOORED obligation is tested: §3.1 is FLOORED, by `ECP-R7`, and carries the MUST that\n"
        "enabled the 0.8.2.23 capability forgery. A floor row is not a vector.\n"
        "The unit is the SECTION, so a floor row citing §5.2 floors dozens of MUSTs at once --\n"
        "every error here UNDER-reports the gap. Not gated: one input is a sibling tree, which\n"
        "is the `driftclaim` class by construction."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
