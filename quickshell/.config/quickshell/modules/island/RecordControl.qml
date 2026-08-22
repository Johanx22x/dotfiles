// Start a screen recording, and choose what to record.
//
// Three buttons and not a button plus a dialog: the target IS the choice, so
// asking it as a second step would be a dialog whose only content is what
// these three already say. While a recording is running the same row collapses
// to one stop button -- there is nothing else to decide at that point.
//
// THEY WERE 56-PIXEL TILES with the glyph stacked over the label, which was
// the right shape while this had a card of its own to fill. It shares one
// strip with the instant replay now (see the actions row in Dashboard.qml), so
// the tiles are rows: the same glyph and the same word, side by side, at the
// height of everything else on that line. Nothing about what they do changed.
//
// THE COLOURS COME FROM THE CALLER. This is drawn on a photograph now, and a
// Theme role is derived from the WALLPAPER, which is not what is behind it.
// The defaults are the roles that used to be read here, so the component still
// works anywhere else.
//
// The state, the command and the reasoning about SIGINT live in
// modules/recorder/RecorderState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    property color ink: Theme.textOnSurface
    property color inkMuted: Theme.textOnSurfaceVariant
    property color wash: Theme.surfaceContainerHighest
    property color danger: Theme.critical

    implicitWidth: RecorderState.recording ? stop.implicitWidth : targets.implicitWidth
    implicitHeight: 34

    // ---------------- Idle: pick a target ----------------
    Row {
        id: targets

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        spacing: 2
        visible: !RecorderState.recording

        Repeater {
            model: [
                {
                    id: "display",
                    glyph: Icons.display,
                    label: "Display"
                },
                {
                    id: "window",
                    glyph: Icons.window,
                    label: "Window"
                },
                {
                    id: "region",
                    glyph: Icons.region,
                    label: "Region"
                }
            ]

            Rectangle {
                id: option

                required property var modelData

                implicitWidth: content.implicitWidth + 22
                implicitHeight: 34
                radius: 10

                color: optionMouse.containsMouse ? root.wash : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.glyph
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: optionMouse.containsMouse ? root.ink : root.inkMuted
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.label
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize * 0.85
                        font.weight: Theme.fontWeight
                        color: root.ink
                    }
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // The panel has to go BEFORE the selection tool appears:
                    // the dashboard is held open by a focus grab, and slurp
                    // cannot take a click while that grab is live. The waiting
                    // is done by RecorderState and not here, because this
                    // component is destroyed by the very close it just asked
                    // for. See the note on startDelayed.
                    onClicked: {
                        IslandState.closeDashboard();
                        RecorderState.startDelayed(option.modelData.id);
                    }
                }
            }
        }
    }

    // ---------------- Recording: one way out ----------------
    Rectangle {
        id: stop

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: stopRow.implicitWidth + 24
        implicitHeight: 34
        radius: 10

        visible: RecorderState.recording
        color: stopMouse.containsMouse ? root.danger : Qt.alpha(root.danger, 0.25)

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            id: stopRow

            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.stop
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: root.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop and save"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize * 0.85
                font.weight: Font.Bold
                color: root.ink
            }
        }

        MouseArea {
            id: stopMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: RecorderState.stop()
        }
    }
}
