// THE TASKBAR CORNER.
//
// Reading right to left off a photograph of a real one: the clock, then the
// system icons as ONE group with a single hover backplate, then the keyboard
// layout, then the overflow chevron. Windows calls the whole right-hand end
// "the taskbar corner" rather than a system tray, and the naming matters here
// because it is not a strip of separate buttons: network, volume and battery
// share one target that opens Quick Settings, and only the third-party icons
// beside them are individually clickable.
//
// THE KEYBOARD LAYOUT IS TWO STACKED LINES -- "ENG" over "IN" -- which is one
// of those details that is invisible until you see it and then cannot be
// unseen. It is drawn that way here for exactly that reason.
//
// WHAT IS NOT HERE, AND WHY. No bell: Windows puts the unread count on the
// clock and has no separate notification button, so this theme has none
// either. No settings gear, no power button, no updates glyph -- on Windows
// those live in Start and in Quick Settings, not on the bar. Anything of ours
// that has no home in the corner does not get one invented for it.

import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick
import qs
import qs.themes.windows

Row {
    id: root

    required property var barScreen

    spacing: 0

    // A backplate that several glyphs share. Declared once as an inline
    // component because the corner has three of them and they differ only in
    // what they contain -- and an inline component's instances are ordinary
    // children, not a delegate, so what they read is still checked.
    component CornerItem: Item {
        id: item

        property alias content: slot.data
        readonly property bool hovered: itemPointer.containsMouse
        readonly property bool held: itemPointer.pressed

        signal activated

        implicitWidth: slot.childrenRect.width + Fluent.trayPadding * 2
        implicitHeight: Fluent.trayItemHeight
        anchors.verticalCenter: parent?.verticalCenter ?? undefined

        Rectangle {
            anchors.fill: parent
            radius: Fluent.controlRadius
            color: {
                if (item.held)
                    return Theme.surface;
                if (item.hovered)
                    return Theme.surfaceContainerHigh;
                return "transparent";
            }
        }

        Item {
            id: slot

            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }

        MouseArea {
            id: itemPointer

            anchors.fill: parent
            hoverEnabled: true
            onClicked: item.activated()
        }
    }

    // The overflow chevron. Windows keeps the icons it is not showing behind
    // it; we have no overflow, so it is what opens the tray's own popout
    // instead -- the same gesture reaching the same set.
    CornerItem {
        visible: SystemTray.items.values.length > 0

        // chevronDown TURNED OVER, because the host's icon vocabulary has no
        // chevronUp: it publishes left, right and down and nothing else, and
        // the 105 names are the host's to add to, not a theme's. Rotating is
        // honest here -- a chevron is symmetric about its own axis, so this is
        // the same glyph and not an approximation of a missing one.
        content: Text {
            text: Icons.chevronDown
            rotation: 180
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurface
        }

        onActivated: root.overflowRequested()
    }

    // The third-party icons, each its own target, at the size Windows draws
    // every symbol.
    Repeater {
        model: SystemTray.items

        CornerItem {
            id: trayItem

            required property SystemTrayItem modelData

            content: Image {
                width: Fluent.trayIcon
                height: Fluent.trayIcon
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: Icons.resolve(trayItem.modelData?.icon ?? "")
            }

            onActivated: trayItem.modelData?.activate()
        }
    }

    // The keyboard layout, when there is more than one to be in.
    CornerItem {
        visible: Config.keyboardLayouts.length > 1

        content: Column {
            spacing: -2

            Text {
                text: root.layoutCode
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize - 1
                color: Theme.textOnSurface
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: root.layoutRegion
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize - 1
                color: Theme.textOnSurface
                horizontalAlignment: Text.AlignHCenter
            }
        }

        onActivated: Compositor.switchKeyboardLayout()
    }

    // THE SYSTEM GROUP: network, volume and battery under ONE backplate and
    // one click. This is the part that is not a row of buttons, and getting it
    // wrong -- three separate targets -- is what makes a recreation read as a
    // Linux panel.
    CornerItem {
        content: Row {
            spacing: 10

            Text {
                text: root.networkGlyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurface
            }

            Text {
                text: root.volumeGlyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurface
            }

            Text {
                visible: root.hasBattery
                text: root.batteryGlyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurface
            }
        }

        onActivated: root.quickSettingsRequested()
    }

    // ---- the readings the glyphs above are hoisted from --------------------
    //
    // Read here at the top level rather than inside the items, because inside
    // an inline component's content slot they would be as unchecked as a
    // delegate's reads are.

    readonly property string layoutCode: {
        const names = Config.keyboardLayouts;
        const i = Compositor.keyboardLayouts?.currentIndex ?? 0;
        const name = names[i] ?? names[0] ?? "";
        return name.slice(0, 3).toUpperCase();
    }

    readonly property string layoutRegion: {
        const names = Config.keyboardLayouts;
        const i = Compositor.keyboardLayouts?.currentIndex ?? 0;
        const name = names[i] ?? names[0] ?? "";
        const dash = name.indexOf("-");
        return dash > 0 ? name.slice(dash + 1, dash + 3).toUpperCase() : "";
    }

    readonly property string networkGlyph: Icons.wifi
    readonly property string volumeGlyph: Icons.volumeHigh

    readonly property bool hasBattery: UPower.displayDevice?.isLaptopBattery === true

    readonly property string batteryGlyph: {
        const d = UPower.displayDevice;
        if (!d)
            return Icons.battery;
        if (d.state === UPowerDeviceState.Charging)
            return Icons.batteryCharging;
        return d.percentage < 0.1 ? Icons.batteryAlert : Icons.battery;
    }

    signal overflowRequested
    signal quickSettingsRequested
}
