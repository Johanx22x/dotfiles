// Sound: where it comes out, where it goes in, and what every running
// application is doing with it.
//
// EVERYTHING HERE COMES OFF QUICKSHELL'S PIPEWIRE BINDING. No wpctl is
// spawned, no pactl, nothing is polled: the lists move on PipeWire's own
// signals. `wpctl status` was used to check what this machine actually has --
// four sinks, four sources, a headset, a USB microphone and two capture cards
// -- and a throwaway QML probe was used to read every node the way this file
// reads them, which is where the filters below come from rather than from a
// guess about what the flags mean.
//
// WHAT THE FLAGS ARE, MEASURED. PwNodeType is a bit set: Audio=1, Video=2,
// Stream=4, Source=8, Sink=16, and the combinations this page cares about are
// AudioSink=17, AudioSource=9, AudioOutStream=21 and AudioInStream=13. The
// trap is `isSink`, which is TRUE for an application that is PLAYING sound --
// audio flows into that node -- so filtering devices on it alone puts Discord
// in the list of speakers. The type is compared whole here for that reason.
//
// WHAT THIS PAGE WILL NOT DO, and none of it is an oversight:
//
//   - Card profiles and ports. Switching a headset between its high-quality
//     stereo profile and the one with the microphone, or choosing which
//     socket on the back of the machine is live, belongs to WirePlumber and
//     is not in the binding at all. There is no honest way to draw it here.
//   - Moving a running application to another device. The route is shown on
//     every row below, because it is worth knowing; changing it means writing
//     PipeWire metadata, which the binding does not expose.
//   - Balance. This one was built, measured and then removed, and the
//     measurement is the reason: `audio.volume` reads back as the AVERAGE of
//     the channels, so panning left drags the volume percentage down with it
//     and the two controls end up fighting over one number. Setting `volume`
//     already preserves the ratio between channels -- measured: [0.8, 0.4]
//     then volume=0.5 gives [0.667, 0.333] -- so a balance set anywhere else
//     survives everything this page does. Please do not re-add it without
//     re-reading that.
//
// The last section hands all three to pavucontrol, which is in this repo's
// package list, and says which of them it is for. Same answer the network
// page gives enterprise Wi-Fi, and for the same reason: a settings window
// that pretends to a capability it does not have is worse than one that
// names the tool that has it.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Sound"
    glyph: Icons.volumeHigh
    // "mic" and "mute" appear nowhere on the page as a label; they are the
    // words someone types when they want this page.
    keywords: ["sound", "audio", "volume", "output", "input", "microphone",
        "mic", "speaker", "speakers", "headphones", "headset", "mute",
        "device", "pipewire", "level"]

    // ---------------- What is on the machine ----------------
    //
    // Read once here so every binding below shares one answer, and referenced
    // through `nodeCount` so that all of them re-evaluate when a device is
    // plugged in or an application starts playing. Reading the length is the
    // only way to depend on the model itself rather than on one node in it.
    readonly property int nodeCount: Pipewire.nodes.values.length

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ALPHABETICAL, AND THE DEFAULT IS NOT PULLED TO THE TOP -- which is
    // where this deliberately parts company with the network page. There the
    // connected network sits first because connecting takes seconds and the
    // list has settled again by the time anything moves. Here the switch is
    // instant, so a list that re-sorted would slide a different device under
    // a pointer that has not moved yet, and the second click of a double
    // click would land on it. The default is marked, not moved.
    readonly property var sinks: {
        root.nodeCount;
        return Pipewire.nodes.values
            .filter(n => n.type === PwNodeType.AudioSink)
            .sort((a, b) => (a.description ?? "").localeCompare(b.description ?? ""));
    }

    readonly property var sources: {
        root.nodeCount;
        return Pipewire.nodes.values
            .filter(n => n.type === PwNodeType.AudioSource)
            .sort((a, b) => (a.description ?? "").localeCompare(b.description ?? ""));
    }

    // BY ID, WHICH IS CREATION ORDER. Anything else -- by name, by volume --
    // would reshuffle the list while a slider in it is being dragged, and the
    // delegate under the pointer would become a different application's.
    readonly property var playing: {
        root.nodeCount;
        return Pipewire.nodes.values
            .filter(n => n.type === PwNodeType.AudioOutStream)
            .sort((a, b) => a.id - b.id);
    }

    // MINUS THIS PAGE'S OWN METERS, which is not tidying up -- it is the
    // difference between reporting the machine and reporting the act of
    // looking at it. A PwNodePeakMonitor opens a real capture stream, so the
    // two below appear in this very list the moment the page is shown: two
    // rows saying "Quickshell Peak Detect · from NZXT USB MIC", every time,
    // caused by nothing but the page being open. They tell the reader
    // precisely nothing about their own system and they make the one question
    // this list exists to answer -- what is listening to me -- harder to read.
    //
    // Matched on the name Quickshell gives the stream, because those nodes
    // carry no process id and no binary at all (measured; every other stream
    // here has both). If a future version renames it the rows come back,
    // which is a visible failure rather than a silent one.
    //
    // Scoped to capture streams on purpose. If this shell ever PLAYS a sound
    // of its own, that belongs in the list above like anything else.
    readonly property var recording: {
        root.nodeCount;
        return Pipewire.nodes.values
            .filter(n => n.type === PwNodeType.AudioInStream
                && n.properties?.["application.name"] !== "Quickshell Peak Detect")
            .sort((a, b) => a.id - b.id);
    }

    // NOT OPTIONAL, and not gated on the page being visible either. PipeWire
    // binds objects lazily: without something declaring an interest, a node's
    // `audio` data is never populated and every volume on this page reads
    // zero. Tracking is passive -- it subscribes, it does not open a stream
    // -- which is why it can be left on while the peak monitors below cannot.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // ---------------- The meters ----------------
    //
    // THESE ARE GATED, and it is the one thing on this page that has to be.
    // A peak monitor opens a real capture stream on the node: on the input
    // that means this shell is recording from the microphone, which would
    // show up as such to anything watching and would keep the device busy
    // forever. `root.visible` is the page's own on-screen flag -- see the
    // note in SettingsPage.qml about why every page is built and only one is
    // shown -- so the microphone is only listened to while somebody is
    // looking at the page that displays it.
    PwNodePeakMonitor {
        id: outputPeak

        node: root.sink
        enabled: root.visible
    }

    PwNodePeakMonitor {
        id: inputPeak

        node: root.source
        enabled: root.visible
    }

    // ---------------- Naming an application ----------------
    //
    // NO SINGLE PROPERTY IS RIGHT, which the probe made obvious: Discord's
    // playback node calls itself "WEBRTC VoiceEngine" and the recorder's
    // calls itself "gsr-default_output", while `application.process.binary`
    // holds "Discord" and "gpu-screen-recorder" for the same two. Zen is the
    // other way round -- binary "zen-bin", application.name "Zen" -- but the
    // binary still wins after the suffix comes off.
    //
    // So: the binary, minus a "-bin" that is an implementation detail of how
    // the program was packaged, and the node's own name for the ones that
    // have no binary at all (cava).
    function streamName(node: var): string {
        const props = node?.properties ?? ({});
        const binary = (props["application.process.binary"] ?? "").replace(/-bin$/, "");
        const name = binary || props["application.name"] || node?.name || "";

        // ONE LOWERCASE WORD GETS A CAPITAL AND NOTHING ELSE DOES. "cava"
        // becomes "Cava" and "zen" becomes "Zen", which is what those
        // programs call themselves; "gpu-screen-recorder" is left alone,
        // because every way of title-casing it makes it harder to recognise
        // rather than easier. A command name is not a proper noun and only
        // looks like one when it is a single word.
        return /^[a-z0-9]+$/.test(name)
            ? name.charAt(0).toUpperCase() + name.slice(1)
            : name;
    }

    // The device -- or the other application -- at the far end of a stream.
    //
    // OFF THE GLOBAL LINK MODEL AND NOT off a PwNodeLinkTracker per row,
    // which was the first attempt and reported nothing at all: measured, a
    // tracker bound to each stream returned zero link groups while
    // Pipewire.linkGroups held all eight of them. Reading `.values` inside
    // the binding is what makes this re-evaluate when a stream is rerouted.
    //
    // A DEVICE IS PREFERRED OVER ANOTHER STREAM, because a node can be at the
    // end of several links at once: Zen is linked both to the headset and to
    // Discord's game capture, and "to G435 Wireless Gaming Headset" is the
    // answer to where the sound is going. When there is no device on the
    // other side -- Discord capturing Zen -- naming the other application is
    // still the truth and still worth saying.
    function peerOf(node: var): var {
        if (!node)
            return null;

        let fallback = null;

        for (const group of Pipewire.linkGroups.values) {
            const other = group.source === node ? group.target
                : group.target === node ? group.source
                : null;

            if (!other)
                continue;
            if (!other.isStream)
                return other;
            if (!fallback)
                fallback = other;
        }

        return fallback;
    }

    function peerLabel(node: var): string {
        const peer = root.peerOf(node);
        if (!peer)
            return "";

        return peer.isStream ? root.streamName(peer)
            : (peer.description || peer.name || "");
    }

    // ---------------- A volume, and the button that silences it ----------------
    //
    // AN INLINE COMPONENT AND NOT A FILE IN components/, which is a departure
    // worth naming. Everything in that directory is deliberately ignorant of
    // where its values come from -- ToggleRow takes a bool, StepperRow takes
    // a number -- and these three know what a PipeWire node is. Putting them
    // there would be the first component in that directory that cannot be
    // used by a page that has nothing to do with sound. They are used two and
    // three times each, all of them on this page, so they live on it.
    component VolumeLine: Item {
        id: line

        property var node: null
        // Only for the search index, which duck-types on `label` -- see the
        // header of SettingsSearch.qml. Nothing draws it: the glyph and the
        // section heading already say which volume this is, and a word in
        // front of the slider would push it into half the width.
        property string label: ""

        property string glyph: ""
        property real peak: 0
        property bool showMeter: false

        // PAST 100% ON PURPOSE, and this is where this page and the island
        // part company. The island clamps a mouse drag at 1.0 on the argument
        // that software gain should not be reached by accident, and that is
        // right for a control that hangs off the bar under a moving pointer.
        // It leaves nowhere to SEE the state, though: the keyboard keys go to
        // 150% (see hyprland.lua), and this machine's headset was sitting at
        // 125% while the island drew a full bar and said 100%. A settings
        // page is where a value gets told the truth about itself, so the
        // range is the real one and the mark at 1.0 says where the hardware
        // stops and the arithmetic starts.
        readonly property real maximum: 1.5

        readonly property var audio: line.node?.audio ?? null
        readonly property bool muted: line.audio?.muted ?? false
        readonly property real volume: line.audio?.volume ?? 0
        readonly property bool loud: line.volume > 1.001

        readonly property color accent: line.muted ? Theme.outline
            : line.loud ? Theme.warning : Theme.primary

        width: parent ? parent.width : 320
        implicitHeight: 46

        // No device at all -- every output unplugged, or PipeWire still
        // coming up. Dimmed and inert rather than hidden: a section that
        // loses its first row looks broken, and one that greys out looks like
        // what it is.
        enabled: line.node !== null
        opacity: line.node ? 1 : 0.4

        Rectangle {
            id: muteButton

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding - 6
            anchors.top: parent.top
            anchors.topMargin: 6

            width: 32
            height: 32
            radius: height / 2
            color: muteMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.centerIn: parent
                text: line.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: line.muted ? Theme.outline : Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                id: muteMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (line.audio)
                        line.audio.muted = !line.audio.muted;
                }
            }
        }

        Text {
            id: percent

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: muteButton.verticalCenter

            // Wide enough for the longest thing it ever says, so the slider
            // beside it keeps one length instead of breathing in and out as
            // the number crosses 100 or the row is muted.
            width: Math.max(mutedMetrics.width, loudMetrics.width)
            horizontalAlignment: Text.AlignRight

            text: line.muted ? mutedMetrics.text : `${Math.round(line.volume * 100)}%`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: line.muted ? Theme.outline
                : line.loud ? Theme.warning : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            TextMetrics {
                id: mutedMetrics

                font: percent.font
                text: "muted"
            }

            TextMetrics {
                id: loudMetrics

                font: percent.font
                text: "150%"
            }
        }

        VolumeSlider {
            id: slider

            // The page scrolls and this does not. See the note on the property
            // itself: the pointer crosses these on the way down the page far
            // more often than it stops on one.
            wheelEnabled: false

            anchors.left: muteButton.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: percent.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: muteButton.verticalCenter

            value: line.volume
            maximum: line.maximum
            notch: 1
            accent: line.accent

            onMoved: value => {
                if (!line.audio)
                    return;
                line.audio.volume = value;
                // Moving the slider is a request to hear something, so it
                // takes the mute off rather than moving a value that changes
                // nothing. Only on the way up: dragging a muted row to zero
                // and having it unmute itself would be worse.
                if (line.muted && value > 0)
                    line.audio.muted = false;
            }
        }

        LevelMeter {
            anchors.left: slider.left
            anchors.right: slider.right
            anchors.top: slider.bottom
            anchors.topMargin: 3

            visible: line.showMeter
            peak: line.peak
            active: line.showMeter && !line.muted
            accent: line.accent
        }
    }

    // ---------------- One device in a list of them ----------------
    component DeviceRow: Rectangle {
        id: device

        property var node: null
        property bool isDefault: false
        property string glyph: ""

        signal chosen

        readonly property bool muted: device.node?.audio?.muted ?? false

        width: parent ? parent.width : 320
        implicitHeight: 32
        radius: Theme.groupRadius
        color: deviceMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            id: deviceGlyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            text: device.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // The accent marks the one in use and nothing else, exactly as
            // the network list marks the connected network.
            color: device.isDefault ? Theme.primary : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.left: deviceGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: state.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            // `description` and not `nickname`, because it is the string
            // wpctl and pavucontrol both print -- a settings window that
            // renames the devices disagrees with every other tool on the
            // machine the moment something goes wrong.
            text: device.node?.description ?? ""
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: device.isDefault ? Font.Bold : Theme.fontWeight
            color: device.isDefault ? Theme.primary : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Row {
            id: state

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // WORTH ITS OWN MARK, and this machine is the argument: two of
            // its four outputs sit at zero and muted. Switching to one of
            // them and hearing nothing is a minute of thinking the change
            // failed, and the row knew all along.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: device.muted

                text: Icons.volumeMuted
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.outline

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // Says what this row IS, or what a click would do to it. The same
            // shape the network list uses, and the same reason: repeating
            // what the row already shows teaches nobody anything.
            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: device.isDefault ? "default" : deviceMouse.containsMouse ? "use" : ""
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.outline

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        MouseArea {
            id: deviceMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: device.chosen()
        }
    }

    // ---------------- One application making noise ----------------
    component StreamRow: Item {
        id: stream

        property var node: null
        property string label: ""
        property string route: ""
        // The preposition differs and the row would read as nonsense with the
        // wrong one: sound goes TO a pair of headphones and comes FROM a
        // microphone.
        property string routePrefix: ""
        property string glyph: ""
        property string mutedGlyph: ""

        readonly property var audio: stream.node?.audio ?? null
        readonly property bool muted: stream.audio?.muted ?? false
        readonly property real volume: stream.audio?.volume ?? 0

        // NO HOVER FILL ON THE ROW ITSELF, unlike the device rows above. The
        // row is not a target -- there is nowhere for a click on it to go,
        // since this page cannot reroute a stream -- and InfoRow's rule
        // applies: the cheapest way to tell a control from a reading is that
        // a control lights up. The two things here that DO respond, the glyph
        // and the slider, light up on their own.
        width: parent ? parent.width : 320
        implicitHeight: 52

        Rectangle {
            id: streamMute

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding - 6
            anchors.top: parent.top
            anchors.topMargin: 3

            width: 30
            height: 30
            radius: height / 2
            color: streamMuteMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.centerIn: parent
                text: stream.muted ? stream.mutedGlyph : stream.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 1
                color: stream.muted ? Theme.outline : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                id: streamMuteMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (stream.audio)
                        stream.audio.muted = !stream.audio.muted;
                }
            }
        }

        Text {
            id: streamPercent

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: streamMute.verticalCenter

            width: streamMutedMetrics.width
            horizontalAlignment: Text.AlignRight

            text: stream.muted ? streamMutedMetrics.text : `${Math.round(stream.volume * 100)}%`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: stream.muted ? Theme.outline : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            TextMetrics {
                id: streamMutedMetrics

                font: streamPercent.font
                text: "muted"
            }
        }

        // The name and where the sound is going, on ONE line. They were two
        // for a version, with the route underneath, and it made every
        // application three rows tall for a fact that fits in the gap at the
        // end of the first one.
        Row {
            anchors.left: streamMute.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: streamPercent.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: streamMute.verticalCenter
            spacing: 6

            Text {
                id: streamLabel

                anchors.verticalCenter: parent.verticalCenter

                // Bounded rather than left to elide against the Row, which
                // hands every child the width it asks for -- an application
                // with a long name would push the route off the end instead
                // of giving way to it.
                width: Math.min(implicitWidth, parent.width * 0.5)
                elide: Text.ElideRight

                text: stream.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: stream.muted ? Theme.outline : Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: stream.route !== ""

                width: Math.min(implicitWidth, parent.width - streamLabel.width - parent.spacing)
                elide: Text.ElideRight

                text: `· ${stream.routePrefix} ${stream.route}`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        VolumeSlider {
            wheelEnabled: false

            anchors.left: streamMute.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: streamPercent.right
            anchors.top: streamMute.bottom
            anchors.topMargin: -2

            value: stream.volume
            maximum: 1.5
            notch: 1
            accent: stream.muted ? Theme.outline : Theme.primary

            onMoved: value => {
                if (!stream.audio)
                    return;
                stream.audio.volume = value;
                if (stream.muted && value > 0)
                    stream.audio.muted = false;
            }
        }
    }

    // A row whose value is a KEY, chosen by pressing it.
    //
    // WHY IT LIVES HERE AND NOT IN components/. Everything in components/ is
    // ignorant of where its value comes from; this one knows what an xkb
    // keysym is called and which keys a compositor bind can be written on,
    // which is knowledge about the thing being configured rather than about
    // settings rows. Same argument as VolumeLine above.
    //
    // PRESSING THE KEY, not choosing it from a list. The list would be a
    // thousand keysyms long, and the question "which key do I want to hold" is
    // one the fingers answer faster than the eyes.
    component KeyPickerRow: Rectangle {
        id: picker

        property string glyph: ""
        property string label: ""
        property string keyName: ""

        // True while the next key press is the answer rather than a keystroke.
        property bool capturing: false
        // Set when a key was pressed that cannot be written into a bind, and
        // cleared a moment later. It replaces the value in the chip, so the
        // refusal appears where the answer would have.
        property bool refused: false

        signal picked(string keysym)

        width: parent ? parent.width : implicitWidth
        implicitWidth: 320
        implicitHeight: Theme.groupHeight

        radius: Theme.groupRadius
        color: pickerMouse.containsMouse || picker.capturing ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // The keys that cannot be the answer, and the reason is the same for
        // both halves: the bind is written with ignore_mods, which means the
        // modifiers are not looked at when it is matched. A bind ON a modifier
        // would be asking the compositor to match the thing it was told to
        // ignore.
        readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt,
            Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R,
            Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock, Qt.Key_NumLock,
            Qt.Key_ScrollLock, Qt.Key_Mode_switch]

        // Qt's key code to the name xkb -- and therefore the bind -- uses.
        //
        // RETURNS EMPTY FOR ANYTHING IT DOES NOT KNOW, and the row refuses
        // rather than falling back to `code:NN`. The keycode is the tempting
        // fallback because it always exists, but Qt's nativeScanCode and
        // Hyprland's `code:` do not provably agree about the offset between
        // evdev numbering and X11 numbering, and a bind on the wrong key is
        // worse than a bind that was never written -- it would open the
        // microphone on a key nobody is watching. `desktop-tweak` still
        // accepts code:NN by hand for whoever wants to check it.
        function keysymFor(key: int): string {
            if (key >= Qt.Key_A && key <= Qt.Key_Z)
                return String.fromCharCode(97 + (key - Qt.Key_A));
            if (key >= Qt.Key_0 && key <= Qt.Key_9)
                return String.fromCharCode(48 + (key - Qt.Key_0));
            // Contiguous in Qt, and F13 upwards is the interesting half here:
            // a keyboard that can send one has a key nothing else wants.
            if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
                return `F${key - Qt.Key_F1 + 1}`;

            switch (key) {
            case Qt.Key_Space:        return "space";
            case Qt.Key_Backslash:    return "backslash";
            case Qt.Key_Bar:          return "bar";
            case Qt.Key_Slash:        return "slash";
            case Qt.Key_Question:     return "question";
            case Qt.Key_Semicolon:    return "semicolon";
            case Qt.Key_Colon:        return "colon";
            case Qt.Key_Apostrophe:   return "apostrophe";
            case Qt.Key_QuoteDbl:     return "quotedbl";
            case Qt.Key_BracketLeft:  return "bracketleft";
            case Qt.Key_BracketRight: return "bracketright";
            case Qt.Key_BraceLeft:    return "braceleft";
            case Qt.Key_BraceRight:   return "braceright";
            case Qt.Key_Comma:        return "comma";
            case Qt.Key_Period:       return "period";
            case Qt.Key_Minus:        return "minus";
            case Qt.Key_Underscore:   return "underscore";
            case Qt.Key_Equal:        return "equal";
            case Qt.Key_Plus:         return "plus";
            case Qt.Key_QuoteLeft:    return "grave";
            case Qt.Key_AsciiTilde:   return "asciitilde";
            case Qt.Key_Less:         return "less";
            case Qt.Key_Greater:      return "greater";
            case Qt.Key_Exclam:       return "exclam";
            case Qt.Key_At:           return "at";
            case Qt.Key_NumberSign:   return "numbersign";
            case Qt.Key_Dollar:       return "dollar";
            case Qt.Key_Percent:      return "percent";
            case Qt.Key_AsciiCircum:  return "asciicircum";
            case Qt.Key_Ampersand:    return "ampersand";
            case Qt.Key_Asterisk:     return "asterisk";
            case Qt.Key_ParenLeft:    return "parenleft";
            case Qt.Key_ParenRight:   return "parenright";
            case Qt.Key_Tab:          return "Tab";
            case Qt.Key_Return:       return "Return";
            case Qt.Key_Enter:        return "Return";
            case Qt.Key_Backspace:    return "BackSpace";
            case Qt.Key_Insert:       return "Insert";
            case Qt.Key_Delete:       return "Delete";
            case Qt.Key_Home:         return "Home";
            case Qt.Key_End:          return "End";
            case Qt.Key_PageUp:       return "Page_Up";
            case Qt.Key_PageDown:     return "Page_Down";
            case Qt.Key_Up:           return "Up";
            case Qt.Key_Down:         return "Down";
            case Qt.Key_Left:         return "Left";
            case Qt.Key_Right:        return "Right";
            case Qt.Key_Menu:         return "Menu";
            case Qt.Key_Print:        return "Print";
            case Qt.Key_Pause:        return "Pause";
            default:                  return "";
            }
        }

        function startCapture(): void {
            picker.refused = false;
            picker.capturing = true;
            picker.forceActiveFocus();
        }

        function cancelCapture(): void {
            picker.capturing = false;
            picker.refused = false;
            // THE FOCUS HAS TO GO BACK TOO, not just the flag. Leaving it here
            // is what made the row keep the window's keyboard after it had
            // stopped listening.
            picker.focus = false;
        }

        // Focus leaving is a cancel. Clicking anywhere else in the window while
        // waiting for a key has to mean "never mind" -- the alternative is a
        // row that is still listening after the user has moved on, and the
        // next thing they type lands in it.
        onActiveFocusChanged: {
            if (!picker.activeFocus)
                picker.cancelCapture();
        }

        // AND LEAVING THE PAGE IS A CANCEL AS WELL, which is not the same
        // event. SettingsPage hides a page it is not showing rather than
        // destroying it, and an item that is hidden KEEPS its active focus --
        // measured. Without this, clicking away from Sound mid-capture left
        // the row listening from a page nobody could see: every key in the
        // window was swallowed, and the first one it recognised silently
        // became the new push-to-talk key.
        onVisibleChanged: {
            if (!picker.visible)
                picker.cancelCapture();
        }

        Keys.onPressed: event => {
            if (!picker.capturing)
                return;

            // Swallowed whichever branch is taken below, including the
            // refusals: while this row is listening, the keyboard is its own.
            event.accepted = true;

            if (event.isAutoRepeat)
                return;

            if (event.key === Qt.Key_Escape) {
                picker.cancelCapture();
                return;
            }

            if (picker.modifierKeys.indexOf(event.key) >= 0) {
                picker.refused = true;
                refusalTimer.restart();
                return;
            }

            const keysym = picker.keysymFor(event.key);
            if (keysym === "") {
                picker.refused = true;
                refusalTimer.restart();
                return;
            }

            picker.capturing = false;
            picker.refused = false;
            picker.focus = false;
            picker.picked(keysym);
        }

        // Long enough to be read, short enough that the row is listening again
        // before the finger has decided what to try instead.
        Timer {
            id: refusalTimer

            interval: 1400
            onTriggered: picker.refused = false
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: picker.glyph !== ""
                text: picker.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: picker.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // The chip carries the value, the invitation and the refusal in turn,
        // rather than a chip plus a button plus a line of helper text: all
        // three are answers to "what key", so they belong in the same place.
        Rectangle {
            id: chip

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: chipText.implicitWidth + Theme.groupPadding * 2
            implicitHeight: Theme.groupHeight - 8
            radius: height / 2

            color: picker.capturing ? Theme.primaryContainer : "transparent"
            border.width: picker.capturing ? 0 : 1
            border.color: Theme.outlineVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Text {
                id: chipText

                anchors.centerIn: parent

                text: picker.refused ? "Not that key"
                    : picker.capturing ? "Press a key"
                    : picker.keyName

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Theme.fontWeight
                color: picker.capturing ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        MouseArea {
            id: pickerMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.capturing ? picker.cancelCapture() : picker.startCapture()
        }
    }

    // ---------------- Output ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.volumeHigh
        title: "Output"

        VolumeLine {
            label: "Output volume"
            node: root.sink
            glyph: Icons.outputGlyph(`${root.sink?.name ?? ""} ${root.sink?.description ?? ""}`,
                root.sink?.audio?.muted ?? false, root.sink?.audio?.volume ?? 0)
            peak: outputPeak.peak
            showMeter: true
        }

        // The floor under the control, so the list below reads as a different
        // kind of thing inside the same card rather than as more rows of it.
        // Same argument the wallpaper page's footer rule makes.
        Item {
            width: parent.width
            implicitHeight: 9

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.groupPadding * 2
                height: 1
                color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Text {
            visible: root.sinks.length === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "No output devices."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // NO CEILING AND NO INNER SCROLL, which is a departure from the
        // network list this was copied from -- and the reason is that the two
        // lists are bounded by different things. The air can carry twenty
        // access points; a machine has the sound cards that are plugged into
        // it, which here is four outputs and four inputs and would be eight
        // on a bad day. A cap that never bites is a cap that only costs
        // something, and what it cost was real: a wheel turned over the list
        // moved the list and the page at once, so a device four rows down
        // walked out from under the pointer aimed at it.
        //
        // The page still scrolls, so nothing is unreachable. One scroll
        // surface, no fight. Where a list genuinely can be long -- Wi-Fi,
        // Bluetooth discovery, the keybind table -- the cap stays and
        // components/ScrollList.qml settles the same fight properly.
        Column {
            id: sinkList

            width: parent.width
            spacing: 2

            Repeater {
                model: root.sinks

                delegate: DeviceRow {
                    required property var modelData

                    node: modelData
                    isDefault: modelData === root.sink
                    glyph: Icons.outputGlyph(`${modelData?.name ?? ""} ${modelData?.description ?? ""}`,
                        false, 1)

                    // Verified against a live machine rather than assumed:
                    // writing this property moved the default off the
                    // headset and onto HDMI, and putting the old node back
                    // moved it home again.
                    onChosen: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }
    }

    // ---------------- Input ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.microphone
        title: "Input"

        VolumeLine {
            label: "Input volume"
            node: root.source
            glyph: (root.source?.audio?.muted ?? false) ? Icons.microphoneOff : Icons.microphone
            peak: inputPeak.peak
            showMeter: true
        }

        // The one line that explains the bar above rather than describing a
        // setting. It is here and not on the output, where a moving meter
        // needs no caption -- music is playing and there it is. An input
        // meter is read the other way round: you make a noise on purpose to
        // find out whether the machine can hear it, and the instruction is
        // the whole point of the control.
        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 4

            text: "Say something — the bar moves if the microphone is hearing it."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Item {
            width: parent.width
            implicitHeight: 9

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.groupPadding * 2
                height: 1
                color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Text {
            visible: root.sources.length === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "No input devices."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // Uncapped, like the outputs above and for the same reason.
        Column {
            id: sourceList

            width: parent.width
            spacing: 2

            Repeater {
                model: root.sources

                delegate: DeviceRow {
                    required property var modelData

                    node: modelData
                    isDefault: modelData === root.source
                    glyph: Icons.microphone

                    onChosen: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }

    // ---------------- Push to talk ----------------
    //
    // A LOADER AND NOT `visible: Compositor.can(...)`, and the difference is
    // the search field. SettingsSearch walks the page's object tree looking
    // for anything with a label, and it does not test visibility -- it cannot,
    // because every page that is not the current one is already invisible and
    // testing would find nothing at all. So a hidden section is still a found
    // section, and on niri typing "push to talk" would offer a row that is not
    // on the page. A Loader that is not active has no children to walk.
    Loader {
        width: parent.width
        active: Compositor.can("pushToTalk")
        // Or the Column counts it as a row and leaves the section's spacing
        // behind on a compositor that never draws the section.
        visible: active

        sourceComponent: SettingsSection {
            width: parent.width
            glyph: Icons.microphone
            title: "Push to talk"

            ToggleRow {
                glyph: Config.pushToTalk ? Icons.microphoneOff : Icons.microphone
                label: "Hold a key to talk"
                checked: Config.pushToTalk
                // Through the tweak store, which writes the compositor binds
                // and reloads them. The switch does not touch the microphone
                // itself -- Microphone.qml watches this value and closes it.
                onToggled: value => Config.setTweak("ptt", value ? "1" : "0")
            }

            KeyPickerRow {
                glyph: Icons.keyboard
                label: "Push-to-talk key"
                keyName: Config.pushToTalkKey
                onPicked: keysym => Config.setTweak("ptt-key", keysym)
            }
        }
    }

    // ---------------- Playing ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.music
        title: "Playing"

        Text {
            visible: root.playing.length === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Nothing is playing."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.playing

                delegate: StreamRow {
                    required property var modelData

                    node: modelData
                    label: root.streamName(modelData)
                    route: root.peerLabel(modelData)
                    routePrefix: "to"
                    glyph: Icons.volumeHigh
                    mutedGlyph: Icons.volumeMuted
                }
            }
        }
    }

    // ---------------- Recording ----------------
    //
    // THE ONE SECTION HERE THAT IS NOT ABOUT VOLUME. Muting an application's
    // capture without muting the microphone itself is a real thing to want,
    // and it is the smaller half of why this list exists -- the other half is
    // that "what is listening to me right now, and to what" is a question a
    // desktop should be able to answer in one place. Every row names the
    // device it is capturing from, so a stream reading the speakers is
    // visibly not a stream reading the microphone.
    SettingsSection {
        width: parent.width
        glyph: Icons.record
        title: "Recording"

        Text {
            visible: root.recording.length === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Nothing is recording."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.recording

                delegate: StreamRow {
                    required property var modelData

                    node: modelData
                    label: root.streamName(modelData)
                    route: root.peerLabel(modelData)
                    routePrefix: "from"
                    glyph: Icons.microphone
                    mutedGlyph: Icons.microphoneOff
                }
            }
        }
    }

    // ---------------- What lives elsewhere ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.tune
        title: "Beyond this page"

        ActionRow {
            glyph: Icons.tune
            label: "Profiles, ports and per-application routing"
            description: "Switching a headset between stereo and its "
                + "microphone profile, choosing which socket is live, and "
                + "moving a running application to another device. None of "
                + "the three is in the shell's reach — see the note at the "
                + "top of this page — and all three are in pavucontrol."
            actionText: "Open"

            onTriggered: Quickshell.execDetached(["pavucontrol"])
        }
    }
}
