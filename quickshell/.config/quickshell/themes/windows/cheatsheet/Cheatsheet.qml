// THE CHEATSHEET, DRAWN AS A SETTINGS PAGE.
//
// Windows ships no keyboard-shortcut overlay at all, so there is nothing here
// to recreate and the only question worth asking is which Windows shape this
// content belongs in. It is a long list of labelled rows under headings, and
// that is a Settings page and nothing else. The two photographs it is drawn
// against are settings-system-about.jpg and
// settings-personalization-taskbar.jpg, and what they settle is the
// silhouette: a big page title over one scrolling column, section headers that
// are TEXT AND SPACE -- no rule, no tint, no glyph -- and the whole thing on a
// window ground rather than a dialog one.
//
// A PAGE, NOT A DIALOG, is the distinction the two photographs make and the
// docs do not: Mica ground, OverlayCornerRadius, a one-pixel stroke, and the
// desktop dimmed behind it because while this is up the desktop is not taking
// input and dimming is the only way Windows says so.
//
// WHERE THE LIST COMES FROM, AND WHY IT CANNOT GO STALE. The compositor, asked
// fresh on every open -- not a list written down here and not hyprland.lua
// parsed by hand. The compositor is the only thing that knows what is bound
// right now, a reload a minute ago included. The one thing it cannot say is
// what a bind DOES: the config is Lua, so every dispatcher reports as "__lua"
// with an opaque callback index. The meaning lives in the description, in
// "Category: what it does" form, and the category before the colon is what
// groups the rows.
//
// A BIND WITH NO DESCRIPTION IS INVISIBLE HERE, deliberately -- that filter is
// what keeps the sheet from listing ten identical rows for SUPER + 1 through
// SUPER + 0.
//
// THE CHIPS ARE NOT DRAWN HERE. components/BindRow.qml is the facade and the
// theme's own components/BindRow.qml draws it; this file only measures the
// gutter they have to fit in and hands over the numbers that measurement was
// made with. Same for the scroll bar. See the note at keyGutter for why those
// numbers cross the seam rather than being chosen on the far side of it.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
// ScrollList, which the sections sit in, and the ScrollBar and BindRow facades.
import qs.components
import qs.modules.cheatsheet
// The theme's own singleton, by MODULE and never `import ".."`. See Fluent.qml.
import qs.themes.windows

PanelWindow {
    id: root

    // The ShellScreen this sheet belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- How big the page is allowed to be ----------------

    readonly property int availableWidth: Math.max(0, (root.modelData?.width ?? 0) - Fluent.sheetMargin * 2)
    readonly property int availableHeight: Math.max(0, (root.modelData?.height ?? 0) - Fluent.sheetMargin * 2)

    // SettingsCardPadding as the PAGE's inset. Microsoft publishes none for a
    // page, and 16 is the closest published figure -- it is what every card on
    // such a page already keeps inside itself, so the frame and the cards on it
    // agree rather than nesting two different insets.
    readonly property int pagePadding: Fluent.cardPadding

    // What is left once the page has had its padding.
    readonly property int contentRoom: Math.max(0, root.availableWidth - root.pagePadding * 2)

    // HOW WIDE THE COLUMN WANTS TO BE: the chord gutter, the gap after it, and
    // the longest description in the sheet. MEASURED rather than written down,
    // for the same reason the gutter is -- a width chosen here goes stale the
    // first time somebody writes a longer description, and the way it goes
    // stale is a row that quietly ends in an ellipsis.
    readonly property int naturalColumnWidth: {
        // The font is READ here, not merely inside the FontMetrics: a binding
        // re-runs when a property IT read changes, and advanceWidth() is a
        // function call. Without this line the column is measured once, at
        // whatever type size the shell first came up at.
        if (bodyMetrics.font.family === "" || bodyMetrics.font.pointSize <= 0)
            return root.keyGutter + root.rowGap;

        let widest = 0;
        for (const group of root.groups)
            for (const bind of group.binds)
                widest = Math.max(widest, bodyMetrics.advanceWidth(bind.text));

        return root.keyGutter + root.rowGap + Math.ceil(widest);
    }

    // ...capped by the published page maximum and by what there actually is. On
    // a screen too narrow for one full column the descriptions elide, which is
    // the honest outcome: there is no width at which they both fit and stay
    // this size.
    readonly property int contentWidth: Math.min(root.naturalColumnWidth,
                                                 Fluent.pageMaxWidth,
                                                 root.contentRoom)

    // The space a row leaves between the chord and its description. Here
    // because naturalColumnWidth adds it up, and handed to BindRow so that the
    // row leaves exactly the gap the column was sized for.
    readonly property int rowGap: 12

    // The description's face, for measuring the longest one. The chips have
    // their own, below: they are drawn a size smaller.
    FontMetrics {
        id: bodyMetrics

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
    }

    // The chords sit in a fixed-width gutter, flush with its RIGHT edge, so the
    // key itself is always the chip nearest its own description and every
    // description in the column starts at the same x. BindRow keeps that
    // promise; this is the width it keeps it in.
    //
    // ADDED UP FROM THE CHORDS, AND NOT COLLECTED FROM THE ROWS. Two earlier
    // answers were both wrong in ways worth keeping written down. A constant
    // 150, taken off the widest chord Hyprland binds, pushed niri's four-chip
    // monitor binds off the left edge of the card entirely. Asking the rows how
    // wide they came out and keeping the largest fixed the overflow and left a
    // running maximum, which can only grow: measured on this machine's
    // fifty-two described binds, the gutter opens at 226, goes to 298 when the
    // type size is taken to 16pt, and STAYS at 298 when it is put back --
    // seventy-two pixels of nothing in front of every description for the rest
    // of the session.
    //
    // A sum of advance widths and paddings is an ordinary binding, so it goes
    // down as readily as up, and it is still right for whatever the compositor
    // turns out to bind, a fifth modifier nobody has thought of included.
    readonly property int keyGutter: {
        // chipMetrics' own font and not Theme's, though they hold the same
        // value: read after the metrics have caught up rather than racing them.
        if (chipMetrics.font.family === "" || chipMetrics.font.pointSize <= 0)
            return root.keyGutterFloor;

        let widest = 0;

        for (const group of root.groups) {
            for (const bind of group.binds) {
                if (bind.keys.length === 0)
                    continue;

                let chord = root.chipSpacing * (bind.keys.length - 1);
                for (const key of bind.keys)
                    chord += chipMetrics.advanceWidth(key) + root.chipPadding;

                widest = Math.max(widest, chord);
            }
        }

        // Rounded up ONCE, at the end. A chip is as wide as its label plus its
        // padding and a label is a fractional number of pixels; rounding each
        // chip first adds up to a gutter slightly wider than the row it is
        // modelling, and a model allowed to disagree with the thing it models
        // cannot be used to notice the two drifting apart.
        return Math.max(root.keyGutterFloor, Math.ceil(widest));
    }

    // A FLOOR AND NOT A DEFAULT: it keeps a short list from closing up, and it
    // is what the gutter reads as before the compositor has answered.
    readonly property int keyGutterFloor: 150

    // The chip's geometry, HERE rather than as literals in the theme's BindRow,
    // because the gutter above is an arithmetic model of a chip -- a model that
    // does not add up the numbers the chip is drawn with drifts, and drifts
    // silently: the chords simply start hanging off the edge again, with
    // nothing failing to load and nothing reaching a log.
    //
    // Fluent.controlPaddingH is Button's and MenuFlyoutItem's own 11, the
    // nearest published horizontal inset Windows gives a small labelled
    // control; doubled, it is a chip's padding around its key name. The spacing
    // between two chips in a chord is OURS -- Windows draws no key caps
    // anywhere.
    readonly property int chipPadding: Fluent.controlPaddingH * 2
    readonly property int chipSpacing: 4

    // The chip label's face, so advanceWidth() measures the text in the face it
    // is actually drawn in. It travels WHOLE -- this value, through BindRow's
    // chipFont, to the chip -- so measured and drawn are one value rather than
    // two spellings that agree today. Caption is the smallest step of the
    // Windows ramp and the one a key cap belongs on.
    FontMetrics {
        id: chipMetrics

        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        font.weight: Fluent.strongWeight
    }

    // Shape: [ { name: "Apps", binds: [ { keys: [...], text: "..." } ] } ].
    // Built at the bottom of this file.
    readonly property var groups: root.groupedBinds

    // The order the categories are shown in: roughly how often you reach for
    // them, with the shell's own controls last. A category not named here still
    // appears, at the end, in the order the compositor reported it -- so a new
    // one is never silently dropped.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // ---------------- Turning a keysym into something readable ----------------
    //
    // Left alone, xkb keysyms and mouse codes read like config rather than like
    // the key under your finger.
    readonly property var keyNames: ({
        "RETURN": "Enter",
        "SPACE": "Space",
        "ESCAPE": "Esc",
        "slash": "/",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "mouse_up": "Scroll ↑",
        "mouse_down": "Scroll ↓",
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic mute",
        "XF86AudioNext": "Next",
        "XF86AudioPrev": "Prev",
        "XF86AudioPlay": "Play",
        "XF86AudioPause": "Pause",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright −"
    })

    function keyName(key: string): string {
        // The fallback strips the XF86 prefix rather than printing it: an
        // unmapped media key reads better as "AudioStop" than as the whole
        // keysym, so a key nobody mapped still looks deliberate.
        return root.keyNames[key] ?? (key.startsWith("XF86") ? key.slice(4) : key);
    }

    screen: modelData
    visible: CheatsheetState.isOpen

    WlrLayershell.namespace: "quickshell-cheatsheet"
    // Overlay, like the power menu: this has to be readable over a fullscreen
    // window, which is exactly when you have forgotten the bind for getting out
    // of one.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, or Escape never arrives. Stated once and never flipped with
    // `isOpen`: `visible` tears the surface down, so nothing holds the keyboard
    // while the sheet is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring
    // all four edges stretches the layer surface instead, and the size the
    // compositor picked is then not a size QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space and never be pushed up by the taskbar's reservation:
    // the sheet covers the bar rather than stopping above it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    Connections {
        target: CheatsheetState

        function onIsOpenChanged(): void {
            if (!CheatsheetState.isOpen)
                return;

            // Re-read on every open: a config reload between two openings is
            // exactly the case a cached list gets wrong. Only where the
            // compositor can be asked at all -- otherwise the sheet says so
            // instead, below, and the query would spawn a process to fail.
            if (Compositor.can("bindsIntrospection"))
                Compositor.refreshBinds();
            sheet.forceActiveFocus();
        }
    }

    Rectangle {
        id: sheet

        // Sized from the SCREEN and not from `parent`: the window's contentItem
        // stays 0x0 whatever the layer surface measures, so `anchors.fill:
        // parent` collapses to nothing.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // SmokeFillColorDefault -- see PowerMenu.qml for the source and for why
        // #4D000000 is the one hex literal in this theme. It is here for the
        // same reason it is there: while this page is up the desktop behind it
        // is not taking input, and dimming is the whole of how Windows says so.
        // A page drawn as an ordinary window would be lying about that.
        //
        // 0x4D is 0.30, under the compositor's 0.84 ignore_alpha, so this fill
        // is left out of the blur and what shows through is a dimmed but sharp
        // desktop.
        color: "#4D000000"

        focus: true

        Keys.onEscapePressed: CheatsheetState.close()
        // The key that opened it closes it, without the modifier: while the
        // sheet holds the keyboard the SUPER + / bind still fires from the
        // compositor, but a bare / is the reflex once you are looking at it.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question)
                CheatsheetState.close();
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. Below the page in the file, so the page
        // takes its own clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: CheatsheetState.close()
        }

        Rectangle {
            id: page

            anchors.centerIn: parent

            implicitWidth: root.contentWidth + root.pagePadding * 2

            // The height is the content's, and it is bounded because the list
            // inside it is -- see list.height. Capped here as well so that a
            // header taller than the screen, which is not a real case but is
            // the sort of thing that makes a modal unclosable, still cannot
            // push the page off its own screen.
            implicitHeight: Math.min(layout.implicitHeight + root.pagePadding * 2,
                                     root.availableHeight)

            // OverlayCornerRadius: the 8 Windows gives windows, flyouts and
            // dialogs alike. There is no third radius in the system.
            radius: Fluent.overlayRadius

            // MICA, WHICH IS THE ONE WINDOWS MATERIAL THIS SHELL GETS FOR FREE.
            // Mica samples the wallpaper once and is static, and hyprland.lua's
            // blur-quickshell rule is xray -- it samples the wallpaper and not
            // the windows in front of it. The two match by accident. Mica's
            // documented fallback is SolidBackgroundFillColorBase #202020,
            // which is exactly windows-11-dark's ui_surface, so Theme.surface
            // is the tint.
            //
            // Theme.glass() and NOT Fluent.acrylic() here, which is the one
            // place in this file the two materials have to be told apart: this
            // is a window on the desktop, not a flyout over something, and the
            // glass alpha is the one the blur rule does not ignore.
            color: Theme.glass(Theme.surface)

            // The one-pixel stroke every Windows surface with a corner radius
            // carries. No scheme role holds a black overlay, so this reads the
            // divider role -- the one role that is a hairline over a surface
            // rather than a fill.
            border.width: 1
            border.color: Theme.outlineVariant
            antialiasing: true

            // Dialog show, from the motion table: scale 1.05 -> 1.0 over 250ms
            // on the single spline WinUI ships, opacity linear over 83. The
            // scale comes DOWN and not up -- a Windows surface arrives by
            // settling, never by growing.
            opacity: CheatsheetState.isOpen ? 1 : 0
            scale: CheatsheetState.isOpen ? 1 : 1.05

            Behavior on opacity {
                NumberAnimation { duration: Fluent.fasterMs; easing.type: Easing.Linear }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Fluent.normalMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            // Swallows clicks that would otherwise reach the dismiss area
            // behind the page.
            MouseArea {
                anchors.fill: parent
            }

            // ---------------- The scroll indicator ----------------
            //
            // IT ANSWERS "IS THERE MORE", which the column cannot answer for
            // itself: a row cut off by the bottom edge looks exactly like a row
            // that happens to end there, and one column of fifty-two binds fits
            // on no screen here.
            //
            // IN THE PAGE'S OWN PADDING, so it costs no width. Windows' bar is
            // a 12px gutter and the page keeps 16 on each side, so centring it
            // in what is left over overlaps nothing -- which is also why the
            // list is told not to draw its own, since ScrollList's sits just
            // inside the list's right edge, on top of the descriptions.
            //
            // POSITIONED AND NOT ANCHORED TO THE LIST, because the list is a
            // GRANDCHILD of this page and anchors reach only a parent or a
            // sibling. QML says so at runtime, as a warning, and leaves the bar
            // at the top of the page. `layout` is a child here, so the list's
            // own y inside it is the offset that would otherwise be missing.
            ScrollBar {
                view: list

                anchors.right: parent.right
                anchors.rightMargin: (root.pagePadding - width) / 2

                y: layout.y + list.y
                height: list.height
            }

            Column {
                id: layout

                anchors.centerIn: parent
                width: root.contentWidth

                // ZERO, and that is the section header style doing its job: its
                // own 30 above separates the first section from the title and
                // every later one from the rows before it. A spacing here as
                // well would be that gap counted twice.
                spacing: 0

                // ---------------- The page title ----------------
                Item {
                    id: header

                    // The content width and not the Column's implicit one. The
                    // sections live in a Flickable, and a Flickable's implicit
                    // width is not its content's -- so "as wide as my widest
                    // sibling" would quietly have become "as wide as the
                    // title", taking "Esc to close" with it.
                    width: root.contentWidth
                    height: pageTitle.implicitHeight

                    // Title: 28 over a 36 line, semibold and NEVER bold, which
                    // is Windows 11's typography rule in as many words. No icon
                    // beside it -- a Settings page title is text, and the icon
                    // lives in the navigation entry that got you there.
                    //
                    // The RATIO and not Fluent.titleLine: sizes here are points
                    // because Theme.fontSize is shared with kitty, and a fixed
                    // line height is pixels. A unit-free multiplier cannot be
                    // got wrong.
                    Text {
                        id: pageTitle

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Keyboard shortcuts"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.titleSize
                        font.weight: Fluent.strongWeight
                        lineHeightMode: Text.ProportionalHeight
                        lineHeight: Fluent.titleLineRatio
                        color: Theme.textOnSurface

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Esc to close"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        font.weight: Fluent.normalWeight
                        color: Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                // ---------------- Nothing to list ----------------
                //
                // A sheet whose whole job is to explain the keys, opened on a
                // compositor that cannot be asked what is bound, must not come
                // up blank: an empty page reads as a broken shell rather than
                // as a missing feature. So it says which it is.
                Text {
                    visible: !Compositor.can("bindsIntrospection")
                    width: parent.width
                    topPadding: Fluent.sectionHeaderAbove

                    text: "This compositor cannot report what is bound to what.\n\n"
                        + "The bindings are still there -- they are in the compositor's own\n"
                        + "configuration file, which is where they were written."
                    wrapMode: Text.WordWrap

                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: Fluent.normalWeight
                    color: Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                // ---------------- The one column ----------------
                //
                // IN A ScrollList AND NOT LOOSE ON THE PAGE, because a column
                // of fifty-two binds is taller than any screen here and there
                // would be no way at all to reach the bottom of it. The
                // component clips, stops at its bounds, and takes the wheel
                // only while there is somewhere to go -- which is what is
                // wanted here too, since this is a modal and there is nothing
                // behind it that should be scrolling instead.
                //
                // ONLY THE SECTIONS SCROLL. The title and "Esc to close" stay
                // put: the one thing somebody who opened a sheet they cannot
                // read needs kept in sight is how to shut it.
                ScrollList {
                    id: list

                    visible: Compositor.can("bindsIntrospection")
                    width: root.contentWidth
                    contentHeight: sections.implicitHeight

                    // The bar for this one is up in the page's padding, which is
                    // empty anyway -- see the note beside it.
                    showScrollBar: false

                    // AS TALL AS THE SECTIONS WANT, UP TO WHAT IS LEFT: the
                    // screen, less the margin around the sheet, less the page's
                    // padding, less the title. Where the sections are shorter
                    // than that this is their own height, the page shrinks to
                    // them, and nothing scrolls.
                    height: Math.min(sections.implicitHeight,
                                     root.availableHeight - root.pagePadding * 2
                                         - header.height)

                    Column {
                        id: sections

                        width: root.contentWidth
                        spacing: 0

                        Repeater {
                            model: root.groups

                            Column {
                                id: group

                                required property var modelData

                                // A read of `parent`, which is given an explicit
                                // width above, rather than of an id from outside
                                // this delegate.
                                width: parent.width
                                spacing: 0

                                // ---- The section header ----
                                //
                                // Body Strong -- 14 semibold -- with the
                                // Toolkit's own 30 above and 6 below. No rule
                                // under it, no accent, no glyph: on a real
                                // Settings page a section header is
                                // TextFillColorPrimary text and the space around
                                // it, and anything more is a divider Windows
                                // does not draw. Both photographs show it.
                                Text {
                                    text: group.modelData.name
                                    topPadding: Fluent.sectionHeaderAbove
                                    bottomPadding: Fluent.sectionHeaderBelow

                                    font.family: Theme.fontFamily
                                    font.pointSize: Fluent.bodySize
                                    font.weight: Fluent.strongWeight
                                    color: Theme.textOnSurface

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.recolorDuration }
                                    }
                                }

                                // ---- The binds ----
                                Repeater {
                                    model: group.modelData.binds

                                    BindRow {
                                        required property var modelData

                                        width: group.width
                                        keys: modelData.keys
                                        label: modelData.text
                                        gutterWidth: root.keyGutter
                                        gap: root.rowGap
                                        chipPadding: root.chipPadding
                                        chipSpacing: root.chipSpacing

                                        // The face the gutter was measured in,
                                        // handed to the chip drawn in it.
                                        chipFont: chipMetrics.font
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // WHERE THE LIST COMES FROM. Nothing here runs a command: each compositor
    // backend produces the same shape -- keys already in chips, a category and
    // a description -- from whatever source it has, a socket on one flavour and
    // the config file on the other. This surface only groups them and draws.
    //
    // Categories are collected in ARRIVAL order, which is the order they are
    // written in the config, and only then sorted into categoryOrder. That is
    // what gives an unlisted category a stable place at the end rather than one
    // that moves about as binds are added.
    readonly property var groupedBinds: {
        const byName = {};
        const seen = [];

        for (const bind of Compositor.binds) {
            // Only what carries a description: a dedicated key prints its own
            // function on the keycap, and a row saying the volume key changes
            // the volume is one nobody would go looking for.
            if (!bind.described)
                continue;
            if (!byName[bind.category]) {
                byName[bind.category] = { name: bind.category, binds: [] };
                seen.push(bind.category);
            }
            byName[bind.category].binds.push({
                keys: bind.keys.map(k => root.keyName(k)),
                text: bind.description
            });
        }

        seen.sort((a, b) => {
            const ia = root.categoryOrder.indexOf(a);
            const ib = root.categoryOrder.indexOf(b);
            return (ia < 0 ? root.categoryOrder.length + seen.indexOf(a) : ia)
                 - (ib < 0 ? root.categoryOrder.length + seen.indexOf(b) : ib);
        });

        return seen.map(name => byName[name]);
    }
}
