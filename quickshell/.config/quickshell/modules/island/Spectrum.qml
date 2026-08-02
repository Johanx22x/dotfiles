// The audio spectrum behind the island's waveform.
//
// WHY cava AND NOT PwNodePeakMonitor
// Quickshell ships a peak monitor and it works -- probed against the live
// sink it returns two floats, one per channel, updating in real time. But two
// amplitudes are not a spectrum: bars driven from them all rise and fall
// together, which reads as a level meter blinking rather than as music. The
// look this is for needs FREQUENCY bands, and getting those means an FFT.
//
// cava is the tool that already does it, it is in the official repos rather
// than the AUR, and it talks to PipeWire directly. One package and one
// process against writing an FFT in QML.
//
// It only runs while something is actually playing: `running` is bound to the
// MPRIS state, so the process starts with the music and dies with it instead
// of sitting there consuming a core to animate a flat line.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Must match `bars` in cava.conf. Declared here too because the QML side
    // needs a length before the first frame arrives, or the waveform has
    // nothing to lay out at startup.
    readonly property int bars: 14

    // One value per bar, 0.0 .. 1.0. Starts flat so the island can draw a
    // resting waveform before cava has said anything.
    property var values: new Array(root.bars).fill(0)

    // True while there is sound to visualise. Everything downstream keys off
    // this rather than off the process state, so the waveform settles to flat
    // instead of freezing on the last frame when the music stops.
    readonly property bool active: Mpris.players.values.some(p => p.isPlaying)

    onActiveChanged: if (!active)
        root.values = new Array(root.bars).fill(0)

    Process {
        // -p: the shell's own config, not ~/.config/cava/config. See the
        // header of cava.conf.
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]

        // Started by the music and stopped by it. cava with no sound still
        // runs a full FFT per frame, so leaving it up would cost a steady
        // slice of a core to animate nothing.
        running: root.active

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                // "12;40;7;...;3;" -- a trailing separator, hence the filter.
                const parts = line.split(";").filter(v => v !== "");
                if (parts.length === 0)
                    return;

                // ascii_max_range is 100 in cava.conf.
                root.values = parts.map(v => Math.max(0, Math.min(1, Number(v) / 100)));
            }
        }
    }
}
