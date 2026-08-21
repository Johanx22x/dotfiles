// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// VOLUME - the output, for whoever is not holding a pointer
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// THE COUNTERPART TO Microphone.qml, WHICH OWNS THE OTHER END. That file owns
// the default SOURCE and the reason it exists is push-to-talk; this one owns
// the default SINK and the reason it exists is that the shell had no way to
// say anything about the volume except by drawing a slider. Every other thing
// this shell can do has a name you can call from a terminal or bind a key to
// -- ten targets before this one -- and the most-pressed keys on the machine
// had none.
//
// WHAT THIS IS NOT. It is not a replacement for the volume keys, which stay
// bound to `wpctl` in both compositors, and it is not the source of truth for
// the sliders. VolumeControl.qml and AudioPage.qml keep reading the sink
// directly; consolidating those is a real change and a separate one, and
// doing it here would have meant touching four files to add an IPC target.
// A fourth PwObjectTracker on the same node is not a new cost -- three
// already exist, and the tracker is a refcount on a binding rather than a
// second connection.
//
// NO SPAWN ON THE PRESS PATH, which is the one thing this does better than
// the keybind it mirrors. Microphone.qml makes the argument in full: this
// process is already holding the node, so setting a value on it costs nothing
// and there is no `wpctl` to fork.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQml

Singleton {
    id: root

    // Read by shell.qml to bring this singleton into existence at startup.
    // An IpcHandler only answers once the thing holding it exists, and a
    // target nobody has instantiated is a target that reports "no such
    // handler" until something unrelated happens to touch this file.
    readonly property bool armed: true

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink?.audio ?? null

    // THE NODE'S OWN `ready`, AND NOT JUST `audio !== null`, for the reason
    // Microphone.qml measured and wrote down: `audio` becomes non-null as
    // soon as the node object exists, which is BEFORE PipeWire has bound it,
    // and a value written in that window is dropped with a log line and no
    // retry. That window is session startup.
    readonly property bool ready: (root.sink?.ready ?? false) && root.audio !== null

    readonly property bool muted: root.ready && root.audio.muted
    readonly property real volume: root.ready ? root.audio.volume : 0

    // One press, and the same 5% the media keys move so that a key and a call
    // step by the same amount.
    readonly property real step: 0.05

    // 150%, MATCHING THE KEYS AND NOT THE SLIDER, and the two disagree on
    // purpose. Above 1.0 PipeWire applies the gain in software and the sound
    // distorts, so a slider dragged with a pointer stops at 1.0 -- see
    // VolumeControl.setVolume, where the note says a mouse should not reach
    // it by accident. A key press is not an accident: `wpctl set-volume -l
    // 1.5` is what both compositors bind XF86AudioRaiseVolume to, and this is
    // that key's equivalent, so it gets that key's ceiling.
    readonly property real maximum: 1.5

    function setVolume(value: real): void {
        if (!root.ready)
            return;
        root.audio.volume = Math.max(0, Math.min(root.maximum, value));
    }

    function up(): void {
        root.setVolume(root.volume + root.step);
    }

    // Down is bounded at zero rather than at the ceiling, so a volume that was
    // boosted walks back down through 100% instead of snapping to it.
    function down(): void {
        root.setVolume(root.volume - root.step);
    }

    function mute(): void {
        if (root.ready)
            root.audio.muted = true;
    }

    function unmute(): void {
        if (root.ready)
            root.audio.muted = false;
    }

    function toggleMuted(): void {
        if (root.ready)
            root.audio.muted = !root.audio.muted;
    }

    IpcHandler {
        target: "volume"

        function up(): void {
            root.up();
        }

        function down(): void {
            root.down();
        }

        // `toggle` on this target is the MUTE, because the mute is the only
        // thing about a volume that has two states to swap between. It is
        // what XF86AudioMute does, and this is the name that key would reach
        // for.
        function toggle(): void {
            root.toggleMuted();
        }

        function mute(): void {
            root.mute();
        }

        function unmute(): void {
            root.unmute();
        }

        function status(): string {
            if (!root.ready)
                return "no output";
            return `${Math.round(root.volume * 100)}%${root.muted ? ", muted" : ""}`;
        }
    }

    // Without this PipeWire never binds the node and `audio` stays unpopulated,
    // so every call above would quietly do nothing and the volume would read 0
    // forever. See the same tracker in Island.qml and VolumeControl.qml -- the
    // binding is lazy, and asking for a property is not what triggers it.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
