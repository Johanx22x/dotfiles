// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - design tokens
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// Material 3, and therefore the ONE exception to this setup's colour policy:
// everywhere else the background and the text are fixed Tokyo Night and only
// the accents follow the wallpaper (see the header of matugen's config.toml).
// Here the surfaces follow the image as well.
//
// That is safe on one condition: roles are always used in PAIRS. Text over a
// surface is on_surface, text over primary is on_primary, and so on. M3
// guarantees the contrast of each pair whatever the wallpaper is. Painting
// on_surface over primary, or a hardcoded hex over a generated surface, is
// what breaks it -- so don't.
//
// WHY colors.json AND NOT A GENERATED .qml
// Quickshell reloads the entire config whenever a .qml file changes. If
// matugen wrote a QML singleton, every wallpaper change would tear down and
// rebuild the shell: state lost and no way to animate the transition.
// Reading a JSON through FileView keeps the colours as ordinary properties
// that simply change value, so the Behaviors below fade them in sync with
// the wallpaper crossfade. The shell is never reloaded by a colour change.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---------------- Palette ----------------
    // Written by matugen on every wallpaper change, see [templates.quickshell]
    // in ~/.config/matugen/config.toml.
    //
    // The value after ?? is the fallback used when the file is not there yet
    // (fresh clone) or comes out malformed. They are Tokyo Night tones, so a
    // shell with no palette still looks deliberate rather than broken.
    //
    // NAMING: M3's foreground roles are on_surface, on_primary and so on, but
    // a QML property called `onSurface` is parsed as the signal handler for
    // `surfaceChanged`, and the file fails to load with "Cannot assign a
    // value to a signal". Hence textOnSurface, textOnPrimary... The JSON keys
    // below keep the M3 names; only the QML side is renamed.
    property color surface: palette.surface ?? "#1a1b26"
    property color surfaceContainer: palette.surface_container ?? "#292e42"
    property color surfaceContainerHigh: palette.surface_container_high ?? "#343a52"
    property color surfaceContainerHighest: palette.surface_container_highest ?? "#414868"
    property color textOnSurface: palette.on_surface ?? "#c0caf5"
    property color textOnSurfaceVariant: palette.on_surface_variant ?? "#a9b1d6"
    property color outline: palette.outline ?? "#565f89"
    property color outlineVariant: palette.outline_variant ?? "#3b4261"

    property color primary: palette.primary ?? "#7aa2f7"
    property color textOnPrimary: palette.on_primary ?? "#1a1b26"
    property color primaryContainer: palette.primary_container ?? "#3d59a1"
    property color textOnPrimaryContainer: palette.on_primary_container ?? "#c0caf5"

    property color secondary: palette.secondary ?? "#bb9af7"
    property color secondaryContainer: palette.secondary_container ?? "#414868"
    property color textOnSecondaryContainer: palette.on_secondary_container ?? "#c0caf5"

    property color tertiary: palette.tertiary ?? "#e0bbdd"
    property color textOnTertiary: palette.on_tertiary ?? "#1a1b26"

    // ---------------- Semantic, NOT from the wallpaper ----------------
    // Alerts keep their meaning across every wallpaper: amber is "watch out"
    // and red is "something is wrong". M3's error role would be tinted by the
    // image, and over a red wallpaper a critical warning would blend into the
    // rest of the bar. Same reasoning as the [config.custom_colors] comment
    // in matugen's config.toml.
    readonly property color warning: "#e0af68"
    readonly property color critical: "#f7768e"
    readonly property color textOnCritical: "#1a1b26"

    // ---------------- Transition ----------------
    // ZERO on purpose. This was 1400ms (matched to the wallpaper crossfade),
    // then 250ms, and both read as the bar playing an animation of its own.
    //
    // Measured end to end on a wallpaper change: matugen finishes writing
    // colors.json at ~0.48s, the FileView watcher fires ~0.14s after that,
    // and only THEN does any transition here start. Anything above zero is
    // added on top of a delay the shell does not control, which is why the
    // change felt slow no matter how short the animation got. The colours now
    // snap the instant the file is read.
    //
    // Raising this reintroduces the effect; it is not a "smoothness" knob.
    readonly property int recolorDuration: 0

    Behavior on surface { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on surfaceContainer { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on surfaceContainerHigh { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on surfaceContainerHighest { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on textOnSurface { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on textOnSurfaceVariant { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on outline { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on outlineVariant { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on primary { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on textOnPrimary { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on primaryContainer { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on textOnPrimaryContainer { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on secondary { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on secondaryContainer { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on textOnSecondaryContainer { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }
    Behavior on tertiary { ColorAnimation { duration: root.recolorDuration; easing.type: Easing.InOutQuad } }

    // ---------------- Glass ----------------
    // 0.85 is this setup's standard, the same figure waybar, wofi and dunst
    // use. The blur behind it is Hyprland's, applied per layer namespace in
    // hyprland.lua -- nothing here produces it.
    readonly property real glassAlpha: 0.85

    function glass(colour: color): color {
        return Qt.alpha(colour, root.glassAlpha);
    }

    // ---------------- Geometry ----------------
    // The bar is FLUSH: it sits on the screen edge with no margin and no
    // rounded corners, and spans the full width. That is also what lets it
    // reserve its own space -- a surface anchored to top+left+right is a
    // valid exclusive-zone request, which a floating island anchored to a
    // corner is not.
    readonly property int barHeight: 48

    // Horizontal padding at the very ends of the bar.
    readonly property int barPadding: 16

    // Space between the items inside one group.
    readonly property int itemSpacing: 9
    // Between groups within the same section (left / centre / right).
    readonly property int groupSpacing: 16

    // Groups that carry their own background are pills: a radius of half the
    // height. Their height is the bar's minus a little breathing room, so
    // they never touch the screen edge.
    readonly property int groupHeight: barHeight - 12
    readonly property int groupRadius: groupHeight / 2
    readonly property int groupPadding: 12

    // For surfaces that are not pills (popouts, notification cards): M3
    // "extra large" corner.
    readonly property int cardRadius: 24

    // ---------------- Notifications ----------------
    // Wide enough for a sentence of body text without wrapping every few
    // words, narrow enough not to cover the window under it.
    readonly property int notificationWidth: 420
    readonly property int notificationGap: 10
    // Breathing room between the cards and the edge of the panel holding them.
    readonly property int notificationPadding: 12
    readonly property int notificationRadius: 18
    readonly property int notificationIconSize: 38

    // Floor for a popout's width. A tray menu with two short entries would
    // otherwise come out as a sliver hanging off the bar.
    readonly property int popoutMinWidth: 220

    // ---------------- Type ----------------
    // POINTS, not pixels, and that is the whole point: kitty.conf says
    // `font_size 11.0`, and kitty measures in points. Sizing the bar in
    // pixels would only match at one particular DPI and drift apart at any
    // other, so the shell asks for the same 11pt the terminal does and lets
    // Qt do the conversion. Change it here only if kitty changes.
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property real fontSize: 11
    readonly property int fontWeight: Font.DemiBold

    // Glyph size for the Nerd Font pictograms, also in points. Two points
    // over the text: a pictogram drawn inside the same em box as a letter
    // reads smaller than the letter does, and matching the numbers would
    // make the icons look undersized next to their own labels.
    readonly property real iconSize: 13

    // The Arch mark on its own: it is the only logo on the bar and it reads
    // smaller than a pictogram at the same size because of how much fine
    // detail it packs.
    readonly property real logoSize: 19

    // Size in PIXELS for real images -- tray icons and application icons.
    // These are bitmaps, not glyphs: they are asked for at the exact pixel
    // size they will be painted at, so the icon theme can hand over the
    // right variant instead of scaling one.
    readonly property int imageSize: 20

    // ---------------- Screen edge ----------------
    // The rounded corners of the display itself, see
    // components/ScreenCorner.qml. Black rather than a palette role: it
    // stands in for the panel bezel, and a bezel does not change colour with
    // the wallpaper.
    readonly property int screenCornerRadius: 10

    // The concave fillet where the bar meets the left and right edges of the
    // screen, so the bar flows down into the side instead of ending in a
    // hard step. Drawn in the bar's own colour, inside the bar's surface.
    // The same 10 as screenCornerRadius above and as `rounding` in
    // hyprland.lua. These three are one decision, not three: they are the
    // radii that touch each other on screen.
    //
    // 10 because that is what applications round their own content at --
    // measured on Zen, ~10 px -- and at 24 the compositor's curve sat
    // visibly outside the app's, two arcs disagreeing on every window. The
    // window radius is what leads here; these two follow so the edges keep
    // agreeing.
    //
    // Known cost, do not rediscover it: a concave fillet only has as many
    // pixel rows as its radius to spread its antialiasing over, so at 10 it
    // shades more coarsely than at 24 did. That is the trade. If it reads
    // jagged, the fix is a bigger radius in all three places at once.
    readonly property int barCornerRadius: 10
    readonly property color screenBezel: "#000000"

    // ---------------- Motion ----------------
    // M3 "standard" easing for interface movement, distinct from the slow
    // recolour above.
    readonly property int animDuration: 220

    // ---------------- Palette source ----------------
    // watchChanges does NOT re-read the file by itself: all it does is emit
    // fileChanged(). Reloading is the handler's job, and without the line
    // below the shell reads the palette once at startup and never again --
    // which is exactly how it behaved until this was found: colors.json
    // changed on every wallpaper, the bar stayed the colour it booted with.
    //
    // Once reloaded, text() re-evaluates the binding underneath, so the
    // colours move without the shell being restarted.
    FileView {
        id: paletteFile
        // shellPath and not configPath: the latter is deprecated in 0.3.0.
        path: Quickshell.shellPath("colors.json")
        watchChanges: true
        onFileChanged: reload()
        // Silent: the fallbacks above already cover a missing file, and a
        // first run before any wallpaper change is not an error worth
        // printing on every launch.
        printErrors: false
    }

    readonly property var palette: {
        try {
            return JSON.parse(paletteFile.text() || "{}");
        } catch (e) {
            // Malformed JSON: matugen caught mid-write, or a broken template.
            // Keeping the last good colours beats blanking the shell.
            console.warn("Theme: could not parse colors.json --", e.message);
            return {};
        }
    }
}
