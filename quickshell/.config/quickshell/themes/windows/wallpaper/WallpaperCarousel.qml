// The wallpaper picker: Personalisation, Background -- a grid of thumbnails
// over a dimmed desktop.
//
// A GRID AND NOT A COVERFLOW, WHICH IS THE WHOLE OF THE REDRAW. genesis puts
// the collection on a curve with the candidate blown up in the middle, and
// argues for it: a carousel answers "what do I want next", one picture at a
// time. That is a good answer to a different question than the one Windows
// asks. Windows' Background page is a grid of small, equal thumbnails with the
// applied one ringed in the accent -- it answers "which of these is on my
// desktop, and which do I want instead" in one look, and every tile is the same
// size because none of them is privileged until you pick it.
//
// SO THE FAN IS GONE, AND SO IS EVERYTHING THAT EXISTED TO SERVE IT: the
// PathView and its seven PathAttribute nodes, the scale ramp, the stacking
// order, the two off-screen slots a delegate was created and destroyed in, and
// the click that meant "bring this one to the middle" rather than "use this
// one". In a grid a click means apply, which is what a click on a Windows
// thumbnail means.
//
// AND THE LIVE PREVIEW WENT WITH IT, which is the one loss worth arguing rather
// than announcing. genesis flips through numbered JPEGs on every card showing a
// video wallpaper, and its header carries the measurements that justified it:
// five cards flipping cost 29.8% of a core against 5.1% for five stills, which
// is affordable when there are five cards. A grid shows twenty or more at once
// and the cost is per card, so the same design here is a picker that spends a
// core and a half to animate thumbnails the size of a business card. Windows'
// own Recent-images grid is still frames. The frame sequences wallpaper-switch
// writes are not wasted -- genesis still plays them, and this file still points
// its tiles at the same cached still frame ffmpeg pulled out of each video.
//
// WHAT DID NOT CHANGE, and must not:
//
//   - `wallpaper-switch set <path>`, spawned as a list and never through a
//     shell. The script is what also regenerates the palette and pushes the new
//     accent into the compositor; awww alone would change the picture and
//     nothing else.
//   - The reset-on-open block. A theme swap does not replay it, so opening on
//     the applied wallpaper, and asking for thumbnails a new file has none of
//     yet, have to be right in this file.
//   - The folder listing's guard, and that it is driven from `status` rather
//     than `count`. A rename changes every path and leaves the count alone;
//     tests/qml-rules.sh has a rule about it and this is the file that rule was
//     written for.
//
// NO qs.components AT ALL, and that stays true. This surface draws its own
// scrolling -- a GridView, which clips and flicks on its own -- rather than
// reaching for ScrollList, and there is no scroll bar over a grid of pictures
// because the pictures themselves are the position indicator.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel
import QtQuick.Effects
import qs
import qs.modules.wallpaper
// Fluent lives one directory up, and without this line the failure is at
// runtime, per read: "ReferenceError: Fluent is not defined".
import ".."

PanelWindow {
    id: root

    // The ShellScreen this picker belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- How big the page is allowed to be ----------------
    //
    // OURS, and the same 60 the cheatsheet keeps for the same reason: it is the
    // breathing room a window wants around itself so that it reads as laid over
    // the desktop rather than as a new desktop.
    readonly property int screenMargin: 60

    readonly property int availableWidth: Math.max(0, (root.modelData?.width ?? 0) - root.screenMargin * 2)
    readonly property int availableHeight: Math.max(0, (root.modelData?.height ?? 0) - root.screenMargin * 2)

    // SettingsCardPadding, the same page inset the cheatsheet takes.
    readonly property int cardPadding: Fluent.cardPadding

    readonly property int contentRoom: Math.max(0, root.availableWidth - root.cardPadding * 2)

    // NO MaxWidth HERE, unlike the cheatsheet, and the difference is deliberate.
    // The Toolkit's 1000 is what keeps a page of TEXT to a line length somebody
    // can track back from; a grid of pictures has no line to track and capping
    // it would throw away the columns a wide monitor is for.

    // ---------------- A tile ----------------
    //
    // A TILE IS A SCALE MODEL OF THE MONITOR, so its aspect comes from the
    // screen rather than from a number here. Cropping a 16:9 desktop wallpaper
    // into a squarer tile would be showing a picture that is not the one being
    // chosen.
    readonly property real screenAspect: (root.modelData?.width ?? 16) / (root.modelData?.height ?? 9)

    // OURS. Microsoft publishes no tile size for the Personalisation grid. A
    // sixth of the screen's width is what puts five tiles across the 2560-wide
    // monitor this was drawn on -- which is what that page shows -- and fewer,
    // rather than narrower ones, on the portrait screen beside it.
    readonly property int tileTarget: Math.round((root.modelData?.width ?? 1920) * 0.16)

    // SettingsCardSpacing: the gap Windows leaves between two cards, which is
    // what a tile is. It is used as the tile's INSET inside its cell, so the gap
    // between two pictures is twice it and the backplate that lights up on hover
    // is the frame it leaves around each one.
    readonly property int tileInset: Theme.groupSpacing

    readonly property int columns: {
        if (root.contentRoom <= 0)
            return 1;
        return Math.max(1, Math.floor(root.contentRoom / root.tileTarget));
    }

    readonly property int cellWidth: Math.floor(root.contentRoom / root.columns)
    readonly property int thumbWidth: Math.max(1, root.cellWidth - root.tileInset * 2)
    readonly property int thumbHeight: Math.max(1, Math.round(root.thumbWidth / root.screenAspect))
    readonly property int cellHeight: root.thumbHeight + root.tileInset * 2

    // ONE READ INSTEAD OF TWO, for the delegate. Every read of an id from
    // outside a delegate is a read qmllint cannot check, so the two numbers a
    // tile needs to decode its picture at travel as one value.
    readonly property size thumbSize: Qt.size(root.thumbWidth, root.thumbHeight)

    // ---------------- The collection ----------------
    //
    // Read with Qt's FolderListModel: Quickshell has no directory API, and
    // shelling out to `ls` for something the toolkit already does would be a
    // process and a parser for no gain.
    //
    // Copied out into an array rather than fed to the view directly, because the
    // entries carry a thumbnail URL that FolderListModel knows nothing about --
    // see rebuild() -- and because finding the applied wallpaper's index means
    // walking the list.
    //
    // EVERY FIELD IS A PURE FUNCTION OF THE PATH, and it has to stay that way.
    // An entry describes a wallpaper; it must not describe the state of the
    // thumbnail cache, however convenient that is for getting a tile to look at
    // a file again. Assigning this array is not free and is not quiet: a view
    // handed a model it considers different destroys and rebuilds every
    // delegate, each of which re-decodes its picture, and it resets the current
    // index on the way.
    //
    // Config.wallpaperThumbsRevision in here is the specific mistake, because it
    // looks like it costs nothing and it bumps on EVERY opening -- the open
    // calls refreshWallpaperThumbs() and the process bumps when it exits whether
    // it wrote a file or not. Measured offscreen on Qt 6.11.2, on a fan of eight
    // already up and settled: with the revision in the entry, the bump rebuilt 8
    // of 8 delegates and re-set 8 of 8 image sources, which is a flash on screen
    // every time the picker is opened. Without it, 0 and 0. The cache tells the
    // TILES it has changed, in the delegate's Connections on Config, and never
    // the model.
    property var entries: []

    readonly property int count: root.entries.length

    // What the last accepted `entries` was built from, as one string: every path
    // in listing order, NUL-separated so a filename cannot fake a boundary. It
    // is a guard and not a cache -- see rebuild().
    property string listing: ""

    // Rebuild `entries` from the folder, and say whether that changed anything.
    // FALSE MEANS THE CALLER SHOULD DO NOTHING ELSE: no thumbnail run, no
    // re-reveal.
    //
    // THE GUARD IS THE POINT, not a saving. The signal this is driven from fires
    // for events that leave the listing exactly as it was -- `touch` on a
    // wallpaper, a rename of some unrelated file that the filters do not even
    // match -- and assigning `entries` is the expensive, visible thing described
    // above. Measured on Qt 6.11.2 over one directory: startup plus five real
    // changes rebuild six times with this in place, and a `touch` rebuilds not
    // at all.
    function rebuild(): bool {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const path = folder.get(i, "filePath");
            out.push({
                name: folder.get(i, "fileName").replace(/\.[^.]+$/, ""),
                path: path,
                video: Config.isWallpaperVideo(path),
                // NEVER the wallpaper itself: a cached thumbnail for a still,
                // the extracted frame for a video. See the note on
                // Config.wallpaperThumb -- the short version is that decoding a
                // 4K PNG to fill a tile costs a fifth of a second.
                thumbUrl: Config.wallpaperThumbUrl(path),
                // Where to go when that file is not there, which is any
                // collection the script has not been over yet. Only for stills:
                // an Image pointed at an mp4 fails just as hard as one pointed
                // at nothing.
                fullUrl: Config.isWallpaperVideo(path) ? "" : Config.wallpaperFullUrl(path)
            });
        }

        const listing = out.map(entry => entry.path).join("\u0000");
        if (listing === root.listing)
            return false;

        root.listing = listing;
        root.entries = out;
        return true;
    }

    FolderListModel {
        id: folder

        // From Config and not a literal here: the folder is a setting, and the
        // settings page lists the same collection. A copy of the path in each of
        // them is how one of the two silently stops agreeing with the other.
        folder: `file://${Config.wallpaperDir}`
        nameFilters: Config.wallpaperNameFilters
        showDirs: false
        sortField: FolderListModel.Name

        // FROM `status` AND NOT FROM `count`, and the difference is a whole
        // class of bug rather than a preference.
        //
        // The model fills asynchronously, so the array cannot be built at
        // construction; something has to say when the listing is ready. Count
        // was that something, and it is blind in exactly one direction: a RENAME
        // changes every path in the folder and leaves the number of files alone,
        // so `countChanged` never fires. The list kept the old name and never
        // learned the new one, and the tile for the old name went blank -- the
        // thumbnail run sweeps the cache entry for a file that is no longer
        // there, and the fallback to the original is a path that no longer
        // exists either. Adding or deleting anything at all put it right, which
        // is a fine description of a bug and no way to use a picture folder.
        //
        // Measured on Qt 6.11.2, every mutation of the directory -- rename, add,
        // remove, a file renamed out of the filters -- produces exactly one
        // `Loading` -> `Ready` cycle, about a millisecond after the event, and
        // the rows are fully up to date by the time `Ready` arrives. Renames
        // emit `dataChanged` and nothing else; adds and removes emit a
        // remove-all/insert-all PAIR, which is why the row signals are not used
        // here either -- they would fire this twice for one change.
        //
        // `Ready` also arrives for events that changed nothing visible, and
        // rebuild()'s guard is what absorbs those.
        onStatusChanged: {
            if (folder.status !== FolderListModel.Ready)
                return;
            if (!root.rebuild())
                return;

            // Only now, and not on every `Ready`: this spawns ffmpeg over the
            // whole collection to give a new file the cached thumbnail it has
            // none of yet, and to sweep the entries of files that have gone.
            Config.refreshWallpaperThumbs();
            if (WallpaperState.isOpen)
                Qt.callLater(root.revealCurrent);
        }
    }

    // ---------------- What is applied right now ----------------
    //
    // A READING, NOT A CONTROL -- the same one the settings page takes, from the
    // same file. wallpaper-switch writes it after the backend has accepted the
    // image, so the ring below lands about a crossfade after the click and does
    // not move at all if the script failed.
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
        // A machine that has never changed its wallpaper has no state file. That
        // is a first run, not an error to print on every launch.
        printErrors: false
    }

    // OPEN ON THE ONE THAT IS APPLIED. Without this the picker opens wherever it
    // was left, which for the common case -- open it, look, change your mind,
    // Escape -- means it opens somewhere arbitrary and the first thing you have
    // to do is find your way back.
    //
    // positionViewAtIndex and not a scroll: at open time there is nothing to
    // animate past, and a grid that visibly scrolls itself into place is a lot
    // of movement to say "nothing has changed yet".
    function revealCurrent(): void {
        if (root.currentPath === "")
            return;

        const i = root.entries.findIndex(e => e.path === root.currentPath);
        if (i >= 0) {
            grid.currentIndex = i;
            grid.positionViewAtIndex(i, GridView.Contain);
        }
    }

    function apply(entry: var): void {
        if (!entry)
            return;

        // Close first, so the crossfade happens on the desktop rather than
        // behind a sheet that is on its way out.
        WallpaperState.close();
        // wallpaper-switch and not awww: the script is what also regenerates the
        // palette and pushes the new accent into the compositor. Applying the one
        // already on screen is not a no-op either -- it reapplies, which is the
        // way back after a matugen template has been edited.
        Quickshell.execDetached(["wallpaper-switch", "set", entry.path]);
    }

    screen: modelData
    visible: WallpaperState.isOpen

    WlrLayershell.namespace: "quickshell-wallpaper"
    // Overlay and not Top: this covers the taskbar and a fullscreen window
    // alike.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, or the arrows, Enter and Escape never reach us: a layer surface
    // that does not hold the keyboard is not sent a keystroke at all. Stated
    // once and never flipped, like every other grabbing surface here --
    // `visible` already tears the whole surface down when the sheet is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring all
    // four edges stretches the layer surface instead, and then the size the
    // compositor picked is not a size QML ever sees. Same as PowerMenu.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's reservation:
    // the sheet covers the taskbar rather than starting above it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    // THE RESET-ON-OPEN BLOCK. A theme swap does not replay it, so everything an
    // opening has to put right lives here rather than anywhere a swap could
    // skip.
    Connections {
        target: WallpaperState

        function onIsOpenChanged(): void {
            if (!WallpaperState.isOpen)
                return;

            sheet.forceActiveFocus();
            // A video added to the folder since the last look has no frame yet.
            Config.refreshWallpaperThumbs();
            // Deferred: the view has just been made visible and has nothing laid
            // out for positionViewAtIndex to position.
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

        // SmokeFillColorDefault -- see PowerMenu.qml for the source and for why
        // it is the one hex literal in this theme. 0x4D is 0.30, under the
        // compositor's 0.84 ignore_alpha, so this fill is left out of the blur
        // and the desktop behind it stays sharp. Which matters more here than
        // anywhere else in the theme: the thing behind this sheet is the
        // wallpaper you are about to replace, and blurring it would hide the one
        // picture the surface exists to compare against.
        color: "#4D000000"

        focus: true

        Keys.onEscapePressed: WallpaperState.close()
        Keys.onLeftPressed: grid.moveCurrentIndexLeft()
        Keys.onRightPressed: grid.moveCurrentIndexRight()
        Keys.onUpPressed: grid.moveCurrentIndexUp()
        Keys.onDownPressed: grid.moveCurrentIndexDown()
        Keys.onReturnPressed: root.apply(root.entries[grid.currentIndex])
        Keys.onEnterPressed: root.apply(root.entries[grid.currentIndex])
        Keys.onPressed: event => {
            // Home row for the same four moves, since the rest of the session is
            // driven that way, and the key that opened it closes it -- a bare W,
            // because while the sheet holds the keyboard the compositor bind
            // still fires but the reflex once you are looking at it is the letter
            // on its own. Same argument the cheatsheet makes for "/".
            if (event.key === Qt.Key_H)
                grid.moveCurrentIndexLeft();
            else if (event.key === Qt.Key_L)
                grid.moveCurrentIndexRight();
            else if (event.key === Qt.Key_K)
                grid.moveCurrentIndexUp();
            else if (event.key === Qt.Key_J)
                grid.moveCurrentIndexDown();
            else if (event.key === Qt.Key_W)
                WallpaperState.close();
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. It sits BELOW the card in the file, so the
        // card takes its own clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: WallpaperState.close()
        }

        // ---------------- One mask, rendered once ----------------
        //
        // EVERY TILE IS THE SAME SIZE, so the rounded rectangle that cuts the
        // corners off a picture is identical for all of them and there is no
        // reason for one copy per tile.
        //
        // AND IT COST A GREAT DEAL MORE THAN A FEW RECTANGLES. Measured with the
        // carousel this replaces open and NOTHING moving: 24% of a core with a
        // live layer per card, 7% -- the shell's idle -- without them. Two live
        // layers and an effect per card keep marking each other dirty, so the
        // whole screen re-rendered at the refresh rate to draw pictures that were
        // not changing. A grid has more tiles than that fan had cards, so the
        // saving is larger here, not smaller.
        //
        // A ShaderEffectSource with live: false is what breaks that: it renders
        // its source once, hands the same texture to every tile for ever after,
        // and asks for nothing else until the geometry changes.
        Item {
            id: maskShape

            width: root.thumbWidth
            height: root.thumbHeight
            visible: false

            Rectangle {
                anchors.fill: parent
                // ControlCornerRadius: a thumbnail is an in-page element, and
                // in-page elements are 4. The 8 is for the window it sits in.
                radius: Fluent.controlRadius
                antialiasing: true
                color: "black"
            }
        }

        ShaderEffectSource {
            id: cardMask

            sourceItem: maskShape
            width: root.thumbWidth
            height: root.thumbHeight
            hideSource: true
            live: false
            visible: false

            // RENDERED ONCE IS NOT RENDERED FOR EVER, and this is the bill for
            // `live: false`. Hiding the sheet destroys its layer surface and with
            // it the scene graph resources behind it -- this texture included --
            // and a source that is not live never asks for another one. The mask
            // came back EMPTY on the second opening, and an empty mask means
            // MultiEffect cuts away everything it is given: tiles with a border
            // and no picture inside them.
            //
            // So it is scheduled on every opening, and on the two other things
            // that can change under it: a different monitor, and so a different
            // tile size.
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

        // ---------------- The page ----------------
        Rectangle {
            id: card

            anchors.centerIn: parent

            implicitWidth: root.contentRoom + root.cardPadding * 2
            implicitHeight: Math.min(layout.implicitHeight + root.cardPadding * 2,
                                     root.availableHeight)

            // OverlayCornerRadius, which is the 8 Windows gives a window.
            radius: Fluent.overlayRadius

            // MICA. Its documented fallback is SolidBackgroundFillColorBase
            // #202020, which is exactly windows-11-dark's ui_surface, and the
            // blur-quickshell rule in hyprland.lua is xray -- it samples the
            // wallpaper and not the windows in front of it, which is what Mica
            // does. Theme.glass() and not an alpha chosen here: the rule ignores
            // anything under 0.84.
            color: Theme.glass(Theme.surface)

            border.width: 1
            border.color: Theme.outlineVariant
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            // Swallows clicks that would otherwise reach the dismiss area behind
            // the card.
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: layout

                anchors.centerIn: parent
                width: root.contentRoom
                spacing: root.cardPadding

                // ---------------- The page title ----------------
                Column {
                    id: header

                    width: parent.width
                    spacing: 2

                    Text {
                        text: "Background"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.titleSize
                        font.weight: Fluent.strongWeight
                        color: Theme.textOnSurface

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }

                    // THE ONE FACT THE GRID CANNOT DRAW BY ITSELF: which picture
                    // you are pointing at, by name. The tiles are deliberately
                    // unlabelled -- a caption under every one of twenty
                    // thumbnails is a wall of text competing with the pictures --
                    // so the name of the highlighted one is said once, here,
                    // where a Settings page puts its description.
                    Row {
                        spacing: 6
                        visible: root.count > 0

                        Text {
                            text: root.entries[grid.currentIndex]?.name ?? ""
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.bodySize
                            font.weight: Fluent.normalWeight
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Text {
                            visible: root.entries[grid.currentIndex]?.path === root.currentPath
                            text: "Applied"
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.bodySize
                            font.weight: Fluent.strongWeight
                            color: Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }
                }

                // ---------------- The grid ----------------
                GridView {
                    id: grid

                    visible: root.count > 0

                    width: parent.width
                    // As tall as the tiles want, up to what is left of the
                    // screen once the card has had its padding and the title its
                    // room. Where the collection is shorter than that, the card
                    // shrinks to it and nothing scrolls.
                    height: Math.min(grid.contentHeight,
                                     root.availableHeight - root.cardPadding * 2
                                         - header.height - layout.spacing)

                    model: root.entries
                    cellWidth: root.cellWidth
                    cellHeight: root.cellHeight
                    clip: true

                    // The wheel and the drag are the view's own, which is the
                    // reason this is a GridView rather than a Row of transforms:
                    // a Flickable takes wheel events whatever device type the
                    // seat reports, where a WheelHandler has to be told, and
                    // there is no scroll bar to place because a grid of pictures
                    // is its own position indicator.
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: tile

                        required property int index
                        required property var modelData

                        readonly property bool applied: tile.modelData.path === root.currentPath

                        // Set when the thumbnail turned out not to exist, which
                        // drops this tile back to the wallpaper itself. Reset
                        // when the tile is handed a different wallpaper: the
                        // delegates are recycled as the grid scrolls, and a tile
                        // that inherited this flag would load a 4K original for a
                        // thumbnail that is perfectly fine.
                        property bool thumbMissing: false

                        width: tile.GridView.view.cellWidth
                        height: tile.GridView.view.cellHeight

                        onModelDataChanged: tile.thumbMissing = false

                        // AND THE OTHER WAY A TILE LEARNS SOMETHING IT GOT WRONG:
                        // the file it asked for was not there at the time, and
                        // now it is.
                        //
                        // An Image pointed at a missing file reports Error and
                        // stops; the flag above latches that so the tile does not
                        // spend the session asking. wallpaper-switch builds the
                        // thumbnails after the fact -- a wallpaper copied into
                        // the folder with the shell running is listed before
                        // ffmpeg has been near it -- and this bump is the shell
                        // being told that run has finished. Without it a tile
                        // that latched stays on the 4K original until the next
                        // restart.
                        //
                        // TO THE TILES AND NOT TO THE MODEL, which is the whole
                        // point of doing it here. Stamping the revision into
                        // every entry would clear the flags by destroying the
                        // objects holding them, and would also rebuild every tile
                        // on screen on every opening -- a visible flash for a
                        // cache that in the ordinary case has nothing new in it.
                        // See the note over `entries` for the measurement.
                        //
                        // COSTS NOTHING WHEN THERE IS NOTHING TO UNDO. Assigning
                        // false to a bool that is already false emits no change,
                        // so a tile whose picture was there is untouched and
                        // nothing redraws.
                        Connections {
                            target: Config

                            function onWallpaperThumbsRevisionChanged(): void {
                                tile.thumbMissing = false;
                            }
                        }

                        // The backplate. It is what lights up, and it is the
                        // whole cell rather than the picture, so the highlight
                        // reads as a frame around the thumbnail exactly the way a
                        // Windows GridViewItem's does.
                        //
                        // HOVER BRIGHTENS, PRESS DIMS, AND NEITHER ANIMATES:
                        // Fluent.hoverMs is 0 and there is deliberately no
                        // Behavior here. Through Theme.glass() because the card
                        // under it is glass -- an opaque fill would punch an
                        // unblurred patch wherever the pointer is.
                        Rectangle {
                            anchors.fill: parent
                            radius: Fluent.controlRadius

                            color: mouse.pressed ? Theme.glass(Fluent.fillPress)
                                : (mouse.containsMouse || tile.GridView.isCurrentItem)
                                    ? Theme.glass(Fluent.fillSubtleHover)
                                    : "transparent"
                        }

                        Image {
                            id: picture

                            anchors.fill: parent
                            anchors.margins: root.tileInset

                            source: tile.thumbMissing
                                ? tile.modelData.fullUrl
                                : tile.modelData.thumbUrl

                            onStatusChanged: {
                                if (picture.status === Image.Error
                                    && !tile.thumbMissing
                                    && tile.modelData.fullUrl !== "")
                                    tile.thumbMissing = true;
                            }

                            fillMode: Image.PreserveAspectCrop
                            // Decoded at the size a tile is drawn at, and not at
                            // the picture's own: a 4K PNG decoded to fill a
                            // thumbnail costs a fifth of a second.
                            sourceSize: root.thumbSize
                            asynchronous: true
                            smooth: true

                            // CACHED FOR A STILL AND NOT FOR A VIDEO. It is about
                            // DECODING and nothing else: caching keeps the grid
                            // from decoding the same pictures again every time it
                            // scrolls them back into view, and a video's
                            // extracted frame is the one picture here that is
                            // routinely asked for before it exists.
                            cache: !tile.modelData.video

                            // NO `layer.enabled`, unlike every other masked image
                            // in this shell. An Image is already a texture
                            // provider, so MultiEffect can sample it directly;
                            // turning on a layer wraps it in a SECOND texture
                            // that has to be re-rendered whenever the item is
                            // marked dirty, to draw a picture that never changes.
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: picture
                            source: picture
                            maskEnabled: true
                            maskSource: cardMask

                            // WITHOUT THESE THE MASK IS A HARD THRESHOLD.
                            // MultiEffect defaults to cutting the mask at a
                            // single value with no spread, which throws away the
                            // antialiased edge the rounded rectangle was drawn
                            // for.
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }

                        // SELECTION IS A RING AND NOT A FILL. A thumbnail is
                        // already a picture, so tinting it would fight the image
                        // itself -- and Windows marks the applied wallpaper on
                        // this page with an accent border and nothing else.
                        //
                        // The hairline underneath it is not decoration either: a
                        // card on a Settings page carries a one-pixel stroke, and
                        // without one a dark photograph over a dark ground has no
                        // edge at all.
                        Rectangle {
                            anchors.fill: picture
                            radius: Fluent.controlRadius
                            color: "transparent"
                            antialiasing: true

                            border.width: tile.applied ? 2 : 1
                            border.color: tile.applied ? Theme.primary : Theme.outlineVariant

                            Behavior on border.color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            // Pointing at a tile also arms it for the keyboard,
                            // so the two never disagree about which one is next.
                            onEntered: tile.GridView.view.currentIndex = tile.index

                            // ONE CLICK APPLIES, which is what a click on a
                            // thumbnail means on the Personalisation page. The
                            // carousel this replaces needed two meanings for one
                            // click because its neighbours were half hidden
                            // behind the card you were aiming past; every tile in
                            // a grid is fully visible and fully clickable, so
                            // there is nothing left to disambiguate.
                            onClicked: root.apply(tile.modelData)
                        }
                    }
                }

                // An empty folder gets a sentence rather than a blank page. It
                // names the folder because nothing else here does, and because
                // the answer is almost always "the collection is somewhere else"
                // -- which is a setting, in the window this line points at.
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.count === 0

                    Text {
                        text: `No wallpapers in ${Config.wallpaperDir.replace(Quickshell.env("HOME"), "~")}`
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodyLargeSize
                        font.weight: Fluent.normalWeight
                        color: Theme.textOnSurface
                    }

                    Text {
                        text: "Point the collection somewhere else in Settings, Wallpaper"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        font.weight: Fluent.normalWeight
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }
        }
    }
}
