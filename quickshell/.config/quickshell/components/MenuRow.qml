// One row of a menu: an optional icon, a label, and an optional trailing
// mark for submenus.
//
// Shared by the tray menus and by the shell's own popouts, so a menu written
// by hand and a menu coming off D-Bus are the same object on screen.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string label: ""
    property string glyph: ""
    property string iconSource: ""
    property bool trailing: false
    property bool checked: false

    signal activated

    implicitWidth: row.implicitWidth + Theme.groupPadding * 2
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse && root.enabled ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    opacity: root.enabled ? 1 : 0.4

    Row {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        // A Nerd Font glyph, for rows the shell writes itself.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant
        }

        // A themed icon, for rows that come from D-Bus.
        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: Icons.resolve(root.iconSource)
            // Ready and not just "non-empty": an icon the theme does not have
            // would otherwise leave the broken-image chequerboard behind.
            visible: status === Image.Ready
            width: Theme.imageSize
            height: Theme.imageSize
            sourceSize.width: width
            sourceSize.height: height
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.checked ? `✓  ${root.label}` : root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.trailing
        text: "›"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurfaceVariant
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.activated()
    }
}
