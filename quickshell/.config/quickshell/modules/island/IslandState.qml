// What the island is currently about, and who gets to say so.
//
// THE ONE RULE: the island shows ONE thing. The moment it shows two, it stops
// being an island and becomes another row of the bar -- which is the thing the
// centre of the bar was cleared out to avoid. So there is an arbiter, and this
// is it.
//
// THE LADDER, highest first:
//
//   1. Acknowledgement  volume and brightness, and whatever joins them later
//                       (mic mute, capture taken). These are answers to
//                       something the user JUST did: they appear, they
//                       confirm, and they get out of the way after
//                       `ackDuration`. This is the whole reason Volume no
//                       longer has a permanent seat on the right of the bar
//                       -- a number that matters for two seconds does not
//                       deserve one.
//   2. Activity         a thing that is ongoing and unattended. Screen
//                       capture is the first occupant: something is watching
//                       this screen and you should not have to remember it.
//                       Recording and transfers join here later.
//   3. Media            what is playing. Lasts as long as a player exists.
//   4. Idle             the minimal capsule. What is on screen 95% of the
//                       time, and deliberately almost nothing: the island
//                       reads as "something happened" only if its resting
//                       state is quiet.
//
// Only level 1 lives here, because only level 1 is a PUSH -- something fires
// and the island has to react within the second. Media and idle are pulled:
// Island.qml derives them from services it already watches, and asking those
// to also report into a singleton would be two sources of truth for one
// screen. `mode` in Island.qml is where the ladder is actually applied.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Singleton {
    id: root

    // ---------------- Level 2: screen capture ----------------
    //
    // WHO is capturing and HOW MANY are doing it comes from the compositor
    // backend, which is where the differences live: one flavor announces the
    // transition on an event socket, the other publishes the list of live
    // casts. See compositor/ for both, and for why a count beats a bool.
    //
    // What is left here is the part that belongs to this indicator.
    readonly property int captureSessions: Compositor.captureCount

    // "monitor" or "window", and which one.
    readonly property string captureOwner: Compositor.captureOwner
    readonly property string captureTarget: Compositor.captureTarget

    // A screenshot is a capture too, and the number here comes from MEASURING
    // one rather than guessing. Timestamped on Hyprland's event socket, a
    // full-desktop `grim` holds its sessions open for 500 ms -- two of them,
    // one per monitor -- so a 400 ms grace period would still have flashed
    // "Sharing DP-3" across the bar every time a screenshot was taken.
    //
    // 1200 clears that with room to spare, and costs nothing where it matters:
    // a real share lasts minutes, so starting the indicator a second late is
    // imperceptible.
    readonly property int captureGrace: 1200

    readonly property bool capturing: root.captureSettled && root.captureSessions > 0

    property bool captureSettled: false

    Timer {
        id: captureGraceTimer

        interval: root.captureGrace
        onTriggered: root.captureSettled = true
    }

    // Counting, and telling monitor from window, is the compositor's business
    // and now lives in its backend -- including the note on where those event
    // lines came from. What stays here is the GRACE PERIOD, which is a decision
    // about this indicator rather than a fact about any compositor.
    Connections {
        target: Compositor

        function onCaptureCountChanged(): void {
            if (Compositor.captureCount > 0) {
                if (!captureGraceTimer.running && !root.captureSettled)
                    captureGraceTimer.restart();
            } else {
                captureGraceTimer.stop();
                root.captureSettled = false;
            }
        }
    }

    // How long an acknowledgement holds the island before it falls back down
    // the ladder. Long enough to read a two-digit number and short enough that
    // nudging the volume wheel repeatedly feels continuous rather than queued.
    readonly property int ackDuration: 2000

    // "" when nothing is being acknowledged. A string rather than a bool
    // because brightness turned out to be exactly that -- the same mechanism
    // with a different glyph -- and mic mute is the next one.
    property string ack: ""

    // Payload of the current acknowledgement. Deliberately untyped and shared:
    // one acknowledgement is on screen at a time, so one set of fields is
    // enough, and a per-kind object would only add a lookup.
    property int ackValue: 0
    property bool ackMuted: false

    // ---------------- The dashboard ----------------
    //
    // WHERE THE DASHBOARD IS, or "" when it is not up: the connector name of
    // the bar drawing it. One string, so it cannot be up in two places, and it
    // is a name rather than an object so that comparing it costs nothing and a
    // monitor being unplugged simply stops matching.
    //
    // THIS USED TO BE A SIGNAL, and the note that stood here said whether the
    // dashboard is up is not this singleton's state -- the popout knows, and a
    // copy here would be a second source of truth. That was right while the
    // panel could only ever appear where it was asked for. It stopped being
    // right when the panel had to FOLLOW THE FOCUS: there is one popout per
    // bar, each of them can see only itself, and none of them can answer "the
    // dashboard is up over there, bring it here" -- which is the whole of the
    // move. The fact outgrew the surface that was holding it.
    //
    // It is not a new pattern either, it is the launcher's. Its isOpen is a
    // bool in a singleton and its window is built by Variants on whichever
    // screen has the focus, so the flag outlives the window and the window
    // moves with it. The dashboard now works the same way, which is also what
    // makes the two behave alike -- they are alternatives hanging off the same
    // place.
    //
    // NOTHING WRITES THIS BY HAND except the doors below and Island.qml, which
    // clears it when its popout stops showing the dashboard for any other
    // reason: a click outside, a click on the bar, the tray taking the popout
    // over. That one rule is what keeps the string from outliving the panel.
    property string dashboardScreen: ""

    // SUPER + D, and the IPC call under it. It asks Screens where the panel
    // belongs, which is the bar with the focus and, failing that, a bar that
    // exists -- see panelScreen there.
    function toggleDashboard(): void {
        root.toggleDashboardOn(Screens.panelScreen?.name ?? "");
    }

    // THE SAME TOGGLE WITH THE BAR NAMED, for the click on the island. A click
    // lands on one bar and says so, and it is the one entry point that does not
    // have to ask where the panel belongs -- it is where the pointer already
    // is. From that moment on the panel follows the focus like any other,
    // because the singleton cannot tell how it came to be up and should not.
    //
    // An empty name closes, which is what a bar with no screen would mean, and
    // is also what makes this safe to call with `screen?.name ?? ""`.
    function toggleDashboardOn(name: string): void {
        root.dashboardScreen = root.dashboardScreen === name ? "" : name;
    }

    // AND IT MOVES. Following panelScreen at every moment rather than only at
    // the moment of opening is the whole point of keeping the screen here: the
    // panel is where the focus is, not where the focus happened to be when the
    // key was pressed.
    //
    // IT USED TO CLOSE INSTEAD, and the argument for that is worth keeping so
    // nobody rediscovers it as an improvement. The launcher can afford to
    // follow the focus because it holds an exclusive keyboard grab: while it is
    // up nothing else can be reached, so the focus cannot wander by accident.
    // This panel holds no grab, and the focus here follows the mouse, so
    // following means the dashboard moving between monitors whenever a pointer
    // crosses -- and closing is what the next click outside it would have done
    // anyway. That reasoning is sound and it is not what is wanted: a panel
    // that vanishes because the pointer went somewhere is worse than a panel
    // that goes with it, and the two doors onto the same place should not
    // behave differently. It lost to that, not to a better argument.
    //
    // What the argument bought is the DEBOUNCE. Following the settled answer
    // rather than the live one -- see the note over settledPanelScreen in
    // Screens.qml -- is what keeps a pointer merely travelling past from
    // dragging the panel along, which was the real cost hiding inside it. Each
    // move destroys the panel on one bar and builds it again on the other.
    //
    // A panel that is DOWN is left alone: this never opens anything, it only
    // moves what is already up.
    Connections {
        target: Screens

        function onSettledPanelScreenChanged(): void {
            if (root.dashboardScreen === "")
                return;

            const moved = Screens.settledPanelScreen?.name ?? "";

            // No bar to move to at all -- every monitor gone, the state a
            // laptop lid closing produces -- leaves the panel where it is
            // rather than dropping it. There is nothing on screen to be wrong
            // about, and the next screen to arrive brings it back.
            if (moved !== "")
                root.dashboardScreen = moved;
        }
    }

    // A `dashboardTabs` list and a `dashboardTab` index lived here, and both
    // are gone because the dashboard has no tabs left to be on.
    //
    // They lived HERE and not in Dashboard.qml for a reason worth keeping in
    // mind if anything else in that panel ever needs to remember something:
    // the popout DESTROYS its content when it closes, which is what stops a
    // popout carrying stale state between openings, and it is also why the tab
    // kept snapping back to the first one until the index moved out here. Any
    // state the dashboard has to keep across an opening has to outlive the
    // thing that displays it.
    //
    // The list itself was here so the ORDER was answerable while the dashboard
    // did not exist, and because two lists that had to agree on an order
    // eventually would not. It ended at four entries: Workspaces went because
    // the bar's dots are on screen at all times, Notifications became the bell
    // at the right end of the bar, and the last three were folded into one
    // view. See the header of modules/island/Dashboard.qml.
    //
    // An `openDashboard(tab)` went before them, for the same reason in
    // miniature: it had exactly one caller -- the do-not-disturb badge, which
    // meant "here is what you missed" and not "here is the dashboard" -- and
    // once its destination was a bar widget there was nowhere specific left to
    // be sent. Everything that opens this panel now opens the whole of it.

    // Putting the dashboard away, from anywhere and whichever bar is showing
    // it: one string set to "" is every copy there can be.
    //
    // It exists because of slurp. The dashboard is open behind a Hyprland
    // FOCUS GRAB, and while that grab is held nothing else can take a click --
    // so a selection tool launched from a button inside it appears and then
    // cannot be used. Whatever starts a screen selection has to get the panel
    // out of the way first.
    function closeDashboard(): void {
        root.dashboardScreen = "";
    }

    IpcHandler {
        target: "island"

        function dashboard(): void {
            root.toggleDashboard();
        }

        // `notifications` was here, opening the dashboard on its second tab.
        // The history is its own widget now and answers on its own target --
        // see the IpcHandler in modules/notifications/NotificationState.qml.
    }

    // A saved replay clip. It is an ACKNOWLEDGEMENT and not a rung: the clip
    // is already written by the time this is called, so there is nothing to
    // control and nothing to keep watching -- only the fact that pressing the
    // key did something, which is exactly what this rung of the ladder is for.
    function flashReplay(): void {
        root.ack = "replay";
        expiry.restart();
    }

    // The mute going on or off. It carries NO payload, unlike the two below:
    // whether do not disturb is on is NotificationState's to say and it says
    // it on every frame, so a copy taken at the moment of the flash would be a
    // second answer that could only ever be the same one or wrong. `ack` says
    // WHICH acknowledgement is up; the row in Island.qml reads the state
    // itself. That is also why there is no `flashDnd(on)` -- a caller that had
    // to be told the new value would be a caller that could get it wrong.
    //
    // WHY IT EXISTS AT ALL: the mute has four doors -- the bell's right click,
    // the switch in the notification panel, SUPER + N, and the `dnd` IPC
    // target -- and two of them change a global mode with nothing on screen
    // moving where the pointer or the eye happens to be. The bell's own header
    // has the long version.
    function flashDnd(): void {
        root.ack = "dnd";
        expiry.restart();
    }

    function flashVolume(value: int, muted: bool): void {
        root.ackValue = value;
        root.ackMuted = muted;
        root.ack = "volume";
        // restart() and not start(): turning the wheel five notches should
        // leave the island up for two seconds after the LAST notch, not after
        // the first.
        expiry.restart();
    }

    // The backlight, and the second occupant of this rung -- the header of
    // this file named it as one before it existed. It is the same mechanism as
    // the volume with a different glyph, which is what `ack` is a string for.
    //
    // NO MUTED FLAG, and the one line that clears it is the whole difference
    // between the two. A backlight has no off: the floor is five percent
    // because zero is a black screen with nothing lit to find the keys by. So
    // `ackMuted` is reset rather than passed, or a brightness acknowledgement
    // raised while the speakers happen to be muted would draw itself in the
    // outline colour and read "off" -- one payload shared by every kind on
    // this rung is what makes that possible, and clearing what does not apply
    // is the price of it.
    function flashBrightness(value: int): void {
        root.ackValue = value;
        root.ackMuted = false;
        root.ack = "brightness";
        // restart(), for the reason above it: holding the key down should
        // leave the island up for two seconds after the last repeat.
        expiry.restart();
    }

    Timer {
        id: expiry

        interval: root.ackDuration
        onTriggered: root.ack = ""
    }
}
