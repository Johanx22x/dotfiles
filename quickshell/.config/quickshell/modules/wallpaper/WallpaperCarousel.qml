// The wallpaper carousel: one fullscreen sheet with the whole collection on a
// curve, the one you would apply in the middle of it.
//
// IT REPLACES THREE THINGS AT ONCE, and that is the point of it. There used to
// be two keybinds that changed the wallpaper without showing it -- SUPER +
// SHIFT + W for the next one alphabetically, SUPER + SHIFT + A for a random
// one -- and a strip of small thumbnails inside the launcher, reached by
// typing ">" and picking "Wallpaper". Three entry points, none of which let
// you SEE the picture at the size it is about to be shown at. A wallpaper is
// chosen by looking; this is the surface that lets you look.
//
// THE SHAPE IS A COVERFLOW and not a grid, which is the other obvious answer
// and is the one the settings window used to carry. A grid answers "which of
// these fifty is applied" -- it shows many small pictures at once. This
// answers "what do I want next", which is a question you take one picture at a
// time: the centred card is as large as the sheet can afford, its neighbours
// are legible enough to aim at, and the rest of the collection is implied by
// the fan running off both edges.
//
// WHAT IT COSTS TO HAVE OPEN, because the answer was not obvious and is worth
// keeping. Nearly all of the work that used to be here was self-inflicted --
// decoding 4K originals to fill card-sized thumbnails, a live layer per card
// feeding the corner mask, and playing the 4K wallpaper itself. See the
// thumbnail cache in Config and the shared mask below.
//
// EVERY CARD YOU CAN SEE MOVES, by flipping through JPEGs, and that is the one
// design decision here that was settled by measurement rather than by argument,
// so the measurements stay. It used to be a QtMultimedia MediaPlayer playing a
// small h264 copy of the wallpaper -- on the centred card alone, because a
// second player was unaffordable -- and stepping through the fan was not
// fluid.
//
// Measured on THIS machine -- an RTX 5070 on driver 610.57.04, where
// qt6-multimedia-ffmpeg decodes through NVDEC -- against the wallpapers in this
// collection. Five cards at 819x461 on a 2560x1440 surface, the fan under a
// continuous animation, frame pacing from a FrameAnimation, CPU from /proc:
//
//   five still cards, nothing moving        5.1% of a core   306 MB
//   one MediaPlayer, 960x540 at 24 fps      9.8%             622 MB
//   one MediaPlayer, 480x270 at 15 fps      9.9%             594 MB
//   five MediaPlayers, 960x540              19.6%            954 MB
//   one card flipping JPEGs at 15 fps       9.7%             311 MB
//   five cards flipping JPEGs               29.8%            320 MB
//
// and, stepping to the next card every 500 ms, which is the gesture the whole
// complaint was about:
//
//   MediaPlayer built and torn down per step   65.0%   p99 frame 249 ms, 6.7% late
//   one MediaPlayer, source re-pointed          66.2%   p99 frame 332 ms, 6.8% late
//   JPEG sequences, sources rotating            31.3%   p99 frame  19 ms, 0.3% late
//
// THE COST WAS NEVER THE DECODING. A MediaPlayer costs the same whatever you
// feed it -- the two rows above differ by a tenth of a point across a 4x
// difference in pixels -- because the bill is a CUDA context: two
// `cuda-EvtHandlr` threads burning a flat 3.2% of a core doing nothing, and
// 412 MB of VRAM, for as long as a player exists. On Intel or AMD that would be
// VA-API and those threads would not be there; this tax is specific to this
// machine. What made the fan stutter was CONSTRUCTION: building or destroying a
// player costs 250 to 466 ms with a third of it on the GUI thread, and
// re-pointing an existing one at another file is just as expensive, because Qt
// rebuilds the decoder either way. Five players kept permanently alive were
// perfectly fluid. There was simply no way to change WHICH video was playing
// without paying a quarter of a second for it.
//
// So nothing here decodes video any more, and everything that existed to hide
// that quarter of a second went with it: the pause-while-moving gate, the
// settle timer, the warmup delay before a player was allowed to exist, and the
// crossfade that covered the swap from still to video. A frame flip costs
// nothing to start or stop, so none of them have anything left to protect.
//
// AND THE ONE-CARD RULE WENT WITH THEM, which took a second pass to notice. It
// was never a statement about what a wallpaper picker should look like -- it
// was rationing. A player was 9.8% of a core and 300 MB whether it was showing
// you anything or not, so five of them were unthinkable and the centre got the
// only one. Frames cost what they draw: five cards flipping is 29.8% of a core
// against one card's 9.7%, but 320 MB of RSS against 311, and the rows above
// say plainly that nothing arrives late either way -- five cards flipping WHILE
// stepping through the fan was 0.26% late frames and a p99 of 19 ms. A picker
// whose four other pictures are frozen is answering the question worse than it
// needs to, and it is no longer paying for the privilege.
//
// The carousel answers "what will my desktop look like", and for a live
// wallpaper the answer moves. It should move on every card that is showing one.
//
// THE NUMBERS ARE FROM A 60 Hz HEADLESS RIG, not from this desktop's 165 Hz
// screen, and not from this file -- they come from a harness that reproduced
// the card geometry, the masking and the media path and nothing else. Read them
// as ratios between the rows rather than as what the shell draws. The per-frame
// costs are the same at any refresh rate; there are simply 2.75x more frames
// here.
//
// A PathView AND NOT A HAND-ROLLED ROW OF TRANSFORMS. The scale, the stacking
// order, the fade at the ends and the drop along the arc are all one
// interpolation along a path, which is what PathAttribute is for. Doing it by
// hand means writing that interpolation again, badly, in five bindings per
// card.
//
// GLASS, LIKE THE POWER MENU AND THE CHEATSHEET. Theme.glass() and not an
// alpha picked here: the blur rule in the compositor config ignores anything
// below Theme.glassAlpha, so a hand-picked value falls out of the blur
// entirely and the sheet goes from frosted wallpaper to a flat tint over
// perfectly sharp windows.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel
import QtQuick.Effects
import "root:/"

PanelWindow {
    id: root

    // The ShellScreen this carousel belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- The card ----------------
    //
    // A CARD IS A SCALE MODEL OF THE MONITOR, so its aspect comes from the
    // screen rather than from a number here. The reference this was built from
    // showed portrait phone wallpapers; cropping a 16:9 desktop wallpaper into
    // a portrait card would be showing you a picture that is not the one you
    // are choosing.
    readonly property real screenAspect: (root.modelData?.width ?? 16) / (root.modelData?.height ?? 9)

    // Height-driven, then capped against the width. The height is what leaves
    // room for the name under the fan; the cap is what keeps an ultrawide
    // monitor from producing a centre card so wide that its neighbours are
    // pushed off screen.
    readonly property int cardWidth: Math.round(Math.min(
        (root.modelData?.height ?? 1080) * 0.32 * root.screenAspect,
        (root.modelData?.width ?? 1920) * 0.34))
    readonly property int cardHeight: Math.round(root.cardWidth / root.screenAspect)

    // How much is cut off each corner. On the carousel and not on the card,
    // because the mask that does the cutting is shared by every card -- see
    // cardMask below.
    readonly property int cardRadius: Theme.cardRadius - 6

    // ---------------- The collection ----------------
    //
    // Read with Qt's FolderListModel: Quickshell has no directory API, and
    // shelling out to `ls` for something the toolkit already does would be a
    // process and a parser for no gain.
    //
    // Copied out into an array rather than fed to the view directly, because
    // the entries carry a thumbnail URL that FolderListModel knows nothing
    // about -- see rebuild() -- and because finding the applied wallpaper's
    // index means walking the list.
    property var entries: []

    readonly property int count: root.entries.length

    function rebuild(): void {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const path = folder.get(i, "filePath");
            out.push({
                name: folder.get(i, "fileName").replace(/\.[^.]+$/, ""),
                path: path,
                video: Config.isWallpaperVideo(path),
                // WHAT MAKES A REBUILD A CHANGE AT ALL, and the only field
                // here that says nothing about the wallpaper. Every other one
                // is a pure function of `path`, so the array this built after
                // a thumbnail run was byte for byte the array already in
                // place -- and an array whose contents compare equal is a
                // no-op on PathView, which is a rebuild that repairs nothing.
                // Measured offscreen on Qt 6.11.2: an identical rebuild costs
                // 0 delegate constructions and 0 onModelDataChanged, one that
                // differs costs one of each per card on the path.
                //
                // The bill for that is in the Connections on Config below: a
                // model PathView accepts as new puts currentIndex and offset
                // back to 0, and something has to put them back.
                rev: Config.wallpaperThumbsRevision,
                // NOT THE WALLPAPER ITSELF but the DIRECTORY of small frames
                // that wallpaper-switch keeps beside the still ones: 960 px
                // JPEGs at 15 fps against a 4K original at up to 120.
                //
                // EMPTY FOR A STILL, and empty for nothing else: this is the
                // name the directory WOULD have, worked out from the extension,
                // and nothing here goes to disk to find out whether it is
                // there. A video whose frames have not been built yet gets a
                // card pointed at a file that does not exist, which is what
                // card.framesMissing below is for.
                previewUrl: Config.wallpaperPreviewUrl(path),
                // NEVER the wallpaper itself either: a cached thumbnail for a
                // still, the extracted frame for a video. See the note on
                // Config.wallpaperThumb -- the short version is that decoding
                // a 4K PNG to fill a card costs a fifth of a second.
                thumbUrl: Config.wallpaperThumbUrl(path),
                // Where to go when that file is not there, which is any
                // collection the script has not been over yet. Only for
                // stills: an Image pointed at an mp4 fails just as hard as one
                // pointed at nothing.
                fullUrl: Config.isWallpaperVideo(path) ? "" : Config.wallpaperFullUrl(path)
            });
        }
        root.entries = out;
    }

    FolderListModel {
        id: folder

        // From Config and not a literal here: the folder is a setting, and the
        // settings page lists the same collection. A copy of the path in each
        // of them is how one of the two silently stops agreeing with the other.
        folder: `file://${Config.wallpaperDir}`
        nameFilters: Config.wallpaperNameFilters
        showDirs: false
        sortField: FolderListModel.Name

        // The model fills asynchronously, so the array is built when it reports
        // how many files it found rather than at construction.
        //
        // A changed count is also how a file dropped into the folder while the
        // shell is running gets its cached thumbnail: it has none until ffmpeg
        // has been past it, and this is the moment we learn it is there.
        //
        // A RENAME IS THE HOLE IN THAT, and it is worth knowing about rather
        // than rediscovering: renaming a wallpaper leaves the count where it
        // was, so nothing here fires, the card falls back to decoding the 4K
        // original, and the old cache entries survive until some other change
        // sweeps them. Adding or removing anything puts it right.
        onCountChanged: {
            root.rebuild();
            Config.refreshWallpaperThumbs();
            if (WallpaperState.isOpen)
                Qt.callLater(root.revealCurrent);
        }
    }

    // THE RUN THAT FINALLY WRITES THE PICTURES HAS TO REACH THE CARDS. An
    // Image pointed at a file that is not there reports Error and stops
    // asking, and the delegate latches that -- thumbMissing for a still,
    // framesMissing for a video's preview -- with nothing clearing either in
    // place. So the only way back is a model PathView treats as new: it
    // regenerates every delegate, and a delegate built after ffmpeg has been
    // past the file simply loads it. That a fresh Image will even try is the
    // premise of this handler and was measured rather than assumed -- see the
    // note on `cache` in the delegate.
    //
    // THIS USED TO DO NOTHING WHATSOEVER. rebuild() built an array that
    // compared equal to the one already in place, PathView returned early, and
    // no delegate heard a thing: a video copied into the folder with the shell
    // running stayed blank until the next restart, and a still added the same
    // way spent the session decoding the 4K original. `rev` in rebuild() is
    // what makes the array differ.
    //
    // AND PUTTING THE FAN BACK IS THE BILL FOR IT. A model PathView accepts as
    // new resets currentIndex and offset to 0, and this bump lands about a
    // second after every opening -- the open calls refreshWallpaperThumbs()
    // and the process bumps on the way out whether it had anything to build or
    // not. Without the reveal below, opening the carousel would snap the fan
    // to the alphabetically first wallpaper a moment later, and Enter would
    // apply that one.
    //
    // BACK TO THE CARD THAT WAS CENTRED, and not to the applied one the way
    // folder.onCountChanged goes. Nothing about the collection changed here --
    // the same wallpapers in the same order, now with the pictures they should
    // always have had -- so there is nothing to re-orient anybody about, and
    // anyone who had stepped away from the applied wallpaper inside that first
    // second would be dragged back to it for no reason they could see.
    //
    // Not deferred, unlike the two calls that go through revealCurrent: those
    // wait because the view has just been made visible and has nothing laid
    // out to position. Here it has been laid out for as long as the sheet has
    // been open, and staying in this turn leaves no moment at all where
    // currentIndex is 0 for anything else to read.
    Connections {
        target: Config

        function onWallpaperThumbsRevisionChanged(): void {
            const centred = root.entries[view.currentIndex]?.path ?? "";
            root.rebuild();
            root.revealPath(centred);
        }
    }

    // ---------------- What is applied right now ----------------
    //
    // A READING, NOT A CONTROL -- the same one the settings page takes, from
    // the same file. wallpaper-switch writes it after the backend has accepted
    // the image, so the "Applied" line below lands about a crossfade after the
    // click and does not move at all if the script failed.
    //
    // watchChanges only emits fileChanged(); reloading is the handler's job.
    // Without the reload this reads the file once at startup and then shows
    // whatever was applied when the shell launched.
    readonly property string currentPath: stateFile.text().trim()

    FileView {
        id: stateFile

        path: `${Quickshell.env("HOME")}/.cache/wallpaper-current`
        watchChanges: true
        onFileChanged: reload()
        // A machine that has never changed its wallpaper has no state file.
        // That is a first run, not an error to print on every launch.
        printErrors: false
    }

    // OPEN ON THE ONE THAT IS APPLIED. Without this the carousel opens wherever
    // it was left, which for the common case -- open it, look, change your
    // mind, Escape -- means it opens somewhere arbitrary and the first thing
    // you have to do is find your way back.
    //
    // positionViewAtIndex and not `currentIndex = i`: the second animates the
    // whole fan past you at open time, which is a lot of movement to say
    // "nothing has changed yet".
    function revealCurrent(): void {
        root.revealPath(root.currentPath);
    }

    // The same move aimed at a wallpaper that is not the applied one, which is
    // what a rebuild needs: the model is replaced, the fan goes back to the
    // start, and putting it back means naming the card that was centred rather
    // than the one on the desktop.
    //
    // BY PATH AND NOT BY INDEX, because an index means nothing across a
    // rebuild -- a file added to or taken out of the collection shifts every
    // index after it, and the carousel would come back pointing at the
    // wallpaper next door.
    function revealPath(path: string): void {
        if (path === "")
            return;

        const i = root.entries.findIndex(e => e.path === path);
        if (i >= 0)
            view.positionViewAtIndex(i, PathView.Center);
    }

    // ---------------- The clock every preview flips on ----------------
    //
    // ONE TIMER FOR THE WHOLE SHEET, and not one per card, which is the second
    // way this could have been built and is worth saying why it was not.
    //
    // The tick is a RATE LIMIT, not a metronome. A card does not draw the frame
    // the tick asked for -- it asks the hidden Image to load it and swaps when
    // that reports Ready, which happens whenever the loader thread gets to it.
    // So the cards are already out of phase with each other by however long
    // their JPEGs took, and five timers would not make them any more organic
    // than they already are. What five timers WOULD buy is five wakeups at
    // fifteen hertz to do the work of one, on a surface that is trying to spend
    // its budget on the fan.
    //
    // Gated on the window and nothing finer. A tick with no video on screen
    // walks five delegates and returns, fifteen times a second, which is
    // nothing next to a 2560x1440 sheet repainting at the refresh rate -- and
    // the window is destroyed outright when the carousel is closed, so this
    // does not exist at all for the part of the session that matters.
    signal frameTick

    Timer {
        // From Config, which is where the number that has to agree with
        // wallpaper-switch's WALLPAPER_PREVIEW_FPS lives. A disagreement there
        // plays the loop fast or slow; it does not break it, which is why that
        // one constant is allowed to be written down twice and the frame count
        // is not.
        interval: Math.round(1000 / Config.wallpaperPreviewFps)
        repeat: true
        running: root.visible
        onTriggered: root.frameTick()
    }

    function apply(entry: var): void {
        if (!entry)
            return;

        // Close first, so the crossfade happens on the desktop rather than
        // behind a sheet that is on its way out.
        WallpaperState.close();
        // wallpaper-switch and not awww: the script is what also regenerates
        // the palette and pushes the new accent into the compositor. Applying
        // the one already on screen is not a no-op either -- it reapplies,
        // which is the way back after a matugen template has been edited.
        Quickshell.execDetached(["wallpaper-switch", "set", entry.path]);
    }

    screen: modelData
    visible: WallpaperState.isOpen

    WlrLayershell.namespace: "quickshell-wallpaper"
    // Overlay and not Top: this covers the bar and a fullscreen window alike.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, or the arrows, Enter and Escape never reach us: a layer
    // surface that does not hold the keyboard is not sent a keystroke at all.
    // Stated once and never flipped, like every other grabbing surface here --
    // `visible` already tears the whole surface down when the sheet is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring
    // all four edges stretches the layer surface instead, and then the size the
    // compositor picked is not a size QML ever sees. Same as PowerMenu.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's reservation:
    // the sheet covers the bar rather than starting below it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    Connections {
        target: WallpaperState

        function onIsOpenChanged(): void {
            if (!WallpaperState.isOpen)
                return;

            sheet.forceActiveFocus();
            // A video added to the folder since the last look has no frame yet.
            Config.refreshWallpaperThumbs();
            // Deferred: the view has just been made visible and has nothing
            // laid out for positionViewAtIndex to position.
            Qt.callLater(root.revealCurrent);
        }
    }

    Rectangle {
        id: sheet

        // Sized from the SCREEN and not from `parent`: the window's contentItem
        // stays 0x0 whatever the layer surface measures, so `anchors.fill`
        // collapses to nothing. Same as PowerMenu and the cheatsheet.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        focus: true

        Keys.onEscapePressed: WallpaperState.close()
        Keys.onLeftPressed: view.decrementCurrentIndex()
        Keys.onRightPressed: view.incrementCurrentIndex()
        Keys.onReturnPressed: root.apply(root.entries[view.currentIndex])
        Keys.onEnterPressed: root.apply(root.entries[view.currentIndex])
        Keys.onPressed: event => {
            // Home row for the same two moves, since the rest of the session is
            // driven that way, and the key that opened it closes it -- a bare
            // W, because while the sheet holds the keyboard the compositor bind
            // still fires but the reflex once you are looking at it is the
            // letter on its own. Same argument the cheatsheet makes for "/".
            if (event.key === Qt.Key_H)
                view.decrementCurrentIndex();
            else if (event.key === Qt.Key_L)
                view.incrementCurrentIndex();
            else if (event.key === Qt.Key_W)
                WallpaperState.close();
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. It sits BELOW the fan in the file, so the
        // cards' own MouseAreas take their clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: WallpaperState.close()
        }

        // The wheel walks the fan. PathView has no wheel handling of its own
        // -- it is the flicking, not the scrolling, that it implements -- and
        // there is nothing underneath this to catch what it drops either: the
        // view is `interactive: false` a few lines down, so there is no
        // Flickable taking the events this handler does not. Whatever goes
        // wrong here goes wrong in silence and in full.
        //
        // EVERY DEVICE, which is the lesson components/ScrollList.qml was
        // written for and states at length. Naming device types fails by
        // declining events without saying so, and qtbase types this machine's
        // mouse as a TouchPad whenever the compositor advertises
        // zwp_pointer_gestures_v1 -- which niri does. Mouse | TouchPad
        // happens to cover that particular surprise; the point of AllDevices
        // is that there is no device this surface wants to refuse, so there
        // is nothing left to be surprised by.
        //
        // A NOTCH WITH NO ANGLE IN IT USED TO STEP BACKWARDS, and that is the
        // bug this replaces. The test was `angleDelta.y < 0 ||
        // angleDelta.x > 0` with `else` meaning "go back", so every wheel
        // event carrying no angle at all took the else: measured with
        // qmltestrunner, feeding the old handler a zero-delta wheel event
        // moved the fan one card BACKWARDS. Those events are ordinary rather
        // than theoretical -- a device that reports a continuous scroll fills
        // in pixelDelta and leaves angleDelta at zero, and the phase events
        // that begin and end a touchpad gesture carry no delta on either.
        //
        // So the angle is read first and the pixels stand in for it, exactly
        // as ScrollList does, and a nonzero step is required in one direction
        // or the other before the fan moves at all. Down or right is forward;
        // the vertical axis decides when both report, which is the one thing
        // here that differs from the old test -- it consulted the horizontal
        // even when the vertical had already answered.
        //
        // ONE CARD PER EVENT and not per pixel: the step this drives is
        // discrete, so what paces it is the stream of events rather than the
        // size of any one of them. A device that reports a continuous scroll
        // would therefore step per event, which is untested here because no
        // device on this machine reports that way. An accumulator is the fix
        // if it ever turns out to be too fast; it is not invented today for a
        // device nobody has.
        WheelHandler {
            acceptedDevices: PointerDevice.AllDevices

            onWheel: event => {
                const y = event.angleDelta.y !== 0 ? event.angleDelta.y
                    : event.pixelDelta.y;
                const x = event.angleDelta.x !== 0 ? event.angleDelta.x
                    : event.pixelDelta.x;
                const step = y !== 0 ? -y : x;

                if (step > 0)
                    view.incrementCurrentIndex();
                else if (step < 0)
                    view.decrementCurrentIndex();
            }
        }

        // ---------------- One mask, rendered once ----------------
        //
        // EVERY CARD IS THE SAME SIZE. The fan's perspective is a transform --
        // scale, not geometry -- so the rounded rectangle that cuts the corners
        // off a card is identical for all seven of them, and there is no reason
        // for seven copies of it.
        //
        // AND IT COST A GREAT DEAL MORE THAN SEVEN RECTANGLES. Measured with
        // the carousel open and NOTHING moving: 24% of a core with a live
        // layer per card, 7% -- the shell's idle -- without them. Two live
        // layers and an effect per card keep marking each other dirty, so the
        // whole screen re-rendered at the refresh rate to draw a picture that
        // was not changing.
        //
        // A ShaderEffectSource with live: false is what breaks that: it renders
        // its source once, hands the same texture to all seven cards for ever
        // after, and asks for nothing else until the geometry changes. The
        // source Rectangle is hidden -- hideSource -- and the texture is the
        // only thing that survives.
        Item {
            id: maskShape

            width: root.cardWidth
            height: root.cardHeight
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                antialiasing: true
                color: "black"
            }
        }

        ShaderEffectSource {
            id: cardMask

            sourceItem: maskShape
            width: root.cardWidth
            height: root.cardHeight
            hideSource: true
            live: false
            visible: false

            // RENDERED ONCE IS NOT RENDERED FOR EVER, and this is the bill for
            // `live: false`. Hiding the sheet destroys its layer surface and
            // with it the scene graph resources behind it -- this texture
            // included -- and a source that is not live never asks for another
            // one. The mask came back EMPTY on the second opening, and an
            // empty mask means MultiEffect cuts away everything it is given:
            // cards with a border and a name and no picture inside them.
            //
            // So it is scheduled on every opening, and on the two other things
            // that can change under it: a different monitor, and so a
            // different card size.
            onWidthChanged: cardMask.scheduleUpdate()
            onHeightChanged: cardMask.scheduleUpdate()
            Component.onCompleted: cardMask.scheduleUpdate()

            Connections {
                target: WallpaperState

                function onIsOpenChanged(): void {
                    if (WallpaperState.isOpen)
                        cardMask.scheduleUpdate();
                }
            }
        }

        PathView {
            id: view

            anchors.fill: parent

            model: root.entries
            pathItemCount: 7
            // The centre of the path is where the current item sits, always.
            // StrictlyEnforceRange is what makes "current" and "in the middle"
            // the same thing rather than two states that drift apart.
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            movementDirection: PathView.Shortest

            // NOT INTERACTIVE, and that is what keeps "click the empty space to
            // dismiss" working. An interactive PathView takes the press over
            // the whole sheet -- it fills it -- and the MouseArea underneath
            // never hears the click that was meant to close the carousel. The
            // wheel above and the arrow keys are the ways through the fan;
            // dragging a row of pictures with the mouse is not one anybody
            // reaches for on a desktop.
            interactive: false

            // Deliberately shorter than Theme.animDuration. The fan has to keep
            // up with the key rather than accompany it: at the interface's
            // standard 220 ms, holding an arrow down feels like dragging the
            // carousel behind the cursor. The same number, and the same reason,
            // as the strip this replaces.
            highlightMoveDuration: 90

            // The curve the cards ride: a shallow arc, widest in the middle,
            // fading out at both ends.
            //
            // THE FADE AT THE ENDS IS NOT DECORATION. pathItemCount is 7, so a
            // card has to be created and destroyed somewhere; at full opacity
            // that happens as a pop. The two outermost nodes are at zero
            // opacity AND past the edge of the screen, which spends two of the
            // seven slots on making the appearance invisible and leaves five
            // cards to look at.
            //
            // EVERY CARD YOU CAN SEE IS FULLY OPAQUE, and the five on screen
            // are the whole of that. The first version faded the outer ones to
            // 0.5 and 0.85 for depth, and what depth actually looked like was
            // the card BEHIND showing through the card in front, because the
            // cards overlap by design. Distance is said with size and with the
            // stacking order; transparency in a stack of overlapping
            // photographs only ever says "broken". The ramp to zero survives
            // only in the segment that runs off the edge of the screen.
            //
            // PathPercent on every node because the segments are NOT the same
            // length -- the fan is tighter at the edges than in the middle --
            // and without it PathView spaces the cards by path length and they
            // land between the nodes instead of on them.
            //
            // FIVE CARDS ON SCREEN AND BOTH ENDS OFF IT. The seven slots are
            // five to look at plus two that live past the edge, where a card
            // is created and destroyed out of sight instead of popping into
            // existence in front of you. They were only just outside before,
            // at -0.03 and 1.03, which on a portrait monitor -- where a card
            // is a third of the width of the screen -- left a sliver of each
            // one clipped against the frame: seven cards visible, two of them
            // cut. -0.2 and 1.2 clears them on any shape of monitor.
            //
            // THE GAPS BETWEEN THE OTHER FIVE ARE MEASURED FROM THE CARDS, not
            // chosen for the look of the numbers: each node sits far enough
            // from its neighbour that the smaller card is covered by about a
            // seventh of its width and no more, and the outermost pair sits
            // far enough in to leave a clear margin down each side. The first
            // attempt spaced the seven evenly and the cards either side of the
            // centre came out a third hidden, which is a picture you cannot
            // judge and a target you cannot aim at.
            path: Path {
                startX: view.width * -0.2
                startY: view.height * 0.52

                PathAttribute { name: "itemScale"; value: 0.34 }
                PathAttribute { name: "itemOpacity"; value: 0.0 }
                PathAttribute { name: "itemZ"; value: 0 }

                PathLine { x: view.width * 0.10; y: view.height * 0.507 }
                PathPercent { value: 1 / 6 }
                PathAttribute { name: "itemScale"; value: 0.44 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 1 }

                PathLine { x: view.width * 0.265; y: view.height * 0.487 }
                PathPercent { value: 2 / 6 }
                PathAttribute { name: "itemScale"; value: 0.66 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 2 }

                PathLine { x: view.width * 0.5; y: view.height * 0.47 }
                PathPercent { value: 3 / 6 }
                PathAttribute { name: "itemScale"; value: 1.0 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 3 }

                PathLine { x: view.width * 0.735; y: view.height * 0.487 }
                PathPercent { value: 4 / 6 }
                PathAttribute { name: "itemScale"; value: 0.66 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 2 }

                PathLine { x: view.width * 0.90; y: view.height * 0.507 }
                PathPercent { value: 5 / 6 }
                PathAttribute { name: "itemScale"; value: 0.44 }
                PathAttribute { name: "itemOpacity"; value: 1.0 }
                PathAttribute { name: "itemZ"; value: 1 }

                PathLine { x: view.width * 1.2; y: view.height * 0.52 }
                PathPercent { value: 1 }
                PathAttribute { name: "itemScale"; value: 0.34 }
                PathAttribute { name: "itemOpacity"; value: 0.0 }
                PathAttribute { name: "itemZ"; value: 0 }
            }

            delegate: Item {
                id: card

                required property int index
                required property var modelData

                readonly property bool centred: card.index === view.currentIndex

                width: root.cardWidth
                height: root.cardHeight

                // The attached values are undefined for an item that has been
                // pushed off the path, and an undefined scale is a card drawn
                // at full size in the top left corner.
                scale: card.PathView.onPath ? card.PathView.itemScale : 0
                opacity: card.PathView.onPath ? card.PathView.itemOpacity : 0
                z: card.PathView.onPath ? card.PathView.itemZ : 0
                visible: card.PathView.onPath

                // Set when the thumbnail turned out not to exist, which drops
                // this card back to the wallpaper itself. Reset when the card
                // is handed a different wallpaper: the delegates are recycled
                // as the fan turns, and a card that inherited this flag would
                // load a 4K original for a thumbnail that is perfectly fine.
                property bool thumbMissing: false

                // EVERYTHING LEARNT ABOUT THE OLD WALLPAPER GOES WITH IT. The
                // same recycling that makes thumbMissing dangerous makes a
                // remembered sequence length dangerous in a worse way: carried
                // onto a shorter video it would loop past the end of it for
                // ever, and onto a longer one it would show a third of it.
                onModelDataChanged: {
                    card.thumbMissing = false;
                    card.frameCount = 0;
                    card.frameShown = 0;
                    card.framePending = 0;
                    card.frontIsA = true;
                    card.framesMissing = false;
                }

                Image {
                    id: picture

                    anchors.fill: parent
                    source: card.thumbMissing
                        ? card.modelData.fullUrl
                        : card.modelData.thumbUrl

                    onStatusChanged: {
                        if (picture.status === Image.Error
                            && !card.thumbMissing
                            && card.modelData.fullUrl !== "")
                            card.thumbMissing = true;
                    }
                    fillMode: Image.PreserveAspectCrop
                    // Decoded at the size the CENTRE card is drawn at, and not
                    // at the size this one happens to be: the scale is a
                    // transform, so a card that shrinks and grows again would
                    // otherwise re-decode a 4K photograph on every step of the
                    // fan.
                    sourceSize.width: root.cardWidth
                    sourceSize.height: root.cardHeight
                    asynchronous: true
                    smooth: true

                    // CACHED FOR A STILL AND NOT FOR A VIDEO, which is the
                    // one place in this shell where that distinction is worth
                    // making. It is about DECODING and nothing else, and the
                    // rest of this note is the correction of what it used to
                    // say.
                    //
                    // A FAILED LOAD IS NOT PINNED. This claimed that Qt
                    // remembers a URL that failed and will not go back to disk
                    // for it, so that a video listed before ffmpeg had pulled
                    // a frame out of it would be blank for the rest of the
                    // session unless the Image kept asking. If that were true
                    // the retry above would repair nothing, so it was measured
                    // rather than believed: offscreen on Qt 6.11.2, `cache:
                    // true` and one sourceSize throughout, an Image asked for
                    // a file that does not exist reports Error, and once the
                    // file appears a NEW Image handed the same URL loads it --
                    // at 360 ms and at 2 s after the failure, with the Image
                    // that failed still alive beside it. What IS pinned is the
                    // request, not the answer: an Image re-handed the source
                    // it already holds emits nothing at all, which is a
                    // different trap and the one advanceFrame guards below.
                    //
                    // So what is left is the decode. Caching is what keeps the
                    // fan from decoding the same handful of stills over and
                    // over as it turns -- measured at roughly half the cost of
                    // the carousel with it on -- and a video's thumbnail is
                    // the one picture on this sheet that is not worth a cache
                    // entry, because the preview sequence covers it within a
                    // frame or two of the card appearing and it is never asked
                    // for again.
                    cache: !card.modelData.video

                    // NO `layer.enabled`, unlike every other masked image in
                    // this shell. An Image is already a texture provider, so
                    // MultiEffect can sample it directly; turning on a layer
                    // wraps it in a SECOND texture that has to be re-rendered
                    // from the image whenever the item is marked dirty, to draw
                    // a picture that never changes. The pair of frames below
                    // does take a layer, and that is not an inconsistency: two
                    // Images cannot be one MultiEffect source without it.
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: picture
                    maskEnabled: true
                    maskSource: cardMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0

                    // OFF THE MOMENT A PREVIEW FRAME IS ON SCREEN, and there
                    // is no fade between the two because there is nothing to
                    // hide: 001.jpg is extracted at the same second as the
                    // still frame, so the two are the same picture and the swap
                    // is invisible. See preview_for in wallpaper-switch, which
                    // seeks both to two seconds for exactly this reason.
                    //
                    // And it does come off, rather than being left to draw
                    // under an opaque picture for ever: nothing in the scene
                    // graph knows the sequence covers it, so without this the
                    // card renders the still into a texture and runs the mask
                    // shader over it again on every frame the sequence flips.
                    visible: card.frameShown === 0
                }

                // ---- A LIVE WALLPAPER ACTUALLY MOVES HERE ----
                //
                // On every card that is showing one. Everywhere else in the
                // shell a video wallpaper is the still frame ffmpeg pulled out
                // of it, because an Image cannot decode an mp4. On this surface
                // the still is a lie worth spending something on: the whole
                // question the carousel answers is "what will my desktop look
                // like", and for these files the answer moves.
                //
                // AND IT IS NOT THE WALLPAPER THAT MOVES. The collection is 4K
                // -- one file is 4K at 120 fps -- so wallpaper-switch keeps a
                // run of numbered 960 px JPEGs beside the still frames and this
                // flips through them on the sheet's shared clock. See the
                // header for why it is frames on a timer and not a video, and
                // what that was measured against.
                //
                // ON SCREEN IS NOT THE SAME AS ON THE PATH, and that distinction
                // is the whole of the condition below. pathItemCount is 7 but
                // only FIVE cards are ever visible: the two outermost nodes sit
                // past the edge of the sheet at zero opacity, which is where a
                // delegate is created and destroyed out of sight. Those two are
                // `PathView.onPath` and they are drawing nothing, so gating on
                // onPath alone would quietly hand two invisible cards a JPEG
                // decode apiece, fifteen times a second, for ever.
                //
                // The path already states which cards are visible -- that is
                // what its itemOpacity ramp to zero IS -- so this reads the
                // card's own opacity rather than inventing a second geometric
                // test that could disagree with it. A card sliding in from the
                // end node starts flipping a little before it has fully cleared
                // the frame, which is the right way round: it is on screen by
                // the time anyone can see it move.
                readonly property bool hasFrames: card.modelData.previewUrl !== ""

                readonly property bool playing: card.hasFrames
                    && WallpaperState.isOpen
                    && card.visible
                    && card.opacity > 0

                // ---- Where the sequence has got to ----
                //
                // HOW LONG THE SEQUENCE IS, DISCOVERED RATHER THAN TOLD. It
                // depends on the video -- a clip shorter than the preview
                // length yields fewer frames -- and on knobs that live in
                // wallpaper-switch and can be overridden per run. A number
                // written down here as well would be a second place for it to
                // be, and the two would disagree the first time anyone touched
                // either. So this asks for one frame past the last one that
                // loaded, and the failure IS the answer: 0 means "not found
                // yet", and it is filled in exactly once per card.
                //
                // That works only because a sequence directory is published
                // whole -- wallpaper-switch writes into `.part` and moves it
                // into place -- so a directory caught half built cannot teach
                // this card a length that is too short and have it believe that
                // for the rest of the card's life.
                property int frameCount: 0

                // What is on screen; 0 until the first frame has loaded, which
                // is what keeps the still visible underneath until then.
                property int frameShown: 0

                // What is decoding, if anything. Also the "busy" flag: one load
                // is in flight at a time, so a tick that arrives while the
                // previous frame is still being decoded is dropped rather than
                // queued. The preview runs a little slow on a slow disk instead
                // of building a backlog.
                property int framePending: 0

                // Which of the two Images below is the one being shown.
                property bool frontIsA: true

                // Set when 001.jpg itself is not there, which is any video the
                // script has not been over yet. Stops the clock rather than
                // letting it ask for a file that does not exist fifteen times a
                // second, and leaves the card on its still frame.
                //
                // NOTHING CLEARS IT IN PLACE, and that is the point to hold on
                // to. It goes when this delegate does: the bump at the end of
                // Config's thumbnail run rebuilds the entries carrying the new
                // revision, PathView is handed a model that genuinely differs,
                // and every card is built again -- this one by an object that
                // has never asked for a frame. The version of that rebuild
                // this replaces produced an identical array, which PathView
                // discards, so this flag survived the one event that exists to
                // clear it and the card stayed blank until the shell was
                // restarted. See the Connections on Config above.
                property bool framesMissing: false

                // THE ONE FRAME AHEAD OF THE ONE ON SCREEN. Two Images and not
                // one: an Image handed a new source has to decode it before it
                // can draw it, and a single Image would be showing SOMETHING
                // during that gap -- either the old frame, if Qt happens to
                // keep it, or nothing, which at fifteen flips a second reads as
                // a strobe. Loading into the hidden one and swapping when it
                // reports Ready means the visible picture only ever changes
                // from one finished frame to the next, and a slow decode costs
                // a late preview frame rather than a blank card.
                //
                // THE TICK REACHES EVERY CARD, so the decision about whether
                // this one should be moving is made HERE and only here. It used
                // to be the `running` property of a Timer per card; folding it
                // into the function is what let those five timers become one.
                function advanceFrame(): void {
                    if (!card.playing || card.framesMissing)
                        return;

                    // One load in flight at a time. A tick that arrives while
                    // the previous frame is still decoding is dropped rather
                    // than queued, so a slow disk plays the loop a little slow
                    // instead of building a backlog it can never work off.
                    if (card.framePending !== 0)
                        return;

                    const next = card.frameCount > 0
                        ? (card.frameShown % card.frameCount) + 1
                        : card.frameShown + 1;

                    const url = Config.wallpaperPreviewFrameUrl(card.modelData.previewUrl, next);
                    const back = card.frontIsA ? frameB : frameA;

                    card.framePending = next;

                    // THE FRAME WE WANT MAY ALREADY BE IN THE HIDDEN IMAGE, and
                    // then nothing will ever tell us so. The two Images hold
                    // frames two apart, so on a sequence of one or two frames
                    // the wrap lands back on the one the hidden Image is still
                    // carrying -- and assigning a source that has not changed
                    // emits no status, so the card would simply stop. Rare
                    // enough to be a fifth of a second of video, common enough
                    // that "the preview froze" would be impossible to explain.
                    if (back.source.toString() === url && back.status === Image.Ready) {
                        card.showPendingFrame();
                        return;
                    }

                    back.source = url;
                }

                function showPendingFrame(): void {
                    card.frameShown = card.framePending;
                    card.framePending = 0;
                    card.frontIsA = !card.frontIsA;
                }

                // A FRAME THAT IS NOT THERE MEANS ONE OF TWO THINGS, and they
                // are told apart by whether anything has ever loaded. Past the
                // first frame it is the end of the sequence, which is how the
                // length is learnt. On the first frame it is a video the script
                // has not built yet, and there is nothing to learn.
                function endOfSequence(): void {
                    card.framePending = 0;

                    if (card.frameShown === 0) {
                        card.framesMissing = true;
                        return;
                    }

                    card.frameCount = card.frameShown;
                }

                Connections {
                    target: root

                    function onFrameTick(): void {
                        card.advanceFrame();
                    }
                }

                // NOTHING IS CREATED OR DESTROYED WHEN YOU STEP, which is the
                // whole point of the design and the reason this is a plain Item
                // rather than the Loader it used to be. Two Images and a Timer
                // cost nothing to keep on a card that is not playing -- an
                // Image with no source is not a picture -- so stepping is a
                // property change and not a teardown.
                Item {
                    anchors.fill: parent

                    // Not drawn at all until there is a frame to draw: the
                    // still underneath is the picture until then.
                    visible: card.frameShown > 0

                    // The same mask as the still, over the same shared texture.
                    // ON THE PAIR AND NOT ON EACH, because the two Images are
                    // one picture that happens to be double buffered, and two
                    // mask passes to draw one card would be the second one
                    // running over a fully transparent image every flip.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: cardMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Image {
                        id: frameA

                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: card.frontIsA
                        // Decoded off the GUI thread. Safe here in a way it is
                        // not for a single Image, because nothing waits on it:
                        // this one is hidden until it reports Ready.
                        asynchronous: true
                        smooth: true

                        // NO sourceSize, unlike the still above. These frames
                        // are already 960 px -- the script sized them for the
                        // widest card a 1440p screen has -- so asking for a
                        // card-sized decode buys a scale pass per frame to save
                        // texture memory that is measured in kilobytes.
                        //
                        // AND NO CACHE. Qt remembers a URL that FAILED and will
                        // not go back to disk for it, and 001.jpg not existing
                        // is the ordinary state of a video added a moment ago:
                        // a pinned failure there is a card that never animates
                        // again for the rest of the session. The frames also
                        // turn over faster than any cache of this size would
                        // keep them, so there is little to give up.
                        cache: false

                        onStatusChanged: {
                            if (card.framePending === 0)
                                return;

                            if (frameA.status === Image.Ready)
                                card.showPendingFrame();
                            else if (frameA.status === Image.Error)
                                card.endOfSequence();
                        }
                    }

                    Image {
                        id: frameB

                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: !card.frontIsA
                        asynchronous: true
                        smooth: true
                        cache: false

                        onStatusChanged: {
                            if (card.framePending === 0)
                                return;

                            if (frameB.status === Image.Ready)
                                card.showPendingFrame();
                            else if (frameB.status === Image.Error)
                                card.endOfSequence();
                        }
                    }
                }

                // A CARD THAT LEAVES THE SCREEN LETS GO OF ITS FRAMES. The
                // sources are what hold two decoded pictures alive, and the
                // fan is a conveyor -- every step pushes one card off each end
                // -- so without this the two parked slots would each sit on a
                // pair of full-size pictures nobody can see. Coming back starts
                // again from 001, which is also where the still frame is, so
                // there is nothing to see in the restart.
                onPlayingChanged: {
                    // ASK FOR THE FIRST FRAME AT ONCE. The shared clock is up
                    // to a fifteenth of a second away, and a card that slides
                    // into the fan and then visibly waits before it starts is
                    // the kind of hitch this whole design exists to remove.
                    // This is what the per-card Timer's triggeredOnStart used
                    // to do.
                    if (card.playing) {
                        card.advanceFrame();
                        return;
                    }

                    // The pending load is dropped FIRST. Clearing a source
                    // while one is in flight moves that Image to Null rather
                    // than to Error, so nothing here would misread it -- but
                    // the handlers below only have to be right about states
                    // that can reach them, and this is what keeps that true.
                    card.framePending = 0;
                    card.frameShown = 0;
                    card.frontIsA = true;
                    frameA.source = "";
                    frameB.source = "";
                }

                // The frame IS the selection: a thumbnail is already a picture,
                // so tinting it would fight the image itself. Drawn OVER the
                // masked image and at the same radius, so the ring sits exactly
                // on the cut edge.
                //
                // Every card gets a hairline, and that is not decoration: a
                // dark photograph over a blurred dark desktop has no edge at
                // all without one.
                Rectangle {
                    anchors.fill: parent
                    radius: root.cardRadius
                    color: "transparent"
                    antialiasing: true

                    border.width: card.centred ? 3 : 1
                    border.color: card.centred ? Theme.primary : Qt.alpha(Theme.outline, 0.6)

                    Behavior on border.width {
                        NumberAnimation { duration: Theme.animDuration }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // ONE CLICK MEANS TWO THINGS depending on where the card
                    // is, and they are the same gesture people already use on a
                    // carousel: clicking one off to the side brings it to the
                    // middle, and clicking the one in the middle applies it.
                    // The alternative -- apply whatever is clicked -- makes the
                    // fan a minefield, since the neighbours are half covered by
                    // the card you were aiming past.
                    onClicked: {
                        if (card.centred)
                            root.apply(card.modelData);
                        else
                            view.currentIndex = card.index;
                    }
                }
            }
        }

        // ---------------- What you are looking at ----------------
        //
        // Under the fan, and only for the centred card: the picture is the
        // subject, and a name under every one of them would be a row of labels
        // competing with the photographs for the eye. The name is here to tell
        // two similar images apart and to be searchable in the folder later,
        // nothing more.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(sheet.height * 0.47 + root.cardHeight / 2 + 28)

            spacing: 4
            visible: root.count > 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: root.entries[view.currentIndex]?.name ?? ""
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 2
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // The one fact the fan cannot draw. Which wallpaper is on the
            // desktop is not visible in a row of pictures -- the desktop is
            // behind the sheet, blurred -- and it is the difference between
            // "browse" and "go back to what I had".
            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                visible: root.entries[view.currentIndex]?.path === root.currentPath
                text: "Applied"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.primary

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // An empty folder gets a sentence rather than a blank screen. It names
        // the folder because nothing else on this sheet does, and because the
        // answer is almost always "the collection is somewhere else" -- which
        // is a setting, in the window this line points at.
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: root.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `No wallpapers in ${Config.wallpaperDir.replace(Quickshell.env("HOME"), "~")}`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 2
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Point the collection somewhere else in Settings, Wallpaper"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.textOnSurfaceVariant
            }
        }
    }
}
