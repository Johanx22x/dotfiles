// Output volume: the glyph that mutes it, a slider, and the number.
//
// IT WAS A SIX-PIXEL HAIRLINE ALONG THE BOTTOM EDGE OF THE PANEL, and the
// line that justified it -- "a control that needs one dimension gets one
// dimension" -- was better on paper than in use. Three things went wrong with
// it and only one of them was the size:
//
//   the mute lost its button      there is nowhere on a rule to put a glyph,
//                                 so muting became a right-click that needed
//                                 a paragraph to explain. A control whose
//                                 documentation is longer than the control is
//                                 the wrong control
//   the number was on hover       so the panel could not answer "how loud is
//                                 it" without being pointed at
//   it sat on the panel's edge    which is where the pointer travels rather
//                                 than where it aims
//
// So it is a band of its own again, and being a band is what lets the left
// column reach the same height as the calendar beside it -- see `bodyHeight`
// in Dashboard.qml. The compaction and this are the same change.
//
// WHAT SURVIVED FROM THE HAIRLINE: the wheel. The pointer is already on the
// row to read the number, and turning the wheel there is faster than aiming
// at the handle. That was a genuine improvement and it is kept.
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

    // The panel this is drawn on is a photograph, so the colours cannot come
    // from Theme -- see the note on `ink` in Dashboard.qml. The defaults are
    // the shell's own, so the control still works anywhere else.
    property color ink: Theme.textOnSurface

    // Rest and hover for the mute button. Everything pressable on the wall
    // carries a surface at rest; see the note over `Pressable` in
    // Dashboard.qml.
    property color rest: Qt.alpha(root.ink, 0.13)
    property color wash: Qt.alpha(root.ink, 0.26)

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    // The keyboard keys go to 150% on purpose (see hyprland.lua) and this
    // rail only represents 0..100: past that the fill would be drawn wider
    // than its own track. Colouring the overflow says "above the limit"
    // without the row growing a second scale nobody asked for.
    readonly property bool overamplified: root.volume > 1.001

    readonly property color accent: {
        if (root.muted)
            return Qt.alpha(root.ink, 0.35);
        return root.overamplified ? Theme.warning : Qt.alpha(root.ink, 0.88);
    }

    // Shared with the sound page rather than decided twice -- see the note on
    // the function in Icons.qml.
    readonly property string glyph: Icons.outputGlyph(
        `${sink?.name ?? ""} ${sink?.description ?? ""}`, root.muted, root.volume)

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

    implicitHeight: 34

    // ---------------- The glyph, which is the mute button ----------------
    Rectangle {
        id: muteButton

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: 30
        height: 30
        radius: width / 2

        color: muteMouse.containsMouse ? root.wash : root.rest

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.muted ? Qt.alpha(root.ink, 0.5) : root.ink

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

    // ---------------- The number ----------------
    //
    // ALWAYS THERE and not on hover. It is one of the two things this row
    // exists to say, and a panel you have to point at to read is a panel that
    // has not answered.
    Text {
        id: readout

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.muted ? "muted" : `${Math.round(root.volume * 100)}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: {
            if (root.muted)
                return Qt.alpha(root.ink, 0.5);
            return root.overamplified ? Theme.warning : root.ink;
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- The slider ----------------
    //
    // components/VolumeSlider.qml, the one every volume in this shell is
    // dragged with -- including the four on the sound page. It grew two
    // colour properties for this caller and nothing else changed; the aiming,
    // the wheel and the handle that swells under the pointer are all its own.
    VolumeSlider {
        anchors.left: muteButton.right
        anchors.leftMargin: 14
        anchors.right: readout.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter

        value: root.volume
        maximum: 1

        accent: root.accent
        railColor: Qt.alpha(root.ink, 0.18)

        onMoved: value => root.setVolume(value)
    }
}
