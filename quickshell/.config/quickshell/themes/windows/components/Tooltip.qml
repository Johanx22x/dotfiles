// THE ONE FLAT, OPAQUE SURFACE IN THE WHOLE SYSTEM.
//
// Everything else this theme draws is acrylic or mica over something: the bar
// carries the wallpaper's colour, a flyout stays a solid-ish grey with a hint
// of it. A tooltip carries none of it. In ref/tooltip-tray-battery.jpg the
// wallpaper two pixels away is bright purple and the note over it samples
// #2c2c2c flat, corner to corner, with no tint, no gradient and no visible
// border -- and ref/tooltip-hovercard-button.jpg, a completely different build
// and context, shows the same thing beside a bright blue.
//
// #2c2c2c is `Theme.surfaceContainer` in this scheme (#2b2b2b), so that is
// what is used. WinUI's own answer is AcrylicInAppFillColorDefault, which is
// the recipe that COMPOSITES to that colour; taking it literally and blurring
// the desktop through a tooltip is how a recreation ends up with the one
// surface in Windows that is flat being the one surface in the theme that
// moves.
//
// RADIUS 4 AND NOT 8, which is Microsoft's own documented exception -- the
// tooltip is small enough that the overlay radius reads as a lozenge. It is
// `Fluent.tooltipRadius` so that a reader does not have to wonder whether the
// tooltip was simply forgotten when the other flyouts were done.
//
// PADDING 9,6,9,8 and font size 12 are ToolTip_themeresources.xaml verbatim
// (ToolTipBorderPadding, ToolTipContentThemeFontSize), and the facade's
// `maxWidth` default of 320 is ToolTipMaxWidth to the pixel -- the two sides of
// this seam agree on that number by accident of both having read the same
// source, which is worth knowing before somebody "fixes" one of them.
//
// ---------------------------------------------------------------------------
// WHAT THIS FILE IS NOT ALLOWED TO DECIDE
// ---------------------------------------------------------------------------
//
// WHERE IT GOES. components/Tooltip.qml walks up to the nearest clipping
// ancestor, works out whether the note fits below its anchor or has to flip
// above it, and raises the z of everything in between so it is not clipped by
// a sibling. All of that reads `root.height` -- this file's `implicitHeight`
// coming back down -- so the height reported here has to be the REAL height of
// the drawn box and must not be floored, padded or rounded up to a row. A
// tooltip that reports more than it draws flips early and hangs in the air.
//
// AND `implicitHeight` IS THE NAME THAT MATTERS. Rule 2 of
// themes/genesis/components/README.md lets a component report a width too when
// no parent sizes itself from it, and a note has no column, so the width is
// here as well -- but the flip arithmetic reads the height, so that is the one
// that must be exact rather than merely present.

import QtQuick
import QtQuick.Effects
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property Tooltip row

    // ToolTipBorderPadding, 9,6,9,8.
    readonly property int padH: 9
    readonly property int padTop: 6
    readonly property int padBottom: 8

    implicitWidth: label.width + root.padH * 2
    implicitHeight: label.height + root.padTop + root.padBottom

    // The shadow, cast by the box and not by this item, so it follows the
    // rounded corners. ElevationHelper puts a tooltip at depth 16, which
    // DropShadowRecipe.h turns into an 8px blur offset 4 down at 26% black in
    // dark mode -- half the flyout's, twice a light theme's.
    //
    // The reference calls the result "no obvious drop shadow", and that is the
    // intended amount: it is what stops a flat grey box on a flat grey window
    // from disappearing into it, and nothing more.
    MultiEffect {
        anchors.fill: box

        source: box

        // False, and for the reason components/Popout.qml sets out at length:
        // MultiEffect draws its SOURCE plus a shadow, so the copy is invisible
        // only while it sits exactly under the real box, and auto-padding
        // moves it by the padding it adds.
        autoPaddingEnabled: false
        blurMax: Fluent.tooltipShadowBlur
        shadowEnabled: true
        shadowBlur: 1.0
        shadowVerticalOffset: Fluent.tooltipShadowY
        shadowColor: Qt.rgba(0, 0, 0, Fluent.shadowOpacity)
    }

    Rectangle {
        id: box

        anchors.fill: parent

        radius: Fluent.tooltipRadius
        antialiasing: true

        color: Theme.surfaceContainer

        // No border. WinUI names one -- SurfaceStrokeColorFlyout at a single
        // pixel -- and neither photograph shows an edge of any kind, on either
        // of the two backgrounds. Nothing is drawn that cannot be seen.

        layer.enabled: true

        Text {
            id: label

            x: root.padH
            y: root.padTop

            // The cap is the facade's `maxWidth`, and the wrap is what makes a
            // paragraph-length note -- the keybinds page hands this one five
            // sentences -- a block instead of a line off the side of the
            // screen. `implicitWidth` is still the unwrapped width, so a short
            // note stays exactly as wide as its words.
            width: Math.min(label.implicitWidth, root.row.maxWidth - root.padH * 2)
            wrapMode: Text.Wrap

            text: root.row.text

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            lineHeight: Fluent.captionLineRatio
            lineHeightMode: Text.ProportionalHeight

            color: Theme.textOnSurface
        }
    }
}
