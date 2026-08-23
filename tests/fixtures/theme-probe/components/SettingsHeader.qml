// SettingsHeader, as the probe draws it: the page's name on a cyan strip with
// a red square in the corner that closes the window.
//
// Rule 7: THERE IS A WAY OUT, and it is the only thing this file has to get
// right. The settings window has no title bar -- Hyprland draws none and Qt
// does not either -- so the button below is the only pointer-reachable way to
// close it. A theme that drew no button would leave a window that looks
// finished and can only be shut from the keyboard, and no property on the
// facade could have required one.
//
// Rule 3: the name is read off the facade as `heading` and never mirrored onto
// this root. It is spelled `heading` rather than `title` on that side for the
// same family of reasons -- the settings search duck-types a section by
// `title`, and the window itself already means something else by it.
//
// implicitHeight is what the facade reads back and floors: the two panes below
// the header anchor to its bottom edge, so a header that reported nothing
// would put them at the top of the window.

import QtQuick
import qs
import qs.modules.settings

Item {
    id: root

    required property SettingsHeader row

    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        color: "#00ffff"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.right: closeButton.left
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.heading
            color: "#000000"
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: 20
        color: "#ff0000"

        // Rule 4: ask, never act. The theme has no idea there is a window.
        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.row.closeRequested()
        }
    }
}
