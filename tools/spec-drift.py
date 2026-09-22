#!/usr/bin/env python3
"""spec-drift — measure the pinned spec snapshot against a live spec tree.

Why this exists
---------------
Every result in this repo is a statement about `spec-data/<pin>/`, not about the
protocol as it stands today. That distinction is only honest if someone can *check*
whether the two have diverged, so this makes the check a command instead of a claim in
a document.

It answers three questions, in increasing order of usefulness:

  1. Do the pinned files still match the live spec, byte for byte?
  2. Which spec SECTIONS moved?
  3. Which sections THE MODELS ACTUALLY CITE moved, and which models depend on them?

(3) is the one that matters. A section list taken from prose is a list someone chose;
the `§`-citations in the models are the dependency set the models themselves declare,
which is why every model in this repo is required to carry them.

Method — deliberately dumb, so it is hard to be wrong
-----------------------------------------------------
A section is "unchanged" iff its pinned text, from its heading up to the next heading
of any level, occurs VERBATIM in the live file. No diff heuristics, no fuzzy matching,
no section-splitting logic applied to the live side. A section that moved position but
kept its bytes still reads as unchanged, which is correct: the models cite content.

Exit status: 0 if nothing the models cite has moved, 1 otherwise. Suitable as a gate.

Usage:
  tools/spec-drift.py --live ../entity-core-protocol/specs
  tools/spec-drift.py --live /tmp/pub-specs --format md
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from collections import defaultdict

HEADING = re.compile(r"^#{1,6}\s+\S", re.M)
NUMBERED = re.compile(r"^#{1,6}\s+(\d+(?:\.\d+)*[a-z]?)\s+.*$", re.M)
CITATION = re.compile(r"§\s*(\d+(?:\.\d+)*[a-z]?)")

MODEL_GLOBS = ("tla/*.tla", "tamarin/*.pv", "tamarin/*.spthy", "spin/*.pml")
TRACKS = {
    "TLA+/Apalache": ("tla/*.tla",),
    "Spin": ("spin/*.pml",),
    "Tamarin/ProVerif": ("tamarin/*.pv", "tamarin/*.spthy"),
}


def read(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def section_block(text: str, sec: str) -> str | None:
    """Pinned text of `sec`: its heading through to the next heading of any level."""
    m = re.search(rf"^(#{{1,6}})\s+{re.escape(sec)}\s+.*$", text, re.M)
    if not m:
        return None
    rest = [h.start() for h in HEADING.finditer(text) if h.start() > m.start()]
    return text[m.start(): rest[0] if rest else len(text)]


def spec_version(text: str) -> str:
    m = re.search(r"^\*\*Version\*\*:\s*(\S+)", text, re.M)
    return m.group(1) if m else "?"


def model_citations(root: str) -> dict[str, set[str]]:
    cites: dict[str, set[str]] = defaultdict(set)
    for pattern in MODEL_GLOBS:
        for path in sorted(glob.glob(os.path.join(root, pattern))):
            for m in CITATION.finditer(read(path)):
                cites[m.group(1)].add(os.path.relpath(path, root))
    return cites


def secsort(sec: str):
    return [int(p) for p in re.findall(r"\d+", sec)] + [sec]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pin", default=None, help="pinned snapshot dir (default: newest spec-data/*/)")
    ap.add_argument("--live", required=True, help="live spec dir, e.g. a sibling's specs/")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--format", choices=("text", "md"), default="text")
    args = ap.parse_args()

    pin_dir = args.pin
    pin_note = ""
    if pin_dir is None:
        # spec-data/MODELING-PIN names the snapshot the models TRANSCRIBE, which is not
        # necessarily the newest one vendored. Measuring drift from the newest vendored
        # snapshot would report zero the moment someone copies files in, which is exactly
        # the false all-clear this tool exists to prevent.
        marker = os.path.join(args.root, "spec-data", "MODELING-PIN")
        named = None
        if os.path.exists(marker):
            for line in read(marker).splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    named = line
                    break
        if named:
            pin_dir = os.path.join(args.root, "spec-data", named)
            if not os.path.isdir(pin_dir):
                print(f"MODELING-PIN names {named!r} but spec-data/{named}/ does not exist",
                      file=sys.stderr)
                return 2
            vendored = sorted(
                os.path.basename(p.rstrip("/"))
                for p in glob.glob(os.path.join(args.root, "spec-data", "*/"))
            )
            newer = [v for v in vendored if v > named]
            if newer:
                pin_note = (f"NOTE: newer snapshot(s) vendored but not yet modeled: "
                            f"{', '.join(newer)}")
        else:
            cands = sorted(glob.glob(os.path.join(args.root, "spec-data", "*/")))
            if not cands:
                print("no spec-data/ snapshot found", file=sys.stderr)
                return 2
            pin_dir = cands[-1]

    files = sorted(
        f for f in os.listdir(pin_dir)
        if f.endswith(".md") and f not in ("MANIFEST.md", "README.md")
    )
    if not files:
        print(f"no spec files in {pin_dir}", file=sys.stderr)
        return 2

    out = []
    emit = out.append
    bullet = "- " if args.format == "md" else "  "

    emit(f"# spec-drift\n" if args.format == "md" else "spec-drift")
    emit(f"{bullet}modeling pin: {os.path.relpath(pin_dir, args.root)}")
    emit(f"{bullet}live:         {args.live}")
    if pin_note:
        emit(f"{bullet}{pin_note}")
    emit("")

    # ---- 1. file-level ------------------------------------------------------
    emit("## Files\n" if args.format == "md" else "Files")
    core_pin = core_live = None
    identical = True
    for f in files:
        p = os.path.join(pin_dir, f)
        l = os.path.join(args.live, f)
        if not os.path.exists(l):
            emit(f"{bullet}{f}: MISSING from live tree")
            identical = False
            continue
        a, b = read(p), read(l)
        same = a == b
        identical &= same
        va, vb = spec_version(a), spec_version(b)
        ver = f"  version {va}" + ("" if va == vb else f" -> {vb}")
        emit(f"{bullet}{f}: {'identical' if same else 'DIFFERS'}{ver}")
        if "CORE-PROTOCOL" in f:
            core_pin, core_live = a, b

    if identical:
        emit("\npin matches the live spec exactly — no drift.")
        print("\n".join(out))
        return 0

    if core_pin is None:
        print("\n".join(out))
        return 1

    # ---- 2. sections the models cite ---------------------------------------
    cites = model_citations(args.root)
    resolved = {}
    for sec in cites:
        blk = section_block(core_pin, sec)
        if blk is not None:
            resolved[sec] = blk not in core_live  # True == moved

    moved = sorted([s for s in resolved if resolved[s]], key=secsort)
    unchanged = sorted([s for s in resolved if not resolved[s]], key=secsort)

    emit("\n## Sections the models cite\n" if args.format == "md" else "\nSections the models cite")
    emit(f"{bullet}{len(moved)} of {len(resolved)} moved\n")

    if args.format == "md":
        emit("| § | status | model files citing it |")
        emit("|---|---|---|")
        for sec in moved + unchanged:
            emit(f"| §{sec} | {'**moved**' if resolved[sec] else 'unchanged'} | {len(cites[sec])} |")
    else:
        for sec in moved:
            emit(f"  §{sec:<7} MOVED      cited by {len(cites[sec])} model file(s)")
        for sec in unchanged:
            emit(f"  §{sec:<7} unchanged  cited by {len(cites[sec])} model file(s)")

    # ---- 3. per-track exposure ---------------------------------------------
    emit("\n## Exposure by track\n" if args.format == "md" else "\nExposure by track")
    if args.format == "md":
        emit("| track | model files | cited § | moved | files touching a moved § |")
        emit("|---|---|---|---|---|")
    for track, patterns in TRACKS.items():
        paths = []
        for pat in patterns:
            paths += sorted(glob.glob(os.path.join(args.root, pat)))
        tcites: dict[str, set[str]] = defaultdict(set)
        for path in paths:
            rel = os.path.relpath(path, args.root)
            for m in CITATION.finditer(read(path)):
                if m.group(1) in resolved:
                    tcites[m.group(1)].add(rel)
        tmoved = [s for s in tcites if resolved[s]]
        affected = set().union(*(tcites[s] for s in tmoved)) if tmoved else set()
        if args.format == "md":
            emit(f"| {track} | {len(paths)} | {len(tcites)} | {len(tmoved)} | {len(affected)}/{len(paths)} |")
        else:
            emit(f"  {track:<18} {len(tmoved)}/{len(tcites)} cited § moved; "
                 f"{len(affected)}/{len(paths)} model files affected")

    emit("\nEvery result in this repo remains a reproducible statement about the PIN.")
    emit("Sections listed as moved are where the pin no longer describes the live spec.")

    print("\n".join(out))
    return 1 if moved else 0


if __name__ == "__main__":
    sys.exit(main())
