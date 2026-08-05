// How much sound is actually going through, drawn under the slider that sets
// it.
//
// WHY IT EARNS ITS PIXELS. A volume slider says what the level is SET to,
// which is not the question anybody has when something is wrong -- "is this
// microphone hearing me", "which of these four outputs is the music coming
// out of". A meter answers both by moving, and nothing else on the page can.
//
// SEGMENTS AND NOT A SECOND FILLED BAR. The first version drew one, and on
// screen it was indistinguishable from the slider three pixels above it: two
// tracks of the same length in the same colour read as one control with a
// shadow, or as two sliders, and both readings are wrong. Ticks cannot be
// mistaken for something you drag, which is the entire job -- and they are
// what a meter has looked like since long before there were screens.
//
// DECIBELS AND NOT THE RAW PEAK. PipeWire reports peak amplitude, 0..1, and
// spacing that linearly makes an ordinary listening level sit in the first
// tenth of the scale and never visibly move -- hearing is logarithmic and the
// amplitude is not. So the amplitude is converted the way every meter ever
// built converts it, with the floor at -60 dB, which is quiet enough to read
// as silence. Measured while music played: peak 0.2 lands at about three
// quarters, which is where -14 dBFS belongs.

import QtQuick
import "root:/"

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

    // The value actually drawn. The monitor delivers about 25 samples a
    // second and the segments would flicker between them; the animation is
    // short enough that the bar still looks like the sound it is made of.
    property real shown: root.level

    Behavior on shown {
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }

    // Within 3 dB of full scale, where the next thing that happens is
    // clipping. Only the last few ticks take the warning colour rather than
    // the whole bar turning: a meter that changes colour all at once says
    // "something is wrong now", and what is true is "you are close to the
    // top", which is what a red zone at one end of a scale says.
    readonly property real hotFrom: 0.95

    implicitHeight: 4

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
