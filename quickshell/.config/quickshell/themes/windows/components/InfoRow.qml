// How genesis draws a reading. The public half -- what the pages write, and
// why this looks like a row and is not one -- is components/InfoRow.qml.
//
// THIS FILE HAS ONE RULE AND IT IS AN ABSENCE: no MouseArea, no HoverHandler,
// no TapHandler, no cursorShape, and no colour that changes because a pointer
// is over it. The facade cannot enforce that -- there is no signal to leave
// unconnected and no property to leave unread -- so it is enforced by being
// written here, and in README.md, and nowhere else. A theme that gives this
// row a hover state has broken the one thing the component is for: telling a
// reading apart from a control at a glance. See components/ActionRow.qml for
// what a reading WITH something to press looks like; it is a different type
// on purpose.
//
// The second line is optional and muted, and the row grows to fit it rather
// than eliding -- an explanation cut off at the width of a sidebar is an
// explanation nobody finishes reading. That growth is what implicitHeight
// below reports back to the facade.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `InfoRow` here is the facade and not
    // this file.
    required property InfoRow row

    // WHAT THE FACADE READS BACK. This is the one component where the number
    // is not a constant: `column` is as tall as the description wraps to, and
    // nothing on the host side can know that. The facade floors this at
    // Theme.groupHeight, which is the same floor the Math.max here applies --
    // stated twice because the two are answering different questions. Here it
    // is "a reading is at least as tall as a row"; there it is "a theme that
    // reported nothing does not collapse the page".
    implicitHeight: Math.max(Theme.groupHeight, column.implicitHeight + 14)

    Text {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.top: column.top
        anchors.topMargin: 1

        visible: root.row.glyph !== ""
        text: root.row.glyph
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
            visible: root.row.label !== ""
            text: root.row.label
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
            visible: root.row.description !== ""
            text: root.row.description
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
