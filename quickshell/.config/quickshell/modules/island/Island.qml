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
//
// WHILE MEDIA IS SHOWING, THIS IS end-4's MEDIA CARD AT BAR SIZE. Not a
// widget that quotes the panel -- the same construction, in a capsule 36
// pixels tall. The cover art is drawn behind the whole capsule, cropped and
// blurred, under a measured scrim; the spectrum runs across it as one
// continuous filled wave; and the title, the artist and the transport sit on
// top of that. Every colour comes from components/AdaptedMaterialScheme.qml,
// fed by a ColorQuantizer reading the same remembered cover the panel reads:
// the capsule takes colLayer0, the title colOnLayer0, the artist colSubtext,
// the wave colPrimary, and the play button is a filled disc that is a rounded
// square while it plays and a circle while it does not -- the panel's 44px
// button at 26.
//
// THE FIRST VERSION OF THIS CHANGED THE COLOURS AND NOT THE CONSTRUCTION,
// which was the wrong reading of the request: it recoloured a row of fourteen
// bars from the cover's palette and left them a row of fourteen bars. The
// bars are gone, and modules/island/Waveform.qml and cava.conf went with
// them -- there is one cava, one config and one feed for the whole shell now,
// because both consumers finally want the same shape. See Spectrum.qml for
// the band count and why eighty serves a 780px panel and a 250px capsule at
// once.
//
// WHAT IS DELIBERATELY NOT THE SAME, because "the same family" is not "the
// same thing" in a capsule 36 pixels tall:
//
//   the source glyph    the panel shows the cover sharp and small; this shows
//                       WHICH PLAYER the audio is coming from, and a 24px
//                       thumbnail of an album sleeve says nothing a 24px
//                       glyph does not say better. The glyph is also what
//                       makes the collapsed and expanded states read as one
//                       widget with more of itself showing
//   the ground's alpha  the panel's is opaque and this one is at the bar's
//                       own glass alpha, because a solid strip of photograph
//                       would be the only thing up there that is not
//                       see-through
//   no seek bar, no     there is no third line in a 36px capsule. The title
//   elapsed time        and the artist already fill it, and a control that
//                       needed a drag in the bar would be a control aimed at
//                       while the pointer is on its way somewhere else

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick.Effects
import QtQuick
import "root:/"
import "root:/components"
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

    // ---------------- The cover's palette ----------------
    //
    // THE SAME SOURCE THE DASHBOARD'S MEDIA USES, and that is the point of
    // this block. The panel the island opens into draws whatever is playing
    // in the ALBUM's colours -- the whole wall is the cover art -- and an
    // island that stayed in the wallpaper's palette would read as a different
    // widget belonging to a different thing.
    //
    // The cover comes through Track for the same reason the panel's does: the
    // player retracts mpris:artUrl two milliseconds after publishing it, so
    // trackArtUrl is empty most of the time a track is up. See Track.qml.
    readonly property string coverArt: Track.covers[root.player?.dbusName ?? ""] ?? ""

    ColorQuantizer {
        id: coverQuantizer

        // LOCAL FILES ONLY. Quickshell's src/core/colorquantizer.cpp loads
        // with `QImage(source.toLocalFile())` and has no network code, so a
        // remote cover -- the YouTube thumbnail fallback, or any player that
        // publishes an https url -- yields nothing and the island falls back
        // to the wallpaper's accent below. That is the same limit the
        // dashboard has and it is the same fallback.
        source: root.coverArt.startsWith("file:") ? root.coverArt : ""

        // One colour off a 1x1 rescale, which is why it costs nothing.
        depth: 0
        rescaleSize: 1
    }

    // Pulled 20% toward the shell's own primary container before use, which
    // is what stops a saturated cover from producing a bar that glows. Same
    // line the dashboard's card had; theirs too.
    readonly property color artDominantColor: {
        const quantized = coverQuantizer.colors.length > 0
            ? coverQuantizer.colors[0]
            : Theme.primary;
        return ColorUtils.mix(quantized, Theme.primaryContainer, 0.8);
    }

    property QtObject cover: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    // HOW DARK THE COVER HAS TO BE BEHIND THE TITLE, by the same rule the
    // dashboard uses -- see ColorUtils.scrimFor. The capsule is a strip of
    // somebody else's artwork with a track title on it, which is exactly the
    // problem that function exists for, and having the island answer it
    // differently from the panel is how two surfaces end up disagreeing about
    // whether a white sleeve is readable.
    readonly property real scrim: ColorUtils.scrimFor(coverQuantizer.colors)

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

    // A ClippingRectangle and not a Rectangle, because the cover art is drawn
    // to this capsule's own edges now. `clip: true` on a plain Item clips to
    // the BOUNDING BOX, so a blurred photograph would be painted straight over
    // the rounded ends and square them off -- the same trap the media card
    // fell into twice. This clips to the radius.
    ClippingRectangle {
        id: capsule

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.targetWidth
        height: Theme.groupHeight
        radius: Theme.groupRadius

        // Idle is quieter than the groups around it: at rest the island should
        // read as part of the bar's surface, not as another pill sitting on
        // it. Anything else and it earns the group's own background.
        //
        // AND WHILE MEDIA IS SHOWING IT IS THE ALBUM'S COLOUR. This is the
        // change that makes the island and the dashboard read as one thing
        // rather than as two widgets about the same track: the panel is the
        // cover art, so the capsule is the cover's surface role -- end-4's
        // colLayer0, the colour their media card paints itself. It also makes
        // every other cover-derived role below VALID, which they are not over
        // a surface in the wallpaper's palette: colOnLayer0 and colSubtext
        // are computed to sit on colLayer0 and nothing else.
        color: {
            if (root.mode === "media")
                return Theme.glass(root.cover.colLayer0);
            if (root.mode === "idle" && !hover.hovered)
                return Qt.alpha(Theme.surfaceContainerHigh, 0.35);
            return Theme.glass(Theme.surfaceContainerHigh);
        }

        // A track change is a colour change now, and a cut between two album
        // colours in the middle of the bar is more noticeable than the
        // artwork changing in a panel nobody has open.
        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // ---------------- The cover, blurred, with the wave on it --------
        //
        // THIS IS end-4's MEDIA CARD AT BAR SIZE, and it is what "change the
        // island's design" actually meant: not the colours of a row of bars,
        // but the construction. Their card draws the art again behind itself,
        // cropped and blurred, covers it with its own surface colour, and runs
        // the spectrum across the whole thing as one continuous wave. So does
        // this, in a capsule 36 pixels tall.
        //
        // AT THE BAR'S OWN ALPHA. Their card is opaque; this is a group on a
        // bar whose whole vocabulary is glass, and an opaque strip of
        // photograph in the middle of it would be the one thing up there that
        // is not see-through. The ground goes to Theme.glassAlpha and the
        // text does not, so the type keeps its contrast while the picture
        // behaves like every other surface on the bar.
        //
        // WHAT IT COSTS, since this is the first blurred surface in the shell
        // that is on screen whenever music plays rather than when a panel is
        // open: the capsule is about 250 x 36 collapsed and 420 x 36
        // expanded, which is nine and fifteen thousand pixels against the
        // dashboard ground's three hundred thousand -- three and five percent
        // of a blur that already runs. The wave's cava is the same process
        // the dashboard reads and was already running for the bars.
        Item {
            id: mediaGround

            anchors.fill: parent
            visible: root.mode === "media"
            opacity: Theme.glassAlpha

            Image {
                id: islandArt

                // Past the ends by a blur radius, so the blur has real pixels
                // to sample at the capsule's edges instead of dragging
                // transparency inwards. Same reason the panel's ground is
                // grown; see Dashboard.qml.
                anchors.fill: parent
                anchors.margins: -24
                visible: false

                source: root.coverArt
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                asynchronous: true
            }

            MultiEffect {
                anchors.fill: islandArt
                source: islandArt

                // Faded in rather than cut in, and only once there is
                // something to fade to: a capsule that blinked to a new
                // photograph on every track change would be the most
                // distracting thing on the bar.
                opacity: islandArt.status === Image.Ready ? 1 : 0

                blurEnabled: true
                blur: 1.0
                blurMax: 32
                saturation: -0.1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDuration }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.scrim

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDuration }
                }
            }

            // The spectrum, across the whole capsule and behind everything.
            // No opacity of its own: it fills at 0.15 alpha inside its canvas
            // and blurs the result, and stacking an item opacity on that would
            // be a second dimming on top of the one this Item already applies.
            WaveVisualizer {
                anchors.fill: parent

                live: Spectrum.active
                points: Spectrum.values
                maxVisualizerValue: Spectrum.maxValue
                smoothing: 2
                color: root.cover.colPrimary
            }
        }

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
                color: root.player?.isPlaying ? root.cover.colPrimary : root.cover.colSubtext

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
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
                // BOLD, AND IT WAS THE BAR'S DemiBold. A title in bold with a
                // quieter line under it is the relationship the media card
                // sets, and the collapsed island shows the same title -- it
                // should be the same weight in both places.
                font.weight: Font.Bold
                color: root.player?.isPlaying ? root.cover.colOnLayer0 : root.cover.colSubtext

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            // THE SPECTRUM USED TO SIT HERE, as a row of bars after the
            // title. The note that was here said behind-the-title had been
            // tried and dropped -- faint enough not to fight the words it was
            // barely visible, and strong enough to see it made them hard to
            // read -- and that was true of bars drawn in an accent over a
            // flat surface.
            //
            // It is not true of what is there now. The wave is a filled
            // silhouette at 0.15 alpha, blurred, under a measured scrim, on a
            // ground that is already a photograph; it reads as texture rather
            // than as a chart, which is the whole reason end-4 draw theirs
            // that way. See the capsule's own ground above.
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
                color: root.player?.isPlaying ? root.cover.colPrimary : root.cover.colSubtext

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
                    color: root.cover.colOnLayer0

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                Text {
                    text: Track.artist(root.player?.trackArtist ?? "")
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 240)
                    font.family: Theme.fontFamily
                    // THE CARD'S RATIO, NOT "one point smaller". end-4 set
                    // the artist at 12 against a body of 16 and this shell
                    // expresses that as a fraction of Theme.fontSize so the
                    // whole thing still answers the setting. The card does
                    // the same sum, so the artist is literally the same size
                    // in the island as it is in the panel.
                    font.pointSize: Theme.fontSize * 12 / 16
                    font.weight: Theme.fontWeight
                    color: root.cover.colSubtext

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
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
                // Four rather than two: the middle control is a filled disc
                // now and two flat glyphs pressed against it read as one
                // three-part object rather than as three buttons.
                spacing: 4

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

                        readonly property bool playing: root.player?.isPlaying ?? false

                        // 26 for the middle one and 24 for the other two,
                        // which is the media card's 44-and-24 pair scaled to a
                        // capsule 36 tall. The ratio is what carries, not the
                        // number: a large filled disc between two bare glyphs.
                        implicitWidth: control.primary ? 26 : 24
                        implicitHeight: control.primary ? 26 : 24
                        anchors.verticalCenter: parent.verticalCenter

                        opacity: control.available ? 1 : 0.35

                        // A ROUNDED SQUARE WHILE IT IS PLAYING AND A CIRCLE
                        // WHEN IT IS NOT, which is end-4's and is the one
                        // detail that makes the button read as a state rather
                        // than as a button. The dashboard's play button does
                        // exactly this at 44; this is the same object in the
                        // bar, which is the whole point of the island being
                        // the thing that opens it.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height

                            radius: control.primary
                                ? (control.playing ? 9 : height / 2)
                                : height / 2

                            color: {
                                if (control.primary)
                                    return controlMouse.containsMouse && control.available
                                        ? root.cover.colPrimaryHover
                                        : root.cover.colPrimary;
                                return controlMouse.containsMouse && control.available
                                    ? root.cover.colSecondaryContainerHover
                                    : "transparent";
                            }

                            Behavior on radius {
                                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                            }

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: control.glyph
                            font.family: Theme.fontFamily
                            font.pointSize: control.primary ? Theme.iconSize + 1 : Theme.iconSize
                            color: control.primary
                                ? root.cover.colOnPrimary
                                : root.cover.colOnSecondaryContainer

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
