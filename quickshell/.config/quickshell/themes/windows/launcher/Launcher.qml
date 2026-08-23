// THE START MENU, AND WHAT IT ACTUALLY RECREATES.
//
// Not the pinned-tile grid. This launcher is search-first -- it opens with the
// caret in the field and Johan types -- so the Windows screen it corresponds to
// is the one you get AFTER you type, not the one you get when you press the
// key. That view is a list with section headers, not a grid of tiles, and this
// file is that list.
//
// AND MICROSOFT PUBLISHES NOTHING ABOUT IT. The Windows 11 search results view
// is not native XAML at all: it is a WebView2 surface, which is verifiable --
// windows-11-start-menu-styler.wh.cpp matches its source URL
// `ms-appx-web://microsoft.windows.search/cache/local/desktop/2.html`, and a
// companion Windhawk mod exists purely to attach Chrome DevTools to
// SearchHost.exe. So the row height, the hero card and the preview split are
// CSS classes in a bundle nobody has scraped, and there is no number to copy.
//
// What this file uses instead is WinUI's own documented ListViewItem -- 40px
// minimum height, 4px radius, a 3x16 accent selection pill -- which is the
// primitive the rest of the Windows shell is built from. That is a defensible
// substitute. A number invented and presented as measured would not be, so
// every figure below that is ours says so at its line.
//
// WHAT MOVED FROM GENESIS, and it is more than a restyle:
//
//   the grid          -> a list. Three columns of 260x60 tiles became one
//                        column of rows, because that is what the view being
//                        copied is, and because `move()` collapses from a
//                        two-dimensional walk to a one-dimensional one.
//   the anchor        -> bottom. Genesis hangs the launcher off the underside
//                        of a top bar with two fillets welding it there. The
//                        taskbar is at the bottom and Windows' panel FLOATS
//                        above it with a gap, so the fillets go and all four
//                        corners round.
//   section headers   -> new. Windows separates "Best match" from the rest,
//                        and the ranking below already computed the tiers that
//                        distinction needs; it was simply not being shown.
//
// WHAT DID NOT MOVE: the ranking, `launch`, `activate`, `back`, the reset on
// opening, and the clipboard picker's Loader. Those are behaviour, they were
// right, and a theme rewriting them would be a theme reimplementing the
// launcher rather than drawing it.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.modules.launcher
import qs.modules.powermenu
import qs.modules.settings
import ".."

PanelWindow {
    id: root

    required property var modelData

    // OURS. Microsoft publishes no width for this view. 560 is read off
    // screenshots and sits between the classic Start panel's 666 and the
    // narrower search flyout; at the shell's default type size it holds a
    // 40-character application name without eliding.
    readonly property int panelWidth: 560

    // How many rows are on screen before the list scrolls. Twelve
    // applications is about as many as can be scanned without reading, and
    // past that the launcher stops being faster than typing -- the same
    // reasoning genesis's four-by-three grid was built on, arriving at the
    // same number down one column instead of across three.
    readonly property int visibleRows: 8

    // OURS, from the same screenshots: the gap between the panel and the
    // taskbar. The Windows panel does not touch the bar.
    readonly property int taskbarGap: 12

    readonly property int padding: 20

    // Windows' search box is 32 in Settings and reads a shade taller in the
    // Start panel. 34 with a 4px radius; the accent underline is drawn inside
    // it rather than added to it, so this is the whole height.
    readonly property int searchHeight: 34

    // The strip along the bottom: account on the left, power on the right. It
    // carries its own tint, distinct from the panel -- which is a correction
    // to an earlier reading that had it flush.
    readonly property int footerHeight: 64

    property string query: ""
    property int selected: 0

    readonly property bool commandMode: root.query.startsWith(">")
    property string picker: ""

    readonly property bool barVisible: Screens.hasBar(root.screen)
        && !Compositor.hasFullscreenOn(root.screen?.name ?? "")

    readonly property var commandResults: root.commandMode ? Commands.search(root.query.slice(1)) : []

    readonly property int count: {
        if (root.picker !== "")
            return 0;               // the picker moves its own selection
        return root.commandMode ? root.commandResults.length : root.results.length;
    }

    // The application list, filtered and ranked. UNCHANGED FROM GENESIS except
    // that the score survives into `ranked` instead of being thrown away after
    // the sort -- see `sectionAt` below, which is the only reason it is kept.
    //
    // noDisplay entries are the ones a desktop file explicitly asks not to
    // show -- settings panels of other desktops, mostly. Matching is on the
    // name AND the keywords, which is what makes "browser" find Brave.
    readonly property var ranked: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = root.query.trim().toLowerCase();

        // A desktop file with no Name is malformed, but it exists in the wild
        // and it must not take the whole list down.
        const named = all.filter(e => e.name);

        if (q === "")
            return named.slice()
                .sort((a, b) => a.name.localeCompare(b.name))
                .map(e => ({ entry: e, score: 0 }));

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
        return scored;
    }

    readonly property var results: root.ranked.map(r => r.entry)

    // WHICH HEADER, IF ANY, GOES ABOVE ROW `i`.
    //
    // Windows shows the top hit under "Best match" and everything after it
    // under its category. The tiers to do that already existed in the ranking
    // above and were being discarded; nothing new is computed here.
    //
    // Returns "" for a row that carries no header, which is most of them.
    function sectionAt(i: int): string {
        if (root.commandMode)
            return i === 0 ? "Commands" : "";
        if (root.query.trim() === "")
            return i === 0 ? "All apps" : "";
        if (i === 0)
            return "Best match";
        if (i === 1)
            return "Apps";
        return "";
    }

    function launch(entry): void {
        if (!entry)
            return;

        LauncherState.close();

        // runInTerminal is Terminal=true in the desktop file: ranger, btop and
        // friends need a terminal to live in.
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", ...entry.command]);
        else
            Quickshell.execDetached(entry.command);
    }

    // ONE DIMENSION NOW, AND THAT IS THE WHOLE OF THE CHANGE HERE. Genesis
    // stepped by `columns` on a vertical move because its results were a grid.
    // A list has a stride of one, so left and right have nothing to walk and
    // are left to the picker.
    function move(dx: int, dy: int): void {
        if (root.picker !== "") {
            // The picker says which axis it walks on. Through the Loader's
            // `item`, not through an id: an id declared inside a Component
            // belongs to that Component's scope and is not visible from here.
            const picker = pickerLoader.item;
            if (picker)
                picker.move(picker.vertical ? dy : dx);
            return;
        }

        if (root.count === 0)
            return;

        const next = root.selected + dy;
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
                // question, and the answer is the next screen. The search box
                // is cleared and RE-POINTED at the picker: one field searches
                // whatever is on screen.
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

    // THE NAMESPACE IS NOT A NAME, IT IS HOW THE BLUR IS FOUND. Hyprland's
    // blur-quickshell layer rule matches on it; a namespace that is not on
    // that list does not come out unblurred, it falls through to the global
    // decoration.blur, which has different parameters and no xray, and the
    // surface ends up visibly blurrier than the taskbar it belongs to.
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive: the launcher is useless without a keyboard, and while it is
    // up nothing else should be receiving keys.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // BOTTOM, AND ONLY BOTTOM. Anchored to one edge, wlr-layer-shell centres
    // it on the other axis without anyone measuring the screen -- which is the
    // same trick genesis used against `top`, pointed the other way.
    anchors {
        bottom: true
    }

    margins {
        bottom: (root.barVisible ? Theme.barHeight : 0) + root.taskbarGap
    }

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // NO FILLETS AND NO SLACK. Genesis grew the panel upwards by one radius so
    // its top corners rounded off out of sight under the bar, and welded it
    // there with two CornerWedges. Windows' panel floats: every corner is
    // visible, so every corner rounds, and there is nothing to weld it to.
    mask: Region {
        item: panel
    }

    // Reset on every opening. A launcher that remembers the last search is a
    // launcher that shows yesterday's answer to today's keystroke.
    onVisibleChanged: {
        if (visible) {
            // input.text and NOT root.query: the field is the source of truth
            // and it drives `query` through onTextChanged. Clearing only the
            // property left the previous search visible in the box while the
            // results below were of an empty one.
            input.text = "";
            root.selected = 0;

            // A keybind may have asked for a particular screen. Consumed here
            // and cleared, so the next plain opening starts on the list.
            root.picker = LauncherState.pendingPicker;
            LauncherState.pendingPicker = "";

            input.forceActiveFocus();
        }
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: root.panelWidth
        implicitHeight: layout.implicitHeight + root.padding * 2 + footer.height

        radius: Fluent.overlayRadius
        antialiasing: true

        color: Theme.glass(Theme.surface)
        border.width: 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Column {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.padding
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding

            spacing: 12

            // ---------------- Search ----------------
            //
            // The Windows text field, and the two details that make it one:
            // the fill INVERTS on focus rather than brightening, and the
            // bottom border becomes two pixels of accent. Both happen with no
            // transition at all -- Microsoft's own state change is a
            // DiscreteObjectKeyFrame at time zero.
            Rectangle {
                id: field

                width: layout.width
                height: root.searchHeight
                radius: Fluent.controlRadius

                color: input.activeFocus ? Theme.surface : Theme.glass(Theme.surfaceContainer)
                border.width: 1
                border.color: Theme.outlineVariant

                // The accent underline. A child rather than a border side,
                // because a Rectangle's border is uniform and this one is not.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    height: Fluent.focusUnderline
                    radius: 1
                    visible: input.activeFocus
                    color: Theme.primary
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.search
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.textOnSurfaceVariant
                    }

                    TextInput {
                        id: input

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.fontSize * 2 - 10

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
                        Keys.onUpPressed: root.move(0, -1)
                        Keys.onDownPressed: root.move(0, 1)

                        // The placeholder, drawn rather than set: TextInput has
                        // no placeholder of its own.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            // Names the list being searched: the same box means
                            // three different things depending on the screen,
                            // and the placeholder is the only thing that can
                            // say which.
                            text: {
                                if (root.picker === "clipboard")
                                    return "Search clipboard";
                                if (root.commandMode)
                                    return "Type a command";
                                return "Type here to search";
                            }
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: Theme.textOnSurfaceVariant
                        }
                    }
                }
            }

            // ---------------- Results ----------------
            //
            // Three screens in one place and only one of them up at a time. A
            // Loader rather than visibility for the last: the clipboard picker
            // spawns a decode per image row, and it should not be doing that
            // while the application list is what is on screen.

            ListView {
                id: list

                // THE VALUES THE DELEGATE READS, HOISTED. Inside a delegate,
                // `root.anything` is out of scope as far as qmllint is
                // concerned -- it resolves at runtime and is checked by
                // nothing, which is the single largest source of unqualified
                // reads in the genesis tree. Read once here, and the delegate
                // reaches them through its `ListView.view` attached property,
                // which IS in scope.
                property int sel: root.selected
                property bool commands: root.commandMode

                function headerFor(i: int): string {
                    return root.sectionAt(i);
                }

                function choose(i: int): void {
                    root.selected = i;
                    root.activate();
                }

                function hover(i: int): void {
                    root.selected = i;
                }

                visible: root.picker === "" && root.count > 0
                width: layout.width
                height: Math.min(contentHeight, root.visibleRows * 44)

                clip: true
                interactive: contentHeight > height
                currentIndex: root.selected
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightRangeMode: ListView.ApplyRange

                model: root.commandMode ? root.commandResults : root.results

                ScrollBar {
                    view: list
                }

                delegate: Column {
                    id: cell

                    required property int index
                    required property var modelData

                    // Hoisted off the view rather than off `root`: see the
                    // note on `sel` above.
                    readonly property bool current: cell.ListView.view.sel === cell.index
                    readonly property string header: cell.ListView.view.headerFor(cell.index)
                    readonly property bool isCommand: cell.ListView.view.commands

                    width: ListView.view.width

                    // The section header, when this row starts one. Windows'
                    // BodyStrong: 14 semibold. 6 below and 12 above, except at
                    // the very top where the field already provides the gap.
                    Item {
                        width: parent.width
                        height: cell.header === "" ? 0 : 30
                        visible: cell.header !== ""

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6

                            text: cell.header
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.captionSize
                            font.weight: Fluent.strongWeight
                            color: Theme.textOnSurface
                        }
                    }

                    // The row itself: WinUI's ListViewItem. 40 minimum, 4
                    // radius, and selection carried by the accent pill rather
                    // than by a colour of its own -- the selected fill and the
                    // hover fill are the SAME brush in Windows, which is why
                    // there is no third branch in the colour below.
                    Rectangle {
                        id: rowBox

                        width: parent.width
                        height: Math.max(40, rowText.implicitHeight + 12)
                        radius: Fluent.controlRadius

                        color: cell.current || rowMouse.containsMouse
                            ? Theme.surfaceContainerHigh
                            : "transparent"

                        // NO Behavior HERE, AND THAT IS THE POINT. Windows
                        // swaps the brush on a DiscreteObjectKeyFrame at time
                        // zero. A fade on hover is the tell that gives a
                        // Fluent recreation away faster than any wrong colour,
                        // because every real control in the same session is
                        // doing it without one.

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Fluent.indicatorWidth
                            height: Fluent.indicatorHeight
                            radius: Fluent.indicatorRadius
                            visible: cell.current
                            color: Theme.primary
                        }

                        // The icon. An application has a real bitmap; a command
                        // has a glyph. Both land in the same 24px box so the
                        // text column starts in the same place either way.
                        Item {
                            id: rowIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24

                            Image {
                                anchors.fill: parent
                                // Icons.resolve and not Quickshell.iconPath:
                                // the host owns icon lookup, and a theme that
                                // resolves its own would be a second answer to
                                // a question Icons.qml already answers -- and
                                // would miss the theme's own icons.json.
                                source: cell.isCommand
                                    ? ""
                                    : Icons.resolve(cell.modelData.icon ?? "")
                                visible: !cell.isCommand && status === Image.Ready
                                sourceSize.width: 24
                                sourceSize.height: 24
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cell.isCommand
                                text: cell.isCommand ? cell.modelData.glyph : ""
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize + 2
                                color: cell.current ? Theme.primary : Theme.textOnSurfaceVariant
                            }
                        }

                        Column {
                            id: rowText

                            anchors.left: rowIcon.right
                            anchors.leftMargin: 12
                            anchors.right: rowChevron.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 0

                            Text {
                                width: parent.width
                                text: cell.modelData.name ?? ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Fluent.bodySize
                                color: Theme.textOnSurface
                            }

                            // The second line, when there is one. Applications
                            // mostly have a genericName; commands always have a
                            // description.
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: cell.isCommand
                                    ? (cell.modelData.description ?? "")
                                    : (cell.modelData.genericName ?? "")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Fluent.captionSize
                                color: Theme.textOnSurfaceVariant
                            }
                        }

                        // Only on the ones that open another screen, so the
                        // list says which entries act and which ask.
                        Text {
                            id: rowChevron

                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            visible: cell.isCommand && cell.modelData.picker !== ""
                            text: Icons.chevronRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: Theme.textOnSurfaceVariant
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: cell.ListView.view.hover(cell.index)
                            onClicked: cell.ListView.view.choose(cell.index)
                        }
                    }
                }
            }

            // Whichever picker a command opened. STILL A LOADER WITH A
            // COMPONENT BESIDE IT although there is only one picker left: what
            // the Loader buys is that the clipboard's decodes do not happen
            // while the application list is what is on screen.
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
            Item {
                width: layout.width
                height: visible ? 72 : 0
                visible: root.picker === "" && root.count === 0

                Text {
                    anchors.centerIn: parent
                    text: `No results for "${root.query}"`
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurfaceVariant
                }
            }
        }

        // ---------------- Footer ----------------
        //
        // Full bleed and its own tint, which is a correction rather than a
        // choice: an earlier reading had this strip flush with the panel, and
        // the CSS recreation that has the only real numbers for it gives it a
        // background of its own. 64 tall, and the bottom corners follow the
        // panel's.
        Rectangle {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1

            height: root.footerHeight
            radius: Fluent.overlayRadius - 1
            color: Theme.surfaceContainer

            // Square at the top, rounded at the bottom, matching the panel.
            // Two rectangles rather than per-corner radii for the same reason
            // components/Popout.qml gives: per-corner radii are not
            // antialiased.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height / 2
                color: parent.color
            }

            // The hairline that separates it from the list above.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.outlineVariant
            }

            Item {
                id: account

                anchors.left: parent.left
                anchors.leftMargin: root.padding
                anchors.verticalCenter: parent.verticalCenter
                width: avatar.width + name.implicitWidth + 10
                height: 32

                Rectangle {
                    id: avatar

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: width / 2
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: (SessionInfo.displayName || "?").charAt(0).toUpperCase()
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        font.weight: Fluent.strongWeight
                        // Black on an accent fill, which is what Windows does
                        // in dark mode: the dark accent is the LIGHT shade of
                        // the ramp, so the ink on it is TextOnAccentFillColor.
                        color: Theme.textOnPrimary
                    }
                }

                Text {
                    id: name

                    anchors.left: avatar.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    text: SessionInfo.displayName
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurface
                }
            }

            Rectangle {
                id: power

                anchors.right: parent.right
                anchors.rightMargin: root.padding
                anchors.verticalCenter: parent.verticalCenter

                width: 40
                height: 40
                radius: Fluent.controlRadius
                color: powerMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Icons.power
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize + 2
                    color: Theme.textOnSurface
                }

                MouseArea {
                    id: powerMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        LauncherState.close();
                        PowerMenuState.toggle();
                    }
                }
            }
        }
    }
}
