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

    // The file the binds below were actually read out of, tidied for printing.
    // Not a second copy of the path: it is configFile's own, so a session
    // pointed somewhere else by $NIRI_CONFIG names the file it is really
    // using. $HOME goes back to "~" because that is how somebody writes a path
    // down, and because the settings page prints this in a sentence.
    bindsFile: {
        const home = Quickshell.env("HOME") ?? "";
        const path = root.configFile.path;
        return home !== "" && path.startsWith(home + "/")
            ? "~" + path.slice(home.length)
            : path;
    }

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
        // TRUE, and the route is different from the other flavor's rather than
        // absent. niri has no `hyprctl binds`, but its config is KDL and a bind
        // can carry a `hotkey-overlay-title` -- which is exactly the
        // "Category: what it does" string Hyprland's `description` holds. So
        // the answer is read from the config file instead of from the socket.
        //
        // Better than Hyprland's in one way worth noting: there, a Lua config
        // makes every bind report as "__lua" with no readable action at all.
        bindsIntrospection: true,
        // TRUE, and it took the output blocks moving out of config.kdl to get
        // here. `desktop-monitors` speaks KDL as well as Lua now: it lists what is
        // connected from `niri msg -j outputs`, applies a provisional change
        // through `niri msg output` -- which niri itself calls temporary, which
        // is exactly what a change waiting to be confirmed should be -- and
        // writes the confirmed one into ~/.config/niri/monitors.kdl.
        monitorConfig: true,
        // FALSE, and it is the one thing on that page niri cannot be offered.
        // The generated monitors.kdl is the only declaration of any output here,
        // so there is no hand-written file to paste a block into -- and pasting
        // one into config.kdl would be worse than useless: the main config wins
        // over an include, and the display page would go silently dead.
        monitorConfigCopy: false,
        // TRUE SINCE `desktop-tweak` LEARNED THIS FLAVOR, and every row on the
        // Input page reaches the compositor: the pointer speed, the
        // acceleration profile, natural scrolling, the key repeat pair and the
        // keyboard cycle all land in ~/.config/niri/tweaks.kdl, which config.kdl
        // includes -- and niri watches what it includes, so writing that file is
        // what applies it. There is nothing to push into a running session and
        // nothing missing because of it; see `compositor can live-config`.
        //
        // The one input setting with NO equivalent here is per-device
        // configuration: niri has none at all, and Hyprland's hl.device is what
        // switches the DualSense's touchpad off. The page never offered it -- so
        // nothing on it is dead under this flavor -- and the absence is written
        // down in its header and in config.kdl's input block, which are the two
        // places somebody would go looking.
        inputConfig: true,
        // niri has no special workspace at all: upstream issue #845, open since
        // December 2024. The config maps the old scratchpad chords onto a named
        // workspace, which is a place you go to rather than an overlay.
        scratchpad: false,
        // FALSE, measured rather than assumed. niri's Window carries a `layout`
        // with tile and window SIZES, but `tile_pos_in_workspace_view` is null
        // -- checked against six visible windows across both monitors, every
        // one of them null. Sizes without positions cannot be turned into
        // screen rectangles, so there is nothing to hand slurp.
        windowGeometry: false,
        // FALSE, and this one is felt immediately rather than in theory. niri's
        // keyboard focus belongs to a monitor, so a launcher pinned to the main
        // screen opens there, takes its exclusive grab, and then receives
        // nothing at all while the user is focused on the other monitor -- the
        // window appears and typing goes nowhere.
        globalKeyboardGrab: false,
        // FALSE on niri 26.04, and this one is a hole in the compositor rather
        // than a shape it chose. There is no way to run anything when a key is
        // RELEASED: `niri validate` rejects on-release, release, key-up and
        // hold, it does not implement hyprland-global-shortcuts-v1 -- no such
        // string in the binary -- and the portal route dead-ends, because
        // xdg-desktop-portal-gnome proxies GlobalShortcuts to org.gnome.Shell
        // and niri publishes only .Introspect and .Screenshot of that.
        //
        // Upstream niri-wm/niri#3621 adds press and release binds and is
        // approved but not merged; its own example is this exact feature. When
        // it lands, this becomes true, desktop-tweak grows a generate_niri
        // counterpart to ptt_lua, and nothing else changes -- the microphone
        // half already lives in the shell.
        //
        // The alternative that works today is an evdev reader outside the
        // compositor (xremap and friends), which is a daemon reading the
        // keyboard, and it is not worth that to avoid waiting for #3621.
        pushToTalk: false,
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

    // ---- Is the bar actually covered? ------------------------------------
    //
    // The wlr protocol says which toplevels are fullscreen and which output
    // each one sits on. It does not say whether that window is the one the
    // monitor is currently showing, and niri never withdraws the output when a
    // workspace scrolls out of sight -- so the inherited answer said "covered"
    // for a game parked fullscreen three workspaces away, forever. The long
    // note over fullscreenOutputs in CompositorBackend.qml is where that is
    // written down; this is the half niri has to supply.
    //
    // IT SUPPLIES IT IN TWO HOPS IT ALREADY SENDS DOWN THIS SOCKET: a window
    // carries `workspace_id`, and a workspace carries `output` and `is_active`
    // -- which is exactly "the workspace this monitor is showing right now".
    // Both arrive in the opening snapshot and both are kept up to date by
    // events this backend already handles (WorkspaceActivated,
    // WindowOpenedOrChanged, WindowClosed), so there is nothing new to poll.
    //
    // THE JOIN IS BY app_id AND title, WHICH IS NOT WHAT ANYBODY WOULD CHOOSE.
    // A wlr Toplevel cannot be tied back to a niri window id: that id travels
    // as ext-foreign-toplevel-list's `identifier`, and Quickshell 0.3.0 does
    // not bind that protocol at all -- the same gap this file's header records
    // for ext-workspace-v1, and the reason this backend speaks the socket
    // itself. app_id and title are the only fields both sides publish, and both
    // sides read them off the same xdg_toplevel role, so they agree by
    // construction rather than by luck.
    //
    // WHICH WAY THE JOIN FAILS IS THE POINT. Two windows of one app sharing a
    // title -- one fullscreen out of sight, one on the visible workspace --
    // read as "covered" when nothing is covering, which is precisely what this
    // shell did for every window before the join existed. Steady state cannot
    // fail the other way: the fullscreen window is itself one of the windows
    // niri lists, so when its own workspace is the active one it matches
    // itself. The one moment it can is a title changing, since the new text
    // reaches the wlr protocol and this socket independently -- a player
    // stepping to the next track leaves the two disagreeing for as long as it
    // takes the second message to arrive, and a panel open at that instant
    // welds itself back on for a frame. It corrects itself and nothing else
    // depends on it.
    readonly property var visibleWindowKeys: {
        const outputOfActive = {};
        for (const ws of rawWorkspaces)
            if (ws.is_active === true)
                outputOfActive[ws.id] = ws.output ?? "";

        const keys = {};
        for (const w of rawWindows) {
            const output = outputOfActive[w.workspace_id];
            if (output === undefined)
                continue;
            keys[root.windowKey(output, w.app_id ?? "", w.title ?? "")] = true;
        }
        return keys;
    }

    // A NUL byte joins the three parts, for two reasons. It cannot occur in an
    // output name, an app id or a title, so no pair of windows can be joined
    // into one key by a separator that appears inside a field; and every key
    // therefore contains one, which is what keeps a window titled "toString"
    // from finding something on Object.prototype instead of missing.
    function windowKey(output: string, appId: string, title: string): string {
        return `${output}\u0000${appId}\u0000${title}`;
    }

    fullscreenOutputs: {
        const names = [];
        for (const tl of root.toplevelManager.toplevels.values) {
            if (tl.fullscreen !== true)
                continue;
            for (const s of (tl.screens ?? [])) {
                const output = s?.name ?? "";
                if (output === "" || names.includes(output))
                    continue;
                const key = root.windowKey(output, tl.appId ?? "", tl.title ?? "");
                if (root.visibleWindowKeys[key] === true)
                    names.push(output);
            }
        }
        return names;
    }

    // ---- Keybindings ------------------------------------------------------
    //
    // READ FROM THE CONFIG FILE, because there is no IPC for this: niri knows
    // its binds -- its own hotkey overlay lists them -- but does not expose
    // them. The file is the next best source and an honest one, since it IS
    // what the compositor loaded.
    //
    // Only binds carrying a hotkey-overlay-title are listed, which matches the
    // rule on the other flavor: a bind with no description is deliberately
    // invisible, and that is what keeps the sheet to the chords worth
    // remembering rather than every media key.
    //
    // The title doubles as niri's own overlay text, so writing one serves both
    // the built-in overlay and this shell -- there is no second place to keep
    // in step.
    function refreshBinds(): void {
        configFile.reload();
    }

    // "Mod+Shift+S" -> ["SUPER", "SHIFT", "S"]. Mod is what niri calls the
    // modifier that is Super in a real session, and the shell spells it the way
    // it is printed on the key.
    function chordToKeys(chord: string): var {
        return chord.split("+").map(part => {
            switch (part) {
            case "Mod": return "SUPER";
            case "Shift": return "SHIFT";
            case "Ctrl": return "CTRL";
            case "Alt": return "ALT";
            default: return part;
            }
        });
    }

    property FileView configFile: FileView {
        // $NIRI_CONFIG wins where it is set, the way niri itself resolves it.
        path: (Quickshell.env("NIRI_CONFIG") ?? "")
            || `${Quickshell.env("HOME")}/.config/niri/config.kdl`

        onLoaded: {
            const out = [];

            // EVERY bind line, titled or not, because the keybinds page lists
            // the undescribed ones too. A line looks like one of:
            //   Mod+Return hotkey-overlay-title="Apps: a terminal" { spawn ... }
            //   XF86AudioMute allow-when-locked=true { spawn ... }
            //
            // Anchored to the start of a line and requiring the opening brace,
            // so a chord written inside a comment cannot be mistaken for a
            // binding -- and this file is full of chords inside comments.
            //
            // ONE HONEST GAP: this reads the config rather than the compositor,
            // so it lists what the file says instead of what niri is holding.
            // The two agree unless the file was edited and not reloaded, and
            // since niri reloads on save that window is about as long as it
            // takes to hit save. Hyprland's side asks the compositor directly
            // and has no such gap.
            const bindLine = /^[ \t]*([A-Za-z0-9_+]+)((?:[ \t]+[a-z-]+=(?:"[^"]*"|[^ \t{]+))*)[ \t]*\{/gm;
            const titleIn = /hotkey-overlay-title="([^"]+)"/;

            let m;
            while ((m = bindLine.exec(text())) !== null) {
                const chord = m[1];
                // The chord always carries a modifier or is a named media key;
                // a bare word followed by a brace is a config section, not a
                // bind.
                if (!chord.includes("+") && !chord.startsWith("XF86"))
                    continue;

                const titleMatch = titleIn.exec(m[2] ?? "");
                const title = titleMatch ? titleMatch[1] : "";
                const described = title !== "";
                const colon = title.indexOf(": ");

                out.push({
                    keys: root.chordToKeys(chord),
                    category: !described ? "Undescribed"
                        : colon < 0 ? "Other" : title.slice(0, colon),
                    description: !described ? ""
                        : colon < 0 ? title : title.slice(colon + 2),
                    described: described,
                    // niri has no submaps, and every bind consumes its chord.
                    submap: "",
                    nonConsuming: false
                });
            }
            root.binds = out;
        }

        onLoadFailed: error => {
            console.warn("niri: could not read the config to list binds:", error);
            root.binds = [];
        }
    }

    // ---- Actions ---------------------------------------------------------

    function focusWorkspace(id: var): void {
        // `reference` is an enum and the variants are not interchangeable: Id is
        // the stable identity, Index is the position on its monitor.
        root.action({ FocusWorkspace: { reference: { Id: id } } });
    }

    function switchKeyboardLayout(): void {
        root.action({ SwitchLayout: { layout: "Next" } });
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
