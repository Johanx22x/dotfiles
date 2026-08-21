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
import Quickshell.Io
import QtQuick

CompositorBackend {
    id: root

    name: "Hyprland"

    // THE ONE VALUE HERE THAT IS A FACT ABOUT THESE DOTFILES rather than about
    // Hyprland, and it is written out rather than resolved because there is
    // nothing to resolve it from: the binds arrive over the socket, so unlike
    // niri's this backend never opens the file they came from and cannot ask
    // it its own name. hypr/.config/hypr/hyprland.lua is what this tree stows,
    // and it is the file the keybinds page named unconditionally before this
    // property existed.
    bindsFile: "~/.config/hypr/hyprland.lua"

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
        // and nothing outside the compositor can read it -- so `desktop-tweak`
        // owns a state file instead and the bar reads that. See the long note
        // on the SUPER+K bind in hyprland.lua.
        keyboardLayout: false,
        focusGrab: true,
        bindsIntrospection: true,
        monitorConfig: true,
        // hyprland.lua declares the monitors by hand and the generated
        // monitors.lua only overrides it, so promoting a value from one file to
        // the other is a thing to want and Copy config is how it crosses.
        monitorConfigCopy: true,
        inputConfig: true,
        scratchpad: true,
        // `hyprctl clients` reports .at and .size for every window, and
        // windowBoxes() below reads them out of the model Quickshell fills
        // from that very command.
        windowGeometry: true,
        // One keyboard focus for the whole session, so a grabbing surface is
        // heard from any monitor.
        globalKeyboardGrab: true,
        // `release = true` on a second bind for the same key, which is what
        // desktop-tweak writes into the generated tweaks.lua.
        pushToTalk: true,
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

    // ---- Dispatching, and the trap in it ----------------------------------
    //
    // THE CLASSIC DISPATCHER SYNTAX DOES NOT WORK HERE, AND FAILS SILENTLY.
    //
    // This setup configures Hyprland in Lua, and in 0.5x that changes what the
    // dispatch socket accepts: it evaluates what it is given as Lua, so
    // `dispatch("workspace 2")` is parsed as the expression `hl.dispatch(
    // workspace 2)` and dies on a syntax error. Measured on 0.56.2:
    //
    //   dispatch exec true              -> "')' expected near 'true'"
    //   dispatch centerwindow           -> "expected a dispatcher (e.g.
    //                                       hl.dsp.window.close())"
    //   dispatch hl.dsp.exec_cmd("true") -> ok
    //
    // AND ALL THREE EXIT 0. hyprctl reports success whatever happened, so
    // nothing upstream can tell that the action was thrown away -- which is
    // exactly how clicking a workspace dot came to do nothing at all without
    // anyone noticing, and how the power menu's Log out entry stopped working.
    //
    // So every dispatch from here is written in the Lua form. If these dotfiles
    // ever go back to a hyprlang config, this is the file that has to change,
    // and the symptom will be buttons that quietly do nothing rather than an
    // error anybody can see.
    // ---- Windows on screen, as rectangles ---------------------------------
    //
    // OUT OF THE MODEL RATHER THAN OUT OF A PIPELINE. This used to be four
    // processes and a jq program built by hand in RecorderState -- `hyprctl
    // monitors -j` for the visible workspace ids, `hyprctl clients -j` for the
    // windows, jq to join them -- and every part of it is already here:
    // Quickshell fills `lastIpcObject` from `hyprctl clients -j` itself, so
    // this is that command's output without spawning it, without jq, and
    // without a shell to quote through.
    //
    // VISIBLE WORKSPACES, NOT THE FOCUSED MONITOR'S. Filtering to the focused
    // workspace meant the other screen's windows were never offered at all,
    // and slurp can only snap to boxes it was given. `workspace.active` is
    // exactly the old `hyprctl monitors -j | jq '[.[].activeWorkspace.id]'`
    // test, including how it treats the special workspace: false there, so a
    // pulled-up magic workspace is not offered. That matches what the pipeline
    // did, so nothing changed with this move; it is worth knowing before
    // somebody reads it as a bug.
    //
    // EVERY FIELD IS GUARDED. A toplevel that has not been filled in yet has
    // no `at` and no `size`, and half a rectangle is not one -- so it is
    // skipped rather than pushed as a box with undefined in it. Skipping all
    // of them yields the empty list, which the recorder already handles: the
    // selector degrades to a free-hand drag.
    function windowBoxes(): var {
        const boxes = [];

        for (const tl of Hyprland.toplevels.values) {
            if (tl.workspace?.active !== true)
                continue;

            const ipc = tl.lastIpcObject;
            if (!ipc || ipc.mapped !== true || ipc.hidden === true)
                continue;

            const at = ipc.at;
            const size = ipc.size;
            if (!at || !size || at.length < 2 || size.length < 2)
                continue;

            boxes.push(`${at[0]},${at[1]} ${size[0]}x${size[1]}`);
        }

        return boxes;
    }

    // Hyprland announces opens, closes and moves on the event socket and
    // Quickshell refreshes the model from them, so this is belt and braces
    // rather than the only thing keeping the list current -- which is why the
    // recorder can ask for it 150 ms before it reads the boxes and not care
    // whether the answer has landed. The cost is one `hyprctl clients -j` per
    // window selection.
    function refreshWindows(): void {
        Hyprland.refreshToplevels();
    }

    function focusWorkspace(id: var): void {
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${id}})`);
    }

    function logout(): void {
        Hyprland.dispatch("hl.dsp.exit()");
    }

    // ---- Keybindings ------------------------------------------------------
    //
    // `hyprctl binds -j`, asked fresh rather than cached. It reports the
    // compositor's live state, so a bind added by a reload shows up without the
    // shell knowing a reload happened.
    //
    // CAREFUL, THE DISPATCHER IS USELESS HERE. With a Lua config every bind
    // comes back as `"dispatcher": "__lua"` with no readable argument, so the
    // only thing worth reading is the description this setup attaches by hand.
    // A bind with no description is deliberately invisible, which is what keeps
    // the sheet to the chords worth remembering.
    function refreshBinds(): void {
        bindQuery.running = true;
    }

    // The X11 modifier bits. Hyprland reports the mask raw; only these four are
    // ever bound by hand, and the rest (caps, numlock) would be noise on a chip
    // even when set.
    function modifierNames(mask: int): var {
        const out = [];
        if (mask & 64) out.push("SUPER");
        if (mask & 8) out.push("ALT");
        if (mask & 4) out.push("CTRL");
        if (mask & 1) out.push("SHIFT");
        return out;
    }

    property Process bindQuery: Process {
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn("Hyprland: could not parse hyprctl binds --", e.message);
                    return;
                }

                const out = [];
                for (const bind of parsed) {
                    const description = (bind.description ?? "").trim();
                    // has_description AND a non-empty string: hyprctl reports
                    // the flag and the text separately and a bind can carry an
                    // empty one.
                    const described = !!bind.has_description && description !== "";
                    const colon = description.indexOf(": ");
                    // A bind written by keycode has no keysym for hyprctl to
                    // report, and an empty chip reads as a row that failed to
                    // load rather than as a key nobody named.
                    const key = (bind.key ?? "") !== "" ? bind.key
                        : bind.keycode ? `code ${bind.keycode}` : "?";

                    out.push({
                        keys: root.modifierNames(bind.modmask).concat([key]),
                        category: !described ? "Undescribed"
                            : colon < 0 ? "Other" : description.slice(0, colon),
                        description: !described ? ""
                            : colon < 0 ? description : description.slice(colon + 2),
                        described: described,
                        submap: bind.submap ?? "",
                        nonConsuming: !!bind.non_consuming
                    });
                }
                root.binds = out;
            }
        }
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
