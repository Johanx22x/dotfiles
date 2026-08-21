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
        "keyboard", "bind", "chord", "conflict", "hyprland", "niri"
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
    // starts at the same x, the same as the cheatsheet's rows. What the gutter
    // buys is set out over KeyChips below and none of it changes here: the key
    // chip is the one nearest its description, the modifiers trail off to the
    // left, and "S" sits at the same x in "SUPER S" and in "SUPER CTRL S".
    // That only works while every row on the page agrees on ONE number, which
    // is why this is a single property and not a per-row width.
    //
    // A FUNCTION OF THE CHORDS AND NOT A NUMBER WRITTEN DOWN ONCE. It was a
    // flat 150, measured against the widest chord that existed the day it was
    // measured -- SUPER + SHIFT + Enter, three chips. The set has grown four-
    // chip chords since, SUPER + CTRL + Left and CTRL + SHIFT + Right among
    // them, and the number did not follow. A chord wider than its gutter does
    // not spill to the right the way a too-narrow column usually does: the Row
    // is laid out RightToLeft from the gutter's right edge, so the extra chips
    // hang off the LEFT edge of the card, which is what this fixes.
    //
    // ADDED UP FROM THE TEXT, NOT COLLECTED FROM THE RENDERED ROWS. The other
    // shape is the one the cheatsheet uses -- each row reports how wide it came
    // out and the sheet keeps the largest -- and a running maximum can only
    // ever grow: it is correct the first time and then holds whatever the
    // widest thing it ever saw was, so it cannot come back down when the type
    // size does. On this page it would also be incomplete, because the rows
    // that would report are the FILTERED ones while the conflict list above the
    // filter is drawn in the same gutter. Adding the chips up from the chord
    // itself has neither problem: it is an ordinary binding on the binds and on
    // the font, so it recomputes in both directions and does not care which
    // rows happen to exist at the moment it runs.
    //
    // OVER EVERY BIND AND NOT OVER THE FILTERED ONES, deliberately, and the
    // conflicts are the half that settles it -- they are never filtered, so a
    // gutter sized to the search results would be too narrow for them. The
    // other half is that a gutter recomputed per keystroke would slide the
    // whole list sideways while somebody is reading it. The price is a few
    // pixels of slack when a search leaves only short chords on screen.
    readonly property int keyGutter: {
        // THE FONT IS NAMED HERE and not only inside chipMetrics below, and it
        // is the one line of this that is not obvious. A binding re-runs when
        // a property it READ changes, not when a property some function it
        // CALLED read changes -- and advanceWidth() is a function call, so
        // nothing in the loop below would ever give this a reason to run
        // again. Measured: with the type size taken from 11pt to 16pt the
        // chips grew and the gutter did not move, which puts the chords back
        // over the edge at exactly the size somebody picked because the text
        // was too small to read.
        //
        // chipMetrics' OWN font and not Theme's, though they hold the same
        // value: both this and chipMetrics.font read Theme.fontSize, and
        // which of the two updates first is not something to rely on. Read off
        // chipMetrics, the answer is always measured with the font
        // advanceWidth() is about to use.
        //
        // An unresolved font measures as nothing, which is a real state -- this
        // runs before Config has read the size off disk -- so it gives the
        // floor rather than a gutter of zero.
        if (chipMetrics.font.family === "" || chipMetrics.font.pointSize <= 0)
            return root.keyGutterFloor;

        let widest = 0;

        for (const entry of root.entries) {
            if (entry.keys.length === 0)
                continue;

            let chord = root.chipSpacing * (entry.keys.length - 1);
            for (const key of entry.keys)
                chord += chipMetrics.advanceWidth(key) + root.chipPadding;

            widest = Math.max(widest, chord);
        }

        // ROUNDED UP ONCE, AT THE END, and not per chip. A chip is as wide as
        // its label plus the padding and a label is a fractional number of
        // pixels; rounding each one up first would add up to a gutter a couple
        // of pixels wider than the row it is measuring, which is not wrong on
        // screen but makes the model and the thing it models disagree -- and a
        // model that is allowed to disagree cannot be used to catch a drift.
        return Math.max(root.keyGutterFloor, Math.ceil(widest));
    }

    // A FLOOR AND NOT A DEFAULT. Every chord this machine binds today is wider
    // than nothing, so the floor is invisible in practice -- what it is for is
    // the two moments the list is short or empty: before the compositor has
    // answered, and on a sheet of two-chip chords that would otherwise close
    // up and read as a different page. 150 is the number the gutter was fixed
    // at before this, so a narrow list looks exactly like it always did.
    readonly property int keyGutterFloor: 150

    // The chip's own geometry, HERE AND NOT AS LITERALS IN KeyChips, because
    // the gutter above is an arithmetic model of a chip: a model that does not
    // add up the same numbers the chip is drawn with is a model that drifts,
    // and it drifts silently -- the chords would simply start hanging off the
    // edge again, which is the bug this is fixing.
    //
    // HANDED TO KeyChips AS REQUIRED PROPERTIES rather than read out of this
    // scope by it, and that is measured rather than stylistic. An inline
    // component does NOT reliably see the ids of the document it is declared
    // in: `root.chipPadding` written inside KeyChips resolves while the chips
    // are built from inside this file and raises "ReferenceError: root is not
    // defined" the moment one is built from anywhere else, at runtime, as a
    // warning rather than an error. Required properties are checked when the
    // page is compiled, so a call site that forgets one cannot be shipped.
    readonly property int chipPadding: 14
    readonly property int chipSpacing: 5

    // The chip label's font, so advanceWidth() above measures the text with
    // the face it will actually be drawn in. It has to be kept in step with
    // the Text inside KeyChips by hand -- FontMetrics takes a font, not a
    // component -- and the check that they agree is the one below: a rendered
    // KeyChips reports implicitWidth, this computes the same number, and the
    // commit that added it measured the two against each other over the whole
    // bind set.
    FontMetrics {
        id: chipMetrics

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1.5
        font.weight: Theme.fontWeight
    }

    // WHAT A ROW WITH NOTHING TO SAY FOR ITSELF SAYS, and the point of it is
    // the second half: where to go and write a description. It read "no
    // description in hyprland.lua" unconditionally, which on this machine is
    // twenty-eight rows telling a niri session to edit a Hyprland config that
    // is not there. The file comes from the compositor facade now -- see
    // bindsFile in compositor/CompositorBackend.qml -- and the sentence drops
    // the words rather than guessing when there is nothing to ask.
    //
    // THE NAME AND NOT THE PATH, here only: this is one line among eighty in a
    // list that elides, and the whole path is in the Editing section at the
    // foot of the page, which is where somebody who has decided to go and edit
    // it is looking.
    readonly property string undescribed: {
        const file = Compositor.bindsFile;
        return file === ""
            ? "no description"
            : `no description in ${file.split("/").pop()}`;
    }

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
    // THE WHOLE CONFLICT FEATURE IS THIS COMPARISON, so it is worth being
    // exact about what is in it and what is deliberately out. It is the
    // `chordId` built on every entry below, and the conflict list is nothing
    // but the entries that share one.
    //
    // IN, because each one changes WHICH EVENT reaches the bind:
    //   submap    -- a submap is a mode. Two binds in different submaps are
    //                never live at the same moment, so they cannot collide.
    //                The empty submap is the root one and is a value like any
    //                other -- and the only one niri has.
    //   the chord -- the modifiers and the key together, as the compositor
    //                facade spells them out, lowercased: a keysym names a
    //                physical key, so `SUPER, S` and `SUPER, s` are one bind
    //                written twice. The modifiers are compared for equality
    //                and not for overlap, which is how the compositor matches
    //                them: SUPER and SUPER + SHIFT are two different
    //                keystrokes and not a near miss.
    //
    // OUT, because they change what a bind DOES once it has already been
    // reached, which is not the question:
    //   locked        -- only says the bind still works over a lock screen. In
    //                    an unlocked session a locked and an unlocked bind on
    //                    the same chord both fire, so this is a conflict and
    //                    leaving the field out is what lets it be seen.
    //   non_consuming -- says the key ALSO goes on to the window. Two binds
    //                    still both fire; it is why a stack can be amber
    //                    rather than red, not why it is a stack.
    //   repeat, mouse -- how it is held or which device pressed it, both
    //                    already implied by the key.
    //
    // THREE BLIND SPOTS, and naming them is part of being able to trust the
    // green line this page prints when it finds nothing:
    //
    //   PRESS AGAINST RELEASE. A bind on the way down and a bind on the way up
    //   of the same chord are a pair and not a clash, and this cannot tell
    //   them apart: the facade carries the chord, the submap and the
    //   description, and not the release flag -- nor the keycode or the raw
    //   modmask that the fields above would want. Push-to-talk is exactly that
    //   shape, so with `ptt=1` under Hyprland its key is listed here as a
    //   conflict. Seeing that pair is the price of seeing every real one;
    //   widening the facade for one line of this page is not.
    //
    //   MODIFIER ORDER. The facade hands the modifiers over already spelled
    //   out -- in a fixed order from Hyprland's modmask, in the order the file
    //   happens to write them from niri's config. `Mod+Shift+E` and
    //   `Shift+Mod+E` in a niri config are one chord and land in two buckets.
    //
    //   catch_all. A bind that swallows every key in its submap collides with
    //   everything there without sharing a key with any of it. There is none
    //   here; when there is, this will not see it.

    // ---------------- The list ----------------

    // The order categories are shown in, and the same order the cheatsheet
    // uses -- both read the categories out of the descriptions in
    // hyprland.lua, so a different order in each would be two answers to one
    // question. A category not named here still appears, at the end, in the
    // order hyprctl reported it.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // One record per bind, in the order the compositor reported them. The two
    // bindings under it are derived from this and from nothing else.
    //
    // WHERE THE LIST COMES FROM. No command is run here: each compositor backend
    // produces the same shape from whatever source it has -- Hyprland's socket
    // on one flavor, the config file on the other -- and this page turns it into
    // rows. See compositor/CompositorBackend.qml.
    //
    // EVERY bind, described or not, unlike the cheatsheet: this page answers
    // "what is this chord doing", so the media keys belong here even though they
    // would be noise on a sheet of chords worth memorising.
    readonly property var entries: Compositor.binds.map(bind => ({
        keys: bind.keys.map(k => root.keyName(k)),
        category: bind.category,
        text: bind.description,
        described: bind.described,
        submap: bind.submap,
        nonConsuming: bind.nonConsuming,
        // A KEY THAT IS MEANT TO COLLIDE, which is the opposite of what a row
        // id usually is and why it is not called one: the conflict list below
        // buckets by it, so two binds that answer the same keystroke have to
        // land on the same string. It carried the entry's index until now,
        // which made every bucket a bucket of one and left `conflicts`
        // permanently empty. See the rule above for what is compared here.
        //
        // NUL as the separator, so a submap named after a chord cannot fake a
        // match across the field boundary.
        chordId: `${bind.submap}\u0000${bind.keys.join("+").toLowerCase()}`,
        search: `${bind.keys.join(" ")} ${bind.category} ${bind.description}`.toLowerCase()
    }))

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
            if (root.query !== "" && entry.search.indexOf(root.query) < 0)
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
            if (!buckets[entry.chordId]) {
                buckets[entry.chordId] = [];
                order.push(entry.chordId);
            }
            buckets[entry.chordId].push(entry);
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
    // FLUSH WITH THE RIGHT EDGE OF THE GUTTER, which is the whole trick: the
    // KEY is always the chip nearest its description, the modifiers trail off
    // to the left, and "S" sits at the same x in "SUPER S" and "SUPER CTRL S".
    // The key chip takes the accent and the modifiers stay muted -- the
    // modifier is the part you already know.
    //
    // AN ITEM HOLDING A RIGHT-ANCHORED ROW, and not a Row laid out
    // RightToLeft inside a width of its own, which is what this was. The two
    // draw exactly the same thing until the gutter CHANGES -- and the gutter
    // changes now that it follows the binds instead of being a constant.
    // Measured: a RightToLeft Row whose width goes from 150 to 227 leaves
    // every chip precisely where it was, on that turn and on the next one. A
    // positioner re-lays-out when its CONTENT changes and not when its own
    // width does, so the chips would stay pinned to the old right edge with
    // the new gutter open behind them. An anchor is re-evaluated, so the row
    // follows the edge it is held to.
    //
    // With the row sized to its own content the layout direction stops
    // mattering, so the chord is drawn in the order it arrives -- modifiers
    // first, key last -- and there is no reversed copy of the array to keep
    // in step with an `index === 0` test.
    component KeyChips: Item {
        id: chips

        required property var keys
        required property int gutterWidth

        // The chip geometry, from the page. See root.chipPadding for why these
        // arrive from the call site instead of being written here: the gutter
        // is computed by adding exactly these two numbers up, so the chip that
        // is drawn and the chip that is measured have to be the same chip.
        required property int chipPadding
        required property int chipSpacing

        // The gutter IS this item; the chips are what sits at the end of it.
        implicitWidth: chips.gutterWidth
        width: chips.gutterWidth
        implicitHeight: row.implicitHeight

        Row {
            id: row

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: chips.chipSpacing

            Repeater {
                model: chips.keys

                Rectangle {
                    id: chip

                    required property int index
                    required property string modelData

                    // The key is the LAST chip, the modifiers everything before
                    // it, which is the order the facade hands the chord over in.
                    readonly property bool isKey: chip.index === chips.keys.length - 1

                    implicitWidth: label.implicitWidth + chips.chipPadding
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
                        // Under the body text: a chip is a label on a key, not
                        // a sentence, and at the same size the chords compete
                        // with the descriptions instead of introducing them.
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
            // clips it.
            //
            // Vertically it says only how far into the row to bite -- 2px, so
            // the note reads as hanging off this row rather than floating
            // under it. WHICH SIDE is Tooltip's decision, and this call site
            // no longer has to know that it happens to sit near the top of a
            // page. It did know, once: the note here was placed below
            // unconditionally with the comment "it can hang below because
            // this row is near the top", which was true and was also exactly
            // the kind of local reasoning that broke the moment a row further
            // down wanted a note.
            Tooltip {
                text: "Same submap, same modifiers, same key. Whether a bind is "
                    + "locked or non-consuming is not part of it: those change what "
                    + "it does after it fires, not whether it fires. Press against "
                    + "release is not part of it either, because the compositor does "
                    + "not report it here — so a hold-to-talk key, which is bound on "
                    + "both, is listed."
                shown: ruleMouse.containsMouse

                x: Theme.groupPadding
                gap: -2
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
                    chipPadding: root.chipPadding
                    chipSpacing: root.chipSpacing
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
                                    chipPadding: root.chipPadding
                                    chipSpacing: root.chipSpacing
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
                                            return root.undescribed;
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

            // THE SAME BUG AS THE ROWS ABOVE, and fixing one without the other
            // would have left the page contradicting itself: eighty rows
            // pointing at config.kdl over a paragraph pointing at
            // hyprland.lua. The file comes from the same place they do.
            //
            // The reason it is a view and not an editor is the file's own
            // header argument rather than the Hyprland one that used to be
            // here. "Hyprland hands out every bind as a Lua callback number"
            // is true and is only true on Hyprland -- under niri the backend
            // reads the config itself and can see exactly what a bind runs, so
            // as a reason for this window not offering to edit them it is the
            // wrong reason on the machine it is being read on. What holds
            // either way is what the file IS.
            text: (Compositor.bindsFile === ""
                    ? "Binds are written in the compositor's own config, and that file "
                    : `Binds are written in ${Compositor.bindsFile}, and that file `)
                + "is where they are changed. This window reads them and never writes "
                + "them: the file is hand-written — prose about why each key sits "
                + "where it does, and loops that turn two lines into twenty binds — "
                + "and a window that generated it would produce a correct list of "
                + "binds while destroying the only record of why they are those binds."
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
    // ON EVERY TRIP TO THE PAGE, because what is bound right now is the
    // compositor's answer and not this window's: a `hyprctl reload`, or a save
    // to the niri config, between two visits is exactly what a cached list
    // gets wrong.
    //
    // `visible` and not Component.onCompleted: the settings window builds
    // every page at startup and keeps them all alive, so onCompleted fires for
    // a page nobody is looking at. It is also enough on its own here -- a page
    // is built with index -1, so `visible` starts false whichever page the
    // window opens on, and the first time this one is selected is a real
    // false-to-true change that this handler sees.
    onVisibleChanged: {
        if (root.visible)
            Compositor.refreshBinds();
    }
}
