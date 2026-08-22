// Instant replay: is it running, and keep the last thirty seconds.
//
// TWO CONTROLS, AND IT USED TO BE FIVE. The switch and the save button are
// what is here; a row of four length chips with the buffer's size in RAM
// beside them, and a row of monitor chips with the connector name beside
// those, are what left. They were not wrong -- each of them was added to fix
// something real, and the reasoning is preserved below where it still applies
// -- they simply stopped being the only way to reach those settings.
//
// WHERE THEY WENT. modules/settings/pages/RecordingPage.qml owns the buffer's
// configuration now: the length, whether it lives in RAM or on disk, which
// screen, the codec, the container, the bitrate and its mode, the framerate
// and the microphone. It explains each one beside the control, it can offer
// the codecs THIS card actually has an encoder for, and it does not have to
// fit in a column of a popout. A dashboard that also carried two of those
// rows was carrying a worse copy of a page that already exists.
//
// WHAT A KEYSTROKE-OPENED PANEL IS FOR is the other half of it: the act, not
// the settings. Whether the buffer is running, and the button that turns the
// last thirty seconds into a file. Everything else is a decision you make
// twice a year.
//
// THE CONNECTOR NAME STAYED, and that is deliberate rather than an oversight
// in the trimming. The monitor chips were added because their absence cost a
// clip: the buffer followed the shell's own screen with nothing on screen
// saying which one that was, and it spent a long time holding the side panel
// while the switch said "Instant replay" and the button said "Save last 30s",
// both telling the truth about the wrong screen. A capture with no visible
// subject is the one setting you cannot check by looking at what it produces,
// because by then what it produces is the evidence.
//
// CHOOSING the screen belongs with the rest of the configuration. SEEING
// which one it is belongs wherever the save button is. So the chips went and
// the readout stayed, on the header line, where it costs no height at all.
//
// The state, the process and the persisted duration live in
// modules/recorder/ReplayState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    implicitHeight: header.height + 10 + save.height

    // ---------------- Header: what it is, where, and the switch ----------
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: 34

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.replay
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: ReplayState.armed ? Theme.primary : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // The connector gpu-screen-recorder was actually handed, not the
        // monitor as a person names it. Those two disagree in exactly one
        // case -- a chosen monitor that is not plugged in -- and that is the
        // case worth being able to see.
        //
        // Shown when there is more than one screen to be wrong about, and
        // shown anyway when the stored choice is missing, which is what a
        // machine with two screens yesterday and one today looks like. Amber
        // then: the buffer is running, it is simply not running where it was
        // told to, and that is a state that ends when the screen comes back
        // rather than an error.
        //
        // It is measured off its own string and the label to its left elides
        // against it, so a long connector name never pushes anything off the
        // row and there is no loop between the two widths.
        Text {
            id: connector

            anchors.right: toggle.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            visible: Screens.all.length > 1 || ReplayState.monitorMissing
            text: ReplayState.monitor === "" ? "no screen" : ReplayState.monitor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            color: ReplayState.monitorMissing ? Theme.warning : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.left: glyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: connector.visible ? connector.left : toggle.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            text: ReplayState.armed ? "Instant replay" : "Replay off"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurface
        }

        Rectangle {
            id: toggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: 40
            height: 22
            radius: height / 2
            color: ReplayState.armed ? Theme.primary : Theme.surfaceContainerHighest

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                x: ReplayState.armed ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                width: 16
                height: 16
                radius: height / 2
                color: ReplayState.armed ? Theme.textOnPrimary : Theme.outline

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ReplayState.toggle()
            }
        }
    }

    // ---------------- Save ----------------
    // Filled, and the only filled button in the panel. Everything else in the
    // dashboard adjusts something that is already happening; this is the one
    // control that produces a file, and it is the reason the buffer is running
    // at all.
    //
    // THE LENGTH IS ON THE BUTTON and no longer in a row of chips above it.
    // That is not a consolation prize for the chips: the number was always the
    // useful half of them -- what this button is about to hand you -- and it
    // is the half that has to be visible at the moment of pressing. What went
    // with the chips is the size in RAM, which was the cost of CHOOSING and
    // belongs where the choosing now happens; ReplayState.cost still computes
    // it and the settings page still shows it.
    Rectangle {
        id: save

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: 42
        radius: 12
        opacity: ReplayState.armed ? 1 : 0.35
        color: {
            if (!ReplayState.armed)
                return Theme.surfaceContainerHighest;
            return saveMouse.containsMouse ? Theme.primary : Qt.alpha(Theme.primary, 0.22);
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        // Pressed state, so the click lands somewhere rather than only in the
        // island a moment later.
        scale: saveMouse.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: Icons.replay
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: saveMouse.containsMouse && ReplayState.armed ? Theme.textOnPrimary : Theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: `Save last ${ReplayState.seconds}s`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: saveMouse.containsMouse && ReplayState.armed ? Theme.textOnPrimary : Theme.textOnSurface
            }
        }

        MouseArea {
            id: saveMouse

            anchors.fill: parent
            enabled: ReplayState.armed
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // The panel goes away with the click. Watching a dashboard while
            // it saves the last thirty seconds -- of a dashboard -- is not
            // what anyone wants the clip to contain, and the island confirms
            // the save on its own, which is where a confirmation belongs.
            onClicked: {
                IslandState.closeDashboard();
                ReplayState.save();
            }
        }
    }
}
