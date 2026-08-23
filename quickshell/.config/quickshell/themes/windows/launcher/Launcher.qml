// THE SEARCH FLYOUT.
//
// Our launcher opens with the caret in the field, so the Windows screen it
// corresponds to is not the pinned-tile Start menu. It is the one you get
// after you type, and that screen has a shape no table of numbers will give
// you:
//
//   a PILL-shaped search field across the top, not a 4px-radius box
//   a row of filter chips under it, the active one filled in accent
//   TWO COLUMNS -- results on the left, a preview of the selection on the right
//   section headers carrying a COUNT and a chevron, not a bare word
//   the selected row inset, with a 3px accent bar on its LEFT edge
//
// The first attempt at this file had a single column of 40px rows, a 4px
// field, and no preview at all. Every one of those was a reasonable reading of
// Microsoft's control documentation, and not one of them is what the screen
// looks like -- because the screen is not XAML. It is a WebView2 surface, which
// is verifiable from the Windhawk styler mod that matches its source URL, so
// there is nothing to look up and the only way to get it right is to look.
//
// WHAT DID NOT MOVE: the ranking, `launch`, `activate`, `back`, and the reset
// on opening. Those are behaviour and they were right.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs
import qs.components
import qs.modules.launcher
import qs.modules.settings
import qs.themes.windows

PanelWindow {
    id: root

    required property var modelData

    // OURS, measured off the photograph: the panel is about two thirds of a
    // 1080p screen's height, and its results column a little under half its
    // width.
    readonly property int panelWidth: 900
    readonly property int panelHeight: 620

    // Whether the power button's flyout is up. Lives here rather than on the
    // footer item because Escape is handled at the search field, which is the
    // only place keys arrive.
    property bool powerOpen: false
    readonly property int resultsWidth: 400
    readonly property int taskbarGap: 12
    readonly property int padding: 16

    property string query: ""
    property int selected: 0

    readonly property bool commandMode: root.query.startsWith(">")
    property string picker: ""

    readonly property bool barVisible: Screens.hasBar(root.screen)
        && !Compositor.hasFullscreenOn(root.screen?.name ?? "")

    readonly property var commandResults: root.commandMode ? Commands.search(root.query.slice(1)) : []

    readonly property int count: {
        if (root.picker !== "")
            return 0;
        return root.commandMode ? root.commandResults.length : root.results.length;
    }

    // The application list, filtered and ranked. The score survives the sort so
    // the section headers can be built from it rather than invented.
    readonly property var ranked: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = root.query.trim().toLowerCase();
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

    // What the preview column is previewing.
    readonly property var current: root.commandMode
        ? (root.commandResults[root.selected] ?? null)
        : (root.results[root.selected] ?? null)

    // Windows heads the top hit "Best match" on its own and groups the rest by
    // kind with a count beside each. Our kinds are the ranking's own tiers,
    // which already existed and were being thrown away after the sort.
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

    function sectionCount(i: int): int {
        if (i !== 1 || root.commandMode || root.query.trim() === "")
            return 0;
        return Math.max(0, root.count - 1);
    }

    function launch(entry): void {
        if (!entry)
            return;

        LauncherState.close();

        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", ...entry.command]);
        else
            Quickshell.execDetached(entry.command);
    }

    function runAction(action): void {
        if (!action)
            return;

        LauncherState.close();
        Quickshell.execDetached(action.command);
    }

    // One dimension: the results are a list, so left and right have nothing to
    // walk.
    function move(dy: int): void {
        if (root.picker !== "") {
            // The picker says which axis it walks on. Through the Loader's
            // `item`, not through an id: an id declared inside a Component
            // belongs to that Component's scope and is not visible from here.
            pickerLoader.item?.move(dy);
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
                // question and the answer is the next screen. The field is
                // cleared and RE-POINTED at the picker -- one field searches
                // whatever is on screen, and leaving ">clipboard" in it would
                // show a command that already ran.
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

    function back(): void {
        // The power flyout is the topmost thing Escape can mean. Windows
        // closes the flyout and leaves Start open, and so does this.
        if (root.powerOpen) {
            root.powerOpen = false;
            return;
        }

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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchored to one edge so wlr-layer-shell centres it on the other axis
    // without anyone measuring the screen.
    anchors {
        bottom: true
    }

    // MEASURED, because this comment used to claim the opposite. The dotted
    // form and the `margins { }` block cost qmllint exactly the same two
    // warnings at exactly the same line -- an [unqualified] "unknown grouped
    // property scope margins" and an [unresolved-type] -- because what it
    // cannot resolve is PanelWindow's `margins` itself, not the syntax used to
    // reach it. Both were run; the output was identical. The dotted form stays
    // because one line beats three, and for no other reason.
    margins.bottom: (root.barVisible ? Theme.barHeight : 0) + root.taskbarGap

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        item: panel
    }

    onVisibleChanged: {
        root.powerOpen = false;
        if (visible) {
            // input.text and NOT root.query: the field is the source of truth
            // and it drives `query` through onTextChanged.
            input.text = "";
            root.selected = 0;
            root.picker = LauncherState.pendingPicker;
            LauncherState.pendingPicker = "";
            input.forceActiveFocus();
        }
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: root.panelWidth
        implicitHeight: root.panelHeight

        radius: Fluent.overlayRadius
        antialiasing: true

        color: Fluent.acrylic(Theme.surface)
        border.width: 1
        border.color: Theme.outlineVariant

        // ---------------- The search field ----------------
        //
        // A PILL. Not the 4px box the Settings search box is.
        Rectangle {
            id: field

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.padding

            height: Fluent.searchFieldHeight
            radius: height / 2

            color: input.activeFocus ? Theme.surface : Theme.surfaceContainer
            border.width: 1
            border.color: input.activeFocus ? Theme.primary : Theme.outlineVariant

            Text {
                id: glass

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                text: Icons.search
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.primary
            }

            TextInput {
                id: input

                anchors.left: glass.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter

                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
                selectionColor: Qt.alpha(Theme.primary, 0.35)
                selectedTextColor: Theme.textOnSurface

                focus: true
                onTextChanged: {
                    root.query = text;
                    root.selected = 0;
                }

                Keys.onEscapePressed: root.back()
                Keys.onReturnPressed: root.activate()
                Keys.onEnterPressed: root.activate()
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Search for apps, settings, and documents"
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.outline
                }
            }
        }

        // ---------------- The filter chips ----------------
        //
        // Windows puts All / Apps / Documents / Web / Settings here and fills
        // the active one in accent with BLACK text, because in dark mode the
        // accent is the light shade of the ramp.
        //
        // Ours are the two lists this launcher actually has. Inventing five
        // chips to match the picture would be drawing controls that answer
        // nothing.
        Row {
            id: chips

            anchors.left: parent.left
            anchors.top: field.bottom
            anchors.leftMargin: root.padding
            anchors.topMargin: 12

            spacing: 8

            component FilterChip: Rectangle {
                id: chip

                property string label: ""
                property bool active: false

                signal picked

                width: chipText.implicitWidth + 28
                height: Fluent.chipHeight
                radius: height / 2

                color: chip.active
                    ? Theme.primary
                    : chipPointer.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                border.width: chip.active ? 0 : 1
                border.color: Theme.outlineVariant

                Text {
                    id: chipText

                    anchors.centerIn: parent
                    text: chip.label
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.captionSize
                    color: chip.active ? Theme.textOnPrimary : Theme.textOnSurface
                }

                MouseArea {
                    id: chipPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: chip.picked()
                }
            }

            FilterChip {
                label: "All"
                active: !root.commandMode
                onPicked: input.text = ""
            }

            FilterChip {
                label: "Commands"
                active: root.commandMode
                onPicked: input.text = ">"
            }
        }

        // ---------------- The results column ----------------
        ListView {
            id: list

            anchors.left: parent.left
            anchors.top: chips.bottom
            anchors.bottom: footer.top
            anchors.leftMargin: root.padding
            anchors.topMargin: 12
            anchors.bottomMargin: root.padding

            width: root.resultsWidth
            clip: true
            interactive: contentHeight > height
            currentIndex: root.selected
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            highlightRangeMode: ListView.ApplyRange

            visible: root.picker === "" && root.count > 0

            model: root.commandMode ? root.commandResults : root.results

            // ANCHORED, because it was not and it showed. Declared bare, the
            // bar takes the ListView's origin -- x 0, y 0 -- and draws its
            // handle down the LEFT edge beside the first section header, where
            // it reads as a stray accent rule against "All apps" rather than
            // as a scrollbar. It is a ListView, so `parent` is the view item
            // and not the content that moves; see the placement note in
            // components/ScrollBar.qml for why that distinction decides
            // whether a bar travels with the scroll it reports.
            ScrollBar {
                view: list

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            delegate: ResultRow {
                required property int index
                required property var modelData

                width: ListView.view.width

                rowIndex: index
                entry: modelData
                command: root.commandMode
                current: ListView.isCurrentItem
                header: root.sectionAt(index)
                headerCount: root.sectionCount(index)

                onHovered: root.selected = rowIndex
                onChosen: {
                    root.selected = rowIndex;
                    root.activate();
                }
            }
        }

        // ---------------- The preview column ----------------
        PreviewPane {
            anchors.left: list.right
            anchors.right: parent.right
            anchors.top: chips.bottom
            anchors.bottom: footer.top
            anchors.rightMargin: root.padding
            anchors.leftMargin: root.padding
            anchors.topMargin: 12
            anchors.bottomMargin: root.padding

            visible: root.picker === "" && root.current !== null

            entry: root.current
            command: root.commandMode

            onLaunched: root.launch(root.current)
            onActionChosen: action => root.runAction(action)
        }

        // Whichever picker a command opened. A Loader and not a visibility
        // flag: the clipboard picker spawns a `cliphist list` and a decode per
        // image row, and it should not be doing that while the application
        // list is what is on screen.
        Loader {
            id: pickerLoader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chips.bottom
            anchors.bottom: footer.top
            anchors.margins: root.padding
            anchors.topMargin: 12

            active: root.picker !== ""
            visible: active

            sourceComponent: clipboardComponent
        }

        Component {
            id: clipboardComponent

            ClipboardPicker {
                filter: root.query

                onPicked: LauncherState.close()
            }
        }

        // ---------------- The footer ----------------
        //
        // The band across the bottom of every Start menu: the account on the
        // left, the power button on the right, on a ground one shade darker
        // than the panel. ref/startmenu-classic-pinned-recommended.jpg is the
        // photograph, Fluent.startFooterHeight the measurement. Windows also
        // offers folder shortcuts along the right when the user turns them on;
        // the DEFAULT footer is these two things and nothing else, and the
        // default is what a fixed theme copies.
        //
        // TWO SOLID RECTANGLES, the second squaring the first's top corners.
        // The band has to keep the panel's rounded BOTTOM corners and give up
        // its top ones, and a Rectangle's radius is all four or none. Safe to
        // overlap only because the panel is opaque -- flyoutAlpha is 1.0, by
        // Johan's transparency rule -- so the double-painted strip does not
        // double any alpha.
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            height: Fluent.startFooterHeight

            readonly property color shade:
                Qt.tint(Fluent.acrylic(Theme.surface),
                        Qt.alpha("#000000", Fluent.startFooterShade))

            Rectangle {
                anchors.fill: parent
                radius: Fluent.overlayRadius
                color: footer.shade
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Fluent.overlayRadius
                color: footer.shade
            }

            // The hairline along the band's top edge: the same black-alpha
            // stroke every card in this theme carries, for the same reason --
            // in dark mode an edge is a SHADOW, not a highlight.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.alpha("#000000", Fluent.cardStrokeAlpha)
            }

            // ---------------- The account ----------------
            //
            // Portrait and name, one hover target. Windows opens account
            // options here; this desktop's account page is the settings
            // window's User page, so that is where it goes -- the same
            // "send them where the page already exists" rule the Quick
            // Settings chevrons follow.
            Rectangle {
                id: account

                anchors.left: parent.left
                anchors.leftMargin: root.padding
                anchors.verticalCenter: parent.verticalCenter

                width: accountRow.implicitWidth + Fluent.controlPaddingH * 2
                height: 40
                radius: Fluent.controlRadius

                color: accountPointer.pressed ? Fluent.fillPress
                    : accountPointer.containsMouse ? Fluent.fillSubtleHover
                    : "transparent"

                Row {
                    id: accountRow

                    anchors.left: parent.left
                    anchors.leftMargin: Fluent.controlPaddingH
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 12

                    Item {
                        anchors.verticalCenter: parent.verticalCenter

                        width: 32
                        height: 32

                        // The initial on the accent circle, exactly the
                        // settings rail's fallback, and the portrait over it
                        // when ~/.face exists. `cache: false` for the reason
                        // components/UserBlock.qml documents at length: the
                        // path never changes, only the file behind it does.
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: portrait.status !== Image.Ready
                            color: Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: SessionInfo.displayName.charAt(0).toUpperCase()
                                font.family: Theme.fontFamily
                                font.pointSize: Fluent.bodySize
                                font.weight: Fluent.strongWeight
                                color: Theme.textOnPrimary
                            }
                        }

                        Image {
                            id: portrait

                            anchors.fill: parent
                            source: SessionInfo.hasAvatar
                                ? `file://${SessionInfo.avatarPath}?r=${SessionInfo.avatarRevision}`
                                : ""
                            cache: false
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SessionInfo.displayName
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        color: Theme.textOnSurface
                    }
                }

                MouseArea {
                    id: accountPointer

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        LauncherState.close();
                        SettingsState.openPage("user");
                    }
                }
            }

            // ---------------- The power button ----------------
            Rectangle {
                id: powerButton

                anchors.right: parent.right
                anchors.rightMargin: root.padding
                anchors.verticalCenter: parent.verticalCenter

                width: 40
                height: 40
                radius: Fluent.controlRadius

                color: powerPointer.pressed ? Fluent.fillPress
                    : (powerPointer.containsMouse || root.powerOpen) ? Fluent.fillSubtleHover
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Icons.power
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurface
                }

                MouseArea {
                    id: powerPointer

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: root.powerOpen = !root.powerOpen
                }
            }
        }

        // A click anywhere else in the panel puts the flyout away, which is
        // what a context menu owes the surface under it. UNDER the flyout in
        // stacking order and only alive while it is up, so the menu's own
        // entries still take their clicks.
        MouseArea {
            anchors.fill: parent

            visible: root.powerOpen
            onClicked: root.powerOpen = false
        }

        // ---------------- The power flyout ----------------
        //
        // What the power button opens, which is Johan's call on where this
        // desktop's power actions LIVE: a context menu off the Start menu's
        // power button, exactly where Windows keeps its own. The drawing
        // mirrors powermenu/PowerMenu.qml row for row -- same MenuFlyout
        // geometry, same rest/hover/press fills, same three entries in the
        // same order -- and the ACTIONS are carried over invocation for
        // invocation from that file, where the header explains why getting
        // one wrong is not a cosmetic bug.
        Rectangle {
            id: powerFlyout

            anchors.right: parent.right
            anchors.rightMargin: root.padding
            anchors.bottom: footer.top
            anchors.bottomMargin: 4

            visible: root.powerOpen

            readonly property var actions: [
                {
                    label: "Sign out",
                    perform: () => Compositor.logout()
                },
                {
                    label: "Restart",
                    command: ["systemctl", "reboot"]
                },
                {
                    label: "Shut down",
                    command: ["systemctl", "poweroff"]
                }
            ]

            // The 4 of MenuFlyoutItemMargin's horizontal inset and the 2 of
            // its vertical one, the same two numbers powermenu/PowerMenu.qml
            // reads out of the control's LayoutRoot.
            readonly property int insetH: 4
            readonly property int insetV: 2

            width: 168
            height: powerEntries.implicitHeight + powerFlyout.insetV * 2 + 8

            radius: Fluent.overlayRadius
            antialiasing: true
            color: Fluent.acrylic(Theme.surface)
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                id: powerEntries

                x: powerFlyout.insetH
                y: powerFlyout.insetV + 4
                width: parent.width - powerFlyout.insetH * 2
                spacing: powerFlyout.insetV * 2

                Repeater {
                    model: powerFlyout.actions

                    Rectangle {
                        id: powerEntry

                        required property var modelData

                        width: parent.width
                        height: Fluent.controlHeight
                        radius: Fluent.controlRadius

                        // Rest, hover, press: transparent, Secondary,
                        // Tertiary. Hover brightens, press dims, nothing
                        // animates -- the MenuFlyoutItem rules PowerMenu.qml
                        // spells out over its own copy of this rectangle.
                        color: powerEntryPointer.pressed ? Fluent.fillPress
                            : powerEntryPointer.containsMouse ? Fluent.fillSubtleHover
                            : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Fluent.controlPaddingH
                            anchors.right: parent.right
                            anchors.rightMargin: Fluent.controlPaddingH
                            anchors.verticalCenter: parent.verticalCenter

                            text: powerEntry.modelData.label
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.bodySize
                            color: Theme.textOnSurface
                        }

                        MouseArea {
                            id: powerEntryPointer

                            anchors.fill: parent
                            hoverEnabled: true

                            // Closes the whole launcher first: the session may
                            // be about to come down, and the last frame should
                            // not be a half-dismissed menu.
                            onClicked: {
                                const action = powerEntry.modelData;
                                LauncherState.close();
                                if (action.perform)
                                    action.perform();
                                else
                                    Quickshell.execDetached(action.command);
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.picker === "" && root.count === 0
            text: `No results for "${root.query}"`
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.outline
        }
    }
}
