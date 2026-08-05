// A row that explains something and offers to do it: the reading of an
// InfoRow with a button on the end.
//
// WHY NOT JUST MAKE InfoRow CLICKABLE. Because then every reading in the
// window becomes a thing you have to test with the pointer to find out
// whether it does anything. InfoRow's whole contract is that it does not
// respond -- no hover, no cursor -- and the moment one of them does, that
// promise is gone for all of them. The button here is the target, and it
// looks like one.
//
// The action is a WORD and not a glyph. A pencil, a folder and an ellipsis
// all mean "choose a file" to somebody, and none of them means it to
// everybody; at the two or three of these a page carries, the width is
// affordable.

import QtQuick
import "root:/"

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string description: ""

    property string actionText: ""
    property string actionGlyph: ""
    // Off while the action is running, so a second click cannot start a
    // second copy of it.
    property bool actionEnabled: true

    signal triggered

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
        anchors.right: action.left
        anchors.rightMargin: Theme.itemSpacing
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

    Rectangle {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: actionRow.implicitWidth + Theme.groupPadding * 2
        implicitHeight: Theme.groupHeight - 8
        radius: height / 2

        color: !root.actionEnabled ? "transparent"
            : actionMouse.containsMouse ? Theme.surfaceContainerHigh
            : "transparent"

        border.width: 1
        border.color: Theme.outlineVariant

        opacity: root.actionEnabled ? 1 : 0.4

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            id: actionRow

            anchors.centerIn: parent
            spacing: Theme.itemSpacing - 3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionGlyph !== ""
                text: root.actionGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 1
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.actionText
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Theme.fontWeight
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.actionEnabled
            onClicked: root.triggered()
        }
    }
}
