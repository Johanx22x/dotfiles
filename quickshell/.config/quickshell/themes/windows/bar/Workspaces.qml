// The app buttons: one 40x40 box per workspace on this monitor, with the
// running indicator underneath it.
//
// THE INDICATOR IS THE WHOLE POINT OF THIS FILE. Everything else about a
// Windows taskbar button -- the box, the radius, the two fills -- is
// TaskbarItem.qml's and is shared with the tray and the clock. What is only
// ever drawn here is the rounded bar along the bottom edge, and it is the one
// piece of taskbar geometry with real corroboration behind it: the literal `3`
// for its height comes out of taskbar-labels.wh.cpp, which reads stock
// geometry, and the two widths agree across a Windhawk XAML dump and a CSS
// clone. All four numbers live in Fluent.qml under the heading that says the
// taskbar's figures are ours.
//
// IT CARRIES FOCUS BY WIDTH AND COLOUR TOGETHER, never by one alone: 6px in
// Theme.outline says a thing is running, 16px in Theme.primary says it is the
// one you are in. THERE IS NO THIRD STATE FOR "SEVERAL WINDOWS OPEN" -- stock
// Windows does not have one, whatever the stacked-indicator mods suggest, and
// the model here would happily supply one because a workspace knows how many
// windows are on it. It is deliberately not read for that.
//
// WHAT A BUTTON IS, HERE. Windows' buttons are applications; ours are
// workspaces, because that is what the compositor facade answers questions
// about. Compositor.activeWindow reports ONE window and nothing in
// Compositor.qml enumerates the rest, so a per-application taskbar would mean
// this theme reaching past the facade into wlr-foreign-toplevel on its own --
// and getting a list with no reliable answer to "is it on THIS monitor", which
// is the fault CompositorBackend.qml's own note on fullscreenOutputs spells
// out. A workspace maps onto the button cleanly in every part that matters:
// it is running when something is on it, it is focused when you are in it, and
// clicking it takes you there.
//
// THE ACTIVE BUTTON KEEPS THE HOVER FILL. That is `washed` on the item below
// and it is not an invented state -- Windows paints the foreground app's button
// with the same subtle brush its hover uses, exactly as NavigationView's
// selected pill does. Giving selection a backplate colour of its own is what a
// recreation does wrong.
//
// THE POSITION IS THE LABEL. A dot said the same thing on genesis's bar; here
// there is a 40px box to fill and the workspace's own number fills it. The one
// thing this cannot draw is an application icon, and that is the same gap as
// above rather than a choice.
//
// WHY THE MODEL IS A COUNT AND NOT THE LIST ITSELF
// Compositor hands out a plain array, rebuilt whenever anything changes -- it
// has to be, because QML only re-evaluates a binding when the property itself
// changes, and mutating an array in place notifies nothing. Feeding that array
// to the Repeater directly would DESTROY AND REBUILD EVERY DELEGATE on every
// event. Binding to the length instead keeps the delegates alive while only
// their contents change.

import Quickshell
import QtQuick
import qs
import qs.themes.windows

Item {
    id: root

    // Which screen to filter by: the compositor reports every workspace on
    // every monitor.
    required property ShellScreen barScreen

    // This monitor's workspaces, in the compositor-neutral shape:
    // { id, number, name, output, active, focused, urgent, windows }
    //
    // EMPTY ONES ARE NOT DRAWN, and which ones those are depends on the
    // compositor rather than on this module. Hyprland only ever holds occupied
    // ones; niri's ten are declared and permanent, which means nine empty
    // buttons unless they are filtered here.
    //
    // THREE THINGS SURVIVE THE FILTER: anything with a window on it, which is
    // the point; the ACTIVE one, empty or not, or the row would lose its
    // indicator the moment you scrolled onto a fresh workspace; and an URGENT
    // one, because something asking for attention from a workspace you cannot
    // see is exactly what the button is for.
    //
    // Where occupancy is unknown -- `windows` is -1 on a compositor that cannot
    // count them -- nothing is filtered at all.
    readonly property var list: {
        const all = Compositor.workspacesOn(root.barScreen.name);
        if (!Compositor.can("workspaceOccupancy"))
            return all;
        return all.filter(ws => ws.windows !== 0 || ws.active || ws.urgent);
    }

    // Does this screen have the keyboard? Straight from the facade, which
    // derives it from whichever workspace is focused -- one question, answered
    // the same way on every compositor.
    //
    // ACTIVE, NOT FOCUSED, on the workspaces themselves. A workspace is
    // `active` when it is the one shown on ITS monitor and `focused` when it is
    // the one the keyboard is on, and only one workspace in the whole session
    // is focused: tracking `focused` per button broke as soon as the other
    // monitor was clicked. The two facts are separated here instead -- which
    // workspace this screen is on is the button, which screen has the keyboard
    // is the indicator's colour.
    readonly property bool screenFocused: Compositor.focusedOutput === root.barScreen.name

    implicitWidth: row.implicitWidth
    implicitHeight: Fluent.taskButton

    // Nothing to show on a compositor that cannot report workspaces. The module
    // collapses rather than leaving a gap in the taskbar.
    visible: Compositor.can("workspaces") && root.list.length > 0

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.itemSpacing

        Repeater {
            model: root.list.length

            TaskbarItem {
                id: button

                required property int index

                // Re-read from the array on every change. The delegate itself
                // survives; only this binding moves.
                readonly property var ws: root.list[button.index] ?? null

                readonly property bool isActive: button.ws?.active === true

                // WHEN OCCUPANCY IS UNKNOWN, EVERYTHING READS AS RUNNING.
                // `windows` is -1 on a compositor that cannot count them, and
                // treating unknown as empty would leave a row of buttons with
                // no indicators at all, which looks like a broken taskbar
                // rather than an empty desktop.
                readonly property bool running: !Compositor.can("workspaceOccupancy")
                    || (button.ws?.windows ?? 0) > 0

                boxWidth: Fluent.taskButton
                boxHeight: Fluent.taskButton

                washed: button.isActive

                onActivated: if (button.ws)
                    Compositor.focusWorkspace(button.ws.id)

                Text {
                    anchors.centerIn: parent

                    text: button.ws?.number ?? ""
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: Fluent.normalWeight
                    color: button.running || button.isActive
                        ? Theme.textOnSurface
                        : Theme.outline
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Fluent.indicatorBottomGap

                    width: button.isActive
                        ? Fluent.indicatorFocusedWidth
                        : Fluent.indicatorRunningWidth
                    height: Fluent.indicatorThickness
                    radius: height / 2

                    visible: button.running || button.isActive

                    color: {
                        if (button.ws?.urgent === true)
                            return Theme.critical;
                        // The accent is the keyboard, not the button. On the
                        // monitor you are not typing into, the wide bar still
                        // says which workspace that screen is on and the grey
                        // says the focus is elsewhere.
                        if (button.isActive && root.screenFocused)
                            return Theme.primary;
                        return Theme.outline;
                    }

                    // THE ONE THING THAT MOVES ON THIS BAR, and it is not a
                    // hover: the indicator grows and shrinks when the focus
                    // changes, on WinUI's only easing spline
                    // (ControlFastOutSlowInKeySpline = 0,0,0,1) over the fast
                    // duration. The colour swaps under it with no transition at
                    // all, like every other brush here.
                    Behavior on width {
                        NumberAnimation {
                            duration: Fluent.fastMs
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Fluent.easeOut
                        }
                    }
                }
            }
        }
    }
}
