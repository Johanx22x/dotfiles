// The keybinds page: every chord the compositor is holding right now, what
// the ones that say so are for, and the ones that answer the same keystroke.
//
// IT READS AND IT DOES NOT WRITE, and that is a decision about what can be
// known, not a corner cut. hyprland.lua is Lua, so every bind reaches
// `hyprctl binds -j` as `"dispatcher": "__lua"` with `"arg"` set to an
// integer -- an index into a callback registry that lives inside the
// compositor's Lua state and means nothing outside it. The chord is knowable
// and the prose description is knowable; WHAT THE BIND DOES is not. An editor
// has to read a bind back before it can offer to change it, and this one
// cannot be read back: "SUPER W runs callback 12" is not something anyone can
// edit, and rewriting it from a form would mean writing a bind whose old body
// nothing here ever saw.
//
// The two ways out were both tried and both are closed. `hyprctl keyword
// bind ...` is refused on this machine -- "keyword can't work with non-legacy
// parsers" -- and `hyprctl eval 'hl.bind(...)'` does take, but only until the
// next `hyprctl reload` re-runs hyprland.lua and erases it. A setting that
// survives until the next reload is worse than no setting at all.
//
// And the file it would have to write is not a list to be regenerated: 981
// lines, roughly ninety of them prose explaining why each key sits where it
// does, plus a `for` loop that turns two `hl.bind` calls into the twenty
// workspace binds this page lists. It is git-tracked and stowed, and a
// generator pointed at it would produce a correct list of binds while
// destroying the only record of why they are those binds. So hyprland.lua
// stays the source and this page stays a view of it.
//
// WHAT THIS SHOWS THAT THE CHEATSHEET DOES NOT. The cheatsheet answers "what
// can I do", so it drops binds with no description on purpose. This page also
// answers "is that key already taken", which is the opposite filter: an
// undescribed bind is exactly the one you are about to collide with, so it is
// listed too, marked as undescribed rather than left blank.

import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"

SettingsPage {
    id: root

    // This page LISTS what is bound, which means reading it back out of the
    // compositor. Nothing to read, nothing to list.
    available: Compositor.can("bindsIntrospection")

    title: "Keybinds"
    glyph: Icons.keyboard
    // "conflict" and "taken" are the questions this page answers that its own
    // title does not say out loud.
    keywords: [
        "keybind", "keybinding", "hotkey", "shortcut", "shortcuts", "keys",
        "keyboard", "bind", "chord", "conflict", "hyprland"
    ]

    // ---------------- Glyphs that are not in Icons yet ----------------
    //
    // TEMPORARY, and they belong in Icons.qml -- they are here only because
    // that file is not mine to edit right now. Move them when it is free;
    // nothing about them should change on the way.
    //
    // All three codepoints were read out of the installed font's cmap rather
    // than looked up by name, which is the rule Icons.qml's own comments set
    // after two of its entries turned out to be a bluetooth speaker and a
    // shower head:
    //
    //   python3 -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap()[0xF0026])"
    //
    // Icons.thermometerAlert is the shell's other alert mark and is wrong
    // here: it is a temperature that has gone too high, not a warning in
    // general.
    readonly property string alert: String.fromCodePoint(0xF0026)        // nf-md-alert
    readonly property string allClear: String.fromCodePoint(0xF05E1)     // nf-md-check_circle_outline
    readonly property string unlabelled: String.fromCodePoint(0xF0625)   // nf-md-help_circle_outline

    // ---------------- Geometry ----------------

    // The chord sits in a fixed-width gutter so every description in the list
    // starts at the same x, the same as the cheatsheet's rows. Measured
    // against the widest chord bound here, SUPER + SHIFT + Enter.
    readonly property int keyGutter: 150

    // A CEILING ON THE LIST, not a height for it. Sixty-four binds at thirty
    // pixels a row plus eight headings is around two thousand pixels, and a
    // page that tall is a page whose section about how to edit binds is a
    // thousand pixels below the fold. The list scrolls inside itself instead,
    // so the conflicts above it and the note below it are always both on
    // screen. About eleven rows.
    readonly property int listCeiling: 340

    // ---------------- Turning a bind into something readable ----------------
    //
    // COPIED FROM modules/cheatsheet/Cheatsheet.qml, not shared with it, and
    // that is now two files that have to agree about what "SUPER" and "Esc"
    // are. The right home is a singleton next to Theme and Icons -- the pair
    // below plus the keyNames table -- and the second caller is what makes
    // that worth doing. Lift them the next time either file is opened for
    // something else; not done here because that is an edit to the cheatsheet
    // and this page is the only thing being changed.

    // The X11 modifier bits. Hyprland reports the mask raw; only these four
    // are ever bound by hand, and the rest (caps, numlock) would be noise on
    // a chip even when set.
    function modifiers(mask: int): var {
        const out = [];
        if (mask & 64) out.push("SUPER");
        if (mask & 8)  out.push("ALT");
        if (mask & 4)  out.push("CTRL");
        if (mask & 1)  out.push("SHIFT");
        return out;
    }

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
        // keysym.
        return root.keyNames[key] ?? (key.startsWith("XF86") ? key.slice(4) : key);
    }

    // ---------------- What counts as the same keystroke ----------------
    //
    // THE WHOLE CONFLICT FEATURE IS THIS FUNCTION, so it is worth being exact
    // about which fields are in it and which are deliberately out.
    //
    // IN, because each one changes WHICH EVENT reaches the bind:
    //   submap   -- a submap is a mode. Two binds in different submaps are
    //               never live at the same moment, so they cannot collide.
    //               The empty submap is the root one and is a value like any
    //               other.
    //   modmask  -- compared for equality, not overlap: Hyprland matches the
    //               held modifiers exactly, so SUPER and SUPER + SHIFT are two
    //               different keystrokes and not a near miss.
    //   the key  -- the keysym, lowercased, because "S" and "s" name the same
    //               physical key; or the KEYCODE when there is one, since a
    //               bind written by code has no keysym to compare and 0 means
    //               "not by code" rather than "code zero".
    //   press / release / long press -- three different events. A bind on the
    //               way down and a bind on the way up of the same chord is a
    //               pair, not a clash.
    //
    // OUT, because they change what a bind DOES once it has already been
    // reached, which is not the question:
    //   locked        -- only says the bind still works over a lock screen. In
    //                    an unlocked session a locked and an unlocked bind on
    //                    the same chord both fire, so this is a conflict and
    //                    excluding the field is what lets it be seen.
    //   non_consuming -- says the key ALSO goes on to the window. Two binds
    //                    still both fire.
    //   repeat, mouse -- how it is held or which device pressed it, both
    //                    already implied by the key.
    //
    // KNOWN BLIND SPOT, and it is honest to name it: a catch_all bind swallows
    // every key in its submap, which collides with everything there without
    // sharing a key with any of it. There is none here; when there is, this
    // will not see it.
    function bindId(bind: var): string {
        const key = bind.keycode ? `code:${bind.keycode}`
            : String(bind.key ?? "").toLowerCase();
        const event = bind.release ? "release" : bind.longPress ? "long" : "press";
        // NUL as the separator, so a submap named "press" cannot fake a match
        // against a field boundary.
        return [bind.submap ?? "", bind.modmask ?? 0, key, event].join("\u0000");
    }

    // ---------------- The list ----------------

    // The order categories are shown in, and the same order the cheatsheet
    // uses -- both read the categories out of the descriptions in
    // hyprland.lua, so a different order in each would be two answers to one
    // question. A category not named here still appears, at the end, in the
    // order hyprctl reported it.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // One record per bind, in the order hyprctl reported them. Filled by the
    // Process at the bottom; the two bindings under it are derived from this
    // and from nothing else.
    property var entries: []

    // Lowercased once here rather than in the loop that uses it, which runs
    // over every bind on every keystroke typed into the field.
    readonly property string query: filter.text.trim().toLowerCase()

    readonly property int total: root.entries.length
    readonly property int shown: root.groups.reduce((n, group) => n + group.binds.length, 0)

    // Where a category sits. `arrival` is a snapshot taken before the sort:
    // reading the position of a name in the very array being sorted gives a
    // different answer halfway through than at the start.
    function rank(name: string, arrival: var): int {
        // Always last, whatever else is on the page. It is the group you go
        // to on purpose, and it is a third of the list.
        if (name === "Undescribed")
            return 1000;

        const i = root.categoryOrder.indexOf(name);
        return i < 0 ? root.categoryOrder.length + arrival.indexOf(name) : i;
    }

    function groupGlyph(name: string): string {
        return name === "Undescribed" ? root.unlabelled : Icons.category(name);
    }

    readonly property var groups: {
        const byName = {};
        const seen = [];

        for (const entry of root.entries) {
            if (root.query !== "" && entry.haystack.indexOf(root.query) < 0)
                continue;

            if (!byName[entry.category]) {
                byName[entry.category] = { name: entry.category, binds: [] };
                seen.push(entry.category);
            }

            byName[entry.category].binds.push(entry);
        }

        const arrival = seen.slice();
        seen.sort((a, b) => root.rank(a, arrival) - root.rank(b, arrival));

        return seen.map(name => byName[name]);
    }

    // NOT FILTERED, on purpose: a conflict that the box you are typing in has
    // hidden is a conflict you were not told about. This is the one thing on
    // the page that always speaks about all sixty-odd binds.
    readonly property var conflicts: {
        const buckets = {};
        const order = [];

        for (const entry of root.entries) {
            if (!buckets[entry.id]) {
                buckets[entry.id] = [];
                order.push(entry.id);
            }
            buckets[entry.id].push(entry);
        }

        const out = [];
        for (const id of order) {
            const bucket = buckets[id];
            if (bucket.length < 2)
                continue;

            out.push({
                keys: bucket[0].keys,
                submap: bucket[0].submap,
                // A stack of non-consuming binds is one somebody wrote on
                // purpose -- that flag exists to let a key go on being
                // handled -- so it is amber rather than red. Anything else is
                // one keystroke doing two things nobody asked for.
                soft: bucket.every(entry => entry.nonConsuming),
                labels: bucket.map(entry => entry.described ? entry.text : "no description")
            });
        }

        return out;
    }

    // ---------------- The chord ----------------
    //
    // An inline component and not a file of its own: it is used twice, both
    // times in this page, and the cheatsheet already has its own copy of the
    // idiom in BindRow. A third file would be a shared component that is not
    // shared.
    //
    // RIGHT TO LEFT inside a fixed gutter, which is the whole trick: the KEY
    // is always the chip nearest its description, the modifiers trail off to
    // the left, and "S" sits at the same x in "SUPER S" and "SUPER CTRL S".
    // The key chip takes the accent and the modifiers stay muted -- the
    // modifier is the part you already know.
    component KeyChips: Row {
        id: chips

        required property var keys
        required property int gutterWidth

        layoutDirection: Qt.RightToLeft
        width: chips.gutterWidth
        spacing: 5

        Repeater {
            // Reversed to match the layout direction: index 0 after the
            // reverse is the key.
            model: chips.keys.slice().reverse()

            Rectangle {
                id: chip

                required property int index
                required property string modelData

                readonly property bool isKey: chip.index === 0

                implicitWidth: label.implicitWidth + 14
                implicitHeight: 22
                radius: height / 2

                color: chip.isKey ? Theme.primaryContainer : Theme.surfaceContainerHighest

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: chip.modelData
                    font.family: Theme.fontFamily
                    // Under the body text: a chip is a label on a key, not a
                    // sentence, and at the same size the chords compete with
                    // the descriptions instead of introducing them.
                    font.pointSize: Theme.fontSize - 1.5
                    font.weight: Theme.fontWeight
                    color: chip.isKey ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }
            }
        }
    }

    // ---------------- Filter ----------------
    Item {
        width: parent.width
        implicitHeight: filter.implicitHeight

        // components/SearchField.qml AS IT IS, not a second field written
        // here: it is already a hand-built TextInput in a pill with the clear
        // button and the focus ring this window uses everywhere else, and a
        // filter box is exactly the corner-of-a-window control its own header
        // says it is for.
        SearchField {
            id: filter

            anchors.left: parent.left
            anchors.right: counter.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            placeholder: "Filter by key or description"
            onEscaped: filter.clear()
        }

        Text {
            id: counter

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            // The count is the answer to "is that all of them", which is the
            // question a filtered list always raises.
            text: root.query === "" ? `${root.total} binds` : `${root.shown} of ${root.total}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Theme.fontWeight
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Conflicts ----------------
    //
    // ABOVE THE LIST even when there are none, and the empty state is the
    // point: "nothing shares a chord" is a thing you came here to be told,
    // and a section that only exists when something is wrong is a section
    // nobody knows to look for.
    SettingsSection {
        width: parent.width
        title: "Conflicts"
        // The heading itself carries the verdict, so the answer is legible
        // before a word of it is read.
        glyph: root.conflicts.length > 0 ? root.alert : root.allClear

        Item {
            width: parent.width
            implicitHeight: summary.implicitHeight + 8

            Text {
                id: summary

                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.right: rule.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (root.entries.length === 0)
                        return "Reading the binds…";
                    if (root.conflicts.length === 0)
                        return "No two binds answer the same keystroke.";
                    return root.conflicts.length === 1
                        ? "One keystroke reaches two binds."
                        : `${root.conflicts.length} keystrokes reach more than one bind.`;
                }

                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: root.conflicts.length > 0 ? Theme.critical : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Item {
                id: rule

                anchors.right: parent.right
                anchors.rightMargin: Theme.groupPadding - 4
                anchors.verticalCenter: parent.verticalCenter

                // A hit area larger than the glyph, the same as StepperRow's
                // hint mark: at 13pt the mark is about ten pixels across.
                implicitWidth: Theme.groupHeight - 12
                implicitHeight: Theme.groupHeight - 12

                Text {
                    anchors.centerIn: parent
                    text: Icons.info
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: ruleMouse.containsMouse ? Theme.primary : Theme.outline

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                MouseArea {
                    id: ruleMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }

            // Hung off the left edge and not off the mark, for the reason in
            // StepperRow: a note starting two thirds of the way across the
            // pane runs off the right edge, where the window's Flickable
            // clips it. It can hang below this row because this row is near
            // the top of the page -- Tooltip's own header is explicit that
            // the same trick at the bottom would be clipped away.
            Tooltip {
                text: "Same submap, same modifiers, same key, and both on the press "
                    + "or both on the release. Whether a bind is locked or "
                    + "non-consuming is not part of it: those change what it does "
                    + "after it fires, not whether it fires."
                shown: ruleMouse.containsMouse

                x: Theme.groupPadding
                y: parent.height - 2
            }
        }

        Repeater {
            model: root.conflicts

            Item {
                id: clash

                required property var modelData

                width: parent.width
                // Room for the chips even when the labels are one short
                // line: the chord is the taller of the two columns.
                implicitHeight: Math.max(clashText.implicitHeight + 10, 32)

                // The same chips as everywhere else on the page. The severity
                // is in the text, not in the chip: a red key chip would need
                // a foreground role paired with red, and inventing one is how
                // the palette stops guaranteeing its own contrast.
                KeyChips {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding
                    anchors.top: parent.top
                    anchors.topMargin: 5

                    keys: clash.modelData.keys
                    gutterWidth: root.keyGutter
                }

                Text {
                    id: clashText

                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding + root.keyGutter + 12
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.groupPadding
                    anchors.verticalCenter: parent.verticalCenter

                    // Every colliding bind is named, including the ones with
                    // nothing to say for themselves: "no description" IS the
                    // finding when a chord you thought was free turns out to
                    // be answered by something nobody labelled.
                    text: {
                        const where = clash.modelData.submap === ""
                            ? "" : ` (in submap ${clash.modelData.submap})`;
                        return clash.modelData.labels.join("  ·  ") + where;
                    }

                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    font.weight: Theme.fontWeight
                    color: clash.modelData.soft ? Theme.warning : Theme.critical

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }
            }
        }
    }

    // ---------------- Every bind ----------------
    SettingsSection {
        width: parent.width
        title: "Binds"
        glyph: Icons.keyboard

        Text {
            visible: root.query !== "" && root.groups.length === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: `Nothing bound matches “${filter.text.trim()}”.`
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ScrollList {
            id: scroller

            width: parent.width
            height: Math.min(groupList.implicitHeight, root.listCeiling)
            visible: height > 0
            contentHeight: groupList.implicitHeight

            // A Repeater in a Flickable rather than a ListView, the same call
            // NetworkPage makes: sixty-four rows all told, so recycling
            // delegates buys nothing, and every row is built once and keeps
            // its place.
            Column {
                id: groupList

                width: scroller.width
                spacing: 14

                Repeater {
                    model: root.groups

                    Column {
                        id: group

                        required property var modelData

                        width: groupList.width
                        spacing: 4

                        Row {
                            x: Theme.groupPadding
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.groupGlyph(group.modelData.name)
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
                                font.pointSize: Theme.fontSize - 1
                                font.weight: Font.Bold
                                // Letterspaced, as on the cheatsheet: at this
                                // size weight alone does not separate a
                                // heading from the rows under it.
                                font.letterSpacing: 0.8
                                color: Theme.primary

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: `${group.modelData.binds.length}`
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1.5
                                color: Theme.outline

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }
                        }

                        Rectangle {
                            x: Theme.groupPadding
                            width: group.width - Theme.groupPadding * 2
                            height: 1
                            color: Theme.outlineVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Repeater {
                            model: group.modelData.binds

                            // Not modules/cheatsheet/BindRow.qml, though it is
                            // the same shape: its label is always body text in
                            // textOnSurface, and half the rows here are
                            // undescribed and have to say so in a quieter
                            // voice. Teaching BindRow that would be an edit to
                            // the cheatsheet for this page's benefit.
                            Item {
                                id: bind

                                required property var modelData

                                width: group.width
                                implicitHeight: 30

                                KeyChips {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.groupPadding
                                    anchors.verticalCenter: parent.verticalCenter

                                    keys: bind.modelData.keys
                                    gutterWidth: root.keyGutter
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.groupPadding + root.keyGutter + 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.groupPadding
                                    anchors.verticalCenter: parent.verticalCenter

                                    // A SENTENCE AND NOT A BLANK. An empty
                                    // cell reads as a row that failed to load;
                                    // the point of listing these is that the
                                    // key is taken by something with no name.
                                    text: {
                                        if (!bind.modelData.described)
                                            return "no description in hyprland.lua";
                                        return bind.modelData.submap === ""
                                            ? bind.modelData.text
                                            : `${bind.modelData.text}  ·  in submap ${bind.modelData.submap}`;
                                    }

                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSize
                                    font.weight: Theme.fontWeight
                                    font.italic: !bind.modelData.described
                                    color: bind.modelData.described ? Theme.textOnSurface : Theme.outline

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.recolorDuration }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------- Where they are edited ----------------
    SettingsSection {
        width: parent.width
        title: "Editing"
        glyph: Icons.info

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Binds are written in ~/.config/hypr/hyprland.lua, and that file "
                + "is where they are changed. Hyprland hands out every bind as a Lua "
                + "callback number, so this window can read which keys are taken and "
                + "what they are for, but never what a bind actually runs — which is "
                + "the half an editor here would need."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Reading them ----------------
    //
    // ON EVERY TRIP TO THE PAGE, because the compositor is the only thing that
    // knows what is bound right now and a `hyprctl reload` between two visits
    // is exactly what a cached list gets wrong.
    //
    // `visible` and not Component.onCompleted: the settings window builds
    // every page at startup and keeps them all alive, so onCompleted fires for
    // a page nobody is looking at. It is also enough on its own here -- a page
    // is built with index -1, so `visible` starts false whichever page the
    // window opens on, and the first time this one is selected is a real
    // false-to-true change that this handler sees.
    onVisibleChanged: {
        if (root.visible)
            reader.running = true;
    }

    Process {
        id: reader

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn("KeybindsPage: could not parse hyprctl binds --", e.message);
                    return;
                }

                const list = [];

                for (const item of parsed) {
                    const description = (item.description ?? "").trim();
                    // has_description and a non-empty string, because hyprctl
                    // reports the flag and the text separately and a bind can
                    // carry an empty one.
                    const described = !!item.has_description && description !== "";
                    const colon = description.indexOf(": ");
                    // A bind written by keycode has no keysym for hyprctl to
                    // report, and an empty chip reads as a row that failed to
                    // load rather than as a key nobody named.
                    const key = (item.key ?? "") !== "" ? root.keyName(item.key)
                        : item.keycode ? `code ${item.keycode}` : "?";
                    const keys = root.modifiers(item.modmask).concat([key]);

                    list.push({
                        keys: keys,
                        // "Category: what it does" is the form hyprland.lua
                        // writes and the cheatsheet reads; a description
                        // without a colon is kept whole under "Other" rather
                        // than being cut at a separator it does not have.
                        category: !described ? "Undescribed"
                            : colon < 0 ? "Other" : description.slice(0, colon),
                        text: !described ? ""
                            : colon < 0 ? description : description.slice(colon + 2),
                        described: described,
                        submap: item.submap ?? "",
                        nonConsuming: !!item.non_consuming,
                        id: root.bindId(item),
                        // Matched against BOTH spellings of the key: the chip
                        // says "Esc" and the config says ESCAPE, and someone
                        // hunting a bind will type either. The description
                        // keeps its category prefix here so "shell" finds the
                        // whole group.
                        haystack: `${keys.join(" ")} ${item.key ?? ""} ${description}`.toLowerCase()
                    });
                }

                root.entries = list;
            }
        }
    }
}
