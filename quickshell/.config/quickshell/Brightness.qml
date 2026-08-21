// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// BRIGHTNESS - the backlight, and how the shell finds out it moved
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// THE READING USED TO LIVE IN THE DASHBOARD, WHICH IS WHY NOTHING FLASHED.
// BrightnessControl.qml owned the device query and the two FileViews, and it
// is a child of Dashboard.qml -- content of the bar's shared popout, which
// destroys what it is showing the moment it closes (see Popout.close). So the
// backlight was watched only while the panel was open in front of you, which
// is the one time you do not need to be told about it. Everything below is
// that same reading, moved somewhere that outlives the thing displaying it.
// IslandState.qml makes the identical argument for `dashboardTab`.
//
// WATCHING SYSFS RATHER THAN BEING TOLD. The alternative was to have whatever
// changes the brightness call in -- `desktop-brightness` running
// `qs ipc call brightness changed`, or the keybind doing it -- and the file
// wins on the only question that matters: WHO IT MISSES.
//
// A watch on /sys/class/backlight/<device>/brightness sees every writer there
// will ever be, because there is only one file and they all end at it: this
// shell's slider, the `brightnessctl -e4 -n2` the media keys are bound to,
// `desktop-brightness` from a terminal, systemd-backlight restoring the level
// at boot, a power-profile daemon dimming on battery. It also sees the one
// case no IPC can ever cover -- a laptop whose Fn keys are handled in
// firmware, where the EC moves the panel and the kernel only publishes the
// result. Nothing in userspace is there to make a call.
//
// An IPC call is explicit, which is its real virtue, and it buys that by
// requiring every writer to agree to make it. The ones that would have to
// agree are a udev-granted C program and a laptop's embedded controller.
//
// The file is world-readable, so the watch costs a poll-free inotify hook and
// needs nobody's cooperation. `desktop-brightness` was written for this: its
// `device` verb exists for no other purpose than to print the path for the
// shell to watch, and its header says so.
//
// WRITES STILL GO OUT THROUGH THE SCRIPT, and that asymmetry is deliberate
// rather than an oversight -- writing needs the group membership
// brightnessctl's udev rule grants. Read from the file, write through the
// script; the script's header carries the long version.
//
// THE DEVICE IS ASKED FOR ONCE. Its name belongs to a driver
// (intel_backlight, amdgpu_bl0, nvidia_0...) and FileView needs a concrete
// path, so the script prints it and this watches whatever it said. Not on a
// timer: a backlight does not appear or disappear while a session runs.
//
// ON A DESKTOP THIS DOES NOTHING AT ALL, which is most of the machines these
// dotfiles run on and every machine they are edited on. `device` comes back
// empty, both FileViews get an empty path and watch nothing, `present` is
// false, and no acknowledgement is ever raised. One process spawn at startup
// is the entire cost -- and it is fewer than before, when the same spawn
// happened every single time the dashboard was opened.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Singleton {
    id: root

    // Read by shell.qml to bring this singleton into existence at startup,
    // the same idiom ReplayState and Microphone use and for the same reason:
    // a Quickshell singleton is not created until something asks for it, and
    // a watcher nobody has asked for yet has not seen anything change. The
    // island cannot ask -- it only reacts to what this reports -- so if this
    // waited to be needed it would come into being holding the value it was
    // supposed to have noticed.
    readonly property bool armed: true

    // The sysfs directory, or empty on a machine with no backlight.
    property string device: ""
    property int raw: 0
    property int maximum: 0

    // OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP, and off anyway when there
    // is no backlight. Two gates, and the header of SystemBattery.qml has the
    // argument for both: the flag is the intention, the device is the check
    // that the intention is possible. Everything that shows brightness --
    // the dashboard's slider and the island's acknowledgement -- hangs off
    // this one property, so turning the module off turns off all of it rather
    // than leaving one of the two behind.
    readonly property bool present: Config.laptopBrightness && root.device !== "" && root.maximum > 0

    readonly property int percent: root.maximum > 0
        // Rounded, not truncated -- the same arithmetic the script uses. With
        // a max_brightness of 96, integer division turns 95% into 94% and a
        // value read back and written again walks downwards on its own.
        ? Math.round((root.raw * 100) / root.maximum)
        : 0

    // FIVE PERCENT IS THE FLOOR, matching the script rather than being
    // enforced twice with two different numbers. Zero is a black screen on
    // most panels -- including the backlight behind whatever you would use to
    // turn it back up.
    readonly property int minPercent: 5

    // What one press of a key or one notch of the stepper is worth. The same
    // 5% the media keys use, so a press and a step move by the same amount
    // whichever door was used.
    readonly property int step: 5

    Component.onCompleted: deviceQuery.running = true

    Process {
        id: deviceQuery

        command: ["desktop-brightness", "device"]

        // Empty on a machine with no backlight: the script exits 1 and prints
        // nothing at all for this verb, rather than the "none" the other
        // verbs answer with. Trimmed because it prints a trailing newline.
        stdout: StdioCollector {
            onStreamFinished: root.device = (text || "").trim()
        }
    }

    // Two files, both watched. `brightness` moves whenever anything changes it
    // -- the slider, the media keys, a laptop's own Fn keys, a power profile
    // -- and `max_brightness` is read once but watched anyway because it costs
    // nothing and a driver that reloads can change it.
    FileView {
        path: root.device !== "" ? `${root.device}/brightness` : ""
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            const parsed = parseInt(text());
            if (!isNaN(parsed))
                root.raw = parsed;
        }
    }

    FileView {
        path: root.device !== "" ? `${root.device}/max_brightness` : ""
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            const parsed = parseInt(text());
            if (!isNaN(parsed))
                root.maximum = parsed;
        }
    }

    function setPercent(value: int): void {
        if (!root.present)
            return;

        const wanted = Math.max(root.minPercent, Math.min(100, Math.round(value)));

        // Moved locally at once so the handle keeps up with the pointer; the
        // file comes back a moment later and confirms it. Same arrangement as
        // the opacity in Config.qml, minus the debounce -- brightnessctl is
        // one small write, not a signal to every terminal on the machine.
        root.raw = Math.round(wanted * root.maximum / 100);
        Quickshell.execDetached(["desktop-brightness", "set", String(wanted)]);
    }

    // UP AND DOWN GO THROUGH THE SCRIPT'S OWN VERBS rather than reading the
    // percentage here and calling setPercent with one more step on it. The
    // clamping and the floor are the script's to apply, and doing the
    // arithmetic on this side would be a second copy of them that agrees
    // today and drifts later.
    //
    // No optimistic local move either, unlike setPercent: nothing is being
    // dragged, so there is no handle that has to keep up with a finger, and
    // the file answers within a frame or two anyway.
    function up(): void {
        if (root.present)
            Quickshell.execDetached(["desktop-brightness", "up", String(root.step)]);
    }

    function down(): void {
        if (root.present)
            Quickshell.execDetached(["desktop-brightness", "down", String(root.step)]);
    }
}
