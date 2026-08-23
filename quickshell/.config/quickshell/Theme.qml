// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - design tokens
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// Material 3 role NAMES, on this setup's ordinary colour policy and no longer
// an exception to it. The two axes are the ones every other application here
// follows (see the header of matugen's config.toml): SURFACES, TEXT and
// OUTLINES come from the scheme and hold still for as long as the scheme does;
// ACCENTS come from the wallpaper and are regenerated on every change. What
// arrives under an M3 name below is one or the other:
//
//   from the SCHEME    surface, surface_container, surface_container_high,
//                      surface_container_highest, on_surface,
//                      on_surface_variant, outline, outline_variant -- eight
//                      M3 names filled from ui_* roles, plus warning, critical
//                      and on_critical from sem_*.
//   from the WALLPAPER primary, on_primary, primary_container,
//                      on_primary_container, secondary, secondary_container,
//                      on_secondary_container, tertiary, on_tertiary. Nine,
//                      and they are the whole of what the image still decides.
//
// THIS FILE'S HEADER USED TO CLAIM THE OPPOSITE and the claim is worth keeping
// because the argument under it was good and the facts moved. It said: the
// shell is the ONE exception, everywhere else the base is fixed Tokyo Night and
// only the accents follow the image, here the surfaces follow it as well -- and
// that is safe because M3 GUARANTEES the contrast of each role pair whatever
// the wallpaper is. Sound, while the alternative was a base nobody could ever
// change. It stopped being sound when the base became the user's to pick:
// desktop-scheme moves GTK, Qt, kitty and zathura, and leaving this one alone
// meant choosing a scheme restyled the whole desktop except the part of it this
// repository draws.
//
// SO THE RULE SURVIVES AND ITS GUARANTEE DID NOT. Roles are still always used
// in PAIRS: text over a surface is on_surface, text over primary is on_primary,
// and so on. Painting on_surface over primary, or a hardcoded hex over a
// generated surface, is still what breaks it -- so don't. What changed is what
// the pairing is worth. On the accent side it is still M3's per-wallpaper
// guarantee. On the scheme side the pairs are the SCHEME's, and their contrast
// is MEASURED -- once, by hand, when the scheme is written -- rather than
// derived. That is a weaker promise and it is the reason the rule matters more
// now than it did, not less: a guaranteed pair tolerates being taken apart and
// a measured one does not, because nothing recomputes it when a wallpaper
// lands. Pair them and the measurement holds; mix them and there is no
// mechanism left to catch you.
//
// The same policy, and the same history, is written from the other side in the
// _policy key of matugen's quickshell-colors.json template -- which is the file
// that fills the eight names above from ui_* roles.
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
// Three values are not the theme's TO PUT IN theme.json. fontSize is the
// user's, written by `desktop-font` and shared with kitty; glassAlpha is
// Config.opacity, shared with kitty, Zen and the compositor; fontFamily is the
// user's too by default, and is the one of the three a theme can take, in its
// MANIFEST rather than here -- because "which family draws me" is a claim a
// theme makes about itself and not a number it picks. A theme.json that names
// any of the three is ignored -- see the notes where each of them is read.
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
    // AND EVERY ONE OF THEM IS A VALUE OF schemes/tokyo-night.json. That is the
    // rule for what may stand after a ?? in this file, and it is checkable:
    // each literal below is that scheme's `fb_*` role of the same name (the
    // three alerts further down are its `sem_*` ones), so a colour here can be
    // looked up rather than taken on trust. Two had drifted off it and were
    // nobody's colour -- surfaceContainerHigh read #343a52 and tertiary read
    // #e0bbdd, which is not in the Tokyo Night palette at all and is not in any
    // scheme file. A literal no scheme contains is a colour nothing can check.
    //
    // TOKYO NIGHT AND NOT "SOME DARK BLUE", because tokyo-night is the scheme
    // in force in every state where this fallback can be seen: `desktop-scheme`
    // answers DEFAULT_SCHEME when its state file says nothing (Config.qml
    // repeats the same default at :440), and a machine that has selected any
    // other scheme selected it through `desktop-scheme set`, which re-renders
    // and therefore leaves a colors.json behind. The fallback and the default
    // scheme are one decision, so they are the same colours.
    //
    // ONE STATE CAN STILL DISAGREE and it is worth knowing rather than
    // pretending away: the scheme is remembered in ~/.local/state, colors.json
    // is generated into the checkout and gitignored, so a re-clone (or a wiped
    // ~/.config) on a machine that had picked Gruvbox boots this Tokyo Night
    // fallback over a Gruvbox base until the first wallpaper change. Both
    // compositors run `wallpaper-switch reapply` at startup, so that window is
    // the length of one render -- unless the wallpaper directory is empty, the
    // case lib/units/80-palette.sh fails by design, where it lasts the session.
    // Closing it means the shell READING the scheme, which is the paragraph
    // below.
    //
    // WHY LITERALS AND NOT A READ OF THE SCHEME'S OWN `fb_*` BLOCK. That block
    // is not unread -- `desktop-scheme` builds the entire accent import out of
    // it for `accent scheme`, and kitty-scheme.conf paints the active border
    // and tab from fb_primary -- but nothing hands it to THIS file. schemes/
    // lives in the checkout, not under Quickshell.shellPath(), and the shell's
    // one route to it is running `desktop-scheme list`
    // (settings/pages/AppearancePage.qml:66). Reading it here would mean either
    // that process or a path climbing out of the shell root, both asynchronous,
    // so a literal would still be needed underneath each one: it would be a
    // layer over these values rather than a replacement for them.
    //
    // NAMING: M3's foreground roles are on_surface, on_primary and so on, but
    // a QML property called `onSurface` is parsed as the signal handler for
    // `surfaceChanged`, and the file fails to load with "Cannot assign a
    // value to a signal". Hence textOnSurface, textOnPrimary... The JSON keys
    // below keep the M3 names; only the QML side is renamed.
    property color surface: palette.surface ?? "#1a1b26"
    property color surfaceContainer: palette.surface_container ?? "#292e42"
    property color surfaceContainerHigh: palette.surface_container_high ?? "#353b55"
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

    property color tertiary: palette.tertiary ?? "#73daca"
    property color textOnTertiary: palette.on_tertiary ?? "#1a1b26"

    // ---------------- Semantic: the SCHEME's, never the wallpaper's ----------
    // THE ARGUMENT THAT PUT THEM HERE IS UNCHANGED. An alert keeps its meaning
    // across every wallpaper: amber is "watch out" and red is "something is
    // wrong". M3's error role is derived from the image, so over a red picture
    // a critical reading would come out the hue of the rest of the bar, and
    // that is why quickshell-colors.json still passes no error/on_error through
    // at all -- see `_no_error_role` in it. Nothing below weakens that. These
    // three are still outside the accent half of the palette and must stay
    // there.
    //
    // WHAT THAT ARGUMENT NEVER SAID IS "HARDCODED", and the two were written
    // here as if they were one thing. They are not. "Not derived per wallpaper"
    // is a claim about WHEN a colour may move; "a Tokyo Night literal" is a
    // claim about who gets to pick it, and only the first one was ever
    // reasoned for. A scheme is not a wallpaper: it is chosen by hand and it
    // moves only when the user moves it, so an alert taken from a scheme is
    // still as fixed as anything on screen is. So the three read sem_warning /
    // sem_critical / sem_on_critical now -- the same roles GTK, Qt and zathura
    // already paint their alerts from -- and the shell stops being the last
    // surface on this desktop wearing Tokyo Night red on a Gruvbox base.
    //
    // MEASURED, AND IT IS NOT ALL ONE WAY. Rendered under all three schemes and
    // graded against all four surface levels. `warning` improves everywhere:
    // its worst pair, on surfaceContainerHighest, goes 3.26 -> 3.84 under
    // Gruvbox and 3.34 -> 5.25 under Catppuccin. Tokyo Night does not move at
    // all, because the literals WERE its scheme. Catppuccin's critical improves
    // (2.52 -> 2.88 on the top container). GRUVBOX'S CRITICAL GETS WORSE:
    // #fb4934 is darker than #f7768e, so against surfaceContainerHighest
    // (#665c54, Gruvbox's own bg3) it falls 2.46:1 -> 1.89:1, and against
    // surfaceContainerHigh 3.33:1 -> 2.56:1. textOnCritical on critical lands
    // at 4.29:1 there, under the 4.5 floor for body text.
    //
    // WHERE THAT ACTUALLY LANDS, because surfaceContainerHighest is never a
    // large background in this tree -- it is field fills, rails, chips and
    // hover tints. Red meets it in exactly two places: the invalid save-path
    // border in RecordingPage.qml:817 over its own field fill (:815), and a
    // hovered peripheral row (PeripheralBattery.qml:679/:693 over the hover
    // fill at :661). surfaceContainerHigh is the commoner one and it is the
    // BAR: every Group pill is glass(surfaceContainerHigh), so the urgent
    // workspace dot (Workspaces.qml:203), the island's alert text
    // (Island.qml:669/:690) and the recording dot (:905) all sit on it. Those
    // are the places to look at under Gruvbox before trusting the grader.
    //
    // THAT IS NOT AN ARGUMENT FOR THE LITERALS COMING BACK. #f7768e scored
    // better on a Gruvbox card only by being a colour Gruvbox does not contain.
    // The pairing that is actually weak is Gruvbox's own bright red against
    // Gruvbox's own bg3, and it is weak in every application on this desktop
    // rather than only here -- GTK, Qt and zathura have paired those two since
    // the templates were substituted. If it is worth fixing, it is fixed in
    // schemes/gruvbox-dark.json (sem_critical, or the ui_border the surface
    // ladder tops out at), where one edit moves the whole desktop at once. A
    // shell that quietly disagreed with the scheme would only hide it.
    //
    // THE ?? FALLBACKS ARE NOT A ROUTE BACK. They are the Tokyo Night literals
    // these properties used to be, kept for exactly the reason every palette
    // property above keeps one: a fresh clone with no colors.json has to look
    // deliberate rather than broken. What is on screen in a running session is
    // the scheme's.
    //
    // No Behavior on these three, unlike the palette above: the Behaviors are
    // there to ride the wallpaper crossfade, and an alert does not change on a
    // wallpaper change at all. It changes on a scheme switch, where a fade
    // timed to an image that did not move would be an animation of the bar's
    // own invention -- the thing recolorDuration was set to zero to stop.
    //
    // WHAT IS DELIBERATELY MISSING, because a property reading a key nothing
    // draws with is the same defect as a key no property reads.
    //
    // NO textOnWarning. Every scheme fills sem_on_warning and GTK paints with
    // it, but nothing in this tree has anywhere to put it: all 24 sites that
    // touch `warning` are foregrounds (a Text, a glyph, a border, a meter tick,
    // a slider fill with nothing on it) or a Qt.alpha() tint of 0.16-0.22 over
    // a card -- and on none of those four tints does anything switch to an
    // on-warning ink: what sits on them is either textOnSurface or the amber
    // itself. No solid amber ground in this tree carries readable content at
    // all. textOnCritical is here because red does have that shape: hovering a
    // Forget button fills it solid and flips the glyph
    // (NetworkPage.qml:524, BluetoothPage.qml:548, Island.qml:952). And it
    // would be a duplicate anyway -- sem_on_warning and sem_on_critical are the
    // same hex in all three schemes (#1a1b26, #1e1e2e, #282828), which is
    // exactly what Chip.qml:22-26 already leans on when it says the two alerts
    // share one dark ink.
    //
    // NO success either. There is no green anywhere in this tree, and the
    // states that would want one -- an `ok` update verdict, a connected
    // network, a paired device, a charging battery -- are `primary` today
    // (UpdatesPage.qml:89 and :315, NetworkPage.qml:406, BluetoothPage.qml:429,
    // SystemBattery.qml:59, PeripheralBattery.qml:561). Pinning those to a
    // fixed green is a design change with its own case to argue, and it starts
    // at those sites; the property would follow it, not lead it.
    readonly property color warning: palette.warning ?? "#e0af68"
    readonly property color critical: palette.critical ?? "#f7768e"
    readonly property color textOnCritical: palette.on_critical ?? "#1a1b26"

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
    // AND A THEME MAY NOW OVERRIDE IT, WHICH THE PARAGRAPH ABOVE SAYS IT MAY
    // NOT. The paragraph is kept because its argument is sound and it is still
    // sound; what it does not survive is a theme whose whole look is a
    // transparency.
    //
    // The number is shared by four programs and only one of them can read a
    // theme -- true, and the four are kitty, Zen, Nautilus and this shell. The
    // first three are WINDOWS: the dial exists so the terminal can be seen
    // through, and it belongs to the person at the keyboard. The fourth is not
    // a window, it is the desktop's own chrome, and it was inheriting the
    // terminal's number by accident rather than by anybody's decision.
    //
    // WHAT MADE IT MATTER. Config.opacity is 0.95 on the machine this was
    // written on, so every glass surface the shell drew was 95% opaque. A
    // Windows 11 taskbar over a wallpaper carries the wallpaper's colour
    // plainly; ours came out flat near-black, and no amount of correct drawing
    // could have fixed it. That was found by photographing the shell over a
    // picture instead of over the compositor's void.
    //
    // A PERCENTAGE BECAUSE token() TAKES A NUMBER. `"surfaceAlpha": 78` is
    // 0.78. A theme that names nothing gets Config.opacity exactly as before,
    // which is what keeps genesis where it is.
    //
    // AND IT IS THE SAME BARGAIN AS `pinned`: a theme that fixes its own
    // transparency has taken the dial away for as long as it is drawn, and the
    // Transparency section of the appearance page says so rather than offering
    // a slider that does nothing.
    readonly property real glassAlpha: root.themeSurfaceAlpha > 0
        ? root.themeSurfaceAlpha / 100
        : Config.opacity

    readonly property int themeSurfaceAlpha: root.token("surfaceAlpha", 0)

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

    // WHICH EDGE THE BAR IS ON, AS A NUMBER, BECAUSE token() ONLY TAKES ONE.
    //
    // 0 is the top and 1 is the bottom. It is not a style choice and it is not
    // the bar's own business: the bar declares its own anchors and needs no
    // help, but components/Popout.qml is a HOST window that has to open on the
    // bar's inner side, and the host cannot see where a theme put its bar.
    //
    // It arrived with the windows theme, whose taskbar is at the bottom, and
    // it is the third thing that theme asked the host for. The other two were
    // railWidth and the notification daemon.
    //
    // A BOOLEAN WOULD BE BETTER AND theme.json CANNOT CARRY ONE: token()
    // requires a finite number and falls through to the fallback for anything
    // else, so a `"barEdge": "bottom"` would be read as absent and the popout
    // would open at the top with nothing saying why. A number that is really a
    // flag is the honest version of that constraint rather than a shortcut
    // around it.
    readonly property bool barAtBottom: root.token("barAtBottom", 0) !== 0

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

    // ---------------- Settings rail ----------------
    // How wide the settings window's navigation sidebar is. NOT READ FROM HERE
    // BY ANYTHING THAT DRAWS: modules/settings/SettingsChrome.qml publishes it
    // as a property of its own and every one of the six things in
    // modules/settings/Settings.qml anchored against the rail reads it off that
    // facade, so the dependency stays in one file rather than in six. That
    // facade's header has the whole account.
    //
    // 210 is what the window has always been, and it is a number this shell
    // chose rather than one it inherited: a rail is as wide as its longest
    // label plus its glyph, and "Notifications" at 11pt DemiBold with a Nerd
    // Font pictogram in front of it is what set it. A theme whose type or
    // whose idea of a sidebar is different needs its own number -- Windows 11
    // ships NavigationView at OpenPaneLength 320 and its Settings app does not
    // override it, and no amount of drawing gets there from 210.
    readonly property int railWidth: root.token("railWidth", 210)

    // How much that rail insets its own contents by, on every side.
    //
    // TEN IS ALSO THE SCROLLBAR'S CHANNEL, which is the part worth knowing
    // before moving it. The rail's entries stop at the padding and the bar
    // lives in the strip that leaves: four pixels of bar centred in ten leaves
    // three on each side, and tests/scrollbar-target.py asserts that at 210 and
    // 10 the entries own up to x=199 and the bar answers from 200. A theme that
    // takes this below the bar's own width has no channel left, and the press
    // target goes back over the entries -- the bug that bench exists for.
    readonly property int railPadding: root.token("railPadding", 10)

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
    // here, because the reason is not about type: every glyph GENESIS draws is
    // a Nerd Font codepoint rendered as text in THIS property. Point it
    // anywhere else and that bar fills with tofu.
    //
    // AND THAT SENTENCE NAMES A THEME NOW, which is the whole of the change
    // here. "Every glyph this shell draws is a Nerd Font codepoint" was true of
    // the only theme there was, and it is false of a theme that brings its own
    // icon set (see the bottom of Icons.qml). A restriction that belongs to one
    // theme cannot be enforced for all of them by the host, so it is DECLARED:
    // a manifest saying `"font": {"source": "user"}` -- which is genesis, and
    // which is also what a manifest that says nothing means -- is a theme
    // asking to be drawn in the family the user picked, from a setting that
    // offers only families carrying the glyph set it needs. A theme that names
    // its own family is a theme taking that responsibility off the setting.
    //
    // NEITHER IS A TOKEN, and that is unchanged: they are one decision shared
    // with a program that has never heard of a theme. A theme.json that names
    // them is ignored -- the manifest is where this one is answered, because it
    // is a claim a theme makes about ITSELF rather than a value it picks.
    //
    // THE SIZE STAYS THE USER'S WHATEVER THE THEME SAYS. It is points, shared
    // with kitty, and it is a question about how big text should be on this
    // screen rather than about which characters exist in a font -- the second
    // is the only one a theme can answer better than the person reading it.
    readonly property string fontFamily: root.fontSource === "theme" ? root.themeFontFamily : Config.fontFamily
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
    // IT DECLARES WHERE THE COLOURS COME FROM, in its manifest, and there are
    // two values:
    //
    //     "palette": { "source": "scheme" }
    //     "palette": { "source": "pinned", "scheme": "gruvbox-dark" }
    //
    // "scheme" is what the header of this file describes: the generated
    // palette, rewritten by matugen on every wallpaper change and followed
    // live, over whichever scheme `desktop-scheme` has in force. A manifest
    // that says nothing gets it, which is what keeps a theme written before
    // this key existed working unchanged.
    //
    // "pinned" NAMES A SCHEME AND THE WHOLE DESKTOP WEARS IT. It is not a
    // palette this shell reads from somewhere else -- entering the theme runs
    // `desktop-scheme pin <name>` and leaving it runs `desktop-scheme unpin`,
    // so matugen re-renders every one of the fourteen generated files and kitty,
    // GTK, Zen and this shell all move together. A theme is a look for the
    // desktop, and a desktop where the shell and the terminal disagree is not a
    // look. The scheme the person picked for themselves is not lost while a
    // theme is pinning: `desktop-scheme` keeps `chosen` beside `scheme` for
    // exactly that, and `unpin` is what hands it back.
    //
    // THE KEY IS `palette.scheme`, AND THIS IS WHERE THAT IS STATED. It is a
    // scheme NAME -- one of `desktop-scheme list` -- and never a path or a
    // colour. Nothing else in the tree defines it: the fixture that pins one
    // (tests/fixtures/theme-probe) and the check that drives the round trip
    // (tests/scheme-pinning.sh) both read it back out of the manifest.
    //
    // WHAT "pinned" IS NOT, because this file used to say the opposite and the
    // two designs are easy to confuse. It is NOT a theme carrying its own
    // palette file that only the shell reads. That design has a name -- `fixed`
    // -- and it was declined rather than deferred: it would produce a Windows
    // shell over a Catppuccin terminal, and the palette this shell reads would
    // be the one thing on the desktop that the scheme did not decide. The seam
    // it would have needed is `palettePath` below, which is why that had a
    // switch in it with one case; it has none now.
    //
    // A THEME THAT PINS A SCHEME THIS MACHINE DOES NOT HAVE is refused at the
    // far end and not here. `desktop-scheme` has no file for the name, so it
    // writes nothing and dies -- and because its stderr is a pipe rather than a
    // terminal when this shell spawns it, lib_notify turns that into a
    // notification naming the script and the name it would not take. What
    // renders is whatever was already in force. Checking the name here would
    // mean running `desktop-scheme list` to find out, which is a process and a
    // second opinion about a directory the script owns.
    readonly property string defaultPaletteSource: "scheme"

    // Not readonly: the manifest is read asynchronously and this is what the
    // read lands on. It sits at the default until then, and a manifest that
    // cannot be read or asks for something unknown leaves it there.
    property string paletteSource: root.defaultPaletteSource

    // WHICH SCHEME THE THEME PINS, or "" when it pins nothing.
    //
    // THE PAIR HAS ONE INVARIANT, the same one fontSource and themeFontFamily
    // keep below: paletteSource is only ever "pinned" when this holds a name a
    // theme actually wrote. adoptPalette() is what guarantees it, and it is what
    // lets the handler underneath be a plain "empty or not" test.
    property string pinnedScheme: ""

    // ---------------- Entering the theme, and leaving it ----------------
    // THE WHOLE OF THE WIRING, and it is two lines because everything either
    // side of it already exists: the value above follows the manifest of the
    // theme being DRAWN, and Config.qml owns the push into `desktop-scheme` the
    // same way it owns `setScheme`. What is between them is one transition.
    //
    // ON THE CHANGE AND NOT ON A TIMER OR A POLL. A theme is entered when this
    // moves from "" to a name -- which includes the first read of a pinning
    // theme's manifest at startup, and is why a login lands on the theme's
    // scheme rather than on whatever the last session left -- and it is left
    // when it moves back to "". A theme swapped straight to another pinning
    // theme moves it from one name to the other and pins the second, which is
    // one call rather than an unpin and a pin with a render in between.
    //
    // IDEMPOTENT AT THE FAR END, which is what makes the startup case free:
    // `desktop-scheme pin` on the scheme already in effect writes its state,
    // declines to re-render and returns. Nothing on the desktop changes colour
    // for a shell that restarted under a theme that was already pinning.
    //
    // WHAT IT DOES NOT COVER, said out loud rather than left to be found: a
    // pinning theme that stops being DRAWN while the shell is not running -- its
    // directory removed, or its manifest broken, so the next start falls back to
    // genesis -- leaves the pin standing in the store, because there is no
    // transition for this to see. The desktop then wears the departed theme's
    // scheme until something moves it, and `desktop-scheme set` is what moves
    // it. Closing that would mean reconciling the store against the manifest at
    // every startup, which is a second mechanism that would also have to decide
    // what to do about a person who picked a scheme while a pinning theme was
    // on -- and that person's `set` is a real choice, not a state to correct.
    onPinnedSchemeChanged: {
        if (root.pinnedScheme === "")
            Config.unpinScheme();
        else
            Config.pinScheme(root.pinnedScheme);
    }

    function adoptManifest(text: string): void {
        let manifest = null;

        try {
            manifest = JSON.parse(text);
        } catch (error) {
            // Silent on purpose: modules/Themes.qml reads the same file, says
            // this out loud and falls back to the shipped theme. A second
            // warning about one broken manifest is noise.
            //
            // BOTH HALVES GO BACK TO THEIR DEFAULTS and not only the palette: a
            // file that does not parse has declared nothing, and a shell holding
            // one declaration out of a manifest the host refused would be the
            // worst of both readings.
            root.adoptPalette(null);
            root.adoptFont(null);
            return;
        }

        root.adoptPalette(manifest);
        root.adoptFont(manifest);
    }

    // MOVED OUT OF adoptManifest AND NOT CHANGED, because there are two
    // declarations to read now and a single function would have had to decide
    // what a manifest that gets one of them wrong means for the other. It means
    // nothing: they are independent claims and each falls back on its own.
    function adoptPalette(manifest: var): void {
        // NOT NAMED `palette`, which is a property of this singleton twenty
        // lines further down: a local of that name reads like the palette the
        // shell is drawing with, and this is what a manifest claimed.
        const declaredPalette = manifest && manifest.palette ? manifest.palette : null;
        const declared = declaredPalette ? declaredPalette.source : undefined;

        if (declared === undefined) {
            root.paletteSource = root.defaultPaletteSource;
            root.pinnedScheme = "";
            return;
        }

        if (declared === "pinned") {
            const scheme = declaredPalette.scheme;

            // A pin with no name is a theme asking for a scheme and not saying
            // which, the same shape adoptFont refuses below for a "theme" font
            // with no family. It cannot be honoured and must not be guessed at:
            // there is no scheme to fall back to but the one already in force,
            // which is what reading the scheme means.
            if (typeof scheme !== "string" || scheme.trim() === "") {
                console.warn(`Theme: ${root.themeName} asks to pin a colour scheme and does not name one -- reading the scheme`);
                root.paletteSource = root.defaultPaletteSource;
                root.pinnedScheme = "";
                return;
            }

            // THE NAME FIRST AND THE SOURCE SECOND, so that the invariant above
            // holds at every moment the handler can run: assigning pinnedScheme
            // is what fires it, and by then paletteSource has to agree.
            root.pinnedScheme = scheme.trim();
            root.paletteSource = declared;
            return;
        }

        if (declared !== "scheme")
            console.warn(`Theme: ${root.themeName} asks for a palette source called "${declared}", which this shell does not know -- reading the scheme`);

        root.paletteSource = root.defaultPaletteSource;
        root.pinnedScheme = "";
    }

    // ---------------- What the theme declares about the type ----------------
    // IT DECLARES WHOSE FAMILY THE SHELL IS DRAWN IN, in its manifest:
    //
    //     "font": { "source": "user" }
    //     "font": { "source": "theme", "family": "Segoe Fluent Icons" }
    //
    // "user" is genesis and is what a manifest that says nothing gets, so a
    // theme written before this key existed keeps working unchanged: the family
    // is Config.fontFamily, written by `desktop-font` and shared with kitty,
    // and the setting that picks it offers only families carrying the glyph set
    // genesis draws with.
    //
    // "theme" is the other half, and it exists for a theme that needs it: a
    // theme whose icons.json replaces the Nerd Font codepoints with an icon
    // font of its own is a theme whose pictograms are not in any family that
    // setting offers. Its `family` reaches Text.font.family unchanged. It is
    // shaped like the palette's "pinned" above -- a source name, and one more
    // key that only that source reads -- and adoptPalette refuses a pin with no
    // scheme in the same words this refuses a font with no family.
    //
    // WHAT THE HOST DOES NOT DO IS CHECK THE FAMILY IS INSTALLED, and that is a
    // decision rather than an omission. Qt resolves a family name by
    // substitution -- it will draw SOMETHING for a name no fontconfig knows --
    // so the only check available here is the family name against
    // Qt.fontFamilies(), which is stricter than Qt's own matching and would
    // refuse names Qt renders perfectly well. Refusing a working theme to catch
    // a broken one is the wrong way round; a theme that names a font nobody has
    // gets the substituted face, which is the same thing every other program on
    // this desktop does with it.
    //
    // AND THE SETTING IS UNTOUCHED BY THIS, which is worth writing down because
    // it looks like a loose end. AppearancePage still offers the three Nerd
    // Font variants and nothing else, and that is still right: it is choosing
    // the USER's family, the one a "user" theme is drawn in and the one kitty
    // shares. What changed is that the reason on that page -- "every icon in
    // this shell is a glyph from this font" -- is now genesis's claim rather
    // than the shell's, and a page that wanted to say so would read
    // root.fontSource here rather than be told again by the host.
    readonly property string defaultFontSource: "user"

    // Not readonly, and for the same reason paletteSource is not: the manifest
    // arrives asynchronously and this is where the read lands. A manifest that
    // cannot be read, or that asks for something this shell does not know,
    // leaves both of these where they start.
    //
    // THE PAIR HAS ONE INVARIANT: fontSource is only ever "theme" when
    // themeFontFamily holds a family a theme actually wrote. adoptFont() below
    // is what guarantees it, which is what lets fontFamily up in the type
    // section be a plain ternary with nothing to check.
    property string fontSource: root.defaultFontSource
    property string themeFontFamily: ""

    function adoptFont(manifest: var): void {
        const font = manifest && typeof manifest.font === "object" && manifest.font !== null ? manifest.font : null;

        // A `font` that is not a set of keys -- a bare string, a number -- is
        // said out loud rather than treated as absent. Absent means "I have no
        // opinion", and somebody who typed the key had one.
        if (manifest && manifest.font !== undefined && font === null) {
            console.warn(`Theme: ${root.themeName} carries a "font" that is not a set of keys -- drawing in the user's family`);
            root.fontSource = root.defaultFontSource;
            root.themeFontFamily = "";
            return;
        }

        const declared = font ? font.source : undefined;

        if (declared === undefined) {
            root.fontSource = root.defaultFontSource;
            root.themeFontFamily = "";
            return;
        }

        if (declared === "theme") {
            const family = font.family;

            // "theme" without a family is a theme asking for its own font and
            // not saying which, which cannot be honoured and must not be
            // guessed at: an empty family is a Text with no font at all.
            if (typeof family !== "string" || family.trim() === "") {
                console.warn(`Theme: ${root.themeName} asks to pick its own font family and does not name one -- drawing in the user's family`);
                root.fontSource = root.defaultFontSource;
                root.themeFontFamily = "";
                return;
            }

            root.themeFontFamily = family;
            root.fontSource = declared;
            return;
        }

        if (declared !== "user") {
            console.warn(`Theme: ${root.themeName} asks for a font source called "${declared}", which this shell does not know -- drawing in the user's family`);
        }

        root.fontSource = root.defaultFontSource;
        root.themeFontFamily = "";
    }

    // ONE VALUE AND NO SWITCH, and the switch that used to be here is the
    // mistake this file's palette section now names. It was a seam kept open
    // for "pinned" to return a path inside the theme directory -- which is the
    // design that was declined, not the one that was built. What was built
    // changes WHICH SCHEME matugen renders from, and matugen writes the same
    // file it always did: a pinning theme reads colors.json exactly like every
    // other theme, and the pin is why colors.json says gruvbox.
    //
    // So there is one palette file, there has only ever been one, and this
    // stays a named property because paletteFile below binds its path to it.
    //
    // shellPath and not configPath: the latter is deprecated in 0.3.0.
    readonly property string palettePath: Quickshell.shellPath("colors.json")

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
        // Both declarations, for the reason adoptManifest gives when the file
        // is there and will not parse: a manifest nobody could read has said
        // nothing about either of them.
        onLoadFailed: {
            root.adoptPalette(null);
            root.adoptFont(null);
        }
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
