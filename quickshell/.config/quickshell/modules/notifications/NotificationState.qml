// Do not disturb, and the history of what has been through here.
//
// The daemon in Notifications.qml still ANSWERS the bus while the mute is on --
// it has to, it owns org.freedesktop.Notifications and refusing to answer
// would make senders think the desktop has no notification support at all.
// What changes is what happens next: the notification is not claimed, so
// Quickshell drops it and no card is ever built. See the header of
// Notifications.qml for why claiming is what puts one on screen.
//
// CRITICAL STILL GETS THROUGH. Urgency 2 is not what applications reach for
// to be noticed -- browsers and chat clients use Normal -- it is what system
// tools use when something is broken, this shell's own recorder included
// ("Instant replay stopped"). A mute that hides those is a mute that costs
// more than it saves.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // ---------------- Do not disturb ----------------

    // IT OUTLIVES THE SHELL, and that is a deliberate trade.
    //
    // Against: a switch that persists can be left on overnight and quietly
    // swallow a day of notifications. For: this config reloads itself every
    // time a .qml is saved, and a mute that turned itself off on every reload
    // would be a mute in name only -- it would come back on exactly when you
    // were not watching for it.
    //
    // What settles it is that the state is never invisible: the bar carries a
    // badge for as long as this is true, so being muted is a thing on screen
    // rather than a thing to remember. Same file the replay buffer uses for
    // its length -- Quickshell's state directory, not the config, because the
    // config is a stow tree of symlinks into a git repo.
    readonly property bool dnd: config.dnd

    // How many have gone by unseen since the mute went on.
    //
    // UNREAD, NOT "SILENCED", and the difference is the whole point of the
    // history below. The number is a debt: it is what you have not looked at,
    // so opening the list pays it off (markRead) even though the entries stay
    // there to be read again. Counting "silenced" instead would leave a number
    // on the bar that no amount of reading could clear.
    property int unread: 0

    function setDnd(value: bool): void {
        if (value === config.dnd)
            return;
        config.dnd = value;
        root.unread = 0;
    }

    function toggle(): void {
        root.setDnd(!root.dnd);
    }

    function markRead(): void {
        root.unread = 0;
    }

    // ---------------- History ----------------
    //
    // WHY THERE IS ONE AT ALL: a mute whose only trace is a number is a mute
    // that loses things. The count says four went by; this says which four.
    //
    // IT KEEPS EVERYTHING, not only what the mute swallowed. "What arrived
    // while I was muted" and "what arrived while I was in the kitchen" are the
    // same question, and a list that answered only the first would be a list
    // you could not trust -- you would still have to remember whether the mute
    // was on at the time. The ones that were silenced are marked instead, so
    // the narrower question is still answerable at a glance.
    //
    // PLAIN OBJECTS AND NOT THE NOTIFICATIONS THEMSELVES. A Notification is
    // owned by the server and destroyed the moment it is dropped or dismissed,
    // so a list of them would be a list of dangling handles. The fields worth
    // keeping are copied out while the object is still alive, which is also
    // why `actions` are NOT among them: an action is a call back into the
    // sending application about a notification it has already closed.
    //
    // IN MEMORY, NOT ON DISK. It is gone when the shell restarts, and that is
    // the intent: this answers "what did I miss just now", not "what did this
    // machine tell me last Tuesday". Writing message bodies to disk to answer
    // a question nobody asked is a cost with no matching benefit.
    property var history: []

    // Old entries fall off the end. Anything past a hundred is not being
    // caught up on, it is being scrolled past.
    readonly property int historyLimit: 100

    function record(notification: var, silenced: bool): void {
        // Newest first: the list is read from the top, and the thing you want
        // is almost always the thing that just happened.
        //
        // Reassigned rather than mutated in place -- a var property does not
        // notify on push(), so the list would grow with nothing on screen
        // changing.
        root.history = [
            {
                appName: notification.appName ?? "",
                summary: notification.summary ?? "",
                body: notification.body ?? "",
                // Both, and resolved at draw time. `image` is the picture the
                // sender attached and may be a provider URL tied to a
                // notification that no longer exists; `appIcon` is a themed
                // name and outlives everything. The row tries them in order
                // and falls back to a glyph, so a dead URL costs nothing.
                image: notification.image ?? "",
                appIcon: notification.appIcon ?? "",
                critical: notification.urgency === NotificationUrgency.Critical,
                silenced: silenced,
                time: Date.now()
            },
            ...root.history
        ].slice(0, root.historyLimit);

        if (silenced)
            root.unread += 1;
    }

    function clearHistory(): void {
        root.history = [];
        root.unread = 0;
    }

    // ---------------- Persistence ----------------

    FileView {
        id: settings

        path: Quickshell.statePath("notifications.json")
        watchChanges: true

        // The first run has no file to read, which is not a fault worth
        // printing: onLoadFailed writes the defaults and the next read finds
        // them.
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: config

            property bool dnd: false
        }
    }

    // `enable` and `disable` rather than `on` and `off`: a QML member whose
    // name starts with "on" is parsed as a signal handler, and `on` alone is
    // the shape that invites the parser to try.
    IpcHandler {
        target: "dnd"

        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.setDnd(true);
        }

        function disable(): void {
            root.setDnd(false);
        }

        function status(): string {
            return root.dnd ? `on, ${root.unread} unread` : "off";
        }
    }
}
