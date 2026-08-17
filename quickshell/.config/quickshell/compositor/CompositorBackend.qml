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

    // Somebody is recording or sharing the screen.
    property bool casting: false

    // Keyboard layouts: names, and which one is current.
    property var keyboardLayouts: ({ names: [], currentIndex: 0 })

    // ---- Actions ---------------------------------------------------------
    //
    // No-ops by default, ON PURPOSE. A caller should be able to invoke any of
    // these without checking first: the capability flag is for deciding whether
    // to show a control, not for guarding every call site.

    function focusWorkspace(id: var): void {}

    function logout(): void {}

    // Helper the bar uses to filter its own monitor's workspaces. Lives here
    // rather than in each backend because it is the same everywhere once the
    // shape above is honoured.
    function workspacesOn(outputName: string): var {
        return workspaces.filter(ws => ws.output === outputName);
    }
}
