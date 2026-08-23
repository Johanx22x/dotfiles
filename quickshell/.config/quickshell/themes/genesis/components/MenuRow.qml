// How genesis draws one row of a menu. The public half -- the two kinds of
// icon, and why the width crosses the seam upwards here -- is
// components/MenuRow.qml.
//
// THE WHOLE ROW IS THE TARGET, which is the same promise ToggleRow's header
// makes and the same one a facade cannot require. A menu row that only
// answered to a click on its label would be a menu you have to aim at, and
// this is the component every tray menu in the shell is built out of.
//
// THE ROOT IS A Rectangle AND THE FACADE'S IS AN Item: `radius` and the hover
// fill are the two reasons this was ever a Rectangle, and both are drawing.
//
// AND THE ICON IS RESOLVED HERE. `Icons.resolve` is a host service reached the
// way rule 5 says host services are reached -- straight off `import qs` --
// rather than handed down as a finished URL. The facade's header has the
// argument; the short of it is that a theme drawing no icon should not be
// making anything resolve one.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `MenuRow` here is the facade and not
    // this file.
    required property MenuRow row

    // WHAT THE FACADE READS BACK, AND HERE IT IS A PAIR. The height is one
    // line, always. The width is the content's plus a padding either side --
    // it is what makes a menu as wide as its longest entry, and it is the
    // number MenuView's entries read to size themselves. Neither is derived
    // from the size this item was given, which is what keeps the pair out of a
    // loop.
    implicitWidth: contents.implicitWidth + Theme.groupPadding * 2
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse && root.enabled ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // Rule 6: this is Qt's effective-enabled, computed down the tree from the
    // facade through its Loader to here. The MouseArea below forwards it by
    // hand because MouseArea.enabled is a flag of its own and does not follow
    // the tree.
    opacity: root.enabled ? 1 : 0.4

    Row {
        id: contents

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        // A Nerd Font glyph, for rows the shell writes itself.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant
        }

        // A themed icon, for rows that come from D-Bus.
        Image {
            anchors.verticalCenter: parent.verticalCenter
            source: Icons.resolve(root.row.iconSource)
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
            text: root.row.checked ? `✓  ${root.row.label}` : root.row.label
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

        visible: root.row.trailing
        text: "›"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurfaceVariant
    }

    // THE WHOLE ROW, and that is the promise the facade's header makes and
    // this file keeps.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.row.activated()
    }
}
