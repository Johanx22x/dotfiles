// The Arch logo at the head of the bar. It opens the application launcher.
//
// IT USED TO BE DECORATION, AND THE OLD ARGUMENT FOR THAT WAS NOT WRONG. This
// glyph was once the power button, and it was stripped back to a picture
// because a destructive action must not sit one stray click away from the
// corner of the screen. The power menu stays on SUPER + SHIFT + ESCAPE and on
// its own button at the far end, and that still stands. What changed is what
// the click does: opening a search box is the least destructive thing this
// shell has to offer -- it costs one keystroke to dismiss and nothing at all
// to have opened by accident.
//
// AND THE CORNER IS THE RIGHT PLACE FOR EXACTLY THAT. The top-left pixel is
// the one target on a screen a pointer cannot overshoot, which is why every
// desktop with a menu puts it there. That property is worth spending on
// something safe and often wanted, and worth refusing to something that turns
// the machine off. The same fact argues both ways, and this file has done
// both in turn.
//
// TOGGLE AND NOT OPEN, the rule SettingsButton and PowerButton already
// follow: clicking the thing that opened a surface should put it away again.
//
// Unlike waybar, the logo is NOT the fixed Arch blue: it takes the
// wallpaper's primary accent, so the leftmost thing on the bar is also the
// clearest statement of the current palette. This deliberately drops the
// brand colour -- see the git history if that ever needs arguing about.
//
// THE HOVER IS A DISC AND NOT A COLOUR CHANGE, which is the one thing here
// that cannot copy SettingsButton. That button says "this opens something" by
// turning Theme.primary on hover; the logo is already Theme.primary at rest,
// so the same gesture would be invisible. It borrows the disc instead, at the
// same alpha, so the two still speak the same language.
//
// nf-linux-archlinux (U+F303) comes from the "Font Logos" range of
// JetBrainsMono Nerd Font.

import QtQuick
import "root:/"
import "root:/modules/launcher"

Item {
    id: root

    // Unchanged from when this was a picture, so becoming a control again
    // does not shift the bar's spacing.
    implicitWidth: Theme.barHeight - 4
    implicitHeight: Theme.barHeight - 4

    // Four inside the footprint, so the disc reads as a target the glyph sits
    // inside rather than as a badge stuck to it -- the same distinction
    // SettingsButton's own note draws about its six.
    readonly property int discSize: root.implicitHeight - 4

    Rectangle {
        anchors.centerIn: parent

        width: root.discSize
        height: root.discSize
        radius: height / 2
        color: mouse.containsMouse ? Qt.alpha(Theme.primary, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // CENTRED ON ITS INK, NOT ON ITS TEXT BOX, and the difference is visible
    // the moment there is a disc behind it. Measured in the font itself:
    // nf-linux-archlinux draws from x=0 to x=1000 inside an advance of only
    // 600 units per 1000-unit em, so the mark overhangs its own cell by 400
    // and its ink centre sits 0.2 em right of the centre `anchors.centerIn`
    // would use. Vertically it is already exact -- ink centre 360 against a
    // box centre of 360 -- which is why only one axis is corrected here.
    //
    // The offset is READ FROM THE FONT rather than written down, because a
    // number would be right for this glyph at this size and silently wrong
    // for a different Nerd Font release or a changed logoSize.
    //
    // ONLY x IS TAKEN FROM THE METRIC, and the vertical stays on an anchor on
    // purpose: tightBoundingRect measures its y from the BASELINE while a
    // Text item's y is measured from the top of its line box, so using it
    // vertically would mix two origins and introduce an error on the one axis
    // the font already gets right. Horizontally the two agree -- both start at
    // the text origin -- so there is nothing to reconcile.
    TextMetrics {
        id: ink

        font: logo.font
        text: logo.text
    }

    Text {
        id: logo

        x: (root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
        anchors.verticalCenter: parent.verticalCenter

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

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: LauncherState.toggle()
    }
}
