// ActionRow, as the probe draws it: a magenta bar with the label on the left
// and a cyan box on the right that is the only thing you can press.
//
// Rule 7, from components/ActionRow.qml: this type exists so that a reading
// WITH something to press is a different type from InfoRow. The press target
// is the action box and the rest of the row is dead.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property ActionRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        color: "#ffff00"
        font.family: Theme.fontFamily
    }

    Rectangle {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 60
        height: 16
        color: "#00ffff"

        Text {
            anchors.centerIn: parent
            text: root.row.actionText
            color: "#000000"
            font.family: Theme.fontFamily
        }

        MouseArea {
            anchors.fill: parent
            // Rule 6: against this item's own `enabled`, not row.enabled.
            enabled: root.enabled && root.row.actionEnabled
            onClicked: root.row.triggered()
        }
    }
}
