// Instant replay: the last 30 seconds, always in hand.
//
// gpu-screen-recorder keeps a rolling buffer in RAM and writes it out only when
// asked, which is the whole feature -- wf-recorder cannot do this at all, since
// it records from the moment it starts to the moment it stops and has no notion
// of "the recent past". gsr is in the official repos, encodes on the GPU
// (NVENC), and is the same program every ShadowPlay-alike on Linux is built on.
// So this file starts it, signals it, and stays out of the way.
//
// EVERYTHING HERE IS A SIGNAL. From its man page, verified against a running
// instance before this file existed:
//
//   SIGUSR1   save the buffer to a file
//   SIGINT    stop -- and in replay mode that means WITHOUT saving
//
// It prints the path of each saved clip on stdout as a bare line, which is
// where the notification below gets the file name from. That was checked by
// saving one and reading the log, not assumed.
//
// ARMED IS THE RESTING STATE. The buffer is worth nothing if it has to be
// switched on before the thing worth keeping happens, so the shell arms it at
// startup and the dashboard is there to turn it OFF, not on.
//
// WHICH IS WHY IT REAPS FIRST. An armed replay is a permanent child process,
// and a permanent child process outlives the shell that started it: killing
// Quickshell reparents it to init, where nothing in this UI can reach it and it
// keeps capturing forever. Every start therefore begins by stopping whatever
// gsr is already running -- with SIGINT, so a stray never writes a file nobody
// asked for.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/modules/island"

Singleton {
    id: root

    readonly property bool armed: replay.running

    readonly property string directory: `${Quickshell.env("HOME")}/Videos/Replays`

    // The buffer, in seconds, and it OUTLIVES THE SHELL. gsr takes it as a
    // command-line flag, so changing it means restarting the recorder -- and a
    // setting that reset itself to thirty every time the shell reloaded would
    // be a setting in name only.
    //
    // It is written to Quickshell's own state directory rather than into the
    // config: the config is a stow tree of symlinks into a git repo, and a file
    // the shell rewrites at runtime does not belong in either.
    readonly property int seconds: config.seconds

    // What the buffer costs, so the choice on screen is not blind. Measured on
    // this machine while armed at 30 s: about 590 MiB resident and a quarter of
    // one core, and the RAM part scales with the duration because that is what
    // the buffer IS.
    readonly property int megabytes: Math.round(root.seconds * 40000 / 8 / 1000)

    readonly property var options: [15, 30, 60, 120]

    function setSeconds(value: int): void {
        if (value === config.seconds)
            return;

        config.seconds = value;

        // The new length only exists on the next process, so an armed buffer
        // is restarted -- and the thirty seconds it was holding are gone. That
        // is the honest cost of changing the setting, and the alternative
        // (waiting until it is next disarmed) would be a setting that appears
        // to do nothing.
        if (root.armed) {
            root.rearm = true;
            root.disarm();
        }
    }

    property bool rearm: false

    FileView {
        id: settings

        path: Quickshell.statePath("replay.json")
        watchChanges: true

        // The first run has no file to read, which is not a fault worth
        // printing: onLoadFailed writes the defaults and the next read finds
        // them.
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        // First run: there is no file yet, so write the defaults rather than
        // complaining about their absence.
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: config

            property int seconds: 30
        }
    }

    // The screen being kept. The 1440p one -- the portrait monitor holds chat
    // and a terminal, and buffering it would spend RAM on nothing worth
    // replaying.
    readonly property string monitor: "DP-3"

    // The system's own sound and the microphone, MERGED INTO ONE TRACK. Passing
    // -a twice would give a file with two separate audio tracks, and most
    // players -- and everything you would send a clip to -- play only the
    // first, so half the sound would go missing on the way out.
    //
    // default_output rather than the device name, so it follows the default
    // sink when the headset connects and disconnects. The microphone IS named,
    // because "default input" is whichever of the three the system last felt
    // like, and this one is the one being asked for.
    readonly property string microphone: "alsa_input.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00.mono-fallback"

    property string lastClip: ""

    function arm(): void {
        if (root.armed)
            return;
        // Through the reaper, never directly: see the header.
        reaper.running = true;
    }

    function disarm(): void {
        if (!root.armed)
            return;

        // Deliberate, so the revival below knows not to undo it.
        root.stopping = true;
        // 2 is SIGINT, which in replay mode stops without writing anything.
        replay.signal(2);
    }

    // Set only by disarm(). Everything else that ends the process -- a crash, a
    // second shell instance reaping it, an stray kill -- is an accident, and an
    // "always on" buffer that stays dead after one is not always on.
    property bool stopping: false

    // Consecutive deaths within ten seconds of starting. Reset by any life
    // longer than that, so an accident an hour in never counts towards it.
    property int failures: 0

    function toggle(): void {
        if (root.armed)
            root.disarm();
        else
            root.arm();
    }

    function save(): void {
        if (!root.armed)
            return;
        // 10 is SIGUSR1.
        replay.signal(10);
    }

    // Arm on startup. The buffer only has to exist before the thing worth
    // keeping does, so there is nothing to wait for.
    Component.onCompleted: root.arm()

    Process {
        id: reaper

        // MATCHED ON THE FULL COMMAND LINE, and the pattern is fussy for two
        // reasons found the hard way. -x cannot be used because the process
        // name is 21 characters and the kernel truncates comm at 15, so an
        // exact-name match finds nothing; and the line does not start with the
        // name either, because it is spawned resolved to /usr/bin. The
        // trailing space is what keeps this from also killing
        // gpu-screen-recorder-gtk and friends.
        command: ["pkill", "-INT", "-f", "(^|/)gpu-screen-recorder "]

        // Whether it killed anything (0) or found nothing (1) is equally fine;
        // either way the field is clear.
        onExited: {
            replay.command = ["gpu-screen-recorder",
                "-w", root.monitor,
                "-f", "60",
                "-c", "mp4",
                "-k", "h264",
                // CBR is what the man page recommends for a replay buffer, and
                // it is also what makes the RAM cost predictable: 40 Mbit/s for
                // 30 s is about 150 MB, whatever is happening on screen.
                "-bm", "cbr",
                "-q", "40000",
                // aac and not the mp4 default of opus: these clips exist to be
                // sent to someone, and opus-in-mp4 is the combination that some
                // players and editors refuse.
                "-ac", "aac",
                "-a", `default_output|device:${root.microphone}`,
                "-r", `${root.seconds}`,
                "-replay-storage", "ram",
                "-o", root.directory];
            replay.running = true;
        }
    }

    Process {
        id: replay

        property real startedAt: 0

        onRunningChanged: {
            if (replay.running)
                replay.startedAt = Date.now();
        }

        onExited: {
            // Asked for by setSeconds: straight back up with the new length.
            if (root.rearm) {
                root.rearm = false;
                root.arm();
                return;
            }

            if (root.stopping) {
                root.stopping = false;
                return;
            }

            // Nobody asked for this, so it comes back. The counter is what
            // keeps that from becoming an infinite loop: a recorder that
            // cannot start at all -- no free GPU encoder, a monitor that is
            // gone -- would otherwise be respawned every two seconds forever.
            //
            // Counted rather than judged by a single timeout, because the
            // length of one life says nothing on its own: three deaths in a
            // row inside ten seconds is a recorder that will not run, while
            // one after an hour is an accident worth undoing.
            if (Date.now() - replay.startedAt > 10000)
                root.failures = 0;
            else
                root.failures += 1;

            if (root.failures >= 3) {
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
                    "-i", "camera-video", "Instant replay stopped",
                    "gpu-screen-recorder keeps failing to start"]);
                return;
            }

            revive.restart();
        }

        stdout: SplitParser {
            onRead: line => {
                // gsr narrates its frame rate on this stream as well, so the
                // path is picked out by shape rather than by position.
                const clip = line.trim();
                if (!clip.startsWith("/") || !clip.endsWith(".mp4"))
                    return;

                root.lastClip = clip;
                IslandState.flashReplay();
                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-i", "camera-video",
                    "Replay saved", clip.split("/").pop()]);
            }
        }
    }

    Timer {
        id: revive

        interval: 2000
        onTriggered: root.arm()
    }

    IpcHandler {
        target: "replay"

        function save(): void {
            root.save();
        }

        function toggle(): void {
            root.toggle();
        }

        function status(): string {
            return root.armed ? "armed" : "off";
        }
    }
}
