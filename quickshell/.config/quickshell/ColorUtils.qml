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
}
