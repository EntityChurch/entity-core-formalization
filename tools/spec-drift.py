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

--check-claims — the D15 half, added 2026-09-06
-----------------------------------------------
The three questions above are a REPORT, and a report nobody runs is a claim nobody checks.
Eight canonical documents stated "`make specdrift` reports **no drift**" for ten days after
the live spec reached 0.8.2.11, two of them in the strongest possible form ("byte-for-byte
across all three normative files"). Nothing caught it, for three compounding reasons:

  * `make specdrift` is wired `|| true`, so running it cannot fail;
  * `make specdrift-gate`, which can, is invoked by no target;
  * and the prose was tied to no derivation at all.

That is exactly the hole `make runcount` closes for the matrix run total, one artifact over,
and this flag is the same fix: every site that states the drift status is DECLARED here by
anchor, and its claim must equal what the measurement above derives.

WHAT MAKES THIS ONE DIFFERENT, and it is worth stating because it changes what a sufficient
gate looks like. Every previous stale-claim finding in this repo went stale because WE
changed something and missed a site -- the run total across two commits, the ledger counts
across seven. This claim goes stale when SOMEBODY ELSE COMMITS, in a repo we do not own,
with our tree untouched and every existing gate green. A gate that only runs on our own
diffs cannot reach it in principle. So this one has to be run on a schedule or at a release
boundary, not merely on change, and `make driftclaim` says so in its own output.

Usage:
  tools/spec-drift.py --live ../entity-core-protocol/specs
  tools/spec-drift.py --live /tmp/pub-specs --format md
  tools/spec-drift.py --live ../entity-core-protocol/specs --check-claims
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys
import tomllib
from collections import defaultdict

HEADING = re.compile(r"^#{1,6}\s+\S", re.M)
NUMBERED = re.compile(r"^#{1,6}\s+(\d+(?:\.\d+)*[a-z]?)\s+.*$", re.M)
CITATION = re.compile(r"§\s*(\d+(?:\.\d+)*[a-z]?)")

# A CROSS-TRACK citation, `§CORE:6.2` — see TRACKS.toml §"The citation convention". It is
# excluded from the citing track's COVERAGE set (it is a reference, not a claim) but it IS a
# dependency for drift: a model that reads core §6.2 is exposed when core §6.2 moves. The
# conservative direction, deliberately — under-reporting exposure is the failure that matters.
PREFIXED = re.compile(r"§([A-Z][A-Z0-9]{1,11}):(\d+(?:\.\d+)*[a-z]?)")

# ENGINES, not "tracks". This grouping is by MODEL CHECKER, and since 2026-09-06 "track" means
# something else in this repo — a proof track (core / attestation / quorum / identity,
# TRACKS.toml). The two were about to be one word for two things in the same output. Renamed
# rather than left to be disambiguated by a reader who has no reason to suspect the collision.
ENGINES = {
    "TLA+/Apalache": ("tla",),
    "Spin": ("spin",),
    "Tamarin/ProVerif": ("tamarin",),
}

# ── WHERE THE DRIFT STATUS IS CLAIMED IN PROSE (--check-claims) ─────────────────────────
# One canonical phrasing, deliberately, so a single anchor reaches every site:
#
#     `make specdrift` reports **no drift**
#     `make specdrift` reports **9 of 30 cited sections moved**
#
# Uniform phrasing is doing real work here beyond tidiness. The eight sites had eight
# different wordings -- "no drift", "reports no drift", "the pin matches the live spec
# byte-for-byte across all three normative files", "current against protocol 0.8.2" -- and
# a gate cannot anchor on prose that says the same thing eight ways. The variety is also
# what let the strongest claim (README's "byte-for-byte") drift furthest from the weakest.
#
# Matched against a NORMALIZED copy of each file (blockquote markers stripped, whitespace
# collapsed) so that markdown line-wrapping and `> ` prefixes do not break the anchor. The
# first draft matched raw text and failed six of nine sites on wrapping alone — a gate whose
# green depends on where an author's editor broke a line asserts the line breaks, not the
# claim.
CLAIM_RE = r"`make specdrift` reports \*\*(no drift|\d+ of \d+ cited sections moved)\*\*"


def normalize(text: str) -> str:
    """Blockquote markers off, whitespace collapsed — so the anchor survives re-wrapping."""
    return re.sub(r"\s+", " ", re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.M))

CLAIM_SITES = [
    ("README.md", "the pin note above the fold"),
    ("README.md", "the Status heading block"),
    ("AGENTS.md", "the Status paragraph"),
    ("CHANGELOG.md", "the versioning preamble"),
    ("CANONICAL-DOCS.toml", "the repo blurb"),
    ("docs/STATUS.md", "the headline pin claim"),
    ("docs/ASSURANCE-MAP.md", "the pin banner"),
    ("docs/FINAL-ASSURANCE-SUMMARY.md", "the pin banner"),
    ("docs/SPEC-DRIFT-ASSESSMENT.md", "the live-measurement banner"),
]

# README.md and docs/SPEC-DRIFT-ASSESSMENT.md are expected to carry the claim TWICE and
# once respectively; the check counts occurrences per file rather than per row, so this
# maps file -> how many times the anchor must appear. A file that grows a new unanchored
# claim is NOT detected -- same acknowledged hole as runcount's, stated rather than hidden.
CLAIM_COUNTS = {"README.md": 2}


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


def track_models(root: str, track: str = "core") -> list[str]:
    """Repo-relative model files of one proof track, from TRACKS.toml.

    Was four non-recursive globs (`tla/*.tla`, ...). Two problems, both fixed by reading the
    registry instead. (1) `tla/*.tla` does not descend, so the obvious first reorganization —
    models into `tla/attestation/` — would have made them invisible here while this gate kept
    reporting a drift number, i.e. a number about a shrinking set nobody was told had shrunk.
    (2) A glob has no notion of WHICH protocol a file models, and this tool measures drift
    against the CORE pin; an extension model's citations resolved against the core spec would
    be noise at best. `make trackcheck` is what keeps the registry honest in both directions.
    """
    with open(os.path.join(root, "TRACKS.toml"), "rb") as fh:
        cfg = tomllib.load(fh)
    return list(cfg.get("track", {}).get(track, {}).get("models", []))


def track_prefix(root: str, track: str = "core") -> str:
    with open(os.path.join(root, "TRACKS.toml"), "rb") as fh:
        cfg = tomllib.load(fh)
    return cfg.get("track", {}).get(track, {}).get("cite_prefix", "")


def model_citations(root: str, paths: list[str], *, bare: bool, prefix: str = "") -> dict[str, set[str]]:
    """Sections these files depend on.

    `bare=True`  -- count unprefixed `§N.M`. ONLY valid for files ON the track being measured,
                    because a bare citation means a section of the citing file's OWN spec.
    `prefix=...` -- also count `§<PREFIX>:N.M`, the cross-track form.

    THE `bare` FLAG IS NOT A CONVENIENCE, IT IS THE FIX FOR A BUG THIS FILE SHIPPED FOR ABOUT
    AN HOUR ON 2026-09-07. The first draft of the cross-track pass called this function on the
    OTHER tracks' models to pick up their `§CORE:N.M` references -- and it also counted their
    BARE citations, so `tla/AttestIndex.tla`'s `§3.1` and `§3.2` (sections of
    EXTENSION-ATTESTATION) were resolved against ENTITY-CORE-PROTOCOL and entered core's
    dependency set. The drift denominator moved 30 -> 32 and `make driftclaim` failed against
    all nine prose sites, which is the only reason it was caught.
    That is the document-blind citation bug -- the exact failure the whole track dimension was
    built to prevent -- reintroduced by the patch that added track awareness to this file.
    Worth the paragraph: knowing the rule, having just written the gate for it, and violating
    it in the same session is the normal case, and the gate is what caught its author.
    """
    cites: dict[str, set[str]] = defaultdict(set)
    for rel in sorted(paths):
        text = read(os.path.join(root, rel))
        if bare:
            for m in CITATION.finditer(text):
                cites[m.group(1)].add(rel)
        if prefix:
            for p, sec in PREFIXED.findall(text):
                if p == prefix:
                    cites[sec].add(rel)
    return cites


def core_citations(root: str) -> dict[str, set[str]]:
    """Every section of the CORE spec any model in this repo depends on.

    Bare `§N.M` from core's own models, plus `§CORE:N.M` written by a model on another proof
    track. Those cross-track references are excluded from coverage (a reference is not a
    claim) but they ARE drift exposure: a model that reads core §6.2 is exposed when core
    §6.2 moves, whichever track it belongs to.
    """
    with open(os.path.join(root, "TRACKS.toml"), "rb") as fh:
        cfg = tomllib.load(fh)
    tracks = cfg.get("track", {})
    core = tracks.get("core", {})
    cites = model_citations(root, list(core.get("models", [])), bare=True)
    prefix = core.get("cite_prefix", "")
    others = [
        f for n, t in tracks.items() if n != "core" and t.get("kind") == "protocol"
        for f in t.get("models", [])
    ]
    if others and prefix:
        for sec, files in model_citations(root, others, bare=False, prefix=prefix).items():
            cites.setdefault(sec, set()).update(files)
    return cites


def secsort(sec: str):
    return [int(p) for p in re.findall(r"\d+", sec)] + [sec]


def check_claims(root: str, moved: int, total: int) -> list[str]:
    """Every declared site must state the drift status the measurement just derived.

    D13 -- what does this assert, and what else satisfies it? It asserts that each declared
    site makes a drift claim AND that the claim agrees with the derivation. Two failures are
    deliberately treated the same way:

      * a site that says "no drift" while sections have moved -- the live bug;
      * a site that says NOTHING -- because deleting the sentence is the cheapest way to go
        green, and a repo whose drift status is unstated is in exactly the position this
        tool exists to prevent. runcount learned this one first.

    What it does NOT assert: that the prose AROUND the anchor is accurate. A site can state
    the right count in a paragraph that misdescribes what moved, and this will pass it.
    """
    want = "no drift" if moved == 0 else f"{moved} of {total} cited sections moved"
    problems = []
    for site in sorted({s for s, _ in CLAIM_SITES}):
        whats = [w for s, w in CLAIM_SITES if s == site]
        try:
            found = re.findall(CLAIM_RE, normalize(read(os.path.join(root, site))))
        except OSError as exc:
            problems.append(f"{site}: cannot read ({exc})")
            continue
        need = CLAIM_COUNTS.get(site, 1)
        if len(found) != need:
            problems.append(
                f"{site}: expected {need} drift claim(s) ({'; '.join(whats)}), found "
                f"{len(found)}. A site that stops stating the drift status is how the "
                f"status goes stale unnoticed -- restore the claim, or drop the row from "
                f"CLAIM_SITES deliberately."
            )
            continue
        wrong = sorted({f for f in found if f != want})
        if wrong:
            problems.append(f"{site}: claims {wrong}, derived {want!r}")
    return problems


def report_claims(problems: list[str], moved: int, total: int) -> str:
    want = "no drift" if moved == 0 else f"{moved} of {total} cited sections moved"
    n = len(CLAIM_SITES)
    if problems:
        lines = [f"CLAIM CHECK FAILED -- {len(problems)} site(s) disagree with the "
                 f"measurement above (derived: {want!r}):"]
        lines += [f"  - {p}" for p in problems]
        lines.append("")
        lines.append("The measurement is the source of truth. Fix the prose, not this tool.")
        lines.append("Do NOT delete a claim to go green -- silence fails here too, by design.")
        return "\n".join(lines)
    return (f"CLAIM CHECK OK -- all {n} declared prose sites state {want!r}.\n"
            "This asserts the STATUS, not that the prose around it describes the drift\n"
            "correctly, and not that an undeclared site exists somewhere stating otherwise.\n"
            "NOTE: this claim can go stale with NO commit in this repo -- it depends on a\n"
            "sibling's tree. Running it only on our own diffs is insufficient in kind; run\n"
            "it at a release boundary and on a schedule.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pin", default=None, help="pinned snapshot dir (default: newest spec-data/*/)")
    ap.add_argument("--live", required=True, help="live spec dir, e.g. a sibling's specs/")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--format", choices=("text", "md"), default="text")
    ap.add_argument("--check-claims", action="store_true",
                    help="assert every declared prose site states the derived drift status")
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
        # The claim check still runs: a document asserting drift that does not exist is
        # wrong in the same way as one denying drift that does, and only one of the two
        # feels like a failure. (The leanproof both-directions lesson, D13.)
        if args.check_claims and core_pin is not None:
            total = len([s for s in core_citations(args.root)
                         if section_block(core_pin, s) is not None])
            problems = check_claims(args.root, 0, total)
            emit("")
            emit(report_claims(problems, 0, total))
            print("\n".join(out))
            return 1 if problems else 0
        print("\n".join(out))
        return 0

    if core_pin is None:
        print("\n".join(out))
        return 1

    # ---- 2. sections the models cite ---------------------------------------
    cites = core_citations(args.root)
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
    # "by ENGINE", not "by track": since 2026-09-06 a *track* is a proof track
    # (core / attestation / quorum / identity, TRACKS.toml). This grouping is by model checker.
    emit("\n## Exposure by engine\n" if args.format == "md" else "\nExposure by engine")
    if args.format == "md":
        emit("| engine | model files | cited § | moved | files touching a moved § |")
        emit("|---|---|---|---|---|")
    core_files = track_models(args.root, "core")
    for engine, roots in ENGINES.items():
        paths = [f for f in core_files if f.split("/")[0] in roots]
        tcites: dict[str, set[str]] = defaultdict(set)
        for rel in paths:
            for m in CITATION.finditer(read(os.path.join(args.root, rel))):
                if m.group(1) in resolved:
                    tcites[m.group(1)].add(rel)
        tmoved = [s for s in tcites if resolved[s]]
        affected = set().union(*(tcites[s] for s in tmoved)) if tmoved else set()
        if args.format == "md":
            emit(f"| {engine} | {len(paths)} | {len(tcites)} | {len(tmoved)} | {len(affected)}/{len(paths)} |")
        else:
            emit(f"  {engine:<18} {len(tmoved)}/{len(tcites)} cited § moved; "
                 f"{len(affected)}/{len(paths)} model files affected")

    emit("\nEvery result in this repo remains a reproducible statement about the PIN.")
    emit("Sections listed as moved are where the pin no longer describes the live spec.")

    if args.check_claims:
        problems = check_claims(args.root, len(moved), len(resolved))
        emit("")
        emit(report_claims(problems, len(moved), len(resolved)))
        print("\n".join(out))
        return 1 if problems else 0

    print("\n".join(out))
    return 1 if moved else 0


if __name__ == "__main__":
    sys.exit(main())
