// Whether the settings window is up.
//
// Same shape as CheatsheetState and PowerMenuState -- a flag plus an
// IpcHandler -- so the bind in hyprland.lua is just
//
//   qs ipc call settings toggle
//
// NO MUTUAL EXCLUSION, unlike the cheatsheet and the power menu. Those are
// layer surfaces that take an exclusive keyboard grab, so two of them up at
// once is two surfaces fighting over the keyboard. This is an ordinary
// window: the compositor stacks it, focuses it and closes it like any other,
// and it has no more claim on the rest of the shell than a terminal does.
//
// DO NOT name an IPC function `show`: `qs ipc show` is a CLI subcommand and
// it swallows the call, printing the handler listing and exiting 0. See
// CheatsheetState.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isOpen: false

    // Which page the rail has selected, as an index into the order the pages
    // are declared in Settings.qml.
    //
    // IT LIVES HERE AND NOT IN THE WINDOW because the pages need it and the
    // pages are separate files: a page decides whether it is on screen by
    // comparing this against its own index, which is what lets the window
    // build the rail by walking the pages rather than by carrying a list of
    // them. It also survives the window being closed and reopened, which is
    // what you want -- coming back to where you were beats coming back to the
    // top every time.
    property int currentPage: 0

    // Set by the search results when one is picked, so the row that was
    // searched for announces itself once the page it lives on comes up.
    // Cleared by the row after it has flashed.
    property string highlightRow: ""

    function open(page: int): void {
        root.currentPage = page;
        root.isOpen = true;
    }

    function close(): void {
        root.isOpen = false;
    }

    function toggle(): void {
        root.isOpen = !root.isOpen;
    }

    IpcHandler {
        target: "settings"

        // Open straight at a page, by its position in the rail. What it buys
        // is a bind that goes where you were already going --
        // `qs ipc call settings page 6` for the network list -- instead of
        // opening the window and then navigating it.
        //
        // AN INDEX AND NOT A NAME, which is the uncomfortable half: the order
        // is declared in Settings.qml and a page inserted in the middle
        // renumbers everything after it. A name would be stable, but the
        // window builds its rail by walking the pages rather than by holding
        // a list of them, so there is nothing here that knows their names
        // until they exist. Out of range is ignored rather than clamped: 99
        // is a typo, and landing on the last page would hide it.
        function page(index: int): void {
            if (index < 0)
                return;
            root.open(index);
        }

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.close();
        }
    }
}
