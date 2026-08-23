// One application making noise: what it is called, where the sound is going,
// a mute button and a slider. THIS IS THE HALF THE PAGES SEE; the pixels are in
// themes/<theme>/components/StreamRow.qml.
//
// WHY IT IS NOT A ListRow, which is the question this file exists to answer.
// It was the fifth candidate for that merge and it was left out on purpose. A
// ListRow is a mark, a line of text and a word at the right end. This carries a
// VolumeSlider, a round mute button of its own, and a percentage whose width is
// pinned to a hidden Text on the literal "muted" so the number does not jog
// sideways when the word replaces it. Folding it in would have made one
// component carry five unrelated shapes and would have put a slider behind a
// property that four rows out of five never set.
//
// NO HOVER FILL ON THE ROW ITSELF, unlike the device rows the sound page draws
// above it. The row is not a target -- there is nowhere for a click on it to
// go, since this page cannot reroute a stream -- and InfoRow's rule applies:
// the cheapest way to tell a control from a reading is that a control lights
// up. The two things here that DO respond, the mute glyph and the slider, light
// up on their own. That is a promise about an absence, so it is written down in
// themes/genesis/components/StreamRow.qml as well, next to the half that keeps
// it.
//
// THE WRITES ARE HERE AND NOT IN THE THEME, and this is the one place this
// component departs from ToggleRow's shape. ToggleRow emits a request because
// it does not know what its switch is wired to; this one does -- `node` is a
// PipeWire node and it is on this side of the seam. So the theme asks, through
// the two functions below, and this half does it. A theme that wrote
// `row.node.audio.muted = ...` itself would need to know what a PipeWire node
// is, which rule 5 of themes/genesis/components/README.md says nothing under a
// theme directory may. The direction is still one-directional and still the
// same one: the theme reads a value and asks for a new one.
//
// The root was already an Item, so ToggleRow's question -- whether a Rectangle
// root was API or drawing -- did not arise. The check was run over both call
// sites anyway: they set `node`, `label`, `route`, `routePrefix`, `glyph` and
// `mutedGlyph`, and nothing else.

import QtQuick
// Themes, for the Loader at the foot of this file. `qs` itself is not needed:
// every design token this component uses is read on the other side of the seam.
import qs.modules

Item {
    id: root

    property var node: null

    property string label: ""
    property string route: ""

    // The preposition differs and the row would read as nonsense with the wrong
    // one: sound goes TO a pair of headphones and comes FROM a microphone.
    property string routePrefix: ""

    property string glyph: ""
    property string mutedGlyph: ""

    readonly property var audio: root.node?.audio ?? null
    readonly property bool muted: root.audio?.muted ?? false
    readonly property real volume: root.audio?.volume ?? 0

    // What the theme calls instead of writing. See the header.
    function toggleMute(): void {
        if (root.audio)
            root.audio.muted = !root.audio.muted;
    }

    // Moving the slider off zero un-mutes, because a slider that moves and
    // changes nothing is a control that lies. Unchanged from before the split.
    function setVolume(value: real): void {
        if (!root.audio)
            return;

        root.audio.volume = value;
        if (root.muted && value > 0)
            root.audio.muted = false;
    }

    // See ToggleRow's header: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // Fifty-two is what this row was before the split -- two stacked bands, the
    // name above and the slider below -- and it does not depend on a text
    // metric, so the theme reports the same number back. See ToggleRow for the
    // two ways a theme reports nothing and for why this reads the Loader rather
    // than `Loader.item`.
    implicitHeight: Math.max(52, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/StreamRow.qml")

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
