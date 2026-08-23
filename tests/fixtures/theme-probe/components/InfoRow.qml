// InfoRow, as the probe draws it: two lines of text on a flat rectangle.
//
// Rule 7, and this is the component whose entire contract is an ABSENCE:
// there is nothing to click and it must not look as though there is. No
// MouseArea, no HoverHandler, no TapHandler, no cursorShape, and no colour
// that changes because a pointer is over it. A facade cannot require an
// absence; components/ActionRow.qml is the type to use when there is something
// to press.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property InfoRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.fill: parent
        anchors.margins: 4
        verticalAlignment: Text.AlignVCenter

        text: root.row.description === ""
            ? root.row.label
            : `${root.row.label} -- ${root.row.description}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }
}
