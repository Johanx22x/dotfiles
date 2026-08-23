#!/usr/bin/env python3
"""Do the scheme files agree with the vocabulary that names their colours?

schemes/README.md lists every colour role this desktop has and what each one
means. schemes/*.json fill them in. Nothing at runtime compares the two, and
for as long as that is true the failure is silent in the worst possible way:

  A ROLE THAT NO SCHEME SUPPLIES IS A DESKTOP THAT CANNOT RE-THEME ITSELF.
  matugen stops at the first `{{colors.foo.default.hex}}` it cannot resolve --
  "Value does not exist in the context" -- and writes NONE of the fourteen
  files. Not a wrong colour: no colour. Every application keeps whatever it
  had, and the next wallpaper change fails the same way.

THIS FILE USED TO SAY THAT COULD NOT HAPPEN YET, and the reason it gave has
expired -- which changes what the check is for, so the old argument goes first.
It said: the templates still carry the base palette as hex literals, not one of
them reads a scheme role, so an incomplete scheme renders a full set of
perfectly good files and says nothing at all -- and until that changed, this
check WAS the whole of the enforcement. The templates were substituted. Ten of
the fourteen read scheme roles now and not one live hex literal is left in any
of them, so an incomplete scheme does fail a render today. THREE THINGS ARE
LEFT, and each is a reason to keep counting roles rather than trusting the
render:

  WHERE THE RENDER FAILS IS THE WORST PLACE IT COULD. On the machine, mid
  wallpaper change or mid scheme switch, as fourteen files that were not
  written -- a desktop that simply does not change, with the reason in
  matugen's stderr and nothing else. This moves that to a runner, before the
  scheme is merged.

  A RENDER ONLY EXERCISES THE ROLES A TEMPLATE HAPPENS TO READ, and that is 60
  of the 78. The other 18 -- sixteen of the `fb_*` fallbacks, which the shell
  and `scheme-accent.py` consume by hand rather than through matugen, plus
  `ui_bg_dim` and `ui_text_dim` -- are read by no template at all. A scheme
  that omits one of those renders cleanly today and breaks on the day something
  reads it. For those 18 this check is still the whole of the enforcement, word
  for word as it was for all 78.

  AND MOST OF WHAT IS CHECKED HERE IS NOT RENDERABLE AT ALL. Canonical JSON
  form, lowercase `#rrggbb`, `_meta.label` and `_meta.variant`, a scheme
  filename that would collide with one of `desktop-scheme`'s own command words,
  a key that would quietly override an accent matugen derives from the
  wallpaper, and the README's prose agreeing with the README's tables. A render
  is happy with every one of those going wrong.

WHY THE README IS THE SOURCE AND NOT THIS FILE. Several people -- several
agents -- edit the templates and the schemes at the same time, and each of them
reads the vocabulary before touching anything. A second list, here, would be a
second thing to keep in step and the first one to go stale. So the role names
are PARSED OUT OF THE TABLES in sections 1.1 to 1.4 of schemes/README.md, and
the counts stated in that section's own prose are checked against the tables
that follow it -- a dropped row cannot pass by being dropped consistently.

WHAT IT CANNOT SEE. Whether the palette actually renders. That needs matugen
and a wallpaper, neither of which a runner has, so it was measured by hand
instead -- every template against what the desktop generates today. The
evidence, and the count of what one render's context actually holds, is written
up under "How the two halves join" in schemes/README.md.

Run it from anywhere:  tests/scheme-roles.py
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHEME_DIR = REPO / "schemes"
README = SCHEME_DIR / "README.md"
DESKTOP_SCHEME = REPO / "bin" / ".local" / "bin" / "desktop-scheme"

# The prefix each group of the vocabulary carries. They are not decoration:
# matugen's template context is FLAT, and `--import-json` lets the imported file
# override what matugen derived from the wallpaper -- measured -- so a scheme
# role spelled `primary` would silently replace the accent the image gave.
GROUP_PREFIX = {
    "1.1": "ui_",
    "1.2": "term_",
    "1.3": "sem_",
    "1.4": "fb_",
}
# Section 1.5 is the other side of that fence: the Material 3 roles matugen
# derives per wallpaper. No scheme may name one.
ACCENT_SECTION = "1.5"

# A scheme is addressed by its filename, and `desktop-scheme <name>` is the bare
# form of `desktop-scheme set <name>`, so a scheme called `list` would be
# unreachable by that spelling. The reserved words are read back out of the
# script's own dispatch rather than copied here, because a copy is a thing to
# keep in step.
RESERVED_RE = re.compile(r"^    ([a-z|-]+)\)$")

# `| `role` | ... |` in sections 1.1-1.4, and `| 9 | `primary` | ... |` in 1.5.
ROW_RE = re.compile(r"^\|\s*(?:\d+\s*\|\s*)?`([a-z0-9_]+)`\s*\|")
HEADING_RE = re.compile(r"^### (\d+\.\d+)")
HEX_RE = re.compile(r"^#[0-9a-f]{6}$")
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")

problems: list[str] = []


def problem(message: str) -> None:
    problems.append(message)


# ---------------------------------------------------------------------------
# The vocabulary, out of the README
# ---------------------------------------------------------------------------

def read_vocabulary() -> tuple[dict[str, list[str]], list[str]]:
    if not README.is_file():
        sys.exit(f"scheme-roles: {README} is missing -- the vocabulary is the "
                 "authority and nothing can be checked without it")

    groups: dict[str, list[str]] = {key: [] for key in GROUP_PREFIX}
    accents: list[str] = []
    section = None

    for line in README.read_text(encoding="utf-8").splitlines():
        heading = HEADING_RE.match(line)
        if heading:
            section = heading.group(1)
            continue
        row = ROW_RE.match(line)
        if not row or section is None:
            continue
        if section in groups:
            groups[section].append(row.group(1))
        elif section == ACCENT_SECTION:
            accents.append(row.group(1))

    return groups, accents


def check_vocabulary(groups: dict[str, list[str]],
                     accents: list[str]) -> tuple[set[str], set[str]]:
    """The tables have to agree with the prose above them, and with the rule
    that gave every group its prefix."""
    text = README.read_text(encoding="utf-8")

    # "78 roles in four groups: **27 base**, **27 terminal**, **7 semantic**,
    # **17 accent fallbacks**." Parsed rather than hardcoded, so the paragraph a
    # person reads and the tables a machine reads cannot drift apart -- and the
    # numbers in this comment are an ILLUSTRATION of the shape, not the values.
    stated = re.search(
        r"\*\*(\d+) base\*\*, \*\*(\d+) terminal\*\*,\s*\*\*(\d+) semantic\*\*,"
        r"\s*\*\*(\d+) accent fallbacks\*\*", text)
    if not stated:
        problem("README section 1 no longer states the size of each group; "
                "the sentence naming '27 base', '27 terminal' and so on is "
                "what the tables are checked against")
    else:
        expected = dict(zip(["1.1", "1.2", "1.3", "1.4"],
                            (int(n) for n in stated.groups())))
        for section, count in expected.items():
            found = len(groups[section])
            if found != count:
                problem(f"README section {section}: the prose says {count} "
                        f"roles, the table has {found}")

    for section, prefix in GROUP_PREFIX.items():
        if not groups[section]:
            problem(f"README section {section}: no role rows found -- has the "
                    "table changed shape?")
        for role in groups[section]:
            if not role.startswith(prefix):
                problem(f"README section {section}: role '{role}' does not "
                        f"carry the group's '{prefix}' prefix")

    if not accents:
        problem(f"README section {ACCENT_SECTION}: no Material 3 role rows "
                "found -- has the table changed shape?")

    vocabulary: set[str] = set()
    for section, roles in groups.items():
        for role in roles:
            if role in vocabulary:
                problem(f"role '{role}' is listed twice in the vocabulary")
            vocabulary.add(role)

    accent_roles = set(accents)
    clash = vocabulary & accent_roles
    if clash:
        problem("these names are both a scheme role and a wallpaper-derived "
                "Material 3 role, which is the one collision the prefixes "
                f"exist to make impossible: {', '.join(sorted(clash))}")

    return vocabulary, accent_roles


# ---------------------------------------------------------------------------
# The command words a scheme may not be named after
# ---------------------------------------------------------------------------

def reserved_words() -> set[str]:
    if not DESKTOP_SCHEME.is_file():
        problem(f"{DESKTOP_SCHEME} is missing")
        return set()

    words: set[str] = set()
    for line in DESKTOP_SCHEME.read_text(encoding="utf-8").splitlines():
        match = RESERVED_RE.match(line)
        if match:
            words.update(part for part in match.group(1).split("|") if part)

    if not words:
        problem("desktop-scheme's command dispatch no longer looks like a "
                "`case` with one word per arm, so the words a scheme may not "
                "be named after could not be read out of it")
    return words


# ---------------------------------------------------------------------------
# The scheme files
# ---------------------------------------------------------------------------

def check_scheme(path: Path, vocabulary: set[str],
                 accent_roles: set[str], reserved: set[str]) -> None:
    name = path.stem
    where = f"schemes/{path.name}"

    if not NAME_RE.match(name):
        problem(f"{where}: '{name}' is not a usable scheme name -- lowercase "
                "letters, digits and hyphens only, and it is what "
                "`desktop-scheme` is given on the command line")
    if name in reserved:
        problem(f"{where}: '{name}' is one of desktop-scheme's own commands, "
                f"so `desktop-scheme {name}` could never select it")

    raw = path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        problem(f"{where}: not valid JSON ({exc})")
        return

    if not isinstance(data, dict):
        problem(f"{where}: the top level must be an object")
        return

    # EVERY TOP-LEVEL KEY BECOMES A NAME IN MATUGEN'S FLAT TEMPLATE CONTEXT, so
    # the file gets exactly two: `colors`, which matugen reads, and `_meta`,
    # which is the one door everything else goes through.
    extra = set(data) - {"_meta", "colors"}
    if extra:
        problem(f"{where}: unexpected top-level key(s) {sorted(extra)} -- "
                "everything that is not a colour belongs under `_meta`")

    meta = data.get("_meta")
    if not isinstance(meta, dict):
        problem(f"{where}: `_meta` is missing or is not an object")
    else:
        for field in ("label", "variant"):
            value = meta.get(field)
            if not isinstance(value, str) or not value:
                problem(f"{where}: `_meta.{field}` must be a non-empty string")

    colors = data.get("colors")
    if not isinstance(colors, dict):
        problem(f"{where}: `colors` is missing or is not an object")
        return

    supplied = set(colors)
    missing = vocabulary - supplied
    if missing:
        problem(f"{where}: {len(missing)} role(s) from the vocabulary are not "
                f"filled: {', '.join(sorted(missing))}")
    unknown = supplied - vocabulary
    if unknown:
        overridden = unknown & accent_roles
        if overridden:
            problem(f"{where}: {', '.join(sorted(overridden))} would override "
                    "the accent matugen derives from the wallpaper -- an "
                    "imported role wins, so this is not a spare name")
        rest = unknown - accent_roles
        if rest:
            problem(f"{where}: role(s) not in the vocabulary: "
                    f"{', '.join(sorted(rest))} -- add them to "
                    "schemes/README.md first, or fix the spelling")

    for role in sorted(supplied):
        entry = colors[role]
        if not isinstance(entry, dict):
            problem(f"{where}: `{role}` must be an object")
            continue
        # `default` alone is what a dark-only project needs; `dark` and `light`
        # are accepted because matugen accepts them and no template reads them.
        odd = set(entry) - {"default", "dark", "light"}
        if odd:
            problem(f"{where}: `{role}` has unexpected key(s) {sorted(odd)}")
        for variant, value in entry.items():
            if not isinstance(value, dict) or "color" not in value:
                problem(f"{where}: `{role}.{variant}` must be "
                        '{"color": "#rrggbb"}')
                continue
            hexcode = value["color"]
            if not isinstance(hexcode, str) or not HEX_RE.match(hexcode):
                problem(f"{where}: `{role}.{variant}` is '{hexcode}', which is "
                        "not a lowercase #rrggbb")
        if "default" not in entry:
            problem(f"{where}: `{role}` has no `default` -- it is the only "
                    "variant this repository's templates read")

    # SORTED AND INDENTED BY TWO, mechanically. `jq -S . file` produces exactly
    # this, so a scheme is reformatted rather than tidied by hand, and two
    # scheme files line up line for line in a diff.
    canonical = json.dumps(data, indent=2, sort_keys=True,
                           ensure_ascii=False) + "\n"
    if raw != canonical:
        problem(f"{where}: not in canonical form. Run: "
                f"jq -S . {where} > tmp && mv tmp {where}")


def main() -> int:
    groups, accents = read_vocabulary()
    vocabulary, accent_roles = check_vocabulary(groups, accents)
    reserved = reserved_words()

    schemes = sorted(SCHEME_DIR.glob("*.json"))
    if not schemes:
        sys.exit("scheme-roles: schemes/ holds no scheme file")

    # desktop-scheme falls back to this one when the state file says nothing,
    # which is every fresh clone.
    if not (SCHEME_DIR / "tokyo-night.json").is_file():
        problem("schemes/tokyo-night.json is missing, and it is the default "
                "desktop-scheme falls back to on a fresh clone")

    for path in schemes:
        check_scheme(path, vocabulary, accent_roles, reserved)

    if problems:
        print("scheme-roles: the schemes and the vocabulary disagree:",
              file=sys.stderr)
        for message in problems:
            print(f"  {message}", file=sys.stderr)
        return 1

    print(f"scheme-roles: {len(schemes)} scheme(s) fill all "
          f"{len(vocabulary)} roles of the vocabulary")
    return 0


if __name__ == "__main__":
    sys.exit(main())
