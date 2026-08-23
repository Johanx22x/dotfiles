// The round minus / plus of a StepperRow. THIS IS THE HALF THE PAGES SEE; the
// pixels are in themes/<theme>/components/StepperButton.qml.
//
// THE REPEAT STAYS HERE, ALL OF IT, and that is the whole reason this file is
// still worth reading after the split. A stepper that only answers one click
// per press is unusable over a range worth stepping through, so it repeats
// while held: 400ms before the first repeat -- long enough that a deliberate
// single click never triggers one -- and 60ms between them after that. Those
// two numbers are not a look. They are the difference between a control that
// feels like a key held down and one that runs away from you, they were
// arrived at by holding the thing, and a theme that reimplemented them would
// be guessing at them again. A theme draws a 26x26 shape and says when the
// pointer went down and when it came up; everything between those two events
// is below.
//
// IT FIRES ON PRESS AND NOT ON CLICK, which is a promise this file can no
// longer keep by itself and so is written down in the theme's file as well.
// The first step lands under the finger rather than on release, and the hold
// continues from it -- a theme wiring `onClicked` instead would still pass
// every check in tests/ and would lose both halves of that at once.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle. Same test ToggleRow's header
// sets out: a property of the current root type is public API if and only if a
// call site sets it. All four sites -- components/StepperRow.qml:178,216 and
// modules/settings/pages/display/CycleRow.qml:88,116 -- set `symbol`,
// `enabled`, `onTriggered` and `anchors.verticalCenter`, and not one of them
// sets `color` or `radius`. Both are drawing and both moved.
//
// AND THIS IS THE ONE THAT REPORTS A WIDTH, which rule 2 of
// themes/genesis/components/README.md forbids in so many words -- for rows.
// The reason it forbids it is a loop: a row is a child of a Column that sizes
// itself to its widest child, so a row sizing itself to the Column closes the
// circle. This is not a row. It is a 26-pixel button inside a Row that sizes
// itself to its children, it has never taken a width from its parent, and it
// cannot: StepperRow puts a number between two of these and both have to be
// as wide as they draw. So the width crosses upwards here exactly as the
// height does, and there is no loop because nothing below binds to it --
// checked, and it is the same check rule 2 asks for: the theme's implicit
// size is a pair of constants, not a function of the size it was given.

import QtQuick
import qs.modules

Item {
    id: root

    property string symbol: ""

    signal triggered

    // BOTH FLOORED AT 26, which is what this button was before the split, and
    // the floor covers the two ways a theme reports nothing: a file that did
    // not load, which Quickshell names in the log, and a root whose author
    // forgot an implicit size, which is 0 and would collapse the button into
    // the gap between the row's other two items without a word. Read off the
    // Loader and not off `Loader.item` -- see ToggleRow's header for why that
    // is a checked read and the other is not.
    implicitWidth: Math.max(26, drawing.implicitWidth)
    implicitHeight: Math.max(26, drawing.implicitHeight)

    // ---------------- What the theme calls ----------------
    //
    // TWO FUNCTIONS AND NOT A SIGNAL, because these are requests inward. The
    // theme owns the MouseArea -- it has to, the hover and press fills are
    // drawn from it -- and these are the only two things it may say about it.
    // Everything the timing turns on is on this side of them.

    // The pointer went down. The first step is immediate, which is the
    // press-not-click promise, and the clock to the first repeat starts here.
    function press(): void {
        root.triggered();
        repeatDelay.restart();
    }

    // The pointer came up, or the grab was taken away. Both mean the same
    // thing to the timers, so both arrive here: a theme's `onReleased` and its
    // `onCanceled` call this and there is nothing for it to tell them apart
    // by.
    function release(): void {
        repeatDelay.stop();
        repeat.stop();
    }

    Timer {
        id: repeatDelay
        interval: 400
        onTriggered: repeat.start()
    }

    Timer {
        id: repeat
        interval: 60
        repeat: true

        // THE GUARD, AND IT IS NOT DEFENSIVE PROGRAMMING. The button disables
        // itself when the value reaches the end of its range -- every call
        // site binds `enabled` to exactly that -- and a Timer already running
        // does not stop for it. Nor does the release handler arrive: the
        // pointer is still down, and a MouseArea that has gone disabled
        // mid-hold never sends one. Without this the value would keep stepping
        // past the end of its own range for as long as the finger stayed put.
        //
        // It reads `root.enabled` and that is the facade's own, which is what
        // the call site wrote. There is nothing to forward from the theme:
        // this is the same property, one level up the same tree.
        onTriggered: {
            if (!root.enabled) {
                repeat.stop();
                return;
            }
            root.triggered();
        }
    }

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/StepperButton.qml")

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
