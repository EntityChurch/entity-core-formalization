#!/usr/bin/env python3
"""vendor-spec — create a frozen spec snapshot, and prove every existing one is still frozen.

Two jobs, deliberately in one file, because they are two halves of one claim.

  vendor   copy a spec byte-for-byte into a new `spec-data/<snapshot>/`, hash it, verify the
           copy against the source, and write the MANIFEST. Refuses to touch a snapshot that
           already exists.
  verify   re-hash every existing snapshot against its own MANIFEST, both directions.

WHY `verify` EXISTS — the freeze was a rule with no enforcement point
--------------------------------------------------------------------
`AGENTS.md`: *"An existing `spec-data/vX/` snapshot is frozen ... never edit a snapshot in
place: a pin whose bytes can change is not a pin, and every result here is quoted against
one."* `spec-data/v0.8.2/MANIFEST.md` says the same thing in the same words, and offers
`Verify: sha256sum spec-data/v0.8.2/*.md` — which is an instruction to a human, not a gate.
Nothing in this repo re-hashed a snapshot. The strongest-stated rule here had the weakest
enforcement: none.

That matters more than it sounds. Every published result is a statement about those bytes,
`make specdrift` measures FROM them, and `make coverage` counts its denominator IN them. A
snapshot that silently drifted would move all three at once and no gate would notice — and
the failure would look like a model error, not a data error. (The digests were checked by
hand before this tool was written and all six matched, so nothing had drifted; the point is
that nobody could have known that without checking by hand.)

D13 — what does `verify` assert, and what else satisfies it?
------------------------------------------------------------
Asserts, per snapshot: every `.md` that is not MANIFEST/README has a SHA-256 row in that
snapshot's MANIFEST and hashes to it, AND every SHA-256 row has a file behind it. Both
directions, because a file added to a snapshot without a manifest row is exactly as much of
a broken pin as a file whose bytes moved. A snapshot with no spec files, or a MANIFEST with
no digest rows, FAILS rather than passing vacuously — an empty check is the thing this whole
family of gates exists to refuse.

Does NOT assert: that a snapshot is a faithful copy of its upstream source. That is checked
once, at `vendor` time, against the source blob — and afterwards it is unknowable from
inside this repo, because the upstream moves and the snapshot must not. Said plainly rather
than left for a reader to assume the provenance line is machine-checked. It is not; it is a
record of what the vendoring run did.

The byte-size column is checked too. It is NOT independent evidence — anyone recomputing a
digest would recompute a size — it catches transcription slips in a hand-edited MANIFEST.

Usage:
  tools/vendor-spec.py verify
  tools/vendor-spec.py vendor --track attestation
  tools/vendor-spec.py vendor --track attestation --dry-run

Exit status: 0 iff every check passes. Suitable as a gate.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import sys
import tomllib

SKIP = {"MANIFEST.md", "README.md"}
# A Files-table row. TWO SCHEMAS ARE LIVE and both must parse, which is a fact about this
# repo's history rather than a nicety: `v0.8.2/MANIFEST.md` has four columns
# (file, version, bytes, digest) and `v0.8.0/MANIFEST.md` has three (no bytes column). The
# older manifest is a point-in-time record; normalizing it to please a regex would mean
# rewriting history so a gate goes green, which is what `runcount`'s first draft was rejected
# for. So the bytes column is OPTIONAL and the size check simply does not run where it is
# absent -- stated here because a check that silently skips is otherwise indistinguishable
# from one that passed.
ROW = re.compile(
    r"^\|\s*`([^`]+\.md)`\s*\|\s*([^|]*?)\s*\|"        # file, spec version
    r"(?:\s*([\d\s,\u2009\u00a0]+?)\s*\|)?"             # bytes -- optional (v0.8.0 has none)
    r"\s*`?([0-9a-f]{64})`?\s*\|",
    re.M,
)
VERSION = re.compile(r"^\*\*Version\*\*:\s*(\S+)", re.M)


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def groupdigits(n: int) -> str:
    """414826 -> '414 826', matching the existing manifests' thousands separator."""
    return f"{n:,}".replace(",", " ")


def snapshots(root: str) -> list[str]:
    base = os.path.join(root, "spec-data")
    return sorted(
        d for d in os.listdir(base)
        if os.path.isdir(os.path.join(base, d)) and not d.startswith(".")
    )


def verify(root: str) -> int:
    problems: list[str] = []
    print("== every spec-data snapshot against its own MANIFEST ==")
    snaps = snapshots(root)
    if not snaps:
        print("FAIL -- no snapshots under spec-data/", file=sys.stderr)
        return 1

    for snap in snaps:
        d = os.path.join(root, "spec-data", snap)
        man = os.path.join(d, "MANIFEST.md")
        if not os.path.isfile(man):
            problems.append(f"{snap}: no MANIFEST.md -- a snapshot without one is not a pin")
            print(f"  NOMANIFEST  {snap}")
            continue
        declared = {m[0]: (m[1], m[2].replace(" ", "").replace(" ", ""), m[3])
                    for m in ROW.findall(read(man))}
        present = sorted(f for f in os.listdir(d) if f.endswith(".md") and f not in SKIP)

        if not declared:
            problems.append(
                f"{snap}: MANIFEST declares no SHA-256 rows"
                "\n      -> a manifest that pins nothing passes any hash check vacuously."
            )
            print(f"  NOROWS      {snap}")
            continue
        if not present:
            problems.append(f"{snap}: no spec files beside the MANIFEST")
            print(f"  NOFILES     {snap}")
            continue

        for f in present:
            if f not in declared:
                problems.append(
                    f"{snap}/{f}: present in the snapshot but pinned by no MANIFEST row"
                    "\n      -> the other direction of the freeze: an UNPINNED file in a"
                    "\n         pinned directory is as broken as one whose bytes moved."
                )
                print(f"  UNPINNED    {snap}/{f}")
                continue
            _ver, size, want = declared[f]
            got = sha256(os.path.join(d, f))
            actual = os.path.getsize(os.path.join(d, f))
            if got != want:
                problems.append(
                    f"{snap}/{f}: SHA-256 {got} != manifest {want}"
                    "\n      -> A SNAPSHOT IS FROZEN. Do not re-hash to make this pass: every"
                    "\n         published result is a statement about the manifest's bytes."
                    "\n         Restore the file, or vendor a NEW snapshot beside this one."
                )
                print(f"  DRIFTED     {snap}/{f}")
            elif size.isdigit() and int(size) != actual:
                problems.append(
                    f"{snap}/{f}: manifest says {size} bytes, file is {actual}"
                    " (digest matches, so this is a manifest transcription error)"
                )
                print(f"  BADSIZE     {snap}/{f}")
            else:
                print(f"  ok          {snap}/{f}")

        for f in sorted(set(declared) - set(present)):
            problems.append(
                f"{snap}/{f}: pinned by a MANIFEST row but not in the snapshot"
                "\n      -> a pin pointing at nothing. Restore the file or drop the row."
            )
            print(f"  MISSING     {snap}/{f}")

    print()
    if problems:
        print(f"FAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    n = sum(len([f for f in os.listdir(os.path.join(root, "spec-data", s))
                 if f.endswith(".md") and f not in SKIP]) for s in snaps)
    print(
        f"OK -- {n} pinned spec file(s) across {len(snaps)} snapshot(s); every file hashes to\n"
        "its MANIFEST row and every row has a file. This asserts the snapshots have NOT MOVED.\n"
        "It does NOT assert any snapshot is a faithful copy of its upstream -- that is checked\n"
        "once at vendor time against the source blob, and is unknowable afterwards from inside\n"
        "this repo, because upstream moves and a pin must not."
    )
    return 0


MANIFEST_TMPL = """# spec-data {snap} — Snapshot Manifest

**Spec:** `{primary}` **{version}**
**Snapshot type:** verbatim copy of the authoritative normative spec file(s) — **byte-for-byte, no paraphrase.**
**Purpose:** the modeling ground truth for the `{track}` proof track (`TRACKS.toml`). Models are
written against a *pinned* snapshot so a model and its result are reproducible per spec-version.
When the spec moves, vendor a new snapshot beside this one and re-check.

> **Vendored is not pinned.** This snapshot exists; whether the `{track}` models transcribe it is
> a separate fact, named by that track's `pin_file` in `TRACKS.toml`. Vendoring alone changes no
> result — the pin moves only as the LAST step of validating models against this text.
>
> **This snapshot is FROZEN.** Never edit a file in it. `make specfreeze`
> (`tools/vendor-spec.py verify`) re-hashes every snapshot against the digests below on every
> `make check` and `make matrix`; a pin whose bytes can change is not a pin.

## Files

| File | Spec version | Bytes | SHA-256 |
|---|---|---|---|
{rows}

Verify: `make specfreeze` (or `sha256sum spec-data/{snap}/*.md`).

## Provenance

| Field | Value |
|---|---|
| Source repo | `{owner}` (sibling) |
| Source path | `{srcdir}/` |
| Vendored | {date}, by this repo, via `tools/vendor-spec.py vendor --track {track}` |
| Method | byte-for-byte copy; each copy's SHA-256 recomputed and compared against the source file's own digest before acceptance. {nfiles} of {nfiles} matched. |
| Dependency floor | {depends} |
| Supersedes | nothing — prior snapshots stay in place as point-in-time pins |

**Cited by content, not by commit.** Published history is re-authored at the release boundary,
so a source commit SHA recorded here would resolve to nothing for a reader. The SHA-256 digests
above are the durable identifier and are verifiable by anyone holding either tree.

## Re-vendor discipline

1. Copy the file(s) byte-for-byte into a NEW `spec-data/<snapshot>/`, verifying each copy's
   SHA-256 against the source before accepting it. `tools/vendor-spec.py vendor` does this and
   refuses to write into an existing snapshot.
2. Record SHA-256, byte size and provenance here. Cite by content digest, not by commit SHA.
3. Record what changed and whether any *modeled* section moved, naming the models to re-check.
4. Keep prior snapshots in place as point-in-time pins. **Never edit a snapshot after it is
   written.**
5. The track's `pin_file` moves **last** — only once the models have been re-validated against
   the new text. Vendoring alone changes no result.
"""


def vendor(root: str, track: str, date: str, dry: bool) -> int:
    with open(os.path.join(root, "TRACKS.toml"), "rb") as fh:
        cfg = tomllib.load(fh)
    t = cfg.get("track", {}).get(track)
    if t is None:
        print(f"FAIL -- no track {track!r} in TRACKS.toml", file=sys.stderr)
        return 1
    src_repo = t.get("source_repo_path", "")
    src_dir = t.get("source_dir", "")
    specs = list(t.get("specs", []))
    if not (src_repo and src_dir and specs):
        print(f"FAIL -- track {track!r} declares no source_repo_path / source_dir / specs",
              file=sys.stderr)
        return 1

    srcs = [os.path.join(root, src_repo, src_dir, s) for s in specs]
    missing = [s for s, p in zip(specs, srcs) if not os.path.isfile(p)]
    if missing:
        print(f"FAIL -- source spec(s) not found under {src_repo}/{src_dir}: "
              f"{', '.join(missing)}", file=sys.stderr)
        return 1

    primary = t.get("primary_spec") or specs[0]
    version = (VERSION.search(read(os.path.join(root, src_repo, src_dir, primary)))
               or [None, "unknown"])[1]
    snap = f"ext-{track}-v{version}" if track != "core" else f"v{version}"
    dest = os.path.join(root, "spec-data", snap)

    if os.path.exists(dest):
        # The freeze, enforced at the only moment it can be: a snapshot is written once.
        print(f"FAIL -- spec-data/{snap}/ already exists. A snapshot is FROZEN and is never\n"
              f"        re-written. If the spec moved, its **Version** moves with it and this\n"
              f"        will resolve to a new directory; if it did not move, there is nothing\n"
              f"        to vendor.", file=sys.stderr)
        return 1

    rows, nfiles = [], 0
    print(f"== vendoring track `{track}` -> spec-data/{snap}/ ==")
    if not dry:
        os.makedirs(dest)
    for s, p in zip(specs, srcs):
        want = sha256(p)
        size = os.path.getsize(p)
        ver = (VERSION.search(read(p)) or [None, "?"])[1]
        if not dry:
            shutil.copyfile(p, os.path.join(dest, s))
            got = sha256(os.path.join(dest, s))
            if got != want:
                print(f"FAIL -- copy of {s} does not match source ({got} != {want})",
                      file=sys.stderr)
                return 1
        rows.append(f"| `{s}` | {ver} | {groupdigits(size)} | `{want}` |")
        nfiles += 1
        print(f"  ok          {s}  v{ver}  {size} bytes  {want[:16]}…")

    manifest = MANIFEST_TMPL.format(
        snap=snap, primary=primary, version=version, track=track,
        rows="\n".join(rows), owner=t.get("owner_repo", "?"), srcdir=src_dir,
        date=date, nfiles=nfiles,
        depends=t.get("depends_note", "—"),
    )
    if dry:
        print(f"\n[dry-run] would write spec-data/{snap}/MANIFEST.md and {nfiles} spec file(s)")
        return 0
    with open(os.path.join(dest, "MANIFEST.md"), "w", encoding="utf-8") as fh:
        fh.write(manifest)
    print(f"\nWrote spec-data/{snap}/ ({nfiles} spec file(s) + MANIFEST.md).")
    print("VENDORED IS NOT PINNED. This changes no published result. To make the models")
    print(f"transcribe it, set track `{track}`'s pin_file in TRACKS.toml as the LAST step of")
    print("validating models against this text, and add:")
    print(f'    vendored     = "{snap}"')
    print(f"to [track.{track}] so `make trackcheck` knows the snapshot exists.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mode", choices=("verify", "vendor"))
    ap.add_argument("--track")
    ap.add_argument("--date", default="", help="vendoring date recorded in the MANIFEST")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = ap.parse_args()

    if args.mode == "verify":
        return verify(args.root)
    if not args.track:
        print("FAIL -- vendor needs --track", file=sys.stderr)
        return 1
    if not args.date and not args.dry_run:
        print("FAIL -- vendor needs --date YYYY-MM-DD (recorded in the MANIFEST provenance)",
              file=sys.stderr)
        return 1
    return vendor(args.root, args.track, args.date, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
