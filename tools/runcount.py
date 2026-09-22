#!/usr/bin/env python3
"""runcount — derive the matrix run total from the gate tables, and check the prose.

Why this exists (D15)
---------------------
`make matrix` runs N model-checker invocations. N appears in prose in several files, and
until now it was **hand-derived**: someone counted the gate tables, wrote the number down,
and every later change to a table meant remembering to edit every site. That went wrong
three times in one week -- 238 -> 242 -> 258 across two commits, four sites hand-edited each
time, and two sites missed entirely (`docs/PROPERTIES.md`'s grader inventory sat at 238 for
two matrix growths; `CANONICAL-DOCS.toml`'s capstone blurb sat at 203).

D15 says a derived number is a claim, and a claim needs a gate. This is that gate.

What this asserts
-----------------
  1. DERIVATION  the per-target run counts computed from the gate tables in tla/, spin/ and
                 tamarin/Makefile, and their total.
  2. PROSE       every declared site (below) states that same total.
  3. SLICES      docs/STATUS.md's per-slice table sums to the total AND each row matches the
                 derived per-target figure.

What this does NOT assert
-------------------------
That the runs pass -- that is `make matrix`. That the counted rows are the RIGHT rows: this
counts the declaration tables, so a run that exists but is in no table is invisible here
exactly as it is invisible to the matrix (that failure mode is real -- `BindingReplayBug`
was on disk and in no gate list for a release -- and it is the reason the tables are the
source of truth rather than the file system). And it says nothing about the Lean seam tier,
which is deliberately NOT in the matrix total (docs/LEAN-SEAM.md section 5).

Usage:  tools/runcount.py [--verbose]
Exit status: 0 iff the derivation and every declared site agree.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tomllib

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── HOW EACH TARGET'S RUN COUNT IS DERIVED ──────────────────────────────────────────────
# (label, makefile, variable, how to count, runs per row, note)
#
# "runs per row" is where a table row is not one invocation: an Apalache row is checked
# twice (base case and inductive step), and a Spin green module is run twice (safety, then
# LTL). Those factors are the only hand-entered numbers here and each is stated on the
# target that implements it.
DERIVATION = [
    ("tlc-green (modules)",   "tla/Makefile",     "TLC_GREEN",         "words", 1),
    ("tlc-green (N-peer)",    "tla/Makefile",     "TLC_GREEN_PAIRS",   "rows",  1),
    ("tlc-green (StoreLive)", None,                None,               "const", 1),
    ("tlc-neg",               "tla/Makefile",     "TLC_NEG",           "rows",  1),
    ("tlc-witness",           "tla/Makefile",     "TLC_WITNESS",       "rows",  1),
    # Added 2026-09-07 with AttestLive. Graded like a control, means the opposite: these rows
    # must be violated on a model in which nothing is weakened, because the SPEC's own
    # algorithm fails a contract the spec writes. Counted here as runs like any other — the
    # total is "invocations `make matrix` performs", not "properties that hold".
    ("tlc-finding",           "tla/Makefile",     "TLC_FINDING",       "rows",  1),
    ("apalache-green",        "tla/Makefile",     "APALACHE_GREEN",    "rows",  2),
    ("apalache-neg",          "tla/Makefile",     "APALACHE_NEG",      "rows",  1),
    # Added 2026-09-08. The closure half of the inductive proof -- the strengthening preserves
    # itself. One run per row; the base and step runs are counted above under apalache-green.
    ("apalache-closure",      "tla/Makefile",     "APALACHE_CLOSURE",  "rows",  1),
    # Added 2026-09-08 with the attestation track's second engine. These models have no
    # transitions (`Next == UNCHANGED vars`), so each row is ONE run at --length=0 rather than
    # the base+step pair -- which is why they are a separate table and a separate factor.
    ("apalache-enum-green",   "tla/Makefile",     "APALACHE_ENUM_GREEN",   "rows", 1),
    ("apalache-enum-neg",     "tla/Makefile",     "APALACHE_ENUM_NEG",     "rows", 1),
    ("apalache-enum-finding", "tla/Makefile",     "APALACHE_ENUM_FINDING", "rows", 1),
    # Added 2026-09-09 with the identity track's second engine on IdentityRecovery. The
    # transition-system twin of the row above: a finding row that must be VIOLATED, on a model
    # where nothing is weakened, run BOUNDED from a named Init because the module has real
    # transitions. One run per row.
    #
    # AND ITS ARRIVAL IS WHY `unknown_tables()` BELOW EXISTS. This list is an input set, and an
    # input set is a claim (D15). Adding APALACHE_FINDING to tla/Makefile left `make runcount`
    # GREEN-CAPABLE while silently omitting eight runs from a total published in eight places —
    # the same shape as `enginecount`'s first draft not reading TLC_GREEN_PAIRS, and as the
    # non-recursive globs before that. The tool now fails on a gate table it does not know.
    ("apalache-finding",      "tla/Makefile",     "APALACHE_FINDING",      "rows", 1),
    ("spin green (safety+LTL)", "spin/Makefile",  "SPIN_GREEN",        "words", 2),
    ("spin green (safety)",   "spin/Makefile",    "SPIN_GREEN_SAFETY", "words", 1),
    ("spin green (N=3)",      "spin/Makefile",    "SPIN_GREEN_N3",     "rows",  2),
    ("spin neg",              "spin/Makefile",    "SPIN_NEG",          "rows",  1),
    ("proverif-green",        "tamarin/Makefile", "PV_GREEN",          "words", 1),
    ("proverif-neg",          "tamarin/Makefile", "PV_NEG",            "words", 1),
    ("tamarin-green",         "tamarin/Makefile", "TM_GREEN",          "words", 1),
    ("tamarin-neg",           "tamarin/Makefile", "TM_NEG",            "words", 1),
]

# `tlc-green` runs one row that is in no variable: Store's liveness slice, invoked by name
# in the recipe because it is the only module whose safety and liveness bounds differ (TLC's
# liveness graph exhausts the 2 GB cap at Store's safety bound). Declared here rather than
# silently added, and asserted to still exist in the recipe below.
STORELIVE_MARKER = "StoreLive.cfg"

# Gate-table-shaped variables in the engine Makefiles that are NOT run counts, each with the
# reason. `unknown_tables()` requires every such variable to be here or in DERIVATION, so a new
# table cannot be added to a Makefile and silently omitted from the published total.
NOT_RUNS: dict[str, str] = {
    # The prover verdict tables. Each is the EXPECTED-VERDICT column for a row already counted
    # under PV_GREEN / PV_NEG / TM_GREEN / TM_NEG -- D13's enforcement that a run declares what
    # it must report, not a second invocation. Counting them would double every prover run.
    "PV_EXPECT": "expected verdicts for PV_GREEN rows, not runs",
    "PV_NEG_EXPECT": "expected verdicts for PV_NEG rows, not runs",
    "TM_EXPECT": "expected verdicts for TM_GREEN rows, not runs",
    "TM_NEG_EXPECT": "expected verdicts for TM_NEG rows, not runs",
}

# ── WHERE THE TOTAL IS CLAIMED IN PROSE ─────────────────────────────────────────────────
# Each row is (file, description, pattern with exactly one capture group). The captured
# number must equal the derived total, and a pattern that matches NOTHING is a failure: a
# site that stops making the claim is exactly how a number goes stale unnoticed.
#
# WHY ANCHORED PATTERNS AND NOT "any 3-digit number near the word runs". Asked of the FIRST
# draft of this gate -- what does it assert, and what else satisfies it? -- and run: it
# flagged three files, all three FALSELY. `AGENTS.md` says "62 of 203 runs", `PROPERTIES.md`
# says "204 runs at the time", `STATUS.md` says "matrix 238 -> 242". Every one is a true
# statement about the past, and a gate that cannot tell a live claim from a historical one
# would have had us delete accurate history to go green -- the worst possible failure for a
# repo whose whole practice is keeping superseded claims visible. So the CURRENT claim is
# declared, by anchor, and history is out of scope by construction rather than by luck.
#
# The cost is stated too: this asserts the anchored sites only. A new prose site that quotes
# a total and is not listed here is not checked, and nothing detects that -- the same class
# of hole as `make coverage` not asserting the engine columns.
PROSE_SITES = [
    ("README.md", "the `make matrix` line in the build block",
     r"negative controls \+ non-vacuity witnesses \((\d+) runs\)"),
    ("README.md", "the docs/ layout tree",
     r"capstone: what was proved \+ the (\d+)-run matrix"),
    ("AGENTS.md", "the Status paragraph",
     r"\*\*(\d+)-run\*\* `make matrix` is the gate"),
    ("docs/STATUS.md", "the headline claim",
     r"\*\*The full matrix is (\d+) runs\*\*"),
    ("docs/STATUS.md", "the per-slice table footer",
     r"\| \*\*total\*\* \| \*\*(\d+)\*\* \|"),
    ("docs/PROPERTIES.md", "the grader inventory header",
     r"targets decide the (\d+) runs"),
    ("docs/FINAL-ASSURANCE-SUMMARY.md", "the control-matrix headline",
     r"\*\*(\d+) runs in one `make matrix`"),
    ("CANONICAL-DOCS.toml", "the capstone blurb",
     r"the (\d+)-run re-verification matrix"),
]


# ── WHICH PROOF TRACK EACH RUN BELONGS TO ───────────────────────────────────────────────
# Added 2026-09-07, with the attestation track's first module. A single "N runs" total across
# two protocols is precisely the conflation TRACKS.toml exists to prevent: a reader seeing one
# number reasonably assumes one subject. The split could have been written into prose by hand
# -- and would then have been an ungated derived number, which is D15's entire subject.
#
# Every gate-table row names its module/theory in its FIRST field (whitespace- or
# pipe-delimited), and TRACKS.toml maps a model FILE to a track, so the mapping is
# module -> file (by each engine's naming convention) -> track. A token that resolves to no
# declared model file is a FAILURE rather than a default-to-core: silently attributing an
# unrecognized run to the biggest track is how a number stops meaning anything.
ENGINE_SUFFIX = {
    "tla/Makefile":     [("tla/", ".tla")],
    "spin/Makefile":    [("spin/", ".pml")],
    "tamarin/Makefile": [("tamarin/", ".pv"), ("tamarin/", ".spthy")],
}


def file_to_track() -> dict[str, str]:
    with open(os.path.join(HERE, "TRACKS.toml"), "rb") as fh:
        cfg = tomllib.load(fh)
    return {f: name for name, t in cfg.get("track", {}).items() for f in t.get("models", [])}


def track_of(rel: str, token: str, f2t: dict[str, str]) -> str:
    for pre, suf in ENGINE_SUFFIX.get(rel, []):
        cand = f"{pre}{token}{suf}"
        if cand in f2t:
            return f2t[cand]
    raise Fail(
        f"{rel}: gate-table entry {token!r} maps to no model file declared in TRACKS.toml"
        "\n      -> a run whose track cannot be determined must not be silently counted as"
        "\n         core. Add the file to a track, or fix the table entry."
    )


def first_token(item: str) -> str:
    return re.split(r"[|\s]", item.strip().strip('"'), 1)[0]


# Where the per-track split is claimed. Same anchored discipline as the total: silence fails,
# because dropping the sentence is otherwise the cheapest way to make a stale split go green.
# EXTENDED 2026-09-07 WITH THE QUORUM TRACK, AND THE REASON IS THE FAILURE MODE, NOT THE
# ADDITION. Before this edit both patterns captured exactly two groups, core and attestation.
# Promoting a third track did NOT fail either of them: the sentences still matched, the two
# captured numbers were still right, and `make runcount` went green while asserting nothing
# whatever about the 28 quorum runs. That is D15's own subject one level down -- the INPUT SET
# a gate checks over, silently narrowed -- and it is the same shape as the non-recursive globs
# that would have hidden a whole subdirectory. A per-track gate must name every modeled track
# or it is a per-SOME-tracks gate; `check_track_prose` now derives the tuple from the modeled
# set rather than from a hardcoded pair, so a fourth track cannot repeat this.
TRACK_PROSE_SITES = [
    ("docs/STATUS.md", "the per-track run split",
     r"\*\*(\d+) runs\*\* on `core`, \*\*(\d+)\*\* on `attestation`, \*\*(\d+)\*\* on `quorum` "
     r"and \*\*(\d+)\*\* on `identity`"),
    # The attestation anchor was `1 module` until 2026-09-07 and had to move when a second
    # module landed. Anchored on `modules?` now, so module COUNT is not part of the anchor --
    # it is prose the gate does not check, and pinning a gate to a number it does not assert
    # is how a correct edit gets reported as a missing claim.
    #
    # ... AND THE PATTERN BELOW OPENED WITH THE LITERAL `95 model files` UNTIL 2026-09-16, four
    # words under the sentence forbidding exactly that. Adding eight model files to `core` made
    # the anchor stop matching, so the gate reported "the site NO LONGER STATES the per-track
    # split" -- a true message naming the wrong defect, on a site that was merely stale. Same
    # failure as `tools/ledgercount.py` anchoring on `**40 rows**` (D19's third anti-pattern,
    # 2026-09-14): NEVER ANCHOR A MATCHER ON A NUMBER IT DOES NOT ASSERT, including one that
    # merely sits NEXT TO the number it does. The file-count is `\d+` now and stays unchecked
    # by this gate; `make trackcheck` is what counts model files.
    ("README.md", "the proof-tracks table",
     r"\d+ model files, (\d+) runs.*?modules?.*?, (\d+) runs.*?modules?.*?, (\d+) runs"
     r".*?modules?.*?, (\d+) runs"),
]

# The tracks the two patterns above capture, IN ORDER. Named here rather than inlined in
# `check_track_prose` so that adding a track is one edit in one place and the mismatch between
# "tracks that exist" and "tracks the gate reads" is checkable -- see the assertion below.
# EXTENDED AGAIN 2026-09-07 with the identity track, and this time the widening WORKED AS
# DESIGNED rather than being found after the fact: promoting a fourth track failed `runcount`
# immediately with "track(s) identity have runs but no group in TRACK_PROSE_SITES", which is
# exactly the message the quorum-day fix was written to produce. Recorded because a gate that
# fires correctly on its first real test is the only evidence that the previous fix was a fix
# and not a restatement.
TRACK_PROSE_ORDER = ("core", "attestation", "quorum", "identity")


def check_track_prose(by_track: dict[str, int]) -> list[str]:
    out = []
    # A modeled track missing from TRACK_PROSE_ORDER is the silent-narrowing failure this
    # function was widened to prevent, so it is an error rather than a skip.
    unread = sorted(set(by_track) - set(TRACK_PROSE_ORDER))
    if unread:
        out.append(
            f"track(s) {', '.join(unread)} have runs but no group in TRACK_PROSE_SITES"
            "\n      -> the split gate would go green while asserting nothing about them."
            "\n         Add a capture group to each pattern and a name to TRACK_PROSE_ORDER."
        )
    want = tuple(by_track.get(t, 0) for t in TRACK_PROSE_ORDER)
    for rel, what, pat in TRACK_PROSE_SITES:
        m = re.search(pat, re.sub(r"\s+", " ", read(rel)), re.S)
        if not m:
            out.append(
                f"{rel}: {what} no longer states the per-track split"
                "\n      -> restore the claim or drop the row from TRACK_PROSE_SITES."
            )
            continue
        got = tuple(int(g) for g in m.groups())
        if got != want:
            say = lambda v: " ".join(f"{t}={n}" for t, n in zip(TRACK_PROSE_ORDER, v))
            out.append(f"{rel}: {what} says {say(got)}; derived {say(want)}")
    return out


class Fail(Exception):
    pass


def read(rel: str) -> str:
    with open(os.path.join(HERE, rel), encoding="utf-8") as fh:
        return fh.read()


def block(rel: str, var: str) -> str:
    """The full (line-continued) right-hand side of a make variable."""
    out, grab = [], False
    for line in read(rel).splitlines():
        if not grab and re.match(rf"^{var} *:?=", line):
            grab, line = True, re.sub(rf"^{var} *:?=", "", line)
            out.append(line)
        elif grab:
            out.append(line)
        if grab and not line.rstrip().endswith("\\"):
            break
    if not out:
        raise Fail(f"{rel}: no variable {var} -- the derivation names a table that is gone")
    return "\n".join(out)


def count(rel: str, var: str, how: str) -> int:
    b = block(rel, var)
    if how == "rows":                       # quoted "…" rows
        return len(re.findall(r'"[^"]+"', b))
    return len([w for w in b.replace("\\", " ").split() if not w.startswith("#")])


def items(rel: str, var: str, how: str) -> list[str]:
    """The individual table entries, so each can be attributed to a track."""
    b = block(rel, var)
    if how == "rows":
        return re.findall(r'"([^"]+)"', b)
    return [w for w in b.replace("\\", " ").split() if not w.startswith("#")]


def derive_tracks() -> dict[str, int]:
    f2t = file_to_track()
    per: dict[str, int] = {}
    for label, rel, var, how, factor in DERIVATION:
        if how == "const":
            per["core"] = per.get("core", 0) + factor      # StoreLive; Store is a core module
            continue
        for it in items(rel, var, how):
            tr = track_of(rel, first_token(it), f2t)
            per[tr] = per.get(tr, 0) + factor
    return per


def derive(verbose: bool) -> tuple[int, dict[str, int]]:
    per: dict[str, int] = {}
    for label, rel, var, how, factor in DERIVATION:
        if how == "const":
            n = factor
            if STORELIVE_MARKER not in read("tla/Makefile"):
                raise Fail(
                    f"{label}: this run is declared as a constant because it is invoked by "
                    f"name in the recipe, and {STORELIVE_MARKER!r} is no longer in "
                    f"tla/Makefile. Either the run is gone (drop the row) or it moved."
                )
        else:
            n = count(rel, var, how) * factor
        per[label] = n
        if verbose:
            src = f"{rel}:{var}" if var else "tla/Makefile recipe"
            print(f"  {label:26} {n:4}   ({src}{'' if factor == 1 else f' x{factor}'})")
    return sum(per.values()), per


def check_prose(total: int) -> list[str]:
    problems = []
    for site, what, pattern in PROSE_SITES:
        found = [int(m.group(1)) for m in re.finditer(pattern, read(site))]
        if not found:
            problems.append(
                f"{site}: {what} no longer states a run total (pattern did not match). "
                f"A site that goes silent is how the number goes stale unnoticed -- either "
                f"restore the claim or drop the row from PROSE_SITES deliberately."
            )
        elif set(found) != {total}:
            problems.append(f"{site}: {what} states {sorted(set(found))}, derived {total}")
    return problems


def check_status_slices(total: int, per: dict[str, int]) -> list[str]:
    """docs/STATUS.md's per-slice table is the reader-facing breakdown; check it sums AND
    that each row matches the derivation rather than only agreeing with itself."""
    rows = re.findall(r"^\| (?!\*\*total)([^|]+?) *\| *(\d+) *\|$", read("docs/STATUS.md"), re.M)
    if not rows:
        return ["docs/STATUS.md: the per-slice run table is gone"]
    got = {label.strip(): int(n) for label, n in rows}
    problems = []
    if sum(got.values()) != total:
        problems.append(f"docs/STATUS.md slice table sums to {sum(got.values())}, derived {total}")
    expect = {
        "TLC green": per["tlc-green (modules)"] + per["tlc-green (N-peer)"]
        + per["tlc-green (StoreLive)"],
        "TLC negative controls": per["tlc-neg"],
        "TLC non-vacuity witnesses": per["tlc-witness"],
        "Apalache inductive": per["apalache-green"],
        "Apalache negative controls": per["apalache-neg"],
        "Spin green": per["spin green (safety+LTL)"] + per["spin green (safety)"]
        + per["spin green (N=3)"],
        "Spin negative controls": per["spin neg"],
        "ProVerif": per["proverif-green"] + per["proverif-neg"],
        "Tamarin": per["tamarin-green"] + per["tamarin-neg"],
    }
    for prefix, want in expect.items():
        match = [n for label, n in got.items() if label.startswith(prefix)]
        if not match:
            problems.append(f"docs/STATUS.md: no slice row starting {prefix!r}")
        elif match[0] != want:
            problems.append(f"docs/STATUS.md slice {prefix!r}: says {match[0]}, derived {want}")
    return problems


def unknown_tables() -> list[str]:
    """Gate tables that exist in a Makefile and are counted by NOTHING here.

    D15, and learned the hard way twice: `DERIVATION` above is an input set, and an input set
    is a claim. On 2026-09-09 `APALACHE_FINDING` was added to `tla/Makefile` and wired into
    `matrix`; this tool kept deriving a total that omitted its eight runs, and would have gone
    green the moment eight prose sites were edited to the wrong number. Nothing about that is
    specific to that table.

    So: every `UPPER_CASE := \\` assignment in the three engine Makefiles whose name matches a
    gate-table shape must be named in `DERIVATION` -- or listed in `NOT_RUNS` with a reason,
    which is the disclosure half. A table that is neither is a build failure.
    """
    problems = []
    for rel in ("tla/Makefile", "spin/Makefile", "tamarin/Makefile"):
        text = read(rel)
        for name in re.findall(r"^([A-Z][A-Z0-9_]+)\s*:?=\s*\\", text, re.M):
            if not re.match(r"^(TLC|APALACHE|SPIN|PV|TM)_", name):
                continue
            if name in NOT_RUNS:
                continue
            if not any(v == name and f == rel for _, f, v, _, _ in DERIVATION):
                problems.append(
                    f"{rel}: gate table {name} is counted by no row of DERIVATION -- either add"
                    " it, or add it to NOT_RUNS with the reason it is not a run"
                )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verbose", action="store_true", help="show the per-target derivation")
    args = ap.parse_args()
    try:
        print("== run total, derived from the gate tables (not from prose) ==")
        total, per = derive(args.verbose or True)
        print(f"  {'TOTAL':26} {total:4}")

        # Per proof track. A single total across two protocols is the conflation TRACKS.toml
        # exists to prevent -- a reader seeing one number reasonably assumes one subject.
        by_track = derive_tracks()
        if sum(by_track.values()) != total:
            raise Fail(
                f"per-track runs sum to {sum(by_track.values())} but the total is {total}"
                " -- the two derivations disagree, which means one of them is wrong"
            )
        print("\n== the same runs, by proof track (TRACKS.toml) ==")
        for tr in sorted(by_track):
            print(f"  {tr:26} {by_track[tr]:4}")
        problems = (check_prose(total) + check_status_slices(total, per)
                    + check_track_prose(by_track) + unknown_tables())
    except Fail as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"FAIL -- {exc}", file=sys.stderr)
        return 1

    print()
    if problems:
        print(f"FAIL -- {len(problems)} disagreement(s) between the tables and the prose:")
        for p in problems:
            print(f"  - {p}")
        print("\nThe tables are the source of truth. Fix the prose, not this script -- unless")
        print("a gate table genuinely changed, in which case the new number is the answer and")
        print("every site above states it.")
        return 1
    print(f"OK -- {total} runs derived from the gate tables; {len(PROSE_SITES)} prose sites")
    print("and the STATUS slice table all state it.")
    print("This asserts the COUNT, not that the runs pass (that is `make matrix`) and not")
    print("that every run is in a table (a run in no table is invisible to both).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
