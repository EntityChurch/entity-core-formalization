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
  E. PER-MODEL PIN OVERRIDES, both directions. A track's pin is the snapshot its models
     transcribe; a model that transcribes a DIFFERENT one declares it in
     `[track.<name>.model_pins]` AND says so in its own text, and the two must agree.

Why E exists, stated concretely because the alternative was on the table
------------------------------------------------------------------------
`spec-data/MODELING-PIN` says every published result is a statement about that snapshot "and
no other". Modelling `§4.11` -- a section that does not exist at the core pin -- makes that
sentence false the moment the file lands, and the obvious remedy is a paragraph in the module
header saying which snapshot it targets.

**That remedy is a disclaimer, and `docs/DISCIPLINE-CHARTER.md` D15's eleventh shape is that a disclaimer is
not a gate** -- it is where a stale figure survives longest, because it reads as a site
someone has already thought about. So the override is a machine-read fact with a tripwire on
each side:

  * every key must be a declared model OF THAT TRACK, and name an existing snapshot;
  * the snapshot must DIFFER from the track's own pin -- a redundant override is a claim that
    goes stale silently the moment the track pin moves;
  * the model file must carry `MODELING-PIN-OVERRIDE: <snapshot>` in its own text, agreeing;
  * and the REVERSE direction, which is the one that catches the real failure: a model file
    carrying that marker with no row here FAILS. Transcribing newer text and forgetting to
    declare it is the error this whole section is about, and it is invisible from inside the
    file that does it.

`spec-drift.py` and `coverage-check.py` both read these overrides, so an overridden model is
measured against ITS OWN pin -- otherwise the drift gate would report a §4.11 citation as
unresolvable against a snapshot that has no §4.11, which is a true complaint about the wrong
thing.

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

        # `vendored` is a DIFFERENT fact from `pin_file` and the gate keeps them apart:
        # a snapshot existing says nothing about whether any model transcribes it. Checked for
        # every track, both statuses, because a scoped track vendoring a snapshot is the normal
        # first step and must not be mistaken for pinning one.
        vend = t.get("vendored", "")
        if vend and not os.path.isdir(os.path.join(root, "spec-data", vend)):
            problems.append(
                f"track {name}: vendored = {vend!r} but spec-data/{vend}/ does not exist"
            )
            print(f"  NOSNAPSHOT  {name}: {vend}")

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
                v = f", vendored {vend}" if vend else ", nothing vendored"
                print(f"  ok          {name:12s} scoped   (no models, no pin{v})")
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

    # ---- E. per-model pin overrides, both directions --------------------------
    # Runs before D so a failure here prints next to the track it belongs to.
    print("\n== E. per-model pin overrides ==")
    overridden: set[str] = set()
    n_over = 0
    for name, t in sorted(tracks.items()):
        mp: dict[str, str] = t.get("model_pins", {}) or {}
        if not mp:
            continue
        track_models = set(t.get("models", []))
        track_pin = (pin_dir(root, t.get("pin_file", "")) or "").removeprefix("spec-data/")
        for f, snap in sorted(mp.items()):
            n_over += 1
            overridden.add(f)
            if f not in track_models:
                problems.append(
                    f"track {name}: model_pins names {f!r}, which is not a model of this track"
                )
                print(f"  NOTOURS     {f} (track {name})")
                continue
            if not os.path.isdir(os.path.join(root, "spec-data", snap)):
                problems.append(
                    f"track {name}: model_pins {f!r} -> {snap!r}, but spec-data/{snap}/ does not exist"
                )
                print(f"  NOSNAPSHOT  {f} -> {snap}")
                continue
            if snap == track_pin:
                problems.append(
                    f"track {name}: model_pins {f!r} -> {snap!r} equals the track pin."
                    "\n      -> a redundant override asserts nothing and goes stale silently the"
                    "\n         moment the track pin moves. Delete the row instead."
                )
                print(f"  REDUNDANT   {f} -> {snap} (== track pin)")
                continue
            text = read(os.path.join(root, f))
            m = re.search(r"MODELING-PIN-OVERRIDE:\s*(\S+)", text)
            if not m:
                problems.append(
                    f"{f}: declared in model_pins as {snap!r} and the FILE DOES NOT SAY SO."
                    "\n      -> add a `MODELING-PIN-OVERRIDE: <snapshot>` line to the model. A"
                    "\n         reader opening the model must be able to see which text it"
                    "\n         transcribes without opening TRACKS.toml."
                )
                print(f"  UNMARKED    {f}")
                continue
            if m.group(1) != snap:
                problems.append(
                    f"{f}: model_pins says {snap!r}, the file's own marker says {m.group(1)!r}"
                )
                print(f"  DISAGREE    {f}: {snap} != {m.group(1)}")
                continue
            print(f"  ok          {f:28s} -> {snap} (track pin {track_pin})")

    # The reverse direction, and the one that catches the real failure: a model that declares
    # an override IN ITSELF with no row here. Transcribing newer text and forgetting to declare
    # it is invisible from inside the file that does it.
    for f in sorted(on_disk - overridden):
        text = read(os.path.join(root, f))
        m = re.search(r"MODELING-PIN-OVERRIDE:\s*(\S+)", text)
        if m:
            problems.append(
                f"{f}: carries `MODELING-PIN-OVERRIDE: {m.group(1)}` and NO model_pins row."
                "\n      -> declare it in TRACKS.toml under its track's [track.<name>.model_pins],"
                "\n         or remove the marker. An undeclared override is measured against the"
                "\n         track pin by every other gate, which is the wrong text."
            )
            print(f"  UNDECLARED  {f} -> {m.group(1)}")
    if n_over == 0 and not any(
        re.search(r"MODELING-PIN-OVERRIDE:", read(os.path.join(root, f))) for f in sorted(on_disk)
    ):
        # Stated rather than silent: a section with an empty input set asserts nothing about
        # the live registry, which is D15's seventh shape and cost this repo a gate once.
        print("  ok          no track declares a model_pins override, and no model claims one")
        print("              (NOTE: with no overrides this check has no live subject --")
        print("               its teeth are in tools/ test paths, not in TRACKS.toml)")

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
