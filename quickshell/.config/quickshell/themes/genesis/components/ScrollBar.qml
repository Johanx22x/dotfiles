// How genesis draws a scrollbar. The public half -- what a bar is FOR, where a
// call site may put one, what it may anchor to and who ends up on top -- is
// components/ScrollBar.qml, and this file is the two rectangles that were
// below those comments before the split, moved unchanged.
//
// `row` IS THE FACADE AND NOT A LIST ROW. It is what every file in this
// directory calls the object it was handed, a Popout and a Tooltip included;
// see README.md, which is also where the sixteen lines that hand it over live.
//
// ---------------------------------------------------------------------------
// THE PRESS TARGET IS NOT IN HERE, AND MUST NOT BE PUT IN HERE
// ---------------------------------------------------------------------------
//
// This is rule 7 for this component, and it is the sharpest one in the
// directory because breaking it would look like an improvement. Four pixels is
// a mean thing to ask anyone to hit, so the obvious thing for a theme to do is
// wrap the pill in a MouseArea with a comfortable margin -- which is exactly
// what VolumeSlider.qml in this directory does, six pixels of it, and is right
// there.
//
// It is wrong here. The facade already widens the target, by three pixels on
// the side that faces the view and eleven on the side that faces the padding,
// and those two numbers are not a fact about a pill: they are a rule about who
// hears a press down the edge of every scrolling view in the shell, arrived at
// by finding the same defect twice -- the settings rail that scrolled instead
// of opening a page, the launcher grid that scrolled instead of launching an
// application. A second MouseArea in here would take those presses first, at
// whatever margin this file felt like, and tests/scrollbar-target.py would go
// on measuring the facade's numbers while the desktop used these ones.
//
// So this file draws and reads, and every event belongs to the half above it.
//
// ---------------------------------------------------------------------------
// WHAT THIS FILE OWES THE FACADE
// ---------------------------------------------------------------------------
//
//   implicitWidth   how wide the pill is drawn. The facade takes its own width
//                   from it, the press target is widened around it, and two
//                   call sites reserve their gutter from it -- so this number
//                   is the shell's idea of how much room a scrollbar takes.
//
//   implicitHeight  THE SHORTEST TRACK THIS THUMB CAN LIVE IN, which is the
//                   floor the facade puts under a proportional thumb. It is
//                   not "how tall a scrollbar wants to be" -- nothing lays one
//                   out that way -- and this is the one place in this
//                   directory where implicitHeight does not mean what rule 2
//                   says it means. Bind it to `root.height` out of habit and
//                   the thumb is floored at the whole track and stops moving.
//
// And in return the facade hands down `thumbY` and `thumbHeight` already
// worked out. Do not recompute them from `row.view` -- the press arithmetic up
// there treats the pointer as the middle of the thumb and needs the length
// this file actually drew, so a thumb drawn anywhere else is a thumb that
// lands somewhere else when it is grabbed.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property, and typed
    // for the reason rule 1 of README.md sets out: `property var row` would
    // make every read below unchecked. `ScrollBar` here is
    // components/ScrollBar.qml and not this file, even though the two share a
    // name -- the explicit `import qs.components` wins over the directory a
    // document implicitly imports.
    required property ScrollBar row

    // See the header: the width of the pill, and the floor under the thumb.
    // Four is wide enough to see against a card and narrow enough that the
    // pixels it takes from a full-width row land on that row's padding;
    // thirty is what keeps fifty entries from leaving a four-pixel dot.
    implicitWidth: 4
    implicitHeight: 30

    radius: width / 2

    // Half-transparent, so the track reads as a groove in whatever it is drawn
    // over rather than as a second object beside it.
    color: Qt.alpha(Theme.outlineVariant, 0.5)

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    Rectangle {
        id: thumb

        // Both of these are the facade's arithmetic. See the header for why
        // they are not this file's.
        y: root.row.thumbY
        height: root.row.thumbHeight

        width: parent.width
        radius: parent.radius

        // Brighter while it is being used -- moved, dragged or pointed at --
        // and quiet the rest of the time. At rest this is a hint about the
        // shape of the view; in the hand it is a control, and the two should
        // not look the same. WHEN that is true is the facade's `inUse`, which
        // knows about wheels and flicks and about a pointer this file never
        // sees; which two colours it means is this file's.
        color: root.row.inUse ? Theme.primary : Theme.outline

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }
}
