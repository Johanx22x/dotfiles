// HOW MUCH SOUND IS ACTUALLY GOING THROUGH, drawn under the slider that sets
// it, as a row of ticks.
//
// SEGMENTS AND NOT A SECOND FILLED BAR. That is the promise
// components/LevelMeter.qml makes and cannot enforce, and it is here because
// this is the only half that can keep it: the first version of this component
// drew a bar, and three pixels under a slider of the same length in the same
// colour it read as one control with a shadow, or as two sliders. Ticks cannot
// be misread that way at any size.
//
// WINDOWS HAS NO LEVEL METER, so every number in this file is OURS and says so
// in Fluent.qml -- the volume mixer animates a fill inside the slider's own
// track and there is nothing else in the shell that shows a signal level. What
// the ticks answer to is the sentence above, not a photograph, and the report
// that goes with this theme says as much rather than implying a source.
//
// THE MATHS IS NOT THE THEME'S AND IS NOT REDONE HERE. `row.level` arrives in
// decibels already -- 20*log10(peak) with the floor at -60 dB -- because
// hearing is logarithmic and PipeWire's peak is not, and a theme that squared
// the amplitude itself would be re-deriving a scale it has no way to check
// against the sound in the room. Same for `row.hotFrom`: 0.95 is -3 dB read
// off that exact scale, one fact in two lines, and it moves if the floor does.
// Read them; do not recompute either from `row.peak`.
//
// HEIGHT ONLY, NO WIDTH. A meter is anchored between the two ends of the
// slider above it by the call site, so there is no width for this file to have
// an opinion about -- and the facade floors the height at 4, which is what the
// meter was before it was split.
//
// THE HOISTS AT THE TOP ARE NOT TIDINESS. Everything inside a `Repeater`
// delegate is a nested component: `root.row.level` read down there is checked
// by nothing at all -- measured, in this very file's genesis counterpart, where
// a deliberately misspelt `row.hotFrmo` produced a named `[missing-property]`
// at the top level and SILENCE inside the delegate. So the three values cross
// the seam once, up here, through typed properties the linter can see.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property LevelMeter row

    // The three reads that cross the seam. Typed, and at the top level.
    readonly property real level: root.row.level
    readonly property real hotFrom: root.row.hotFrom
    readonly property color accent: root.row.accent

    implicitHeight: Fluent.meterHeight

    // How many ticks fit. The last one is allowed to fall off the end rather
    // than the pitch being stretched to make it fit: a meter that changed its
    // spacing with the width of the page would read as a different control on
    // a wider window.
    readonly property int ticks: Math.max(1,
        Math.floor((root.width + Fluent.meterPitch - Fluent.meterTick) / Fluent.meterPitch))

    Row {
        anchors.verticalCenter: parent.verticalCenter

        spacing: Fluent.meterPitch - Fluent.meterTick

        Repeater {
            model: root.ticks

            Rectangle {
                required property int index

                // Where this tick sits on the same 0..1 scale `level` is on.
                readonly property real at: (index + 1) / root.ticks
                readonly property bool lit: root.level >= at

                width: Fluent.meterTick
                height: Fluent.meterHeight
                radius: 1
                antialiasing: true

                // ONLY THE LAST FEW TICKS TAKE THE WARNING COLOUR, and only
                // once they are lit. A meter that turns red all at once says
                // "something is wrong now"; what is true is "you are close to
                // the top", which is what a red zone at one end of a scale
                // says. `Theme.critical` rather than an invented red: the
                // scheme has a role for this and rule 5 says to read it.
                color: !lit
                    ? Theme.surfaceContainerHighest
                    : (at >= root.hotFrom ? Theme.critical : root.accent)
            }
        }
    }
}
