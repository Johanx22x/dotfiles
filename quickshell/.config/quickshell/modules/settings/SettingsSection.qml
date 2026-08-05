// A titled group of settings rows: a heading, then a card holding the rows.
//
// The heading sits OUTSIDE the card rather than inside it. Inside, it would
// be the first row of a list of rows and would have to be styled hard enough
// not to be read as one; outside, the indent alone does the work and the card
// stays a list of like things.

import QtQuick
import "root:/"

Column {
    id: root

    property string glyph: ""
    property string title: ""

    // Rows written between this component's braces land in the card below,
    // not next to the heading.
    default property alias content: rows.data

    spacing: Theme.itemSpacing

    Row {
        x: Theme.groupPadding
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // The accent is the heading's, and it is the only place it is
            // spoken for in this window: the rows below stay neutral so the
            // eye finds the section breaks first.
            color: Theme.primary

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.primary

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    Rectangle {
        width: root.width
        implicitHeight: rows.implicitHeight + Theme.itemSpacing * 2

        radius: Theme.cardRadius
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Column {
            id: rows

            // An explicit width, because the rows inside take theirs from
            // this column -- see the note at the top of ToggleRow.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Enough to keep the pill of a hovered row off the rounded corner
            // of the card behind it.
            anchors.margins: 4
            spacing: 2
        }
    }
}
