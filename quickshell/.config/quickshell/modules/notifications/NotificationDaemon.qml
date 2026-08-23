// THE NOTIFICATION DAEMON, and the whole of what answers the bus.
//
// This IS the daemon: NotificationServer below takes
// org.freedesktop.Notifications on the session bus, which means dunst has to be
// gone before this runs -- two processes cannot own the same bus name, and the
// second one to ask simply does not get it. Worse, dunst is D-Bus activated:
// kill it and the next notification starts it again if this shell is not up to
// answer first.
//
// IT USED TO BE IN A THEME. Every line below was inside
// themes/genesis/notifications/Notifications.qml, welded to the panel that
// stacks the cards, and the README beside that file carried a paragraph saying
// so in as many words -- "One thing sits on the wrong side and is left there."
// It was left there because splitting it is logic and not a move.
//
// WHAT MADE IT WORTH DOING is the second theme. Answering the bus is not
// drawing: a theme that had to carry this would have had to reimplement the bus
// name, the two stack-tag hints, the claim that makes a notification exist at
// all and the do-not-disturb drop -- correctly, in full -- or the desktop would
// have had NO notifications whatsoever for as long as that theme was selected.
// A missing widget is a theme's business; a missing notification daemon is not.
//
// WHAT A THEME IS HANDED, and it is two properties and no functions:
//
//   tracked   the model to hand a Repeater, one entry per notification on
//             screen right now
//   count     how many are in it, for a panel that has to know whether to be
//             a window at all
//
// Everything that decides WHICH notifications are in that model -- what is
// ignored, what the mute swallows, what a stack tag retires -- is below, where
// there is one copy of it. A theme reads the model and draws it. The card
// itself is components/NotificationCard.qml, which is where the click that
// dismisses one, and the difference between dismissing and expiring, are
// spelled out.
//
// AND IT IS ARMED FROM shell.qml, like the services and like Surfaces. A
// Quickshell singleton is not created until something asks for it, and the only
// thing that ever asks for this one is the surface drawing the cards -- so a
// theme with no notification panel would be a desktop with no notification
// daemon on it, silently, and dunst would be started by D-Bus the first time
// anything sent one. Owning the bus name is not conditional on somebody
// drawing.

pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
// For Connections, and for the array walk below.
import QtQuick

Singleton {
    id: root

    // Read by shell.qml to bring this singleton into existence at startup --
    // see the last paragraph of the header.
    readonly property bool armed: true

    // WHAT IS ON SCREEN RIGHT NOW, as a model a Repeater takes directly. It is
    // the server's own ObjectModel and not a copy: a copy would be a second
    // thing to keep in step with the claiming below, and the model already
    // notifies on every add and remove.
    readonly property var tracked: server.trackedNotifications

    // HOW MANY, so a panel does not have to reach through `tracked.values` to
    // find out whether it should be a window at all.
    readonly property int count: server.trackedNotifications.values.length

    NotificationServer {
        id: server

        // Declare what the shell can actually render, so senders do not
        // downgrade their notifications for nothing.
        //
        // IT IS THE SHELL AND NOT THE THEME THAT ANSWERS THIS. GetCapabilities
        // is asked once, by a sender, before anything is drawn, and a theme
        // swap does not re-ask it -- so these four cannot follow the theme even
        // if a theme had an opinion. What they promise is that the host's card
        // facade renders a body, markup, an image and actions, which it does.
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        // Notifications survive a config reload instead of vanishing every
        // time a .qml is saved.
        keepOnReload: true

        // STACK TAGS, and why they have to be named here.
        //
        // A sender that fires the same notification over and over -- a volume
        // key, a brightness key, ~/.local/bin/capture-card-audio -- does not
        // want six of them piling up; it wants the previous one replaced. The
        // spec has no hint for that, so daemons invented their own, and a
        // notification carrying one is asking to be grouped.
        //
        // `hints` only ever contains the hints the spec defines PLUS the ones
        // listed here. Anything else is dropped before it reaches QML, so
        // without this line the tag simply is not there to read and the
        // grouping below would silently never fire.
        //
        // Both names are accepted because senders are split between them:
        // x-dunst-stack-tag is dunst's, which is what the scripts on this
        // machine were written against, and x-canonical-private-synchronous is
        // the older notify-osd one that GNOME-era software still emits.
        extraHints: ["x-dunst-stack-tag", "x-canonical-private-synchronous"]

        // The tag a notification is asking to be grouped under, or "" for the
        // ordinary kind that should just stack.
        function stackTag(notification: var): string {
            return notification.hints?.["x-dunst-stack-tag"]
                ?? notification.hints?.["x-canonical-private-synchronous"]
                ?? "";
        }

        // WITHOUT THIS NOTHING IS EVER SHOWN.
        // Quickshell does not keep notifications by default: one arrives, the
        // signal fires, and unless someone claims it the object is dropped
        // and trackedNotifications stays empty. Verified the hard way -- the
        // daemon owned the bus name and received every message with
        // `tracked: false`, so no window was ever built.
        //
        // Claiming it here means "this shell is displaying it"; releasing it
        // is what dismiss() and expire() do.
        // Music notifications are handled elsewhere in the shell, so they are
        // deliberately NOT claimed here: leaving one untracked is what drops
        // it. ~/.local/bin/mpris-notify is what sends them (dunstify -a
        // "mpris-notify"), fired by the browser changing track.
        readonly property var ignoredApps: ["mpris-notify"]

        onNotification: notification => {
            if (ignoredApps.includes(notification.appName))
                return;

            // Do not disturb. Not claiming it is what drops it -- the same
            // mechanism the ignored apps above go through. Critical is let
            // through on purpose; the reasoning for both is in
            // NotificationState.qml.
            const silenced = NotificationState.dnd && notification.urgency !== NotificationUrgency.Critical;

            // Written down BEFORE the decision to show it, and regardless of
            // which way that goes: the history is what arrived here, not what
            // made it to the screen. Recorded here rather than deeper in, so
            // there is exactly one line in this file where a notification
            // enters the shell and one place that can forget to log it.
            NotificationState.record(notification, silenced);

            if (silenced)
                return;

            // Retire whatever is already on screen under the same tag, so the
            // panel shows the LATEST state of that thing rather than its
            // history. Nudging the capture card's volume five times leaves one
            // card reading the final value, not five cards counting up.
            const tag = server.stackTag(notification);
            if (tag) {
                // Collected first and dismissed after: dismiss() removes the
                // entry from the very model being walked, and mutating a list
                // mid-iteration skips elements.
                const stale = server.trackedNotifications.values.filter(existing => server.stackTag(existing) === tag);
                for (const existing of stale)
                    existing.dismiss();
            }

            notification.tracked = true;
        }
    }

    // Switching do-not-disturb ON clears what is already up.
    //
    // The gesture is "shut up", and a panel that keeps three cards on screen
    // after it has been muted has half-obeyed. They are dismissed rather than
    // expired: dismiss() is the deliberate close, which is what tells an
    // application like Discord to stop re-sending the same thing.
    //
    // Collected into a plain array first, because dismiss() removes the entry
    // from the very model being walked and mutating a list mid-iteration skips
    // elements -- the same trap the stack-tag code above documents.
    //
    // IT IS ON THIS SIDE AND NOT IN THE PANEL, which is the clearest single
    // reason the daemon moved. Emptying the model is the mute being obeyed, and
    // it has to happen whether or not anything is drawing the model -- a theme
    // that forgot this clause would keep the cards up over a desktop that had
    // been told to be quiet, and a theme cannot be asked to remember it.
    Connections {
        target: NotificationState

        function onDndChanged(): void {
            if (!NotificationState.dnd)
                return;
            for (const existing of server.trackedNotifications.values.slice())
                existing.dismiss();
        }
    }
}
