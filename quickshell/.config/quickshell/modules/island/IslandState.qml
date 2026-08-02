// What the island is currently about, and who gets to say so.
//
// THE ONE RULE: the island shows ONE thing. The moment it shows two, it stops
// being an island and becomes another row of the bar -- which is the thing the
// centre of the bar was cleared out to avoid. So there is an arbiter, and this
// is it.
//
// THE LADDER, highest first:
//
//   1. Acknowledgement  volume, and whatever joins it later (brightness, mic
//                       mute, capture taken). These are answers to something
//                       the user JUST did: they appear, they confirm, and they
//                       get out of the way after `ackDuration`. This is the
//                       whole reason Volume no longer has a permanent seat on
//                       the right of the bar -- a number that matters for two
//                       seconds does not deserve one.
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
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---------------- Dashboard ----------------
    //
    // Which tab the dashboard was last on. It lives HERE and not in
    // Dashboard.qml because the popout destroys its content when it closes --
    // that is what keeps a popout from carrying stale state between openings,
    // and it is also why the tab kept snapping back to Dashboard. The state
    // has to outlive the thing that displays it.
    //
    // Session-scoped, not written to disk: it survives closing and reopening
    // the dashboard, not restarting the shell.
    property int dashboardTab: 0

    // ---------------- Level 2: screen capture ----------------
    //
    // Hyprland announces this on its event socket, so there is nothing to
    // poll and no portal to talk to:
    //
    //   screencast>>1,monitor            started
    //   screencastv2>>1,monitor,DP-3     started, and what is being taken
    //   screencastv2>>0,monitor,DP-3     stopped
    //
    // v2 is used for the target name; v1 carries the same state without it,
    // so listening to both would double-count.
    //
    // Verified by listening on .socket2.sock while capturing -- the events
    // above are copied from that capture, not from documentation.

    // A COUNT and not a bool. Two applications can hold a capture at once
    // (a call sharing a window while OBS records the screen), and with a bool
    // whichever stops first would clear the indicator while the other is
    // still going.
    property int captureSessions: 0

    // "monitor" or "window", and which one.
    property string captureOwner: ""
    property string captureTarget: ""

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

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name !== "screencastv2")
                return;

            // state, owner, name
            const args = event.parse(3);
            if (args[0] === "1") {
                root.captureOwner = args[1] ?? "";
                root.captureTarget = args[2] ?? "";
                root.captureSessions += 1;
                if (root.captureSessions === 1)
                    captureGraceTimer.restart();
            } else {
                // Clamped at zero: a session that was already running when the
                // shell started is stopped without ever having been counted.
                root.captureSessions = Math.max(0, root.captureSessions - 1);
                if (root.captureSessions === 0) {
                    captureGraceTimer.stop();
                    root.captureSettled = false;
                }
            }
        }
    }

    // How long an acknowledgement holds the island before it falls back down
    // the ladder. Long enough to read a two-digit number and short enough that
    // nudging the volume wheel repeatedly feels continuous rather than queued.
    readonly property int ackDuration: 2000

    // "" when nothing is being acknowledged. A string rather than a bool
    // because brightness and mic mute are the next two entries and they are
    // the same mechanism with a different glyph.
    property string ack: ""

    // Payload of the current acknowledgement. Deliberately untyped and shared:
    // one acknowledgement is on screen at a time, so one set of fields is
    // enough, and a per-kind object would only add a lookup.
    property int ackValue: 0
    property bool ackMuted: false

    // ---------------- The dashboard ----------------
    // A signal and not a flag. Whether the dashboard is up is not state this
    // singleton owns: the dashboard is CONTENT inside the bar's shared
    // popout, and the popout already knows whether it is open and with what.
    // Mirroring that here would be a second source of truth for one surface,
    // which is the thing the header of this file argues against.
    //
    // So the keybind asks, and Island.qml -- the only place that can see both
    // the popout and the dashboard component -- answers.
    signal dashboardRequested

    function toggleDashboard(): void {
        root.dashboardRequested();
    }

    // Asking for the dashboard to go away, for the same reason as above: the
    // popout that holds it is not this singleton's to close.
    //
    // It exists because of slurp. The dashboard is open behind a Hyprland
    // FOCUS GRAB, and while that grab is held nothing else can take a click --
    // so a selection tool launched from a button inside it appears and then
    // cannot be used. Whatever starts a screen selection has to get the panel
    // out of the way first.
    signal dashboardCloseRequested

    function closeDashboard(): void {
        root.dashboardCloseRequested();
    }

    IpcHandler {
        target: "island"

        function dashboard(): void {
            root.toggleDashboard();
        }
    }

    // A saved replay clip. It is an ACKNOWLEDGEMENT and not a rung: the clip
    // is already written by the time this is called, so there is nothing to
    // control and nothing to keep watching -- only the fact that pressing the
    // key did something, which is exactly what this rung of the ladder is for.
    function flashReplay(): void {
        root.ack = "replay";
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

    Timer {
        id: expiry

        interval: root.ackDuration
        onTriggered: root.ack = ""
    }
}
