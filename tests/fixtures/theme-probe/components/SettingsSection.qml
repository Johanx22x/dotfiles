// SettingsSection, as the probe draws it: the title on a flat strip with the
// page's own rows under it.
//
// `SettingsSection` in the declaration below is the FACADE, which lives at
// modules/settings/SettingsSection.qml and not under components/ -- hence the
// import. This file has the same basename as the facade and a QML document
// implicitly imports its own directory, so the explicit import is what decides
// which of the two the type means. It is the riskiest name in the interface
// for that reason.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN, the same way SearchField.qml in
// this directory does: `data: [root.row.rows]` is what moves the facade's
// Column of rows in here. The spacing between those rows is the facade's and
// no theme can pick another one. Rule 3: `title` and `glyph` are read off the
// facade and never mirrored onto this root -- the settings search walks the
// live tree looking for those names and would index every section twice.

import QtQuick
import qs
import qs.modules.settings

Item {
    id: root

    required property SettingsSection row

    implicitHeight: heading.height + 4 + root.row.rows.implicitHeight + 8

    Rectangle {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: 20
        color: "#00ffff"

        Text {
            anchors.fill: parent
            anchors.margins: 2
            verticalAlignment: Text.AlignVCenter

            text: root.row.title
            color: "#000000"
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: 40
            visible: root.row.actionText !== ""
            enabled: root.enabled && root.row.actionText !== ""
            onClicked: root.row.actionTriggered()
        }
    }

    // Where the rows go. An empty item whose only job is to have a position;
    // the line that matters is `data`.
    Item {
        id: slot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.topMargin: 4

        height: root.row.rows.implicitHeight

        data: [root.row.rows]
    }
}
