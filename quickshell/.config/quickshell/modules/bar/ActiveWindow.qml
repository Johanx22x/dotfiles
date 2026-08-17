// The focused window: its application icon and its title.
//
// The icon is resolved through the desktop entry database rather than from
// anything the compositor reports: a compositor only knows the Wayland app id
// (a string like "org.gnome.Loupe"), and turning that into an icon file is
// exactly what heuristicLookup does -- it copes with the app id not matching
// the .desktop file name, which is the common case.
//
// Everything about WHICH window is focused, and about the two Hyprland faults
// that make answering it awkward, now lives in the compositor backend. This
// module asks for the focused window and draws it.

import Quickshell
import QtQuick
import "root:/"

Item {
    id: root

    // The screen this bar is on: the focused window is a session-wide fact, so
    // it has to be checked against this monitor or a bar on one screen would
    // echo the window focused on the other.
    required property var barScreen

    // { appId, title, output } or null.
    readonly property var window: {
        const w = Compositor.activeWindow;
        if (!w || w.output !== root.barScreen.name)
            return null;
        return w;
    }

    readonly property var entry: window?.appId ? DesktopEntries.heuristicLookup(window.appId) : null

    implicitWidth: window ? row.implicitWidth : 0
    implicitHeight: Theme.barHeight

    // Nothing focused, or a compositor that cannot say: the module collapses
    // instead of leaving a gap.
    visible: window !== null && Compositor.can("activeWindow")

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

            text: root.window?.title ?? ""
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
