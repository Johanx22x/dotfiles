// How the windows theme draws a level meter. The public half -- what `peak` is,
// and why the amplitude is converted to decibels before it gets here -- is
// components/LevelMeter.qml.
//
// SEGMENTS AND NOT A SECOND FILLED BAR, and this is the promise the facade
// cannot require. The first version drew one, and on screen it was
// indistinguishable from the slider three pixels above it: two tracks of the
// same length in the same colour read as one control with a shadow, or as two
// sliders, and both readings are wrong. Ticks cannot be mistaken for something
// you drag, which is the entire job -- and they are what a meter has looked like
// since long before there were screens. A theme that draws a bar here loads,
// passes every check in tests/, and gives the sound page two sliders where it
// meant to have one.
//
// WINDOWS HAS NO METER, so there is nothing to copy and the numbers below are
// this file's rather than Microsoft's. What IS Microsoft's is the language they
// are written in: square ticks rather than rounded ones, the unlit ones in
// `ControlStrongFillColorDefault` -- the same grey the slider's own track uses
// -- and four pixels tall, which is `ProgressBar`'s height and the height the
// facade already floors at. The ticks are finer and closer together than
// genesis's for the same reason a Fluent progress bar is thinner than a
// Material one.
//
// THE SMOOTHING IS MOTION AND THAT IS WHY IT IS ON THIS SIDE. The monitor
// delivers about 25 samples a second and the segments would flicker between
// them. genesis picked 90ms by feel; this is ControlFasterAnimationDuration,
// 83, on WinUI's single easing spline -- near enough the same interval, and it
// is a duration the rest of the theme already moves at rather than a number of
// its own.
//
// AND THE COLOUR SWAP IS NOT SMOOTHED. genesis fades each tick between its two
// colours; Windows swaps a brush at time zero and a meter is a fast-moving
// thing, so a tick here lights and goes out in one frame. That is `Fluent.hoverMs`
// being 0 applied to something that is not a hover, and it is the right reading
// of the same rule.

import QtQuick
import qs
// LevelMeter is components/LevelMeter.qml -- the facade -- and not this file.
// The explicit import wins over the directory a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property LevelMeter row

    // WHAT THE FACADE READS BACK, AND IT IS THE ONLY THING IT READS. Four
    // pixels, always -- the facade floors at the same number. There is no width
    // contract at all: a meter is as wide as whatever it was put in.
    implicitHeight: 4

    // A tick is SQUARE -- as wide as the meter is tall -- with two pixels
    // between, so the pitch is six. Ours; see the header.
    //
    // Square rather than a width of its own, and it saves something real: the
    // delegate can write `width: height`, which is its OWN property and costs
    // nothing, where `width: root.tickWidth` would be a seventh unqualified
    // read of an outer id. Six warnings for a component genesis draws in five
    // would be this theme moving the lint baseline the wrong way.
    readonly property int tickGap: 2

    // The value actually drawn, which is the facade's level with the flicker
    // taken out of it. Held here rather than read straight off `row` because
    // the Behavior is the whole point of it, and a Behavior on somebody else's
    // property is not something this file may have.
    property real shown: root.row.level

    // ---- THE TWO THE DELEGATE WOULD OTHERWISE READ OFF `row` ----
    //
    // These look like the mirroring rule 3 forbids and they are the opposite of
    // it: rule 3 bans copying `label`, `title` and `glyph` because the settings
    // search walks the live tree and would find every row twice. Nothing walks
    // for these two, and hoisting them buys something specific that the delegate
    // cannot have.
    //
    // A TYPED `row` DOES NOT REACH INSIDE A DELEGATE. Measured in this file's
    // genesis twin, with `hotFrom` and `accent` deliberately misspelled in both
    // places at once: the read at THIS level produced
    // `Member "hotFrmo" not found on type "LevelMeter" [missing-property]` and
    // tests/qml-lint.sh went 19 -> 20 and failed, which is rule 1 working
    // exactly as README.md describes. The identical misspellings inside the
    // Repeater delegate below produced NOTHING AT ALL -- not a missing-property,
    // not even an [unqualified]. qmllint stops at the outer component's `root`
    // and does not follow through to `.row.<name>`.
    //
    // So every `row.<name>` inside a delegate is an unchecked read, which is the
    // state `property var row` would have put the whole file in. Hoisting moves
    // the read to where it IS checked and leaves the delegate binding to a local
    // name.
    //
    // WHAT HOISTING DOES NOT BUY, said plainly: the delegate still names `root`
    // for `shown`, `height` and the two below, and every one of those is an
    // [unqualified] read that only `pragma ComponentBehavior: Bound` could
    // resolve -- which tests/qml-lint.sh's own header rules out for this tree.
    // What hoisting fixes is the CHECKING, not the count: a misspelt local name
    // is still an unqualified read, but a misspelt `row.<name>` is nothing at
    // all. The alternative -- folding the colours into the Repeater's model so
    // the delegate reads only `modelData` -- rebuilds every tick on every one of
    // the twenty-five samples a second, which is a worse trade than four
    // warnings.
    readonly property real hotFrom: root.row.hotFrom
    readonly property color accent: root.row.accent

    Behavior on shown {
        NumberAnimation {
            duration: Fluent.fasterMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    Row {
        id: ticks

        anchors.fill: parent
        spacing: root.tickGap

        // From the width rather than a fixed count, so the ticks keep their size
        // when the window is resized instead of stretching.
        readonly property int count: Math.max(1, Math.floor((width + spacing) / (root.height + root.tickGap)))

        Repeater {
            model: ticks.count

            delegate: Rectangle {
                required property int index

                // Through the id and not through `parent`: a delegate is
                // reparented on the way into the Row, so a binding that reads
                // parent.count evaluates once against nothing.
                readonly property real position: (index + 1) / ticks.count
                readonly property bool lit: root.shown >= position

                // `height` from the meter, `width` from this rectangle's own
                // height: see the note on tickGap above for why the second one
                // is written that way round.
                height: root.height
                width: height

                // Square. Windows' progress and slider fills are capsules, but
                // a three-pixel tick with a radius is a dot, and a row of dots
                // is not a meter.
                radius: 0

                // THROUGH THE HOISTED NAMES AND NOT THROUGH `row`. Both still
                // come from the facade -- `hotFrom` is -3 dB on the scale the
                // facade's own maths defines, and the note beside it there says
                // why the number and its floor are one fact -- but they are read
                // at the top of this file, where qmllint can check them.
                // `root.row.hotFrom` written here instead would be spelled
                // however it was spelled, for ever, in silence.
                //
                // SystemFillColorCaution for the last few ticks, and only the
                // last few: a meter that changes colour all at once says
                // "something is wrong now", and what is true is "you are close
                // to the top".
                color: !lit ? Theme.outline
                    : position > root.hotFrom ? Theme.warning
                    : root.accent
            }
        }
    }
}
