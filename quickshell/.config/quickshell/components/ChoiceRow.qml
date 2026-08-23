// A settings row with a small closed set of answers. THIS IS THE HALF THE
// PAGES SEE; the pixels are in themes/<theme>/components/ChoiceRow.qml.
//
// WHAT AN OPTION IS, AND WHY THAT STAYED HERE. `options` is either a list of
// plain strings or a list of objects with `label` and `value`, and valueOf()
// and labelOf() below are the whole of that contract. It is not drawing: the
// font picker on AppearancePage stores "JetBrainsMono Nerd Font Propo" and
// shows "Propo", and a theme that reimplemented the unpacking could get that
// pair the wrong way round and be wrong about which font is selected rather
// than about how the selection looks. Themes read the two functions; nobody
// else has to know the shape.
//
// SEGMENTS RATHER THAN A DROPDOWN, and the ceiling that goes with it -- about
// four options at this width -- are the theme's now. They are a statement
// about what this control looks like and how much of it fits, which is the
// half of the seam that draws. themes/genesis/components/ChoiceRow.qml carries
// the reasoning; what stays here is that the set is CLOSED and SMALL, which is
// what makes this type the right one to reach for at a call site.
//
// It knows nothing about Config, the same as every other row: it takes a
// `value` and emits `chosen` to ask for a different one. The theme inherits
// that whole -- it reads `row.value` and calls `row.chosen()`, and writes to
// neither.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle. It was a Rectangle for `radius`
// and a hover fill, and both of those are drawing. The test ToggleRow's header
// sets out was run over all 10 call sites -- 9 written as `ChoiceRow {` and one
// as the `sourceComponent` of a Loader in BarPage.qml, which is the site that
// would have been missed by reading rather than extracting -- and NOTHING
// OUTSIDE THIS FILE SETS `color`, `radius` OR `border`. So none of the three is
// public API and all three moved behind the seam. What the call sites do set
// stayed: `glyph`, `label`, `options`, `value`, `hint`, `onChosen`, and the
// ordinary Item properties `visible` and `enabled`, which an Item carries too.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""

    // Either plain strings, or objects with `label` and `value` when what is
    // shown and what is stored differ -- which they do for font families,
    // where "Propo" is the useful label and "JetBrainsMono Nerd Font Propo"
    // is the value.
    property var options: []
    property var value: null

    property string hint: ""

    signal chosen(var value)

    // THE TWO HALVES OF AN OPTION, UNPACKED HERE AND NOT IN THE THEME. See the
    // header: this is the API's own contract about what a caller may put in
    // `options`, so it is checked, tested and fixed in one place rather than
    // once per theme.
    function valueOf(option: var): var {
        return option !== null && typeof option === "object" ? option.value : option;
    }

    function labelOf(option: var): string {
        return option !== null && typeof option === "object" ? option.label : String(option);
    }

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT, and this row is the
    // clearest case in the set for why the height crosses the seam upwards at
    // all. Before the split it read `Theme.groupHeight + segments.height - 4`
    // -- the label line, plus the segment track under it, less the overlap --
    // and every term after the first is a measurement of something that has
    // moved. There is no arithmetic left here that could stand in for it: a
    // theme drawing this control some other way has a different second storey
    // or none, and only it knows how tall that is.
    //
    // The floor is Theme.groupHeight, which is what a row of this shell is when
    // a theme reports nothing at all -- see ToggleRow for the two ways that
    // happens and for why this reads the Loader's implicit size rather than the
    // loaded item's.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/ChoiceRow.qml")

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
