// One entry in the settings window's navigation rail.
//
// Selected state is a FILLED PILL, not an accent bar or bold text: the rail
// sits on the same glass as the content beside it, and a mark that only
// colours the label is easy to lose over a wallpaper. The pill also matches
// what the rest of this shell already does to say "this one" -- the active
// workspace on the bar is the same shape.
//
// Selected and hovered are deliberately different tones rather than different
// intensities of one, so that hovering a selected entry does not read as
// having deselected it.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property bool selected: false

    signal clicked

    // The rail gives the width; see the note at the top of ToggleRow.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 150
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius

    color: root.selected ? Theme.primaryContainer
        : mouse.containsMouse ? Theme.surfaceContainerHigh
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            // Elide rather than let a long name push the glyph out of the
            // pill: the rail has a fixed width and a section added later
            // should not be able to change the window's proportions.
            width: parent.width - parent.spacing - Theme.iconSize * 1.6
            elide: Text.ElideRight
            color: root.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
