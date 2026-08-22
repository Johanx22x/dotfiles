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
// ONLY ONE HALF OF THAT RULE IS HERE, and this header used to claim both.
// The dashboard is content inside a popout there is one of PER BAR, and a
// singleton cannot reach a window: what closes it when the launcher opens is
// Bar.qml, which watches `isOpen` and closes its own popout. The half this
// file does own is the other direction, off the report Bar.qml publishes into
// `popoutOpen` below.
//
// There WAS a line here that read like the first half -- `dashboardOpen`
// assigned false the moment the launcher opened -- and it closed nothing at
// all. See the note over popoutOpen.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    // WHETHER ANY POPOUT IS UP ON ANY BAR, published by Bar.qml. A REPORT and
    // not a request: assigning it closes nothing. Every handler on it -- here,
    // in CheatsheetState and in WallpaperState -- acts on the RISING edge
    // alone, and the only writer that reaches a popout is Bar.qml, one way.
    //
    // IT WAS CALLED dashboardOpen, AND THE NAME IS WHAT WENT WRONG. Three
    // places assigned it false to put the dashboard away -- this file, the
    // cheatsheet and the wallpaper carousel -- and not one of them did
    // anything: they changed a mirror and left the panel on screen. The name
    // was wrong on its face as well, because the one popout a bar owns also
    // serves the tray menus, the notification history and the peripheral
    // batteries, so this has always gone true for a tray icon.
    //
    // WHAT TO CALL INSTEAD, when you want the dashboard down:
    // IslandState.closeDashboard(). That singleton owns the fact -- the
    // connector name of the bar the panel is drawn on -- rather than mirroring
    // a window, so clearing it both closes the panel and stops the
    // follow-the-focus rule from building it again on the next monitor the
    // pointer crosses onto. Clearing the string is what makes the panel go;
    // the popout closing is the consequence, not the mechanism.
    property bool popoutOpen: false

    // A popout going up closes the launcher: the two hang from the same place
    // and neither is readable through the other. An EDGE and not a level --
    // the flag above is one bar's news about something global, so it can read
    // false while another bar still has a panel up, and the next opening
    // raises the edge again.
    onPopoutOpenChanged: if (popoutOpen)
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
    }
}
