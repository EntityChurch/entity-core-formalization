#!/usr/bin/env python3
"""trackcheck -- does every model file belong to exactly one declared proof track?

Why this exists
---------------
This repo had one subject until 2026-09-06 and every artifact assumed it. Extension protocols
(attestation, quorum, identity) arrive with their own spec bodies and their own section
numbering, which turns that assumption into a claim. `TRACKS.toml` is where the claim lives;
this is the gate that makes it one.

The concrete failure it heads off, in two halves:

  1. `§(\\d+\\.\\d+)` -- the pattern behind the published coverage number -- is DOCUMENT-BLIND.
     `EXTENSION-ATTESTATION §5.7` and core `§5.7` produce the same token, and core already has
     a `5.7` grid row, so an attestation citation would be absorbed into a core claim and
     `make coverage` would report OK. A phantom row arriving *through* the gate built to stop
     phantom rows.
  2. `coverage-check.py` and `spec-drift.py` globbed `tla/*.tla` NON-RECURSIVELY. Moving models
     into `tla/attestation/` -- the obvious first reorganization -- makes them invisible to
     both, which then stay green while asserting nothing about the new track.

Half 2 is why this walks the filesystem recursively instead of trusting a glob, and why the
walk is cross-checked against git.

What this asserts
-----------------
  A. DISCOVERY, both directions. Every model file found by a recursive walk of the declared
     roots belongs to exactly one track; every file a track declares exists on disk. An
     unregistered file fails, a declared-but-missing file fails, and a file claimed by two
     tracks fails.
  B. GIT AGREEMENT. The walk's file set equals git's tracked set, and no untracked,
     non-ignored model file exists. This closes the hole where a model file is run by the
     matrix (which reads the engine Makefiles, not git) while being invisible to every
     claim-checking gate. Not a git repo -> FAIL; a check that cannot run is not a pass.
  C. TRACK WELL-FORMEDNESS. A `modeled` protocol track has a pin file that exists and names an
     existing snapshot, a primary_spec present in that snapshot, and a coverage doc + heading
     that resolve. A `scoped` track has NO models and NO pin -- so assigning a file to a
     scoped track fails until someone promotes it and states which snapshot the results are
     about. That promotion step is the point: it cannot be skipped by quietly adding a file.
  D. PROSE. Every declared site states the track inventory this file derives. Silence fails,
     the `runcount` / `ledgercount` rule -- deleting the sentence is otherwise the cheapest
     way to green.

What this does NOT assert
-------------------------
That a file is on the RIGHT track. Membership is a human's declaration, checked for existence
and uniqueness only; a core model listed under `attestation` passes every check here. Same
standing caveat as the assumption ledger's, and said out loud for the same reason.

Nor does it assert anything about CITATIONS -- whether a model's `§` refs resolve against its
own track's spec is `make coverage`'s question, not this one.

Usage:  tools/trackcheck.py [--tracks TRACKS.toml]
Exit status: 0 iff every check above passes. Suitable as a gate.
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import re
import subprocess
import sys
import tomllib

MODEL_KINDS = ("protocol", "toolchain")

# D15/`runcount` shape: the inventory is derived here, and every site that PUBLISHES it must
# agree. Anchored per site so a true statement about the past is not mistaken for a live claim.
# (site, what it is, key, regex over the normalized text)
PROSE_SITES = [
    ("README.md", "the proof-tracks block", "summary",
     r"\*\*(\d+) proof tracks?\*\*.*?(\d+) modeled.*?(\d+) scoped"),
    ("docs/COVERAGE-MATRIX.md", "the track preamble", "summary",
     r"\*\*(\d+) proof tracks?\*\*.*?(\d+) modeled.*?(\d+) scoped"),
    ("docs/STATUS.md", "the track inventory", "summary",
     r"\*\*(\d+) proof tracks?\*\*.*?(\d+) modeled.*?(\d+) scoped"),
    ("AGENTS.md", "the track paragraph", "summary",
     r"\*\*(\d+) proof tracks?\*\*.*?(\d+) modeled.*?(\d+) scoped"),
]


def normalize(text: str) -> str:
    """Blockquote markers off, whitespace collapsed -- so an anchor survives re-wrapping.

    `driftclaim`'s first draft matched raw text and failed six of nine sites on markdown line
    breaks alone. A gate whose green depends on where an author's editor wrapped a line
    asserts the line breaks, not the claim.
    """
    return re.sub(r"\s+", " ", re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.M))


def read(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def git_model_files(root: str, exts: tuple[str, ...], roots: list[str]) -> tuple[set[str], set[str]] | None:
    """(tracked, untracked-but-not-ignored) model files, or None if this is not a git repo."""
    def run(*args: str) -> list[str]:
        p = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
        if p.returncode != 0:
            raise RuntimeError(p.stderr.strip())
        return [ln for ln in p.stdout.splitlines() if ln]

    try:
        tracked = {f for f in run("ls-files", "--", *roots) if f.endswith(exts)}
        untracked = {
            f for f in run("ls-files", "--others", "--exclude-standard", "--", *roots)
            if f.endswith(exts)
        }
    except (RuntimeError, FileNotFoundError):
        return None
    return tracked, untracked


def walk_models(root: str, roots: list[str], exts: tuple[str, ...], excludes: list[str]) -> set[str]:
    """Every model file under the declared roots, RECURSIVELY, minus declared artifacts."""
    found: set[str] = set()
    for r in roots:
        base = os.path.join(root, r)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for fn in sorted(filenames):
                if not fn.endswith(exts):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                if any(fnmatch.fnmatch(rel, g) or fnmatch.fnmatch("/" + rel, g)
                       or any(fnmatch.fnmatch(part, g.strip("*/")) for part in rel.split(os.sep))
                       for g in excludes):
                    continue
                found.add(rel)
    return found


def pin_dir(root: str, pin_file: str) -> str | None:
    """First non-comment, non-blank line of a pin file -- the same parse spec-drift.py does."""
    path = os.path.join(root, pin_file)
    if not os.path.isfile(path):
        return None
    for line in read(path).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            return os.path.join("spec-data", line)
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--tracks", default="TRACKS.toml")
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = args.root

    with open(os.path.join(root, args.tracks), "rb") as fh:
        cfg = tomllib.load(fh)

    reg = cfg.get("registry", {})
    exts = tuple(reg.get("model_extensions", []))
    roots = list(reg.get("model_roots", []))
    excludes = list(reg.get("exclude_globs", []))
    tracks: dict[str, dict] = cfg.get("track", {})
    if not exts or not roots or not tracks:
        print("FAIL -- TRACKS.toml declares no extensions, roots or tracks", file=sys.stderr)
        return 1

    problems: list[str] = []

    # ---- A. discovery, both directions ---------------------------------------
    print("== A. every model file belongs to exactly one track ==")
    on_disk = walk_models(root, roots, exts, excludes)

    owner: dict[str, str] = {}
    dupes: list[str] = []
    declared: set[str] = set()
    for name, t in sorted(tracks.items()):
        for f in t.get("models", []):
            declared.add(f)
            if f in owner:
                dupes.append(f"{f}: {owner[f]} and {name}")
            else:
                owner[f] = name

    unregistered = sorted(on_disk - declared)
    missing = sorted(declared - on_disk)
    if unregistered:
        problems.append(
            "model file on disk but in no track: " + ", ".join(unregistered)
            + "\n      -> add it to a track in TRACKS.toml. A model no track claims is a model"
              "\n         no coverage/drift gate can see -- the failure this file exists for."
        )
        for f in unregistered:
            print(f"  UNTRACKED   {f}")
    if missing:
        problems.append(
            "declared by a track but not on disk: " + ", ".join(missing)
            + "\n      -> the file moved or was deleted; update TRACKS.toml deliberately."
        )
        for f in missing:
            print(f"  MISSING     {f}")
    if dupes:
        problems.append("claimed by two tracks: " + "; ".join(dupes))
        for d in dupes:
            print(f"  DUPLICATE   {d}")
    if not (unregistered or missing or dupes):
        print(f"  ok          {len(on_disk)} model files, {len(tracks)} tracks, both directions")

    # ---- B. git agreement -----------------------------------------------------
    print("\n== B. the walk agrees with git ==")
    g = git_model_files(root, exts, roots)
    if g is None:
        # D13: a check that cannot run is a FAILURE. Passing quietly here would mean the one
        # assertion that catches an unstaged-but-runnable model file silently disappears.
        problems.append("not a git repository (or git unavailable) -- cannot cross-check the walk")
        print("  UNCHECKED   git not available")
    else:
        tracked, untracked = g
        tracked = {f for f in tracked if not any(fnmatch.fnmatch(f, x) for x in excludes)
                   and "_TTrace_" not in f and "_apalache-out" not in f}
        if untracked:
            problems.append(
                "model file exists, is not gitignored, and is not staged: "
                + ", ".join(sorted(untracked))
                + "\n      -> `make matrix` reads the engine Makefiles, not git, so a file in"
                  "\n         this state can be RUN while being invisible to every claim gate."
            )
            for f in sorted(untracked):
                print(f"  UNSTAGED    {f}")
        drift = (tracked ^ on_disk)
        if drift:
            problems.append("walk and git disagree on: " + ", ".join(sorted(drift)))
            for f in sorted(drift):
                print(f"  DISAGREE    {f}")
        if not untracked and not drift:
            print(f"  ok          {len(tracked)} tracked, 0 untracked-and-unignored")

    # ---- C. track well-formedness --------------------------------------------
    print("\n== C. each track is well-formed for its status ==")
    modeled = scoped = 0
    for name, t in sorted(tracks.items()):
        kind, status = t.get("kind", ""), t.get("status", "")
        if kind not in MODEL_KINDS:
            problems.append(f"track {name}: kind {kind!r} is not one of {MODEL_KINDS}")
            print(f"  BADKIND     {name}: {kind!r}")
            continue
        if kind != "protocol":
            print(f"  ok          {name:12s} {kind} ({len(t.get('models', []))} files, no §-claim)")
            continue

        if status == "scoped":
            scoped += 1
            before = len(problems)
            # A scoped track with models would be a track making claims nobody pinned.
            if t.get("models"):
                problems.append(
                    f"track {name}: status 'scoped' but declares {len(t['models'])} model(s)"
                    "\n      -> promote it to 'modeled' AND give it a pin_file. That step is where"
                    "\n         someone states which snapshot the results are about; it is not"
                    "\n         skippable by adding a file."
                )
                print(f"  UNPINNED    {name}: scoped track has models")
            if t.get("pin_file"):
                problems.append(f"track {name}: status 'scoped' but declares a pin_file")
                print(f"  ODDPIN      {name}: scoped track has a pin")
            if not t.get("primary_spec"):
                problems.append(f"track {name}: no primary_spec named")
                print(f"  NOSPEC      {name}")
            if len(problems) == before:
                print(f"  ok          {name:12s} scoped   (no models, no pin, spec named)")
        elif status == "modeled":
            modeled += 1
            pin = pin_dir(root, t.get("pin_file", ""))
            if not pin or not os.path.isdir(os.path.join(root, pin)):
                problems.append(
                    f"track {name}: status 'modeled' but pin_file {t.get('pin_file')!r}"
                    f" resolves to {pin!r}, which is not a directory"
                )
                print(f"  BADPIN      {name}: {pin!r}")
                continue
            ps = os.path.join(root, pin, t.get("primary_spec", ""))
            if not os.path.isfile(ps):
                problems.append(f"track {name}: primary_spec not in the pin: {ps}")
                print(f"  NOSPEC      {name}: {ps}")
                continue
            cov, head = t.get("coverage_doc", ""), t.get("coverage_heading", "")
            if not cov or not os.path.isfile(os.path.join(root, cov)):
                problems.append(f"track {name}: coverage_doc {cov!r} does not exist")
                print(f"  NOCOVDOC    {name}: {cov!r}")
                continue
            if head not in read(os.path.join(root, cov)):
                problems.append(
                    f"track {name}: coverage_heading not found in {cov}:\n      {head!r}"
                    "\n      -> a modeled track with no grid section publishes no coverage claim."
                )
                print(f"  NOHEADING   {name}")
                continue
            print(f"  ok          {name:12s} modeled  (pin {pin}, {len(t['models'])} files)")
        else:
            problems.append(f"track {name}: status {status!r} is not 'modeled' or 'scoped'")
            print(f"  BADSTATUS   {name}: {status!r}")

    # ---- D. the prose ---------------------------------------------------------
    print("\n== D. the inventory as published ==")
    total = modeled + scoped
    for site, what, _key, pattern in PROSE_SITES:
        path = os.path.join(root, site)
        if not os.path.isfile(path):
            problems.append(f"{site}: declared prose site does not exist")
            print(f"  MISSING     {site}")
            continue
        m = re.search(pattern, normalize(read(path)), re.S)
        if not m:
            problems.append(
                f"{site}: {what} no longer states the track inventory."
                "\n      -> restore the claim, or drop the row from PROSE_SITES deliberately."
                "\n         Silence fails here: deleting the sentence is the cheapest way to green."
            )
            print(f"  SILENT      {site:28s} {what}")
            continue
        got = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        if got != (total, modeled, scoped):
            problems.append(
                f"{site}: {what} says {got[0]} tracks / {got[1]} modeled / {got[2]} scoped;"
                f" TRACKS.toml has {total} / {modeled} / {scoped}"
            )
            print(f"  STALE       {site:28s} {got} != {(total, modeled, scoped)}")
        else:
            print(f"  ok          {site:28s} {what}")

    print()
    if problems:
        print(f"FAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(
        f"OK -- {len(on_disk)} model files across {total} protocol tracks "
        f"({modeled} modeled, {scoped} scoped); every file in exactly one, git agrees,\n"
        f"{len(PROSE_SITES)} prose sites state it.\n"
        "This asserts MEMBERSHIP and track well-formedness. It does NOT assert that a file is\n"
        "on the RIGHT track -- that is a human's declaration -- nor anything about citations,\n"
        "which is `make coverage`'s question."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
