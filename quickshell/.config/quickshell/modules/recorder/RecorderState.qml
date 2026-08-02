// Screen recording: whether one is running, and how to start and stop it.
//
// wf-recorder does the encoding. It is the wlroots recorder, it is in the
// official repos, and it takes a region on the command line -- which is what
// makes the three targets below one program rather than three.
//
// TWO PROCESSES, BECAUSE THEY ARE TWO THINGS.
// Picking an area and recording it used to be one shell command, and that one
// command was the cause of three separate bugs: the island showed "Recording"
// while slurp was still on screen waiting to be dragged, pressing Escape
// announced a recording had been saved, and `stop` aimed a signal at a process
// that might still be the shell rather than the recorder. Selection is now its
// own process whose only output is a geometry; the recorder is started only if
// one comes back.
//
// A cancelled selection prints nothing, which is the whole cancellation
// protocol: no geometry, no recording, no notification.
//
// THE INDICATOR IS NOT WIRED UP HERE, AND THAT IS DELIBERATE.
// The island already lights up when anything captures the screen, because it
// listens to Hyprland's `screencast` events on the event socket. wf-recorder
// is a screencast client like any other, so starting one lights the indicator
// on its own. Reporting it from here as well would be a second source of
// truth for one fact -- and it would be the worse one, since it would miss
// OBS and every video call.
//
// STOPPING IS A SIGNAL, NOT A KILL. wf-recorder finalises the container on
// SIGINT; killed outright it leaves an unplayable file. Measured on this
// machine, it exits 0.02 s after the signal with a 4 MB file already written,
// so a stop that appears to hang is not the recorder finishing up.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Recording means wf-recorder is running. Not "the user asked for a
    // recording", and specifically not "slurp is waiting for a drag".
    readonly property bool recording: recorder.running

    readonly property bool selecting: selector.running

    // Where the files land, and under the name they are most useful with:
    // sorted by name is sorted by time.
    readonly property string directory: `${Quickshell.env("HOME")}/Videos/recordings`

    property string lastPath: ""

    // "display" | "window" | "region"
    function start(target: string): void {
        if (root.recording || root.selecting)
            return;

        // All three targets end in the same call with a geometry, so all three
        // pick that geometry with slurp:
        //
        //   display  slurp -o, which snaps to whole outputs -- so it ASKS
        //            which monitor instead of assuming the focused one
        //   region   slurp, free-hand
        //   window   slurp -r fed the geometry of every mapped window on the
        //            visible workspaces, so it snaps to them
        //
        // EVERY slurp GETS ITS stdin CLOSED.
        // slurp reads a list of boxes from standard input, so with stdin left
        // on a pipe that never reaches EOF -- which is exactly what a child of
        // Quickshell inherits -- it blocks in read() before it ever creates a
        // surface. The process is alive, `hyprctl layers` shows nothing on the
        // overlay level, and there is simply no selector on screen to click.
        // This is why `window` was the one target that ever worked: `slurp -r`
        // is fed by a pipe that closes, so it got its EOF for free.
        let command = "";
        switch (target) {
        case "region":
            command = `exec slurp < /dev/null`;
            break;

        case "window":
            // Every window on every VISIBLE workspace, not just the focused
            // monitor's. Filtering by the active workspace meant the other
            // screen's windows were not offered at all -- slurp can only snap
            // to boxes it was given.
            command = `WS=$(hyprctl monitors -j | jq -c '[.[].activeWorkspace.id]'); ` +
                `hyprctl clients -j | jq -r --argjson ws "$WS" ` +
                `'.[] | select((.workspace.id as $id | $ws | index($id)) != null and .mapped and (.hidden | not)) | ` +
                `"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | slurp -r`;
            break;

        default:
            command = `exec slurp -o < /dev/null`;
        }

        selector.command = ["sh", "-c", command];
        selector.running = true;
    }

    // Start after giving the caller's panel time to get out of the way.
    //
    // THE TIMER HAS TO LIVE HERE, not in the button that was pressed. It was
    // in the dashboard's RecordControl first and nothing ever recorded: the
    // button asks the dashboard to close, closing destroys the popout's
    // content, and the component taking the delay went with it before it
    // could fire. A singleton is not destroyed, so the pending request
    // survives the panel that made it.
    property string pendingTarget: ""

    function startDelayed(target: string): void {
        root.pendingTarget = target;
        grabRelease.restart();
    }

    Timer {
        id: grabRelease

        // Long enough for Hyprland to release the focus grab the panel held.
        // Closing is a request to the compositor, not an instantaneous fact,
        // and slurp launched in the same tick comes up unable to take a click.
        interval: 150

        onTriggered: {
            if (root.pendingTarget !== "")
                root.start(root.pendingTarget);
            root.pendingTarget = "";
        }
    }

    function stop(): void {
        if (!root.recording)
            return;

        // 2 is SIGINT. See the header: anything harsher and the file is not
        // finalised. The command below ends in `exec`, so this pid IS
        // wf-recorder and the signal does not have to survive a shell.
        recorder.signal(2);
    }

    function toggle(target: string): void {
        if (root.recording)
            root.stop();
        else
            root.start(target);
    }

    // Selection. Its stdout is the geometry and its exit code is not consulted:
    // a cancelled slurp and a failed one both print nothing, and "nothing" is
    // the only answer that has to be acted on differently.
    Process {
        id: selector

        stdout: StdioCollector {
            onStreamFinished: {
                const geometry = text.trim();
                if (geometry !== "")
                    root.record(geometry);
            }
        }
    }

    // Geometry in hand, record it.
    //
    // The directory, the geometry and the path go in as ARGUMENTS rather than
    // being pasted into the script. A geometry is "1102,310 1251x1348" -- one
    // value with a space in it -- and an earlier version that interpolated it
    // into the command had the shell split it into three words, which is why
    // region recording produced nothing at all.
    //
    // --audio is the default sink's MONITOR source, which is what "record the
    // computer's sound" means: a sink cannot be read from, its monitor can.
    // Resolved at record time rather than stored, because the default sink
    // changes when the headset connects.
    function record(geometry: string): void {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        root.lastPath = `${root.directory}/${stamp}.mp4`;

        recorder.command = ["sh", "-c",
            `mkdir -p "$1" || exit 1; ` +
            `AUDIO="$(pactl get-default-sink).monitor"; ` +
            `exec wf-recorder -g "$2" --audio="$AUDIO" -f "$3"`,
            "record", root.directory, geometry, root.lastPath];
        recorder.running = true;
    }

    Process {
        id: recorder

        onExited: exitCode => {
            // 0 is what wf-recorder exits with after finalising on SIGINT, so
            // this is the success case and not a special one. Anything else is
            // a recording that did not happen, and saying nothing about it
            // would leave a button that silently does nothing.
            if (exitCode === 0) {
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-i", "camera-video",
                    "Recording saved", root.lastPath.split("/").pop()]);
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
                    "-i", "camera-video", "Recording failed", `wf-recorder exited with ${exitCode}`]);
            }
        }
    }

    IpcHandler {
        target: "recorder"

        function display(): void {
            root.toggle("display");
        }

        function window(): void {
            root.toggle("window");
        }

        function region(): void {
            root.toggle("region");
        }

        function stop(): void {
            root.stop();
        }
    }
}
