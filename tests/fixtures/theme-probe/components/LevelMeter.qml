// LevelMeter, as the probe draws it: a green bar that turns red where the
// facade says it is hot.
//
// Both reads are hoisted to the top level for rule 1's reason -- they would be
// unchecked inside a delegate, and this file is where the checking is.

import QtQuick
import qs.components

Rectangle {
    id: root

    required property LevelMeter row

    readonly property real level: root.row.level
    readonly property real hotFrom: root.row.hotFrom

    implicitHeight: 8
    color: "#000000"

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: parent.width * Math.max(0, Math.min(1, root.level))
        color: root.level >= root.hotFrom ? "#ff0000" : "#00ff00"
    }
}
