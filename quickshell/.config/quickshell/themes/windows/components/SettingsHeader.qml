// THE TOP OF THE CONTENT PANE: the page's name, and the way out.
//
// THE NAME IS A TITLE AND NOT A HEADING. Windows sets the page name in Title
// -- 28 over a 36 line, semibold -- and it is the largest thing in the window
// by a long way; in ref/settings-system-about.jpg it is twice the height of
// everything under it. Windows draws it as a breadcrumb, "System > About", and
// this window has one page name rather than a trail, so what is drawn is the
// last crumb, which is the one set in the heavier face anyway. It does NOT
// start at the window's top edge: the caption strip is above it (the account
// in SettingsChrome.qml), and Fluent.headerTopGap is what pushes the ink down
// to the 51-below-the-top the reference measures.
//
// THE CLOSE BUTTON IS A CAPTION CONTROL, NOT A PAGE CONTROL. Windows has no X
// inside the Settings page -- the way out is the title bar's close button,
// 46x32, flush against the window's top-right corner, and an earlier version
// of this file that floated a 32-square X inside the pane's padding was the
// second-fastest tell in the window after the pane divider. So the button is
// drawn AT the corner: the host anchors this facade a groupPadding inside the
// window on both axes, and the two negative margins below spend exactly that
// padding to put the button's edges on the window's edges. Its hover fill
// rounds its outer corner by the window's own radius, because a square fill
// there would paint over the mica's rounding.
//
// It is the only caption control drawn. Minimize and maximize are compositor
// operations no facade offers a signal for, and two buttons that did nothing
// would be worse than two buttons missing; close is the one this window
// promises (rule 7 in themes/genesis/components/README.md -- the compositor
// draws no decorations, so this is the only pointer-reachable way out).
//
// IT GOES RED, WHICH IS THE ONE THING EVERY WINDOWS USER KNOWS ABOUT IT. Not
// the caption bar's exact #c42b1c -- a theme reads colour off roles and there
// is no role for that red -- but Theme.critical with Theme.textOnCritical on
// top of it, which is the same statement in this shell's vocabulary. The
// glyph is the 10-epx caption ramp, not the 16 the in-pane X used: measured
// against the reference, where the title bar's X is 10 px across.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsHeader row

    implicitHeight: Fluent.headerTopGap + Fluent.titleLine + Fluent.sectionHeaderBottom

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Fluent.headerTopGap

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

        // The two negative margins are the host's own padding, spent to reach
        // the window's corner -- Theme.groupPadding is the number Settings.qml
        // anchors this facade in by, read from the same token.
        anchors.right: parent.right
        anchors.rightMargin: -Theme.groupPadding
        anchors.top: parent.top
        anchors.topMargin: -Theme.groupPadding

        width: Fluent.captionButtonWidth
        height: Fluent.captionButtonHeight
        topRightRadius: Fluent.overlayRadius

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
            font.pointSize: Fluent.captionGlyphSize
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
