// Mouse and keyboard: how far the pointer moves for a given push, and how
// fast a held key repeats.
//
// ALL OF IT IS THE COMPOSITOR'S. Hyprland owns libinput here; the shell never
// sees a pointer event that is not already scaled by these numbers, and
// cannot apply any of them itself. Everything on this page goes out through
// `hypr-tweak` -- one state file, one generated tweaks.lua, `hyprctl eval`
// for the running session. See that script's header.
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
// state file this page writes. See hypr-tweak's header for the mechanism.
//
// The one thing that can still overrule it is local.lua, which is read after
// the generated file. A machine that sets kb_layout there keeps whatever it
// says and should stop, if it wants this page to be in charge.
//
// WHAT IS NOT HERE, and each absence is a decision rather than a gap:
//
//   - Layout VARIANTS -- us(intl), es(dvorak), and about six hundred more.
//     They multiply a list of ninety-nine into one nobody can scroll, and the
//     variant is the part almost nobody needs: what people mean by "I need to
//     type in Spanish" is a layout. `hypr-tweak set layouts` takes what this
//     page offers, and a variant is still reachable by hand from local.lua.
//   - kb_options, which is where xkb's own group switchers live
//     (grp:alt_shift_toggle and friends). Deliberately unused: they move an
//     index that dies with the session and that nothing outside the
//     compositor can read, so the bar would have no way of knowing what you
//     are typing in. SUPER + K goes through the script instead.
//   - Per-device settings. Hyprland can configure each mouse separately with
//     hl.device, and a page that offered it would need a device list, a
//     per-device store and a way to talk about a mouse that is not plugged in
//     today. The values here are the defaults every device inherits, which is
//     what somebody adjusting their pointer speed actually means.
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
        "dead keys", "ñ"]

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

    // The configured layouts in a FIXED order, which is not the order they are
    // stored in.
    //
    // The store rotates -- that is how it remembers which one is active -- so
    // showing the cycle as it is stored would mean the segments swapped places
    // every time one of them was clicked, and the row you just pressed moved
    // out from under the pointer. Sorting by code is stable under rotation,
    // because a rotation changes the order and never the set.
    //
    // What is lost is the cycle ORDER, which this control was never the right
    // place to read: SUPER + K is where that is felt, and the sequence is
    // still whatever the store holds.
    readonly property var layoutsInFixedOrder: Config.keyboardLayouts.slice().sort()

    // The whole list, in the order the rows are drawn.
    //
    // CONFIGURED FIRST AND IN CYCLE ORDER, then everything else by name. The
    // rows worth clicking are the ones already in use -- that is where you go
    // to switch or to remove -- and past that a stable alphabetical list beats
    // a clever one, the same call NetworkPage makes about sorting by signal.
    //
    // While there is a query the order is the score's, because then the list
    // is an answer to what was typed rather than a list to look down.
    readonly property var layoutRows: {
        const names = Config.layoutNames;
        const all = Object.keys(names).map(code => ({ code, name: names[code] }));

        // Before the process has come back there is nothing to list except
        // what is already configured, which is enough to switch between.
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

        // In the fixed order and not the stored one, for the reason given on
        // layoutsInFixedOrder: rows that reshuffle when you click one are how
        // you end up clicking the wrong one next.
        const configured = root.layoutsInFixedOrder
            .map(code => rows.find(row => row.code === code))
            .filter(row => row !== undefined);

        const rest = rows
            .filter(row => !Config.keyboardLayouts.includes(row.code))
            .sort((a, b) => a.name.localeCompare(b.name));

        return configured.concat(rest);
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
    // The first entry is the one in use; SUPER + K and the pill on the bar
    // both step it.
    SettingsSection {
        width: parent.width
        glyph: Icons.keyboard
        title: "Layout"

        // The segments are the CODES, in caps, and not the names -- "US",
        // "LATAM". Two reasons: they are what the bar shows, so this control
        // and that pill say the same word; and a name like "Spanish (Latin
        // American)" elides to "Spanish (La…" in a quarter of this width,
        // which is not a label. The names are in the list below.
        ChoiceRow {
            visible: Config.keyboardLayouts.length > 1

            glyph: Icons.keyboard
            label: "Active layout"
            options: root.layoutsInFixedOrder.map(code => ({
                label: code.toUpperCase(),
                value: code
            }))
            value: Config.keyboardLayout

            onChosen: value => Config.useKeyboardLayout(value)

            hint: "What the keyboard is typing in right now — every "
                + "application on the machine, not just this shell. SUPER + K "
                + "steps through the same list without opening this window, "
                + "and so does clicking the layout on the bar."
        }

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            // A ChoiceRow ends a handful of pixels under its own segments,
            // so a caption with no top padding sits against them and reads as
            // a label belonging to the last one.
            topPadding: 6
            bottomPadding: 6

            text: Config.keyboardLayouts.length > 1
                ? "Click a layout below to add it to the cycle, and the × to "
                  + "take it out."
                : "One layout is configured. Add a second below and the pair "
                  + "becomes a cycle you can step with SUPER + K."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The ceiling is xkb's and not this window's: a keymap holds four
        // groups, and a fifth layout is accepted by the parser and then never
        // reached by the cycle. Said out loud only when it is reached --
        // a limit nobody is near is a sentence that teaches the eye to skip
        // this part of the card.
        Text {
            visible: Config.keyboardLayouts.length >= Config.keyboardLayoutMax

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "Four layouts is the most an xkb keymap can hold. Remove "
                + "one before adding another — a fifth would be accepted and "
                + "then never reached."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
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
        // 220 is about six rows, enough to see the configured ones plus the
        // top of the search results.
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
                        readonly property bool active: Config.keyboardLayout === entry.code
                        // A row that cannot be clicked: the cycle is full and
                        // this one is not in it. Dimmed rather than hidden --
                        // a list that silently drops ninety rows when you add
                        // a fourth layout would look broken.
                        readonly property bool reachable: entry.configured
                            || Config.keyboardLayouts.length < Config.keyboardLayoutMax

                        width: layoutEntries.width
                        implicitHeight: 34

                        radius: Theme.groupRadius
                        // Membership is the tint and the active one is the
                        // word on the right. Two marks for two different
                        // facts: being in the cycle, and being the one in use.
                        color: entryMouse.containsMouse && entry.reachable ? Theme.surfaceContainerHigh
                            : entry.configured ? Qt.alpha(Theme.surfaceContainerHigh, 0.5)
                            : "transparent"

                        opacity: entry.reachable ? 1 : 0.4

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
                            font.weight: entry.active ? Font.Bold : Theme.fontWeight
                            color: entry.active ? Theme.primary : Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // The code, always, and not only for the configured
                        // ones: it is what the bar shows and what every
                        // command takes, so this is where somebody learns
                        // that the pill saying LATAM is this row.
                        Text {
                            id: entryCode

                            anchors.right: entryState.left
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

                        Text {
                            id: entryState

                            anchors.right: entryRemove.left
                            anchors.rightMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter

                            visible: entry.active
                            text: "Active"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            color: Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // Its own target, over the row's own click, so the two
                        // meanings never share a hit area: the row means "type
                        // in this", the × means "stop offering it". The last
                        // remaining layout has no × -- a keyboard has to be
                        // something.
                        Item {
                            id: entryRemove

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding - 6
                            anchors.verticalCenter: parent.verticalCenter

                            visible: entry.configured && Config.keyboardLayouts.length > 1
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
                                onClicked: root.removeLayout(entry.code)
                            }
                        }

                        MouseArea {
                            id: entryMouse

                            anchors.fill: parent
                            // UNDER EVERY SIBLING, which is what leaves the ×
                            // clickable. Among items with the same z the one
                            // declared LAST wins the pointer, and this one is
                            // last because it has to cover the whole row --
                            // so it takes a negative z and the remove target
                            // keeps its own hit area inside it.
                            z: -1
                            hoverEnabled: true
                            cursorShape: entry.reachable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: entry.reachable

                            // Two verbs on one click, and they do not overlap:
                            // a layout that is not in the cycle gets added, a
                            // layout that is in it becomes the active one.
                            // Clicking the one already active is the only
                            // no-op, which is what a row should do when it is
                            // already saying yes.
                            onClicked: {
                                if (!entry.configured)
                                    root.addLayout(entry.code);
                                else if (!entry.active)
                                    Config.useKeyboardLayout(entry.code);
                            }
                        }
                    }
                }
            }
        }
    }
}
