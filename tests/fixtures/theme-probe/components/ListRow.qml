// ListRow, as the probe draws it: the label, the detail after it, and a cyan
// block on the left when the row is selected.
//
// `interactive` false means no hover, no cursor and no `chosen` -- the facade
// says so and only this file can keep it.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property ListRow row

    implicitHeight: root.row.compact ? 20 : 26
    color: root.row.selected ? "#00ffff" : "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.fill: parent
        anchors.margins: 3
        verticalAlignment: Text.AlignVCenter

        text: root.row.detail === ""
            ? root.row.rowLabel
            : `${root.row.rowLabel}  (${root.row.detail})`
        color: "#000000"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.row.interactive
        hoverEnabled: root.row.interactive
        cursorShape: root.row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.row.chosen()
    }
}
