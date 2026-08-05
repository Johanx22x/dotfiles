// Opens the settings window. Shares a pill with the power button at the right
// end of the bar: the two are the shell's own controls rather than readings,
// and one background around the pair says so.
//
// NEXT TO POWER, WITH A FULL Theme.groupSpacing BETWEEN THEM. PowerButton's
// own note says nothing should be one slipped click away from it, and sharing
// a background does not change that -- the group carries the wider gap rather
// than the tight itemSpacing used inside every other one.
//
// Hover speaks in primary, the ordinary "this opens something" colour, which
// is the other half of what makes the red on the power button mean anything.

import QtQuick
import "root:/"
import "root:/modules/settings"

Item {
    id: root

    // The hover disc, matching PowerButton beside it. Smaller than the pill
    // that now holds both, the way the workspace dots are smaller than
    // theirs: a disc as tall as its own group reads as a second background
    // rather than as a target inside one.
    //
    // Six under the pill and not ten: at ten it cleared a controlSize glyph by
    // barely two pixels, and a hover that hugs its own glyph reads as a badge
    // stuck to it rather than as a target it sits inside.
    readonly property int discSize: Theme.groupHeight - 6

    implicitWidth: discSize
    implicitHeight: Theme.groupHeight

    Rectangle {
        anchors.centerIn: parent

        width: root.discSize
        height: root.discSize
        radius: height / 2
        color: mouse.containsMouse ? Qt.alpha(Theme.primary, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Icons.settings
        font.family: Theme.fontFamily
        // Theme.controlSize, matching PowerButton beside it. It was logoSize
        // while these were lone glyphs on the bare bar and needed the weight
        // to read as controls at all; inside a pill part of that job is done
        // by the background, but only part -- see the note on the property.
        font.pointSize: Theme.controlSize
        color: mouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Toggle and not open, same as the power button: clicking the button
        // that opened the window should put it away again.
        onClicked: SettingsState.toggle()
    }
}
