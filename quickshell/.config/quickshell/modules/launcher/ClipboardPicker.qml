// Clipboard history, from cliphist.
//
// The last thing that was still opening wofi. cliphist itself stays -- it is
// the store, and the two `wl-paste --watch cliphist store` processes in
// hyprland.lua keep filling it; what moves here is the picking.
//
// IMAGES ARE SHOWN AS IMAGES
// `cliphist list` gives one line per entry, "<id>\t<preview>", and for
// anything binary the preview is a description rather than the content:
// "[[ binary data 7 KiB png 234x119 ]]". wofi could only ever show that
// string. Here an entry that says png or jpeg gets decoded to a file and
// drawn, so the history is browsable by sight for the thing you most often
// want back: a screenshot.
//
// Decoding is LAZY -- one process per image, started when its row is built,
// not 194 of them when the picker opens.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    // Which arrows walk this picker. The launcher reads it to know whether
    // to hand over the horizontal or the vertical step: a list and a strip
    // take the same move() but not the same keys.
    readonly property bool vertical: true

    // What the launcher's search box currently holds. Entering a picker
    // clears the box and re-points it here, so one field searches whatever is
    // on screen instead of each picker growing a second one.
    property string filter: ""

    property int selected: 0
    property var allEntries: []

    readonly property var entries: {
        const q = root.filter.trim().toLowerCase();
        if (q === "")
            return root.allEntries;

        // The preview is what the user can see, so it is what they will type
        // at. For an image that is cliphist's description -- "png 709x351" --
        // which makes "png" a usable filter for "show me the screenshots".
        return root.allEntries.filter(e => e.preview.toLowerCase().includes(q));
    }

    readonly property int count: root.entries.length

    // A new filter invalidates where the highlight was.
    onFilterChanged: root.selected = 0
    readonly property int rowHeight: 56
    readonly property int visibleRows: 7

    // Where decoded images land. Under XDG_RUNTIME_DIR because it is tmpfs:
    // these are throwaway copies of things already in the clipboard store,
    // and they should not survive a reboot.
    readonly property string cacheDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clipboard`

    signal picked

    implicitHeight: visibleRows * rowHeight

    function move(delta: int): void {
        if (root.count === 0)
            return;

        // Wraps, like the wallpaper carousel: a list that stops silently
        // leaves the user pressing a key that does nothing.
        root.selected = (root.selected + delta + root.count) % root.count;
    }

    function activate(): void {
        const entry = root.entries[root.selected];
        if (!entry)
            return;

        // decode and not the preview text: the preview is a description for
        // binary entries and a TRUNCATION for long text ones, so pasting it
        // would quietly hand over the wrong thing.
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${entry.id} | wl-copy`]);
        root.picked();
    }

    Component.onCompleted: lister.running = true

    Process {
        id: lister

        command: ["sh", "-c", `mkdir -p '${root.cacheDir}' && cliphist list`]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];

                for (const line of text.split("\n")) {
                    if (line === "")
                        continue;

                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;

                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);

                    // The marker cliphist writes for anything it could not
                    // render as text, with the format named inside it.
                    const binary = preview.match(/^\[\[ binary data .* (png|jpe?g|webp|bmp|gif) /);

                    parsed.push({
                        id: id,
                        preview: preview,
                        isImage: binary !== null
                    });

                    // Capped. The store holds a couple of hundred entries and
                    // nobody scrolls that far to find a paste; past this the
                    // list is a memory cost with no reader.
                    if (parsed.length >= 60)
                        break;
                }

                root.allEntries = parsed;
            }
        }
    }

    ListView {
        id: history

        anchors.fill: parent

        model: root.entries
        currentIndex: root.selected
        spacing: 2
        clip: true

        // Short: the selection itself is instant, and a slow scroll behind it
        // is what makes holding an arrow key feel like the list is dragging.
        highlightMoveDuration: 90
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange

        // Seven rows of up to sixty, and the selection WRAPS: arrow up from the
        // first entry lands on the sixtieth with nothing on screen saying the
        // list went anywhere. This is the only thing here that says how much of
        // the history is off the top and the bottom.
        //
        // Anchored, and to this ListView itself. A child declared inside a
        // ListView or a GridView is a child of the VIEW, not of its
        // contentItem -- QQuickListView overrides the default property back to
        // `data`, unlike a plain Flickable, which sends children to the thing
        // that scrolls. So the `y: history.contentY` this used to carry was
        // never giving back what the scroll took: nothing had taken anything,
        // and it pushed the bar down the full scroll instead, out through the
        // clip and off the list after one row.
        //
        // Hard against the right edge, in the groupPadding the row labels
        // already keep clear before they elide.
        ScrollBar {
            view: history

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        delegate: Rectangle {
            id: row

            required property int index
            required property var modelData

            width: ListView.view.width
            height: root.rowHeight
            radius: Theme.cardRadius - 6

            color: row.index === root.selected
                ? Qt.alpha(Theme.primary, 0.18)
                : rowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            // One decode per image row, started when the row is built.
            Process {
                id: decoder

                running: row.modelData.isImage
                command: ["sh", "-c", `cliphist decode ${row.modelData.id} > '${root.cacheDir}/${row.modelData.id}'`]

                onExited: thumbnail.source = `file://${root.cacheDir}/${row.modelData.id}`
            }

            Image {
                id: thumbnail

                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter

                width: 76
                height: 42

                visible: row.modelData.isImage && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
                smooth: true
            }

            // Stands in while the decode is still running, so the row does not
            // change width under the pointer when the image lands.
            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter

                visible: row.modelData.isImage && !thumbnail.visible
                text: Icons.image
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.outline
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: row.modelData.isImage ? Theme.groupPadding + 76 + Theme.itemSpacing : Theme.groupPadding + 4
                anchors.right: parent.right
                anchors.rightMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter

                text: row.modelData.isImage
                    // The size and dimensions out of cliphist's own
                    // description, without the brackets around them.
                    ? row.modelData.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                    : row.modelData.preview

                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: row.modelData.isImage ? Theme.textOnSurfaceVariant : Theme.textOnSurface
            }

            MouseArea {
                id: rowMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.selected = row.index
                onClicked: {
                    root.selected = row.index;
                    root.activate();
                }
            }
        }
    }
}
