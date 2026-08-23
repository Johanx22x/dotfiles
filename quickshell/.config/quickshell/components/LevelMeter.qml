// How much sound is actually going through, drawn under the slider that sets
// it. THIS IS THE HALF THE PAGES SEE; the ticks are in
// themes/<theme>/components/LevelMeter.qml.
//
// WHY IT EARNS ITS PIXELS. A volume slider says what the level is SET to,
// which is not the question anybody has when something is wrong -- "is this
// microphone hearing me", "which of these four outputs is the music coming
// out of". A meter answers both by moving, and nothing else on the page can.
//
// DECIBELS AND NOT THE RAW PEAK, AND THAT IS WHY THE MATHS STAYED HERE.
// PipeWire reports peak amplitude, 0..1, and spacing that linearly makes an
// ordinary listening level sit in the first tenth of the scale and never
// visibly move -- hearing is logarithmic and the amplitude is not. So the
// amplitude is converted the way every meter ever built converts it, with the
// floor at -60 dB, which is quiet enough to read as silence. Measured while
// music played: peak 0.2 lands at about three quarters, which is where
// -14 dBFS belongs.
//
// None of that is a look. It is what the number MEANS, and a theme that did it
// itself would be re-deriving a scale it has no way to check against the sound
// in the room. What crosses the seam is `level`, already in the units a bar is
// drawn in.
//
// SEGMENTS AND NOT A SECOND FILLED BAR, which is the theme's, and is the one
// promise about this component that no property here can require. The first
// version drew a bar, and on screen it was indistinguishable from the slider
// three pixels above it: two tracks of the same length in the same colour read
// as one control with a shadow, or as two sliders, and both readings are
// wrong. It is written down in the theme's file, next to the half that can
// keep it.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // Straight off a PwNodePeakMonitor.
    property real peak: 0

    // False parks it at zero instead of showing the last value it saw. The
    // page turns its monitors off when it is not on screen, and a meter that
    // froze mid-swing would look like sound that never stopped.
    property bool active: true

    property color accent: Theme.primary

    readonly property real level: {
        if (!root.active || root.peak <= 0)
            return 0;

        const db = 20 * Math.log10(root.peak);
        return Math.max(0, Math.min(1, (db + 60) / 60));
    }

    // Within 3 dB of full scale, where the next thing that happens is
    // clipping. Only the last few ticks take the warning colour rather than
    // the whole bar turning: a meter that changes colour all at once says
    // "something is wrong now", and what is true is "you are close to the
    // top", which is what a red zone at one end of a scale says.
    //
    // IT IS HERE AND NOT IN THE THEME EVEN THOUGH NO CALL SITE SETS IT, which
    // is the one place this component departs from "API is what a call site
    // writes". 0.95 is not a position somebody liked the look of; it is -3 dB
    // read off the scale `level` above defines, and the two are one fact in
    // two lines. Move the floor from -60 and this number means something else
    // -- so it has to be able to move with it, and it cannot do that from the
    // other side of the seam.
    readonly property real hotFrom: 0.95

    // Four is what the meter was before the split. See ToggleRow's header for
    // the two ways a theme reports nothing and for why this reads the Loader
    // rather than `Loader.item`.
    implicitHeight: Math.max(4, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/LevelMeter.qml")

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
