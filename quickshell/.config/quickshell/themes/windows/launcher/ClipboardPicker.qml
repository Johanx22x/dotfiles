// THE CLIPBOARD HISTORY, which is what Windows opens on Win+V.
//
// A list of cards, one per entry, newest first. Windows draws it as a flyout
// of rounded tiles with the text or the image in each and a pin on hover; ours
// is the same list inside the search flyout, because that is the surface this
// shell puts pickers in.
//
// THE READING HALF IS BEHAVIOUR, NOT DRAWING, and it is carried across from
// the previous version of this file rather than rewritten -- `cliphist list`,
// the tab-separated parse, the binary marker, the sixty-entry cap and
// `cliphist decode | wl-copy`. Getting a paste wrong is not a cosmetic bug,
// and none of it is a question about what Windows looks like. What is new is
// every pixel.
//
// DECODE AND NOT THE PREVIEW TEXT when something is chosen. The preview is a
// description for binary entries and a TRUNCATION for long text ones, so
// pasting it would quietly hand over the wrong thing.

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    // The launcher asks which axis a picker walks on before handing it a key.
    readonly property bool vertical: true

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

    // Where decoded images land. Under XDG_RUNTIME_DIR because it is tmpfs:
    // these are throwaway copies of things already in the clipboard store and
    // they should not survive a reboot.
    readonly property string cacheDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clipboard`

    signal picked

    function move(delta: int): void {
        if (root.count === 0)
            return;

        // Wraps: a list that stops silently leaves the user pressing a key
        // that does nothing.
        root.selected = (root.selected + delta + root.count) % root.count;
    }

    function activate(): void {
        const entry = root.entries[root.selected];
        if (!entry)
            return;

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
                    // nobody scrolls that far to find a paste.
                    if (parsed.length >= 60)
                        break;
                }

                root.allEntries = parsed;
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 12

        id: heading

        text: "Clipboard history"
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        font.weight: Fluent.strongWeight
        color: Theme.textOnSurface
    }

    ListView {
        id: history

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 8

        model: root.entries
        currentIndex: root.selected
        spacing: Fluent.clipboardGap
        clip: true

        // Short: the selection itself is instant, and a slow scroll behind it
        // is what makes holding an arrow key feel like the list is dragging.
        highlightMoveDuration: 90
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange

        // A child declared inside a ListView is a child of the VIEW, not of
        // its contentItem -- QQuickListView overrides the default property
        // back to `data`, unlike a plain Flickable. So this is anchored to the
        // view and does not need to give back what the scroll took.
        ScrollBar {
            view: history

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        delegate: Rectangle {
            id: card

            required property int index
            required property var modelData

            width: ListView.view.width - Fluent.scrollGutter
            height: Fluent.clipboardCardHeight
            radius: Fluent.controlRadius

            // Selected and hovered are the same fill, which is the rule the
            // rest of this theme follows; the accent bar is what carries
            // selection.
            color: card.ListView.isCurrentItem || cardPointer.containsMouse
                ? Theme.surfaceContainerHigh
                : Theme.surfaceContainer

            border.width: 1
            border.color: Theme.outlineVariant

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Fluent.indicatorWidth
                height: Fluent.indicatorHeight
                radius: Fluent.indicatorRadius
                visible: card.ListView.isCurrentItem
                color: Theme.primary
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                // Two lines for text, one for the "binary data" description --
                // there is nothing more to read in that case.
                maximumLineCount: card.modelData.isImage ? 1 : 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight

                text: card.modelData.preview
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: card.modelData.isImage
                    ? Theme.textOnSurfaceVariant
                    : Theme.textOnSurface
            }

            MouseArea {
                id: cardPointer

                anchors.fill: parent
                hoverEnabled: true

                onEntered: root.selected = card.index
                onClicked: {
                    root.selected = card.index;
                    root.activate();
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.count === 0
        text: root.allEntries.length === 0
            ? "Nothing has been copied yet"
            : `No clipboard entry matches "${root.filter}"`
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        color: Theme.outline
    }
}
