// THE SETTINGS WINDOW'S TWO SURFACES: the mica the whole window sits on, and
// the lighter layer the content pane is.
//
// WHAT THE PHOTOGRAPH SAYS AND THE FACADE'S NAME DOES NOT. The half the window
// sees calls the second rectangle "the tint down the navigation rail", which is
// where genesis puts it. Windows tints the OTHER SIDE: in
// ref/settings-personalization-taskbar.jpg the navigation pane is the window's
// bare mica and the content pane is a LayerFillColorDefault over it, thirteen
// levels lighter on every channel. In ref/settings-system-about.jpg, taken with
// transparency off, the two panes are the same #202020 and only the cards stand
// away from them -- which is the same drawing seen without the layer.
//
// So the rail gets nothing of its own and the pane on the right is the one that
// comes forward, which is section 0 of the brief in one rectangle: every
// surface that comes forward gets LIGHTER.
//
// THE PANE'S CORNER IS 8,0,0,0 AND ITS STROKE IS TOP AND LEFT ONLY, which is
// two facts about a corner that only exists because Windows rounds windows.
// The pane's other three corners are the WINDOW's corners, so they take the
// window's own 8 -- a square corner there would cut the mica's rounding off at
// the bottom right. The stroke is drawn as a rectangle in the stroke's colour
// with the fill inset one pixel on the two sides that carry it, because a
// Rectangle's border is all four sides or none.
//
// NO SIZE CONTRACT AT ALL. This item is anchors.fill'ed by the window and
// reports nothing back; `railWidth` comes off `row` and never off Theme, so
// that the rectangle this draws and the rail the window lays out are one
// number.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsChrome row

    // ---------------- The ground: mica ----------------
    //
    // Theme.glass() and not Fluent.acrylic(): this is a WINDOW, and a window's
    // backdrop in Windows 11 is mica, which is the material that carries the
    // wallpaper's colour. The flyouts that open on top of things are the other
    // material and use the other function.
    Rectangle {
        anchors.fill: parent

        radius: Fluent.overlayRadius
        color: Theme.glass(Theme.surface)
    }

    // ---------------- The content pane, and its stroke ----------------
    Rectangle {
        id: pane

        anchors.left: parent.left
        anchors.leftMargin: root.row.railWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // The stroke. CardStrokeColorDefault is black at ten per cent, so this
        // reads as a shadow line between the two panes rather than as a
        // highlight -- see Fluent.cardStrokeAlpha for the measurement.
        color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)

        topLeftRadius: Fluent.overlayRadius
        topRightRadius: Fluent.overlayRadius
        bottomRightRadius: Fluent.overlayRadius
        bottomLeftRadius: 0

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.leftMargin: 1

            color: Qt.alpha(Theme.surfaceContainerHigh, Fluent.layerAlpha)

            topLeftRadius: Fluent.overlayRadius - 1
            topRightRadius: pane.topRightRadius
            bottomRightRadius: pane.bottomRightRadius
            bottomLeftRadius: 0
        }
    }
}
