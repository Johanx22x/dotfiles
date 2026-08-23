// The machine's own battery, for the machines that have one.
//
// A TRAY GLYPH AND NOT A PILL. Windows draws the battery as one icon with the
// charge beside it, in the same box as everything else in the taskbar corner:
// no tinted backplate when it is low, no rounded capsule, no colour behind the
// number. When it is nearly flat the GLYPH and the READING go critical, which is
// what Windows does and is also less shouting than genesis's tinted pill -- a
// solid block of colour on a bar reads as an error dialog that got loose.
//
// NOT THE SAME WIDGET AS PeripheralBattery, and the split is the whole design.
// That one shows everything with a battery that is NOT powering the computer --
// a mouse, a headset, a controller -- and filters this out by name. This one is
// the opposite filter, and the two never show the same device twice. A
// peripheral running flat means "go and charge that thing"; the machine running
// flat means "save your work". They deserve different thresholds and different
// words.
//
// OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP. See Config.laptopBattery --
// install.sh asks once, `laptop-modules` records the answer and the Bar page can
// change it afterwards, because a tracked configuration cannot know which of two
// machines it landed on. AND OFF ANYWAY WHEN THERE IS NO BATTERY: the flag is
// the intention, this is the check that the intention is possible.

import Quickshell.Services.UPower
import QtQuick
import qs
import qs.modules.bar
import qs.themes.windows

TaskbarItem {
    id: root

    // UPower's aggregate. On a laptop it IS the battery; on a desktop it exists
    // but reports isLaptopBattery false and a percentage of zero -- measured
    // here, where it also carries icon-name battery-missing-symbolic.
    readonly property var device: UPower.displayDevice

    readonly property bool present: Config.laptopBattery
        && (root.device?.isLaptopBattery ?? false)
        && (root.device?.isPresent ?? false)

    readonly property int charge: Math.round((root.device?.percentage ?? 0) * 100)

    readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
        || root.device?.state === UPowerDeviceState.FullyCharged

    // TIGHTER THAN THE PERIPHERAL ONE, and deliberately. 20% on a mouse is a
    // reminder; 20% on the machine you are working on is about half an hour.
    //
    // Only the amber one is a decision made here. The point at which this
    // interrupts you belongs to BatteryAlerts, which is where both battery
    // widgets now agree about it -- and which is also the only thing that can
    // count how many times it has already interrupted you.
    readonly property int warnBelow: 25

    readonly property bool alerting: BatteryAlerts.isAlerting(root.charge, root.charging)

    readonly property color tint: {
        if (root.charging)
            return Theme.primary;
        if (root.alerting)
            return Theme.critical;
        if (root.charge <= root.warnBelow)
            return Theme.warning;
        return Theme.textOnSurface;
    }

    // A separate glyph while charging, because the percentage alone cannot say
    // which way it is going -- and "30%" means two opposite things depending on
    // whether the cable is in.
    readonly property string glyph: {
        if (root.charging)
            return Icons.batteryCharging;
        if (root.alerting)
            return Icons.batteryAlert;
        return Icons.battery;
    }

    readonly property int padH: Theme.barPadding

    visible: root.present

    boxWidth: reading.implicitWidth + root.padH * 2

    // A READING AND NOT A DOOR, so it neither takes clicks nor washes under the
    // pointer. Windows' own battery icon does both, because there it opens Quick
    // Settings; this one has nothing behind it, and a hover fill on an item that
    // cannot be clicked is an affordance promising something that is not there.
    interactive: false

    Row {
        id: reading

        anchors.centerIn: parent
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: `${root.charge}%`
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            font.features: ({ "tnum": 1 })
            color: root.tint
        }
    }

    // ---------------- The warning ----------------
    //
    // ONCE PER CROSSING, AND ONCE PER MACHINE. This used to hold its own
    // `warned` flag and send its own notify-send, which is one flag per Bar --
    // and shell.qml builds a Bar per screen. Two monitors carrying a bar meant
    // two critical notifications, which do not expire, for one battery crossing
    // one line. The state and the sending are in BatteryAlerts now; this file
    // reports a reading and nothing more.
    //
    // STILL ON EVERY READING and not only on the ones that cross the line: the
    // check has to see the value climb back up as well, or it never re-arms.
    onChargeChanged: root.considerAlert()
    onChargingChanged: root.considerAlert()

    function considerAlert(): void {
        // A desktop where somebody answered "laptop" by mistake has a
        // DisplayDevice reporting 0% forever, and that is not a flat battery.
        if (!root.present)
            return;

        BatteryAlerts.consider({
            // ONE KEY FOR THE MACHINE, and it does not come off the device:
            // UPower's DisplayDevice is an aggregate with a synthetic path, and
            // there is exactly one of it. A fixed string is what makes every
            // bar's call land on the same entry.
            key: "system",
            label: "Battery",
            charge: root.charge,
            charging: root.charging,
            secondsLeft: root.device?.timeToEmpty ?? 0
        });
    }
}
