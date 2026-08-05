// A row that says something instead of doing something: a fact, a limit, or
// a place to go and do the thing this window will not.
//
// IT LOOKS LIKE A ROW AND IT IS NOT ONE, which is the whole difficulty. The
// cheapest way to tell a reading from a control is that a control lights up
// under the pointer and this does not -- no hover, no cursor change, nothing
// to click. Anything that reads like a switch and answers to nothing is worse
// than plain text.
//
// The second line is optional and muted. When it is there the row grows to
// fit it rather than eliding: an explanation cut off at the width of a
// sidebar is an explanation nobody finishes reading.

import QtQuick
import "root:/"

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string description: ""

    width: parent ? parent.width : implicitWidth
    implicitWidth: 320
    implicitHeight: Math.max(Theme.groupHeight, column.implicitHeight + 14)

    Text {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.top: column.top
        anchors.topMargin: 1

        visible: root.glyph !== ""
        text: root.glyph
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Column {
        id: column

        anchors.left: mark.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: 3

        Text {
            width: parent.width
            visible: root.label !== ""
            text: root.label
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
