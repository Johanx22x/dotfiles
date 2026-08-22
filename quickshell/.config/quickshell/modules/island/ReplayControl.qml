// Instant replay: is it running, and keep the last thirty seconds.
//
// TWO CONTROLS, AND IT USED TO BE FIVE. The switch and the save button are
// what is here; a row of four length chips with the buffer's size in RAM
// beside them, and a row of monitor chips with the connector name beside
// those, are what left. They were not wrong -- each was added to fix something
// real -- they simply stopped being the only way to reach those settings.
//
// WHERE THEY WENT. modules/settings/pages/RecordingPage.qml owns the buffer's
// configuration now: the length, whether it lives in RAM or on disk, which
// screen, the codec, the container, the bitrate and its mode, the framerate
// and the microphone. It explains each one beside the control, it can offer
// the codecs THIS card actually has an encoder for, and it does not have to
// fit in a column of a popout.
//
// WHAT A KEYSTROKE-OPENED PANEL IS FOR is the other half of it: the act, not
// the settings. Whether the buffer is running, and the button that turns the
// last thirty seconds into a file.
//
// TWO ROWS BECAME ONE. The dashboard's actions strip is a single line shared
// with the three capture targets, so the header line this used to carry is
// gone and everything it said had to find a place on the button:
//
//   "Instant replay"     the switch is on -- so the button offers the save
//   "Replay elsewhere"   another shell holds the buffer. THREE ANSWERS AND
//                        NOT TWO: a shell that stood down for another one has
//                        the switch ON and no buffer, and calling that "off"
//                        would send somebody to a switch already where they
//                        want it. See ReplayState.heldElsewhere
//   "Replay off"         the switch is off
//
// THE CONNECTOR NAME STAYED, on the button's right, and that is deliberate
// rather than an oversight in the trimming. The monitor chips were added
// because their absence cost a clip: the buffer followed the shell's own
// screen with nothing on screen saying which one that was. CHOOSING the screen
// belongs with the rest of the configuration; SEEING which one it is belongs
// wherever the save button is.
//
// THE COLOURS COME FROM THE CALLER, for the reason RecordControl.qml gives.
//
// The state, the process and the persisted duration live in
// modules/recorder/ReplayState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    property color ink: Theme.textOnSurface
    property color inkMuted: Theme.textOnSurfaceVariant
    property color wash: Theme.surfaceContainerHighest

    // What is legible ON the switch's own fill when it is on.
    property color inkInverse: Theme.textOnPrimary

    implicitWidth: line.implicitWidth
    implicitHeight: 34

    Row {
        id: line

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        // ---------------- Save ----------------
        //
        // The one control in the panel that produces a file, and the reason
        // the buffer is running at all. THE LENGTH IS ON THE BUTTON: the
        // number was always the useful half of the chips that carried it --
        // what this is about to hand you -- and it is the half that has to be
        // visible at the moment of pressing.
        Rectangle {
            id: save

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: saveRow.implicitWidth + 22
            implicitHeight: 34
            radius: 10

            opacity: ReplayState.armed ? 1 : 0.45
            color: saveMouse.containsMouse && ReplayState.armed ? root.wash : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            // Pressed state, so the click lands somewhere rather than only in
            // the island a moment later.
            scale: saveMouse.pressed ? 0.97 : 1

            Behavior on scale {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }

            Row {
                id: saveRow

                anchors.centerIn: parent
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.replay
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: ReplayState.armed ? root.ink : root.inkMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ReplayState.armed ? `Save last ${ReplayState.seconds}s`
                        : ReplayState.heldElsewhere ? "Replay elsewhere" : "Replay off"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize * 0.85
                    font.weight: Font.Bold
                    color: root.ink
                }
            }

            MouseArea {
                id: saveMouse

                anchors.fill: parent
                enabled: ReplayState.armed
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // The panel goes away with the click. Watching a dashboard
                // while it saves the last thirty seconds -- of a dashboard --
                // is not what anyone wants the clip to contain, and the island
                // confirms the save on its own.
                onClicked: {
                    IslandState.closeDashboard();
                    ReplayState.save();
                }
            }
        }

        // The connector gpu-screen-recorder was actually handed, not the
        // monitor as a person names it. Those two disagree in exactly one case
        // -- a chosen monitor that is not plugged in -- and that is the case
        // worth being able to see. Amber then: the buffer is running, it is
        // simply not running where it was told to.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: Screens.all.length > 1 || ReplayState.monitorMissing
            text: ReplayState.monitor === "" ? "no screen" : ReplayState.monitor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize * 0.78
            color: ReplayState.monitorMissing ? Theme.warning : root.inkMuted

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // ---------------- The switch ----------------
        //
        // THE DRAWING PUT A DOT HERE, and a dot is a state rather than a
        // control: it says whether the buffer is running and gives you nothing
        // to press. Arming it is one of the two things this panel is for, so
        // it keeps the switch it had -- same size, same travel, in the panel's
        // ink rather than in an accent that could land on a ground of its own
        // colour.
        Rectangle {
            id: toggle

            anchors.verticalCenter: parent.verticalCenter

            width: 40
            height: 22
            radius: height / 2
            color: ReplayState.armed ? Qt.alpha(root.ink, 0.92) : Qt.alpha(root.ink, 0.2)

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                x: ReplayState.armed ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                width: 16
                height: 16
                radius: height / 2
                color: ReplayState.armed ? root.inkInverse : Qt.alpha(root.ink, 0.6)

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ReplayState.toggle()
            }
        }
    }
}
