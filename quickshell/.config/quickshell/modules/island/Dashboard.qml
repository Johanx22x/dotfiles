// The dashboard: what the island opens into.
//
// It is the content of the bar's shared popout, not a window of its own, so
// it inherits the welding to the bar, the outside-click dismissal and the
// blur for free. See components/Popout.qml.
//
// ONE VIEW, AND IT USED TO BE THREE TABS. Dashboard, Media and Performance
// each had a strip entry, a panel of its own and a size of its own, and the
// panel was as wide as the widest of them. The split was argued by QUESTION
// -- this desktop, what is playing, this machine -- and the argument was
// sound; what was not sound was the price. Two of the three answers were
// always one click away, the size changed under the pointer every time the
// answer changed, and the tab strip cost a row of the panel to say which of
// three things you were looking at.
//
// So the three questions are asked at once, in three columns:
//
//   left    the time and the month
//   middle  the things reached for without leaving the panel, and capture
//   right   what is playing, and what this machine is doing
//
// It fits because five things left, and each of them left for a reason that
// is written where it used to be:
//
//   Wi-Fi and Bluetooth      full pages in the settings window do this better
//   the identity card        distribution, compositor and uptime
//   the replay's own config  length, screen, codecs -- all on the settings
//                            page now, so what is left here is the act
//   nine detail rows         three per subsystem, replaced by three dials
//   the tab strip            with nothing left to switch between
//
// WHAT DID NOT CHANGE. The panel is still a fixed size, and still snaps
// rather than animating: this Item's implicit size drives the popout's, which
// drives the LAYER SURFACE, and animating that asks the compositor to
// reconfigure and re-centre the surface on every frame. Sixty resizes in a
// fifth of a second is what tore. With one view there is nothing left to
// resize BETWEEN, which is the other half of the reason the tabs are gone.

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick.Effects
import QtQuick
import "root:/"
import "root:/modules/bar"

Item {
    id: root

    // ---------------- Geometry ----------------
    //
    // MEASURED, NOT PICKED. Every number below is either derived from the
    // content it holds or is a size somebody chose on purpose; the three
    // column widths and the panel height are the only literals, and each one
    // says what it is made of.
    //
    // The old file carried three of these sets, one per tab, because a
    // resizing panel had to know where it was going. There is one now.

    readonly property int gap: 14
    readonly property int cardPad: 16

    // As wide as the month, which is a fixed seven columns and cannot be
    // negotiated with. Everything else in this column is narrower.
    readonly property int leftWidth: month.implicitWidth + root.cardPad * 2

    // 296, and it was 330 while Wi-Fi and Bluetooth lived here. Those two
    // opened into LISTS -- a network name plus a signal glyph plus a lock --
    // and the width was theirs. What is left is a switch, two sliders and
    // three capture buttons; at 296 each of those buttons is 84 across, which
    // holds "Display" at 9pt with room either side.
    readonly property int midWidth: 296

    // 348: three dials of 100 with 8 between them and the card's own padding
    // either side. The media card above it inherits the width rather than
    // asking for one, because a cover, a title and a transport row will use
    // whatever they are given and the dials will not.
    readonly property int rightWidth: 348

    readonly property int clockHeight: 104

    // The dial, and the card that holds a row of them. A hundred pixels is
    // what it takes for "100%" at three points over the body size to sit
    // inside the ring with the label above it and the reading below -- see
    // the Gauge component at the foot of this file.
    readonly property int gaugeSize: 100
    readonly property int gaugeCardHeight: root.gaugeSize + root.cardPad * 2

    // The cover art is a square and everything beside it is shorter, so the
    // square is what sets the height of the top half of the media card.
    readonly property int coverSize: 110

    // 2*16 padding + cover + 12 + the progress line + 12 + the transport row.
    // Stated rather than bound to the children because it is one of the three
    // candidates for the panel height below, and binding it to items that are
    // themselves inside a card sized by that height is a loop.
    readonly property int mediaHeight: root.cardPad * 2 + root.coverSize + 12 + 26 + 12 + 44

    // THE PANEL IS AS TALL AS ITS TALLEST COLUMN, and which column that is
    // depends on the machine: the calendar grows with the type size, the
    // controls column loses its brightness row on a desktop, and the capture
    // column does not move at all. Asking rather than asserting is what stops
    // a larger font from pushing the month out through the bottom edge, which
    // is what a stated height would have done.
    //
    // None of the three terms reads a card's height, so there is no loop:
    // `month` and the two Columns report what their CONTENT needs, and the
    // cards are sized from the answer.
    readonly property int bodyHeight: Math.max(
        root.clockHeight + root.gap + month.implicitHeight + root.cardPad * 2,
        controlsCard.height + root.gap + captureColumn.implicitHeight + root.cardPad * 2,
        root.mediaHeight + root.gap + root.gaugeCardHeight)

    implicitWidth: root.leftWidth + root.midWidth + root.rightWidth + root.gap * 2
    implicitHeight: root.bodyHeight

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
    // happened to be there when the panel was opened and then sits frozen --
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
        // The gate used to be "the Media tab is on screen". There is no tab
        // to ask about now, so it is the panel's own visibility -- and the
        // popout destroys its content when it closes, so this stops on its
        // own the rest of the time rather than polling D-Bus all day.
        running: root.visible && (root.mediaPlayer?.isPlaying ?? false)
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

    // One definition of "the player", so the Timer above and the media card
    // below cannot disagree about which one they are talking to.
    readonly property var mediaPlayer: {
        const players = Mpris.players.values;
        if (players.length === 0)
            return null;
        return players.find(p => p.isPlaying) ?? players[0];
    }

    // ---------------- What replaced the sampling gate ----------------
    //
    // This was `root.tab === "Performance"`, and it was the one binding in
    // the old file that could be wrong without anything looking wrong: get it
    // pointed at the wrong tab and the shell goes on reading /proc and
    // holding nvidia-smi at two-second intervals from a panel nobody is
    // looking at.
    //
    // With one view there is no tab left to name, and the honest replacement
    // is the panel itself. The popout loads this component when it opens and
    // DESTROYS it when it closes -- `Loader { active: root.isOpen }` in
    // components/Popout.qml -- so "this exists" and "somebody is looking at
    // it" are the same statement here. `visible` rather than a literal `true`
    // because it costs nothing and covers the case where the panel is alive
    // but not on screen.
    //
    // What that gate actually buys is smaller than it sounds and worth
    // knowing before anyone tightens it further: SystemStats never stops. It
    // drops to a 5 s GPU poll and a 2 s read of two small files, because the
    // island has to be able to warn about a hot card with this panel shut.
    // `active` only decides whether /proc/stat and /proc/cpuinfo are parsed
    // as well, and whether the GPU loop runs at 2 s instead of 5.
    Binding {
        target: SystemStats
        property: "active"
        value: root.visible
    }

    Row {
        anchors.fill: parent
        spacing: root.gap

        // ================ Left: the time and the month ================
        Column {
            width: root.leftWidth
            height: parent.height
            spacing: root.gap

            Card {
                width: parent.width
                height: root.clockHeight

                Column {
                    anchors.centerIn: parent

                    // Centring the Column centres its LINE BOXES, not its
                    // ink. At 40pt the digits reserve descender space they
                    // never use, so the visible block sat low: measured 15px
                    // of gap above and 2 below. The offset is that
                    // difference, halved, and it is measured rather than
                    // guessed -- same as the icon overflow the old waybar
                    // stylesheet documented.
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

            // The month, reused verbatim from what the clock's popout used to
            // open. Moving it here is the whole reason that popout went away:
            // a calendar is something you go to, not something that springs
            // out when you meant to read the time.
            Card {
                width: parent.width
                height: root.bodyHeight - root.clockHeight - root.gap

                CalendarView {
                    id: month

                    anchors.centerIn: parent
                }
            }
        }

        // ================ Middle: what you reach for ================
        Column {
            width: root.midWidth
            height: parent.height
            spacing: root.gap

            // The settings, in the sense of things you set and stop thinking
            // about.
            //
            // WI-FI AND BLUETOOTH ARE NOT HERE ANY MORE, and their absence is
            // most of why this panel got shorter. Each was a row plus a list
            // that opened underneath it, and between them they owned this
            // card: the rules either side, the "one list open at a time" rule
            // that closed the other when one opened, and the third column of
            // the old layout, which existed only because a list that grows
            // pushes everything under it off the bottom of a card.
            //
            // Both have a full page in the settings window -- see
            // modules/settings/pages/NetworkPage.qml and BluetoothPage.qml --
            // and those pages do more than a dashboard row can: saved
            // networks, forgetting one, pairing, per-device volume. A
            // truncated second copy of a better screen is not worth the
            // panel's tallest card.
            Card {
                id: controlsCard

                width: parent.width
                // FROM ITS CONTENT. This card holds three fixed rows on a
                // desktop and four on a laptop, and it is also the first term
                // of the capture card's height below, so a number picked by
                // hand here would be a number to re-pick every time a row
                // joins or leaves.
                height: controlsColumn.implicitHeight + root.cardPad * 2

                Column {
                    id: controlsColumn

                    anchors.fill: parent
                    anchors.margins: root.cardPad
                    spacing: root.gap

                    // First, because it is the only toggle here and the rule
                    // below separates it from the two sliders. It used to be
                    // first for a different reason -- it was the one row that
                    // never changed height, and below Wi-Fi and Bluetooth it
                    // would have been shoved down the card every time one of
                    // their lists opened. Nothing in this card moves any more;
                    // the order is now just the grouping.
                    DndControl {
                        width: parent.width
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // ABOVE THE VOLUME AND WITH NO RULE BETWEEN THEM. They are
                    // the same kind of control -- a value you set by feel and
                    // stop thinking about -- so they read as one block.
                    //
                    // `visible` and not merely a zero implicit height: on a
                    // desktop this component measures zero, but a Column still
                    // spends its spacing in front of an invisible-but-present
                    // child, so the old layout kept fourteen pixels of gap for
                    // a control that was not there. A Column skips an
                    // invisible child AND the spacing before it.
                    BrightnessControl {
                        id: brightness

                        width: parent.width
                        visible: brightness.present
                    }

                    VolumeControl {
                        width: parent.width
                    }
                }
            }

            // Capture: the two things that produce a file.
            Card {
                width: parent.width
                height: root.bodyHeight - controlsCard.height - root.gap

                Column {
                    id: captureColumn

                    anchors.fill: parent
                    anchors.margins: root.cardPad
                    spacing: root.gap

                    RecordControl {
                        width: parent.width
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // The instant replay, cut down to the act. What it keeps
                    // and what it keeps it from are settings now, and they
                    // live on the settings window's Recording page; the file
                    // itself says which rows went and why.
                    ReplayControl {
                        width: parent.width
                    }
                }
            }
        }

        // ================ Right: what is playing, what it is doing ========
        Column {
            width: root.rightWidth
            height: parent.height
            spacing: root.gap

            // ---------------- Media ----------------
            // Cover on the left as a square, an eyebrow, the title in bold
            // and the artist under it in muted text; a waveform for a progress
            // line with the times at each end, and the transport centred under
            // that.
            //
            // WHAT LEFT WITH THE TAB. The album line went: title and artist
            // answer "what is this", and the album is the third fact nobody
            // came for. The volume slider went too -- it is a row in the card
            // to the left of this one, and having it twice in one view was
            // only ever defensible while the two were on different tabs.
            Card {
                id: mediaCard

                width: parent.width
                height: root.bodyHeight - root.gaugeCardHeight - root.gap

                // Same rule the island uses: prefer what is actually playing,
                // fall back to the first player that exists so a paused track
                // still fills the card.
                readonly property var player: root.mediaPlayer

                // WHEN NOTHING IS PLAYING the card is one line of text and the
                // rest of the view is untouched. That is the whole reason this
                // is a card in a column rather than a section that collapses:
                // a card that shrank would drag the dials up into the gap and
                // the panel would be a different shape depending on whether
                // music happened to be on.
                Text {
                    anchors.centerIn: parent
                    visible: !mediaCard.player
                    text: "Nothing is playing"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.textOnSurfaceVariant
                }

                Column {
                    id: media

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
                        const meta = mediaCard.player?.metadata ?? null;
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
                        const direct = mediaCard.player?.trackArtUrl ?? "";
                        if (direct)
                            return direct;
                        if (!media.youtubeId)
                            return "";
                        const size = media.maxResFailed ? "mqdefault" : "maxresdefault";
                        return "https://i.ytimg.com/vi/" + media.youtubeId + "/" + size + ".jpg";
                    }

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: root.cardPad
                    // Centred rather than pinned to the top: this card takes
                    // whatever height the dials below it did not, so there are
                    // a few pixels of slack and they belong evenly above and
                    // below rather than all at the bottom.
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 12
                    visible: !!mediaCard.player

                    // ---- Cover, and what it is playing ----
                    Item {
                        width: parent.width
                        height: root.coverSize

                        // ClippingRectangle and NOT a Rectangle with clip:
                        // true. A plain Item clips to its BOUNDING BOX, so the
                        // rounded corners were painted on the rectangle and the
                        // artwork carried straight on over them -- a square
                        // photo sitting in a rounded frame, which is what
                        // looked out of place against every other card here.
                        // This one clips to the radius itself.
                        ClippingRectangle {
                            id: cover

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            width: root.coverSize
                            height: root.coverSize
                            radius: Theme.cardRadius - 10
                            color: Theme.surfaceContainerHighest

                            // A BLURRED COPY BEHIND, and the sharp one fitted
                            // in front. This is damage control, not a fix:
                            // what the player publishes is all there is.
                            //
                            // Measured, on the track that prompted this:
                            // Chromium writes the MediaSession thumbnail to a
                            // temp file and that file is 150x83. Drawn into a
                            // square with PreserveAspectCrop it was being
                            // magnified and cropped to its middle third, which
                            // is most of why it looked so rough.
                            //
                            // Fit instead of Crop halves the magnification and
                            // shows the whole thumbnail; the blurred fill is
                            // what stops that leaving two empty bands. Blur is
                            // the one treatment that costs nothing here --
                            // there is no detail left to protect.
                            Image {
                                id: artBackdrop

                                anchors.fill: parent
                                source: art.source
                                visible: false
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 1024
                                asynchronous: true
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
                                source: media.artSource
                                // Ready and not just "source is set": a player
                                // that publishes no art would otherwise leave
                                // the broken-image chequerboard in the card.
                                visible: status === Image.Ready

                                // The retry described on media.artSource. An
                                // Error on the maxres URL means that video has
                                // no maxres thumbnail, so drop to mqdefault;
                                // the flag resets by itself on the next track.
                                onStatusChanged: {
                                    if (status === Image.Error && media.youtubeId && !media.maxResFailed)
                                        media.maxResFailed = true;
                                }
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true

                                // Decoded at up to 1024 rather than at the size
                                // it is drawn. sourceSize never ENLARGES -- Qt
                                // only uses it to scale down -- so a 150px
                                // thumbnail costs nothing here and a real 600px
                                // cover, which is what other players send,
                                // keeps its detail.
                                sourceSize.width: 1024

                                mipmap: true
                                smooth: true
                            }

                            // The stand-in. A blank square reads as a load that
                            // failed; a glyph reads as "this track has no
                            // cover".
                            Text {
                                anchors.centerIn: parent
                                visible: !art.visible
                                text: Icons.music
                                font.family: Theme.fontFamily
                                font.pointSize: 34
                                color: Theme.outline
                            }
                        }

                        Column {
                            anchors.left: cover.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 3

                            // The eyebrow, and it says which of the two states
                            // this is. A label that read "NOW PLAYING" over a
                            // paused track would be the one piece of text on
                            // the card that is not true, and the transport
                            // glyph is the only other thing saying otherwise.
                            Text {
                                width: parent.width
                                text: mediaCard.player?.isPlaying ? "NOW PLAYING" : "PAUSED"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 4
                                font.weight: Font.Bold
                                // Letter-spaced, which is what makes four
                                // small bold words read as a label rather than
                                // as a very short first line of the title.
                                font.letterSpacing: 1.4
                                color: Theme.primary

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }

                            Text {
                                width: parent.width
                                text: mediaCard.player?.trackTitle ?? ""
                                // Two lines and then an ellipsis. A track
                                // title is the one string here worth the
                                // second line -- everything else on the card
                                // is short by nature -- and a fixed two keeps
                                // the block the same height whichever it gets.
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize + 2
                                font.weight: Font.Bold
                                color: Theme.textOnSurface
                            }

                            Text {
                                width: parent.width
                                // Through Track, not raw: it strips the
                                // " - Topic" suffix YouTube's auto-generated
                                // channels carry. Shared with the island so the
                                // same track never reads two different ways in
                                // two places.
                                text: Track.artist(mediaCard.player?.trackArtist ?? "")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1
                                color: Theme.textOnSurfaceVariant
                            }
                        }
                    }

                    // ---- The progress line ----
                    //
                    // A WAVEFORM THAT IS ALSO THE SEEK BAR, which is one row
                    // where the old tab had two: a spectrum above a rule, each
                    // spanning the same width and reading as a short row of
                    // bars floating over a long line.
                    //
                    // THE HEIGHTS ARE REAL AUDIO. They come from the same cava
                    // feed the island's capsule draws, through the same
                    // component -- one instrument at two sizes, not a second
                    // visualiser, and not a decorative squiggle that would be
                    // a picture of audio that is not this audio.
                    //
                    // THE PROGRESS IS THE CLIP, NOT THE BAR COUNT. The obvious
                    // implementation is to light each bar whose turn has come,
                    // and it does not work: cava gives fourteen bands, so the
                    // fill would move once every seventeen seconds on a
                    // four-minute track and sit dead still in between. So the
                    // waveform is drawn TWICE in two colours, and the played
                    // copy sits inside an Item that is `fraction` of the width
                    // with `clip: true`. The edge is vertical and straight, so
                    // clipping costs it nothing -- this is not the curved
                    // boundary CornerWedge.qml had to solve.
                    //
                    // AT REST it is a row of dots on the centre line, which is
                    // Waveform's own resting shape and the same vocabulary the
                    // workspace dots use. cava is not running then: Spectrum
                    // binds the process to MPRIS playback, so a paused track
                    // costs nothing to draw.
                    Item {
                        id: progress

                        width: parent.width
                        height: 26

                        readonly property real fraction: {
                            const len = mediaCard.player?.length ?? 0;
                            if (len <= 0)
                                return 0;
                            return Math.max(0, Math.min(1, root.livePosition / len));
                        }

                        // Only when the player actually reports a position. A
                        // progress line frozen at zero is worse than none, and
                        // the times either side of it would both be lies.
                        readonly property bool seekable: (mediaCard.player?.lengthSupported ?? false)
                            && (mediaCard.player?.length ?? 0) > 0

                        Text {
                            id: elapsed

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            visible: progress.seekable
                            text: root.clockFormat(root.livePosition)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 3
                            color: Theme.textOnSurfaceVariant
                        }

                        Text {
                            id: total

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            visible: progress.seekable
                            text: root.clockFormat(mediaCard.player?.length ?? 0)
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 3
                            color: Theme.textOnSurfaceVariant
                        }

                        Item {
                            id: line

                            // Between the two times, and measured off them
                            // rather than given a share of the width: the
                            // strings are as wide as the track is long, and a
                            // fixed reservation would either crowd "1:04" or
                            // clip "112:30".
                            anchors.left: elapsed.visible ? elapsed.right : parent.left
                            anchors.right: total.visible ? total.left : parent.right
                            anchors.leftMargin: elapsed.visible ? 10 : 0
                            anchors.rightMargin: total.visible ? 10 : 0
                            anchors.verticalCenter: parent.verticalCenter

                            height: parent.height

                            // Solve for the GAP and not for the bar width.
                            // Filling the width by fattening the bars was
                            // tried on the old Media tab and looked wrong:
                            // fourteen bands spread over the full width made
                            // each one a lozenge rather than a spectrum. The
                            // bars keep a fixed slim width and the space
                            // between them absorbs the rest. Floored, so
                            // rounding never pushes the last bar past the edge.
                            readonly property real barGap: Math.max(2,
                                (line.width - Spectrum.bars * 7) / (Spectrum.bars - 1))

                            Waveform {
                                id: ghost

                                anchors.verticalCenter: parent.verticalCenter
                                width: line.width

                                maxHeight: 22
                                barWidth: 7
                                spacing: line.barGap

                                // Flat and muted: this is the part of the track
                                // that has not played. Both ends of Waveform's
                                // gradient are set to the same colour, which is
                                // how a two-colour component draws one colour.
                                barColor: Theme.outlineVariant
                                barColorEnd: Theme.outlineVariant
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                width: line.width * progress.fraction
                                clip: true

                                // Smoothed, or the fill jumps twice a second
                                // instead of creeping. Same 480 the old seek
                                // bar used, which is just under the poll.
                                Behavior on width {
                                    NumberAnimation { duration: 480 }
                                }

                                Waveform {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: line.width

                                    maxHeight: ghost.maxHeight
                                    barWidth: ghost.barWidth
                                    spacing: line.barGap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.topMargin: -4
                                anchors.bottomMargin: -4
                                cursorShape: Qt.PointingHandCursor
                                enabled: mediaCard.player?.canSeek ?? false
                                onClicked: mouse => {
                                    const p = mediaCard.player;
                                    if (!p)
                                        return;
                                    p.position = (mouse.x / line.width) * p.length;
                                }
                            }
                        }
                    }

                    // ---- Transport ----
                    // Round buttons rather than bare glyphs. Three marks
                    // floating on a card have no target to aim at and no hover
                    // to speak of; the play button is also the one control here
                    // anyone reaches for without looking, so it is the only
                    // filled one and the larger of the three. That size
                    // difference IS the hierarchy.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        RoundButton {
                            glyph: Icons.skipPrevious
                            enabled: mediaCard.player?.canGoPrevious ?? false
                            onActivated: mediaCard.player?.previous()
                        }

                        RoundButton {
                            glyph: mediaCard.player?.isPlaying ? Icons.pause : Icons.play
                            filled: true
                            enabled: mediaCard.player?.canTogglePlaying ?? false
                            onActivated: mediaCard.player?.togglePlaying()
                        }

                        RoundButton {
                            glyph: Icons.skipNext
                            enabled: mediaCard.player?.canGoNext ?? false
                            onActivated: mediaCard.player?.next()
                        }
                    }
                }
            }

            // ---------------- What this machine is doing ----------------
            //
            // THREE DIALS AND NOT THREE CARDS OF ROWS. Each subsystem used to
            // carry a headline percentage, a bar under it and three lines of
            // detail -- Used / Free / Swap, Temp / Clock / Threads, Temp /
            // VRAM / Power -- plus the hardware's name at the foot. Nine
            // readings, of which the ones anybody opened the panel for were
            // the three percentages and, when something sounded wrong, the two
            // temperatures.
            //
            // The rest were either the percentage said again in another unit
            // (Free is Used subtracted from Total; Used-of-Total is the
            // percentage with a GiB on it) or facts about the machine that do
            // not change between two openings of a popout: the thread count,
            // the card's name, the model string. Those belong with the
            // identity card, and the identity card is what left.
            //
            // So each subsystem gets a dial: the load large in the middle,
            // and under it in small type the one reading that says whether it
            // is in trouble.
            Card {
                width: parent.width
                height: root.gaugeCardHeight

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Gauge {
                        title: "CPU"
                        percent: SystemStats.cpuPercent
                        reading: `${Math.round(SystemStats.cpuTemp)} °C`
                    }

                    // WHICH READING FOR RAM, since memory has no temperature.
                    //
                    // The line under a dial answers a different question from
                    // the dial itself: the percentage says how hard the thing
                    // is working, the line says whether that is a problem.
                    // Used-of-total fails that test -- it is the same fact in
                    // GiB, and it moves in lockstep with the ring above it.
                    //
                    // Swap does not. A machine at 85% memory with an empty
                    // swap is a machine using its memory, which is what it is
                    // for; the same machine with two gigabytes in swap is
                    // paging, and paging is the thing you actually get up and
                    // do something about. It is also the one memory reading
                    // that is invisible everywhere else in this shell -- the
                    // island's alert watches ramPercent, not swap.
                    //
                    // Short-form GiB, because it has to fit inside the ring
                    // next to "100%": "2.1G swap" is nine characters where
                    // "2.1 / 8.0 GiB" is thirteen. "no swap" when there is no
                    // swap device at all, which is a fact worth stating rather
                    // than a zero to be misread as "none in use".
                    Gauge {
                        title: "RAM"
                        percent: SystemStats.ramPercent
                        reading: SystemStats.swapTotal > 0
                            ? `${SystemStats.swapUsed.toFixed(1)}G swap`
                            : "no swap"
                    }

                    // ONLY ONCE A CARD HAS ANSWERED. On a machine with neither
                    // vendor bound SystemStats spawns nothing and leaves every
                    // figure at its initial zero, and a dial reading 0% and
                    // 0 °C looks like a panel that broke rather than a machine
                    // without the part. No dial says the second.
                    //
                    // `visible` and not a zero width, because a Row skips an
                    // invisible child AND the spacing in front of it: the two
                    // that remain simply close up and stay centred, with no
                    // gap where this one would have been. The panel does not
                    // change size -- the dials are centred in a card whose
                    // width is the column's.
                    //
                    // It only ever turns on, and it turns on early: the GPU
                    // reader runs whether or not this panel is open, because
                    // the island has to be able to warn about a hot card with
                    // the dashboard shut. By the first time anyone opens this
                    // the dial is either already here or was never coming, so
                    // there is nothing appearing to animate.
                    Gauge {
                        title: "GPU"
                        visible: SystemStats.gpuAvailable
                        percent: SystemStats.gpuPercent
                        reading: `${Math.round(SystemStats.gpuTemp)} °C`
                    }
                }
            }
        }
    }

    // MINUTES, and the same choice the bar's clock already made: the two
    // things reading this are a "HH:mm" and a date, so a per-second tick is
    // fifty-nine wake-ups an hour that redraw the same two strings. A
    // SystemClock only fires at the precision it is given, so the precision
    // is the whole of the cost.
    SystemClock {
        id: dashClock

        precision: SystemClock.Minutes
    }

    // A transport button. Filled and larger for the primary action, a ghost
    // circle for the others.
    //
    // Smaller than it was -- 44 where the old Media tab used 58 -- because the
    // tab had a card to itself and this has a third of a column. The ratio
    // between the two sizes is what carries the hierarchy, and that is kept.
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
        implicitWidth: 44
        implicitHeight: 44
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
            width: button.filled ? 42 : 34
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
            font.pointSize: button.filled ? Theme.fontSize + 8 : Theme.fontSize + 5
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

    // One subsystem, drawn as a dial.
    //
    // WHY IT IS A RING OF TICKS AND NOT AN ARC. The obvious implementation is
    // QtQuick.Shapes: one PathAngleArc for the track and a second for the
    // sweep. This shell has already paid for that lesson once. The header of
    // components/CornerWedge.qml records it with the measurement -- a Shape's
    // curved edge averaged 0.94 intermediate pixels per row against 5.25 for a
    // Rectangle's rounded corner, five times worse, and neither 4x
    // multisampling nor a 4x supersampled layer texture fixed it. The house
    // answer is to build curves out of `Rectangle { radius: width / 2 }`,
    // which is the one case Qt's documentation says is antialiased without
    // multisampling.
    //
    // A ring can be built that way -- CornerWedge punches a circle out of a
    // square with an inverted MultiEffect mask, and UserBlock.qml rounds an
    // avatar the same way. A PARTIAL ring cannot: a mask has no way to say
    // "up to this angle", and the sweep is the entire point of a gauge.
    //
    // So it is not a curve at all. It is thirty-seven rounded rectangles
    // standing on a circle, lit up to the value, which is what a meter has
    // looked like since long before there were screens -- and it is exactly
    // what components/LevelMeter.qml already does in a straight line, for the
    // reasons written in its header. Each tick is a plain Rectangle with a
    // radius, so each one is antialiased by the case Qt is good at, and the
    // rotation is applied to the tick's parent rather than to the geometry.
    //
    // 37 ticks over 270 degrees is a step of exactly 7.5, and 270 is the
    // sweep a car's dial uses: it leaves a gap at the bottom, which is what
    // tells you at a glance which end is empty.
    component Gauge: Item {
        id: dial

        property string title: ""
        property real percent: 0
        // The small line under the number: what says whether this is in
        // trouble. A temperature where there is one, and see the note beside
        // the RAM dial for what stands in where there is not.
        property string reading: ""

        readonly property int ticks: 37
        readonly property real sweep: 270

        // Clamped here rather than at each reader: nvidia-smi has been seen to
        // report over 100 for a moment, and a dial with more ticks lit than it
        // has is worse than one that saturates.
        readonly property real fraction: Math.max(0, Math.min(1, dial.percent / 100))

        // The whole dial turns as the load does, so it can be read from across
        // the room without the number -- the same thresholds and the same
        // argument as the bar it replaces. Not LevelMeter's rule, where only
        // the top few ticks go warm: that is right for a signal that is about
        // to clip and wrong for a load, where 95% is not "nearly at the top of
        // the scale", it is "this machine is busy".
        readonly property color lit: dial.percent > 90 ? Theme.critical
            : dial.percent > 66 ? Theme.warning
            : Theme.primary

        implicitWidth: root.gaugeSize
        implicitHeight: root.gaugeSize

        Repeater {
            model: dial.ticks

            // A full-size Item rotated about its own centre, with the tick
            // drawn at the top of it. Rotating the PARENT and not the
            // rectangle is what keeps the tick's own geometry axis-aligned in
            // its item coordinates, which is the form Qt's antialiased
            // rectangle path expects; the transform is then applied to the
            // finished, feathered edge.
            Item {
                id: spoke

                required property int index

                // Through the id and not through `parent`: a Repeater's
                // delegate is reparented on the way in, so a binding that
                // reads parent.ticks evaluates once against nothing.
                readonly property real position: (spoke.index + 1) / dial.ticks
                readonly property bool on: dial.fraction >= spoke.position

                anchors.fill: parent

                // Zero is twelve o'clock, so half the sweep either side of it
                // puts the gap at the bottom.
                rotation: -dial.sweep / 2 + spoke.index * (dial.sweep / (dial.ticks - 1))

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 1

                    width: 3
                    height: 9
                    radius: width / 2
                    antialiasing: true

                    color: spoke.on ? dial.lit : Theme.surfaceContainerHighest

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.title
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 3
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: Theme.textOnSurfaceVariant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${Math.round(dial.percent)}%`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 7
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.reading
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 3
                color: Theme.outline
            }
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
