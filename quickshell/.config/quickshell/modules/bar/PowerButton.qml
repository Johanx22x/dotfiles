// Power options. The last thing on the bar, and the only control on it that
// can end the session. It shares a pill with the settings button -- the two
// are the shell's own controls -- but keeps a full Theme.groupSpacing from it
// rather than the tight itemSpacing a group normally uses: nothing should be
// one slipped click away from this, background or no background.
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

    // Matches SettingsButton beside it; the note on the size lives there.
    readonly property int discSize: Theme.groupHeight - 6

    implicitWidth: discSize
    implicitHeight: Theme.groupHeight

    Rectangle {
        anchors.centerIn: parent

        width: root.discSize
        height: root.discSize
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
        // Theme.controlSize, matching SettingsButton; the note on the change
        // lives there. It was logoSize while this was a lone glyph on the
        // bare bar, where it needed the weight to read as a control.
        font.pointSize: Theme.controlSize
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
