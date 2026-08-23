// How Windows draws one row of a list. The public half -- what the four rows
// this replaced were, why `label` and `name` are two properties, and what
// `interactive: false` promises -- is components/ListRow.qml.
//
// THIS IS WinUI'S ListViewItem AND ALL FOUR OF ITS NUMBERS ARE PUBLISHED, which
// makes it the one surface on this page that is not a judgement call:
//
//   min height   40
//   padding      16,0,12,0   -- sixteen on the left, twelve on the right, and
//                              NOTHING top or bottom: the min height does that
//   radius       4           -- ControlCornerRadius, the in-page radius
//   selection    a 3x16 accent pill at radius 2, flush with the left edge and
//                              vertically centred
//
// SELECTION IS THE PILL, NOT A FILL, and getting that wrong invents a state
// Windows does not have. NavigationView's selected item has EXACTLY the same
// backplate as its hover state; the accent indicator is the whole of what says
// "this one". Two things follow and both are easy to get wrong from a
// screenshot: a selected row that is not hovered still shows the hover fill, and
// the FOREGROUND does not change -- the label stays TextFillColorPrimary in
// every state including selected. A recreation that turns the selected label
// accent-coloured, or bolds it, has added emphasis to a row that already had
// its answer.
//
// HOVER BRIGHTENS, PRESS DIMS, AND NEITHER FADES. The subtle ramp a list draws
// from is Transparent at rest, SubtleFillColorSecondary on hover and
// SubtleFillColorTertiary on press -- so press is BELOW hover and above rest.
// Fluent's fillPress is the CONTROL ramp's press, one level below a control's
// resting fill, and it is Theme.surface: right for a button whose rest is
// already filled, wrong here, because a row at rest is transparent and a press
// painted in the ground colour would be a press nobody can see. The level
// between the ground and the hover is Theme.surfaceContainer, and that is the
// one this file uses. Windows swaps both on a DiscreteObjectKeyFrame at time
// zero, so there is no Behavior on colour anywhere in this file.
//
// `interactive: false` IS AN ABSENCE AND THIS FILE IS WHERE IT LIVES. The
// updates page's check table is a reading, not a list of choices: no hover fill,
// no pointer cursor, nothing to click, and no colour that changes because a
// pointer is over it. Its own header said it is "shaped like an InfoRow because
// it is one", and InfoRow.qml sets out at length why a facade cannot require
// that and this file can. How it is kept -- and why it is three bindings rather
// than the Loader InfoRow's rule would ask for -- is written out over the
// MouseArea at the foot of this file. Read that before changing any of the
// three.
//
// TWO SHAPES, AND WHICH ONE A ROW GETS IS WHETHER IT CAN BE CLICKED.
//
//   the choice   a line of text you can pick, optionally with a second line
//                under it. The text ELIDES, because a device name or a codec is
//                an identifier and half of one is still enough to recognise.
//   the reading  the text WRAPS, because a unit's title and the sentence it
//                wrote about itself are prose, and prose cut off at the width of
//                a sidebar is prose nobody finishes. The row grows to fit it.
//
// THE MARK ON THE LEFT HANGS FROM THE TOP OF THE TEXT WHEN THERE IS A SECOND
// LINE AND IS CENTRED WHEN THERE IS NOT. A reading always hangs, because its
// column always might grow.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `ListRow` here is the facade and not this file.
    required property ListRow row

    // ---------------- The three things the shape turns on ----------------
    //
    // Read once, into locals with real types. Nothing below is a delegate, so
    // rule 1's checking reaches every one of these reads -- but they are read
    // eight or nine times each and a local `bool` says what it is.
    readonly property bool compact: root.row.compact

    // The reading shape. See the two-shape note above.
    readonly property bool reading: !root.row.interactive

    readonly property bool selected: root.row.selected

    // Whether the mark on the left hangs from the top of the text or sits in the
    // middle of it. Static per row: `detail` and `interactive` are both constants
    // at every call site, so nothing here moves while the row is on screen.
    readonly property bool topAligned: root.reading || root.row.detail !== ""

    // ---------------- The box ----------------
    //
    // ListViewItemMinHeight, and the compact list is Windows' 32 -- the height
    // Button, ComboBox and TextBox all sit at, which is what a dense list row
    // lands on. Microsoft's compact ListViewItem metric is not in Fluent.qml, so
    // this reads the control height rather than restating a number.
    readonly property int minHeight: root.compact ? Fluent.controlHeight : 40

    // Padding is 16,0,12,0 and the vertical halves really are zero: the min
    // height carries a one-line row on its own. A row whose second line WRAPS is
    // the one case the published metric does not cover, and the eight pixels a
    // side below are OURS -- Microsoft publishes nothing for a two-line
    // ListViewItem.
    readonly property int padLeft: 16
    readonly property int padRight: 12
    readonly property int wrapPad: 8

    implicitHeight: Math.max(root.minHeight, column.implicitHeight + root.wrapPad * 2)

    // ControlCornerRadius. Not `Theme.groupRadius`, which is `groupHeight / 2`
    // and a capsule; a compact row is the same 4 as a full one, because Windows
    // has no third radius and no pill.
    radius: Fluent.controlRadius

    // Nothing at all for a reading: the MouseArea at the foot of this file has
    // hoverEnabled false there, so containsMouse never becomes true. See the
    // header for why press is surfaceContainer and not Fluent.fillPress.
    color: {
        if (root.selected)
            return Fluent.fillSubtleHover;

        if (press.pressed)
            return Theme.surfaceContainer;

        return press.containsMouse ? Fluent.fillSubtleHover : "transparent";
    }

    // ---------------- Selection: the 3x16 accent pill ----------------
    //
    // Flush with the left edge -- OUTSIDE the 16 of padding, not inside it --
    // and vertically centred whatever the row's height came out at. This is the
    // whole of selection; see the header.
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        visible: root.selected

        width: Fluent.indicatorWidth
        height: Fluent.indicatorHeight
        radius: Fluent.indicatorRadius
        color: Theme.primary
    }

    // ---------------- The mark on the left ----------------

    Text {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: root.padLeft

        // ONE OF THESE TWO IS ALWAYS undefined, which is how QML is told to
        // forget an anchor rather than to fight over one. See topAligned above
        // for which and why.
        anchors.top: root.topAligned ? column.top : undefined
        anchors.topMargin: 1
        anchors.verticalCenter: root.topAligned ? undefined : parent.verticalCenter

        visible: root.row.glyph !== ""
        text: root.row.glyph
        font.family: Theme.fontFamily

        // Body size when compact, icon size otherwise: the package list's mark
        // is a checkbox sitting beside text at Caption size, and at icon size it
        // out-weighs the name it belongs to.
        font.pointSize: root.compact ? Fluent.bodySize : Theme.iconSize

        // THE MARK IS THE ONE THING SELECTION DOES RECOLOUR, and it is not the
        // text: a glyph is a picture and the accent on it reads the way the
        // network list's connected tick does. The label above it stays primary.
        color: root.selected ? Theme.primary : Theme.textOnSurfaceVariant
    }

    // The other kind of mark: a state word in a pill instead of a picture. Only
    // the reading uses one today. It hangs from the top of the column always,
    // and two pixels down rather than the mark's one, because a 20-pixel pill
    // and a line of type do not sit on the same top edge.
    Chip {
        id: state

        anchors.left: parent.left
        anchors.leftMargin: root.padLeft
        anchors.top: column.top
        anchors.topMargin: 2

        visible: root.row.badge !== ""
        role: "badge"

        // `name` and not `label`: a state word is not a setting and putting it
        // under `label` would file fifteen of them in the settings search. The
        // facade's header has the whole of that, and it is rule 3.
        name: root.row.badge
        tone: root.row.badgeTone
    }

    // ---------------- The text ----------------

    Column {
        id: column

        // Whichever mark this row has. Both are anchored to this column's top,
        // and this column's top depends on its own height and its parent's --
        // never on theirs -- so there is no loop.
        anchors.left: root.row.badge !== "" ? state.right : mark.right
        anchors.leftMargin: Theme.itemSpacing

        anchors.right: marks.left

        // THE GUTTER IS RESERVED BY THE PROPERTIES AND NOT BY THE DRAWN WIDTH.
        // `marks` is empty most of the time -- the word appears under the pointer
        // -- so a margin conditioned on its width would open and close as the
        // mouse moved and re-wrap the second line while somebody read it.
        // `row.marked` is constant. A row with no mark at all gets the full
        // width, which is what the check table had.
        anchors.rightMargin: root.row.marked ? Theme.itemSpacing : 0

        anchors.verticalCenter: parent.verticalCenter

        spacing: 2

        Text {
            width: parent.width
            visible: root.row.rowLabel !== ""
            text: root.row.rowLabel

            // See the two-shape note at the top of this file.
            wrapMode: root.reading ? Text.WordWrap : Text.NoWrap
            elide: root.reading ? Text.ElideNone : Text.ElideRight

            font.family: Theme.fontFamily

            // Body, and Caption when the list is compact. NEVER BOLDER BECAUSE
            // THE ROW IS SELECTED: see the header. Windows carries selection in
            // the pill and nowhere else, and a list where the chosen row is
            // heavier than its neighbours is a list with a texture instead of a
            // list.
            font.pointSize: root.compact ? Fluent.captionSize : Fluent.bodySize
            font.weight: Fluent.normalWeight

            // TextFillColorPrimary in every state, selected included.
            color: Theme.textOnSurface
        }

        Text {
            width: parent.width
            visible: root.row.detail !== ""
            text: root.row.detail
            wrapMode: Text.WordWrap

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }

    // ---------------- The word on the right ----------------

    Row {
        id: marks

        anchors.right: parent.right
        anchors.rightMargin: root.padRight
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Invisible children take no space in a Row, so this collapses to
        // nothing on a row that has no mark and none under the pointer -- which
        // is what the column's right anchor is measuring against.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.markGlyph !== ""
            text: root.row.markGlyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.outline
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.selected ? root.row.mark : press.containsMouse ? root.row.hoverMark : ""
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }

    // ---------------- The click, where there is one ----------------
    //
    // THE WHOLE ROW IS THE TARGET, as it is for ToggleRow and for the same
    // reason -- and for a reading there is no target at all.
    //
    // THREE BINDINGS AND NOT A Loader, and this is the one decision in this file
    // worth arguing with. InfoRow's rule as README.md writes it is "no
    // MouseArea", full stop, and a `Loader { active: row.interactive }` around
    // this object would keep that to the letter. What it costs is that
    // everything inside a Loader's inline component is a NESTED component, so
    // `root` is out of scope there and every read of it comes back
    // `[unqualified]` -- three of them, in a file whose whole point is that rule
    // 1 gives the reads across the seam back their checking. Written like this,
    // the three lines that make a reading a reading are ordinary bindings on
    // `root.reading`, checked, and visible in one place:
    //
    //   enabled       false: the click cannot land, and `chosen` is never
    //                 emitted. Events pass through a disabled MouseArea to the
    //                 scroll surface behind it, which is what the check table
    //                 needs -- it lives inside one.
    //   hoverEnabled  false: `containsMouse` stays false, so the fill above
    //                 stays transparent and the word on the right stays empty.
    //   cursorShape   the arrow, which is Windows' own over a list row -- there
    //                 is no hand cursor anywhere in the shell -- so there is
    //                 nothing under the pointer to say this can be pressed.
    //
    // Anything that flips one of those three and not the other two turns a
    // reading into something that looks like a control, which is the bug the
    // rule is about. All three, or none.
    MouseArea {
        id: press

        anchors.fill: parent

        // MouseArea.enabled is a flag of its own and does not follow the item
        // tree, so `root.enabled` is forwarded by hand here where the item's own
        // is not. Rule 6 in README.md measures that and it is the opposite of
        // what it looks like.
        enabled: root.enabled && !root.reading

        hoverEnabled: !root.reading

        // WINDOWS DOES NOT CHANGE THE CURSOR OVER A LIST ROW. The hand is a web
        // idiom; Explorer, Settings and every WinUI list leave the arrow alone
        // and let the backplate do the saying. So there is no branch on
        // `root.reading` here, and that is not the promise being dropped -- it
        // is the promise arriving for free, because the shape a reading must not
        // have is a shape this theme never draws in the first place. The two
        // lines above still carry it.
        cursorShape: Qt.ArrowCursor

        onClicked: root.row.chosen()
    }
}
