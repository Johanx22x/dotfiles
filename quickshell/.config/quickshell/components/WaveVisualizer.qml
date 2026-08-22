// The audio spectrum drawn as ONE CONTINUOUS WAVE across the media card,
// which is what end-4/dots-hyprland put behind theirs.
//
// Ported from their modules/common/widgets/WaveVisualizer.qml. This shell
// already had a spectrum -- a row of rounded bars in the island -- and the
// first port of the media card reused it. That was the wrong call and was
// rejected: the bars were the island's shape and the point of the card was to
// look like theirs. The bars are gone entirely now; this draws the spectrum
// everywhere in the shell that one is drawn.
//
// It is a Canvas because theirs is a Canvas, and it fills one closed path from
// the bottom-left corner, along the spectrum, to the bottom-right -- so the
// wave is a filled silhouette rather than a stroked line, at 0.15 alpha, and
// then blurred. That blur is theirs too and is doing real work: at 50 bands
// the raw path is visibly polygonal, and MultiEffect at blurMax 7 is what
// turns a chain of line segments into something that reads as a wave.

import QtQuick
import QtQuick.Effects
import "root:/"

Canvas {
    id: root

    // Raw cava values, NOT normalised -- see maxVisualizerValue.
    property var points: []

    // The last set of points after the moving average below. Kept as a
    // property because theirs is.
    property var smoothPoints: []

    // cava's ascii_max_range. 1000 is cava's own default and their config
    // does not override it; ours does not either, for this feed.
    property real maxVisualizerValue: 1000

    // Points either side of each sample to average over. Theirs is 2, so each
    // value is the mean of five.
    property int smoothing: 2

    // False collapses the wave to the baseline rather than freezing it on the
    // last frame it was given.
    property bool live: true

    property color color: Theme.primary

    onPointsChanged: root.requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const points = root.points;
        const maxVal = root.maxVisualizerValue || 1;
        const h = height;
        const w = width;
        const n = points.length;
        if (n < 2)
            return;

        // Simple moving average, clamped at both ends so the first and last
        // bands are not dragged toward zero by samples that do not exist.
        const smoothWindow = root.smoothing;
        const smoothed = [];
        for (let i = 0; i < n; ++i) {
            let sum = 0;
            let count = 0;
            for (let j = -smoothWindow; j <= smoothWindow; ++j) {
                const idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            smoothed.push(sum / count);
        }
        if (!root.live)
            smoothed.fill(0);
        root.smoothPoints = smoothed;

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (let i = 0; i < n; ++i) {
            const x = i * w / (n - 1);
            const y = h - (smoothed[i] / maxVal) * h;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.15);
        ctx.fill();
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        source: root
        saturation: 0.2
        blurEnabled: true
        blurMax: 7
        blur: 1
    }
}
