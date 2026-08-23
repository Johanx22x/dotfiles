// One row of a list of things: a mark on the left, a line of text, sometimes a
// second line under it, sometimes a word on the right saying what the row IS or
// what a click would do to it. THIS IS THE HALF THE PAGES SEE; the pixels are
// in themes/<theme>/components/ListRow.qml.
//
// WHAT IT REPLACED, and why one type instead of four. The sound page's
// DeviceRow, the recording page's PickRow and the updates page's UnitRow and
// PkgRow were four inline components drawing the same row four times over --
// glyph, text, hover fill, a word at the right end -- each with its own copy of
// the accent rule and its own Behaviors. PickRow's own header already said it
// "is very nearly that page's DeviceRow", and the difference it named was
// knowledge about PipeWire that lived in the properties, not in the pixels. So
// the pixels are here once and the knowledge stayed on the pages.
//
// CycleRow AND Reading ARE NOT IN THAT LIST and that was checked rather than
// overlooked. CycleRow takes no clicks by design and holds two StepperButtons
// around a width-pinned value -- its relative is StepperRow, not this. Reading
// is a two-column definition list with a right-aligned, middle-elided value,
// and Text.AlignRight appears three times in the whole tree. Both belong to the
// settings-chrome work, and folding either one in here would have bought a
// fifth unrelated shape for nothing.
//
// THE ROOT IS AN Item AND THREE OF THE FOUR SOURCES WERE Rectangles. The test
// is ToggleRow's and the answer is the same: a property of the old root is
// public API if and only if a call site set it. Over all nine call sites,
// nothing sets `color`, `radius` or `border`; all three are drawing and all
// three moved behind the seam. What the sites DO set is below, plus the
// ordinary Item properties `width` and `visible`.
//
// ---------------------------------------------------------------------------
// `label` OR `name`, AND THE DIFFERENCE IS THE SETTINGS SEARCH
// ---------------------------------------------------------------------------
//
// This is the one part of the API that looks redundant and is not.
//
// modules/settings/SettingsSearch.qml builds its index by walking the live
// object tree and duck-typing: a row is anything with a non-empty string
// `label`. Nothing opts in and nothing can opt out. So of the four rows merged
// here, PickRow -- which had a `label` -- was in the search index, and
// DeviceRow, UnitRow and PkgRow -- which had `node.description`, `title` and
// `name` -- were not. That difference was an accident of naming, and one
// property called `label` would have silently changed it in one direction or
// the other: either the recording page's answers drop out of the search, or
// every audio device, every check-table row and every package name in an
// opened pack drops in. On this machine the second is about twenty entries
// with nothing open and ninety more with one pack expanded.
//
// So the accident is made a decision instead. Both names hold the row's one
// line of text, both are drawn identically, and the call site picks:
//
//   label:  this row is a setting somebody might search for.
//   name:   this row is machine data -- a device, a package, a unit.
//
// Set exactly one. `rowLabel` below is what the theme draws.
//
// ---------------------------------------------------------------------------
//
// `interactive: false` IS A PROMISE ONLY THE THEME CAN KEEP. UnitRow's header
// said it is "shaped like an InfoRow because it is one -- no hover, no cursor,
// nothing to click", and a facade has no way to require an absence: there is no
// signal to leave unconnected and no property to leave unread. It is written
// down in themes/genesis/components/ListRow.qml next to the half that keeps it,
// which is the same arrangement InfoRow has and for the same reason.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // ---------------- The mark on the left ----------------

    // A glyph, or a badge, and never both: three of the four sources lead with
    // a glyph and the fourth leads with a state word in a Chip.
    property string glyph: ""

    property string badge: ""

    // THE BADGE'S COLOUR COMES FROM THE PAGE, which looks like design crossing
    // the seam and is the opposite of it. `ok`, `missing` and `drift` are the
    // installer's own vocabulary -- they appear in the check table, in the
    // README and in this repository's commit messages -- and which Theme role
    // each one takes is a statement about that engine, not about this row. The
    // page keeps the switch; this carries its answer.
    property color badgeTone: Theme.textOnSurfaceVariant

    // ---------------- The text ----------------

    // See the long note above. Set one of these, never both.
    property string label: ""
    property string name: ""

    readonly property string rowLabel: root.label !== "" ? root.label : root.name

    // A second line, muted, and empty is normal: the connector for a screen,
    // the node name for a microphone, the sentence a failing unit wrote about
    // itself. A list where every row has one is a list nobody reads. The row
    // grows to fit it rather than eliding it -- an explanation cut off at the
    // width of a sidebar is one nobody finishes.
    property string detail: ""

    // ---------------- The word on the right ----------------
    //
    // Says what this row IS, or what a click would do to it -- never both, and
    // never a repetition of what the row already shows.

    // Shown while `selected`.
    property string mark: ""

    // Shown under the pointer while NOT selected.
    property string hoverMark: ""

    // A small glyph before the word: the sound page marks a muted output with
    // one, and this machine is the argument -- two of its four outputs sit at
    // zero and muted, and switching to one of them and hearing nothing is a
    // minute of thinking the change failed.
    property string markGlyph: ""

    // WHETHER THIS ROW RESERVES THE GUTTER AT ITS RIGHT END, and it is read off
    // the properties rather than off the drawn width on purpose. The word
    // itself comes and goes with the pointer, so a gutter measured from the
    // drawn mark would breathe under the pointer and take the text's wrapping
    // with it. These three are constants at every call site that sets them.
    readonly property bool marked: root.mark !== "" || root.hoverMark !== ""
        || root.markGlyph !== ""

    // ---------------- What the row is ----------------

    // The one in use. The accent marks it and nothing else, exactly as the
    // network list marks the connected network.
    property bool selected: false

    // Half height, smaller type, and a pill instead of a rounded rectangle. A
    // pack on the updates page can hold ninety of these and a list of ninety
    // full-height rows is a page nobody scrolls to the end of.
    property bool compact: false

    // False is InfoRow's contract: no hover, no cursor, nothing to click, and
    // `chosen` never emitted. See the header note above -- the theme is the
    // only half that can keep it.
    property bool interactive: true

    signal chosen

    // See ToggleRow's header: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT, and here the floor is
    // the SMALLEST of the four the sources had rather than a fifth opinion.
    // DeviceRow was a flat 32 and PickRow floored at 32; UnitRow floored at
    // Theme.groupHeight, which is 36, and the theme reports that back itself,
    // so flooring here at 32 never clips it. PkgRow was 26 and nothing else is,
    // which is what `compact` is doing in this line.
    //
    // The floor's job is not to be the right height -- the theme's is. It is to
    // cover the two ways a theme reports nothing: a file that did not load,
    // which Quickshell names once per row, and a root Item whose author forgot
    // implicitHeight, which is 0, warns about nothing, and would drop the row
    // out of its section in silence. See ToggleRow for why this reads the
    // Loader rather than `Loader.item`.
    implicitHeight: Math.max(root.compact ? 26 : 32, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/ListRow.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
