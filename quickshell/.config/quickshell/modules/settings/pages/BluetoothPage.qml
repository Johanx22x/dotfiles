// The bluetooth page: the radio, the devices already paired, and whatever
// else is in the air.
//
// The island's BluetoothControl lists ONLY paired devices, and its header says
// why: discovery has a different rhythm, it fills the list with strangers'
// headphones, and pairing asks questions. This page is where that job was
// sent -- the same relationship NetworkPage has with WifiControl.
//
// EXCEPT THAT ONE THIRD OF IT CANNOT BE DELIVERED, and the page says so
// instead of pretending. Read out of the module's own type registration
// (/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes),
// BluetoothDevice exports exactly five methods -- connect, disconnect, pair,
// cancelPair, forget -- plus a read-only `pairing` flag. There is no agent
// type in the module and no signal carrying a pairing request. So a device
// that answers pair() with "type the PIN" or "do these numbers match?" has
// nowhere on this page to be answered, and the attempt just sits there until
// BlueZ gives up. Only "just works" pairing can complete here. The note in the
// last section says that out loud rather than leaving it to be discovered as a
// failure.
//
// Everything else comes off Quickshell's BlueZ backend: nothing is polled and
// no bluetoothctl is spawned to read state. `bluetoothctl show` was used to
// check what this adapter actually reports -- including the 60-second
// DiscoverableTimeout the visibility row explains -- but the only bluetoothctl
// that runs from this file is the one the user asks for by name.

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only -- without this line the root element below is an
// unknown type and the page fails to load. The other imports are the
// shell-wide ones every file here takes.
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Bluetooth"
    glyph: Icons.bluetooth
    // The words someone would type and expect to land here, including the ones
    // that appear nowhere on the page. "airpods" is in because it is what the
    // one paired device on this machine is called, and nobody searching for it
    // will type "audio sink"; "gamepad" and "mouse" because the thing you go
    // looking for is the object on the desk, not the word "device".
    keywords: ["bluetooth", "bt", "pair", "pairing", "headphones", "headset", "airpods", "controller", "gamepad", "mouse", "keyboard", "speaker", "device"]

    // ---------------- Glyphs that are not in Icons yet ----------------
    //
    // TEMPORARY, and they belong in Icons.qml -- they are here only because
    // that file is being edited elsewhere right now. Move them when it is
    // free; nothing else about them should change.
    //
    // Every codepoint below was read out of the installed font's cmap rather
    // than looked up by name, which is the rule that file's own comments set
    // after two of its entries turned out to be a bluetooth speaker and a
    // shower head:
    //
    //   python3 -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap()[0xF0208])"
    //
    // Solid eye, not md-eye_outline (0xF06D0). It sits in the same card as the
    // bluetooth mark on the row above it, and an outlined glyph next to a solid
    // one reads as the disabled version of it rather than as a different thing
    // -- the call the `settings` glyph in Icons.qml already makes, for the same
    // reason.
    readonly property string eye: String.fromCodePoint(0xF0208)         // nf-md-eye

    // The device-type marks. Icons already has headphones, headset, gamepad
    // and keyboard; these four are what is missing to cover the rest of what
    // BlueZ hands out.
    readonly property string mouse: String.fromCodePoint(0xF037D)       // nf-md-mouse
    readonly property string speaker: String.fromCodePoint(0xF04C3)     // nf-md-speaker
    readonly property string cellphone: String.fromCodePoint(0xF011C)   // nf-md-cellphone
    readonly property string laptop: String.fromCodePoint(0xF0322)      // nf-md-laptop

    // ---------------- The adapter ----------------
    //
    // May be null, and not only on a machine with no bluetooth: BlueZ arrives
    // over D-Bus, so at the moment this page is built there is often no adapter
    // yet. Every read below tolerates that rather than guarding it once.
    readonly property var adapter: Bluetooth.defaultAdapter

    // NOT called `state`. Item already has a `state` -- the string naming the
    // current State block -- and shadowing it on the page root is how you get a
    // page whose transitions silently stop working.
    readonly property int adapterState: root.adapter?.state ?? BluetoothAdapterState.Disabled
    readonly property bool radioOn: root.adapter?.enabled ?? false

    // Paired first by connection, then by name: the row worth clicking is at
    // the top whether you came to connect or to disconnect. `bonded` is
    // accepted alongside `paired` because they are not the same bit in BlueZ --
    // a device can be paired without the keys having been stored -- and a
    // device in either state is one this machine already knows.
    readonly property var pairedDevices: {
        const all = Bluetooth.devices?.values ?? [];
        return all.filter(d => d.paired || d.bonded).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return root.displayName(a).localeCompare(root.displayName(b));
        });
    }

    // Everything else the scan turned up. NAMED ONES FIRST, and the unnamed
    // ones are kept rather than filtered out: most of them are LE beacons
    // nobody came here to pair, but a device that has not answered the name
    // request yet is indistinguishable from one, and hiding the headset you are
    // holding because it was half a second slow is the worse failure. Sorting
    // them to the bottom costs nothing and does the same job.
    readonly property var availableDevices: {
        const all = Bluetooth.devices?.values ?? [];
        return all.filter(d => !d.paired && !d.bonded).sort((a, b) => {
            const an = a.name || a.deviceName || "";
            const bn = b.name || b.deviceName || "";
            if ((an !== "") !== (bn !== ""))
                return an !== "" ? -1 : 1;
            return an.localeCompare(bn) || (a.address ?? "").localeCompare(b.address ?? "");
        });
    }

    // ---------------- Discovery lifetime ----------------
    //
    // THE PAGE'S OWN `visible`, AND THAT IS THE WHOLE TRAP. The settings window
    // builds every page at startup and keeps them all alive, showing one at a
    // time -- see the note above the Flickable in Settings.qml about why a
    // Loader was rejected. So a page nobody is looking at is still fully
    // constructed with its bindings live, and would happily leave the adapter
    // scanning forever if this were tied to anything else.
    //
    // It has to go off when the page is left, and this is not a tidiness
    // argument. A discovering adapter keeps the radio transmitting inquiry
    // scans, which costs power on both ends -- a connected headset's battery
    // included -- and it keeps appending every LE beacon in range to
    // Bluetooth.devices, so the list the user comes back to is longer and
    // worse every minute it was left running.
    //
    // `Component.onCompleted` is therefore wrong (it fires once, for a page
    // nobody is looking at), and so is the window being open: the other pages
    // are open too. The only thing that tracks "someone is actually reading
    // this list" is this item's own visible flag, which the window drives from
    // the selected page.
    //
    // A Binding and not an onVisibleChanged handler, for the reason NetworkPage
    // gives about its scanner: the adapter arrives over D-Bus and can appear
    // AFTER the page is built, and a handler that already fired would never
    // notice. A binding re-evaluates when `adapter` stops being null -- and
    // also when the radio is switched off, which is the other way this would
    // otherwise be left writing to a dead adapter.
    Binding {
        target: root.adapter
        property: "discovering"
        value: root.visible && root.radioOn && root.scanning
    }

    // The scan switch in the last section writes this, not `discovering`
    // directly: the binding above owns that property, and a second writer to it
    // would be overwritten on the next re-evaluation. Starts true so opening
    // the page starts looking -- which is the only reason anyone opens it --
    // and the switch is there to stop it without leaving.
    property bool scanning: true

    // ---------------- List ceiling ----------------
    //
    // Both lists, one number. The count of rows is decided by whatever the air
    // happens to be carrying, so a card that grows to fit them is a card whose
    // height is set by the neighbours -- and here it would also set the height
    // of the window, which would then resize on the way to this page.
    //
    // 180 is five rows: enough to see the top of a list that is already sorted
    // so the useful rows are at the top. The network page's 200 is the same
    // decision made for a taller row; the two pages agree on the shape of the
    // rule, not on the number.
    readonly property int listCeiling: 180

    // ---------------- Names ----------------
    //
    // `||` AND NOT `??`, which is the trap in this particular API. Both `name`
    // and `deviceName` are QString in the type registration, so a device that
    // has not reported a name arrives as an EMPTY STRING, not as null or
    // undefined -- and `??` only falls through on those two. Written with `??`
    // this returns "" and the row draws a blank line where the device should
    // be. The island's BluetoothControl has the same expression in it and the
    // same hole; this is the version to copy.
    // The parameter carries no type annotation, unlike every other function on
    // this page: `device: var` is what it would want to say, and qmlformat
    // cannot parse that annotation -- no other file here uses one either. An
    // unannotated parameter costs nothing and keeps the file in the same
    // syntactic class as its neighbours.
    function displayName(device): string {
        if (!device)
            return "";
        return device.name || device.deviceName || device.address || "Unknown device";
    }

    // BlueZ derives `icon` from the device's class-of-device field, so the
    // strings are its own small fixed vocabulary rather than anything this
    // shell chose. Only the ones worth telling apart at a glance are listed:
    // everything unrecognised falls back to the bluetooth mark, so a value not
    // handled here costs a generic glyph and nothing else -- which is why this
    // is a short list and not an attempt at the whole table.
    function deviceGlyph(icon: string): string {
        switch (icon) {
        case "audio-headset":
            return Icons.headset;
        case "audio-headphones":
            return Icons.headphones;
        case "audio-card":
        case "multimedia-player":
            return root.speaker;
        case "input-gaming":
            return Icons.gamepad;
        case "input-keyboard":
            return Icons.keyboard;
        case "input-mouse":
        case "input-tablet":
            return root.mouse;
        case "phone":
            return root.cellphone;
        case "computer":
            return root.laptop;
        default:
            return Icons.bluetooth;
        }
    }

    // ---------------- Radio ----------------
    SettingsSection {
        width: parent.width
        title: "Adapter"

        ToggleRow {
            glyph: Icons.bluetooth
            label: "Bluetooth"
            checked: root.radioOn

            // Dimmed for the two states that PERSIST and cannot be clicked out
            // of, and deliberately not for Enabling/Disabling. Powering a
            // controller up takes about a second, and greying the row for that
            // second reads as a glitch rather than as information; the caption
            // below says what is happening instead. Blocked, by contrast, lasts
            // until something outside this window is touched.
            enabled: root.adapter !== null && root.adapterState !== BluetoothAdapterState.Blocked

            onToggled: value => {
                if (root.adapter)
                    root.adapter.enabled = value;
            }
        }

        // ONE Text and not one per case. The four states below differ in
        // urgency and in nothing else -- same place, same width, same wrap --
        // so splitting them would be four near-identical blocks whose only
        // real difference is a colour, which is what the colour binding is.
        Text {
            visible: text !== ""

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 2
            bottomPadding: 6

            text: {
                if (!root.adapter)
                    return "No Bluetooth adapter found.";

                switch (root.adapterState) {
                case BluetoothAdapterState.Blocked:
                    // Two different blocks with the same name in BlueZ, and
                    // only one of them has a fix that can be typed, so both are
                    // named: telling someone to run rfkill when the switch on
                    // the side of the machine is off wastes the one instruction
                    // they were given.
                    return "The adapter is blocked. `rfkill unblock bluetooth` clears a soft block; "
                        + "a hardware switch or key has to clear a hard one.";
                case BluetoothAdapterState.Enabling:
                    return "Turning on…";
                case BluetoothAdapterState.Disabling:
                    return "Turning off…";
                default:
                    return "";
                }
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: !root.adapter || root.adapterState === BluetoothAdapterState.Blocked
                ? Theme.warning
                : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // Only when the radio is on, because it is the radio's own setting:
        // shown while the adapter is off it would be a switch that silently
        // does nothing, and BlueZ resets discoverable on power-up anyway.
        ToggleRow {
            visible: root.radioOn

            glyph: root.eye
            label: "Visible to other devices"
            checked: root.adapter?.discoverable ?? false

            onToggled: value => {
                if (root.adapter)
                    root.adapter.discoverable = value;
            }
        }

        // THIS SWITCH TURNS ITSELF BACK OFF, and without this line that looks
        // like a bug in the window. BlueZ expires discoverability on its own
        // timer -- `bluetoothctl show` on this adapter reports
        // DiscoverableTimeout 0x3c, sixty seconds -- and when it does, the
        // property changes underneath and the switch visibly flips back.
        //
        // The number is read from the adapter rather than written here: it is
        // BlueZ's setting, changeable with `bluetoothctl discoverable-timeout`,
        // and a hardcoded "60" would be a sentence in a settings window that
        // quietly stops being true. Zero means it never expires, which is a
        // different sentence rather than "0 seconds".
        //
        // Setting discoverableTimeout to 0 from here was the other option and
        // is not taken: leaving a machine permanently announcing itself is a
        // decision for the person who owns it, not a side effect of flipping a
        // switch labelled "visible".
        Text {
            visible: root.radioOn && (root.adapter?.discoverable ?? false)

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 2
            bottomPadding: 6

            text: {
                const timeout = root.adapter?.discoverableTimeout ?? 0;
                if (timeout === 0)
                    return "Visible until this is switched off again.";
                return `Visible for ${timeout} seconds — BlueZ's own timeout, not this window's. `
                    + "The switch will go back off by itself.";
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Paired ----------------
    SettingsSection {
        width: parent.width
        title: "My devices"

        // Each case is a different thing to do about it, which is why this is
        // not one "nothing here": the radio being off is fixed by the switch
        // above, and an empty list is fixed in the section below.
        Text {
            visible: text !== ""

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: {
                if (!root.adapter)
                    return "No adapter, so nothing can be paired.";
                if (!root.radioOn)
                    return "Bluetooth is off. Turn it on above to reach paired devices.";
                if (root.pairedDevices.length === 0)
                    return "Nothing paired yet. Devices you pair below appear here.";
                return "";
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ScrollList {
            id: pairedList

            width: parent.width
            height: Math.min(pairedEntries.implicitHeight, root.listCeiling)
            visible: height > 0
            contentHeight: pairedEntries.implicitHeight

            // A Repeater in a Flickable and not a ListView, the same trade
            // NetworkPage documents: ListView recycles delegates as they
            // scroll, which is right for a thousand rows and pointless for the
            // handful of devices a machine is ever paired with -- and recycling
            // is what would hand a half-hovered Forget chip to a different
            // device on the way past.
            Column {
                id: pairedEntries

                width: pairedList.width
                spacing: 2

                Repeater {
                    model: root.radioOn ? root.pairedDevices : []

                    delegate: Rectangle {
                        id: paired

                        required property var modelData

                        readonly property bool isConnected: paired.modelData?.connected ?? false

                        width: pairedEntries.width
                        implicitHeight: 36
                        radius: Theme.groupRadius

                        color: pairedMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        Text {
                            id: pairedGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.deviceGlyph(paired.modelData?.icon ?? "")
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize
                            color: paired.isConnected ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Row {
                            id: pairedNameRow

                            anchors.left: pairedGlyph.right
                            anchors.leftMargin: Theme.itemSpacing
                            anchors.right: pairedActions.left
                            anchors.rightMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                // Bounded rather than left to elide against the
                                // row: a Row hands each child whatever width it
                                // asks for, so a long device name would push
                                // the battery reading out past the right edge
                                // instead of eliding. The battery's width is
                                // subtracted only when it is showing, because
                                // an invisible child takes no space in a Row.
                                width: Math.min(implicitWidth, pairedNameRow.width - (battery.visible ? battery.width + pairedNameRow.spacing : 0))
                                elide: Text.ElideRight

                                text: root.displayName(paired.modelData)
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                                font.weight: paired.isConnected ? Font.Bold : Theme.fontWeight
                                color: paired.isConnected ? Theme.primary : Theme.textOnSurface

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }
                            }

                            // For a headset this is the single most useful
                            // number about it, which is why it sits next to the
                            // name rather than in the status column on the
                            // right where it would be competing with what a
                            // click does.
                            //
                            // Coloured only once it is worth acting on. A
                            // percentage that is amber at 90% is a percentage
                            // nobody reads by the second week, so the neutral
                            // tone carries every level that does not need
                            // anything doing about it.
                            Text {
                                id: battery

                                anchors.verticalCenter: parent.verticalCenter
                                visible: paired.modelData?.batteryAvailable ?? false

                                text: `${Math.round((paired.modelData?.battery ?? 0) * 100)}%`
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 2
                                color: {
                                    const level = paired.modelData?.battery ?? 1;
                                    if (level <= 0.15)
                                        return Theme.critical;
                                    if (level <= 0.3)
                                        return Theme.warning;
                                    return Theme.outline;
                                }

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }
                            }
                        }

                        Row {
                            id: pairedActions

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding - 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Forget. Spelled out rather than given a glyph,
                            // the same call the network page's chip makes and
                            // for the same reason: it throws away the pairing
                            // keys, and every icon that could stand for that (a
                            // bin, a cross) is also the icon for "close this".
                            // A word cannot be misread.
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter

                                implicitWidth: forgetLabel.implicitWidth + 16
                                implicitHeight: 22
                                radius: height / 2

                                color: forgetMouse.containsMouse ? Theme.critical : "transparent"
                                border.width: 1
                                border.color: forgetMouse.containsMouse ? Theme.critical : Theme.outlineVariant

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }

                                Text {
                                    id: forgetLabel

                                    anchors.centerIn: parent
                                    text: "Forget"
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSize - 2
                                    // Paired with the fill behind it, as M3
                                    // requires: on the critical red it has to
                                    // be textOnCritical, never textOnSurface.
                                    color: forgetMouse.containsMouse ? Theme.textOnCritical : Theme.textOnSurfaceVariant

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animDuration }
                                    }
                                }

                                MouseArea {
                                    id: forgetMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (paired.modelData)
                                            paired.modelData.forget();
                                    }
                                }
                            }

                            // Says what a click will do rather than repeating
                            // what the row already shows -- the accent on the
                            // name has already said "connected" to anyone
                            // looking at the list rather than reading it.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                text: {
                                    switch (paired.modelData?.state) {
                                    case BluetoothDeviceState.Connecting:
                                        return "connecting…";
                                    case BluetoothDeviceState.Disconnecting:
                                        return "disconnecting…";
                                    case BluetoothDeviceState.Connected:
                                        return "connected";
                                    default:
                                        return "connect";
                                    }
                                }

                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 2
                                color: Theme.outline

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }
                        }

                        // Behind the chip above, exactly as the island's list
                        // and the network page do it: reaching for Forget must
                        // never also connect. z: -1 puts this under every
                        // sibling, and none of the others take a click.
                        MouseArea {
                            id: pairedMouse

                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                const device = paired.modelData;
                                if (!device)
                                    return;

                                if (device.connected) {
                                    device.disconnect();
                                    return;
                                }

                                // TRUSTED ON THE WAY IN, and this is the fix
                                // for a real failure rather than a nicety. An
                                // untrusted device connects, and then BlueZ
                                // does not bring its audio profiles up on its
                                // own: the AirPods here appeared in
                                // `bluetoothctl` as connected while PipeWire
                                // had no sink for them at all, and they only
                                // became an output after a second, manual
                                // "connect the audio" from a tray menu.
                                //
                                // Deliberately connecting a device from this
                                // window IS the statement that it is trusted;
                                // making that a separate step somewhere else
                                // is asking the same question twice. The row
                                // shows the flag, so it is visible rather than
                                // magic, and Forget clears it with everything
                                // else.
                                device.trusted = true;
                                device.connect();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------- Unpaired ----------------
    SettingsSection {
        width: parent.width
        title: "Available devices"

        // THE LIMIT, IN FRONT OF THE USER, and a plain line rather than a
        // Tooltip on an info mark. Three reasons, in order of weight:
        //
        //   - A tooltip has to be hovered, so it is only found by someone who
        //     already suspects there is something to know. This is the opposite
        //     case: it has to be read BEFORE the first click, because the
        //     failure it describes is a pairing attempt that never finishes and
        //     never says why.
        //   - Tooltip.qml's own header warns that it is clipped by the first
        //     ancestor with clip: true -- the Flickable holding the pages --
        //     and calls itself "wrong for one at the very bottom". This section
        //     is the bottom of the page.
        //   - It would be explaining the section, not a row, and there is no
        //     row here for the mark to belong to.
        //
        // Kept to what someone can act on. The reason there is no agent is in
        // this file's header, where it belongs; here it only has to say what
        // will not work and where the job lives instead.
        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Pairing from this window only works for devices that pair without asking a question. "
                + "There is no way to answer a PIN or a \"do these numbers match?\" confirmation here, "
                + "so those attempts stall silently — pair them with bluetoothctl instead."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The escape hatch, and it OPENS rather than just being named --
        // WifiControl does not tell you about nm-connection-editor, it launches
        // it, and a limit is only honest if the way round it is one click away.
        //
        // `kitty -e` because bluetoothctl is a terminal program with a prompt
        // that has to be typed at; the launcher already spawns terminal entries
        // exactly this way, and kitty is this setup's terminal everywhere else
        // in the config.
        Item {
            width: parent.width
            height: 30

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: ctlLabel.implicitWidth + 20
                implicitHeight: 24
                radius: height / 2

                color: ctlMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Text {
                    id: ctlLabel

                    anchors.centerIn: parent
                    text: "Open bluetoothctl"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 2
                    color: Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                MouseArea {
                    id: ctlMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["kitty", "-e", "bluetoothctl"])
                }
            }
        }

        // The scan switch. It writes root.scanning and never `discovering`
        // itself -- see the Binding at the top of this file, which owns that
        // property -- but it READS the adapter, so what it shows is what BlueZ
        // is actually doing rather than what was asked for.
        ToggleRow {
            glyph: Icons.refresh
            label: "Scan for nearby devices"
            checked: root.adapter?.discovering ?? false
            enabled: root.radioOn
            onToggled: value => root.scanning = value
        }

        Text {
            visible: text !== ""

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: {
                if (!root.radioOn)
                    return "";
                if (!root.scanning)
                    return "Scanning is off. Nothing new will appear until it is on.";
                if (root.availableDevices.length === 0)
                    return "Looking…";
                return "";
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ScrollList {
            id: availableList

            width: parent.width
            height: Math.min(availableEntries.implicitHeight, root.listCeiling)
            visible: height > 0
            contentHeight: availableEntries.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: availableEntries

                width: availableList.width
                spacing: 2

                Repeater {
                    model: root.radioOn ? root.availableDevices : []

                    delegate: Rectangle {
                        id: available

                        required property var modelData

                        readonly property bool isPairing: available.modelData?.pairing ?? false

                        width: availableEntries.width
                        implicitHeight: 36
                        radius: Theme.groupRadius

                        color: availableMouse.containsMouse || available.isPairing
                            ? Theme.surfaceContainerHigh
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        Text {
                            id: availableGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.deviceGlyph(available.modelData?.icon ?? "")
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize
                            color: available.isPairing ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        // No address shown beside the name. displayName already
                        // falls back to the address for a device that has not
                        // reported one, so printing it as well would mean every
                        // named row carrying seventeen characters of hex that
                        // identify nothing anyone is looking for.
                        Text {
                            anchors.left: availableGlyph.right
                            anchors.leftMargin: Theme.itemSpacing
                            anchors.right: availableActions.left
                            anchors.rightMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.displayName(available.modelData)
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Row {
                            id: availableActions

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding - 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Cancel is the ONLY way out of a stalled attempt,
                            // which is why it is a chip and not another use of
                            // the row. A pairing that is waiting for a PIN this
                            // window cannot show will otherwise sit there until
                            // BlueZ times it out, and until it does, the device
                            // refuses every other attempt -- including
                            // bluetoothctl's.
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: available.isPairing

                                implicitWidth: cancelLabel.implicitWidth + 16
                                implicitHeight: 22
                                radius: height / 2

                                color: cancelMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                border.width: 1
                                border.color: Theme.outlineVariant

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }

                                Text {
                                    id: cancelLabel

                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSize - 2
                                    color: Theme.textOnSurfaceVariant

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.recolorDuration }
                                    }
                                }

                                MouseArea {
                                    id: cancelMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (available.modelData)
                                            available.modelData.cancelPair();
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                text: available.isPairing ? "pairing…" : "pair"
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 2
                                color: Theme.outline

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }
                        }

                        MouseArea {
                            id: availableMouse

                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                const device = available.modelData;
                                if (!device)
                                    return;

                                // A second click on a row that is already
                                // pairing does NOT cancel. That is the Cancel
                                // chip's job, and calling pair() again on a
                                // device mid-attempt is how you end up with two
                                // outstanding requests to a device that could
                                // not answer the first one.
                                if (device.pairing)
                                    return;

                                // TRUSTED BEFORE PAIRING, for the reason
                                // written out at the connect handler above:
                                // BlueZ leaves an untrusted device's profiles
                                // down, so a freshly paired headset connects
                                // with no audio and a freshly paired
                                // controller with no input. Pairing something
                                // from this window is the statement that it is
                                // trusted; asking again afterwards would be
                                // asking the same question twice.
                                device.trusted = true;
                                device.pair();
                            }
                        }
                    }
                }
            }
        }
    }
}
