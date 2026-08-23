// How genesis draws one screen on the arrangement map: a rounded rectangle in
// one of three states, with the connector and the logical size written in the
// middle of it. The public half -- what the four readings mean, why the
// dragger stayed in ArrangementSection.qml, and why this facade reports no size
// at all -- is modules/settings/pages/display/MonitorTile.qml, and this file is
// the delegate's drawing from before the split, moved unchanged.
//
// THIS FILE TAKES NO INPUT AND MUST NOT. No MouseArea, no TapHandler, no
// DragHandler, no cursorShape. The one that drags a screen belongs to the
// section, covers the whole tile, and follows the pointer by hand precisely so
// that the rectangle stays drawn from the draft -- see the facade's header,
// which has the whole of that argument. It is rule 7 of README.md, and the
// thing it protects is the only interaction on this page.
//
// THREE STATES BECAUSE THEY ANSWER THREE DIFFERENT QUESTIONS. The one being
// dragged leads in the accent, the ones that have moved since the last apply
// are tinted, and the rest are plain. The middle one is the only way to see
// what Apply is about to send.
//
// THE SIZE IS THE HOST'S AND SO IS THE PLACE. This item is anchor-filled by the
// facade's Loader, so `root.width` and `root.height` are what the map worked
// out; nothing here reports a size upward and a theme that drew nothing would
// leave the tiles exactly where they are, in the right sizes, still draggable.

import QtQuick
import qs
// MonitorTile is modules/settings/pages/display/MonitorTile.qml -- the facade
// -- and not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings.pages.display

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `MonitorTile` here is the facade and not
    // this file.
    required property MonitorTile row

    radius: 6

    color: root.row.dragging || root.row.moved
        ? Qt.alpha(Theme.primary, 0.28)
        : Theme.surfaceContainerHigh

    border.width: root.row.focused ? 2 : 1
    border.color: root.row.dragging || root.row.moved
        ? Theme.primary
        : Theme.outlineVariant

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.row.connector
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Bold
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The logical size and not the mode, because that is what the
        // rectangle is drawn from: a rotated 1080p panel reads 1080 × 1920
        // here and the number matches the shape it is written on.
        //
        // HIDDEN ON A TILE TOO SHORT TO HOLD TWO LINES. Forty-four is measured
        // against this item's own height, which is the tile's -- see the
        // header -- and it is the same test the delegate ran on itself before
        // the split.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.height > 44
            text: `${Math.round(root.row.logicalWidth)} × ${Math.round(root.row.logicalHeight)}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
