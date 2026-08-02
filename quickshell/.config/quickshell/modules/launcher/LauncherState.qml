// Whether the launcher is up, and the one rule it shares with the island.
//
// Same shape as PowerMenuState: a flag plus an IpcHandler, so the keybind in
// hyprland.lua is `qs ipc call launcher toggle` and the compositor does not
// have to know anything about the shell beyond that. It also replaces what
// the old wofi script did with `pgrep wofi` and a kill-and-wait loop --
// pressing the shortcut twice is a toggle because the state lives in one
// place, not because a second process looked for the first one.
//
// MUTUAL EXCLUSION WITH THE ISLAND
// The launcher and the island's dashboard both hang from the centre of the
// bar, in the same place, and neither is readable through the other. So only
// one is ever up: opening either closes the other.
//
// The arbitration is HERE rather than in either window, because the two do
// not know about each other -- the dashboard is content inside the bar's
// shared popout, and the launcher is a window of its own. Bar.qml wires the
// popout to `dashboardOpen` in both directions; this file owns the rule.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    // Mirrors the bar's popout, published by Bar.qml. Read only in the sense
    // that nothing here should assign it: it is a report, not a request.
    property bool dashboardOpen: false

    // Opening the launcher closes the dashboard, and vice versa. Written as
    // two handlers rather than one binding because each side has to act on
    // the OTHER window, and a binding can only own one property.
    onIsOpenChanged: if (isOpen)
        root.dashboardOpen = false

    onDashboardOpenChanged: if (dashboardOpen)
        root.isOpen = false

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

        function wallpaper(): void {
            root.openPicker("wallpaper");
        }
    }
}
