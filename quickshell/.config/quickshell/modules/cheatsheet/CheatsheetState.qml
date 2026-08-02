// Whether the cheatsheet is showing, and the rule that keeps it alone.
//
// Same shape as PowerMenuState and LauncherState: a flag plus an IpcHandler,
// so the SUPER + / bind in hyprland.lua is just
//
//   qs ipc call cheatsheet toggle
//
// and the compositor knows nothing about the shell beyond that name.
//
// MUTUAL EXCLUSION
// This is a fullscreen sheet, so everything else in the shell is behind it and
// none of it is reachable while it is up. Opening the cheatsheet therefore
// closes the launcher, the dashboard and the power menu, and any of those
// opening closes the cheatsheet.
//
// The rule lives HERE, in the newcomer, and not spread across the three older
// singletons -- the same reason LauncherState owns its half of the arbitration
// with the island: one file to read when the windows disagree about who is up.
// The dashboard is reached through LauncherState.dashboardOpen, which Bar.qml
// keeps wired to the popout in both directions.
//
// DO NOT name an IPC function `show`: `qs ipc show` is a CLI subcommand and it
// swallows the call, printing the handler listing and exiting 0. It looks
// exactly like a call that ran and did nothing. See PowerMenuState.

pragma Singleton

import Quickshell
import Quickshell.Io
// For Connections. A singleton that only declares properties does not need
// QtQuick; the two handlers below do.
import QtQuick
import "root:/modules/launcher"
import "root:/modules/powermenu"

Singleton {
    id: root

    property bool isOpen: false

    function close(): void {
        root.isOpen = false;
    }

    function toggle(): void {
        root.isOpen = !root.isOpen;
    }

    onIsOpenChanged: {
        if (!root.isOpen)
            return;

        LauncherState.isOpen = false;
        LauncherState.dashboardOpen = false;
        PowerMenuState.isOpen = false;
    }

    // The other direction. Written as three handlers rather than one binding
    // because each acts on a property it does not own, and a binding can only
    // own one.
    Connections {
        target: LauncherState

        function onIsOpenChanged(): void {
            if (LauncherState.isOpen)
                root.isOpen = false;
        }

        function onDashboardOpenChanged(): void {
            if (LauncherState.dashboardOpen)
                root.isOpen = false;
        }
    }

    Connections {
        target: PowerMenuState

        function onIsOpenChanged(): void {
            if (PowerMenuState.isOpen)
                root.isOpen = false;
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.close();
        }
    }
}
