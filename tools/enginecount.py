#!/usr/bin/env python3
"""enginecount — is every published claim carried by the number of ENGINES we say it is?

`make enginecount`. The enforcement point for AGENTS.md **D16** (two independent engines per
claim, and a one-engine claim declares itself).

WHY THIS EXISTS, and it is D15's mechanism in an eleventh medium: a derived number is a claim.
"Five of the nine extension modules rest on two engines" was written into `AGENTS.md` by hand
on 2026-09-08, was correct that day, and was stale the next morning — the same failure as the
run total (three times in one week), the ledger row counts (four times) and the coverage pair.
Nothing could catch it, because the corroboration ledger existed only as a sentence.

D13 — WHAT DOES THIS ASSERT?
  * Every model file on a protocol track appears in exactly ONE subject row of
    `docs/CORROBORATION.md`, and every declared file exists (both directions, `trackcheck`'s
    shape). A subject nobody declared fails; a declared file that has been deleted fails.
  * The engine set on each row equals the engines DERIVED FROM THE GREEN GATE TABLES for that
    subject's files — not from the files' existence.
  * Every subject with fewer than two engines is declared in the single-engine section WITH a
    reason, and that list matches the derived one in both directions.
  * Every declared prose site states the derived corroboration pair.

WHAT ELSE PRODUCES THIS RESULT — the question that decided the derivation:
  A FILE EXISTING IS NOT AN ENGINE CHECKING ANYTHING. `tamarin/BindingReplayBug.spthy` exists
  and there is no `BindingReplay.spthy`: Tamarin has a NEGATIVE CONTROL on that subject and no
  green. Counting engines by file extension would have published "ProVerif and Tamarin both
  carry the replay result" on the strength of a file whose entire job is to fail. So an engine
  counts for a subject only if that engine's GREEN table has a row naming one of the subject's
  files. Controls, witnesses and finding rows do not corroborate anything: they are claims
  about what breaks, not about what holds.

WHAT THIS DOES *NOT* ASSERT, said out loud rather than left to be assumed:
  * That two engines are INDEPENDENT of the transcription. They are not. Two models of one
    spec section written by one author from one reading share that reading, and a misreading
    survives both — the 5th wall (`docs/ASSURANCE-MAP.md`), which no engine moves.
  * That the two engines check the same PROPERTY. `AttestIndex` and `AttestIndexApalache` are
    verified to be about the same section by `make coverage`, and about the same claim by a
    human reading the two files. This gate counts engines.
  * That a subject grouping is CORRECT. Membership is a human's declaration, exactly as
    `TRACKS.toml`'s is.

Host python3 only. No third-party imports, no network.
"""

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "docs" / "CORROBORATION.md"

# ── which engine a model file belongs to ────────────────────────────────────────────────
# Declared here rather than inferred per call site, so the mapping is one readable table.
def engine_of(path: str):
    if path.endswith(".pml"):
        return "Spin"
    if path.endswith(".pv"):
        return "ProVerif"
    if path.endswith(".spthy"):
        return "Tamarin"
    if path.endswith("Apalache.tla"):
        return "Apalache"
    if path.endswith(".tla"):
        return "TLC"
    return None


# ── the GREEN tables, per engine ────────────────────────────────────────────────────────
# Each entry: (makefile, variable names, how to get the module name out of a row).
# A row's first `|`- or space-separated field is the module in every one of these tables.
GREEN_TABLES = [
    # TLC_GREEN_PAIRS is in this list and it is the reason the first draft of this gate
    # reported `CoreMapFree` as having no engine at all: its greens are MODULE|INVARIANT rows
    # in a second table, not module names in the first. A green table left out of a gate that
    # counts greens is the input-set failure D15 is about, one artifact over.
    ("tla/Makefile", ["TLC_GREEN", "TLC_GREEN_PAIRS"], "TLC"),
    ("tla/Makefile", ["APALACHE_GREEN", "APALACHE_ENUM_GREEN"], "Apalache"),
    ("spin/Makefile", ["SPIN_GREEN", "SPIN_GREEN_SAFETY", "SPIN_GREEN_N3"], "Spin"),
    ("tamarin/Makefile", ["PV_EXPECT"], "ProVerif"),
    ("tamarin/Makefile", ["TM_EXPECT"], "Tamarin"),
]

# module name -> model file, per engine. The inverse of engine_of, and it is a rule rather
# than a table because every engine's green rows name a module, not a path.
def file_for(engine: str, module: str) -> str:
    return {
        "TLC": f"tla/{module}.tla",
        "Apalache": f"tla/{module}.tla",
        "Spin": f"spin/{module}.pml",
        "ProVerif": f"tamarin/{module}.pv",
        "Tamarin": f"tamarin/{module}.spthy",
    }[engine]


def read_make_var(text: str, var: str):
    """The value of a `VAR := ...` assignment, backslash-continuations joined."""
    m = re.search(rf"^{re.escape(var)}\s*:?=\s*(.*?)(?<!\\)$", text, re.M | re.S)
    if not m:
        return None
    # walk forward over continuation lines
    start = m.start()
    out, i = [], start
    lines = text[start:].splitlines()
    for line in lines:
        stripped = line.rstrip()
        out.append(stripped.rstrip("\\"))
        if not stripped.endswith("\\"):
            break
    joined = " ".join(out)
    joined = joined.split("=", 1)[1]
    # strip comments that made it in (none of these tables interleave them, but be safe)
    return joined


def green_engines():
    """subject-file -> set of engines with at least one GREEN row on it."""
    by_file = {}
    problems = []
    for mk, variables, engine in GREEN_TABLES:
        text = (ROOT / mk).read_text()
        for var in variables:
            raw = read_make_var(text, var)
            if raw is None:
                problems.append(f"{mk}: green table `{var}` not found — has it been renamed?")
                continue
            for row in re.findall(r'"([^"]*)"|(\S+)', raw):
                cell = row[0] or row[1]
                if not cell or cell.startswith("$"):
                    continue
                module = re.split(r"[|\s]", cell)[0]
                if not module:
                    continue
                by_file.setdefault(file_for(engine, module), set()).add(engine)
    return by_file, problems


# ── the ledger ──────────────────────────────────────────────────────────────────────────
ROW = re.compile(
    r"^\|\s*`(?P<subject>[^`]+)`\s*\|\s*(?P<track>\S+)\s*\|\s*(?P<files>[^|]*)\|"
    r"\s*(?P<engines>[^|]*)\|\s*(?P<count>\d+)\s*\|"
)
SINGLE = re.compile(r"^\-\s+\*\*`(?P<subject>[^`]+)`\*\*\s+—\s+(?P<reason>.+\S)\s*$")
SITE = re.compile(r"<!--\s*enginecount-site:\s*(?P<path>\S+)\s*::\s*(?P<anchor>.+?)\s*-->")


def parse_ledger():
    text = LEDGER.read_text()
    rows, singles, sites = [], {}, []
    for line in text.splitlines():
        m = ROW.match(line)
        if m:
            files = re.findall(r"`([^`]+)`", m.group("files"))
            engines = set(re.findall(r"\b(TLC|Apalache|Spin|ProVerif|Tamarin)\b", m.group("engines")))
            rows.append(
                dict(subject=m.group("subject"), track=m.group("track"), files=files,
                     engines=engines, count=int(m.group("count")), line=line)
            )
            continue
        m = SINGLE.match(line)
        if m:
            singles[m.group("subject")] = m.group("reason")
            continue
        m = SITE.search(line)
        if m:
            sites.append((m.group("path"), m.group("anchor")))
    return text, rows, singles, sites


def main() -> int:
    problems = []

    tracks = tomllib.loads((ROOT / "TRACKS.toml").read_text())["track"]
    declared_files = set()
    file_track = {}
    for name, t in tracks.items():
        if t.get("kind") != "protocol":
            continue
        for f in t["models"]:
            declared_files.add(f)
            file_track[f] = name

    derived, tbl_problems = green_engines()
    problems += tbl_problems

    text, rows, singles, sites = parse_ledger()
    if not rows:
        print("FAIL -- docs/CORROBORATION.md has no subject rows. Either the ledger was")
        print("        emptied or the row format changed and this gate now asserts nothing.")
        return 1

    # A. membership, both directions
    seen = {}
    for r in rows:
        for f in r["files"]:
            if f in seen:
                problems.append(f"{f} is claimed by two subjects: `{seen[f]}` and `{r['subject']}`")
            seen[f] = r["subject"]
            if f not in declared_files:
                problems.append(f"`{r['subject']}` lists {f}, which is not a model file in TRACKS.toml")
            elif file_track[f] != r["track"]:
                problems.append(
                    f"`{r['subject']}` is on track {r['track']} but {f} is on {file_track[f]} in TRACKS.toml")
    for f in sorted(declared_files - set(seen)):
        problems.append(
            f"model file in no subject row: {f}\n"
            f"      -> an undeclared file is a claim nothing counts the engines of.")

    # B. the engine set is derived, not declared. EVERY count below reads `r["derived"]`, never
    # `r["engines"]`: the declaration is the thing under test, so nothing may be computed from it.
    for r in rows:
        got = set()
        for f in r["files"]:
            got |= derived.get(f, set())
        r["derived"] = got
        if got != r["engines"]:
            problems.append(
                f"`{r['subject']}` declares {sorted(r['engines']) or ['(none)']} and the GREEN tables "
                f"give {sorted(got) or ['(none)']}"
            )
        if r["count"] != len(got):
            problems.append(f"`{r['subject']}` states {r['count']} engine(s); derived {len(got)}")

    # C. single-engine subjects are declared with a reason.
    # Keyed on the DERIVED engine set, not the declared one. Keying it on the declaration would
    # let a subject escape the exemption requirement by overstating its own engines column — the
    # check would then be reading the claim it exists to test. (Check B catches the overstatement
    # too; this is the same defect refusing to depend on the order the checks happen to run in.)
    derived_single = {r["subject"] for r in rows if len(r["derived"]) < 2}
    for s in sorted(derived_single - set(singles)):
        problems.append(
            f"`{s}` rests on fewer than two engines and is NOT declared in the single-engine\n"
            f"      section. D16: a one-engine claim is allowed and must SAY SO.")
    for s in sorted(set(singles) - derived_single):
        problems.append(
            f"`{s}` is declared single-engine and is no longer: delete the declaration.\n"
            f"      A stale exemption is how a corroborated subject goes on reading as a gap.")

    # D. the published pair
    corroborated = sum(1 for r in rows if len(r["derived"]) >= 2)
    total = len(rows)
    ext = [r for r in rows if r["track"] != "core"]
    ext_corr = sum(1 for r in ext if len(r["derived"]) >= 2)
    # Every `N of M` in the window whose M is one of OUR denominators must have the right N,
    # and at least one must be present. The first draft asked only whether SOME pair matched,
    # which a site stating both pairs satisfies with one of them broken — found by breaking the
    # ledger's own line and watching it pass, because the next line carried the other pair.
    #
    # ⛔ AND THAT FIX CAUGHT A WRONG NUMERATOR AND NOT A WRONG DENOMINATOR, 2026-09-16.
    # `expected` was keyed BY THE DERIVED DENOMINATOR, so the moment a subject was added the
    # total went 35 -> 36 and every site still saying `33 of 35` had a denominator that was no
    # longer "one of ours" — skipped by the `continue` below, invisible. `seen` then came out
    # True anyway off the `9 of 9` extension pair sitting in the same sentence, so neither the
    # wrong-pair branch nor the no-pair branch fired. FOUR live sites, including this gate's own
    # ledger and `AGENTS.md`, read `33 of 35` with `make enginecount` GREEN.
    #
    # Same root cause as `tools/runcount.py`'s README anchor, found the same afternoon: A GATE
    # THAT RECOGNISES A CLAIM BY A VALUE THAT MOVES STOPS RECOGNISING THE CLAIM EXACTLY WHEN
    # THE CLAIM GOES STALE. The fix is to classify a pair by the NOUN beside it — `subjects`,
    # `extension` — which does not move when the number does. The denominator-keyed arm is kept
    # underneath it for pairs written without either noun.
    ANY_PAIR = re.compile(r"\b(\d+)\s+of\s+(?:the\s+)?(\d+)\b")
    expected = {total: corroborated, len(ext): ext_corr}
    # What the noun after a pair says the pair IS. Checked before the denominator arm, because
    # a pair that names its subject is checkable even when BOTH of its numbers are wrong.
    NOUN_WINDOW = 48
    BY_NOUN = [
        (re.compile(r"\bextension\b", re.I), lambda: (ext_corr, len(ext)), "on the extensions"),
        (re.compile(r"\bsubjects?\b", re.I),  lambda: (corroborated, total), "overall"),
    ]

    def window_states_the_pair(win):
        seen, bad = False, []
        for m in ANY_PAIR.finditer(win):
            num, den = int(m.group(1)), int(m.group(2))
            # DENOMINATOR ARM FIRST. A pair whose M is one of ours is unambiguous, and the noun
            # is not: `9 of 9 SUBJECTS carry a green on two engines` is the EXTENSION pair in
            # two canonical documents. Reading the noun first mis-files both of them.
            if den in expected:
                seen = True
                if num != expected[den]:
                    bad.append(f"{num} of {den} (derived {expected[den]} of {den})")
                continue
            # NOUN ARM — only for a pair whose denominator matches nothing, which is precisely
            # the state a stale pair enters when the total moves. This is the hole.
            tail = win[m.end():m.end() + NOUN_WINDOW]
            for rx, want, label in BY_NOUN:
                if rx.search(tail):
                    wn, wd = want()
                    seen = True
                    bad.append(f"{num} of {den} {label} (derived {wn} of {wd})")
                    break
            # A pair with neither our denominator nor a recognised noun is still invisible, and
            # that is stated rather than papered over: this gate reads the pairs it can name.
        return seen, bad
    for path, anchor in sites:
        p = ROOT / path
        if not p.exists():
            problems.append(f"declared prose site does not exist: {path}")
            continue
        lines = p.read_text().splitlines()
        # A WINDOW, not a line. `driftclaim`'s first draft matched raw text line by line and
        # failed six of nine sites on markdown LINE-WRAPPING alone; the same trap is here,
        # because a claim like "only **6 of 9** extension / subjects carry ..." puts the number
        # and the anchor on different lines. One line of context each way, joined.
        hit = [" ".join(lines[max(0, i - 1):i + 2])
               for i, ln in enumerate(lines) if anchor in ln]
        if not hit:
            problems.append(
                f"{path}: the anchor for `{anchor}` is gone — the site stopped making the claim.")
            continue
        results = [window_states_the_pair(w) for w in hit]
        wrong = sorted({b for _, bads in results for b in bads})
        if wrong:
            problems.append(f"{path}: `{anchor}` states " + "; ".join(wrong))
        elif not any(seen for seen, _ in results):
            problems.append(
                f"{path}: `{anchor}` does not state a derived pair "
                f"({corroborated} of {total} overall, {ext_corr} of {len(ext)} on the extension tracks)")

    print(f"== corroboration, derived from the GREEN gate tables ==")
    for tname in sorted({r["track"] for r in rows}):
        trows = [r for r in rows if r["track"] == tname]
        c = sum(1 for r in trows if len(r["derived"]) >= 2)
        print(f"  {tname:14s} {c:3d} of {len(trows):3d} subject(s) on two or more engines")
    print(f"  {'ALL':14s} {corroborated:3d} of {total:3d}")
    print(f"  {'extensions':14s} {ext_corr:3d} of {len(ext):3d}")

    if problems:
        print(f"\nFAIL -- {len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        print("\ndocs/CORROBORATION.md is the declaration; the GREEN tables are the evidence.")
        print("Fix the ledger, or add the engine -- do not relax this script.")
        return 1

    print(f"\nOK -- {total} subjects across {len({r['track'] for r in rows})} protocol track(s);")
    print(f"{corroborated} carry a green on two or more engines, {total - corroborated} are declared single-engine.")
    print("This asserts the ENGINE COUNT per subject, derived from the green tables rather than")
    print("from which files exist. It does NOT assert that two engines are independent of the")
    print("TRANSCRIPTION (they are not -- one author, one reading, one 5th wall), that they check")
    print("the same property, or that a subject grouping is right.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
