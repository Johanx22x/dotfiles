// Mouse and keyboard: how far the pointer moves for a given push, and how
// fast a held key repeats.
//
// ALL OF IT IS THE COMPOSITOR'S. Whichever one is running owns libinput; the
// shell never sees a pointer event that is not already scaled by these
// numbers, and cannot apply any of them itself. Everything on this page goes
// out through `desktop-tweak` -- one state file, and one generated override
// file per flavor: tweaks.lua plus `hyprctl eval` on Hyprland, tweaks.kdl on
// niri, where writing the file IS applying it. See that script's header.
//
// SO THE PAGE ITSELF NEVER LEARNS WHICH COMPOSITOR IT IS ON. Every row means
// the same thing on both -- the pointer speed is libinput's -1.0..1.0 either
// way -- and the one asymmetry, which of them remembers the ACTIVE keyboard
// layout, is handled inside the script and inside Config.keyboardLayoutIndex.
// What the page asks is `Compositor.can("inputConfig")`, once, below.
//
// THE KEYBOARD LAYOUT IS HERE NOW, and this comment used to say the opposite:
// that the layout belongs to one machine and one person, and that a settings
// window writing it into a "shared generated file" would hand this machine's
// layout to the other one on the next pull. The second half of that was
// simply wrong. tweaks.lua is not shared -- it is generated, gitignored and
// machine-local, exactly like the monitors.lua sitting next to it -- so the
// argument that kept the layout out applied to a file that does not exist.
// What was true is that hyprland.lua must not carry it, and it still does not:
// what is tracked there is a plain `us` fallback, and the choice lives in the
// state file this page writes -- and the same is true of config.kdl on the
// other flavor. See desktop-tweak's header for the mechanism.
//
// The one thing that can still overrule it is local.lua or local.kdl, both
// read after the generated file. A machine that sets the layout there keeps
// whatever it says and should stop, if it wants this page to be in charge.
//
// WHAT IS NOT HERE, and each absence is a decision rather than a gap:
//
//   - Layout VARIANTS -- us(intl), es(dvorak), and about six hundred more.
//     They multiply a list of ninety-nine into one nobody can scroll, and the
//     variant is the part almost nobody needs: what people mean by "I need to
//     type in Spanish" is a layout. `desktop-tweak set layouts` takes what
//     this page offers, and a variant is still reachable by hand from the
//     machine's local config.
//   - kb_options, which is where xkb's own group switchers live
//     (grp:alt_shift_toggle and friends). Deliberately unused: they move an
//     index that dies with the session and that nothing outside the
//     compositor can read, so the bar would have no way of knowing what you
//     are typing in. SUPER + K goes through the script instead.
//   - Per-device settings, AND THIS ONE IS NOW AN ABSENCE ON BOTH SIDES OF
//     THE LINE. Hyprland can configure each mouse separately with hl.device,
//     and a page that offered it would need a device list, a per-device store
//     and a way to talk about a mouse that is not plugged in today. niri has
//     no per-device input configuration AT ALL, so on that flavor there is
//     nothing to offer even if the page wanted to -- which is why the one
//     real casualty, the DualSense's touchpad moving the pointer, is written
//     up in config.kdl's input block rather than here. The values on this page
//     are the defaults every device inherits, which is what somebody adjusting
//     their pointer speed actually means.
//   - Anything touchpad. There is no touchpad on this machine, and a section
//     that is always empty teaches the eye to skip the page.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    // Pointer speed, keyboard repeat and the layout cycle are all pushed into
    // the compositor. No way to push them, no page.
    available: Compositor.can("inputConfig")

    title: "Input"
    glyph: Icons.mouse
    // "spanish", "latam" and "español" are in here on purpose: somebody
    // looking for this row is looking for the language they want to type in,
    // not for the word "layout". The list itself is searched separately, by
    // the field in that section.
    keywords: ["mouse", "pointer", "sensitivity", "speed", "acceleration",
        "accel", "scroll", "natural scroll", "keyboard", "repeat", "delay",
        "key repeat", "layout", "keymap", "xkb", "language", "spanish",
        "español", "latam", "latin american", "distribución", "accents",
        // "active layout" was a ROW here until the layout section was
        // redesigned -- the ChoiceRow that used to carry that label is gone,
        // and without this the words that reached this page for two months
        // reach nothing. The cycle rows are labelled with the layout's name
        // now, so "spanish" still finds it on its own.
        "dead keys", "ñ", "active layout", "cycle"]

    // The code-to-name table, asked for the first time this page is looked at.
    // See Config.ensureLayoutNames: nothing at startup needs ninety-nine
    // layout names, and the bar's pill shows the code.
    onVisibleChanged: {
        if (visible)
            Config.ensureLayoutNames();
    }

    // What the search field is holding. On the page and not in the section so
    // that it survives the section being rebuilt.
    property string layoutQuery: ""

    // THE CYCLE IN THE ORDER SUPER + K WALKS IT, starting at the layout in
    // use, and this reverses what the page used to do -- so the old reasoning
    // goes first.
    //
    // The cycle used to be shown sorted by code. The store ROTATES on
    // Hyprland -- "us,latam" becomes "latam,us" when you switch -- so drawing
    // it as stored meant the segments of a ChoiceRow swapped places every
    // time one of them was clicked, and the next one you reached for had
    // moved out from under the pointer. Sorting is stable under rotation,
    // because a rotation changes the order and never the set, and that bought
    // a control that stayed still.
    //
    // What it cost was the ORDER, which is the only thing a cycle has beyond
    // its members. SUPER + K steps this list; a display that hides the
    // sequence cannot answer "and then what", and with three or four layouts
    // that is the entire question. The old comment said the order "was never
    // the right thing to read here" and pointed at the keybind. That was the
    // wrong way round: the keybind is where the order is FELT, which is
    // exactly why this is where it has to be READ.
    //
    // Anchoring the display at the active layout buys the order back and pays
    // less for it than sorting did:
    //
    //   - A ring has no first element, so it needs an anchor, and the layout
    //     you are typing in right now is the only one that means anything.
    //     Read down the list and you are reading what SUPER + K will do next.
    //   - It makes the two flavors draw the same thing. Hyprland rotates the
    //     stored list and niri keeps an index into it (see Config); rotating
    //     the display by that index hides a difference that was never the
    //     user's business.
    //   - The click that moves it is no longer ambiguous. What made the old
    //     control dangerous was that a click reshuffled the row you were
    //     about to press NEXT. Here the row you clicked moves to a place the
    //     list already names -- the top, because the top is what you are
    //     typing in -- and nothing else changes place.
    //
    // THE ORDER IS SHOWN AND NOT EDITED, which is a smaller claim than it
    // looks. With two layouts, the case this machine and most others are in,
    // a ring of two has one sequence and there is nothing to reorder. Past
    // that, "move this one up" means two different things underneath: on
    // Hyprland the stored list is the ring rotated to put the active layout
    // first, so a reorder has to be rewritten to preserve that, while on niri
    // the stored positions ARE the indices `niri msg action switch-layout`
    // takes, so rewriting them moves what the compositor is pointing at. One
    // control, two meanings, and on one flavor a silent change of the layout
    // you are typing in. Removing and adding again is two clicks, does the
    // same thing, and cannot mean anything else.
    readonly property var layoutCycle: {
        const list = Config.keyboardLayouts;
        if (list.length === 0)
            return [];

        const at = Config.keyboardLayoutIndex;
        const out = [];
        for (let i = 0; i < list.length; i++)
            out.push(list[(at + i) % list.length]);
        return out;
    }

    // Every layout xkb ships, for the section that ADDS one.
    //
    // ONE JOB, which is the whole change on this page: this list only ever
    // adds. It used to be the same rows that also switched and removed, with
    // the configured ones hoisted to the top wearing badges, so a click meant
    // "add" in one part of it and "switch to" in another and the answer to
    // "what am I using" was mixed into the answer to "what could I use". The
    // cycle has its own section above now, and nothing in this one moves it.
    //
    // The configured ones are still IN the list, dimmed and saying so, rather
    // than dropped: a search for "spanish" that came back empty because the
    // layout was already configured would read as the search being broken.
    //
    // Plain alphabetical, with nothing hoisted -- there is nothing up here
    // worth reaching first any more. While there is a query the order is the
    // score's, because then the list is an answer to what was typed rather
    // than a list to look down.
    readonly property var layoutRows: {
        const names = Config.layoutNames;
        const all = Object.keys(names).map(code => ({ code, name: names[code] }));

        // Before the process has come back there is nothing to list except
        // what is already configured, which at least draws the section
        // instead of an empty card.
        const rows = all.length > 0 ? all
            : Config.keyboardLayouts.map(code => ({ code, name: code }));

        const query = root.layoutQuery.trim();

        if (query !== "") {
            return rows
                .map(row => ({
                    row,
                    // The name and the code both, scored separately and the
                    // better one kept: "spanish" has to find latam and "lat"
                    // has to find it too, and neither string contains the
                    // other's answer.
                    score: Math.max(Fuzzy.score(row.name, query), Fuzzy.score(row.code, query))
                }))
                .filter(scored => scored.score >= 0)
                .sort((a, b) => b.score - a.score)
                .map(scored => scored.row);
        }

        return rows.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    // Add one to the end of the cycle. The end and not the front: adding a
    // layout is not the same as asking to type in it, and a list that jumped
    // you into Greek because you were curious what it was called would be
    // worse than one extra click.
    function addLayout(code: string): void {
        if (Config.keyboardLayouts.includes(code))
            return;
        if (Config.keyboardLayouts.length >= Config.keyboardLayoutMax)
            return;

        Config.setKeyboardLayouts(Config.keyboardLayouts.concat([code]));
    }

    // Take one out. Removing the active one is allowed and does the obvious
    // thing -- whatever is next becomes active, because the first entry IS the
    // active one. The last one cannot go: a keyboard has to be something.
    function removeLayout(code: string): void {
        if (Config.keyboardLayouts.length <= 1)
            return;

        Config.setKeyboardLayouts(Config.keyboardLayouts.filter(other => other !== code));
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.mouse
        title: "Mouse"

        // STORED IN HUNDREDTHS AND SHOWN AS A FRACTION. Hyprland takes
        // -1.0..1.0 and the script keeps whole numbers, because bash has no
        // floating point and a shell script that shells out to bc to check a
        // number is a shell script looking for a different language. The
        // conversion happens once, here and in the script, and the two agree
        // because neither of them rounds.
        StepperRow {
            glyph: Icons.mouse
            label: "Pointer speed"
            value: Config.sensitivity
            from: -100
            to: 100
            step: 5
            display: (Config.sensitivity / 100).toFixed(2)
            onMoved: value => Config.setTweak("sensitivity", value)

            hint: "Zero is the hardware's own speed, which is what libinput "
                + "reports before anything is applied to it. Negative is "
                + "slower, positive is faster; this is not a DPI setting and "
                + "the mouse's own is untouched."
        }

        ChoiceRow {
            glyph: Icons.tune
            label: "Acceleration"
            options: [
                { label: "Adaptive", value: "adaptive" },
                { label: "Flat", value: "flat" }
            ]
            value: Config.accel
            onChosen: value => Config.setTweak("accel", value)

            hint: "Adaptive moves the pointer further when the mouse moves "
                + "faster, which is what a desktop expects. Flat maps "
                + "movement one to one at any speed, which is what a game "
                + "expects — if you have ever turned acceleration off in a "
                + "shooter, this is that setting."
        }

        ToggleRow {
            glyph: Icons.swapVertical
            label: "Natural scrolling"
            checked: Config.naturalScroll
            onToggled: value => Config.setTweak("natural-scroll", value ? 1 : 0)
        }
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.keyboard
        title: "Keyboard"

        // THE TWO HALVES OF HOLDING A KEY DOWN, and they are easy to confuse
        // because both are "how fast does it repeat". The delay is how long
        // before the first repeat -- the guard against a key held a moment too
        // long turning into ten characters. The rate is how quickly they come
        // after that.
        StepperRow {
            glyph: Icons.keyboard
            label: "Repeat delay"
            value: Config.repeatDelay
            from: 150
            to: 800
            step: 25
            suffix: " ms"
            onMoved: value => Config.setTweak("repeat-delay", value)

            hint: "How long a key has to be held before it starts repeating."
        }

        StepperRow {
            glyph: Icons.keyboard
            label: "Repeat rate"
            value: Config.repeatRate
            from: 10
            to: 80
            step: 5
            suffix: "/s"
            onMoved: value => Config.setTweak("repeat-rate", value)

            hint: "Characters per second once it has started."
        }
    }

    // ---------------- Layout ----------------
    //
    // A CYCLE AND NOT A SINGLE CHOICE, because the thing people do with this
    // is switch back and forth: code in English, write in Spanish, and back.
    // One layout at a time would mean coming to this window twice a paragraph.
    // SUPER + K and the pill on the bar both step it.
    //
    // TWO SECTIONS, AND THAT IS THE WHOLE REDESIGN. This was one list doing
    // two jobs: every layout xkb ships, with the handful actually configured
    // hoisted to the top wearing an "Active" badge and an x, plus a ChoiceRow
    // above it showing the same handful a third time, plus a line of prose
    // explaining that a click means "add" down here and something else up
    // there. Three drawings of one set, one click with two meanings, and a
    // sentence apologising for both.
    //
    // So: "Layout cycle" is what you have and what it does, and "Add a
    // layout" is the several hundred you could have. Each list has one verb.
    // Which layouts are in the cycle is the first card; the order is the
    // order they are drawn in; which one is active is the top row and the
    // filled pill; removing is the x, which is only in the first card; adding
    // is a click in the second, which does nothing else. None of that needs a
    // sentence under it, which is why there is no longer one.
    SettingsSection {
        width: parent.width
        glyph: Icons.keyboard
        title: "Layout cycle"

        Repeater {
            model: root.layoutCycle

            delegate: Rectangle {
                id: cycleEntry

                required property var modelData
                required property int index

                readonly property string code: cycleEntry.modelData
                readonly property string name: Config.layoutName(cycleEntry.code)
                // The list starts at the layout in use -- see layoutCycle --
                // so being first IS being active, and the row after it is
                // where SUPER + K goes.
                readonly property bool active: cycleEntry.index === 0
                readonly property bool isNext: cycleEntry.index === 1

                // WHAT SettingsSearch MATCHES ON. The walk duck-types a row
                // as anything carrying a non-empty `label`, and these are
                // rows: "spanish" should find the layout you are using. There
                // are at most four of them, which is why the browse list
                // below deliberately has no label on its delegate -- ninety-
                // nine layouts in the index would drown every other answer.
                readonly property string label: cycleEntry.name
                readonly property string glyph: Icons.keyboard

                width: parent ? parent.width : 320
                implicitHeight: Theme.groupHeight

                radius: Theme.groupRadius
                // The active row takes no hover tint: it is the one row here
                // with nothing to do when clicked.
                color: cycleMouse.containsMouse && !cycleEntry.active
                    ? Theme.surfaceContainerHigh : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                // THE CODE IN CAPS AND FILLED WHEN ACTIVE. Two things at
                // once, and both of them are why it is a pill rather than a
                // word: it is what the bar shows, so this row and that pill
                // say the same thing in the same shape; and filled-versus-
                // outlined is a state you can read at a glance from across
                // the card, which "Active" written in small letters at the
                // other end of the row was not.
                Rectangle {
                    id: cycleCode

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: Math.max(56, cycleCodeLabel.implicitWidth + 18)
                    implicitHeight: 24
                    radius: height / 2

                    color: cycleEntry.active ? Theme.primary : "transparent"
                    border.width: cycleEntry.active ? 0 : 1
                    border.color: Theme.outlineVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        id: cycleCodeLabel

                        anchors.centerIn: parent
                        text: cycleEntry.code.toUpperCase()
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1.5
                        font.weight: cycleEntry.active ? Font.Bold : Theme.fontWeight
                        color: cycleEntry.active ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                Text {
                    id: cycleName

                    anchors.left: cycleCode.right
                    anchors.leftMargin: Theme.itemSpacing
                    anchors.right: cycleTrailing.left
                    anchors.rightMargin: Theme.itemSpacing
                    anchors.verticalCenter: parent.verticalCenter

                    text: cycleEntry.name
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: cycleEntry.active ? Font.Bold : Theme.fontWeight
                    color: cycleEntry.active ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                // A Row rather than two anchored items, because both of these
                // come and go: a Row drops an invisible child and closes the
                // gap, where an item anchored to an invisible neighbour keeps
                // the hole where it used to be.
                Row {
                    id: cycleTrailing

                    anchors.right: parent.right
                    anchors.rightMargin: Theme.groupPadding - 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.itemSpacing

                    // THE ROW SUPER + K TAKES YOU TO, WEARING THE KEY THAT
                    // TAKES YOU THERE. This is what makes the order legible
                    // without a caption claiming the rows are in cycle order:
                    // the second row is labelled with the thing that reaches
                    // it, and the rest follow from there.
                    //
                    // The chips are the keybinds page's, down to the sizes:
                    // the key takes the accent and the modifier stays muted,
                    // because the modifier is the part you already know.
                    Row {
                        visible: cycleEntry.isNext
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Repeater {
                            model: ["SUPER", "K"]

                            Rectangle {
                                id: keyChip

                                required property int index
                                required property string modelData

                                readonly property bool isKey: keyChip.index === 1

                                implicitWidth: keyChipLabel.implicitWidth + 14
                                implicitHeight: 22
                                radius: height / 2

                                color: keyChip.isKey ? Theme.primaryContainer : Theme.surfaceContainerHighest

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }

                                Text {
                                    id: keyChipLabel

                                    anchors.centerIn: parent
                                    text: keyChip.modelData
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSize - 1.5
                                    font.weight: Theme.fontWeight
                                    color: keyChip.isKey ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.recolorDuration }
                                    }
                                }
                            }
                        }
                    }

                    // Its own target over the row's own click, so the two
                    // meanings never share a hit area: the row means "type in
                    // this", the x means "stop offering it". The last
                    // remaining layout has no x -- a keyboard has to be
                    // something.
                    Item {
                        id: cycleRemove

                        anchors.verticalCenter: parent.verticalCenter

                        visible: Config.keyboardLayouts.length > 1
                        implicitWidth: 24
                        implicitHeight: 24

                        Text {
                            anchors.centerIn: parent
                            text: Icons.close
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize
                            color: removeMouse.containsMouse ? Theme.critical : Theme.outline

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        MouseArea {
                            id: removeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeLayout(cycleEntry.code)
                        }
                    }
                }

                MouseArea {
                    id: cycleMouse

                    anchors.fill: parent
                    // UNDER EVERY SIBLING, which is what leaves the x
                    // clickable. Among items with the same z the one declared
                    // LAST wins the pointer, and this one is last because it
                    // has to cover the whole row -- so it takes a negative z
                    // and the remove target keeps its own hit area inside it.
                    z: -1
                    hoverEnabled: true
                    // ONE VERB IN THIS CARD: make this the layout I am typing
                    // in. The row that already says yes is not a target.
                    enabled: !cycleEntry.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.useKeyboardLayout(cycleEntry.code)
                }
            }
        }

        // WHAT THE LIST CANNOT DRAW: that the sequence wraps, and that the
        // same thing is a click away on the bar. Not an explanation of the
        // control above it -- that one explains itself now -- which is why it
        // is two short lines instead of the paragraph that used to be here.
        SectionNote {
            topPadding: 4
            bottomPadding: 4

            text: Config.keyboardLayouts.length > 1
                ? "SUPER + K steps to the next one and wraps at the end. So "
                  + "does clicking the layout on the bar."
                : "One layout, so there is nothing to step. Add a second "
                  + "below and SUPER + K starts cycling."
        }
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.search
        title: "Add a layout"

        // The ceiling is xkb's and not this window's: a keymap holds four
        // groups, and a fifth layout is accepted by the parser and then never
        // reached by the cycle. Said out loud only when it is reached -- a
        // limit nobody is near is a sentence that teaches the eye to skip
        // this part of the card. It sits above the field rather than below
        // the list, because it is the reason nothing in the list can be
        // clicked and that is worth knowing before scrolling it.
        SectionNote {
            visible: Config.keyboardLayouts.length >= Config.keyboardLayoutMax

            text: "Four layouts is the most an xkb keymap can hold. Remove "
                + "one above before adding another — a fifth would be "
                + "accepted and then never reached."
            color: Theme.warning
        }

        SearchField {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2

            placeholder: "Search layouts"

            // NOT focused on arrival. The page is mostly steppers and
            // switches, and a field that takes the keyboard as soon as the
            // page is opened would swallow the first thing typed by somebody
            // who came here for the pointer speed.
            onTextChanged: root.layoutQuery = text
            onEscaped: {
                clear();
                root.layoutQuery = "";
            }
        }

        // Same ceiling-and-capture arrangement as the network list, and for
        // the same reason: this is a card of however many layouts xkb happens
        // to ship -- ninety-nine of them -- inside a page that also scrolls.
        // 220 is about six rows, enough to see the top of the search results
        // without the field scrolling off the screen behind them.
        ScrollList {
            id: layoutList

            width: parent.width
            height: Math.min(layoutEntries.implicitHeight, 220)
            contentHeight: layoutEntries.implicitHeight

            Column {
                id: layoutEntries

                width: layoutList.width
                spacing: 2

                Repeater {
                    model: root.layoutRows

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property string code: entry.modelData.code
                        readonly property bool configured: Config.keyboardLayouts.includes(entry.code)
                        // Nothing can be added while the cycle is full.
                        // Dimmed rather than hidden -- a list that silently
                        // dropped ninety rows when you added a fourth layout
                        // would look broken.
                        readonly property bool addable: !entry.configured
                            && Config.keyboardLayouts.length < Config.keyboardLayoutMax

                        // NO `label` HERE, deliberately: SettingsSearch walks
                        // children and duck-types a row by that property, and
                        // ninety-nine of them would bury every other answer
                        // in the window. The four in the cycle above carry one
                        // instead.

                        width: layoutEntries.width
                        implicitHeight: 34

                        radius: Theme.groupRadius
                        color: entryMouse.containsMouse && entry.addable
                            ? Theme.surfaceContainerHigh : "transparent"

                        opacity: entry.addable || entry.configured ? 1 : 0.4

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        Text {
                            id: entryName

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: entryCode.left
                            anchors.rightMargin: Theme.itemSpacing

                            text: entry.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                            color: entry.configured ? Theme.textOnSurfaceVariant : Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // The code, always: it is what the bar shows and what
                        // every command takes, so this is where somebody
                        // learns that the pill saying LATAM is this row.
                        Text {
                            id: entryCode

                            anchors.right: entryMark.left
                            anchors.rightMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter

                            text: entry.code
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // WHAT THIS ROW WOULD DO, on the row itself: a plus
                        // where the click adds one, and the word where it is
                        // already yours. A layout already in the cycle is not
                        // hidden and not clickable -- it is answered. That is
                        // what keeps this list to one verb: nothing in it
                        // ever means "switch to" or "remove", which is what
                        // the card above is for.
                        //
                        // The plus is a character and not a glyph from the
                        // font, the same call StepperRow's buttons make: it
                        // is one shape everybody reads and it needs no
                        // codepoint checked against the cmap.
                        Text {
                            id: entryMark

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter

                            text: entry.configured ? "In cycle" : "+"
                            font.family: Theme.fontFamily
                            font.pointSize: entry.configured ? Theme.fontSize - 1 : Theme.fontSize + 2
                            font.weight: entry.configured ? Theme.fontWeight : Font.Bold
                            color: entry.configured ? Theme.outline
                                : entryMouse.containsMouse && entry.addable ? Theme.primary
                                : Theme.outline

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        MouseArea {
                            id: entryMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: entry.addable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: entry.addable
                            onClicked: root.addLayout(entry.code)
                        }
                    }
                }
            }
        }
    }
}
