// The charge left in whatever wireless thing is on your head or under your
// hand.
//
// NOT THE MACHINE'S BATTERY. This is a desktop and has none; UPower's
// DisplayDevice -- the aggregate every laptop bar shows -- reports nothing
// useful here. What it does report is HID++ peripherals: a wireless headset
// and a wireless mouse both appear as their own device with their own
// percentage, and until this existed that number was on the machine and
// nowhere on the screen. Measured while writing it: a Logitech headset at
// 60%, discharging, entirely invisible.
//
// SO THE FILTER IS "IS IT A POWER SUPPLY", inverted. UPower marks the thing
// that powers the computer with powerSupply = true, which is exactly what
// this is not interested in; everything else with a battery is a peripheral.
// That way a laptop running these dotfiles shows its mouse here and its own
// battery wherever a laptop battery belongs, rather than both in one row
// meaning two different things.
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

    // Every battery that is not the one running the computer. Sorted by how
    // empty it is, so the one about to die is the one on the left -- with two
    // devices connected the order otherwise depends on which was paired
    // first, which is not a fact anybody is looking for.
    readonly property var devices: {
        // Read so the binding re-evaluates when a device connects or goes
        // away, not only at startup.
        UPower.devices.values.length;

        return UPower.devices.values
            .filter(d => d.ready && d.isLaptopBattery === false && !d.powerSupply && d.percentage > 0)
            .sort((a, b) => a.percentage - b.percentage);
    }

    // A PLAIN PROPERTY AND NOT `visible` FOR THE PARENT TO READ. The pill
    // around this has to disappear along with it, and hanging its `visible`
    // off this item's own `visible` is a binding loop -- Qt detects it, drops
    // the binding, and the result is a battery that never appears at all with
    // nothing in the log to say why. That is exactly what happened the first
    // time. This says the same thing without involving visibility.
    readonly property bool hasAny: root.devices.length > 0

    visible: root.hasAny

    spacing: Theme.itemSpacing

    Repeater {
        model: root.devices

        delegate: Row {
            id: entry

            required property var modelData

            // 0..1 from UPower -- measured against `upower -i`, which prints
            // the same charge as a whole number. A percentage everywhere a
            // person reads it.
            readonly property int charge: Math.round((entry.modelData?.percentage ?? 0) * 100)

            // TWO THRESHOLDS AND NOT ONE. 20% on a headset is a warning --
            // finish what you are doing and put it on the dock. 10% is the
            // one that means it will cut out mid-sentence, and it gets the
            // colour this shell reserves for things that are actually wrong.
            // A single threshold makes the bar shout too early or too late.
            readonly property color tint: {
                if (entry.charge <= 10)
                    return Theme.critical;
                if (entry.charge <= 20)
                    return Theme.warning;
                return Theme.textOnSurface;
            }

            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter

                // The device's own icon name would be the obvious source and
                // is not usable: UPower classifies this headset as a MOUSE
                // (measured -- `upower -i` prints "mouse" for a Logitech
                // headset), so its icon would be a mouse on the bar. One
                // glyph that means "a battery" is honest about what the
                // number is; a wrong picture of the device is not.
                text: Icons.battery
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
    }
}
