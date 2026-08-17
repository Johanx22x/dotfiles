// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - the Hyprland backend
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// A thin translation of Quickshell.Hyprland into the common shape. Quickshell
// does the socket work here, so this file is mostly about vocabulary -- plus
// the two workarounds that used to live in the modules that drew things, and
// which belong at this layer: they are facts about Hyprland, not about a bar.

import Quickshell
import Quickshell.Hyprland
import QtQuick

CompositorBackend {
    id: root

    name: "Hyprland"

    // Quickshell.Hyprland populates itself when a Hyprland socket is there. The
    // signature is the compositor's own announcement and the cheapest proof it
    // is this flavor and not another.
    ready: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== undefined
        && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

    capabilities: ({
        workspaces: true,
        // Hyprland's workspaces are numbered places: workspace 3 is workspace 3
        // tomorrow too, and SUPER+3 always lands on the same one.
        fixedWorkspaceNumbers: true,
        workspaceOccupancy: true,
        activeWindow: true,
        castingIndicator: true,
        // The active layout does NOT come from the compositor here, by design:
        // Hyprland's layout index is session-only, is thrown away by a reload,
        // and nothing outside the compositor can read it -- so `hypr-tweak`
        // owns a state file instead and the bar reads that. See the long note
        // on the SUPER+K bind in hyprland.lua.
        keyboardLayout: false,
        focusGrab: true,
        bindsIntrospection: true,
        monitorConfig: true,
        inputConfig: true,
        scratchpad: true,
        logout: true
    })

    workspaces: {
        const out = [];
        for (const ws of Hyprland.workspaces.values) {
            out.push({
                id: ws.id,
                number: ws.id,
                name: ws.name ?? "",
                // `?.` is load-bearing: a workspace exists for an instant with
                // no monitor while it is being moved between screens, and
                // reading .name off null throws inside the binding.
                output: ws.monitor?.name ?? "",
                active: ws.active === true,
                focused: ws.focused === true,
                urgent: ws.urgent === true,
                windows: ws.toplevels?.values?.length ?? -1
            });
        }
        return out;
    }

    // THE FOCUSED WINDOW IS FOUND BY SEARCHING, NOT BY ASKING.
    //
    // Two separate faults in Quickshell.Hyprland 0.3.0 push it this way, and
    // both were measured here rather than reasoned about:
    //
    // 1. activeToplevel IS EMPTY UNTIL FOCUS CHANGES. It is populated from the
    //    `activewindow` event and nothing queries the state at startup, so a
    //    freshly launched shell has null while three toplevels sit in the model
    //    -- verified: `toplevels: 3, activeToplevel: null`, indefinitely, until
    //    a window is clicked. A shell that has been up for hours hides this
    //    completely, which is why it went unnoticed: it only bites on restart.
    //
    // 2. IT ALSO GOES STALE WHEN FOCUS GOES NOWHERE. Hyprland announces the
    //    loss -- switching to an empty workspace emits `activewindowv2>>` with
    //    no address -- but Quickshell does not clear the property, so it keeps
    //    pointing at the last focused window and a bar paints a title for a
    //    workspace with nothing on it.
    //
    // Scanning the toplevel model for the one whose WAYLAND HANDLE says it is
    // activated fixes both, because that flag is the only one here that tracks
    // reality: the IPC-side `activated` freezes along with activeToplevel, and
    // `workspace.active` is false for special workspaces -- which ARE on
    // screen, so it would blank the title every time the magic workspace is
    // pulled up.
    //
    // activeToplevel is still consulted, but only as a FALLBACK: the Wayland
    // handle is briefly absent while a window maps, and during that instant the
    // search finds nothing. Falling back to the last known answer leaves the
    // module as it was instead of blinking it away.
    activeWindow: {
        for (const tl of Hyprland.toplevels.values) {
            if (tl.wayland?.activated !== true)
                continue;
            return {
                appId: tl.wayland?.appId ?? tl.lastIpcObject?.class ?? "",
                title: tl.title ?? "",
                output: tl.monitor?.name ?? ""
            };
        }

        const active = Hyprland.activeToplevel;
        if (!active || active.wayland?.activated === false)
            return null;
        return {
            appId: active.wayland?.appId ?? active.lastIpcObject?.class ?? "",
            title: active.title ?? "",
            output: active.monitor?.name ?? ""
        };
    }

    // Derived from the workspace model rather than from Hyprland.focusedMonitor.
    // The IPC models are populated LAZILY: whichever one nothing subscribes to
    // is never refreshed, and focusedMonitor stayed frozen on whatever monitor
    // happened to be focused at startup. The workspace model is subscribed to
    // right above, so asking it which monitor holds the globally focused
    // workspace gives the same answer off data that is guaranteed live.
    focusedOutput: {
        for (const ws of workspaces)
            if (ws.focused)
                return ws.output;
        return "";
    }

    function focusWorkspace(id: var): void {
        Hyprland.dispatch(`workspace ${id}`);
    }

    function logout(): void {
        Hyprland.dispatch("exit");
    }

    // Screen capture, announced on Hyprland's own event socket, so there is
    // nothing to poll and no portal to talk to:
    //
    //   screencast>>1,monitor            started
    //   screencastv2>>1,monitor,DP-3     started, and what is being taken
    //   screencastv2>>0,monitor,DP-3     stopped
    //
    // v2 is used for the target name; v1 carries the same state without it, so
    // listening to both would double-count. Verified by listening on
    // .socket2.sock while capturing -- those lines are copied from that
    // capture, not from documentation.
    //
    // AN EDGE RATHER THAN STATE, which is the one place niri is better: a shell
    // started while a call is already running has no way to learn about it
    // here, whereas niri publishes the list of live casts. Nothing to be done
    // from this side; it is the shape of the event.
    property Connections castWatch: Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "screencastv2")
                return;

            // state, owner, name
            const args = event.parse(3);
            if (args[0] === "1") {
                root.captureOwner = args[1] ?? "";
                root.captureTarget = args[2] ?? "";
                root.captureCount += 1;
            } else {
                // Clamped at zero: a session already running when the shell
                // started is stopped without ever having been counted.
                root.captureCount = Math.max(0, root.captureCount - 1);
            }
        }
    }
}
