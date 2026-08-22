// The audio spectrum, and the shell's only cava.
//
// WHY cava AND NOT PwNodePeakMonitor
// Quickshell ships a peak monitor and it works -- probed against the live
// sink it returns two floats, one per channel, updating in real time. But two
// amplitudes are not a spectrum: everything driven from them rises and falls
// together, which reads as a level meter blinking rather than as music. The
// look this is for needs FREQUENCY bands, and getting those means an FFT.
//
// cava is the tool that already does it, it is in the official repos rather
// than the AUR, and it talks to PipeWire directly. One package and one
// process against writing an FFT in QML.
//
// IT WAS TWO PROCESSES AND TWO CONFIGS, and that was right for exactly as
// long as the two consumers wanted different shapes. The island drew fourteen
// fat bars in a capsule off `cava.conf`; the dashboard drew a continuous wave
// off `cava-wave.conf`, and a wave built from fourteen points is a zigzag, so
// sharing one feed would have meant one of them being wrong.
//
// The island draws the same wave now -- see Island.qml -- so both consumers
// want the same thing and there is one process, one config and one set of
// numbers. `cava.conf` and modules/island/Waveform.qml went with the bars.
//
// EIGHTY BANDS, AND THAT NUMBER SERVES BOTH. What decides it is how many
// pixels one segment of the drawing gets, not how many bands music has:
//
//   dashboard   the wave spans about 780 px   ->  9.8 px a segment
//   island      the capsule is 250 to 420 px  ->  3 to 5 px a segment
//
// end-4's is 50 for a 420px card, which is 8.4 px a segment; eighty holds
// that density at the panel's width, and the island is finer than it needs to
// be rather than coarser than it can afford, which is the right way round --
// a wave with more points than pixels still reads as a wave, and one with
// fewer reads as a chain of straight lines. Going further would change what
// the wave SHOWS, since bands are frequency bins rather than resolution.
//
// It only runs while something is actually playing: `running` is bound to the
// MPRIS state, so the process starts with the music and dies with it instead
// of sitting there consuming a core to animate a flat line.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Singleton {
    id: root

    // Must match `bars` in cava-wave.conf. Declared here too because a
    // consumer needs a length before the first frame arrives.
    readonly property int bands: 80

    // cava's ascii_max_range, stated in cava-wave.conf. The visualiser
    // divides by this itself, which is how end-4's is wired, so what is
    // published here is RAW.
    readonly property real maxValue: 1000

    // One value per band, raw. Empty until cava has said something, which is
    // what a visualiser reads as "nothing to draw".
    property var values: []

    // True while there is sound to visualise. Everything downstream keys off
    // this rather than off the process state, so a wave settles to flat
    // instead of freezing on the last frame when the music stops.
    //
    // Through Track, so this and every other "is something playing" in the
    // shell agree -- and so that the mirror playerctld puts on the bus is not
    // counted as a second player. See Track.qml.
    readonly property bool active: Track.players.some(p => p.isPlaying)

    onActiveChanged: if (!active)
        root.values = []

    Process {
        // -p: the shell's own config, not ~/.config/cava/config. That path
        // belongs to cava run as a terminal program, and this file is a
        // component of the shell -- which is still why the name carries a
        // suffix now that it is the only one.
        command: ["cava", "-p", Quickshell.shellPath("cava-wave.conf")]

        // Started by the music and stopped by it. cava with no sound still
        // runs a full FFT per frame, so leaving it up would cost a steady
        // slice of a core to animate nothing.
        running: root.active

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                // "0;12;40;...;3;" -- a trailing separator, hence the filter.
                const points = line.split(";")
                    .map(v => parseFloat(v.trim()))
                    .filter(v => !isNaN(v));
                if (points.length > 0)
                    root.values = points;
            }
        }
    }
}
