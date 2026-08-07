// How the desktop looks: how solid its surfaces are, what it is set in, how
// its windows are spaced and what the pointer looks like.
//
// EVERY SETTING ON THIS PAGE REACHES PAST THE SHELL, which is why they are
// here together rather than filed under the bar or the window. Each is a file
// under ~/.local/state that a script writes and several programs read; the
// shell is only the first of those readers. See Config.qml for the shape and
// bin/desktop-opacity for the sibling that started it.
//
// Nothing here is a Theme constant, and the line between the two is the one
// Config.qml's header draws: Theme.qml is a design system whose values are
// decisions with reasons written beside them, and this page holds the ones
// where there is no right answer -- or, in the case of the gaps and the
// rounding, the ones the shell does not draw at all.

import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Appearance"
    glyph: Icons.palette
    keywords: ["opacity", "transparency", "glass", "font", "type", "size",
        "gaps", "spacing", "rounding", "corners", "border", "cursor",
        "pointer", "mouse pointer"]

    // The installed cursor themes, asked for once when the page is
    // looked at. `hypr-tweak themes` lists the icon themes that have a
    // cursors/ directory -- an icon theme without one is an application
    // icon set, and offering it would produce a choice that does nothing.
    property var cursorThemes: []

    onVisibleChanged: {
        if (visible && !themeQuery.running)
            themeQuery.running = true;
    }

    Process {
        id: themeQuery

        command: ["hypr-tweak", "themes"]

        stdout: StdioCollector {
            onStreamFinished: root.cursorThemes =
                (text || "").split("\n").filter(line => line.trim() !== "")
        }
    }

    SettingsSection {
        width: parent.width
        title: "Transparency"

        StepperRow {
            glyph: Icons.display
            label: "Desktop opacity"
            // Stored as a fraction, shown as percent: see the note on opacity
            // in Config.qml.
            value: Math.round(Config.opacity * 100)
            // The floor is legibility and not taste: below 40% small text
            // over a bright wallpaper stops being readable however much blur
            // sits behind it. The script enforces the same pair.
            from: 40
            to: 100
            // Fives, not ones. Below about 5% the change is not visible on a
            // surface this size, so single steps would mostly be clicks that
            // do nothing on screen.
            step: 5
            suffix: "%"
            onMoved: value => Config.setOpacity(value / 100)

            // Deliberately NOT a list of app names. The first version of this
            // named the three it knew about, which is a note that goes stale
            // the moment the script learns a fourth -- and a settings window
            // is the last place that should be telling you something that is
            // no longer true.
            hint: "Applies to most surfaces immediately. "
                + "Some apps only read it at startup and will not "
                + "follow until they are restarted."
        }
    }

    SettingsSection {
        width: parent.width
        title: "Windows"

        // THE COMPOSITOR'S, NOT THE SHELL'S, which is why it sits in its own
        // section rather than under Transparency: it is drawn around every
        // window on the machine, and this window is only the place that asks
        // for it. Hyprland applies it the moment the number changes, to
        // windows already open as well as new ones -- unlike the opacity
        // above, which new windows pick up and old ones do not.
        StepperRow {
            glyph: Icons.windowTiles
            label: "Window border"
            value: Config.borderSize
            from: 0
            to: 6
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("border", value)

            hint: "Zero removes it entirely. The colour comes from the "
                + "wallpaper and is not set here."
        }

        // TWO GAPS AND NOT ONE, because they are genuinely different
        // measurements and setting them together is the thing that looks
        // wrong: the space between two windows is counted twice -- each of
        // them contributes gaps_in -- while the space to the edge of the
        // screen is counted once. Equal numbers give a border round the
        // desktop that is half the width of the seams inside it.
        StepperRow {
            glyph: Icons.gaps
            label: "Gap between windows"
            value: Config.gapsIn
            from: 0
            to: 40
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("gaps-in", value)

            hint: "Counted on both sides of a seam, so two tiled windows sit "
                + "twice this far apart."
        }

        StepperRow {
            glyph: Icons.gaps
            label: "Gap to the screen edge"
            value: Config.gapsOut
            from: 0
            to: 80
            step: 2
            suffix: " px"
            onMoved: value => Config.setTweak("gaps-out", value)

            hint: "The margin the tiled area leaves around itself. This is "
                + "also what the bar sits in, so taking it to zero puts "
                + "windows under the bar rather than beside it."
        }

        StepperRow {
            glyph: Icons.rounding
            label: "Corner rounding"
            value: Config.rounding
            from: 0
            to: 30
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("rounding", value)

            hint: "Hyprland's own corners, on every window. The shell's "
                + "surfaces have their own radius and do not follow this — "
                + "see the note above `rounding` in hyprland.lua about why "
                + "the two are set apart from each other."
        }
    }

    // ---------------- Pointer ----------------
    //
    // ITS OWN SECTION AND NOT PART OF "Windows", because it is the one thing
    // on this page that is not drawn by the compositor at all. The size has
    // to be told to three different parties -- Hyprland for the session, the
    // environment for anything started afterwards, and GTK through its own
    // settings -- which is what the `hypr-tweak` script exists to keep in
    // step. See its header.
    SettingsSection {
        width: parent.width
        glyph: Icons.cursor
        title: "Pointer"

        StepperRow {
            glyph: Icons.cursor
            label: "Cursor size"
            value: Config.cursorSize
            from: 16
            to: 48
            step: 4
            suffix: " px"
            onMoved: value => Config.setTweak("cursor-size", value)

            hint: "Applies to windows opened from now on. Ones already up "
                + "keep the size they started with — the pointer is chosen "
                + "by each client, not painted over the screen."
        }

        // THE THEME ROW IS ONLY THERE WHEN THERE IS A CHOICE, and on this
        // machine there is not: exactly one installed icon theme has a
        // cursors/ directory (Adwaita). A picker with one entry is not a
        // setting, it is a label pretending to be one. Install a second and
        // the row appears on its own.
        ChoiceRow {
            visible: root.cursorThemes.length > 1

            glyph: Icons.palette
            label: "Cursor theme"
            options: root.cursorThemes
            value: Config.cursorTheme

            onChosen: value => Config.setTweak("cursor-theme", value)
        }
    }

    SettingsSection {
        width: parent.width
        title: "Type"

        StepperRow {
            glyph: Icons.textSize
            label: "Interface size"
            value: Config.fontSize
            from: 8
            to: 16
            step: 1
            suffix: " pt"
            onMoved: value => Config.setFont(value, Config.fontFamily)

            hint: "Points, the same unit the terminal measures in — the two "
                + "move together. Icons and the logo scale with it."
        }

        // THE LIST IS SHORT ON PURPOSE AND IT IS NOT A TASTE DECISION. Every
        // icon in this shell is a Nerd Font codepoint drawn as text in
        // Theme.fontFamily. Offer a family without the glyph set and the bar,
        // the island and this window fill with tofu boxes -- including the
        // glyph on the button that would let you change it back.
        //
        // What is left is still a real choice: the terminal-shaped default,
        // the strictly monospaced variant, and the proportional one, which is
        // the interesting one for a window that is mostly prose.
        ChoiceRow {
            glyph: Icons.tune
            label: "Interface font"
            options: [
                { label: "Default", value: "JetBrainsMono Nerd Font" },
                { label: "Mono", value: "JetBrainsMono Nerd Font Mono" },
                { label: "Propo", value: "JetBrainsMono Nerd Font Propo" }
            ]
            value: Config.fontFamily
            onChosen: value => Config.setFont(Config.fontSize, value)

            hint: "Only Nerd Font variants are offered: every icon in this "
                + "shell is a glyph from this font, and a family without them "
                + "would leave empty boxes everywhere."
        }
    }
}
