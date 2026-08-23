// MenuRow, as the probe draws it: one line of text in a flat rectangle.
//
// It reports implicitWidth as well as implicitHeight, which rule 2 allows here
// for the same reason it allows it in genesis: the Column a menu row sits in
// has no width of its own, so the width has to come from the row and there is
// nothing above it whose size depends on this one.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property MenuRow row

    implicitWidth: label.implicitWidth + Theme.groupPadding * 2
    implicitHeight: 22
    color: root.row.checked ? "#00ffff" : "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        id: label

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        color: "#000000"
        font.family: Theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.row.activated()
    }
}
