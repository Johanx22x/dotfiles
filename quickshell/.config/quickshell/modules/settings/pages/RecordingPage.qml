// Screen recording and the instant replay buffer: what gets captured, how, and
// where it lands.
//
// WHY THIS PAGE EXISTS. Every value on it was a literal in modules/recorder
// until it did. The buffer kept 30 seconds of the shell's screen at 60 fps,
// h264 in mp4 at 40 Mbit/s CBR, aac audio, in RAM, with ONE PARTICULAR NZXT USB
// microphone named in full -- on a machine with six inputs, and on anybody
// else's machine a name that resolves to nothing at all. None of that was
// wrong. All of it was unreachable: trying 120 seconds meant editing a file in
// a git repository and reloading the shell, which is not a setting, it is a
// patch.
//
// TWO PROGRAMS, AND THE PAGE SAYS WHICH IS WHICH. gpu-screen-recorder keeps the
// replay buffer and obeys everything here; wf-recorder makes the manual
// recordings and can honestly be given two of these values -- the container and
// whether the desktop's sound is in it. The rest are gsr's alone, for reasons
// written beside the controls rather than left for somebody to discover from a
// file. A page that implied otherwise would be worse than one that is shorter.
//
// THE CODEC LIST IS NOT A LITERAL, and this is the one control here that could
// not be. gsr is a hardware recorder: a codec this card has no encoder for is
// not a slower recording, it is a buffer that refuses to arm, three times, and
// then gives up. So the list comes from `gpu-screen-recorder --info`, which
// reports what THIS machine can do -- fifteen entries on this desktop, and very
// few indeed on the RX 6400 in the note in ReplayState. See RecorderCodecs.
//
// EVERY CHANGE HERE COSTS THE SECONDS THE BUFFER WAS HOLDING. gsr takes all of
// it on the command line, so the recorder has to come back for any of it to
// take effect -- see ReplayState.reapply(). That is said once, on the page, at
// the top of the section it is true of, rather than on every row.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"
import "root:/modules/recorder"

SettingsPage {
    id: root

    title: "Recording"
    glyph: Icons.record
    // "shadowplay" and "clip" appear nowhere on the page and are what somebody
    // arrives looking for; the rest are the words on the controls.
    keywords: ["record", "recording", "replay", "instant replay", "shadowplay",
        "clip", "buffer", "capture", "screen", "video", "codec", "h264",
        "hevc", "av1", "bitrate", "framerate", "fps", "mp4", "mkv",
        "container", "microphone", "mic", "audio", "gpu-screen-recorder",
        "wf-recorder", "obs"]

    // ---------------- What the machine can do ----------------
    //
    // ASKED WHEN SOMEBODY LOOKS, and not before. `gpu-screen-recorder --info`
    // takes about half a second and opens the GPU to enumerate; every page in
    // this window is built at startup and kept alive, so a probe in
    // Component.onCompleted would be that half second at every login of a
    // machine where this page is never opened. `onScreen` is the same gate the
    // sound page's meters use, and for the same reason. refresh() is
    // idempotent, so being looked at twice costs nothing.
    onOnScreenChanged: {
        if (root.onScreen)
            RecorderCodecs.refresh();
    }

    // ---------------- The microphones ----------------
    //
    // Read once here so every binding below shares one answer, and referenced
    // through `nodeCount` so all of them re-evaluate when a device is plugged
    // in or taken away. Reading the length is the only way to depend on the
    // model itself rather than on one node in it. The filter and the sort are
    // the sound page's, for the reasons its header gives -- the type is
    // compared whole because `isSink` is true for an application that is
    // PLAYING, and the order is alphabetical rather than default-first so the
    // list does not reshuffle under a pointer.
    readonly property int nodeCount: Pipewire.nodes.values.length

    readonly property var sources: {
        root.nodeCount;
        return Pipewire.nodes.values
            .filter(n => n.type === PwNodeType.AudioSource)
            .sort((a, b) => (a.description ?? "").localeCompare(b.description ?? ""));
    }

    // NOT OPTIONAL AND NOT GATED. PipeWire binds objects lazily: without
    // something declaring an interest, a node's data is never populated and
    // every device below has an empty description. Tracking is passive -- it
    // subscribes, it does not open a stream -- which is why it can be left on
    // while the sound page's peak meters cannot.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function screenLabel(screen: var): string {
        return `${screen.model || screen.name}${screen.model ? ` (${screen.name})` : ""}`;
    }

    // ---------------- Instant replay ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.replay
        title: "Instant replay"

        // THE SAME SWITCH AS THE DASHBOARD'S AND THE SAME KEY, not a copy of
        // the state: both write Config.replayEnabled and both read
        // ReplayState, which owns the recorder. A settings window with its own
        // idea of whether the buffer was armed would be a second answer to a
        // question that already has one.
        ToggleRow {
            glyph: Icons.replay
            label: "Keep the last seconds"
            checked: ReplayState.wanted
            onToggled: value => ReplayState.setEnabled(value)
        }

        // Four lengths and not a stepper: they are the four anybody picks, the
        // island offers exactly these, and the same list feeds both -- see
        // ReplayState.options. A free number here would also be a free memory
        // cost, and the reading under it is what makes the choice legible.
        ChoiceRow {
            glyph: Icons.clock
            label: "Buffer length"
            options: ReplayState.options.map(seconds => ({ label: `${seconds} s`, value: seconds }))
            value: ReplayState.seconds
            onChosen: value => ReplayState.setSeconds(value)

            hint: "Changing it restarts the recorder, so the seconds it is "
                + "holding right now are lost. Everything on this page works "
                + "that way: gpu-screen-recorder takes all of it on the "
                + "command line."
        }

        // WHAT IT COSTS, AND THE ARITHMETIC IS NOT THIS PAGE'S. A buffer is its
        // bitrate times its duration and nothing else, which is one calculation
        // -- ReplayState.cost -- shown here and on the island under the same
        // choice. Two copies of it would have drifted the day the bitrate
        // became a setting, which is this commit.
        InfoRow {
            glyph: Icons.ram
            label: ReplayState.inRam ? `About ${ReplayState.cost} of memory`
                : `About ${ReplayState.cost} on disk`
            description: ReplayState.sizeKnown
                ? "Constant bitrate, so the size does not depend on what is on "
                  + "screen. Measured on this machine at 30 s and 40 Mbit/s: "
                  + "about 590 MiB resident and a quarter of one core."
                : "In this bitrate mode the size follows what is on screen, so "
                  + "there is no number to promise. Constant bitrate is the one "
                  + "gpu-screen-recorder recommends for a replay buffer."
        }

        ChoiceRow {
            glyph: Icons.ram
            label: "Kept in"
            options: [{ label: "Memory", value: "ram" }, { label: "Disk", value: "disk" }]
            value: ReplayState.inRam ? "ram" : "disk"
            onChosen: value => Config.replayStorage = value

            hint: "Memory is what a replay buffer is for and what gsr does by "
                + "default. Its own man page says disk mode \"may reduce SSD "
                + "lifespan\", which is the trade: an SSD instead of the "
                + "reading above."
        }
    }

    // ---------------- Which screen ----------------
    //
    // HIDDEN ON A SINGLE-MONITOR MACHINE, the one place on this page where
    // hiding a control is right and the same judgement the bar page makes: a
    // choice between one thing is not a choice, and the answer would be the
    // same whatever was pressed.
    SettingsSection {
        width: parent.width
        visible: Screens.all.length > 1
        glyph: Icons.monitor
        title: "Screen the buffer keeps"

        // A LIST AND NOT SEGMENTS, unlike almost everything else here.
        // ChoiceRow's own note puts its ceiling at about four options at this
        // width, and a monitor is labelled with a model name rather than a
        // word -- so this is the shape the microphones and the codecs below
        // use, and all three read the same way.
        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: Screens.all

                PickRow {
                    required property var modelData

                    glyph: Icons.monitor
                    label: root.screenLabel(modelData)
                    // The connector, because that is what gsr is actually given
                    // as -w and what a log or a `ps` line would show. The key
                    // stored is the model and serial -- see Config.screenKey --
                    // and neither of those is what the recorder sees.
                    detail: modelData.name
                    picked: Config.replayMonitor === Config.screenKey(modelData)
                        || (Config.replayMonitor === "" && ReplayState.monitor === modelData.name)
                    onChosen: ReplayState.setMonitor(Config.screenKey(modelData))
                }
            }
        }

        // The chosen screen is not plugged in, so the buffer is on another one.
        // It is not silent and it is not a failure: the setting stays put, so
        // plugging the screen back in puts the buffer back on it. See
        // ReplayState.screen.
        Text {
            visible: ReplayState.monitorMissing

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: `The chosen screen is not connected, so the buffer is keeping `
                + `${ReplayState.monitor} instead. It moves back on its own when `
                + `the screen returns.`
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Audio ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.volumeHigh
        title: "Audio"

        ToggleRow {
            glyph: Icons.speaker
            label: "The computer's own sound"
            checked: Config.recordingDesktopAudio
            onToggled: value => Config.recordingDesktopAudio = value
        }

        ToggleRow {
            glyph: Config.recordingMicrophone ? Icons.microphone : Icons.microphoneOff
            label: "The microphone"
            checked: Config.recordingMicrophone
            onToggled: value => Config.recordingMicrophone = value
        }

        // ONE TRACK, NOT TWO, and it is worth saying because a file with two
        // audio tracks looks fine until it is sent somewhere: gsr is asked for
        // `default_output|device:NAME`, which is one merged track, because two
        // -a flags give two tracks and most players -- and everything you would
        // send a clip to -- play only the first.
        InfoRow {
            visible: Config.recordingDesktopAudio && Config.recordingMicrophone

            glyph: Icons.info
            label: "Both go into one track"
            description: "Two separate tracks would be the alternative, and "
                + "half the sound would go missing wherever only the first is "
                + "played."
        }

        // A manual recording cannot do this, and the row says so where the
        // switch above would otherwise imply it can. wf-recorder's --audio
        // takes ONE device.
        InfoRow {
            visible: Config.recordingMicrophone

            glyph: Icons.info
            label: "The microphone is the replay buffer's"
            description: "A manual recording is made by wf-recorder, whose "
                + "--audio takes one device; it gets the computer's sound if "
                + "the switch above is on, and nothing else."
        }
    }

    // ---------------- Which microphone ----------------
    SettingsSection {
        width: parent.width
        visible: Config.recordingMicrophone
        glyph: Icons.microphone
        title: "Microphone"

        Column {
            width: parent.width
            spacing: 2

            // SYSTEM DEFAULT IS AN ANSWER AND IT IS FIRST. Empty in the config
            // means gsr's own `default_input` -- follow whatever the system
            // currently calls the input -- which is a real choice and not a gap
            // to be filled in later. It is also the only entry here that cannot
            // stop existing.
            PickRow {
                glyph: Icons.microphone
                label: "System default"
                detail: "Follows whatever the machine is set to"
                picked: Config.recordingMicrophoneDevice === ""
                onChosen: Config.recordingMicrophoneDevice = ""
            }

            Repeater {
                model: root.sources

                PickRow {
                    required property var modelData

                    glyph: Icons.microphone
                    // `description` and not `nickname`, because it is the
                    // string wpctl and pavucontrol both print: a settings
                    // window that renames the devices disagrees with every
                    // other tool on the machine the moment something goes
                    // wrong.
                    label: modelData.description || modelData.name
                    detail: modelData.name
                    picked: Config.recordingMicrophoneDevice === modelData.name
                    onChosen: Config.recordingMicrophoneDevice = modelData.name
                }
            }
        }

        // THE CHOSEN DEVICE IS NOT HERE, and this is the row the whole picker
        // had to be designed around. A named device that is not present makes
        // gpu-screen-recorder REFUSE TO START AT ALL -- so the shell resolves
        // the name against the live node list and quietly sends the system
        // default instead, which keeps the buffer running and would otherwise
        // be completely invisible. This is where it stops being invisible.
        Text {
            visible: ReplayState.microphoneMissing

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "That microphone is not connected, so the system default is "
                + "being recorded instead. The choice stays put and takes "
                + "effect again when the device comes back."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // AAC AND NOT THE mp4 DEFAULT OF opus, and the reason has to live next
        // to the control or it will be undone by somebody reading a bitrate
        // comparison. These clips exist to be sent to people and cut in an
        // editor, and opus-in-mp4 is the combination some players and some
        // editors refuse.
        //
        // FLAC IS NOT OFFERED even though gsr's usage line lists it: its own
        // man page says "FLAC temporarily disabled" two lines further down. An
        // option that the recorder would reject is worse than no option.
        ChoiceRow {
            glyph: Icons.volumeHigh
            label: "Audio codec"
            options: [{ label: "AAC", value: "aac" }, { label: "Opus", value: "opus" }]
            value: Config.recordingAudioCodec
            onChosen: value => Config.recordingAudioCodec = value

            hint: "AAC because these clips get sent to people: opus inside an "
                + "mp4 is the combination some players and some editors refuse. "
                + "Opus is the better codec at the same bitrate."
        }
    }

    // ---------------- Video ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.gpu
        title: "Video"

        // THE CONTAINER IS A DECISION ON THIS MACHINE, not a detail, and it is
        // the one video setting a manual recording also obeys -- wf-recorder
        // names the file with -f and its muxer follows the extension.
        ChoiceRow {
            glyph: Icons.window
            label: "File format"
            options: [{ label: "MP4", value: "mp4" }, { label: "MKV", value: "mkv" }]
            value: Config.recordingContainer
            onChosen: value => Config.recordingContainer = value

            hint: "DaVinci Resolve on Linux refuses MKV outright, so anything "
                + "meant to be edited there has to be MP4. MKV survives the "
                + "recorder being killed, since it needs no header rewritten "
                + "at the end."
        }

        // From here down it is the replay buffer alone. Said once, here, rather
        // than on each of the four rows below it.
        InfoRow {
            glyph: Icons.info
            label: "The rest of this section is the replay buffer's"
            description: "A manual recording goes through wf-recorder, which "
                + "wants ffmpeg's codec names rather than these, and whose "
                + "framerate option forces constant frame rate -- a different "
                + "recording, not the same one at a chosen rate. Left alone it "
                + "follows the screen."
        }

        ChoiceRow {
            glyph: Icons.clock
            label: "Framerate"
            options: [{ label: "30", value: 30 }, { label: "60", value: 60 },
                { label: "120", value: 120 }, { label: "144", value: 144 }]
            value: Config.recordingFramerate
            onChosen: value => Config.recordingFramerate = value

            hint: "Above what the screen actually refreshes at, the extra "
                + "frames are duplicates. It is also the first knob to turn "
                + "down on a machine with no hardware encoder."
        }

        ChoiceRow {
            glyph: Icons.tune
            label: "Bitrate mode"
            options: [{ label: "Constant", value: "cbr" }, { label: "Variable", value: "vbr" },
                { label: "Quality", value: "qp" }]
            value: Config.recordingBitrateMode
            onChosen: value => Config.recordingBitrateMode = value

            hint: "Constant is what gpu-screen-recorder recommends for a replay "
                + "buffer, and it is what makes the memory cost above a number "
                + "rather than a guess."
        }

        // ONE FLAG, TWO SETTINGS, because -q is overloaded in gsr itself: a
        // number of kbit/s in constant bitrate, and one of four named presets
        // in the other two. Storing one value for both would mean sending a
        // preset name where a number belongs.
        StepperRow {
            visible: Config.recordingBitrateMode === "cbr"

            glyph: Icons.tune
            label: "Bitrate"
            // Stored in kbit/s because that is what gsr's -q takes; shown in
            // Mbit/s because that is how anybody talks about it.
            value: Math.round(Config.recordingBitrate / 1000)
            from: 5
            to: 200
            step: 5
            suffix: " Mbit/s"
            onMoved: value => Config.recordingBitrate = value * 1000

            hint: "40 is the default and is generous for 1440p. It is also "
                + "exactly what the buffer costs: the reading further up is "
                + "this number times the length."
        }

        ChoiceRow {
            visible: Config.recordingBitrateMode !== "cbr"

            glyph: Icons.tune
            label: "Quality"
            options: [{ label: "Medium", value: "medium" }, { label: "High", value: "high" },
                { label: "Very high", value: "very_high" }, { label: "Ultra", value: "ultra" }]
            value: Config.recordingQuality
            onChosen: value => Config.recordingQuality = value

            hint: "gpu-screen-recorder's own four presets. Very high is its "
                + "default."
        }
    }

    // ---------------- The codec ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.gpu
        title: "Video codec"

        Column {
            width: parent.width
            spacing: 2

            // AUTOMATIC IS FIRST AND IT IS THE DEFAULT, which is to say no -k
            // flag reaches the recorder at all. On a machine this page has
            // never been opened on, the codec is whatever gsr thinks is right
            // for the card it finds -- which is a better answer than anything
            // this shell could write down and keep true.
            PickRow {
                glyph: Icons.gpu
                label: "Automatic"
                detail: "Let gpu-screen-recorder choose (h264 today)"
                picked: Config.recordingCodec === ""
                onChosen: Config.recordingCodec = ""
            }

            Repeater {
                model: RecorderCodecs.videoCodecs

                PickRow {
                    required property string modelData

                    glyph: Icons.gpu
                    label: modelData
                    detail: RecorderCodecs.caution(modelData)
                    picked: Config.recordingCodec === modelData
                    onChosen: Config.recordingCodec = modelData
                }
            }
        }

        // The three states of the probe, in the order they happen. None of them
        // is a control, and none of them is silence: a list that is empty
        // because a command has not finished looks exactly like a list that is
        // empty because the command is not installed.
        Text {
            visible: RecorderCodecs.probing || RecorderCodecs.failed

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: RecorderCodecs.probing
                ? "Asking gpu-screen-recorder what this card can encode…"
                : "gpu-screen-recorder could not be asked what this card can "
                  + "encode, so only Automatic is offered. It is either not "
                  + "installed or it could not reach the GPU."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: RecorderCodecs.failed ? Theme.warning : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        InfoRow {
            visible: RecorderCodecs.videoCodecs.length > 0

            glyph: Icons.info
            label: "This list is what your card reports"
            description: "It comes from `gpu-screen-recorder --info`, not from "
                + "a list written into the shell. gsr encodes on the GPU, so a "
                + "codec that is not here is not a slower recording -- it is a "
                + "buffer that refuses to arm."
        }
    }

    // ---------------- Files ----------------
    //
    // NO GLYPH ON THIS HEADING, and it is the only section without one.
    // Icons.qml has nothing that means a folder, and its rule -- stated at
    // length, after two glyphs turned out to draw a cassette and a scooter --
    // is that a codepoint is written down only after being RENDERED and looked
    // at. Guessing one from a name to fill this in would break the rule the
    // rest of that file is built on.
    SettingsSection {
        width: parent.width
        title: "Where files go"

        PathRow {
            glyph: Icons.record
            label: "Recordings"
            fallback: `${Quickshell.env("HOME")}/Videos/recordings`
            stored: Config.recordingDirectory
            onCommitted: value => Config.recordingDirectory = value
        }

        PathRow {
            glyph: Icons.replay
            label: "Replay clips"
            fallback: `${Quickshell.env("HOME")}/Videos/Replays`
            stored: Config.replayDirectory
            onCommitted: value => Config.replayDirectory = value
        }

        InfoRow {
            glyph: Icons.info
            label: "The folder is created if it is missing"
            description: "Both recorders are started through a `mkdir -p`, so "
                + "naming somewhere that does not exist yet is not a way to "
                + "break recording."
        }
    }

    // ---------------- One row of a list of answers ----------------
    //
    // AN INLINE COMPONENT AND NOT A FILE IN components/, for the reason the
    // sound page gives for its own: this is used three times and all three are
    // on this page. It is very nearly that page's DeviceRow, and the difference
    // is exactly why it is not shared -- DeviceRow knows what a PipeWire node
    // is and this one knows nothing at all. A monitor, a microphone and a codec
    // are three unrelated kinds of thing offered in one shape.
    component PickRow: Rectangle {
        id: pick

        property string glyph: ""
        property string label: ""
        // A second line, muted, and empty is normal: the connector for a
        // screen, the node name for a microphone, a caution for a codec that
        // has one. A list where every row has one is a list nobody reads.
        property string detail: ""
        property bool picked: false

        signal chosen

        width: parent ? parent.width : 320
        // Grows for the second line rather than eliding it: an explanation cut
        // off at the width of a sidebar is one nobody finishes.
        implicitHeight: Math.max(32, column.implicitHeight + 12)

        radius: Theme.groupRadius
        color: pickMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            id: pickGlyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.top: column.top
            anchors.topMargin: 1

            text: pick.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // The accent marks the one in use and nothing else, exactly as the
            // sound page marks the default device and the network page marks
            // the connected network.
            color: pick.picked ? Theme.primary : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Column {
            id: column

            anchors.left: pickGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: mark.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: pick.label
                elide: Text.ElideRight

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: pick.picked ? Font.Bold : Theme.fontWeight
                color: pick.picked ? Theme.primary : Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                width: parent.width
                visible: pick.detail !== ""

                text: pick.detail
                wrapMode: Text.WordWrap

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // Says what this row IS, or what a click would do to it -- never both,
        // and never a repetition of what the row already shows. The same shape
        // the device and network lists use.
        Text {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            text: pick.picked ? "in use" : pickMouse.containsMouse ? "use" : ""
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        MouseArea {
            id: pickMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pick.chosen()
        }
    }

    // ---------------- A directory, typed ----------------
    //
    // A BARE TextInput IN A PILL, drawn by hand, which is what the network
    // page's password field is and for the same reason: nothing in this shell
    // imports QtQuick.Controls, and one widget that did would arrive with its
    // own palette and its own metrics.
    //
    // COMMITTED ON ENTER OR ON LEAVING THE FIELD, never per keystroke. Every
    // write here restarts the replay buffer, and a directory committed letter
    // by letter would be a recorder restarted once per character -- with the
    // first few going to /h, /ho, /hom.
    //
    // AN EMPTY FIELD IS AN ANSWER: it means the folder the recorder has always
    // written to, which is shown greyed in the field so the answer is visible
    // rather than absent.
    component PathRow: Item {
        id: path

        property string glyph: ""
        property string label: ""
        // What is stored, and what the empty string means.
        property string stored: ""
        property string fallback: ""

        signal committed(string value)

        // The text being edited. It follows `stored` until somebody types,
        // which breaks the binding -- so onStoredChanged puts it back, and a
        // restore-defaults elsewhere in the window is reflected here rather
        // than leaving a field showing a path nothing uses.
        property string draft: path.stored

        onStoredChanged: path.draft = path.stored

        // What is a legal answer. NOT A VALIDATOR SO MUCH AS A REFUSAL TO
        // GUESS: a relative path would be resolved against whatever directory
        // the shell happens to have been started in, which is a place nobody
        // chose and nobody can find afterwards.
        readonly property string resolved: {
            const text = path.draft.trim();
            if (text === "")
                return "";

            // `~` is expanded here because nothing else will: the recorders are
            // given this string as an argument, and an argument is not passed
            // through a shell.
            if (text.startsWith("~/"))
                return `${Quickshell.env("HOME")}/${text.slice(2)}`;

            return text;
        }

        readonly property bool valid: path.resolved === "" || path.resolved.startsWith("/")

        function commit(): void {
            if (!path.valid)
                return;

            if (path.resolved !== path.stored)
                path.committed(path.resolved);
        }

        width: parent ? parent.width : implicitWidth
        implicitWidth: 320
        // Taller than a plain row, because the field sits under the label
        // rather than beside it -- the same arrangement ChoiceRow uses for its
        // segments and for the same reason: squeezed into what is left after a
        // label, a path is unreadable.
        implicitHeight: Theme.groupHeight + 30

        Row {
            id: labelRow

            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: path.glyph !== ""
                text: path.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: path.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Rectangle {
            anchors.top: labelRow.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.groupPadding
            anchors.rightMargin: Theme.groupPadding

            height: 28
            radius: height / 2

            // Its own surface, a step up from the card behind it: a field that
            // is only outlined reads as a label with a box round it, and this
            // one has to look like somewhere to type.
            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: !path.valid ? Theme.critical
                : field.activeFocus ? Theme.primary : Theme.outlineVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.animDuration }
            }

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                text: path.draft
                onTextEdited: path.draft = text

                // A path is not a sentence: an autocapitalised first letter is
                // a directory that does not exist, found out about later.
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurface
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                selectByMouse: true

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                onAccepted: path.commit()

                // LEAVING THE FIELD COMMITS IT, because a settings window has
                // no Save button and nothing else on this page has one either.
                // Clicking away from a field that then discarded what was typed
                // would be the only control here that does nothing when used
                // normally.
                onActiveFocusChanged: {
                    if (!field.activeFocus)
                        path.commit();
                }

                // ESCAPE HAS TO BE SWALLOWED. The settings window's FocusScope
                // closes the whole window on Escape, so without accepting the
                // event, abandoning an edit would put the window away instead
                // of the edit.
                Keys.onEscapePressed: event => {
                    path.draft = path.stored;
                    event.accepted = true;
                }

                // TextInput has no placeholderText -- that belongs to
                // TextField, which is Controls. Drawn underneath instead, and
                // it is not decoration: an empty field here MEANS this path, so
                // showing it is the difference between a default and a blank.
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    visible: path.draft === ""
                    text: path.fallback
                    elide: Text.ElideMiddle
                    width: parent.width

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    color: Theme.outline

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding + 12

            visible: !path.valid
            text: "Needs to start with / or ~/"
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            color: Theme.critical

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
