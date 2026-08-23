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
// ONE PHYSICAL PERIPHERAL, ONE ROW, WHICH IS NOT ONE UPower DEVICE. Plug the
// Logitech mouse in to charge and UPower grows a SECOND battery for it: the
// wireless one behind the Lightspeed receiver, and a new one for the cable.
// Same charge, same serial, different native-path -- and the bar drew both,
// the second one wearing a keyboard glyph. That glyph was faithful. UPower
// types every enumeration from the HID interface it attached to, and the
// wired interface of this mouse advertises a keyboard collection for its
// buttons, so UPower says keyboard and means it. The device was double, not
// the type.
//
// SO THEY ARE MERGED ON THE KERNEL'S OWN IDENTITY FOR THE HARDWARE: the
// manufacturer, the model and the serial exactly as they sit in
// /sys/class/power_supply/<native-path>/uevent, which is where UPower read
// them in the first place. Not the model NAME -- see the paragraph above.
// Nothing here recognises a string; it only compares two of them, and the
// serial has to be present for a merge to be possible at all. All three have
// to agree, so two devices collapse only when every word the kernel has about
// them is the same word. Anything less keeps its own row, which is the safe
// way to be wrong: a duplicate is visible and annoying, a wrong merge hides a
// device.
//
// READ OUT OF sysfs BECAUSE IT IS NOT ON THE OBJECT. Quickshell's UPowerDevice
// carries type, state, percentage, model and native-path and no serial at all,
// so the one field that ties the two entries together cannot be reached from
// the device -- but native-path IS the kernel's name for the power supply, and
// the uevent beside it has all three fields. Roughly 7 us a read, measured
// over a thousand of them, once per device per reading.
//
// IT IS ONLY THERE WHEN THERE IS SOMETHING TO SAY. No peripheral, no glyph --
// a permanent empty slot on the bar is worse than the reading being absent,
// because the eye learns to skip the place where it lives.

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import qs
import qs.modules.bar
import ".."

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

    // Charging OR full: something sitting on its cable at 100% is still on its
    // cable, and every rule below that asks "is this the wired one" is asking
    // this question.
    function isCharging(device: var): bool {
        return device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged;
    }

    // ---------------- Which devices are the same device ----------------

    // native-path -> the kernel's identity for whatever is behind it, or "".
    //
    // AND FILLED IN HERE RATHER THAN WHERE IT IS USED, which is not a matter
    // of taste. Reading a FileView from inside a binding makes that FileView's
    // path and text into dependencies OF THAT BINDING, so a loop that points
    // one FileView at each device's file in turn marks its own binding dirty
    // on every device and re-runs it forever -- a shell pinned at 100% of a
    // core with nothing on screen to say why. The reads happen in a handler,
    // the binding reads this map, and the map is reassigned only when it has
    // actually changed so that the rows are not rebuilt for nothing.
    property var identities: ({})

    onUpowerDevicesChanged: root.relearnIdentities()
    // The handler above covers every device that arrives later; this covers
    // the ones that were already there when the shell started, whose binding
    // may well have settled before anything was listening.
    Component.onCompleted: root.relearnIdentities()

    function relearnIdentities(): void {
        const learned = {};
        let changed = false;

        for (const device of root.upowerDevices) {
            const path = device.nativePath;
            if (!path)
                continue;

            learned[path] = root.identityOf(path);
            if (root.identities[path] !== learned[path])
                changed = true;
        }

        if (changed || Object.keys(learned).length !== Object.keys(root.identities).length)
            root.identities = learned;
    }

    // The kernel's own identity for the hardware behind a power supply --
    // manufacturer, model and serial, joined on a byte none of them can
    // contain. "" is this saying "do not merge me", and it says it whenever
    // there is no serial to anchor the answer.
    function identityOf(nativePath: string): string {
        if (!nativePath)
            return "";

        // UPower's native-path is the kernel's name for the power supply for
        // everything that IS one. For a Bluetooth battery it is a bluez object
        // path instead, and for the rest it is something else again -- in
        // every one of those cases this file does not exist, the read fails
        // quietly, and the device keeps its own row.
        ueventFile.path = `/sys/class/power_supply/${nativePath}/uevent`;
        // RELOADED AND NOT MERELY READ. The path is the same string on every
        // pass for a device that stays where it is, and a FileView asked for a
        // path it already holds hands back what it read the first time -- for
        // as long as the shell runs, including after the kernel has recycled
        // that name onto different hardware. A stale identity is a wrong
        // merge, which is the one outcome worth paying 7 us to avoid.
        ueventFile.reload();

        const fields = {};
        for (const line of (ueventFile.text() || "").split("\n")) {
            const eq = line.indexOf("=");
            if (eq > 0)
                fields[line.slice(0, eq)] = line.slice(eq + 1).trim();
        }

        const serial = fields["POWER_SUPPLY_SERIAL_NUMBER"] || "";
        if (serial === "")
            return "";

        return [fields["POWER_SUPPLY_MANUFACTURER"] || "",
                fields["POWER_SUPPLY_MODEL_NAME"] || "",
                serial].join("\u0000");
    }

    FileView {
        id: ueventFile

        // Read synchronously, the same way SessionInfo reads /proc/uptime and
        // for the same reason: the caller wants the answer in the expression
        // it asked in. It is two hundred bytes of sysfs.
        blockLoading: true
        // Absent for every device that is not a power supply, which is not an
        // error and must not print one on every reading.
        printErrors: false
    }

    // ---------------- Who speaks for a merged device ----------------
    //
    // TWO ANSWERS, BECAUSE THE TWO ENTRIES ARE GOOD AT DIFFERENT THINGS.
    //
    // WHAT IT IS comes from the member that is NOT on the cable. The second
    // entry exists *because* something was plugged in: it is a fresh
    // enumeration of the same hardware over a different interface, and its
    // type is whatever HID class that interface advertises -- which is exactly
    // how this mouse came to be a keyboard. The member that is there with the
    // cable and without it is the one describing the peripheral, and it is
    // also the one that survives unplugging, so the glyph does not change when
    // the cable comes out.
    function compareIdentity(a: var, b: var): int {
        if (root.isCharging(a) !== root.isCharging(b))
            return root.isCharging(a) ? 1 : -1;

        // There is nothing to prefer about a type UPower does not have.
        const aTyped = a.type !== UPowerDeviceType.Unknown;
        const bTyped = b.type !== UPowerDeviceType.Unknown;
        if (aTyped !== bTyped)
            return aTyped ? -1 : 1;

        // Arbitrary, and here precisely so that it is never a coin flip:
        // without a last resort the winner would depend on the order UPower
        // happened to list them in, and the glyph could swap between readings
        // with nothing having changed.
        return root.byNativePath(a, b);
    }

    // WHAT IT IS DOING comes from the member that knows. UPowerDeviceState
    // .Unknown is UPower saying it has no reading, and the wireless side goes
    // exactly that quiet while the cable is in -- the cable's own entry is the
    // only one that can see the cable. Where both know and disagree, charging
    // wins, which is the rule the alert further down already follows and for
    // the same reason.
    function compareState(a: var, b: var): int {
        const aKnown = a.state !== UPowerDeviceState.Unknown;
        const bKnown = b.state !== UPowerDeviceState.Unknown;
        if (aKnown !== bKnown)
            return aKnown ? -1 : 1;

        if (root.isCharging(a) !== root.isCharging(b))
            return root.isCharging(a) ? -1 : 1;

        return root.byNativePath(a, b);
    }

    function byNativePath(a: var, b: var): int {
        return a.nativePath < b.nativePath ? -1 : a.nativePath > b.nativePath ? 1 : 0;
    }

    // ONE ENTRY OUT OF EVERY UPower DEVICE THAT IS THE SAME PIECE OF HARDWARE.
    // Almost always there is exactly one of them, in which case every rule in
    // here picks the only candidate and this is the old code with more words
    // around it.
    function entryFor(key: string, members: var): var {
        const identity = members.slice().sort(root.compareIdentity)[0];
        const teller = members.slice().sort(root.compareState)[0];
        const charging = root.isCharging(teller);

        // THE LONGEST NAME ANY OF THEM GIVES IT. The two here are "Logitech
        // PRO X 2" and "PRO X 2" -- one name, one of them with the maker still
        // attached -- and the longer string is never the less correct one.
        // Decided by length rather than taken from the identity winner so that
        // the label cannot change when the cable goes in.
        const label = members.reduce((best, m) =>
            (m.model || "").length > best.length ? m.model : best, "");

        // THE LOWEST OF THEM WHEN THEY DISAGREE AT ALL. There is one battery
        // behind both readings and they should agree -- both say 36% here --
        // but they are polled separately, so one can be a percent behind for a
        // cycle. The pessimistic reading is the safe one, and it is the same
        // rule the earphones below use to stand for three components at once.
        const charge = Math.round(members.reduce((low, m) =>
            Math.min(low, m.percentage ?? 0), 1) * 100);

        // From whichever one measures it, if any of them does.
        const healthy = members.find(m => m.healthSupported ?? false);

        return {
            key: key,
            glyph: root.glyphFor(identity),
            // 0..1 from UPower -- measured against `upower -i`, which prints
            // the same charge as a whole number.
            charge: charge,
            charging: charging,
            label: label || "Wireless device",
            stateText: root.stateTextOf(teller.state),
            remaining: root.remainingText(
                charging ? (teller.timeToFull ?? 0) : (teller.timeToEmpty ?? 0), charging),
            // The same estimate again, unformatted, for the notification.
            // BatteryAlerts words that one itself -- taking `remaining` would
            // be taking a sentence written for the panel, which is how the two
            // battery widgets ended up saying the same thing two different
            // ways in the first place.
            secondsLeft: charging ? 0 : (teller.timeToEmpty ?? 0),
            health: healthy ? Math.round(healthy.healthPercentage ?? 0) : -1,
            parts: []
        };
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

            // THREE FIELDS FROM HERE DOWN, and the guard above is not enough
            // on its own: it lets a two-field line through and the state is
            // read out of fields[2] a few lines below, where `undefined !==
            // "disconnected"` is true and the component is reported as
            // connected and in use. The one line that legitimately has two
            // fields is `name`, which has just been dealt with.
            //
            // Latent rather than live: `airpods-battery` writes
            // "<component>\t<level>\t<state>" for every component it found
            // and "name\t<alias>" for the alias, so nothing it produces today
            // takes this path. What does is a half-written file -- the writer
            // replaces it atomically, so that would have to be something else
            // -- or the day a component reports a level with no state.
            if (fields.length < 3)
                continue;

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

        // GROUPED BEFORE ANY OF THEM IS DRAWN. See the header: one peripheral
        // can be two UPower devices, and the key is the thing that says so.
        //
        // AND IT IS THE SAME KEY WIRED OR WIRELESS, which matters further down
        // more than it matters here. BatteryAlerts remembers, under this
        // string, that it has already shouted about a device -- and the string
        // used to be the native-path, so a mouse put on its cable acquired a
        // second one and became, to that map, a device it had never seen. Both
        // entries now reduce to the hardware's own identity, the survivor
        // keeps that identity when the cable comes out, and `shownKey` holds
        // the panel open on it across the whole transition.
        const groups = [];
        const slotOf = ({});

        for (let i = 0; i < root.upowerDevices.length; i++) {
            const device = root.upowerDevices[i];
            const identity = root.identities[device.nativePath] || "";

            // THREE KINDS OF KEY AND ONLY THE FIRST MERGES ANYTHING. A device
            // whose kernel identity cannot be read falls back to its own
            // native-path, which is unique per UPower device, so it stands
            // alone -- which is what should happen when there is nothing to
            // prove it is a duplicate of anything. The third is for a device
            // with no native-path either: keyed on its place in the list,
            // which is not stable across another device coming or going, and
            // that costs at worst a repeated notification. Two nameless
            // devices sharing one key would cost one of them disappearing.
            const key = identity !== "" ? `serial:${identity}`
                : device.nativePath ? `path:${device.nativePath}`
                : `slot:${i}`;

            if (slotOf[key] === undefined) {
                slotOf[key] = groups.length;
                groups.push({ key: key, members: [device] });
            } else {
                groups[slotOf[key]].members.push(device);
            }
        }

        for (const group of groups)
            out.push(root.entryFor(group.key, group.members));

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
                // AAP carries a percentage and a charging flag and no estimate
                // at all, so the notification falls back to its instruction.
                secondsLeft: 0,
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
    // Only the amber one is decided here. Where the shouting starts, where it
    // re-arms, and whether a given reading is shouting-worthy all live in
    // BatteryAlerts now: the machine's own battery widget asks the same
    // questions, and the answers had been written out twice.
    readonly property int warnBelow: 30

    function isAlerting(charge: int, charging: bool): bool {
        return BatteryAlerts.isAlerting(charge, charging);
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

    // `alertingAlone` USED TO LIVE HERE AND IT WENT WITH THE PILL. It answered
    // one question -- does the tint belong on the group's background or on the
    // one row that is actually low -- and under this theme there is no group
    // background to tint: each reading is its own taskbar item and each one
    // carries its own colour. Bar.qml read it too, to tint the pill it no
    // longer draws.

    // ---------------- The alert ----------------
    //
    // KEYED, AND NOT KEPT HERE ANY MORE. The reasoning that took it off the
    // delegate still holds -- the list is sorted by how empty each thing is,
    // so the rows are destroyed and rebuilt whenever a percentage changes,
    // which is exactly when this state matters -- and it did not go far
    // enough. A flag on the WIDGET is one flag per Bar, and shell.qml builds a
    // Bar per screen: two monitors carrying a bar meant two critical
    // notifications, which do not expire, for one mouse going flat.
    //
    // So it lives in BatteryAlerts, which exists once per shell process. This
    // hands over a reading; being called again with the same reading from the
    // other bar is a no-op there.
    function considerAlert(entry: var): void {
        if (!entry)
            return;

        BatteryAlerts.consider({
            key: entry.key,
            label: entry.label,
            charge: entry.charge,
            charging: entry.charging,
            secondsLeft: entry.secondsLeft
        });
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

    // ---------------- What is on the bar ----------------
    //
    // ONE TASKBAR ITEM PER PERIPHERAL: a glyph, a percentage, a 4px box that
    // washes under the pointer and opens the panel. Genesis draws each of these
    // as a capsule and tints the capsule when the thing is nearly flat; Windows
    // has no capsule in its notification area and no coloured backplate
    // anywhere in it, so the alert is carried by the ink instead -- see tintFor
    // above, which already returns Theme.critical for exactly that case and did
    // not have to change.
    Repeater {
        model: root.entries

        TaskbarItem {
            id: entry

            required property var modelData

            readonly property color tint: root.tintFor(entry.modelData.charge, entry.modelData.charging)

            Component.onCompleted: root.considerAlert(entry.modelData)

            anchors.verticalCenter: parent.verticalCenter

            boxWidth: reading.implicitWidth + Theme.barPadding * 2

            // A door, unlike the machine's own battery beside it: there is a
            // panel behind this with the parts, the estimate and the health in
            // it, so it takes clicks and washes to say so.
            onActivated: {
                root.shownKey = entry.modelData.key;
                root.popout.toggleAt(entry.mapToItem(null, entry.width / 2, 0).x, detailComponent);
            }

            Row {
                id: reading

                anchors.centerIn: parent
                spacing: Theme.itemSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: entry.modelData.glyph
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: entry.tint
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: `${entry.modelData.charge}%`
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.captionSize
                    font.weight: Fluent.normalWeight
                    font.features: ({ "tnum": 1 })
                    color: entry.tint
                }
            }
        }
    }

    // ---------------- What is in the panel ----------------
    //
    // The heading, the bar, the pieces, the estimate and the health. It is the
    // same content genesis showed and the same order; what changed is the type
    // ramp -- Body for the name, Caption for everything under it, Semibold and
    // never Bold, which is Windows 11's typography rule in as many words.
    Component {
        id: detailComponent

        Column {
            id: detail

            readonly property var entry: root.shownEntry

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

                    width: heading.width - headingGlyph.width - heading.spacing

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap

                        text: detail.entry?.label ?? ""
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        font.weight: Fluent.strongWeight
                        color: Theme.textOnSurface
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight

                        text: `${detail.entry?.charge ?? 0}%  ·  ${detail.entry?.stateText ?? ""}`
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }

            // The bar the panel can afford and the one in the taskbar cannot: at
            // this width the number has room to be a picture too. WinUI's own
            // ProgressBar is 1px of track behind a rounded fill; this is thicker
            // because it is being read across a room rather than inside a form.
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
                        NumberAnimation {
                            duration: Fluent.fastMs
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Fluent.easeOut
                        }
                    }
                }
            }

            // ---------------- The pieces, when a thing has pieces ----------
            //
            // ONLY EARPHONES HAVE THESE, and they are the reason the panel is
            // worth opening for them at all: the bar shows the lower of the two
            // buds, and "which one, and how is the case doing" is exactly what
            // that number leaves out. A mouse has one battery and gets no list,
            // because a list of one is a heading.
            //
            // ONLY THE ONES THAT ANSWERED. Dropping an absent component reads as
            // the panel forgetting the case exists; showing it with a dash reads
            // as a fault. What is actually true is that nothing was heard from
            // it, and a row that is not there says that better than a row that
            // is there saying nothing.
            Repeater {
                model: (detail.entry?.parts ?? []).filter(p => p.available)

                Item {
                    id: part

                    required property var modelData

                    width: detail.width
                    implicitHeight: 22

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        text: part.modelData.label.charAt(0).toUpperCase()
                            + part.modelData.label.slice(1)
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        color: Theme.textOnSurfaceVariant
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: part.modelData.charging
                            ? `${part.modelData.charge}%  ·  charging`
                            : `${part.modelData.charge}%`
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        font.weight: Fluent.strongWeight
                        font.features: ({ "tnum": 1 })
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
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }

            Text {
                visible: (detail.entry?.health ?? -1) >= 0

                width: parent.width
                text: `Battery health ${detail.entry?.health ?? 0}%`
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }
    }
}
