#!/usr/bin/env python3
"""Ask the settings rail both of the questions it has to answer at once.

The rail is the strip of fourteen subjects down the left of the settings
window. It scrolls, because at the window's pinned 820x580 its entries are
530 px tall in a 452 px viewport, and Updates and About are the two below the
fold. Three pull requests in a row went at it -- #144, #155 and #158 -- and the
first two shipped something wrong, for the same reason both times: each one
measured half of it.

THE TWO HALVES, AND WHY EITHER ALONE IS A TRAP.

  A WHEEL NOTCH STILL SCROLLS THE RAIL. #155 stopped the drag stealing the
  next click by setting `interactive: false` on the list, measured that the
  click now landed, and shipped a settings window in which nothing scrolled at
  all -- because the Flickable that switch turns off was the only thing that
  had ever been doing the scrolling. #157 reverted it the same day.

  A CLICK AFTER A GESTURE STILL LANDS ON THE ENTRY UNDER IT. This is the
  original complaint -- "Updates does not open on the first click" -- and a
  change that removes scrolling passes it trivially, because a list that
  cannot move can never have moved under your pointer.

So this bench asks both, on every path, and a change that answers one by
breaking the other fails here rather than on Johan's screen.

THE DEVICE IS THE THIRD THING, AND IT IS WHAT MADE THE FIRST BENCH LIE. A
`WheelHandler` is constructed with `acceptedDevices: Mouse` and, on top of
that, drops any wheel event Qt marks as synthesized. A handler that declines an
event does nothing, silently. Offscreen, Qt hands out a device typed Mouse and
the handler accepts, so a bench that sends whatever Qt gives it reports that
the handler works. On this machine's Wayland seat qtbase registers no Mouse
device at all -- with `zwp_pointer_gestures_v1` advertised the only mouse-like
device on the seat is the touchpad one, so every wheel event, from a wired
mouse included, arrives typed TouchPad -- and the handler declined all of them
for months while the Flickable underneath quietly did the scrolling and quietly
went on eating the click.

THEREFORE EVERY WHEEL SHAPE IS SYNTHESIZED BY HAND, with the device and the
source set deliberately, and the bench asserts WHICH PATH TOOK THE EVENT and
not merely that something moved:

  Mouse, not synthesized      the handler takes it
  TouchPad, not synthesized   the handler takes it -- only because
                              acceptedDevices names AllDevices; the default
                              declines this one, which is the bug
  Mouse, synthesized          the handler takes it -- naming TouchPad is what
                              lifts the synthesized-source check as well
  Unknown, not synthesized    THE HANDLER DECLINES IT. `Unknown` is the zero
                              flag and `AllDevices` cannot cover it. This is
                              not a gap being papered over: it is the one
                              device shape that still goes through the
                              Flickable, and it is here so that the bench
                              contains a live example of a decline. If it ever
                              starts behaving like the three above, either the
                              handler changed or the bench stopped sending what
                              it thinks it is sending.

"WHICH PATH TOOK IT" IS READ OFF `moving`, AND THAT IS THE SHARP EDGE OF THIS
WHOLE FILE. ScrollList answers the wheel by writing contentY itself, so the
move is instantaneous and the Flickable never enters its moving state. A
Flickable answering the wheel starts a flick animation instead: contentY has
not changed yet when the call returns, and `moving` is true. So one wheel notch
with no event loop in between tells the two apart with no timing in it at all
-- contentY is either already at the bottom or still at the top, never
somewhere in between.

That also removes the only source of flakiness this bench could have had. Every
click below is sent at that same instant, against a contentY that is one of two
exact values, so "the entry under the pointer" is a fixed answer rather than a
race with an animation.

A FRESH QQuickView PER MEASUREMENT, AND THAT IS NOT TIDINESS. A QQuickFlickable
answers ONE wheel event and then stops answering: put the list back to the top
by writing contentY and send the same notch again, and nothing at all happens
-- measured here, four times in a row, contentY 0 and moving false where the
first identical notch had moved it 72 px. Whatever that state is, it is Qt's
and it is not reset by anything reachable from QML. A bench that reused one
view would therefore report that the Flickable path does not scroll, which is
precisely the false alarm -- "nothing scrolls" -- that this file exists to be
able to tell the truth about. Eight measurements, eight views; building one
costs about 10 ms and the whole file runs in under a second.

THE CALIBRATION, WHICH IS THE PART THAT MAKES THE REST MEAN ANYTHING. Beside
the rail the scene puts a bare Flickable holding bare MouseAreas -- no
ScrollList, no SettingsNavItem, nothing from this repository. A wheel notch
over it scrolls it and the click that follows is LOST, and the bench asserts
that. A bench that cannot see a click go missing cannot report that one did
not, and the version of this that lived only in the description of #158 had no
such control: every row of its table said "lands", including the rows that were
wrong.

WHAT IS REAL HERE AND WHAT IS NOT. The two components are imported out of
quickshell/ by relative path and are the shipping files, byte for byte; the
geometry is the settings window's own. Two things are stood in for:

  Theme, because quickshell/.config/quickshell/Theme.qml opens with
  `import Quickshell` and reads the wallpaper's palette through a FileView,
  none of which exists under a plain QQuickView. tests/theme-stub.qml carries
  the real values for every token the three components read.

  `import "root:/"`, which is Quickshell's own resolver and means "the config
  root". A plain QML engine has never heard of the scheme, and the obvious
  repair -- a QQmlAbstractUrlInterceptor rewriting root:/ to a file: URL --
  does not work: Qt keeps the import's base URL remote and fails the directory
  import outright with "Cannot update qmldir content for 'root:/'" the moment
  a qmldir is found there. Quickshell itself gets around that with a whole
  QNetworkAccessManager, which is more machinery than this bench is worth. So
  the interceptor points root:/ at an EMPTY directory -- the import then
  resolves to nothing and contributes no types -- and Theme is handed in as a
  root context property instead, which is looked up exactly when a name is not
  a type. The components are not edited and do not know the difference.

WHAT IS NOT ASKED HERE. The scrollbar, which #159 measured separately and
which the rail places from outside this component; the hand-back to the page
underneath when a capped list cannot move; anything needing a real compositor.
This is the settings rail's two questions and nothing else.

PROVEN TO DISCRIMINATE, not assumed to. Every defence this measures was
deleted on purpose in a scratch worktree, the bench was run, and the product
files were put back with `git checkout`. What it said, each time:

  `acceptedDevices: PointerDevice.AllDevices` deleted from ScrollList.qml --
  the state of the tree before #158 -- turns the touchpad and synthesized rows
  from "the handler took it" into "the Flickable has it": two failures, each
  naming the device and reporting contentY -0.0 with moving true where 78 was
  due. The plain mouse row still passes, which is the point: it is the only
  device the default accepts, and it is the reason a bench that sends whatever
  Qt hands it reports success.

  `preventStealing: true` deleted from SettingsNavItem.qml -- also the state
  before #158 -- lets the drag through to the Flickable: one failure, "the drag
  reached the Flickable -- contentY went 78.0 -> 41.0". That assertion is the
  sharp one for this half. The click sent after that drag still landed, because
  a slow drag ends with no velocity and leaves nothing flicking; reproducing
  the flick that eats the click would mean timing the release, and a bench that
  has to be fast enough is a bench that fails on a loaded runner.

  `interactive: false` added to ScrollList -- #155 alone -- leaves the declined
  device with nothing underneath it: two failures, the second reading "THE RAIL
  DID NOT SCROLL AT ALL on a device the handler declines".

  Both together, which is exactly what #155 shipped and #157 had to revert:
  four failures. Touchpad and synthesized lose the handler, the device that
  never had a handler loses the Flickable as well, and the row that asks
  whether anything is left underneath says THE RAIL DID NOT SCROLL AT ALL --
  which is the settings window Johan reported, named in one run of under a
  second. Only the plain-mouse row still passes, and that is the whole shape of
  the trap: on this machine a plain mouse is not what arrives.

NEEDS python-pyqt6 AND qt6-declarative, which are two packages and not one:
python-pyqt6 declares qt6-base and stops there, and its QtQuick module links
libQt6Quick and libQt6Qml, which only qt6-declarative ships. QT_QPA_PLATFORM is
forced to offscreen by this file, so there is no display and nothing to see --
including when it is run from inside a session, which is the point.

Run it from anywhere:  tests/wheel-and-click.py
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

# BEFORE QGuiApplication IS BUILT, and before PyQt6.QtGui is even imported:
# the platform plugin is chosen at application construction and there is no
# supported way to change it afterwards. Forced rather than defaulted, because
# a run started from inside Johan's own session would otherwise open a real
# window on his screen and take his pointer for the duration.
os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PyQt6.QtCore import QCoreApplication, QElapsedTimer, QEventLoop, QPoint, QPointF, QUrl, Qt
from PyQt6.QtGui import QGuiApplication, QInputDevice, QMouseEvent, QPointingDevice, QWheelEvent
from PyQt6.QtQml import QQmlAbstractUrlInterceptor, QQmlComponent
from PyQt6.QtQuick import QQuickView

TESTS = Path(__file__).resolve().parent
SCENE = TESTS / "wheel-and-click.qml"
THEME_STUB = TESTS / "theme-stub.qml"

# One notch. Qt's wheel unit is an eighth of a degree and every mouse on this
# desk reports 15 degrees a notch, which is the 120 every toolkit special-cases.
NOTCH = 120

failed = 0


def note(message: str) -> None:
    print(f"wheel-and-click: {message}")


def fail(message: str) -> None:
    global failed
    print(f"wheel-and-click: FAIL {message}", file=sys.stderr)
    failed = 1


def check(condition: bool, message: str) -> bool:
    if not condition:
        fail(message)
    return condition


# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------
# See the header for why root:/ goes to an empty directory and Theme comes in
# as a context property.


# Kept alive here on purpose. Both are BORROWED by the engine rather than
# owned by it, and a Python object with no remaining reference is collected
# under a running engine, which segfaults rather than raising. Each is replaced
# only after the view that was using it has been torn down.
_interceptor = None
_theme = None


class RootScheme(QQmlAbstractUrlInterceptor):
    """Sends Quickshell's root:/ imports somewhere that resolves to nothing."""

    def __init__(self, target: Path) -> None:
        super().__init__()
        self.target = target

    def intercept(self, url: QUrl, kind: object) -> QUrl:
        if url.scheme() == "root":
            return QUrl.fromLocalFile(str(self.target / url.path().lstrip("/")))
        return url


def build_view(app: QGuiApplication, empty_root: Path) -> QQuickView:
    view = QQuickView()
    engine = view.engine()

    global _interceptor, _theme
    _interceptor = RootScheme(empty_root)
    engine.addUrlInterceptor(_interceptor)

    theme = QQmlComponent(engine, QUrl.fromLocalFile(str(THEME_STUB)))
    _theme = theme.create()
    for error in theme.errors():
        fail(f"theme-stub.qml: {error.toString()}")
    if _theme is None:
        fail("theme-stub.qml produced no object; nothing below can run")
        sys.exit(1)
    engine.rootContext().setContextProperty("Theme", _theme)

    view.setSource(QUrl.fromLocalFile(str(SCENE)))
    for error in view.errors():
        fail(f"wheel-and-click.qml: {error.toString()}")
    if view.status() != QQuickView.Status.Ready:
        fail(f"the scene did not load: {view.status()}")
        sys.exit(1)

    view.resize(820, 580)
    view.show()
    app.processEvents()
    return view


# ---------------------------------------------------------------------------
# Sending events
# ---------------------------------------------------------------------------
# Devices are built once and kept: QPointingDevice is borrowed by every event
# that names it, and Qt keeps looking at it long after send returns.

DEVICES: dict[str, QPointingDevice] = {}


def devices() -> None:
    kinds = {
        "mouse": QInputDevice.DeviceType.Mouse,
        "touchpad": QInputDevice.DeviceType.TouchPad,
        # PyQt does not name the zero flag, so it is spelled by value. This is
        # QInputDevice::DeviceType::Unknown, which is what AllDevices cannot
        # cover -- see the header.
        "unknown": QInputDevice.DeviceType(0),
    }
    for name, kind in kinds.items():
        DEVICES[name] = QPointingDevice(
            f"wheel-and-click {name}",
            4242,
            kind,
            QPointingDevice.PointerType.Generic,
            QInputDevice.Capability.Position | QInputDevice.Capability.Scroll,
            1,
            3,
        )


def wheel(view: QQuickView, x: float, y: float, notches: int, device: str,
          synthesized: bool = False) -> None:
    """One wheel event, with the device and the source said out loud.

    A positive `notches` is a scroll UP, which is how the hardware reports it
    and which ScrollList subtracts.
    """
    at = QPointF(x, y)
    source = (Qt.MouseEventSource.MouseEventSynthesizedBySystem if synthesized
              else Qt.MouseEventSource.MouseEventNotSynthesized)
    event = QWheelEvent(
        at, at,
        # No pixelDelta. This is the shape qtbase's Wayland plugin builds for
        # `axis_source == wheel`: angleDelta only, NoScrollPhase, and a null
        # pixelDelta -- which is why ScrollList has to read angleDelta first
        # and fall back rather than the other way round.
        QPoint(0, 0), QPoint(0, NOTCH * notches),
        Qt.MouseButton.NoButton, Qt.KeyboardModifier.NoModifier,
        Qt.ScrollPhase.NoScrollPhase, False, source, DEVICES[device],
    )
    QCoreApplication.sendEvent(view, event)


def mouse(view: QQuickView, kind: QMouseEvent.Type, x: float, y: float,
          button: Qt.MouseButton, buttons: Qt.MouseButton) -> None:
    at = QPointF(x, y)
    QCoreApplication.sendEvent(view, QMouseEvent(
        kind, at, at, button, buttons, Qt.KeyboardModifier.NoModifier,
        DEVICES["mouse"],
    ))


def click(view: QQuickView, x: float, y: float) -> None:
    """A press and a release in the same place, with no event loop between.

    No loop, because that is the whole point: the click is being asked whether
    it survives a gesture that has only just happened, and letting the flick
    animation tick first would be measuring a different moment.
    """
    mouse(view, QMouseEvent.Type.MouseButtonPress, x, y,
          Qt.MouseButton.LeftButton, Qt.MouseButton.LeftButton)
    mouse(view, QMouseEvent.Type.MouseButtonRelease, x, y,
          Qt.MouseButton.LeftButton, Qt.MouseButton.NoButton)


def drag(app: QGuiApplication, view: QQuickView, x: float, y: float, by: float,
         steps: int = 8, milliseconds: int = 15) -> None:
    """Press, pull, let go -- the gesture #155 was written for.

    THE EVENT LOOP RUNS BETWEEN THE MOVES, and it has to. QQuickFlickable
    decides that a press has become a drag from the distance travelled AND the
    time it took; eight moves delivered back to back with nothing in between
    carry one timestamp between them, and the Flickable declines to call that a
    drag at all. A bench that sent them that way would find that the list never
    moves under a drag -- which is the answer it is looking for, arrived at by
    never asking the question. Measured: with preventStealing deleted from
    SettingsNavItem and no loop between the moves, this file passed.
    """
    mouse(view, QMouseEvent.Type.MouseButtonPress, x, y,
          Qt.MouseButton.LeftButton, Qt.MouseButton.LeftButton)
    for step in range(1, steps + 1):
        settle(app, milliseconds)
        mouse(view, QMouseEvent.Type.MouseMove, x, y + by * step / steps,
              Qt.MouseButton.NoButton, Qt.MouseButton.LeftButton)
    settle(app, milliseconds)
    mouse(view, QMouseEvent.Type.MouseButtonRelease, x, y + by,
          Qt.MouseButton.LeftButton, Qt.MouseButton.NoButton)


def settle(app: QGuiApplication, milliseconds: int) -> None:
    """Let animations run for a while. Only used between measurements."""
    clock = QElapsedTimer()
    clock.start()
    while clock.elapsed() < milliseconds:
        app.processEvents(QEventLoop.ProcessEventsFlag.AllEvents, 5)


# ---------------------------------------------------------------------------
# The measurements
# ---------------------------------------------------------------------------

# What the scene is expected to be. Asserted rather than assumed, because every
# result below is only about the settings rail for as long as these hold: a
# list that fits its content has no fold, and no fold means no bug and a bench
# that passes forever while measuring nothing.
CONTENT_HEIGHT = 530.0
VIEWPORT_HEIGHT = 452.0
BOTTOM = CONTENT_HEIGHT - VIEWPORT_HEIGHT  # 78, the hidden two entries

# device name, synthesized, and whether ScrollList's handler should take it.
WHEEL_SHAPES = (
    ("mouse", False, True),
    ("touchpad", False, True),
    ("mouse", True, True),
    ("unknown", False, False),
)


def shape_name(device: str, synthesized: bool) -> str:
    return f"{device}{', synthesized' if synthesized else ''}"


def check_geometry(rail: object, plain: object) -> None:
    note("the scene is the settings rail at 820x580")
    check(rail.property("contentHeight") == CONTENT_HEIGHT,
          f"the rail's entries are {rail.property('contentHeight')} tall, "
          f"not the {CONTENT_HEIGHT} the settings window has")
    check(rail.property("height") == VIEWPORT_HEIGHT,
          f"the rail's viewport is {rail.property('height')}, not {VIEWPORT_HEIGHT}")
    check(plain.property("contentHeight") == CONTENT_HEIGHT,
          "the calibration Flickable is not the same size as the rail, so it is "
          "not answering the same question")


def check_wheel(app: QGuiApplication, view: QQuickView, scene: object, rail: object,
                device: str, synthesized: bool, accepted: bool) -> None:
    """Both questions, for one wheel shape, at the instant the notch lands."""
    name = shape_name(device, synthesized)

    wheel(view, scene.property("aimX"), scene.property("aimY"), -1, device, synthesized)

    # WHICH PATH TOOK IT. Written by hand means the move has already happened
    # and the Flickable never woke up; animated means the handler declined and
    # the Flickable has it.
    moving = rail.property("moving")
    landed = rail.property("contentY")
    if accepted:
        as_expected = check(
            not moving and landed == BOTTOM,
            f"{name}: the handler did not take the wheel -- contentY is {landed} "
            f"and moving is {moving}, where a handler that accepted would have "
            f"written {BOTTOM} on the spot and left the Flickable asleep. This is "
            f"what acceptedDevices being anything narrower than AllDevices looks "
            f"like from the outside.")
    else:
        as_expected = check(
            moving and landed == 0.0,
            f"{name}: this device was expected to be DECLINED and left to the "
            f"Flickable, and instead contentY is {landed} with moving {moving}. "
            f"Either the handler now covers the zero device flag or this bench is "
            f"not sending what it says it is.")

    # QUESTION (B), AT THE INSTANT THE NOTCH LANDED. The click ends the
    # measurement: a press is exactly what stops a flick, so anything asked
    # about scrolling after this line is asking about a gesture that was
    # interrupted. Question (a) is answered in check_net, in a view of its own.
    if check(scene.property("aimOnEntry"),
             f"{name}: the aim fell in the 2 px between two entries; nothing is "
             f"under it and no result here would mean anything"):
        expected = scene.property("aimIndex")
        click(view, scene.property("aimX"), scene.property("aimY"))
        app.processEvents()
        heard = scene.property("railHeard")
        count = scene.property("railHeardCount")
        if accepted:
            landing = check(count == 1 and heard == expected,
                            f"{name}: the click after the notch was lost -- entry "
                            f"{expected} was under the pointer and heard nothing "
                            f"(heard {heard}, {count} time(s))")
            if as_expected and landing:
                note(f"  {name}: the handler took it, the rail is at {landed}, "
                     f"entry {expected} heard the click")
        else:
            # Reported and not required. The click surviving here is the second
            # of the two defences -- preventStealing on the entry -- doing its
            # job with the first one out of the picture, which is worth seeing
            # but is not this row's question.
            note(f"  {name}: declined, the Flickable took it, the click "
                 f"{'landed anyway' if count else 'was lost'}")


def check_net(app: QGuiApplication, view: QQuickView, scene: object, rail: object,
              plain: object) -> None:
    """QUESTION (A) on the path that has no handler behind it.

    A device the handler declines has only the Flickable underneath, and #155
    took that away: `interactive: false` stopped the drag stealing the click and
    stopped the settings window scrolling at the same time. This is the row that
    would have caught it, so nothing is clicked in this view -- a press stops a
    flick, and a flick that was interrupted says nothing about how far it would
    have gone.

    The bare Flickable is wheeled here as well, in the same view and at the same
    moment, because it is the proof that a notch of this shape moves an ordinary
    Flickable at all.
    """
    note("what is under the handler still scrolls")

    wheel(view, scene.property("aimX"), scene.property("aimY"), -1, "unknown")
    wheel(view, scene.property("plainAimX"), scene.property("plainAimY"), -1, "mouse")
    settle(app, 800)

    # NOT `== BOTTOM`. A Flickable answering a notch travels its own distance --
    # 72 px here against the handler's 120 clamped to 78 -- and how far Qt
    # flicks is Qt's business, not this repository's. What is being asked is
    # only whether anything is under the handler at all.
    check(rail.property("contentY") > 0.0,
          f"THE RAIL DID NOT SCROLL AT ALL on a device the handler declines. The "
          f"Flickable underneath is the only thing left on that path and contentY "
          f"settled at {rail.property('contentY')}. This is #155 exactly: the "
          f"switch that stops a drag stealing the click also removes the net "
          f"under the wheel, and the whole settings window stops scrolling.")
    check(plain.property("contentY") > 0.0,
          f"the bare Flickable did not scroll either -- contentY settled at "
          f"{plain.property('contentY')}. That is not a fact about this "
          f"repository: it means the bench is not delivering wheel events.")


def check_drag(app: QGuiApplication, view: QQuickView, scene: object,
               rail: object) -> None:
    """The gesture the rail refuses, and the click that has to survive it."""
    note("a drag on an entry is refused, and the click after it lands")

    # To the bottom through the handler, which writes contentY outright: no
    # animation is started, so the drag below is the first thing the Flickable
    # is offered.
    wheel(view, scene.property("aimX"), scene.property("aimY"), -1, "mouse")
    if not check(rail.property("contentY") == BOTTOM,
                 "could not get the rail to the bottom to start the drag from"):
        return

    before = rail.property("contentY")
    drag(app, view, scene.property("aimX"), scene.property("aimY"), 60)
    app.processEvents()

    # preventStealing on the entry holds keepMouseGrab from the press, and
    # QQuickFlickable's filter checks that flag before it consults its own
    # moving state -- so the list never sees the gesture at all. That it does
    # not scroll is not a side effect: it is the trade SettingsNavItem's header
    # says it is making, and it is what keeps the click that comes next.
    check(rail.property("contentY") == before and not rail.property("moving"),
          f"the drag reached the Flickable -- contentY went {before} -> "
          f"{rail.property('contentY')}, moving {rail.property('moving')}. "
          f"preventStealing on the entry is what is supposed to refuse that, and "
          f"a list that moves under a drag is a list that eats the next click.")

    scene.setProperty("railHeard", -1)
    scene.setProperty("railHeardCount", 0)
    if check(scene.property("aimOnEntry"),
             "the aim fell between two entries after the drag"):
        expected = scene.property("aimIndex")
        click(view, scene.property("aimX"), scene.property("aimY"))
        app.processEvents()
        check(scene.property("railHeardCount") == 1
              and scene.property("railHeard") == expected,
              f"the click after the drag was lost -- entry {expected} was under "
              f"the pointer and heard nothing "
              f"(heard {scene.property('railHeard')}, "
              f"{scene.property('railHeardCount')} time(s))")


def check_calibration(app: QGuiApplication, view: QQuickView, scene: object,
                      plain: object) -> None:
    """Prove the bench can see a click go missing.

    Bare Qt, no ScrollList, no SettingsNavItem: a Flickable answering a wheel
    notch starts a flick, and while it flicks it takes the next press for
    itself. If this ever reports that the click landed, nothing above it is
    evidence of anything.
    """
    note("the bare Flickable beside it loses the click, which is the control")

    wheel(view, scene.property("plainAimX"), scene.property("plainAimY"), -1, "mouse")
    check(plain.property("moving"),
          "a wheel notch did not even start the bare Flickable moving, so the "
          "bench is not delivering wheel events the way it thinks it is")

    if check(scene.property("plainAimOnEntry"),
             "the calibration aim fell between two rows"):
        click(view, scene.property("plainAimX"), scene.property("plainAimY"))
        app.processEvents()
        check(scene.property("plainHeardCount") == 0,
              f"THE CONTROL PASSED, WHICH MEANS THIS BENCH IS BROKEN. A bare "
              f"Flickable takes the press away from the row under it while it is "
              f"flicking, and here the row heard the click anyway (heard "
              f"{scene.property('plainHeard')}). Every 'the click landed' above "
              f"this line is worthless until that is explained.")



def main() -> int:
    app = QGuiApplication(sys.argv)
    devices()

    with tempfile.TemporaryDirectory() as empty_root:
        root = Path(empty_root)

        # A view of its own for each measurement; see the header for why one
        # cannot be reused. Every one of them is torn down before the next is
        # built, and all of them before the temporary import root goes.
        def measure(work) -> None:
            view = build_view(app, root)
            scene = view.rootObject()
            rail = scene.findChild(object, "railList")
            plain = scene.findChild(object, "plainList")
            if rail is None or plain is None:
                fail("the scene did not build the two lists")
            else:
                work(view, scene, rail, plain)
            view.setSource(QUrl())
            view.close()
            app.processEvents()

        measure(lambda view, scene, rail, plain: check_geometry(rail, plain))

        note("one wheel notch, four device shapes")
        for device, synthesized, accepted in WHEEL_SHAPES:
            measure(lambda view, scene, rail, plain, d=device, s=synthesized,
                    a=accepted: check_wheel(app, view, scene, rail, d, s, a))

        measure(lambda view, scene, rail, plain:
                check_net(app, view, scene, rail, plain))
        measure(lambda view, scene, rail, plain: check_drag(app, view, scene, rail))
        measure(lambda view, scene, rail, plain:
                check_calibration(app, view, scene, plain))

    if failed == 0:
        note("the wheel still scrolls the rail and the click after it still lands")
    return failed


if __name__ == "__main__":
    sys.exit(main())
