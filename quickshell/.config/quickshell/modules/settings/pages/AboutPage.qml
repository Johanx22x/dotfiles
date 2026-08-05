// What this shell is, where it lives, and the one button that undoes
// everything the rest of this window does.
//
// THE RESET LIVES HERE AND NOWHERE ELSE. It spent a version at the foot of
// the sidebar, which put it a hand's width from the close button: two clicks
// side by side, one of which throws away every value in the window. Filed at
// the bottom of the last page it is somewhere you arrive deliberately, which
// is the right amount of friction for an action with no undo -- and it still
// asks before doing it.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "About"
    glyph: Icons.info
    keywords: ["about", "version", "reset", "defaults", "restore", "config"]

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

    SettingsSection {
        width: parent.width
        title: "Reset"

        InfoRow {
            glyph: Icons.restore
            label: "Restore every setting to its default"
            description: "Opacity back to 85%, type back to 11pt, the clock "
                + "back to 24-hour with the date on, notifications back to 10 "
                + "seconds. The wallpaper and the mute are not touched."
        }

        Item {
            width: parent.width
            implicitHeight: resetButton.implicitHeight + 8

            ConfirmButton {
                id: resetButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter

                glyph: Icons.restore
                text: "Restore defaults"
                confirmText: "Click again to confirm"

                onConfirmed: Config.restoreDefaults()
            }
        }
    }
}
