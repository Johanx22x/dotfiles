// The waveform: one rounded bar per frequency band, sitting beside the track
// title inside the island's capsule.
//
// It was tried as a BACKGROUND spanning the whole capsule with the title on
// top. It did not work: faint enough not to fight the words it was barely
// visible, and strong enough to see it made the text hard to read. Beside the
// title it gets to be itself.
//
// SHAPE
// Bars grow from the CENTRE outwards, not up from a baseline. A capsule has
// no floor to stand on -- anchored to the bottom the waveform reads as a
// chart that happens to be inside a pill, while mirrored around the middle it
// reads as part of the capsule and sits on the text's axis. It also means the
// resting state is a row of dots on the centre line, which is the same
// vocabulary the workspaces use.
//
// COLOUR
// A gradient across the bars from primary to tertiary, both from the
// wallpaper. Two roles rather than one because a single accent makes the
// waveform a solid block of colour; and these two specifically because
// matugen derives them from the same image, so they always agree -- picking a
// second colour by hand would be a new thing to get wrong on every wallpaper.
//
// MOTION
// Every bar animates its own height over a few frames. cava already smooths
// its output, but at 60fps the last step is still visible as a flicker, and
// the animation is what turns a sequence of readings into movement.

import QtQuick
import "root:/"

Row {
    id: root

    // Tallest a bar can get: the capsule's height less room to breathe at top
    // and bottom. Derived rather than a number of its own, so the waveform
    // keeps its proportions if the bar's height is ever changed again.
    property int maxHeight: Theme.groupHeight - 10

    // Thicker than a hairline: next to text at 11pt, 3px bars read as noise
    // rather than as bars.
    property int barWidth: 4

    // What a silent bar looks like: a dot on the centre line rather than
    // nothing, so the waveform holds its shape between tracks.
    readonly property int minHeight: barWidth

    spacing: 3
    height: maxHeight

    Repeater {
        model: Spectrum.bars

        Rectangle {
            id: bar

            required property int index

            readonly property real value: Spectrum.values[index] ?? 0

            width: root.barWidth
            height: root.minHeight + bar.value * (root.maxHeight - root.minHeight)
            radius: width / 2

            // Centred in the row: this is what mirrors the bar around the
            // middle instead of standing it on the bottom edge.
            anchors.verticalCenter: parent.verticalCenter

            color: Qt.tint(Theme.primary, Qt.alpha(Theme.tertiary, bar.index / (Spectrum.bars - 1)))

            // Quiet bars fade as well as shrink. Height alone leaves a hard
            // row of dots at rest; opacity makes the tail of the spectrum
            // recede instead of sitting there.
            opacity: 0.45 + bar.value * 0.55

            Behavior on height {
                NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
            }

            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
