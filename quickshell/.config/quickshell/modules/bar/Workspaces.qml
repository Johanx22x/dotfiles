// Workspaces of the monitor this bar sits on.
//
// Event-driven through Compositor, which keeps a live model fed by whichever
// compositor is running. Nothing polls and nothing spawns a CLI tool.
//
// SHAPE
// No numbers: each workspace is a dot, and the active one is a wide pill.
// Position in the row identifies a workspace, so the label is redundant --
// and dropping it is what lets the module shrink to a strip a few pixels
// tall. It also happens to be the only design that works on both compositors:
// Hyprland's workspaces are numbered places, niri's are a dynamic list where
// the number is a position, and a dot means the same thing in both.
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
// while the workspace of the OTHER monitor claimed the indicator and threw the
// pill to x = 0. Filtering the model by output, below, is what makes that
// impossible rather than merely unlikely.
//
// WHY THE MODEL IS A COUNT AND NOT THE LIST ITSELF
// Compositor hands out a plain array, rebuilt whenever anything changes -- it
// has to be, because QML only re-evaluates a binding when the property itself
// changes, and mutating an array in place notifies nothing. Feeding that array
// to the Repeater directly would DESTROY AND REBUILD EVERY DELEGATE on every
// event, which resets the width animation mid-flight and makes the pill jump
// instead of travel. Binding to the length instead keeps the delegates alive
// while only their contents change, so a rebuild happens when a workspace is
// genuinely added or removed and not when one is merely focused.

import QtQuick
import "root:/"

Item {
    id: root

    // Which screen to filter by: the compositor reports every workspace on
    // every monitor.
    required property var barScreen

    readonly property int dotSize: 12
    readonly property int pillWidth: 36
    readonly property int slotSpacing: 9

    // This monitor's workspaces, in the compositor-neutral shape:
    // { id, number, name, output, active, focused, urgent, windows }
    //
    // EMPTY ONES ARE NOT DRAWN, and which ones those are depends on the
    // compositor rather than on this module. Hyprland creates a workspace when
    // something opens on it and drops it when the last window closes, so the
    // model only ever holds occupied ones and this filter changes nothing
    // there. niri's are declared and permanent -- ten of them, so that
    // workspace 3 is still workspace 3 tomorrow -- which means nine dots for
    // nothing unless they are filtered here.
    //
    // THREE THINGS SURVIVE THE FILTER:
    //   * anything with a window on it, which is the point;
    //   * the ACTIVE one, empty or not, or the row would lose its indicator
    //     the moment you scrolled onto a fresh workspace;
    //   * an URGENT one, because something asking for attention from a
    //     workspace you cannot see is exactly what the dot is for.
    //
    // And where occupancy is unknown -- `windows` is -1 on a compositor that
    // cannot count them -- nothing is filtered at all. Showing a row that is
    // too long beats hiding a workspace that has something on it.
    readonly property var list: {
        const all = Compositor.workspacesOn(barScreen.name);
        if (!Compositor.can("workspaceOccupancy"))
            return all;
        return all.filter(ws => ws.windows !== 0 || ws.active || ws.urgent);
    }

    // Does this screen have the keyboard? Straight from the facade, which
    // derives it from whichever workspace is focused -- one question, answered
    // the same way on every compositor.
    readonly property bool screenFocused: Compositor.focusedOutput === barScreen.name

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

    // Nothing to show on a compositor that cannot report workspaces. The module
    // collapses rather than leaving a gap in the bar.
    visible: Compositor.can("workspaces") && list.length > 0

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
            model: root.list.length

            Item {
                id: slot

                required property int index

                // Re-read from the array on every change. The delegate itself
                // survives; only this binding moves.
                readonly property var ws: root.list[index] ?? null

                readonly property bool isActive: ws?.active === true

                // WHEN OCCUPANCY IS UNKNOWN, EVERYTHING READS AS OCCUPIED.
                // `windows` is -1 on a compositor that cannot count them, and
                // the alternative -- treating unknown as empty -- would paint
                // the whole row in the barely-there colour and make the bar
                // look broken. Bright is the safe direction to be wrong in.
                readonly property bool occupied: !Compositor.can("workspaceOccupancy")
                    || (ws?.windows ?? 0) > 0

                // The slot widens for the active workspace so the pill has
                // room; the rest of the row reflows around it.
                implicitWidth: isActive ? root.pillWidth : root.dotSize
                implicitHeight: Theme.groupHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                onIsActiveChanged: if (isActive)
                    root.activeSlot = slot
                Component.onCompleted: if (isActive)
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
                        if (slot.ws?.urgent === true)
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
                    onClicked: if (slot.ws)
                        Compositor.focusWorkspace(slot.ws.id)
                }
            }
        }
    }
}
