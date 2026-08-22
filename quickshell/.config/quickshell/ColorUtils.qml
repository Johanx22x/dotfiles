// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - blending colours
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// This shell had no colour arithmetic before the media card, and did not need
// any: Theme hands out finished roles and the call sites reach for Qt.alpha,
// Qt.tint or Qt.lighter when they want a hover state. That is still the right
// answer for one-off adjustments and nothing here replaces it.
//
// What needed more was the media card, which derives a WHOLE palette from the
// dominant colour of the cover art -- see components/AdaptedMaterialScheme.qml.
// Doing that with Qt.tint at each call site does not work, because Qt.tint
// composites and the derivation has to lerp, including through alpha, and
// because `adaptToAccent` below has no Qt.* equivalent at all.
//
// Ported from end-4/dots-hyprland's modules/common/functions/ColorUtils.qml,
// which is where the media card being copied gets these. Only the four the
// card actually uses are here; the rest of theirs can be added if something
// asks for it.
//
// ONE FUNCTION AT THE BOTTOM IS NOT THEIRS and says so where it is. It is
// here rather than in a caller because two different surfaces now need the
// same answer to the same question, and a legibility rule with two copies is
// a legibility rule that will eventually have two answers.
//
// KEPT OUT OF Theme.qml deliberately. Theme is the tokens -- what the palette
// IS -- and it is generated from the wallpaper. This is arithmetic on colours
// and has no opinion about where they came from. Theme.glass() is the one
// blend that lives over there, and it is there because it is about this
// shell's own surfaces rather than about colour in general.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // A LINEAR BLEND, and the percentage is the weight of the FIRST argument.
    //
    // That is theirs and it reads backwards, so it is worth stating plainly:
    // mix(a, b, 0.15) is 15% a and 85% b. Their scheme leans on it -- the
    // secondary container is written mix(container, cover, 0.15), which is
    // 85% cover art.
    //
    // Alpha is lerped with the channels, which matters: blending an opaque
    // role with a translucent one gives something part-translucent. Their card
    // works around that by forcing alpha back to 1 where it needs opacity.
    function mix(color1: color, color2: color, percentage: real): color {
        const c1 = Qt.color(color1);
        const c2 = Qt.color(color2);
        return Qt.rgba(
            percentage * c1.r + (1 - percentage) * c2.r,
            percentage * c1.g + (1 - percentage) * c2.g,
            percentage * c1.b + (1 - percentage) * c2.b,
            percentage * c1.a + (1 - percentage) * c2.a);
    }

    // HUE AND SATURATION FROM THE ACCENT, LIGHTNESS AND ALPHA FROM THE ROLE.
    //
    // This is the one with no Qt.* equivalent and the one that makes the
    // derived palette legible: a role keeps the weight it was designed to have
    // -- a foreground stays a foreground -- while moving onto the cover art's
    // hue. Compositing instead of this is what turns text the same colour as
    // the thing it is written on.
    function adaptToAccent(color1: color, color2: color): color {
        const c1 = Qt.color(color1);
        const c2 = Qt.color(color2);
        return Qt.hsla(c2.hslHue, c2.hslSaturation, c1.hslLightness, c1.a);
    }

    // MULTIPLIES the existing alpha by (1 - percentage) rather than setting
    // it, which is theirs. transparentize(c, 1) is therefore fully
    // transparent, and that is how their skip buttons get an invisible resting
    // background.
    function transparentize(colour: color, percentage: real): color {
        const c = Qt.color(colour);
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - percentage));
    }

    // Sets alpha outright, clamped. Qt.alpha does the same thing and is what
    // the rest of this shell uses; this exists so the ported scheme can be
    // read against theirs line by line.
    function applyAlpha(colour: color, alpha: real): color {
        const c = Qt.color(colour);
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha)));
    }

    // ---- OURS, NOT THEIRS: how dark a scrim has to be to read on ----
    //
    // Both the dashboard and the island draw white type over a picture
    // somebody else chose -- the cover art, or the wallpaper behind it -- and
    // a fixed scrim opacity cannot serve a black album sleeve and a white one
    // at once. So the scrim is measured: a ColorQuantizer reduces the picture
    // to a single colour, and this turns that colour into how much black has
    // to go over it.
    //
    // TAKES THE QUANTIZER'S LIST AND NOT A COLOUR, because "no measurement"
    // is a real case with a different answer and passing a fallback colour
    // would hide it. ColorQuantizer reads LOCAL FILES ONLY -- its source is
    // `QImage(source.toLocalFile())` in Quickshell's
    // src/core/colorquantizer.cpp, with no network code near it -- so an
    // https cover or a YouTube thumbnail yields an empty list.
    //
    // WITH NOTHING MEASURED it returns 0.62 rather than the middle of the
    // range. The safe assumption about a picture you cannot see is that it is
    // bright: being wrong that way costs a dark panel, being wrong the other
    // way costs a panel you cannot read.
    //
    // RELATIVE LUMINANCE AND NOT `hslLightness`, because the question is
    // whether white type will read and a saturated blue and a saturated
    // yellow at equal HSL lightness are nowhere near equally bright to look
    // at. These are the sRGB coefficients without the gamma linearisation --
    // an approximation, and an approximation is enough to choose between 0.30
    // and 0.74.
    function scrimFor(quantized: var): real {
        if (!quantized || quantized.length === 0)
            return 0.62;

        const c = Qt.color(quantized[0]);
        const luminance = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return Math.max(0.3, Math.min(0.74, 0.3 + 0.45 * luminance));
    }
}
