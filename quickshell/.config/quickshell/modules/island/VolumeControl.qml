// Output volume, as a hairline along the very bottom edge of the dashboard.
//
// IT WAS A CARD: a speaker glyph doubling as the mute button, a percentage on
// the right, and a slider under both -- sixty-two pixels of panel to carry one
// number. A control that needs ONE DIMENSION gets one dimension, so it is a
// six-pixel rule spanning the whole panel now. It says the same thing, it
// takes no height from anything else, and because it spans the panel it is a
// wider target than the slider it replaces ever was.
//
// WHAT MOVED RATHER THAN LEFT. The mute is a RIGHT-CLICK on the line, and the
// whole line goes dim to say so; there is no room on a rule for a button and
// there was no honest way to keep one. That is the least discoverable thing in
// this redesign and it is written down here rather than left to be found. The
// percentage is on hover, above the right-hand end, so the number is available
// without a label sitting there permanently saying what any straight line
// already says.
//
// The wheel works too, which the card never offered: the pointer is already on
// the line to read it.
//
// PwObjectTracker is not optional. PipeWire binds objects lazily: without
// something declaring interest in the node, its `audio` data is never
// populated and the volume reads 0 forever.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"

Item {
    id: root

    // The panel this is drawn on is a photograph, so the colour cannot come
    // from Theme -- see the note on `ink` in Dashboard.qml. The default is
    // the shell's own text colour, so the control still works anywhere else.
    property color ink: Theme.textOnSurface

    // How far above the line the pointer still counts as being on it. The
    // rule is six pixels tall and nobody can hit six pixels on purpose.
    readonly property int reach: 16

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    // The keyboard keys go to 150% on purpose (see hyprland.lua) and this
    // rail only represents 0..100: past that the fill would be drawn wider
    // than the panel. Colouring the overflow says "above the limit" without
    // the line having to grow a second scale nobody asked for.
    readonly property bool overamplified: root.volume > 1.001

    readonly property color accent: {
        if (root.muted)
            return Qt.alpha(root.ink, 0.3);
        return root.overamplified ? Theme.warning : Qt.alpha(root.ink, 0.85);
    }

    function setVolume(value: real): void {
        if (!root.sink?.audio)
            return;
        // Capped at 1.0. Above that PipeWire applies gain in software and the
        // sound distorts; the keyboard keys allow it deliberately, a pointer
        // should not do it by accident.
        root.sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    implicitHeight: 6

    // ---------------- The rail ----------------
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.ink, 0.15)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: parent.width * Math.max(0, Math.min(1, root.volume))
        color: root.accent

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- The number, only while it is being looked at --------
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.top
        anchors.bottomMargin: 6

        visible: opacity > 0
        opacity: rail.containsMouse ? 1 : 0

        text: root.muted ? "muted" : `${Math.round(root.volume * 100)}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize * 0.85
        font.weight: Font.Bold
        color: root.overamplified && !root.muted ? Theme.warning : root.ink

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- Aiming ----------------
    //
    // The hit area reaches UP out of the item. Nothing above it is closer
    // than the actions strip, which clears the bottom edge by the panel's own
    // margin, so there is nothing for this to steal a click from.
    MouseArea {
        id: rail

        anchors.fill: parent
        anchors.topMargin: -root.reach

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        function report(mouseX: real): void {
            if (root.width <= 0)
                return;
            root.setVolume(mouseX / root.width);
        }

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
                return;
            }
            rail.report(mouse.x);
        }

        onPositionChanged: mouse => {
            if (rail.pressed && !(rail.pressedButtons & Qt.RightButton))
                rail.report(mouse.x);
        }

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
            root.setVolume(root.volume + step);
        }
    }
}
