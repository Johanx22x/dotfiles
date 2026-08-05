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
import "root:/components"

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    // The keyboard keys go to 150% on purpose (see hyprland.lua) and this
    // track only represents 0..100: past that the fill would be drawn wider
    // than its own rail and the handle would walk off the end. The slider is
    // given a maximum of 1 and clamps the geometry itself; colouring the
    // overflow says "above the limit" without the bar having to grow a second
    // scale nobody asked for.
    //
    // THE SETTINGS WINDOW MAKES THE OPPOSITE CHOICE and shows the real 0..150
    // range. That is not a contradiction: this control hangs off the bar
    // under a pointer that is on its way somewhere else, and the settings
    // page is somewhere you go on purpose. See the note over VolumeLine in
    // AudioPage.qml.
    readonly property bool overamplified: root.volume > 1.001

    readonly property color accent: {
        if (root.muted)
            return Theme.outline;
        return root.overamplified ? Theme.warning : Theme.primary;
    }

    // Shared with the sound page rather than decided twice -- see the note on
    // the function in Icons.qml.
    readonly property string glyph: Icons.outputGlyph(
        `${sink?.name ?? ""} ${sink?.description ?? ""}`, root.muted, root.volume)

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
    //
    // The drawing moved out to components/VolumeSlider.qml when the sound
    // page needed four more of them. Nothing about the behaviour here
    // changed with it except for one bug that came out in the move: the
    // MouseArea is inset by negative margins, and the old code divided its
    // raw x by the track width without correcting for them, so every click
    // landed about 3% high.
    VolumeSlider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        value: root.volume
        maximum: 1
        accent: root.accent

        onMoved: value => root.setVolume(value)
    }
}
