// What this shell is and where it lives.
//
// THERE IS NO "RESTORE DEFAULTS" HERE ANY MORE, and the space where it was is
// worth a note so that it is not put back. It offered to undo every value in
// the window and undid about a third of them: the four it named in its own
// description, and then thirty settings that have been added to this window
// since it was written and that it never learned about. It also could not do
// what it said even for the ones it did assign -- see the commit that removed
// it, and Config.qml, where a JsonAdapter drops every second write made in one
// synchronous turn.
//
// A control that undoes everything is a fine thing to want. It needs a way of
// enumerating what "everything" is rather than a list somebody remembers to
// extend, and it needs its writes spaced out; neither exists yet.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "About"
    glyph: Icons.info
    keywords: ["about", "version", "config"]

    SettingsSection {
        width: parent.width
        title: "Shell"

        // WHAT IT IS, NOT WHAT IT REPLACED. This used to end with "waybar,
        // wofi and dunst are gone", which is a fact about a migration that
        // finished -- it belongs in the repository's history, where somebody
        // is asking why, and not in a window whose reader is asking what.
        // Nobody opens their settings to find out which programs they no
        // longer run.
        //
        // What is worth knowing here is the part with a consequence: it is
        // one program, so a crash takes all of it, and it reloads itself on
        // save, so editing the config with this window open closes it.
        InfoRow {
            glyph: Icons.arch
            label: "Quickshell"
            description: "The bar, the island, the launcher, the notifications "
                + "and this window are one QML program — which is why a "
                + "setting changed here reaches the bar before you let go of "
                + "the button."
        }

        InfoRow {
            glyph: Icons.settings
            label: "~/.config/quickshell"
            description: "Symlinks into ~/dotfiles. Editing the config is "
                + "editing the repo, and saving a file reloads the shell."
        }

        InfoRow {
            glyph: Icons.info
            label: "Preferences on disk"
            // NOT A LIST OF THE FILES, which was the first version and was
            // already out of date two settings later. The rule is what
            // stays true: one store for what only this shell reads, another
            // for the values other programs read as well.
            description: "~/.local/state/quickshell/ for what only the shell "
                + "reads. The desktop-* and hypr-* files beside it are the "
                + "ones the terminal, the browser and the compositor read too."
        }
    }
}
