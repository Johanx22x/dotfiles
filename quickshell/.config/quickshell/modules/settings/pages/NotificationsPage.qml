// How long a notification stays up, and what it does while it is there.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"
import "root:/modules/notifications"

SettingsPage {
    id: root

    title: "Notifications"
    glyph: Icons.bell
    keywords: ["notification", "timeout", "do not disturb", "dnd", "mute", "history"]

    SettingsSection {
        width: parent.width
        title: "Timing"

        StepperRow {
            glyph: Icons.clock
            label: "Default timeout"
            value: Config.notificationTimeout
            // Three seconds is about the floor for reading one line; past a
            // minute the panel stops clearing itself and the history is the
            // better tool anyway.
            from: 3
            to: 60
            step: 1
            suffix: " s"
            onMoved: value => Config.notificationTimeout = value

            hint: "Only for senders with no opinion of their own. One that "
                + "asks for a specific timeout still gets it, and critical "
                + "notifications keep their longer window."
        }
    }

    SettingsSection {
        width: parent.width
        title: "Do not disturb"

        // THE SAME SWITCH AS THE DASHBOARD'S AND THE SAME KEY, not a copy of
        // the state: all three write NotificationState, which owns the mute
        // and persists it. A settings window that kept its own idea of
        // whether notifications were muted would be a second answer to a
        // question that already has one.
        ToggleRow {
            glyph: NotificationState.dnd ? Icons.bellOff : Icons.bell
            label: "Mute notifications"
            checked: NotificationState.dnd
            onToggled: value => NotificationState.setDnd(value)
        }

        InfoRow {
            glyph: Icons.info
            label: "Critical notifications still get through"
            description: "Urgency 2 is what system tools use when something "
                + "is broken, this shell's own recorder included. A mute that "
                + "hid those would cost more than it saves."
        }
    }
}
