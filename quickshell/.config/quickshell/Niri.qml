// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - niri's IPC, as a live model
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// The counterpart of Quickshell.Hyprland for the other compositor flavor.
// Quickshell has no niri backend -- verified on 0.3.0: the installed modules
// are Hyprland and I3 and nothing else, and `strings /usr/bin/quickshell` has
// no occurrence of "niri" at all -- so this talks to the socket directly.
//
// WHY NOT Quickshell.WindowManager, WHICH DOES EXIST AND DOES WORK
// It speaks ext-workspace-v1, niri implements it, and it would give workspaces
// and an activate() for free. It was measured against what the bar actually
// needs and it comes up three short:
//
//   * No window list, so "does this workspace have anything on it" -- the dim
//     dot versus the bright one in Workspaces.qml -- cannot be answered.
//   * No index. It exposes `coordinates`, and the dots are numbered by
//     position, which is also what Mod+1..0 binds to.
//   * Its companion for windows, ToplevelManager, has no `identifier` property
//     in 0.3.0 (checked in the .qmltypes and in the binary: only
//     zwlr_foreign_toplevel is linked, not ext_foreign_toplevel_list, which is
//     the protocol that carries it). So a Toplevel cannot be tied back to a
//     niri window id, and matching by app id and title is a guess.
//
// Since the socket is needed anyway -- for the screencast badge, the keyboard
// layout and a focused window that can be trusted -- taking workspaces from a
// second source as well would mean two models to keep in step. One source.
//
// The protocol itself is documented on the socket below rather than up here,
// and NOT for tidiness -- see the warning under the imports.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// !! NEVER PUT A CURLY BRACE IN A COMMENT ABOVE `pragma Singleton` !!
//
// A comment line containing braces, ANYWHERE before the pragma, stops the file
// from loading as a singleton. There is no error, no warning and no failed
// import: the type still resolves, so nothing looks wrong, but the object comes
// out with no properties at all -- every read is `undefined` and
// Object.keys() on it is empty. It cost a full bisection to find, because
// qmllint passes the file and Quickshell logs "Configuration Loaded".
//
// Measured on Quickshell 0.3.0 by feeding it the header one line at a time:
// the four lines that broke it were the four holding JSON examples, and the
// one holding "\n" was fine. Braces in comments INSIDE the body are harmless --
// this file is full of them below and it loads.
//
// So the protocol notes live here, under the imports, where braces are safe:
//
//   request   one JSON value per line, "\n" terminated
//               "EventStream"
//               {"Action":{"FocusWorkspace":{"reference":{"Id":3}}}}
//   reply     {"Ok": <response>}  or  {"Err": "<message>"}
//   stream    after the {"Ok":"Handled"} acknowledgement, one event per line,
//             indefinitely
//
// The first thing the stream sends is a COMPLETE SNAPSHOT of the state --
// WorkspacesChanged, WindowsChanged, KeyboardLayoutsChanged, CastsChanged --
// and only then deltas. So there is no initial query to make and no window
// where the bar is empty because the answer has not arrived yet.
//
// Events are externally tagged: {"EventName": {...}}, so the name is
// Object.keys(event)[0].
Singleton {
    id: root

    // $NIRI_SOCKET is the compositor's own announcement, the way
    // $HYPRLAND_INSTANCE_SIGNATURE is for the other one. Empty under Hyprland,
    // which is exactly how `available` tells the two flavors apart.
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool available: socketPath !== ""

    // True once the stream has acknowledged and the first snapshot is in.
    // Everything below is empty until then, so a consumer that paints on
    // `connected` never shows a half-built state.
    property bool connected: false

    // ---- The state, mirrored from the stream ----------------------------
    //
    // Plain JS arrays of the raw IPC objects, deliberately: niri's own field
    // names are kept (is_active, app_id, workspace_id) instead of being
    // renamed into a house style. Anything reading this can be checked against
    // `niri msg -j workspaces` in a terminal, which is worth more than
    // prettier property names.
    //
    // Workspace: {id, idx, name, output, is_urgent, is_active, is_focused,
    //             active_window_id}
    // Window:    {id, title, app_id, pid, workspace_id, is_focused,
    //             is_floating, is_urgent, layout, focus_timestamp}
    property var workspaces: []
    property var windows: []
    property var casts: []
    property var keyboardLayouts: ({ names: [], current_idx: 0 })
    property bool overviewOpen: false

    // ---- Derived -------------------------------------------------------

    // The focused window, or null. niri marks exactly one, and unlike
    // Hyprland's activeToplevel it clears the flag when focus goes nowhere --
    // which is the bug ActiveWindow.qml documents at length for the other
    // flavor.
    readonly property var focusedWindow: {
        for (const w of windows)
            if (w.is_focused)
                return w;
        return null;
    }

    // Which output has the keyboard. Only one workspace in the session is
    // focused, and its output is the answer.
    readonly property string focusedOutput: {
        for (const ws of workspaces)
            if (ws.is_focused)
                return ws.output ?? "";
        return "";
    }

    // Someone is capturing the screen. The replacement for Hyprland's
    // screencastv2 event, and a better one: it is state rather than an edge,
    // so a shell that starts while a call is already running still knows.
    readonly property bool casting: casts.some(c => c.is_active)

    // How many windows sit on a workspace. This is the one the bar needs and
    // the one ext-workspace cannot answer.
    function windowCount(workspaceId: var): int {
        let n = 0;
        for (const w of windows)
            if (w.workspace_id === workspaceId)
                n += 1;
        return n;
    }

    function workspacesOn(outputName: string): var {
        return workspaces.filter(ws => ws.output === outputName);
    }

    // ---- Sending ---------------------------------------------------------
    //
    // A SECOND SOCKET, not the streaming one. The stream's connection is
    // consumed by the stream: niri answers one request per connection and then
    // keeps that one open forever pushing events, so a request written into it
    // would never be read. Each action opens, writes, and closes.
    function action(payload: var): void {
        if (!available)
            return;
        sender.send(JSON.stringify({ Action: payload }));
    }

    // The handful the shell actually calls. Wrapped rather than left to
    // callers so the JSON shape lives in one place: `reference` is an enum and
    // {"Id": n} is not interchangeable with {"Index": n} -- the first is the
    // stable identity, the second is the position on its monitor.
    function focusWorkspace(id: var): void {
        root.action({ FocusWorkspace: { reference: { Id: id } } });
    }

    function quit(): void {
        root.action({ Quit: { skip_confirmation: true } });
    }

    // ---- The stream ------------------------------------------------------
    Socket {
        id: stream

        path: root.socketPath
        connected: root.available

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n');
            } else {
                // The compositor went away (or never was). Drop everything
                // rather than leave the bar painting a stale workspace row.
                root.connected = false;
                root.workspaces = [];
                root.windows = [];
                root.casts = [];
                root.overviewOpen = false;
            }
        }

        parser: SplitParser {
            // One JSON value per line, which is the protocol's own framing.
            splitMarker: "\n"

            onRead: line => {
                if (line.length === 0)
                    return;

                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    // A malformed line is not worth taking the shell down for,
                    // but it must not pass silently either: it would mean the
                    // IPC changed shape under us.
                    console.warn("Niri: unparseable line from the socket:", line);
                    return;
                }

                // The acknowledgement that opens the stream, {"Ok":"Handled"}.
                // Anything with an Err instead is a request niri refused.
                if (msg.Ok !== undefined) {
                    root.connected = true;
                    return;
                }
                if (msg.Err !== undefined) {
                    console.warn("Niri: the compositor refused a request:", JSON.stringify(msg.Err));
                    return;
                }

                root.handleEvent(msg);
            }
        }
    }

    Socket {
        id: sender

        path: root.socketPath
        connected: false

        property string pending: ""

        function send(payload: string): void {
            pending = payload;
            connected = true;
        }

        onConnectionStateChanged: {
            if (connected && pending !== "") {
                write(pending + "\n");
                pending = "";
                // niri replies and the connection has served its purpose. Left
                // to close on the next send rather than immediately, so the
                // reply is not cut off mid-write.
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.Err !== undefined)
                    console.warn("Niri: action refused:", JSON.stringify(msg.Err));
                sender.connected = false;
            }
        }
    }

    // ---- Events ----------------------------------------------------------
    //
    // Externally tagged, so the name is the single key. The full set niri 26.04
    // emits is nineteen; the ones not handled here (WindowLayoutsChanged,
    // WindowFocusTimestampChanged, ScreenshotCaptured, ConfigLoaded) carry
    // nothing the shell draws, and are ignored on purpose rather than by
    // omission -- an unknown name is warned about below, and these would
    // otherwise cry wolf on every window move.
    readonly property var ignoredEvents: [
        "WindowLayoutsChanged",
        "WindowFocusTimestampChanged",
        "ScreenshotCaptured",
        "ConfigLoaded"
    ]

    function handleEvent(event: var): void {
        const name = Object.keys(event)[0];
        const data = event[name];

        switch (name) {
        // ---- Wholesale replacements (the opening snapshot uses these) ----
        case "WorkspacesChanged":
            workspaces = data.workspaces ?? [];
            break;
        case "WindowsChanged":
            windows = data.windows ?? [];
            break;
        case "CastsChanged":
            casts = data.casts ?? [];
            break;
        case "KeyboardLayoutsChanged":
            keyboardLayouts = data.keyboard_layouts ?? { names: [], current_idx: 0 };
            break;
        case "OverviewOpenedOrClosed":
            overviewOpen = data.is_open ?? false;
            break;

        // ---- Deltas ------------------------------------------------------
        // Reassigning the whole array rather than mutating in place: QML only
        // re-evaluates a binding when the property itself changes, and a
        // push() into an existing array notifies nothing.
        case "WorkspaceActivated": {
            // Two fields, {id, focused}. Activation is per output, so every
            // OTHER workspace on the same output loses it -- and `focused` is
            // global, so if this one takes it, every workspace everywhere
            // loses it.
            const target = workspaces.find(ws => ws.id === data.id);
            if (!target)
                break;
            workspaces = workspaces.map(ws => {
                const sameOutput = ws.output === target.output;
                return Object.assign({}, ws, {
                    is_active: sameOutput ? ws.id === data.id : ws.is_active,
                    is_focused: data.focused ? ws.id === data.id : ws.is_focused
                });
            });
            break;
        }
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(ws =>
                ws.id === data.id ? Object.assign({}, ws, { is_urgent: data.urgent }) : ws);
            break;
        case "WorkspaceActiveWindowChanged":
            workspaces = workspaces.map(ws =>
                ws.id === data.workspace_id
                    ? Object.assign({}, ws, { active_window_id: data.active_window_id })
                    : ws);
            break;

        case "WindowOpenedOrChanged": {
            const w = data.window;
            if (!w)
                break;
            const rest = windows.filter(x => x.id !== w.id);
            // A window that opens focused takes the flag off whatever had it.
            windows = (w.is_focused ? rest.map(x => Object.assign({}, x, { is_focused: false })) : rest)
                .concat([w]);
            break;
        }
        case "WindowClosed":
            windows = windows.filter(w => w.id !== data.id);
            break;
        case "WindowFocusChanged":
            // data.id is null when focus goes nowhere, which is the case
            // Hyprland never reports cleanly.
            windows = windows.map(w =>
                Object.assign({}, w, { is_focused: data.id !== null && w.id === data.id }));
            break;
        case "WindowUrgencyChanged":
            windows = windows.map(w =>
                w.id === data.id ? Object.assign({}, w, { is_urgent: data.urgent }) : w);
            break;

        case "KeyboardLayoutSwitched":
            keyboardLayouts = Object.assign({}, keyboardLayouts, { current_idx: data.idx });
            break;

        case "CastStartedOrChanged": {
            const c = data.cast;
            if (!c)
                break;
            casts = casts.filter(x => x.stream_id !== c.stream_id).concat([c]);
            break;
        }
        case "CastStopped":
            casts = casts.filter(c => c.stream_id !== data.stream_id);
            break;

        default:
            if (!ignoredEvents.includes(name))
                console.warn("Niri: unhandled event", name);
        }
    }
}
