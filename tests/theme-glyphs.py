#!/usr/bin/env python3
"""A theme that ships its own icon font must map every glyph it draws.

WHY THIS EXISTS, AND WHAT IT IS ACTUALLY GUARDING.

`Icons.qml` publishes 105 named glyphs and a theme may override any of them in
`themes/<name>/icons.json`. The override is an OVERLAY, not a replacement: a
name the theme does not list keeps the codepoint the shell shipped, which is a
Nerd Font one.

That is the right default and it is a trap for a theme that also names its own
FONT. The windows theme sets `"font": {"source": "theme", "family": "Segoe UI
Variable Static Text"}` and relies on a fontconfig rule to reach Segoe Fluent
Icons for the Private Use Area. So an unmapped name asks Segoe for a Nerd Font
codepoint -- and the two overlap heavily. Measured: of the 92 codepoints
`icons.json` names, 82 also exist in JetBrainsMono NL Nerd Font.

So the failure is NOT a missing glyph. It is A DIFFERENT GLYPH THAT LOOKS
DELIBERATE: the power button as a stack of coins, the wifi arc as a triangle,
the volume icon as a domino. Nothing looks broken, which is why nobody would
find it by looking at one screenshot.

WHAT THIS DOES NOT CHECK. That the codepoint is in the font -- `icons.json`'s
values were checked against the font's cmap when they were written, and doing
it here would need the font installed, which is not a thing a test may assume.
And it says nothing about whether a glyph is the RIGHT glyph. It answers one
question: does the theme have an answer at all for every name it draws.

A theme with no `icons.json` is not checked, because it is not claiming to have
its own icon set and its glyphs are the shell's.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELL = REPO / "quickshell/.config/quickshell"
THEMES = SHELL / "themes"

# `Icons.resolve(name)` is a FUNCTION, not a glyph -- it turns an application's
# icon name into an image URL. It is the one member of Icons that is not one of
# the 105.
NOT_A_GLYPH = {"resolve"}

# Comments name glyphs while explaining them, so they come off first. Without
# this, a file documenting why it does NOT use a glyph would be reported as
# using it.
COMMENT = re.compile(r"//[^\n]*")
GLYPH = re.compile(r"Icons\.([a-zA-Z][a-zA-Z0-9]*)")


def note(msg: str) -> None:
    print(f"theme-glyphs: {msg}")


def fail(msg: str) -> None:
    print(f"theme-glyphs: FAIL {msg}", file=sys.stderr)


def tracked(pattern: str) -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "--", pattern],
        cwd=REPO, capture_output=True, text=True, check=True,
    )
    return [line for line in out.stdout.splitlines() if line]


def main() -> int:
    # Through git ls-files and not a directory walk, for the reason
    # tests/qml-lint.sh records: a worktree left under the checkout is a whole
    # second copy of the repository.
    manifests = tracked("*manifest.json")
    if not manifests:
        fail("no theme found -- looked for a manifest.json in git ls-files")
        return 1

    checked = 0
    failures = 0

    for manifest in manifests:
        theme_dir = REPO / Path(manifest).parent
        icons_json = theme_dir / "icons.json"
        if not icons_json.exists():
            continue

        try:
            mapped = set(json.loads(icons_json.read_text()))
        except json.JSONDecodeError as exc:
            fail(f"{icons_json.relative_to(REPO)} is not JSON: {exc}")
            failures += 1
            continue

        used: dict[str, set[str]] = {}
        for qml in sorted(theme_dir.rglob("*.qml")):
            text = COMMENT.sub("", qml.read_text())
            for match in GLYPH.finditer(text):
                name = match.group(1)
                if name in NOT_A_GLYPH:
                    continue
                used.setdefault(name, set()).add(
                    str(qml.relative_to(theme_dir))
                )

        # The floor every other check here has: an assertion over an empty set
        # is not an assertion. A theme whose files moved out from under the
        # sweep would pass in exactly the way a correct one does.
        if not used:
            fail(
                f"{theme_dir.name} ships an icons.json and draws no glyph at "
                "all -- the sweep found nothing, which is not an answer"
            )
            failures += 1
            continue

        checked += 1
        missing = sorted(name for name in used if name not in mapped)
        if missing:
            fail(
                f"{theme_dir.name} draws {len(missing)} glyph(s) its "
                "icons.json does not name"
            )
            for name in missing:
                where = ", ".join(sorted(used[name]))
                print(f"theme-glyphs:   {name} -- {where}", file=sys.stderr)
            print(
                "theme-glyphs: an unmapped name keeps the shell's Nerd Font "
                "codepoint, and this theme asks a different font for it",
                file=sys.stderr,
            )
            print(
                "theme-glyphs: the failure is not a missing glyph, it is a "
                "DIFFERENT one that looks deliberate",
                file=sys.stderr,
            )
            failures += 1
        else:
            note(
                f"{theme_dir.name}: {len(used)} glyph name(s) drawn, "
                f"all {len(used)} mapped"
            )

    if checked == 0 and failures == 0:
        note("no theme ships an icons.json -- nothing to check")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
