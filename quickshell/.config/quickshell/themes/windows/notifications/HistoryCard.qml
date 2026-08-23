// ONE ENTRY IN THE NOTIFICATION CENTRE.
//
// NOT components/NotificationCard.qml, AND THE REASON IS THE DATA. That file
// draws a LIVE notification: it is handed the server's own object, so it can
// dismiss it, expire it, invoke its actions and watch its timer. What the
// notification centre lists is NotificationState.history, which is plain
// objects copied out while the notification was still alive -- because a
// Notification is destroyed the moment it is closed, and a list of them would
// be a list of dangling handles. A history entry has no actions to invoke and
// nothing left to dismiss.
//
// So this is the same card with the live half taken out: no close, no chevron,
// no buttons, no hover, no click. A hover state on a row that does nothing
// when clicked is a promise the row cannot keep.
//
// AND IT IS THE ONE CARD IN THE THEME THAT CAN PRINT A TIME. `entry.time` is
// stamped by NotificationState.record() the moment a notification reaches the
// shell. The live card has no such number -- see the note in
// components/NotificationCard.qml -- which is exactly the split Windows shows:
// a toast carries no timestamp and a card in the notification centre does.
//
// Measured off scratchpad/ref/notifcenter-card-buttons.jpg: the card is
// #252932 on a #1c2029 panel, one step lighter than the panel it sits on, with
// no border; the time sits on its own row above the icon and the text.

import QtQuick
import Quickshell.Widgets
import qs
import qs.themes.windows

Rectangle {
    id: root

    // A PLAIN OBJECT AND NOT A TYPE, because that is what the history holds:
    // appName, summary, body, image, appIcon, critical, silenced, time. See
    // modules/notifications/NotificationState.qml for why they are copies.
    required property var entry

    readonly property int padding: Theme.notificationPadding

    readonly property string picture: root.entry.image !== ""
        ? root.entry.image
        : Icons.resolve(root.entry.appIcon)

    implicitHeight: body.y + body.height + root.padding

    radius: Theme.notificationRadius
    color: Theme.surfaceContainer
    border.width: root.entry.critical ? 1 : 0
    border.color: Theme.critical
    antialiasing: true

    // ---------------- The time ----------------
    Item {
        id: stamp

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding

        height: clock.implicitHeight

        Text {
            id: clock

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: Qt.formatDateTime(new Date(root.entry.time), Config.use24Hour ? "HH:mm" : "h:mm AP")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
        }

        // WHAT THE MUTE SWALLOWED, marked rather than listed separately --
        // NotificationState keeps everything and flags the silenced ones, so
        // "what did I miss while I was muted" is still answerable at a glance.
        // OURS: Windows has no do-not-disturb marker on a card, because
        // Windows does not keep what its Focus session dropped.
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: root.entry.silenced
            text: Icons.bellOff
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.outline
        }
    }

    // ---------------- Icon, summary, body ----------------
    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: stamp.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: Theme.groupSpacing * 2

        implicitHeight: Math.max(art.visible ? art.height : 0, text.height)
        height: body.implicitHeight

        ClippingRectangle {
            id: art

            anchors.left: parent.left
            anchors.top: parent.top

            width: Theme.notificationIconSize
            height: Theme.notificationIconSize

            visible: root.picture !== "" && picture.status === Image.Ready
            color: "transparent"
            radius: Fluent.controlRadius

            Image {
                id: picture

                anchors.fill: parent

                source: root.picture
                sourceSize.width: Theme.notificationIconSize * 2
                sourceSize.height: Theme.notificationIconSize * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Column {
            id: text

            anchors.left: art.visible ? art.right : parent.left
            anchors.leftMargin: art.visible ? Fluent.cardIconGap : 0
            anchors.right: parent.right
            anchors.top: parent.top

            spacing: 0

            Text {
                width: parent.width

                text: root.entry.summary
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.strongWeight
                color: Theme.textOnSurface
                elide: Text.ElideRight
            }

            Text {
                width: parent.width

                visible: root.entry.body !== ""
                text: root.entry.body
                // The daemon answers GetCapabilities with body-markup, so a
                // sender is entitled to have sent some.
                textFormat: Text.StyledText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurfaceVariant
                wrapMode: Text.Wrap
                // Three, and no expander to lift it: there is nothing behind a
                // history entry to open, so a chevron here would be a control
                // that reveals the rest of a string and nothing more.
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
