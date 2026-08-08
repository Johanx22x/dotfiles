// The charge left in whatever wireless thing is under your hand, on your head
// or in your lap, and a panel with the rest of what is known about it.
//
// NOT THE MACHINE'S BATTERY. This is a desktop and has none; UPower's
// DisplayDevice -- the aggregate every laptop bar shows -- reports nothing
// here. What it does report is HID++ peripherals: a wireless mouse, a
// keyboard, a game controller, each with its own percentage, and until this
// existed that number was on the machine and nowhere on the screen.
//
// SO THE FILTER IS "IS IT A POWER SUPPLY", inverted. UPower marks the thing
// that powers the computer with powerSupply = true, which is exactly what
// this is not interested in; everything else with a battery is a peripheral.
// A laptop running these dotfiles would show its mouse here and its own
// battery wherever a laptop battery belongs, rather than both in one row
// meaning two different things.
//
// TWO SOURCES, NOT ONE, and the second one is a whole script. AirPods report
// no battery to Linux by any standard road -- no org.bluez.Battery1, no
// Battery Service in their UUID list -- so UPower cannot see them and neither
// can anything reading UPower. `airpods-battery` talks to them directly over
// Apple's own protocol and leaves the answer in a file; its header is where
// the evidence for all of that lives.
//
// THE GLYPH FOLLOWS UPower's OWN DEVICE TYPE and nothing else. An earlier
// version of this file was about to grow a list of model-name keywords, on
// the belief that the type was unreliable -- the Logitech PRO X 2 here
// reports Mouse, and that was read as a misclassified headset. It is a mouse.
// The type was right and the workaround would have been brittle string
// matching solving a problem that did not exist.
//
// IT IS ONLY THERE WHEN THERE IS SOMETHING TO SAY. No peripheral, no glyph --
// a permanent empty slot on the bar is worse than the reading being absent,
// because the eye learns to skip the place where it lives.

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // ---------------- UPower ----------------

    readonly property var upowerDevices: {
        // Read so the binding re-evaluates when a device connects or goes
        // away, not only at startup.
        UPower.devices.values.length;

        return UPower.devices.values
            .filter(d => d.ready && !d.isLaptopBattery && !d.powerSupply && d.percentage > 0);
    }

    function glyphFor(device: var): string {
        switch (device?.type) {
        case UPowerDeviceType.Mouse:       return Icons.mouse;
        case UPowerDeviceType.Keyboard:    return Icons.keyboard;
        case UPowerDeviceType.Headset:     return Icons.headset;
        case UPowerDeviceType.Headphones:
        case UPowerDeviceType.Speakers:
        case UPowerDeviceType.OtherAudio:  return Icons.headphones;
        case UPowerDeviceType.GamingInput: return Icons.gamepad;
        case UPowerDeviceType.Phone:       return Icons.bluetooth;
        }

        // "A battery" is the honest answer when the only thing known about
        // the device is that it has one.
        return Icons.battery;
    }

    // Plain words and not UPowerDeviceState.toString(), which returns the
    // enumerator's own name -- "PendingCharge" -- and that is a sentence about
    // UPower's internals to somebody who wants to know whether it is charging.
    function stateTextOf(state: int): string {
        switch (state) {
        case UPowerDeviceState.Charging:         return "charging";
        case UPowerDeviceState.Discharging:      return "in use";
        case UPowerDeviceState.FullyCharged:     return "full";
        case UPowerDeviceState.Empty:            return "empty";
        case UPowerDeviceState.PendingCharge:    return "waiting to charge";
        case UPowerDeviceState.PendingDischarge: return "waiting";
        default:                                 return "state unknown";
        }
    }

    // ONLY WHEN THERE IS ONE. UPower reports 0 for "no estimate yet", which is
    // most of the time on a device that has just connected, and "0 minutes
    // left" beside a battery at half full is a worse answer than no line.
    function remainingText(seconds: real, charging: bool): string {
        if (!seconds || seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const spelled = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;

        return charging ? `${spelled} until full` : `About ${spelled} left`;
    }

    // ---------------- AirPods ----------------
    //
    // Written by the `airpods-battery` script on a systemd timer, in the same
    // tab-separated shape the rest of this repository's state files use. It is
    // watched rather than polled here: the file changing IS the event.
    property var airpods: null

    FileView {
        id: airpodsFile

        path: `${root.stateDir}/airpods-battery`
        watchChanges: true
        // Absent whenever they have never been connected, which is not an
        // error and must not print one every time the shell starts.
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptAirpods()
        onLoadFailed: root.airpods = null
    }

    function adoptAirpods(): void {
        const parsed = { name: "AirPods", parts: [] };

        for (const line of (airpodsFile.text() || "").split("\n")) {
            const fields = line.split("\t");
            if (fields.length < 2)
                continue;

            if (fields[0] === "name") {
                parsed.name = fields[1];
                continue;
            }

            const level = parseInt(fields[1]);
            if (isNaN(level))
                continue;

            // KEPT EVEN WHEN IT IS NOT THERE, and marked rather than
            // dropped. A component the earphones report as disconnected is a
            // case sitting shut in a pocket, or a bud still in it -- and its
            // level comes back as 0, which is not a charge. Dropping the row
            // was the first version and it read as the panel forgetting the
            // case existed; printing the 0 would say the case is flat. So the
            // row is there and says it is not connected.
            const available = fields[2] !== "disconnected";

            parsed.parts.push({
                label: fields[0],
                charge: level,
                available: available,
                stateText: !available ? "not connected"
                    : fields[2] === "charging" ? "charging" : "in use",
                charging: available && fields[2] === "charging"
            });
        }

        // Nothing to show at all if not one component answered. Rows that
        // all say "not connected" are earphones sitting in a closed case,
        // which is the one moment the bar should be quiet about them.
        root.airpods = parsed.parts.some(p => p.available) ? parsed : null;
    }

    // ---------------- One list, whatever it came from ----------------
    //
    // NORMALISED INTO PLAIN OBJECTS rather than passing UPower devices to the
    // delegate. Two sources with nothing in common -- a D-Bus object and a
    // parsed file -- would otherwise mean two delegates and two panels drawn
    // to look the same, which is how they stop looking the same.
    //
    // Sorted by how empty each one is, so the thing about to die is on the
    // left: with several connected the order otherwise depends on which was
    // paired first, which is not a fact anybody is looking for.
    readonly property var entries: {
        const out = [];

        for (const device of root.upowerDevices) {
            const charging = device.state === UPowerDeviceState.Charging
                || device.state === UPowerDeviceState.FullyCharged;

            out.push({
                key: device.nativePath || device.model,
                glyph: root.glyphFor(device),
                // 0..1 from UPower -- measured against `upower -i`, which
                // prints the same charge as a whole number.
                charge: Math.round((device.percentage ?? 0) * 100),
                charging: charging,
                label: device.model || "Wireless device",
                stateText: root.stateTextOf(device.state),
                remaining: root.remainingText(
                    charging ? (device.timeToFull ?? 0) : (device.timeToEmpty ?? 0), charging),
                health: (device.healthSupported ?? false)
                    ? Math.round(device.healthPercentage ?? 0) : -1,
                parts: []
            });
        }

        // AND ONLY WHILE THEY ARE ACTUALLY CONNECTED. The file is written by a
        // script on a three-minute timer, so on its own it is up to three
        // minutes stale -- and the way that showed up was earphones put back
        // in their case with their charge still sitting on the bar, which is
        // a reading that says "connected" when they are not. The script now
        // deletes the file, and this is the other half: BlueZ knows the
        // instant they go, so the row goes with them and the file catches up
        // whenever it likes.
        //
        // Matched on the NAME because that is all there is to match on:
        // Quickshell's BluetoothDevice exposes no UUID list, so the AAP
        // vendor UUID the script identifies them by is not reachable from
        // here. Both strings come from BlueZ's own Alias, so they agree.
        if (root.airpods && root.airpodsConnected) {
            // THE BAR CARRIES THE LOWER EARPHONE. One number has to stand for
            // three, and the useful one is the one that runs out first --
            // saying 80% while the other bud is at 20% is worse than saying
            // nothing at all. The panel has all of them.
            //
            // The CASE is deliberately not part of that minimum: it is not
            // going to cut out mid-call, and a case at 10% in a bag would keep
            // the bar red over earphones that are perfectly fine.
            // Only the ones that answered: a bud still in the case reports 0
            // and would otherwise drag the bar to zero over an earphone that
            // is merely not in use.
            const live = root.airpods.parts.filter(p => p.available);
            const buds = live.filter(p => p.label !== "case");
            const measured = buds.length > 0 ? buds : live;
            const lowest = measured.reduce((a, b) => a.charge <= b.charge ? a : b);

            out.push({
                key: "airpods",
                glyph: Icons.headphones,
                charge: lowest.charge,
                charging: root.airpods.parts.filter(p => p.available).every(p => p.charging),
                label: root.airpods.name,
                stateText: lowest.stateText,
                remaining: "",
                health: -1,
                parts: root.airpods.parts
            });
        }

        return out.sort((a, b) => a.charge - b.charge);
    }

    readonly property bool airpodsConnected: {
        if (!root.airpods)
            return false;

        // Read so the binding re-evaluates when something connects or goes.
        Bluetooth.devices.values.length;

        return Bluetooth.devices.values.some(d => d.connected
            && (d.name === root.airpods.name || d.deviceName === root.airpods.name));
    }

    // A PLAIN PROPERTY AND NOT `visible` FOR THE PARENT TO READ. The pill
    // around this has to disappear along with it, and hanging its `visible`
    // off this item's own `visible` is a binding loop -- Qt detects it, drops
    // the binding, and the result is a battery that never appears at all with
    // nothing in the log to say why. That is exactly what happened the first
    // time. This says the same thing without involving visibility.
    readonly property bool hasAny: root.entries.length > 0

    // ---------------- When to start worrying ----------------
    //
    // TWO LEVELS, AND ONLY THE LOWER ONE SHOUTS. Under 30% the number goes
    // amber and nothing else happens: it is a heads-up, and a bar that changes
    // colour every time something drops below a third would be noise. Under
    // 15% the reading tints red and a notification goes out once -- that is
    // the point where the thing will actually stop working during whatever you
    // are doing.
    //
    // CHARGING BEATS BOTH. A mouse on its cable at 8% is not a problem, and
    // colouring it as one is how a warning stops being believed.
    readonly property int alertBelow: 15
    readonly property int warnBelow: 30

    // Higher than alertBelow on purpose. A battery sitting exactly on the
    // threshold flickers across it as the reading settles, and without a gap
    // between "start warning" and "stop warning" that flicker is a
    // notification every few minutes.
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

    // ONE DEVICE IS A DIFFERENT PICTURE FROM TWO, and the pill around this
    // reads it. With a single peripheral there is nothing to tell apart, so
    // the whole group takes the colour and the reading inside it stays plain
    // -- a tinted pill inside a tinted pill is two edges saying one thing.
    // With two or more the tint has to be on the row that is actually low,
    // because "one of these is nearly flat" is only useful if it says which.
    readonly property bool alertingAlone: root.entries.length === 1
        && root.isAlerting(root.entries[0].charge, root.entries[0].charging)

    // ---------------- The alert ----------------
    //
    // KEYED AND HELD ON THE WIDGET, not in the delegate. The list is sorted by
    // how empty each thing is, so the delegates are destroyed and rebuilt
    // whenever a percentage changes -- which is exactly when this state
    // matters. A flag stored in the row would be thrown away by the same event
    // that should have set it, and the notification would go out again every
    // few minutes.
    property var alerted: ({})

    function considerAlert(entry: var): void {
        const key = entry?.key ?? "";
        if (key === "")
            return;

        // Back above the re-arm line, or on a cable: forget it happened, so
        // the next time it runs down there is a warning again.
        if (entry.charging || entry.charge >= root.rearmAt) {
            if (root.alerted[key]) {
                const next = Object.assign({}, root.alerted);
                delete next[key];
                root.alerted = next;
            }
            return;
        }

        if (entry.charge > root.alertBelow || root.alerted[key])
            return;

        const next = Object.assign({}, root.alerted);
        next[key] = true;
        root.alerted = next;

        // notify-send and not a call into this shell's own notification model:
        // the shell IS the notification daemon, so this goes out over the bus
        // and comes straight back in as an ordinary notification -- which
        // means it looks like every other one, stacks with them, and obeys
        // do-not-disturb. A private code path would bypass all three.
        //
        // Critical urgency, which is what makes it outlive its timeout: see
        // the header of NotificationCard.qml. A warning that disappears while
        // you are looking at the other monitor has not warned anybody.
        Quickshell.execDetached(["notify-send",
            "--urgency=critical",
            "--app-name=Battery",
            `${entry.label} is at ${entry.charge}%`,
            "Put it on the cable before it stops."]);
    }

    // Which entry the panel is about. A KEY and not the object: `entries` is
    // rebuilt on every reading, so a stored object would be a snapshot of the
    // charge at the moment it was clicked and the panel would stop moving.
    property string shownKey: ""

    readonly property var shownEntry: {
        for (const entry of root.entries)
            if (entry.key === root.shownKey)
                return entry;
        return null;
    }

    visible: root.hasAny

    spacing: Theme.itemSpacing

    Repeater {
        model: root.entries

        delegate: Rectangle {
            id: entry

            required property var modelData

            readonly property bool alerting: root.isAlerting(entry.modelData.charge, entry.modelData.charging)
            readonly property color tint: root.tintFor(entry.modelData.charge, entry.modelData.charging)

            // Every reading, not only the ones that cross the line: the check
            // has to see the value climb back up as well, or it never re-arms.
            // The delegate is rebuilt on each reading, which is what makes
            // this enough on its own.
            Component.onCompleted: root.considerAlert(entry.modelData)

            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: reading.implicitWidth + 12
            implicitHeight: Theme.groupHeight - 8
            radius: height / 2

            // A pill under the pointer, which the bare glyph did not have: the
            // reading is a button and has to look like one before it is
            // touched.
            //
            // AND A TINTED ONE WHEN IT IS NEARLY FLAT. Colouring the text
            // alone was not enough -- a red number among white ones on a bar
            // full of other marks is something you notice on the second look
            // -- but the first attempt filled the pill with solid critical and
            // that was worse: on a bar where everything else is a translucent
            // pill over glass, one opaque red block reads as an error dialog
            // that got loose. 0.18 is the same alpha, chosen the same way, as
            // the settings window's sidebar.
            //
            // Suppressed when this is the only device, because the group
            // behind it has taken the colour instead and doing both stacks one
            // tint on the other into something twice as loud as either.
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

                    text: entry.modelData.glyph
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: entry.tint

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: `${entry.modelData.charge}%`
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
                    root.shownKey = entry.modelData.key;
                    root.popout.toggleAt(entry.mapToItem(null, entry.width / 2, 0).x, detailComponent);
                }
            }
        }
    }

    Component {
        id: detailComponent

        // ---------------- The panel ----------------
        //
        // EVERYTHING THERE IS TO SAY, which is the point of it: the bar can
        // only carry one number, and the questions that number raises -- what
        // is it, is it charging, how long have I got, and for earphones WHICH
        // of the three the bar is showing -- all have answers, a click away
        // rather than in a tooltip that cannot be read at leisure.
        Column {
            id: detail

            readonly property var entry: root.shownEntry

            // Wide enough for a long product name on two lines rather
            // than three. Measured against the longest thing connected
            // here, "DualSense Wireless Controller".
            width: 300
            spacing: Theme.itemSpacing
            visible: detail.entry !== null

            Row {
                id: heading

                width: parent.width
                spacing: Theme.itemSpacing

                Text {
                    id: headingGlyph

                    anchors.verticalCenter: parent.verticalCenter

                    text: detail.entry?.glyph ?? ""
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize + 6
                    color: root.tintFor(detail.entry?.charge ?? 0, detail.entry?.charging ?? false)
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // GIVEN A WIDTH RATHER THAN LEFT TO FIND ONE. A Row hands
                    // every child whatever it asks for, so a Column of Text
                    // asks for the width of its longest line and gets it --
                    // and "DualSense Wireless Controller" ran straight out of
                    // the panel. Nothing about the Row being width-bound
                    // reaches its children on its own.
                    width: heading.width - headingGlyph.width - heading.spacing

                    Text {
                        width: parent.width
                        // WRAPPED AND NOT ELIDED, unlike the line under it.
                        // This is the device's identity -- "DualSense
                        // Wireless Cont..." is the one thing on the panel
                        // that must not be guessed at, and a second line
                        // costs nothing here.
                        wrapMode: Text.WordWrap

                        // The manufacturer's own name for it. Nothing else on
                        // this desktop prints it, which is half the reason the
                        // panel exists: with two wireless things connected,
                        // the model is how you know WHICH one the bar is
                        // worried about.
                        text: detail.entry?.label ?? ""
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Bold
                        color: Theme.textOnSurface
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight

                        text: `${detail.entry?.charge ?? 0}%  ·  ${detail.entry?.stateText ?? ""}`
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }

            // The bar the panel can afford and the one on the bar cannot: at
            // this width the number has room to be a picture too.
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (detail.entry?.charge ?? 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.tintFor(detail.entry?.charge ?? 0, detail.entry?.charging ?? false)

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }

            // ---------------- The pieces, when a thing has pieces ----------
            //
            // ONLY EARPHONES HAVE THESE, and they are the reason the panel is
            // worth opening for them at all: the bar shows the lower of the
            // two buds, and "which one, and how is the case doing" is exactly
            // what that number leaves out. A mouse has one battery and gets no
            // list, because a list of one is a heading.
            //
            // ONLY THE ONES THAT ANSWERED. This went back and forth twice and
            // the second answer is the right one. Dropping an absent component
            // reads as the panel forgetting the case exists -- so it was shown
            // saying "not connected", and that turned out worse: the case is
            // out of range for as long as the earphones are being worn, so
            // that row is permanent furniture that never once tells you
            // anything. It is the same rule the whole widget follows, which is
            // that a reading with nothing to say should not be on screen.
            Repeater {
                model: (detail.entry?.parts ?? []).filter(p => p.available)

                delegate: Item {
                    id: part

                    required property var modelData

                    width: detail.width
                    implicitHeight: 22

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        // "left", "right", "case" as the script writes them,
                        // capitalised here rather than there: the file is data
                        // and this is the only place it is read aloud.
                        text: part.modelData.label.charAt(0).toUpperCase()
                            + part.modelData.label.slice(1)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        color: Theme.textOnSurfaceVariant
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: part.modelData.charging
                            ? `${part.modelData.charge}%  ·  charging`
                            : `${part.modelData.charge}%`
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Theme.fontWeight
                        color: root.tintFor(part.modelData.charge, part.modelData.charging)
                    }
                }
            }

            Text {
                visible: (detail.entry?.remaining ?? "") !== ""

                width: parent.width
                text: detail.entry?.remaining ?? ""
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurfaceVariant
            }

            Text {
                visible: (detail.entry?.health ?? -1) >= 0

                width: parent.width
                text: `Battery health ${detail.entry?.health ?? 0}%`
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurfaceVariant
            }
        }
    }
}
