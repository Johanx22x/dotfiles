// SettingsChrome, as the probe draws it: a black window with a yellow strip
// down the rail.
//
// `SettingsChrome` in the declaration below is the FACADE, which lives at
// modules/settings/SettingsChrome.qml and not under components/ -- hence the
// import, the same way SettingsSection.qml in this directory does it.
//
// THE RAIL'S WIDTH IS READ AND NEVER CHOSEN. `railWidth` is declared on the
// facade because six things in the settings window are anchored against it and
// a theme reporting nothing would collapse all six -- so this file paints over
// the rectangle it is told about rather than deciding where the rail ends. It
// is the CornerWedge case: the number stayed on the host side, and this is the
// second caller for that clause.

import QtQuick
import qs.modules.settings

Item {
    id: root

    required property SettingsChrome row

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        width: root.row.railWidth
        color: "#ffff00"
    }
}
