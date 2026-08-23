// MonitorTile, as the probe draws it: a flat box with the connector on it,
// lime while it is being dragged, cyan once it has moved, magenta otherwise.
//
// THREE STATES, UGLY, AND ALL THREE PRESENT. They answer three different
// questions -- what is under the pointer, what Apply is about to send, and what
// is merely there -- and a theme that drew two of them would make the middle
// one invisible.
//
// IT TAKES NO INPUT, which is rule 7 for this component and the sharpest one in
// the interface: the MouseArea that drags a screen belongs to
// ArrangementSection.qml, covers this whole tile, and follows the pointer by
// hand so that the tile stays drawn from the draft. A MouseArea in here would
// be a second opinion about the one interaction on that page.
//
// IT REPORTS NO SIZE AND MUST NOT. `x`, `y`, `width` and `height` are the map's
// -- a coordinate transform, a zoom factor and a logical size -- so this file
// is anchor-filled into a box it does not get a say in. That is the CornerWedge
// clause of themes/genesis/components/README.md rather than rule 2.

import QtQuick
import qs
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property MonitorTile row

    color: root.row.dragging
        ? "#00ff00"
        : (root.row.moved ? "#00ffff" : "#ff00ff")

    border.width: root.row.focused ? 4 : 2
    border.color: "#000000"

    Text {
        anchors.fill: parent
        anchors.margins: 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: root.height > 44
            ? `${root.row.connector}\n${Math.round(root.row.logicalWidth)}x${Math.round(root.row.logicalHeight)}`
            : root.row.connector
        color: "#000000"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }
}
