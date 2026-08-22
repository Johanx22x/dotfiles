// Whether the cheatsheet is showing.
//
// Same shape as PowerMenuState and LauncherState: a flag plus an IpcHandler,
// so the SUPER + / bind in hyprland.lua is just
//
//   qs ipc call cheatsheet toggle
//
// and the compositor knows nothing about the shell beyond that name.
//
// MUTUAL EXCLUSION IS NOT IN THIS FILE ANY MORE, and reading the rule off this
// header would be reading it in the wrong place. The cheatsheet is one of the
// five surfaces that may not share the screen -- it is a fullscreen sheet on
// the Overlay layer holding an exclusive keyboard grab, so everything else in
// the shell is both behind it and deaf while it is up. Which five they are,
// which one wins, and what a grab has to do with it: modules/Surfaces.qml.
//
// WHAT WAS HERE WAS HALF OF A MESH. This file closed four singletons on the way
// up -- LauncherState, IslandState, NotificationState, PowerMenuState -- and
// three Connections watched two of them for the way back. WallpaperState next
// door carried the same block with five entries, Bar.qml carried two more, and
// PowerMenuState carried none, which is exactly how the power menu came to
// leave a popout up behind it for longer than either sheet ever did. Ten pairs
// spelled out in five files, and the sixth surface would have needed six edits
// to arrive. It is one function now.
//
// THE HEADER USED TO ENUMERATE WHAT THIS FILE CLOSED, deliberately, so that an
// addition could not leave a stale total behind. That was the right defence for
// a list kept by hand, and it is why the list above is a pointer instead: there
// is one membership now and it is written where the code that acts on it is,
// so there is nothing here to fall out of step.
//
// DO NOT name an IPC function `show`: `qs ipc show` is a CLI subcommand and it
// swallows the call, printing the handler listing and exiting 0. It looks
// exactly like a call that ran and did nothing. See PowerMenuState.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    function close(): void {
        root.isOpen = false;
    }

    function toggle(): void {
        root.isOpen = !root.isOpen;
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
