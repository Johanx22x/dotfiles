// One notification.
//
// Collapsed it is two lines: who sent it and when, then the body cut to a
// single line. The chevron expands it in place to the full body plus the
// actions the sender offered -- the card grows, the stack below slides down,
// and nothing opens a second window.
//
// Clicking the card dismisses it. That is `dismiss()` and not `expire()`:
// dismissing tells the sending application the user closed it deliberately,
// which is what lets apps like Discord stop re-sending the same thing.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "root:/"

Rectangle {
    id: root

    required property Notification notification

    property bool expanded: false

    // How long this card stays up, in MILLISECONDS.
    //
    // expireTimeout is already in milliseconds -- `notify-send -t 2000`
    // arrives here as 2000. An earlier version multiplied it by 1000 "to
    // convert from seconds", which turned every explicit timeout into a
    // little over half an hour. That is why notifications piled up and never
    // left: the only ones that expired were the ones asking for the default.
    //
    // The two special values come from the desktop notification spec:
    //   -1  the sender has no opinion -> ours
    //    0  "never expire"
    //
    // "Never" is NOT honoured. Applications reach for it far too easily
    // (browser notifications especially) and the result is a panel that only
    // grows. Every setting below is bounded at both ends, so even something
    // important eventually clears itself.
    //
    // ONE DEFAULT PER URGENCY, and this is where the file changed its mind.
    // It used to say that critical did not follow the setting, because "how
    // long do I want to read a chat notification" is not an answer to "how
    // long should the recorder's failure stay up". Those are still two
    // different questions -- which is the argument for giving them two
    // different ANSWERS, not for hardcoding one of them. A number written
    // into the source is not an answer to a question nobody can ask; it only
    // makes the question unaskable. So the settings page asks all three and
    // each urgency carries its own number.
    //
    // The old behaviour is what the defaults still are: 10 seconds for low
    // and normal, 30 for critical. Nothing moves until somebody moves it.
    //
    // Anything the spec does not define falls to normal, which is the closest
    // true answer for an urgency this shell has never heard of.
    readonly property int timeoutSeconds: {
        switch (root.notification.urgency) {
        case NotificationUrgency.Low:
            return Config.notificationTimeoutLow;
        case NotificationUrgency.Critical:
            return Config.notificationTimeoutCritical;
        default:
            return Config.notificationTimeout;
        }
    }

    // SECONDS in Config and multiplied HERE -- the one place in the shell
    // that conversion happens, so there is one place to get it wrong. Three
    // settings and still one `* 1000`.
    readonly property int timeout: {
        const asked = root.notification.expireTimeout;
        if (asked > 0)
            return asked;
        return root.timeoutSeconds * 1000;
    }

    readonly property bool critical: root.notification.urgency === NotificationUrgency.Critical

    implicitWidth: Theme.notificationWidth
    implicitHeight: layout.implicitHeight + Theme.groupPadding * 2

    // A box on the panel, not a window of its own: a step up the surface
    // ladder from the panel behind it, and opaque -- the panel already
    // carries the transparency for both.
    radius: Theme.notificationRadius
    color: Theme.surfaceContainer

    // Critical notifications get an outline instead of a different fill:
    // recolouring the whole card would fight the palette, an edge does not.
    border.width: root.critical ? 1 : 0
    border.color: Theme.critical

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    // Expanded means the user is reading it, so the clock stops; collapsing
    // it again starts a fresh one.
    Timer {
        running: !root.expanded
        interval: root.timeout
        onTriggered: root.notification.expire()
    }

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.groupPadding

        spacing: 6

        // ---------------- Header ----------------
        Item {
            width: parent.width
            height: Math.max(icon.height, header.implicitHeight)

            // The sender's icon: its own image if it sent one, otherwise the
            // application icon from the desktop entry.
            Rectangle {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: Theme.notificationIconSize
                height: Theme.notificationIconSize
                radius: height / 2
                color: Theme.surfaceContainerHigh

                Image {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: parent.height - 8

                    source: Icons.resolve(root.notification.image || root.notification.appIcon)
                    visible: status === Image.Ready
                    sourceSize.width: width
                    sourceSize.height: height
                }

                Text {
                    anchors.centerIn: parent
                    // Nothing to show: the bell stands in, so the card never
                    // has a hole where the icon goes.
                    visible: !root.notification.image && !root.notification.appIcon
                    text: Icons.bell
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            Column {
                id: header

                anchors.left: icon.right
                anchors.leftMargin: Theme.itemSpacing
                anchors.right: chevron.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: parent.verticalCenter

                spacing: 2

                Row {
                    spacing: 6

                    Text {
                        text: root.notification.summary || root.notification.appName
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Bold
                        color: Theme.textOnSurface
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, header.width - 60)
                    }

                    Text {
                        text: "•"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.outline
                    }

                    Text {
                        text: "now"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.textOnSurfaceVariant
                    }
                }

                Text {
                    width: header.width
                    text: root.notification.body
                    textFormat: Text.StyledText

                    // Collapsed: one line, cut. Expanded: as many as it needs.
                    maximumLineCount: root.expanded ? 0 : 1
                    wrapMode: root.expanded ? Text.Wrap : Text.NoWrap
                    elide: root.expanded ? Text.ElideNone : Text.ElideRight

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            // Expand / collapse.
            Text {
                id: chevron

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: "⌄"
                rotation: root.expanded ? 180 : 0
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.textOnSurfaceVariant

                Behavior on rotation {
                    NumberAnimation { duration: Theme.animDuration }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }
        }

        // ---------------- Actions ----------------
        // Only while expanded: collapsed cards stay two lines tall whatever
        // the sender attached to them.
        Row {
            visible: root.expanded && root.notification.actions.length > 0
            spacing: Theme.itemSpacing

            Repeater {
                model: root.notification.actions

                Rectangle {
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + Theme.groupPadding * 2
                    implicitHeight: Theme.groupHeight
                    radius: Theme.groupRadius
                    color: actionMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: parent.modelData.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                        color: actionMouse.containsMouse ? Theme.textOnPrimary : Theme.textOnSurface
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.invoke()
                    }
                }
            }
        }
    }

    // Click anywhere else on the card to dismiss. Declared last so the
    // chevron and the action buttons win the click where they overlap.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.notification.dismiss()
    }
}
