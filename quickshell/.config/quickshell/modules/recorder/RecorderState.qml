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
// protocol: no geometry, no recording, no notification. What it DOES print is
// on stderr and in slurp's own words -- "selection cancelled" -- which is how
// this file now tells a cancel apart from a slurp that is not installed. See
// the selector's onExited.
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
import "root:/"

Singleton {
    id: root

    // Recording means wf-recorder is running. Not "the user asked for a
    // recording", and specifically not "slurp is waiting for a drag".
    readonly property bool recording: recorder.running

    readonly property bool selecting: selector.running

    // Where the files land, and under the name they are most useful with:
    // sorted by name is sorted by time. Empty in the config means the
    // directory recordings have always gone to.
    readonly property string directory: Config.recordingDirectory
        || `${Quickshell.env("HOME")}/Videos/recordings`

    // TWO OF THE RECORDING SETTINGS REACH THIS PROGRAM, AND ONLY TWO. The
    // recording page owns a container, a framerate, a codec, a bitrate mode, a
    // bitrate and two audio switches; wf-recorder can honestly be given the
    // first of those and half of the last, and the rest belong to
    // gpu-screen-recorder alone. The page says so beside the controls rather
    // than leaving somebody to find out from a file.
    //
    //   CONTAINER   -f names the file and the muxer follows its extension, so
    //               mp4 or mkv is the same decision here as it is for a replay
    //               clip -- and it is a real one: DaVinci Resolve on Linux
    //               refuses MKV outright.
    //   DESKTOP     -a takes ONE device. "The computer's sound" is the default
    //   AUDIO       sink's monitor and that is what it gets; off means no -a at
    //               all, which is a silent recording rather than a broken one.
    //
    //   MICROPHONE  Not offered here, because -a cannot merge two sources the
    //               way gsr's `default_output|device:NAME` does; a second -a
    //               would give a file with two tracks, of which most players
    //               play the first.
    //   FRAMERATE   wf-recorder's -r forces CONSTANT frame rate, which is a
    //               different recording rather than the same one at a chosen
    //               rate. Left alone, it follows the screen.
    //   CODEC       The names it wants are ffmpeg's -- libx264, h264_vaapi --
    //   AND         and not the ones `gpu-screen-recorder --info` prints.
    //   BITRATE     Translating between them would be a layer able to produce a
    //               recorder that refuses to start for a reason neither program
    //               ever said.

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
        // This is why `window` was the one target that ever worked: it is fed
        // by a pipe that closes, so it got its EOF for free.
        let command = "";
        let boxes = [];

        switch (target) {
        case "region":
            command = `exec slurp < /dev/null`;
            break;

        case "window":
            // SNAPPING NEEDS BOXES, AND NOT EVERY COMPOSITOR HAS THEM.
            //
            // Given a list of rectangles, slurp snaps the selection to whichever
            // one is under the pointer, so picking a window is a click. Given
            // nothing, it is still slurp: the same drag as region mode, just
            // without the help. That is the honest fallback rather than a mode
            // that refuses to run.
            //
            // Hyprland reports .at and .size for every client. niri does not --
            // its Window carries sizes but `tile_pos_in_workspace_view` is null
            // even for windows plainly on screen, measured across six of them,
            // and a size with no position is not a rectangle.
            //
            // WHERE THE RECTANGLES COME FROM IS NOT THIS FILE'S BUSINESS, and
            // it used to be: this branch ran `hyprctl monitors -j`, a jq
            // program and `hyprctl clients -j` in a pipeline built here, under
            // a `Compositor.can("windowGeometry")` guard -- asking the facade
            // whether the feature existed and then going around it to use the
            // feature. The capability has a method behind it now, so the test
            // and the answer come from the same place. The `can()` check is
            // gone with the pipeline: an empty list IS the answer for a
            // compositor that cannot do this, and it falls through to the same
            // free-hand slurp the guard used to select.
            boxes = Compositor.windowBoxes();
            command = boxes.length > 0 ? `printf '%s\\n' "$@" | slurp -r`
                : `exec slurp < /dev/null`;
            break;

        default:
            command = `exec slurp -o < /dev/null`;
        }

        // THE BOXES GO IN AS ARGUMENTS, for the reason the geometry does in
        // record() below: "1102,310 1251x1348" is one value with a space in
        // it, and anything that pastes it into the script has the shell split
        // it into three words. `printf` writes them and closes the pipe, which
        // is where this slurp gets its EOF. The extra arguments are harmless
        // in the branches that ignore them, so there is one call site rather
        // than three.
        selector.command = ["sh", "-c", command, "slurp", ...boxes];
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

        // Ask the compositor for fresh window positions while the panel is
        // getting out of the way. The answer comes back over IPC and this call
        // cannot wait for it -- which is exactly what the 150 ms below is: a
        // delay that already exists, doing a second job for free. If it has
        // not landed by then the boxes are one event stale, which costs a
        // rectangle that snaps to where a window was a moment ago; the
        // selection is on screen before it is committed, so that is visible
        // rather than silent.
        if (target === "window")
            Compositor.refreshWindows();

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

    // Selection. Its stdout is the geometry; a selection that produced none is
    // where the two answers this file used to confuse each other live.
    //
    // A CANCEL AND A MISSING slurp BOTH PRINT NOTHING ON stdout, and for a
    // long time that was the end of it: pressing Escape and never having
    // installed slurp were the same event, so a machine without it had a
    // keybinding that did nothing at all, silently, forever. They are not the
    // same on stderr. slurp says "selection cancelled" in those words -- it is
    // in the binary, `strings /usr/bin/slurp` -- and a shell that cannot find
    // it says so instead, with 127.
    //
    // So stderr is collected and read at exit. THE ORDER IS NOT ASSUMED: a
    // throwaway Quickshell probe running `echo out; echo err >&2; exit 3` was
    // watched printing stdout-finished, then stderr-finished, then exited, so
    // both collectors have their text by the time this handler runs. The
    // geometry is still acted on in onStreamFinished rather than here, so the
    // path that works today does not depend on that ordering at all -- only
    // the wording of a failure does, and an empty stderr degrades to the exit
    // code rather than to nothing.
    Process {
        id: selector

        stdout: StdioCollector {
            id: selectorOut

            onStreamFinished: {
                const geometry = text.trim();
                if (geometry !== "")
                    root.record(geometry);
            }
        }

        stderr: StdioCollector {
            id: selectorErr
        }

        onExited: exitCode => {
            // A selection happened; the recorder has it.
            if (selectorOut.text.trim() !== "")
                return;

            const reason = selectorErr.text.trim();

            // The cancellation protocol, unchanged: no geometry, no recording,
            // NO NOTIFICATION. Escape is an answer, and a desktop that pops up
            // a message every time somebody changes their mind is one people
            // stop reading messages from.
            if (reason.includes("cancelled") || reason.includes("canceled"))
                return;

            // Anything else is a selector that could not run, which is worth
            // exactly one line. The last line of stderr rather than all of it:
            // sh prefixes its own "line 1:" noise and the useful part is at the
            // end.
            const detail = reason === "" ? `slurp exited with ${exitCode}`
                : reason.split("\n").pop().trim();

            Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
                "-i", "camera-video", "Nothing was selected", detail]);
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
        root.lastPath = `${root.directory}/${stamp}.${Config.recordingContainer}`;

        // TWO SCRIPTS AND NOT ONE WITH A CONDITIONAL, because the audio switch
        // decides whether a flag EXISTS rather than what is in it:
        // `--audio=""` is not "no audio", it is a device with no name.
        const script = Config.recordingDesktopAudio
            ? `mkdir -p "$1" || exit 1; ` +
              `AUDIO="$(pactl get-default-sink).monitor"; ` +
              `exec wf-recorder -g "$2" --audio="$AUDIO" -f "$3"`
            : `mkdir -p "$1" || exit 1; ` +
              `exec wf-recorder -g "$2" -f "$3"`;

        recorder.command = ["sh", "-c", script,
            "record", root.directory, geometry, root.lastPath];
        recorder.running = true;
    }

    Process {
        id: recorder

        // WHY IT FAILED AND NOT ONLY THAT IT DID. "wf-recorder exited with 1"
        // is the same sentence for a codec the machine cannot encode, a
        // directory that could not be created and a program that is not
        // installed, and the one that matters is the first: the settings page
        // can offer a container, and a container the muxer refuses has to say
        // so here or the page is a set of switches with no consequence anybody
        // can see.
        stderr: StdioCollector {
            id: recorderErr
        }

        onExited: exitCode => {
            // 0 is what wf-recorder exits with after finalising on SIGINT, so
            // this is the success case and not a special one. Anything else is
            // a recording that did not happen, and saying nothing about it
            // would leave a button that silently does nothing.
            if (exitCode === 0) {
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-i", "camera-video",
                    "Recording saved", root.lastPath.split("/").pop()]);
                return;
            }

            // The LAST line, because wf-recorder narrates what it is doing on
            // the way up and the complaint is what it says on the way out.
            const reason = recorderErr.text.trim();
            const detail = reason === "" ? `wf-recorder exited with ${exitCode}`
                : reason.split("\n").pop().trim();

            Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
                "-i", "camera-video", "Recording failed", detail]);
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
