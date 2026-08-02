// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - Nerd Font glyphs, by codepoint
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// Every glyph lives here as a NUMBER, not as a literal character pasted into
// a .qml file. Two reasons, and the first one is not theoretical -- it
// already cost an afternoon:
//
//   - Private Use Area characters do not survive every editor, terminal or
//     copy-paste round trip. When they get lost they do not error: the string
//     is simply empty and the module renders blank, which looks like a
//     layout bug rather than a missing character.
//   - A codepoint can be checked. `String.fromCodePoint(0xF08AE)` says which
//     glyph it is even when the font is not installed, and the name in the
//     comment says what it is meant to look like.
//
// The names follow the Nerd Fonts ones (nf-md-*, nf-fa-*, nf-linux-*) so any
// of them can be looked up at nerdfonts.com/cheat-sheet.
//
// These are the same glyphs waybar used, kept deliberately: the bar changed,
// the vocabulary did not.

pragma Singleton

import Quickshell

Singleton {
    // Turns whatever an application handed us into something Image can open.
    //
    // D-Bus menus and notifications pass icon NAMES ("bluetooth-symbolic"),
    // not paths. Image treats a bare name as a relative file, fails to find
    // it, and paints the broken-image chequerboard -- which is exactly what
    // showed up in the bluetooth menu. Names go through the icon theme;
    // anything that already looks like a path or a URL is passed straight
    // through.
    //
    // The `true` asks iconPath to CHECK the icon exists and return an empty
    // string if it does not, so a missing icon disappears instead of
    // becoming a chequerboard.
    function resolve(nameOrUrl: string): string {
        if (!nameOrUrl)
            return "";

        // Quickshell's own provider. Its URLs cannot simply be passed through:
        // when the theme does not have the icon, the provider still answers
        // with a PLACEHOLDER -- the magenta and black chequerboard -- and the
        // Image reports status Ready, so checking the status is not enough to
        // hide it. The name has to be checked first, which is what the `true`
        // below does: iconPath returns an empty string when the icon does not
        // exist.
        const provider = "image://icon/";
        if (nameOrUrl.startsWith(provider)) {
            const rest = nameOrUrl.slice(provider.length);

            // A "?path=" query means the icon lives OUTSIDE the theme and the
            // provider has been told where to look -- Steam's tray icon is
            // image://icon/steam_tray_mono?path=~/.local/share/Steam/public.
            // Checking such a name against the theme always fails, so leave
            // these alone: the provider knows something we do not.
            if (rest.includes("?"))
                return nameOrUrl;

            return Quickshell.iconPath(rest, true) ? nameOrUrl : "";
        }

        if (nameOrUrl.includes("://") || nameOrUrl.startsWith("/"))
            return nameOrUrl;

        return Quickshell.iconPath(nameOrUrl, true);
    }

    // ---------------- Brand ----------------
    // nf-linux-archlinux. From the "Font Logos" range, not the Material
    // Design one -- that is why it is a four-digit codepoint while everything
    // else here is five.
    readonly property string arch: String.fromCodePoint(0xF303)

    // ---------------- Clock ----------------
    readonly property string clock: String.fromCodePoint(0xF0954)      // nf-md-clock_outline
    readonly property string calendar: String.fromCodePoint(0xF00ED)   // nf-md-calendar_text

    // ---------------- System ----------------
    readonly property string cpu: String.fromCodePoint(0xF0EE0)        // nf-md-cpu_64_bit
    readonly property string ram: String.fromCodePoint(0xF035B)        // nf-md-memory
    readonly property string gpu: String.fromCodePoint(0xF08AE)        // nf-md-expansion_card_variant

    // The island's thermal alert. A thermometer with an exclamation mark, so
    // it does not have to be read as "here is a temperature" -- it reads as
    // "this temperature is a problem". Picked off a rendered sheet.
    readonly property string thermometerAlert: String.fromCodePoint(0xF0E01) // nf-md-thermometer_alert

    // For the island's screen-capture state. Verified by RENDERING it: the
    // obvious-looking nf-md-monitor_share (U+F0A1B) draws a cassette in this
    // font, and two other candidates came out as a chequered square and a
    // sigma. Guessing codepoints by name does not work; this one was picked
    // off a rendered sheet.
    readonly property string monitor: String.fromCodePoint(0xF0379)    // nf-md-monitor

    // ---------------- Actions ----------------
    readonly property string gamepad: String.fromCodePoint(0xF02B4)    // nf-md-google_controller
    readonly property string search: String.fromCodePoint(0xF0349)     // nf-md-magnify
    readonly property string close: String.fromCodePoint(0xF0156)      // nf-md-close
    readonly property string power: String.fromCodePoint(0xF0425)      // nf-md-power

    // ---------------- Session ----------------
    // The power menu's actions, alongside `power` above. Same Material Design
    // family as the rest, for the reason the old wofi script already
    // documented: within one family the glyphs share weight and width, and the
    // legacy Font Awesome range collides with the "Font Awesome 7 Free"
    // installed as a fallback.
    readonly property string logout: String.fromCodePoint(0xF0343)     // nf-md-logout
    readonly property string restart: String.fromCodePoint(0xF0709)    // nf-md-restart

    // ---------------- Audio ----------------
    readonly property string volumeMuted: String.fromCodePoint(0xF075F)  // nf-md-volume_off
    readonly property string volumeLow: String.fromCodePoint(0xF057F)    // nf-md-volume_low
    readonly property string volumeMedium: String.fromCodePoint(0xF0580) // nf-md-volume_medium
    readonly property string volumeHigh: String.fromCodePoint(0xF057E)   // nf-md-volume_high
    readonly property string headphones: String.fromCodePoint(0xF02CB)   // nf-md-headphones
    readonly property string headset: String.fromCodePoint(0xF02CE)      // nf-md-headset

    // ---------------- Bluetooth ----------------
    readonly property string bluetooth: String.fromCodePoint(0xF00AF)     // nf-md-bluetooth

    // ---------------- Screen recording ----------------
    // The three targets the recorder offers, plus its stop button.
    readonly property string record: String.fromCodePoint(0xF044B)        // nf-md-record_rec
    // Checked on a rendered sheet like the rest of this section: at this
    // codepoint the font really does draw a circular arrow. Two of the
    // candidates did not survive that check -- nf-md-backup_restore draws a
    // paperclip here and nf-md-motion_play draws a scooter.
    readonly property string replay: String.fromCodePoint(0xF0459)        // nf-md-replay
    readonly property string stop: String.fromCodePoint(0xF04DB)          // nf-md-stop
    // PICKED OFF A RENDERED SHEET, not by name, and the first attempt shows
    // why that matters in this font: nf-md-window_maximize draws a SHIELD and
    // nf-md-selection_drag draws a hook. Neither name is wrong -- the glyphs
    // at those codepoints simply are not what the names suggest here.
    //
    // display shares the monitor glyph with the capture indicator on purpose:
    // the same object should not have two drawings in one shell.
    readonly property string display: String.fromCodePoint(0xF0379)       // nf-md-monitor
    readonly property string window: String.fromCodePoint(0xF08C6)        // nf-md-application
    readonly property string region: String.fromCodePoint(0xF0001)        // nf-md-vector_square

    // ---------------- Network ----------------
    readonly property string wifi: String.fromCodePoint(0xF0928)         // nf-md-wifi_strength_4
    readonly property string wifiAlert: String.fromCodePoint(0xF092B)    // nf-md-wifi_strength_alert_outline
    readonly property string wifiOff: String.fromCodePoint(0xF092D)      // nf-md-wifi_strength_off_outline
    readonly property string ethernet: String.fromCodePoint(0xF0201)     // nf-md-ethernet_cable
    readonly property string ethernetOff: String.fromCodePoint(0xF0202)  // nf-md-ethernet_cable_off

    // ---------------- Media ----------------
    readonly property string music: String.fromCodePoint(0xF075A)        // nf-md-music
    readonly property string pause: String.fromCodePoint(0xF03E4)        // nf-md-pause

    // The dashboard's transport. Material Design and NOT the Unicode media
    // symbols (U+23EE/23EF/23ED) that were here first: those fall through to
    // whatever fallback font has them, so they arrive at a different weight
    // and a different optical size than every other glyph on screen, which is
    // exactly what made the buttons look wrong. All four were picked off a
    // rendered sheet.
    readonly property string skipPrevious: String.fromCodePoint(0xF04AE)  // nf-md-skip_previous
    readonly property string skipNext: String.fromCodePoint(0xF04AD)      // nf-md-skip_next
    readonly property string play: String.fromCodePoint(0xF040A)         // nf-md-play

    readonly property string chromium: String.fromCodePoint(0xF02AF)     // nf-md-google_chrome
    readonly property string firefox: String.fromCodePoint(0xF0239)      // nf-md-firefox
    readonly property string vlc: String.fromCodePoint(0xF057C)          // nf-md-vlc
    readonly property string spotify: String.fromCodePoint(0xF1BC)       // nf-fa-spotify

    // ---------------- Launcher commands ----------------
    // The ">" mode's entries. Same rule as everything else in this file:
    // checked against the font before being used.
    readonly property string image: String.fromCodePoint(0xF02E9)         // nf-md-image
    readonly property string shuffle: String.fromCodePoint(0xF049D)       // nf-md-shuffle_variant
    readonly property string clipboard: String.fromCodePoint(0xF0385)     // nf-md-clipboard_text
    readonly property string refresh: String.fromCodePoint(0xF0450)       // nf-md-refresh
    readonly property string chevronRight: String.fromCodePoint(0xF0142)  // nf-md-chevron_right
    readonly property string palette: String.fromCodePoint(0xF0765)       // nf-md-palette

    // ---------------- Notifications ----------------
    readonly property string bell: String.fromCodePoint(0xF09A2)         // nf-md-bell_outline
    readonly property string bellOff: String.fromCodePoint(0xF09A1)      // nf-md-bell_off_outline
}
