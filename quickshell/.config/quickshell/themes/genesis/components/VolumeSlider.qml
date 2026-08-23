// How genesis draws a volume slider. The public half -- the range, the units,
// what `notch` means and why the wheel is off on the sound page -- is
// components/VolumeSlider.qml.
//
// Built by hand rather than from QtQuick.Controls, for the reason the island's
// copy already gave: a Controls Slider arrives with its own style, and styling
// it back into this palette is more code than drawing a bar.
//
// THE TWO PROMISES THIS FILE KEEPS, both of which the facade can require no
// property for:
//
//   A CLICK JUMPS AND A DRAG FOLLOWS. `onPressed` and `onPositionChanged`
//   both report, so there is one gesture and no dead zone on the rail where
//   pressing does nothing.
//
//   THE WHEEL'S ANSWER IS HANDED BACK. `event.accepted` is assigned what
//   row.wheel() returned, every time. Dropping it -- or writing an empty
//   handler, which looks like the same thing -- turns the sound page's
//   sliders into dead patches that swallow the notch instead of scrolling
//   the page. The facade's wheel() has the long version.
//
// AND THE ARITHMETIC THAT USED TO BE UPSTAIRS IS DOWN HERE NOW. emit() below
// converts a pointer x into a share of the rail. Both numbers it needs are
// this file's own -- the six pixels the hit area is inset by, and the width
// of the rail this file drew -- which is exactly why the facade stopped doing
// it. A theme that insets by a different amount changes one line here and
// nothing anywhere else.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `VolumeSlider` here is the facade and
    // not this file.
    required property VolumeSlider row

    // WHAT THE FACADE READS BACK. Twenty is the height of the hit area's
    // business end, not of the 6px rail: the row is thin and the pointer is
    // not. The facade floors at the same number.
    implicitHeight: 20

    // ---------------- Rail ----------------
    Rectangle {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: root.row.railColor

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- Fill ----------------
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: rail.width * root.row.fraction
        height: 6
        radius: 3
        color: root.row.accent

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- The mark ----------------
    //
    // OVER THE FILL AND UNDER THE HANDLE, which is the whole reason it is
    // written here and not before the fill: painted underneath it would
    // disappear at exactly the moment it starts to mean something, which is
    // when the fill has passed it.
    Rectangle {
        visible: root.row.notch > 0 && root.row.notch < root.row.maximum

        x: rail.width * (root.row.notch / root.row.maximum) - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: 2
        height: 12
        radius: 1

        // See notchColor on the facade: it reads as a gap cut through the bar
        // rather than as a third colour, which works over the rail and over
        // the fill alike where no ink colour does.
        color: root.row.notchColor

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- Handle ----------------
    Rectangle {
        x: rail.width * root.row.fraction - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: 14
        height: 14
        radius: 7
        color: root.row.accent

        // Grows under the pointer: the handle is the thing being aimed at and
        // 14px is small for a mouse.
        scale: mouse.containsMouse || mouse.pressed ? 1.25 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.animDuration }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        // Taller than the 6px rail it covers: the row is thin and the pointer
        // is not.
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Both, so a click jumps and a drag follows.
        onPressed: event => root.emit(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.emit(event.x);
        }

        // THE ANSWER IS HANDED BACK, and that assignment is the whole of this
        // theme's part in the wheel. Whether a notch belongs to this slider at
        // all is the facade's decision -- see its wheel() -- and dropping the
        // result here would leave the sound page with a dead strip down every
        // slider instead of a page that scrolls.
        onWheel: event => {
            event.accepted = root.row.wheel(event.angleDelta.y);
        }
    }

    // WHERE THE POINTER IS ALONG THE RAIL, 0 TO 1, WHICH IS ALL THE FACADE
    // WANTS TO KNOW.
    //
    // The MouseArea is inset by its negative margins, so its x is 6px to the
    // left of the rail's; without correcting for that, a press at the very
    // start of the rail reports a small negative share and one at the end
    // overshoots. Both of those numbers are this file's -- the inset is right
    // above, and the rail is one this file drew -- which is why this
    // arithmetic lives here and the clamp and the range do not. The facade
    // clamps what comes out of this, so the margins are free to let the
    // pointer stray past both ends.
    function emit(x: real): void {
        root.row.moveTo((x + mouse.anchors.margins) / rail.width);
    }
}
