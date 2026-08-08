// The wallpaper picker: a strip of the images in the wallpaper collection.
//
// Horizontal and not a grid, and with real thumbnails rather than names,
// because a wallpaper is chosen by LOOKING. A list of filenames would make
// the user open the folder to remember which one "lonely-grass" is, which is
// the whole job the picker is supposed to do.
//
// The directory is read with Qt's FolderListModel: Quickshell has no
// directory API, and shelling out to `ls` for something the toolkit already
// does would be a process and a parser for no gain.
//
// Picking one calls wallpaper-switch, the same script the keybinds and the
// rotation timer use. That matters more than it looks: the script is what
// sets the wallpaper AND regenerates the palette AND pushes the new border
// colour into Hyprland. Calling awww directly here would change the image and
// leave the whole desktop on the previous colours.

import Quickshell
import QtQuick
import Qt.labs.folderlistmodel
import QtQuick.Effects
import "root:/"

Item {
    id: root

    // A strip: the left and right arrows walk it. See the same property on
    // ClipboardPicker, which is a list and answers to up and down.
    readonly property bool vertical: false

    // What the launcher's search box currently holds. See the same property
    // on ClipboardPicker.
    property string filter: ""

    // Set by the launcher so the arrow keys reach the strip.
    property int selected: 0

    // The folder, read out into an array so it can be filtered.
    // FolderListModel matches on file name patterns and nothing else, so a
    // free-text filter has to happen on this side.
    property var allEntries: []

    readonly property var entries: {
        const q = root.filter.trim().toLowerCase();
        if (q === "")
            return root.allEntries;

        return root.allEntries.filter(e => e.name.toLowerCase().includes(q));
    }

    readonly property int count: root.entries.length

    onFilterChanged: root.selected = 0

    function rebuild(): void {
        const out = [];
        for (let i = 0; i < folder.count; i++) {
            const path = folder.get(i, "filePath");
            out.push({
                name: folder.get(i, "fileName"),
                path: path,
                // For a still this is the wallpaper itself. For a video it is
                // the frame wallpaper-switch pulled out with ffmpeg, because
                // an Image cannot decode an mp4.
                thumbUrl: Config.wallpaperThumbUrl(path)
            });
        }
        root.allEntries = out;
    }

    // A video listed before its frame has been extracted has nothing to draw.
    // Rebuilding on the bump replaces the entry objects, which is what gets
    // the delegates to ask for the file a second time.
    Connections {
        target: Config

        function onWallpaperThumbsRevisionChanged() {
            root.rebuild();
        }
    }
    readonly property int thumbWidth: 190
    readonly property int thumbHeight: 108

    signal picked(string path)

    implicitHeight: thumbHeight + 34

    // Wraps. Walking off the right end lands on the first wallpaper and off
    // the left end on the last: with ten images and no scrollbar, a strip
    // that simply stops leaves the user pressing a key that does nothing and
    // wondering whether the list ended or the key did.
    function move(delta: int): void {
        if (root.count === 0)
            return;

        root.selected = (root.selected + delta + root.count) % root.count;
    }

    function activate(): void {
        const entry = root.entries[root.selected];
        if (entry)
            root.picked(entry.path);
    }

    FolderListModel {
        id: folder

        // From Config, not from a literal here. This strip and the grid on
        // the settings window's Wallpaper page are two views of one folder,
        // and that folder is a setting now -- a copy of the path in each of
        // them is how one of the two silently stops agreeing with the other.
        folder: `file://${Config.wallpaperDir}`
        // The same extensions wallpaper-switch looks for, and from Config for
        // the same reason the folder is: the settings grid lists this folder
        // too, and one of the two quietly accepting a different set of files
        // is the half-working outcome that property exists to prevent.
        nameFilters: Config.wallpaperNameFilters
        showDirs: false
        sortField: FolderListModel.Name

        // The model fills asynchronously, so the array is built when it
        // reports how many files it found rather than at construction.
        //
        // A changed count is also how a video dropped into the folder while
        // the shell is running gets a thumbnail: it has none until ffmpeg has
        // been past it, and this is the moment we learn it is there.
        onCountChanged: {
            root.rebuild();
            Config.refreshWallpaperThumbs();
        }
    }

    ListView {
        id: strip

        anchors.fill: parent

        orientation: ListView.Horizontal
        spacing: 12
        model: root.entries
        currentIndex: root.selected
        // Keep the highlighted thumbnail on screen as the arrows walk past
        // the edge of the strip.
        //
        // Deliberately shorter than Theme.animDuration. The selection ring
        // moves the instant the key is pressed and the view was taking the
        // interface's standard 220ms to follow, so holding an arrow down felt
        // like dragging the strip behind the cursor. The scroll has to keep up
        // with the selection, not accompany it.
        highlightMoveDuration: 90
        preferredHighlightBegin: 0
        preferredHighlightEnd: width
        highlightRangeMode: ListView.ApplyRange
        clip: true

        delegate: Item {
            id: thumb

            required property int index
            required property var modelData

            width: root.thumbWidth
            height: root.thumbHeight + 30

            Item {
                id: frame

                anchors.top: parent.top
                width: root.thumbWidth
                height: root.thumbHeight

                readonly property int radius: Theme.cardRadius - 8

                // THE IMAGE HAS TO BE MASKED, not merely put inside a rounded
                // rectangle. An Image is a rectangle: sitting in a rounded
                // parent it keeps its own square corners and they poke out
                // past the frame, which is what the selected thumbnail looked
                // like. `clip` does not help either -- it clips to the
                // bounding rect, not to the curve.
                //
                // So the corners are cut with the same inverted-mask trick
                // components/CornerWedge.qml uses, including the threshold
                // and spread: without those MultiEffect cuts the mask at a
                // hard step and throws away its antialiasing.
                Image {
                    id: picture

                    anchors.fill: parent
                    source: thumb.modelData.thumbUrl
                    fillMode: Image.PreserveAspectCrop
                    // Decoded at the size it is drawn at: these are 4K
                    // wallpapers and ten of them at full size is a lot of
                    // memory for a strip of thumbnails.
                    sourceSize.width: root.thumbWidth
                    sourceSize.height: root.thumbHeight
                    asynchronous: true
                    smooth: true
                    // Qt remembers that a URL failed to load and will not go
                    // back to disk for it. A video's frame is written after
                    // the strip has already asked for it once, so without this
                    // the retry above would find the same cached failure.
                    cache: false

                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: pictureMask

                    anchors.fill: parent
                    radius: frame.radius
                    antialiasing: true
                    color: "black"

                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: picture
                    maskEnabled: true
                    maskSource: pictureMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                // The frame IS the selection: a thumbnail is already a
                // picture, so tinting it would fight the image itself. Drawn
                // OVER the masked image and with the same radius, so the ring
                // sits exactly on the cut edge.
                Rectangle {
                    anchors.fill: parent
                    radius: frame.radius
                    color: "transparent"
                    border.width: thumb.index === root.selected ? 2 : 0
                    border.color: Theme.primary
                    antialiasing: true

                    Behavior on border.width {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }

            Text {
                anchors.bottom: parent.bottom
                width: parent.width
                horizontalAlignment: Text.AlignHCenter

                // Without the extension: it is noise, and the file name is
                // only there to tell two similar images apart.
                text: thumb.modelData.name.replace(/\.[^.]+$/, "")
                elide: Text.ElideRight

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: thumb.index === root.selected ? Font.Bold : Theme.fontWeight
                color: thumb.index === root.selected ? Theme.textOnSurface : Theme.textOnSurfaceVariant
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.selected = thumb.index
                onClicked: root.picked(thumb.modelData.path)
            }
        }
    }
}
