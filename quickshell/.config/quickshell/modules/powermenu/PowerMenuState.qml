// Whether the power menu is showing, and the two ways of asking for it.
//
// The state lives in a singleton rather than inside the menu window because
// the thing that opens it is somewhere else entirely: PowerButton sits in the
// bar, which is its own layer surface, and a keybind does not sit in the QML
// tree at all. Both need to reach the same boolean.
//
// The IpcHandler is what replaces the old script's `pgrep wofi` dance. That
// script had to guess whether the menu was already up by looking at the
// process list, kill it, and wait for the layer to be released. Here the menu
// IS the shell, so the keybind just toggles a property:
//
//   qs ipc call powermenu toggle
//
// See the SUPER + SHIFT + ESCAPE bind in hyprland.lua.
//
// DO NOT name an IPC function `show`. `qs ipc show` is a subcommand of the
// CLI, and `qs ipc call powermenu show` is swallowed by it: the listing of
// handlers is printed, the function is never called, and the exit status is
// 0. It looks exactly like a call that ran and did nothing. Toggle is the
// only verb this needs anyway.

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
        target: "powermenu"

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.close();
        }
    }
}
