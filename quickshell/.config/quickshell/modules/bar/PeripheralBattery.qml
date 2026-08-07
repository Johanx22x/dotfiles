// The charge left in whatever wireless thing is under your hand or on your
// head, and a panel with the rest of what UPower knows about it.
//
// NOT THE MACHINE'S BATTERY. This is a desktop and has none; UPower's
// DisplayDevice -- the aggregate every laptop bar shows -- reports nothing
// here. What it does report is HID++ peripherals: a wireless mouse, a
// keyboard, a headset, each with its own percentage, and until this existed
// that number was on the machine and nowhere on the screen.
//
// SO THE FILTER IS "IS IT A POWER SUPPLY", inverted. UPower marks the thing
// that powers the computer with powerSupply = true, which is exactly what
// this is not interested in; everything else with a battery is a peripheral.
// A laptop running these dotfiles would show its mouse here and its own
// battery wherever a laptop battery belongs, rather than both in one row
// meaning two different things.
//
// THE GLYPH FOLLOWS UPower's OWN DEVICE TYPE and nothing else. An earlier
// version of this file was about to grow a list of model-name keywords, on
// the belief that the type was unreliable -- the Logitech PRO X 2 here
// reports Mouse, and that was read as a misclassified headset. It is a mouse.
// The type was right and the workaround would have been a pile of brittle
// string matching solving a problem that did not exist. If a device ever does
// report the wrong type, the fix belongs in UPower or in the device, not in a
// desktop bar guessing from a product name.
//
// IT IS ONLY THERE WHEN THERE IS SOMETHING TO SAY. No peripheral, no glyph --
// a permanent empty slot on the bar is worse than the reading being absent,
// because the eye learns to skip the place where it lives.

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "root:/"

Row {
    id: root

    // The bar's shared popout, handed down by Bar.qml exactly as the tray
    // gets it. One popout for the whole bar rather than one per widget: it is
    // a single surface that moves and re-fills, so two can never be open at
    // once and the animation is the same wherever it appears.
    required property var popout

    // Every battery that is not the one running the computer. Sorted by how
    // empty it is, so the one about to die is the one on the left -- with two
    // devices connected the order otherwise depends on which was paired
    // first, which is not a fact anybody is looking for.
    readonly property var devices: {
        // Read so the binding re-evaluates when a device connects or goes
        // away, not only at startup.
        UPower.devices.values.length;

        return UPower.devices.values
            .filter(d => d.ready && !d.isLaptopBattery && !d.powerSupply && d.percentage > 0)
            .sort((a, b) => a.percentage - b.percentage);
    }

    // A PLAIN PROPERTY AND NOT `visible` FOR THE PARENT TO READ. The pill
    // around this has to disappear along with it, and hanging its `visible`
    // off this item's own `visible` is a binding loop -- Qt detects it, drops
    // the binding, and the result is a battery that never appears at all with
    // nothing in the log to say why. That is exactly what happened the first
    // time. This says the same thing without involving visibility.
    readonly property bool hasAny: root.devices.length > 0

    // ONE DEVICE IS A DIFFERENT PICTURE FROM TWO, and the pill around this
    // reads it. With a single peripheral there is nothing to tell apart, so
    // the whole group takes the colour and the reading inside it stays plain
    // -- a tinted pill inside a tinted pill is two edges saying one thing.
    // With two or more the tint has to be on the row that is actually low,
    // because "one of these is nearly flat" is only useful if it says which.
    readonly property bool alertingAlone: root.devices.length === 1
        && root.isAlerting(root.chargeOf(root.devices[0]), root.isCharging(root.devices[0]))

    function glyphFor(device: var): string {
        switch (device?.type) {
        case UPowerDeviceType.Mouse:
            return Icons.mouse;
        case UPowerDeviceType.Keyboard:
            return Icons.keyboard;
        case UPowerDeviceType.Headset:
            return Icons.headset;
        case UPowerDeviceType.Headphones:
        case UPowerDeviceType.Speakers:
        case UPowerDeviceType.OtherAudio:
            return Icons.headphones;
        case UPowerDeviceType.GamingInput:
            return Icons.gamepad;
        case UPowerDeviceType.Phone:
            return Icons.bluetooth;
        }

        // Anything else says "a battery", which is the honest answer when the
        // only thing known about the device is that it has one.
        return Icons.battery;
    }

    // ---------------- When to start worrying ----------------
    //
    // TWO LEVELS, AND ONLY THE LOWER ONE SHOUTS. Under 30% the number goes
    // amber and nothing else happens: it is a heads-up, and a bar that
    // changes shape every time a mouse drops below a third would be noise.
    // Under 15% the whole reading turns into a red pill and a notification
    // goes out once -- that is the point where the thing will actually stop
    // working during whatever you are doing.
    //
    // CHARGING BEATS BOTH. A mouse on its cable at 8% is not a problem, and
    // colouring it as one is how a warning stops being believed.
    readonly property int alertBelow: 15
    readonly property int warnBelow: 30

    // Higher than alertBelow on purpose. A battery sitting exactly on the
    // threshold flickers across it as the reading settles, and without a gap
    // between "start warning" and "stop warning" that flicker is a
    // notification every few minutes. It has to climb back to 20 before the
    // alert can fire again.
    readonly property int rearmAt: 20

    function isAlerting(charge: int, charging: bool): bool {
        return !charging && charge <= root.alertBelow;
    }

    function tintFor(charge: int, charging: bool): color {
        if (charging)
            return Theme.primary;
        if (root.isAlerting(charge, charging))
            return Theme.critical;
        if (charge <= root.warnBelow)
            return Theme.warning;
        return Theme.textOnSurface;
    }

    // ---------------- The alert ----------------
    //
    // KEYED BY nativePath AND HELD ON THE WIDGET, not in the delegate. The
    // list is sorted by how empty each device is, so the delegates are
    // destroyed and rebuilt whenever a percentage changes -- which is exactly
    // when this state matters. A flag stored in the row would be thrown away
    // by the same event that should have set it, and the notification would
    // go out again every few minutes.
    property var alerted: ({})

    function considerAlert(device: var): void {
        const key = device?.nativePath ?? "";
        if (key === "")
            return;

        const charge = root.chargeOf(device);
        const charging = root.isCharging(device);

        // Back above the re-arm line, or on a cable: forget it happened, so
        // the next time it runs down there is a warning again.
        if (charging || charge >= root.rearmAt) {
            if (root.alerted[key]) {
                const next = Object.assign({}, root.alerted);
                delete next[key];
                root.alerted = next;
            }
            return;
        }

        if (charge > root.alertBelow || root.alerted[key])
            return;

        const next = Object.assign({}, root.alerted);
        next[key] = true;
        root.alerted = next;

        // notify-send and not a call into this shell's own notification
        // model: the shell IS the notification daemon, so this goes out over
        // the bus and comes straight back in as an ordinary notification --
        // which means it looks like every other one, stacks with them, and
        // obeys do-not-disturb. A private code path into the model would
        // bypass all three.
        //
        // Critical urgency, which is what makes it outlive its timeout: see
        // the header of NotificationCard.qml. A warning that disappears while
        // you are looking at the other monitor has not warned anybody.
        Quickshell.execDetached(["notify-send",
            "--urgency=critical",
            "--app-name=Battery",
            `${device.model || "A wireless device"} is at ${charge}%`,
            "Put it on the cable before it stops."]);
    }

    function isCharging(device: var): bool {
        return device?.state === UPowerDeviceState.Charging
            || device?.state === UPowerDeviceState.FullyCharged;
    }

    // 0..1 from UPower -- measured against `upower -i`, which prints the same
    // charge as a whole number. A percentage everywhere a person reads it.
    function chargeOf(device: var): int {
        return Math.round((device?.percentage ?? 0) * 100);
    }

    // Which device the panel is about. Held on the widget rather than passed
    // in, because a Component cannot take arguments; the view reads it when
    // it is built. Same arrangement the tray uses for its menus.
    property var shownDevice: null

    visible: root.hasAny

    spacing: Theme.itemSpacing

    Repeater {
        model: root.devices

        delegate: Rectangle {
            id: entry

            required property var modelData

            readonly property int charge: root.chargeOf(entry.modelData)
            readonly property bool charging: root.isCharging(entry.modelData)
            readonly property bool alerting: root.isAlerting(entry.charge, entry.charging)

            readonly property color tint: root.tintFor(entry.charge, entry.charging)

            // Every reading, not only the ones that cross the line: the check
            // has to see the value climb back up as well, or the alert never
            // re-arms.
            onChargeChanged: root.considerAlert(entry.modelData)
            onChargingChanged: root.considerAlert(entry.modelData)
            Component.onCompleted: root.considerAlert(entry.modelData)

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: reading.implicitWidth + 12
            implicitHeight: Theme.groupHeight - 8
            radius: height / 2

            // A pill under the pointer, which the bare glyph did not have.
            // The reading is now a button and has to look like one before it
            // is touched -- the same argument the wallpaper page's Change chip
            // lost and then won.
            //
            // AND A TINTED ONE WHEN IT IS NEARLY FLAT. Colouring the text
            // alone was not enough -- a red number among white ones on a bar
            // full of other marks is something you notice on the second look
            // -- but the first attempt filled the pill with solid critical
            // and that was worse: on a bar where everything else is a
            // translucent pill over glass, one opaque red block does not read
            // as "this is low", it reads as an error dialog that got loose.
            //
            // 0.18 is the same alpha, chosen the same way, as the settings
            // window's sidebar: enough to see a patch of colour where there
            // was none, not enough to outshout the rest of the bar. The text
            // stays Theme.critical rather than becoming textOnCritical,
            // because at this alpha the background behind it is still the
            // bar's own -- pairing it with the solid colour would make it
            // nearly invisible.
            //
            // Suppressed when this is the only device: the group behind it has
            // taken the colour instead, and doing both stacks one tint on the
            // other into something twice as loud as either.
            color: entry.alerting && !root.alertingAlone
                ? Qt.alpha(Theme.critical, entryMouse.containsMouse ? 0.30 : 0.18)
                : entryMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Row {
                id: reading

                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.glyphFor(entry.modelData)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: entry.tint

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: `${entry.charge}%`
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                    color: entry.tint

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }
            }

            MouseArea {
                id: entryMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.shownDevice = entry.modelData;
                    root.popout.toggleAt(entry.mapToItem(null, entry.width / 2, 0).x, detailComponent);
                }
            }
        }
    }

    Component {
        id: detailComponent

        // ---------------- The panel ----------------
        //
        // EVERYTHING UPOWER WILL SAY, which is the point of it: the bar can
        // only carry a number, and the questions that number raises -- what
        // is it, is it charging, how long have I got -- all have answers, a
        // click away rather than in a tooltip that cannot be read at leisure.
        Column {
            id: detail

            readonly property var device: root.shownDevice
            readonly property int charge: root.chargeOf(detail.device)
            readonly property bool charging: root.isCharging(detail.device)

            // Plain words and not UPowerDeviceState.toString(), which returns
            // the enumerator's own name -- "PendingCharge" -- and that is a
            // sentence about UPower's internals to somebody who wants to know
            // whether the thing is charging.
            readonly property string stateText: {
                switch (detail.device?.state) {
                case UPowerDeviceState.Charging:         return "charging";
                case UPowerDeviceState.Discharging:      return "in use";
                case UPowerDeviceState.FullyCharged:     return "full";
                case UPowerDeviceState.Empty:            return "empty";
                case UPowerDeviceState.PendingCharge:    return "waiting to charge";
                case UPowerDeviceState.PendingDischarge: return "waiting";
                default:                                 return "state unknown";
                }
            }

            // ONLY WHEN UPOWER HAS ONE. It reports 0 for "no estimate yet",
            // which is most of the time on a device that has just connected,
            // and "0 minutes left" beside a battery at half full is a worse
            // answer than no line at all.
            readonly property string remaining: {
                const seconds = detail.charging
                    ? (detail.device?.timeToFull ?? 0)
                    : (detail.device?.timeToEmpty ?? 0);

                if (!seconds || seconds <= 0)
                    return "";

                const hours = Math.floor(seconds / 3600);
                const minutes = Math.round((seconds % 3600) / 60);
                const spelled = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;

                return detail.charging ? `${spelled} until full` : `About ${spelled} left`;
            }

            width: 260
            spacing: Theme.itemSpacing

            Row {
                width: parent.width
                spacing: Theme.itemSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.glyphFor(detail.device)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize + 6
                    color: root.tintFor(detail.charge, detail.charging)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        // The manufacturer's own name for it. Nothing else on
                        // this desktop prints it, which is half the reason the
                        // panel exists: with two wireless things connected,
                        // the model is how you know WHICH one the bar is
                        // worried about.
                        text: detail.device?.model || "Wireless device"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Bold
                        color: Theme.textOnSurface
                    }

                    Text {
                        text: `${detail.charge}%  ·  ${detail.stateText}`
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }

            // The bar the one on the panel can afford and the one in the bar
            // cannot: at this width the number has room to be a picture too.
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, detail.charge / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.tintFor(detail.charge, detail.charging)

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }

            Text {
                visible: detail.remaining !== ""

                width: parent.width
                text: detail.remaining
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurfaceVariant
            }

            Text {
                visible: detail.device?.healthSupported ?? false

                width: parent.width
                text: `Battery health ${Math.round(detail.device?.healthPercentage ?? 0)}%`
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurfaceVariant
            }
        }
    }
}
