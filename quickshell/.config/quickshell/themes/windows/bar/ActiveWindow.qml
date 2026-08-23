// The focused window: its application icon and its title.
//
// WINDOWS' TASKBAR DOES NOT SHOW THIS, and it is drawn anyway. The choice was
// between deleting the widget and moving it, and deleting it is the worse
// answer for a reason that has nothing to do with taste: `activeWindow` is a
// per-monitor switch the Bar page offers and Config seeds it ON. A theme that
// simply stopped drawing it would leave a toggle that flips, saves, and changes
// nothing on screen -- the failure this repository keeps meeting from the other
// side, where a test passes over nothing.
//
// SO IT MOVED INSTEAD. It is a left-zone item now rather than a centre one --
// the centre belongs to Start and the app buttons, and a title that changes
// width with every tab would shove them off the middle of the screen. What it
// looks like is the closest thing Windows has: a taskbar button in labels mode,
// which is a 16px icon and one line of body text. It carries NO BACKPLATE and
// NO CLICK, because unlike a real labelled button there is nothing to activate
// -- it already has the focus. Switch it off and the left of the taskbar is
// empty, which is the stock answer.
//
// The icon is resolved through the desktop entry database rather than from
// anything the compositor reports: a compositor only knows the Wayland app id
// (a string like "org.gnome.Loupe"), and turning that into an icon file is
// exactly what heuristicLookup does -- it copes with the app id not matching the
// .desktop file name, which is the common case.
//
// Everything about WHICH window is focused, and about the two Hyprland faults
// that make answering it awkward, lives in the compositor backend. This module
// asks for the focused window and draws it.

import Quickshell
import QtQuick
import qs
import ".."

Item {
    id: root

    // The screen this bar is on: the focused window is a session-wide fact, so
    // it has to be checked against this monitor or a bar on one screen would
    // echo the window focused on the other.
    required property ShellScreen barScreen

    // { appId, title, output } or null.
    readonly property var window: {
        const w = Compositor.activeWindow;
        if (!w || w.output !== root.barScreen.name)
            return null;
        return w;
    }

    readonly property var entry: root.window?.appId
        ? DesktopEntries.heuristicLookup(root.window.appId)
        : null

    // OURS: a labelled taskbar button stops growing somewhere, and a browser tab
    // title will happily eat the whole bar. Windows truncates its own at about
    // this width before it starts dropping labels altogether.
    readonly property int maxTitle: 320

    implicitWidth: root.window ? row.implicitWidth : 0
    implicitHeight: Fluent.taskButton

    // Nothing focused, or a compositor that cannot say: the module collapses
    // instead of leaving a gap.
    visible: root.window !== null && Compositor.can("activeWindow")

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Fluent.fastMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barPadding

        Image {
            anchors.verticalCenter: parent.verticalCenter

            source: Icons.resolve(root.entry?.icon ?? "")
            visible: status === Image.Ready

            width: Fluent.navIcon
            height: Fluent.navIcon
            // Scaled on load rather than at paint time: icon themes hand out
            // whatever size they have.
            sourceSize.width: width
            sourceSize.height: height
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.window?.title ?? ""
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.maxTitle)

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }
    }
}
