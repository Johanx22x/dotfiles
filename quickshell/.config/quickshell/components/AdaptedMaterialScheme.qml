// The media card's palette, derived from the cover art rather than from the
// wallpaper.
//
// Ported from end-4/dots-hyprland's modules/common/models/AdaptedMaterialScheme.qml.
// Their media card does not use the shell's colours: it pulls the dominant
// colour out of the album art with Quickshell's ColorQuantizer and blends
// every role it needs toward that colour. That is the single biggest reason
// their card looks the way it does, and the first port of this card left it
// out on the grounds that we did not have a quantizer. We do -- it ships in
// Quickshell 0.3.0 as Quickshell.ColorQuantizer -- so it is here.
//
// TWO SOURCES OF COLOUR ON ONE SCREEN, and this is the consequence worth
// knowing about. Everything else in this shell is matugen's palette, generated
// from the WALLPAPER and handed out by Theme. This object is generated from
// the COVER ART, so while music is playing the media card is deliberately not
// in the same palette as the panel it sits in. That is what their card does
// and it is what was asked for; it is not a bug to be reported later.
//
// EVERY BASE ROLE IS ONE OF OURS. Theirs blends against a Material layer model
// -- colLayer0, colLayer1, colOnLayer0 -- that this shell does not have, so
// each is mapped to the Theme role the card was already using for that job.
// The blend percentages are all theirs, unchanged, and they are the weight of
// the BASE, not of the cover: 0.15 means 85% cover art.
//
// A KNOWN DEFECT, COPIED ON PURPOSE. colSecondaryContainer takes 85% of the
// cover colour while colOnSecondaryContainer takes 50%, so on a cover of
// middling lightness the two converge and the glyph on the paused play button
// loses contrast against it. That is in the original and the instruction on
// this card was fidelity, so it is reproduced rather than quietly corrected.
// If it turns out to matter, the fix is to raise the 0.5 on
// colOnSecondaryContainer -- one number, right below.

import QtQuick
import "root:/"

QtObject {
    id: root

    // The cover's dominant colour, already pre-blended by the caller. See
    // where it is built in Dashboard.qml: it is NOT the quantizer's raw
    // output, and handing this the raw colour is what makes a ported card
    // look garish on a saturated cover.
    required property color color

    readonly property bool colorIsDark: root.color.hslLightness < 0.5

    // Whether the SHELL is dark, which is their m3colors.darkmode. Derived the
    // way they derive it, from the background's own lightness, because this
    // shell has no such flag.
    readonly property bool shellIsDark: Theme.surface.hslLightness < 0.5

    // ---- Surfaces ----
    //
    // colLayer0 is the card itself. The 0.6 rather than 0.5 for a dark cover
    // on a dark shell is theirs: it holds back the blend so a dark cover does
    // not sink the card into the panel behind it.
    readonly property color colLayer0: ColorUtils.mix(Theme.surfaceContainerHigh, root.color,
        (root.colorIsDark && root.shellIsDark) ? 0.6 : 0.5)

    // The square the cover sits in.
    readonly property color colLayer1: ColorUtils.mix(Theme.surfaceContainerHighest, root.color, 0.5)

    // ---- Text ----
    readonly property color colOnLayer0: ColorUtils.mix(Theme.textOnSurface, root.color, 0.5)
    readonly property color colOnLayer1: ColorUtils.mix(Theme.textOnSurfaceVariant, root.color, 0.5)

    // Artist and elapsed time. Theirs is the same formula as colOnLayer1 and
    // is kept as its own role because theirs is.
    readonly property color colSubtext: ColorUtils.mix(Theme.textOnSurfaceVariant, root.color, 0.5)

    // ---- Accent ----
    readonly property color colPrimary: ColorUtils.mix(
        ColorUtils.adaptToAccent(Theme.primary, root.color), root.color, 0.5)

    // Their colPrimaryHover is a Material role this shell does not generate.
    // The base is the shell's own idiom for a hovered accent, which is what
    // the media card was already using for this exact button.
    readonly property color colPrimaryHover: ColorUtils.mix(
        ColorUtils.adaptToAccent(Qt.lighter(Theme.primary, 1.15), root.color), root.color, 0.3)

    readonly property color colOnPrimary: ColorUtils.mix(
        ColorUtils.adaptToAccent(Theme.textOnPrimary, root.color), root.color, 0.5)

    // ---- Secondary container: the skip buttons and the paused play button ----
    //
    // 0.15, so 85% cover art -- the strongest tint in the set, and theirs.
    readonly property color colSecondaryContainer: ColorUtils.mix(Theme.secondaryContainer, root.color, 0.15)

    // Same substitution as colPrimaryHover: the base is this shell's existing
    // hover blend for a secondary container, then theirs at 0.3.
    readonly property color colSecondaryContainerHover: ColorUtils.mix(
        Qt.tint(Theme.secondaryContainer, Qt.alpha(Theme.textOnSecondaryContainer, 0.1)), root.color, 0.3)

    readonly property color colOnSecondaryContainer: ColorUtils.mix(Theme.textOnSecondaryContainer, root.color, 0.5)
}
