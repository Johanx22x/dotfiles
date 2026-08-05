// The session: whose it is and what it is running on.
//
// IT IS ALMOST ALL READINGS, and that is what this page is for. A settings
// window opens on the question "is this machine set up the way I think it
// is", and the answers -- which user, which host, how long it has been up,
// which kernel -- are the cheapest possible way to answer it. Nothing here
// needs a control because nothing here is a preference.
//
// THE ONE CONTROL IS THE PICTURE, and getting there took admitting that this
// shell has no file dialog and should not grow one. It borrows GTK's, through
// zenity, the same way the Wi-Fi list borrows nm-connection-editor for the
// networks it cannot handle: a file chooser already knows about thumbnails,
// recent places and filtering by type, and rebuilding that in QML to avoid one
// small package would be the wrong trade twice over.
//
// The work is the `desktop-avatar` script's, not this page's. It validates
// that the file is an image by content rather than by extension, scales it
// down if it is a wallpaper-sized thing, and puts it at ~/.face -- which is
// where a display manager looks too, so the picture is the account's and not
// just this shell's.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "User"
    glyph: Icons.account
    keywords: ["user", "account", "session", "avatar", "picture", "host", "uptime", "kernel"]

    // Read when the page comes up rather than on a timer. Uptime is the only
    // value here that moves, and nobody watches it move -- a clock ticking in
    // a settings window is work done for no one.
    property string uptime: ""

    onVisibleChanged: {
        if (!root.visible)
            return;
        root.uptime = SessionInfo.uptime();
        // Also catches a picture put there from a terminal while the window
        // was on another page.
        SessionInfo.refreshAvatar();
    }

    // A Process and not execDetached, for one reason: the sidebar has to be
    // told when to look at the file again, and only the exit tells us the
    // script is done writing it. Detached, the avatar would change on screen
    // whenever it felt like it -- or not until the window was reopened.
    Process {
        id: avatarAction

        onExited: SessionInfo.refreshAvatar()
    }

    function runAvatar(argument: string): void {
        if (avatarAction.running)
            return;
        avatarAction.command = ["desktop-avatar", argument];
        avatarAction.running = true;
    }

    SettingsSection {
        width: parent.width
        title: "Account"

        InfoRow {
            glyph: Icons.account
            label: SessionInfo.displayName
            description: `${SessionInfo.user}@${SessionInfo.host} · ${SessionInfo.shell}`
        }

        ActionRow {
            glyph: Icons.image
            label: "Profile picture"
            description: SessionInfo.hasAvatar
                ? "Shown at the top of the sidebar, cropped to a circle. A square image frames best."
                : "None yet. Choose one and it appears at the top of the sidebar."

            actionText: avatarAction.running ? "Choosing…"
                : SessionInfo.hasAvatar ? "Change"
                : "Choose"
            actionGlyph: Icons.image
            actionEnabled: !avatarAction.running

            onTriggered: root.runAvatar("pick")
        }

        // Only when there is something to remove. A permanently disabled
        // control is a row that spends most of its life explaining that it
        // does not apply.
        ActionRow {
            visible: SessionInfo.hasAvatar
            glyph: Icons.close
            label: "Remove the picture"
            description: "Goes back to the initial over the accent colour."

            actionText: "Remove"
            actionEnabled: !avatarAction.running

            onTriggered: root.runAvatar("clear")
        }
    }

    SettingsSection {
        width: parent.width
        title: "System"

        InfoRow {
            glyph: Icons.arch
            label: SessionInfo.distro
            description: `Kernel ${SessionInfo.kernel}`
        }

        InfoRow {
            glyph: Icons.clock
            label: "Up for " + root.uptime
            description: "Since the last boot."
        }
    }
}
