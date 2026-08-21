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
// keeps capturing forever. Every start therefore begins by stopping the
// recorder this shell left behind -- with SIGINT, so a stray never writes a
// file nobody asked for.
//
// BY A PID THIS SHELL WROTE DOWN, AND NEVER BY NAME. That reaper used to be
// `pkill -INT -f "(^|/)gpu-screen-recorder "`, with a paragraph explaining how
// the pattern had been tuned -- which is the tell: a kill that needs a tuned
// pattern is a kill aimed at whatever matches it. The standing rule on this
// desktop is that processes are ended by a pid somebody recorded, and it was
// written after `pkill -x kitty` closed every terminal on the machine at once.
// The pid goes to a file in the state directory when the recorder starts,
// because the fact that has to survive the shell is precisely which process it
// started; the file is read back synchronously at launch and the pid is
// checked against /proc before anything is signalled.
//
// The difference is not only tidiness. The pattern killed EVERY
// gpu-screen-recorder on the machine, including one started by hand from a
// terminal to record something else; this ends the one that is this shell's
// and leaves everything else alone.

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
        root.reapply();
    }

    // PUT THE NEW FLAG ON THE RECORDER. Everything gpu-screen-recorder is told
    // is a command-line argument, so none of it can change under a running
    // process: the length, the screen, the microphone and every codec the
    // settings page offers exist only on the NEXT one. So changing any of them
    // takes the recorder down and brings it back, and the seconds it was
    // holding are gone.
    //
    // That is the honest cost of changing a setting here, and the alternative
    // -- waiting until the buffer is next switched off -- would be a settings
    // page whose controls appear to do nothing. Not armed means there is
    // nothing to reapply: the next arm() builds the command line from whatever
    // the settings say then.
    function reapply(): void {
        if (!root.armed)
            return;

        root.rearm = true;
        root.disarm();
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
            root.reapply();
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

    // THE ANSWER ABOVE IS LIVE AND THE RECORDER'S COPY OF IT WAS NOT. This is
    // the same fault the monitor had, in the same file, and it survived the fix
    // to that one because the two were never read side by side: `monitor` got
    // an onMonitorChanged and thirty lines saying why a buffer that resolves a
    // flag once and keeps the process built from it is a buffer recording the
    // wrong thing -- and `microphone`, resolved exactly once for exactly the
    // same reason, got nothing.
    //
    // What it looked like from the desk: the buffer is armed at boot, before
    // PipeWire has announced the USB microphone, so it comes up with
    // default_input; the microphone appears a second later, this binding
    // notices and nothing else does. Every clip saved for the rest of the
    // session has whatever the system felt like as its input, and the setting
    // that names the right device is sitting there looking correct. With a
    // picker on the settings page it stops being an inconvenience: choosing a
    // microphone would visibly do nothing until something else happened to
    // restart the buffer.
    //
    // DEBOUNCED, WHICH THE MONITOR IS NOT. PipeWire announces its nodes over
    // several turns as the graph is built, so this binding settles through two
    // or three answers at startup rather than one, and a restart per answer is
    // a buffer that spends its first seconds being torn down. Half a second is
    // long enough to cover the enumeration and short enough that a device
    // plugged in by hand is in the recording before the reason for plugging it
    // in has happened.
    onMicrophoneChanged: micSettled.restart()

    Timer {
        id: micSettled

        interval: 500
        onTriggered: root.reapply()
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
    Component.onCompleted: {
        // FOR THE SIDE EFFECT, and it is the whole reason the pid survives a
        // restart: this is what makes the FileView above load, synchronously,
        // before the reaper's command line is built from what is in it. The
        // string it returns is of no interest -- the JsonAdapter is what was
        // wanted, and it is populated by the time this returns. See the note
        // on processFile.
        processFile.text();

        root.arm();
    }

    // ---------------- The pid, kept across the shell's own life ----------------
    //
    // ONE NUMBER ON DISK, and it is there for exactly one moment: the instant
    // after this shell has been restarted and before it starts a recorder of
    // its own, when the only thing that knows which process is still capturing
    // is a file. Everything else about the recorder is in this singleton
    // already.
    //
    // blockLoading, WHICH IS THE ONLY BLOCKING READ IN THIS SHELL. arm() runs
    // from Component.onCompleted, and an asynchronous read would land after
    // it: the reap would go out with pid 0, the orphan would survive, and the
    // two recorders would fight over the encoder. It is one short file in the
    // state directory, read once at startup.
    //
    // AND blockLoading ON ITS OWN DOES NOT DO IT, which was measured rather
    // than trusted. A probe with exactly this FileView, a file already on
    // disk holding a pid, and a read of the adapter property from
    // Component.onCompleted printed 0 -- then 12345 four hundred
    // milliseconds later. The flag says HOW to load, not WHEN: nothing had
    // asked the FileView for anything yet, so nothing had loaded. Calling
    // text() is what forces it, and onLoaded fires inside that call. See
    // Component.onCompleted below, which does exactly that and throws the
    // string away.
    //
    // 0 IS "NOBODY", the same way an empty screenKey is in Config: the file
    // absent, the recorder stopped cleanly, or a shell that has never armed
    // one.
    FileView {
        id: processFile

        path: Quickshell.statePath("replay-process.json")
        blockLoading: true
        printErrors: false

        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: lastProcess

            property int pid: 0
        }
    }

    Process {
        id: reaper

        // KILL BY THE PID, AND ONLY AFTER ASKING /proc WHAT IT IS. A pid is
        // reused, and the one written down before a reboot may well belong to
        // something else by now -- so the name is checked first, and this is
        // the ONE place a name is allowed to appear, because it is being used
        // to decide NOT to kill.
        //
        // "gpu-screen-reco" and not the whole name: the kernel truncates comm
        // at 15 characters and gpu-screen-recorder is 21. Measured rather than
        // counted -- a copy of /usr/bin/sleep renamed gpu-screen-recorder was
        // run and its /proc/<pid>/comm read back as exactly that string.
        //
        // A shell and not a bare `kill`, because the check and the signal have
        // to happen together; there is no way to read /proc from QML without
        // asking a FileView for a path that only exists sometimes.
        command: ["sh", "-c",
            `pid=$1; ` +
            `[ "$pid" -gt 0 ] 2>/dev/null || exit 0; ` +
            `[ "$(cat /proc/$pid/comm 2>/dev/null)" = "gpu-screen-reco" ] || exit 0; ` +
            `kill -INT "$pid"`,
            "reap", `${lastProcess.pid}`]

        // Whether it signalled anything or found nothing is equally fine;
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

        // The pid goes down as soon as there is one, not when the shell is on
        // its way out: a shell that is killed does not get to run anything, and
        // that is the case the file exists for.
        onStarted: lastProcess.pid = replay.processId ?? 0

        onExited: {
            // This recorder is gone, whatever ended it, so the number stops
            // naming it. Left standing it would name whichever process the
            // kernel handed the pid to next -- and the /proc check in the
            // reaper is the second line of defence, not the first.
            lastProcess.pid = 0;

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
                // WITH THE REASON, because without it this notification is a
                // dead end. "gpu-screen-recorder keeps failing to start" was
                // true of a monitor that had gone away, of a GPU with no
                // encoder, and of a codec this card cannot do -- and the last
                // of those is now something a settings page can put in front
                // of somebody, so the message has to be able to say that the
                // codec is why nothing is being kept.
                //
                // The LAST line of stderr: gsr narrates its startup there and
                // the complaint is what it says on the way out.
                const reason = replayErr.text.trim();
                const detail = reason === "" ? "gpu-screen-recorder keeps failing to start"
                    : reason.split("\n").pop().trim();

                Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical",
                    "-i", "camera-video", "Instant replay stopped", detail]);
                return;
            }

            revive.restart();
        }

        // WHY IT DIED, kept for the notification above. A StdioCollector and
        // not a SplitParser: only the end of it is ever read, and there is no
        // reason to walk into QML once per line for a stream nothing watches
        // while things are going well.
        stderr: StdioCollector {
            id: replayErr
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
