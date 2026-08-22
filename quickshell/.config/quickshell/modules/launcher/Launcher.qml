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
    // TWO WAYS FOR THE BAR NOT TO BE THERE, and only one of them used to be
    // checked. A fullscreen window covers it -- the bar is on the Top layer and
    // fullscreen draws over that -- but a monitor can also simply not HAVE one:
    // the bar is per screen and which screens carry it is a setting.
    //
    // Only testing for fullscreen meant that on a monitor without a bar this
    // panel still welded itself to one: square top corners and a fillet on each
    // side, joined to nothing, hanging off the top edge of the screen. Which is
    // exactly what it looked like.
    //
    // AND IT HAS TO BE A FULLSCREEN WINDOW YOU CAN ACTUALLY SEE: one parked on
    // a workspace nobody is looking at covers nothing. What is fullscreen comes
    // from wlr-foreign-toplevel and reads the same on every flavor; whether it
    // is on screen is the backend's to answer, because the protocol does not
    // say -- see fullscreenOutputs in CompositorBackend.qml.
    readonly property bool barVisible: Screens.hasBar(root.screen)
        && !Compositor.hasFullscreenOn(root.screen?.name ?? "")


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
            // The picker says which axis it walks on. There is one picker
            // left -- the clipboard, a vertical list -- and the question
            // survives its horizontal sibling on purpose: this used to hand
            // the horizontal step to both, which left the clipboard dead to
            // the arrow keys.
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
                // field searches whatever is on screen. Leaving ">clipboard"
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

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

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

    // Named, because the blur region above is built from them: it reads each
    // one's `radius`, `corner` and `visible` rather than being told any of it
    // twice.
    CornerWedge {
        id: leftFillet

        visible: root.barVisible

        anchors.left: parent.left
        anchors.top: parent.top
        corner: "topRight"
        radius: Theme.barCornerRadius
        fillColor: panel.color
    }

    CornerWedge {
        id: rightFillet

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
            // time. A Loader rather than visibility for the last of them: the
            // clipboard picker spawns a decode per image row, and it should
            // not be doing that while the application grid is what is on
            // screen.

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

                // Twelve cells of everything installed. The header up there
                // says four rows is as many as can be scanned without reading
                // and that past it you should be typing instead -- which is an
                // argument for this rather than against it: a grid that ends
                // flush with the bottom row looks like the whole answer, and
                // the bar is what says the answer is four hundred long and
                // typing is the way through it.
                //
                // ANCHORED TO THE GRID, and it is already the grid's own child
                // even though it is declared in here. A GridView is not a
                // Flickable in this one respect: QQuickFlickable's default
                // property is `flickableData`, which puts declared children on
                // the contentItem that scrolls, but QQuickListView and
                // QQuickGridView override it back to plain `data`, so a child
                // declared inside one of those belongs to the view item, which
                // does not move. (Checked both ways: `bar.parent === grid` is
                // true at runtime, and `defaultProperty` in QtQuick's
                // plugins.qmltypes says `data` for both views and
                // `flickableData` for Flickable.)
                //
                // This used to say `y: grid.contentY`, borrowed from
                // components/ScrollList.qml where it is right because that one
                // really is a plain Flickable and its bar really does ride the
                // contents. Here there was nothing to give back, so the line
                // was not a cancellation but a shove: the bar slid down the
                // panel by exactly the scroll and was clipped away before the
                // first row had finished passing.
                //
                // Hard against the right edge, where the third column's cell
                // already keeps a groupPadding clear before its label starts.
                ScrollBar {
                    view: grid

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    // THREE AND NOT THE DEFAULT SEVEN, which is the same
                    // correction the settings rail carries and is made for the
                    // same reason its own note gives: the margin is only free
                    // where the bar has empty room on BOTH sides, and this one
                    // has an application on one side and the grid's clip on
                    // the other.
                    //
                    // The margin widens the press target in both directions,
                    // but only one of them exists here. Measured offscreen on
                    // this geometry -- three columns of 260, rows of 60, the
                    // bar hard against the right edge, pressing a row of the
                    // third column across the last pixels of its width, with
                    // the grid's own left edge at x=0 and its right at x=779:
                    //
                    //   grabMargin  the app hears the press  the bar takes it
                    //   7           up to x=768             769 to 779
                    //   3           up to x=772             773 to 779
                    //   0           up to x=775             776 to 779
                    //
                    // Which is eleven pixels down the right-hand edge of every
                    // third-column row where clicking an application scrolls
                    // the grid instead of launching it. The outward half buys
                    // nothing to set against that: `clip: true` on the grid
                    // ends the target at its own edge, so everything past the
                    // bar is discarded and the whole of the margin is taken
                    // out of the column.
                    //
                    // NOT ZERO, because four pixels is the width to look at
                    // and an unfair thing to ask anyone to hit -- which is the
                    // reason the margin exists at all. Three is what the rail
                    // settled on for a bar in the same position, and one
                    // answer for "the bar is over something clickable" is
                    // better than two.
                    grabMargin: 3
                }

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

            // Whichever picker a command opened. STILL A LOADER WITH A
            // COMPONENT BESIDE IT although there is only one picker left: the
            // wallpaper strip that used to be the other one is now a
            // fullscreen carousel of its own (see modules/wallpaper), and what
            // the Loader buys is that the clipboard's decodes do not happen
            // while the application grid is what is on screen.
            Loader {
                id: pickerLoader

                width: layout.width
                active: root.picker !== ""
                visible: active

                sourceComponent: clipboardComponent
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
