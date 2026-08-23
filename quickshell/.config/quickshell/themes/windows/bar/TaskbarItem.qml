// THE ONE SHAPE EVERY THING IN THE TASKBAR IS DRAWN ON.
//
// Windows' taskbar is not a row of pills. It is a row of RECTANGLES with a 4px
// radius, transparent at rest, that take a flat brush when the pointer is over
// them and a different flat brush while they are held down -- and nothing in
// between, at any point, ever. Eleven files in this directory need exactly that
// box, so it is written once here rather than eleven times.
//
// THIS FILE IS THE THEME'S OWN AND NOT PART OF THE INTERFACE. The host asks a
// theme for `bar/Bar.qml` and for nothing else under bar/; everything beside it
// is reached by relative import from inside this theme, which is what
// tests/theme-interface.py means when it says a theme's internals are its own.
// Sibling .qml files resolve without an import line, so the widgets simply name
// it.
//
// THE THREE THINGS IT GETS RIGHT THAT A RECREATION USUALLY GETS WRONG
//
// NO TRANSITION ON HOVER. Fluent.hoverMs is 0 and it is 0 on purpose: Windows
// swaps a control's brush on a `DiscreteObjectKeyFrame KeyTime="0"`. There is
// no `Behavior on color` in this file and there must not be one. A 150ms fade
// is the tell that gives a recreation away faster than any wrong colour,
// because every real Windows control in the same session is doing it without
// one. Reveal was Windows 10 and is dead.
//
// PRESS IS DARKER THAN HOVER. SubtleFillColorSecondary is #0FFFFFFF and
// SubtleFillColorTertiary is #0AFFFFFF -- the pressed fill sits BELOW the
// hovered one, not above it. Getting this the other way round is the second
// tell after animating the hover. Fluent.qml names the hover level
// (fillSubtleHover); the press level has no name there because the scheme has
// no role at #0A, so this file takes the level below the hover -- see the
// comment at the colour itself.
//
// NO POINTING HAND. The cursor over a Windows taskbar button is the ordinary
// arrow. Genesis sets Qt.PointingHandCursor on every control it draws, which is
// right for genesis and wrong here, and it is the kind of difference that is
// only ever noticed as a vague feeling that something is off.
//
// WHY THE FILLS GO THROUGH Theme.glass(). The bar itself is painted at
// Config.opacity so the compositor has something to blur behind; an opaque
// overlay on top of it would turn the hovered item into a solid patch on a
// translucent bar. Group.qml does the same on the host side and for the same
// reason. With opacity at 1 the call is a no-op.

import QtQuick
import qs
import ".."

Rectangle {
    id: root

    // THE HIT TARGET, AND ITS HEIGHT IS OURS. Fluent.taskButton -- the 40 of
    // an app button -- is the one taskbar box with corroboration behind it.
    // The corner items (the clock, the tray, a status glyph) are shorter than
    // that, and nothing published says how much shorter: 34 is measured off a
    // screenshot at 100% scaling and it is a design decision wearing a
    // measurement's clothes. It lives here rather than in Fluent.qml only
    // because that file was being edited elsewhere while this one was written;
    // it belongs there beside the other taskbar figures.
    property int boxHeight: 34
    property int boxWidth: root.boxHeight

    // Off for an item that is only a backplate for something else's input --
    // see Tray.qml, where one strip washes for a row of separately clickable
    // icons.
    property bool interactive: true

    // PAINT THE HOVER FILL WITHOUT BEING HOVERED. Windows keeps the subtle
    // brush on the foreground app's task button, and it is EXACTLY the hover
    // brush rather than a colour of its own: NavigationView's selected pill
    // does the same, and a recreation that gives the selected state its own
    // backplate has invented a state Windows does not have. What carries
    // selection is the indicator, not the fill.
    property bool washed: false

    signal activated
    signal secondaryActivated

    default property alias content: holder.data

    readonly property bool hovered: pointer.containsMouse && root.interactive
    readonly property bool held: pointer.pressed && root.interactive

    implicitWidth: root.boxWidth
    implicitHeight: root.boxHeight

    radius: Fluent.controlRadius

    color: {
        if (root.held)
            // SubtleFillColorTertiary is #0AFFFFFF and the scheme publishes no
            // role at that alpha: surfaceContainer is #0D, the nearest level
            // BELOW the hover's #15, which is the direction that matters.
            return Theme.glass(Theme.surfaceContainer);
        if (root.hovered || root.washed)
            return Theme.glass(Fluent.fillSubtleHover);
        return "transparent";
    }

    // NO `Behavior on color`. See the header. This is the load-bearing absence
    // in this file and deleting these three lines is how it comes back.

    Item {
        id: holder

        anchors.fill: parent
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.secondaryActivated();
            else
                root.activated();
        }
    }
}
