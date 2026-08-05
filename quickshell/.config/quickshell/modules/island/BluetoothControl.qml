// Bluetooth: the radio, and the devices worth one click.
//
// Through Quickshell's BlueZ backend, so no bluetoothctl being spawned and no
// polling.
//
// Only PAIRED devices are listed. Discovery is a different job with a
// different rhythm -- it needs the adapter scanning, it fills with strangers'
// headphones, and pairing asks questions. The panel answers "reconnect my
// headset", which is what is actually wanted from a bar; blueman is one row
// away for the rest.

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "root:/"

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: root.adapter?.enabled ?? false

    readonly property var devices: {
        const all = Bluetooth.devices?.values ?? [];
        // Connected first, then the rest by name: the one to click is at the
        // top whether you are connecting or disconnecting.
        return all.filter(d => d.paired).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return (a.name ?? "").localeCompare(b.name ?? "");
        });
    }

    // Collapsed by default with a ceiling on the expanded list, for the same
    // reason as WifiControl: a row that changes height with how many devices
    // happen to be paired is not a row anything can be laid out against.
    property bool expanded: false

    readonly property int listCeiling: 96

    implicitHeight: header.height + (root.expanded ? root.listCeiling : 0) + 4

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: 34

        Text {
            id: btGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.bluetooth
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.enabled ? Theme.primary : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.left: btGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: btToggle.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            text: root.enabled ? "Bluetooth" : "Bluetooth off"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurface
        }

        // The radio switch. It stays on the header rather than inside the
        // expanded list: it is the one control here that changes everything
        // below it, and it has to be reachable without opening anything.
        Rectangle {
            id: btToggle

            anchors.right: btChevron.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            width: 40
            height: 22
            radius: height / 2
            color: root.enabled ? Theme.primary : Theme.surfaceContainerHighest

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                x: root.enabled ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                width: 16
                height: 16
                radius: height / 2
                color: root.enabled ? Theme.textOnPrimary : Theme.outline

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.adapter)
                        root.adapter.enabled = !root.adapter.enabled;
                }
            }
        }

        Text {
            id: btChevron

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.chevronRight
            rotation: root.expanded ? 90 : 0
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.outline

            Behavior on rotation {
                NumberAnimation { duration: Theme.animDuration }
            }
        }

        // The whole row expands, chevron included: that arrow is what the row
        // looks like it is offering, so it has to be the one thing that is
        // certain to work. Below the switch in stacking, so reaching for the
        // toggle still never opens the list by accident.
        MouseArea {
            anchors.fill: parent
            z: -1

            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 4

        height: root.expanded ? root.listCeiling : 0
        visible: height > 0
        clip: true
        spacing: 1

        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        model: root.enabled ? root.devices : []

        delegate: Rectangle {
                id: entry

                required property var modelData

                width: list.width
                height: 26
                radius: height / 2

                color: entryMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: state.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    text: entry.modelData.name ?? entry.modelData.deviceName ?? entry.modelData.address
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    color: entry.modelData.connected ? Theme.primary : Theme.textOnSurfaceVariant
                }

                Text {
                    id: state

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    // The battery when the device reports one: for headphones
                    // that is the single most useful number about them, and it
                    // is only known once connected.
                    text: {
                        if (entry.modelData.connected && entry.modelData.batteryAvailable)
                            return `${Math.round(entry.modelData.battery * 100)}%`;
                        return entry.modelData.connected ? "connected" : "connect";
                    }

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 2
                    color: Theme.outline
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (entry.modelData.connected)
                            entry.modelData.disconnect();
                        else
                            entry.modelData.connect();
                    }
                }
            }
        }

}
