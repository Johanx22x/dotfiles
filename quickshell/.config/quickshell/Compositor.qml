// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - which compositor is running, and what it can do
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// The one place in the shell that knows there is more than one compositor.
// Everything else asks this singleton for workspaces, for the focused window,
// for whether somebody is recording -- and, when it wants to know if a control
// is worth showing at all, for a capability.
//
// HOW TO ADD A THIRD COMPOSITOR
// Write compositor/YourBackend.qml, subclassing CompositorBackend; override
// what it can do and declare the rest false. Add two lines here: a Component
// and a case in the detector below. Nothing else in the shell changes, and
// anything your backend cannot do is already handled everywhere, because niri
// exercises the false path today.
//
// AN UNKNOWN COMPOSITOR IS A SUPPORTED STATE, not an error. With no match the
// plain CompositorBackend is loaded: every capability false, every list empty,
// every action a no-op. The bar comes up, the clock ticks, the tray works, the
// notifications work, and the parts that need a compositor quietly stay away.
// That is the floor a new backend is built up from rather than a failure mode
// to guard against.
//
// See compositor/CompositorBackend.qml for the interface and the rule about
// what belongs in `capabilities`.

pragma Singleton

import Quickshell
import QtQuick
import "compositor"

Singleton {
    id: root

    // WHY THE SOCKET AND NOT XDG_CURRENT_DESKTOP
    // The desktop name is set by the session's .desktop file and survives into
    // any process the session starts, including one running under a nested
    // compositor -- so it says what you logged into, not what this shell is
    // talking to. The socket variables are published by the compositor itself,
    // which makes them proof that it is there and answering.
    readonly property string flavor: {
        if ((Quickshell.env("NIRI_SOCKET") ?? "") !== "")
            return "niri";
        if ((Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== "")
            return "hyprland";
        return "unknown";
    }

    readonly property CompositorBackend backend: loader.item

    // ---- The interface, forwarded ----------------------------------------
    //
    // Defaults repeated here rather than trusted to the backend: `loader.item`
    // is null for the instant before the component finishes, and a binding that
    // read straight through would spend that instant undefined.
    readonly property bool ready: backend?.ready ?? false
    readonly property string name: backend?.name ?? "unknown"
    readonly property var workspaces: backend?.workspaces ?? []
    readonly property var activeWindow: backend?.activeWindow ?? null
    readonly property string focusedOutput: backend?.focusedOutput ?? ""
    readonly property bool casting: backend?.casting ?? false
    readonly property var keyboardLayouts: backend?.keyboardLayouts ?? ({ names: [], currentIndex: 0 })

    // The question the shell should be asking. `Compositor.can("monitorConfig")`
    // rather than a name check -- see the header of CompositorBackend.qml for
    // why that difference is the whole point of this layer.
    function can(feature: string): bool {
        return backend?.can(feature) ?? false;
    }

    function workspacesOn(outputName: string): var {
        return workspaces.filter(ws => ws.output === outputName);
    }

    function focusWorkspace(id: var): void {
        backend?.focusWorkspace(id);
    }

    function logout(): void {
        backend?.logout();
    }

    // ---- The backend itself ----------------------------------------------
    property Loader loader: Loader {
        active: true
        sourceComponent: {
            switch (root.flavor) {
            case "niri":
                return niriBackend;
            case "hyprland":
                return hyprlandBackend;
            default:
                return nullBackend;
            }
        }
    }

    property Component niriBackend: Component { NiriBackend {} }
    property Component hyprlandBackend: Component { HyprlandBackend {} }

    // The floor: the contract with nothing implemented. Not a stub for testing
    // -- this is what runs on a compositor nobody has written a backend for.
    property Component nullBackend: Component { CompositorBackend {} }
}
