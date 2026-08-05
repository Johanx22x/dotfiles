// Do not disturb, as a row in the dashboard's control card.
//
// One line and no chevron: unlike Wi-Fi and Bluetooth there is nothing under
// it to open -- the state is the whole of the setting. That is also why it
// sits ABOVE both of them in the column. Those two grow downwards when their
// lists open, and anything below a control that expands is a control that
// moves out from under the pointer.
//
// The state, the persistence and the reasoning about which notifications still
// get through live in modules/notifications/NotificationState.qml. This file is
// only the switch.

import QtQuick
import "root:/"
import "root:/modules/notifications"

Item {
    id: root

    // Same height as the Wi-Fi and Bluetooth headers, so the four controls in
    // this card read as one list rather than as rows of assorted sizes.
    implicitHeight: 34

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        text: NotificationState.dnd ? Icons.bellOff : Icons.bell
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: NotificationState.dnd ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Text {
        anchors.left: glyph.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: count.left
        anchors.rightMargin: Theme.itemSpacing
        anchors.verticalCenter: parent.verticalCenter

        text: "Do not disturb"

        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: Theme.textOnSurface
    }

    // How many have been dropped since it was switched on.
    //
    // A CHIP AND NOT PART OF THE LABEL, which is what it was first: written
    // out as "Do not disturb · 2 silenced" the sentence did not fit the 330px
    // card and elided to "Do not disturb · 2 sile…", so the count was the
    // thing being cut -- the one part of the row that is not already implied
    // by the glyph and the switch. As a chip it has its own width, and the
    // label goes back to always fitting.
    Rectangle {
        id: count

        anchors.right: toggle.left
        anchors.rightMargin: Theme.itemSpacing
        anchors.verticalCenter: parent.verticalCenter

        visible: NotificationState.dnd && NotificationState.unread > 0

        implicitWidth: countLabel.implicitWidth + 14
        implicitHeight: 20
        // Zero when hidden, so the label above gets the space back instead of
        // anchoring against an invisible box.
        width: visible ? implicitWidth : 0

        radius: height / 2
        color: Qt.alpha(Theme.primary, 0.22)

        Text {
            id: countLabel

            anchors.centerIn: parent
            text: `${NotificationState.unread}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Bold
            color: Theme.primary
        }
    }

    // The same switch Wi-Fi and Bluetooth carry, in the same place: three rows
    // that turn something on and off must not need to be read three ways.
    Rectangle {
        id: toggle

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        width: 40
        height: 22
        radius: height / 2
        color: NotificationState.dnd ? Theme.primary : Theme.surfaceContainerHighest

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Rectangle {
            x: NotificationState.dnd ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter

            width: 16
            height: 16
            radius: height / 2
            color: NotificationState.dnd ? Theme.textOnPrimary : Theme.outline

            Behavior on x {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    // The whole row is the target, switch included -- same as the Wi-Fi and
    // Bluetooth rows. Simpler here than there, though: those two need the
    // switch stacked above this area because the row underneath does a
    // different thing (it opens the list), and this row has only one thing to
    // do, so there is nothing for the switch to be protected from.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationState.toggle()
    }
}
