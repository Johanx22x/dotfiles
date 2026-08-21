// What this graphics card can actually encode, asked of the recorder itself.
//
// `gpu-screen-recorder --info` prints a small machine-readable report -- lines
// of `section=NAME` followed by that section's entries -- and one of those
// sections is the list of video codecs THIS machine has an encoder for. That
// is the only honest source for the codec picker on the recording page: gsr is
// a hardware recorder, so a codec it does not list is not a slower recording,
// it is a buffer that refuses to arm. On this desktop, with an NVIDIA card,
// the list is fifteen entries long; on the RX 6400 in the note in
// ReplayState it would be very short indeed.
//
// ASKED ONCE AND KEPT. The command takes about half a second and it opens the
// DRM device to enumerate, so it is not something to run inside a binding --
// which is what a codec list built by a `Repeater` over a function would end
// up doing, once per delegate per repaint.
//
// AND ASKED ONLY WHEN SOMEBODY LOOKS. Nothing in the shell needs this until
// the recording page is on screen: the recorder itself is given a codec name
// or no -k flag at all, and gsr validates its own arguments. So the page calls
// probe() from `onScreen`, the same gate the sound page's meters use, and a
// machine where that page is never opened never runs this.
//
// WHAT IS PARSED IS ONE SECTION AND THE REST IS SKIPPED ON PURPOSE. --info
// also reports the display server, the GPU vendor, the capture options and
// every mode of every v4l2 device on the machine -- 200-odd lines here, mostly
// webcam resolutions. Two of those are things the shell already knows better
// from elsewhere (the monitors come from Screens), so taking them from here
// would be a second answer to a settled question.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // The codec names, exactly as gsr spells them, because they go back to gsr
    // as -k. No prettifying at this layer: the page can put "H.264" in front
    // of a reader, but the string stored in the config has to be the one the
    // recorder answers to.
    readonly property var videoCodecs: root.parsed

    // Has an answer been had? Three states rather than two, because "not asked
    // yet" and "asked and it said nothing" want different words on screen: the
    // first is a list that is about to appear, the second is a machine where
    // gpu-screen-recorder is not installed or would not run.
    readonly property bool probing: probe.running
    property bool probed: false

    readonly property bool failed: root.probed && root.parsed.length === 0

    property var parsed: []

    // Idempotent, and it has to be: the page asks every time it is looked at.
    function refresh(): void {
        if (root.probed || probe.running)
            return;

        probe.running = true;
    }

    Process {
        id: probe

        command: ["gpu-screen-recorder", "--info"]

        stdout: StdioCollector {
            id: info
        }

        onExited: exitCode => {
            root.probed = true;

            // A non-zero exit is a machine without gsr, or one where it could
            // not reach the GPU. Nothing to report and nothing to guess: the
            // page says the list could not be read, and the recorder is left
            // to pick for itself.
            if (exitCode !== 0)
                return;

            const codecs = [];
            let inside = false;

            for (const raw of info.text.split("\n")) {
                const line = raw.trim();
                if (line === "")
                    continue;

                // A section header ends the one before it, which is the whole
                // of the format: entries are bare lines and belong to whatever
                // section was last announced. Matched on the header rather than
                // counted by position, so a future gsr adding a section in
                // front of this one changes nothing here.
                if (line.startsWith("section=")) {
                    inside = line === "section=video_codecs";
                    continue;
                }

                if (!inside)
                    continue;

                // Other sections put a `|` between a value and its label --
                // "DP-3|2560x1440" -- and this one does not, so a line with one
                // in it is a format that has moved and is left out rather than
                // stored as a codec name gsr would reject.
                if (line.includes("|"))
                    continue;

                codecs.push(line);
            }

            root.parsed = codecs;
        }
    }

    // A word about the ones that need one, for the row under the name. Only the
    // families that carry a real caveat: the plain codecs need no caption and a
    // list where every line has one is a list nobody reads.
    function caution(codec: string): string {
        if (codec.includes("vulkan"))
            return "Experimental in gpu-screen-recorder, and it depends on the "
                + "GPU driver. It exists because Vulkan encoding avoids the "
                + "NVIDIA \"cuda p2 state\" downclock that nvenc suffers on "
                + "older drivers.";

        if (codec.includes("hdr"))
            return "HDR is not available on X11 or through the portal, and a "
                + "clip in it looks wrong anywhere that cannot read it.";

        if (codec.includes("10bit"))
            return "10-bit reduces banding, and not every player handles it.";

        if (codec === "h264_software")
            return "Encoded on the CPU. It is the fallback for a card with no "
                + "encoder, not a choice worth making on one that has one.";

        return "";
    }
}
