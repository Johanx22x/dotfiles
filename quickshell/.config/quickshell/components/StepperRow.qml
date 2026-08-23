// A settings row that holds a number. THIS IS THE HALF THE PAGES SEE; the
// pixels are in themes/<theme>/components/StepperRow.qml.
//
// A STEPPER AND NOT A SLIDER, which is a decision about the API and therefore
// stays here. Both values this shell has to offer -- an opacity in whole
// percent and a timeout in whole seconds -- have a small number of useful
// positions and one number that matters. A slider hides that number behind a
// handle position, cannot be nudged by one, and needs a drag gesture to do
// what a click does here. Sliders earn their place over continuous ranges;
// these are not. That is why the properties below are `from`, `to` and `step`
// rather than a range and a position, and why the signal is `moved(int)`.
//
// THE CLAMPING IS HERE AND THE BUTTONS ARE NOT. nudge() below is the rule
// about what a step is allowed to produce -- inside the range, and silent when
// the value would not move -- and a theme calls it rather than doing the
// arithmetic. A theme that clamped for itself could emit `moved` with the
// value the row already has, which is a write to Config for no change, or
// could emit one outside [from, to] and put a number on screen the page never
// offered. It draws the minus and the plus; what a press MEANS is this file's.
//
// Same contract as ToggleRow: it displays `value` and asks for a new one
// through the signal. It does not write anything itself.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle. It was a Rectangle for `radius`
// and a hover fill, and both are drawing. The test ToggleRow's header sets out
// was run over all 18 call sites and NOTHING OUTSIDE THIS FILE SETS `color`,
// `radius` OR `border`, so all three moved behind the seam. What the call sites
// do set stayed: `glyph`, `label`, `value`, `from`, `to`, `step`, `suffix`,
// `display`, `hint`, `onMoved`, and the ordinary Item properties `enabled` --
// four sites -- and `visible` -- one.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    // Shown after the number, e.g. "%" or " s". Part of the label rather than
    // of the value, so the arithmetic never has to parse it back out.
    property string suffix: ""

    // Shown INSTEAD of the number when it is set.
    //
    // FOR VALUES THAT ARE NOT READ AS NUMBERS. A time of day steps in half
    // hours and is stored as minutes since midnight, because that is the only
    // representation the arithmetic is simple in -- but "1230 min" is not a
    // time and nobody reading it would know what it meant. The stepper keeps
    // the range, the step and the clamping; only the few characters on screen
    // become the caller's.
    property string display: ""

    // Optional. A row with one grows an info glyph after its label, and the
    // note appears under it on hover. Empty means no glyph at all -- a mark
    // that is always there and usually says nothing trains the eye to skip
    // it.
    property string hint: ""

    signal moved(int value)

    // THE RULE ABOUT WHAT A STEP PRODUCES. Clamped to the range, and SILENT
    // when the value would not move: at `to` the plus emits nothing at all
    // rather than emitting the number that is already there. The theme's plus
    // and minus call this with `+row.step` and `-row.step` and read nothing
    // back -- the new value arrives the way every other value does, through
    // the page, back into `value`.
    function nudge(delta: int): void {
        const next = Math.max(root.from, Math.min(root.to, root.value + delta));
        if (next !== root.value)
            root.moved(next);
    }

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT. This row was one line
    // tall before the split and this theme's is still one line tall, so the
    // number the Loader reports and the floor under it agree today -- which is
    // the point rather than a redundancy: a theme that stacks the stepper under
    // the label the way ChoiceRow stacks its segments reports a bigger one and
    // the section grows to fit. See ToggleRow for the two ways a theme reports
    // nothing and for why this reads the Loader's implicit size rather than the
    // loaded item's.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/StepperRow.qml")

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
