// The backlight, with a slider you can aim at.
//
// NEXT TO THE VOLUME AND SHAPED LIKE IT, because they are the same kind of
// thing: a value with a floor and a ceiling that you set by feel and then stop
// thinking about. Anything else here would be a second vocabulary for one
// idea.
//
// READ FROM SYSFS, WRITTEN THROUGH A SCRIPT, and the asymmetry is not an
// oversight. /sys/class/backlight/<device>/brightness is world-readable, so
// watching it means the slider follows a laptop's own Fn keys the instant
// they are pressed -- no polling, no state file, nothing to fall out of step.
// Writing needs the group membership brightnessctl's udev rule grants, so
// writes go out through `desktop-brightness`.
//
// THE DEVICE IS ASKED FOR ONCE. Its name is a driver's (intel_backlight,
// amdgpu_bl0, nvidia_0...) and QML's FileView needs a concrete path, so the
// script prints it and this watches whatever it said.
//
// OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP, and off anyway when there is no
// backlight -- see the header of SystemBattery.qml for why it is both.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    // The sysfs directory, or empty on a machine with no backlight.
    property string device: ""
    property int raw: 0
    property int maximum: 0

    readonly property bool present: Config.laptopBrightness && root.device !== "" && root.maximum > 0

    readonly property int percent: root.maximum > 0
        // Rounded, not truncated -- the same arithmetic the script uses. With
        // a max_brightness of 96, integer division turns 95% into 94% and a
        // value read back and written again walks downwards on its own.
        ? Math.round((root.raw * 100) / root.maximum)
        : 0

    // Asked when the widget is built and not on a timer: a backlight device
    // does not appear or disappear while the session is running.
    Component.onCompleted: deviceQuery.running = true

    Process {
        id: deviceQuery

        command: ["desktop-brightness", "device"]

        stdout: StdioCollector {
            onStreamFinished: root.device = (text || "").trim()
        }
    }

    // Two files, both watched. `brightness` moves whenever anything changes it
    // -- this slider, the Fn keys, a power profile -- and `max_brightness` is
    // read once but watched anyway because it costs nothing and a driver that
    // reloads can change it.
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

    // FIVE PERCENT IS THE FLOOR, matching the script rather than being
    // enforced twice with two different numbers. Zero is a black screen on
    // most panels -- including the backlight behind whatever you would use to
    // turn it back up.
    function setPercent(value: int): void {
        const wanted = Math.max(5, Math.min(100, Math.round(value)));

        // Moved locally at once so the handle keeps up with the pointer; the
        // file comes back a moment later and confirms it. Same arrangement as
        // the opacity in Config.qml, minus the debounce -- brightnessctl is
        // one small write, not a signal to every terminal on the machine.
        root.raw = Math.round(wanted * root.maximum / 100);
        Quickshell.execDetached(["desktop-brightness", "set", String(wanted)]);
    }

    visible: root.present
    implicitHeight: root.present ? 62 : 0

    Text {
        id: mark

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 6

        text: Icons.brightness
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: mark.verticalCenter

        text: `${root.percent}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    VolumeSlider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Named for the volume because that is where it was extracted from,
        // and it is not audio-specific: a track, a fill and a handle over a
        // range. See its header.
        value: root.percent
        maximum: 100
        step: 5
        accent: Theme.primary

        onMoved: value => root.setPercent(value)
    }
}
