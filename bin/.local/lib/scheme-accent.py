#!/usr/bin/env python3
"""scheme-accent.py -- keep the accent inside the colour scheme's own palette.

    scheme-accent.py snap SCHEME.json '#f0453d'   the nearest colour the scheme
                                                  publishes, as #rrggbb
    scheme-accent.py candidates SCHEME.json       role<TAB>hex, one per line,
                                                  the whole set snap chooses from

WHAT THIS IS FOR. The wallpaper decides WHICH accent the desktop wears and the
scheme decides WHAT that accent is. matugen pulls a colour out of the image --
a vivid #0b87e2 out of a blue picture -- and used to hand it straight to the
Material 3 derivation, so a Gruvbox desktop came out wearing a sky blue Gruvbox
does not contain and would never print. This snaps the extracted colour onto
the nearest colour the scheme itself publishes first, so that same picture
gives Gruvbox's own blue and the accent can never leave the palette.

WHICH COLOURS ARE CANDIDATES: the six ANSI chromatics and their six bright
variants, `term_red` through `term_bright_cyan`. Not `term_fg`, `term_bg` or
any of the greys -- an accent has to be a colour -- and not the `fb_*` roles
either, which answer a different question (what a clone with no wallpaper yet
should show). Duplicates are collapsed: Catppuccin Mocha gives each bright
variant the same value as its normal one, so its twelve names carry six
distinct colours; Tokyo Night and Gruvbox publish twelve apiece.

WHY THE BRIGHTS ARE IN, and the honest answer is that they mostly do not
matter and the one place they do is decisive. Measured pair by pair, as the
distance between the accents matugen derives from a normal and from its bright:
Catppuccin repeats its normals exactly, so all six pairs come out at dE2000
0.00 and its twelve names carry six colours; Tokyo Night's six pairs all land
within 1.05, under the ~2.3 that `color_match.py` documents as the threshold of
a visible difference; Gruvbox's are within 3.6 except for blue, where #458588
derives a teal #80d4d8 and #83a598 a mint #87d6bc, 11.13 apart.

That last one is why they are in. #83a598 is not just another candidate: it is
Gruvbox's own `fb_primary`, the colour the scheme file itself names as its
accent. A candidate list that stopped at the six normals would be one that
threw away the colour the scheme declares it wants to be accented with, and
"all twelve chromatics the scheme publishes" needs no such exception to
explain. Nothing is weighed against it: there is no risk of a washed accent
from a light candidate, because the seed's lightness never reaches a pixel --
see the note below.

THE DISTANCE IS CIEDE2000 WITH THE LIGHTNESS TERM DROPPED (kL -> inf, kC and kH
at 1), and that is the one judgement call in this file.

  matugen throws the seed's lightness away. Measured on 4.2.0, dark mode,
  scheme-tonal-spot: seeds #400000, #800000 and #fb4934 -- black-red to vivid
  red -- all derive the same primary #ffb4a8. Only the seed's HUE survives into
  anything a pixel ever shows. So lightness matched at this step is lightness
  discarded one step later, and weighting it can only move the pick to a worse
  hue than it would otherwise have had.

  It measurably did. Over the 58 stills in ~/Pictures/Wallpapers under all
  three schemes -- 174 pairs -- the lightness term moves the pick into a
  different colour family 22 times, and they are not 22 of a kind:

    13 it gets WRONG. Every burnt orange and warm brown lands on the palette's
       PINK rather than its gold, because at that lightness the pink is nearer:
       #9f5314, #8c562a, #b5582b, #ae4917, #976850, #eb7c47, #e08960 snap to
       Catppuccin's #f38ba8 instead of #f9e2af -- seven of them there, three
       the same way under Tokyo Night, two under Gruvbox -- plus a muted purple
       (#816491) that goes to Catppuccin's pink rather than its magenta. A
       sunset giving a pink desktop is the failure this whole file is about,
       wearing the right palette instead of the wrong one.

     7 are a toss-up. Six steel-teal blues (#32769e, #5188b5, #305d7f,
       #245c7a, #3e89a3, #328ac3) move from Tokyo Night's periwinkle blue to
       its sky cyan, which is the nearer hue and looks it, and one salmon moves
       between two Gruvbox pinks whose derived accents are dE2000 4 apart.

     2 it gets RIGHT and dropping the term costs: a bright yellow sky
       (#e8ca51) lands on Gruvbox's olive #98971a rather than its gold #fabd2f
       -- four degrees of hue nearer and duller for it -- and a dark crimson
       (#b63348) lands on the pink between red and magenta rather than on red.

  Thirteen absurd traded for two dull, and the seven in the middle read at
  least as well either way.

  CHROMA STAYS WEIGHTED at kC = 1, although it does not survive the derivation
  either. It is the guard for a wallpaper whose extracted colour comes out
  nearly grey: a hue angle read off a near-neutral is noise, and with chroma in
  the metric a washed-out seed at least prefers a washed-out candidate instead
  of snapping to a fully saturated one on the strength of it. The 58 stills
  never get near that -- the least saturated extracts at C* = 18 -- so this is
  insurance rather than a measured effect.

The arithmetic itself is not written here: `color_match.py` in color-match/
next to this file is the vendored CIEDE2000 the cursor matcher already uses,
and its parametric kL/kC/kH factors are exactly this knob. See its header.
"""

import importlib.util
import json
import math
import os
import sys

# THE CANDIDATE ORDER IS FIXED AND IS PART OF THE ANSWER. Two colours in a
# scheme can be equidistant from an extracted colour, and the same wallpaper
# has to give the same accent every time it comes up -- so the first name in
# THIS list wins a tie, rather than whatever order a dict happened to have.
# The same order collapses duplicates: a bright that repeats its normal is
# dropped in favour of the normal.
CHROMATICS = [
    "term_red", "term_green", "term_yellow",
    "term_blue", "term_magenta", "term_cyan",
    "term_bright_red", "term_bright_green", "term_bright_yellow",
    "term_bright_blue", "term_bright_magenta", "term_bright_cyan",
]


def die(message):
    print(f"scheme-accent: {message}", file=sys.stderr)
    sys.exit(1)


def load_matcher():
    """The vendored CIEDE2000, imported by path.

    By path and not by name, exactly as cursor-match does it: this file is
    found through the stow link beside the scripts, never on sys.path, and
    there is no package to install.
    """
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "color-match", "color_match.py")
    spec = importlib.util.spec_from_file_location("color_match", path)
    if spec is None or spec.loader is None:
        die(f"no colour matcher at {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def candidates(scheme_path):
    """[(role, hex)] for every distinct chromatic the scheme publishes."""
    try:
        with open(scheme_path) as handle:
            colors = json.load(handle)["colors"]
    except (OSError, ValueError, KeyError) as exc:
        die(f"cannot read the scheme at {scheme_path}: {exc}")

    seen = {}
    out = []
    for role in CHROMATICS:
        try:
            value = colors[role]["default"]["color"]
        except (KeyError, TypeError):
            # LOUD, and not a skip. A scheme missing one of these is a scheme
            # tests/scheme-roles.py should already have refused; carrying on
            # with eleven candidates would quietly narrow the palette instead.
            die(f"{scheme_path} has no {role}")
        value = value.strip().lower()
        if value in seen:
            continue
        seen[value] = role
        out.append((role, value))
    return out


def snap(matcher, target, cands):
    """The candidate nearest TARGET, ignoring lightness. Returns (role, hex)."""
    try:
        target_lab = matcher.hex_to_lab(target)
    except ValueError as exc:
        die(str(exc))

    best_role, best_hex, best_distance = None, None, math.inf
    for role, value in cands:
        # kL = inf drops the lightness term; kC and kH stay at the spec's
        # defaults. The header argues both.
        distance = matcher.ciede2000(target_lab, matcher.hex_to_lab(value),
                                     math.inf, 1.0, 1.0)
        # Strictly less, so a tie leaves the earlier candidate in place and the
        # order in CHROMATICS is what decides it.
        if distance < best_distance:
            best_role, best_hex, best_distance = role, value, distance
    return best_role, best_hex


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        print("usage: scheme-accent.py snap SCHEME.json '#rrggbb'\n"
              "       scheme-accent.py candidates SCHEME.json", file=sys.stderr)
        sys.exit(2)

    mode, scheme_path = sys.argv[1], sys.argv[2]
    cands = candidates(scheme_path)

    if mode == "candidates":
        for role, value in cands:
            print(f"{role}\t{value}")
        return

    if mode != "snap":
        die(f"unknown command: {mode}")
    if len(sys.argv) < 4:
        die("snap needs the colour to snap")

    _, value = snap(load_matcher(), sys.argv[3], cands)
    print(value)


if __name__ == "__main__":
    main()
