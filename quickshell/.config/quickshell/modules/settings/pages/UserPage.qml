// The session: whose it is and what it is running on.
//
// IT IS ALMOST ALL READINGS, and that is what this page is for. A settings
// window opens on the question "is this machine set up the way I think it
// is", and the answers -- which user, which host, how long it has been up,
// which kernel -- are the cheapest possible way to answer it. Nothing here
// needs a control because nothing here is a preference.
//
// The one thing that could be a control is the picture, and it is not one: a
// file picker for an avatar is a file picker, and this shell has no dialog to
// hang one on. Dropping an image at ~/.face is the whole procedure, so the
// page says so rather than pretending to offer more.

import Quickshell
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
        if (root.visible)
            root.uptime = SessionInfo.uptime();
    }

    SettingsSection {
        width: parent.width
        title: "Account"

        InfoRow {
            glyph: Icons.account
            label: SessionInfo.displayName
            description: `${SessionInfo.user}@${SessionInfo.host} · ${SessionInfo.shell}`
        }

        InfoRow {
            glyph: Icons.image
            label: "Profile picture"
            description: "There is none. Put a square image at ~/.face and it "
                + "appears at the top of the sidebar; nothing else has to change."
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
