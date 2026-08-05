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

        InfoRow {
            glyph: Icons.arch
            label: "Quickshell"
            description: "This bar, the island, the launcher, the notifications "
                + "and this window are one QML program. waybar, wofi and dunst "
                + "are gone."
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
            description: "~/.local/state/quickshell/by-shell/*/config.json for "
                + "what only the shell reads; ~/.local/state/desktop-opacity "
                + "and desktop-font for what the terminal and the browser read too."
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
