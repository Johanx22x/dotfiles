// The Arch logo at the head of the bar. Decoration, not a control: it does
// not click, it does not hover, it does not take input at all. The power menu
// stays on SUPER + SHIFT + ESCAPE, which is where it belongs -- a destructive
// action should not sit one stray click away from the corner of the screen.
//
// Unlike waybar, the logo is NOT the fixed Arch blue: it takes the
// wallpaper's primary accent, so the leftmost thing on the bar is also the
// clearest statement of the current palette. This deliberately drops the
// brand colour -- see the git history if that ever needs arguing about.
//
// nf-linux-archlinux (U+F303) comes from the "Font Logos" range of
// JetBrainsMono Nerd Font.

import QtQuick
import "root:/"

Item {
    id: root

    // Same footprint the button had, so the bar's spacing does not shift.
    implicitWidth: Theme.barHeight - 4
    implicitHeight: Theme.barHeight - 4

    Text {
        anchors.centerIn: parent
        text: Icons.arch
        color: Theme.primary
        font.family: Theme.fontFamily
        // One point over the rest: the logo carries a lot of fine detail and
        // smudges at the bar's base size.
        font.pointSize: Theme.logoSize

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
