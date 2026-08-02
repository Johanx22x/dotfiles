// Output volume, with a slider you can actually aim at.
//
// The bar's island shows the volume for two seconds after you change it; this
// is the other half -- the place you go when you want to SET it rather than
// be told about it.
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

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    // What the SLIDER draws, as opposed to what the volume is.
    //
    // The keyboard keys go to 150% on purpose (see hyprland.lua), and the
    // track only represents 0..100: past that the fill was drawn wider than
    // its own rail and the handle walked off the end. Clamping the geometry
    // and colouring the overflow says "above the limit" without the bar
    // having to grow a second scale nobody asked for.
    readonly property real sliderValue: Math.min(1, root.volume)
    readonly property bool overamplified: root.volume > 1.001

    readonly property color accent: {
        if (root.muted)
            return Theme.outline;
        return root.overamplified ? Theme.warning : Theme.primary;
    }

    readonly property string glyph: {
        if (root.muted)
            return Icons.volumeMuted;
        const both = `${sink?.name ?? ""} ${sink?.description ?? ""}`.toLowerCase();
        if (both.includes("headset"))
            return Icons.headset;
        if (both.includes("headphone"))
            return Icons.headphones;
        if (root.volume < 0.01)
            return Icons.volumeLow;
        if (root.volume < 0.5)
            return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    function setVolume(value: real): void {
        if (!root.sink?.audio)
            return;
        // Capped at 1.0. Above that PipeWire applies gain in software and the
        // sound distorts; the keyboard keys allow it deliberately, a slider
        // dragged with a mouse should not do it by accident.
        root.sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    implicitHeight: 62

    // ---------------- Icon, doubling as the mute button ----------------
    Rectangle {
        id: muteButton

        anchors.left: parent.left
        anchors.top: parent.top

        width: 34
        height: 34
        radius: height / 2
        color: muteMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.muted ? Theme.outline : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: muteMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: muteButton.verticalCenter

        text: root.muted ? "muted" : `${Math.round(root.volume * 100)}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: {
            if (root.muted)
                return Theme.outline;
            return root.overamplified ? Theme.warning : Theme.textOnSurface;
        }
    }

    // ---------------- Slider ----------------
    // Built from two rectangles and a MouseArea rather than from
    // QtQuick.Controls: a Controls Slider brings its own style, and styling it
    // back into this palette is more code than drawing a bar.
    Item {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.surfaceContainerHighest
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.sliderValue
            height: 6
            radius: 3
            color: root.accent

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Rectangle {
            x: parent.width * root.sliderValue - width / 2
            anchors.verticalCenter: parent.verticalCenter

            width: 14
            height: 14
            radius: 7
            color: root.accent

            // Grows under the pointer: the handle is the thing being aimed at
            // and 14px is small for a mouse.
            scale: trackMouse.containsMouse || trackMouse.pressed ? 1.25 : 1

            Behavior on scale {
                NumberAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: trackMouse

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // Both, so a click jumps and a drag follows.
            onPressed: mouse => root.setVolume(mouse.x / track.width)
            onPositionChanged: mouse => {
                if (pressed)
                    root.setVolume(mouse.x / track.width);
            }

            // Same 5% step the bar's wheel uses.
            onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
}
