// NotificationCard, as the probe draws it: a red rectangle for a critical
// notification and a magenta one for everything else.
//
// Rule 7, and it is the sharpest one in this file: THE WHOLE CARD IS THE
// TARGET AND WHAT THE CLICK MEANS IS `dismiss()`. There is no close button and
// there never was one. Reaching past the facade to call `expire()` on the
// notification would clear the screen the same way and tell the sending
// application the opposite thing -- and an application that thinks you never
// closed its notification sends it again.
//
// Rule 4 holds for state the facade owns outright: `expanded` has exactly one
// writer, so the chevron calls `toggleExpanded()` and never assigns.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property NotificationCard row

    implicitHeight: root.row.expanded ? 56 : 28
    color: root.row.critical ? "#ff0000" : "#ff00ff"
    border.width: 2
    border.color: "#000000"

    MouseArea {
        anchors.fill: parent
        onClicked: root.row.dismiss()
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: chevron.left
        anchors.top: parent.top
        anchors.topMargin: 4

        text: root.row.notification.summary
        color: "#ffff00"
        font.family: Theme.fontFamily
        wrapMode: Text.Wrap
        elide: Text.ElideRight
    }

    Rectangle {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.topMargin: 4

        width: 16
        height: 16
        color: "#00ffff"

        MouseArea {
            anchors.fill: parent
            onClicked: root.row.toggleExpanded()
        }
    }
}
