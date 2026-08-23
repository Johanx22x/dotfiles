// The Start button. It opens the application launcher.
//
// IT IS AN APP BUTTON AND IT SITS WITH THEM. Windows 11 moved Start off the
// corner and into the middle of the taskbar, in the same 40x40 box as
// everything beside it, and that is the change everybody noticed on the day it
// shipped. Bar.qml puts it first in the centred row.
//
// GENESIS'S ARGUMENT FOR THE CORNER IS NOT WRONG, IT IS SOMEBODY ELSE'S. The
// top-left pixel is the one target on a screen a pointer cannot overshoot,
// which is why every desktop with a menu puts its menu there, and this file
// used to spend three paragraphs on why that property is worth spending on
// something safe and often wanted. Windows 11 spends it on nothing at all and
// centres the button instead. This theme draws Windows 11.
//
// STILL THE ARCH MARK AND STILL IN THE ACCENT. There is no free Windows logo to
// draw and pretending otherwise would be the wrong kind of fidelity; what is
// faithful is that the Start button is the ONE accent-coloured thing in the
// whole taskbar, which is true of the real one and is true here.
//
// nf-linux-archlinux (U+F303) comes from the "Font Logos" range of
// JetBrainsMono Nerd Font.

import QtQuick
import qs
import qs.modules.launcher
import ".."

TaskbarItem {
    id: root

    boxWidth: Fluent.taskButton
    boxHeight: Fluent.taskButton

    // Toggle and not open, the rule every door in this bar follows: clicking
    // the thing that opened a surface should put it away again.
    onActivated: LauncherState.toggle()

    // CENTRED ON ITS INK, NOT ON ITS TEXT BOX, and the difference is visible the
    // moment there is a fill behind it. Measured in the font itself:
    // nf-linux-archlinux draws from x=0 to x=1000 inside an advance of only 600
    // units per 1000-unit em, so the mark overhangs its own cell by 400 and its
    // ink centre sits 0.2 em right of the centre `anchors.centerIn` would use.
    // Vertically it is already exact -- ink centre 360 against a box centre of
    // 360 -- which is why only one axis is corrected here.
    //
    // The offset is READ FROM THE FONT rather than written down, because a
    // number would be right for this glyph at this size and silently wrong for
    // a different Nerd Font release or a changed logoSize.
    //
    // ONLY x IS TAKEN FROM THE METRIC, and the vertical stays on an anchor on
    // purpose: tightBoundingRect measures its y from the BASELINE while a Text
    // item's y is measured from the top of its line box, so using it vertically
    // would mix two origins and introduce an error on the one axis the font
    // already gets right.
    TextMetrics {
        id: ink

        font: logo.font
        text: logo.text
    }

    Text {
        id: logo

        x: (parent.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
        anchors.verticalCenter: parent.verticalCenter

        text: Icons.arch
        color: Theme.primary
        font.family: Theme.fontFamily
        // One point over the rest: the logo carries a lot of fine detail and
        // smudges at the bar's base size.
        font.pointSize: Theme.logoSize
    }
}
