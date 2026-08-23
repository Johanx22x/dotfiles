// How genesis draws a level meter. The public half -- what `peak` is, and why
// the amplitude is converted to decibels before it gets here -- is
// components/LevelMeter.qml.
//
// SEGMENTS AND NOT A SECOND FILLED BAR, and this is the promise the facade
// cannot require. The first version drew one, and on screen it was
// indistinguishable from the slider three pixels above it: two tracks of the
// same length in the same colour read as one control with a shadow, or as two
// sliders, and both readings are wrong. Ticks cannot be mistaken for something
// you drag, which is the entire job -- and they are what a meter has looked
// like since long before there were screens. A theme that draws a bar here
// loads, passes every check in tests/, and gives the sound page two sliders
// where it meant to have one.
//
// THE SMOOTHING IS MOTION AND THAT IS WHY IT IS ON THIS SIDE. The monitor
// delivers about 25 samples a second and the segments would flicker between
// them. Ninety milliseconds is short enough that the bar still looks like the
// sound it is made of and long enough that it is not a strobe -- but it is a
// judgement about how a thing should move, which is the theme's, and a theme
// with a different idea changes it here and nothing else.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `LevelMeter` here is the facade and not
    // this file.
    required property LevelMeter row

    // WHAT THE FACADE READS BACK. Four pixels, always -- the facade floors at
    // the same number, so this is what it was before the split rather than a
    // second opinion about it.
    implicitHeight: 4

    // The value actually drawn, which is the facade's level with the flicker
    // taken out of it. Held here rather than read straight off `row` because
    // the Behavior is the whole point of it, and a Behavior on somebody else's
    // property is not something this file may have.
    property real shown: root.row.level

    // ---- THE TWO THE DELEGATE WOULD OTHERWISE READ OFF `row` ----
    //
    // These look like the mirroring rule 3 forbids and they are the opposite
    // of it: rule 3 bans copying `label`, `title` and `glyph` because the
    // settings search walks the live tree and would find every row twice.
    // Nothing walks for these two, and hoisting them buys something specific
    // that the delegate cannot have.
    //
    // A TYPED `row` DOES NOT REACH INSIDE A DELEGATE. Measured in this file,
    // with `hotFrom` and `accent` deliberately misspelled in both places at
    // once: the read at THIS level produced
    // `Member "hotFrmo" not found on type "LevelMeter" [missing-property]`
    // and tests/qml-lint.sh went 19 -> 20 and failed, which is rule 1 working
    // exactly as README.md describes. The identical misspellings inside the
    // Repeater delegate below produced NOTHING AT ALL -- not a
    // missing-property, not even an [unqualified]. qmllint stops at the outer
    // component's `root` and does not follow through to `.row.<name>`.
    //
    // So every `row.<name>` inside a delegate is an unchecked read, which is
    // the state `property var row` would have put the whole file in. Hoisting
    // moves the read to where it IS checked and leaves the delegate binding to
    // a local name. See rule 1 in README.md, which now carries this.
    readonly property real hotFrom: root.row.hotFrom
    readonly property color accent: root.row.accent

    Behavior on shown {
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }

    Row {
        id: ticks

        anchors.fill: parent
        spacing: 3

        // From the width rather than a fixed count, so the ticks keep their
        // size when the window is resized instead of stretching. 4 wide on a
        // pitch of 7.
        readonly property int count: Math.max(1, Math.floor((width + spacing) / 7))

        Repeater {
            model: ticks.count

            delegate: Rectangle {
                required property int index

                // Through the id and not through `parent`: a delegate is
                // reparented on the way into the Row, so a binding that reads
                // parent.count evaluates once against nothing.
                readonly property real position: (index + 1) / ticks.count
                readonly property bool lit: root.shown >= position

                width: 4
                height: root.height
                radius: 1

                // THROUGH THE HOISTED NAMES AND NOT THROUGH `row`. Both still
                // come from the facade -- `hotFrom` is -3 dB on the scale the
                // facade's own maths defines, and the note beside it there
                // says why the number and its floor are one fact -- but they
                // are read at the top of this file, where qmllint can check
                // them. `root.row.hotFrom` written here instead would be
                // spelled however it was spelled, for ever, in silence.
                color: !lit ? Theme.surfaceContainerHighest
                    : position > root.hotFrom ? Theme.warning
                    : root.accent

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }
        }
    }
}
