// THE SETTINGS WINDOW'S GROUND, WHICH IS ONE SURFACE, and the caption that
// names it.
//
// AN EARLIER VERSION OF THIS FILE DREW TWO SURFACES and the second one was a
// measurement error. It laid a LayerFillColorDefault rectangle over the
// content pane, thirteen levels lighter than the rail, with a stroke and a
// rounded top-left corner -- the WinUI Gallery's arrangement -- and cited a
// +13 read out of ref/settings-personalization-taskbar.jpg. That +13 was the
// expanded "Taskbar behaviors" CARD, which fills most of that page. Sampled
// where nothing is drawn, the same photograph says the opposite: the strip
// between the cards' right edge and the window edge (x=1200) is the rail's
// own ground from top to bottom, and in ref/settings-home-navpane.png the nav
// pane, the margin left of the cards and the gap between the two card columns
// are all exactly #202020 while only the cards sit at #2B2B2B. The Settings
// app has NO content layer: one mica ground under both panes, no divider down
// the rail's edge, and the cards are the only thing that comes forward.
//
// WHAT SEPARATES THE PANES, THEN, IS NOTHING -- which is the look. A boundary
// line down the rail is the single fastest way to read as "a sidebar app that
// is not Windows"; every reference photograph shows the rail ending where its
// pills end and the ground running on underneath.
//
// THE CAPTION STRIP IS THE OTHER THING THE PHOTOGRAPHS INSIST ON. Windows
// starts no app content in the top 48 of this window: that strip is the title
// bar, carrying "Settings" at the left and the caption controls at the right,
// and the account block and the page title both start under it. This shell's
// compositor draws no decorations (Settings.qml has the Qt/Hyprland story),
// so the strip is the theme's to draw: the word here, the close button in
// SettingsHeader.qml where the facade's signal is, and the clearance under
// both in Fluent.userBlockTopGap and Fluent.headerTopGap. The caption says
// "Settings" -- the name the real window prints -- in Caption type, centred
// on the strip at the pane's own padding. The back arrow beside it in the
// references is a navigation control this window has no history for, and
// Segoe's proper glyph for it is not in this theme's ramp; a chevron standing
// in would be the wrong shape at the one place every screenshot agrees on, so
// nothing is drawn.
//
// NO SIZE CONTRACT AT ALL. This item is anchors.fill'ed by the window and
// reports nothing back; `railWidth` and `railPadding` come off `row` and
// never off Theme, so that the strip this draws and the rail the window lays
// out are one geometry.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsChrome row

    // Theme.glass() and not Fluent.acrylic(): this is a WINDOW, and a window's
    // backdrop in Windows 11 is mica, which is the material that carries the
    // wallpaper's colour. The flyouts that open on top of things are the other
    // material and use the other function.
    Rectangle {
        anchors.fill: parent

        radius: Fluent.overlayRadius
        color: Theme.glass(Theme.surface)
    }

    // ---------------- The caption ----------------
    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.row.railPadding
        anchors.top: parent.top

        height: Fluent.captionHeight
        verticalAlignment: Text.AlignVCenter

        text: "Settings"
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        color: Theme.textOnSurface
    }
}
