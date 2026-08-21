// The cheatsheet: every keybind that carries a description, by category.
//
// WHERE THE LIST COMES FROM, AND WHY IT CANNOT GO STALE
// `hyprctl binds`, asked fresh on every open. Not a list written here, and not
// hyprland.lua parsed by hand: the compositor is the only thing that knows
// what is bound RIGHT NOW, including whatever a reload changed a minute ago.
// Adding a bind to hyprland.lua with a description is the whole of what it
// takes to make it appear here.
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
// LAYOUT
// Columns, filled shortest-first rather than in order, so they end at roughly
// the same height instead of leaving one long and two stubby. That packing is
// the part of this layout worth keeping and none of what follows changes it.
//
// HOW MANY COLUMNS IS THE SCREEN'S ANSWER AND NOT THIS FILE'S. It used to be
// three, and three of a fixed 540 plus the gaps and the padding is a card 1740
// pixels wide -- which is comfortable on the 2560-wide monitor it was written
// on and 660 pixels wider than the 1080-wide portrait one beside it. On that
// screen whole columns ran off both edges, and since nothing here scrolled
// there was no way to reach them. So the count comes from the width that is
// actually there, and on a screen with room for one column it is one.
//
// AND THE COLUMN IS AS WIDE AS ITS WIDEST ROW. 540 was a number too, and it
// was too NARROW: a chord gutter of 227 leaves about 300 pixels for the
// description, and "fake fullscreen (for games that minimise)" wants more, so
// it came out as "fake fullscreen (for games that ...". The width is measured
// off the descriptions now, the same way the gutter is measured off the
// chords.
//
// AND IT SCROLLS WHEN IT STILL DOES NOT FIT, which one column of fifty-two
// binds does not. The card is capped at the screen it opens on and the columns
// sit in a ScrollList inside it; the header and "Esc to close" stay put above
// them, because a heading that scrolls away on a reference sheet is a heading
// nobody can use.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/"
// ScrollList, which the columns sit in.
import "root:/components"

PanelWindow {
    id: root

    // The ShellScreen this sheet belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- How big the sheet is allowed to be ----------------
    //
    // EVERY NUMBER BELOW IS DERIVED FROM THE SCREEN except this one, which is
    // the breathing room a modal wants around itself so that it reads as a
    // sheet laid over the desktop rather than as a new desktop. It is the only
    // place a constant belongs in this section: it is a look, and the rest are
    // consequences.
    readonly property int screenMargin: 60

    readonly property int availableWidth: Math.max(0, (root.modelData?.width ?? 0) - root.screenMargin * 2)
    readonly property int availableHeight: Math.max(0, (root.modelData?.height ?? 0) - root.screenMargin * 2)

    // What is left for the columns once the card has had its padding.
    readonly property int contentRoom: Math.max(0, root.availableWidth - root.cardPadding * 2)

    // HOW WIDE A COLUMN WANTS TO BE: the chord gutter, the gap after it, and
    // the longest description in the sheet. Measured off the text for the same
    // reason keyGutter is -- a number written down here is a number that goes
    // stale the first time somebody writes a longer description, and the way
    // it goes stale is a row that quietly ends in an ellipsis.
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

    // ...capped by what there is. On a screen too narrow even for one full
    // column the descriptions elide, which is the old behaviour and the honest
    // one: there is no width at which they both fit and stay this size.
    readonly property int columnWidth: Math.min(root.naturalColumnWidth, root.contentRoom)

    // Three is a ceiling and not a count. It is what the sheet was designed
    // around and what the widest monitor here has room for; a fourth column
    // would be a different sheet rather than the same one on a bigger screen.
    readonly property int columnCountMax: 3

    // As many as fit side by side, and never fewer than one -- a sheet with
    // zero columns is a blank card, and a screen too narrow for a column still
    // gets the column, elided, which is more use than nothing.
    readonly property int columnCount: {
        if (root.columnWidth <= 0)
            return 1;

        const fit = Math.floor((root.contentRoom + root.columnGap)
                             / (root.columnWidth + root.columnGap));
        return Math.max(1, Math.min(root.columnCountMax, fit));
    }

    // The columns and the gaps between them, which is what the header spans
    // and what the card is built around.
    readonly property int contentWidth: root.columnCount * root.columnWidth
        + (root.columnCount - 1) * root.columnGap

    readonly property int columnGap: 30

    // The space between a chord and its description, in BindRow. Here because
    // naturalColumnWidth above adds it up; see chipPadding for the same
    // argument at one level down.
    readonly property int rowGap: 12

    // The description's font, for measuring the longest one. The chips have
    // their own -- see chipMetrics -- because they are drawn a size smaller.
    FontMetrics {
        id: bodyMetrics

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Theme.fontWeight
    }

    // The keys sit in a fixed-width gutter and are flush with its right edge,
    // so the actual key is always the chip nearest its own description and
    // every description in a column starts at the same x.
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
    // has ever seen, so it is right until something gets SMALLER and then it
    // is stuck. Measured, on this machine's fifty-two described binds: the
    // sheet opens with a gutter of 226, the type size is taken to 16pt and it
    // becomes 298, the type size is put back to 11pt -- and the widest chord
    // is 226 again while the gutter stays at 298, which is seventy-two pixels
    // of nothing in front of every description in all three columns, for the
    // rest of the session.
    //
    // So the gutter is added up from the chords instead of collected from the
    // rows: the label's advance width plus the chip padding for each chip,
    // plus the spacing between them, over every chord the sheet is showing.
    // It is an ordinary binding, so it goes down as readily as up, and it is
    // still correct for whatever the compositor turns out to bind -- including
    // a fifth modifier nobody has thought of yet. The same shape as the
    // keybinds settings page, which had the opposite half of this bug: a
    // gutter that was a constant and could not move at all.
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

    // The chip's own geometry, HERE AND NOT AS LITERALS IN BindRow, because
    // the gutter above is an arithmetic model of a chip: a model that does not
    // add up the numbers the chip is drawn with is a model that drifts, and it
    // drifts silently -- the chords would simply start hanging off the edge
    // again. Handed to BindRow, which is where they are used.
    readonly property int chipPadding: 14
    readonly property int chipSpacing: 5

    // The chip label's font, so advanceWidth() measures the text with the face
    // it will actually be drawn in. Kept in step with the Text inside BindRow
    // by hand -- FontMetrics takes a font, not a component.
    FontMetrics {
        id: chipMetrics

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1.5
        font.weight: Theme.fontWeight
    }
    readonly property int cardPadding: 30

    // Shape: [ { name: "Apps", binds: [ { keys: [...], text: "..." } ] } ]
    // Derived from Compositor.binds, at the bottom of this file.
    readonly property var groups: root.groupedBinds

    // The order categories are shown in: roughly how often you reach for them,
    // with the shell's own controls last. A category not named here still
    // appears -- at the end, in the order hyprctl reported it -- so a new one
    // is never silently dropped.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // ---------------- Turning a bind into something readable ----------------

    // Hyprland's key names are xkb keysyms and mouse codes. Left alone they
    // read like config, not like the key under your finger.
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

    // Shortest-first packing. Categories keep their order within a column, and
    // each goes to whichever column is currently shortest -- measured in rows
    // plus two for the heading, so a heading is not free.
    //
    // It takes the count from root.columnCount, which is now the screen's
    // answer rather than a three written down. Nothing else about it changes:
    // one column is the same algorithm with one bucket, and the categories
    // come out in order because every one of them is the shortest column.
    function pack(groups: var): var {
        const columns = [];
        const heights = [];

        for (let i = 0; i < root.columnCount; i++) {
            columns.push([]);
            heights.push(0);
        }

        for (const group of groups) {
            let shortest = 0;
            for (let i = 1; i < heights.length; i++)
                if (heights[i] < heights[shortest])
                    shortest = i;

            columns[shortest].push(group);
            heights[shortest] += group.binds.length + 2;
        }

        return columns;
    }

    readonly property var columns: root.pack(root.groups)

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
    // all four edges stretches the layer surface instead, and then the size
    // the compositor picked is not one QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's reservation:
    // the sheet covers the bar rather than starting below it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.
    //
    // ext-background-effect: the client names the region behind it that should
    // be blurred, and both compositors here implement it -- niri since 26.04,
    // Hyprland since 0.56.0. The whole sheet, because on a full-screen sheet
    // the rectangle IS what gets painted; frosting everything behind a modal is
    // the point of it.
    //
    // Said out loud anyway rather than left to a compositor to infer, because
    // that is the whole change: a surface with nothing to declare still has to
    // declare it. The region starts empty, and a sheet that never asked would
    // be a dark tint over perfectly sharp windows.
    //
    // `sheet` and not the window, for the reason its own note gives: the
    // window's contentItem measures 0x0 whatever the layer surface is, and the
    // Rectangle is the only thing here that knows the screen's size. Checked on
    // screen -- a region taken from an item inside a 0x0 contentItem still
    // comes out the item's size.
    BackgroundEffect.blurRegion: Region {
        item: sheet
    }

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

        // The shell's standard glass, and that is not decoration: the
        // blur-quickshell rule in hyprland.lua sets ignore_alpha just under
        // Theme.glassAlpha, so an alpha picked by hand here would fall out of
        // the blur entirely and the sheet would go from frosted wallpaper to a
        // flat tint over perfectly sharp windows.
        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        focus: true

        Keys.onEscapePressed: CheatsheetState.close()
        // The key that opened it also closes it, without the modifier: while
        // the sheet holds the keyboard, the SUPER + / bind still fires from
        // the compositor, but a bare / is the reflex once you are looking at
        // it.
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

            // BUILT AROUND THE CONTENT WIDTH RATHER THAN AROUND THE COLUMN'S
            // OWN IDEA OF IT. `layout.implicitWidth` was the widest child, and
            // the widest child was a Row of three fixed columns -- so the card
            // was as wide as the columns happened to be and the screen never
            // came into it. root.contentWidth is the columns AFTER the screen
            // has had its say, so this can no longer come out wider than what
            // it is drawn on.
            implicitWidth: root.contentWidth + root.cardPadding * 2

            // The height is still the content's, and it is bounded because the
            // list inside it is: see `list.height`. Capped here as well, so
            // that a header taller than the whole screen -- which is not a
            // real case, but is the sort of thing that makes a modal
            // unclosable -- still cannot push the card off its own screen.
            implicitHeight: Math.min(layout.implicitHeight + root.cardPadding * 2,
                                     root.availableHeight)
            radius: Theme.cardRadius

            color: Theme.glass(Theme.surfaceContainer)

            // Opening move: a short rise into place. Small on purpose -- this
            // is a reference you want to be able to read, not an entrance.
            opacity: CheatsheetState.isOpen ? 1 : 0
            scale: CheatsheetState.isOpen ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
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
            // IT ANSWERS "IS THERE MORE", which the sheet cannot answer on its
            // own: a row cut off by the bottom of the card looks exactly like a
            // row that happens to end there, and on the portrait screen there
            // are around six hundred pixels of binds below the fold. It also
            // says how far down you are, which a list of similar-looking rows
            // otherwise does not.
            //
            // IT IS NOT THERE WHEN EVERYTHING FITS, which is every landscape
            // screen here -- a bar that is always full height is a control that
            // says nothing and takes room saying it.
            //
            // IN THE CARD'S OWN PADDING, so it costs no width: the card keeps
            // thirty pixels of padding on each side and four pixels of bar
            // centred in the right-hand thirty overlaps nothing.
            //
            // Hand-drawn, and it is the second one of these in the shell --
            // modules/notifications/NotificationHistory.qml has the other, and
            // its comments carry the reasoning for the thumb's floor and for
            // the travel mapping below. A THIRD caller is what should lift this
            // into components/; two is where that starts being worth doing and
            // this is not the commit to do it in.
            Rectangle {
                id: scrollTrack

                anchors.right: parent.right
                anchors.rightMargin: (root.cardPadding - width) / 2

                // POSITIONED AND NOT ANCHORED TO THE LIST, because the list is
                // a grandchild of this card and anchors only reach a parent or
                // a sibling -- QML says so at runtime, as a warning, and leaves
                // the bar at the top of the card. `layout` IS a child here, so
                // the list's own y inside it is the offset that is missing.
                y: layout.y + list.y
                height: list.height

                width: 4
                radius: width / 2

                visible: list.visible && list.scrollable

                color: Qt.alpha(Theme.outlineVariant, 0.5)

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                Rectangle {
                    id: thumb

                    // As tall a share of the track as the visible part is of
                    // the whole, with a floor -- proportional alone leaves a
                    // few pixels to hunt for on a long list.
                    height: Math.max(30, scrollTrack.height * list.visibleArea.heightRatio)

                    // The floor is also why this is not simply
                    // `yPosition * track.height`: once the thumb is taller than
                    // its share it has less room to travel than the content
                    // does, so the position is mapped onto the travel that is
                    // actually left. Without it the bar reaches the bottom
                    // before the sheet does.
                    y: {
                        const travel = scrollTrack.height - thumb.height;
                        const range = 1 - list.visibleArea.heightRatio;
                        if (travel <= 0 || range <= 0)
                            return 0;
                        return Math.max(0, Math.min(1, list.visibleArea.yPosition / range)) * travel;
                    }

                    width: parent.width
                    radius: parent.radius

                    // Brighter while it is being used and quiet the rest of the
                    // time: at rest this is a hint about the shape of the list,
                    // in the hand it is a control. Both `moving` and the
                    // velocity are asked because a wheel notch is neither a
                    // drag nor a flick and does not set `moving`.
                    color: list.moving || list.verticalVelocity !== 0
                            || scrollMouse.pressed || scrollMouse.containsMouse
                        ? Theme.primary
                        : Theme.outline

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                // Four pixels is the right width to look at and an unfair thing
                // to ask anyone to hit, so the pointer gets eighteen. Wider
                // only, never taller: growing it vertically would move this
                // item's origin off the track that `mouse.y` is measured from.
                MouseArea {
                    id: scrollMouse

                    anchors.fill: parent
                    anchors.leftMargin: -7
                    anchors.rightMargin: -7

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // Press jumps and drag follows, one gesture and no dead
                    // zone. The pointer is the MIDDLE of the thumb, so what you
                    // pressed on ends up under your finger.
                    function scrollTo(y: real): void {
                        const travel = scrollTrack.height - thumb.height;
                        if (travel <= 0)
                            return;
                        const progress = Math.max(0, Math.min(1, (y - thumb.height / 2) / travel));
                        list.contentY = progress * (list.contentHeight - list.height);
                    }

                    onPressed: mouse => scrollMouse.scrollTo(mouse.y)
                    onPositionChanged: mouse => {
                        if (pressed)
                            scrollMouse.scrollTo(mouse.y);
                    }
                }
            }

            Column {
                id: layout

                anchors.centerIn: parent
                width: root.contentWidth
                spacing: 22

                // ---------------- Header ----------------
                Item {
                    id: header

                    // The content width and not the Column's implicit one: the
                    // columns live in a Flickable now, and a Flickable's
                    // implicit width is not its content's -- so "as wide as my
                    // widest sibling" would have quietly become "as wide as the
                    // title", taking "Esc to close" with it.
                    width: root.contentWidth
                    height: title.implicitHeight

                    Row {
                        id: title

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.keyboard
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize + 4
                            color: Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Keybindings"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize + 4
                            font.weight: Font.Bold
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Esc to close"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Theme.fontWeight
                        color: Theme.outline

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                // ---------------- Nothing to list ----------------
                //
                // A sheet whose whole job is to explain the keys, opened on a
                // compositor that cannot be asked what is bound, must not come
                // up blank: an empty panel reads as a broken shell rather than
                // as a missing feature. It says which it is.
                Text {
                    visible: !Compositor.can("bindsIntrospection")
                    width: parent.width

                    text: "This compositor cannot report what is bound to what.\n\n"
                        + "The bindings are still there -- they are in the compositor's own\n"
                        + "configuration file, which is where they were written."
                    horizontalAlignment: Text.AlignHCenter

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                    color: Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                // ---------------- The columns ----------------
                //
                // IN A ScrollList AND NOT LOOSE IN THE CARD, because one
                // column of fifty-two binds is taller than a 1920-pixel screen
                // and there was no way at all to reach the bottom of it. The
                // component is components/ScrollList.qml as it stands: it
                // clips, it stops at its bounds, and it takes the wheel only
                // while there is somewhere to go -- which is the behaviour
                // wanted here too, since the sheet is a modal and there is
                // nothing behind it that should be scrolling instead.
                //
                // ONLY THE COLUMNS SCROLL. The header and "Esc to close" are
                // above this and stay where they are: the one thing somebody
                // opening a sheet they cannot read needs to keep in sight is
                // how to shut it.
                ScrollList {
                    id: list

                    visible: Compositor.can("bindsIntrospection")
                    width: root.contentWidth
                    contentHeight: columnsRow.implicitHeight

                    // AS TALL AS THE COLUMNS WANT, UP TO WHAT IS LEFT. What is
                    // left is the screen, less the margin around the sheet,
                    // less the card's own padding, less the header and the
                    // space under it. Where the columns are shorter than that
                    // -- which is every landscape screen here -- this is their
                    // own height, the card shrinks to them as it always did,
                    // and nothing scrolls.
                    height: Math.min(columnsRow.implicitHeight,
                                     root.availableHeight - root.cardPadding * 2
                                         - header.height - layout.spacing)

                    Row {
                        id: columnsRow

                        spacing: root.columnGap

                        Repeater {
                            model: root.columns

                            Column {
                                id: column

                                required property var modelData

                                width: root.columnWidth
                                spacing: 18

                                Repeater {
                                    model: column.modelData

                                    Column {
                                        id: group

                                        required property var modelData

                                        width: column.width
                                        spacing: 6

                                        // ---- Category heading ----
                                        Row {
                                            spacing: 8

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Icons.category(group.modelData.name)
                                                font.family: Theme.fontFamily
                                                font.pointSize: Theme.iconSize - 1
                                                color: Theme.primary

                                                Behavior on color {
                                                    ColorAnimation { duration: Theme.recolorDuration }
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: group.modelData.name
                                                font.family: Theme.fontFamily
                                                font.pointSize: Theme.fontSize
                                                font.weight: Font.Bold
                                                // Letterspaced and in the accent:
                                                // the headings are signposts, and
                                                // at this size weight alone does
                                                // not separate them enough from
                                                // the rows under them.
                                                font.letterSpacing: 0.8
                                                color: Theme.primary

                                                Behavior on color {
                                                    ColorAnimation { duration: Theme.recolorDuration }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: column.width
                                            height: 1
                                            color: Theme.outlineVariant

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.recolorDuration }
                                            }
                                        }

                                        // ---- The binds ----
                                        Repeater {
                                            model: group.modelData.binds

                                            BindRow {
                                                required property var modelData

                                                width: column.width
                                                keys: modelData.keys
                                                label: modelData.text
                                                gutterWidth: root.keyGutter
                                                gap: root.rowGap
                                                chipPadding: root.chipPadding
                                                chipSpacing: root.chipSpacing
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // WHERE THE LIST COMES FROM. Nothing here runs a command any more: each
    // compositor backend produces the same shape -- keys already in chips, a
    // category and a description -- from whatever source it has, which is a
    // socket on one flavor and the config file on the other. This module only
    // groups them and draws.
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
