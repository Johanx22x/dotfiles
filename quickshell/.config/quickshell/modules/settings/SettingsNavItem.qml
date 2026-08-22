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

        // THE RAIL IS INSIDE A LIST THAT CAN BE DRAGGED, and a Flickable that
        // is moving takes the next press away from whatever is under it, so
        // that the press carries on the gesture instead of landing on the row
        // that happened to slide there. That is right for a finger. Here it
        // means the first click after dragging the rail is thrown away, and
        // the only two entries anybody drags to are the two below the fold --
        // which is how a scrolling problem got reported as "Updates does not
        // open".
        //
        // preventStealing is the documented way to refuse that: it holds
        // keepMouseGrab from the moment it is set, and QQuickFlickable's
        // filter checks that flag before it ever consults its own moving
        // state. Measured on the rail at 0, 100, 300 and 600 ms after a drag
        // and after a flick: the click lands at all four, where before it
        // landed only at 600.
        //
        // WHAT IT COSTS is dragging the rail. A row that keeps its own grab
        // never hands it to the Flickable, so pulling the list by an entry no
        // longer scrolls it -- the wheel and the scrollbar beside it still
        // do, which is every way a mouse actually moves this list. NOT
        // `interactive: false` on the list itself, which looks like the same
        // trade and is not: that switch also turns off the Flickable's own
        // wheel handling, which is the net under ScrollList's handler, and
        // taking it away stopped the whole settings window scrolling.
        preventStealing: true

        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
