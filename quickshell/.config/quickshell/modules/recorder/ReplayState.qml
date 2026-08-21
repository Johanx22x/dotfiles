// Instant replay: the last half minute or so, always in hand.
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
// startup and the switch -- on the dashboard, and now on the recording page in
// the settings window -- is there to turn it OFF, not on. That switch is
// remembered: it used to last only as long as the process did, which on a
// config that reloads whenever a .qml file is saved is not a switch at all.
//
// AND NOT ONE OF ITS FLAGS IS WRITTEN HERE ANY MORE. The length, the screen,
// the framerate, the codec, the bitrate, the container, the microphone, where
// clips go and whether the buffer lives in RAM or on disk all come out of
// Config -- see its Recording section, and `command` below, which is the one
// binding they all end up in. What that buys is in the paragraph after next:
// gsr takes every one of them on the command line, so a change means the
// process comes back.
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

    // ---------------- What the recorder is told ----------------
    //
    // ALL OF IT COMES OUT OF Config NOW, and until the recording settings page
    // existed none of it did: the length was in a JSON file of this file's own,
    // the screen was the one setting anybody could change, and everything else
    // -- the framerate, the codec, the bitrate, the container, the microphone,
    // where the clips go -- was a literal on the command line thirty lines
    // below. See the Recording section of Config.qml for what each one means
    // and which of them a manual wf-recorder recording also obeys.

    // Where clips land. Empty means the directory this has always written to.
    readonly property string directory: Config.replayDirectory
        || `${Quickshell.env("HOME")}/Videos/Replays`

    // The buffer, in seconds. 0 in the config means nobody has chosen, and 30
    // is what the buffer has always been.
    readonly property int seconds: Config.replaySeconds > 0 ? Config.replaySeconds : 30

    readonly property var options: [15, 30, 60, 120]

    // What the buffer costs, so the choice on screen is not blind. A buffer is
    // its bitrate times its duration and nothing else -- measured on this
    // machine while armed at 30 s and 40 Mbit/s: about 590 MiB resident and a
    // quarter of one core.
    //
    // ONE ARITHMETIC, TWO READERS. The island shows it under the length chips
    // and the settings page shows it under the same choice, because a length
    // with no price beside it is not a choice anybody can make. It is exported
    // as a STRING rather than as a number for the reason below.
    readonly property int megabytes: Math.round(root.seconds * Config.recordingBitrate / 8 / 1000)

    // CBR IS WHAT MAKES THE NUMBER TRUE. In constant bitrate the size of the
    // buffer does not depend on what is on screen, which is exactly why gsr's
    // man page recommends CBR for a replay buffer; in qp and vbr it does, and
    // there is no honest number to print. So the reading says so instead of
    // quoting an average nobody promised.
    readonly property bool sizeKnown: Config.recordingBitrateMode === "cbr"

    readonly property string cost: root.sizeKnown ? `${root.megabytes} MB` : "size varies"

    // Where the buffer is being kept, in one word, for the page that offers the
    // choice and for anything else that wants to say what the cost is made of.
    readonly property bool inRam: Config.replayStorage !== "disk"

    function setSeconds(value: int): void {
        Config.replaySeconds = value;
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
        root.stop();
    }

    property bool rearm: false

    // ---------------- The length, as it used to be stored ----------------
    //
    // A FILE THIS SHELL NO LONGER WRITES. The buffer length lived in
    // replay.json, next to config.json in the state directory and read through
    // an adapter of this file's own -- which is one store more than the split
    // at the top of Config.qml describes, and the reason for the split does not
    // apply: nothing outside this process ever wanted to know how long the
    // buffer was.
    //
    // Moving it would have quietly reset it, and a machine that had chosen 60
    // seconds finding itself back at 30 after a `git pull` is the exact silent
    // loss a settings page is supposed to end. So the old file is read ONCE, at
    // startup, and its answer is copied over when nobody has chosen in the new
    // one. It is never written again, and deleting it is safe -- an absent file
    // is a machine that never chose, which is what 0 already means.
    //
    // watchChanges is deliberately absent: this is a one-way door, and a file
    // the shell has stopped writing should not be able to move a setting behind
    // the settings page's back.
    FileView {
        id: legacy

        path: Quickshell.statePath("replay.json")
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: legacySeconds

            property int seconds: 0
        }
    }

    // AFTER Config HAS BEEN READ AND NOT BEFORE, which is the whole difficulty
    // of a migration between two asynchronous files. Asked earlier,
    // Config.replaySeconds reads its default of 0 -- "nobody has chosen" --
    // whatever is actually on disk, so a machine that HAS chosen would be
    // handed the old file's answer and then have it overwritten by the real one
    // a moment later. Config.loaded is the flag that makes the order knowable.
    function adoptLegacyLength(): void {
        if (!Config.loaded || Config.replaySeconds > 0)
            return;

        // For the side effect: this is what makes the FileView above load. See
        // the note on processFile -- blockLoading says how, not when.
        legacy.text();

        if (legacySeconds.seconds > 0)
            Config.replaySeconds = legacySeconds.seconds;
    }

    // Both ends of the race, because either can happen first: the config file
    // may already have been read by the time this singleton is built, and it
    // may not.
    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.adoptLegacyLength();
            root.arm();
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
    // THE MICROPHONE IS A PREFERENCE, NOT A REQUIREMENT, and this is the rule
    // the picker on the settings page had to be built around rather than
    // around a list of what is plugged in. "Default input" is whichever of the
    // six inputs on this machine the system last felt like, so the one worth
    // recording is named -- but a named device that is not present makes
    // gpu-screen-recorder REFUSE TO START AT ALL, and the buffer would be
    // silently disarmed on any machine without that exact microphone. So the
    // name is looked up in the live node list first and the system default
    // stands in when it is missing.
    //
    // IT USED TO BE ONE NAME, WRITTEN HERE. A particular NZXT USB mic, on a
    // machine with six inputs -- correct here, and on anybody else's machine a
    // preference that could never resolve and therefore a setting that did
    // nothing at all. The name now comes from the config and empty means "the
    // system default", which is a real answer somebody can pick rather than a
    // gap.
    readonly property string preferredMicrophone: Config.recordingMicrophoneDevice

    // Subscribing is what populates the model: Pipewire objects are bound
    // lazily, and a node list nothing has asked for stays empty.
    readonly property int nodeCount: Pipewire.nodes.values.length

    // What actually goes on the command line, already in gsr's spelling -- one
    // of its two source formats and never a guess between them:
    //
    //   default_input   the system's own choice, followed as it changes
    //   device:NAME     a particular PipeWire node
    //
    // THE SPELLING MATTERS AND WAS GOT WRONG BEFORE. This used to be built as
    // `device:${microphone}` with `default_input` as the fallback value, which
    // produces `device:default_input` -- a device NAME made out of the word
    // that means "no name". `gpu-screen-recorder --list-audio-devices` prints
    // default_input as an entry of its own, so it may well resolve; the man
    // page lists the two forms separately and nothing promises the mixture, so
    // the documented spelling is what is sent. It is not a difference anybody
    // could have seen from the desk: the fallback only happens on a machine
    // where the chosen microphone is absent.
    readonly property string microphone: {
        // Referenced so the binding re-evaluates when a device appears or goes
        // away, not only at startup.
        root.nodeCount;

        if (root.preferredMicrophone === "")
            return "default_input";

        for (const node of Pipewire.nodes.values)
            if (node.name === root.preferredMicrophone)
                return `device:${root.preferredMicrophone}`;

        return "default_input";
    }

    // Is the chosen microphone actually here? Not used to decide anything --
    // the fallback above is the decision -- but the settings page marks the
    // choice with it, the same way the monitor list marks a screen that is not
    // plugged in. A preference that is quietly not in force is exactly what
    // this file spent a paragraph explaining, and now there is somewhere to
    // say it.
    readonly property bool microphoneMissing: {
        root.nodeCount;

        return root.preferredMicrophone !== "" && root.microphone === "default_input";
    }

    // WHAT gsr IS TOLD TO RECORD, as one source string. Both halves merged with
    // `|` and never two -a flags: two flags give a file with two audio tracks
    // and most players -- and everything you would send a clip to -- play only
    // the first, so half the sound would go missing on the way out.
    //
    // Empty means neither was asked for, and then no -a reaches the command
    // line at all. A silent clip is a choice somebody made here; an -a with
    // nothing after it is a recorder that will not start.
    readonly property string audioSources: {
        const parts = [];

        if (Config.recordingDesktopAudio)
            parts.push("default_output");

        if (Config.recordingMicrophone)
            parts.push(root.microphone);

        return parts.join("|");
    }

    // THE ANSWER ABOVE IS LIVE AND THE RECORDER'S COPY OF IT WAS NOT, until
    // the command line below became a binding. It is worth leaving on the
    // record next to the value it went wrong on, because it hid in this file
    // for as long as it did by looking like it was handled: `monitor` had an
    // onMonitorChanged and thirty lines saying why a recorder that resolves a
    // flag once and keeps the process built from it is a recorder capturing
    // the wrong thing -- and `microphone`, resolved exactly once for exactly
    // the same reason, had no handler at all.
    //
    // From the desk it looked like nothing: the buffer arms at boot, before
    // PipeWire has announced the USB microphone, and comes up with the system
    // default; the microphone appears a second later, this binding notices and
    // nothing else did. Every clip for the rest of the session had whatever the
    // system felt like as its input, while the setting naming the right device
    // sat there looking correct.

    property string lastClip: ""

    // Whether the buffer is MEANT to be running, which is not the same as
    // whether it is. It is the switch on the dashboard held across the moments
    // when there is no process to read the answer off: between a restart and
    // the one after it, and before there is a screen to record at all.
    //
    // A STORED SETTING NOW, AND IT WAS A FACT ABOUT THIS RUN. Armed is still
    // the resting state and the stored default is still true -- see the header
    // -- but switching the buffer off used to last exactly as long as the
    // process did, and this config is reloaded every time a .qml file is
    // saved. A switch that comes back on by itself is not a switch, and the
    // one place it was reachable from said "Instant replay" next to it.
    //
    // DERIVED AND NOT ASSIGNED, which is what makes the settings page and the
    // island the same switch rather than two: both write Config, both read
    // this, and the handler below is the only thing that acts on it. It is
    // also what makes the config file landing late harmless -- the buffer is
    // not armed until it has, and a stored `false` disarms whatever came up in
    // the meantime.
    readonly property bool wanted: Config.replayEnabled

    function setEnabled(on: bool): void {
        Config.replayEnabled = on;
    }

    onWantedChanged: {
        if (root.wanted)
            root.arm();
        else
            root.stop();
    }

    function arm(): void {
        if (!root.wanted || root.armed)
            return;

        // ALREADY ON ITS WAY UP. arm() has four callers -- startup, the config
        // arriving, a screen appearing and the revive timer -- and at login
        // three of them fire within a few turns of each other, measured on a
        // probe that printed this path three times. `armed` does not cover it:
        // the reaper is a separate process and the recorder does not exist yet
        // while it runs, so without this the reap would be asked to start again
        // underneath itself.
        if (reaper.running)
            return;

        // NOT BEFORE THE CONFIG HAS BEEN READ. Every flag this recorder takes
        // comes out of Config, the read is asynchronous, and for the first
        // turns of the shell's life those properties hold their defaults --
        // so arming here would start a recorder at 30 seconds and 40 Mbit/s on
        // a machine that had chosen otherwise, then tear it down and rebuild
        // it a moment later when the file landed. The Connections above bring
        // us straight back here when it has.
        if (!Config.loaded)
            return;

        // Nothing to point it at yet. See onMonitorChanged, which is what
        // starts the buffer when a screen finally shows up.
        if (root.monitor === "")
            return;

        // Through the reaper, never directly: see the header.
        reaper.running = true;
    }

    // STOP THE PROCESS, WITHOUT ANSWERING "SHOULD THERE BE ONE". That question
    // is `wanted` and it lives in the config now, which is the whole reason
    // this is no longer called disarm(): its callers are the switch going off,
    // and reapply(), which is putting the recorder straight back up with a new
    // flag and must not write a false anybody would see.
    function stop(): void {
        if (!root.armed)
            return;

        // Deliberate, so the revival below knows not to undo it.
        root.stopping = true;
        // 2 is SIGINT, which in replay mode stops without writing anything.
        replay.signal(2);
    }

    // Set only by stop(). Everything else that ends the process -- a crash, a
    // second shell instance reaping it, a stray kill -- is an accident, and an
    // "always on" buffer that stays dead after one is not always on.
    property bool stopping: false

    // Consecutive deaths within ten seconds of starting. Reset by any life
    // longer than that, so an accident an hour in never counts towards it.
    property int failures: 0

    function toggle(): void {
        root.setEnabled(!root.wanted);
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

        // The other end of the race with Config's own read: if it has already
        // happened, nothing will tell us again. Both are no-ops when it has
        // not, and the Connections above run them when it does.
        root.adoptLegacyLength();
        root.arm();
    }

    // ---------------- The command line ----------------
    //
    // ONE BINDING HOLDING EVERY FLAG, and it is what turns a settings page into
    // a working one. Each value it reads is a property somebody can change --
    // the screen, the length, the codec, the microphone, where the file goes --
    // and gpu-screen-recorder takes all of them on the command line, so none of
    // them can move under a running process. Because this is a binding, "the
    // settings changed" and "this list changed" are the same event, and there
    // is exactly one handler for it rather than one per setting. The first two
    // of those handlers already existed, for the monitor and the microphone,
    // and were about to become fourteen.
    //
    // WRAPPED IN A SHELL FOR ONE REASON: the directory. It is a setting now, so
    // it can name somewhere that does not exist yet, and a buffer that refuses
    // to arm because a folder is missing would be a page that breaks recording
    // by being used. `exec` is what keeps this honest -- the shell REPLACES
    // itself with gsr, so the pid this file writes down is the recorder's, the
    // SIGINT that saves a clip reaches the recorder, and /proc/<pid>/comm reads
    // gpu-screen-reco. Every value goes in as an ARGUMENT and none is pasted
    // into the script text.
    readonly property var command: {
        const args = ["gpu-screen-recorder",
            "-w", root.monitor,
            "-f", `${Config.recordingFramerate}`,
            "-c", Config.recordingContainer,
            // Not every GPU can encode. Navi 24 -- the RX 6400 and 6500 XT --
            // ships with no video encoder AT ALL: AMD dropped the VCN encode
            // block because the chip was meant for laptops paired with an APU
            // that has its own. gsr is a hardware recorder, so there it refused
            // to start at all, three times, and the buffer disarmed itself with
            // "keeps failing to start".
            //
            // This changes nothing where an encoder exists -- NVENC is still
            // used here -- and rescues the machines where it does not. The cost
            // on those is real and worth knowing: encoding 1080p60 CBR in
            // software, permanently, because the buffer is armed from boot. The
            // framerate and the bitrate are the knobs to turn there, and they
            // are both on the settings page now.
            "-fallback-cpu-encoding", "yes",
            // CBR is what the man page recommends for a replay buffer, and it
            // is also what makes the memory cost predictable: 40 Mbit/s for 30 s
            // is about 150 MB whatever is happening on screen. The other two
            // modes are offered because gsr offers them and because a machine
            // falling back to CPU encoding may want one; what they cost is the
            // number under the length, which stops being a number.
            "-bm", Config.recordingBitrateMode,
            // OVERLOADED IN gsr ITSELF: -q is a number of kbit/s in CBR and one
            // of four named presets in qp and vbr. Two settings and one flag,
            // rather than one setting that would be a preset name in one mode
            // and a number in the other.
            "-q", root.sizeKnown ? `${Config.recordingBitrate}` : Config.recordingQuality,
            "-r", `${root.seconds}`,
            "-replay-storage", Config.replayStorage,
            "-o", root.directory];

        // NO -k AT ALL rather than `-k auto`, when nobody has chosen. They mean
        // the same thing to gsr -- auto is its documented default and resolves
        // to h264 -- and the absent flag is the one that cannot go stale: what
        // this shell ships with is then whatever gsr thinks is right for the
        // card it finds, on a machine this page has never been opened on.
        if (Config.recordingCodec !== "")
            args.push("-k", Config.recordingCodec);

        // AND NO -a WHEN NOTHING WAS ASKED FOR. A silent clip is a choice
        // somebody made on the settings page; an -a with an empty value is a
        // recorder that will not start. -ac goes with it, since an audio codec
        // for no audio is a flag about nothing.
        if (root.audioSources !== "")
            args.push("-a", root.audioSources, "-ac", Config.recordingAudioCodec);

        return ["sh", "-c", `mkdir -p "$1" || exit 1; shift; exec "$@"`,
            "replay", root.directory, ...args];
    }

    // ANY OF IT CHANGING IS THE SAME EVENT, and it is debounced for two
    // reasons that arrive together. PipeWire announces its nodes over several
    // turns while the graph is built, so the microphone settles through two or
    // three answers at startup rather than one; and Config.restoreDefaults()
    // assigns fifteen of these in a single turn. Without this, either one is a
    // recorder torn down and rebuilt once per value.
    //
    // Half a second is long enough to cover both and short enough that a
    // microphone plugged in by hand is in the recording before the reason for
    // plugging it in has happened.
    onCommandChanged: settle.restart()

    Timer {
        id: settle

        interval: 500
        onTriggered: root.reapply()
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
            replay.command = root.command;
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
                if (!clip.startsWith("/") || !clip.endsWith(`.${Config.recordingContainer}`))
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
