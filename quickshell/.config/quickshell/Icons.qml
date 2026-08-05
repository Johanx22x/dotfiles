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
    id: root

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
    // Solid and not md-cog_outline (0xF08BB): it sits next to the power glyph
    // on the bar, which is solid, and an outlined one beside it read as the
    // disabled version of a button rather than as a different button.
    // Checked against the font's cmap rather than guessed -- see the note
    // above `monitor` for why that matters.
    readonly property string settings: String.fromCodePoint(0xF0493)   // nf-md-cog
    // Outline and not the filled md-information (0xF02FC): it marks a row
    // that has something extra to say, and a solid disc next to a label reads
    // as a status light -- as though something were wrong with the setting.
    readonly property string info: String.fromCodePoint(0xF02FD)       // nf-md-information_outline

    // ---------------- Settings window ----------------
    // All four checked against the font's cmap before being written down,
    // which is the rule the two corrections further down this file exist to
    // enforce.
    readonly property string account: String.fromCodePoint(0xF0009)     // nf-md-account_circle
    readonly property string textSize: String.fromCodePoint(0xF027F)    // nf-md-format_size
    readonly property string restore: String.fromCodePoint(0xF099B)     // nf-md-restore
    readonly property string tune: String.fromCodePoint(0xF062E)        // nf-md-tune

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

    // The sound page's devices. Resolved by NAME out of the installed font
    // rather than read off a chart, which is this file's rule and which paid
    // for itself again here: md-usb was guessed at 0xF0528 and is 0xF0553.
    //
    //   python3 -c "from fontTools.ttLib import TTFont; \
    //     f = TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf'); \
    //     print({n: c for c, n in f.getBestCmap().items()}['md-usb'])"
    readonly property string microphone: String.fromCodePoint(0xF036C)    // nf-md-microphone
    readonly property string microphoneOff: String.fromCodePoint(0xF036D) // nf-md-microphone_off
    readonly property string speaker: String.fromCodePoint(0xF04C3)       // nf-md-speaker
    readonly property string usb: String.fromCodePoint(0xF0553)           // nf-md-usb

    // Which of the above an audio output should be drawn with.
    //
    // IT IS A FUNCTION BECAUSE THREE PLACES ASK IT: the island's volume
    // control, the sound page's output row, and every device in the sound
    // page's list. The same headset drawn as headphones in one of them and as
    // a speaker in another is the kind of disagreement nobody reports and
    // everybody notices.
    //
    // `label` is the node's name and description run together -- the words
    // are in one or the other depending on the driver, and searching both
    // costs nothing. Pass a volume of 1 and muted false to ask what a device
    // IS rather than what it is currently doing, which is what a row in a
    // list of devices wants.
    function outputGlyph(label: string, muted: bool, volume: real): string {
        if (muted)
            return root.volumeMuted;

        const text = (label ?? "").toLowerCase();
        if (text.includes("headset"))
            return root.headset;
        if (text.includes("headphone"))
            return root.headphones;
        // Its own glyph rather than a speaker: an HDMI output goes to the
        // monitor, and on this machine that is the difference between the
        // desk speakers and the screen on the wall.
        if (text.includes("hdmi"))
            return root.display;

        if (volume < 0.01)
            return root.volumeLow;
        if (volume < 0.5)
            return root.volumeMedium;
        return root.volumeHigh;
    }

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
    // The third one of these found the same way, and the most quietly wrong:
    // 0xF0385 is md-MUSIC_BOX_OUTLINE, so the launcher's clipboard mode has
    // been offering to paste a music box. clipboard_text is 0xF014D.
    readonly property string clipboard: String.fromCodePoint(0xF014D)     // nf-md-clipboard_text
    readonly property string refresh: String.fromCodePoint(0xF0450)       // nf-md-refresh
    readonly property string chevronRight: String.fromCodePoint(0xF0142)  // nf-md-chevron_right
    // It was 0xF0765 until the settings window put it next to a label and it
    // was obviously a plain filled disc. Read out of the font's cmap: 0xF0765
    // is md-CIRCLE. The palette is 0xF03D8.
    //
    // It had gone unnoticed because both places using it tolerate a disc: the
    // colour picker in the launcher, where it passes for a swatch, and the
    // "Look" heading in the cheatsheet, where it is one glyph in a column of
    // them. That is the failure mode this file's other notes warn about: the
    // name in the comment is not evidence, the cmap is.
    //
    //   python -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('<font>.ttf').getBestCmap()[0xF03D8])"
    readonly property string palette: String.fromCodePoint(0xF03D8)       // nf-md-palette

    // ---------------- Notifications ----------------
    // BOTH OF THESE WERE WRONG, and silently: the codepoints below used to be
    // 0xF09A2 and 0xF09A1, which the comments called bell_outline and
    // bell_off_outline. In the font actually installed here they are
    // md-speaker_bluetooth and md-shower_head -- so the fallback icon on a
    // notification with no image of its own has been a bluetooth speaker.
    //
    // Read out of the font rather than off a chart, which is how it was
    // caught in the first place. To check any other entry in this file the
    // same way:
    //
    //   python -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap().get(0xF009C))"
    //
    // Nerd Fonts keeps the icon's own name as the glyph name, so the answer is
    // the identity of the glyph and not just "something is mapped there".
    readonly property string bell: String.fromCodePoint(0xF009C)         // nf-md-bell_outline
    readonly property string bellOff: String.fromCodePoint(0xF0A91)      // nf-md-bell_off_outline

    // ---------------- Cheatsheet ----------------
    // One per category heading. The names on the LEFT are the categories as
    // they are spelled in the descriptions in hyprland.lua -- that is the join
    // between the two files, so renaming a category there means renaming it
    // here, and a category with no entry falls back to a neutral glyph rather
    // than to a missing one. `palette` and `music` above already cover Look
    // and Media, and are reused instead of duplicated.
    readonly property string keyboard: String.fromCodePoint(0xF030C)      // nf-md-keyboard
    readonly property string apps: String.fromCodePoint(0xF003B)          // nf-md-apps
    // Same correction as `palette` above, found the same way: 0xF169B is
    // md-BOOK_SETTINGS_OUTLINE, which is why the "Windows" heading on the
    // cheatsheet carried a little book. dock_window is 0xF10AC.
    readonly property string windowTiles: String.fromCodePoint(0xF10AC)   // nf-md-dock_window
    readonly property string workspaces: String.fromCodePoint(0xF0570)    // nf-md-view_grid
    readonly property string camera: String.fromCodePoint(0xF0100)        // nf-md-camera
    readonly property string widgets: String.fromCodePoint(0xF072C)       // nf-md-widgets

    // The category glyph, by the name used in the bind descriptions.
    function category(name: string): string {
        switch (name) {
        case "Apps":       return root.apps;
        case "Windows":    return root.windowTiles;
        case "Workspaces": return root.workspaces;
        case "Capture":    return root.camera;
        case "Shell":      return root.widgets;
        case "Look":       return root.palette;
        case "Media":      return root.music;
        default:           return root.keyboard;
        }
    }
}
