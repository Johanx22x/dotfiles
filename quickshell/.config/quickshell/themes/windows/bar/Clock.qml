// THE CLOCK, WHICH IS TWO LINES AND RIGHT-ALIGNED.
//
// Time above, date below, both at Caption size, both flushed to the right edge
// of the taskbar. That stacking is one of the details that reads as Windows
// immediately, and it is why the taskbar corner is taller than a single line
// of text needs.
//
// IT IS A DOOR AND NOT A READING, which is where this disagrees with genesis's
// clock and with genesis's argument for it. On Windows the clock is what opens
// the notification centre and the calendar, so it takes a hover backplate and
// a click. Genesis's note says a reading should not pretend to be a control;
// true, and this one is not pretending.
//
// A NOTIFICATION COUNT SITS ON IT rather than beside it -- Windows puts the
// unread badge on the clock itself, and there is no separate bell. That is why
// this theme has no bell widget at all.

import Quickshell
import QtQuick
import qs
import qs.modules.notifications
import qs.themes.windows

Item {
    id: root

    readonly property bool hovered: pointer.containsMouse
    readonly property bool held: pointer.pressed

    implicitWidth: column.implicitWidth + Fluent.trayPadding * 2
    implicitHeight: Fluent.trayItemHeight

    // precision: Minutes rather than Seconds, so the clock wakes once a minute
    // instead of sixty times, and the date line changes with it.
    SystemClock {
        id: clock

        enabled: true
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: Fluent.controlRadius
        color: {
            if (root.held)
                return Theme.surface;
            if (root.hovered)
                return Theme.surfaceContainerHigh;
            return "transparent";
        }
    }

    Column {
        id: column

        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, Config.use24Hour ? "HH:mm" : "hh:mm AP")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurface
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, "dd/MM/yyyy")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurface
            horizontalAlignment: Text.AlignRight
        }
    }

    // The unread badge. A filled accent dot with the count in it when there is
    // room for a number, and a bare dot past ninety-nine -- which is what
    // Windows does and what stops the corner growing.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2

        visible: NotificationState.unread > 0
        width: Math.max(height, count.implicitWidth + 6)
        height: Fluent.badgeHeight
        radius: height / 2
        color: Theme.primary

        Text {
            id: count

            anchors.centerIn: parent
            text: NotificationState.unread > 99 ? "99+" : NotificationState.unread
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize - 2
            font.weight: Fluent.strongWeight
            // Black on accent, which is what dark mode does.
            color: Theme.textOnPrimary
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true

        onClicked: root.clicked()
    }

    signal clicked
}
