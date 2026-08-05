// The launcher's command mode: what typing ">" offers.
//
// These are the shell's OWN actions, kept apart from the application list on
// purpose. An application launcher that also answers to verbs ends up ranking
// "Wallpaper" against a program called Wallpaper and getting it wrong; the
// ">" prefix says which of the two lists is being searched, so neither has to
// guess.
//
// WHAT IS AND IS NOT HERE
// Every entry is something this setup can already do -- each one wraps a
// script or a service that exists. Deliberately absent:
//
//   - Light / dark mode. wallpaper-switch runs matugen with `--mode dark`
//     hardcoded and every template is written for a dark surface, so a light
//     switch here would be a button that half works.
//   - A transparency control. Theme.glassAlpha is tied to ignore_alpha in
//     hyprland.lua -- the two have to move together or the rounded corners
//     go jagged again -- and a slider that silently breaks the edges is
//     worse than no slider.
//   - Anything that locks the session, which was ruled out for this setup.

pragma Singleton

import Quickshell
import QtQuick
// Icons lives at the root of the config: a singleton is not in scope just
// because it is one. Without this the entries below build with an undefined
// glyph and the whole list comes out empty, with a single ReferenceError as
// the only clue.
import "root:/"

Singleton {
    id: root

    // `picker` names a second screen the command opens instead of running
    // straight away. Empty means it acts immediately and closes the launcher.
    readonly property var entries: [
        {
            id: "wallpaper",
            name: "Wallpaper",
            // The folder is a setting, so the description reads it rather
            // than naming one. A ~ for $HOME because that is how a person
            // writes the path they are being shown.
            description: `Pick from ${Config.wallpaperDir.replace(Quickshell.env("HOME"), "~")}`,
            glyph: Icons.image,
            picker: "wallpaper"
        },
        {
            id: "random",
            name: "Random wallpaper",
            description: "Switch to a random one and recolour everything",
            glyph: Icons.shuffle,
            picker: ""
        },
        {
            id: "gamescope",
            name: "Gamescope options",
            description: "Copy the Steam launch options to the clipboard",
            glyph: Icons.gamepad,
            picker: ""
        },
        {
            id: "clipboard",
            name: "Clipboard history",
            description: "Past entries, through cliphist",
            glyph: Icons.clipboard,
            picker: "clipboard"
        },
        {
            id: "reload",
            name: "Reload shell",
            description: "Re-read the Quickshell configuration",
            glyph: Icons.refresh,
            picker: ""
        },
        {
            id: "colour",
            name: "Colour picker",
            description: "Pick a colour off the screen and copy it as hex",
            glyph: Icons.palette,
            picker: ""
        }
    ]

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "")
            return root.entries;

        return root.entries.filter(e => e.name.toLowerCase().includes(q) || e.id.includes(q));
    }

    // Runs a command that has no picker behind it.
    function run(id: string): void {
        switch (id) {
        case "random":
            Quickshell.execDetached(["wallpaper-switch", "random"]);
            break;

        case "gamescope":
            // The same string the bar's button used to copy before it was
            // taken off, kept identical so the muscle memory of pasting it
            // into Steam still works.
            Quickshell.clipboardText = `${Quickshell.env("HOME")}/.local/bin/gs -- %command%`;
            Quickshell.execDetached(["notify-send", "-t", "2000", "-a", "Quickshell", "-i", "input-gaming", "Copied to clipboard", "Paste it in Steam: Properties > Launch options"]);
            break;

        case "reload":
            Quickshell.reload(false);
            break;

        case "colour":
            // hyprpicker does the whole job itself: -a copies the value,
            // -n raises a notification (which this shell's own daemon draws)
            // and -f hex fixes the format. Nothing to capture or parse on
            // this side.
            Quickshell.execDetached(["hyprpicker", "-a", "-n", "-f", "hex"]);
            break;
        }
    }
}
