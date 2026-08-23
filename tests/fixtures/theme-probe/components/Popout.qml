// Popout, as the probe draws it: a magenta rectangle around whatever the bar
// asked to put in it.
//
// THE FACADE HERE IS A PanelWindow AND NOT AN Item, which is the one place the
// ToggleRow shape does not describe. The window, the layer surface, the input
// mask and the screen-edge clamp are the facade's; this file is the rectangle
// inside it. The facade takes its width and height from this item's implicit
// size, so nothing in here may be derived from root.width or root.height --
// that is the loop rule 2 is about.

import QtQuick
import qs.components

Rectangle {
    id: root

    required property Popout row

    implicitWidth: Math.max(content.implicitWidth + 8, 40)
    implicitHeight: Math.max(content.implicitHeight + 8, 24)
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"

    Loader {
        id: content

        anchors.centerIn: parent

        active: root.row.isOpen
        sourceComponent: root.row.contentComponent
    }
}
