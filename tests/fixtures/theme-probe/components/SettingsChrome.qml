// SettingsChrome, as the probe draws it: a black window with a yellow strip
// down the rail.
//
// `SettingsChrome` in the declaration below is the FACADE, which lives at
// modules/settings/SettingsChrome.qml and not under components/ -- hence the
// import, the same way SettingsSection.qml in this directory does it.
//
// THE RAIL'S WIDTH IS READ HERE AND NEVER MEASURED BACK. `railWidth` is
// published by the facade because six things in the settings window are
// anchored against it and a facade sized by whatever this file drew would
// collapse all six -- so this file paints over the rectangle it is told about
// rather than deciding where the rail ends.
//
// A THEME STILL GETS TO CHOOSE THE NUMBER, and this file's silence is how it
// declines to. The facade reads `Theme.railWidth`, a token out of the theme's
// own theme.json; the probe's theme.json does not name it, so the probe gets
// the host's 210 and paints its strip exactly that wide. Stating a number up
// front in JSON and reporting one back up through a Loader are different
// channels, and only the second is the one the facade's header refuses.

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
