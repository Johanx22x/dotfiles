// StepperRow, as the probe draws it: the label, the number as the facade would
// have it read, and two boxes that ask for one step in either direction.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property StepperRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: down.left
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.display !== ""
            ? `${root.row.label}: ${root.row.display}`
            : `${root.row.label}: ${root.row.value}${root.row.suffix}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: down

        anchors.right: up.left
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        width: 18
        height: 18
        color: "#00ffff"

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled && root.row.value > root.row.from
            onClicked: root.row.nudge(-root.row.step)
        }
    }

    Rectangle {
        id: up

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 18
        height: 18
        color: "#00ffff"

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled && root.row.value < root.row.to
            onClicked: root.row.nudge(root.row.step)
        }
    }
}
