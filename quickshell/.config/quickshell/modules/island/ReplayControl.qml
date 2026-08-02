// Instant replay: the switch, how much it keeps, and the button that keeps it.
//
// It lives in the same column as the recorder rather than under the Wi-Fi and
// Bluetooth rows, and that move fixed a real problem: those two expand into
// lists, and everything below them was pushed off the bottom of the card when
// they did. Things that grow and things that must stay put do not share a
// column.
//
// The header reads like the Wi-Fi and Bluetooth ones -- glyph, name, switch --
// because it is the same kind of thing: a background service that is either on
// or off. What follows is what makes it different: a buffer has a LENGTH, and
// that length is the only real decision here, so it is four chips rather than
// a menu.
//
// The size in RAM is on screen next to them because it is the entire cost of
// the choice, and it is not knowable from anywhere else -- a buffer is exactly
// its bitrate times its duration.
//
// The state, the process and the persisted duration live in
// modules/recorder/ReplayState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    implicitHeight: header.height + 10 + chips.height + 12 + 42

    // ---------------- Header: what it is, and the switch ----------------
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

        Text {
            anchors.left: glyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: toggle.left
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

    // ---------------- How much it keeps ----------------
    Item {
        id: chips

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 10

        height: 26

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            spacing: 5

            Repeater {
                model: ReplayState.options

                Rectangle {
                    id: chip

                    required property int modelData

                    readonly property bool current: ReplayState.seconds === chip.modelData

                    width: 38
                    height: 24
                    radius: 7
                    color: {
                        if (chip.current)
                            return Theme.primary;
                        return chipMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent";
                    }

                    border.width: chip.current ? 0 : 1
                    border.color: Theme.outlineVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        anchors.centerIn: parent

                        text: `${chip.modelData}s`
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 3
                        font.weight: chip.current ? Font.Bold : Theme.fontWeight
                        color: chip.current ? Theme.textOnPrimary : Theme.textOnSurfaceVariant
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ReplayState.setSeconds(chip.modelData)
                    }
                }
            }
        }

        // The price of the chip on the left of it. A buffer is its bitrate
        // times its duration and nothing else, so this is the whole cost.
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: `${ReplayState.megabytes} MB`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            color: Theme.outline
        }
    }

    // ---------------- Save ----------------
    // Filled, and the only filled button in the panel. Everything else here
    // adjusts something that is already happening; this is the one control
    // that produces a file, and it is the reason the buffer is running at all.
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

            // The panel goes away with the click. Watching a dashboard while it
            // saves the last thirty seconds -- of a dashboard -- is not what
            // anyone wants the clip to contain, and the island confirms the
            // save on its own, which is where a confirmation belongs.
            onClicked: {
                IslandState.closeDashboard();
                ReplayState.save();
            }
        }
    }
}
