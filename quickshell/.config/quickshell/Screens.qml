// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - which screen the shell lives on
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// The bar, the launcher, the power menu, the notifications, the cheatsheet and
// the wallpaper carousel all go on ONE monitor. Four of those take an exclusive
// keyboard grab -- everything but the bar and the notifications -- and two
// copies of any of them would be two surfaces fighting over the keyboard; the
// bar is one monitor for taste rather than necessity.
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

import QtQuick
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

    // WHERE THE GRABBING SURFACES GO -- the launcher, the power menu, the
    // cheatsheet and the wallpaper carousel. One of them at a time, always --
    // each of those singletons closes the others -- and the only question is
    // which screen it appears on, which depends on the compositor rather than
    // on taste.
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

    // WHICH BAR SHOWS A PANEL THAT WAS ASKED FOR RATHER THAN CLICKED ON -- the
    // island's dashboard and the notification history.
    //
    // Both are CONTENT inside the bar's shared popout, and that popout is per
    // bar because the bar is (see barScreens below). So SUPER + D reached every
    // bar at once and every bar opened its own copy: the dashboard inherited
    // the bar's multiplicity by being welded to it, and it is a panel, not a
    // bar. Exactly one of them has to answer.
    //
    // WHICH one is a question grabScreens has already answered -- where a
    // surface the user summoned out of nowhere belongs -- so it is ASKED here
    // rather than answered a second time. A second rule would be free to
    // disagree with the first, and the dashboard and the launcher are
    // alternatives that hang off the same place: opening on different monitors
    // is the one thing they must not do. The unknown-output case and the first
    // instants of a session come with it, already handled up there.
    //
    // THE ONE THING THIS ADDS is that a panel welded to the bar needs a BAR to
    // hang from, which grabScreens knows nothing about. The focused monitor may
    // carry none -- that is a setting -- and there is no popout on a screen
    // with no bar, so the keybind would land nowhere and read as broken. It
    // falls back to the main bar, and to the first bar when the main screen is
    // not one of the screens carrying one.
    //
    // THIS IS ALSO WHERE AN OPEN PANEL MOVES TO. It answers "which bar" at
    // every moment and not only at the moment of opening, so a panel that is
    // already up follows it across -- see settledPanelScreen just below for the
    // part that keeps a travelling pointer from dragging the panel with it.
    readonly property var panelScreen: {
        const bars = root.barScreens;

        if (bars.length === 0)
            return null;

        const wanted = root.grabScreens[0] ?? null;

        if (wanted && bars.some(screen => screen.name === wanted.name))
            return wanted;

        return bars.find(screen => screen.name === root.mainName) ?? bars[0];
    }

    // THE SAME ANSWER, HELD STILL WHILE THE POINTER IS TRAVELLING.
    //
    // A panel that is already open follows panelScreen, and following it costs
    // a REBUILD: the popout on the old bar destroys its content and the popout
    // on the new bar builds it again, because a layer surface belongs to one
    // output and there is no moving one across. That is the same price Variants
    // pays for the launcher and it is fine once. It is not fine several times a
    // second, which is what a focus that follows the mouse hands out while a
    // pointer crosses a monitor edge, or sweeps over a screen in the middle of
    // three.
    //
    // So the MOVE reads this and the OPEN reads panelScreen directly. Opening
    // has to land on the monitor being looked at right now; moving can afford
    // to wait for the focus to mean it. A sweep straight across never moves the
    // panel at all, because by the time this settles the focus is back where it
    // started and the value has not changed.
    //
    // NOT A BINDING, deliberately: a binding would track panelScreen exactly
    // and there would be nothing settled about it. It is assigned by the timer.
    property var settledPanelScreen: null

    // Long enough that crossing a monitor to reach something on the other side
    // does not drag the panel along on the way, short enough that a deliberate
    // move does not read as the shell being slow to notice. It is a rebuild
    // being debounced, not an animation, so it is not one of Theme's durations.
    readonly property int panelSettleDelay: 250

    onPanelScreenChanged: settle.restart()

    Timer {
        id: settle

        interval: root.panelSettleDelay
        onTriggered: root.settledPanelScreen = root.panelScreen
    }

    // The first settle costs no delay. Waiting a quarter of a second at startup
    // for a value nothing is reading yet would be harmless, but it would also
    // leave settledPanelScreen null for that long, and a null that only ever
    // appears in the first instants of a session is the kind of state nothing
    // gets tested against.
    Component.onCompleted: root.settledPanelScreen = root.panelScreen

    // The main screen's key, for the settings window and for anything that has
    // to say "this one" in the same spelling Config stores.
    readonly property string mainKey: Config.screenKey(root.main)

    // The screens carrying a bar. NOT the same filter as mainOnly: the bar is
    // the one surface here that can exist several times over, because it is the
    // only one that never takes a keyboard grab. The launcher, the power menu,
    // the cheatsheet and the carousel all do, and two of those on two monitors
    // would be two surfaces fighting over the keyboard -- see the header.
    //
    // WHAT RIDES ALONG WITH IT does not inherit that licence. The popout that
    // hangs off the bar is per bar too, and the panels inside it that are
    // opened by a KEY are single things that were being drawn once per bar
    // because of where they live. panelScreen above is which bar answers those.
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
