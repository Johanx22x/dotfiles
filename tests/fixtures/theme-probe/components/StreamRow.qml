// StreamRow, as the probe draws it: the stream's name, its route, and a bar
// as long as its volume. Clicking the bar sets the volume; clicking the block
// on the left mutes.
//
// Rule 4: `setVolume()` and `toggleMute()` are the facade's functions and are
// the only way this file may move anything. `row.node` is not touched.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property StreamRow row

    implicitHeight: 40
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        id: mute

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 18
        height: 18
        color: root.row.muted ? "#ff0000" : "#00ff00"

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.row.toggleMute()
        }
    }

    Text {
        anchors.left: mute.right
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 3

        text: `${root.row.label}  ${root.row.routePrefix}${root.row.route}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: rail

        anchors.left: mute.right
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4

        height: 8
        color: "#000000"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: parent.width * Math.max(0, Math.min(1, root.row.volume))
            color: "#00ff00"
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: mouse => root.row.setVolume(mouse.x / Math.max(1, rail.width))
        }
    }
}
