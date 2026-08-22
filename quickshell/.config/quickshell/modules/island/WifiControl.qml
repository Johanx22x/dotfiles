// NOTHING INSTANTIATES THIS FILE ANY MORE, and that is the state it was left
// in rather than an oversight. It was a row in the dashboard's control card
// until the dashboard became one view; it came out because
// modules/settings/pages/NetworkPage.qml does the same job better -- saved
// networks, forgetting one, the enterprise cases -- and a truncated second
// copy of a better screen was not worth the panel's tallest card.
//
// It is kept, not deleted, for one reason: NetworkPage is written AGAINST it.
// Three comments there, including the page's own header, explain what that
// page does by saying what this file deliberately refuses to do, and deleting
// the file would leave those arguments pointing at nothing. Delete both
// together, or neither.
//
// Wi-Fi: what we are on, and what else is in range.
//
// Through Quickshell's NetworkManager backend, so there is no nmcli being
// spawned to read state and no polling: the list and the connection status
// come off NetworkManager's own signals.
//
// It is deliberately NOT a full network manager. Connecting to a network the
// machine already knows is one click; a network it does not know needs a
// password, and a password field belongs in nm-connection-editor rather than
// in a panel that hangs off the bar. Unknown networks are shown and open the
// editor, which is honest about where that job lives.

import Quickshell
import Quickshell.Networking
import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var active: root.device?.networks?.values?.find(n => n.connected) ?? null

    // Everything in range, connected one first and known ones next: the two
    // things worth clicking are at the top.
    readonly property var networks: {
        const all = root.device?.networks?.values ?? [];
        return all.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return (a.name ?? "").localeCompare(b.name ?? "");
        });
    }

    // Collapsed by default, and the expanded list has a CEILING.
    //
    // The list used to hang open underneath: fine with two networks in range
    // and a mess with fifteen, because the card grew by however many the air
    // happened to be carrying. A row that changes height with the weather is
    // not a row you can lay anything out against.
    property bool expanded: false

    readonly property int listCeiling: 96

    implicitHeight: header.height + (root.expanded ? root.listCeiling : 0) + 4

    // Scanning costs power and only makes sense while the list is on screen,
    // so it is turned on with the panel rather than left running.
    onVisibleChanged: {
        if (root.device)
            root.device.scannerEnabled = visible;
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: 34

        Text {
            id: wifiGlyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: root.active ? Icons.wifi : Icons.wifiOff
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.active ? Theme.primary : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.left: wifiGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: wifiToggle.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!Networking.wifiEnabled)
                    return "Wi-Fi off";
                return root.active?.name ?? "Not connected";
            }

            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurface
        }

        // The radio switch, same shape and same place as bluetooth's: the two
        // rows do the same job and must not need to be read differently.
        //
        // Networking.wifiEnabled is NetworkManager's own soft switch, so this
        // is the same thing `nmcli radio wifi off` does -- no process, and the
        // state comes back over the same signals as everything else.
        // wifiHardwareEnabled is the physical kill switch: when that is off,
        // the soft one cannot be turned on, so the control says so instead of
        // accepting a click that would do nothing.
        Rectangle {
            id: wifiToggle

            anchors.right: wifiChevron.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            width: 40
            height: 22
            radius: height / 2
            opacity: Networking.wifiHardwareEnabled ? 1 : 0.4
            color: Networking.wifiEnabled ? Theme.primary : Theme.surfaceContainerHighest

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                width: 16
                height: 16
                radius: height / 2
                color: Networking.wifiEnabled ? Theme.textOnPrimary : Theme.outline

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Networking.wifiHardwareEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Text {
            id: wifiChevron

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

        // Everything in range, but inside a fixed box: it scrolls rather than
        // pushing the card around.
        height: root.expanded ? root.listCeiling : 0

        // `visible: height > 0` is safe here for a plainer reason than the
        // one in ScrollList's header: this height is a bool, so nothing the
        // hiding does to any parent can feed back into it at all. Driven
        // anyway, since nothing instantiates this file -- expanded, collapsed
        // and expanded again in a throwaway window, back at 96 both times.
        visible: height > 0
        clip: true
        spacing: 1

        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        model: Networking.wifiEnabled ? root.networks : []

        // Three and a half rows of however many are in the air, and until this
        // was drawn the card said nothing about the difference: the sort puts
        // the connected and the known ones at the top, which is what let a list
        // that ends mid-row pass for the whole list.
        //
        // PLACED AND NOT ANCHORED, and against the right edge rather than a few
        // pixels in. A child of a Flickable rides its contents, so `y` gives
        // back exactly what the scroll took; and the rows already keep ten
        // pixels between the state word and the edge, which is the clear space
        // this borrows four of rather than spending it twice.
        ScrollBar {
            view: list

            x: list.width - width
            y: list.contentY
            height: list.height
        }

        delegate: Item {

            id: entryHolder

            required property int index
            required property var modelData

            width: list.width
            height: 26

            Rectangle {
                id: entry

                readonly property var modelData: entryHolder.modelData

                anchors.fill: parent
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

                    text: entry.modelData.name
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

                    // Says what a click will do, rather than repeating what
                    // the row already shows.
                    text: {
                        if (entry.modelData.connected)
                            return "connected";
                        if (entry.modelData.stateChanging)
                            return "…";
                        return entry.modelData.known ? "connect" : "set up";
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
                        if (entry.modelData.connected) {
                            entry.modelData.disconnect();
                            return;
                        }

                        if (entry.modelData.known) {
                            entry.modelData.connect();
                            return;
                        }

                        // Unknown: it needs a password, and that is a form.
                        Quickshell.execDetached(["nm-connection-editor"]);
                    }
                }
            }
        }
    }
}
