pragma Singleton

import Quickshell
import Quickshell.Io

// The Japanese input method, which is fcitx5 with Mozc, as one switch.
//
// The script `input-method` owns everything that happens; this file is the
// shell's view of it. Writes go out as a detached call, reads come back from
// the file the script writes, so a `input-method off` typed in a terminal
// moves the switch on the Input page without anything polling.
//
// THERE IS NO `armed` PROPERTY HERE, and that is the one way this differs
// from NightLight.qml, which it otherwise copies. That singleton has to be
// brought to life by shell.qml because it runs a schedule: nothing else would
// turn the filter on at 20:00. This one runs nothing. What survives a logout
// is not a timer in the shell, it is ~/.config/autostart/org.fcitx.Fcitx5.desktop,
// which systemd's xdg-autostart generator reads long before any QML loads --
// so being created lazily, the first time the Input page is looked at, costs
// nothing at all.
//
// NOR IS THERE AN IpcHandler, deliberately. The terminal door already exists
// and is the better one: `input-method toggle` works with the shell killed,
// which is exactly the session where somebody is trying to fix something.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // ON unless the file says otherwise, matching the script's own default and
    // for the same reason: the only way fcitx5 is on this machine is that
    // somebody ticked input-method in the installer, and a package ticked and
    // then silently not running is the worse of the two surprises.
    property bool enabled: true

    // OPTIMISTIC UNTIL THE PROBE ANSWERS. A row that flashes dead and then
    // alive on every visit reads as a page that is broken and recovers; the
    // probe takes a few milliseconds and the honest default is the common case.
    property bool available: true

    function setEnabled(value: bool): void {
        if (value === root.enabled)
            return;

        root.enabled = value;
        Quickshell.execDetached(["input-method", value ? "on" : "off"]);
    }

    function toggle(): void {
        root.setEnabled(!root.enabled);
    }

    // Asked once per visit to the page rather than polled: the answer changes
    // only when somebody installs or removes a package, and that ends with a
    // trip back here. InputPage owns the call because QML allows one
    // onVisibleChanged handler per object and the page already has it.
    function probe(): void {
        if (!availability.running)
            availability.running = true;
    }

    // ---------------- Reading the script's state ----------------

    FileView {
        id: stateFile

        path: `${root.stateDir}/input-method`
        watchChanges: true
        // Absent until the script has run once, which is not an error: the
        // property above already holds the same default it would write.
        printErrors: false

        // watchChanges only emits the signal; the reload is ours to ask for.
        onFileChanged: stateFile.reload()
        onLoaded: root.adopt()
    }

    function adopt(): void {
        // ONE LINE, the enabled flag, in the shape night-light and desktop-font
        // already use. `split` always yields at least one element, so there is
        // nothing to guard against on the index.
        const lines = (stateFile.text() || "").split("\n");
        root.enabled = lines[0].trim() !== "0";
    }

    // ---------------- Is there an engine at all ----------------

    Process {
        id: availability

        command: ["input-method", "show"]

        stdout: StdioCollector {
            id: collector

            // `engine: none` is the only hard no -- it means the optional
            // package group was never ticked. A daemon merely not running is
            // what the switch is for.
            //
            // Through the id rather than the bare `text` the sibling probes
            // use: an unqualified read is what qmllint counts, and this file
            // can be written without adding to that budget.
            onStreamFinished: {
                const engine = /^engine:\s+(\S+)$/m.exec(collector.text);
                root.available = !!engine && engine[1] !== "none";
            }
        }
    }
}
