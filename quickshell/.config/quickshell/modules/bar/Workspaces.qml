// Workspaces of the monitor this bar sits on.
//
// Event-driven: Quickshell.Hyprland keeps a live model fed by the
// compositor's event socket. Nothing polls and nothing spawns hyprctl.
//
// SHAPE
// No numbers: each workspace is a dot, and the active one is a wide pill.
// Position in the row identifies a workspace, so the label is redundant --
// and dropping it is what lets the module shrink to a strip a few pixels
// tall.
//
// THE INDICATOR IS ONE OBJECT, NOT A STATE PER DOT
// The pill is a single Rectangle floating over the row, not the active dot
// painted differently. It moves by animating its two edges at DIFFERENT
// speeds: the leading edge is quick and the trailing edge lags, so the pill
// stretches while it travels and settles when the slow edge catches up. That
// stretch is what makes the switch read as one object moving instead of two
// dots blinking. (The idea is taken from caelestia-dots/shell, which does the
// same thing on a vertical bar; the code here is our own.)
//
// The dot of the active workspace is hidden while the pill covers it, so
// nothing shows through.
//
// ACTIVE, NOT FOCUSED
// A workspace is `active` when it is the one shown on ITS monitor, and
// `focused` when it is the one the keyboard is on -- and only one workspace
// in the whole session is focused. Tracking `focused` broke as soon as the
// other monitor was clicked: no workspace on this bar was focused any more,
// while the workspace of the OTHER monitor (whose slot exists here but is
// invisible, and therefore never positioned by the Row) claimed the
// indicator and threw the pill to x = 0.
//
// `active` is per monitor, so each bar follows its own screen and nothing
// moves when focus leaves. The guard on `visible` below is the belt to that
// braces: a slot that does not belong to this monitor can never take the
// indicator.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "root:/"

Item {
    id: root

    // Which screen to filter by: Hyprland.workspaces holds every workspace
    // on every monitor.
    required property var barScreen

    readonly property int dotSize: 12
    readonly property int pillWidth: 36
    readonly property int slotSpacing: 9

    // Derived from the workspace model rather than from
    // Hyprland.focusedMonitor. The IPC models are populated LAZILY: whichever
    // one nothing subscribes to is never refreshed, and focusedMonitor stayed
    // frozen on whatever monitor happened to be focused at startup. The
    // Repeater below already subscribes to the workspace model, so asking it
    // which monitor holds the globally focused workspace gives the same
    // answer off data that is guaranteed live.
    readonly property bool screenFocused: {
        for (const ws of Hyprland.workspaces.values) {
            if (ws.focused)
                return ws.monitor?.name === barScreen.name;
        }
        return false;
    }

    // Set by whichever slot is currently active, see the delegate below.
    // Reading it out of the Repeater instead would mean looping over items
    // inside a binding, and QML cannot track a loop's dependencies.
    property Item activeSlot: null

    // The pill's two edges. Both chase the same target; the different
    // durations on their Behaviors are the entire effect.
    readonly property real target: activeSlot ? activeSlot.x : 0
    property real leading: target
    property real trailing: target

    onTargetChanged: {
        leading = target;
        trailing = target;
    }

    Behavior on leading {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Behavior on trailing {
        NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.groupHeight

    // ---------------- The moving pill ----------------
    Rectangle {
        id: indicator

        // Spans from whichever edge is behind to whichever is ahead, so the
        // shape covers the ground between the two while they are apart.
        x: row.x + Math.min(root.leading, root.trailing)
        width: Math.abs(root.leading - root.trailing) + (root.activeSlot?.width ?? root.dotSize)

        anchors.verticalCenter: parent.verticalCenter
        height: root.dotSize
        radius: height / 2
        // Full accent only on the monitor that has the keyboard; the other
        // bar keeps its pill, dimmed, so "which workspace is this screen on"
        // and "which screen am I typing into" are both answerable at a glance.
        color: root.screenFocused ? Theme.primary : Theme.primaryContainer
        visible: root.activeSlot !== null

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- The dots ----------------
    Row {
        id: row

        anchors.centerIn: parent
        spacing: root.slotSpacing

        Repeater {
            id: repeater
            model: Hyprland.workspaces

            Item {
                id: slot

                required property HyprlandWorkspace modelData

                readonly property bool occupied: modelData.toplevels.values.length > 0
                readonly property bool isActive: modelData.active

                // `?.` is load-bearing: a workspace exists for an instant
                // with no monitor while it is being moved between screens,
                // and reading .name off null throws inside the binding.
                visible: modelData.monitor?.name === root.barScreen.name

                // The slot widens for the active workspace so the pill has
                // room; the rest of the row reflows around it.
                implicitWidth: isActive ? root.pillWidth : root.dotSize
                implicitHeight: Theme.groupHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                onIsActiveChanged: if (isActive && visible)
                    root.activeSlot = slot
                Component.onCompleted: if (isActive && visible)
                    root.activeSlot = slot
                // A workspace moved onto this monitor arrives already active.
                onVisibleChanged: if (isActive && visible)
                    root.activeSlot = slot

                Rectangle {
                    anchors.centerIn: parent

                    width: root.dotSize
                    height: root.dotSize
                    radius: height / 2

                    // Hidden under the pill: the indicator is the only thing
                    // that paints the active workspace.
                    opacity: slot.isActive ? 0 : 1

                    color: {
                        if (slot.modelData.urgent)
                            return Theme.critical;
                        if (mouse.containsMouse)
                            return Theme.textOnSurface;
                        // Occupied but unfocused reads clearly; empty is
                        // barely there, present only so the row does not
                        // reflow when a workspace appears.
                        return slot.occupied ? Theme.textOnSurfaceVariant : Theme.outlineVariant;
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.modelData.id}`)
                }
            }
        }
    }
}
