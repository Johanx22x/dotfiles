// How long a notification stays up -- one answer per urgency -- and what
// it does while it is there.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"
import "root:/modules/notifications"

SettingsPage {
    id: root

    title: "Notifications"
    glyph: Icons.bell
    keywords: ["notification", "timeout", "expire", "urgency", "low",
        "normal", "critical", "do not disturb", "dnd", "mute", "history"]

    // ONE SECTION AND THREE ROWS, not three sections and not three rows with
    // three different marks on them. The three are one idea -- how long a
    // notification stays up -- read down a scale from the least urgent to the
    // most, and the section title is the question every row answers. Which is
    // also why they all carry the same clock: three different glyphs would
    // say these were three unrelated settings that happen to sit together.
    //
    // The order is the spec's own, 0 to 2, so the row you want is where its
    // urgency is rather than where somebody thought it belonged.
    SettingsSection {
        width: parent.width
        glyph: Icons.clock
        title: "Timeout by urgency"

        StepperRow {
            glyph: Icons.clock
            label: "Low"
            value: Config.notificationTimeoutLow
            // The same range as normal, because until this change they were
            // the same setting: three seconds is about the floor for reading
            // one line, and past a minute the panel stops clearing itself and
            // the history is the better tool anyway.
            from: 3
            to: 60
            step: 1
            suffix: " s"
            onMoved: value => Config.notificationTimeoutLow = value

            hint: "Urgency 0 — the ones that would be fine to miss. A track "
                + "change, a download that finished."
        }

        StepperRow {
            glyph: Icons.clock
            label: "Normal"
            value: Config.notificationTimeout
            from: 3
            to: 60
            step: 1
            suffix: " s"
            onMoved: value => Config.notificationTimeout = value

            hint: "Urgency 1 — nearly everything, and what a sender that "
                + "says nothing about urgency gets. A message, a mail."
        }

        StepperRow {
            glyph: Icons.clock
            label: "Critical"
            value: Config.notificationTimeoutCritical
            // ITS OWN RANGE, wider and coarser, because this is the one you
            // may not be at the desk for: ten seconds is the shortest that
            // could still be called a warning, three minutes is long enough
            // to come back from another room, and the step is ten because
            // nobody tunes an alarm to the second.
            //
            // BOUNDED AT BOTH ENDS LIKE THE OTHERS, and the top of the range
            // is the reason: "never" is not on offer here either. See the
            // header of NotificationCard.qml.
            from: 10
            to: 180
            step: 10
            suffix: " s"
            onMoved: value => Config.notificationTimeoutCritical = value

            hint: "Urgency 2 — something is broken. This shell's own recorder "
                + "uses it, and so do the system's own tools."
        }

        // ONCE, UNDER THE THREE, rather than repeated in each row's note:
        // this is true of all of them, and a sentence that appears three
        // times reads as three different sentences that have to be compared.
        SectionNote {
            topPadding: 4
            bottomPadding: 4

            text: "These are for senders with no opinion of their own. One "
                + "that asks for a specific timeout still gets it, and "
                + "“never expire” is refused whatever the urgency — it is "
                + "asked for far too easily, and the answer is a panel that "
                + "only grows."
        }
    }

    SettingsSection {
        width: parent.width
        title: "Do not disturb"

        // THE SAME SWITCH AS THE NOTIFICATION PANEL'S AND THE SAME KEY, not
        // a copy of the state: every door writes NotificationState, which owns
        // the mute and persists it. A settings window that kept its own idea
        // of whether notifications were muted would be a second answer to a
        // question that already has one.
        //
        // The panel's copy is the one that is actually reached for -- it is
        // beside the list it silences. This one is here because a setting with
        // a page has to be ON that page: somebody looking for the mute in the
        // settings window and not finding it would conclude the shell has
        // none.
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
