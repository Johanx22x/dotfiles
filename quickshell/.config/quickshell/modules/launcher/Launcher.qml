// The application launcher, hanging from the centre of the bar.
//
// It replaces `wofi --show drun` (see ~/.local/bin/wofi-drun for what it used
// to be). The layout is deliberately the same shape it had there -- a grid of
// three columns with the icon to the left of the name -- so the habit
// survives the move; what changes is that it now belongs to the bar instead
// of being a separate window that happened to be near it.
//
// CONTINUITY WITH THE BAR
// Square top corners, rounded bottom, and a concave fillet on each side
// welding it to the bar's underside: the same construction the popouts and
// the notification panel use. The rounding trick is the same too -- a plain
// `radius` with the top corners pushed above the window and clipped, because
// Rectangle's per-corner radii are not antialiased.
//
// KEYBOARD
// The surface takes an exclusive keyboard grab while it is up, or there is
// nothing to type into. Typing filters, Enter launches, Escape closes, and
// the arrows move a highlight around the grid.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "root:/"
import "root:/components"

PanelWindow {
    id: root

    required property var modelData

    // Three columns, as in the wofi grid. Four rows on screen and the rest on
    // scroll: twelve applications is about as many as can be scanned without
    // reading, and past that the launcher stops being faster than typing.
    readonly property int columns: 3
    readonly property int rows: 4
    readonly property int cellWidth: 260
    readonly property int cellHeight: 60

    // Breathing room inside the panel. Deliberately larger than the bar's
    // groupPadding: the bar is a strip where every pixel is contested, and
    // this is a surface you stop and look at.
    readonly property int padding: 20

    // The search field's own height. A pill, like everything else the shell
    // draws that you can act on.
    readonly property int searchHeight: 42

    property string query: ""
    property int selected: 0

    // Which screen the launcher is on. "" is the application grid; "command"
    // is the ">" list; anything else is a picker a command opened, and the
    // string is which one.
    //
    // The ">" prefix is what separates the two searches. An application
    // launcher that also answers to verbs ends up ranking "Wallpaper" against
    // a program of that name and getting it wrong; the prefix says which list
    // is being searched so neither has to guess.
    readonly property bool commandMode: root.query.startsWith(">")
    property string picker: ""

    // How much of the panel is hidden ABOVE the top edge.
    //
    // Welded to the bar, the rectangle starts a corner radius higher than the
    // window so its top corners are cut off by the screen edge and only the
    // bottom two round. Detached there is nothing to hide under, so the slack
    // goes to zero and all four corners are drawn -- and the content, the
    // window height and the fillets all have to agree on which of the two it
    // currently is, or the panel gains a square bottom or uneven padding.
    readonly property int topSlack: root.barVisible ? Theme.cardRadius : 0


    // IS THE BAR ACTUALLY THERE?
    //
    // The launcher is welded to the bar's underside: square top corners and a
    // concave fillet on each side. A fullscreen window covers the bar -- it is
    // on the Top layer and fullscreen windows draw over that -- so the weld
    // ends up joining the panel to nothing, and what is left is a card with
    // two square corners floating in the middle of a game.
    //
    // So when the bar is hidden the panel stops pretending: it detaches, drops
    // its fillets and rounds all four corners like the free-floating thing it
    // has become.
    // Answered through wlr-foreign-toplevel in the compositor backend, so it
    // reads the same on every flavor -- see hasFullscreenOn in
    // compositor/CompositorBackend.qml.
    readonly property bool barVisible: !Compositor.hasFullscreenOn(root.screen?.name ?? "")


    readonly property var commandResults: root.commandMode ? Commands.search(root.query.slice(1)) : []

    // How many things the arrows can walk through right now.
    readonly property int count: {
        if (root.picker !== "")
            return 0;               // the picker moves its own selection
        return root.commandMode ? root.commandResults.length : root.results.length;
    }

    // The application list, filtered.
    //
    // noDisplay entries are the ones a desktop file explicitly asks not to
    // show -- settings panels of other desktops, mostly. Matching is on the
    // name AND the keywords, which is what makes "browser" find Brave.
    readonly property var results: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = root.query.trim().toLowerCase();

        // A desktop file with no Name is malformed, but it exists in the
        // wild and it must not take the whole list down.
        const named = all.filter(e => e.name);

        if (q === "")
            return named.slice().sort((a, b) => a.name.localeCompare(b.name));

        const scored = [];
        for (const entry of named) {
            const name = (entry.name ?? "").toLowerCase();
            const generic = (entry.genericName ?? "").toLowerCase();
            const keywords = (entry.keywords ?? []).join(" ").toLowerCase();

            // Rank rather than merely filter: a prefix match on the name is
            // what the user almost always means, so it has to come first --
            // typing "fi" should offer Firefox before anything that merely
            // mentions files.
            let score = -1;
            if (name.startsWith(q))
                score = 0;
            else if (name.includes(q))
                score = 1;
            else if (generic.includes(q) || keywords.includes(q))
                score = 2;

            if (score >= 0)
                scored.push({ entry: entry, score: score });
        }

        scored.sort((a, b) => a.score - b.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function launch(entry): void {
        if (!entry)
            return;

        LauncherState.close();

        // runInTerminal is Terminal=true in the desktop file: ranger, btop and
        // friends need a terminal to live in, and the old script handed that
        // job to wofi with `--term kitty`. Here it has to be done explicitly.
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", ...entry.command]);
        else
            Quickshell.execDetached(entry.command);
    }

    function move(dx: int, dy: int): void {
        if (root.picker !== "") {
            // The picker says which axis it walks on, because they do not
            // agree: the wallpaper strip is horizontal and the clipboard is a
            // vertical list. Handing the horizontal step to both left the
            // clipboard dead to the arrow keys.
            //
            // Through the Loader's `item`, not through an id: an id declared
            // inside a Component belongs to that Component's scope and is not
            // visible from out here.
            const picker = pickerLoader.item;
            if (picker)
                picker.move(picker.vertical ? dy : dx);
            return;
        }

        if (root.count === 0)
            return;

        // The command list is one column, so a vertical step is one entry
        // rather than a row of the grid.
        const stride = root.commandMode ? 1 : root.columns;
        const next = root.selected + dx + dy * stride;
        if (next >= 0 && next < root.count)
            root.selected = next;
    }

    function activate(): void {
        if (root.picker !== "") {
            pickerLoader.item?.activate();
            return;
        }

        if (root.commandMode) {
            const command = root.commandResults[root.selected];
            if (!command)
                return;

            if (command.picker !== "") {
                // Opening a picker keeps the launcher up: the command was a
                // question, and the answer is the next screen.
                //
                // The search box is cleared and RE-POINTED at the picker: one
                // field searches whatever is on screen. Leaving ">wallpaper"
                // in it would be a box showing a command that already ran,
                // and giving the picker a second field of its own would be
                // two places to type in one window.
                root.picker = command.picker;
                root.selected = 0;
                input.text = "";
                return;
            }

            LauncherState.close();
            Commands.run(command.id);
            return;
        }

        root.launch(root.results[root.selected]);
    }

    // Escape backs OUT of a picker before it closes the launcher: one step
    // undone at a time is what makes a nested screen safe to enter.
    function back(): void {
        if (root.picker !== "") {
            root.picker = "";
            root.selected = 0;
            input.text = "";
            return;
        }

        LauncherState.close();
    }

    screen: modelData
    visible: LauncherState.isOpen

    WlrLayershell.namespace: "quickshell-launcher"
    // Overlay, above the notification panel on Top, for the same reason the
    // popouts are: this is something the user opened and is looking at.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive: the launcher is useless without a keyboard, and while it is
    // up nothing else should be receiving keys.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
    }

    // Flush with the bar's underside; anchored to `top` alone, so
    // wlr-layer-shell centres it horizontally without anyone measuring the
    // screen.
    margins {
        top: root.barVisible ? Theme.barHeight : Theme.barCornerRadius
    }

    implicitWidth: panel.implicitWidth + Theme.barCornerRadius * 2
    implicitHeight: panel.implicitHeight - root.topSlack

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Input stops at the panel: the fillets are decoration.
    mask: Region {
        item: panel
    }

    // Reset on every opening. A launcher that remembers the last search is a
    // launcher that shows yesterday's answer to today's keystroke.
    onVisibleChanged: {
        if (visible) {
            // input.text and NOT root.query: the field is the source of
            // truth and it drives `query` through onTextChanged. Clearing
            // only the property left the previous search visible in the box
            // while the results below were of an empty one -- reopening
            // after a ">" command showed the grid with ">" still typed.
            input.text = "";
            root.selected = 0;

            // A keybind may have asked for a particular screen. Consumed here
            // and cleared, so the next plain opening starts on the grid.
            root.picker = LauncherState.pendingPicker;
            LauncherState.pendingPicker = "";

            input.forceActiveFocus();
        }
    }

    CornerWedge {
        visible: root.barVisible

        anchors.left: parent.left
        anchors.top: parent.top
        corner: "topRight"
        radius: Theme.barCornerRadius
        fillColor: panel.color
    }

    CornerWedge {
        visible: root.barVisible

        anchors.right: parent.right
        anchors.top: parent.top
        corner: "topLeft"
        radius: Theme.barCornerRadius
        fillColor: panel.color
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter

        // Grown upwards by one radius and pushed the same amount above the
        // window, so the top corners round off out of sight and the edge that
        // meets the bar comes out straight. Per-corner radii would be simpler
        // and are not antialiased; see components/Popout.qml.
        y: -root.topSlack

        implicitWidth: root.columns * root.cellWidth + root.padding * 2
        implicitHeight: layout.implicitHeight + root.padding * 2 + root.topSlack

        radius: Theme.cardRadius
        antialiasing: true

        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Column {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.topSlack + root.padding
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding

            spacing: root.padding - 6

            // ---------------- Search ----------------
            // In a container of its own, in the island's tone
            // (surfaceContainerHigh over the panel's surface). A bare input
            // line on the panel reads as a caption; a filled pill reads as
            // something to type into, which is the first thing this window
            // has to say.
            Rectangle {
                width: layout.width
                height: root.searchHeight
                radius: height / 2
                color: Theme.glass(Theme.surfaceContainerHigh)

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding + 4
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.groupPadding + 4
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: Theme.itemSpacing

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.search
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        // Brighter once something is typed: the glyph doubles
                        // as the sign that the field is live.
                        color: root.query === "" ? Theme.outline : Theme.primary

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }

                    TextInput {
                        id: input

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize * 2 - Theme.itemSpacing

                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.textOnSurface
                        selectionColor: Qt.alpha(Theme.primary, 0.35)
                        selectedTextColor: Theme.textOnSurface

                        focus: true
                        onTextChanged: {
                            root.query = text;
                            // Any keystroke invalidates where the highlight was.
                            root.selected = 0;
                        }

                        Keys.onEscapePressed: root.back()
                        Keys.onReturnPressed: root.activate()
                        Keys.onEnterPressed: root.activate()
                        Keys.onLeftPressed: root.move(-1, 0)
                        Keys.onRightPressed: root.move(1, 0)
                        Keys.onUpPressed: root.move(0, -1)
                        Keys.onDownPressed: root.move(0, 1)

                        // The placeholder, drawn rather than set: TextInput has
                        // no placeholder of its own.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            // Names the list being searched: the same box
                            // means three different things depending on the
                            // screen, and the placeholder is the only thing
                            // that can say which.
                            text: {
                                if (root.picker === "wallpaper")
                                    return "Search wallpapers";
                                if (root.picker === "clipboard")
                                    return "Search clipboard";
                                if (root.commandMode)
                                    return "Search commands";
                                return "Search applications";
                            }
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: Theme.outline
                        }
                    }
                }
            }

            // ---------------- Results ----------------
            // Three screens in one place, and only one of them is up at a
            // time. Loaders rather than visibility: the wallpaper picker
            // decodes ten images, and it should not be doing that while the
            // application grid is what is on screen.

            // The application grid.
            GridView {
                id: grid

                visible: !root.commandMode && root.picker === ""
                width: layout.width
                height: visible ? root.rows * root.cellHeight : 0

                cellWidth: root.cellWidth
                cellHeight: root.cellHeight

                model: root.results
                currentIndex: root.selected

                highlightFollowsCurrentItem: true
                snapMode: GridView.SnapToRow
                clip: true

                delegate: Item {
                    id: cell

                    required property int index
                    required property var modelData

                    width: root.cellWidth
                    height: root.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.cardRadius - 6

                        color: cell.index === root.selected
                            ? Qt.alpha(Theme.primary, 0.18)
                            : cellMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.groupPadding
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.groupPadding
                        anchors.verticalCenter: parent.verticalCenter

                        spacing: Theme.itemSpacing

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            source: Icons.resolve(cell.modelData.icon ?? "")
                            visible: status === Image.Ready
                            width: 34
                            height: 34
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.modelData.name ?? ""
                            elide: Text.ElideRight
                            width: root.cellWidth - 34 - Theme.itemSpacing - Theme.groupPadding * 2
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                            color: Theme.textOnSurface
                        }
                    }

                    MouseArea {
                        id: cellMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: root.selected = cell.index
                        onClicked: root.launch(cell.modelData)
                    }
                }
            }

            // The ">" commands. A list and not a grid: each one carries a line
            // of explanation, and explanations want a full width to sit on.
            Column {
                visible: root.commandMode && root.picker === ""
                width: layout.width
                spacing: 2

                Repeater {
                    model: root.commandResults

                    Rectangle {
                        id: row

                        required property int index
                        required property var modelData

                        width: layout.width
                        height: 56
                        radius: Theme.cardRadius - 6

                        color: row.index === root.selected
                            ? Qt.alpha(Theme.primary, 0.18)
                            : rowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        Text {
                            id: rowGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.groupPadding + 4
                            anchors.verticalCenter: parent.verticalCenter

                            text: row.modelData.glyph
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize + 3
                            color: row.index === root.selected ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Column {
                            anchors.left: rowGlyph.right
                            anchors.leftMargin: Theme.itemSpacing + 4
                            anchors.right: rowChevron.left
                            anchors.rightMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 1

                            Text {
                                text: row.modelData.name
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize
                                font.weight: Font.Bold
                                color: Theme.textOnSurface
                            }

                            Text {
                                width: parent.width
                                text: row.modelData.description
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1
                                color: Theme.textOnSurfaceVariant
                            }
                        }

                        // Only on the ones that open another screen, so the
                        // list says which entries act and which ask.
                        Text {
                            id: rowChevron

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding + 4
                            anchors.verticalCenter: parent.verticalCenter

                            visible: row.modelData.picker !== ""
                            text: Icons.chevronRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize
                            color: Theme.outline
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

            // The wallpaper strip.
            // Whichever picker a command opened. One Loader and not one per
            // kind: only one is ever up, and an inactive Loader costs nothing
            // -- which matters here because the clipboard picker spawns a
            // decode per image row and the wallpaper strip decodes ten
            // photographs.
            Loader {
                id: pickerLoader

                width: layout.width
                active: root.picker !== ""
                visible: active

                sourceComponent: root.picker === "wallpaper" ? wallpaperComponent : clipboardComponent
            }

            Component {
                id: wallpaperComponent

                WallpaperPicker {
                    width: layout.width
                    filter: root.query

                    onPicked: path => {
                        LauncherState.close();
                        // wallpaper-switch and not awww: the script is what
                        // also regenerates the palette and pushes the new
                        // border colour into Hyprland.
                        Quickshell.execDetached(["wallpaper-switch", "set", path]);
                    }
                }
            }

            Component {
                id: clipboardComponent

                ClipboardPicker {
                    width: layout.width
                    filter: root.query

                    onPicked: LauncherState.close()
                }
            }

            // Nothing matched: say so rather than showing an empty box.
            Text {
                width: layout.width
                visible: root.picker === "" && root.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No matches"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.outline
            }
        }
    }
}
