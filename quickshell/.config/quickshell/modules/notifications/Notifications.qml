// The notification daemon and the panel it draws, top right.
//
// This IS the daemon: NotificationServer takes org.freedesktop.Notifications
// on the session bus, which means dunst has to be gone before this runs --
// two processes cannot own the same bus name, and the second one to ask
// simply does not get it. Worse, dunst is D-Bus activated: kill it and the
// next notification starts it again if this shell is not up to answer first.
//
// SHAPE
// Not one floating card per notification: a single surface that hangs off
// the bar and grows as notifications arrive, with each notification a box
// inside it. It is flush with the bar's bottom edge and flush with the right
// side of the screen, so what it looks like is the bar bulging downwards --
// the same fillet that carries the bar into the sides of the screen carries
// it into this.
//
// WITH NO BAR UNDER IT that shape is wrong rather than merely unnecessary, so
// it comes apart: no fillet, no sheet behind the cards, corners kept. What is
// left is the notification and nothing else, which is roughly what dunst drew.
// See `undocked` -- it happens over a fullscreen window, and it happens on a
// main monitor that was never given a bar.
//
// The window takes input only where the panel is, so the area it spans while
// empty does not swallow clicks meant for the window underneath.

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/powermenu"

PanelWindow {
    id: root

    required property var modelData

    readonly property int count: server.trackedNotifications.values.length

    // Whether the bar is actually behind this panel right now.
    //
    // The whole shape below -- the fillet, the straight top edge, the
    // rectangle pushed up past the window -- assumes the bar is there to weld
    // to. A fullscreen window covers the Top layer, so it takes the bar away
    // while leaving this on Overlay, and the weld is left joining the panel to
    // nothing: a fillet hanging in mid air over the game.
    //
    // IS THE BAR ABSENT, for either of the two reasons it can be. A fullscreen
    // window covers it, and a monitor can also simply not carry one -- the bar
    // is per screen and which screens have it is a setting. Both mean this
    // panel has nothing to weld itself to.
    readonly property bool barCovered: !Screens.hasBar(root.modelData)
        || Compositor.hasFullscreenOn(root.modelData?.name ?? "")

    // NO BAR TO WELD TO, for either of the two reasons there can be one: it is
    // covered by a fullscreen window, or this monitor simply has no bar --
    // which became possible when the bar stopped being on every screen the
    // shell lives on. The shell's screen and the bar's screens are two
    // different lists now (see Screens.qml), and this panel follows the first
    // one: notifications belong on the monitor you are told to look at, which
    // is the main one, whether or not it happens to carry a bar.
    //
    // Everything below reads this rather than barCovered. The distinction the
    // drawing cares about is not WHY there is no bar, it is whether there is
    // one -- and a fillet welded to a bar that was never there looks exactly
    // as wrong as one welded to a bar a game is covering.
    readonly property bool undocked: root.barCovered || !Screens.hasBar(root.modelData)

    screen: modelData

    NotificationServer {
        id: server

        // Declare what the shell can actually render, so senders do not
        // downgrade their notifications for nothing.
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
    Connections {
        target: NotificationState

        function onDndChanged(): void {
            if (!NotificationState.dnd)
                return;
            for (const existing of server.trackedNotifications.values.slice())
                existing.dismiss();
        }
    }

    WlrLayershell.namespace: "quickshell-notifications"

    // Top normally, Overlay once the bar is covered.
    //
    // Top is the right home most of the time: it puts the tray menus and the
    // power menu -- both on Overlay -- ABOVE a notification. A menu was opened
    // deliberately and is being read; a notification arrives by itself and can
    // wait.
    //
    // But stacking against a fullscreen window turned out to depend on which
    // surface was mapped FIRST. A notification that arrived before the window
    // went fullscreen ended up underneath it, while one that arrived after came
    // out on top: the same panel behaving two ways depending on the order of
    // events. Moving to Overlay for as long as the bar is covered settles it,
    // and costs nothing -- over a fullscreen window there is no menu to lose
    // to anyway.
    WlrLayershell.layer: root.undocked ? WlrLayer.Overlay : WlrLayer.Top

    anchors {
        top: true
        right: true
    }

    margins {
        // Flush with the bar and flush with the screen edge: the panel has to
        // look like part of the bar, and a gap on either side would break it.
        top: Theme.barHeight
        right: 0
    }

    // What the panel actually shows, before the rectangle is grown past the
    // window edges to hide its other corners.
    readonly property int panelHeight: stack.implicitHeight + Theme.notificationPadding * 2

    // The fillet lives to the LEFT of the panel, outside it, so the window is
    // that much wider than what it draws.
    implicitWidth: Theme.notificationWidth + Theme.notificationPadding * 2 + Theme.barCornerRadius
    implicitHeight: root.panelHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    color: "transparent"

    // Nothing to show: no surface at all, rather than an invisible window
    // sitting over the corner of the screen.
    //
    // And nothing while the power menu is up. Both live on the Overlay layer,
    // so which one wins is down to the order the surfaces happened to be
    // created in -- not something to leave to chance when one of the two is a
    // modal sheet asking whether to end the session. A notification arriving
    // mid-decision is also exactly the wrong moment to be covering a button
    // labelled "Shut down". They are not lost: the panel comes back with them
    // still in it as soon as the menu closes.
    visible: root.count > 0 && !PowerMenuState.isOpen

    exclusionMode: ExclusionMode.Ignore

    // Input only where the panel is; the fillet is decoration.
    mask: Region {
        item: panel
    }

    // Welds the panel to the bar on its open side: material ADDED outside the
    // panel, filling the angle. The bottom corners are the panel's own
    // rounding, which is the opposite operation.
    CornerWedge {
        anchors.left: parent.left
        anchors.top: parent.top
        corner: "topRight"
        radius: Theme.barCornerRadius
        fillColor: panel.color

        // Only when there is a bar to weld to. Over a fullscreen window this
        // fillet is a wedge of panel colour joined to nothing.
        visible: !root.undocked
    }


    // THE ROUNDING IS UNIFORM, AND THE SQUARE EDGES ARE CLIPPED AWAY.
    //
    // The obvious way to write this is bottomLeftRadius on its own with the
    // other three at zero. Do not: Rectangle's per-corner radius path is NOT
    // antialiased -- setting `antialiasing: true` changes nothing -- and the
    // curve comes out as 2-3px stair steps. Verified by swapping one for the
    // other and comparing the same corner: uniform `radius` gives a clean
    // one-pixel gradient, per-corner gives blocks.
    //
    // So the rectangle uses a plain `radius` and is pushed BEYOND the window
    // upwards, behind the bar. The window clips that, so the edge meeting the
    // bar comes out straight while BOTH bottom corners round normally.
    Rectangle {
        id: panel

        anchors.left: parent.left
        anchors.leftMargin: Theme.barCornerRadius
        anchors.right: parent.right
        anchors.top: parent.top
        // Pushed up behind the bar so the window clips its top corners
        // straight -- but only when the bar is there. Over a fullscreen window
        // it sits where it is and keeps all four corners, which is what a card
        // floating over a game should look like anyway.
        anchors.topMargin: root.undocked ? 0 : -Theme.barCornerRadius

        height: root.panelHeight + (root.undocked ? 0 : Theme.barCornerRadius)

        radius: Theme.barCornerRadius
        antialiasing: true

        // Nothing behind the cards once it has come away from the bar. The
        // sheet exists to make the panel read as the bar bulging downwards; 
        // with no bar there it is just a slab of glass floating over someone's
        // game, and NotificationCard already carries its own background and
        // rounding. Undocked, what is left is the notification and nothing
        // else -- which is what dunst looked like.
        color: root.undocked ? "transparent" : Theme.glass(Theme.surface)

        // The panel grows and shrinks as notifications come and go; animating
        // the height is what makes it read as one thing expanding rather than
        // as cards appearing out of nowhere.
        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }

    // The content is positioned against the WINDOW, not against the rectangle
    // above: that one is deliberately larger than what is visible.
    Column {
        id: stack

        anchors.left: parent.left
        anchors.leftMargin: Theme.barCornerRadius + Theme.notificationPadding
        anchors.top: parent.top
        anchors.topMargin: Theme.notificationPadding

        spacing: Theme.notificationGap

        Repeater {
            model: server.trackedNotifications

            NotificationCard {
                required property Notification modelData

                notification: modelData

                // Each card slides in from the right as it arrives.
                x: Theme.notificationWidth

                Component.onCompleted: x = 0

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
