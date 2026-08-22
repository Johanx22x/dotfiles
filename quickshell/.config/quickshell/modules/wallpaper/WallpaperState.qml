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
// MUTUAL EXCLUSION IS NOT IN THIS FILE ANY MORE. The carousel is one of the
// five surfaces that may not share the screen -- a fullscreen sheet on the
// Overlay layer holding an exclusive keyboard grab, so everything else is both
// behind it and deaf while it is up. Which five they are and what happens when
// one goes up is modules/Surfaces.qml. Without that rule SUPER + SPACE over an
// open carousel leaves two surfaces holding the keyboard and the one that
// answers is whichever the compositor happened to hand it to.
//
// WHAT WAS HERE was this file's own copy of a mesh: five singletons closed on
// the way up and three Connections for the way back, beside a nearly identical
// block in CheatsheetState and two more in Bar.qml. Every new surface had to be
// added to each of them, and the one that was not -- the power menu, which
// closed nothing -- is the hole the rule was written to remove. The header used
// to enumerate the list by name so an addition could not leave a stale total;
// there is one list now, and it lives with the code that acts on it.
//
// DO NOT name an IPC function `show` -- `qs ipc show` is a subcommand of the
// CLI and swallows the call, printing the handler listing and exiting 0. It
// looks exactly like a call that ran and did nothing. See PowerMenuState.

pragma Singleton

import Quickshell
import Quickshell.Io

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
