#!/usr/bin/env python3
"""lean-proof — check that the Lean proofs the assumption ledger cites STILL HOLD.

Why this exists
---------------
`docs/LEAN-SEAM.md` says, per abstraction in this repo's TLA+/Spin/Tamarin models, which
Lean theorem in the sibling `entity-core-keystone` peer discharges the proposition the
model assumes. `make leanseam` checks that the cited TEXT has not moved (byte digests).

It does not check that the cited PROOFS still hold, and until this gate existed nothing
anywhere did. `lake build EntityCoreProofs` is called "the proof check" in the keystone
lakefile ("a `sorry` or failed proof fails the build"), its proof-library root, the peer
profile's testing contract and two status docs -- five sites -- and is invoked by no
Makefile, script or CI workflow in that tree (exhaustive search,
2026-08-30). So the ten ledger rows that cite a Lean theorem by name rested on a build
nobody ran.

The D13 question, answered by DEMONSTRATION rather than by reasoning
-------------------------------------------------------------------
"What does this assert, and what else satisfies it?" Asked of `lake build` and answered by
building each case (`docs/LEAN-SEAM.md` §7 records the runs):

  * a `sorry` in a cited theorem   -> lake prints `Build completed successfully`, EXITS 0.
    A warning, not an error. The lakefile's own claim is false.
  * a custom `axiom` standing in for a proof -> `Build completed successfully`, EXITS 0.
    Nothing in the build output distinguishes it except the `#print axioms` line.
  * a broken proof                 -> exit 1. This is the ONLY one of the three that an
    exit-status grader catches.

So exit status catches one failure mode in three, and the two it misses are exactly the
two a proof gate exists to catch. The assertion has to be made against the AXIOM SETS.

What this asserts
-----------------
  1. TOOLCHAIN   the Lean version this image resolves equals the version keystone's own
                 `lean-toolchain` pins. Verifying with a different compiler than the peer
                 ships is not verifying the peer.
  2. BUILD       `lake build EntityCoreProofs` completes: exit 0, no `error:` line, and the
                 positive `Build completed successfully` line present.
  3. AXIOM GATES every declaration under a `#print axioms` gate reports an axiom set that
                 is a subset of Lean's three standard axioms {propext, Classical.choice,
                 Quot.sound}. `sorryAx` or any other axiom is a failure, and the axiom set
                 must equal the one DECLARED for it in lean/proof-gate.expect -- no more,
                 no less, in both directions, so a gate silently added, dropped, renamed or
                 weakened fails the build.
  4. LEDGER      every theorem `docs/LEAN-SEAM.md` pins (including the one pinned as a
                 REJECTED correspondence) is among those gated declarations. This is what
                 ties the gate to the ledger rather than to "some proofs built".
  5. WARNINGS    a Lean warning is a build failure unless it is declared in
                 lean/proof-gate.expect. D13's "a tool warning is a build failure", applied
                 to a toolchain that reports `sorry` AS a warning.

What this does NOT assert
-------------------------
That any correspondence in the ledger is CORRECT -- that a Lean theorem, proved, is the
proposition our model assumes. That is a human reading of two texts (`docs/LEAN-SEAM.md`
§1), and this gate cannot do it any more than `make leanseam` can. Together the two say:
the cited text has not moved (leanseam) AND what it says is proved without `sorry` or an
extra axiom (this). Whether it is the RIGHT theorem is still §1's human claim.

It also asserts nothing about the Lean peer's OTHER libraries (`EntityCore`, the exes) --
only the proof track, which is the only part the seam cites.

Usage:
  tools/lean-proof.py --keystone ../entity-core-keystone            # green
  tools/lean-proof.py --keystone ../entity-core-keystone --neg      # negative controls
  tools/lean-proof.py --variant neg-sorry                           # one control

Exit status: 0 iff the run produced EXACTLY the declared outcome for its variant.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEAN_ROOT = "protocol-generator/lean"
EXPECT_FILE = os.path.join(HERE, "lean", "proof-gate.expect")
LEDGER = os.path.join(HERE, "docs", "LEAN-SEAM.md")
SCRATCH = os.path.join(HERE, "lean", "_work")

# Lean's three standard axioms. Everything else -- `sorryAx`, or a hand-written `axiom` --
# is a hole in the proof, and no row of proof-gate.expect may declare one (parse-time
# error): a gate you can declare your way out of is not a gate.
TRUSTED_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}

CAP_PROOFS = "proofs/EntityCoreProofs/CapabilityProofs.lean"

# The anchor both mutation controls rewrite: `matchesSeg_refl`, cited by ledger row L6 and
# depended on by several others, so a hole in it propagates -- which is itself part of what
# the controls demonstrate. Matched as an exact substring: if keystone's text changes, the
# control FAILS TO APPLY and says so, rather than silently mutating something else. (The
# same text is digest-pinned by `make leanseam`, so a change is caught on both sides.)
_ANCHOR = '''theorem matchesSeg_refl : ∀ x, matchesSeg x x = true := by
  intro x
  induction x with
  | nil => rfl
  | cons xh xt ih =>
    by_cases h : xh = "*"
    · subst h
      cases xt with
      | nil => rfl
      | cons _ _ => rw [ms_lead]; exact ih
    · rw [ms_lit h, Bool.and_eq_true]; exact ⟨beq_iff_eq.mpr rfl, ih⟩'''

# ── NEGATIVE CONTROLS, with the verdict each MUST produce ────────────────────────────────
# Every control declares its expected reason codes AND, per code, the exact set of
# DECLARATIONS (or error text) that must carry it. The run must produce that set exactly --
# same count, same identities, no extras.
#
# WHY IDENTITIES AND NOT COUNTS. The first version of this table declared counts alone
# (`SORRY_AX: 3`). Audited the same session and it is below the standard this repo earned
# three times over on its other engines: `TM_NEG_EXPECT` declares a verdict PER LEMMA and
# `SPIN_NEG` a failure signature per row, precisely because "three things broke" cannot
# distinguish "the three I injected" from "three others". Three Tamarin controls once
# falsified their own reachability lemma alongside their target and a count could not see
# it. A count is a symptom of the outcome; the identities are the outcome.
#
# Read the five together and they are the D13 demonstration in executable form:
# neg-broken is what an exit-status grader catches; neg-sorry and neg-axiom are what it
# does not; neg-ungate and neg-dropfile are the two ways to make the gate stop looking.
CONTROLS: dict[str, dict] = {
    # A `sorry` in a cited theorem. lake exits 0 and prints "Build completed successfully".
    # THREE declarations, not one: the hole propagates two hops (matchesSeg_refl ->
    # isAttenuated_refl -> allowed_chain_leaf_atten_root), so the axiom check catches
    # transitive contamination and not merely the declaration that was edited. All three are
    # MEASURED, not reasoned -- the first draft declared two of them and the run said three.
    "neg-sorry": {
        "file": CAP_PROOFS,
        "old": _ANCHOR,
        "new": "theorem matchesSeg_refl : ∀ x, matchesSeg x x = true := by\n  sorry",
        "expect": {
            "SORRY_WARNING": ["CapabilityProofs.lean"],
            # THREE, and the identities matter: the hole propagates two hops from the one
            # theorem that was edited. Declared as 2 and measured as 3 on the first run.
            "SORRY_AX": ["Proofs.matchesSeg_refl ", "Proofs.isAttenuated_refl ",
                         "Proofs.allowed_chain_leaf_atten_root "],
        },
        "why": "a `sorry` is a WARNING in Lean; lake exits 0. Exit status cannot see it.",
    },
    # A hand-written axiom standing in for the proof: no warning at all, exit 0, and the
    # ONLY trace is the axiom set. This is the failure mode with no symptom. Same three
    # declarations as neg-sorry, by the same propagation.
    "neg-axiom": {
        "file": CAP_PROOFS,
        "old": _ANCHOR,
        "new": (
            "axiom matchesSeg_refl_ax : ∀ x, matchesSeg x x = true\n"
            "theorem matchesSeg_refl : ∀ x, matchesSeg x x = true := matchesSeg_refl_ax"
        ),
        "expect": {
            "UNTRUSTED_AXIOM": ["Proofs.matchesSeg_refl ", "Proofs.isAttenuated_refl ",
                                "Proofs.allowed_chain_leaf_atten_root "],
        },
        "why": "an `axiom` produces no warning and no error; only #print axioms shows it.",
    },
    # Delete the gate line itself. If the grader trusted `grep -c sorryAx` over the build
    # log, this variant would score GREEN -- no gate line, no sorryAx to find. It fails
    # because the DECLARED set of gated names must appear, which is the same move as
    # "an undeclared query is an ungraded query" in the prover tables.
    "neg-ungate": {
        "file": CAP_PROOFS,
        "old": "#print axioms matchesSeg_refl\n",
        "new": "",
        "expect": {
            "MISSING_GATE": ["Proofs.matchesSeg_refl "],
            "LEDGER_UNCOVERED": ["matchesSeg_refl "],
        },
        "why": "removing the honesty gate must fail; a silent gate asserts nothing.",
    },
    # The one failure an exit-status grader DOES catch, kept as a control precisely so the
    # comparison is on the record rather than asserted.
    "neg-broken": {
        "file": CAP_PROOFS,
        "old": "theorem matchesSeg_refl : ∀ x, matchesSeg x x = true := by\n  intro x\n",
        "new": (
            "theorem matchesSeg_refl : ∀ x, matchesSeg x x = true := by\n"
            "  intro x\n  exact absurd rfl (by intro h; exact h)\n"
        ),
        # The error TEXT is declared, not merely "something failed": any typo anywhere in
        # the file would satisfy `BUILD_ERROR x1`, including one that never reached the
        # proof this control targets.
        "expect": {
            "BUILD_ERROR": [["CapabilityProofs.lean", "Type mismatch"]],
            "NO_COMPLETION": ["Build completed successfully"],
        },
        "why": "a failed proof IS an error and exits 1 -- one failure mode in three.",
    },
    # A whole proof FILE dropped from the library root. Distinct from neg-ungate: there the
    # theorem is built and ungated, here it is never built at all, and the ledger-facing
    # symptom is different again (SortProofs carries no ledger row, so LEDGER_UNCOVERED does
    # NOT fire -- which is why the file-level case needs its own control rather than being
    # assumed covered by the declaration-level one).
    "neg-dropfile": {
        "file": "proofs/EntityCoreProofs.lean",
        "old": "import EntityCoreProofs.SortProofs\n",
        "new": "",
        "expect": {
            "MISSING_GATE": ["Codec.Proofs.lexCmp_self ", "Codec.Proofs.keyCmp_self ",
                             "Codec.Proofs.keyLe_refl "],
        },
        "why": "a proof file dropped from the root builds clean and gates nothing.",
    },
}

AXIOM_LINE = re.compile(
    r"^info: (?P<file>\S+?):\d+:\d+: '(?P<name>[^']+)' depends on axioms: \[(?P<ax>[^\]]*)\]",
    re.M | re.S,
)
WARN_LINE = re.compile(r"^warning: (.*)$", re.M)
ERR_LINE = re.compile(r"^error: (.*)$", re.M)
SORRY_WARN = re.compile(r"declaration uses .?sorry")
PIN_BLOCK = re.compile(r"^```leanseam-pins$(.*?)^```$", re.M | re.S)


class Fail(Exception):
    pass


def read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def parse_expect() -> tuple[dict[str, set[str]], list[str]]:
    """-> ({full declaration name: declared axiom set}, [declared warning substrings])

    lean/proof-gate.expect is the declaration. Format, `|`-separated:
        gate|<file>|<full lean name>|<comma-separated axioms, or `-` for none>
        warn|<substring that must match a warning line>|<why it is tolerated>
    """
    gates: dict[str, set[str]] = {}
    warns: list[str] = []
    for lineno, raw in enumerate(read(EXPECT_FILE).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if parts[0] == "gate":
            if len(parts) != 4:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected 4 `|` fields, got {len(parts)}")
            _, _f, name, ax = parts
            axioms = set() if ax == "-" else {a.strip() for a in ax.split(",") if a.strip()}
            bad = axioms - TRUSTED_AXIOMS
            if bad:
                raise Fail(
                    f"{EXPECT_FILE}:{lineno}: declares untrusted axiom(s) {sorted(bad)} for "
                    f"{name}. A hole cannot be declared away -- fix the proof, or take the "
                    f"row out of the ledger and say what is unproved."
                )
            if name in gates:
                raise Fail(f"{EXPECT_FILE}:{lineno}: {name} declared twice")
            gates[name] = axioms
        elif parts[0] == "warn":
            if len(parts) != 3:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected `warn|<substring>|<why>`")
            warns.append(parts[1])
        else:
            raise Fail(f"{EXPECT_FILE}:{lineno}: unknown row kind {parts[0]!r}")
    if not gates:
        raise Fail(f"{EXPECT_FILE}: declares no gates -- nothing would be graded")
    return gates, warns


def ledger_names() -> set[str]:
    """The theorem names docs/LEAN-SEAM.md pins, discharging AND rejected.

    A rejected pin is a correspondence considered and found not to hold; it still names a
    real theorem, and it is required to be proved for the same reason -- a stale rejection
    is as misleading as a stale citation.
    """
    m = PIN_BLOCK.search(read(LEDGER))
    if not m:
        raise Fail(f"{LEDGER}: no ```leanseam-pins block")
    names = set()
    for raw in m.group(1).splitlines():
        parts = raw.strip().split()
        if len(parts) == 4 and parts[0] in ("theorem", "rejected"):
            names.add(parts[1])
    if not names:
        raise Fail(f"{LEDGER}: pin block names no theorems")
    return names


def lean_tree(keystone: str) -> str:
    # Resolved against the REPO ROOT, never the caller's cwd: this runs from the root
    # Makefile and from lean/Makefile, and a path that means two different directories
    # depending on which one invoked it is a trap with no upside.
    if not os.path.isabs(keystone):
        keystone = os.path.join(HERE, keystone)
    path = os.path.join(keystone, LEAN_ROOT)
    if not os.path.isdir(path):
        raise Fail(
            f"no Lean tree at {path}\n"
            "  This gate builds the proofs the seam ledger cites, in the peer that ships\n"
            "  them. Without that checkout there is nothing to check, so it FAILS rather\n"
            "  than skips -- a skip would report green for proofs nobody ran:\n"
            "      make leanproof KEYSTONE=/path/to/entity-core-keystone"
        )
    return path


def podman_run(image: str, workdir: str, cmd: str, caps: list[str]) -> tuple[int, str]:
    """One container, no network. `:Z` is correct here: lean/_work is owned by this image
    alone (AGENTS.md -- lowercase `:z` is for directories two images share)."""
    argv = [
        "podman", "run", "--rm", "--network=none", *caps,
        "-v", f"{workdir}:/work:Z", "-w", "/work", image, "bash", "-lc", cmd,
    ]
    p = subprocess.run(argv, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def prepare(src: str, variant: str) -> str:
    """Copy the peer's Lean tree into a scratch worktree and apply the variant's mutation.

    The source is never written to: keystone is another repo's tree and this repo does not
    reach into it. `.lake` is dropped so every run is a CLEAN build -- a cached build is
    a different experiment from the one the gate claims to run.
    """
    dst = os.path.join(SCRATCH, variant)
    shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(SCRATCH, exist_ok=True)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".lake"))
    if variant == "green":
        return dst
    spec = CONTROLS[variant]
    path = os.path.join(dst, spec["file"])
    text = read(path)
    if spec["old"] not in text:
        raise Fail(
            f"control {variant}: its anchor text is not in {spec['file']}.\n"
            "  The control is pinned to the peer's source; if that source changed, the\n"
            "  control must be re-derived against the new text -- NOT loosened. (`make\n"
            "  leanseam` pins the same file by digest and will be red for the same reason.)"
        )
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text.replace(spec["old"], spec["new"], 1))
    return dst


def grade(out: str, rc: int, gates: dict[str, set[str]], warns: list[str],
          ledger: set[str]) -> tuple[dict[str, list[str]], list[str]]:
    """-> ({reason code: [findings]}, human-readable detail lines).

    An empty dict is a clean proof. Findings are kept as TEXT, not counted, because the
    controls are graded on WHICH declarations carry each code -- see the CONTROLS table.
    """
    codes: dict[str, list[str]] = {}
    detail: list[str] = []

    def hit(code: str, msg: str) -> None:
        codes.setdefault(code, []).append(msg)
        detail.append(f"{code}: {msg}")

    errors = ERR_LINE.findall(out)
    if rc != 0 or errors:
        hit("BUILD_ERROR", f"exit {rc}" + (f"; first error: {errors[0]}" if errors else ""))
    if "Build completed successfully" not in out:
        hit("NO_COMPLETION", "lake did not print `Build completed successfully`")
    # A failed build short-circuits per-declaration grading: no olean, no axiom lines, and
    # 30-odd MISSING_GATEs would say only "the build failed" a second time.
    if "BUILD_ERROR" in codes:
        return codes, detail

    for w in WARN_LINE.findall(out):
        if SORRY_WARN.search(w):
            hit("SORRY_WARNING", w.strip())
        elif not any(d in w for d in warns):
            hit("UNDECLARED_WARNING", w.strip())

    seen: dict[str, set[str]] = {}
    for m in AXIOM_LINE.finditer(out):
        name = m.group("name")
        axioms = {a.strip() for a in m.group("ax").replace("\n", " ").split(",") if a.strip()}
        seen[name] = axioms
        if "sorryAx" in axioms:
            hit("SORRY_AX", f"{name} depends on sorryAx -- the proof has a hole")
        elif axioms - TRUSTED_AXIOMS:
            hit("UNTRUSTED_AXIOM", f"{name} depends on {sorted(axioms - TRUSTED_AXIOMS)}")
        elif name not in gates:
            hit("UNDECLARED_GATE", f"{name} is gated but declared in no expect row")
        elif axioms != gates[name]:
            hit("AXIOM_SET_MISMATCH",
                f"{name} declared {sorted(gates[name])}, reported {sorted(axioms)}")

    for name in sorted(gates):
        if name not in seen:
            hit("MISSING_GATE", f"{name} is declared but printed no `#print axioms` line")
    # The ledger tie: short names in the pin block, namespaced names in Lean's output.
    for short in sorted(ledger):
        if not any(n == short or n.endswith("." + short) for n in seen):
            hit("LEDGER_UNCOVERED",
                f"{short} is pinned by docs/LEAN-SEAM.md and no proved gate reports it")
    return codes, detail


def match_declared(codes: dict[str, list[str]],
                   want: dict[str, list[str]]) -> list[str]:
    """Compare the run's findings against a control's DECLARED identities.

    Returns [] iff they agree exactly: every declared code present, every declared
    identity matched by exactly one distinct finding, and no finding left over under any
    code. The pairing is one-to-one on purpose -- two findings that both contain the same
    declared substring must not satisfy two declarations.

    A declared identity is a substring, or a LIST of substrings that must all appear in the
    same finding (used where one finding needs pinning by more than its name -- e.g. a
    build error pinned to both its file and its error kind).
    """
    problems: list[str] = []
    for code in sorted(set(codes) | set(want)):
        got = list(codes.get(code, []))
        need = [t if isinstance(t, list) else [t] for t in want.get(code, [])]
        if not need:
            problems.append(f"UNDECLARED {code} x{len(got)} — the run produced a failure "
                            f"this variant does not declare")
            continue
        unmatched_need = []
        for token in need:
            # NOT `t.strip()`: a trailing space in a declared token is a deliberate word
            # boundary, so `Proofs.matchesSeg_refl ` cannot be satisfied by a finding about
            # `Proofs.matchesSeg_refl_ax`. Stripping here would have thrown that away.
            hit = next((g for g in got if all(t in g for t in token)), None)
            if hit is None:
                unmatched_need.append(" + ".join(t.strip() for t in token))
            else:
                got.remove(hit)
        if unmatched_need:
            problems.append(f"{code}: declared but did not occur: {unmatched_need}")
        if got:
            problems.append(f"{code}: occurred but was not declared: {got}")
    return problems


def run_variant(variant: str, keystone: str, image: str, caps: list[str]) -> int:
    gates, warns = parse_expect()
    ledger = ledger_names()
    src = lean_tree(keystone)

    label = "GREEN" if variant == "green" else "neg control"
    print(f"== Lean proof gate: {variant} ({label}) ==")

    # 1. TOOLCHAIN -- verify with the compiler the peer pins, or not at all.
    pinned = read(os.path.join(src, "lean-toolchain")).strip()
    want = pinned.split(":")[-1].lstrip("v")
    probe = subprocess.run(
        ["podman", "run", "--rm", "--network=none", *caps, image, "bash", "-lc", "lean --version"],
        capture_output=True, text=True,
    )
    rc, ver = probe.returncode, (probe.stdout + probe.stderr).strip()
    # A missing image and a wrong Lean both stop the run, but they are different problems and
    # the fix for one is not the fix for the other. Reporting "toolchain mismatch" for
    # "there is no image" is the same defect as a control that fails for the wrong reason,
    # one level down in the diagnostics -- found by running it with a bogus image name.
    if rc != 0:
        print(f"FAIL: could not run the toolchain image {image!r} at all -- podman said:")
        print(f"      {ver.splitlines()[0] if ver else '(no output)'}")
        print("      This is NOT a verdict about the proofs. Build the image first:")
        print("          make lean-image")
        return 1
    if want not in ver:
        print(f"FAIL: toolchain mismatch. keystone pins {pinned!r}; image reports {ver!r}.")
        print("      Proving with a different Lean than the peer ships is not proving the")
        print("      peer. Re-pin lean/Containerfile's LEAN_VERSION and rebuild the image.")
        return 1
    print(f"   toolchain ok ({ver}; keystone pins {pinned})")

    work = prepare(src, variant)
    rc, out = podman_run(image, work, "lake build EntityCoreProofs", caps)
    codes, detail = grade(out, rc, gates, warns, ledger)

    want_codes = {} if variant == "green" else CONTROLS[variant]["expect"]
    missed = match_declared(codes, want_codes)
    if not missed:
        if variant == "green":
            print(f"   ok ({len(gates)} axiom-gated declarations, every axiom set exactly as")
            print(f"       declared, {len(ledger)} ledger-pinned theorems all proved,")
            print(f"       0 undeclared warnings, build completed)")
        else:
            got = ", ".join(f"{k}x{len(v)}" for k, v in sorted(codes.items()))
            print(f"   ok (failed for its declared reason, on the declared declarations: {got})")
            for d in detail:
                print(f"      {d}")
        return 0

    print(f"FAIL: {variant} did not produce its declared outcome.")
    for m in missed:
        print(f"      {m}")
    for d in detail:
        print(f"      - {d}")
    if variant == "green":
        print("\n      A red GREEN row means the Lean proofs the seam ledger cites no longer")
        print("      hold as declared. Re-read the affected docs/LEAN-SEAM.md rows before")
        print("      touching lean/proof-gate.expect: re-declaring the new axiom set is how")
        print("      this gate would come to assert nothing.")
    else:
        print(f"\n      This control exists to show: {CONTROLS[variant]['why']}")
        print("      A control that fails for a different reason is not a control.")
    print("\n---- lake output ----")
    print(out[-4000:])
    return 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--keystone", default=os.environ.get("KEYSTONE", "../entity-core-keystone"))
    ap.add_argument("--image", default=os.environ.get("LEAN_IMAGE", "entity-lean"))
    ap.add_argument("--variant", default="green", choices=["green", *CONTROLS])
    ap.add_argument("--neg", action="store_true", help="run every negative control")
    ap.add_argument("--caps", default=os.environ.get("PODMAN_RUN_CAPS", ""),
                    help="podman resource caps, passed through from caps.mk")
    args = ap.parse_args()
    caps = args.caps.split()
    variants = list(CONTROLS) if args.neg else [args.variant]
    try:
        worst = 0
        for v in variants:
            worst |= run_variant(v, args.keystone, args.image, caps)
        return worst
    except Fail as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
