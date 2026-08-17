// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - the contract every compositor backend implements
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// This file is the interface, written as a working object rather than as
// documentation: every property below has a safe, empty default, so a backend
// only declares what it can actually do and anything it leaves alone still
// reads as "nothing" instead of undefined. Subclass it, override what you
// support, and say so in `capabilities`.
//
// WHY CAPABILITIES AND NOT A COMPOSITOR NAME
// The shell must never ask "am I on niri". It asks "can this compositor tell me
// which windows are on a workspace", and draws accordingly. The difference is
// what a third compositor costs: with a name check, every `if (compositor ===
// "hyprland")` scattered through the QML has to be found and extended, and the
// ones that are missed fail silently. With capabilities, a new backend declares
// false and every consumer already handles it, because they all handle the
// false case today -- niri exercises it.
//
// The rule for adding to this file: a capability describes SOMETHING THE SHELL
// DRAWS OR DOES, not a feature of a compositor. `bindsIntrospection` is here
// because there is a cheatsheet that lists keybinds and it needs to know
// whether it can be filled; there is no `supportsScrollableTiling`, because
// nothing in the shell would do anything differently.

import Quickshell
import Quickshell.Wayland
import QtQuick

QtObject {
    id: root

    // A human-readable name, for the one legitimate use of knowing: telling the
    // user what they are running (the dashboard's system panel). Never branch
    // on this.
    property string name: "unknown"

    // Is a compositor actually there and talking? False means every property
    // below is empty and every method is a no-op, which is the state the shell
    // comes up in for a few hundred milliseconds and the state it stays in if
    // the backend cannot connect at all.
    property bool ready: false

    // ---- What this backend can do ---------------------------------------
    //
    // Every flag defaults to false. A backend that forgets to declare one gets
    // the conservative answer, and a feature quietly missing is a far better
    // failure than a feature that throws.
    property var capabilities: ({
        // Can it list workspaces, with an active/focused state?
        workspaces: false,
        // Are workspaces stable, numbered places (Hyprland's 1..10), as opposed
        // to a dynamic list where the number is a position (niri)? The bar
        // draws both, but only the first can label a dot with a number that
        // means something tomorrow.
        fixedWorkspaceNumbers: false,
        // Can it say how many windows sit on a given workspace? Drives the
        // dim-versus-bright dot.
        workspaceOccupancy: false,
        // Can it report the focused window's app id and title, per monitor?
        activeWindow: false,
        // Can it tell us somebody is capturing the screen?
        castingIndicator: false,
        // Can it report the active keyboard layout?
        keyboardLayout: false,
        // Does it offer a click-outside-to-dismiss grab for layer surfaces?
        // Hyprland does through its own protocol; nothing generic exists, so
        // everyone else falls back to a full-screen input catcher.
        focusGrab: false,
        // Can the list of keybindings be read back out of it? Feeds the
        // cheatsheet and the keybinds settings page.
        bindsIntrospection: false,
        // Can monitors be configured through the shell (the display page)?
        monitorConfig: false,
        // Can input settings be changed through the shell (the input page)?
        inputConfig: false,
        // Is there a scratchpad / special workspace to send a window to?
        scratchpad: false,
        // Does a layer surface holding an exclusive keyboard grab receive keys
        // NO MATTER WHICH MONITOR the user is focused on?
        //
        // True on a compositor with one session-wide keyboard focus, false where
        // focus belongs to a monitor. It decides where the launcher, the power
        // menu and the cheatsheet are put: one fixed screen is only safe when
        // the grab is global, and anywhere else they have to follow the focus or
        // they come up on the wrong monitor and swallow nothing.
        globalKeyboardGrab: false,
        // Can the session be ended by asking the compositor?
        logout: false
    })

    function can(feature: string): bool {
        return capabilities[feature] === true;
    }

    // ---- State -----------------------------------------------------------
    //
    // NORMALISED SHAPES, not whatever the compositor happens to call things.
    // Each backend translates on the way out, so the QML that draws a workspace
    // dot never learns that one compositor spells it `is_active` and another
    // `active`. This is the whole point of the layer.
    //
    // Workspace:
    //   id        opaque, stable identity -- pass it back to focusWorkspace
    //   number    what to show the user, or 0 when there is nothing meaningful
    //   name      may be empty
    //   output    the monitor's name, matched against ShellScreen.name
    //   active    shown on its own monitor
    //   focused   has the keyboard (at most one in the whole session)
    //   urgent    wants attention
    //   windows   how many windows are on it, or -1 when unknown
    property var workspaces: []

    // ActiveWindow, or null:
    //   appId   the Wayland app id, for the icon lookup
    //   title   the window title
    //   output  which monitor it is on, so a bar can ignore the other one's
    property var activeWindow: null

    // The monitor holding the keyboard, by name. Empty when unknown.
    property string focusedOutput: ""

    // ---- Screen capture ---------------------------------------------------
    //
    // A COUNT AND NOT A BOOL. Two applications can hold a capture at once -- a
    // call sharing a window while OBS records the screen -- and with a bool
    // whichever stops first would clear the indicator while the other is still
    // going.
    property int captureCount: 0

    // "monitor" or "window", and which one. Best effort: not every compositor
    // says, and an empty string means "capturing, but it did not tell us what".
    // The indicator degrades to saying that something is being shared.
    property string captureOwner: ""
    property string captureTarget: ""

    readonly property bool casting: captureCount > 0

    // Keyboard layouts: names, and which one is current.
    property var keyboardLayouts: ({ names: [], currentIndex: 0 })

    // ---- Keybindings -----------------------------------------------------
    //
    // What is bound, for the cheatsheet and the keybinds page. Empty where
    // `bindsIntrospection` is false.
    //
    // ALREADY IN CHIPS, not in the compositor's own spelling: each entry is
    //   { keys: ["SUPER","SHIFT","S"], category: "Capture",
    //     description: "...", described: true }
    // because the two compositors describe a chord in completely different
    // terms -- one hands over an X11 modifier bitmask and an xkb keysym, the
    // other a string like "Mod+Shift+S" -- and a cheatsheet should not have to
    // know either. Translating on the way out is the same rule the workspace
    // shape follows.
    //
    // The category is the part before ": " in the description, which is the
    // convention both flavors already write their descriptions in.
    //
    // EVERY BIND IS LISTED, described or not, and `described` says which. The
    // two consumers want different halves: the cheatsheet shows only what
    // carries a description, because its job is the chords worth remembering,
    // while the keybinds page lists everything the compositor is holding --
    // including the media keys -- because its job is to answer "what is this
    // chord doing". One source, filtered by whoever draws it.
    property var binds: []

    // Re-read what is bound. Called when the cheatsheet opens, since a config
    // reload between two openings is exactly what a cached list gets wrong.
    function refreshBinds(): void {}

    // ---- Implemented once, for everyone -----------------------------------
    //
    // WHAT BELONGS HERE RATHER THAN IN A BACKEND: anything answerable through a
    // protocol every compositor speaks. A backend may still override it if its
    // own IPC does the job better, but nobody has to, and a compositor nobody
    // has written a backend for gets it for free.
    //
    // Fullscreen detection is the first of these. wlr-foreign-toplevel carries
    // a `fullscreen` flag and the screens a window is on, so this needs no
    // compositor-specific help at all -- which is just as well, because niri's
    // IPC does not report fullscreen on a window (its Window has ten fields and
    // none of them is that) while Hyprland's does, and a facade whose answer
    // depended on which one you were running would be exactly the kind of thing
    // this layer exists to prevent.
    property var toplevelManager: ToplevelManager

    readonly property var fullscreenOutputs: {
        const names = [];
        for (const tl of ToplevelManager.toplevels.values) {
            if (tl.fullscreen !== true)
                continue;
            for (const s of (tl.screens ?? [])) {
                if (s?.name && !names.includes(s.name))
                    names.push(s.name);
            }
        }
        return names;
    }

    // Is something fullscreen on this monitor? Asked by every surface that is
    // welded to the bar, since a fullscreen window covers the bar and leaves
    // the weld joining a panel to nothing.
    function hasFullscreenOn(outputName: string): bool {
        return fullscreenOutputs.includes(outputName);
    }

    // ---- Actions ---------------------------------------------------------
    //
    // No-ops by default, ON PURPOSE. A caller should be able to invoke any of
    // these without checking first: the capability flag is for deciding whether
    // to show a control, not for guarding every call site.

    function focusWorkspace(id: var): void {}

    // Ending the session HAS a generic answer, unlike most of this file, so the
    // default is a working one rather than a no-op: systemd-logind will close
    // the session whatever is drawing it. A backend overrides this only to ask
    // its compositor nicely first -- which is worth doing, because a compositor
    // that exits on its own tears the session down in the order it wants to.
    // Step to the next keyboard layout. Only meaningful where
    // `keyboardLayout` is true -- elsewhere the shell rotates a stored list
    // instead, because the compositor's own index cannot be read back.
    function switchKeyboardLayout(): void {}

    function logout(): void {
        Quickshell.execDetached(["loginctl", "terminate-user", Quickshell.env("USER") ?? ""]);
    }

    // Helper the bar uses to filter its own monitor's workspaces. Lives here
    // rather than in each backend because it is the same everywhere once the
    // shape above is honoured.
    function workspacesOn(outputName: string): var {
        return workspaces.filter(ws => ws.output === outputName);
    }
}
