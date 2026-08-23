// Notifications, as the probe draws it: a red box in the corner carrying the
// unread count, and NO DAEMON.
//
// THE MISSING NotificationServer IS DELIBERATE AND IS THE ONE PLACE THIS
// FIXTURE REFUSES TO COPY genesis. That file owns
// org.freedesktop.Notifications -- the bus name, the server, the whole reason
// dunst is gone -- as well as drawing the cards, and themes/genesis/README.md
// already says it sits on the wrong side of the seam and is left there. A
// fixture is loaded by tests, tests run on a developer's own machine, and a
// second process claiming that bus name is a session whose notifications stop
// arriving where they were going. tests/shell-load.sh points the whole run at
// a dead bus so it cannot happen; not writing the server is the second lock on
// the same door.
//
// WHAT IT COSTS, said out loud rather than left to be discovered: this theme
// does not prove that a theme CAN host the daemon. Nothing under modules/
// reads the server or needs the window to exist -- NotificationState's `dnd`,
// `unread` and `markRead()` all work with no server and `history` simply stays
// empty -- so the host is not broken by the refusal, only unexercised.

import QtQuick
import Quickshell
import qs
import qs.modules.notifications

PanelWindow {
    id: root

    // The ShellScreen this surface belongs to, from Variants in shell.qml.
    required property var modelData

    screen: root.modelData

    anchors.top: true
    anchors.right: true

    implicitWidth: 160
    implicitHeight: 28

    visible: NotificationState.unread > 0
    color: "#ff0000"
    exclusionMode: ExclusionMode.Ignore

    Text {
        anchors.centerIn: parent

        text: `${NotificationState.unread} unread`
        color: "#ffff00"
        font.family: Theme.fontFamily
    }

    // THE LINE tests/shell-load.sh WATCHES FOR, and the only reason this
    // fixture prints anything at all. A theme swap rebuilds the surfaces
    // inside a running engine: nothing is written, nothing exits, and
    // "Configuration Loaded" is not printed a second time -- so from outside
    // the process there is no evidence it happened. Seven of these are.
    Component.onCompleted: console.log("theme-probe drew notifications/Notifications.qml")
}
