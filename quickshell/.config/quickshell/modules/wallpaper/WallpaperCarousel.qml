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
// keeping: about 7% of one core over the shell's idle, with the centred card
// playing. Nearly all of the work that used to be there was self-inflicted --
// decoding 4K originals to fill card-sized thumbnails, a live layer per card
// feeding the corner mask, and playing the 4K wallpaper itself. See the
// thumbnail cache in Config, the shared mask below, and root.atRest.
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
// The player for a live wallpaper. NOT a Quickshell module -- it is Qt's own,
// from qt6-multimedia, which is a hard dependency of this file and of nothing
// else in the shell.
import QtMultimedia
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
                // NOT THE WALLPAPER ITSELF but the small copy of it that
                // wallpaper-switch keeps beside the still frames: 960x540 at
                // 24 fps against a 4K original at up to 120.
                //
                // EMPTY FOR A STILL, and empty for nothing else: this is the
                // name the clip WOULD have, worked out from the extension, and
                // nothing here goes to disk to find out whether it is there. A
                // video whose clip has not been built yet gets a player
                // pointed at a file that does not exist, which is what the
                // error handler below is for.
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
            // Opening counts as movement: the fan is landing on the applied
            // wallpaper and the players should start after it has, not during.
            // This also covers the case where positionViewAtIndex has nothing
            // to do because the view was already there -- currentIndex never
            // changes, so nothing else here would ever start the wait.
            root.stir();
        }
    }

    // A video listed before its frame has been extracted has nothing to draw.
    // Rebuilding on the bump replaces the entry objects, which is what gets the
    // delegates to ask for the file a second time.
    Connections {
        target: Config

        function onWallpaperThumbsRevisionChanged(): void {
            root.rebuild();
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
        if (root.currentPath === "")
            return;

        const i = root.entries.findIndex(e => e.path === root.currentPath);
        if (i >= 0)
            view.positionViewAtIndex(i, PathView.Center);
    }

    // ---------------- Is the fan moving? ----------------
    //
    // NOTHING DECODES WHILE YOU ARE MOVING, and this property is the whole of
    // that rule. It is the difference between a carousel that scrolls and one
    // that drags.
    //
    // WHY, measured rather than guessed: the decoding itself lands on the
    // GPU -- the h264 threads sit at nearly nothing and NVDEC does the work --
    // but the frames come back to the process' MAIN thread to be turned into
    // textures, and that is the same thread that runs this view's animation.
    // Five previews playing put 25 to 40% of a core on it. The animation gets
    // whatever is left, which is what "it sticks when I move through the
    // videos" was.
    //
    // So a keypress PAUSES every player, the movement has the thread to itself,
    // and the pictures start moving again once the fan is still. A paused
    // player keeps its last frame on screen, so a card freezes and thaws
    // rather than going blank.
    //
    // PAUSED AND NOT DESTROYED, which was the first version of this and was
    // measurably worse than the problem: tearing down five decoders at every
    // keypress and building them again a fifth of a second later put the
    // process over a full core while walking the fan. Pausing costs nothing on
    // either side of the gesture. What this flag ALSO does is hold back the
    // creation of new players -- a card sliding into the fan waits for the
    // movement to end before it gets a decoder -- so the only thing a step can
    // cost is the teardown of the one card that left.
    property bool atRest: true

    Timer {
        id: settle

        // Longer than highlightMoveDuration (90 ms) so the animation is
        // genuinely finished, short enough that stopping on a live wallpaper
        // feels like it starts by itself.
        interval: 180
        onTriggered: root.atRest = true
    }

    function stir(): void {
        root.atRest = false;
        settle.restart();
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

        // The wheel walks the fan. PathView has no wheel handling of its own --
        // it is the flicking, not the scrolling, that it implements.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                if (event.angleDelta.y < 0 || event.angleDelta.x > 0)
                    view.incrementCurrentIndex();
                else
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

            // Every step pauses the players and starts the wait. See atRest.
            onCurrentIndexChanged: root.stir()

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

                onModelDataChanged: card.thumbMissing = false

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
                    // making.
                    //
                    // The trap the rest of the shell avoids with a blanket
                    // `cache: false` is that Qt remembers a URL that FAILED to
                    // load and will not go back to disk for it, and the cache
                    // key -- URL plus size -- does not change when the file
                    // finally appears. A video dropped into the collection is
                    // listed before ffmpeg has pulled a frame out of it, and a
                    // pinned failure there is a card that stays BLANK for the
                    // rest of the session, with no second picture to fall back
                    // to. So videos keep asking.
                    //
                    // A still cannot go blank: its thumbnail failing drops it
                    // to the wallpaper itself, which is slower but is the
                    // right picture, and the next run of the shell finds the
                    // thumbnail built. Against that, caching is what keeps the
                    // fan from decoding the same handful of files over and
                    // over as it turns -- measured at roughly half the cost of
                    // the carousel with it on.
                    cache: !card.modelData.video

                    // NO `layer.enabled`, unlike every other masked image in
                    // this shell. An Image is already a texture provider, so
                    // MultiEffect can sample it directly; turning on a layer
                    // wraps it in a SECOND texture that is re-rendered from the
                    // image on every frame the window draws -- which, with a
                    // video playing anywhere on the sheet, is every frame.
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: picture
                    maskEnabled: true
                    maskSource: cardMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0

                    // OFF ONCE THE VIDEO HAS FINISHED FADING IN, and not one
                    // frame before: the video covers this exactly, edge to
                    // edge and corner to corner, but while it is still
                    // translucent this is what shows through it. Hiding it at
                    // the START of the fade -- which is what testing whether
                    // the player is showing amounts to -- makes the card dip
                    // towards the sheet behind it and back, which is the flash
                    // the fade exists to remove.
                    //
                    // And it does come off, rather than being left to draw
                    // under an opaque video for ever: nothing in the scene
                    // graph knows the video covers it, so without this the card
                    // renders the still into a texture and runs the mask shader
                    // over it on every frame the video delivers.
                    visible: player.cover < 0.99
                }

                // A LIVE WALLPAPER ACTUALLY MOVES HERE, on the card in the
                // middle. Everywhere else in the shell a video wallpaper is
                // the still frame ffmpeg pulled out of it, because an Image
                // cannot decode an mp4. On this surface the still is a lie
                // worth spending a decoder on: the whole question the carousel
                // answers is "what will my desktop look like", and for these
                // files the answer moves.
                //
                // AND IT IS NOT THE WALLPAPER THAT PLAYS. The collection is 4K
                // -- one file is 4K at 120 fps -- and one of those measured
                // about two thirds of a core on its own. wallpaper-switch
                // keeps a 960x540 copy of every video beside the still frames,
                // and twelve seconds of one of those decodes in a third of a
                // second of CPU.
                //
                // A LOADER AND NOT A `playing` FLAG, so the player is
                // DESTROYED when the card leaves the middle or the sheet
                // closes. A paused MediaPlayer still holds its decoder and its
                // file open, and this window spends most of its life
                // invisible.
                //
                // The still underneath is left in place rather than hidden: it
                // is the poster while the first frame is being decoded, and it
                // is the whole picture for a video whose preview has not been
                // built yet -- a file dropped into the collection a moment ago
                // plays the next time the carousel is opened.
                // -------- Which card carries a decoder --------
                //
                // THE CARD IN THE MIDDLE AND NOTHING ELSE, and that was
                // measured rather than assumed. Playing all five cost the same
                // as playing one -- around two thirds of a core either way --
                // because the price is not the decoding, which happens on the
                // GPU: it is that a moving picture anywhere in this window
                // makes the whole window repaint, and the window is the
                // screen. Five moving cards buy four more animations for
                // nothing, and they buy them on the same thread that has to
                // animate the fan.
                //
                // So the middle card moves and the other four are the still
                // frame, which is also how every carousel that plays anything
                // behaves.
                readonly property bool inFan: card.modelData.previewUrl !== ""
                    && WallpaperState.isOpen
                    && card.PathView.onPath

                readonly property bool wantsVideo: card.inFan && card.centred

                // A LAST BEAT AFTER THE FAN HAS STOPPED. Creating a player is
                // a decoder, a handful of threads and a CUDA context, and doing
                // that in the same frame the animation finishes in is a visible
                // stall -- it was the "it sticks for a moment when I open it on
                // a video". A tenth of a second later, the animation is over
                // and nothing is competing with it.
                Timer {
                    id: warmup

                    interval: 100
                    onTriggered: player.wanted = true
                }

                // NOTHING IS CREATED *OR* DESTROYED WHILE THE FAN IS MOVING,
                // and the second half of that was a bug worth naming: tearing
                // the player down is as expensive as building it -- a decoder,
                // its threads and a CUDA context all go at once -- and doing it
                // at the first keypress put that cost inside the very animation
                // it was supposed to protect. Stepping off a playing card was
                // heavy while stepping between still ones was smooth, which is
                // exactly what it looked like.
                //
                // So a step only PAUSES what is playing (see root.atRest), and
                // this function does nothing at all until the fan is still
                // again. The one exception is a card that has left the fan
                // altogether, or the sheet closing: then the player has to go
                // whatever else is happening, because the card it belongs to is
                // about to be destroyed under it.
                function syncPlayer(): void {
                    if (!card.inFan) {
                        warmup.stop();
                        player.wanted = false;
                        return;
                    }

                    if (!root.atRest)
                        return;

                    if (!card.wantsVideo) {
                        warmup.stop();
                        player.wanted = false;
                        return;
                    }

                    // Already carrying one: nothing to do, and restarting the
                    // timer here would be a way to never actually start.
                    if (!player.wanted)
                        warmup.restart();
                }

                onWantsVideoChanged: card.syncPlayer()
                onInFanChanged: card.syncPlayer()

                // A card that comes into existence already eligible never
                // fires the handler above.
                Component.onCompleted: card.syncPlayer()

                Connections {
                    target: root

                    function onAtRestChanged(): void {
                        card.syncPlayer();
                    }
                }

                Loader {
                    id: player

                    // Set by the timer above rather than bound to wantsVideo,
                    // which is the point of the timer: the decision to carry a
                    // decoder is deferred, the decision to drop one is not.
                    property bool wanted: false

                    anchors.fill: parent

                    active: player.wanted

                    // What the still underneath is being crossfaded out by.
                    // Read as a number rather than a boolean because the fade
                    // is what decides when the still stops being drawn.
                    readonly property real cover: player.item?.opacity ?? 0

                    sourceComponent: Item {
                        // NOT A SWAP, A CROSSFADE. The still is the frame two
                        // seconds into the video and the preview starts at that
                        // same second, so the two pictures are nearly the same
                        // -- but "nearly" over an abrupt swap is exactly what
                        // reads as a flash. A quarter of a second of fade turns
                        // it into the picture simply starting to move.
                        opacity: showing ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Republished for the card outside: a Loader's
                        // component has its own scope and nothing out there
                        // can reach an id declared in here.
                        // Paused counts as showing: the player keeps its last
                        // frame on screen, and swapping back to the still under
                        // it at every keypress would be a flicker on the whole
                        // fan for nothing.
                        readonly property bool showing: media.hasVideo
                            && media.playbackState !== MediaPlayer.StoppedState

                        anchors.fill: parent

                        VideoOutput {
                            id: output

                            anchors.fill: parent
                            // Crop to fill, exactly like the still under it and
                            // like mpvpaper's own panscan=1.0 on the desktop.
                            // Letterboxing here would show a shape the
                            // wallpaper will never have.
                            fillMode: VideoOutput.PreserveAspectCrop

                            visible: false
                            layer.enabled: true
                        }

                        MediaPlayer {
                            id: media

                            source: card.modelData.previewUrl
                            videoOutput: output
                            loops: MediaPlayer.Infinite
                            // NO AudioOutput, deliberately. Leaving the
                            // property unset is what mutes it: a picker that
                            // makes noise is a picker nobody opens twice, and
                            // the wallpaper itself is started with --no-audio
                            // for the same reason. The preview clips are
                            // written without an audio track at all, so this
                            // is the second of two locks on the same door.

                            // Playing is what costs -- every frame goes to the
                            // main thread to become a texture -- so it happens
                            // only while the fan is still. See root.atRest.
                            Component.onCompleted: if (root.atRest)
                                media.play()

                            // A CLIP THAT IS NOT THERE. The preview is built
                            // in the background, so a video added to the
                            // collection a moment ago has a name here and no
                            // file behind it. Dropping the player rather than
                            // leaving it to retry is what keeps the card on
                            // its still frame -- and the still, unlike a
                            // failed player, is a picture.
                            onErrorOccurred: (error, message) => {
                                player.wanted = false;
                            }
                        }

                        // OUTSIDE the MediaPlayer and not in it: MediaPlayer is
                        // not an Item and has no default property, so a child
                        // declared inside it fails to load the whole file --
                        // with "cannot assign to non-existent default
                        // property", which does not say that.
                        Connections {
                            target: root

                            function onAtRestChanged(): void {
                                if (root.atRest)
                                    media.play();
                                else
                                    media.pause();
                            }
                        }

                        // The same mask as the still, over the same Rectangle:
                        // a VideoOutput is as rectangular as an Image and its
                        // square corners would poke out past the card exactly
                        // the same way.
                        MultiEffect {
                            anchors.fill: parent
                            source: output
                            maskEnabled: true
                            maskSource: cardMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }
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
