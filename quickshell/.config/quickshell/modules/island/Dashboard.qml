// The dashboard: what the island opens into.
//
// It is the content of the bar's shared popout, not a window of its own, so
// it inherits the welding to the bar, the outside-click dismissal and the
// blur for free. See components/Popout.qml.
//
// ---------------------------------------------------------------------------
// THE WALL
// ---------------------------------------------------------------------------
//
// THE COVER ART IS THE GROUND. Not a card in a grid of cards: the picture of
// whatever is playing fills the whole panel, blurred until it is a field of
// colour rather than a photograph, darkened by a scrim, and everything else
// floats on it as frosted glass. The panel's colour and mood change with the
// music. With nothing playing it falls back to the WALLPAPER, which is where
// the shell's palette comes from anyway, so the panel is never a grey box.
//
// This replaces the three-column grid of opaque cards that stood here. What
// left with it, and why, is written where each thing now is:
//
//   the media card       there is no card. The art is the ground; a small
//                        sharp copy of it, the title, the artist, the time,
//                        the seek wave and the transport sit on top of it
//   the three dials      a label, a big percentage and a short bar, three
//                        across one strip. See `Reading`
//   the volume slider    a band of its own, with the glyph that mutes it and
//                        the number always on show
//   the brightness       the second row of that band, on a machine that has
//                        a backlight
//   the capture buttons  labelled tiles in the actions strip rather than 56px
//                        glyph-over-label squares
//
// NOTHING WAS DROPPED. Time, date, month, what is playing, the three machine
// readings, volume and its mute, the three capture targets and the instant
// replay are all still here, and so is the brightness on a laptop and the
// connector name the replay is pointed at.
//
// ---------------------------------------------------------------------------
// AND THEN IT WAS BUILT, LOOKED AT, AND CHANGED AGAIN
// ---------------------------------------------------------------------------
//
// Three things were wrong with the first build and all three were the same
// mistake in different places: a drawing had been trusted past the point
// where it stops being able to answer.
//
// IT WAS TOO SPREAD OUT, measurably -- about a fifth of the panel was ground
// with nothing on it. The geometry note below carries the two places it went
// and what closed them.
//
// THE VOLUME WAS A SIX-PIXEL RULE ALONG THE BOTTOM EDGE. "A control that
// needs one dimension gets one dimension" is a good line and it cost the mute
// its button, put the number behind a hover, and left the whole thing on the
// edge of the panel where a pointer travels rather than aims. When a control
// needs a paragraph to explain how to reach it, the control is wrong and not
// the reader. See VolumeControl.qml.
//
// AND NOTHING LOOKED LIKE A BUTTON. This is the one worth remembering,
// because this panel can fall into it again: on an ordinary card a button can
// be a bare label, because the card's own edge says where the surface is. The
// ground here is a PHOTOGRAPH and has no edges at all, so a label whose
// background only appears on hover is indistinguishable from a caption until
// the pointer is already on it. Every control now carries a fill AT REST --
// the capture tiles, the replay's save, the skip buttons, the month steppers,
// the mute. The other half of the rule does the real work: nothing that
// cannot be pressed gets a surface, so the readings, the clock, the date and
// the elapsed time stay bare and the difference is what reads.
//
// ---------------------------------------------------------------------------
// THE TWO THINGS THIS DESIGN CAN GET WRONG
// ---------------------------------------------------------------------------
//
// LEGIBILITY IS CONDITIONAL ON SOMEBODY ELSE'S ARTWORK. White type over a
// pale cover is the failure mode, and a fixed scrim cannot cover both a black
// album sleeve and a white one. So the scrim is MEASURED: ColorQuantizer
// reduces the ground to a single colour, that colour's luminance picks the
// scrim's opacity, and the range is wide enough that a white cover ends up as
// dark behind the type as a black one does. See `scrimOpacity`.
//
// WHERE THAT CANNOT WORK, said plainly: ColorQuantizer reads LOCAL FILES ONLY
// -- `QImage(this->source.toLocalFile())` in Quickshell's
// src/core/colorquantizer.cpp, with no network code anywhere near it. Zen's
// covers are file:// paths under ~/.zen/firefox-mpris/ and quantize fine; the
// YouTube thumbnail fallback is an https URL and does not. With no
// measurement the scrim goes to a fixed value near the dark end of the range,
// because the safe guess about an unknown picture is that it is bright.
//
// THE SECOND HALF OF THE ANSWER IS THE BLUR ITSELF. The ground is decoded at
// 96 pixels wide and then blurred, so it is a field of colour with no detail
// left in it -- which means the ONE colour the quantizer measured really does
// describe what is behind every label, rather than describing an average with
// a bright patch hiding in it.
//
// COST, AND IT IS THE HONEST NUMBER RATHER THAN A REASSURING ONE. A blur over
// the whole panel is the expensive part of this design and it is not free.
// What it replaces is the media card's own blurred backdrop, which did the
// same thing over 420 x 140; this does it over roughly 1014 x 470, about
// seven times the area. Three things hold it down: the source image is
// decoded at 96px rather than 1024, so the texture being blurred is tiny; the
// glass panels are NOT separately blurred -- a 10% white film over a ground
// that is already a blur reads as frosted without a second pass; and the
// crossfade between two covers happens INSIDE the one source item rather than
// between two finished blurs, so a track change costs a second small decode
// and not a second blur. I did not measure the frame cost; there is no way to
// do that here without putting a window on screen, which this work was told
// not to do.
//
// NOT COMPOSITOR BLUR. This is a picture we draw ourselves, inside our own
// surface. ext-background-effect-v1 and per-surface blur regions under niri
// are a different thing, they were tried and reverted, and nothing here goes
// near them.
//
// ---------------------------------------------------------------------------
// WHAT DID NOT CHANGE
// ---------------------------------------------------------------------------
//
// The panel is still a fixed size and still snaps rather than animating: this
// Item's implicit size drives the popout's, which drives the LAYER SURFACE,
// and animating that asks the compositor to reconfigure and re-centre the
// surface on every frame. Sixty resizes in a fifth of a second is what tore.
//
// AND IT IS NOT FULL-BLEED TO THE POPOUT'S EDGE, on purpose. components/
// Popout.qml insets its content by Theme.groupPadding and draws two fillets
// that weld the panel to the bar in `panel.color`. A ground that ran to the
// window's edge would meet two fillets in the wallpaper's surface colour at
// the one join that is meant to be invisible. So the wall is a sheet mounted
// in the popout with the shell's own glass showing as a border: the weld
// keeps the bar's colour, and the photograph keeps its edges.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/bar"

Item {
    id: root

    // ---------------- Geometry ----------------
    //
    // COMPACTED, AND THE FIX WAS NOT "MAKE EVERYTHING SMALLER". The panel was
    // 1014 x 470 and about a fifth of it was ground with nothing on it, in
    // two places:
    //
    //   158 px between the columns   the leftover of a width that had been
    //                               fixed at 1014 since the dials set it. It
    //                               was never chosen; it was what was left
    //   105 px under the media      the left column had three bands adding
    //                               up to 323 and the right column had 410,
    //                               so the left one simply ran out of things
    //                               to hold before the calendar ran out of
    //                               height
    //
    // The second is the real one, and the volume is what fixes it: moved off
    // the bottom edge into a band of its own, the left column has four bands
    // and comes to 338 against the right column's 341. Three pixels apart
    // instead of eighty-seven, and there is no hole left to look at.
    //
    // Everything else here is trimmed rather than redesigned -- margins,
    // gaps, padding, the art square, the calendar cell and the type scale --
    // and together with the two above the panel comes out near 792 x 381,
    // about 36% less area.

    // From the panel's edge to anything in it. The popout adds
    // Theme.groupPadding of its own outside this.
    readonly property int edge: 20

    // Between two glass panels.
    readonly property int gap: 12

    // Inside one.
    readonly property int glassPad: 14

    readonly property int glassRadius: 14

    // DERIVED FROM THE ACTIONS ROW, which is the direction the dependency has
    // to run. That row is the widest fixed thing in this column -- three
    // capture targets, a rule, the replay's button, the connector it is
    // pointed at and its switch, all on one line -- and every string in it
    // grows with Theme.fontSize. Stated as a literal, a larger font would
    // elide "Display" down to "Disp..." instead of widening the panel, which
    // is the failure the old literal 522 was one setting away from.
    //
    // The floor is what the media block needs: the art square, the seek wave
    // and the transport. Nothing above the actions row asks for more than
    // this, so nothing above it appears in the sum.
    //
    // DERIVING A WIDTH FROM LIVE CONTENT IS ONLY SAFE WHILE THAT CONTENT
    // RESERVES ITS OWN WIDEST CASE, and this is the trap to re-read before
    // adding anything to that row. Toggling the instant replay used to resize
    // the whole dashboard: the save button's label runs "Save last 30s",
    // "Replay elsewhere" or "Replay off" depending on the state, the button
    // reported whichever was showing, and the panel's edge followed it.
    // Every label in that row measures its widest form now -- see the
    // TextMetrics at the top of ReplayControl.qml and the Math.max in
    // RecordControl.qml. A new control with a label that changes with state
    // has to do the same or it will move the panel again.
    readonly property int leftWidth: Math.max(460, actionsRow.implicitWidth + root.glassPad * 2)

    // The right column is the month, which is a fixed seven columns and
    // cannot be negotiated with.
    readonly property int rightWidth: month.implicitWidth + root.glassPad * 2

    // THE GROUND SHOWING THROUGH, and now a decision rather than a remainder.
    // The picture is the point of this design and a panel packed edge to edge
    // with glass would only have a tinted border -- but 158 pixels of it was
    // not a decision, it was the width left over once the two columns had
    // taken theirs. Twelve is a gutter; the ground shows through above and
    // below the columns instead, where it is not a channel down the middle.
    readonly property int columnGap: 14

    implicitWidth: root.edge * 2 + root.leftWidth + root.columnGap + root.rightWidth

    // The FLOOR under the media block, and the size of the art square when
    // the column beside it needs no more than this. It is not the art's own
    // size any more -- see artFrame, which fills the block's height the way
    // end-4's does, so that the picture and the text beside it end level and
    // there is no strip of empty ground under one of them.
    readonly property int artSize: 104

    // AND THE BLOCK IS AS TALL AS THE TALLER OF THE TWO THINGS IN IT, which
    // it was not, and that is what let the seek wave draw straight through
    // the elapsed time.
    //
    // `height: root.artSize` said the block was as tall as the picture. The
    // column beside the picture -- title, artist, times, then the wave and
    // the transport -- was never in that sum at all, so when the compaction
    // took the art square from 132 to 104 the column simply carried on being
    // as tall as it needed and the two ends of it met in the middle. The
    // times ran to about 76 pixels and the transport started at 60.
    //
    // Asking rather than asserting is the same discipline every other height
    // in this panel already follows; the media block was the one that did
    // not. There is no loop: `info` reports what its CONTENT needs and the
    // block is sized from the answer.
    readonly property int mediaHeight: Math.max(root.artSize, info.implicitHeight)

    // ASKED, NOT ASSERTED, exactly as the old grid did it: the calendar grows
    // with the type size and the readings row grows with it too, so a stated
    // height is a height that pushes something out through the bottom edge on
    // the first person who changes Theme.fontSize.
    readonly property int actionsHeight: actionsRow.implicitHeight + root.glassPad * 2
    readonly property int readingsHeight: readingsRow.implicitHeight + root.glassPad * 2
    readonly property int slidersHeight: sliders.implicitHeight + root.glassPad * 2
    readonly property int clockHeight: clockLines.implicitHeight + root.glassPad * 2
    readonly property int calendarHeight: month.implicitHeight + root.glassPad * 2

    readonly property int leftHeight: root.mediaHeight + root.gap + root.readingsHeight
        + root.gap + root.slidersHeight + root.gap + root.actionsHeight
    readonly property int rightHeight: root.clockHeight + root.gap + root.calendarHeight

    // THE TWO COLUMNS NOW AGREE, which is the whole compaction. The right one
    // is the month and cannot be argued with -- it is a steppable grid at body
    // size, and the only thing that moved there is the cell, from 34 x 30 to
    // 30 x 26, which took 39 pixels off without touching the type inside it.
    // The left one gained the volume as a fourth band and reaches 338 against
    // that 341. Whichever wins, the difference now lands in the ground as a
    // few pixels rather than as the 105-pixel hole that was there.
    readonly property int bodyHeight: Math.max(root.leftHeight, root.rightHeight) + root.edge * 2

    implicitHeight: root.bodyHeight

    // ---------------- Ink ----------------
    //
    // DELIBERATELY NOT Theme ROLES. Every other surface in this shell is
    // painted from matugen's palette, which is derived from the wallpaper --
    // and on this panel the wallpaper is not what is behind the type. The
    // ground can be any album cover ever made, so the type is white and the
    // panels are white films, which is the one pair that works over all of
    // them. The colour in this panel comes from the photograph.
    readonly property color ink: "#ffffff"

    // The one inverted surface: the play button, which is a white disc with a
    // dark mark on it. Fixed rather than derived for the same reason the ink
    // is -- it has to read on white whatever the album is.
    readonly property color inkInverse: "#12161f"

    // ---------------- Type ----------------
    //
    // THE DRAWING'S RATIOS, EXPRESSED AGAINST Theme.fontSize. The drawing was
    // made at a 17px body with a 56px clock; these are its sizes divided
    // through by that, so the whole panel still answers the font setting
    // rather than freezing at whatever size it happened to be drawn at. The
    // clock lands within a point of the 40 it has always been.
    //
    // The two smallest are rounded UP from the drawing: its 9.5px labels come
    // out at 6.7pt against an 11pt body, which is smaller than anything else
    // in this shell and smaller than I am willing to ask anyone to read.
    //
    // THE THREE LARGEST CAME DOWN in the compaction -- the clock from 3.6 to
    // 3.0, the title from 2.1 to 1.6, the readings from 1.55 to 1.35. That is
    // the one part of "make it smaller" that is genuinely about size rather
    // than about spacing, and it is limited to the three that were set large
    // to fill a panel that no longer needs filling. Nothing at or below body
    // size moved: the artist, the elapsed time, the labels and every day in
    // the calendar are exactly as legible as they were.
    readonly property real clockSize: Theme.fontSize * 3.0
    readonly property real titleSize: Theme.fontSize * 1.6
    readonly property real artistSize: Theme.fontSize * 0.9
    readonly property real timeSize: Theme.fontSize * 0.8
    readonly property real labelSize: Theme.fontSize * 0.78
    readonly property real readingSize: Theme.fontSize * 1.35
    readonly property real actionSize: Theme.fontSize * 0.85

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
    // WHAT `MprisPlayer.position` ACTUALLY IS, because the comment that used
    // to be here had it wrong and the wrong model produced a wrong fix.
    // Quickshell computes it on every read, in
    // src/services/mpris/player.cpp:
    //
    //   positionMs() = lastValueTheSenderPublished + wallClockSinceItArrived
    //
    // So it is an EXTRAPOLATION from an anchor, not a value fetched from the
    // bus. Nothing in QML can ask for the anchor to be refreshed: Quickshell
    // re-requests it by itself on a track change and on a playback-state
    // change, and at no other time.
    //
    // Reading it on a timer is still necessary and is all this does. The
    // property's notify signal only fires when the anchor moves, so a plain
    // binding would sit still while the extrapolation ran on underneath it.
    // What is NOT here any more is the `positionChanged()` poke that used to
    // sit above this line in the belief that it forced a re-read off D-Bus:
    // the only thing connected to that signal inside Quickshell is
    // `onExportedPositionChanged`, which emits `lengthChanged` when the track
    // has no length -- so the poke did nothing for the position and made a
    // fabricated length look alive. See `hasLength`.
    //
    // WHAT THIS COSTS US, stated because it is not fixable from here: a
    // player that publishes Position once and never again -- Zen, on a plain
    // youtube.com video, publishes a constant 0 -- gives an anchor that is
    // only re-taken when the track or the playback state changes. Between
    // those events the elapsed time shown is "time since that event", which
    // is right for a track played from its start and wrong for one joined in
    // the middle.
    //
    // Twice a second: a seek bar that steps once a second visibly ticks.
    property real livePosition: 0

    Timer {
        interval: 500
        repeat: true
        // The popout destroys its content when it closes, so this stops on
        // its own the rest of the time rather than polling all day.
        running: root.visible && (root.player?.isPlaying ?? false)
        triggeredOnStart: true

        onTriggered: {
            const p = root.player;
            root.livePosition = p ? (p.position ?? 0) : 0;
        }
    }

    // One definition of "the player", and it is the SHELL's rather than this
    // file's. The rule moved to Track.qml because there were three copies of
    // it and none of them knew that playerctld puts a mirror of the real
    // player on the bus under a name of its own; see the long note there.
    readonly property var player: Track.active

    // ---- IS THERE A LENGTH AT ALL, AND THE BUG THAT ASKING REPLACES ----
    //
    // The card showed "4:18 / 5:17" for a track YouTube Music was showing as
    // "0:22 / 4:06". Both numbers wrong, and the total was not a total.
    //
    // `MprisPlayer.length` DOES NOT RETURN A LENGTH WHEN THE PLAYER DID NOT
    // PUBLISH ONE. From src/services/mpris/player.cpp:
    //
    //   qreal MprisPlayer::length() const {
    //       if (!this->bLengthSupported) {
    //           return this->position();   // unsupported
    //       ...
    //
    // -- so with `mpris:length` absent from the metadata it hands back the
    // current POSITION, which is itself extrapolated from wall clock. The
    // card was drawing a clock over a second clock and calling one of them
    // the duration.
    //
    // AND THE PLAYER HERE REALLY DOES OMIT IT. Read off the live bus while
    // Zen played a youtube.com video: the metadata carried mpris:trackid,
    // xesam:title, xesam:album, xesam:artist and xesam:url and no
    // mpris:length at all, and Position read 0 three times over four seconds.
    //
    // Quickshell publishes `lengthSupported` for exactly this, so the panel
    // asks instead of assuming. With no length there is no total to print and
    // no fraction to seek to, and both say so rather than inventing one.
    readonly property bool hasLength: root.player?.lengthSupported ?? false

    // Clamped at the total, because the position is extrapolated and can
    // otherwise run past a length the player did publish -- and a panel
    // reading "4:20 / 4:05" is a panel nobody believes again.
    readonly property real elapsed: root.hasLength
        ? Math.min(root.livePosition, root.player?.length ?? 0)
        : root.livePosition

    readonly property string timeText: root.hasLength
        ? root.clockFormat(root.elapsed) + " / " + root.clockFormat(root.player?.length ?? 0)
        : root.clockFormat(root.elapsed)

    readonly property real fraction: {
        if (!root.hasLength)
            return 0;
        const len = root.player?.length ?? 0;
        if (len <= 0)
            return 0;
        return Math.max(0, Math.min(1, root.elapsed / len));
    }

    // ---------------- The cover, and what is drawn from it ----------------
    //
    // ALL OF THIS USED TO LIVE INSIDE THE MEDIA CARD and had to come up here,
    // because two different things now read the picture: the small sharp
    // square at the top left and the ground behind the entire panel.
    //
    // ---- Zen's YouTube fallback ----
    // Zen publishes title, album and artist over MPRIS but not mpris:artUrl
    // for every track, so the panel came up blank. What is worked around here
    // is the symptom, using the one thing it does publish: xesam:url. For
    // anything YouTube -- which is what music.youtube.com is -- the video id
    // in that URL maps to a public thumbnail. No key, no API, no extra
    // process. Any other site still shows the stand-in, and every non-Firefox
    // player is untouched because the remembered art wins whenever it exists.
    // The regular expression moved to Track when the island started needing
    // the same answer; the retry below is still this file's, because it needs
    // an Image with a status to catch a failure and the island has none.
    readonly property string youtubeId: Track.videoId(root.player)

    // maxresdefault first, mqdefault as the retry. Both are 16:9 and BAR-FREE,
    // which is the point: hqdefault is 480x360 and pads a widescreen frame
    // with black bands.
    property bool maxResFailed: false
    onYoutubeIdChanged: root.maxResFailed = false

    // THE COVER THIS PLAYER IS KNOWN TO HAVE, which is not the same thing as
    // the one it is admitting to right now. Track remembers the last art URL
    // each player published and drops it only on a genuine track change, so
    // this survives the retraction described there -- and, because it lives
    // in a singleton rather than in this panel, it survives the panel being
    // closed and rebuilt too. The ground depends on that: without the memory
    // the whole background would go grey two milliseconds after a track
    // started.
    readonly property string remembered: Track.covers[root.player?.dbusName ?? ""] ?? ""

    readonly property string offered: {
        if (root.remembered)
            return root.remembered;
        if (!root.youtubeId)
            return "";
        const size = root.maxResFailed ? "mqdefault" : "maxresdefault";
        return "https://i.ytimg.com/vi/" + root.youtubeId + "/" + size + ".jpg";
    }

    // ---- The cover that is actually on screen ----
    //
    // `offer` below loads whatever is worth loading and is never drawn; only
    // when it reaches Ready does its source become `held`, which is what the
    // visible images are bound to. So the picture is never replaced by a load
    // in progress and never by a load that failed -- if Zen has already
    // unlinked the file it named, the old one simply stays up. The images
    // share a decode where their sourceSize agrees; the ground asks for a far
    // smaller one on purpose and is a second decode of the same file.
    property string held: ""

    // WHAT CLEARS IT: there being nothing left to show. Keyed on `offered`
    // and not on `remembered`, because a player that never publishes artwork
    // leaves `remembered` permanently empty -- and a property that is always
    // "" never emits a change, so a track change on such a player would clear
    // nothing and the previous track's thumbnail would stay up.
    onOfferedChanged: {
        if (root.offered === "")
            root.held = "";
    }

    Image {
        id: offer

        visible: false
        source: root.offered
        asynchronous: true
        sourceSize.width: 1024

        onStatusChanged: {
            if (offer.status === Image.Ready) {
                // offer.source and not root.offered -- the resolved url is
                // what the cache is keyed on.
                root.held = offer.source;
                return;
            }

            if (offer.status === Image.Error && root.youtubeId && !root.maxResFailed)
                root.maxResFailed = true;
        }
    }

    // ---------------- The wallpaper, for when nothing is playing ----------
    //
    // The same file `wallpaper-switch` writes and the carousel reads, so the
    // panel and the desktop can never disagree about which picture is up.
    //
    // THE THUMBNAIL AND NOT THE WALLPAPER. The collection is 4K and about
    // half of it is PNG, which has no scaled decoding -- asking an Image for
    // a small version of one costs a full 8.3-megapixel decode. wallpaper-
    // switch keeps a 960px JPEG of each, and for a video wallpaper it keeps
    // an extracted frame, which is the only thing an Image can show at all.
    // The full file is the fallback for a collection the script has not been
    // over yet; for a video that fallback cannot load and the ground falls
    // back to the panel's own colour.
    FileView {
        id: wallpaperFile

        path: `${Config.cacheDir}/wallpaper-current`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
    }

    readonly property string wallpaperPath: (wallpaperFile.text() || "").trim()

    property bool wallpaperThumbFailed: false
    onWallpaperPathChanged: root.wallpaperThumbFailed = false

    readonly property string wallpaperSource: {
        if (root.wallpaperPath === "")
            return "";
        return root.wallpaperThumbFailed
            ? Config.wallpaperFullUrl(root.wallpaperPath)
            : Config.wallpaperThumbUrl(root.wallpaperPath);
    }

    // ---------------- The ground, and how dark it has to be ----------------
    //
    // `offered` AND NOT `held`, AND THAT ONE WORD WAS A BUG YOU COULD SEE.
    // Opening the panel flashed the WALLPAPER for a frame or two and then
    // corrected itself to the cover.
    //
    // The cause is the same trap the cover art itself fell into once already.
    // components/Popout.qml is `Loader { active: root.isOpen }`, so the panel
    // is DESTROYED on close and rebuilt from nothing on open -- and `held` is
    // this component's own property, which means it starts empty every single
    // time. Keyed on `held`, this expression could not tell "there is no
    // cover" from "the cover has not been decoded yet": both were the empty
    // string, and both answered the wallpaper. A panel that has just been
    // constructed has no past, so the fallback was always what frame one got.
    //
    // `offered` is the URL this shell KNOWS about, and it survives the close
    // because it is read out of the Track singleton -- which watches every
    // player on the bus whether or not anything is on screen, and which was
    // put there for exactly this reason when the cover kept vanishing. So on
    // frame one the ground is already pointed at the right picture and never
    // at the wrong one. The fallback is now only ever the answer to "there is
    // no cover", which is the question it was written for.
    //
    // WHAT THAT COSTS, said rather than hidden: `held` exists so that the
    // sharp art square is never handed a load in progress or a load that
    // failed, and the ground gives that protection up. It can afford to --
    // it is behind a blur and a scrim, so "not decoded yet" is the panel's
    // own surface colour for a few frames rather than a broken picture, and
    // an https cover that 404s is corrected by the retry on `offered` itself.
    // The art square still uses `held` and still has the protection.
    //
    // OPENING TWICE ON THE SAME TRACK NOW SHOWS NOTHING AT ALL. The Image
    // below leaves `cache` at its default of true, so the second open is a
    // pixmap-cache hit on the same source at the same sourceSize and there is
    // nothing to decode. The first open after a track change still pays for
    // one 96-pixel decode; what it does NOT do any more is show the wrong
    // picture while it waits.
    readonly property string groundSource: root.offered !== "" ? root.offered : root.wallpaperSource

    // ---- WHY THE GROUND IS TWO PICTURES AND NOT ONE ----
    //
    // A track change swaps the background of the ENTIRE panel. Cut, it reads
    // as something breaking rather than as something changing -- the whole
    // surface everything else is standing on jumps colour in one frame.
    //
    // So there are two slots. `groundShown` is what is being faded IN and
    // `groundBehind` is what was there before it, still at full opacity
    // underneath, and the two are crossfaded inside ONE source item. That
    // last part is the point: they are two Images in a hidden, layered Item
    // handed to a single MultiEffect, so the crossfade costs one more textured
    // quad and one more 96-pixel decode -- and NOT a second full-panel blur,
    // which is the one thing this design cannot afford to do twice. The
    // hidden-Item-as-effect-source pair is components/CornerWedge.qml's, which
    // hands a composed subtree to a MultiEffect the same way.
    //
    // Assigned in a handler rather than by two bindings, because what is
    // wanted is the PREVIOUS value of a property and a binding cannot see one.
    property string groundShown: ""
    property string groundBehind: ""

    onGroundSourceChanged: {
        // Nothing left to show: drop BOTH, or the picture underneath would
        // stay up forever behind a front slot that never loads again.
        if (root.groundSource === "") {
            root.groundBehind = "";
            root.groundShown = "";
            return;
        }

        root.groundBehind = root.groundShown;
        root.groundShown = root.groundSource;
    }

    // A binding's first evaluation is lazy, so the handler above may or may
    // not have fired by now. Setting it again here is harmless either way and
    // is what guarantees the panel opens with a ground.
    Component.onCompleted: root.groundShown = root.groundSource

    ColorQuantizer {
        id: groundQuantizer

        // LOCAL FILES ONLY, and this guard is not defensive programming -- it
        // is the documented limit of the type. Quickshell's
        // src/core/colorquantizer.cpp loads with
        // `QImage(this->source.toLocalFile())` and contains no network code
        // at all, so an https cover yields an empty path and a warning on
        // stderr once per track.
        source: root.groundShown.startsWith("file:") ? root.groundShown : ""

        // One colour off a 1x1 rescale. The whole job is "what colour is this
        // picture", and doing it on one pixel is why it costs nothing.
        depth: 0
        rescaleSize: 1
    }

    // THE SCRIM, MEASURED, and the rule lives in ColorUtils because the island
    // needs the same answer about the same picture. See scrimFor there for
    // what it does with an unmeasurable cover and why it uses luminance
    // rather than lightness.
    readonly property real scrimOpacity: ColorUtils.scrimFor(groundQuantizer.colors)

    // ---------------- What replaced the sampling gate ----------------
    //
    // The popout loads this component when it opens and DESTROYS it when it
    // closes, so "this exists" and "somebody is looking at it" are the same
    // statement here. SystemStats never stops entirely -- it drops to a 5s GPU
    // poll and a 2s read of two small files, because the island has to warn
    // about a hot card with this panel shut.
    Binding {
        target: SystemStats
        property: "active"
        value: root.visible
    }

    // MINUTES, the same choice the bar's clock made: the two things reading
    // this are a "HH:mm" and a date, so a per-second tick is fifty-nine
    // wake-ups an hour that redraw the same two strings.
    SystemClock {
        id: dashClock

        precision: SystemClock.Minutes
    }

    // ---------------- The wall itself ----------------
    //
    // A ClippingRectangle and not a plain Item with `clip: true`, for the
    // reason the ported media card was one: `clip` on a plain Item clips to
    // the BOUNDING BOX, so a blurred photograph would be painted straight
    // over the rounded corners and square them off. This clips to the radius.
    ClippingRectangle {
        id: wall

        anchors.fill: parent

        // The shell's own card radius, so the sheet reads as one more surface
        // in this shell rather than as a foreign object dropped into it.
        radius: Theme.cardRadius - 6

        // What is under the picture, and what is left when there is no
        // picture at all -- no cover, and a wallpaper the shell cannot draw.
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        // NINETY-SIX PIXELS WIDE. This is the input to a blur that erases
        // every detail anyway, so decoding a 4K wallpaper or a 1024px cover
        // at full size to throw all of it away is the one cost here that
        // would be pure waste. It also does half the blurring for free: at
        // this size the upscale to panel width is already a soft field, and
        // the effect below only has to take the interpolation seams out.
        // BIGGER THAN THE PANEL BY A BLUR RADIUS ON EVERY SIDE, and that is
        // not a flourish. MultiEffect blurs whatever is in its source, and
        // outside the source there is nothing -- so a ground that stopped
        // exactly at the panel's edge would have sixty-four pixels of
        // transparency dragged inwards all the way round, and the wall's own
        // colour would show through as a vignette. Grown past the edges, the
        // fringe lands outside the clip and never gets drawn.
        Item {
            id: groundStack

            anchors.fill: parent
            anchors.margins: -70

            // Rendered into a texture for the effect below and never drawn
            // directly. Both halves are needed and they are the pair
            // components/CornerWedge.qml already uses for this: `visible`
            // keeps it off the screen, `layer.enabled` is what gives the
            // MultiEffect a texture of the composed subtree rather than of
            // one item.
            visible: false
            layer.enabled: true

            // What was on the wall before the last change. No opacity of its
            // own: it is simply what shows through while the picture in front
            // of it is still loading or still arriving.
            Image {
                anchors.fill: parent

                source: root.groundBehind
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                asynchronous: true
            }

            Image {
                id: groundImage

                anchors.fill: parent

                source: root.groundShown
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                asynchronous: true

                // NOT READY MEANS NOT SHOWN, which is what makes this a
                // crossfade rather than a flash: the moment the source
                // changes this falls away and the old picture behind it is
                // what is on screen, and the new one comes up only once there
                // is something to come up.
                opacity: groundImage.status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    // Nothing to fade FROM on the first load -- the panel is
                    // built when it opens, so every open would otherwise fade
                    // its own background in from nothing.
                    enabled: root.groundBehind !== ""

                    // Slower than the shell's own animations on purpose: this
                    // is a whole wall changing colour, and at 220ms that
                    // still reads as a cut.
                    NumberAnimation { duration: 400 }
                }

                onStatusChanged: {
                    // Only the WALLPAPER has a second thing to try here. A
                    // cover that fails is handled by the retry on `offered`,
                    // which drops maxresdefault for mqdefault and hands this
                    // a new url.
                    //
                    // Asked as "is the ground currently the wallpaper" rather
                    // than "is there no cover held", because the ground stopped
                    // keying on `held` -- see groundSource. Getting this wrong
                    // would blame the wallpaper for a cover's 404 and quietly
                    // stop using the thumbnail cache for the rest of the
                    // session.
                    if (groundImage.status === Image.Error && root.offered === "" && !root.wallpaperThumbFailed)
                        root.wallpaperThumbFailed = true;
                }
            }
        }

        MultiEffect {
            anchors.fill: groundStack
            source: groundStack
            visible: root.groundShown !== ""

            blurEnabled: true
            blur: 1.0
            blurMax: 64

            // A touch off the top, because a heavily blurred photograph
            // reads more saturated than the photograph does -- the blur
            // averages away the detail that was breaking the colour up.
            // MultiEffect's saturation is an ADJUSTMENT with 0 for no change,
            // so this is a small reduction and not a multiplier.
            saturation: -0.1
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.scrimOpacity

            // The scrim moves when the album does, and a cut between two
            // opacities is more noticeable than the picture changing under
            // it.
            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }
        }

        // ---- The spectrum, rising off the bottom of the ground ----
        //
        // end-4's WaveVisualizer, which is cava drawn as one continuous
        // filled wave. It used to span the media card; here it spans the
        // panel, behind everything, because there is no card left for it to
        // belong to and the whole ground is the media's now.
        //
        // BOTTOM-ANCHORED AND NOT FILLING THE PANEL. The wave is drawn on a
        // Canvas, which is rasterised on the CPU and uploaded, so its cost is
        // its area -- filling a 1014 x 470 panel is seven times the card it
        // came off. At 190 it is under three times, and a wave whose peaks
        // could reach the clock would be fighting the type rather than
        // sitting under it.
        //
        // No opacity here: it fills at 0.15 alpha inside the canvas and blurs
        // the result, and stacking an item opacity on top would be a second
        // dimming.
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.min(root.bodyHeight, 190)

            live: Spectrum.active
            // ONE FEED FOR THE WHOLE SHELL. This panel used to run a cava of
            // its own beside the island's, because the island drew 14 fat
            // bars and this drew a wave and the two wanted different numbers.
            // The island draws the same wave now, so there is one process and
            // one config; see Spectrum.qml.
            points: Spectrum.values
            maxVisualizerValue: Spectrum.maxValue
            smoothing: 2
            color: root.ink
        }

        // ================ The media block ================
        Item {
            id: mediaBlock

            x: root.edge
            y: root.edge
            width: root.leftWidth
            height: root.mediaHeight

            // ---- The sharp copy of the ground ----
            // AS TALL AS THE BLOCK, WHICH IS AS TALL AS THE COLUMN BESIDE
            // IT. This was a fixed 104 square while the column came to 126,
            // which left twenty-two pixels of empty ground under the picture
            // and beside the transport -- the exact kind of hole this whole
            // redesign started over. Filling the height is also what end-4's
            // own card does: their art square is Layout.fillHeight with the
            // width following, so the two sides of the block always end
            // level.
            //
            // No loop: the width follows the height, and the height comes
            // from the block, which is sized from the COLUMN's implicit
            // height. The column's texts all elide rather than wrap, so their
            // heights do not depend on the width this leaves them.
            ClippingRectangle {
                id: artFrame

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: height
                radius: 10

                // A tint of the ground rather than a grey hole, so a track
                // with no artwork still belongs to the panel it is on.
                color: Qt.alpha(root.ink, 0.08)

                Image {
                    id: art

                    anchors.fill: parent

                    // `held` and not `offered`: this is the cover that has
                    // already loaded, so it changes only when there is a new
                    // picture to change to.
                    source: root.held

                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize.width: 1024
                    asynchronous: true
                    mipmap: true
                    smooth: true
                }

                // A blank square reads as a load that failed; a glyph reads
                // as "this track has no cover".
                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: Icons.music
                    font.family: Theme.fontFamily
                    font.pointSize: Math.round(artFrame.height * 0.26)
                    color: Qt.alpha(root.ink, 0.5)
                }
            }

            // The hairline, drawn OVER the square rather than as its border:
            // a ClippingRectangle's border would be clipped along with
            // everything else in it, which leaves a half-width line.
            Rectangle {
                anchors.fill: artFrame

                color: "transparent"
                radius: artFrame.radius
                border.width: 1
                border.color: Qt.alpha(root.ink, 0.18)
                antialiasing: true
            }

            // ---- Everything beside it ----
            // ---- Everything beside it ----
            //
            // A ColumnLayout AND NOT FOUR ANCHORED ITEMS, and the difference
            // is the whole bug. The title, the artist and the times used to
            // hang DOWNWARD from the top of this block while the transport
            // rose from its bottom, and nothing anywhere reserved the space
            // between the two ends. They did not collide because they were
            // positioned wrongly; they collided because nothing prevented it,
            // which is a bug that waits rather than a bug that is fixed.
            //
            // Widening a margin would have bought a few pixels and left the
            // same collision waiting for the next change to Theme.fontSize --
            // and this panel's own width is derived from font metrics
            // precisely because text growing is a case it is designed for.
            // In one chain the separation is guaranteed by construction: the
            // spacer takes whatever is left over and never less than eight,
            // so the transport can never reach the line above it.
            //
            // The spacer is end-4's, from the card this block came from --
            // everything above it sits at the top, everything below it at the
            // bottom. It was dropped in the rewrite that turned their card
            // into this panel, and dropping it is what removed the guarantee.
            ColumnLayout {
                id: info

                anchors.left: artFrame.right
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                spacing: 2

                Text {
                    id: trackTitle

                    Layout.fillWidth: true
                    Layout.topMargin: 2

                    text: root.player ? (root.player.trackTitle ?? "Untitled") : "Nothing is playing"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: root.titleSize
                    font.weight: Font.Bold
                    color: root.player ? root.ink : Qt.alpha(root.ink, 0.55)
                }

                Text {
                    id: trackArtist

                    Layout.fillWidth: true

                    visible: !!root.player

                    // Through Track, not raw: it strips the " - Topic" suffix
                    // YouTube's auto-generated channels carry. Shared with the
                    // island so the same track never reads two different ways
                    // in two places.
                    text: Track.artist(root.player?.trackArtist ?? "")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: root.artistSize
                    color: Qt.alpha(root.ink, 0.7)
                }

                // THE SLACK, AND IT SITS ABOVE THE TIMES RATHER THAN UNDER
                // THEM.
                //
                // It was between the times and the transport, which put a
                // greedy spacer between a CAPTION AND THE THING IT CAPTIONS.
                // "1:13 / 3:29" describes the bar below it; separated from it
                // by every spare pixel in the block, the times read as a
                // small line orphaned under the artist and related to
                // nothing, and the wave sat a gap away below.
                //
                // The times and the seek row are one group and move together.
                // Everything between the artist and that group is what
                // stretches, so the distance from the times to the bar is the
                // layout's own spacing and NOTHING ELSE -- it cannot change
                // however tall the block gets, which is the test this has to
                // pass. Growing the panel can only ever open the gap above
                // the group.
                //
                // Eight is a floor and not a target. The block is sized from
                // this column, so in practice there is no slack at all and
                // this is exactly eight; the fillHeight only matters if
                // something else ever makes the block taller than its own
                // content.
                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 8
                }

                // The caption for the bar below it. No top margin: the gap
                // above belongs to the spacer, and the gap below is the
                // layout's spacing, which is what keeps the pair together.
                Text {
                    Layout.alignment: Qt.AlignLeft

                    visible: !!root.player
                    text: root.timeText
                    font.family: Theme.fontFamily
                    font.pointSize: root.timeSize
                    color: Qt.alpha(root.ink, 0.55)
                }

                // ---- The seek wave and the transport, on one row ----
                RowLayout {
                    id: transport

                    Layout.fillWidth: true

                    visible: !!root.player
                    spacing: 14

                    // end-4's wavy slider, and the reason the panel's one
                    // curve is a curve: the played part is a travelling sine,
                    // the rest a flat rail. See components/WavySlider.qml.
                    WavySlider {
                        Layout.fillWidth: true

                        value: root.fraction

                        // A fraction of a length that does not exist is a
                        // seek to nowhere: the handler below multiplies by
                        // `length`, which without a real one is the current
                        // position, so dragging to the middle would ask the
                        // player to jump to half of now.
                        seekable: root.hasLength && (root.player?.canSeek ?? false)

                        // The wave travels while the track does. Paused, the
                        // curve stays where it is rather than flattening.
                        animateWave: root.player?.isPlaying ?? false

                        highlightColor: Qt.alpha(root.ink, 0.85)
                        trackColor: Qt.alpha(root.ink, 0.22)
                        handleColor: root.ink
                        dotColor: Qt.alpha(root.ink, 0.5)
                        dotColorHighlighted: root.ink

                        onMoved: at => {
                            const p = root.player;
                            if (!p || !root.hasLength || !p.length)
                                return;
                            p.position = at * p.length;

                            // AND MOVE THE BAR NOW. The position is read back
                            // twice a second, so without this the handle
                            // snaps back and animates forward again on the
                            // next poll -- a visible rubber-band after every
                            // seek.
                            root.livePosition = at * p.length;
                        }

                        // Smoothed, or the fill jumps twice a second instead
                        // of creeping.
                        Behavior on value {
                            NumberAnimation { duration: 480 }
                        }
                    }

                    TrackChangeButton {
                        glyph: Icons.skipPrevious
                        enabled: root.player?.canGoPrevious ?? false
                        onActivated: root.player?.previous()
                    }

                    // 44 across and end-4's, which is the size the ported
                    // card used: a rounded SQUARE while it is playing and a
                    // circle when it is not, so the button reads as a state
                    // rather than as a button. White rather than an accent,
                    // because it is the one thing on this panel that has to
                    // be found instantly on any ground.
                    Rectangle {
                        id: playPause

                        readonly property bool playing: root.player?.isPlaying ?? false

                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44

                        radius: playPause.playing ? 17 : width / 2

                        color: playMouse.containsMouse ? root.ink : Qt.alpha(root.ink, 0.92)

                        opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.3

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
                            font.pointSize: Theme.fontSize * 22 / 16
                            color: root.inkInverse
                        }

                        MouseArea {
                            id: playMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.player?.canTogglePlaying ?? false
                            onClicked: root.player?.togglePlaying()
                        }
                    }

                    TrackChangeButton {
                        glyph: Icons.skipNext
                        enabled: root.player?.canGoNext ?? false
                        onActivated: root.player?.next()
                    }
                }
            }
        }

        // ================ What this machine is doing ================
        //
        // THREE READINGS AND NOT THREE DIALS. The rings that stood here were
        // 124 pixels each and were the reason the panel was as wide as it is;
        // on a photograph they were three heavy pieces of furniture competing
        // with the picture for the same corner. A label, a number and a short
        // bar say the same thing in a quarter of the height, and the bar is
        // the part that is read at a glance.
        //
        // WHAT DID NOT GO WITH THEM is the second line each dial carried --
        // the temperature, or the swap. It moved up beside the label, where
        // it costs no height at all, and it keeps the colour: the reading and
        // the bar turn amber and then red together, on the island's own
        // thresholds, so "hot" means the same thing everywhere in this shell.
        Glass {
            id: readingsGlass

            x: root.edge
            width: root.leftWidth
            height: root.readingsHeight

            anchors.bottom: slidersGlass.top
            anchors.bottomMargin: root.gap

            RowLayout {
                id: readingsRow

                anchors.fill: parent
                anchors.margins: root.glassPad
                spacing: 0

                Reading {
                    Layout.fillWidth: true

                    title: "CPU"
                    percent: SystemStats.cpuPercent
                    reading: `${Math.round(SystemStats.cpuTemp)} °C`

                    // Coloured by the temperature beside it, not by the
                    // percentage: a CPU pinned at 100% is a CPU compiling,
                    // and a red bar every time is a red bar that stops being
                    // read. The thresholds are the island's own, so nothing
                    // in this shell has a second opinion about "hot".
                    level: SystemStats.cpuTemp
                    warmAt: SystemStats.cpuCoolAt
                    hotAt: SystemStats.cpuHotAt
                }

                // WHICH READING FOR RAM, since memory has no temperature.
                // Used-of-total is the percentage again in GiB and moves in
                // lockstep with the bar; swap does not. A machine at 85%
                // memory with an empty swap is a machine using its memory,
                // which is what it is for. The same machine with two
                // gigabytes in swap is paging, and paging is the thing you
                // get up and do something about.
                Reading {
                    Layout.fillWidth: true

                    title: "RAM"
                    percent: SystemStats.ramPercent
                    reading: SystemStats.swapTotal > 0
                        ? `${SystemStats.swapUsed.toFixed(1)}G swap`
                        : "no swap"

                    // The one reading still coloured by its own percentage,
                    // on the island's memory thresholds rather than on a
                    // number of this file's own.
                    level: SystemStats.ramPercent
                    warmAt: SystemStats.ramCoolAt
                    hotAt: SystemStats.ramHotAt
                }

                // ONLY ONCE A CARD HAS ANSWERED. On a machine with neither
                // vendor bound SystemStats spawns nothing and leaves every
                // figure at zero, and a reading of 0% and 0 °C looks like a
                // panel that broke rather than a machine without the part.
                // A RowLayout skips an invisible child outright, so the two
                // that remain simply take the width.
                Reading {
                    Layout.fillWidth: true

                    title: "GPU"
                    visible: SystemStats.gpuAvailable
                    percent: SystemStats.gpuPercent
                    reading: `${Math.round(SystemStats.gpuTemp)} °C`

                    // Its own numbers and not the CPU's: coretemp puts this
                    // chip's throttle at 100 °C and Blackwell starts losing
                    // clocks around 85.
                    level: SystemStats.gpuTemp
                    warmAt: SystemStats.gpuCoolAt
                    hotAt: SystemStats.gpuHotAt
                }
            }
        }

        // ================ The two values you set by feel ================
        //
        // THE VOLUME CAME UP OFF THE BOTTOM EDGE, and this band is both
        // halves of the fix at once. As a control it is the obvious one: a
        // six-pixel rule at the very edge of the panel had nowhere to put the
        // mute button, so muting became a right-click nobody would find, and
        // the number only appeared when you pointed at it. As a LAYOUT it is
        // what closes the 105-pixel hole this panel had -- the left column
        // was three bands where the right column needed four bands' worth of
        // height. See the note on `bodyHeight`.
        //
        // The brightness is the second row of the same panel and exists only
        // on a machine with a backlight; a Column skips an invisible child
        // AND the spacing in front of it, so on a desktop this band is
        // exactly one slider tall.
        Glass {
            id: slidersGlass

            x: root.edge
            width: root.leftWidth
            height: root.slidersHeight

            anchors.bottom: actionsGlass.top
            anchors.bottomMargin: root.gap

            Column {
                id: sliders

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.glassPad
                anchors.rightMargin: root.glassPad
                anchors.verticalCenter: parent.verticalCenter

                spacing: 4

                VolumeControl {
                    width: parent.width

                    ink: root.ink
                    rest: Qt.alpha(root.ink, 0.13)
                    wash: Qt.alpha(root.ink, 0.26)
                }

                BrightnessControl {
                    width: parent.width

                    ink: root.ink
                }
            }
        }

        // ================ What produces a file ================
        Glass {
            id: actionsGlass

            x: root.edge
            width: root.leftWidth
            height: root.actionsHeight

            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.edge

            RowLayout {
                id: actionsRow

                anchors.fill: parent
                anchors.margins: root.glassPad
                spacing: 14

                RecordControl {
                    // FILL, so the three targets share whatever the replay
                    // block beside them does not take. Their own implicit
                    // width is still what sets the panel's -- see leftWidth.
                    Layout.fillWidth: true

                    ink: root.ink
                    rest: Qt.alpha(root.ink, 0.14)
                    wash: Qt.alpha(root.ink, 0.28)
                    stroke: Qt.alpha(root.ink, 0.22)
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    color: Qt.alpha(root.ink, 0.2)
                }

                ReplayControl {
                    ink: root.ink
                    inkMuted: Qt.alpha(root.ink, 0.65)

                    // A step brighter than the capture targets at rest and on
                    // hover alike: this is the one control in the panel that
                    // writes a file.
                    rest: Qt.alpha(root.ink, 0.22)
                    wash: Qt.alpha(root.ink, 0.38)
                    stroke: Qt.alpha(root.ink, 0.3)
                    inkInverse: root.inkInverse
                }
            }
        }

        // ================ The time ================
        Glass {
            id: clockGlass

            x: root.edge + root.leftWidth + root.columnGap
            y: root.edge
            width: root.rightWidth
            height: root.clockHeight

            // CENTRED IN THE BOX, both ways, and so is the month below it.
            // They were set against the left edge, which is right when a
            // panel is a column of left-aligned rows and wrong here: these
            // two are the only things in their glass, the glass is as wide as
            // the calendar demands rather than as wide as they need, and
            // anything left-aligned in a box that is wider than it reads as
            // having been pushed there.
            Column {
                id: clockLines

                anchors.centerIn: parent

                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(dashClock.date, "HH:mm")
                    font.family: Theme.fontFamily
                    font.pointSize: root.clockSize
                    font.weight: Font.Bold
                    color: root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Upper case and tracked out, which is the drawing's, and
                    // it is doing a job: a date set in the same case as the
                    // title across the panel would read as a second heading
                    // rather than as a caption under the time.
                    text: Qt.formatDate(dashClock.date, "dddd, d MMMM").toUpperCase()
                    font.family: Theme.fontFamily
                    font.pointSize: root.labelSize
                    font.letterSpacing: 1.4
                    color: Qt.alpha(root.ink, 0.65)
                }
            }
        }

        // ================ The month ================
        Glass {
            id: calendarGlass

            x: clockGlass.x
            width: root.rightWidth
            height: root.calendarHeight

            anchors.top: clockGlass.bottom
            anchors.topMargin: root.gap

            CalendarView {
                id: month

                anchors.centerIn: parent

                // The one card in this panel that had to be taught a palette:
                // every colour in it was a Theme role, and Theme is the
                // WALLPAPER's palette, which has nothing to do with the album
                // behind the glass.
                ink: root.ink
                inkMuted: Qt.alpha(root.ink, 0.6)

                // The month steppers are controls, so they carry a surface at
                // rest like every other control on this ground.
                restWash: Qt.alpha(root.ink, 0.1)
                hoverWash: Qt.alpha(root.ink, 0.24)

                // Today is the panel's one inverted mark, matching the play
                // button rather than taking an accent that could land on a
                // ground of its own colour.
                todayFill: Qt.alpha(root.ink, 0.92)
                todayInk: root.inkInverse
            }
        }

    }

    // ---------------- The pieces ----------------

    // A panel floating on the ground.
    //
    // NOT SEPARATELY BLURRED, and that is the whole reason this design is
    // affordable. "Frosted glass" normally means a blur of what is behind the
    // panel, which here would be a second, third and fourth full-size blur
    // pass over an image that has ALREADY been blurred past recognition. A
    // white film at a tenth and a hairline at a sixth is what is left of the
    // effect once the blur underneath is doing the work, and it is
    // indistinguishable at this radius.
    component Glass: Rectangle {
        radius: root.glassRadius
        color: Qt.alpha(root.ink, 0.1)
        border.width: 1
        border.color: Qt.alpha(root.ink, 0.16)
        antialiasing: true
    }

    // One subsystem: a label and its detail on the top line, the load large
    // underneath, and a short bar beside the number.
    //
    // THE BAR IS 70 LONG AND DOES NOT STRETCH. The cell does -- three of them
    // share the strip -- but a bar that grew with the panel would be the
    // longest graphic in the design and would out-shout the wave behind it.
    // Seventy is the drawing's, and at that length the eye reads the FILL
    // rather than measuring the length.
    component Reading: Item {
        id: cell

        property string title: ""
        property real percent: 0

        // The line that says whether this is in trouble: a temperature where
        // there is one, and the swap where there is not.
        property string reading: ""

        // WHAT THE COLOUR FOLLOWS, and it is not the load. See the note where
        // each of the three is built.
        property real level: cell.percent
        property int warmAt: 85
        property int hotAt: 90

        readonly property real fraction: Math.max(0, Math.min(1, cell.percent / 100))

        readonly property color lit: cell.level >= cell.hotAt ? Theme.critical
            : cell.level >= cell.warmAt ? Theme.warning
            : Qt.alpha(root.ink, 0.9)

        implicitHeight: label.implicitHeight + 6 + value.implicitHeight

        Text {
            id: label

            anchors.left: parent.left
            anchors.top: parent.top

            text: cell.title
            font.family: Theme.fontFamily
            font.pointSize: root.labelSize
            font.weight: Font.Bold
            font.letterSpacing: 1.2
            color: Qt.alpha(root.ink, 0.55)
        }

        Text {
            anchors.left: label.right
            anchors.leftMargin: 10
            anchors.baseline: label.baseline

            text: cell.reading
            font.family: Theme.fontFamily
            font.pointSize: root.labelSize
            color: cell.level >= cell.warmAt ? cell.lit : Qt.alpha(root.ink, 0.45)

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            id: value

            anchors.left: parent.left
            anchors.bottom: parent.bottom

            text: `${Math.round(cell.percent)}%`
            font.family: Theme.fontFamily
            font.pointSize: root.readingSize
            font.weight: Font.Bold
            color: root.ink
        }

        // Anchored to the number and not to a fixed offset: "100%" is wider
        // than "7%", and a bar at a fixed x is a bar the number eventually
        // runs into.
        Rectangle {
            id: bar

            anchors.left: value.right
            anchors.leftMargin: 12
            anchors.verticalCenter: value.verticalCenter

            width: 70
            height: 5
            radius: height / 2
            color: Qt.alpha(root.ink, 0.2)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: parent.width * cell.fraction
                radius: parent.radius
                color: cell.lit

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }
        }
    }

    // A skip button, and it is still end-4's TrackChangeButton: 24 x 24 with
    // a glyph drawn at their `huge` size, so the mark very nearly fills the
    // target and slightly overhangs it. That is why these read as glyphs with
    // a hit area rather than as buttons.
    component TrackChangeButton: Rectangle {
        id: button

        property string glyph: ""

        signal activated

        // CENTRED AND NOT STRETCHED. A RowLayout gives a child the whole
        // cross axis unless it is told otherwise, and the row this sits in is
        // 44 tall because of the play button beside it -- so without this the
        // 24-pixel circle comes out as a 24-by-44 vertical pill the moment
        // the pointer touches it.
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: 24
        implicitHeight: 24
        radius: width / 2

        // A SURFACE AT REST, like everything else that can be pressed here.
        // These were transparent until hovered, which on a photograph makes a
        // control indistinguishable from a glyph somebody drew.
        color: buttonMouse.containsMouse ? Qt.alpha(root.ink, 0.24) : Qt.alpha(root.ink, 0.1)

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
            color: root.ink
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
}
