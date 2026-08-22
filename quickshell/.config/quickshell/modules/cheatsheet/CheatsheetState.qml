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
// closes the launcher, the dashboard, the notification history and the power
// menu, and any of those opening closes the cheatsheet.
//
// THE HISTORY IS IN THAT LIST BECAUSE IT WAS MISSING FROM IT, and the
// behaviour was missing with it. This paragraph is the CONTRACT -- it is what
// a reader checks the file against, and it was short by one panel for as long
// as the list sat up behind the sheet following the pointer between monitors.
// A header that undercounts what a file closes is the same class of defect as
// a property name that promises what it does not do; LauncherState.popoutOpen
// carries the one that fooled three authors. Anything added to this file's
// reach gets added to this sentence first.
//
// The rule lives HERE, in the newcomer, and not spread across the FOUR other
// singletons it reaches -- LauncherState, IslandState, NotificationState and
// PowerMenuState. The same reason LauncherState owns its half of the
// arbitration with the island: one file to read when the windows disagree
// about who is up. It said three before the notification history was counted
// in; the number moves whenever the list above does, so it is spelled out
// here rather than left as a total to re-derive.
//
// THE TWO PANELS THAT LIVE IN A POPOUT ARE REACHED THROUGH THEIR OWN
// SINGLETONS: IslandState.closeDashboard() and NotificationState.closeHistory().
// Each of those owns the connector name of the bar its panel is drawn on, and
// clearing that string is what makes the panel go -- the popout closing is the
// consequence and not the mechanism. Two panels of the same kind, closed by
// the same shape of call, on purpose: the next one added here will be copied
// from whichever of them is read first.
//
// THE DASHBOARD USED TO BE REACHED BY ASSIGNING LauncherState.dashboardOpen
// FALSE, AND THAT CLOSED NOTHING: the flag is a report Bar.qml publishes about
// its own popout, so the write changed a mirror and the sheet came up over a
// dashboard that was still there. It got worse when the dashboard began
// following the focused screen -- the bar it was on stayed named, so a pointer
// crossing monitors rebuilt a panel the user believed was gone. The history
// was never wired in here at all, which is the same bug reached by the other
// road: nothing to write to and so nothing written. Closing both at the source
// is what fixes them.
//
// WHICH IS WHY THE WALLPAPER CAROUSEL IS NOT LISTED ABOVE. It arrived after
// this file and owns its own half of the arbitration, in WallpaperState, by the
// same convention: it closes this sheet, and this sheet opening closes it.
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
import "root:/modules/island"
import "root:/modules/launcher"
import "root:/modules/notifications"
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
        IslandState.closeDashboard();
        NotificationState.closeHistory();
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

        // ANY popout going up, not only the dashboard -- see the note over
        // popoutOpen in LauncherState. This sheet covers the bar while it is
        // up, so what can still raise one is a keybind: SUPER + D for the
        // dashboard, SUPER + SHIFT + N for the notification history. Either
        // means the sheet is no longer what is being asked for.
        function onPopoutOpenChanged(): void {
            if (LauncherState.popoutOpen)
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
