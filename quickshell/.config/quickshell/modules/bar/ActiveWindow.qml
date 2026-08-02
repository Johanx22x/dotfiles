// The focused window: its application icon and its title.
//
// The icon is resolved through the desktop entry database rather than from
// anything Hyprland reports: the compositor only knows the Wayland app id
// (a string like "org.gnome.Loupe"), and turning that into an icon file is
// exactly what heuristicLookup does -- it copes with the app id not matching
// the .desktop file name, which is the common case.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "root:/"

Item {
    id: root

    // The screen this bar is on: the global "active toplevel" has to be
    // checked against it, or a bar on one monitor would echo the window
    // focused on the other.
    required property var barScreen

    // HYPRLAND.ACTIVETOPLEVEL GOES STALE WHEN FOCUS GOES NOWHERE
    // Hyprland does announce the loss -- switching to an empty workspace
    // emits `activewindowv2>>` with no address -- but Quickshell 0.3.0 does
    // not clear activeToplevel on it: the property keeps pointing at the
    // last focused window, so the module kept painting a title for a
    // workspace with nothing on it.
    //
    // So focus is read off the toplevel itself. `wayland.activated` is the
    // Wayland handle's own state and it is the only flag here that tracks
    // reality: the IPC-side `activated` is frozen true right along with
    // activeToplevel, and `workspace.active` is false for special
    // workspaces -- which ARE on screen, so it would blank the title every
    // time the magic workspace is pulled up.
    //
    // Compared against `false` rather than tested for truth: the Wayland
    // handle is briefly absent while a window maps, and an unknown state
    // should leave the module as it was instead of blinking it away.
    readonly property HyprlandToplevel toplevel: {
        const active = Hyprland.activeToplevel;
        if (active?.monitor?.name !== root.barScreen.name)
            return null;
        return active.wayland?.activated === false ? null : active;
    }

    readonly property string appId: toplevel?.wayland?.appId ?? toplevel?.lastIpcObject?.class ?? ""
    readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null

    implicitWidth: toplevel ? row.implicitWidth : 0
    implicitHeight: Theme.barHeight

    // Nothing focused: the module collapses instead of leaving a gap.
    visible: toplevel !== null

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter

            source: Icons.resolve(root.entry?.icon ?? "")
            visible: status === Image.Ready

            width: Theme.imageSize
            height: Theme.imageSize
            // Scaled on load rather than at paint time: icon themes hand out
            // whatever size they have.
            sourceSize.width: width
            sourceSize.height: height
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.toplevel?.title ?? ""
            elide: Text.ElideRight
            // A browser tab title will happily eat the whole bar.
            width: Math.min(implicitWidth, 420)

            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
