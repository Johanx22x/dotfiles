// How genesis draws one row of a list. The public half -- what the four rows
// this replaced were, why `label` and `name` are two properties, and what
// `interactive: false` promises -- is components/ListRow.qml.
//
// `interactive: false` IS AN ABSENCE AND THIS FILE IS WHERE IT LIVES. The
// updates page's check table is a reading, not a list of choices: no hover
// fill, no pointer cursor, nothing to click, and no colour that changes because
// a pointer is over it. Its own header said it is "shaped like an InfoRow
// because it is one", and InfoRow.qml in this directory sets out at length why
// a facade cannot require that and this file can. How it is kept -- and why it
// is three bindings rather than the Loader InfoRow's rule would ask for -- is
// written out over the MouseArea at the foot of this file. Read that before
// changing any of the three.
//
// TWO SHAPES, AND WHICH ONE A ROW GETS IS WHETHER IT CAN BE CLICKED.
//
//   the choice   a line of text you can pick, optionally with a second line
//                under it. Tighter than a reading -- 2 between the lines, 12
//                around them -- and the text ELIDES, because a device name or
//                a codec is an identifier and half of one is still enough to
//                recognise. DeviceRow, PickRow and PkgRow.
//   the reading  InfoRow's own metrics to the pixel: 3 between the lines, 14
//                around them, and the text WRAPS, because a unit's title and
//                the sentence it wrote about itself are prose and prose cut off
//                at the width of a sidebar is prose nobody finishes. UnitRow.
//
// THE MARK ON THE LEFT HANGS FROM THE TOP OF THE TEXT WHEN THERE IS A SECOND
// LINE AND IS CENTRED WHEN THERE IS NOT, which is what the four sources did
// between them: DeviceRow and PkgRow centred a one-line row's glyph, PickRow
// and UnitRow hung theirs from the top of a column that might grow. A reading
// always hangs, because its column always might.
//
// AND IT IS THE ONE PLACE THE MERGE IS NOT PIXEL-FOR-PIXEL, which was measured
// rather than argued about: twenty before-and-after pairs were grabbed under a
// headless run and compared pixel by pixel, and nineteen came back byte for
// byte identical. The twentieth is a PickRow whose `detail` is empty -- on this
// machine, a codec with no caution to print -- where the glyph moves UP BY
// THREE PIXELS and nothing else on the row moves at all (measured: 121 pixels
// differ, all of them inside the glyph's own box, x 12..26).
//
// It cannot be both. DeviceRow and PickRow both draw a one-line row with a
// glyph, and they disagreed about where that glyph sits; one rule cannot
// reproduce two answers to the same question without a property invented to
// carry the disagreement. The rule kept is the one three of the four sources
// already followed, and the three pixels are on the side that was the odd one
// out -- PickRow's anchor was written for its two-line case and left the glyph
// hanging low when the second line was absent.
//
// `compact` IS THE PACKAGE LIST AND ONLY THE PACKAGE LIST. Half height, a pill
// instead of a rounded rectangle, the glyph at body size rather than icon size,
// the text two points under, and the selected state carried by ink alone rather
// than by the accent and a bolder weight. A pack can hold ninety rows, and at
// full size and full contrast ninety of them is a wall.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `ListRow` here is the facade and not
    // this file.
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

    // Whether the mark on the left hangs from the top of the text or sits in
    // the middle of it. Static per row: `detail` and `interactive` are both
    // constants at every call site, so nothing here moves while the row is on
    // screen.
    readonly property bool topAligned: root.reading || root.row.detail !== ""

    // ---------------- What the facade reads back ----------------
    //
    // Three numbers because the four sources had three, and each one is what
    // its source was rather than a fourth opinion about it. The facade floors
    // at the smallest of them and says why. `column` is as tall as the second
    // line wraps to, which is the only part of this nothing on the host side
    // can know.
    implicitHeight: {
        if (root.compact)
            return 26;

        if (root.reading)
            return Math.max(Theme.groupHeight, column.implicitHeight + 14);

        return Math.max(32, column.implicitHeight + 12);
    }

    radius: root.compact ? height / 2 : Theme.groupRadius

    // Nothing at all for a reading: the MouseArea at the foot of this file has
    // hoverEnabled false there, so containsMouse never becomes true.
    color: press.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // ---------------- The mark on the left ----------------

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding

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
        // is a checkbox sitting beside text two points under the body, and at
        // icon size it out-weighs the name it belongs to.
        font.pointSize: root.compact ? Theme.fontSize : Theme.iconSize

        // The accent marks the one in use and nothing else, exactly as the
        // network list marks the connected network.
        color: root.selected ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // The other kind of mark: a state word in a pill instead of a picture. Only
    // the reading uses one today. It hangs from the top of the column always,
    // and two pixels down rather than the glyph's one, because a 20-pixel pill
    // and a line of type do not sit on the same top edge.
    Chip {
        id: badge

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.top: column.top
        anchors.topMargin: 2

        visible: root.row.badge !== ""
        role: "badge"

        // `name` and not `label`: a state word is not a setting and putting it
        // under `label` would file fifteen of them in the settings search. The
        // facade's header has the whole of that.
        name: root.row.badge
        tone: root.row.badgeTone
    }

    // ---------------- The text ----------------

    Column {
        id: column

        // Whichever mark this row has. Both are anchored to this column's top,
        // and this column's top depends on its own height and its parent's --
        // never on theirs -- so there is no loop. InfoRow does the same.
        anchors.left: root.row.badge !== "" ? badge.right : glyph.right
        anchors.leftMargin: Theme.itemSpacing

        anchors.right: marks.left

        // THE GUTTER IS RESERVED BY THE PROPERTIES AND NOT BY THE DRAWN WIDTH.
        // `marks` is empty most of the time -- the word appears under the
        // pointer -- so a margin conditioned on its width would open and close
        // as the mouse moved and re-wrap the second line while somebody read
        // it. `row.marked` is constant. A row with no mark at all gets the full
        // width, which is what the check table had.
        anchors.rightMargin: root.row.marked ? Theme.itemSpacing : 0

        anchors.verticalCenter: parent.verticalCenter

        spacing: root.reading ? 3 : 2

        Text {
            width: parent.width
            visible: root.row.rowLabel !== ""
            text: root.row.rowLabel

            // See the two-shape note at the top of this file.
            wrapMode: root.reading ? Text.WordWrap : Text.NoWrap
            elide: root.reading ? Text.ElideNone : Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: root.compact ? Theme.fontSize - 2 : Theme.fontSize

            // A compact row keeps one weight throughout. Ninety rows of which
            // some are bold is a list with a texture instead of a list.
            font.weight: root.compact
                ? Font.Normal
                : root.selected ? Font.Bold : Theme.fontWeight

            color: root.compact
                ? (root.selected ? Theme.textOnSurface : Theme.textOnSurfaceVariant)
                : (root.selected ? Theme.primary : Theme.textOnSurface)

            // The interface's own pace where this colour carries a choice
            // somebody just made, and the palette's where it only ever changes
            // because the wallpaper did. Each keeps what its source had.
            Behavior on color {
                ColorAnimation {
                    duration: root.compact || root.reading
                        ? Theme.recolorDuration
                        : Theme.animDuration
                }
            }
        }

        Text {
            width: parent.width
            visible: root.row.detail !== ""
            text: root.row.detail
            wrapMode: Text.WordWrap

            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- The word on the right ----------------

    Row {
        id: marks

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
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
            font.pointSize: Theme.fontSize - 1
            color: Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.selected ? root.row.mark : press.containsMouse ? root.row.hoverMark : ""
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- The click, where there is one ----------------
    //
    // THE WHOLE ROW IS THE TARGET, as it is for ToggleRow and for the same
    // reason -- and for a reading there is no target at all.
    //
    // THREE BINDINGS AND NOT A Loader, and this is the one decision in this
    // file worth arguing with. InfoRow's rule as README.md writes it is "no
    // MouseArea", full stop, and a `Loader { active: row.interactive }` around
    // this object would keep that to the letter. It was written that way first.
    // What it costs is that everything inside a Loader's inline component is a
    // NESTED component, so `root` is out of scope there and every read of it
    // comes back as `[unqualified]` -- three of them, in a file whose whole
    // point is that rule 1 gives the reads across the seam back their checking.
    // Written like this, the three lines that make a reading a reading are
    // ordinary bindings on `root.reading`, checked, and visible in one place:
    //
    //   enabled       false: the click cannot land, and `chosen` is never
    //                 emitted. Events pass through a disabled MouseArea to the
    //                 scroll surface behind it, which is what the check table
    //                 needs -- it lives inside one.
    //   hoverEnabled  false: `containsMouse` stays false, so the fill above
    //                 stays transparent and the word on the right stays empty.
    //   cursorShape   the arrow, which is the settings window's own, so there
    //                 is nothing under the pointer to say this can be pressed.
    //
    // Anything that flips one of those three and not the other two turns a
    // reading into something that looks like a control, which is the bug the
    // rule is about. All three, or none.
    MouseArea {
        id: press

        anchors.fill: parent

        // MouseArea.enabled is a flag of its own and does not follow the item
        // tree, so `root.enabled` is forwarded by hand here where the item's
        // own is not. Rule 6 in README.md measures that and it is the opposite
        // of what it looks like.
        enabled: root.enabled && !root.reading

        hoverEnabled: !root.reading
        cursorShape: root.reading ? Qt.ArrowCursor : Qt.PointingHandCursor

        onClicked: root.row.chosen()
    }
}
