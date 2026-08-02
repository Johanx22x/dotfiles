// "Something is capturing this screen."
//
// The macOS recording dot, in this shell's vocabulary. It sits BESIDE the
// island rather than inside it, and that placement is the whole design:
//
//   - A privacy fact has to be continuously true on screen. Inside the island
//     it would be one rung of a ladder, which means anything above it could
//     take the slot -- a volume nudge would hide the fact that a call is
//     watching your desktop, which is exactly backwards.
//   - It is also not a rung BELOW media, because then starting a song would
//     hide it. There is no correct position for it in a one-slot widget. The
//     answer is not to put it in one.
//
// So the island keeps its rule -- one thing at a time -- and this keeps its
// own, much smaller, piece of bar. They never compete.
//
// WHAT IT SAYS, AND WHEN
// At rest: a breathing dot and a screen. That is the whole message -- you are
// being captured -- and it is the part that has to be true at a glance from
// across the room. WHICH screen is a follow-up question, so it is answered on
// hover and takes no width until asked. The badge is permanent, so its
// resting size is what it costs you all day.
//
// It borrows the island's own grammar for that: collapsed by default, wider
// on hover, and the width animates rather than the content appearing.
//
// The state, and the Hyprland event it comes from, live in IslandState.qml.
// This file is only the badge.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    // CAPTURE BY SOMEONE ELSE -- which is what this badge is for. A Discord
    // share has to be on the bar; a recording started from the dashboard is
    // already a rung inside the island with a stop button on it, and counting
    // it here as well put two red dots on the bar for one recording.
    //
    // SUBTRACTED, NOT SWITCHED OFF. Hiding the badge outright while we record
    // would also hide a share running at the same time -- the badge would go
    // out mid-call because you started a recording, which is exactly the
    // failure this badge exists to prevent. Hyprland emits one screencast
    // event PER CLIENT (verified with two recorders at once: two starts, two
    // stops), so IslandState counts them and this only has to discount our
    // own. Two sessions with one of them ours still lights the badge.
    //
    // The settle timer is for the gap at the end: our recorder is gone the
    // instant it exits, but Hyprland's event arrives about half a second
    // later, and without the delay the badge flashed on for that half second
    // on every stop.
    readonly property int mine: RecorderState.recording || settle.running ? 1 : 0

    readonly property bool external: IslandState.capturing && IslandState.captureSessions > root.mine

    Timer {
        id: settle

        interval: 1200
    }

    Connections {
        target: RecorderState

        function onRecordingChanged(): void {
            if (!RecorderState.recording)
                settle.restart();
        }
    }

    // Collapses to nothing when idle, so the bar has no hole in it. The width
    // animates rather than the visibility flipping: the badge grows out of the
    // island's right edge instead of appearing on top of it.
    implicitWidth: root.external ? pill.implicitWidth : 0
    implicitHeight: Theme.groupHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
    }

    clip: true

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: pill

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: content.implicitWidth + 22
        implicitHeight: Theme.groupHeight
        radius: Theme.groupRadius

        // Tinted rather than neutral. Every other pill on this bar is a
        // container; this one is a warning, and it should not be mistaken for
        // a reading at a glance.
        color: Qt.alpha(Theme.critical, hover.hovered ? 0.26 : 0.18)

        opacity: root.external ? 1 : 0

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.critical

                // Breathing, not blinking. A hard on/off reads as a fault
                // light; this reads as something running.
                SequentialAnimation on opacity {
                    running: IslandState.capturing
                    loops: Animation.Infinite

                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.monitor
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.critical
            }

            // A SLOT that widens, not a label that appears.
            //
            // The Text cannot be the thing animating: giving a Text an explicit
            // width narrower than its content makes it wrap or elide rather
            // than be revealed. So the label sits at its natural size inside a
            // clipping Item, and the ITEM's width is what moves -- the text
            // slides out from behind the screen glyph.
            //
            // `visible` follows the width because a Row does not lay out
            // invisible children: without it the Row's spacing would leave a
            // gap on the right at rest, and the badge would not actually be
            // any narrower.
            Item {
                anchors.verticalCenter: parent.verticalCenter

                clip: true
                width: hover.hovered ? label.implicitWidth : 0
                height: label.implicitHeight
                visible: width > 0

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Text {
                    id: label

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    // What is being taken, not just that something is. "My
                    // second monitor is shared" and "my whole desktop is
                    // shared" are not the same news, and Hyprland hands the
                    // name over for free in screencastv2 -- the menu-bar dot
                    // on macOS cannot tell you this.
                    text: IslandState.captureOwner === "window"
                        ? "Sharing a window"
                        : (IslandState.captureTarget ? `Sharing ${IslandState.captureTarget}` : "Sharing this screen")

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Font.Bold
                    color: Theme.textOnSurface

                    opacity: hover.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }
        }
    }
}
