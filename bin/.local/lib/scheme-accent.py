#!/usr/bin/env python3
"""scheme-accent.py -- keep the accent inside the colour scheme's own palette.

    scheme-accent.py snap SCHEME.json '#f0453d'   the nearest colour the scheme
                                                  publishes, as #rrggbb
    scheme-accent.py accent SCHEME.json '#f0453d' the whole Material 3 accent
                                                  family built round it, as the
                                                  JSON matugen imports
    scheme-accent.py candidates SCHEME.json       role<TAB>hex, one per line,
                                                  the whole set snap chooses from

WHAT THIS IS FOR. The wallpaper decides WHICH accent the desktop wears and the
scheme decides WHAT that accent is. matugen pulls a colour out of the image --
a vivid #0b87e2 out of a blue picture -- and used to hand it straight to the
Material 3 derivation, so a Gruvbox desktop came out wearing a sky blue Gruvbox
does not contain and would never print. This snaps the extracted colour onto
the nearest colour the scheme itself publishes first, so that same picture
gives Gruvbox's own blue and the accent can never leave the palette.

SNAPPING WAS HALF OF IT. The other half is that matugen was then handed the
snapped colour as a SEED and re-derived the family from it, keeping only its
hue -- so Gruvbox's muted #83a598 came back as the mint #87d6bc and every
scheme, restrained or loud, produced an equally loud accent. `accent` is the
answer to that: it builds the nine roles here, out of the scheme's own
colours, and matugen is given them rather than asked for them. The long
version is above `relative_luminance`, further down.

WHICH COLOURS ARE CANDIDATES: the six ANSI chromatics and their six bright
variants, `term_red` through `term_bright_cyan`. Not `term_fg`, `term_bg` or
any of the greys -- an accent has to be a colour -- and not the `fb_*` roles
either, which answer a different question (what a clone with no wallpaper yet
should show). Duplicates are collapsed: Catppuccin Mocha gives each bright
variant the same value as its normal one, so its twelve names carry six
distinct colours; Tokyo Night and Gruvbox publish twelve apiece.

WHY THE BRIGHTS ARE IN. The measurement that used to be here compared the
accents matugen DERIVED from a normal and from its bright, and found the two
mostly collapsed onto the same colour. That comparison no longer describes
anything: the candidate is now the accent, so a normal and its bright are as
far apart on screen as they are in the palette -- Gruvbox's #458588 and
#83a598 are simply two different colours, not two seeds for one mint.

What survives is the reason that never depended on the derivation. #83a598 is
not just another candidate: it is Gruvbox's own `fb_primary`, the colour the
scheme file itself names as its accent. A candidate list that stopped at the
six normals would be one that threw away the colour the scheme declares it
wants to be accented with, and "all twelve chromatics the scheme publishes"
needs no such exception to explain.

THE DISTANCE IS CIEDE2000 WITH THE LIGHTNESS TERM DROPPED (kL -> inf, kC and kH
at 1), and that is the one judgement call in this file.

  READ THE NEXT PARAGRAPH BEFORE THE ONE AFTER IT. The argument for dropping
  the term used to be that matugen discarded the seed's lightness anyway, so
  matching it here was work undone one step later. That premise is GONE: since
  `accent` below supplies the family instead of letting matugen derive it, the
  candidate's lightness and its chroma both reach the screen exactly as the
  scheme publishes them. Every sentence that rested on "the seed's lightness
  never reaches a pixel" has been removed rather than reworded, because it is
  no longer true.

  The term stays dropped all the same, and now for the reason that was always
  the load-bearing one: WEIGHTING LIGHTNESS PICKS A WORSE HUE. That was
  measured independently of what happens downstream, and the measurement is
  unchanged by any of this.

  Over the 58 stills in ~/Pictures/Wallpapers under all three schemes -- 174
  pairs -- the lightness term moves the pick into a different colour family 22
  times, and they are not 22 of a kind:

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

  CHROMA STAYS WEIGHTED at kC = 1, and unlike lightness it now survives all the
  way to the screen. It is the guard for a wallpaper whose extracted colour
  comes out nearly grey: a hue angle read off a near-neutral is noise, and with
  chroma in the metric a washed-out seed at least prefers a washed-out
  candidate instead of snapping to a fully saturated one on the strength of it.
  The 58 stills never get near that -- the least saturated extracts at
  C* = 18 -- so this is insurance rather than a measured effect.

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

# THE NINE ROLES A TEMPLATE CAN ACTUALLY ASK FOR. Counted rather than assumed:
# these are every Material 3 accent role referenced by the fourteen templates
# in matugen/config.toml, and there are no others -- no `*_fixed`, no
# `inverse_primary`, no `on_secondary`, no `tertiary_container`. The scheme
# files' `fb_*` block carries exactly these nine names and no more, which is
# not a coincidence: it was written as the fallback for the same set.
ACCENT_ROLES = [
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "secondary_container", "on_secondary_container",
    "tertiary", "on_tertiary",
]

# WHAT MAY BE PUT ON TOP OF AN ACCENT FILL, in the scheme's own words.
# `ui_on_accent` is the role the scheme file names for exactly this job;
# `ui_surface` is its darkest base surface and `ui_text` its body text. The
# pick between them is by measured contrast, per accent, rather than fixed --
# see `on_for`.
ON_POOL = ["ui_on_accent", "ui_surface", "ui_text"]

# THE FLOOR, AND IT IS 3.0 RATHER THAN 4.5 ON PURPOSE.
#
# 4.5:1 is WCAG's bar for body text; 3:1 is its bar for user-interface
# components and large text, and that is what these pairs are -- a label on a
# filled button, a tab, a badge. The distinction matters here because the
# palette cannot always reach 4.5 and it is this file's own fidelity rule that
# put it in that position.
#
# Measured over all 30 distinct candidates in the three schemes: Tokyo Night
# bottoms out at 7.29:1 and Catppuccin at 8.10:1 -- both far clear. Gruvbox
# reaches 4.5 on nine of its twelve and lands at 3.99 (`term_red #cc241d`),
# 3.48 (`term_blue #458588`) and 3.48 (`term_magenta #b16286`) on the other
# three. Those three are mid-lightness colours, L* 44 to 52, and NOTHING
# Gruvbox publishes contrasts 4.5:1 with them: pooling all 78 roles instead of
# these three only lifts the worst case to 3.87.
#
# That is the price of the fidelity, and it is worth naming what buys it back.
# Material 3 never meets this problem because it lifts every accent to about
# L* 80 before showing it -- which is precisely the loudness this file exists
# to remove. A Gruvbox desktop whose accent is Gruvbox's own mid blue, with a
# label on it at 3.48:1, is the thing that was asked for; the same desktop at
# 4.5:1 is one wearing a colour Gruvbox does not publish.
#
# So the floor is the UI-component bar, it is enforced rather than hoped for,
# and a scheme that cannot clear even that does not render at all.
MIN_CONTRAST = 3.0

# THE HUE OFFSETS, AND THEY ARE MATERIAL 3'S OWN. M3 builds `tertiary` a
# sixty-degree turn from `primary`; `secondary` is a subdued same-hue in M3,
# which cannot be expressed by PICKING from a palette -- picking the nearest
# hue to the primary's own would just return the primary again. So secondary
# takes the next turn round instead, 120 degrees, and the two of them plus the
# primary read as a triad drawn entirely from the scheme's own colours.
#
# Which of the two gets the near turn is decided by what reads them.
# `tertiary` is the accent2 of the Hyprland and niri border gradient, ranger's
# second colour and zathura's highlight -- thirteen references against
# `secondary`'s three, and the gradient in particular wants a colour that
# sweeps out of the primary rather than fights it. Sixty degrees does that.
TERTIARY_TURN = 60.0
SECONDARY_TURN = 120.0

# HOW FAR THE CONTAINER IS MIXED BACK INTO THE SURFACE, and the number is
# measured rather than picked. Three things had to hold at once, over all 30
# distinct candidates in the three schemes:
#
#   * the container must stay clear of the primary, or a chip and the accent
#     beside it are the same colour. At this amount the gap is 17.5 to 43.3 L*.
#   * it must stay clear of the surface, or the chip has no edge. The gap is
#     10.9 to 41.9 L*, and Gruvbox's own surface ladder climbs in rungs of
#     about 8, so even the narrowest is more than one rung.
#   * `on_primary_container` must not FLIP. Below about 0.5 the lightest
#     candidates -- Catppuccin's #f9e2af, Tokyo Night's #a4daff -- mix to a
#     container light enough that the scheme's dark colour wins the contrast
#     measurement and the chip's text turns from light to dark depending on
#     the wallpaper. At 0.55 the scheme's text colour wins everywhere, by
#     3.42:1 at worst, so the chip reads the same way whatever is on screen.
#
# The cost is fit: 0.45 reproduces Tokyo Night's hand-filled #3d59a1 to
# dE2000 3.66 and this reproduces it to 6.23. A container two shades off one
# scheme's hand-made value is worth less than a chip whose text colour is
# stable, so the flip is what decided it.
CONTAINER_MIX = 0.55


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


def load_scheme(scheme_path):
    """The scheme's whole `colors` block."""
    try:
        with open(scheme_path) as handle:
            return json.load(handle)["colors"]
    except (OSError, ValueError, KeyError) as exc:
        die(f"cannot read the scheme at {scheme_path}: {exc}")


def role(colors, name, scheme_path):
    """One published colour, or a `die` naming the role that is missing.

    LOUD, like `candidates` below and for the same reason: a scheme short of a
    role this file builds the accent out of is one `tests/scheme-roles.py`
    should already have refused, and carrying on would mean rendering the
    desktop with a hole in the accent family instead of saying so.
    """
    try:
        value = colors[name]["default"]["color"]
    except (KeyError, TypeError):
        die(f"{scheme_path} has no {name}")
    return value.strip().lower()


def candidates(scheme_path, colors=None):
    """[(role, hex)] for every distinct chromatic the scheme publishes."""
    if colors is None:
        colors = load_scheme(scheme_path)

    seen = {}
    out = []
    for name in CHROMATICS:
        try:
            value = colors[name]["default"]["color"]
        except (KeyError, TypeError):
            # LOUD, and not a skip. A scheme missing one of these is a scheme
            # tests/scheme-roles.py should already have refused; carrying on
            # with eleven candidates would quietly narrow the palette instead.
            die(f"{scheme_path} has no {name}")
        value = value.strip().lower()
        if value in seen:
            continue
        seen[value] = name
        out.append((name, value))
    return out


def snap(matcher, target, cands):
    """The candidate nearest TARGET, ignoring lightness. Returns (role, hex)."""
    try:
        target_lab = matcher.hex_to_lab(target)
    except ValueError as exc:
        die(str(exc))

    best_role, best_hex, best_distance = None, None, math.inf
    for name, value in cands:
        # kL = inf drops the lightness term; kC and kH stay at the spec's
        # defaults. The header argues both.
        distance = matcher.ciede2000(target_lab, matcher.hex_to_lab(value),
                                     math.inf, 1.0, 1.0)
        # Strictly less, so a tie leaves the earlier candidate in place and the
        # order in CHROMATICS is what decides it.
        if distance < best_distance:
            best_role, best_hex, best_distance = name, value, distance
    return best_role, best_hex


# ---------------------------------------------------------------------------
# The rest of the accent family
# ---------------------------------------------------------------------------
#
# WHY THERE IS ANYTHING HERE AT ALL. Snapping fixed which colour the accent is
# derived FROM and did not fix what came out. matugen re-derives the Material 3
# family from the snapped colour as a seed, and in `scheme-tonal-spot` dark
# mode that derivation keeps the seed's HUE and throws its lightness and its
# chroma away -- the same measurement the header makes for lightness holds for
# chroma, and the two together are the whole of a colour's tone:
#
#     seed #400000  ->  primary #ffb4a8      seed #cc241d  ->  primary #ffb4a9
#     seed #800000  ->  primary #ffb4a8      seed #fb4934  ->  primary #ffb4a8
#
# So Gruvbox's muted blue #83a598 was snapped correctly and came back as the
# mint #87d6bc, and a restrained palette and a loud one produced equally loud
# accents. The hue belonged to the scheme; nothing else did.
#
# WHAT MAKES IT STICK is that a role supplied through `--import-json-string`
# overrides the one matugen derived -- verified against 4.2.0, and it is
# already how the seventy-eight scheme roles reach the templates. Two details
# of it are load-bearing and both were measured:
#
#   * THE IMPORT MUST CARRY MATUGEN'S OWN NESTED SHAPE. A flat
#     `{"primary": "#83a598"}` is accepted and silently ignored -- the render
#     still shows the derived #87d6bc. Only
#     `{"colors": {"primary": {"default": {"color": "#83a598"}}}}` overrides.
#     That is why `payload` below builds the nesting rather than a flat map.
#
#   * ONE `color` FILLS EVERY FORMAT. An imported `.default.color` comes out
#     of the render as `.hex`, `.hex_stripped`, `.rgb`, `.rgba`, `.hsl` and
#     the separate `.red` / `.green` / `.blue` that ranger and zathura read.
#     `.dark` and `.light` are NOT filled from it -- they are siblings, not
#     children -- and nothing has to be done about that because all fourteen
#     templates read `.default` and only `.default`.
#
# NOTHING BELOW INVENTS A COLOUR, which is the rule the scheme vocabulary
# already sets for itself. Every one of the nine roles is either a colour the
# scheme publishes or a straight mix of two of them, so the family cannot
# drift out of the palette any more than the snapped primary can. It also
# means no colour arithmetic runs backwards: hues are read off published
# colours to CHOOSE between them, mixes happen in sRGB the way the scheme
# files' own `Util.blend` does, and there is no Lab-to-sRGB step to put a
# result out of gamut.


def relative_luminance(matcher, value):
    """WCAG 2.x relative luminance."""
    channels = []
    for component in matcher.hex_to_rgb(value):
        channels.append(component / 12.92 if component <= 0.03928
                        else ((component + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(matcher, one, other):
    """WCAG 2.x contrast ratio, 1.0 to 21.0."""
    a = relative_luminance(matcher, one)
    b = relative_luminance(matcher, other)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


def hue_of(matcher, value):
    """The CIELAB hue angle in degrees, 0 to 360."""
    _, a, b = matcher.hex_to_lab(value)
    return math.degrees(math.atan2(b, a)) % 360.0


def mix(matcher, one, other, amount):
    """`other` mixed into `one` by AMOUNT, in sRGB.

    In sRGB and not in a linear or perceptual space because that is what the
    scheme files themselves used: the two Tokyo Night roles that had to be
    derived rather than published are `Util.blend` -- upstream's own function
    -- over their two neighbours. A second mixing rule here would put two
    different meanings on the same word.
    """
    out = []
    for a, b in zip(matcher.hex_to_rgb(one), matcher.hex_to_rgb(other)):
        out.append(round(255 * (a * (1.0 - amount) + b * amount)))
    return "#%02x%02x%02x" % tuple(out)


def on_for(matcher, colors, scheme_path, fill, what):
    """The most legible of the scheme's on-accent colours, over FILL.

    Measured per accent rather than fixed, and the difference is the whole
    point of measuring: the scheme files answer this once, with
    `ui_on_accent`, because their own accent is fixed too. Ours moves over
    twelve candidates whose lightness runs from L* 44 to L* 91, and the same
    dark answer cannot serve both ends of that -- Catppuccin's `term_yellow`
    #f9e2af wants the dark one at 12.91:1 and Gruvbox's `term_red` #cc241d
    wants the light one, the dark being 2.69:1 on it.
    """
    best_value, best_ratio = None, -1.0
    for name in ON_POOL:
        value = role(colors, name, scheme_path)
        ratio = contrast(matcher, fill, value)
        # Strictly greater, so ON_POOL's order breaks a tie and the same
        # wallpaper gives the same answer every time it comes up.
        if ratio > best_ratio:
            best_value, best_ratio = value, ratio
    if best_ratio < MIN_CONTRAST:
        die(f"nothing {os.path.basename(scheme_path)} publishes is legible on "
            f"{what} {fill}: the best of {', '.join(ON_POOL)} is {best_value} "
            f"at {best_ratio:.2f}:1, under the {MIN_CONTRAST:.1f}:1 floor")
    return best_value


def turn_to(matcher, cands, primary, turn):
    """The candidate whose hue sits nearest PRIMARY's, turned by TURN degrees.

    Never the primary itself and never one already spoken for: a triad of one
    colour is not a triad, and the Hyprland border would be a gradient between
    a colour and itself. With fewer distinct chromatics than roles to fill --
    Catppuccin publishes six -- the walk to the next-nearest is what keeps
    them apart.
    """
    want = (hue_of(matcher, primary) + turn) % 360.0
    ranked = []
    for index, (name, value) in enumerate(cands):
        gap = abs(hue_of(matcher, value) - want) % 360.0
        gap = min(gap, 360.0 - gap)
        # The index keeps the sort total, so CHROMATICS' order breaks a tie
        # between two candidates the same distance round the wheel.
        ranked.append((gap, index, value))
    ranked.sort()
    return ranked


def family(matcher, colors, scheme_path, primary):
    """The nine Material 3 accent roles, built round PRIMARY."""
    cands = candidates(scheme_path, colors)

    # `taken` is what keeps the triad distinct. The primary is in it before
    # anything is chosen, so neither turn can land back on it.
    taken = {primary}
    picked = {}
    for role_name, turn in (("tertiary", TERTIARY_TURN),
                            ("secondary", SECONDARY_TURN)):
        for _, _, value in turn_to(matcher, cands, primary, turn):
            if value not in taken:
                picked[role_name] = value
                taken.add(value)
                break
        else:
            # Reached only by a scheme publishing fewer than three distinct
            # chromatics, which `tests/scheme-roles.py` would not accept. Loud
            # rather than a repeat: a gradient from a colour to itself is a
            # border that looks broken rather than one that looks plain.
            die(f"{os.path.basename(scheme_path)} publishes too few distinct "
                f"chromatics to build an accent triad")

    # A CONTAINER IS A MUTED TINT OF THE ACCENT, which is what the role means
    # in Material 3 and what the hand-filled `fb_primary_container` is in the
    # two schemes that could fill it: Tokyo Night's #3d59a1 under #7aa2f7 is
    # this mix of its own primary toward its darkest surface to within
    # dE2000 3.7, at very nearly this amount.
    #
    # IT ALSO FIXES A DEFECT THE SCHEME FILES RECORD. Catppuccin Mocha
    # publishes no darkened variant of any accent, so the hand-filled
    # `fb_primary_container` fell back on the neutral `surface1 #45475a`
    # -- schemes/README.md
    # names the lost hue as the cost. Mixing reaches the tint the palette does
    # not contain without inventing one, because both ends of the mix are the
    # scheme's own.
    surface = role(colors, "ui_surface", scheme_path)
    container = mix(matcher, primary, surface, CONTAINER_MIX)

    # `secondary_container` and `on_secondary_container` are the scheme's own
    # answers, unchanged: all three files fill them with
    # `ui_surface_container_highest` and `ui_text`. They are a raised surface
    # and the text on it rather than a tint of the accent, so the wallpaper has
    # no say in them and there is nothing for this file to move.
    secondary_container = role(colors, "ui_surface_container_highest",
                               scheme_path)

    return {
        "primary": primary,
        "on_primary": on_for(matcher, colors, scheme_path, primary,
                             "the accent"),
        "primary_container": container,
        "on_primary_container": on_for(matcher, colors, scheme_path, container,
                                       "the accent container"),
        "secondary": picked["secondary"],
        "secondary_container": secondary_container,
        "on_secondary_container": on_for(matcher, colors, scheme_path,
                                         secondary_container,
                                         "the secondary container"),
        "tertiary": picked["tertiary"],
        "on_tertiary": on_for(matcher, colors, scheme_path, picked["tertiary"],
                              "the second accent"),
    }


def payload(roles):
    """The family in the shape matugen accepts as an override.

    The nesting is not decoration: the flat form is ignored in silence. See
    the note above.
    """
    return {"colors": {name: {"default": {"color": roles[name]}}
                       for name in ACCENT_ROLES}}


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        print("usage: scheme-accent.py snap SCHEME.json '#rrggbb'\n"
              "       scheme-accent.py accent SCHEME.json '#rrggbb'\n"
              "       scheme-accent.py candidates SCHEME.json", file=sys.stderr)
        sys.exit(2)

    mode, scheme_path = sys.argv[1], sys.argv[2]
    colors = load_scheme(scheme_path)
    cands = candidates(scheme_path, colors)

    if mode == "candidates":
        for name, value in cands:
            print(f"{name}\t{value}")
        return

    if mode not in ("snap", "accent"):
        die(f"unknown command: {mode}")
    if len(sys.argv) < 4:
        die(f"{mode} needs the colour to snap")

    matcher = load_matcher()
    _, value = snap(matcher, sys.argv[3], cands)

    if mode == "snap":
        print(value)
        return

    # `separators` and `sort_keys` are not tidiness. This goes onto a command
    # line one argument wide, so it has to be one line -- and the same
    # wallpaper under the same scheme has to produce the same bytes every
    # time, which a dict's insertion order does not promise across versions.
    print(json.dumps(payload(family(matcher, colors, scheme_path, value)),
                     separators=(",", ":"), sort_keys=True))


if __name__ == "__main__":
    main()
