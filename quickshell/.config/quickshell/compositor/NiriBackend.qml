// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - the niri backend
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// Quickshell ships no niri module -- on 0.3.0 the compositor backends are
// Hyprland and I3, and the binary has no occurrence of "niri" at all -- so this
// speaks the IPC socket itself.
//
// WHY NOT Quickshell.WindowManager, WHICH EXISTS AND WOULD WORK
// It speaks ext-workspace-v1, niri implements it, and it would hand over
// workspaces and an activate() for free. Measured against what the bar draws it
// comes up three short: no window list, so `workspaceOccupancy` could not be
// answered; no index, and the dots are numbered by position; and its companion
// ToplevelManager has no `identifier` property in 0.3.0 -- checked in the
// .qmltypes and again in the binary, which links zwlr_foreign_toplevel but not
// ext_foreign_toplevel_list, the protocol that carries it -- so a Toplevel
// cannot be tied back to a niri window id. The socket is needed anyway for the
// screencast badge and the keyboard layout, and a second source would only be a
// second model to keep in step.
//
// THE PROTOCOL, measured against a live niri 26.04 rather than read:
//
//   request   one JSON value per line, "\n" terminated
//               "EventStream"
//               {"Action":{"FocusWorkspace":{"reference":{"Id":3}}}}
//   reply     {"Ok": <response>} or {"Err": "<message>"}
//   stream    after the {"Ok":"Handled"} acknowledgement, one event per line
//
// The stream opens with a COMPLETE SNAPSHOT -- WorkspacesChanged,
// WindowsChanged, KeyboardLayoutsChanged, CastsChanged -- and only then sends
// deltas, so there is no initial query to make and no window where the bar is
// empty because the answer has not arrived yet.
//
// Events are externally tagged, so the name is Object.keys(event)[0].
//
// (Braces in comments are safe HERE. They are not above a `pragma Singleton`:
// see the warning in Compositor.qml, which is a singleton and was bitten.)

import Quickshell
import Quickshell.Io
import QtQuick

CompositorBackend {
    id: root

    name: "niri"

    // $NIRI_SOCKET is the compositor's own announcement, the way
    // $HYPRLAND_INSTANCE_SIGNATURE is for the other one.
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""

    capabilities: ({
        workspaces: true,
        // FALSE, and this is the honest answer rather than a missing feature.
        // niri's workspaces are dynamic and per monitor: the third workspace of
        // this monitor is the third one today and something else tomorrow, and
        // Mod+3 means "the third one", not "workspace 3". Numbering the dots
        // would print a label that lies.
        fixedWorkspaceNumbers: false,
        workspaceOccupancy: true,
        activeWindow: true,
        castingIndicator: true,
        keyboardLayout: true,
        // No equivalent protocol, and none is generic. Popouts fall back to a
        // full-screen input catcher; see Popout.qml.
        focusGrab: false,
        // niri has no `hyprctl binds`. The binds live in the KDL config, which
        // is parseable -- unlike Hyprland's Lua, where every bind reports as
        // "__lua" -- but reading it is a separate job from this backend.
        bindsIntrospection: false,
        monitorConfig: false,
        inputConfig: false,
        // niri has no special workspace at all: upstream issue #845, open since
        // December 2024. The config maps the old scratchpad chords onto a named
        // workspace, which is a place you go to rather than an overlay.
        scratchpad: false,
        logout: true
    })

    // ---- Raw state, in niri's own vocabulary -----------------------------
    //
    // Kept as the compositor sends it and translated on the way out, so what is
    // in here can be compared against `niri msg -j workspaces` in a terminal
    // when something looks wrong.
    property var rawWorkspaces: []
    property var rawWindows: []
    property var rawCasts: []

    // ---- Translation to the common shape ---------------------------------

    workspaces: rawWorkspaces.map(ws => ({
        id: ws.id,
        // 0 rather than ws.idx: the capability above says these numbers are not
        // stable, and handing one over anyway invites something to draw it.
        number: 0,
        name: ws.name ?? "",
        output: ws.output ?? "",
        active: ws.is_active === true,
        focused: ws.is_focused === true,
        urgent: ws.is_urgent === true,
        windows: root.countWindows(ws.id)
    }))

    activeWindow: {
        for (const w of rawWindows) {
            if (!w.is_focused)
                continue;
            // The window knows its workspace and the workspace knows its
            // output; niri does not put the monitor on the window itself.
            const ws = rawWorkspaces.find(x => x.id === w.workspace_id);
            return {
                appId: w.app_id ?? "",
                title: w.title ?? "",
                output: ws?.output ?? ""
            };
        }
        return null;
    }

    focusedOutput: {
        for (const ws of rawWorkspaces)
            if (ws.is_focused)
                return ws.output ?? "";
        return "";
    }

    // STATE RATHER THAN AN EDGE, which is where niri beats the other flavor: a
    // shell that starts while a call is already running still knows, because
    // the opening snapshot carries the live casts. Hyprland only announces the
    // transition, so a restart mid-call loses it.
    captureCount: rawCasts.filter(c => c.is_active).length

    // `target` is a tagged enum -- {"Output": "DP-3"} or {"Window": <id>} -- so
    // the owner is its key and the name is what is under it. Read defensively:
    // this is the one shape in the whole backend that was NOT confirmed against
    // a live cast, because reproducing one needs a real screencast session and
    // the nested compositor had no portal. If it is wrong the indicator simply
    // says "sharing" without naming what, which is the intended degradation.
    captureOwner: {
        const live = rawCasts.find(c => c.is_active);
        if (!live?.target)
            return "";
        const key = Object.keys(live.target)[0] ?? "";
        return key.toLowerCase();
    }

    captureTarget: {
        const live = rawCasts.find(c => c.is_active);
        if (!live?.target)
            return "";
        const key = Object.keys(live.target)[0];
        const value = key ? live.target[key] : null;
        return typeof value === "string" ? value : "";
    }

    function countWindows(workspaceId: var): int {
        let n = 0;
        for (const w of rawWindows)
            if (w.workspace_id === workspaceId)
                n += 1;
        return n;
    }

    // ---- Actions ---------------------------------------------------------

    function focusWorkspace(id: var): void {
        // `reference` is an enum and the variants are not interchangeable: Id is
        // the stable identity, Index is the position on its monitor.
        root.action({ FocusWorkspace: { reference: { Id: id } } });
    }

    function logout(): void {
        root.action({ Quit: { skip_confirmation: true } });
    }

    function action(payload: var): void {
        if (socketPath === "")
            return;
        requester.send(JSON.stringify({ Action: payload }));
    }

    // ---- The stream ------------------------------------------------------
    property Socket stream: Socket {
        path: root.socketPath
        connected: root.socketPath !== ""

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n');
            } else {
                // The compositor went away. Drop everything rather than leave
                // the bar painting a workspace row that no longer exists.
                root.ready = false;
                root.rawWorkspaces = [];
                root.rawWindows = [];
                root.rawCasts = [];
            }
        }

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line.length === 0)
                    return;

                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    // Not worth taking the shell down for, but it must not pass
                    // in silence either: it would mean the IPC changed shape.
                    console.warn("niri: unparseable line from the socket:", line);
                    return;
                }

                // The acknowledgement that opens the stream.
                if (msg.Ok !== undefined) {
                    root.ready = true;
                    return;
                }
                if (msg.Err !== undefined) {
                    console.warn("niri: request refused:", JSON.stringify(msg.Err));
                    return;
                }

                root.handleEvent(msg);
            }
        }
    }

    // ---- Sending ---------------------------------------------------------
    //
    // A SECOND SOCKET, not the streaming one. niri answers one request per
    // connection and then keeps that connection open pushing events forever, so
    // a request written into the stream would never be answered.
    property Socket requester: Socket {
        // NAMED, and not reachable as `parent` from the parser below: a
        // DataStreamParser is not a visual child, so its `parent` is null and
        // touching it throws "Value is null and could not be converted to an
        // object" -- once per action, from inside a signal handler, which is a
        // long way from where it would look like it came from.
        id: requesterSocket

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
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                try {
                    const msg = JSON.parse(line);
                    if (msg.Err !== undefined)
                        console.warn("niri: action refused:", JSON.stringify(msg.Err));
                } catch (e) {
                    // The reply is only read to know it arrived.
                }
                // The connection has served its purpose: niri answers one
                // request per connection.
                requesterSocket.connected = false;
            }
        }
    }

    // ---- Events ----------------------------------------------------------
    //
    // niri 26.04 emits nineteen. The ones listed here as ignored carry nothing
    // the shell draws, and are named rather than left to the default so that an
    // event we have genuinely never seen still gets a warning.
    readonly property var ignoredEvents: [
        "WindowLayoutsChanged",
        "WindowFocusTimestampChanged",
        "ScreenshotCaptured",
        "ConfigLoaded",
        "OverviewOpenedOrClosed"
    ]

    function handleEvent(event: var): void {
        const name = Object.keys(event)[0];
        const data = event[name];

        switch (name) {
        // ---- Wholesale replacements: the opening snapshot uses these ----
        case "WorkspacesChanged":
            rawWorkspaces = data.workspaces ?? [];
            break;
        case "WindowsChanged":
            rawWindows = data.windows ?? [];
            break;
        case "CastsChanged":
            rawCasts = data.casts ?? [];
            break;
        case "KeyboardLayoutsChanged": {
            const kl = data.keyboard_layouts ?? { names: [], current_idx: 0 };
            keyboardLayouts = { names: kl.names ?? [], currentIndex: kl.current_idx ?? 0 };
            break;
        }

        // ---- Deltas ------------------------------------------------------
        // Every one reassigns the whole array rather than mutating it: QML only
        // re-evaluates a binding when the property itself changes, and a push()
        // into an existing array notifies nothing.
        case "WorkspaceActivated": {
            // Activation is per output, so the others on the SAME output lose
            // it; `focused` is global, so if this one takes it, every workspace
            // everywhere loses it.
            const target = rawWorkspaces.find(ws => ws.id === data.id);
            if (!target)
                break;
            rawWorkspaces = rawWorkspaces.map(ws => Object.assign({}, ws, {
                is_active: ws.output === target.output ? ws.id === data.id : ws.is_active,
                is_focused: data.focused ? ws.id === data.id : ws.is_focused
            }));
            break;
        }
        case "WorkspaceUrgencyChanged":
            rawWorkspaces = rawWorkspaces.map(ws =>
                ws.id === data.id ? Object.assign({}, ws, { is_urgent: data.urgent }) : ws);
            break;
        case "WorkspaceActiveWindowChanged":
            rawWorkspaces = rawWorkspaces.map(ws =>
                ws.id === data.workspace_id
                    ? Object.assign({}, ws, { active_window_id: data.active_window_id })
                    : ws);
            break;

        case "WindowOpenedOrChanged": {
            const w = data.window;
            if (!w)
                break;
            const rest = rawWindows.filter(x => x.id !== w.id);
            // A window that opens focused takes the flag off whatever had it.
            rawWindows = (w.is_focused
                ? rest.map(x => Object.assign({}, x, { is_focused: false }))
                : rest).concat([w]);
            break;
        }
        case "WindowClosed":
            rawWindows = rawWindows.filter(w => w.id !== data.id);
            break;
        case "WindowFocusChanged":
            // data.id is null when focus goes nowhere -- the case Hyprland
            // never reports cleanly, and the reason ActiveWindow.qml needs a
            // paragraph of workaround on that flavor and none on this one.
            rawWindows = rawWindows.map(w =>
                Object.assign({}, w, { is_focused: data.id !== null && w.id === data.id }));
            break;
        case "WindowUrgencyChanged":
            rawWindows = rawWindows.map(w =>
                w.id === data.id ? Object.assign({}, w, { is_urgent: data.urgent }) : w);
            break;

        case "KeyboardLayoutSwitched":
            keyboardLayouts = { names: keyboardLayouts.names, currentIndex: data.idx ?? 0 };
            break;

        case "CastStartedOrChanged": {
            const c = data.cast;
            if (!c)
                break;
            rawCasts = rawCasts.filter(x => x.stream_id !== c.stream_id).concat([c]);
            break;
        }
        case "CastStopped":
            rawCasts = rawCasts.filter(c => c.stream_id !== data.stream_id);
            break;

        default:
            if (!ignoredEvents.includes(name))
                console.warn("niri: unhandled event", name);
        }
    }
}
