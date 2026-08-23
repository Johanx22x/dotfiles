// SettingsNavItem, as the probe draws it: the entry's name on a strip that is
// green when the rail has it selected, blue while the pointer is over it, and
// magenta the rest of the time.
//
// Rule 7, and this one is an ABSENCE: THERE IS NO MouseArea IN HERE. The
// facade keeps the hit target, because its `preventStealing: true` is the
// whole of a bug reported as "Updates does not open" -- the first click after
// dragging the rail is thrown away, and the only two entries anybody drags to
// are the two below the fold. A theme that drew its own target and left the
// flag off would bring the bug back on a window that looks perfect, and there
// is no property a facade could have made `required` to stop it.
//
// SO THE HOVER TONE IS ASKED FOR AND NOT MEASURED. `hovered` is published by
// the facade and written by the one MouseArea there is.
//
// Rule 3: `label` and `glyph` are read off the facade and never copied onto
// this root.

import QtQuick
import qs
import qs.modules.settings

Rectangle {
    id: root

    required property SettingsNavItem row

    implicitHeight: 24

    color: root.row.selected ? "#00ff00"
        : root.row.hovered ? "#0000ff"
        : "#ff00ff"

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        text: `${root.row.glyph} ${root.row.label}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }
}
