#!/usr/bin/env python3
"""The three seam rules nothing checked.

`themes/genesis/components/README.md` closes with a section headed "what the
directory does not do", and it says this plainly:

    Nothing checks rules 3, 4 or 7. All three load, pass every test, and are
    wrong.

That was true, and each of the three fails in a way that is worse than a crash
because the desktop keeps working:

RULE 3 -- a theme file must not declare `label`, `title` or `glyph`.
    modules/settings/SettingsSearch.qml duck-types the live object tree to
    build its index: a row is anything with a non-empty string `label`, a
    section anything with a non-empty `title` and no `label`. Its recursion is
    unconditional, so it walks THROUGH the facade's Loader and into the theme's
    own item. A theme that mirrors `label` onto itself gives every row two
    entries, and the settings window looks perfect while its search is wrong.
    Measured when the rule was written: 2 hits for "Wi-Fi", 2 exact and 6
    results for "Bluetooth".

RULE 4 -- a theme reads `row`, it never writes to it.
    A theme that assigns to `row.checked` has taken a decision the call site
    owns, and the two disagree from then on. Where a theme must change
    something the facade gives it a function.

RULE 7 -- the components whose contract is an ABSENCE must keep it.
    `InfoRow` and `Reading` are readings. A facade cannot require an absence --
    there is no signal to leave unconnected and no property to leave unread --
    so it is kept in the theme or it is not kept at all. It also happens to be
    what the control does: in CommunityToolkit's SettingsCard.cs the pointer
    handlers are subscribed only when IsClickEnabled is true, so a card with
    nothing to click never lights up under the pointer either.
    `MonitorTile` is the same shape for a different reason: its drag belongs to
    the host, and an input handler in the theme half would fight it.
    `SettingsNavItem` is the sharpest case, because it once had one: the host
    keeps a MouseArea there solely for `preventStealing`, which was the fix for
    a real bug ("Updates does not open"), and that is why the facade publishes
    `hovered` at all.

COMMENTS COME OFF BEFORE ANY OF IT, and that is not a detail. Every one of
these files EXPLAINS the rule it is keeping, by name, in prose -- InfoRow's
header says "AND THEREFORE IT HAS NO MouseArea AT ALL". A sweep that read
comments would report the file that documents the rule as the file that breaks
it. The first version of this audit did exactly that and called four clean
files dirty.

WHAT THIS DOES NOT CHECK. Rule 7 is a behaviour promise and only the absences
are mechanically checkable. That the whole row is the target for `ToggleRow`,
or that a click on `NotificationCard` means dismiss() rather than expire(), is
not expressible here -- the second is partly covered by grepping for expire(),
which this does, and the first is not covered at all.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Components documented as taking no input at all. The list is short on purpose:
# every entry needs a reason written down beside it, and a list nobody can
# justify line by line is a list that grows until it means nothing.
NO_INPUT = {
    "InfoRow.qml": "a reading; rule 7, and SettingsCard does the same",
    "Reading.qml": "a reading; the same promise one directory up",
    "MonitorTile.qml": "the drag belongs to the host",
    "SettingsNavItem.qml": "the host keeps the MouseArea for preventStealing",
}

HANDLERS = ("MouseArea", "TapHandler", "HoverHandler", "DragHandler",
            "PointHandler", "cursorShape")

LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
DECLARES = re.compile(r"property\s+(?:string|alias|var)\s+(label|title|glyph)\b")
WRITES_ROW = re.compile(r"\brow\.[A-Za-z_][A-Za-z0-9_]*\s*=(?!=)")
EXPIRES = re.compile(r"\.expire\s*\(")


def code(path: Path) -> str:
    text = path.read_text()
    text = BLOCK_COMMENT.sub("", text)
    return LINE_COMMENT.sub("", text)


def note(msg: str) -> None:
    print(f"theme-seam: {msg}")


def fail(msg: str) -> None:
    print(f"theme-seam: FAIL {msg}", file=sys.stderr)


def main() -> int:
    # Through git ls-files, for the reason tests/qml-lint.sh records: a worktree
    # left under the checkout is a whole second copy of the repository.
    out = subprocess.run(["git", "ls-files", "--", "*manifest.json"],
                         cwd=REPO, capture_output=True, text=True, check=True)
    themes = [REPO / Path(line).parent for line in out.stdout.splitlines() if line]

    if not themes:
        fail("no theme found -- looked for a manifest.json in git ls-files")
        return 1

    failures = 0
    swept = 0
    checked_absences = 0

    for theme in themes:
        for qml in sorted(theme.rglob("*.qml")):
            swept += 1
            body = code(qml)
            rel = qml.relative_to(REPO)

            # Rule 3 -- only for the facade-loaded components. A surface is not
            # in the settings window's tree, so a `title` there reaches nothing.
            if qml.parent.name == "components":
                for match in DECLARES.finditer(body):
                    fail(f"{rel} declares `{match.group(1)}` -- rule 3")
                    print("theme-seam:   the settings search walks through the "
                          "facade's Loader into this item and duck-types on "
                          "that name", file=sys.stderr)
                    failures += 1

            # Rule 4 -- anywhere in a theme.
            for match in WRITES_ROW.finditer(body):
                fail(f"{rel} writes `{match.group(0).strip()}` -- rule 4")
                print("theme-seam:   a theme reads `row`; where it must change "
                      "something the facade gives it a function",
                      file=sys.stderr)
                failures += 1

            # Rule 7 -- the absences, and the one behaviour that greps.
            if qml.name in NO_INPUT:
                checked_absences += 1
                found = [h for h in HANDLERS if re.search(rf"\b{h}\b", body)]
                if found:
                    fail(f"{rel} has {', '.join(found)} -- rule 7")
                    print(f"theme-seam:   {NO_INPUT[qml.name]}",
                          file=sys.stderr)
                    failures += 1

            if EXPIRES.search(body):
                fail(f"{rel} calls expire() -- rule 7")
                print("theme-seam:   expiring tells the application the user "
                      "never closed it, so it sends again. dismiss() is the "
                      "one that means closed", file=sys.stderr)
                failures += 1

    # The floor every other check here has: an assertion over an empty set is
    # not an assertion. A theme whose files moved out from under the sweep would
    # pass in exactly the way a correct one does.
    if swept < 30 or checked_absences == 0:
        fail(f"swept {swept} file(s) and {checked_absences} documented "
             "absence(s) -- far below the tree this is written against")
        return 1

    if failures == 0:
        note(f"{len(themes)} theme(s), {swept} file(s): rules 3, 4 and 7's "
             f"absences all kept ({checked_absences} absence(s) checked)")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
