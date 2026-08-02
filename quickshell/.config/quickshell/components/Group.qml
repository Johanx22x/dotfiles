// A pill that holds related items together.
//
// The bar is one continuous surface, so grouping has to come from the
// containers rather than from gaps: a group is a slightly lighter pill
// (surfaceContainerHigh over the bar's surface) with its items in a row.
//
// Not everything on the bar gets one. Readings that belong together and are
// scanned as a unit -- the workspaces, the CPU/RAM/GPU trio, the clock -- do.
// Single indicators sit directly on the bar, or the bar would turn into a
// fence of pills.

import QtQuick
import "root:/"

Rectangle {
    id: root

    default property alias content: row.data
    property int padding: Theme.groupPadding

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.groupHeight
    radius: Theme.groupRadius
    color: Theme.glass(Theme.surfaceContainerHigh)

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.itemSpacing
    }
}
