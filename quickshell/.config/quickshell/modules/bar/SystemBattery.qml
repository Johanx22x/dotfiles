// The machine's own battery, for the machines that have one.
//
// NOT THE SAME WIDGET AS PeripheralBattery, and the split is the whole design.
// That one shows everything with a battery that is NOT powering the computer
// -- a mouse, a headset, a controller -- and filters this out by name. This
// one is the opposite filter, and the two never show the same device twice.
//
// It is worth being two widgets rather than one with a flag: a peripheral
// running flat means "go and charge that thing", while the machine running
// flat means "save your work". They deserve different thresholds and
// different words, and they do not belong side by side in one list.
//
// OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP. See Config.laptopBattery --
// install.sh asks once, `laptop-modules` records the answer and the Bar page
// can change it afterwards, because a tracked configuration cannot know
// which of two machines it landed on.
//
// AND OFF ANYWAY WHEN THERE IS NO BATTERY. The flag is the intention; this is
// the check that the intention is possible. A desktop where somebody answered
// yes by mistake shows nothing rather than a permanent 0%.

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "root:/"

Rectangle {
    id: root

    // UPower's aggregate. On a laptop it IS the battery; on a desktop it
    // exists but reports isLaptopBattery false and a percentage of zero --
    // measured here, where it also carries icon-name battery-missing-symbolic.
    readonly property var device: UPower.displayDevice

    readonly property bool present: Config.laptopBattery
        && (root.device?.isLaptopBattery ?? false)
        && (root.device?.isPresent ?? false)

    readonly property int charge: Math.round((root.device?.percentage ?? 0) * 100)

    readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
        || root.device?.state === UPowerDeviceState.FullyCharged

    // TIGHTER THAN THE PERIPHERAL ONE, and deliberately. 20% on a mouse is a
    // reminder; 20% on the machine you are working on is about half an hour.
    // The numbers are the ones every laptop desktop has settled on for the
    // same reason -- they are roughly "finish the paragraph" and "save now".
    readonly property int alertBelow: 15
    readonly property int warnBelow: 25

    readonly property bool alerting: !root.charging && root.charge <= root.alertBelow

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
    // which way it is going -- and "30%" means two opposite things depending
    // on whether the cable is in.
    readonly property string glyph: {
        if (root.charging)
            return Icons.batteryCharging;
        if (root.alerting)
            return Icons.batteryAlert;
        return Icons.battery;
    }

    readonly property string remaining: {
        const seconds = root.charging
            ? (root.device?.timeToFull ?? 0)
            : (root.device?.timeToEmpty ?? 0);

        // Zero is "no estimate yet", which is most of the first minute after a
        // cable moves. A line saying nothing is better than one saying zero.
        if (!seconds || seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const spelled = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;

        return root.charging ? `${spelled} until full` : `${spelled} left`;
    }

    visible: root.present

    implicitWidth: reading.implicitWidth + 12
    implicitHeight: Theme.groupHeight - 8
    radius: height / 2

    // The same tinted pill the peripheral widget uses when something is nearly
    // flat, at the same alpha and for the same reason: on a bar where
    // everything is a translucent pill over glass, a solid block of colour
    // reads as an error dialog that got loose.
    color: root.alerting ? Qt.alpha(Theme.critical, 0.18) : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        id: reading

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.tint

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: `${root.charge}%`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: root.tint

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    // ---------------- The warning ----------------
    //
    // ONCE PER CROSSING, with the same re-arm gap the peripheral widget uses:
    // a battery sitting on the threshold flickers across it as the reading
    // settles, and without a gap that flicker is a notification a minute.
    property bool warned: false

    onChargeChanged: root.considerAlert()
    onChargingChanged: root.considerAlert()

    function considerAlert(): void {
        if (!root.present)
            return;

        if (root.charging || root.charge >= 20) {
            root.warned = false;
            return;
        }

        if (root.charge > root.alertBelow || root.warned)
            return;

        root.warned = true;

        // Through the bus like any other notification -- see the note in
        // PeripheralBattery: the shell is the notification daemon, so this
        // comes back in as an ordinary one and obeys do-not-disturb.
        Quickshell.execDetached(["notify-send",
            "--urgency=critical",
            "--app-name=Battery",
            `Battery at ${root.charge}%`,
            root.remaining !== "" ? `About ${root.remaining}.` : "Find a cable."]);
    }
}
