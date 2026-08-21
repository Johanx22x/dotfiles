// The settings window.
//
// AN ORDINARY WINDOW, NOT A LAYER SURFACE, and it is the only thing this
// shell puts on screen that is one. Everything else here belongs to the
// desktop itself -- the bar, the notifications, the launcher -- and a layer
// surface is what that means. This is a thing you open, read, change and
// close, so it gets a place in the window list, a workspace and the Alt+Tab
// order, all of which the compositor already knows how to do.
//
// IT LIVES IN THE SHELL PROCESS. The usual arrangement -- a separate
// `qs -p settings.qml` app writing a file the shell watches -- cannot work
// here, and fails silently rather than loudly: see the long note in
// Config.qml about statePath() hashing the entry point. In-process there is
// nothing to synchronise, because a switch flipped here assigns to the same
// singleton property the bar is already bound to.
//
// The cost, and it is a real one: this window is destroyed and rebuilt every
// time a .qml file is saved, since that reloads the whole config. Editing the
// shell with the settings window open closes it.
//
// LAYOUT: the macOS arrangement. A sidebar carrying who you are, a search
// field and the list of subjects; a content pane with the page's own title
// and the way out. The user block is at the top because a settings window is
// where you change things about YOUR session, and it is the only entry in
// there that is a person rather than a subject -- which is why it sits above
// the list with a gap rather than inside it.
//
// NOTHING HERE KNOWS WHAT PAGES EXIST. The rail is a Repeater over the pages
// declared in the host below, reading the title and glyph each page carries;
// search walks those same objects. Adding a page is one line here and one new
// file, and there is no third place to forget.
//
// NO TITLE BAR, and nothing here asks for that -- it is what Hyprland and Qt
// negotiate on their own. Qt offers to draw its own decorations, Hyprland
// answers that it will handle them server-side, and then draws none, which is
// what every other window on this desktop gets. Verified, not assumed:
// QT_WAYLAND_DISABLE_WINDOWDECORATION is NOT set anywhere in this config. So
// the header below is the only title bar this window has, and the close
// button in it is the only pointer-reachable way out.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings/pages"

FloatingWindow {
    id: root

    title: "Shell settings"

    // The rail sets the height and the widest page sets the width.
    // window_rules in hyprland.lua carries the same pair of numbers, because
    // a floating rule without a size lets Hyprland keep whatever tiling
    // geometry the window had -- and measured, that was 1251x1348.
    implicitWidth: 820
    implicitHeight: 580
    minimumSize: Qt.size(680, 460)

    // ---------------- Transparency ----------------
    //
    // TWO THINGS ARE NEEDED and neither works without the other: an alpha
    // channel in the surface (opaque: false, otherwise Qt composites the
    // window onto black and the alpha below is silently ignored) and a colour
    // that has an alpha (the Rectangle further down).
    //
    // The blur behind it is Hyprland's and needs no rule: decoration.blur is
    // globally enabled and the compositor applies it behind any translucent
    // window, the same way it already does for kitty.
    //
    // NOT the `opacity` window rule that Nautilus gets in hyprland.lua. That
    // fades the WHOLE window, text and switches included, and this window is
    // small type over a wallpaper. Here only the background carries the
    // alpha; every glyph on top of it stays fully opaque.
    color: "transparent"
    surfaceFormat.opaque: false

    visible: SettingsState.isOpen

    // The compositor's close request -- SUPER + W, or anything else that asks
    // the window to go away. Without this the flag stays true, the window is
    // gone, and the next toggle would appear to do nothing: it would be
    // turning OFF a window that is not there.
    onClosed: SettingsState.close()

    // Search resets when the window is put away. Coming back to a filtered
    // list you filtered ten minutes ago looks like a window with most of its
    // settings missing.
    onVisibleChanged: {
        if (!root.visible)
            search.clear();
    }

    // Filled by pageHost below, once: the pages this machine actually offers,
    // in rail order. NOT `pageHost.children` any more -- a page can opt out
    // when the compositor cannot back it, and the rail, the title and search
    // all have to agree on the shortened list.
    property var pages: []

    Rectangle {
        anchors.fill: parent

        // The same glass as the bar, and therefore the same value this window
        // edits -- move the opacity and the window showing the number goes
        // with it. No radius: Hyprland rounds the window itself, at the
        // `rounding` in hyprland.lua that everything else on screen agrees
        // with.
        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // FocusScope and not a bare Item: Escape has to arrive somewhere, and a
    // key handler only receives what a focused item lets through.
    //
    // NO MARGIN ON THIS ONE. It used to inset everything by groupPadding,
    // which is what a window of floating cards wants and the exact opposite
    // of what a sidebar wants: the rail has to run into the left and bottom
    // edges for its panel to read as part of the window frame rather than as
    // another card. Each area below carries its own padding instead.
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: SettingsState.close()

        // ================= SIDEBAR =================
        Item {
            id: rail

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.bottom: parent.bottom

            readonly property int padding: 10

            width: 210

            // The panel. A TINT OVER THE GLASS and not a second glass layer:
            // an opaque colour at its own alpha would compound with the
            // window's, and the sidebar would come out noticeably more solid
            // than the pane beside it -- the two would stop looking like one
            // window seen through one sheet.
            //
            // 0.18 AND NO DIVIDING LINE. It started at 0.5 with a hairline
            // down the right edge, which is how a file manager does it, and
            // in a window this size it read as two windows stitched together:
            // the line drew more attention than the boundary deserved, and
            // the step in tone did the same job twice over. What is wanted is
            // only enough separation to tell the navigation from the content
            // at a glance -- past that, every bit of contrast spent on the
            // frame is contrast taken from the selected entry, which is the
            // thing actually worth seeing.
            //
            // It runs into the left, top and bottom edges of the window on
            // purpose. Hyprland rounds those corners itself, so the panel
            // ends in the window's own curve instead of in a straight cut a
            // few pixels inside it.
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.surfaceContainerHigh, 0.18)

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            UserBlock {
                id: userBlock

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: rail.padding

                selected: SettingsState.currentPage === 0 && !root.searching
                onClicked: {
                    search.clear();
                    SettingsState.currentPage = 0;
                }
            }

            SearchField {
                id: search

                anchors.top: userBlock.bottom
                anchors.topMargin: rail.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: rail.padding

                placeholder: "Search"

                onEscaped: {
                    if (text !== "")
                        clear();
                    else
                        SettingsState.close();
                }
            }

            // The subjects. The user block above is deliberately not one of
            // them even though it selects the same way: it is a different
            // kind of thing, and putting it in the list would make "Johan"
            // read as a settings category.
            //
            // Index 0 is the user page, so the Repeater starts at 1 -- see
            // the page host at the bottom of this file for the order.
            Flickable {
                anchors.top: search.bottom
                anchors.topMargin: rail.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: rail.padding

                contentWidth: width
                contentHeight: railItems.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: railItems

                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.pages

                        SettingsNavItem {
                            required property var modelData
                            required property int index

                            visible: index > 0
                            glyph: modelData.glyph
                            label: modelData.title
                            selected: SettingsState.currentPage === index && !root.searching
                            onClicked: {
                                search.clear();
                                SettingsState.currentPage = index;
                            }
                        }
                    }
                }
            }
        }

        // ================= CONTENT =================

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.margins: Theme.groupPadding
            height: Theme.groupHeight

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.right: closeButton.left
                anchors.verticalCenter: parent.verticalCenter

                text: root.searching ? "Search" : (root.pages[SettingsState.currentPage]?.title ?? "")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // Close. In the corner, round, and the only control in this
            // window that is not a setting -- which is why it is a bare glyph
            // on the glass rather than a pill like everything else.
            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: Theme.groupHeight
                implicitHeight: Theme.groupHeight
                radius: height / 2

                color: closeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: closeMouse.containsMouse ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsState.close()
                }
            }
        }

        // ---------------- Pages ----------------
        //
        // Flickable rather than a plain Column: the window is resizable, and
        // one that can be made shorter than its contents needs somewhere for
        // the rest to go. It does not scroll while everything fits.
        //
        // EVERY PAGE IS BUILT AND ONE IS VISIBLE. It keeps each page's state
        // -- a scroll position, a half-typed password, an expanded row --
        // across a trip to another page, which a Loader would throw away.
        //
        // The cost is that `visible` on a page means only "the rail has me
        // selected", which SettingsPage drives from its index. It does NOT
        // mean anybody is looking: this window is hidden far more often than
        // it is open, and hiding a window leaves its content item visible.
        // Pages that turn hardware on when looked at -- the microphone meters,
        // the Wi-Fi scanner, Bluetooth discovery -- must gate on
        // `onScreen` instead, which is that flag AND the window being open.
        Flickable {
            anchors.top: header.bottom
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.groupPadding

            contentWidth: width
            contentHeight: pageHost.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: !root.searching

            Column {
                id: pageHost

                width: parent.width
                spacing: 0

                // THE ORDER HERE IS THE ORDER IN THE RAIL, and index 0 is
                // reached through the user block rather than through a rail
                // entry. Everything after it is a subject, roughly in the
                // order someone would go looking: what it looks like, then
                // what is on screen, then the machine, then the reference
                // material.
                UserPage {}
                AppearancePage {}
                WallpaperPage {}
                BarPage {}
                NotificationsPage {}
                DisplayPage {}
                AudioPage {}
                InputPage {}
                NetworkPage {}
                BluetoothPage {}
                AppsPage {}
                KeybindsPage {}
                AboutPage {}

                Component.onCompleted: {
                    // Each page is told where it sits, which is how it knows
                    // whether it is the visible one. Done here rather than
                    // written into each file because a page should not have
                    // to know its own position in a list it is not holding.
                    //
                    // PAGES THAT ARE NOT AVAILABLE ARE LEFT OUT ENTIRELY rather
                    // than hidden -- see `available` in SettingsPage.qml. They
                    // keep index -1, which no page can be current at, so they
                    // never draw; and they are absent from root.pages, so they
                    // take no rail entry and cannot be found by search.
                    //
                    // Computed ONCE and not bound, deliberately: what a page
                    // depends on is what the compositor can do, and that cannot
                    // change without the session ending. A binding here would
                    // re-index the whole rail on any child change for an answer
                    // that is fixed for the lifetime of the process.
                    const shown = [];
                    for (const page of children) {
                        if (!page.available)
                            continue;
                        page.index = shown.length;
                        shown.push(page);
                    }
                    root.pages = shown;
                }
            }
        }

        // ---------------- Search results ----------------
        SettingsSearch {
            anchors.top: header.bottom
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.groupPadding

            visible: root.searching
            query: search.text
            pages: root.pages

            onPicked: (page, row) => {
                SettingsState.highlightRow = row;
                SettingsState.currentPage = page;
                search.clear();
            }
        }
    }

    readonly property bool searching: search.text.trim() !== ""
}
