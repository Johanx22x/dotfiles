// CycleRow, as the probe draws it: the label and the value, and two boxes that
// ask for one step in either direction.
//
// IT ASKS FOR A DIRECTION AND NOTHING ELSE. `row.stepped(-1)` and
// `row.stepped(1)`; the list, the wrapping and the new value belong to the card
// and this file could not reach them if it wanted to.
//
// THE ROW LIGHTS UP AND THE ROW DOES NOT ANSWER is genesis's promise and this
// theme keeps the half that matters: the row itself takes no clicks. There is
// no hover here at all, because there is no hover anywhere in this theme.

import QtQuick
import qs
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property CycleRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: back.left
        anchors.verticalCenter: parent.verticalCenter

        text: `${root.row.label}: ${root.row.value}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: back

        anchors.right: forward.left
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        width: 18
        height: 18
        color: "#00ffff"

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.row.stepped(-1)
        }
    }

    Rectangle {
        id: forward

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 18
        height: 18
        color: "#00ffff"

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.row.stepped(1)
        }
    }
}
