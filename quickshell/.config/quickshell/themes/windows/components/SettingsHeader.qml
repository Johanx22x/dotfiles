// THE LINE ACROSS THE TOP OF THE CONTENT PANE: the page's name, and the way
// out.
//
// THE NAME IS A TITLE AND NOT A HEADING. Windows sets the page name in Title
// -- 28 over a 36 line, semibold -- and it is the largest thing in the window
// by a long way; in ref/settings-system-about.jpg it is twice the height of
// everything under it. Windows draws it as a breadcrumb, "System > About", and
// this window has one page name rather than a trail, so what is drawn is the
// last crumb, which is the one set in the heavier face anyway.
//
// THE CLOSE BUTTON IS THE ONLY POINTER-REACHABLE WAY OUT. Qt offers to draw
// decorations, Hyprland says it will do it server-side and then draws none, so
// a theme that leaves this out leaves Escape and the compositor's own binding.
// That is rule 7 in themes/genesis/components/README.md and it is kept here.
//
// IT GOES RED, WHICH IS THE ONE THING EVERY WINDOWS USER KNOWS ABOUT IT. Not
// the caption bar's exact #c42b1c -- a theme reads colour off roles and there
// is no role for that red -- but Theme.critical with Theme.textOnCritical on
// top of it, which is the same statement in this shell's vocabulary. Its shape
// is the subtle button's: 32 square, radius 4, no fill at rest.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsHeader row

    implicitHeight: Fluent.titleLine + Fluent.sectionHeaderBottom

    Text {
        anchors.left: parent.left
        anchors.right: close.left
        anchors.rightMargin: Fluent.cardPadding
        anchors.top: parent.top

        height: Fluent.titleLine
        verticalAlignment: Text.AlignVCenter

        text: root.row.heading
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Fluent.titleSize
        font.weight: Fluent.strongWeight
        color: Theme.textOnSurface
    }

    Rectangle {
        id: close

        anchors.right: parent.right
        anchors.top: parent.top

        width: Fluent.controlHeight
        height: Fluent.controlHeight
        radius: Fluent.controlRadius

        color: {
            if (pointer.pressed)
                return Qt.alpha(Theme.critical, 0.7);
            if (pointer.containsMouse)
                return Theme.critical;
            return "transparent";
        }

        Text {
            anchors.centerIn: parent

            text: Icons.close
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: pointer.containsMouse ? Theme.textOnCritical : Theme.textOnSurface
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.row.closeRequested()
        }
    }
}
