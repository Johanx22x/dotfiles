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
//   1. `preferredModel` below, if it is set and present. The escape hatch, for
//      two identical monitors where the rule cannot know which you meant.
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

Singleton {
    id: root

    // Set to a monitor model (as `hyprctl monitors -j` reports `model`, e.g.
    // "PG32QF2B") to pin the shell to it. Empty means "work it out", which is
    // what every machine but a two-identical-monitor one wants.
    readonly property string preferredModel: ""

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
        const screens = Quickshell.screens;

        if (screens.length === 0)
            return null;

        if (root.preferredModel) {
            for (const screen of screens)
                if (screen.model === root.preferredModel)
                    return screen;
            // Falls through on purpose: a preferred model that is not plugged
            // in right now should not cost you the whole shell.
            console.warn(`Screens: no monitor with model "${root.preferredModel}", choosing automatically`);
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
}
