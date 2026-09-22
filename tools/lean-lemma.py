#!/usr/bin/env python3
"""lean-lemma — do OUR Lean results about the peer's definitions still hold?

Why this is a separate gate from `leanproof`
--------------------------------------------
`make leanproof` asserts one thing: the proofs `docs/LEAN-SEAM.md` cites, in the sibling
keystone peer, still hold as declared. Its subject is SOMEONE ELSE'S TREE.

This repo now has Lean results of its own -- `lean/lemmas/`, written to answer A-31/K2 --
and they are a different claim about a different artifact. Folding them into `leanproof`
would mean a typo of ours turns the gate that watches keystone red, which is a false
signal on the one gate whose whole job is to report movement in a tree we do not control.
Two claims, two gates. They share a toolchain and a scratch discipline and nothing else.

What this asserts
-----------------
  1. TOOLCHAIN   the Lean version this image resolves equals the version keystone's own
                 `lean-toolchain` pins -- our lemma is about THEIR definitions, so it has
                 to elaborate under the compiler they ship or it is about something else.
  2. INJECTION   every file in lean/lemmas/ is copied into a COPY of the peer's tree and
                 imported from the proofs-library root. The peer's tree is read-only input
                 and is never written to (AGENTS.md: a local fork would make the result a
                 claim about our copy).
  3. BUILD       `lake build EntityCoreProofs` completes: exit 0, no `error:` line, and the
                 positive `Build completed successfully` line present.
  4. AXIOM GATES every `#print axioms` line for a declaration in OUR namespace reports the
                 axiom set DECLARED for it in lean/lemma-gate.expect -- exactly, in both
                 directions. A `sorry` is a WARNING in Lean and lake exits 0; a substituted
                 `axiom` exits 0 with no warning at all. Exit status catches one failure
                 mode in three (docs/LEAN-SEAM.md section 7 records the runs).
  5. EVAL ROWS   the `#eval` output lines must equal the declared set exactly, one to one.
                 This is what makes the A-31 differential a GATED CLAIM rather than a
                 printout: the sweep's own numbers -- 3276 pairs, 108 disagreements, 1521
                 star-free pairs clean -- are published in three documents, and until this
                 existed nothing re-derived them. D15: a derived number is a claim.
  6. SITES       every prose site declared in lemma-gate.expect must still carry its
                 declared claim text, and every number in that text must occur in a
                 declared eval line. That is the `runcount`/`enginecount` shape: a figure
                 this repo published moves when the sweep moves, or the build fails.
  7. WARNINGS    a Lean warning is a build failure unless declared.

What this does NOT assert
-------------------------
  * Anything about keystone's own theorems. `leanproof` grades those; the axiom lines from
    their files are deliberately ignored here, so a change in their tree cannot make this
    gate red for a reason it cannot explain. If both are red, read `leanproof` first.
  * That `mp54` is a faithful transcription of §5.4. It is OUR reading of the pinned text,
    controlled against the spec's own worked examples and nothing stronger -- the 5th wall
    in full (docs/LEAN-SEAM.md section 5). The theorem about `matchesSeg` does not depend
    on it; every claim that mentions `mp54` does.
  * That the SITE list is complete. Nothing can derive the set of documents that quote a
    number. Sites are declared by hand and this tool says so, exactly as `runcount` does.

Usage:
  tools/lean-lemma.py --keystone ../entity-core-keystone           # green
  tools/lean-lemma.py --keystone ../entity-core-keystone --neg     # negative controls
  tools/lean-lemma.py --variant neg-sorry                          # one control

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
EXPECT_FILE = os.path.join(HERE, "lean", "lemma-gate.expect")
LEMMA_DIR = os.path.join(HERE, "lean", "lemmas")
SCRATCH = os.path.join(HERE, "lean", "_work")
PROOFS_ROOT = "proofs/EntityCoreProofs.lean"
PROOFS_DIR = "proofs/EntityCoreProofs"

# Lean's three standard axioms. Everything else -- `sorryAx`, or a hand-written `axiom` --
# is a hole, and no expect row may declare one (parse-time error): a gate you can declare
# your way out of is not a gate.
TRUSTED_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}

# Our declarations live under this namespace. Keystone's do not, which is exactly how the
# two gates stay separable -- see "What this does NOT assert".
OUR_NS = "EntityCoreFormalization."

LEMMA_FILE = "StarFree.lean"

# The whole proof of the headline theorem, as the anchor `neg-sorry` replaces. Pinned as an
# exact substring on purpose: if the proof changes, the control FAILS TO APPLY and says so
# rather than silently mutating something else.
#
# It is the whole proof and not a fragment because the first draft anchored on two lines and
# commented out the remainder of the file, which killed all four gates and both eval rows.
# That variant "failed" -- and it failed for four reasons, none of them the one it exists to
# demonstrate. A control that fails broadly is not a control; found by running it.
_PROOF_ANCHOR = '''  intro path
  induction path with
  | nil =>
    intro pt _
    cases pt with
    | nil => rfl
    | cons b bs => rw [matchesSeg_nil_cons]; simp
  | cons a as ih =>
    intro pt h
    cases pt with
    -- `matchesSeg (a :: as) [] = false` (arm 3) and `(a :: as == []) = false`, definitionally.
    | nil => rfl
    | cons b bs =>
      have h' : (b != "*") = true ∧ starFree bs = true := by
        simpa [starFree, List.all_cons, Bool.and_eq_true] using h
      have hb : b ≠ "*" := by simpa using h'.1
      -- `ms_lit` is keystone's own arm characterization: with a non-`*` pattern head,
      -- neither wildcard arm fires and the match is `head equality && recurse`.
      rw [ms_lit hb, ih bs h'.2]
      simp'''

# ── NEGATIVE CONTROLS, with the verdict each MUST produce ────────────────────────────────
# Identities, never counts: "something broke" cannot distinguish the break we injected from
# a different one that happened to occur (the lesson `TM_NEG_EXPECT` and lean/proof-gate
# both paid for). Every declared identity must be matched by exactly one finding and no
# finding may be left over.
CONTROLS: dict[str, dict] = {
    # A `sorry` in the headline theorem. lake exits 0 and prints "Build completed
    # successfully"; the ONLY trace is the axiom set. THREE declarations, not one: the hole
    # propagates to both corollaries, which is measured, not assumed.
    "neg-sorry": {
        "file": LEMMA_FILE,
        "old": _PROOF_ANCHOR,
        "new": "  sorry",
        "expect": {
            "SORRY_WARNING": ["StarFree.lean"],
            # THREE, and the identities are the outcome: the hole propagates from the one
            # theorem that was edited to both corollaries, because each rewrites with it.
            # MEASURED -- the first draft of this row guessed and the run said which.
            "SORRY_AX": ["A31.matchesSeg_starFree ",
                         "A31.starFree_matches_only_itself ",
                         "A31.matchesSeg_starFree_iff "],
        },
        "why": "a `sorry` is a WARNING in Lean; lake exits 0. Exit status cannot see it.",
    },
    # The differential's own input set, narrowed. Drop the wildcard from the pattern
    # alphabet and every disagreement vanishes -- the sweep goes "clean" while asserting
    # nothing about the class it exists to measure. This is the control that gives the
    # EVAL row teeth, and it is D15's mechanism in the medium this file is about: the
    # numbers still print, they are just about a different question.
    "neg-eval": {
        "file": LEMMA_FILE,
        "old": 'def patAlpha : List String := ["a", "b", "p", "*"]',
        "new": 'def patAlpha : List String := ["a", "b", "p"]',
        # BOTH codes fire, and that pairing is the demonstration: the declared line is
        # gone AND a different, entirely clean-looking line took its place --
        # `pairs=1521 disagree=0 ... interior=0/0`. A sweep that narrowed its own input set
        # does not report an error; it reports SUCCESS about a smaller question.
        "expect": {
            "EVAL_MISMATCH": ["A31 pairs=3276 disagree=108"],
            "EVAL_UNDECLARED": ["A31 pairs=1521 disagree=0"],
        },
        "why": "a sweep whose input set narrowed reports clean; the numbers must be gated.",
    },
    # The one failure an exit-status grader DOES catch, kept so the comparison is on the
    # record rather than asserted.
    "neg-broken": {
        "file": LEMMA_FILE,
        "old": "  exact eq_of_beq hm",
        "new": "  exact hm",
        "expect": {
            "BUILD_ERROR": [["StarFree.lean", "Type mismatch"]],
            "NO_COMPLETION": ["Build completed successfully"],
        },
        "why": "a failed proof IS an error and exits 1 -- one failure mode in three.",
    },
    # The gate line deleted. If this graded `grep -c sorryAx` over the log, no gate line
    # would mean no finding and the variant would score GREEN.
    "neg-ungate": {
        "file": LEMMA_FILE,
        "old": "#print axioms matchesSeg_starFree\n",
        "new": "",
        "expect": {
            "MISSING_GATE": ["A31.matchesSeg_starFree "],
        },
        "why": "removing the honesty gate must fail; a silent gate asserts nothing.",
    },
}

AXIOM_LINE = re.compile(
    r"^info: (?P<file>\S+?):\d+:\d+: '(?P<name>[^']+)' depends on axioms: \[(?P<ax>[^\]]*)\]",
    re.M | re.S,
)
# `#eval` of a String prints it quoted, on one `info:` line.
EVAL_LINE = re.compile(r'^info: (?P<file>\S+?):\d+:\d+: "(?P<out>[^"]*)"$', re.M)
WARN_LINE = re.compile(r"^warning: (.*)$", re.M)
ERR_LINE = re.compile(r"^error: (.*)$", re.M)
SORRY_WARN = re.compile(r"declaration uses .?sorry")
NUMBER = re.compile(r"\d+")


class Fail(Exception):
    pass


def read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def parse_expect() -> tuple[dict[str, set[str]], list[str], list[str], list[tuple[str, str]]]:
    """-> ({declaration: axiom set}, [declared warnings], [expected #eval lines], [sites])

    lean/lemma-gate.expect is the declaration. Format, `|`-separated:
        gate|<full lean name>|<comma-separated axioms, or `-` for none>
        eval|<the exact string the #eval must print>
        warn|<substring that must match a warning line>|<why it is tolerated>
        site|<repo-relative path>|<claim text that must occur verbatim>
    """
    gates: dict[str, set[str]] = {}
    warns: list[str] = []
    evals: list[str] = []
    sites: list[tuple[str, str]] = []
    for lineno, raw in enumerate(read(EXPECT_FILE).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # NOT stripped per field: an `eval` payload and a `site` claim are VERBATIM text,
        # and a markdown table row (`| pairs compared | **3276** |`) is mostly the spaces.
        # Stripping each field would have made every table-shaped site unmatchable, which
        # the gate would have reported as "the document no longer says this" -- a control
        # failing for the wrong reason, found by running it.
        parts = line.split("|")
        kind = parts[0].strip()
        if kind == "gate":
            parts = [p.strip() for p in parts]
            if len(parts) != 3:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected `gate|<name>|<axioms>`")
            _, name, ax = parts
            axioms = set() if ax == "-" else {a.strip() for a in ax.split(",") if a.strip()}
            bad = axioms - TRUSTED_AXIOMS
            if bad:
                raise Fail(
                    f"{EXPECT_FILE}:{lineno}: declares untrusted axiom(s) {sorted(bad)} for "
                    f"{name}. A hole cannot be declared away -- fix the proof, or withdraw "
                    f"the claim and say what is unproved."
                )
            if not name.startswith(OUR_NS):
                raise Fail(
                    f"{EXPECT_FILE}:{lineno}: {name} is not under {OUR_NS!r}. This gate "
                    f"grades OUR declarations; keystone's are `make leanproof`'s subject "
                    f"and grading them here would make one tree's change red in two places."
                )
            if name in gates:
                raise Fail(f"{EXPECT_FILE}:{lineno}: {name} declared twice")
            gates[name] = axioms
        elif kind == "eval":
            if len(parts) < 2:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected `eval|<expected output>`")
            evals.append("|".join(parts[1:]))
        elif kind == "warn":
            if len(parts) != 3:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected `warn|<substring>|<why>`")
            warns.append(parts[1].strip())
        elif kind == "site":
            if len(parts) < 3:
                raise Fail(f"{EXPECT_FILE}:{lineno}: expected `site|<path>|<claim text>`")
            sites.append((parts[1].strip(), "|".join(parts[2:])))
        else:
            raise Fail(f"{EXPECT_FILE}:{lineno}: unknown row kind {kind!r}")
    if not gates:
        raise Fail(f"{EXPECT_FILE}: declares no gates -- nothing would be graded")
    if not evals:
        raise Fail(f"{EXPECT_FILE}: declares no eval rows -- the sweep would be a printout")
    return gates, warns, evals, sites


def lean_tree(keystone: str) -> str:
    if not os.path.isabs(keystone):
        keystone = os.path.join(HERE, keystone)
    path = os.path.join(keystone, LEAN_ROOT)
    if not os.path.isdir(path):
        raise Fail(
            f"no Lean tree at {path}\n"
            "  Our lemmas are about the peer's OWN definitions, imported from the peer's\n"
            "  own tree. Without that checkout there is nothing to prove them against, so\n"
            "  this FAILS rather than skips -- a skip would report green for a theorem\n"
            "  nobody elaborated:\n"
            "      make leanlemma KEYSTONE=/path/to/entity-core-keystone"
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
    """Copy the peer's Lean tree, inject lean/lemmas/, then apply the variant's mutation.

    The source is never written to. `.lake` is dropped so every run is a CLEAN build --
    a cached build is a different experiment from the one the gate claims to run.
    """
    dst = os.path.join(SCRATCH, "lemma-" + variant)
    shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(SCRATCH, exist_ok=True)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".lake"))

    names = sorted(f for f in os.listdir(LEMMA_DIR) if f.endswith(".lean"))
    if not names:
        raise Fail(f"{LEMMA_DIR}: no .lean files -- this gate would build nothing")
    root = os.path.join(dst, PROOFS_ROOT)
    with open(root, "a", encoding="utf-8") as fh:
        for n in names:
            shutil.copyfile(os.path.join(LEMMA_DIR, n), os.path.join(dst, PROOFS_DIR, n))
            fh.write(f"import EntityCoreProofs.{n[:-len('.lean')]}\n")

    if variant == "green":
        return dst
    spec = CONTROLS[variant]
    path = os.path.join(dst, PROOFS_DIR, spec["file"])
    text = read(path)
    if spec["old"] not in text:
        raise Fail(
            f"control {variant}: its anchor text is not in lean/lemmas/{spec['file']}.\n"
            "  The control is pinned to the source it mutates; if that source changed, the\n"
            "  control must be RE-DERIVED against the new text, not loosened."
        )
    text = text.replace(spec["old"], spec["new"], 1)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return dst


def check_sites(sites: list[tuple[str, str]], evals: list[str],
                reader=None) -> list[str]:
    """Every declared prose site still carries its claim, and every NUMBER in that claim
    occurs in a declared eval line.

    The second half is what makes this more than a grep: a site could keep its sentence and
    have its figures go stale, which is precisely how three artifacts in this repo went
    wrong while their gates stayed green. It does NOT assert the sentence around the number
    is a correct reading of the sweep -- that is a human claim, as always.
    """
    findings: list[str] = []
    corpus = " ".join(evals)
    known = set(NUMBER.findall(corpus))
    for path, claim in sites:
        full = os.path.join(HERE, path)
        if reader is None:
            if not os.path.isfile(full):
                findings.append(f"SITE_MISSING: {path} does not exist")
                continue
            text = read(full)
        else:
            text = reader(path)
            if text is None:
                findings.append(f"SITE_MISSING: {path} does not exist")
                continue
        if claim not in text:
            findings.append(f"SITE_STALE: {path} no longer states: {claim!r}")
            continue
        unknown = [n for n in NUMBER.findall(claim) if n not in known]
        if unknown:
            findings.append(
                f"SITE_FIGURE: {path} states {unknown} which no declared eval line produces"
            )
    return findings


def grade(out: str, rc: int, gates: dict[str, set[str]], warns: list[str],
          evals: list[str], sites: list[tuple[str, str]]) -> tuple[dict[str, list[str]], list[str]]:
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
    if "BUILD_ERROR" in codes:
        # No olean, no axiom lines, no evals: 30-odd downstream findings would say only
        # "the build failed" a second time.
        return codes, detail

    for w in WARN_LINE.findall(out):
        if SORRY_WARN.search(w):
            hit("SORRY_WARNING", w.strip())
        elif not any(d in w for d in warns):
            hit("UNDECLARED_WARNING", w.strip())

    seen: dict[str, set[str]] = {}
    for m in AXIOM_LINE.finditer(out):
        name = m.group("name")
        if not name.startswith(OUR_NS):
            continue  # keystone's own gates are `make leanproof`'s subject, not ours
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

    # EVAL: one-to-one against the declared set. An extra line is as much a failure as a
    # missing one -- a sweep that grew a row nobody read is the shape this gate exists for.
    got = [m.group("out") for m in EVAL_LINE.finditer(out)]
    for want in evals:
        if want in got:
            got.remove(want)
        else:
            hit("EVAL_MISMATCH", f"declared but not printed: {want}")
    for extra in got:
        hit("EVAL_UNDECLARED", f"printed but declared nowhere: {extra}")

    for f in check_sites(sites, evals):
        hit(f.split(":", 1)[0], f.split(":", 1)[1].strip())
    return codes, detail


def selftest_sites(sites: list[tuple[str, str]], evals: list[str]) -> int:
    """`neg-site` -- the teeth-test for check 6, which no build-mutating control can reach.

    The `site` rows are the only part of this gate whose input is THIS repo's documents
    rather than the scratch build, so breaking them means perturbing a document -- which we
    do in memory, never on disk. Three ways a site row can stop asserting, and each must be
    caught by its own code:

        deleted   the document no longer carries the claim                -> SITE_STALE
        stale     the claim carries a figure no eval line produces        -> SITE_FIGURE
        moved     the declared path is gone                               -> SITE_MISSING

    Without this the site rows would be the one check in the file that had never been
    observed failing -- and a tripwire nobody has fired reports a clean pass forever
    (`retractcheck`'s own reason for carrying a witness per row).
    """
    print("== Lean lemma gate: neg-site (neg control) ==")
    print("   no build: this control perturbs the declared prose sites IN MEMORY.")
    problems: list[str] = []
    for path, claim in sites:
        full = os.path.join(HERE, path)
        text = read(full)

        got = check_sites([(path, claim)], evals, reader=lambda _p: text.replace(claim, "", 1))
        if not any(g.startswith("SITE_STALE") for g in got):
            problems.append(f"{path}: deleting the claim was NOT caught ({got})")

        nums = NUMBER.findall(claim)
        if not nums:
            problems.append(f"{path}: declared claim carries no figure, so `site` asserts "
                            f"only that a sentence exists -- use a claim with a number")
        else:
            # A figure no eval line produces. 999999 is chosen to be absent from the sweep
            # rather than assumed absent: it is asserted below.
            if "999999" in " ".join(evals):
                problems.append("the sentinel figure 999999 occurs in an eval line")
            bogus = claim.replace(nums[0], "999999", 1)
            got = check_sites([(path, bogus)], evals,
                              reader=lambda _p: text.replace(claim, bogus, 1))
            if not any(g.startswith("SITE_FIGURE") for g in got):
                problems.append(f"{path}: a stale figure was NOT caught ({got})")

        got = check_sites([(path + ".gone", claim)], evals, reader=lambda _p: None)
        if not any(g.startswith("SITE_MISSING") for g in got):
            problems.append(f"{path}: a moved site was NOT caught ({got})")

    if problems:
        print("FAIL: neg-site did not produce its declared outcome.")
        for p in problems:
            print(f"      {p}")
        print("\n      This control exists to show: a `site` row that cannot fail asserts")
        print("      nothing, and a figure goes stale in prose nothing re-reads (D15).")
        return 1
    print(f"   ok (all 3 failure modes caught on each of {len(sites)} declared site(s): "
          f"deleted claim, stale figure, moved file)")
    return 0


def match_declared(codes: dict[str, list[str]], want: dict[str, list]) -> list[str]:
    """[] iff the run's findings are EXACTLY the control's declared identities: every
    declared code present, every declared identity matched by exactly one finding, nothing
    left over. Pairing is one-to-one so two findings cannot satisfy two declarations by
    sharing a substring."""
    problems: list[str] = []
    for code in sorted(set(codes) | set(want)):
        got = list(codes.get(code, []))
        need = [t if isinstance(t, list) else [t] for t in want.get(code, [])]
        if not need:
            problems.append(f"UNDECLARED {code} x{len(got)} -- the run produced a failure "
                            f"this variant does not declare: {got}")
            continue
        unmatched = []
        for token in need:
            # NOT stripped: a trailing space in a declared token is a word boundary, so
            # `matchesSeg_starFree ` cannot be satisfied by `matchesSeg_starFree_iff`.
            hit = next((g for g in got if all(t in g for t in token)), None)
            if hit is None:
                unmatched.append(" + ".join(t.strip() for t in token))
            else:
                got.remove(hit)
        if unmatched:
            problems.append(f"{code}: declared but did not occur: {unmatched}")
        if got:
            problems.append(f"{code}: occurred but was not declared: {got}")
    return problems


def run_variant(variant: str, keystone: str, image: str, caps: list[str]) -> int:
    gates, warns, evals, sites = parse_expect()
    if variant == "neg-site":
        return selftest_sites(sites, evals)
    src = lean_tree(keystone)

    label = "GREEN" if variant == "green" else "neg control"
    print(f"== Lean lemma gate: {variant} ({label}) ==")

    pinned = read(os.path.join(src, "lean-toolchain")).strip()
    want = pinned.split(":")[-1].lstrip("v")
    probe = subprocess.run(
        ["podman", "run", "--rm", "--network=none", *caps, image, "bash", "-lc", "lean --version"],
        capture_output=True, text=True,
    )
    rc, ver = probe.returncode, (probe.stdout + probe.stderr).strip()
    if rc != 0:
        print(f"FAIL: could not run the toolchain image {image!r} at all -- podman said:")
        print(f"      {ver.splitlines()[0] if ver else '(no output)'}")
        print("      This is NOT a verdict about the lemmas. Build the image first:")
        print("          make lean-image")
        return 1
    if want not in ver:
        print(f"FAIL: toolchain mismatch. keystone pins {pinned!r}; image reports {ver!r}.")
        print("      Our lemma is about THEIR definitions; elaborating it under a different")
        print("      Lean is a theorem about a different artifact.")
        return 1
    print(f"   toolchain ok ({ver}; keystone pins {pinned})")

    work = prepare(src, variant)
    rc, out = podman_run(image, work, "lake build EntityCoreProofs", caps)
    codes, detail = grade(out, rc, gates, warns, evals, sites)

    want_codes = {} if variant == "green" else CONTROLS[variant]["expect"]
    missed = match_declared(codes, want_codes)
    if not missed:
        if variant == "green":
            print(f"   ok ({len(gates)} axiom-gated declarations, every axiom set exactly as")
            print(f"       declared, {len(evals)} eval row(s) exact, {len(sites)} prose site(s)")
            print(f"       still stating a figure the sweep produces, build completed)")
            for e in evals:
                print(f"      {e}")
        else:
            got = ", ".join(f"{k}x{len(v)}" for k, v in sorted(codes.items()))
            print(f"   ok (failed for its declared reason, on the declared identities: {got})")
            for d in detail:
                print(f"      {d}")
        return 0

    print(f"FAIL: {variant} did not produce its declared outcome.")
    for m in missed:
        print(f"      {m}")
    for d in detail:
        print(f"      - {d}")
    if variant == "green":
        print("\n      A red GREEN row means one of: our lemma no longer holds against the")
        print("      peer's current definitions (read `make leanseam` -- did their text")
        print("      move?); the differential's numbers moved; or a document still states a")
        print("      figure the sweep no longer produces. Re-deriving the expect file to")
        print("      make it pass is how this gate would come to assert nothing -- the")
        print("      packet those numbers are in has already been sent.")
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
    ap.add_argument("--variant", default="green", choices=["green", *CONTROLS, "neg-site"])
    ap.add_argument("--neg", action="store_true", help="run every negative control")
    ap.add_argument("--caps", default=os.environ.get("PODMAN_RUN_CAPS", ""))
    args = ap.parse_args()
    caps = args.caps.split()
    variants = [*CONTROLS, "neg-site"] if args.neg else [args.variant]
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
