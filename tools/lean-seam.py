#!/usr/bin/env python3
"""lean-seam — check the assumption ledger against the Lean text it cites.

Why this exists
---------------
`docs/LEAN-SEAM.md` records, per abstraction in this repo's models, the proposition the
model relies on and the Lean theorem that discharges it. Those correspondences were
established by a human reading two texts. Nothing stops the Lean side from changing
afterwards, at which point the ledger silently becomes a claim about text that no longer
exists — which is the failure mode the ledger was written to prevent, reappearing one
level up.

What this asserts (the D13 question, answered in the file rather than in a commit message)
------------------------------------------------------------------------------------------
ONE claim: **nothing on the Lean side has moved under us.** Concretely --

  1. FILE DIGEST   every Lean file the ledger pins is byte-identical to the text the
                   correspondences were derived from.  <- this is the assertion
  2. NAME PRESENT  every cited theorem name still exists in the file it is cited from.
  3. AXIOM GATE    every cited name still sits under a `#print axioms` line in that file,
                   so a `sorry` would be visible rather than silent.
  4. LEDGER SYNC   the prose citations and the machine-readable pin block name exactly the
                   same set, in both directions.

(2) and (3) assert nothing (1) does not already imply. They exist to make a failure
DIAGNOSABLE -- did the theorem vanish, or did the file merely change around it? -- and are
reported as triage, not as independent evidence. (4) is the real second assertion: it is
what stops a citation being added to the prose without being pinned, or a pin outliving
the row that justified it.

What this does NOT assert
-------------------------
That any correspondence is CORRECT. That is a human reading, and it is exactly the work
that must be redone when a digest breaks. Re-pinning a digest without re-reading the rows
it supports defeats the entire file. A green run means the reading is still ABOUT the
current text; it does not mean the reading was right.

Why it is not part of `make matrix`
-----------------------------------
`make matrix` runs on a bare clone with only `make` + `podman`. This needs a sibling
`entity-core-keystone` checkout, which a fresh clone does not have. A target folded into
the gate that skips when its input is absent asserts nothing -- so this one FAILS LOUDLY
on a missing sibling instead, and stays a separate top-level target.

Usage:
  tools/lean-seam.py --keystone ../../entity-core-keystone
  tools/lean-seam.py --keystone /path/to/entity-core-keystone --ledger docs/LEAN-SEAM.md

Exit status: 0 iff every check above passes. Suitable as a gate.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys

# Where the pinned paths are rooted inside the keystone checkout.
LEAN_ROOT = "protocol-generator/lean"

PIN_BLOCK = re.compile(r"^```leanseam-pins$(.*?)^```$", re.M | re.S)
# `theorem foo` / `lemma foo` at the start of a line -- Lean's own declaration syntax.
DECL = re.compile(r"^(?:theorem|lemma)\s+([A-Za-z_][A-Za-z0-9_'?!.]*)", re.M)
AXIOM_GATE = re.compile(r"^#print\s+axioms\s+([A-Za-z_][A-Za-z0-9_'?!.]*)\s*$", re.M)
# A backticked identifier in the prose that looks like a Lean declaration name.
PROSE_IDENT = re.compile(r"`([A-Za-z_][A-Za-z0-9_']*(?:_[A-Za-z0-9_']+)+)`")
# Any sha256 written out in full, anywhere in the ledger.
DIGEST = re.compile(r"\b[0-9a-f]{64}\b")


class Fail(Exception):
    pass


def read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_pins(ledger_text: str, ledger_path: str):
    """-> (files: {relpath: digest},
           theorems: [(name, relpath, rows)],
           rejected: [(name, relpath, rows)])

    `rejected` records a correspondence that was CONSIDERED AND DOES NOT HOLD -- a Lean
    theorem that discharges nothing here. Making that a pin rather than a prose aside is
    deliberate: it is the form a phantom correspondence has to take so that (a) the sync
    check can tell it from a real citation, and (b) re-proposing it later runs into a
    written record instead of an absence.
    """
    m = PIN_BLOCK.search(ledger_text)
    if not m:
        raise Fail(f"{ledger_path}: no ```leanseam-pins block -- nothing to check against")

    files: dict[str, str] = {}
    theorems: list[tuple[str, str, str]] = []
    rejected: list[tuple[str, str, str]] = []
    for lineno, raw in enumerate(m.group(1).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        kind = parts[0]
        if kind == "file":
            if len(parts) != 3:
                raise Fail(f"pins line {lineno}: expected `file <path> <sha256>`, got: {line}")
            _, relpath, digest = parts
            if len(digest) != 64 or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise Fail(f"pins line {lineno}: not a sha256 digest: {digest}")
            files[relpath] = digest
        elif kind in ("theorem", "rejected"):
            if len(parts) != 4:
                raise Fail(
                    f"pins line {lineno}: expected `{kind} <name> <path> <rows>`, got: {line}"
                )
            (theorems if kind == "theorem" else rejected).append((parts[1], parts[2], parts[3]))
        else:
            raise Fail(f"pins line {lineno}: unknown pin kind {kind!r}")

    if not files:
        raise Fail(f"{ledger_path}: pin block declares no files")
    if not theorems:
        raise Fail(f"{ledger_path}: pin block declares no theorems")

    dupes = {n for n, _, _ in theorems} & {n for n, _, _ in rejected}
    if dupes:
        raise Fail(
            "pinned as BOTH a discharge and a rejected correspondence: " + ", ".join(sorted(dupes))
        )

    unpinned = {p for _, p, _ in theorems + rejected} - set(files)
    if unpinned:
        raise Fail(
            "pin block cites theorems from files it does not pin: " + ", ".join(sorted(unpinned))
        )
    return files, theorems, rejected


def check(keystone: str, ledger_path: str) -> int:
    ledger_text = read(ledger_path)
    files, theorems, rejected = parse_pins(ledger_text, ledger_path)

    lean_root = os.path.join(keystone, LEAN_ROOT)
    if not os.path.isdir(lean_root):
        raise Fail(
            f"no Lean tree at {lean_root}\n"
            "  The ledger cites theorems in the keystone peer; without that checkout there is\n"
            "  nothing to check. This target fails rather than skips -- a skip would report\n"
            "  green for a seam nobody looked at. Point it at a checkout:\n"
            "      make leanseam KEYSTONE=/path/to/entity-core-keystone"
        )

    problems: list[str] = []
    triage: list[str] = []
    sources: dict[str, str] = {}

    # ---- 1. FILE DIGEST -- the assertion -------------------------------------
    print("== 1. file digests (the assertion: the cited text has not changed) ==")
    for relpath, want in sorted(files.items()):
        abspath = os.path.join(lean_root, relpath)
        if not os.path.isfile(abspath):
            problems.append(f"pinned file is gone: {relpath}")
            print(f"  MISSING  {relpath}")
            continue
        sources[relpath] = read(abspath)
        got = sha256(abspath)
        if got == want:
            print(f"  ok       {relpath}")
        else:
            problems.append(
                f"digest mismatch: {relpath}\n"
                f"      pinned {want}\n"
                f"      actual {got}\n"
                f"      -> re-read the changed Lean text against every row citing this file,\n"
                f"         update the verdicts, THEN re-pin. Re-pinning alone defeats the ledger."
            )
            print(f"  CHANGED  {relpath}")

    # ---- 2/3. NAME + AXIOM GATE -- triage ------------------------------------
    print("\n== 2/3. cited names + `#print axioms` gates (triage, not assertion) ==")
    for name, relpath, rows in theorems:
        src = sources.get(relpath)
        if src is None:
            triage.append(f"{name}: file {relpath} unreadable (see above)")
            continue
        decls = set(DECL.findall(src))
        gated = set(AXIOM_GATE.findall(src))
        if name not in decls:
            triage.append(f"{name} ({rows}): no `theorem {name}` in {relpath}")
            print(f"  GONE     {name:34s} {rows}")
        elif name not in gated:
            triage.append(f"{name} ({rows}): present but no `#print axioms {name}` in {relpath}")
            print(f"  UNGATED  {name:34s} {rows}")
        else:
            print(f"  ok       {name:34s} {rows}")

    # A rejected correspondence must still NAME something real. If the theorem it declines
    # to use is gone, the rejection is stale and the row should go with it.
    for name, relpath, rows in rejected:
        src = sources.get(relpath)
        if src is None:
            triage.append(f"{name}: file {relpath} unreadable (see above)")
            continue
        if name not in set(DECL.findall(src)):
            triage.append(f"{name} ({rows}): rejected correspondence names a theorem that is gone")
            print(f"  STALE    {name:34s} {rows}  (rejected)")
        else:
            print(f"  ok       {name:34s} {rows}  (rejected -- discharges nothing here)")

    # ---- 4. LEDGER SYNC -- the second assertion ------------------------------
    print("\n== 4. ledger sync (prose citations <-> pin block, both directions) ==")
    prose = PIN_BLOCK.sub("", ledger_text)
    prose_idents = set(PROSE_IDENT.findall(prose))
    declared_names = {n for n, _, _ in theorems} | {n for n, _, _ in rejected}
    # Only identifiers that are ACTUALLY Lean declarations in a pinned file count as
    # citations -- the prose is full of TLA+ and Promela symbols with the same shape.
    all_decls: set[str] = set()
    for src in sources.values():
        all_decls |= set(DECL.findall(src))
    cited_in_prose = prose_idents & all_decls

    missing_pin = sorted(cited_in_prose - declared_names)
    missing_prose = sorted(declared_names - prose_idents)
    if missing_pin:
        problems.append(
            "a Lean theorem is named in the prose but declared in neither the `theorem` nor\n"
            "      the `rejected` pins: " + ", ".join(missing_pin) + "\n"
            "      -> if it discharges a row, pin it; if it discharges nothing, pin it as\n"
            "         `rejected` and say so in the prose. Naming one in passing is the\n"
            "         failure mode this check exists for."
        )
        for n in missing_pin:
            print(f"  UNPINNED {n}")
    if missing_prose:
        problems.append("pinned but named by no prose row: " + ", ".join(missing_prose))
        for n in missing_prose:
            print(f"  ORPHAN   {n}")
    if not missing_pin and not missing_prose:
        print(
            f"  ok       {len(theorems)} discharging + {len(rejected)} rejected, "
            "both directions"
        )

    # ---- 5. RESTATED DIGESTS -- the third assertion ---------------------------
    #
    # D13, asked of this gate rather than of a model: what does step 1 assert, and what
    # else satisfies it? It reads the `leanseam-pins` block and NOTHING ELSE. From
    # 2026-09-06 to 2026-09-09 the ledger's own §"Citing the Lean side" table restated both
    # digests at superseded values -- while telling the reader that the digest IS the pin
    # and that this tool checks every digest -- and step 1 was green throughout, because a
    # prose table is not the pin block. The stale copy was created by the commit that
    # correctly updated the pin block: a 64-hex string does not read as a claim, so the
    # session that re-pinned did not see the table as a site.
    #
    # So: every full sha256 anywhere in the ledger must be a value the pin block declares.
    # This does not assert the pin block is RIGHT (step 1 does that against the real file);
    # it asserts the document does not state a second, different answer to the same
    # question in a notation nobody parses.
    print("\n== 5. restated digests (every sha256 in the ledger is a declared pin) ==")
    pinned_values = set(files.values())
    prose_only = PIN_BLOCK.sub("", ledger_text)
    stray = sorted({d for d in DIGEST.findall(prose_only)} - pinned_values)
    if stray:
        problems.append(
            "the ledger states "
            f"{len(stray)} sha256 digest(s) outside the pin block that the pin block does\n"
            "      not declare: " + ", ".join(f"{d[:12]}..." for d in stray) + "\n"
            "      -> a digest restated in prose is a SECOND copy of a gated fact, and only\n"
            "         the pin block is read. Update the restatement, or drop it -- do not\n"
            "         leave two answers to one question in one document."
        )
        for d in stray:
            print(f"  STRAY    {d[:12]}...  (not a declared pin)")
    else:
        n = len(DIGEST.findall(prose_only))
        print(f"  ok       {n} restated digest(s), all declared in the pin block")

    # ---- verdict --------------------------------------------------------------
    print()
    if triage and not problems:
        # A name/gate failure with intact digests should be impossible -- report it as a
        # real failure rather than swallowing it, because it means one of the two is wrong.
        problems.append(
            "digests match but a cited name or axiom gate does not resolve -- "
            "the pin block and the pinned file disagree about what is in it"
        )
    if triage:
        print("triage:")
        for t in triage:
            print(f"  - {t}")
        print()
    if problems:
        print(f"FAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nThe seam ledger is a human reading of two texts. This gate only detects that\n"
            "one of them moved; re-establishing the reading is the work it is asking for."
        )
        return 1

    print(
        f"OK -- {len(files)} file(s), {len(theorems)} discharging theorem(s), "
        f"{len(rejected)} rejected correspondence(s), ledger in sync.\n"
        "This asserts only that the Lean text the ledger cites has not changed.\n"
        "It does NOT assert any correspondence is correct -- see docs/LEAN-SEAM.md section 5."
    )
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--keystone",
        default=os.environ.get("KEYSTONE", "../entity-core-keystone"),
        help="path to an entity-core-keystone checkout",
    )
    ap.add_argument("--ledger", default="docs/LEAN-SEAM.md", help="path to the assumption ledger")
    args = ap.parse_args()
    try:
        return check(args.keystone, args.ledger)
    except Fail as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
