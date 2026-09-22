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

--track — the widening, 2026-09-09, and the reason it was needed
----------------------------------------------------------------
Everything above was written about ONE track, because when it was written there was one.
`core` was hard-wired: `spec-data/MODELING-PIN` for the pin, `track_models(root, "core")`
for the models, one `--live` for the tree. Three extension tracks were promoted on
2026-09-07 and this tool did not notice — it kept deriving a correct, gated, entirely
core-shaped number while **three pins it had never heard of drifted from live**. Found by
hand on 2026-09-09, two days later, with every gate in the repo green.

That is D15's mechanism — *what is the input set of this number?* — in the tool whose whole
job is to answer that question about somebody else's tree. The fix is the `runcount` fix:
the track list is DERIVED from `TRACKS.toml` (`measured_tracks`), each track's pin comes from
its own `pin_file`, each track's live tree from its own `source_repo_path`/`source_dir`, and
a modeled track that no declared prose site states a status for is a **build failure**. A
fifth track cannot repeat this.

Two smaller fixes came with it, both of which had been silently subtracting from the
denominator: `section_block` could not match `## 4. Connections` (the trailing dot), so a
model citing `§4` resolved to nothing; and a citation that resolved to nothing was DROPPED
rather than reported, which is how eight `COVERAGE-MATRIX` document references lived inside
the citation set. Unresolvable citations now fail the run and are named.

Usage:
  tools/spec-drift.py                        # every modeled protocol track
  tools/spec-drift.py --check-claims         # ...and the prose that states each status
  tools/spec-drift.py --track quorum
  tools/spec-drift.py --track core --live /tmp/pub-specs --format md
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
CLAIM_COUNTS = {"README.md": 2, "docs/SPEC-DRIFT-ASSESSMENT.md": 2}

# ── THE SAME CLAIM, PER TRACK ───────────────────────────────────────────────────────────
# The nine sites above state CORE's status in the unqualified form, which is right: core is
# the headline a public reader wants and rewriting nine sites to say `core` buys nothing. The
# three extension tracks get a QUALIFIED form, and the two patterns are disjoint by
# construction -- the track form opens with a backtick, so `CLAIM_RE`'s `\*\*(no drift|\d...`
# cannot match it and it cannot match `CLAIM_RE`'s sites.
#
#     `make specdrift` reports **`quorum` no drift**
#     `make specdrift` reports **`identity` 2 of 24 cited sections moved**
#
# WHY THE EXTENSION TRACKS NEEDED THIS AT ALL: they had no drift claim anywhere, because they
# had no drift MEASUREMENT anywhere. `docs/status/FINDINGS-INDEX.md` carried the nearest thing
# -- "byte-identical to live when checked (2026-09-07)" beside its own note that none has a
# drift gate -- and by 2026-09-09 all three had drifted with every gate in the repo green.
TRACK_CLAIM_RE = r"`make specdrift` reports \*\*`([a-z]+)` (no drift|\d+ of \d+ cited sections moved)\*\*"

TRACK_CLAIM_SITES = [
    ("docs/SPEC-DRIFT-ASSESSMENT.md", "the per-track measurement table"),
    ("docs/status/FINDINGS-INDEX.md", "the extension-pin status note"),
]


def read(path: str) -> str:
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def section_block(text: str, sec: str) -> str | None:
    """Pinned text of `sec`: its heading through to the next heading of any level.

    THE TRAILING DOT IS NOT COSMETIC -- it silently narrowed this tool's input set for as
    long as the tool has existed. Top-level headings in every spec here are written
    `## 4. Connections`, and the old pattern required whitespace directly after the number,
    so a model citing `§4` -- which `tla/Conn.tla` and `tla/Core.tla` both do, about the §4
    dispatch rules -- resolved to nothing and was DROPPED from the denominator without a word.
    Same for `EXTENSION-QUORUM` §1, §2, §7 and §8; §8 is the `tree:put` permission clause that
    Q5's whole amendment turns on. D15's mechanism (what is the input set of this number?)
    inside the tool that measures drift.
    """
    m = re.search(rf"^(#{{1,6}})\s+{re.escape(sec)}\.?\s+.*$", text, re.M)
    if not m:
        return None
    rest = [h.start() for h in HEADING.finditer(text) if h.start() > m.start()]
    return text[m.start(): rest[0] if rest else len(text)]


def resolve_section(text: str, sec: str) -> tuple[str, str] | None:
    """(section actually compared, its pinned text) -- or None if the citation resolves to
    nothing in this spec.

    Two shapes resolve, and the second one is why this is a function rather than a call:

      * an exact heading -- the ordinary case, including lettered SIBLING sections that this
        spec really has (`1.2a`, `4.5a`, `5.2a` in core are `###` headings in their own right);
      * a lettered SUB-CLAUSE with no heading of its own -- `§4.9a`..`§4.9d`, `§4.10a`,
        `§4.10b` are lettered bullets INSIDE §4.9 and §4.10. They are precise, correct
        citations of normative text and they are not headings, so an exact match drops them.
        Their exposure is their parent's, so they are credited to the parent and the report
        says so.

    Order matters: exact first. `§1.2a` is a heading AND would strip to `§1.2`, and crediting
    it to the parent would be the §4.7-range-endpoint miscredit in a new place.
    """
    blk = section_block(text, sec)
    if blk is not None:
        return sec, blk
    if sec and sec[-1].isalpha():
        parent = sec[:-1]
        blk = section_block(text, parent)
        if blk is not None:
            return parent, blk
    return None


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


def registry(root: str) -> dict:
    with open(os.path.join(root, "TRACKS.toml"), "rb") as fh:
        return tomllib.load(fh).get("track", {})


def measured_tracks(root: str) -> list[str]:
    """The tracks this tool MUST measure: every modeled protocol track, from the registry.

    Derived, never listed. Until 2026-09-09 this tool was hard-wired to `core` -- no `--track`
    flag existed -- so when three extension tracks were promoted it silently became a
    one-of-four gate, and all three extension pins drifted from live with `make specdrift`
    reporting a clean, accurate, and entirely core-shaped number. That is the SAME failure
    `runcount`'s two-group regex had (a per-track gate that does not name every track is a
    per-SOME-tracks gate) and the same failure the non-recursive globs had before it. Reading
    the registry is what makes a fifth track a build failure instead of a silent omission.
    """
    return sorted(
        n for n, t in registry(root).items()
        if t.get("kind") == "protocol" and t.get("status") == "modeled"
    )


def track_pin(root: str, track: str) -> tuple[str, str, list[str]]:
    """(snapshot name, snapshot dir, newer-vendored-but-unmodeled) for one track.

    Reads the track's OWN `pin_file`. Each track pins independently -- core is held at v0.8.2
    pending keystone, which has no bearing on the three extension pins -- so there is no
    single MODELING-PIN to fall back to and no default that is right for more than one track.
    """
    t = registry(root)[track]
    pin_file = t.get("pin_file", "")
    if not pin_file:
        raise SystemExit(f"track {track!r} declares no pin_file")
    named = None
    for line in read(os.path.join(root, pin_file)).splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            named = line
            break
    if not named:
        raise SystemExit(f"{pin_file} names no snapshot")
    pin_dir = os.path.join(root, "spec-data", named)
    if not os.path.isdir(pin_dir):
        raise SystemExit(f"{pin_file} names {named!r} but spec-data/{named}/ does not exist")
    # "Newer" means newer IN THIS TRACK'S OWN FAMILY. The first draft split on "-" and so
    # matched every `ext-*` snapshot against every other, telling the attestation track that
    # `ext-identity-v3.10` was a newer unmodeled snapshot OF ATTESTATION. A cross-track pin
    # reported as this track's own is the document-blind citation bug wearing a directory
    # name; caught by running it, as usual, not by reading it.
    family = re.sub(r"-?v[\d.]+$", "", named)
    newer = sorted(
        b for b in (os.path.basename(p.rstrip("/"))
                    for p in glob.glob(os.path.join(root, "spec-data", "*/")))
        if re.sub(r"-?v[\d.]+$", "", b) == family and b > named
    )
    return named, pin_dir, newer


def track_live(root: str, track: str) -> str:
    """Where this track's spec lives NOW, derived from the registry rather than passed in.

    `source_repo_path` + `source_dir` were already in TRACKS.toml for every track and nothing
    read them. Deriving the live tree per track is what makes `--live` an override rather than
    the only way to say it -- and it is why the extension specs are found in
    `entity-system-architecture/specs/extensions/` without anyone having to remember that the
    core repo does not own them.
    """
    t = registry(root)[track]
    return os.path.normpath(os.path.join(root, t.get("source_repo_path", ""),
                                         t.get("source_dir", "")))


def model_pins(root: str, track: str) -> dict[str, str]:
    """Models of this track that transcribe a DIFFERENT snapshot than the track pin.

    Declared in `[track.<name>.model_pins]` and gated by `make trackcheck`, both directions
    (the file must carry a `MODELING-PIN-OVERRIDE:` marker agreeing with the row, and a marker
    with no row fails). See that tool's header for why this is a registry fact rather than a
    sentence in a module header.
    """
    return dict(registry(root).get(track, {}).get("model_pins", {}) or {})


def track_citations(root: str, track: str) -> dict[str, set[str]]:
    """Every section of THIS track's spec that any model in this repo depends on.

    Bare `§N.M` from the track's own models, plus `§<PREFIX>:N.M` written by a model on any
    other track. Those cross-track references are excluded from coverage (a reference is not
    a claim) but they ARE drift exposure: a model that reads core §6.2 is exposed when core
    §6.2 moves, whichever track it belongs to.

    ⛔ PIN-OVERRIDDEN MODELS ARE EXCLUDED, and that exclusion is the whole point of the
    override. This function answers "which sections of the PIN do the models depend on", and a
    model transcribing a newer snapshot depends on that snapshot's text instead. Counting its
    citations here would report the pin's §4.7 as covered by a model that transcribes §4.7 as
    it reads three revisions later -- the phantom-row shape, arriving through the drift gate.
    Their own drift is measured separately, against their own pin, in `measure_overrides`.
    """
    tracks = registry(root)
    t = tracks.get(track, {})
    own = [f for f in t.get("models", []) if f not in model_pins(root, track)]
    cites = model_citations(root, own, bare=True)
    prefix = t.get("cite_prefix", "")
    others = [
        f for n, o in tracks.items() if n != track and o.get("kind") == "protocol"
        for f in o.get("models", [])
    ]
    if others and prefix:
        for sec, files in model_citations(root, others, bare=False, prefix=prefix).items():
            cites.setdefault(sec, set()).update(files)
    return cites


def secsort(sec: str):
    """Sort key for a section id. HOMOGENEOUS BY CONSTRUCTION, which the previous version
    was not: it returned `[ints…] + [sec]`, so sorting `§4` against `§4.9` compared the
    string `'4'` against the int `9` and raised. It never fired because bare `§4` had never
    resolved — the dot bug in `section_block` kept it out of the sorted set. Two defects
    holding each other up, and fixing one exposed the other immediately.
    """
    return tuple(int(p) for p in re.findall(r"\d+", sec)), (sec[-1] if sec[-1].isalpha() else "")


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


def check_live_version(root: str, version: str) -> list[str]:
    """Every declared site must mention the live spec version the measurement just read.

    WHY THIS EXISTS: the nine sites said "the live spec is **0.8.2.11**" while it was
    **0.8.2.14**, and `make driftclaim` was green over all nine the whole time -- because the
    gate anchored the SECTION COUNT and nothing anchored the VERSION beside it. The count
    happened to still be 9, so the one gated number never moved while the ungated one next to
    it went stale. Two facts in one sentence, one of them checked.

    What this asserts: the derived live version string occurs at least once in the file.
    What else satisfies it, stated rather than hidden: a file that mentions the current
    version somewhere and ALSO keeps a stale live claim elsewhere passes. That is the same
    "different words, same file" hole `runcount` and `enginecount` have, and it is why
    `CHANGELOG.md` and `docs/STATUS.md` -- which legitimately carry past versions in dated
    sentences -- can be gated this way at all without an exemption list.
    """
    problems = []
    for site in sorted({s for s, _ in CLAIM_SITES}):
        try:
            text = normalize(read(os.path.join(root, site)))
        except OSError as exc:
            problems.append(f"{site}: cannot read ({exc})")
            continue
        if version not in text:
            problems.append(
                f"{site}: never mentions the live spec version {version!r}. The live spec "
                f"moved under this document -- update the claim, or drop the row from "
                f"CLAIM_SITES deliberately.")
    return problems


def check_track_claims(root: str, derived: dict[str, tuple[int, int]]) -> list[str]:
    """Every declared site must state the derived status for EVERY extension track.

    Three failures, graded the same:

      * a site whose number disagrees with the measurement -- the live bug;
      * a site that names a track the registry does not have, or omits one it does -- the
        `runcount` failure, where a per-track gate captured exactly two groups and went green
        while asserting nothing whatever about a third track's runs;
      * a site that states nothing at all -- deleting the sentence is the cheapest way to go
        green, and a repo whose drift status is unstated is exactly where this started.
    """
    want = {t: ("no drift" if m == 0 else f"{m} of {n} cited sections moved")
            for t, (m, n) in derived.items()}
    problems = []
    for site, what in TRACK_CLAIM_SITES:
        try:
            found = dict(re.findall(TRACK_CLAIM_RE, normalize(read(os.path.join(root, site)))))
        except OSError as exc:
            problems.append(f"{site}: cannot read ({exc})")
            continue
        missing = sorted(set(want) - set(found))
        extra = sorted(set(found) - set(want))
        if missing:
            problems.append(
                f"{site} ({what}): states no drift status for track(s) {', '.join(missing)}. "
                f"A per-track claim that does not name every measured track is a "
                f"per-SOME-tracks claim -- add the row or drop the site deliberately.")
        if extra:
            problems.append(
                f"{site} ({what}): claims a status for {', '.join(extra)}, which is not a "
                f"measured track in TRACKS.toml")
        for t in sorted(set(found) & set(want)):
            if found[t] != want[t]:
                problems.append(f"{site} ({what}): `{t}` claims {found[t]!r}, derived {want[t]!r}")
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


def measure(root: str, track: str, live: str, fmt: str, emit) -> tuple[int, int, list[str], str]:
    """Measure one track. Returns (moved, resolvable-total, unresolvable citations, live version).

    UNRESOLVABLE CITATIONS ARE RETURNED, NOT DISCARDED. The old code did
    `if blk is not None: resolved[sec] = ...` and said nothing about the rest, so a citation
    that stopped matching a heading left the denominator silently -- which is how `§4` sat
    outside the core measurement for the life of the tool, and how eight `COVERAGE-MATRIX`
    document references sat inside the citation set without ever being noticed. The caller
    treats a non-empty list as a build failure.
    """
    t = registry(root)[track]
    named, pin_dir, newer = track_pin(root, track)
    primary = t.get("primary_spec", "")
    bullet = "- " if fmt == "md" else "  "

    emit(f"\n## track `{track}`\n" if fmt == "md" else f"\n== track `{track}` ==")
    emit(f"{bullet}pin:  spec-data/{named}   ({primary})")
    emit(f"{bullet}live: {os.path.relpath(live, root)}")
    if newer:
        emit(f"{bullet}NOTE: newer snapshot(s) vendored but not yet modeled: {', '.join(newer)}")

    # D22 -- what does this print when its own input is missing? The measurement needs TWO
    # trees: the pin (ours, always here) and the live spec (a sibling repo's, often not).
    # It used to check only the pin, walk the file list finding nothing on the live side,
    # fall out of the loop with `pin_text` still None, and report
    # `primary_spec 'X' not in <pin_dir>` -- accusing a file that is present, in a directory
    # that is intact, and never naming the tree it could not reach. On a fresh clone, where
    # no sibling exists, that is the ONLY thing this tool says. Say what is actually absent.
    if not os.path.isdir(live):
        raise SystemExit(
            f"track {track!r}: the live spec tree is not here -- {live}\n"
            f"  The pin (spec-data/{named}/) is intact; there is nothing to compare it "
            f"AGAINST.\n"
            f"  This measurement reads a SIBLING repository's working tree, so it cannot run "
            f"from a\n"
            f"  standalone clone. Check out the repo that owns this spec beside this one, or "
            f"pass\n"
            f"  --track {track} --live <path>. Every other gate here runs standalone.")

    files = sorted(f for f in os.listdir(pin_dir)
                   if f.endswith(".md") and f not in ("MANIFEST.md", "README.md"))
    if not files:
        raise SystemExit(f"no spec files in {pin_dir}")

    pin_text = live_text = None
    identical = True
    for f in files:
        lp = os.path.join(live, f)
        if not os.path.exists(lp):
            emit(f"{bullet}{f}: MISSING from live tree")
            identical = False
            continue
        a, b = read(os.path.join(pin_dir, f)), read(lp)
        identical &= a == b
        va, vb = spec_version(a), spec_version(b)
        ver = f"  version {va}" + ("" if va == vb else f" -> {vb}")
        emit(f"{bullet}{f}: {'identical' if a == b else 'DIFFERS'}{ver}")
        if f == primary:
            pin_text, live_text = a, b

    if pin_text is None:
        raise SystemExit(f"track {track!r}: primary_spec {primary!r} not in {pin_dir}")

    cites = track_citations(root, track)
    resolved: dict[str, bool] = {}
    credited: dict[str, str] = {}
    unresolvable: list[str] = []
    for sec in cites:
        hit = resolve_section(pin_text, sec)
        if hit is None:
            unresolvable.append(sec)
            continue
        actual, blk = hit
        credited[sec] = actual
        resolved[actual] = resolved.get(actual, False) or (blk not in live_text)

    moved = sorted([s for s in resolved if resolved[s]], key=secsort)
    unchanged = sorted([s for s in resolved if not resolved[s]], key=secsort)
    ncite = {s: len({f for c, a in credited.items() if a == s for f in cites[c]})
             for s in resolved}

    if identical:
        emit(f"{bullet}pin matches live exactly — no drift.")
    emit(f"{bullet}{len(moved)} of {len(resolved)} cited sections moved")
    for sec in moved:
        emit(f"    §{sec:<8} MOVED      cited by {ncite[sec]} model file(s)")
    if fmt == "md":
        for sec in unchanged:
            emit(f"    §{sec:<8} unchanged  cited by {ncite[sec]} model file(s)")

    rolled = sorted([c for c, a in credited.items() if c != a], key=secsort)
    if rolled:
        emit(f"{bullet}{len(rolled)} lettered sub-clause citation(s) credited to their parent "
             f"section (not headings in this spec): {', '.join('§' + s for s in rolled)}")

    # Exposure by ENGINE, not by track -- this grouping is by model checker, and since
    # 2026-09-06 "track" means a proof track in this repo. Scoped to THIS track's files, and
    # excluding pin-overridden models for the same reason `track_citations` excludes them:
    # they are not exposed to the PIN moving, they are exposed to their own snapshot moving.
    overrides = model_pins(root, track)
    own = [f for f in t.get("models", []) if f not in overrides]
    emit(f"{bullet}exposure by engine:")
    for engine, roots in ENGINES.items():
        paths = [f for f in own if f.split("/")[0] in roots]
        if not paths:
            continue
        tc: dict[str, set[str]] = defaultdict(set)
        for rel in paths:
            for m in CITATION.finditer(read(os.path.join(root, rel))):
                a = credited.get(m.group(1))
                if a in resolved:
                    tc[a].add(rel)
        tmoved = [s for s in tc if resolved[s]]
        affected = set().union(*(tc[s] for s in tmoved)) if tmoved else set()
        emit(f"    {engine:<18} {len(tmoved)}/{len(tc)} cited § moved; "
             f"{len(affected)}/{len(paths)} model files affected")

    # ---- pin-overridden models, measured against THEIR OWN snapshot -------------------
    # Reported as its own block rather than folded into the numbers above, because the pair
    # `N of M cited sections moved` is a claim about THE TRACK PIN and must stay one. A
    # reader who sees a total here is entitled to assume it is about the snapshot named at the
    # top of this block; blending two pins into one figure is the shape D15 keeps finding.
    if overrides:
        emit("")
        emit(f"{bullet}PIN-OVERRIDDEN MODELS — measured against their own snapshot, "
             f"NOT against spec-data/{named}:")
        for snap in sorted(set(overrides.values())):
            paths = sorted(f for f, s in overrides.items() if s == snap)
            snap_primary = os.path.join(root, "spec-data", snap, primary)
            if not os.path.isfile(snap_primary):
                emit(f"    spec-data/{snap}: MISSING {primary} — cannot measure")
                unresolvable.append(f"<override snapshot {snap} has no {primary}>")
                continue
            snap_text = read(snap_primary)
            ocites = model_citations(root, paths, bare=True)
            ores: dict[str, bool] = {}
            for sec in ocites:
                hit = resolve_section(snap_text, sec)
                if hit is None:
                    unresolvable.append(f"{sec} (in {snap})")
                    continue
                actual, blk = hit
                ores[actual] = ores.get(actual, False) or (blk not in live_text)
            omoved = sorted([s for s in ores if ores[s]], key=secsort)
            emit(f"    spec-data/{snap}: {len(omoved)} of {len(ores)} cited sections moved "
                 f"({len(paths)} model file(s))")
            for f in paths:
                emit(f"      {f}")
            for sec in omoved:
                emit(f"      §{sec:<8} MOVED")

    return (len(moved), len(resolved), sorted(unresolvable, key=secsort),
            spec_version(live_text))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--track", default=None,
                    help="measure one proof track (default: every modeled protocol track)")
    ap.add_argument("--live", default=None,
                    help="override the live spec dir; only valid with --track, since each "
                         "track's live tree is derived from TRACKS.toml and they differ")
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--format", choices=("text", "md"), default="text")
    ap.add_argument("--check-claims", action="store_true",
                    help="assert every declared prose site states the derived drift status")
    args = ap.parse_args()

    want = measured_tracks(args.root)
    if args.track:
        if args.track not in want:
            print(f"--track {args.track!r} is not a modeled protocol track; have: "
                  f"{', '.join(want)}", file=sys.stderr)
            return 2
        want = [args.track]
    elif args.live:
        print("--live without --track is ambiguous: four tracks, four live trees. Pass "
              "--track, or drop --live and let TRACKS.toml say where each one lives.",
              file=sys.stderr)
        return 2

    out: list[str] = []
    emit = out.append
    emit("# spec-drift\n" if args.format == "md" else "spec-drift")
    emit(("- " if args.format == "md" else "  ") +
         f"measuring {len(want)} modeled protocol track(s): {', '.join(want)}")

    derived: dict[str, tuple[int, int]] = {}
    unresolvable: dict[str, list[str]] = {}
    live_version: dict[str, str] = {}
    for tr in want:
        live = args.live if (args.track and args.live) else track_live(args.root, tr)
        m, n, bad, ver = measure(args.root, tr, live, args.format, emit)
        derived[tr] = (m, n)
        live_version[tr] = ver
        if bad:
            unresolvable[tr] = bad

    emit("\nEvery result in this repo remains a reproducible statement about its track's PIN.")
    emit("Sections listed as moved are where that pin no longer describes the live spec.")

    rc = 0
    if unresolvable:
        emit("")
        emit("UNRESOLVABLE CITATIONS -- these resolve to no heading in the track's own spec:")
        for tr, bad in unresolvable.items():
            emit(f"  {tr}: {', '.join('§' + s for s in bad)}")
        emit("")
        emit("A bare `§N.M` in a model file means a section of that model's OWN track's spec")
        emit("(TRACKS.toml §'The citation convention'). One that resolves to nothing is either")
        emit("a reference to some OTHER document -- write `COVERAGE-MATRIX.md section 3b`, with")
        emit("no sigil -- or a real section that has been renamed, which is drift this tool")
        emit("cannot measure. Both are failures. Silently dropping them is what let `§4` sit")
        emit("outside the core denominator for the life of this tool.")
        rc = 1

    if args.check_claims:
        core_moved, core_total = derived.get("core", (0, 0))
        problems = check_claims(args.root, core_moved, core_total)
        problems += check_live_version(args.root, live_version.get("core", "?"))
        emit("")
        emit(report_claims(problems, core_moved, core_total))
        ext = {t: v for t, v in derived.items() if t != "core"}
        tproblems = check_track_claims(args.root, ext)
        emit("")
        if tproblems:
            emit(f"PER-TRACK CLAIM CHECK FAILED -- {len(tproblems)} problem(s):")
            for p in tproblems:
                emit(f"  - {p}")
            emit("")
            emit("The measurement is the source of truth. Fix the prose, not this tool.")
        else:
            emit(f"PER-TRACK CLAIM CHECK OK -- {len(TRACK_CLAIM_SITES)} declared site(s) state "
                 f"the derived status for all {len(ext)} extension track(s).")
        # `--check-claims` grades the PROSE, never the drift. Drift is information: core has
        # been 9-sections-behind on purpose for days and `make driftclaim` must stay green
        # over that, or the gate that checks whether we DESCRIBE drift honestly becomes a
        # gate that fails whenever drift exists -- which is every day, so it would be muted
        # within a week. Caught by teeth-testing the RESTORED state after four break tests,
        # which is the check that is easy to skip because it is the one expected to pass.
        print("\n".join(out))
        return 1 if (problems or tproblems or unresolvable) else 0

    print("\n".join(out))
    return rc if rc else (1 if any(m for m, _ in derived.values()) else 0)


if __name__ == "__main__":
    sys.exit(main())
