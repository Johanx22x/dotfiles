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
// button in it is the only pointer-reachable way out. Both are drawn by the
// theme now; SettingsHeader.qml carries that promise across the seam, because
// a facade can require a property and cannot require a button.
//
// WHAT THIS FILE STILL DRAWS IS NOTHING. The glass, the rail's tint, the
// header's two items, the pill behind a rail entry, the person at the top of
// the sidebar and a search result are all the theme's -- SettingsChrome,
// SettingsHeader, SettingsNavItem, UserBlock and SettingsResult beside this
// file are the facades in front of them. What is left here is which pages
// exist, which one is selected, where everything sits, and the three
// scrollbars that hang outside the panes they describe.

import Quickshell
import QtQuick
import qs
import qs.components
import qs.modules.settings.pages

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
        if (root.visible)
            root.everOpened = true;
        else
            search.clear();
    }

    // HAS THIS WINDOW EVER BEEN OPENED IN THIS SHELL PROCESS. What the page
    // host below is loaded on, and it only ever goes one way: once the pages
    // exist they are kept, so everything the window promises about coming back
    // to where you were still holds. See the Loader for the whole argument.
    property bool everOpened: false

    // Filled by pageHost below, once: the pages this machine actually offers,
    // in rail order. NOT `pageHost.children` any more -- a page can opt out
    // when the compositor cannot back it, and the rail, the title and search
    // all have to agree on the shortened list.
    property var pages: []

    // THE WINDOW'S OWN SURFACES, and the two numbers the rail is built on.
    // What it draws -- the glass under everything and the tint down the rail
    // -- is the theme's; `railWidth` and `railPadding` are read back out of it
    // below, and its header says why they are declared on that side rather
    // than measured off whatever the theme drew.
    //
    // FIRST CHILD, as the glass rectangle it replaces was, so nothing about
    // what paints over what has changed.
    SettingsChrome {
        id: chrome

        anchors.fill: parent
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

            // BOTH NUMBERS COME OUT OF THE CHROME, which is the one place
            // they are written. The panel the theme paints over this
            // rectangle is drawn from the same `railWidth`, so the tint and
            // the rail cannot end in different places; the padding is what
            // leaves the empty strip the scrollbar below lives in, and
            // tests/scrollbar-target.py asserts on the three pixels it takes
            // out of it. See SettingsChrome.qml for why a theme does not get
            // to move either of them.
            // AND THIS ITEM DRAWS NOTHING AT ALL NOW. The panel that used to
            // be its first child is one of the two rectangles the chrome
            // paints, underneath everything here, over exactly this
            // rectangle -- which is what reading `railWidth` from there
            // rather than writing 210 twice is for.
            readonly property int padding: chrome.railPadding

            width: chrome.railWidth

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
            //
            // ScrollList AND NOT A PLAIN Flickable, WHICH IS THE BUG THIS
            // FILE WAS EDITED FOR. A Flickable answers a wheel notch by
            // starting a scroll animation of its own, and for as long as that
            // animation is running it takes the next mouse press for itself
            // in order to stop the flick -- the item under the pointer is
            // never told there was a press at all. So the click that follows
            // a scroll is thrown away, and only the one after it, half a
            // second later, arrives. ScrollList moves contentY on the wheel
            // itself and never starts that animation, so nothing is ever
            // owed a click.
            //
            // ONLY TWO ENTRIES HERE ARE EVER REACHED BY SCROLLING, which is
            // why a window-wide effect was reported as one page misbehaving.
            // At this window's fixed 820x580 the rail shows 452 px and its
            // fourteen entries are 530 tall, so Updates and About are the
            // only two below the fold -- and About is not a page anybody
            // visits. "Updates does not open on the first click" was the
            // whole of the report, and it was the rail, not that page.
            //
            // AND IT TOOK THREE GOES, because for two of them the handler in
            // ScrollList was declining every wheel event this machine sends
            // and the Flickable was quietly doing the scrolling after all --
            // so the fix was in the tree, doing nothing, while the click went
            // on being eaten. The whole account is in components/ScrollList.qml.
            // Dragging the rail is answered separately, on the entries
            // themselves, in SettingsNavItem.qml.
            ScrollList {
                id: railScroll

                anchors.top: search.bottom
                anchors.topMargin: rail.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: rail.padding

                contentHeight: railItems.implicitHeight

                // The bar this rail wants sits in the padding beside it, which
                // is placed below and anchored from outside; the one ScrollList
                // would draw over its own inside edge is not wanted here.
                showScrollBar: false

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

            // The rail scrolls on a short window -- fourteen subjects do not
            // fit under the search field at 700px tall -- and until this was
            // drawn nothing said so: the list simply ended, and the entries
            // below the cut were as good as absent.
            //
            // IN THE RAIL'S OWN PADDING, not over the entries. The panel
            // already insets its contents by `padding` on every side, so the
            // strip down the right of it is empty by construction, and putting
            // the bar there costs no width and covers no label. Four pixels
            // centred in ten leaves three on each side.
            //
            // Anchored to the panel rather than to the list it describes,
            // because that padding belongs to the panel; the top and bottom
            // still come off the list, so the track is exactly as long as the
            // thing it is a picture of.
            //
            // NO MARGIN OVERRIDE, and this file used to carry one. The
            // component widened its press target by seven on each side, and
            // seven reached four pixels back over every entry: pressing the
            // right-hand edge of a navigation row scrolled the rail instead
            // of opening the page. It asked for three, which stopped the
            // target at the entries and also stopped it dead at the edge of
            // this channel; the component now reaches three inward by
            // default, so the first half is the default and the second half
            // was never wanted. Nothing lies between this channel and the
            // page pane but window padding, and the target spends the rest of
            // its width out there: measured offscreen, an entry is selected
            // everywhere up to x=199 and the bar answers from 200 to 217,
            // four pixels short of the pane.
            ScrollBar {
                view: railScroll

                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.top: railScroll.top
                anchors.bottom: railScroll.bottom
            }
        }

        // ================= CONTENT =================

        // The page's name and the way out. Both are drawn by the theme; what
        // stays here is WHICH NAME -- "Search" while the field has something
        // in it, otherwise the selected page's own title, which is a question
        // about the two panes below and not about the header.
        //
        // NO HEIGHT SET HERE. The header reports one, floored at
        // Theme.groupHeight, and an Item's height follows its implicitHeight
        // until something assigns one. Both panes below still anchor to
        // `header.bottom`, which is what that number is for.
        SettingsHeader {
            id: header

            anchors.top: parent.top
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.margins: Theme.groupPadding

            heading: root.searching ? "Search" : (root.pages[SettingsState.currentPage]?.title ?? "")

            onCloseRequested: SettingsState.close()
        }

        // ---------------- Pages ----------------
        //
        // A scrolling view rather than a plain Column: the window is
        // resizable, and one that can be made shorter than its contents needs
        // somewhere for the rest to go. It does not scroll while everything
        // fits.
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
        //
        // ScrollList for the same reason the rail is one, and it matters here
        // too: a plain Flickable swallows the press that follows a wheel
        // notch, so scrolling down a page and reaching for the switch that
        // just came into view costs a click. The capped lists inside the
        // pages are already ScrollLists and already take the wheel first
        // while they can still move; this only settles what happens when the
        // pointer is on the page itself.
        ScrollList {
            id: pages

            anchors.top: header.bottom
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.groupPadding

            contentHeight: pageHost.implicitHeight
            visible: !root.searching

            // As in the rail: the bar for this pane is placed below, in the
            // margin that is already there.
            showScrollBar: false

            // BUILT THE FIRST TIME THE WINDOW IS OPENED, AND KEPT AFTER THAT.
            // `everOpened` latches true and never goes back, so this is not a
            // Loader in the usual sense of throwing things away -- it saves
            // exactly one case, the shell that is started and whose settings
            // window is never opened, which is nearly every shell start.
            //
            // AND NEARLY EVERY SHELL START IS WHAT MAKES IT WORTH DOING. The
            // fourteen pages below are about 10,100 lines of QML, all of it
            // constructed before the first frame is drawn, and Quickshell
            // reloads the whole config every time a .qml file is saved -- so
            // the bill is paid again on every save while editing the shell,
            // which is when somebody is most likely to be watching it come up.
            //
            // WHAT WAS MEASURED, and it is smaller than the line count
            // suggests. A probe holding this window and nothing else, in the
            // tree with this change and in the tree without it, timing from
            // the moment the process was launched to the moment its shell root
            // reported itself complete -- seven runs each, alternating between
            // the two so a busy moment could not land on one side:
            //
            //     without    215 237 221 213 219 221 233 ms   median 221
            //     with       176 192 188 176 176 187 188 ms   median 187
            //
            // Thirty-four milliseconds, and every run with it was faster than
            // every run without it. Building QML objects is not where a shell
            // start goes -- the process, Qt, the Wayland connection and the
            // scene graph are the rest of those 187 ms -- so this is close to
            // all of what there was to take, and it is not a lot.
            //
            // AND THE PAGES ARE STILL THERE AFTERWARDS, which is the half
            // that would matter if it were wrong. The same probe, asked how
            // many pages the window is holding:
            //
            //                            without    with
            //     never opened                13       0
            //     opened on the sound page    13      13
            //     closed again                13      13
            //
            // IT DOES NOT COST THE STATED GOAL. The note further down about
            // every page being built and kept alive is about state surviving a
            // trip to ANOTHER PAGE, and about `visible` being the wrong flag
            // for "somebody is looking at me". Both still hold: after the
            // first opening this is exactly the tree that used to be here, and
            // nothing is destroyed when the window closes.
            //
            // What it does change is WHEN the pages are built: on the first
            // open rather than at startup, so those 34 ms land on the frame
            // that first shows the window instead. That is the trade -- a cost
            // nobody asked for at every start, against the same cost once, at
            // the moment somebody did ask.
            Loader {
                id: pageHost

                width: parent.width
                active: root.everOpened

                // Kept alive deliberately: `active` never returns to false.
                sourceComponent: Component {
                    Column {
                        // `parent` is the Loader, which has a width. The Loader
                        // writes the same number in on its own; the binding is
                        // here so this does not depend on that.
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
                        RecordingPage {}
                        InputPage {}
                        NetworkPage {}
                        BluetoothPage {}
                        AppsPage {}
                        KeybindsPage {}
                        // Second to last, in front of About. It is about the
                        // machine rather than about the shell, which is the
                        // group it lands in, and About stays last because it
                        // is the reference material and holds the one button
                        // that undoes everything above it.
                        //
                        // APPENDED RATHER THAN INSERTED, deliberately: page
                        // indices are positions, `qs ipc call settings page N`
                        // addresses them by number, and a page dropped into
                        // the middle renumbers every bind after it. This moves
                        // About alone.
                        UpdatesPage {}
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
            }
        }

        // ---------------- Search results ----------------
        // The pane's own bar, and the reason the pages list above says it
        // does not scroll while everything fits: now that it can be seen to
        // scroll, it can also be seen not to. Most pages fit on a window of
        // any size, and on those nothing is drawn here.
        //
        // IN THE MARGIN THE WINDOW ALREADY LEAVES, in the gap between the
        // right edge of the pages and the edge of the window, which is empty
        // on every page by construction. So it takes no width from the cards,
        // covers nothing on them, and lands where a window's scrollbar is
        // expected to be -- at the frame, rather than a card's width inside it.
        ScrollBar {
            view: pages

            anchors.left: pages.right
            anchors.leftMargin: 4
            anchors.top: pages.top
            anchors.bottom: pages.bottom
        }

        SettingsSearch {
            id: searchResults

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

        // And the same bar over the results, in the same margin, for the same
        // reason. It hides itself along with the pane: `visible` in QML is
        // effective visibility, so the moment the search results are put away
        // the list reads as invisible and this stops being drawn -- without
        // this file having to repeat the condition that decides which of the
        // two panes is up.
        ScrollBar {
            view: searchResults.view

            anchors.left: searchResults.right
            anchors.leftMargin: 4
            anchors.top: searchResults.top
            anchors.bottom: searchResults.bottom
        }
    }

    readonly property bool searching: search.text.trim() !== ""
}
