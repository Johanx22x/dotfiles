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
// or off. What follows is what makes it different: a buffer has a LENGTH and a
// SUBJECT, and those are the two real decisions here, so they are two rows of
// chips rather than a menu.
//
// The size in RAM is on screen next to the lengths because it is the entire
// cost of that choice, and it is not knowable from anywhere else -- a buffer is
// exactly its bitrate times its duration. The connector name is next to the
// screens for the opposite reason: it is knowable, from `hyprctl monitors`, and
// nobody was going to go and look. See the section on that row.
//
// The state, the process and the persisted duration live in
// modules/recorder/ReplayState.qml.

import QtQuick
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    implicitHeight: header.height + 10 + chips.height
        + (screens.visible ? 8 + screens.height : 0) + 12 + 42

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

    // ---------------- Which screen it keeps ----------------
    //
    // THIS ROW IS HERE BECAUSE ITS ABSENCE COST A CLIP. The buffer used to
    // follow the shell's monitor with nothing on screen saying which one that
    // was, and it spent a long time holding the side panel: the switch said
    // "Instant replay", the button said "Save last 30s", and both were telling
    // the truth about the wrong screen. A capture with no visible subject is
    // the one setting you cannot check by looking at the thing it produces --
    // by then the thing it produces is the evidence.
    //
    // Chips and not a dropdown, for the reason the lengths above are chips:
    // the alternatives ARE the information here, and there are two of them.
    //
    // A MONITOR AND NOTHING ELSE. There is no "Auto" chip, deliberately: the
    // whole failure this row exists to end was an automatic answer nobody had
    // given and nobody could see, and offering it back as an option would be
    // offering the failure back. One screen is filled, always, and it is the
    // screen being recorded.
    //
    // WHICH IS NOT THE SAME AS SAYING THE SETTING IS NEVER EMPTY. A machine
    // that has never touched this row -- a fresh clone, the first boot after
    // pulling it -- has no choice stored, and the buffer still has to record
    // something: it falls to the shell's own monitor, exactly as it did before
    // any of this existed. What that resolves to is what is filled below, so
    // the row is never blank and never lying, and the first click on it turns
    // the inherited answer into a given one. See ReplayState.screen.
    //
    // Hidden with one monitor, where a choice between one thing is not a choice.
    Item {
        id: screens

        visible: Screens.all.length > 1

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: chips.bottom
        anchors.topMargin: 8

        height: 26

        readonly property var options: Screens.all.map(screen => ({
            key: Config.screenKey(screen),
            connector: screen.name,
            // The model -- "PG32QF2B" -- because that is the monitor as it is
            // sold and as it is labelled on the box. Falls back to the
            // connector for the virtual outputs that report no model, which is
            // the same fallback screenKey makes.
            label: screen.model || screen.name
        }))

        // The connector, which is a second fact and not a repeat of the filled
        // chip: the chip is a monitor as a person names it, this is the string
        // gpu-screen-recorder was handed. They disagree in exactly one case --
        // a chosen monitor that is not plugged in -- and that is the case worth
        // being able to see.
        Text {
            id: connector

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: ReplayState.monitor === "" ? "no screen" : ReplayState.monitor
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            // Amber when the chosen monitor is not plugged in: the buffer is
            // running, it is simply not running where it was told to. That is a
            // state that ends when the screen comes back, not an error.
            color: ReplayState.monitorMissing ? Theme.warning : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Row {
            id: screenRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            spacing: 5

            // EQUAL SHARES OF WHAT IS LEFT, rather than a width per chip: a
            // third monitor should make the chips narrower, not push one off
            // the card. Measured against the connector text, whose width comes
            // from its own string and not from this row -- so there is no loop.
            readonly property real slot: (screens.width - connector.width - Theme.itemSpacing
                - screenRow.spacing * (screens.options.length - 1)) / screens.options.length

            Repeater {
                model: screens.options

                Rectangle {
                    id: screenChip

                    required property var modelData

                    // Filled when it is the screen being recorded, which is the
                    // stored choice when there is one and the resolved screen
                    // when there is not. Comparing only against the stored key
                    // would leave every chip hollow on a machine that has never
                    // picked -- a row of options with the answer missing, about
                    // a recorder that is running right now.
                    readonly property bool current: Config.replayMonitor === ""
                        ? ReplayState.monitor === screenChip.modelData.connector
                        : Config.replayMonitor === screenChip.modelData.key

                    width: Math.max(0, screenRow.slot)
                    height: 24
                    radius: 7
                    color: {
                        if (screenChip.current)
                            return Theme.primary;
                        return screenMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent";
                    }

                    border.width: screenChip.current ? 0 : 1
                    border.color: Theme.outlineVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight

                        text: screenChip.modelData.label
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 3
                        font.weight: screenChip.current ? Font.Bold : Theme.fontWeight
                        color: screenChip.current ? Theme.textOnPrimary : Theme.textOnSurfaceVariant
                    }

                    MouseArea {
                        id: screenMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Costs the seconds the buffer is holding, exactly like
                        // changing the length does: -w is a command-line flag,
                        // so the recorder comes back. ReplayState.setMonitor is
                        // where that is arranged.
                        onClicked: ReplayState.setMonitor(screenChip.modelData.key)
                    }
                }
            }
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
