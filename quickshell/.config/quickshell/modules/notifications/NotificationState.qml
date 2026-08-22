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
import "root:/"

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

    // ---------------- Where the list is ----------------
    //
    // THE SAME SHAPE AS IslandState.dashboardScreen, and the long version of
    // why is over there: the connector name of the bar drawing the history, or
    // "" when it is down. These two are the same kind of thing -- one panel,
    // summoned by a key, drawn inside a popout there is one of per bar -- and
    // they were the same bug. They must not now be two different mechanisms.
    //
    // This was a pair of signals, with a note saying whether the list is up is
    // the popout's business and a flag here would be a second source of truth.
    // True while the panel could only appear where it was asked for; false once
    // it had to FOLLOW THE FOCUS, which needs somebody who can see all the bars
    // at once, and no popout can.
    property string historyScreen: ""

    // THE PLACE IN THE LIST, carried across a MOVE and dropped by a close.
    //
    // Moving rebuilds the panel on the other monitor -- a layer surface belongs
    // to one output -- and a rebuilt ListView starts at the top, which would
    // throw away a long scroll because the pointer crossed a monitor edge. So
    // the offset lives out here, where it outlives the list that displays it,
    // which is the same argument the dashboard's tab index was moved out on;
    // see the note in IslandState.
    //
    // CLEARED ON A CLOSE and not on a move, which is the whole distinction:
    // "what did I miss" starts at the top every time you open it, and only a
    // panel that never went away keeps its place.
    property real historyScroll: 0

    onHistoryScreenChanged: if (root.historyScreen === "")
        root.historyScroll = 0

    // TWO BEHAVIOURS, NOT TWO DOORS. A key pressed by mistake should put the
    // panel away when it is pressed again; a badge that has already sent you to
    // the list should not close the thing it just opened. What tells them apart
    // is toggle against open, and every caller names the bar it means -- the
    // key by asking Screens, a click by knowing which bar it landed on.
    function toggleHistory(): void {
        root.toggleHistoryOn(Screens.panelScreen?.name ?? "");
    }

    // The same two with the bar named, for the bell and the badge: a click
    // lands on one bar and does not have to ask where the panel belongs. From
    // then on it follows the focus like any other, because this singleton
    // cannot tell how the panel came to be up and should not.
    function openHistoryOn(name: string): void {
        root.historyScreen = name;
    }

    function toggleHistoryOn(name: string): void {
        root.historyScreen = root.historyScreen === name ? "" : name;
    }

    // AND IT MOVES, off the settled answer rather than the live one -- see the
    // note over settledPanelScreen in Screens.qml for why a focus that follows
    // the mouse must not drag a panel across on its way past. Identical to the
    // dashboard's rule in IslandState, deliberately: two panels behaving
    // differently on the same monitor is the thing this is meant to stop.
    Connections {
        target: Screens

        function onSettledPanelScreenChanged(): void {
            if (root.historyScreen === "")
                return;

            const moved = Screens.settledPanelScreen?.name ?? "";

            if (moved !== "")
                root.historyScreen = moved;
        }
    }

    // The keyboard's way in, SUPER + SHIFT + N. Without it the only doors are
    // the bell, which a bar can be told not to draw, and the do-not-disturb
    // badge, which exists only while the mute is on -- and "what did I miss"
    // is a question you ask when you sit back down, whether or not the mute
    // was ever switched on.
    //
    // ITS OWN TARGET rather than a second function on "dnd" below: the mute
    // and the record of what got through are two different things, and
    // `qs ipc call dnd history` would read as the history OF the mute. It used
    // to be `island notifications`, which was only true while the list was a
    // tab of the island's dashboard.
    IpcHandler {
        target: "notifications"

        function history(): void {
            root.toggleHistory();
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
