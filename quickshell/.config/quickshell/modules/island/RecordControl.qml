// Start a screen recording, and choose what to record.
//
// Three buttons and not a button plus a dialog: the target IS the choice, so
// asking it as a second step would be a dialog whose only content is what
// these three already say. While a recording is running the same row collapses
// to one stop button -- there is nothing else to decide at that point.
//
// The state, the command and the reasoning about SIGINT live in
// modules/recorder/RecorderState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    implicitHeight: label.height + 8 + 56

    Text {
        id: label

        anchors.left: parent.left
        anchors.top: parent.top

        text: RecorderState.recording ? "Recording" : "Record screen"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: RecorderState.recording ? Theme.critical : Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- Idle: pick a target ----------------
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        spacing: 6
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

                // Exact thirds of the full width, so the three of them span
                // the card edge to edge with no remainder left over.
                width: (root.width - 12) / 3
                height: 56
                // Squared off rather than a pill: a pill reads as a chip you
                // might dismiss, and these are the primary action of the card.
                radius: 10
                color: optionMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHighest

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                // Glyph over label, not beside it: side by side the three
                // buttons were mostly text and the widths depended on the
                // words. Stacked, the button is a square with a picture in it
                // and the label is a caption.
                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: option.modelData.glyph
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize + 2
                        color: optionMouse.containsMouse ? Theme.textOnPrimary : Theme.textOnSurface
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: option.modelData.label
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 2
                        font.weight: Theme.fontWeight
                        color: optionMouse.containsMouse ? Theme.textOnPrimary : Theme.textOnSurfaceVariant
                    }
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // The panel has to go BEFORE the selection tool appears:
                    // the dashboard is held open by a focus grab, and slurp
                    // cannot take a click while that grab is live.
                    //
                    // The delay is for the grab to actually be released --
                    // closing is a request to the compositor, not an
                    // instantaneous fact, and slurp launched in the same tick
                    // came up unusable.
                    // The panel has to go BEFORE the selection tool appears:
                    // the dashboard is held open by a focus grab, and slurp
                    // cannot take a click while that grab is live.
                    //
                    // The waiting is done by RecorderState and not here: this
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: 56
        radius: 10
        visible: RecorderState.recording
        color: stopMouse.containsMouse ? Theme.critical : Theme.surfaceContainerHighest

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.stop
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: stopMouse.containsMouse ? Theme.textOnCritical : Theme.critical
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop and save"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Theme.fontWeight
                color: stopMouse.containsMouse ? Theme.textOnCritical : Theme.textOnSurface
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
