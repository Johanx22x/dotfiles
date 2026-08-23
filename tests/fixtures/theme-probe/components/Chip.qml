// Chip, as the probe draws it: a flat rectangle sized to its word.
//
// It reports implicitWidth, which rule 2 allows here for the reason it allows
// it in genesis's Chip: a chip fills nothing, so there is no parent whose size
// depends on this one and no loop to close.
//
// Rule 7: only a chip whose role is "button" is a control. A badge and a key
// are readings, and the three lines below say so side by side rather than
// behind a Loader, where nothing would check them.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property Chip row

    readonly property bool pressable: root.row.role === "button"

    implicitWidth: label.implicitWidth + 8
    implicitHeight: 18
    color: root.row.filled ? "#00ffff" : "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        id: label

        anchors.centerIn: parent
        text: root.row.chipText
        color: "#000000"
        font.family: Theme.fontFamily
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.pressable
        hoverEnabled: root.pressable
        cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.row.activated()
    }
}
