# ranger colorscheme: Tokyo Night as the base + the wallpaper accent.
#
# This is NOT a colorscheme written from scratch. It inherits from ranger's
# Default and only repaints three things: the cursor row, the path in the
# title bar and the progress bars. Everything else (directories in blue,
# executables in green, broken links in red, permissions, bookmarks...)
# stays as upstream defined it, which is already well thought out.
#
# The Tokyo Night base is not declared here: ranger paints with the 16 ANSI
# colours and those come from kitty.conf. Changing the terminal theme changes
# ranger on its own. That is why this file has not a single raw hex.
#
# The accent does come from matugen, via ~/.config/ranger/accent, which is
# regenerated on every wallpaper change. Ranger picks it up when it opens.

import os

from ranger.colorschemes.default import Default
from ranger.gui.color import reverse


# Path of the file matugen writes (see templates/ranger-accent).
ACCENT_FILE = os.path.expanduser("~/.config/ranger/accent")

# If the file does not exist yet -- first boot, or matugen failed -- it falls
# back to the usual ANSI colours instead of leaving the interface colourless.
# 6 is cyan and 3 yellow in the terminal palette.
FALLBACK = {"accent": 6, "accent2": 3}


def _nearest_256(red, green, blue):
    """Index of the xterm-256 palette closest to a given RGB.

    Curses does not take 24-bit colour, so it has to be approximated.
    Candidates are searched only between 16 and 255: the 6x6x6 cube and the
    24-step greyscale ramp. Indices 0-15 are left out ON PURPOSE --
    kitty redefines those to Tokyo Night, so their real value is not the one
    the standard states and comparing against them would give an accent that
    does not resemble the one matugen asked for.
    """
    # Colour cube levels: they are not linear, xterm defines them this way.
    levels = (0, 95, 135, 175, 215, 255)

    def closest_level(value):
        return min(range(6), key=lambda i: abs(levels[i] - value))

    r_i, g_i, b_i = (closest_level(c) for c in (red, green, blue))
    cube_index = 16 + 36 * r_i + 6 * g_i + b_i
    cube_dist = (
        (levels[r_i] - red) ** 2
        + (levels[g_i] - green) ** 2
        + (levels[b_i] - blue) ** 2
    )

    # The greyscale ramp usually wins for very desaturated colours, where
    # the cube only offers coarse steps.
    gray_value = round((red + green + blue) / 3)
    gray_step = min(23, max(0, round((gray_value - 8) / 10)))
    gray_level = 8 + 10 * gray_step
    gray_dist = (
        (gray_level - red) ** 2
        + (gray_level - green) ** 2
        + (gray_level - blue) ** 2
    )

    return 232 + gray_step if gray_dist < cube_dist else cube_index


def _load_accents():
    """Read the matugen file. Never raises: ranger would die at startup."""
    accents = dict(FALLBACK)
    try:
        with open(ACCENT_FILE, encoding="utf-8") as handle:
            for line in handle:
                parts = line.split()
                # Skip comments and the file header.
                if len(parts) != 4 or parts[0] not in accents:
                    continue
                accents[parts[0]] = _nearest_256(*(int(p) for p in parts[1:]))
    except (OSError, ValueError):
        pass
    return accents


_ACCENTS = _load_accents()
ACCENT = _ACCENTS["accent"]
ACCENT2 = _ACCENTS["accent2"]


# The class MUST be called "Scheme". This is not cosmetic.
#
# When the module does not define that name, ranger walks the module
# dictionary and takes the FIRST class inheriting from ColorScheme
# (ranger/gui/colorscheme.py). And since Default is imported here to inherit
# from it, Default enters the dictionary before this class and wins: ranger
# loaded the default colorscheme and the accent appeared nowhere. With the
# name "Scheme" the loader picks it up directly and skips that walk.
class Scheme(Default):
    def use(self, context):
        fg, bg, attr = Default.use(self, context)

        # ---- Cursor row ----
        # Default marks it with "reverse", which inverts the file's colours:
        # the cursor changes colour depending on the type of file it is on.
        # Here it becomes a solid accent bar, which is what makes the
        # wallpaper colour visible at a glance.
        #
        # The text on top goes in color0 (kitty's background) and not a fixed
        # white: if the wallpaper yields a light accent, a white would vanish.
        # Same criterion as on_primary in the GTK template.
        if context.in_browser and context.selected:
            attr &= ~reverse
            fg, bg = 0, ACCENT

        # ---- Title bar ----
        # The name at the end, which is the file the cursor is on
        # (titlebar.py adds it with the 'file' context; the path segments go
        # with 'directory').
        #
        # CAREFUL: context.directory does NOT work here. Ranger marks every
        # path segment that way, not "the current directory", so it paints
        # the whole line in the accent and the blue hierarchy is lost. With
        # 'file' the accent points at the same thing as the cursor row, which
        # is exactly the relationship worth seeing.
        elif context.in_titlebar and context.file:
            fg = ACCENT

        # ---- Tabs ----
        elif context.in_titlebar and context.tab and context.good:
            fg, bg = 0, ACCENT

        # ---- Progress bar (copies, moves) ----
        elif context.in_statusbar and context.loaded:
            fg, bg = 0, ACCENT2

        return fg, bg, attr
