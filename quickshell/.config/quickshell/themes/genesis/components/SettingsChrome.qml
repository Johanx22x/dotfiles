// How genesis draws the settings window's own surfaces. The public half -- the
// rail's two numbers and the long note on why they are declared there rather
// than read back off this file -- is modules/settings/SettingsChrome.qml.
//
// TWO RECTANGLES AND NOTHING ELSE, in the order they were painted before the
// split: the window's glass first, the rail's tint over it. Everything else in
// that window is still the host's and is drawn on top of both.
//
// THE GLASS IS THE SAME GLASS AS THE BAR, and therefore the same value this
// window edits -- move the opacity in the appearance page and the window
// showing the number goes with it. No radius: Hyprland rounds the window
// itself, at the `rounding` in hyprland.lua that everything else on screen
// agrees with.
//
// 0.18 AND NO DIVIDING LINE, which is the promise this file inherited from the
// rail it was split out of. It started at 0.5 with a hairline down the right
// edge, which is how a file manager does it, and in a window this size it read
// as two windows stitched together: the line drew more attention than the
// boundary deserved, and the step in tone did the same job twice over. What is
// wanted is only enough separation to tell the navigation from the content at a
// glance -- past that, every bit of contrast spent on the frame is contrast
// taken from the selected entry, which is the thing actually worth seeing.
//
// A TINT OVER THE GLASS AND NOT A SECOND GLASS LAYER. An opaque colour at its
// own alpha would compound with the window's, and the sidebar would come out
// noticeably more solid than the pane beside it -- the two would stop looking
// like one window seen through one sheet.
//
// IT RUNS INTO THE LEFT, TOP AND BOTTOM EDGES OF THE WINDOW ON PURPOSE.
// Hyprland rounds those corners itself, so the panel ends in the window's own
// curve instead of in a straight cut a few pixels inside it.

import QtQuick
import qs
// SettingsChrome is modules/settings/SettingsChrome.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsChrome row

    // ---------------- The window ----------------
    Rectangle {
        anchors.fill: parent

        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- The rail's panel ----------------
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        width: root.row.railWidth

        color: Qt.alpha(Theme.surfaceContainerHigh, 0.18)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
