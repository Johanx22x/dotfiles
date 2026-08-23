// ToggleRow, as the probe draws it: the label, and a block that is green when
// the row is on and red when it is off.
//
// Rule 7: THE WHOLE ROW IS THE TARGET, not the block. A theme that put the
// MouseArea on the switch instead of the row would pass every check in tests/.
//
// Rule 3: `label` is read off the facade and never copied onto this root. The
// settings search duck-types on that name by walking the live tree, Loader
// included, so a mirrored one indexes every row twice in a window that
// otherwise looks correct.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property ToggleRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    // Rule 6: the dim goes against this item's own effective `enabled`, which
    // Qt propagates down the tree and through the Loader. row.enabled would
    // give the same answer today and the wrong one the moment anything between
    // the page and here is disabled.
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: knob.left
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: knob

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 26
        height: 16
        color: root.row.checked ? "#00ff00" : "#ff0000"
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        // Rule 4: ask, never write. `row.checked = true` would be a second
        // writer to a value this same object displays.
        onClicked: root.row.toggled(!root.row.checked)
    }
}
