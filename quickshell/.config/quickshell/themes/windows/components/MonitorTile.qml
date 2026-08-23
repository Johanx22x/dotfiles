// How Windows draws one screen on the arrangement map: a rectangle in one of
// three states with the connector and the logical size written in the middle of
// it. The public half -- what the five readings mean, why the dragger stayed in
// ArrangementSection.qml, and why this facade reports no size at all -- is
// modules/settings/pages/display/MonitorTile.qml.
//
// THIS FILE TAKES NO INPUT AND MUST NOT. No MouseArea, no TapHandler, no
// DragHandler, no cursorShape. The one that drags a screen belongs to the
// section, covers the whole tile, and follows the pointer by hand precisely so
// that the rectangle stays drawn from the draft rather than from an `x` a
// dragger assigned to it -- see the facade's header, which has the whole of that
// argument. It is rule 7 of themes/genesis/components/README.md, and the thing
// it protects is the only interaction on this page.
//
// `row.dragging` IS A PLAIN BOOL AND NOT A HANDLER, for the same reason: handing
// the MouseArea over would let this file read `pressed`, `mouseX` and `drag`,
// and would make the one thing the section is careful about reachable from
// behind the seam.
//
// AND THE PROPERTY IS `connector`, DELIBERATELY NOT `label`. SettingsSearch
// duck-types a row as anything with a non-empty string `label`, so a monitor
// called `label` would put one search hit per screen into an index of settings
// rows with nothing to open. Rule 3, decided on the facade; this file only has
// to not undo it, which it does by declaring no properties of its own at all.
//
// IT HAS NO SIZE CONTRACT IN EITHER DIRECTION. `x`, `y`, `width` and `height`
// are the map's -- a logical size times a zoom factor, through two coordinate
// transforms -- and this item is anchor-filled to them by the facade's Loader.
// Nothing here reports a size upward and nothing reads one back; a theme that
// drew nothing would leave every tile exactly where the arrangement says, in the
// right size, still draggable. This is the CornerWedge clause and not an
// exception to rule 2.
//
// THREE STATES BECAUSE THEY ANSWER THREE DIFFERENT QUESTIONS. The one being
// dragged leads in the accent, the ones that have moved since the last apply are
// tinted, and the rest are plain. The middle one is the only way to see what
// Apply is about to send.

import QtQuick
import qs
// MonitorTile is modules/settings/pages/display/MonitorTile.qml -- the facade --
// and not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins.
import qs.modules.settings.pages.display
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `MonitorTile` here is the facade and not this file.
    required property MonitorTile row

    // Read once, into a local with a real type: it decides the fill, the stroke
    // and nothing else, and it is read four times below.
    readonly property bool pending: root.row.dragging || root.row.moved

    // ControlCornerRadius. A tile on a map is an in-page element, so it is 4 --
    // genesis's 6 is not a radius Windows has, and there is no third one.
    radius: Fluent.controlRadius

    // A raised element on the map's ground. The tinted state is the accent at a
    // sixteenth, which is the same weight the pending banner tints its amber at:
    // enough to group the moved screens, not enough to fight the palette.
    color: root.pending
        ? Qt.alpha(Theme.primary, 0.16)
        : Theme.surfaceContainerHighest

    // The focused screen is the only one with a heavier stroke, and it is a
    // WIDTH and not a colour: the accent is already saying "moved" on the tiles
    // beside it, and a second meaning on the same colour would make the two
    // unreadable together.
    border.width: root.row.focused ? 2 : 1
    border.color: root.pending ? Theme.primary : Theme.outlineVariant

    Column {
        anchors.centerIn: parent
        spacing: 2

        // Body Strong: the one place Windows 11's typography asks for weight, and
        // a connector is the tile's name.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.row.connector
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        // The logical size and not the mode, because that is what the rectangle
        // is drawn from: a rotated 1080p panel reads 1080 x 1920 here and the
        // number matches the shape it is written on.
        //
        // HIDDEN ON A TILE TOO SHORT TO HOLD TWO LINES. Forty-four is measured
        // against this item's own height, which is the tile's -- see the header
        // -- and it is the same test the delegate ran on itself before the split.
        // Reading `root.height` is safe in a way rule 2 warns about elsewhere:
        // nothing here reports a height, so there is no loop to close.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.height > 44
            text: `${Math.round(root.row.logicalWidth)} × ${Math.round(root.row.logicalHeight)}`
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }
}
