// How the windows theme draws a scrollbar. The public half -- what a bar is
// FOR, where a call site may put one, what it may anchor to and who ends up on
// top -- is components/ScrollBar.qml.
//
// `row` IS THE FACADE AND NOT A LIST ROW. It is what every file in this
// directory calls the object it was handed, a Popout and a Tooltip included.
//
// ---------------------------------------------------------------------------
// THIS ONE IS A BEHAVIOUR AND NOT A SHAPE
// ---------------------------------------------------------------------------
//
// Windows' scrollbar is one of the most recognisable details in the system and
// almost none of what makes it recognisable is a colour or a radius. It is a
// TWO-PIXEL LINE at rest inside a TWELVE-PIXEL gutter. Point at it and nothing
// happens for FOUR HUNDRED MILLISECONDS; then, over 167, the line widens to SIX
// and a track fades in behind it. Take the pointer away and it stays wide for
// FIVE HUNDRED before going back.
//
// THE THUMB'S COLOUR NEVER CHANGES. Not on hover, not while dragging, not while
// the wheel is turning. genesis switches it from `Theme.outline` to
// `Theme.primary` while the bar is in use and that is a real design decision --
// it is simply not this one. Here the whole affordance is the width and the
// track appearing behind it, and adding a colour change on top would say the
// same thing three times.
//
// The delay is what a scrollbar is FOR: it has to be visible enough to read
// while you are reading the page, and only becomes a control once you have
// aimed at it on purpose. Four hundred milliseconds is long enough that a
// pointer crossing the edge of a list on its way somewhere else never widens
// anything.
//
// All six numbers are Fluent.scroll* and Fluent.fastMs. None of them is retyped
// here.
//
// ---------------------------------------------------------------------------
// THE PRESS TARGET IS NOT IN HERE, AND MUST NOT BE PUT IN HERE
// ---------------------------------------------------------------------------
//
// This is rule 7 for this component, and it is the sharpest one in the
// directory because breaking it would look like an improvement. Two pixels is a
// mean thing to ask anyone to hit, so the obvious thing for a theme to do is
// wrap the line in a MouseArea with a comfortable margin -- which is exactly
// what VolumeSlider.qml in this directory used to do and is right there.
//
// It is wrong here. The facade already widens the target, by three pixels on
// the side that faces the view and eleven on the side that faces the padding,
// and those two numbers are not a fact about a pill: they are a rule about who
// hears a press down the edge of every scrolling view in the shell, arrived at
// by finding the same defect twice -- the settings rail that scrolled instead of
// opening a page, the launcher grid that scrolled instead of launching an
// application. A second MouseArea in here would take those presses first, at
// whatever margin this file felt like, and tests/scrollbar-target.py would go on
// measuring the facade's numbers while the desktop used these ones.
//
// The facade also declares its MouseArea BEFORE its Loader so that the target
// sits above this drawing. So this file draws and reads, and every event
// belongs to the half above it.
//
// AND THE POINTER ARRIVES THROUGH `row.inUse`. That is the only signal this
// side gets, and it is the right one: it is true for a hover, a drag, a flick
// and a wheel notch alike, and a wheel notch is not a state a Flickable reports
// any other way.
//
// ---------------------------------------------------------------------------
// WHAT THIS FILE OWES THE FACADE
// ---------------------------------------------------------------------------
//
//   implicitWidth   how wide a scrollbar is. TWELVE -- the gutter, not the line
//                   -- because the facade takes its own width from this and two
//                   call sites reserve their layout from it, and what has to be
//                   kept clear is the space the bar expands INTO rather than
//                   the two pixels it rests at. A bar that reported 2 would be
//                   given two pixels of room and would grow over the content
//                   beside it the moment somebody pointed at it.
//
//   implicitHeight  THE SHORTEST TRACK THIS THUMB CAN LIVE IN, which is the
//                   floor the facade puts under a proportional thumb. It is not
//                   "how tall a scrollbar wants to be" -- nothing lays one out
//                   that way -- and this is the one place in this directory
//                   where implicitHeight does not mean what rule 2 says it
//                   means. Bind it to `root.height` out of habit and the thumb
//                   is floored at the whole track and stops moving.
//
// And in return the facade hands down `thumbY` and `thumbHeight` already worked
// out. Do not recompute them from `row.view` -- the press arithmetic up there
// treats the pointer as the middle of the thumb and needs the length this file
// actually drew, so a thumb drawn anywhere else is a thumb that lands somewhere
// else when it is grabbed.

import QtQuick
import qs
// ScrollBar is components/ScrollBar.qml -- the facade -- and not this file,
// even though the two share a name. The explicit import wins over the directory
// a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property ScrollBar row

    // See the header for what each of these means. Neither is derived from the
    // size this item was given.
    implicitWidth: Fluent.scrollGutter
    implicitHeight: Fluent.scrollThumbMin

    // ---------------- The dwell ----------------
    //
    // WIDE OR NARROW, and the only thing that ever writes it is the timer below.
    // Bound straight to `row.inUse` it would widen the instant a pointer touched
    // the edge of a list, which is the behaviour Windows spends 400ms avoiding.
    property bool expanded: false

    // ONE TIMER FOR BOTH DIRECTIONS, because they are the same rule with two
    // constants: wait, then agree with the pointer. It runs only while the two
    // disagree, so a pointer that arrives and leaves again inside the four
    // hundred milliseconds stops it before it fires and nothing moves -- and a
    // pointer that comes back inside the five hundred cancels the contraction
    // the same way.
    //
    // Changing `interval` on a running Timer restarts it, which is exactly what
    // is wanted here: the interval only ever changes when `row.inUse` changes,
    // and that is the moment the clock should start again.
    Timer {
        interval: root.row.inUse ? Fluent.scrollExpandDelayMs : Fluent.scrollContractDelayMs
        running: root.row.inUse !== root.expanded
        onTriggered: root.expanded = root.row.inUse
    }

    // ---------------- The track ----------------
    //
    // Behind the line and only there once the bar has widened: at rest a Windows
    // scrollbar is a line on the content, with nothing behind it. It fades
    // rather than appearing, which is the one thing in this file that is not
    // instant -- it is not a hover state, it is the same 167ms transition the
    // width below runs on.
    Rectangle {
        anchors.fill: parent

        radius: Fluent.scrollRadius
        antialiasing: true
        color: Theme.surfaceContainer
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Fluent.fastMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }
    }

    // ---------------- The thumb ----------------
    //
    // ONE COLOUR, FOR EVERY STATE. See the header: the affordance is the width.
    // ControlStrongFillColorDefault is the grey it is, which is the scheme's
    // `Theme.outline` -- the same one the slider's unfilled track uses.
    //
    // `radius` is 3 and Qt clamps it to half the shorter side, so the line is a
    // capsule at both widths without this file having to say so twice.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter

        // Both of these are the facade's arithmetic. See the header for why they
        // are not this file's.
        y: root.row.thumbY
        height: root.row.thumbHeight

        width: root.expanded ? Fluent.scrollLineHover : Fluent.scrollLineRest
        radius: Fluent.scrollRadius
        antialiasing: true
        color: Theme.outline

        // ControlFastAnimationDuration on WinUI's one easing spline.
        Behavior on width {
            NumberAnimation {
                duration: Fluent.fastMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }
    }
}
