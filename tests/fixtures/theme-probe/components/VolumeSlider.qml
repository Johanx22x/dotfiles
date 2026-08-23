// VolumeSlider, as the probe draws it: a green bar on a black rail, dragged or
// scrolled.
//
// `wheel()` returns whether the facade took the event and the answer has to be
// assigned to `wheel.accepted` -- dropping it on the floor would leave a
// scroll over the slider moving the list behind it as well.

import QtQuick
import qs.components

Rectangle {
    id: root

    required property VolumeSlider row

    implicitHeight: 12
    color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: parent.width * Math.max(0, Math.min(1, root.row.fraction))
        color: "#00ff00"
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        x: parent.width * Math.max(0, Math.min(1, root.row.notch)) - 1
        width: 2
        visible: root.row.notch >= 0
        color: "#ff0000"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.enabled

        onPressed: mouse => root.row.moveTo(mouse.x / Math.max(1, area.width))
        onPositionChanged: mouse => root.row.moveTo(mouse.x / Math.max(1, area.width))
        onWheel: wheel => {
            wheel.accepted = root.row.wheel(wheel.angleDelta.y);
        }
    }
}
