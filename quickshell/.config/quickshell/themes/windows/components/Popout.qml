// How the windows theme draws the panel that opens from the bar. Under this
// theme that panel is the QUICK SETTINGS FLYOUT: acrylic, an eight-pixel
// radius, a hairline stroke, and the content inset by the standard flyout
// padding. The public half -- the layer surface, the keyboard focus, the input
// mask, the screen-edge clamp, the reservation and the grab that dismisses it
// -- is components/Popout.qml, and none of that is drawing.
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
//   `topSlack` IS NOT A STYLE TOKEN. It is how much of this rectangle is hidden
//   past the window's edge, and the facade computes the window's own height
//   from the same number. Both ends have to use it or the panel gains a square
//   edge or uneven padding, so it is read here and added to the height rather
//   than being decided again.
//
//   UNDER THIS THEME IT IS ZERO, and reading it anyway is the point. The facade
//   gates the slack on the fillet, and this theme's fillet is zero -- so there
//   is nothing hidden, all four corners are drawn, and the panel floats clear
//   of the taskbar the way a Windows flyout does. Hard-coding the zero here
//   would be this file agreeing with the facade by coincidence rather than by
//   reading it, and the first theme to want a weld back would find the two
//   halves disagreeing.
//
// ---------------------------------------------------------------------------
// NO FILLETS, AND THAT IS THIS THEME SAYING WHAT IT IS
// ---------------------------------------------------------------------------
//
// genesis welds this panel to the bar with a concave CornerWedge on each side,
// so the two read as one surface that grew out of it. Windows has no such shape
// anywhere: a flyout is a rectangle with a stroke, and the taskbar it opened
// from -- which under this theme is along the BOTTOM -- is a separate object. This theme's `screenCornerRadius` is 0 for the same
// reason -- Windows rounds WINDOWS, not the screen -- and `Theme.barCornerRadius`
// follows it, so a wedge here would be drawn at radius zero in any case. Both
// are gone, and with them two Loaders per popout.
//
// AND ALL FOUR CORNERS ARE ROUND, which is the same decision read from the
// other end. genesis squares the two corners facing the bar by growing the
// rectangle out of the window and letting the screen edge cut them off; that
// only makes sense for a panel that is WELDED, and this one is not. With the
// fillet at zero the facade drops the slack to zero with it, the window is
// exactly this rectangle, and what is left is a flyout with an eight-pixel
// radius all the way round -- which is what Windows draws.
//
// The radius is uniform rather than per-corner for a reason that survives
// either shape: Rectangle's per-corner radius path is NOT antialiased and comes
// out as two or three pixels of stair step, whatever `antialiasing` says.
//
// ---------------------------------------------------------------------------
// THE FLYOUT SHADOW IS NOT HERE, AND IT IS NOT AN OVERSIGHT
// ---------------------------------------------------------------------------
//
// Windows gives a flyout `0 8px 16px` of black at 26% -- Fluent.flyoutShadowY,
// flyoutShadowBlur and shadowOpacity are all sitting there waiting for it. It
// cannot be drawn from this side, and the reason is arithmetic in the facade
// rather than anything about effects:
//
//     implicitWidth:  max(reservedWidth, popoutMinWidth) + fillet * 2
//     implicitHeight: max(reservedHeight, popoutMinWidth) - topSlack
//
// `fillet` is `Theme.barCornerRadius`, which is this theme's screen corner
// radius, which is 0 -- Windows rounds windows, not the screen. And with the
// fillet at zero the slack is zero too. So the window is EXACTLY this panel's
// box on all four sides: there is no transparent margin for a shadow to fall
// on, and anything drawn outside this rectangle lands outside the layer surface
// and is never composited.
//
// The one way to make room is to report a larger implicit size and inset the
// panel inside it -- and the window's input mask is the Loader, not this
// rectangle, so that would buy a shadow at the price of a dead ring of pixels
// around every popout: clicks landing on it would be taken by the window,
// FocusGrab would not see them, and the panel would refuse to dismiss for no
// visible reason. That is the fault class this repository keeps meeting; it is
// not worth a shadow.
//
// So: no shadow, and the stroke does the whole job of separating the flyout
// from what is behind it. If the interface ever grows a way for a theme to ask
// for margin around a popout that the mask does not follow, this is the
// component that wanted it.

import QtQuick
import qs
// Popout is components/Popout.qml -- the facade -- and not this file. The
// explicit import wins over the directory a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property Popout row

    // WHERE THE PANEL IS GOING, from the content and never from this item's own
    // size. `Theme.groupPadding` is 16 under this theme, which is the standard
    // flyout padding; `Theme.popoutMinWidth` is 340, which is ours -- Microsoft
    // publishes no Quick Settings geometry at all.
    readonly property int targetWidth: Math.max(holder.implicitWidth + Theme.groupPadding * 2, Theme.popoutMinWidth)
    readonly property int targetHeight: holder.implicitHeight + Theme.groupPadding * 2 + root.row.topSlack

    implicitWidth: root.targetWidth
    implicitHeight: root.targetHeight

    // OverlayCornerRadius. Windows gives 8 to windows, flyouts, dialogs and
    // menus and 4 to everything that sits inside one, and there is no third
    // value: a 7 measured off a screenshot is this 8 minus the 1px stroke below.
    radius: Fluent.overlayRadius
    antialiasing: true

    // ACRYLIC, as close as a layer surface gets to it. Microsoft's recipe is a
    // tint of #2C2C2C at 15% over a 96% luminosity layer with a 30px gaussian
    // behind it; what this shell has is the compositor's blur behind the
    // surface and one alpha in front of it, which is `Theme.glass`. The tint is
    // the scheme's own ground rather than a colour invented here.
    //
    // The alpha is the user's -- four programs share that number and only one
    // of them can read a theme -- so a flyout here is as opaque as the terminal
    // beside it, which is the trade the host made deliberately.
    color: Theme.glass(Theme.surface)

    // SurfaceStrokeColorFlyout, which is a BLACK overlay in dark mode and not a
    // white one. Read as the scheme's divider role, which is where the black
    // overlays land once they are composited.
    border.width: 1
    border.color: Theme.outlineVariant

    // NO `Behavior on color` ANYWHERE IN THIS FILE. This theme's
    // recolorDuration is 0 and its hoverMs is 0, so every Behavior a colour
    // could carry would animate for no time at all; leaving them out says the
    // instantaneous swap was chosen rather than inherited.

    Item {
        id: holder

        // Centred on the VISIBLE area. `topSlack` is zero under this theme, so
        // this is the plain flyout padding -- but it is read rather than
        // assumed, because a rectangle grown out of the window by the slack
        // would put a content item centred on the whole of it that far too
        // high.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.row.topSlack + Theme.groupPadding
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height

        // The content is the facade's -- a Component the widget that opened
        // this popout handed it -- and destroying it on close is what keeps a
        // popout from showing stale state the next time it is opened. This file
        // only decides where it sits.
        Loader {
            active: root.row.isOpen
            sourceComponent: root.row.contentComponent
        }
    }
}
