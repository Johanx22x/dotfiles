// The dashboard: what the island opens into.
//
// It is the content of the bar's shared popout, not a window of its own, so
// it inherits the welding to the bar, the outside-click dismissal and the
// blur for free. See components/Popout.qml.
//
// FOUR TABS, and the split is by QUESTION rather than by widget:
//   Dashboard     what time is it, what day, and the things worth reaching
//                 for without leaving the panel: do not disturb, volume,
//                 wi-fi, bluetooth and starting a recording
//   Notifications what has been through here, and what the mute swallowed
//   Media         what is playing, and the controls for it
//   Performance   what is this machine doing right now
//
// There was another, Workspaces. It went because the bar already answers
// that question permanently and better: the dots are on screen at all times
// and switch on a click, while the dashboard's copy needed opening first.
//
// The tab strip stays put and only the panel under it changes. The panel is
// sized PER TAB -- see tabSizes below for why that is safe here and what it
// costs elsewhere.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick.Effects
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/modules/bar"
import "root:/modules/notifications"

Item {
    id: root

    // Fixed, for the reason in the header. Sized to hold the widest tab
    // (Dashboard, whose calendar sets the floor) with nothing cramped.
    // ONE SIZE PER TAB.
    //
    // This used to be a single fixed size for all of them, argued as "a
    // dashboard that resized itself would move its own tabs out from under
    // the pointer". Half of that held up and half did not: the panel hangs
    // from the bar, so its TOP edge and the tab strip on it never move
    // whatever the height is -- only the bottom edge travels, and nothing is
    // there to be clicked. Width is the one that shifts the tabs, because the
    // popout re-centres itself, so the tabs are kept still by animating it
    // rather than by freezing it.
    //
    // The cost of the old rule was a dashboard as tall as its tallest tab,
    // which meant Media and Performance sat in a box with a third of it
    // empty.
    readonly property var tabSizes: [
        {
            width: 942,
            height: 480
        },       // Dashboard: 270 + 14 + 330 + 14 + 314, measured rather than
                 // guessed -- the slack of a width declared too wide all lands
                 // on the right, because the row is laid out from the left.
                 //
                 // The third column exists because of the two that expand:
                 // Wi-Fi and Bluetooth open into lists, and while they shared a
                 // column with the recorder and the replay buffer, opening one
                 // shoved those off the bottom of the card. Things that grow
                 // and things that must stay put now have a column each.
        {
            width: 620,
            height: 480
        },       // Notifications: as tall as the Dashboard tab so the panel
                 // does not shrink under you on the way in from the badge,
                 // and narrow enough that a body wraps into two readable
                 // lines rather than one very long one.
        {
            width: 700,
            height: 380
        },       // Media
        {
            width: 760,
            height: 380
        }        // Performance
    ]

    readonly property var tabSize: root.tabSizes[root.currentTab] ?? root.tabSizes[0]

    implicitWidth: root.tabSize.width
    implicitHeight: root.tabSize.height

    // NO Behavior on either. Animating them looks like the obvious thing and
    // is the wrong thing: this Item's implicit size drives the popout's
    // implicit size, which drives the LAYER SURFACE. Animating it asks the
    // compositor to reconfigure and re-centre the surface on every frame --
    // sixty resizes in a fifth of a second -- and the tearing that produced
    // is the artefact. The size snaps in one step; what animates is the
    // content, below.

    // Seconds to m:ss. MPRIS reports seconds as a double.
    function clockFormat(seconds: real): string {
        if (!seconds || seconds < 0)
            return "0:00";
        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return `${minutes}:${rest < 10 ? "0" : ""}${rest}`;
    }

    // ---------------- Live playback position ----------------
    //
    // MPRIS position is NOT pushed. The player only volunteers it when it
    // seeks, so a binding straight to `player.position` paints the value that
    // happened to be there when the tab was opened and then sits frozen --
    // which is exactly what the seek bar was doing.
    //
    // So it is polled, and the poll does two things: it pokes the notify
    // signal, which is what makes Quickshell re-read the property off D-Bus,
    // and then it copies the result somewhere the bindings can see change.
    // Reading `player.position` on its own is not enough; nothing would have
    // told QML the value moved.
    //
    // Twice a second: a seek bar that steps once a second visibly ticks.
    property real livePosition: 0

    Timer {
        interval: 500
        repeat: true
        // Only while the tab is on screen AND something is playing. The
        // popout destroys its content when it closes, so this stops on its
        // own the rest of the time rather than polling D-Bus all day.
        running: root.tab === "Media" && (root.mediaPlayer?.isPlaying ?? false)
        triggeredOnStart: true

        onTriggered: {
            const p = root.mediaPlayer;
            if (!p)
                return;
            if (typeof p.positionChanged === "function")
                p.positionChanged();
            root.livePosition = p.position ?? 0;
        }
    }

    // One definition of "the player", so the Timer above and the Media tab
    // below cannot disagree about which one they are talking to.
    readonly property var mediaPlayer: {
        const players = Mpris.players.values;
        if (players.length === 0)
            return null;
        return players.find(p => p.isPlaying) ?? players[0];
    }

    // Nothing is sampled unless the Performance tab is actually being looked
    // at. The popout destroys its content when it closes, so this goes false
    // on its own -- /proc is left alone and nvidia-smi is not held open.
    Binding {
        target: SystemStats
        property: "active"
        value: root.tab === "Performance"
    }

    // Both the names and the current one come from the singleton: see
    // IslandState.dashboardTabs for why the order is not written down here.
    readonly property var tabs: IslandState.dashboardTabs
    // Read-only: the tab is IslandState's to own, so that it is still there
    // the next time this component is built. Clicking a tab writes to the
    // singleton, which flows straight back here.
    readonly property int currentTab: IslandState.dashboardTab

    // WHAT IS SHOWING, BY NAME. Everything below asks this rather than
    // comparing currentTab to a number.
    //
    // The numbers were fine while the order was fixed and became a trap the
    // moment it was not: adding Notifications in second place moved Media and
    // Performance along by one, and every `currentTab === 2` in the file was
    // silently about a different tab than it used to be. Three of those were
    // `visible` bindings, which fail loudly, and one was the binding that
    // decides whether SystemStats samples the machine -- which would have gone
    // on polling /proc and nvidia-smi from the wrong tab without anything
    // looking wrong.
    readonly property string tab: root.tabs[root.currentTab] ?? root.tabs[0]

    Column {
        anchors.fill: parent
        spacing: 16

        // ---------------- Tab strip ----------------
        Row {
            id: strip

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28

            Repeater {
                model: root.tabs

                Item {
                    id: tab

                    required property int index
                    required property string modelData

                    readonly property bool active: root.currentTab === tab.index

                    implicitWidth: label.implicitWidth
                    implicitHeight: label.implicitHeight + 10

                    Text {
                        id: label

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: tab.active ? Font.Bold : Theme.fontWeight
                        color: tab.active ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }

                    // The underline is one rectangle per tab rather than one
                    // that slides: a slider would have to know where every tab
                    // is, and the tabs are laid out by the Row.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tab.active ? label.implicitWidth : 0
                        height: 2
                        radius: 1
                        color: Theme.primary

                        Behavior on width {
                            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandState.dashboardTab = tab.index
                    }
                }
            }
        }

        // ---------------- Panel ----------------
        Item {
            id: panelArea

            width: parent.width
            height: parent.height - strip.height - 16

            // The transition between tabs, now that the size itself cannot be
            // animated (see the note on tabSizes). The panel snaps to its new
            // size and the content fades in over it, which reads as one
            // deliberate change rather than as a box jumping.
            //
            // Fading IN only, not out and in: the old tab is gone the instant
            // the size changes, and fading something that is already replaced
            // would just be a flash.
            NumberAnimation {
                id: tabFade

                target: panelArea
                property: "opacity"
                from: 0
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }

            Connections {
                target: root

                function onCurrentTabChanged(): void {
                    tabFade.restart();
                }
            }

            // ============ Dashboard ============
            Row {
                anchors.fill: parent
                spacing: 14
                visible: root.tab === "Dashboard"

                // Clock and calendar in ONE column, not two cards side by
                // side.
                //
                // Vertically they were both wasteful in the same way: the
                // clock stacked HH over mm down a 150px card and the calendar
                // sat centred in whatever height the controls column happened
                // to need. Laying the time out horizontally lets it sit ON TOP
                // of the month at the same width, and the two together end up
                // shorter than either card was on its own.
                Column {
                    // One number for the clock's height, used by both cards:
                    // raising it and leaving the calendar subtracting the old
                    // value is what pushed the month past the bottom edge.
                    readonly property int clockHeight: 104

                    width: month.implicitWidth + 32
                    height: parent.height
                    spacing: 14

                    Card {
                        width: parent.width
                        height: parent.clockHeight

                        Column {
                            anchors.centerIn: parent

                            // Centring the Column centres its LINE BOXES, not
                            // its ink. At 40pt the digits reserve descender
                            // space they never use, so the visible block sat
                            // low: measured 15px of gap above and 2 below.
                            // The offset is that difference, halved, and it is
                            // measured rather than guessed -- same as the icon
                            // overflow the old waybar stylesheet documented.
                            anchors.verticalCenterOffset: -6

                            spacing: 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(dashClock.date, "HH:mm")
                                font.family: Theme.fontFamily
                                font.pointSize: 40
                                font.weight: Font.Bold
                                color: Theme.textOnSurface
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDate(dashClock.date, "dddd, d MMMM")
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                                color: Theme.primary

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }
                        }
                    }

                // The month, reused verbatim from what the clock's popout used
                // to open. Moving it here is the whole reason that popout went
                // away: a calendar is something you go to, not something that
                // springs out when you meant to read the time.
                // Widened: the system card that used to sit to its right moved
                // to the Performance tab, where it belongs next to the other
                // readings about this machine.
                    Card {
                        // Sized to the month it holds, not to whatever is
                        // left over: a calendar is a fixed 7 columns wide.
                        width: parent.width
                        height: parent.height - parent.clockHeight - parent.spacing

                        CalendarView {
                            id: month

                            anchors.centerIn: parent
                        }
                    }
                }


                // Controls. The things most often reached for without leaving
                // the panel.
                //
                // A column of its own rather than four more cards in the row:
                // they are all small, they are all actions, and side by side
                // they would each be too narrow to hold a slider or a list.
                Card {
                    width: 330
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        // First, and not last, because it is the only one of
                        // the four that never changes height: below Wi-Fi and
                        // Bluetooth it would be shoved down the card every
                        // time one of their lists opened.
                        DndControl {
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineVariant
                        }

                        // ABOVE THE VOLUME AND WITH NO RULE BETWEEN THEM.
                        // They are the same kind of control -- a value you set
                        // by feel and stop thinking about -- so they read as
                        // one block, and the rule below separates that block
                        // from the toggles. On a desktop this collapses to
                        // nothing and the pair is just the volume again.
                        BrightnessControl {
                            width: parent.width
                        }

                        VolumeControl {
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineVariant
                        }

                        WifiControl {
                            id: wifi

                            width: parent.width

                            // One list open at a time. With both, the column
                            // would need room for two ceilings and the card
                            // would have to be as tall as the worst case
                            // rather than as tall as it ever looks.
                            onExpandedChanged: if (expanded)
                                bluetooth.expanded = false
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineVariant
                        }

                        BluetoothControl {
                            id: bluetooth

                            width: parent.width

                            onExpandedChanged: if (expanded)
                                wifi.expanded = false
                        }

                    }
                }

                // ...and capture gets its own, where nothing above it can move
                // it. Both of these are things you aim at knowing where they
                // are, which is exactly what a column shared with an expanding
                // list cannot promise.
                Card {
                    width: 314
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        RecordControl {
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineVariant
                        }

                        ReplayControl {
                            width: parent.width
                        }
                    }
                }
            }

            // ============ Notifications ============
            // One card and no columns: this tab is a list, and a list wants
            // the whole width rather than a share of it.
            Card {
                anchors.fill: parent
                visible: root.tab === "Notifications"

                // Its `visible` is not set here on purpose: an item's
                // effective visibility follows its parent's, so hiding the
                // card hides this, and the onVisibleChanged inside it -- the
                // thing that marks the count read -- fires off that. Same
                // mechanism WifiControl uses to only scan while it is on
                // screen.
                NotificationHistory {
                    anchors.fill: parent
                    anchors.margins: 16
                }
            }

            // ============ Media ============
            // A real player rather than a readout: cover, transport, seek and
            // volume, with the waveform the island already uses so the two
            // read as the same instrument at two sizes.
            Card {
                anchors.fill: parent
                visible: root.tab === "Media"

                // Same rule the island uses: prefer what is actually playing,
                // fall back to the first player that exists so a paused track
                // still fills the tab.
                readonly property var player: root.mediaPlayer

                Text {
                    anchors.centerIn: parent
                    visible: !parent.player
                    text: "Nothing is playing"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.textOnSurfaceVariant
                }

                Row {
                    id: playerRow

                    readonly property var player: parent.player

                    // ---- Cover art, and the fallback for Firefox players ----
                    // Zen publishes title, album and artist over MPRIS but NOT
                    // mpris:artUrl, so trackArtUrl is empty and the card came
                    // up blank. Verified on the bus while a track was playing:
                    //
                    //   busctl --user get-property \
                    //     org.mpris.MediaPlayer2.firefox.instance_1_148 \
                    //     /org/mpris/MediaPlayer2 \
                    //     org.mpris.MediaPlayer2.Player Metadata
                    //
                    // returns xesam:title / album / artist / url and no art
                    // key, and nothing is written to any temp directory
                    // either. Firefox has had this since 81 (bug 1642729:
                    // fetch the MediaSession image, save it in the profile,
                    // publish a file:// URL), so the code is there and
                    // something in Zen is not running it. That is the real
                    // bug and it is NOT fixed here.
                    //
                    // What is fixed here is the symptom, using the one thing
                    // Zen does publish: xesam:url. For anything YouTube --
                    // which is what music.youtube.com is -- the video id in
                    // that URL maps to a public thumbnail. No key, no API, no
                    // extra process.
                    //
                    // Scope, so nobody expects more than it does: this covers
                    // YouTube URLs only. Any other site playing in Zen still
                    // shows the stand-in, exactly as before. Every non-Firefox
                    // player is untouched -- trackArtUrl wins whenever it has
                    // a value.
                    readonly property string youtubeId: {
                        const meta = player?.metadata ?? null;
                        const url = meta ? (meta["xesam:url"] ?? "") : "";
                        const m = url.match(/[?&]v=([\w-]{11})/) || url.match(/youtu\.be\/([\w-]{11})/);
                        return m ? m[1] : "";
                    }

                    // maxresdefault first, mqdefault as the retry. Both are
                    // 16:9 and BAR-FREE, which is the point: hqdefault is
                    // 480x360 and pads a widescreen frame with black bands,
                    // and those bands would be part of the image the sharp
                    // layer draws. maxresdefault does not exist for every
                    // video, hence the retry rather than picking one.
                    property bool maxResFailed: false
                    onYoutubeIdChanged: maxResFailed = false

                    readonly property string artSource: {
                        const direct = player?.trackArtUrl ?? "";
                        if (direct)
                            return direct;
                        if (!youtubeId)
                            return "";
                        const size = maxResFailed ? "mqdefault" : "maxresdefault";
                        return "https://i.ytimg.com/vi/" + youtubeId + "/" + size + ".jpg";
                    }

                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    visible: !!playerRow.player

                    // ---- Cover ----
                    // ClippingRectangle and NOT a Rectangle with clip: true.
                    // A plain Item clips to its BOUNDING BOX, so the rounded
                    // corners were painted on the rectangle and the artwork
                    // carried straight on over them -- a square photo sitting
                    // in a rounded frame, which is what looked out of place
                    // against every other card here. This one clips to the
                    // radius itself.
                    ClippingRectangle {
                        id: cover

                        width: parent.height
                        height: parent.height
                        radius: Theme.cardRadius - 8
                        color: Theme.surfaceContainerHighest

                        // TEMPORARY -- chasing the unpainted bottom band. Dumps
                        // the geometry of the cover and of both layers whenever
                        // any of it settles. Remove once the cause is known; do
                        // not commit.
                        function dumpGeometry(what: string): void {
                            console.log(`[cover] ${what}` + ` cover=${cover.width}x${cover.height}` + ` backdrop=${artBackdrop.width}x${artBackdrop.height}` + ` status=${artBackdrop.status} painted=${artBackdrop.paintedWidth}x${artBackdrop.paintedHeight}` + ` source=${artBackdrop.sourceSize.width}x${artBackdrop.sourceSize.height}` + ` art=${art.width}x${art.height} artStatus=${art.status}` + ` artPainted=${art.paintedWidth}x${art.paintedHeight}` + ` url=${playerRow.artSource}`);
                        }

                        onWidthChanged: dumpGeometry("cover resized")
                        onHeightChanged: dumpGeometry("cover resized")

                        // A BLURRED COPY BEHIND, and the sharp one fitted in
                        // front. This is damage control, not a fix: what the
                        // player publishes is all there is.
                        //
                        // Measured, on the track that prompted this: Chromium
                        // writes the MediaSession thumbnail to a temp file and
                        // that file is 150x83. Drawn into a ~300px square with
                        // PreserveAspectCrop it was being magnified more than
                        // three times AND cropped to its middle third, which is
                        // most of why it looked so rough.
                        //
                        // Fit instead of Crop halves the magnification and
                        // shows the whole thumbnail; the blurred fill is what
                        // stops that leaving two empty bands. Blur is the one
                        // treatment that costs nothing here -- there is no
                        // detail left to protect.
                        Image {
                            id: artBackdrop

                            anchors.fill: parent
                            source: art.source
                            visible: false
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 1024
                            asynchronous: true

                            // TEMPORARY, see cover.dumpGeometry above.
                            onStatusChanged: cover.dumpGeometry("backdrop status " + status)
                            onPaintedHeightChanged: cover.dumpGeometry("backdrop repainted")
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: artBackdrop
                            visible: art.visible
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 48
                            brightness: -0.35
                            saturation: 0.2
                        }

                        Image {
                            id: art

                            anchors.fill: parent
                            source: playerRow.artSource
                            // Ready and not just "source is set": a player that
                            // publishes no art would otherwise leave the
                            // broken-image chequerboard sitting in the card.
                            visible: status === Image.Ready

                            // The retry described on playerRow.artSource. An
                            // Error on the maxres URL means that video has no
                            // maxres thumbnail, so drop to mqdefault; the flag
                            // resets by itself on the next track.
                            onStatusChanged: {
                                if (status === Image.Error && playerRow.youtubeId && !playerRow.maxResFailed)
                                    playerRow.maxResFailed = true;

                                // TEMPORARY, see cover.dumpGeometry above.
                                cover.dumpGeometry("art status " + status);
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true

                            // Decoded at up to 1024 rather than at the size it
                            // is drawn. sourceSize never ENLARGES -- Qt only
                            // uses it to scale down -- so a 150px thumbnail
                            // costs nothing here and a real 600px cover, which
                            // is what other players send, keeps its detail.
                            sourceSize.width: 1024

                            mipmap: true
                            smooth: true
                        }

                        // The stand-in. A blank square reads as a load that
                        // failed; a glyph reads as "this track has no cover".
                        Text {
                            anchors.centerIn: parent
                            visible: !art.visible
                            text: Icons.music
                            font.family: Theme.fontFamily
                            font.pointSize: 42
                            color: Theme.outline
                        }
                    }

                    // ---- Everything else ----
                    Column {
                        id: details

                        // Centred against the cover rather than starting at
                        // its top edge: the cover is a fixed square and this
                        // column is shorter, so top-aligning left the whole
                        // right-hand side hanging off the ceiling.
                        anchors.verticalCenter: parent.verticalCenter

                        width: parent.width - cover.width - parent.spacing
                        spacing: 10

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: playerRow.player?.trackTitle ?? ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize + 5
                            font.weight: Font.Bold
                            color: Theme.textOnSurface
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            // Through Track, not raw: it strips the " - Topic"
                            // suffix YouTube's auto-generated channels carry.
                            // Shared with the island so the same track never
                            // reads two different ways in two places.
                            text: Track.artist(playerRow.player?.trackArtist ?? "")
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: Theme.textOnSurfaceVariant
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: playerRow.player?.trackAlbum ?? ""
                            // An empty album would otherwise keep a blank line
                            // and its spacing, which is the gap that made the
                            // block look pushed upwards.
                            visible: text !== ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            color: Theme.outline
                        }

                        // The island's waveform, given room. Same component and
                        // the same cava feed -- it is one instrument shown at
                        // two sizes, not a second visualiser.
                        //
                        // It spans exactly the seek bar's width, so the two
                        // read as one block instead of a short row of bars
                        // floating above a long line. The bar COUNT is fixed by
                        // cava's config, so filling the width means solving for
                        // the bar width rather than adding bars:
                        //
                        //   n*w + (n-1)*gap = width
                        //
                        // Floored, so rounding never pushes the last bar past
                        // the edge and makes the Row wider than the column.
                        Waveform {
                            anchors.horizontalCenter: parent.horizontalCenter

                            maxHeight: 46

                            // Solve for the GAP and not for the bar width.
                            // Filling the width by fattening the bars was the
                            // first attempt and it looked wrong: cava gives 14
                            // bands, so spreading them over ~430px made each
                            // one 27px across -- a row of lozenges rather than
                            // a spectrum. The bars keep a fixed slim width and
                            // the space between them absorbs the rest.
                            barWidth: 8
                            spacing: Math.max(3, (details.width - Spectrum.bars * barWidth) / (Spectrum.bars - 1))
                        }

                        // ---- Seek ----
                        // Only when the player actually reports a position. A
                        // progress bar frozen at zero is worse than no bar.
                        Item {
                            width: parent.width
                            height: 22
                            visible: (playerRow.player?.lengthSupported ?? false) && (playerRow.player?.length ?? 0) > 0

                            Rectangle {
                                id: track

                                anchors.left: parent.left
                                anchors.right: elapsed.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 5
                                radius: 2.5
                                color: Qt.alpha(Theme.textOnSurfaceVariant, 0.25)

                                Rectangle {
                                    width: parent.width * Math.min(1, root.livePosition / Math.max(1, playerRow.player?.length ?? 1))

                                    // Smoothed, or the bar jumps twice a
                                    // second instead of creeping.
                                    Behavior on width {
                                        NumberAnimation { duration: 480 }
                                    }
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: playerRow.player?.canSeek ?? false
                                    onClicked: mouse => {
                                        const p = playerRow.player;
                                        if (!p)
                                            return;
                                        p.position = (mouse.x / track.width) * p.length;
                                    }
                                }
                            }

                            Text {
                                id: elapsed

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const p = playerRow.player;
                                    if (!p)
                                        return "";
                                    return `${root.clockFormat(root.livePosition)} / ${root.clockFormat(p.length)}`;
                                }
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1
                                color: Theme.textOnSurfaceVariant
                            }
                        }

                        // ---- Transport ----
                        // Round buttons rather than bare glyphs. Three marks
                        // floating on a card have no target to aim at and no
                        // hover to speak of; the play button is also the one
                        // control here anyone reaches for without looking, so
                        // it is the only filled one and the larger of the
                        // three. That size difference IS the hierarchy.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10

                            RoundButton {
                                glyph: Icons.skipPrevious
                                enabled: playerRow.player?.canGoPrevious ?? false
                                onActivated: playerRow.player?.previous()
                            }

                            RoundButton {
                                glyph: playerRow.player?.isPlaying ? Icons.pause : Icons.play
                                filled: true
                                enabled: playerRow.player?.canTogglePlaying ?? false
                                onActivated: playerRow.player?.togglePlaying()
                            }

                            RoundButton {
                                glyph: Icons.skipNext
                                enabled: playerRow.player?.canGoNext ?? false
                                onActivated: playerRow.player?.next()
                            }
                        }

                    }
                }
            }

            // ============ Performance ============
            // WHAT THIS MACHINE IS on the left, WHAT IT IS DOING on the right.
            //
            // The left column is the narrow one and holds the two readings
            // that are a list: the hardware's identity on top, memory below.
            // The right column is wide because CPU and GPU lie down -- three
            // short readings each, which sit beside the headline rather than
            // under it, and that shape wants width more than height.
            Row {
                anchors.fill: parent
                spacing: 14
                visible: root.tab === "Performance"

                // ---- Left: identity over memory ----
                Column {
                    width: (parent.width - 14) * 0.38
                    height: parent.height
                    spacing: 14

                    Card {
                        id: systemCard

                        width: parent.width

                        // MEASURED FROM ITS CONTENT, not a number picked to
                        // fit. It was 104, then 88 when RAM needed the space,
                        // and at 88 its own rows were the cramped ones -- two
                        // cards trading the same pixels back and forth, each
                        // fix creating the next complaint. Bound to the rows
                        // plus a fixed 18 of padding it cannot be cramped, and
                        // RAM still gets everything left over.
                        height: systemRows.implicitHeight + 36

                        Column {
                            id: systemRows

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 18
                            spacing: 12

                            Repeater {
                                model: [
                                    { glyph: Icons.arch, value: "Arch Linux" },
                                    { glyph: Icons.gpu, value: "Hyprland" },
                                    { glyph: Icons.clock, value: root.uptime }
                                ]

                                Row {
                                    required property var modelData

                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData.glyph
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.iconSize
                                        color: Theme.primary
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        // Elided rather than wrapped: uptime is
                                        // the long one and a second line would
                                        // push the row out of the card.
                                        width: parent.width - Theme.iconSize - 16
                                        elide: Text.ElideRight
                                        text: parent.modelData.value
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize - 1
                                        font.weight: Theme.fontWeight
                                        color: Theme.textOnSurface
                                    }
                                }
                            }
                        }
                    }

                    StatCard {
                        width: parent.width
                        // Everything the identity card did not take. RAM was
                        // cramped when the split was a fraction: its headline
                        // plus four rows came to more than the share it was
                        // given, so the rows ended up shoulder to shoulder.
                        height: parent.height - systemCard.height - 14

                        title: "RAM"
                        glyph: Icons.ram
                        percent: SystemStats.ramPercent
                        // Used AND total on one line. They were two rows and a
                        // third for free, which is the same fact said three
                        // ways -- and three rows of it are what made the card
                        // feel packed. "8.5 / 31.1" answers "how much is left"
                        // without arithmetic and without a row of its own.
                        details: [
                            { label: "Used", value: `${SystemStats.ramUsed.toFixed(1)} / ${SystemStats.ramTotal.toFixed(1)} GiB` },
                            { label: "Free", value: `${(SystemStats.ramTotal - SystemStats.ramUsed).toFixed(1)} GiB` },
                            { label: "Swap", value: SystemStats.swapTotal > 0
                                ? `${SystemStats.swapUsed.toFixed(1)} / ${SystemStats.swapTotal.toFixed(1)} GiB`
                                : "off" }
                        ]
                        footer: ""
                    }
                }

                // ---- Right: the two that are working ----
                Column {
                    width: (parent.width - 14) * 0.62
                    height: parent.height
                    spacing: 14

                    StatCard {
                        width: parent.width
                        // Half the column, or the whole of it when the GPU
                        // card is not there to take the other half. The same
                        // arrangement RAM has with the identity card above it:
                        // one card takes what the other left, so a card that
                        // does not apply to this machine costs no empty space.
                        height: gpuCard.visible ? (parent.height - 14) / 2 : parent.height
                        horizontal: true

                        title: "CPU"
                        glyph: Icons.cpu
                        percent: SystemStats.cpuPercent
                        details: [
                            { label: "Temp", value: `${Math.round(SystemStats.cpuTemp)} °C` },
                            { label: "Clock", value: `${(SystemStats.cpuFreq / 1000).toFixed(2)} GHz` },
                            { label: "Threads", value: `${SystemStats.cpuThreads}` }
                        ]
                        footer: SystemStats.cpuModel
                    }

                    StatCard {
                        id: gpuCard

                        width: parent.width
                        height: (parent.height - 14) / 2
                        horizontal: true

                        // ONLY ONCE A CARD HAS ANSWERED. On a machine with
                        // neither vendor bound SystemStats spawns nothing and
                        // leaves every figure below at its initial zero, and a
                        // tile reading 0 °C, 0.0 / 0 GiB, 0 W under a blank
                        // name looks like a panel that broke rather than a
                        // machine without the part. No tile says the second.
                        //
                        // `visible` and not a zero height, for the reason the
                        // empty album line down in Media uses it: a Column
                        // skips an invisible child AND the spacing in front of
                        // it, which is what lets the CPU card above simply
                        // grow into the space instead of leaving a gap where
                        // this one would have been.
                        //
                        // It only ever turns on. Both readers run whether or
                        // not this tab is open -- the island has to be able to
                        // warn about a hot card with the dashboard shut -- so
                        // by the first time anyone opens Performance the card
                        // is either already here or was never coming, and
                        // there is no appearing tile to animate.
                        visible: SystemStats.gpuAvailable

                        title: "GPU"
                        glyph: Icons.gpu
                        percent: SystemStats.gpuPercent
                        details: [
                            { label: "Temp", value: `${Math.round(SystemStats.gpuTemp)} °C` },
                            { label: "VRAM", value: `${SystemStats.gpuVramUsed.toFixed(1)} / ${SystemStats.gpuVramTotal.toFixed(0)} GiB` },
                            { label: "Power", value: `${Math.round(SystemStats.gpuPower)} W` }
                        ]
                        // Already trimmed of its vendor prefix by SystemStats,
                        // for both vendors, where the card is named and the
                        // vendor is known. Nothing to do here.
                        footer: SystemStats.gpuName
                    }
                }
            }

        }
    }

    SystemClock {
        id: dashClock

        precision: SystemClock.Seconds
    }

    // ---------------- Readings off /proc ----------------
    // Straight from the kernel rather than by spawning `free` or `top` on a
    // timer: reading two small files is what those tools do anyway, and doing
    // it here keeps the shell process-free the way the rest of the migration
    // did.

    readonly property string uptime: {
        const raw = uptimeFile.text();
        if (!raw)
            return "";
        const seconds = Math.floor(parseFloat(raw.split(" ")[0]));
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return `up ${hours} hour${hours === 1 ? "" : "s"}, ${minutes} minute${minutes === 1 ? "" : "s"}`;
    }

    property real ramPercent: 0
    property real cpuPercent: 0

    // CPU is a RATE, so one reading says nothing: it needs the difference
    // between two samples of the cumulative jiffy counters. These hold the
    // previous sample.
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
    }

    FileView {
        id: statFile

        path: "/proc/stat"
    }

    function sample(): void {
        uptimeFile.reload();
        memFile.reload();
        statFile.reload();

        const mem = memFile.text();
        if (mem) {
            const total = parseFloat(mem.match(/MemTotal:\s+(\d+)/)?.[1] ?? 0);
            // MemAvailable and not MemFree: free counts cache as used memory
            // and reports a machine with a warm page cache as nearly full.
            const available = parseFloat(mem.match(/MemAvailable:\s+(\d+)/)?.[1] ?? 0);
            if (total > 0)
                root.ramPercent = (1 - available / total) * 100;
        }

        const stat = statFile.text();
        if (stat) {
            const fields = stat.split("\n")[0].trim().split(/\s+/).slice(1).map(parseFloat);
            const total = fields.reduce((a, b) => a + b, 0);
            // Fields 3 and 4 are idle and iowait: both are the CPU not working.
            const idle = fields[3] + fields[4];
            const deltaTotal = total - root.lastCpuTotal;
            const deltaIdle = idle - root.lastCpuIdle;
            if (root.lastCpuTotal > 0 && deltaTotal > 0)
                root.cpuPercent = (1 - deltaIdle / deltaTotal) * 100;
            root.lastCpuTotal = total;
            root.lastCpuIdle = idle;
        }
    }

    Timer {
        interval: 2000
        // Only while the dashboard is actually on screen. The popout destroys
        // its content on close, so this stops sampling the moment it is shut
        // rather than polling /proc forever in the background.
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // A transport button. Filled and larger for the primary action, a ghost
    // circle for the others.
    component RoundButton: Rectangle {
        id: button

        property string glyph: ""
        property bool filled: false

        signal activated

        // The BOX is the same for all three; only the drawn circle differs.
        // That is what keeps them square with each other: a Row lays its
        // children out on the x axis and leaves them at y = 0, so three boxes
        // of different heights line up by their TOPS -- which is exactly how
        // the small buttons ended up sitting high against the play button.
        // Equal boxes make the alignment structural instead of something each
        // instance has to remember to anchor.
        implicitWidth: 58
        implicitHeight: 58
        radius: width / 2

        // The box itself draws nothing; `disc` below is the circle.
        color: "transparent"

        // Dimmed rather than hidden when the player cannot do it: a control
        // that disappears moves the two beside it.
        opacity: button.enabled ? 1 : 0.3

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Rectangle {
            id: disc

            anchors.centerIn: parent

            // Drawn smaller than the box for the secondary buttons, so the
            // play button still reads as the larger of the three without the
            // boxes having to differ.
            width: button.filled ? 56 : 46
            height: width
            radius: width / 2

            color: {
                if (button.filled)
                    return buttonMouse.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary;
                return buttonMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent";
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Theme.fontFamily
            // Material Design glyphs sit well inside their em box, so a size
            // that looks right as text looks lost inside a circle. These are
            // set against the disc, not against the body text.
            font.pointSize: button.filled ? Theme.fontSize + 11 : Theme.fontSize + 8
            color: button.filled ? Theme.textOnPrimary : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    // One subsystem's card: a headline percentage over a bar, a table of
    // details, and the hardware's name at the foot.
    // One subsystem's card. Two shapes from one definition: a GridLayout of
    // one column stacks the headline over the details, of two columns it sets
    // them side by side. Writing the two layouts out separately would be the
    // same card twice, and they would drift.
    component StatCard: Rectangle {
        id: stat

        property string title: ""
        property string glyph: ""
        property real percent: 0
        property var details: []
        property string footer: ""
        property bool horizontal: false

        radius: Theme.cardRadius - 6
        color: Theme.surfaceContainerHigh

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        // Anchored top AND bottom, so the layout knows the whole height it has
        // to work with. That is what lets the detail rows below distribute
        // into the space left over instead of running past the card -- three
        // rounds of hand-arithmetic between this card and the one above it
        // said clearly enough that the sizes should not be arithmetic.
        GridLayout {
            id: cardLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18
            // Room for the footer, when there is one.
            anchors.bottomMargin: stat.footer !== "" ? 38 : 18

            columns: stat.horizontal ? 2 : 1
            columnSpacing: 24
            // The gap between the headline and the rows in the stacked shape.
            rowSpacing: 14

            // ---- Headline ----
            Column {
                Layout.alignment: Qt.AlignTop
                // Wide enough for "100%" and the bar under it, and no wider:
                // in the two-column shape everything left over goes to the
                // detail rows.
                Layout.preferredWidth: stat.horizontal ? 130 : stat.width - 36
                spacing: 8

                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.glyph
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.primary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.title
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Bold
                        color: Theme.textOnSurfaceVariant
                    }
                }

                Text {
                    text: `${Math.round(stat.percent)}%`
                    font.family: Theme.fontFamily
                    // Smaller in the stacked shape than in the wide one. A
                    // vertical card has to fit a headline AND four rows in one
                    // column, and the percentage is the one element with room
                    // to give -- it is still by far the largest thing on the
                    // card at 22.
                    font.pointSize: stat.horizontal ? 26 : 22
                    font.weight: Font.Bold
                    color: Theme.textOnSurface
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.textOnSurfaceVariant, 0.25)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, stat.percent / 100))
                        height: parent.height
                        radius: parent.radius

                        // The bar turns as the load does, so the card can be
                        // read from across the room without the number.
                        color: stat.percent > 90 ? Theme.critical
                            : stat.percent > 66 ? Theme.warning
                            : Theme.primary

                        Behavior on width {
                            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }
                }
            }

            // ---- Details ----
            Column {
                id: detailRows

                readonly property int rowHeight: 18

                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                // Takes whatever the headline did not, and spreads its rows
                // across it. Clamped at both ends: never tighter than 4, so
                // the rows stay legible if the card is short, and never looser
                // than 10, so a tall card does not drift into a list of
                // widely separated lines.
                Layout.fillHeight: true

                spacing: Math.max(4, Math.min(10,
                    (height - stat.details.length * rowHeight) / Math.max(1, stat.details.length - 1)))

                Repeater {
                    model: stat.details

                    Item {
                        required property var modelData

                        width: parent.width
                        height: detailRows.rowHeight

                        Text {
                            anchors.left: parent.left
                            text: parent.modelData.label
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            color: Theme.textOnSurfaceVariant
                        }

                        Text {
                            anchors.right: parent.right
                            text: parent.modelData.value
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            color: Theme.textOnSurface
                        }
                    }
                }
            }
        }

        // Pinned to the bottom rather than sitting at the end of the layout:
        // the cards carry names of different lengths and this keeps them on
        // one line whichever shape the card is in.
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18

            visible: stat.footer !== ""
            text: stat.footer
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.outline
        }
    }

    // A panel inside the dashboard. One rounded surface, one step lighter than
    // the popout it sits in, so the grid reads as cards on a sheet.
    component Card: Rectangle {
        radius: Theme.cardRadius - 6
        color: Theme.surfaceContainerHigh

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
