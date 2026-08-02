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

    readonly property HyprlandToplevel toplevel: {
        const active = Hyprland.activeToplevel;
        return active?.monitor?.name === root.barScreen.name ? active : null;
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
