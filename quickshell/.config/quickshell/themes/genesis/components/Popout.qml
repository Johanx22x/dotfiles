// How genesis draws the panel that hangs from the bar: one rounded rectangle
// welded to the bar's underside by a concave fillet on each side, with the
// popout's content inset inside it. The public half -- the layer surface, the
// keyboard focus, the input mask, the screen-edge clamp, the reservation and
// the grab that dismisses it -- is components/Popout.qml, and none of that is
// drawing.
//
// THIS ITEM IS THE PANEL. The facade's Loader is sized to what this file
// reports and sits where the panel goes, so the window masks input to this
// rectangle and the reservation follows its implicit size. Two things follow
// and both matter:
//
//   REPORT THE SIZE THE PANEL IS GOING TO, not the size it is on this frame.
//   The facade animates the Loader between reports; a theme that reported an
//   animating number would raise the window's high-water mark sixty times a
//   second, which is the surface reconfigure the whole arrangement exists to
//   avoid. So `implicitWidth` and `implicitHeight` come from the content, and
//   never from this item's own `width` or `height`, which the Loader assigns.
//
//   THE FILLETS ARE OUTSIDE THIS ITEM AND THAT IS WHY THEY ARE NOT MASKED.
//   Each one anchors past an edge of this rectangle, so it is drawn beside the
//   panel and not inside it -- the window is two radii wider than the panel to
//   hold them -- and a click on one belongs to whatever is underneath. A
//   fillet drawn INSIDE this item would start taking clicks.
//
// ONE CONTINUOUS SURFACE THAT GREW DOWNWARDS, rather than a floating menu that
// happens to be near the bar. That is the promise, and the fillets are how it
// is kept: they fill the junction with the same concave shape the bar uses
// where it meets the sides of the screen.
//
// WITH NO BAR TO WELD TO it stops pretending. `row.topSlack` goes to zero, the
// rectangle sits where it is drawn instead of being grown upwards, all four
// corners are visible, and the fillets go away -- a card with two square
// corners hanging off the top of the screen is what the alternative looks
// like, and it was on screen for a while.
//
// THE FILLETS GO THROUGH components/CornerWedge.qml AND NOT ROUND IT, now
// that the wedge is split too. That reads like a detour -- a theme file
// reaching for a facade whose only job is to load a file back in this same
// directory -- and it is the only thing that works: the theme's half takes a
// `required property CornerWedge row` and there is no facade to hand it unless
// one is built. It is also the arrangement the seam already assumes, in
// ../README.md's own words: a theme draws WITH the shell's components. The
// cost is one Loader per fillet, two per popout.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property Popout row

    // WHERE THE PANEL IS GOING. Both floors are the ones the pre-split window
    // used: a panel narrower than Theme.popoutMinWidth reads as a fragment
    // rather than as a menu, and the height carries the slack because the
    // rectangle is grown upwards by it.
    readonly property int targetWidth: Math.max(holder.implicitWidth + Theme.groupPadding * 2, Theme.popoutMinWidth)
    readonly property int targetHeight: holder.implicitHeight + Theme.groupPadding * 2 + root.row.topSlack

    implicitWidth: root.targetWidth
    implicitHeight: root.targetHeight

    // Why not topLeftRadius/topRightRadius at 0 and be done: Rectangle's
    // per-corner radius path is NOT antialiased -- `antialiasing: true` makes
    // no difference to it -- and the rounded corners come out as 2-3px stair
    // steps. A uniform `radius` is antialiased properly, so the square edges
    // are made by clipping rather than by geometry: the rectangle is grown
    // upwards out of the window by `topSlack` and the screen edge cuts the top
    // two corners off. The facade is what places it that far up.
    radius: Theme.cardRadius
    antialiasing: true

    color: Theme.glass(Theme.surface)

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    // The two fillets that weld the panel to the bar. Same colour as the
    // panel, and outside it -- see the header -- so they are neither clipped
    // by its own rounding nor covered by its input mask.
    //
    // The top margin is the slack: this item's own top edge is that far ABOVE
    // the window, and a fillet has to start where the bar ends, which is the
    // window's top edge.
    CornerWedge {
        anchors.right: parent.left
        anchors.top: parent.top
        anchors.topMargin: root.row.topSlack

        visible: root.row.barVisible
        corner: "topRight"
        radius: root.row.fillet
        fillColor: root.color
    }

    CornerWedge {
        anchors.left: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.row.topSlack

        visible: root.row.barVisible
        corner: "topLeft"
        radius: root.row.fillet
        fillColor: root.color
    }

    Item {
        id: holder

        // Centred on the VISIBLE area: the rectangle extends one radius above
        // the window while it is welded to the bar, and a content item centred
        // on the whole of it would sit that far too high.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.row.topSlack + Theme.groupPadding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height

        // The content is the facade's -- a Component the widget that opened
        // this popout handed it -- and destroying it on close is what keeps a
        // popout from showing stale state the next time it is opened. This
        // file only decides where it sits.
        Loader {
            active: root.row.isOpen
            sourceComponent: root.row.contentComponent
        }
    }
}
