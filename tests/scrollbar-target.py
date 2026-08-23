#!/usr/bin/env python3
"""Ask components/ScrollBar.qml which pixels it takes, at every placement it has.

WHY THIS EXISTS. The bar is four pixels wide and its press target is widened
past that, because four pixels is the right width to look at and an unfair
thing to ask anyone to hit. The widening is the whole difficulty: it is not
free, it is taken out of whatever is beside the bar, and twice now it has been
taken out of something that wanted the press. The settings rail scrolled
instead of opening a page when the right-hand edge of an entry was pressed;
the launcher grid scrolled instead of launching an application down eleven
pixels of every third-column row. Both were fixed at the call site, by hand,
after somebody noticed.

Nothing could have noticed for them. The fault is invisible in a diff -- one
integer -- invisible in a screenshot, and invisible to tests/shell-load.sh,
which asks whether the tree comes up and not what it does when pressed. This
bench is the thing that can see it: it presses every x across a call site's
geometry and reports WHICH ITEM heard the press.

THE SIDES ARE NOT ALIKE, WHICH IS THE POINT OF THE TWO MARGINS. Inward is over
the view the bar describes, where every pixel taken is a pixel a row stops
hearing. Outward is over whatever the call site put the bar into. So the
assertions below come in pairs: the bar's band, and the content's -- because
"the bar answers here" is only half of it and "the row still answers there" is
the half that was wrong both times.

QT'S RULE IS NOT THE OBVIOUS ONE, and the outward margin's whole justification
rests on it, so it is asserted rather than believed: a press target is bounded
by a CLIPPING ancestor and by nothing else. An unclipped parent does not stop
a child's MouseArea reaching past it. `view-unclipped` below is the same grid
as `launcher-grid` with `clip` off, and its bar reaches eleven pixels further.

THREE SHAPES AND THEY STACK DIFFERENTLY -- see the header of
scrollbar-target.qml. The one worth naming here is `list`: ScrollList declares
its bar in the base document and the call site's Column is appended to the
same `flickableData` afterwards, so THE ROWS SIT ABOVE THE BAR. A call site
whose rows carry a full-width MouseArea takes every press across the list,
including the bar's, and the bar is drawn but cannot be grabbed at all. That
is asserted here because it is the reason the seven ScrollList call sites
never suffered the fault the rail and the launcher did -- and because it is a
different fault of its own, still standing, which a future edit to either file
could silently turn into the first one.

A FRESH QQuickView PER CASE, AND THAT IS NOT TIDINESS. Setting the geometry on
a scene that is already up and pressing again reports a target that stops at
the parent's OLD bounds even where nothing clips: measured, a bar whose
MouseArea spanned 769..787 inside an unclipped 782-wide parent answered up to
781 when the parent had been resized to 782 from 780, and up to 786 when the
same geometry was declared from the start. Whatever that state is, it is Qt's.
A bench that reused one view would report the outward margin as dead
everywhere, which is exactly the claim it exists to check.

WHAT IS REAL AND WHAT IS NOT. components/ScrollBar.qml and
components/ScrollList.qml are imported by relative path and are the shipping
files, byte for byte; so is themes/genesis/components/ScrollBar.qml, which is
the half that draws and which the facade loads by URL exactly as the shell
does. The geometry of every case is the call site's own, taken off the files
named beside it. The rows are stand-in MouseAreas that record their own name,
because the question is which item receives the press and a real row answers it
by opening a page. Theme is stood in for by tests/theme-stub.qml for the reason
written at length in tests/wheel-and-click.py, and Themes -- the singleton that
turns a theme's name into a path -- by the six lines further down that point it
at themes/genesis.

WHAT IT DOES NOT ASK. Whether the bar is in the right PLACE -- that is a
judgement about what is beside it, and no bench holds it. Whether it looks
right. Whether the drag that follows the press tracks the pointer. And nothing
at all about the five ScrollList call sites whose bar cannot be reached: this
records the fact and does not call it acceptable.

NEEDS python-pyqt6 AND qt6-declarative, both, for the reason wheel-and-click.py
gives. QT_QPA_PLATFORM is forced to offscreen by this file, so a run started
from inside Johan's session opens nothing and takes nothing.

Run it from anywhere:  tests/scrollbar-target.py
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

# Before QGuiApplication exists and before PyQt6.QtGui is imported -- the
# platform plugin is chosen at construction and cannot be changed after.
os.environ["QT_QPA_PLATFORM"] = "offscreen"

# The software scene graph, so the one rendered assertion at the bottom needs
# no GL context and answers the same on this desk and on a runner. Measured:
# every press row above reports identically under both backends.
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt6.QtCore import QCoreApplication, QPointF, QUrl, Qt
from PyQt6.QtGui import QGuiApplication, QInputDevice, QMouseEvent, QPointingDevice
from PyQt6.QtQml import QQmlAbstractUrlInterceptor, QQmlComponent
from PyQt6.QtQuick import QQuickView

TESTS = Path(__file__).resolve().parent
SCENE = TESTS / "scrollbar-target.qml"
THEME = TESTS / "theme-stub.qml"

SHELL = TESTS.parent / "quickshell" / ".config" / "quickshell"
COMPONENTS = SHELL / "components"
SETTINGS = SHELL / "modules" / "settings"
# The theme whose drawing is measured. Hard-coded rather than read out of
# Config, because the real Themes falls back to exactly this name when the
# configured theme has no readable manifest, and it is the one this repository
# ships: a bench that followed a setting would measure a different bar on a
# machine where somebody had changed one.
DRAWN_BY = SHELL / "themes" / "genesis"


# ---------------------------------------------------------------------------
# The `qs` module
# ---------------------------------------------------------------------------
# components/ScrollBar.qml opens `import QtQuick` / `import qs.modules`, and
# `qs` is a module Quickshell synthesizes at runtime from the config root. A
# plain QQmlEngine has never heard of it, so without this the shipping file the
# bench is here to measure does not load at all -- "module qs is not
# installed", then "Type ScrollBar unavailable", then a scene that is
# Status.Error and a bench that asserts nothing. That is what it did between
# the day the tree moved to module imports and the day this was written.
#
# A SANDBOX MODULE AND NOT THE REAL TREE, which is the same decision
# theme-stub.qml already made and for the same reason: the root module's
# Theme.qml opens `import Quickshell`, reads the generated palette through a
# FileView, and pulls in a compositor behind it. What the two halves of
# ScrollBar actually ask `qs` for is five design tokens off Theme -- primary,
# outline, outlineVariant and the two durations -- so the module built here
# holds exactly one type, and it is the stub whose numbers this bench already
# trusted. The day either half reaches for a second one -- Config, Icons -- it
# has to be added here as well: an unknown name inside an import that DOES
# resolve is a broken binding at runtime and not a refused load, which is
# quieter than what this comment is here to prevent.
#
# AS A SINGLETON, because that is what the shell registers and therefore what
# the shipping file expects: `Theme.primary` inside a file that imports qs is a
# singleton lookup and not the context property below. The context property
# stays for scrollbar-target.qml itself, which is the bench's own scene and
# imports nothing.
#
# Built into a temporary directory rather than committed, for the reason
# tests/qml-lint.sh sets out at length next to the same trick: Quickshell
# disables its own qmldir synthesis for any directory that already has one on
# disk, so a qmldir in the repository would change what the shell does in order
# to tell a test something.
#
# ONE DIRECTORY FOR THE WHOLE RUN, held open by a name at module scope. Each
# case builds a fresh engine and every one of them is handed this same path;
# a per-case directory would be written and swept fifteen times over to say
# the same thing.
_imports = tempfile.TemporaryDirectory(prefix="scrollbar-target-qs-")
IMPORTS = Path(_imports.name)

_qs = IMPORTS / "qs"
_qs.mkdir()
(_qs / "Theme.qml").write_text(
    "pragma Singleton\n" + THEME.read_text(encoding="utf-8"), encoding="utf-8"
)
(_qs / "qmldir").write_text(
    "module qs\nsingleton Theme 1.0 Theme.qml\n", encoding="utf-8"
)

# ---------------------------------------------------------------------------
# `qs.modules` and `qs.components`, which is how a bench reaches a component
# the THEME draws
# ---------------------------------------------------------------------------
# components/ScrollBar.qml is a facade: it keeps the press target and the
# position arithmetic, and loads the pill and the thumb out of
# themes/<theme>/components/ScrollBar.qml. That costs two more modules, one per
# direction across the seam, and without either of them the file this bench
# measures does not load:
#
#   qs.modules      the facade calls Themes.surface() to find its theme's file.
#   qs.components   the theme file declares `required property ScrollBar row`,
#                   which is a type it can only name by importing the host's
#                   components.
#
# BOTH ARE BUILT HERE AND BOTH ARE BUILT IN tests/wheel-and-click.py, which
# loads ScrollList and therefore holds one of these bars. The two sandboxes are
# not shared -- that one hands Theme in as a context property and this one
# registers it as a singleton, for reasons each file gives -- but the four
# modules are the same four. Add one here and it belongs there too, and the
# other way round; a bench whose theme file does not load still measures every
# press correctly and reports a bar with nothing drawn in it.
#
# THE COMPONENTS ARE THE SHIPPING FILES AND NOT COPIES OF THEM. The qmldir
# below names each one by a relative path back into quickshell/, so `import
# qs.components` and the scene's own relative import resolve to the same
# document -- which is what makes the theme's `required property ScrollBar row`
# accept the very object the scene built. Measured, in a scratch tree of four
# files, because a qmldir entry reaching back out of its own directory is not
# an obvious thing to rely on: two spellings of one file, an object made
# through one of them, a `required property` declared through the other, and
# the assignment lands. COPYING the components into the sandbox would be the
# obvious alternative and is the thing to avoid -- a QML type is its document,
# so a copy is a second type and the initial property would be refused by a
# name that reads as though it matched.
#
# A SINGLETON, and a stub, for the same reason Theme is. The real
# modules/Themes.qml opens `import Quickshell`, reads a manifest through a
# FileView and builds its URL with Quickshell.shellPath -- none of which exists
# under a plain QQuickView. What it is asked for here is one function of one
# string, so that is what this is. IT POINTS AT THE REAL THEME DIRECTORY: the
# pixels the last assertion in this file reads are the ones genesis paints, and
# a stub theme written by the bench would have made that assertion a check that
# the bench can draw a rectangle.
_components = _qs / "components"
_components.mkdir()
(_components / "qmldir").write_text(
    "module qs.components\n" + "".join(
        # Fuzzy.qml is `pragma Singleton` and a qmldir that said otherwise
        # would refuse it at the moment something used it. Read rather than
        # listed, so the next singleton under components/ needs no edit here.
        ("singleton " if "pragma Singleton" in qml.read_text(encoding="utf-8") else "")
        + f"{qml.stem} 1.0 {os.path.relpath(qml, _components)}\n"
        for qml in sorted(COMPONENTS.glob("*.qml"))
    ),
    encoding="utf-8",
)

_modules = _qs / "modules"
_modules.mkdir()
(_modules / "Themes.qml").write_text(
    "pragma Singleton\n"
    "import QtQuick\n"
    "QtObject {\n"
    "    function surface(file: string): string {\n"
    f'        return "file://" + encodeURI("{DRAWN_BY}/" + file);\n'
    "    }\n"
    "}\n",
    encoding="utf-8",
)
(_modules / "qmldir").write_text(
    "module qs.modules\nsingleton Themes 1.0 Themes.qml\n", encoding="utf-8"
)

# AND `qs.modules.settings`, WHICH NOTHING IN THIS FILE ASKS FOR. It is here
# because the paragraph above says the modules are the same modules in both
# benches and that adding one to either belongs in the other -- the settings
# window's own facades became a fourth module in tests/wheel-and-click.py when
# SettingsNavItem was split, and the two sandboxes drifting apart is exactly
# what that sentence exists to stop. Nothing here imports it, so it costs one
# qmldir written into a temporary directory.
#
# THE SINGLETONS ARE LEFT OUT, unlike qs.components above, and that is measured
# rather than tidy: a composite singleton declared in a qmldir is created when a
# document that imports the module is created, and two of the files in that
# directory are singletons that open `import Quickshell`. Declaring them turns
# every use of the module into "Type SessionInfo unavailable" followed by
# `module "Quickshell" plugin "quickshell-coreplugin" not found`.
_settings = _modules / "settings"
_settings.mkdir()
(_settings / "qmldir").write_text(
    "module qs.modules.settings\n" + "".join(
        f"{qml.stem} 1.0 {os.path.relpath(qml, _settings)}\n"
        for qml in sorted(SETTINGS.glob("*.qml"))
        if "pragma Singleton" not in qml.read_text(encoding="utf-8")
    ),
    encoding="utf-8",
)

failed = 0


def note(message: str) -> None:
    print(f"scrollbar-target: {message}")


def fail(message: str) -> None:
    global failed
    print(f"scrollbar-target: FAIL {message}", file=sys.stderr)
    failed = 1


# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------
# Borrowed by the engine rather than owned by it, so a name has to stay on
# them: a Python object with no reference left is collected under a running
# engine, and that segfaults rather than raising.
_keep: list = []


class RootScheme(QQmlAbstractUrlInterceptor):
    """Sends Quickshell's root:/ imports somewhere that resolves to nothing."""

    def __init__(self, target: Path) -> None:
        super().__init__()
        self.target = target

    def intercept(self, url: QUrl, kind: object) -> QUrl:
        if url.scheme() == "root":
            return QUrl.fromLocalFile(str(self.target / url.path().lstrip("/")))
        return url


app = QGuiApplication(sys.argv)

DEVICE = QPointingDevice(
    "scrollbar-target mouse", 4242, QInputDevice.DeviceType.Mouse,
    QPointingDevice.PointerType.Generic, QInputDevice.Capability.Position, 1, 3,
)


def build(case: dict, empty_root: Path) -> QQuickView:
    view = QQuickView()
    engine = view.engine()

    interceptor = RootScheme(empty_root)
    _keep.append(interceptor)
    engine.addUrlInterceptor(interceptor)

    # A fresh engine per case means a fresh set of import paths per case, so
    # this is added here rather than once at the top. The directory it points
    # at is built once, above.
    engine.addImportPath(str(IMPORTS))

    component = QQmlComponent(engine, QUrl.fromLocalFile(str(THEME)))
    theme = component.create()
    _keep.append(theme)
    for error in component.errors():
        fail(f"theme-stub.qml: {error.toString()}")
    if theme is None:
        fail("theme-stub.qml produced no object; nothing below can run")
        sys.exit(1)
    engine.rootContext().setContextProperty("Theme", theme)
    engine.rootContext().setContextProperty("Case", case)

    view.setSource(QUrl.fromLocalFile(str(SCENE)))
    for error in view.errors():
        fail(f"scrollbar-target.qml: {error.toString()}")
    if view.status() != QQuickView.Status.Ready:
        fail(f"the scene did not load: {view.status()}")
        sys.exit(1)

    view.resize(case["sceneWidth"], 400)
    view.show()
    app.processEvents()
    return view


def press(view: QQuickView, x: float, y: float) -> str:
    """One press and release with no event loop between, and who heard it."""
    root = view.rootObject()
    root.reset()
    at = QPointF(x, y)
    QCoreApplication.sendEvent(view, QMouseEvent(
        QMouseEvent.Type.MouseButtonPress, at, at, Qt.MouseButton.LeftButton,
        Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, DEVICE))
    QCoreApplication.sendEvent(view, QMouseEvent(
        QMouseEvent.Type.MouseButtonRelease, at, at, Qt.MouseButton.LeftButton,
        Qt.MouseButton.NoButton, Qt.KeyboardModifier.NoModifier, DEVICE))
    return root.tookIt()


def bands(case: dict) -> dict[str, tuple[int, int] | None]:
    """Sweep a press across the whole width, a pixel at a time.

    The y is fixed low down the track on purpose: the bar answers a press by
    scrolling to it, and a press near the top would land on a contentY of zero
    -- which is how "the bar did nothing" is spelled.
    """
    with tempfile.TemporaryDirectory() as empty:
        view = build(case, Path(empty))
        hits: dict[str, list[int]] = {}
        for x in range(case["sceneWidth"]):
            hits.setdefault(press(view, x + 0.5, 280.0), []).append(x)
        view.hide()
        view.setSource(QUrl())
        view.deleteLater()
        app.processEvents()
    out: dict[str, tuple[int, int] | None] = {}
    for who in ("bar", "content"):
        got = hits.get(who)
        out[who] = (got[0], got[-1]) if got else None
    # A band with a hole in it is not a band, and the assertions below all
    # read as though it were one.
    for who in ("bar", "content"):
        got = hits.get(who)
        if got and got[-1] - got[0] + 1 != len(got):
            fail(f"{case['name']}: {who} answers in pieces, not one run: {got}")
    return out


def check(case: dict, bar, content) -> None:
    got = bands(case)
    for who, want in (("bar", bar), ("content", content)):
        if got[who] != want:
            fail(f"{case['name']}: {who} answers {got[who]}, expected {want}")
    note(f"{case['name']:<26} bar {str(got['bar']):<12} content {got['content']}")


# `tuned` false means the bar is left at the component's own defaults, which
# is what every call site in the tree now does and therefore what is worth
# asserting. The one case that sets them says so in its own comment.
BESIDE = {"shape": "beside", "rowsClickable": True, "viewClips": True,
          "tuned": False, "inward": 0, "outward": 0, "rowZ": 0,
          "rowColour": "transparent"}
VIEW = {"shape": "view", "rowsClickable": True, "viewClips": True,
        "tuned": False, "inward": 0, "outward": 0, "rowZ": 0,
        "rowColour": "transparent"}
LIST = {"shape": "list", "barX": 0, "tuned": False, "inward": 0, "outward": 0,
        "viewClips": True, "rowZ": 0, "rowColour": "transparent"}

# ---------------------------------------------------------------------------
# The bar beside the list, in padding the call site already had
# ---------------------------------------------------------------------------
# Five call sites, and the geometry of each is taken off its own file. Every
# one of them places the bar OUTSIDE the list, as a later sibling, so the bar
# is above whatever it overlaps and the inward margin is the whole risk.

note("--- the bar beside the list ---")

# modules/settings/Settings.qml:304. Rail 210 wide with 10 of padding, bar
# inset 3 from its right edge, entries stopping at the padding. Window 820.
check({**BESIDE, "name": "settings rail", "listLeft": 10, "listRight": 200,
       "barX": 203, "sceneWidth": 820},
      bar=(200, 217), content=(10, 199))

# modules/settings/Settings.qml:575. Page pane ends at 808 and its section
# rows stop 4 short of that; bar 4 outside the pane; the window ends at 820
# and takes the last seven pixels of the outward margin with it.
check({**BESIDE, "name": "settings page pane", "listLeft": 226,
       "listRight": 804, "barX": 812, "sceneWidth": 820},
      bar=(809, 819), content=(226, 803))

# modules/settings/Settings.qml:610. Same placement, but the result rows run
# the FULL pane width -- no 4px inset -- so this is the one where the old
# symmetric seven still reached three pixels back over every row.
check({**BESIDE, "name": "settings search results", "listLeft": 222,
       "listRight": 808, "barX": 812, "sceneWidth": 820},
      bar=(809, 819), content=(222, 807))

# themes/genesis/notifications/NotificationHistory.qml:514. The list gives up
# `scrollBar.width + 8`, so there are eight clear pixels inward, and the
# Popout's own groupPadding is what lies outward.
check({**BESIDE, "name": "notification history", "listLeft": 12,
       "listRight": 588, "barX": 596, "sceneWidth": 612},
      bar=(593, 610), content=(12, 587))

# themes/genesis/cheatsheet/Cheatsheet.qml:475. Centred in thirty pixels of card
# padding: thirteen clear on each side, and nothing in the file clips.
check({**BESIDE, "name": "cheatsheet", "listLeft": 30, "listRight": 830,
       "barX": 843, "sceneWidth": 1000},
      bar=(840, 857), content=(30, 829))

# ---------------------------------------------------------------------------
# The bar inside a ListView or a GridView
# ---------------------------------------------------------------------------

note("--- the bar inside the view ---")

# themes/genesis/launcher/Launcher.qml:508 -- three columns of 260, bar hard against
# the right edge -- and themes/genesis/launcher/ClipboardPicker.qml:165, which is the
# same 780 with the same placement. The outward eleven is discarded whole.
check({**VIEW, "name": "launcher grid", "listLeft": 0, "listRight": 780,
       "sceneWidth": 820},
      bar=(773, 779), content=(0, 772))
check({**VIEW, "name": "clipboard list", "listLeft": 0, "listRight": 780,
       "sceneWidth": 820},
      bar=(773, 779), content=(0, 772))

# THE CONTROL, and without it none of the rows above mean anything. Same grid
# with `clip` off: the bar reaches its full outward eleven, past the view's
# own edge, onto nothing. This is what says the outward margin is only ever
# discarded by a CLIP -- not by the parent's bounds, which do not bound it --
# and therefore that the eleven is affordable at all.
check({**VIEW, "name": "view, unclipped", "listLeft": 0, "listRight": 780,
       "viewClips": False, "sceneWidth": 820},
      bar=(773, 790), content=(0, 772))

# ---------------------------------------------------------------------------
# ScrollList's own bar
# ---------------------------------------------------------------------------
# The margins are the component's defaults here: ScrollList places this bar
# itself and the call site never sees it.

note("--- ScrollList's own bar ---")

# ALL SEVEN, ONE ROW EACH, because the fault was never uniform: five of these
# carry a MouseArea across the full row and two do not, and until ScrollList's
# bar was given a z the five were the ones where the bar could not be grabbed
# at any x. The list's WIDTH is not what any of this turns on -- the bar hangs
# on the right edge wherever that edge is, and the answer is always its last
# seven pixels -- so one width stands for all of them and the per-site column
# that matters is whether the rows take presses.
#
#   Bluetooth paired / available   MouseArea anchors.fill, unconditional
#   Updates, packages in a pack    MouseArea anchors.fill, unconditional
#   Input, xkb layouts             the same, `enabled: entry.addable`
#   Network, wifi                  the same, but only over the collapsed 32px
#   Keybinds                       no input handler in the list at all
#   Updates, installer log         one Text, no handler
#
# The two conditional ones fall back to the row below when their condition is
# off, which is why the inert row is asserted as well and not merely noted.

SITES = (
    ("bluetooth paired", True),
    ("bluetooth available", True),
    ("input layouts", True),
    ("network wifi", True),
    ("updates packages", True),
    ("keybinds", False),
    ("updates log", False),
)

for name, clickable in SITES:
    check({**LIST, "name": name, "rowsClickable": clickable,
           "listLeft": 226, "listRight": 804, "sceneWidth": 820},
          bar=(797, 803),
          content=(226, 796) if clickable else None)

# THE ROWS GIVE UP SEVEN PIXELS AND NOT ONE MORE, which is the other half of
# the question and the half a "the bar is reachable now" check would miss. The
# rows above answer to 796 on a list whose edge is 804: the bar's own four and
# the three of inward margin, and nothing else moved. Nothing clickable in any
# of the seven sits in that strip -- the tightest inset in the tree is eight
# pixels, on the Bluetooth and Network rows, and what sits at eight is a
# status label. The chips those rows carry are around a hundred pixels in.

# A ROW'S OWN z CANNOT CLIMB BACK OVER IT, which is what says `z: 1` is
# enough rather than merely enough for now. Stacking is per parent: the z on a
# row orders that row against its siblings in the Column, and the bar is a
# sibling of the Column itself. Bluetooth's and Network's row MouseAreas
# really do carry `z: -1`, so this is not hypothetical in either direction.
for row_z in (99, 1000):
    check({**LIST, "name": f"row at z={row_z}", "rowsClickable": True,
           "rowZ": row_z, "listLeft": 226, "listRight": 804,
           "sceneWidth": 820},
          bar=(797, 803), content=(226, 796))

# THE PROPERTIES ARE STILL WIRED TO SOMETHING. Every row above leaves the
# margins at the component's defaults, which is the right thing to assert and
# also means none of them would notice if the two properties stopped being
# read at all. This is the same rail with both margins set by hand.

check({**BESIDE, "name": "margins set by hand", "listLeft": 10,
       "listRight": 200, "barX": 203, "sceneWidth": 820, "tuned": True,
       "inward": 1, "outward": 40},
      bar=(202, 246), content=(10, 199))

# ---------------------------------------------------------------------------
# The thumb does not move with the margins
# ---------------------------------------------------------------------------
# The component's own note says the target may be widened SIDEWAYS ONLY,
# because `mouse.y` is measured from the MouseArea's origin and lifting that
# origin above the track would offset every position under it. Widening the
# two sides by DIFFERENT amounts moves the origin sideways, which that
# argument says is harmless -- `mouse.x` is never read. Said out loud here
# because it is the one thing asymmetry could have broken silently, and a
# thumb that lands a few pixels from where it was grabbed is not something a
# load check would ever see.

note("--- the thumb lands in the same place either way ---")

landed = []
for inward, outward in ((3, 11), (7, 7), (0, 30)):
    case = {**BESIDE, "name": "thumb", "listLeft": 10, "listRight": 200,
            "barX": 203, "sceneWidth": 820, "tuned": True, "inward": inward,
            "outward": outward}
    with tempfile.TemporaryDirectory() as empty:
        view = build(case, Path(empty))
        press(view, 204.5, 190.0)
        landed.append((inward, outward, round(view.rootObject().drivenY(), 3)))
        view.hide()
        view.setSource(QUrl())
        view.deleteLater()
        app.processEvents()

where = {y for _, _, y in landed}
if len(where) != 1:
    fail(f"the same press scrolled to different places: {landed}")
elif where == {0.0}:
    fail("the press scrolled nowhere at all, so this row proves nothing")
else:
    note(f"a press at y=190 lands at contentY {landed[0][2]} for all of "
         f"{[(i, o) for i, o, _ in landed]}")

# ---------------------------------------------------------------------------
# And it is drawn where a row paints over it
# ---------------------------------------------------------------------------
# THE ONLY ROW HERE THAT IS SEEN RATHER THAN ASKED. Being unreachable was half
# of what being underneath cost ScrollList's bar; the other half is that it
# was PAINTED underneath too, and a press check cannot see that at all. Every
# row in the tree is transparent at rest and paints on hover, on selection, on
# pairing or while a password box is open -- so what this looked like was an
# indicator that disappeared under whatever the pointer was on.
#
# The window is grabbed and the pixels are read. If the grab comes back empty
# -- no renderer, somewhere this has not been tried -- that is said out loud
# and not counted as a pass or a failure, because a rendered assertion that
# quietly turns into nothing is worse than none.
#
# AND SINCE THE SPLIT IT ASKS A SECOND QUESTION IN THE SAME BREATH, which is
# the reason it did not have to be weakened into a geometry check when the
# drawing moved into themes/. Those four pixels are now painted by
# themes/genesis/components/ScrollBar.qml, and the row underneath is opaque and
# runs the full width of the list -- so "not the row's colour" is exactly "the
# theme half loaded, was handed a thumb, and painted over the row". Measured by
# moving that file out of the way: the press rows above go to `bar None`, this
# one reads `the row paints over the bar: 596..599 are ['#804060'] * 4`, and the
# run is red in thirty places rather than quietly green with an invisible bar.

note("--- and the row does not paint over it ---")

ROW = "#804060"
case = {**LIST, "name": "opaque row", "rowsClickable": True,
        "rowColour": ROW, "listLeft": 0, "listRight": 600, "sceneWidth": 700}

with tempfile.TemporaryDirectory() as empty:
    view = build(case, Path(empty))
    app.processEvents()
    shot = view.grabWindow()
    if shot.isNull() or shot.width() < case["sceneWidth"]:
        note("the window did not render here, so nothing was looked at")
    else:
        # 596..599 is the bar; 590 is the row beside it and is the control --
        # without it, a grab that came back blank would read as a pass.
        beside = shot.pixelColor(590, 150).name()
        over = [shot.pixelColor(x, 150).name() for x in range(596, 600)]
        if beside != ROW:
            fail(f"the row itself did not paint: x=590 is {beside}, not {ROW}")
        elif any(c == ROW for c in over):
            fail(f"the row paints over the bar: 596..599 are {over}")
        else:
            note(f"the row is {beside} beside the bar and the bar's four "
                 f"pixels are {over[0]}")
    view.hide()
    view.setSource(QUrl())
    view.deleteLater()
    app.processEvents()

if failed == 0:
    note("every placement takes the pixels it is meant to and no others")
sys.exit(failed)
