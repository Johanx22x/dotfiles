// THE PANEL THAT HANGS OFF THE TASKBAR: Quick Settings, the notification
// centre, the tray overflow. One window, moved under whichever item was
// clicked, with its content swapped -- see components/Popout.qml for why it is
// one and not one per item.
//
// WHAT THIS FILE DOES, AND IT IS SMALLER THAN IT LOOKS LIKE IT SHOULD BE:
// it INSTANTIATES the content the facade was handed, REPORTS how big that
// content came out, and holds the flyout off the bar by the gap Windows
// leaves. Three things, and the third is the only pixel of its own.
//
// ---------------------------------------------------------------------------
// THERE IS NO PANEL RECTANGLE HERE, AND THAT IS A DECISION, NOT AN OMISSION
// ---------------------------------------------------------------------------
//
// The obvious implementation is one acrylic rounded rectangle with the content
// inside it, and it is what genesis draws. Under this theme it is wrong, and
// the photograph is what says so.
//
// `ref/quicksettings-media-tiles.jpg`: the media transport is a PHYSICALLY
// SEPARATE rounded panel sitting above the Quick Settings panel, with a
// visible gap between them through which the wallpaper reads. They are two
// surfaces, not two sections of one. A rectangle drawn behind the whole
// content would bridge that gap with a strip of acrylic and turn the two
// panels back into one -- the exact thing the reference is a picture of NOT
// happening.
//
// So under this theme the MATERIAL belongs to the content, one card at a time,
// and bar/QuickSettings.qml already draws its two: `Theme.surfaceContainer`,
// `Fluent.overlayRadius`, one-pixel `Theme.outlineVariant` border, each. This
// file owns the window's inside and nothing that is painted in it. If a future
// surface wants one panel edge to edge, it draws one panel edge to edge; that
// is a fact about that surface and not about every popout.
//
// The shadow is still this file's, because a shadow is not a card: it belongs
// to the whole thing that is floating, whatever shape that turned out to be.
// MultiEffect takes the CONTENT as its source, so the shadow follows the real
// silhouette -- two cards with a gap get two shadows and the gap keeps its
// wallpaper.
//
// ---------------------------------------------------------------------------
// SIZE COMES FROM THE CONTENT AND FROM NOWHERE ELSE
// ---------------------------------------------------------------------------
//
// The facade is a PanelWindow, not an Item, and it reads `implicitWidth` and
// `implicitHeight` off its Loader to decide how big a layer surface to ask
// for -- as a session high-water mark, so a popout never shrinks the window
// under a later one. Reporting nothing is not "the theme declined to draw":
// it is a window frozen at the `popoutMinWidth` floor with the content
// invisible inside it. Measured while this file was still the empty skeleton:
//
//     QSDBG open= true w= 340 h= 340 resW= 0 resH= 0
//
// And it has to come from the CONTENT: `root.width` is the Loader's width,
// which the facade sets from this file's `implicitWidth`. Reading it back is
// the loop rule 2 of themes/genesis/components/README.md is about.
//
// `row.topSlack` is not touched here on purpose. It is the facade's own
// arithmetic for the fillets that hide behind the bar, both ends of it are in
// components/Popout.qml, and under this theme it is 0 because
// `Theme.barCornerRadius` is 0 -- Windows rounds windows, not screens.

import QtQuick
import QtQuick.Effects
import qs.components
import qs.themes.windows

Item {
    id: root

    required property Popout row

    // THE GAP BETWEEN A FLYOUT AND THE TASKBAR, WHICH ONLY THIS FILE CAN LEAVE.
    //
    // The facade anchors its window to the bar's inner edge and puts the panel
    // hard against it: under a bottom bar `y: parent.height - height + slack`,
    // which with no fillets is flush. Windows does not draw it flush -- every
    // flyout in the reference set floats clear of the taskbar and clear of the
    // screen edge -- so the clearance has to be inside what this file reports,
    // and it is symmetric so that the clamp at the screen's right edge gets the
    // same air as the bar does.
    //
    // It is NOT room for the shadow, which was the first thing it was written
    // down as: see the note on the effect below for where the shadow ended up
    // and why it cannot use this gap.
    readonly property int inset: Fluent.flyoutInset

    implicitWidth: content.implicitWidth + root.inset * 2
    implicitHeight: content.implicitHeight + root.inset * 2

    // The flyout shadow, cast by whatever the content actually is. Elevation 32
    // in ElevationHelper terms; see Fluent.qml on where the blur and the offset
    // come from and on why dark mode's shadows are twice light mode's.
    //
    // `blurMax` is MultiEffect's own unit -- `shadowBlur` is a fraction of it --
    // so the pair below is the closest this gets to "16px of blur".
    //
    // `autoPaddingEnabled: false`, AND IT IS THE LINE THAT KEEPS THIS HONEST.
    // MultiEffect DOES NOT DRAW A SHADOW: it draws ITS SOURCE PLUS a shadow.
    // The copy is invisible only while it lands exactly on top of the real
    // item, and auto-padding grows the effect's bounds to fit the blur, which
    // moves it. Photographed with it on: every heading, every line of body
    // text and every number in the calendar carried a dimmer ghost of itself
    // about ten pixels up and to the left.
    //
    // WHAT THAT COSTS, SAID PLAINLY: the shadow now lives INSIDE the content's
    // own box. The halo around the outside of the flyout is gone, and what is
    // left is the part that falls on the theme's own transparent gaps -- under
    // the media card, into the space between two panels, around each rounded
    // corner. That is a smaller thing than Windows draws and it is what can be
    // had without a ghost.
    //
    // TWO OTHER WAYS WERE TRIED AND BOTH WERE WORSE, photographed each time.
    // `layer.effect: MultiEffect` on the Loader draws the content once and
    // does pad, so the outer halo comes back -- and every pixel of the flyout
    // came out three levels darker than the same run without it (32,32,32 ->
    // 29,29,32 on the notification centre's own card), because the effect
    // re-composites a texture that already has translucency flattened into it.
    // A hand-set `paddingRect` with matching negative margins moved the copy
    // instead of aligning it, in both signs. A shadow is not worth a colour
    // shift in a theme whose whole claim is that its colours are measured.
    MultiEffect {
        anchors.fill: content

        source: content
        visible: content.status === Loader.Ready

        autoPaddingEnabled: false
        blurMax: Fluent.flyoutShadowBlur
        shadowEnabled: true
        shadowBlur: 1.0
        shadowVerticalOffset: Fluent.flyoutShadowY
        shadowColor: Qt.rgba(0, 0, 0, Fluent.shadowOpacity)
    }

    Loader {
        id: content

        // Centred by construction: one inset on each side, and the root's
        // implicit size is the content plus both of them.
        x: root.inset
        y: root.inset

        width: content.implicitWidth
        height: content.implicitHeight

        // Nothing is built until something is opened, and closing takes it
        // down again -- the facade keeps the reservation, so a closed popout
        // costs a window and not a panel.
        active: root.row.isOpen
        sourceComponent: root.row.contentComponent

        // MultiEffect needs a texture to sample, and a Loader is not one
        // until it is layered. The effect above draws that texture a second
        // time, exactly on top of this one -- see the note on
        // `autoPaddingEnabled` for what happens when the two stop lining up.
        layer.enabled: true
    }
}
