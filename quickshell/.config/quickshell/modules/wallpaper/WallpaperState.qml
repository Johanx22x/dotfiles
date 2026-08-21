// Whether the wallpaper carousel is showing, and the ways of asking for it.
//
// Same shape as PowerMenuState, and for the same reason: the things that open
// it are not in the carousel's own QML tree. A keybind is not in the tree at
// all, and the settings window's Wallpaper page is a different surface
// entirely -- both need to reach the same boolean.
//
// The keybind is SUPER + SHIFT + W, which used to step to the next wallpaper:
//
//   qs ipc call wallpaper toggle
//
// WHY THE STEPPING BINDS ARE GONE. SUPER+SHIFT+W walked the folder forwards
// and SUPER+SHIFT+A picked at random, and neither could tell you what you
// were about to get: with fifty images in the collection, "next" is a
// lottery you play one keypress at a time. Choosing a wallpaper is done by
// LOOKING, so the one bind opens the thing that shows you the pictures.
// Random survives as a launcher command, where it reads as the deliberate
// "surprise me" it is.
//
// MUTUAL EXCLUSION
// The carousel is a fullscreen sheet that takes an EXCLUSIVE keyboard grab, so
// everything else in the shell is both behind it and deaf while it is up.
// Opening it therefore closes the launcher, the dashboard, the power menu and
// the cheatsheet, and any of those opening closes it. Without this rule
// SUPER + SPACE over an open carousel leaves two surfaces holding the keyboard
// and the one that answers is whichever the compositor happened to hand it to.
//
// The rule lives HERE, in the newcomer, which is the convention CheatsheetState
// set and states: one file to read when the windows disagree about who is up,
// rather than a clause added to each of the four older singletons. The
// dashboard is reached through LauncherState.dashboardOpen, which Bar.qml keeps
// wired to the popout in both directions.
//
// DO NOT name an IPC function `show` -- `qs ipc show` is a subcommand of the
// CLI and swallows the call, printing the handler listing and exiting 0. It
// looks exactly like a call that ran and did nothing. See PowerMenuState.

pragma Singleton

import Quickshell
import Quickshell.Io
// For Connections. A singleton that only declares properties does not need
// QtQuick; the handlers below do.
import QtQuick
import "root:/modules/launcher"
import "root:/modules/powermenu"
import "root:/modules/cheatsheet"

Singleton {
    id: root

    property bool isOpen: false

    function open(): void {
        root.isOpen = true;
    }

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
        CheatsheetState.isOpen = false;
    }

    // The other direction. Written as handlers rather than as a binding
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

    Connections {
        target: CheatsheetState

        function onIsOpenChanged(): void {
            if (CheatsheetState.isOpen)
                root.isOpen = false;
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }
}
