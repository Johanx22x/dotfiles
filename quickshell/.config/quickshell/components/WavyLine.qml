// A sine drawn on a canvas, which is how end-4/dots-hyprland draws the played
// part of a seek bar and the fill of a progress bar.
//
// Ported from their modules/common/widgets/WavyLine.qml, and it is a Canvas
// because theirs is a Canvas. A Shape with a PathPolyline would draw the same
// curve and a shader would draw it more cheaply, but the instruction on this
// was fidelity to their build rather than a result that resembles it.
//
// THE PHASE IS WALL-CLOCK, not an animated property: `Date.now() / 400`. So
// every WavyLine on screen is at the same point in the wave regardless of when
// it was created, and a repaint that arrives late lands where it should rather
// than where the last frame left off. Nothing drives it on its own -- the
// caller repaints it, with a FrameAnimation while it should be moving.
//
// FULLLENGTH IS NOT WIDTH, and that separation is theirs and is the point of
// the component. The phase is computed against `fullLength` -- the whole rail
// -- while the loop only draws as far as `width`. So the played part of a seek
// bar is a window onto one continuous wave that spans the entire control,
// instead of a wave that gets squashed as the track plays.

import QtQuick
import "root:/"

Canvas {
    id: root

    // Half the line width, theirs. The wave therefore swings by exactly the
    // thickness of the line it is drawn with.
    property real amplitudeMultiplier: 0.5

    // Cycles across `fullLength`. Theirs.
    property real frequency: 6

    property color color: Theme.primary

    // Theirs, and the canvas wants to be several times this tall -- see the
    // note where the seek bar sizes it.
    property real lineWidth: 4

    property real fullLength: width

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const amplitude = root.lineWidth * root.amplitudeMultiplier;
        const frequency = root.frequency;
        const phase = Date.now() / 400.0;
        const centerY = height / 2;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.beginPath();

        for (let x = ctx.lineWidth / 2; x <= root.width - ctx.lineWidth / 2; x += 1) {
            const waveY = centerY + amplitude * Math.sin(frequency * 2 * Math.PI * x / root.fullLength + phase);
            if (x === 0)
                ctx.moveTo(x, waveY);
            else
                ctx.lineTo(x, waveY);
        }

        ctx.stroke();
    }
}
