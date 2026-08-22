// The island: the centre of the bar, showing the one thing that matters now.
//
// See modules/island/IslandState.qml for the priority ladder. This file
// applies it (`mode` below) and draws the three sizes:
//
//   COLLAPSED  a capsule with one reading. The resting size.
//   EXPANDED   on hover, and only when there is something to expand INTO --
//              media gains its transport controls. Falls back on its own when
//              the pointer leaves.
//   OPEN       on click: the dashboard, hanging off the bar.
//
// THE ANIMATION IS THE FEATURE. What sells this as one object changing shape,
// rather than as widgets being swapped, is that the capsule's WIDTH animates
// while its contents cross-fade inside. Both parts are required: animate the
// width without fading and the old text jumps out, fade without animating the
// width and the bar snaps. Everything else here is in service of that.
//
// All four contents are instantiated at once and hidden by opacity rather than
// loaded on demand. That is deliberate: `targetWidth` has to be able to ask an
// inactive content how wide it WOULD be, so the capsule can start growing on
// the same frame the mode changes instead of a frame later.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"
import "root:/modules/notifications"
import "root:/modules/recorder"

Item {
    id: root

    // The bar's shared popout, handed down by Bar.qml. The dashboard is shown
    // in it rather than in a window of the island's own: it already knows how
    // to weld itself to the bar, close on an outside click, and swap content.
    required property var popout

    // Horizontal breathing room inside the capsule.
    readonly property int pad: 14

    // ---------------- The ladder ----------------
    readonly property string mode: {
        // OUR OWN recording is a rung, above media: it was started from the
        // dashboard, it has to be stoppable, and the stop button needs
        // somewhere to live.
        //
        // Capture the shell did not start -- a Discord share, a call, OBS --
        // is NOT a rung and stays as the badge beside the island. The
        // difference is not pedantry: a share must be continuously visible
        // whatever else happens, which a one-slot ladder cannot promise, while
        // a recording you started yourself is something you are looking for.
        // See CaptureIndicator.qml for the longer argument.
        //
        // A machine in trouble -- too hot, or out of memory -- is the ONE
        // thing above the acknowledgement. Everything else on
        // this ladder is something you did or something you chose; this is the
        // machine telling you it is in trouble, and it holds the island for as
        // long as that is true. A volume nudge losing its two seconds of
        // readout while the CPU is at 92 C is the right trade -- the reverse
        // is not. Thresholds and their derivation are in SystemStats.qml.
        if (SystemStats.alert)
            return "alert";
        if (IslandState.ack !== "")
            return "ack";
        if (RecorderState.recording)
            return "recording";
        if (root.hasPlayer)
            return "media";
        return "idle";
    }

    // WHICH ACKNOWLEDGEMENTS ARE A READOUT. Volume and brightness share one
    // row -- a glyph, a bar and a percentage -- because they are the same
    // event with a different glyph; the replay and the mute each say a
    // sentence instead. Asked positively and in one place, because it is read
    // by both the width and the row's opacity and the alternative was a chain
    // of negations that grew a term every time a sentence was added.
    readonly property bool valueAck: IslandState.ack === "volume" || IslandState.ack === "brightness"

    // Expansion only means something when the mode has more to give. Hovering
    // the idle capsule should not make it breathe.
    readonly property bool expanded: hover.hovered && root.mode === "media"

    // ---------------- Media ----------------
    // Prefer whatever is actually playing; fall back to the first player that
    // exists, so a paused track still holds the island. The rule itself lives
    // in Track.qml, because this file and Dashboard.qml each had a copy of it
    // and neither knew about the mirror playerctld puts on the bus.
    readonly property var player: Track.active

    readonly property bool hasPlayer: root.player !== null

    // Per-player glyph, the same table Media.qml carried. Matched against the
    // D-Bus identity, lowercased.
    readonly property var playerIcons: ({
        brave: Icons.chromium,
        chromium: Icons.chromium,
        chrome: Icons.chromium,
        firefox: Icons.firefox,
        spotify: Icons.spotify,
        vlc: Icons.vlc
    })

    readonly property string mediaGlyph: {
        if (!root.hasPlayer)
            return Icons.music;
        if (!root.player.isPlaying)
            return Icons.pause;
        const identity = (root.player.identity ?? "").toLowerCase();
        for (const key in root.playerIcons) {
            if (identity.includes(key))
                return root.playerIcons[key];
        }
        return Icons.music;
    }

    // ---------------- Volume, as an acknowledgement ----------------
    readonly property var sink: Pipewire.defaultAudioSink

    // Not optional. PipeWire objects are bound lazily: without something
    // declaring interest in the node its `audio` data is never populated and
    // volume reads 0 forever.
    PwObjectTracker {
        objects: [root.sink]
    }

    // The shell starting up is not the user changing the volume. Without this
    // the island flashes a volume readout every time the config reloads,
    // because binding to the sink counts as the first change.
    property bool volumeSettled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: root.volumeSettled = true
    }

    Connections {
        target: root.sink?.audio ?? null
        enabled: root.volumeSettled

        function onVolumeChanged(): void {
            IslandState.flashVolume(Math.round((root.sink?.audio?.volume ?? 0) * 100), root.sink?.audio?.muted ?? false);
        }

        function onMutedChanged(): void {
            IslandState.flashVolume(Math.round((root.sink?.audio?.volume ?? 0) * 100), root.sink?.audio?.muted ?? false);
        }
    }

    // ---------------- Brightness, as an acknowledgement ----------------
    //
    // THE THIRD TIME THIS SHAPE IS USED AND THE SECOND THAT IS A VALUE
    // CHANGING UNDERNEATH US, and it is deliberately the same shape as the
    // volume immediately above rather than anything new: watch the thing
    // itself, and flash when it moves. What differs is only where the push
    // comes from -- PipeWire has a signal, a backlight has a file -- and
    // Brightness.qml is where that difference is absorbed, so by the time it
    // reaches this file the two are the same kind of event.
    //
    // WHY WATCHING BEATS BEING TOLD, in one line: the media keys are bound
    // straight to `brightnessctl` in both compositors and neither knows this
    // shell exists. Following the value covers them, and covers a laptop's
    // firmware Fn keys, which nothing could tell us about. The long version
    // is in Brightness.qml.
    //
    // THE FLASH LIVES HERE AND NOT IN THAT SINGLETON, which is not where it
    // would first go. Nothing at the root of this config imports
    // `root:/modules` -- the dependency runs modules-to-root and never back --
    // so a singleton beside Config and Theme cannot reach into the island's
    // arbiter without turning that around. It also keeps the split clean:
    // Brightness owns what the backlight IS, and this file owns what the bar
    // does about it. The same reason the volume's flash is here and not in
    // PipeWire's node.
    //
    // ON A DESKTOP NOTHING BELOW EVER RUNS. `Brightness.present` is false with
    // no backlight or with the laptop module switched off, so the handler
    // returns before it can raise anything.

    // The shell starting up is not the user changing the brightness. Exactly
    // the argument `volumeSettled` makes above, and needed twice over here:
    // the FileView delivers its first value once the device has been asked
    // for, so a fresh shell would otherwise flash the current brightness at
    // whoever just logged in.
    property bool brightnessSettled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: root.brightnessSettled = true
    }

    Connections {
        target: Brightness
        enabled: root.brightnessSettled

        function onPercentChanged(): void {
            if (!Brightness.present)
                return;
            IslandState.flashBrightness(Brightness.percent);
        }
    }

    // ---------------- The mute, as an acknowledgement ----------------
    //
    // THE FOURTH TIME THIS SHAPE IS USED, and deliberately the same one as the
    // volume and the brightness above: watch the thing itself, and flash when
    // it moves. Watching beats being told for the same reason it does there --
    // the mute has four doors (the bell's right click, the switch in the
    // notification panel, SUPER + N, and `qs ipc call dnd`) and this covers
    // all four without any of them knowing the island exists.
    //
    // THE FLASH LIVES HERE AND NOT IN NotificationState, which is the same
    // split the paragraph above the brightness watcher argues: that singleton
    // owns what the mute IS, and this file owns what the bar does about it.
    //
    // WHY THE MUTE NEEDS ANNOUNCING when the bell already draws it: on a right
    // click the pointer is on the bell, hover has already turned its glyph
    // accent, and so the only thing that changes there is bell to bellOff --
    // a thin diagonal on a small glyph. The full argument is in the header of
    // modules/bar/NotificationButton.qml.
    //
    // IT FIRES FROM EVERY DOOR, the panel's own switch included, and that is
    // the trade taken rather than an oversight. The dashboard's volume slider
    // raises the volume acknowledgement in exactly the same way; a flash that
    // appeared for some ways of changing a value and not others would be a
    // confirmation you could not learn to trust. The panel hangs off the right
    // end of the bar and the island is in the middle of it, so nothing is
    // covered either way.

    // The shell starting up is not the user muting anything. The same argument
    // `volumeSettled` makes, and needed here for a sharper reason: the mute is
    // PERSISTED, so on a reload with it on the JsonAdapter delivers false and
    // then true a moment later -- without this guard every restart would flash
    // "Do not disturb on" at whoever had just logged in.
    property bool dndSettled: false

    Timer {
        interval: 1000
        running: true
        onTriggered: root.dndSettled = true
    }

    Connections {
        target: NotificationState
        enabled: root.dndSettled

        function onDndChanged(): void {
            IslandState.flashDnd();
        }
    }

    // ---------------- Size ----------------
    // What the capsule is aiming at. The Behavior on `capsule.width` is what
    // turns a change here into the morph.
    readonly property int targetWidth: {
        switch (root.mode) {
        case "alert":
            return alertContent.implicitWidth + root.pad * 2;
        case "ack":
            if (root.valueAck)
                return ackContent.implicitWidth + root.pad * 2;
            return (IslandState.ack === "dnd" ? dndAck.implicitWidth : replayAck.implicitWidth) + root.pad * 2;
        case "recording":
            return recordingContent.implicitWidth + root.pad * 2;
        case "media":
            return (root.expanded ? mediaExpanded.implicitWidth : mediaCollapsed.implicitWidth) + root.pad * 2;
        default:
            return idleContent.implicitWidth + root.pad * 2;
        }
    }

    implicitWidth: capsule.width
    implicitHeight: Theme.groupHeight

    // FIRST, and that is load-bearing. A later sibling is painted on top and
    // is offered input first, so this catch-all has to come BEFORE the capsule
    // or it swallows every click meant for the transport glyphs inside it.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // Right click is play/pause while media is showing. It is the one
        // action worth reaching without aiming: the transport buttons only
        // exist once the island is expanded and the pointer is already on top
        // of it, so the whole capsule doubles as the play button.
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                // Only in media mode, and only if the player allows it. Right
                // clicking the idle capsule or a volume acknowledgement does
                // nothing rather than something surprising.
                if (root.mode === "media" && root.player?.canTogglePlaying)
                    root.player.togglePlaying();
                return;
            }

            // mapToItem(null, ...) gives coordinates in the bar's window, and
            // the bar starts at x = 0 of the screen, so this is already a
            // screen x.
            root.popout.toggleAt(root.mapToItem(null, root.width / 2, 0).x, dashboardComponent);
        }
    }

    // SUPER + D, through IslandState's IpcHandler. Deliberately the SAME call
    // the click makes, so the keybind and the pointer cannot drift apart: one
    // of them opening what the other closes is the kind of bug that only
    // shows up months later.
    Connections {
        target: IslandState

        function onDashboardCloseRequested(): void {
            root.popout.close();
        }

        function onDashboardRequested(): void {
            root.popout.toggleAt(root.mapToItem(null, root.width / 2, 0).x, dashboardComponent);
        }

        // An onDashboardOpenRequested was here, opening rather than toggling
        // for the one caller that sent you to a named tab. That caller was the
        // do-not-disturb badge and the tab was Notifications, which is now a
        // widget of its own at the right end of the bar. There are no tabs at
        // all now -- the dashboard is one view -- so there is nothing left to
        // be sent to. See the header of modules/island/Dashboard.qml.
    }

    Rectangle {
        id: capsule

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.targetWidth
        height: Theme.groupHeight
        radius: Theme.groupRadius

        // Idle is quieter than the groups around it: at rest the island should
        // read as part of the bar's surface, not as another pill sitting on
        // it. Anything else and it earns the group's own background.
        color: root.mode === "idle" && !hover.hovered
            ? Qt.alpha(Theme.surfaceContainerHigh, 0.35)
            : Theme.glass(Theme.surfaceContainerHigh)

        Behavior on width {
            NumberAnimation {
                duration: Theme.animDuration
                // Out-back overshoots a few pixels and settles. It is the
                // difference between a box resizing and something with weight
                // arriving.
                easing.type: Easing.OutBack
                easing.overshoot: 0.7
            }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // ---------------- Machine in trouble ----------------
        // Critical throughout, and it pulses. The other states are read when
        // the eye happens to pass over the centre of the bar; this one has to
        // catch someone whose attention is somewhere else entirely.
        Row {
            id: alertContent

            anchors.centerIn: parent
            spacing: 9
            opacity: root.mode === "alert" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStats.alertKind === "thermal" ? Icons.thermometerAlert : Icons.ram
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.critical

                SequentialAnimation on opacity {
                    running: root.mode === "alert"
                    loops: Animation.Infinite

                    NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Names the part and gives the number, because "something is
                // wrong" is not actionable and "the GPU is at 86" is.
                text: SystemStats.alertKind === "thermal"
                    ? `${SystemStats.thermalSource} ${Math.round(SystemStats.thermalTemp)} °C`
                    : `RAM ${Math.round(SystemStats.ramPercent)}%  ·  ${SystemStats.ramUsed.toFixed(1)} / ${SystemStats.ramTotal.toFixed(1)} GiB`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.critical
            }
        }

        // ---------------- Idle ----------------
        // Three dots. Not a clock and not a status: the resting state has to
        // be something the eye skips, so that anything appearing here is
        // read as new.
        Row {
            id: idleContent

            anchors.centerIn: parent
            spacing: 5
            opacity: root.mode === "idle" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Repeater {
                model: 3

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.textOnSurfaceVariant
                }
            }
        }

        // ---------------- Acknowledgement: a value that just moved ----------
        //
        // SERVES VOLUME AND BRIGHTNESS FROM ONE ROW, because they ask the same
        // question and want the same answer: a glyph saying which value, a bar
        // saying where it sits, and a number confirming it. A second Row for
        // brightness would have been a copy of this one with one line changed,
        // and two copies drift -- the fixed width below that stops the capsule
        // twitching between 9% and 10% would have been fixed in one of them.
        Row {
            id: ackContent

            anchors.centerIn: parent
            spacing: 9
            opacity: root.mode === "ack" && root.valueAck ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // THE ONLY THING THAT VARIES BY KIND. The bar and the number
                // below are the same question in both cases -- how much of it
                // is there -- so they are drawn once rather than copied per
                // acknowledgement, and the glyph is what says which value is
                // being talked about. Adding mic mute here is one more branch.
                text: {
                    if (IslandState.ack === "brightness")
                        return Icons.brightness;
                    if (IslandState.ackMuted)
                        return Icons.volumeMuted;
                    if (IslandState.ackValue === 0)
                        return Icons.volumeLow;
                    if (IslandState.ackValue < 50)
                        return Icons.volumeMedium;
                    return Icons.volumeHigh;
                }
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: IslandState.ackMuted ? Theme.outline : Theme.primary
            }

            // The bar is the reading; the number is the confirmation. A
            // percentage alone makes you do the arithmetic of where it sits.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                height: 4
                radius: 2
                color: Qt.alpha(Theme.textOnSurfaceVariant, 0.3)

                Rectangle {
                    width: parent.width * Math.min(1, IslandState.ackValue / 100)
                    height: parent.height
                    radius: parent.radius
                    color: IslandState.ackMuted ? Theme.outline : Theme.primary

                    Behavior on width {
                        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // Fixed width so the capsule does not twitch between 9% and
                // 10% while the wheel is being turned.
                width: 38
                horizontalAlignment: Text.AlignRight
                text: IslandState.ackMuted ? "off" : `${IslandState.ackValue}%`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: IslandState.ackMuted ? Theme.outline : Theme.textOnSurface
            }
        }

        // ---------------- Replay saved ----------------
        // The clip is on disk before this appears, so it says so and goes. It
        // is not a rung with a button on it like the recording above, because
        // there is nothing left to decide once the file exists.
        Row {
            id: replayAck

            anchors.centerIn: parent
            spacing: 9
            opacity: root.mode === "ack" && IslandState.ack === "replay" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.replay
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `Last ${ReplayState.seconds}s saved`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }
        }

        // ---------------- Do not disturb ----------------
        // The mute was switched, from wherever. It is an ACKNOWLEDGEMENT and
        // not a rung of its own for the same reason the replay above is one:
        // the state is already carried permanently by the bell at the right of
        // the bar (and by the badge on a bar with no bell), so there is nothing
        // here left to watch -- only the fact that the thing you just did took
        // effect, which is exactly what this rung is for.
        //
        // IT SAYS THE STATE AND NOT THE ACTION. "Do not disturb" alone would
        // be the same string in both directions and would read as a label on a
        // mode that had just been turned OFF; naming the state outright is the
        // one wording that cannot be got backwards. It reads NotificationState
        // directly rather than a payload on IslandState -- see flashDnd there.
        Row {
            id: dndAck

            anchors.centerIn: parent
            spacing: 9
            opacity: root.mode === "ack" && IslandState.ack === "dnd" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: NotificationState.dnd ? Icons.bellOff : Icons.bell
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                // Accent for on, quiet for off -- the same pair the bell uses,
                // and the same reasoning: a mode you asked for is a state and
                // not a fault, so it never reaches for critical.
                color: NotificationState.dnd ? Theme.primary : Theme.textOnSurfaceVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: NotificationState.dnd ? "Do not disturb on" : "Do not disturb off"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }
        }

        // ---------------- Recording ----------------
        // Only for a recording THIS shell started. Something else capturing
        // the screen is the badge beside the island, not this.
        Row {
            id: recordingContent

            anchors.centerIn: parent
            spacing: 12
            opacity: root.mode === "recording" ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            // Breathing, not blinking: a hard on/off reads as a fault light,
            // this reads as something running. Same treatment the capture
            // badge uses, so the two say "live" the same way.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter

                width: 8
                height: 8
                radius: 4
                color: Theme.critical

                SequentialAnimation on opacity {
                    running: root.mode === "recording"
                    loops: Animation.Infinite

                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Recording"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }

            // The stop button, and the reason this is a rung at all: a
            // recording you started has to be stoppable from where you can see
            // it is running.
            //
            // 24 and not 26: the capsule is 36 tall, so a 26 button left five
            // pixels of air above and below and read as stuffed into a hole
            // slightly too small for it, while the leading dot is eight pixels
            // in the middle of nothing. Same size as the media transport
            // buttons, which is what the rest of the island uses for a round
            // button on a capsule.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter

                width: 24
                height: 24
                radius: height / 2
                color: stopMouse.containsMouse ? Theme.critical : Qt.alpha(Theme.critical, 0.18)

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.stop
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: stopMouse.containsMouse ? Theme.textOnCritical : Theme.critical
                }

                MouseArea {
                    id: stopMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: RecorderState.stop()
                }
            }
        }

        // ---------------- Media, collapsed ----------------
        Row {
            id: mediaCollapsed

            anchors.centerIn: parent
            spacing: 8
            opacity: root.mode === "media" && !root.expanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mediaGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: root.player?.isPlaying ? Theme.tertiary : Theme.outline
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.player?.trackTitle ?? ""
                elide: Text.ElideRight
                // Capped, or a track with a long title drags the island across
                // half the bar and the centre stops being the centre. Tighter
                // than it was before the waveform arrived: the two of them
                // share the capsule now.
                width: Math.min(implicitWidth, 200)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: root.player?.isPlaying ? Theme.textOnSurface : Theme.textOnSurfaceVariant
            }

            // The waveform sits AFTER the title, not behind it and not
            // instead of it.
            //
            // Behind was tried and dropped: faint enough not to fight the
            // words it was barely visible, and strong enough to see it made
            // the text hard to read.
            //
            // Order matters here too. The title is what you read and the
            // waveform is what you glance at, so the text keeps the reading
            // position next to the glyph and the bars trail off to the right.
            // Put first, the moving thing pulls the eye before the words every
            // time.
            Waveform {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ---------------- Media, expanded ----------------
        Row {
            id: mediaExpanded

            anchors.centerIn: parent
            // Wider than the collapsed row's spacing: the text block and the
            // transport are two different things to look at, and the gap is
            // what says so without drawing a separator for it.
            spacing: 18
            opacity: root.mode === "media" && root.expanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            // The same source glyph the collapsed state shows. Expanding is
            // supposed to ADD to what was there, not swap it for something
            // else: dropping the one icon that says WHERE the audio comes from
            // made the two states read as different widgets rather than as one
            // widget with more of itself showing.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mediaGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: root.player?.isPlaying ? Theme.tertiary : Theme.outline

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: root.player?.trackTitle ?? ""
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 240)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Font.Bold
                    color: Theme.textOnSurface
                }

                Text {
                    text: Track.artist(root.player?.trackArtist ?? "")
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 240)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    font.weight: Theme.fontWeight
                    color: Theme.textOnSurfaceVariant
                }
            }

            // Transport.
            //
            // Each control is a fixed-size Item with the glyph centred in it,
            // NOT a bare Text with a MouseArea stretched over it. That was the
            // bug: the glyphs were the plain Unicode media symbols, which the
            // font does not have, so the Text measured almost nothing, the
            // click area measured almost nothing with it, and every press went
            // through to the capsule underneath and opened the dashboard. A
            // declared size means the target is the same whatever the glyph
            // turns out to be.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        {
                            action: "previous"
                        },
                        {
                            action: "toggle"
                        },
                        {
                            action: "next"
                        }
                    ]

                    Item {
                        id: control

                        required property var modelData

                        // The middle one is the primary action, so it gets the
                        // bigger target and the accent when idle. The other
                        // two are corrections.
                        readonly property bool primary: control.modelData.action === "toggle"

                        readonly property string glyph: {
                            switch (control.modelData.action) {
                            case "previous":
                                return Icons.skipPrevious;
                            case "next":
                                return Icons.skipNext;
                            default:
                                // The button says what pressing it DOES, so it
                                // shows the opposite of the current state.
                                return root.player?.isPlaying ? Icons.pause : Icons.play;
                            }
                        }

                        readonly property bool available: {
                            if (!root.player)
                                return false;
                            switch (control.modelData.action) {
                            case "previous":
                                return root.player.canGoPrevious;
                            case "next":
                                return root.player.canGoNext;
                            default:
                                return root.player.canTogglePlaying;
                            }
                        }

                        implicitWidth: control.primary ? 28 : 24
                        implicitHeight: 24
                        anchors.verticalCenter: parent.verticalCenter

                        opacity: control.available ? 1 : 0.35

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: height / 2
                            color: controlMouse.containsMouse && control.available
                                ? Qt.alpha(Theme.primary, 0.18)
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: control.glyph
                            font.family: Theme.fontFamily
                            font.pointSize: control.primary ? Theme.iconSize + 1 : Theme.iconSize
                            color: {
                                if (controlMouse.containsMouse && control.available)
                                    return Theme.primary;
                                return control.primary ? Theme.textOnSurface : Theme.textOnSurfaceVariant;
                            }

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        MouseArea {
                            id: controlMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: control.available
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                switch (control.modelData.action) {
                                case "previous":
                                    root.player.previous();
                                    break;
                                case "next":
                                    root.player.next();
                                    break;
                                default:
                                    root.player.togglePlaying();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    Component {
        id: dashboardComponent

        Dashboard {}
    }
}
