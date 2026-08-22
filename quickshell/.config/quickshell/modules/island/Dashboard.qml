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
//   middle  the sliders reached for without leaving the panel, and capture
//   right   what is playing, and what this machine is doing
//
// WHERE THE MEDIA CARD COMES FROM. It is a port of end-4/dots-hyprland's
// PlayerControl, taken from that repository's source rather than drawn from a
// screenshot -- it is Quickshell/QML too, so the sizes, insets, radii and the
// arrangement of the controls are theirs by copy. The note above that card
// lists their numbers and the pull request lists what could not be taken
// as-is.
//
// EVERY CARD IS AS TALL AS ITS COLUMN AND CENTRES WHAT IS IN IT. The panel is
// as tall as its tallest column, so two of the three always have height to
// spare; the question is only where it goes. It goes into the cards, evenly
// above and below their content, rather than into gaps between them -- which
// is why the middle column is one card rather than two and why the media card
// does NOT stretch (it is the one card here whose proportions are somebody
// else's, so the slack in that column goes to the dials' card instead).
//
// It fits because six things left, and each of them left for a reason that
// is written where it used to be:
//
//   do not disturb           the panel the bell opens governs the list it
//                            silences; a dashboard about this desktop did not
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
import QtQuick.Layouts
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
    // and the width was theirs. What is left is two sliders and three capture
    // buttons; at 296 each of those buttons is 84 across, which holds
    // "Display" at 9pt with room either side. It is NOT narrowed again now
    // that the mute has gone too: the buttons are what set this number, and
    // they have not moved.
    readonly property int midWidth: 296

    // DERIVED FROM THE DIALS, which is the direction the dependency has to
    // run: three of them side by side with `gaugeSpacing` between and the
    // card's own padding either side, and nothing else in this column has an
    // opinion. It was the literal 348 -- exactly this sum at a dial of 100 --
    // and a literal is what made the dials un-growable: the number that had to
    // change was two screens away from the number somebody wanted to change.
    // The media card above inherits the width rather than asking for one,
    // because a cover, a title and a transport row will use whatever they are
    // given and the dials will not.
    readonly property int rightWidth: root.gaugeSize * 3 + root.gaugeSpacing * 2 + root.cardPad * 2

    readonly property int clockHeight: 104

    // The dial, and the card that holds a row of them.
    //
    // 124, AND IT WAS 100, and the number was CHOSEN BY MEASURING rather than
    // by taste. Three variants were rendered in a nested compositor and the
    // clear span of the ring was measured against the width of the line
    // sitting in it -- "3.6G swap", which is 59px and does not change size,
    // because the type inside is deliberately not grown with the ring. Growing
    // both would hand the reading back exactly the margin being taken away.
    //
    //   dial   panel   clear span   margin per side
    //    100     942       56px        -2   the string OVERLAPS the ring
    //    110     972       71px         6   clears it by under a character
    //    124    1014       89px        15   sits inside it
    //
    // So a hundred was never "tight": at a hundred the line and the ticks are
    // drawn on top of each other, which is what was actually being complained
    // about. And there is no free middle -- at the spacing below, the largest
    // dial that keeps the panel at its old 942 is exactly 100, so the choice
    // was never "free versus expensive", it was 30 pixels versus 72.
    //
    // WHY NOT 110, at less than half the cost. Six pixels is under one
    // character, and the string is not fixed: "12.4G swap" is one character
    // longer and lands back at two pixels a side, while 124 still has eleven.
    // `Theme.fontSize` is a setting, too, and it grows the string without
    // growing the ring. A fix that the next plausible reading undoes is not a
    // fix.
    //
    // WHAT IT COSTS. Width, and width is what the panel had none of: the
    // number above is a sum of these, so the panel is 1014 where it was 942.
    // That lands on the main monitor, which is the only screen with a bar
    // unless the Bar page says otherwise, and there it is 40% of the width.
    // On a 1080-wide portrait monitor asked to carry a bar it would be 94%,
    // and Popout's own clamp is what keeps it on screen. That is the trade.
    // What paid for it in HEIGHT is the media card above, which lost a row.
    readonly property int gaugeSize: 124
    readonly property int gaugeSpacing: 8
    readonly property int gaugeCardHeight: root.gaugeSize + root.cardPad * 2

    // THE MEDIA CARD'S NATURAL SIZE, AND IT IS end-4's. Their
    // Appearance.sizes has mediaControlsWidth 440 and mediaControlsHeight 160,
    // and the card they draw inside that is inset by elevationMargin (10) on
    // every side for a drop shadow. So the card itself is 420 x 140.
    //
    // The width is not asserted here: the right column is a sum of the dials
    // above, and at 124 it comes to 420 -- their width exactly, which is why
    // that number is left alone. The height IS asserted, as the term this
    // column contributes to the panel height below, and the card grows past it
    // when the column has room: their layout is built to stretch, with the art
    // square on Layout.fillHeight and a Layout.fillHeight spacer between the
    // artist and the controls.
    readonly property int mediaHeight: 140

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
        midColumn.implicitHeight + root.cardPad * 2,
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
        //
        // ONE CARD, AND IT WAS TWO. The top one held "the things you set" and
        // the bottom one "the things that produce a file", which was a real
        // distinction and a card each was a reasonable way to draw it -- while
        // the top one had four rows in it. Do not disturb leaving took it to
        // one slider on a desktop, and a card whose entire content is a single
        // row is not a group, it is a row with a border round it. The two are
        // one card now with a rule where the boundary was, so the grouping
        // survives and the fourteen pixels between the cards do not.
        Column {
            width: root.midWidth
            height: parent.height

            Card {
                width: parent.width
                height: parent.height

                // CENTRED AND NOT FILLED, the same treatment the calendar
                // beside it gets: this card is as tall as the panel, the panel
                // is as tall as its tallest column, and whatever is left over
                // belongs evenly above and below rather than all at the bottom.
                Column {
                    id: midColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: root.cardPad
                    anchors.rightMargin: root.cardPad
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: root.gap

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

                    // Where the second card used to start.
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

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
            //
            // A PORT OF end-4/dots-hyprland, and a deliberate one: three
            // attempts at this card from screenshots produced three different
            // cards and none of them was what was asked for, so the design is
            // now taken from source rather than inferred from pixels. The
            // original is Quickshell/QML like ours --
            //
            //   dots/.config/quickshell/ii/modules/ii/mediaControls/PlayerControl.qml
            //
            // -- so the numbers below are THEIRS, copied rather than chosen:
            //
            //   card                 440 x 160, less a 10px elevation margin
            //                        on every side, so 420 x 140 drawn
            //   card radius          19  (their popupRounding: rounding.large
            //                        23, less hyprlandGapsOut 5, plus 1)
            //   content inset        13, with 15 between the art and the text
            //   art square           as tall as the content, radius 8
            //                        (rounding.verysmall)
            //   info column          2 between the lines
            //   skip buttons         24 x 24
            //   play button          44 x 44, radius 17 (rounding.normal)
            //                        while playing and a circle while paused
            //   time and play        5 above the row of controls
            //
            // The layout, top to bottom on the right of the art: the title,
            // the artist, all the slack, then a block whose bottom row is
            // skip-back / progress / skip-forward and whose line above it
            // carries the elapsed-over-total time on the left and the play
            // button on the right. Behind all of it the cover art again,
            // blurred and dimmed, with the cava spectrum drawn across it.
            //
            // WHAT COULD NOT BE TAKEN AS-IS is listed in the pull request; the
            // short version is that they derive the card's whole palette from
            // the cover art with a ColorQuantizer we do not have, they draw
            // their progress as a wavy slider, and they download every cover
            // to disk with curl before showing it. None of those three port.
            //
            // NOT IMPROVED. Where their design looks odd to me it is
            // implemented anyway; the instruction on this card is fidelity.
            Card {
                id: mediaCard

                width: parent.width

                // THEIR HEIGHT, NOT THE COLUMN'S. This card used to take
                // whatever the dials below did not, which is what every other
                // stretching card in this panel does -- and doing it here
                // would defeat the point of the port: their layout puts the
                // art square on Layout.fillHeight, so a card 88 pixels taller
                // than theirs draws an art square 88 pixels bigger and an
                // info column that much narrower. The card is 420 x 140
                // because that is what 440 x 160 less their elevation margin
                // is, and the whole instruction on this card is fidelity.
                //
                // The height the column has spare goes to the dials' card
                // instead; see there.
                height: root.mediaHeight

                // 19, and theirs -- not this shell's cardRadius. The point of
                // the port is that this card looks like that card.
                radius: 19

                // The blurred cover is drawn to the card's own edges, so the
                // card has to cut it to its corners.
                clip: true

                // Same rule the island uses: prefer what is actually playing,
                // fall back to the first player that exists so a paused track
                // still fills the card.
                readonly property var player: root.mediaPlayer

                // THEIR TYPE SCALE, EXPRESSED IN OURS. Theirs is in pixels
                // against a body size of 16 -- large 17, small 15, smaller 12,
                // huge 22 -- and everything in this shell is in points against
                // Theme.fontSize, which is a setting. Kept as ratios rather
                // than as their literals so the card still answers to that
                // setting; a card that ignored it would be the only one.
                readonly property real titleSize: Theme.fontSize * 17 / 16
                readonly property real artistSize: Theme.fontSize * 12 / 16
                readonly property real timeSize: Theme.fontSize * 15 / 16
                readonly property real glyphSize: Theme.fontSize * 22 / 16

                // WHEN NOTHING IS PLAYING the card is one line of text and the
                // rest of the view is untouched. Their build puts a separate
                // "No active player" card in the same place; ours keeps the
                // sentence it already had, because this card is one of two in
                // a column and a card that changed shape would drag the dials
                // up into the gap.
                Text {
                    anchors.centerIn: parent
                    visible: !mediaCard.player
                    text: "Nothing is playing"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.textOnSurfaceVariant
                }

                Item {
                    id: media

                    anchors.fill: parent
                    visible: !!mediaCard.player

                    // ---- Cover art, and the fallback for Firefox players ----
                    // Zen publishes title, album and artist over MPRIS but not
                    // mpris:artUrl for every track, so the card came up blank.
                    // What is worked around here is the symptom, using the one
                    // thing it does publish: xesam:url. For anything YouTube --
                    // which is what music.youtube.com is -- the video id in
                    // that URL maps to a public thumbnail. No key, no API, no
                    // extra process.
                    //
                    // Scope, so nobody expects more than it does: this covers
                    // YouTube URLs only. Any other site still shows the
                    // stand-in. Every non-Firefox player is untouched --
                    // trackArtUrl wins whenever it has a value.
                    readonly property string youtubeId: {
                        const meta = mediaCard.player?.metadata ?? null;
                        const url = meta ? (meta["xesam:url"] ?? "") : "";
                        const m = url.match(/[?&]v=([-\w]{11})/) || url.match(/youtu[.]be\/([-\w]{11})/);
                        return m ? m[1] : "";
                    }

                    // maxresdefault first, mqdefault as the retry. Both are
                    // 16:9 and BAR-FREE, which is the point: hqdefault is
                    // 480x360 and pads a widescreen frame with black bands.
                    // maxresdefault does not exist for every video, hence the
                    // retry rather than picking one.
                    property bool maxResFailed: false
                    onYoutubeIdChanged: media.maxResFailed = false

                    // WHAT THE PLAYER IS OFFERING RIGHT NOW, which is not the
                    // same thing as what the card should be drawing. See
                    // `held` below for why the two had to be separated.
                    readonly property string offered: {
                        const direct = mediaCard.player?.trackArtUrl ?? "";
                        if (direct)
                            return direct;
                        if (!media.youtubeId)
                            return "";
                        const size = media.maxResFailed ? "mqdefault" : "maxresdefault";
                        return "https://i.ytimg.com/vi/" + media.youtubeId + "/" + size + ".jpg";
                    }

                    readonly property real fraction: {
                        const len = mediaCard.player?.length ?? 0;
                        if (len <= 0)
                            return 0;
                        return Math.max(0, Math.min(1, root.livePosition / len));
                    }

                    // ---- The cover that is actually on screen ----
                    //
                    // THE COVER USED TO APPEAR AS A TRACK STARTED AND VANISH A
                    // FRAME LATER, and both halves of why were measured on the
                    // bus rather than guessed at. Watching every
                    // PropertiesChanged on org.mpris.MediaPlayer2.Player while
                    // a track started in Zen:
                    //
                    //   19:38:53.286  Metadata, no mpris:artUrl    (new track)
                    //   19:38:53.730  Metadata WITH mpris:artUrl    -> art
                    //   19:38:53.732  Metadata, key ABSENT again    -> gone
                    //   19:38:54.097  Metadata WITH a DIFFERENT file -> art
                    //   19:38:55.854  Metadata, key ABSENT again    -> gone
                    //
                    // Two milliseconds between having a cover and not. MPRIS
                    // Metadata is one whole map, so a sender that rebuilds it
                    // without the artwork key has effectively retracted the
                    // artwork -- and this one does that repeatedly, on a track
                    // it has already published art for. Bound straight to that,
                    // the Image's source went empty, its status left Ready, and
                    // a card that draws the stand-in whenever the image is not
                    // Ready dropped the cover on the floor.
                    //
                    // AND THE FILE DOES NOT SURVIVE EITHER. The two URLs above
                    // are ~/.zen/firefox-mpris/3304_257.png and _258.png --
                    // numbered temporaries, and that directory holds exactly
                    // one of them: 257 was already unlinked by the time 258
                    // existed. So "remember the URL and put it back later" is
                    // not a fix; the picture has to be held, not the path.
                    //
                    // WHICH IS WHAT THIS DOES. `offer` below loads whatever is
                    // being offered and is never drawn; only when it actually
                    // reaches Ready does its source become `held`, which is
                    // what the two visible Images are bound to. An offer of
                    // nothing is therefore ignored -- `held` does not change,
                    // their source does not change, so Qt neither reloads nor
                    // releases anything and the cover stays put.
                    //
                    // The Images share one decode: same URL and the same
                    // sourceSize, so the rest are the pixmap cache answering.
                    // That sharing is also what makes the deleted file safe --
                    // the visible Images take their reference while the loader
                    // still holds it, so the picture outlives the file it came
                    // from and is never read off disk twice.
                    //
                    // end-4's own card does NOT survive this. It copies every
                    // cover into a cache directory with curl and shows the
                    // copy, and the copy's path is derived from the art URL --
                    // so the same retraction empties the path and blanks their
                    // card too. This is the one piece of behaviour here that
                    // is ours rather than theirs.
                    property string held: ""

                    // WHAT MUST CLEAR IT: the track changing, and nothing else.
                    // Holding a cover across a track change would be worse than
                    // holding none, because it would confidently show the wrong
                    // album -- the failure this is fixing is only ever "the
                    // same track, source retracted".
                    //
                    // Built from what the track IS rather than from
                    // mpris:trackid, which this player publishes as one
                    // constant string for every track it plays. The player's
                    // own bus name is in there so that a card handed a
                    // DIFFERENT player starts from nothing: a sender that
                    // publishes no art at all must reach the stand-in, not
                    // inherit whatever the last one was showing.
                    readonly property string trackKey: [
                        mediaCard.player?.dbusName ?? "",
                        mediaCard.player?.trackTitle ?? "",
                        mediaCard.player?.trackAlbum ?? "",
                        mediaCard.player?.trackArtist ?? ""
                    ].join(" - ")

                    onTrackKeyChanged: media.held = ""

                    // THE ONE THAT LOADS, AND IT IS NEVER DRAWN.
                    //
                    // No geometry: it exists to have a `status`, and an Image
                    // loads whether or not it is visible. The sourceSize
                    // matches the visible ones so that all of them resolve to
                    // the same cache entry and the picture is decoded once.
                    Image {
                        id: offer

                        visible: false
                        source: media.offered
                        asynchronous: true
                        sourceSize.width: 1024

                        onStatusChanged: {
                            if (offer.status === Image.Ready) {
                                // offer.source and not media.offered -- the
                                // resolved url is what the cache is keyed on,
                                // and handing the visible Images anything else
                                // would make them read the file again, which by
                                // then may be gone.
                                media.held = offer.source;
                                return;
                            }

                            // The retry described on media.offered. It lives
                            // HERE, on the loader, because the loader is the
                            // only thing that ever sees a failure now.
                            if (offer.status === Image.Error && media.youtubeId && !media.maxResFailed)
                                media.maxResFailed = true;
                        }
                    }

                    // ---- The card's own background: the cover, blurred ----
                    //
                    // THEIRS, and the thing that makes their card look the way
                    // it does. The art is drawn again at card size, cropped,
                    // blurred, and then covered by the card's own colour at
                    // 0.7 -- their ColorUtils.transparentize(colLayer0, 0.3).
                    //
                    // It is a MultiEffect and not their layer effect because
                    // that is what this shell already uses for blur; the
                    // result is the same treatment.
                    Image {
                        id: artBackdrop

                        anchors.fill: parent
                        source: media.held
                        visible: false
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1024
                        asynchronous: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: artBackdrop
                        visible: media.held !== ""
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 48
                        saturation: 0.2
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: media.held !== ""
                        color: Qt.alpha(Theme.surfaceContainerHigh, 0.7)
                    }

                    // ---- The spectrum, across the whole card ----
                    //
                    // Their WaveVisualizer, which is cava drawn as one
                    // continuous wave over the card. Ours is the same cava
                    // feed through the component this shell already has, so it
                    // is a row of bars rather than a wave -- see the pull
                    // request. Behind the text, as theirs is.
                    Waveform {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        maxHeight: Math.round(mediaCard.height * 0.5)
                        barWidth: 6
                        spacing: Math.max(2, (mediaCard.width - Spectrum.bars * 6) / (Spectrum.bars - 1))
                        opacity: 0.25
                    }

                    // ---- Their RowLayout ----
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 13
                        spacing: 15

                        // Art background: a square as tall as the content,
                        // exactly as theirs -- Layout.fillHeight with the
                        // width following the height.
                        Rectangle {
                            id: artBackground

                            Layout.fillHeight: true
                            implicitWidth: height

                            radius: 8
                            color: Qt.alpha(Theme.surfaceContainerHighest, 0.5)
                            clip: true

                            Image {
                                id: art

                                anchors.fill: parent

                                // `held` and not `offered`: this is the cover
                                // that has already loaded, so it changes only
                                // when there is a new picture to change to.
                                source: media.held

                                // PreserveAspectCrop, theirs. The square is
                                // filled and the overflow is cut, which is why
                                // there is no letterboxing to hide.
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                sourceSize.width: 1024
                                asynchronous: true
                                mipmap: true
                                smooth: true
                            }

                            // The stand-in. A blank square reads as a load that
                            // failed; a glyph reads as "this track has no
                            // cover". Not in their build, which leaves the
                            // square empty.
                            Text {
                                anchors.centerIn: parent
                                visible: !art.visible
                                text: Icons.music
                                font.family: Theme.fontFamily
                                font.pointSize: Math.max(12, Math.round(artBackground.height * 0.28))
                                color: Theme.outline
                            }
                        }

                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            spacing: 2

                            Text {
                                Layout.fillWidth: true

                                text: mediaCard.player?.trackTitle ?? "Untitled"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: mediaCard.titleSize
                                font.weight: Font.Bold
                                color: Theme.textOnSurface
                            }

                            Text {
                                Layout.fillWidth: true

                                // Through Track, not raw: it strips the
                                // " - Topic" suffix YouTube's auto-generated
                                // channels carry. Shared with the island so the
                                // same track never reads two different ways in
                                // two places. Their StringUtils does the same
                                // job with a different list of suffixes.
                                text: Track.artist(mediaCard.player?.trackArtist ?? "")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: mediaCard.artistSize
                                color: Theme.outline
                            }

                            // Their spacer: everything above sits at the top,
                            // everything below at the bottom.
                            Item {
                                Layout.fillHeight: true
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                                Text {
                                    id: trackTime

                                    anchors.bottom: sliderRow.top
                                    anchors.bottomMargin: 5
                                    anchors.left: parent.left

                                    text: root.clockFormat(root.livePosition) + " / " + root.clockFormat(mediaCard.player?.length ?? 0)
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pointSize: mediaCard.timeSize
                                    color: Theme.outline
                                }

                                RowLayout {
                                    id: sliderRow

                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right

                                    TrackChangeButton {
                                        glyph: Icons.skipPrevious
                                        enabled: mediaCard.player?.canGoPrevious ?? false
                                        onActivated: mediaCard.player?.previous()
                                    }

                                    Item {
                                        id: progressBarContainer

                                        Layout.fillWidth: true
                                        implicitHeight: 4

                                        // THEIRS IS A WAVY SLIDER, and this is
                                        // a plain bar -- see the pull request.
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter

                                            height: 4
                                            radius: height / 2
                                            color: Theme.secondaryContainer

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom

                                                width: parent.width * media.fraction
                                                radius: parent.radius
                                                color: Theme.primary

                                                // Smoothed, or the fill jumps
                                                // twice a second instead of
                                                // creeping. Same 480 the old
                                                // seek bar used, just under
                                                // the poll.
                                                Behavior on width {
                                                    NumberAnimation { duration: 480 }
                                                }
                                            }
                                        }

                                        // The target is taller than the bar it
                                        // drives -- four pixels is the right
                                        // thickness to look at and an unfair
                                        // thing to ask anyone to hit.
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.topMargin: -10
                                            anchors.bottomMargin: -10

                                            cursorShape: Qt.PointingHandCursor
                                            enabled: mediaCard.player?.canSeek ?? false

                                            onClicked: mouse => {
                                                const p = mediaCard.player;
                                                if (!p || !p.length)
                                                    return;
                                                p.position = (mouse.x / progressBarContainer.width) * p.length;
                                            }
                                        }
                                    }

                                    TrackChangeButton {
                                        glyph: Icons.skipNext
                                        enabled: mediaCard.player?.canGoNext ?? false
                                        onActivated: mediaCard.player?.next()
                                    }
                                }

                                // 44 across, on the same line as the time and
                                // hard against the right edge; a rounded
                                // SQUARE while it is playing and a circle when
                                // it is not, which is theirs and is the one
                                // detail that makes the button read as a state
                                // rather than as a button.
                                Rectangle {
                                    id: playPause

                                    anchors.right: parent.right
                                    anchors.bottom: sliderRow.top
                                    anchors.bottomMargin: 5

                                    readonly property bool playing: mediaCard.player?.isPlaying ?? false

                                    width: 44
                                    height: 44
                                    radius: playPause.playing ? 17 : width / 2

                                    color: playPause.playing
                                        ? (playMouse.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary)
                                        : (playMouse.containsMouse
                                            ? Qt.tint(Theme.secondaryContainer, Qt.alpha(Theme.textOnSecondaryContainer, 0.1))
                                            : Theme.secondaryContainer)

                                    opacity: (mediaCard.player?.canTogglePlaying ?? false) ? 1 : 0.3

                                    Behavior on radius {
                                        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animDuration }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: playPause.playing ? Icons.pause : Icons.play
                                        font.family: Theme.fontFamily
                                        font.pointSize: mediaCard.glyphSize
                                        color: playPause.playing ? Theme.textOnPrimary : Theme.textOnSecondaryContainer
                                    }

                                    MouseArea {
                                        id: playMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: mediaCard.player?.canTogglePlaying ?? false
                                        onClicked: mediaCard.player?.togglePlaying()
                                    }
                                }
                            }
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

                // WHATEVER THE MEDIA CARD ABOVE DID NOT TAKE, which is the
                // other half of the note there. `gaugeCardHeight` is still
                // this card's NATURAL height and is still what the column
                // contributes to the panel height; when another column is
                // taller, the difference lands here rather than stretching the
                // ported card out of proportion. The dials are centred in it,
                // exactly as the calendar and the controls are centred in
                // theirs.
                height: root.bodyHeight - root.mediaHeight - root.gap

                Row {
                    anchors.centerIn: parent
                    spacing: root.gaugeSpacing

                    Gauge {
                        title: "CPU"
                        percent: SystemStats.cpuPercent
                        reading: `${Math.round(SystemStats.cpuTemp)} °C`

                        // Coloured by the temperature under it, not by the
                        // percentage in it. See the note on `level`.
                        level: SystemStats.cpuTemp
                        warmAt: SystemStats.cpuCoolAt
                        hotAt: SystemStats.cpuHotAt
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

                        // The one dial still coloured by its own percentage,
                        // because memory has no temperature to be coloured by.
                        // It takes the island's memory thresholds all the same,
                        // so "amber" means the same thing on all three rings.
                        //
                        // ITS AMBER STEP MOVED FROM 66% TO 85% ON PURPOSE, and
                        // that was asked about and kept rather than slipping
                        // through. 66 was this component's own number from
                        // when every ring meant "how busy"; 85 is
                        // SystemStats.ramCoolAt, which is where the island
                        // stops warning about memory. Do not put 66 back as a
                        // tidy-up: it would leave this ring calling something
                        // a problem at a point where nothing else in the shell
                        // does, which is the second opinion the note on
                        // `level` exists to prevent.
                        level: SystemStats.ramPercent
                        warmAt: SystemStats.ramCoolAt
                        hotAt: SystemStats.ramHotAt
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

                        // Its own numbers and not the CPU's, and the gap
                        // between them is the hardware's rather than a taste:
                        // coretemp puts this chip's throttle at 100 °C, and
                        // Blackwell starts losing clocks around 85. Both are
                        // read out in SystemStats.qml with the measurement
                        // each came from.
                        level: SystemStats.gpuTemp
                        warmAt: SystemStats.gpuCoolAt
                        hotAt: SystemStats.gpuHotAt
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

    // A skip button, and it is end-4's TrackChangeButton.
    //
    // 24 x 24 with a glyph drawn at their `huge` size, which is 22 against a
    // body of 16 -- so the mark very nearly fills the target and slightly
    // overhangs it. That is theirs, and it is why these read as glyphs with a
    // hit area rather than as buttons.
    //
    // No fill at rest; the secondary container on hover, which is the only
    // part of their RippleButton that ports (we have no ripple, and adding one
    // for two buttons would be a component nothing else in this shell uses).
    component TrackChangeButton: Rectangle {
        id: button

        property string glyph: ""

        signal activated

        implicitWidth: 24
        implicitHeight: 24
        radius: width / 2

        color: buttonMouse.containsMouse
            ? Qt.tint(Theme.secondaryContainer, Qt.alpha(Theme.textOnSecondaryContainer, 0.1))
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // Dimmed rather than hidden when the player cannot do it: a control
        // that disappears moves the two beside it.
        opacity: button.enabled ? 1 : 0.3

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize * 22 / 16
            color: Theme.textOnSecondaryContainer

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

        // WHAT THE COLOUR FOLLOWS, and it is not the sweep.
        //
        // The ring used to turn amber and then red on its own percentage, at
        // 66 and 90, and the argument for it was that a dial should be
        // readable from across the room without the number. The argument
        // survives; what did not is that the percentage is the wrong VALUE for
        // two of the three. A CPU pinned at 100% is a CPU doing its job -- it
        // is what compiling looks like, and a red ring every time is a red
        // ring that stops being read. A CPU at 92 °C is a CPU in trouble
        // whatever the load says, and the temperature was already printed
        // under the ring, so the dial was showing the wrong one of the two
        // numbers it had.
        //
        // THE THRESHOLDS ARE THE ISLAND'S, not new ones. SystemStats already
        // decides when to interrupt with a heat warning, and a dashboard that
        // called something hot at a different number would give this shell two
        // opinions about the same word. Each dial is handed that subsystem's
        // own pair: `hotAt` is the point the island starts shouting at, and
        // `warmAt` is the point it will stop shouting at once it has started
        // -- which is exactly the band where the thing is still warmer than it
        // should be, and so is exactly the amber step this needed and had
        // nowhere to get. Nothing here is invented; see the block of
        // measurements at "Thermal alert" in SystemStats.qml.
        //
        // The defaults are the sweep itself against the memory thresholds, so
        // a dial that says nothing about any of this still colours the way a
        // dial should rather than coming up red on a zero.
        property real level: dial.percent
        property int warmAt: 85
        property int hotAt: 90

        readonly property int ticks: 37
        readonly property real sweep: 270

        // Clamped here rather than at each reader: nvidia-smi has been seen to
        // report over 100 for a moment, and a dial with more ticks lit than it
        // has is worse than one that saturates.
        readonly property real fraction: Math.max(0, Math.min(1, dial.percent / 100))

        // The WHOLE dial changes colour, not the top few ticks. LevelMeter
        // lights only its last ones because a signal that is about to clip is
        // in trouble at the top of its own scale; this is not that. The ring
        // is a load and the colour is a verdict about something else entirely,
        // so lighting part of the sweep in it would say that the trouble
        // starts partway along the load, which is the thing that is not true.
        readonly property color lit: dial.level >= dial.hotAt ? Theme.critical
            : dial.level >= dial.warmAt ? Theme.warning
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
