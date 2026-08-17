// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - which screen the shell lives on
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// The bar, the launcher, the power menu, the notifications and the cheatsheet
// all go on ONE monitor. Four of those take an exclusive keyboard grab, and
// two copies of any of them would be two surfaces fighting over the keyboard;
// the bar is one monitor for taste rather than necessity.
//
// WHY THIS IS NOT A MODEL NAME ANY MORE
// It used to be `screen.model === "PG32QF2B"`, written out five times in
// shell.qml. That is not a preference, it is a machine: on any other hardware
// the filter matches nothing, Variants builds nothing, and the shell comes up
// with NO bar, no launcher, no notifications and no power menu -- running
// perfectly and drawing nothing. A clone that silently produces an empty
// screen is worse than one that fails loudly.
//
// So the screen is CHOSEN, by a rule that lands on the right one here and on a
// sensible one anywhere:
//
//   1. `Config.mainMonitor`, if it is set and that monitor is plugged in. The
//      answer given in the settings window, which beats any rule: the rule can
//      only guess from size and shape, and two identical monitors defeat it
//      entirely.
//   2. One screen: that one. The single-monitor case, which is most people.
//   3. The largest LANDSCAPE screen. Landscape first because a portrait panel
//      is a side monitor in every setup that has one -- it is here, and a
//      full-width bar across a 1080px-wide screen would be a different design
//      anyway.
//   4. No landscape screen at all: the largest one, whatever its shape.
//
// Ties break on the connector name, alphabetically. That matters more than it
// looks: two identical monitors would otherwise be separated by whatever order
// the compositor happened to report them in, and the bar would move from one
// to the other between boots.

pragma Singleton

import Quickshell
import "root:/"

Singleton {
    id: root

    // Every screen the compositor is driving, in a stable order. Sorted by
    // connector so the settings window lists them the same way twice running --
    // Quickshell reports them in the order they were announced, which is not
    // an order, it is a history.
    readonly property var all: [...Quickshell.screens].sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)

    // Bigger is better, and equal areas fall back to the name so the answer is
    // the same on every boot.
    function better(candidate: var, current: var): bool {
        if (!current)
            return true;

        const a = candidate.width * candidate.height;
        const b = current.width * current.height;

        if (a !== b)
            return a > b;

        return candidate.name < current.name;
    }

    readonly property var main: {
        const screens = root.all;

        if (screens.length === 0)
            return null;

        if (Config.mainMonitor) {
            for (const screen of screens)
                if (Config.screenKey(screen) === Config.mainMonitor)
                    return screen;
            // Falls through on purpose: a monitor that is chosen but unplugged
            // right now -- a laptop away from its dock, a KVM on the other
            // input -- should not cost you the whole shell. The setting stays
            // put, so plugging it back in puts the bar back where it was.
            console.warn(`Screens: chosen monitor "${Config.mainMonitor}" is not connected, choosing automatically`);
        }

        if (screens.length === 1)
            return screens[0];

        let best = null;

        for (const screen of screens)
            if (screen.width > screen.height && root.better(screen, best))
                best = screen;

        if (best)
            return best;

        for (const screen of screens)
            if (root.better(screen, best))
                best = screen;

        return best;
    }

    // The connector name -- "DP-3", "HDMI-A-1". What Hyprland and the tools
    // that take a monitor on their command line expect. Assigned by the kernel
    // and NOT stable across kernel versions, which is exactly why nothing
    // should write one down: read it from here instead.
    readonly property string mainName: root.main?.name ?? ""

    // For `Variants { model: Screens.mainOnly }`: a list of one, or of none if
    // there is no screen at all. Variants takes a list, and this keeps the
    // filtering out of shell.qml.
    readonly property var mainOnly: root.main ? [root.main] : []

    // WHERE THE GRABBING SURFACES GO -- the launcher, the power menu and the
    // cheatsheet. One of them at a time, always; the only question is which
    // screen it appears on, and that depends on the compositor rather than on
    // taste.
    //
    // Where the keyboard grab is session-wide, a fixed screen is right: the
    // surface is heard wherever the user happens to be looking, and pinning it
    // to the main monitor means it always shows up in the same place.
    //
    // Where keyboard focus belongs to a MONITOR, that same arrangement breaks in
    // the worst way -- the launcher opens on the main screen, takes its
    // exclusive grab, and receives nothing at all while the user is focused on
    // the other monitor. The window is there and typing goes nowhere. So it
    // follows the focus instead.
    //
    // Falls back to the main screen whenever the focused output is unknown or
    // is not one of ours, which is also the state for the first instants of a
    // session, before the compositor has said anything.
    readonly property var grabScreens: {
        if (Compositor.can("globalKeyboardGrab"))
            return root.mainOnly;

        const focused = Quickshell.screens.find(s => s.name === Compositor.focusedOutput);
        return focused ? [focused] : root.mainOnly;
    }

    // The main screen's key, for the settings window and for anything that has
    // to say "this one" in the same spelling Config stores.
    readonly property string mainKey: Config.screenKey(root.main)

    // The screens carrying a bar. NOT the same filter as mainOnly: the bar is
    // the one surface here that can exist several times over, because it is the
    // only one that never takes a keyboard grab. The launcher, the power menu
    // and the cheatsheet all do, and two of those on two monitors would be two
    // surfaces fighting over the keyboard -- see the header.
    //
    // Falls back to the main screen when the chosen monitors are all
    // disconnected. Coming back from an undocked laptop, or from a monitor that
    // died, should leave you a bar to work with rather than a bare desktop and
    // no visible way to open the settings window that fixes it.
    readonly property var barScreens: {
        const chosen = Config.barMonitors ?? [];

        // Nothing chosen is not "nowhere", it is the arrangement this shell
        // shipped with: one bar, on the main monitor.
        if (chosen.length === 0)
            return root.mainOnly;

        const on = root.all.filter(screen => chosen.includes(Config.screenKey(screen)));
        return on.length > 0 ? on : root.mainOnly;
    }

    // Whether a given screen ends up with a bar, answered from barScreens
    // rather than from the stored list, so the fallbacks above are part of the
    // answer: a settings window reading the raw list would show every monitor
    // switched off on a machine that plainly has a bar.
    function hasBar(screen: var): bool {
        return root.barScreens.some(candidate => candidate.name === (screen?.name ?? ""));
    }
}
