// Whether the launcher is up, and the ways of asking for it.
//
// Same shape as PowerMenuState: a flag plus an IpcHandler, so the keybind in
// hyprland.lua is `qs ipc call launcher toggle` and the compositor does not
// have to know anything about the shell beyond that. It also replaces what
// the old wofi script did with `pgrep wofi` and a kill-and-wait loop --
// pressing the shortcut twice is a toggle because the state lives in one
// place, not because a second process looked for the first one.
//
// MUTUAL EXCLUSION IS NOT IN THIS FILE, and it used to be half in it. The
// launcher is one of the five surfaces that may not share the screen -- it
// takes an exclusive keyboard grab, and it hangs from the bar's underside in
// the same place the island's dashboard does, where neither is readable
// through the other. Which five they are and what happens when one goes up is
// modules/Surfaces.qml, in one place rather than a clause per pair.
//
// WHAT WAS HERE: a `popoutOpen` flag the bars published into, and a handler
// that closed the launcher when it turned true. Both moved to Surfaces
// unchanged, including the reason the flag is a report and not a request. And
// before that there was a `dashboardOpen` assigned false to put the dashboard
// away, which closed nothing at all: it changed a mirror and left the panel on
// screen. That story is worth keeping and now lives beside the flag it is
// about.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    // Which picker to land on when the launcher next opens. Consumed and
    // cleared by Launcher.qml, so it is a request rather than state: the
    // launcher owns which screen it is showing.
    //
    // This is what lets a keybind open straight into the clipboard instead of
    // making the user type ">clipboard" every time.
    property string pendingPicker: ""

    function open(): void {
        root.isOpen = true;
    }

    function openPicker(name: string): void {
        root.pendingPicker = name;
        root.isOpen = true;
    }

    function close(): void {
        root.isOpen = false;
    }

    function toggle(): void {
        root.isOpen = !root.isOpen;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function clipboard(): void {
            root.openPicker("clipboard");
        }
    }
}
