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
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"
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

    // ---------------- The screen being kept ----------------
    //
    // A CHOICE, and it did not used to be one. This was `Screens.mainName` --
    // "whatever screen the shell is on" -- and the failure that made it a
    // setting is worth writing down, because nothing about it looked broken:
    // the recorder resolves the connector ONCE, in reaper.onExited, and keeps
    // the process it built from it. A buffer that came up when only the second
    // monitor had been announced went on recording the second monitor for as
    // long as the shell lived, and the only place that fact existed was the
    // command line of a background process. Every clip saved was of the wrong
    // screen, and the dashboard said "Instant replay" the whole time.
    //
    // So two things changed. The answer is now visible -- the dashboard names
    // the screen next to the switch -- and it can be given by hand rather than
    // only inferred. And the resolution is live: `monitor` is a binding, and
    // onMonitorChanged below restarts the recorder when it moves.
    //
    // STORED AS A screenKey AND NOT AS A CONNECTOR, for the reason the monitor
    // section of Config.qml gives at length: "DP-3" is assigned by the kernel
    // and the move from linux-lts to mainline renamed both outputs on this
    // machine once already. The connector is only ever resolved, never
    // written down -- and it is resolved because gpu-screen-recorder's -w is
    // one of the things that wants it.
    //
    // NOTHING CHOSEN IS NOT ONE OF THE ANSWERS. The dashboard offers monitors
    // and only monitors -- see the note on it -- so an empty setting is a
    // machine that has not been asked yet rather than one that asked for
    // "automatic". It still has to record something, and the something is the
    // shell's own screen: what this did before it was a choice, and what a
    // fresh clone and a single-monitor machine both want without a click.
    readonly property var screen: {
        if (!Config.replayMonitor)
            return Screens.main;

        for (const candidate of Screens.all)
            if (Config.screenKey(candidate) === Config.replayMonitor)
                return candidate;

        // A CHOSEN MONITOR THAT IS NOT PLUGGED IN falls back to the main one,
        // the same way Screens.qml falls back for the shell's own screen and
        // for the same reason: a buffer that disarms itself because a monitor
        // is off is a buffer that is not there the one time it matters. The
        // setting stays put, so plugging the screen back in puts the buffer
        // back on it. It is not silent either -- monitorMissing is what the
        // dashboard draws to say the recording is not where it was asked to be.
        return Screens.main;
    }

    readonly property string monitor: root.screen?.name ?? ""

    readonly property bool monitorMissing: Config.replayMonitor !== ""
        && Config.screenKey(root.screen) !== Config.replayMonitor

    function setMonitor(key: string): void {
        Config.replayMonitor = key;
    }

    // The monitor is a command-line flag, exactly like the buffer length, so it
    // cannot change under a running recorder -- the process has to come back.
    // Same path setSeconds uses and the same honest cost: the seconds it was
    // holding are gone.
    onMonitorChanged: {
        if (root.armed) {
            root.rearm = true;
            root.disarm();
            return;
        }

        // NOT ARMED, and this is the case that used to leave the buffer dead
        // rather than merely misdirected. arm() runs at startup, and at startup
        // the compositor may not have announced a single output yet: gsr given
        // an empty -w exits at once, three of those inside ten seconds trips
        // the failure counter, and the buffer gives up on a monitor that was
        // about to appear. So arm() refuses to start without a screen and this
        // starts it as soon as there is one -- unless it was switched off on
        // purpose, which is what `wanted` remembers.
        if (root.wanted)
            root.arm();
    }

    // The system's own sound and the microphone, MERGED INTO ONE TRACK. Passing
    // -a twice would give a file with two separate audio tracks, and most
    // players -- and everything you would send a clip to -- play only the
    // first, so half the sound would go missing on the way out.
    //
    // default_output rather than a device name, so it follows the default sink
    // when the headset connects and disconnects.
    //
    // THE MICROPHONE IS A PREFERENCE, NOT A REQUIREMENT. "default input" is
    // whichever of the three inputs here the system last felt like, so the one
    // worth recording is named -- but a named device that is not present makes
    // gpu-screen-recorder refuse to start at all, and the buffer would be
    // silently disarmed on any machine without that exact microphone. So the
    // name is looked up first and default_input stands in when it is missing.
    readonly property string preferredMicrophone: "alsa_input.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00.mono-fallback"

    // Subscribing is what populates the model: Pipewire objects are bound
    // lazily, and a node list nothing has asked for stays empty.
    readonly property int nodeCount: Pipewire.nodes.values.length

    readonly property string microphone: {
        // Referenced so the binding re-evaluates when a device appears or goes
        // away, not only at startup.
        root.nodeCount;

        for (const node of Pipewire.nodes.values)
            if (node.name === root.preferredMicrophone)
                return root.preferredMicrophone;

        return "default_input";
    }

    property string lastClip: ""

    // Whether the buffer is MEANT to be running, which is not the same as
    // whether it is. It is the switch on the dashboard remembered across the
    // moments when there is no process to read the answer off: between a
    // restart and the one after it, and before there is a screen to record at
    // all. Armed is the resting state, so it starts true.
    property bool wanted: true

    function arm(): void {
        root.wanted = true;

        if (root.armed)
            return;

        // Nothing to point it at yet. See onMonitorChanged, which is what
        // starts the buffer when a screen finally shows up.
        if (root.monitor === "")
            return;

        // Through the reaper, never directly: see the header.
        reaper.running = true;
    }

    function disarm(): void {
        // Set even when there is no process to stop, because this is the
        // answer to "should there be one" and the two callers that are only
        // restarting -- setSeconds and onMonitorChanged -- put it straight
        // back through arm().
        root.wanted = false;

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
                // Not every GPU can encode. Navi 24 -- the RX 6400 and 6500 XT
                // -- ships with no video encoder AT ALL: AMD dropped the VCN
                // encode block because the chip was meant for laptops paired
                // with an APU that has its own. gsr is a hardware recorder, so
                // there it refused to start at all, three times, and the buffer
                // disarmed itself with "keeps failing to start".
                //
                // This changes nothing where an encoder exists -- NVENC is
                // still used here -- and rescues the machines where it does
                // not. The cost on those is real and worth knowing: encoding
                // 1080p60 CBR in software, permanently, because the buffer is
                // armed from boot. -f and -q are the knobs to turn there.
                "-fallback-cpu-encoding", "yes",
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
            // Asked for by setSeconds or by the monitor changing: straight back
            // up with the new flag.
            if (root.rearm) {
                root.rearm = false;
                // The stop was deliberate and it has now happened; leaving this
                // standing would make the NEXT death look like one that was
                // asked for, and the recorder would not come back from it.
                root.stopping = false;
                // NOT arm() FROM HERE, and this is the whole reason a length
                // change used to leave the buffer switched off: `armed` is
                // replay.running, and inside this handler the process is still
                // marked as running -- so arm() saw a live recorder and did
                // nothing at all. A timer gets the call out of the exit
                // handler and into a turn where the answer is true.
                restart.restart();
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

            // `wanted` is deliberately left standing here. Giving up is about
            // this recorder, on this screen, right now -- and the likeliest
            // reason for three deaths in a row is the monitor it was pointed
            // at, so a screen appearing or the choice changing gets one more
            // go rather than nothing at all. See onMonitorChanged.
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

    // The way back from a deliberate restart, and it is separate from `revive`
    // only in how long it waits. Two seconds is the right pause before chasing
    // a recorder that died on its own -- whatever killed it may still be
    // happening -- and it is two seconds of no buffer after a click that was
    // meant to change one setting. This is as short as it can be: the point is
    // to leave the exit handler, not to wait for anything.
    Timer {
        id: restart

        interval: 1
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
