// The cheatsheet: every keybind that carries a description, drawn as a Settings
// page.
//
// WINDOWS HAS NO KEYBOARD-SHORTCUT OVERLAY AT ALL, so there is nothing to
// recreate and the question is which Windows shape this content belongs in. It
// is a long list of labelled rows grouped under headings, which is a Settings
// page and nothing else: a page title in Title type, section headers in Body
// Strong with the Community Toolkit's own spacing around them, and the rows
// underneath. The card the page sits in is a window -- Mica ground, overlay
// radius, one-pixel stroke -- rather than a dialog.
//
// WHAT WENT WITH GENESIS'S SHAPE, and it is worth naming because it was good.
// genesis packs the categories into up to three columns shortest-first so they
// end at roughly the same height, and sizes both the columns and the sheet off
// the screen. Windows Settings pages are ONE column with a published maximum
// width and everything below the fold reached by scrolling, so the packing had
// nothing left to pack and it is gone. What survives is the arithmetic that is
// about the CONTENT rather than the layout: the key gutter added up from the
// chords, and the column width measured off the longest description.
//
// WHERE THE LIST COMES FROM, AND WHY IT CANNOT GO STALE
// The compositor, asked fresh on every open. Not a list written here, and not
// hyprland.lua parsed by hand: the compositor is the only thing that knows what
// is bound RIGHT NOW, including whatever a reload changed a minute ago. Adding
// a bind with a description is the whole of what it takes to make it appear
// here.
//
// The one thing the compositor cannot tell us is what a bind DOES. The config
// is in Lua, so `hyprctl binds` reports every dispatcher as "__lua" with an
// opaque callback index for an argument -- useless as a label. The description
// is where the meaning lives, in the "Category: what it does" form, and the
// category before the colon is what groups the rows below.
//
// A BIND WITH NO DESCRIPTION IS INVISIBLE HERE, deliberately. That is the
// filter that keeps the sheet from listing ten identical rows for SUPER + 1
// through SUPER + 0, and it is why the loops in hyprland.lua describe only
// their first iteration.
//
// ON LINE HEIGHTS, AND WHY Fluent'S ARE NOT USED HERE. Fluent.qml expresses
// Windows' type ramp as offsets from the user's own size, which this shell
// carries in POINTS -- `font.pointSize: Theme.fontSize` is how every text in
// the tree is written. Its line heights are in that same unit, and
// Text.lineHeight with lineHeightMode FixedHeight is in PIXELS, so the two are
// not interchangeable and there is no conversion here that would not be a DPI
// assumption invented at this line. Every text on this surface is a single
// line, where the face's own leading is the right answer anyway; the one
// paragraph that wraps is the empty state, and it wants ordinary body leading.
// The sizes and the weights are Fluent's, which is where the Windows look
// actually lives.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
// ScrollList, which the sections sit in, and the ScrollBar and BindRow facades.
import qs.components
import qs.modules.cheatsheet
// Fluent lives one directory up, and without this line the failure is at
// runtime, per read: "ReferenceError: Fluent is not defined".
import ".."

PanelWindow {
    id: root

    // The ShellScreen this sheet belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- How big the page is allowed to be ----------------
    //
    // OURS: Microsoft publishes no margin between a window and the screen, and
    // this window is not one the user can drag. 60 is the breathing room a
    // sheet wants around itself so that it reads as a window laid over the
    // desktop rather than as a new desktop, and it is the only constant in this
    // section -- the rest are consequences of it and of the screen.
    readonly property int screenMargin: 60

    readonly property int availableWidth: Math.max(0, (root.modelData?.width ?? 0) - root.screenMargin * 2)
    readonly property int availableHeight: Math.max(0, (root.modelData?.height ?? 0) - root.screenMargin * 2)

    // OURS, and only in the sense that Microsoft publishes no page inset for a
    // Settings page. 16 is SettingsCardPadding, which is the closest published
    // figure and is what every card on such a page already keeps inside itself,
    // so the page frame and the cards on it agree.
    readonly property int cardPadding: Fluent.cardPadding

    // What is left for the content once the card has had its padding.
    readonly property int contentRoom: Math.max(0, root.availableWidth - root.cardPadding * 2)

    // A SETTINGS PAGE IS CAPPED, AND THE NUMBER IS PUBLISHED. The Community
    // Toolkit's SettingsPageExample.xaml -- the sample the official docs point
    // at -- wraps the whole page in `MaxWidth="1000"`, which is why a Settings
    // window maximised on a 2560-wide monitor still lays its cards out down the
    // left. Without it a wide screen would give one column of fifty-two binds a
    // line length nobody can track back from.
    readonly property int contentMaxWidth: 1000

    // HOW WIDE THE COLUMN WANTS TO BE: the chord gutter, the gap after it, and
    // the longest description in the sheet. Measured off the text for the same
    // reason keyGutter is -- a number written down here is a number that goes
    // stale the first time somebody writes a longer description, and the way it
    // goes stale is a row that quietly ends in an ellipsis.
    readonly property int naturalColumnWidth: {
        // See keyGutter: advanceWidth() is a function call, so the font has to
        // be READ here or this never recomputes when the type size moves.
        if (bodyMetrics.font.family === "" || bodyMetrics.font.pointSize <= 0)
            return root.keyGutter + root.rowGap;

        let widest = 0;
        for (const group of root.groups)
            for (const bind of group.binds)
                widest = Math.max(widest, bodyMetrics.advanceWidth(bind.text));

        return root.keyGutter + root.rowGap + Math.ceil(widest);
    }

    // ...capped by the page's maximum and by what there is. On a screen too
    // narrow even for one full column the descriptions elide, which is the
    // honest outcome: there is no width at which they both fit and stay this
    // size.
    readonly property int contentWidth: Math.min(root.naturalColumnWidth,
                                                 root.contentMaxWidth,
                                                 root.contentRoom)

    // The space between a chord and its description, in BindRow. Here because
    // naturalColumnWidth above adds it up; see chipPadding for the same
    // argument at one level down.
    readonly property int rowGap: 12

    // The description's font, for measuring the longest one. The chips have
    // their own -- see chipMetrics -- because they are drawn a size smaller.
    FontMetrics {
        id: bodyMetrics

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
    }

    // The keys sit in a fixed-width gutter and are flush with its right edge,
    // so the actual key is always the chip nearest its own description and
    // every description starts at the same x.
    //
    // MEASURED, NOT GUESSED, and that changed the day this had to serve two
    // compositors. It was 150, taken off the widest chord Hyprland bound --
    // SUPER + SHIFT + Esc, three chips. niri needs four for the monitor binds
    // (SUPER CTRL SHIFT Left), and a fixed number sized for the old worst case
    // pushed those chips out of the card entirely, off the left edge.
    //
    // The first answer to that was to ask the ROWS how wide they had come out
    // and keep the largest. It fixed the overflow and it left a defect of its
    // own: a running maximum can only ever grow. It holds the widest thing it
    // has ever seen, so it is right until something gets SMALLER and then it is
    // stuck. Measured, on this machine's fifty-two described binds: the sheet
    // opens with a gutter of 226, the type size is taken to 16pt and it becomes
    // 298, the type size is put back to 11pt -- and the widest chord is 226
    // again while the gutter stays at 298, which is seventy-two pixels of
    // nothing in front of every description, for the rest of the session.
    //
    // So the gutter is added up from the chords instead of collected from the
    // rows: the label's advance width plus the chip padding for each chip, plus
    // the spacing between them, over every chord the sheet is showing. It is an
    // ordinary binding, so it goes down as readily as up, and it is still
    // correct for whatever the compositor turns out to bind -- including a
    // fifth modifier nobody has thought of yet.
    readonly property int keyGutter: {
        // THE FONT IS NAMED HERE and not only inside chipMetrics below. A
        // binding re-runs when a property it READ changes, not when a property
        // some function it CALLED read changes, and advanceWidth() is a
        // function call -- without this the sheet would be measured once, at
        // whatever size it first opened at. chipMetrics' own font rather than
        // Theme's, though they hold the same value, so it is read after the
        // metrics have caught up rather than racing them.
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

        // Rounded up ONCE, at the end. A chip is as wide as its label plus the
        // padding and a label is a fractional number of pixels; rounding each
        // one first adds up to a gutter a little wider than the row it is
        // measuring, and a model that is allowed to disagree with the thing it
        // models cannot be used to catch the two drifting apart.
        return Math.max(root.keyGutterFloor, Math.ceil(widest));
    }

    // A FLOOR AND NOT A DEFAULT. It keeps a short list looking the way it
    // always did rather than letting a sheet of two-chip chords close up, and
    // it is what the gutter reads as before the compositor has answered.
    readonly property int keyGutterFloor: 150

    // The chip's own geometry, HERE AND NOT AS LITERALS IN BindRow, because the
    // gutter above is an arithmetic model of a chip: a model that does not add
    // up the numbers the chip is drawn with is a model that drifts, and it
    // drifts silently -- the chords would simply start hanging off the edge
    // again. Handed to BindRow, which is where they are used.
    //
    // Fluent.controlPaddingH is MenuFlyoutItemThemePadding's and Button's own
    // 11, which is the nearest published horizontal inset Windows gives a small
    // labelled control; doubled, it is the padding a chip keeps around its key
    // name. The spacing between two chips in a chord is OURS -- Windows draws
    // no key chips anywhere.
    readonly property int chipPadding: Fluent.controlPaddingH * 2
    readonly property int chipSpacing: 4

    // The chip label's font, so advanceWidth() measures the text with the face
    // it will actually be drawn in. It travels -- this value, whole, through
    // BindRow's `chipFont` to the chip's `labelFont` -- so the face that is
    // measured and the face that is drawn are one value rather than two
    // spellings that agree today. Caption is the Windows ramp's smallest step
    // and the one a key cap belongs on.
    FontMetrics {
        id: chipMetrics

        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        font.weight: Fluent.strongWeight
    }

    // ---------------- The page's own spacing ----------------
    //
    // SettingsSectionHeaderTextBlockStyle, verbatim from the Community
    // Toolkit's SettingsPageExample.xaml: BodyStrong with Margin="1,30,0,6".
    // The 30 above and the 6 below are the whole of the rhythm of a Settings
    // page -- it is what separates one group of cards from the next without a
    // rule, a tint or a box.
    readonly property int sectionHeaderAbove: 30
    readonly property int sectionHeaderBelow: 6

    // Shape: [ { name: "Apps", binds: [ { keys: [...], text: "..." } ] } ]
    // Derived from Compositor.binds, at the bottom of this file.
    readonly property var groups: root.groupedBinds

    // The order categories are shown in: roughly how often you reach for them,
    // with the shell's own controls last. A category not named here still
    // appears -- at the end, in the order the compositor reported it -- so a new
    // one is never silently dropped.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // ---------------- Turning a bind into something readable ----------------

    // Hyprland's key names are xkb keysyms and mouse codes. Left alone they read
    // like config, not like the key under your finger.
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
        // keysym, and this way a key we forgot still looks deliberate.
        return root.keyNames[key] ?? (key.startsWith("XF86") ? key.slice(4) : key);
    }

    screen: modelData
    visible: CheatsheetState.isOpen

    WlrLayershell.namespace: "quickshell-cheatsheet"
    // Overlay, like the power menu: this has to be readable over a fullscreen
    // window, which is exactly when you have forgotten the bind to get out of
    // one.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive so Escape reaches us at all. Static rather than flipped with
    // `isOpen`, the same as PowerMenu: `visible` tears the surface down, so
    // nothing holds the keyboard while the sheet is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring
    // all four edges stretches the layer surface instead, and then the size the
    // compositor picked is not one QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's reservation:
    // the sheet covers the taskbar rather than starting above it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    Connections {
        target: CheatsheetState

        function onIsOpenChanged(): void {
            if (!CheatsheetState.isOpen)
                return;

            // Re-read on every open. A config reload between two openings is
            // exactly the case a cached list would get wrong.
            //
            // Only where the compositor can be asked at all -- otherwise the
            // sheet says so instead, below, and running the query would just
            // spawn a process to fail.
            if (Compositor.can("bindsIntrospection"))
                Compositor.refreshBinds();
            sheet.forceActiveFocus();
        }
    }

    Rectangle {
        id: sheet

        // Sized from the SCREEN, not from `parent`: the window's contentItem
        // stays 0x0 whatever the layer surface measures, so `anchors.fill`
        // would collapse to nothing. Same as PowerMenu.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // SmokeFillColorDefault -- see PowerMenu.qml for the source and for why
        // this is the one hex literal in the theme. It is here for the same
        // reason it is there: while this surface is up the desktop behind it is
        // not taking input, and dimming is the only thing Windows does to say
        // so. A page drawn as though it were an ordinary window would be
        // lying about that.
        //
        // 0x4D is 0.30, under the compositor's 0.84 ignore_alpha, so this fill
        // is left out of the blur and what shows through is a dimmed but sharp
        // desktop -- which is the point of it.
        color: "#4D000000"

        focus: true

        Keys.onEscapePressed: CheatsheetState.close()
        // The key that opened it also closes it, without the modifier: while
        // the sheet holds the keyboard, the SUPER + / bind still fires from the
        // compositor, but a bare / is the reflex once you are looking at it.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question)
                CheatsheetState.close();
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. Below the card in the file, so the card
        // takes its own clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: CheatsheetState.close()
        }

        Rectangle {
            id: card

            anchors.centerIn: parent

            implicitWidth: root.contentWidth + root.cardPadding * 2

            // The height is the content's, and it is bounded because the list
            // inside it is: see `list.height`. Capped here as well, so that a
            // header taller than the whole screen -- which is not a real case,
            // but is the sort of thing that makes a modal unclosable -- still
            // cannot push the card off its own screen.
            implicitHeight: Math.min(layout.implicitHeight + root.cardPadding * 2,
                                     root.availableHeight)

            // A WINDOW AND NOT A DIALOG: OverlayCornerRadius, which is the 8
            // Windows gives windows, flyouts and dialogs alike.
            radius: Fluent.overlayRadius

            // MICA, WHICH IS THE ONE WINDOWS MATERIAL THIS SHELL GETS FOR FREE.
            // Mica samples the wallpaper once and is static, and the
            // blur-quickshell rule in hyprland.lua is xray -- it samples the
            // wallpaper and not the windows in front of it. The two are a close
            // match by accident. Its documented fallback is
            // SolidBackgroundFillColorBase #202020, which is exactly
            // windows-11-dark's ui_surface, so Theme.surface is the tint.
            //
            // Theme.glass() and not an alpha chosen here: the rule ignores
            // anything under 0.84 and Theme.glassAlpha is the number just above
            // it, so a hand-picked value falls out of the blur entirely and the
            // card goes from Mica to a flat tint over a sharp desktop.
            color: Theme.glass(Theme.surface)

            // A one-pixel stroke, which every Windows surface with a corner
            // radius carries. No scheme role holds a black overlay, so this
            // reads the divider role -- the one role that is a hairline over a
            // surface rather than a fill.
            border.width: 1
            border.color: Theme.outlineVariant
            antialiasing: true

            // Dialog show, from the motion table: scale 1.05 -> 1.0 over 250ms
            // on the one spline WinUI ships, opacity linear over 83. The scale
            // comes DOWN rather than up -- a Windows surface arrives by
            // settling, not by growing.
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
            // behind the card.
            MouseArea {
                anchors.fill: parent
            }

            // ---------------- Scroll indicator ----------------
            //
            // IT ANSWERS "IS THERE MORE", which the page cannot answer on its
            // own: a row cut off by the bottom of the card looks exactly like a
            // row that happens to end there, and one column of fifty-two binds
            // does not fit on any screen here. It also says how far down you
            // are, which a list of similar-looking rows otherwise does not.
            //
            // components/ScrollBar.qml draws it, and this file only places it.
            // IN THE CARD'S OWN PADDING, so it costs no width: Windows' bar is
            // a 12px gutter and the card keeps 16 on each side, so four pixels
            // of margin either side of it overlap nothing. Which is also why
            // the list is told not to draw its own -- ScrollList's sits just
            // inside the right edge of the list, where the descriptions are.
            //
            // POSITIONED AND NOT ANCHORED TO THE LIST, because the list is a
            // grandchild of this card and anchors only reach a parent or a
            // sibling -- QML says so at runtime, as a warning, and leaves the
            // bar at the top of the card. `layout` IS a child here, so the
            // list's own y inside it is the offset that is missing.
            ScrollBar {
                view: list

                anchors.right: parent.right
                anchors.rightMargin: (root.cardPadding - width) / 2

                y: layout.y + list.y
                height: list.height
            }

            Column {
                id: layout

                anchors.centerIn: parent
                width: root.contentWidth

                // ZERO, and that is the section header style doing its job: its
                // own 30 above is what separates the first section from the
                // title, and every later one from the rows before it. A spacing
                // here as well would be that gap counted twice.
                spacing: 0

                // ---------------- The page title ----------------
                Item {
                    id: header

                    // The content width and not the Column's implicit one: the
                    // sections live in a Flickable, and a Flickable's implicit
                    // width is not its content's -- so "as wide as my widest
                    // sibling" would quietly have become "as wide as the title",
                    // taking "Esc to close" with it.
                    width: root.contentWidth
                    height: pageTitle.implicitHeight

                    // Title, 28 semibold. No icon beside it: a Settings page
                    // title is text, and the icon lives in the navigation entry
                    // that got you there.
                    Text {
                        id: pageTitle

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Keyboard shortcuts"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.titleSize
                        font.weight: Fluent.strongWeight
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
                // up blank: an empty page reads as a broken shell rather than as
                // a missing feature. It says which it is.
                Text {
                    visible: !Compositor.can("bindsIntrospection")
                    width: parent.width
                    topPadding: root.sectionHeaderAbove

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

                // ---------------- The sections ----------------
                //
                // IN A ScrollList AND NOT LOOSE IN THE CARD, because one column
                // of fifty-two binds is taller than any screen here and there
                // would be no way at all to reach the bottom of it. The
                // component is components/ScrollList.qml as it stands: it clips,
                // it stops at its bounds, and it takes the wheel only while
                // there is somewhere to go -- which is the behaviour wanted
                // here too, since the sheet is a modal and there is nothing
                // behind it that should be scrolling instead.
                //
                // ONLY THE SECTIONS SCROLL. The title and "Esc to close" are
                // above this and stay where they are: the one thing somebody
                // opening a sheet they cannot read needs to keep in sight is how
                // to shut it.
                ScrollList {
                    id: list

                    visible: Compositor.can("bindsIntrospection")
                    width: root.contentWidth
                    contentHeight: sections.implicitHeight

                    // The bar for this one is up in the card, in padding that is
                    // empty anyway -- see the note beside it for why here is the
                    // wrong place for it.
                    showScrollBar: false

                    // AS TALL AS THE SECTIONS WANT, UP TO WHAT IS LEFT. What is
                    // left is the screen, less the margin around the sheet, less
                    // the card's own padding, less the title. Where the sections
                    // are shorter than that this is their own height, the card
                    // shrinks to them, and nothing scrolls.
                    height: Math.min(sections.implicitHeight,
                                     root.availableHeight - root.cardPadding * 2
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

                                // From the Column above, which is given an
                                // explicit width -- a read of `parent` rather
                                // than of an id outside this delegate.
                                width: parent.width
                                spacing: 0

                                // ---- Section header ----
                                //
                                // Body Strong with the Toolkit's own 30 above
                                // and 6 below. No rule under it, no accent and
                                // no glyph: a Settings section header is
                                // TextFillColorPrimary text and the space around
                                // it, and anything more is a divider Windows
                                // does not draw.
                                Text {
                                    text: group.modelData.name
                                    topPadding: root.sectionHeaderAbove
                                    bottomPadding: root.sectionHeaderBelow

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

                                        // The face the gutter above was measured
                                        // in, handed to the chip that is drawn
                                        // in it. See chipMetrics.
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
    // backend produces the same shape -- keys already in chips, a category and a
    // description -- from whatever source it has, which is a socket on one
    // flavour and the config file on the other. This surface only groups them
    // and draws.
    //
    // Categories are collected in ARRIVAL order, which is the order they are
    // written in the config, and only then sorted into categoryOrder. That is
    // what gives an unlisted category a stable place at the end instead of one
    // that moves around as binds are added.
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
