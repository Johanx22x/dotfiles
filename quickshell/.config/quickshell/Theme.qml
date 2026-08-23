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
//
// AND THE SAME REASONING IS WHY THE THEME'S TOKENS ARE JSON TOO
// The sizes below -- the bar's height, the pill radius, the notification card
// -- are the THEME's decisions and stopped being constants in this file: they
// come out of themes/<name>/theme.json, read through a FileView of their own.
// A .qml full of the same numbers would have cost the reload the palette
// avoids, and it would have cost it at the one moment the shell is expected to
// restyle itself without being torn down -- a theme SWITCH, where the surfaces
// are rebuilt out of the new directory with no config reload (see the header of
// modules/Themes.qml). The tokens follow the switch the same way, by changing
// value under the bindings that read them.
//
// WHAT IS A TOKEN AND WHAT IS NOT, because the line is the whole design.
// A number here is either the theme's own decision or a CONSEQUENCE of one, and
// only the first kind is in the JSON. groupRadius is half groupHeight because
// that is what a pill IS; iconSize is fontSize + 2 for the reason written where
// it is derived. Handing a consequence to the JSON would not make a theme more
// expressive, it would give it a second place to disagree with itself.
//
// Three values are not the theme's at all. fontFamily and fontSize are the
// user's, written by `desktop-font` and shared with kitty; glassAlpha is
// Config.opacity, shared with kitty, Zen and the compositor. They keep coming
// from Config, and a theme.json that names them is ignored -- see the notes
// where each of them is read.
//
// WHAT THIS BUYS BEYOND THEMES, and it is the case that proves the mechanism.
// components/SectionNote.qml is a Text whose defaults are Theme.fontSize - 1,
// Theme.textOnSurfaceVariant and Theme.groupPadding. A Loader cannot re-base a
// Text, so that component can never be handed to a theme through a facade the
// way a window can -- and it does not need one: the tokens it reads are the
// theme's now, so it follows the theme without knowing a theme exists.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
// For Themes.name -- the theme actually being DRAWN, which is not always the
// one Config names: a manifest that cannot be read falls back to the shipped
// theme, and the tokens have to fall back with the surfaces rather than dress
// one theme's windows in another's geometry.
//
// This is an import cycle on paper -- modules/Themes.qml imports qs for Config,
// and Config lives next to this file -- and it resolves, in qmllint and in a
// loaded shell alike. QML imports are namespaces rather than initialisation
// order; what would actually break is a singleton READING another one at
// construction time, and neither of these does.
import qs.modules

Singleton {
    id: root

    // THE THEME BEING DRAWN, named once here and read by the two FileViews at
    // the bottom that go looking inside its directory. Themes.name is already
    // the answer to "which theme, fallback included"; working it out again here
    // would be a second place for this file to get it wrong.
    //
    // AND IT HAS TO BE A PROPERTY. Both uses below are inside template literals,
    // and qmllint does not look inside one when it decides whether an import was
    // used: spelling `Themes.name` straight into the path makes `import
    // qs.modules` above an "unused import" and turns tests/qml-lint.sh red on a
    // file that is perfectly correct. Reading it once out here is what the
    // linter can see.
    readonly property string themeName: Themes.name

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
    // It is the THEME's to raise, now that motion is a token -- genesis keeps
    // the measured zero, and a theme that sets anything else is choosing the
    // effect rather than discovering it.
    readonly property int recolorDuration: root.token("recolorDuration", 0)

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
    // use. The blur behind it is the compositor's, but WHERE it goes is this
    // shell's own doing now: every glass surface names its blur region through
    // the compositor, which under Hyprland is a layerrule with ignore_alpha and
    // its siblings), and both compositors honour it. Under Hyprland the
    // blur-quickshell rule in hyprland.lua still picks the parameters, and one
    // of them -- ignore_alpha at 0.84 -- is tied to the number below: it drops
    // anything more transparent than that out of the blur, so an alpha chosen
    // under it there would come out flat rather than frosted.
    //
    // THE ONE VALUE IN THIS FILE THAT IS A PREFERENCE and not a decision, so
    // it is the one that comes from Config rather than being written here.
    // The 0.85 still lives in Config.qml, as its default -- and it is no
    // longer only the shell's: kitty, Zen and Hyprland's window rules read
    // the same number now, through the `desktop-opacity` script.
    //
    // Note what this buys, and it is the whole reason the settings window
    // sits in the shell process: glass() is called inside bindings all over
    // the shell, so those bindings capture this property as a dependency and
    // re-evaluate the moment it changes. The bar restyles itself while the
    // number is still moving under the pointer.
    //
    // NOT A TOKEN for exactly that reason: four programs share this number and
    // only one of them can read a theme. A theme.json that names it is ignored.
    readonly property real glassAlpha: Config.opacity

    function glass(colour: color): color {
        return Qt.alpha(colour, root.glassAlpha);
    }

    // ---------------- Geometry ----------------
    // The bar is FLUSH: it sits on the screen edge with no margin and no
    // rounded corners, and spans the full width. That is also what lets it
    // reserve its own space -- a surface anchored to top+left+right is a
    // valid exclusive-zone request, which a floating island anchored to a
    // corner is not.
    readonly property int barHeight: root.token("barHeight", 48)

    // Horizontal padding at the very ends of the bar.
    readonly property int barPadding: root.token("barPadding", 16)

    // Space between the items inside one group.
    readonly property int itemSpacing: root.token("itemSpacing", 9)
    // Between groups within the same section (left / centre / right).
    readonly property int groupSpacing: root.token("groupSpacing", 16)

    // Groups that carry their own background are pills: a radius of half the
    // height. Their height is the bar's minus a little breathing room, so
    // they never touch the screen edge.
    //
    // BOTH DERIVED AND NEITHER IS A TOKEN. A pill is half its own height by
    // definition, and a group that stopped following the bar would stop
    // clearing the edge the sentence above promises it clears. A theme moves
    // this pair by moving barHeight, which is the only number in it that is a
    // decision rather than a consequence.
    readonly property int groupHeight: root.barHeight - 12
    readonly property int groupRadius: root.groupHeight / 2
    readonly property int groupPadding: root.token("groupPadding", 12)

    // For surfaces that are not pills (popouts, notification cards): M3
    // "extra large" corner.
    readonly property int cardRadius: root.token("cardRadius", 24)

    // ---------------- Notifications ----------------
    // Wide enough for a sentence of body text without wrapping every few
    // words, narrow enough not to cover the window under it.
    readonly property int notificationWidth: root.token("notificationWidth", 420)
    readonly property int notificationGap: root.token("notificationGap", 10)
    // Breathing room between the cards and the edge of the panel holding them.
    readonly property int notificationPadding: root.token("notificationPadding", 12)
    readonly property int notificationRadius: root.token("notificationRadius", 18)
    readonly property int notificationIconSize: root.token("notificationIconSize", 38)

    // Floor for a popout's width. A tray menu with two short entries would
    // otherwise come out as a sliver hanging off the bar.
    readonly property int popoutMinWidth: root.token("popoutMinWidth", 220)

    // ---------------- Type ----------------
    // POINTS, not pixels, and that is the whole point: kitty.conf says
    // `font_size 11.0`, and kitty measures in points. Sizing the bar in
    // pixels would only match at one particular DPI and drift apart at any
    // other, so the shell asks for the same 11pt the terminal does and lets
    // Qt do the conversion. Change it here only if kitty changes.
    // FAMILY AND SIZE COME FROM Config NOW, and the note above is the reason
    // rather than an argument against it: the pair was one decision shared
    // with kitty, remembered by a comment. It still is one decision -- the
    // `desktop-font` script writes both -- but the remembering is mechanical.
    //
    // The family is restricted to the Nerd Font variants at the setting, not
    // here, because the reason is not about type: every glyph this shell
    // draws is a Nerd Font codepoint rendered as text in THIS property. Point
    // it anywhere else and the bar fills with tofu.
    //
    // NEITHER IS A TOKEN, and the paragraph above is the reason rather than an
    // oversight: they are one decision shared with a program that has never
    // heard of a theme. A theme.json that names them is ignored.
    readonly property string fontFamily: Config.fontFamily
    readonly property real fontSize: Config.fontSize

    // The weight every label the shell draws is asked for at. Qt's 100-900
    // scale, so 600 is DemiBold -- and the fallback says `Font.DemiBold` rather
    // than 600 so that a theme.json without it lands on the enum instead of on
    // a number somebody has to recognise.
    readonly property int fontWeight: root.token("fontWeight", Font.DemiBold)

    // Glyph size for the Nerd Font pictograms, also in points. Two points
    // over the text: a pictogram drawn inside the same em box as a letter
    // reads smaller than the letter does, and matching the numbers would
    // make the icons look undersized next to their own labels.
    // DERIVED, not a second setting. It was 13 next to a fontSize of 11, and
    // the two points between them are the whole reason it exists -- a
    // pictogram drawn in the same em box as a letter reads smaller than the
    // letter. Leaving it a constant while the size moved would have made the
    // icons shrink relative to their own labels at every step.
    readonly property real iconSize: root.fontSize + 2

    // The Arch mark on its own: it is the only logo on the bar and it reads
    // smaller than a pictogram at the same size because of how much fine
    // detail it packs.
    // Also derived, at the ratio it had when both were constants (19/11).
    // Rounded, because a glyph asked for at 20.7pt is a glyph rendered at a
    // size no hinting was done for.
    readonly property real logoSize: Math.round(root.fontSize * 1.73)

    // The shell's own controls -- the settings and power buttons. Between the
    // two above, and for the same reason each of those exists: a control has
    // to invite a click, which a reading's glyph does not, but it is not the
    // lone mark the logo is either. At iconSize the pair read as two more
    // readings that happened to get a pill; at logoSize they dwarfed the
    // clock's glyphs one group over.
    // Derived like the rest, so it tracks the font setting.
    readonly property real controlSize: root.iconSize + 3

    // Size in PIXELS for real images -- tray icons and application icons.
    // These are bitmaps, not glyphs: they are asked for at the exact pixel
    // size they will be painted at, so the icon theme can hand over the
    // right variant instead of scaling one.
    readonly property int imageSize: root.token("imageSize", 20)

    // ---------------- Screen edge ----------------
    // The rounded corners of the display itself, see
    // components/ScreenCorner.qml. Black rather than a palette role: it
    // stands in for the panel bezel, and a bezel does not change colour with
    // the wallpaper.
    readonly property int screenCornerRadius: root.token("screenCornerRadius", 10)

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
    //
    // DERIVED, and that is what "one decision" means here. Two constants that
    // happened to read 10 were two chances for a theme to make them disagree,
    // and the paragraph above spends nine lines saying they must not. The third
    // of the three -- `rounding` in hyprland.lua -- is outside this shell and
    // outside a theme's reach; tying together the two that are inside it is
    // what this file can do about that, and moving the pair means moving
    // screenCornerRadius.
    readonly property int barCornerRadius: root.screenCornerRadius
    readonly property color screenBezel: "#000000"

    // ---------------- Motion ----------------
    // M3 "standard" easing for interface movement, distinct from the slow
    // recolour above.
    readonly property int animDuration: root.token("animDuration", 220)

    // ---------------- What the theme declares about the palette ----------------
    // IT DECLARES WHERE THE COLOURS COME FROM, in its manifest:
    //
    //     "palette": { "source": "scheme" }
    //
    // "scheme" is the one value this shell implements and it is exactly what
    // the header describes: the generated palette, rewritten by matugen on
    // every wallpaper change and followed live. A manifest that says nothing
    // gets it, which is what keeps a theme written before this key existed
    // working unchanged.
    //
    // The other half of the decision -- a theme that does NOT follow the
    // wallpaper -- is designed as "pinned" and is not built here. The seam it
    // needs is palettePath below and nothing else in this file.
    readonly property string defaultPaletteSource: "scheme"

    // Not readonly: the manifest is read asynchronously and this is what the
    // read lands on. It sits at the default until then, and a manifest that
    // cannot be read or asks for something unknown leaves it there.
    property string paletteSource: root.defaultPaletteSource

    function adoptManifest(text: string): void {
        let manifest = null;

        try {
            manifest = JSON.parse(text);
        } catch (error) {
            // Silent on purpose: modules/Themes.qml reads the same file, says
            // this out loud and falls back to the shipped theme. A second
            // warning about one broken manifest is noise.
            root.paletteSource = root.defaultPaletteSource;
            return;
        }

        const declared = manifest && manifest.palette ? manifest.palette.source : undefined;

        if (declared === undefined) {
            root.paletteSource = root.defaultPaletteSource;
            return;
        }

        if (declared !== "scheme") {
            console.warn(`Theme: ${root.themeName} asks for a palette source called "${declared}", which this shell does not know -- reading the scheme`);
            root.paletteSource = root.defaultPaletteSource;
            return;
        }

        root.paletteSource = declared;
    }

    // ONE VALUE AND A SWITCH ANYWAY, because the switch is the seam: "pinned"
    // is one more case returning a path inside the theme directory, and every
    // line below it already handles a palette that changes file.
    readonly property string palettePath: {
        switch (root.paletteSource) {
        case "scheme":
        default:
            // shellPath and not configPath: the latter is deprecated in 0.3.0.
            return Quickshell.shellPath("colors.json");
        }
    }

    // FOLLOWS Themes.name AND NOT Config.theme, unlike the manifest read in
    // modules/Themes.qml, and the two are right for opposite reasons. That one
    // watches the SETTING so that correcting a typo re-reads a manifest; this
    // one watches what is being DRAWN, so a refused theme's manifest never gets
    // to say where the colours of the theme drawn in its place come from.
    FileView {
        id: manifestFile

        path: Quickshell.shellPath(`themes/${root.themeName}/manifest.json`)
        printErrors: false

        onLoaded: root.adoptManifest(manifestFile.text())
        onLoadFailed: root.paletteSource = root.defaultPaletteSource
    }

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
        path: root.palettePath
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

    // ---------------- Token source ----------------
    // themes/<name>/theme.json, the same shape of file as the palette and read
    // the same way, so that a theme switch restyles the shell instead of
    // reloading it. Its keys are the property names above; every one of them is
    // optional and the fallback written at each site is genesis's value, so a
    // theme.json with three keys in it is a theme that changed three things.
    //
    // NO watchChanges, unlike the palette, and the difference is the file's own
    // habits rather than a rule. colors.json is rewritten several times a day
    // by a program the shell does not control, so not watching it was a real
    // bug. theme.json changes when somebody edits a theme, and an edit under
    // themes/ already needs the restart modules/Themes.qml documents -- a token
    // that reloaded live while the QML around it did not would be half an edit
    // landing, which is worse than none.
    //
    // blockLoading, which the palette does not use, and this is the reason:
    // colours arriving a frame late fade in and nobody sees it, while GEOMETRY
    // arriving a frame late is a bar that resizes itself in front of you at
    // every login. text() below performs the read synchronously the first time
    // it is called, so the first frame is already the theme's.
    FileView {
        id: tokenFile

        path: Quickshell.shellPath(`themes/${root.themeName}/theme.json`)
        blockLoading: true
        // Silent for the same reason the palette is: every token has a
        // fallback, so a theme that ships no theme.json is a theme that
        // accepted every default rather than a theme that is broken.
        printErrors: false
    }

    readonly property var tokens: {
        try {
            const parsed = JSON.parse(tokenFile.text() || "{}");
            // `null`, `7` and `"nope"` are all valid JSON and none of them is a
            // set of tokens. Indexing the first would throw inside a binding
            // that every file drawing anything depends on; the others quietly
            // answer undefined to everything, which the fallbacks handle.
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (e) {
            // Malformed JSON: a theme edited by hand and saved mid-thought.
            // Falling back to the whole set beats a shell with no geometry.
            console.warn("Theme: could not parse theme.json --", e.message);
            return {};
        }
    }

    // ONE TOKEN, WITH ITS FALLBACK WRITTEN AT THE SITE THAT USES IT, which is
    // what keeps every number above next to the paragraph explaining it.
    //
    // THE TYPE CHECK IS NOT DEFENSIVENESS. `??` alone would pass a string or a
    // null straight into an int property: "48px" becomes 0, and a barHeight of
    // 0 is a desktop with no bar and no way back to the setting. A token that
    // is present but is not a finite number is a token the theme got wrong, and
    // the right answer to that is the same as for a missing one.
    //
    // Called from inside bindings, which is what makes it live: reading
    // root.tokens here registers it as a dependency of every property above, so
    // a theme switch moves all of them at once. Same mechanism as glass().
    function token(key: string, fallback: real): real {
        const value = root.tokens[key];
        return typeof value === "number" && isFinite(value) ? value : fallback;
    }
}
