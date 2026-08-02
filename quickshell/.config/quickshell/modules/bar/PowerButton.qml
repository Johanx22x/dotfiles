// Power options. The last thing on the bar, and the only control on it that
// can end the session -- which is why it sits alone at the far edge instead
// of inside a group: nothing should be one slipped click away from it.
//
// It used to live under the Arch logo at the opposite corner. Moving it here
// costs nothing and buys two things: the logo goes back to being decoration,
// and the destructive action stops hiding behind a brand mark.
//
// Hover speaks in Theme.critical rather than the usual primary. Every other
// hover on this bar promises "this opens something"; this one has to promise
// something else, and colour is the cheapest way to say it before the click.

import QtQuick
import "root:/"
import "root:/modules/powermenu"

Item {
    id: root

    implicitWidth: Theme.groupHeight
    implicitHeight: Theme.groupHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.containsMouse ? Qt.alpha(Theme.critical, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Icons.power
        font.family: Theme.fontFamily
        // Theme.logoSize, not Theme.iconSize: this is not an icon inside a
        // group, it is a lone glyph sitting on the bare bar, and at the icon
        // size it read as a leftover rather than a control. It ends up the
        // same size as the Arch logo at the opposite corner, which is right --
        // the two of them bookend the bar.
        font.pointSize: Theme.logoSize
        color: mouse.containsMouse ? Theme.critical : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // The shell's own menu now, not the wofi script. Toggle and not open:
        // clicking the button that opened it should put it away again.
        onClicked: PowerMenuState.toggle()
    }
}
