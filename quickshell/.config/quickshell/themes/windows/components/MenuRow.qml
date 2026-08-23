// ONE ITEM IN A MENU -- A MenuFlyoutItem.
//
// 32 TALL, AND THE MEASUREMENT IS WORTH THE SENTENCE. The Explorer context
// menu in ref/contextmenu-explorer-dark.png has taller rows than this, and it
// is not this control: the shell's context menu is its own thing. The menu
// that opens INSIDE a Windows app is the flyout in
// ref/settings-flyout-menu.jpg, where "Modify" and "Uninstall" sit 48 apart in
// a 150% shot -- 32 apiece -- with their text 16 from the menu's left edge,
// which is the four-pixel inset plus the item's own eleven.
//
// THE HIGHLIGHT IS INSET FOUR PIXELS FROM EACH SIDE OF THE MENU and the
// separators are not: a MenuFlyoutSeparator runs wider than the backplates
// above and below it, which is why the menu looks banded rather than striped.
// The separator belongs to whatever draws the menu around these; what this
// file owes it is the inset, so that the two do not line up.
//
// A CHECKED ITEM SHOWS ITS CHECK IN THE ICON COLUMN, which is what a
// ToggleMenuFlyoutItem does -- the tick takes the icon's place rather than
// sitting beside it.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property MenuRow row

    readonly property bool leading: root.row.checked
        || root.row.glyph !== ""
        || root.row.iconSource !== ""

    implicitHeight: Fluent.menuItemHeight

    // ADDED UP OUT OF WHAT IS ACTUALLY DRAWN, and the chevron is why. It was
    // budgeted at the icon column's 16 first, and Segoe's chevron measures
    // wider than that with its bearings, so every item with a submenu came out
    // four pixels short and elided its own label -- "Open wi..." in the
    // photograph. A width that guesses at a glyph is a width that is wrong for
    // one font.
    implicitWidth: 2 * Fluent.menuItemInset + 2 * Fluent.controlPaddingH
        + (root.leading ? lead.width + 8 : 0)
        + word.implicitWidth
        + (root.row.trailing ? chevron.implicitWidth : 0)

    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.leftMargin: Fluent.menuItemInset
        anchors.rightMargin: Fluent.menuItemInset

        radius: Fluent.controlRadius
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        color: {
            if (pointer.pressed)
                return Fluent.fillPress;
            if (pointer.containsMouse)
                return Fluent.fillSubtleHover;
            return "transparent";
        }

        Item {
            id: lead

            anchors.left: parent.left
            anchors.leftMargin: Fluent.controlPaddingH
            anchors.verticalCenter: parent.verticalCenter

            width: root.leading ? Fluent.navIcon : 0
            height: Fluent.navIcon

            Image {
                anchors.fill: parent

                source: root.row.iconSource
                visible: !root.row.checked && root.row.iconSource !== "" && status === Image.Ready
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent

                visible: root.row.checked || (root.row.glyph !== "" && root.row.iconSource === "")
                text: root.row.checked ? Icons.check : root.row.glyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.glyphSmallSize
                color: Theme.textOnSurface
            }
        }

        Text {
            id: word

            anchors.left: lead.right
            anchors.leftMargin: root.leading ? 8 : 0
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.textOnSurface
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Fluent.controlPaddingH
            anchors.verticalCenter: parent.verticalCenter

            width: root.row.trailing ? implicitWidth : 0
            visible: root.row.trailing
            text: Icons.chevronRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: Theme.textOnSurfaceVariant
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            enabled: root.row.enabled

            onClicked: root.row.activated()
        }
    }
}
