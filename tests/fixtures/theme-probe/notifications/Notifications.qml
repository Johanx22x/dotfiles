// Notifications, as the probe draws it: a red box in the corner carrying the
// unread count, and NO DAEMON.
//
// THERE IS NO NotificationServer IN HERE AND THERE IS NOWHERE TO PUT ONE.
// It used to be a refusal: genesis owned org.freedesktop.Notifications from
// inside notifications/Notifications.qml, themes/genesis/README.md said that
// was the wrong side of the seam, and this file declined to copy it because a
// fixture is loaded by tests, tests run on a developer's own machine, and a
// second process claiming that bus name is a session whose notifications stop
// arriving where they were going.
//
// The daemon is modules/notifications/NotificationDaemon.qml now, in the host,
// armed from shell.qml -- so loading this theme starts it exactly as loading
// genesis does, and the refusal has nothing left to refuse. What kept a test
// run off the session bus is now the only thing keeping it off:
// tests/shell-load.sh unsets DBUS_SESSION_BUS_ADDRESS, and tests/scheme-pinning.sh
// points it at a path with no bus behind it. That was always the lock that did
// the work; this file's silence was the second one, and it is gone.
//
// WHAT THIS THEME DRAWS INSTEAD OF CARDS is the unread count and nothing else,
// which is a legal theme rather than an incomplete one: the daemon does not
// need anybody to draw its model for it to answer the bus, and that is the
// property the move was for.

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
