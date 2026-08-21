#!/usr/bin/env python3
"""Check that the two compositors really do have the same keybinds.

The README's headline claim about this repo is that every keybind is identical
under Hyprland and niri. Nothing verified it, and by the time this was written
the two files had already drifted in five places -- all of them the kind of
drift nobody notices, because a bind that works but is missing its label is
invisible exactly where you would go looking for it (the cheatsheet under
Hyprland, the hotkey overlay under niri).

WHAT IS COMPARED, AND WHAT DELIBERATELY IS NOT.

  * The chord. Both sides must bind it, spelled however each config spells it.
  * Whether the chord carries a human label -- `description` on the Hyprland
    side, `hotkey-overlay-title` on the niri side. Both or neither.

  * NOT the text of that label, and not the action behind the chord. Four
    Hyprland actions have no niri equivalent and their chords were
    deliberately reused for the nearest thing niri does (pseudotile became
    "cycle the column width", and so on) -- see the Compositors section of the
    README. Comparing the text would flag every one of those as a difference
    when the difference is the whole point.

Anything genuinely asymmetric is declared in bind-exceptions.toml with a
reason. An exception without a reason is a failure, and so is an exception
that no longer applies: the file is meant to be a list of decisions, not a
place where old ones go to rot.

Run it from anywhere:  tests/bind-parity.py
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HYPR_DIR = REPO / "hypr/.config/hypr"
NIRI_CONFIG = REPO / "niri/.config/niri/config.kdl"
STUB = Path(__file__).resolve().parent / "hl-stub.lua"
EXCEPTIONS = Path(__file__).resolve().parent / "bind-exceptions.toml"

HYPRLAND, NIRI = "hyprland", "niri"
SIDES = (HYPRLAND, NIRI)


# --------------------------------------------------------------------------
# Normalising a chord
# --------------------------------------------------------------------------
# The two configs spell the same chord differently and both spellings are
# correct in their own file: Hyprland's `mainMod .. " + SHIFT + F"` and niri's
# `Mod+Shift+F` are one bind. Everything is folded to one canonical form --
# uppercase, modifiers in a fixed order, " + " between the parts -- so that
# comparison is a set operation and the error messages read the same whichever
# side is missing.

# Modifiers, in the order they are printed. SUPER first because that is how
# both files read, and because the cheatsheet shows it that way.
MODIFIER_ORDER = ("SUPER", "CTRL", "ALT", "SHIFT")

MODIFIERS = {
    "SUPER": "SUPER", "MOD": "SUPER", "WIN": "SUPER", "LOGO": "SUPER",
    "CTRL": "CTRL", "CONTROL": "CTRL",
    "ALT": "ALT", "MOD1": "ALT",
    "SHIFT": "SHIFT",
}

# Keys whose two spellings are not just a matter of case. Everything not in
# here is compared uppercased, which already covers the letters, the digits,
# the arrows and the whole XF86 family -- the two files agree on those names
# and only disagree on capitalisation.
KEYS = {
    # Hyprland accepts both; niri only knows Return.
    "ENTER": "RETURN",
    "ESC": "ESCAPE",
    # A wheel notch. Hyprland calls the direction after the scroll button
    # (mouse_down is a notch towards you), niri after what the wheel is doing.
    "MOUSE_DOWN": "WHEELSCROLLDOWN",
    "MOUSE_UP": "WHEELSCROLLUP",
}


def normalise(chord: str) -> str:
    """Fold one chord to the spelling both sides are compared in."""
    parts = [p.strip() for p in chord.split("+") if p.strip()]
    mods, keys = set(), []
    for part in parts:
        upper = part.upper()
        if upper in MODIFIERS:
            mods.add(MODIFIERS[upper])
        else:
            keys.append(KEYS.get(upper, upper))
    ordered = [m for m in MODIFIER_ORDER if m in mods]
    return " + ".join(ordered + keys)


# --------------------------------------------------------------------------
# The Hyprland side
# --------------------------------------------------------------------------

def read_hyprland() -> dict[str, str]:
    """Every bind Hyprland would end up with, as {chord: description}.

    The config is executed rather than read -- see tests/hl-stub.lua for why
    that is the only way to get the twenty workspace binds that come out of a
    loop. HOME points at an empty directory for the duration: hyprland.lua
    ends with `pcall(dofile, ~/.config/hypr/tweaks.lua)`, and on a machine
    that has this desktop installed that file exists and adds binds which are
    not in the repo. Without this the check would pass or fail depending on
    whose machine it ran on.
    """
    # THE ENTRY POINT ONLY, and not every .lua in the directory: hyprland.lua
    # pulls gaming.lua in itself through `require`, and running a required file
    # a second time on its own would report half these binds twice.
    config = HYPR_DIR / "hyprland.lua"
    if not config.is_file():
        die(f"{config} is missing")

    binds: dict[str, str] = {}
    with tempfile.TemporaryDirectory() as empty_home:
        result = subprocess.run(
            ["lua", str(STUB), str(config)],
            capture_output=True, text=True, check=False,
            env={"HOME": empty_home, "PATH": os.environ.get("PATH", "/usr/bin")},
        )
        if result.returncode != 0:
            die(f"could not run {config}:\n{result.stderr.strip()}")
        for line in result.stdout.splitlines():
            chord, _, description = line.partition("\t")
            binds[normalise(chord)] = description
    return binds


# --------------------------------------------------------------------------
# The niri side
# --------------------------------------------------------------------------

# A bind line: the chord, then any number of key=value properties, then the
# action in braces. `Mod+Shift+E hotkey-overlay-title="..." { spawn "..."; }`
NIRI_BIND = re.compile(r"""^\s*(?P<chord>[^\s{}"]+)(?P<props>[^{}]*)\{""")
NIRI_TITLE = re.compile(r"""hotkey-overlay-title="(?P<title>[^"]*)\"""")


def read_niri() -> dict[str, str]:
    """Every bind in the `binds { }` block, as {chord: hotkey-overlay-title}.

    KDL is read with a regular expression and not with a parser, because the
    only thing worth a dependency here would be a real KDL library and there
    is none in the base install. What keeps that honest is `niri validate`,
    which runs in the same workflow: this function never sees a file niri
    itself would reject, so it only has to cope with valid KDL.
    """
    binds: dict[str, str] = {}
    depth, inside = 0, False
    for raw in NIRI_CONFIG.read_text().splitlines():
        # Comments first. Quoted strings in this file never contain "//", and
        # `niri validate` guarantees the file parses, so this stays simple.
        line = raw.split("//", 1)[0]
        if not line.strip():
            continue

        if not inside:
            if re.match(r"^\s*binds\s*\{", line):
                inside, depth = True, 1
            continue

        # Inside the block. A bind occupies one line and balances its own
        # braces; depth only moves if somebody writes a multi-line one, and
        # then its continuation lines are skipped rather than misread.
        if depth == 1:
            match = NIRI_BIND.match(line)
            if match:
                title = NIRI_TITLE.search(match.group("props"))
                binds[normalise(match.group("chord"))] = title.group("title") if title else ""

        depth += line.count("{") - line.count("}")
        if depth <= 0:
            break

    if not binds:
        die(f"found no binds in {NIRI_CONFIG} -- has the block moved?")
    return binds


# --------------------------------------------------------------------------
# Declared exceptions
# --------------------------------------------------------------------------

class Exceptions:
    """The deliberate asymmetries, and whether each one was used."""

    def __init__(self) -> None:
        data = tomllib.loads(EXCEPTIONS.read_text())
        self.chord_only: dict[str, tuple[str, str]] = {}   # chord -> (side, reason)
        self.label_only: dict[str, tuple[str, str]] = {}   # chord -> (side, reason)
        self.used: set[tuple[str, str]] = set()
        self.errors: list[str] = []

        for kind, target in (("chord", self.chord_only), ("label", self.label_only)):
            for entry in data.get(kind, []):
                chords = entry.get("chords") or [entry.get("chord")]
                side = entry.get("side")
                reason = (entry.get("reason") or "").strip()
                for chord in chords:
                    if not chord or side not in SIDES:
                        self.errors.append(
                            f"[[{kind}]] entry needs a chord and a side of "
                            f"{SIDES}, got chord={chord!r} side={side!r}")
                        continue
                    # An undocumented exception is worse than no exception: it
                    # silences the check and leaves nobody able to say why.
                    if not reason:
                        self.errors.append(
                            f"[[{kind}]] {chord} is declared with no reason")
                        continue
                    target[normalise(chord)] = (side, reason)

    def allows_chord(self, chord: str, side: str) -> bool:
        entry = self.chord_only.get(chord)
        if entry and entry[0] == side:
            self.used.add(("chord", chord))
            return True
        return False

    def allows_label(self, chord: str, side: str) -> bool:
        entry = self.label_only.get(chord)
        if entry and entry[0] == side:
            self.used.add(("label", chord))
            return True
        return False

    def stale(self) -> list[str]:
        """Exceptions that no longer excuse anything.

        Reported as failures on purpose. A stale entry is an exception waiting
        to hide a real regression: the day somebody deletes that bind for real,
        a leftover line here would wave it through.
        """
        out = []
        for kind, table in (("chord", self.chord_only), ("label", self.label_only)):
            for chord in table:
                if (kind, chord) not in self.used:
                    out.append(f"[[{kind}]] {chord} no longer applies -- delete it")
        return sorted(out)


# --------------------------------------------------------------------------

def die(message: str) -> None:
    print(f"bind-parity: {message}", file=sys.stderr)
    sys.exit(2)


def other(side: str) -> str:
    return NIRI if side == HYPRLAND else HYPRLAND


def main() -> int:
    hypr, niri = read_hyprland(), read_niri()
    exceptions = Exceptions()
    failures = list(exceptions.errors)

    binds = {HYPRLAND: hypr, NIRI: niri}
    for side in SIDES:
        for chord in sorted(binds[side]):
            if chord in binds[other(side)]:
                continue
            if exceptions.allows_chord(chord, side):
                continue
            failures.append(
                f"{chord}: bound under {side}, missing under {other(side)}")

    for chord in sorted(set(hypr) & set(niri)):
        labelled = {side: bool(binds[side][chord]) for side in SIDES}
        if labelled[HYPRLAND] == labelled[NIRI]:
            continue
        has = HYPRLAND if labelled[HYPRLAND] else NIRI
        if exceptions.allows_label(chord, has):
            continue
        field = "description" if has == HYPRLAND else "hotkey-overlay-title"
        failures.append(
            f"{chord}: {has} gives it a {field} "
            f"({binds[has][chord]!r}), {other(has)} gives it none")

    failures.extend(exceptions.stale())

    print(f"bind-parity: {len(hypr)} binds under Hyprland, "
          f"{len(niri)} under niri, "
          f"{len(exceptions.chord_only) + len(exceptions.label_only)} declared exceptions")
    if failures:
        print()
        for failure in failures:
            print(f"  FAIL  {failure}")
        print(f"\n{len(failures)} divergence(s). Fix the config, or declare the "
              f"asymmetry with a reason in {EXCEPTIONS.relative_to(REPO)}.")
        return 1

    print("bind-parity: the two compositors agree")
    return 0


if __name__ == "__main__":
    sys.exit(main())
