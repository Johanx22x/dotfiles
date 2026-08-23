// How the desktop looks: how solid its surfaces are, what it is set in, how
// its windows are spaced and what the pointer looks like.
//
// EVERY SETTING ON THIS PAGE REACHES PAST THE SHELL, which is why they are
// here together rather than filed under the bar or the window. Each is a file
// under ~/.local/state that a script writes and several programs read; the
// shell is only the first of those readers. See Config.qml for the shape and
// bin/desktop-opacity for the sibling that started it.
//
// Nothing here is a Theme constant, and the line between the two is the one
// Config.qml's header draws: Theme.qml is a design system whose values are
// decisions with reasons written beside them, and this page holds the ones
// where there is no right answer -- or, in the case of the gaps and the
// rounding, the ones the shell does not draw at all.

import Quickshell.Io
import QtQuick
import qs
import qs.components
import qs.modules.settings

SettingsPage {
    id: root

    title: "Appearance"
    glyph: Icons.palette
    keywords: ["opacity", "transparency", "glass", "font", "type", "size",
        "gaps", "spacing", "rounding", "corners", "border", "cursor",
        "pointer", "mouse pointer", "colour", "color", "scheme", "palette",
        "accent", "theme", "tokyo night", "catppuccin", "gruvbox"]

    // The installed cursor themes, asked for once when the page is
    // looked at. `desktop-tweak themes` lists the icon themes that have a
    // cursors/ directory -- an icon theme without one is an application
    // icon set, and offering it would produce a choice that does nothing.
    property var cursorThemes: []

    // The schemes the repository ships, in the same way and for the same
    // reason: they are files in `schemes/`, so the list is whatever is on disk
    // and a copy of it written here would be wrong the day one is added.
    // `{ name, label }` per entry -- the name is what the script takes, the
    // label is what a person reads.
    property var schemes: []

    onVisibleChanged: {
        if (visible && !themeQuery.running)
            themeQuery.running = true;
        if (visible && !schemeQuery.running)
            schemeQuery.running = true;
    }

    Process {
        id: themeQuery

        command: ["desktop-tweak", "themes"]

        stdout: StdioCollector {
            onStreamFinished: root.cursorThemes =
                (text || "").split("\n").filter(line => line.trim() !== "")
        }
    }

    Process {
        id: schemeQuery

        command: ["desktop-scheme", "list"]

        stdout: StdioCollector {
            // NAME<TAB>Label. Split on the FIRST tab only, the same rule
            // Config.qml's readers of these stores follow -- a label is free
            // text and nothing stops one carrying another.
            onStreamFinished: root.schemes = (text || "").split("\n")
                .filter(line => line.trim() !== "")
                .map(line => {
                    const at = line.indexOf("\t");
                    return at < 0
                        ? ({ name: line.trim(), label: line.trim() })
                        : ({ name: line.slice(0, at), label: line.slice(at + 1).trim() });
                })
        }
    }

    // ---------------- Colour ----------------
    //
    // FIRST ON THE PAGE because it is the largest thing on it: everything
    // below moves a number, and this decides what the desktop is made of.
    //
    // TWO CONTROLS AND THEY ARE NOT THE SAME QUESTION. The scheme is the BASE
    // -- surfaces, text, the sixteen ANSI slots every terminal in the session
    // inherits. The accent source is where the seventeen Material 3 roles come
    // from. Setting only the first is what this desktop did until now, and it
    // is why a scheme whose base already looked familiar seemed to do nothing:
    // its accent was on disk and nothing read it.
    SettingsSection {
        width: parent.width
        glyph: Icons.palette
        title: "Colour"

        // A LIST AND NOT A ChoiceRow, which every other choice on this page is.
        //
        // ChoiceRow puts its own ceiling at about four options (see the note at
        // the top of it), and the cursor theme picker was deleted from this
        // very page for walking past it -- at a pack's worth of themes the
        // segments were dots. The set here is OPEN in exactly the same way: a
        // scheme is a JSON file dropped into `schemes/`, the list is read from
        // `desktop-scheme list` rather than written down, and the release this
        // sits on already took it from one to three. A control that cannot grow
        // past four is the wrong shape for a set whose size is a directory
        // listing.
        //
        // The trade accepted is vertical space and one page holding two shapes
        // of picker. The font row below stays segments because ITS set is
        // closed and always three: the Nerd Font variants, and nothing else can
        // ever be offered there without filling the shell with tofu.
        Repeater {
            model: root.schemes

            SchemeRow {
                required property var modelData

                label: modelData.label
                // The name is what `desktop-scheme <name>` takes in a terminal,
                // so showing it is the difference between a settings window and
                // a settings window you can act on somewhere else.
                detail: modelData.name
                picked: Config.scheme === modelData.name
                onChosen: Config.setScheme(modelData.name)
            }
        }

        ChoiceRow {
            glyph: Icons.tune
            label: "Accent from"
            options: [
                { label: "Wallpaper", value: "wallpaper" },
                { label: "Scheme", value: "scheme" },
                { label: "Custom", value: "hex" }
            ]
            value: Config.accentSource
            // ONE CALL AND NOT TWO ASSIGNMENTS. Config cannot take two property
            // writes in one synchronous turn -- see the note above `saveTimer`
            // in Config.qml -- so the source and the colour move together
            // through one setter. An empty seed here means "the one already
            // stored", which is what the script does with a bare `accent hex`.
            onChosen: value => Config.setAccent(value, "")

            hint: "Wallpaper is how this desktop has always worked. Scheme "
                + "uses the accent the scheme was written with — that is what "
                + "makes one look like itself rather than like the picture "
                + "behind it."
        }

        // ONLY WHEN IT IS THE ANSWER. A colour field standing next to a
        // wallpaper-driven accent is a control that changes nothing, which is
        // the same fault as a segment nobody can hit.
        SeedRow {
            visible: Config.accentSource === "hex"

            label: "Accent colour"
            stored: Config.accentSeed
            onCommitted: value => Config.setAccent("hex", value)
        }

        InfoRow {
            visible: Config.accentSource !== "wallpaper"

            glyph: Icons.image
            label: "The wallpaper still sets itself"
            description: "Only the accent stops following it. The picture, the "
                + "rotation and the pointer are unchanged — and the base "
                + "palette comes from the scheme either way."
        }
    }

    SettingsSection {
        width: parent.width
        title: "Transparency"

        StepperRow {
            glyph: Icons.display
            label: "Desktop opacity"
            // Stored as a fraction, shown as percent: see the note on opacity
            // in Config.qml.
            value: Math.round(Config.opacity * 100)
            // The floor is legibility and not taste: below 40% small text
            // over a bright wallpaper stops being readable however much blur
            // sits behind it. The script enforces the same pair.
            from: 40
            to: 100
            // Fives, not ones. Below about 5% the change is not visible on a
            // surface this size, so single steps would mostly be clicks that
            // do nothing on screen.
            step: 5
            suffix: "%"
            onMoved: value => Config.setOpacity(value / 100)

            // Deliberately NOT a list of app names. The first version of this
            // named the three it knew about, which is a note that goes stale
            // the moment the script learns a fourth -- and a settings window
            // is the last place that should be telling you something that is
            // no longer true.
            hint: "Applies to most surfaces immediately. "
                + "Some apps only read it at startup and will not "
                + "follow until they are restarted."
        }
    }

    SettingsSection {
        width: parent.width
        title: "Windows"

        // THE COMPOSITOR'S, NOT THE SHELL'S, which is why it sits in its own
        // section rather than under Transparency: it is drawn around every
        // window on the machine, and this window is only the place that asks
        // for it. It applies the moment the number changes, to windows already
        // open as well as new ones -- unlike the opacity above, which new
        // windows pick up and old ones do not.
        //
        // WHAT IT MOVES IS NOT THE SAME EDGE ON BOTH FLAVORS, and the name on
        // the row is the honest one for either. Hyprland has one border, drawn
        // outside the window's own area. niri has two -- a border that takes
        // space INSIDE the layout and a focus ring drawn outside -- so this
        // moves the ring, which is the one that behaves like Hyprland's.
        // Zero turns it off rather than drawing an edge nobody can see.
        StepperRow {
            glyph: Icons.windowTiles
            label: "Window border"
            value: Config.borderSize
            from: 0
            to: 6
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("border", value)

            hint: "Zero removes it entirely. The colour comes from the "
                + "wallpaper and is not set here."
        }

        // TWO GAPS AND NOT ONE, because they are genuinely different
        // measurements and setting them together is the thing that looks
        // wrong: the space between two windows is counted twice -- each of
        // them contributes gaps_in -- while the space to the edge of the
        // screen is counted once. Equal numbers give a border round the
        // desktop that is half the width of the seams inside it.
        StepperRow {
            glyph: Icons.gaps
            label: "Gap between windows"
            value: Config.gapsIn
            from: 0
            to: 40
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("gaps-in", value)

            hint: "Counted on both sides of a seam, so two tiled windows sit "
                + "twice this far apart. On a compositor with a single gap "
                + "value this is that gap."
        }

        StepperRow {
            glyph: Icons.gaps
            label: "Gap to the screen edge"
            value: Config.gapsOut
            from: 0
            to: 80
            step: 2
            suffix: " px"
            onMoved: value => Config.setTweak("gaps-out", value)

            hint: "The margin the tiled area leaves around itself. This is "
                + "also what the bar sits in, so taking it to zero puts "
                + "windows under the bar rather than beside it. Below the gap "
                + "between windows it stops shrinking: that gap is already "
                + "there."
        }

        StepperRow {
            glyph: Icons.rounding
            label: "Corner rounding"
            value: Config.rounding
            from: 0
            to: 30
            step: 1
            suffix: " px"
            onMoved: value => Config.setTweak("rounding", value)

            hint: "The compositor's own corners, on every window. The shell's "
                + "surfaces have their own radius and do not follow this — "
                + "see the note above `rounding` in hyprland.lua about why "
                + "the two are set apart from each other."
        }
    }

    // ---------------- Pointer ----------------
    //
    // ITS OWN SECTION AND NOT PART OF "Windows", because it is the one thing
    // on this page that is not drawn by the compositor at all. The size has
    // to be told to three different parties -- the compositor for the session,
    // the environment for anything started afterwards, and GTK through its own
    // settings -- which is what the `desktop-tweak` script exists to keep in
    // step. See its header: how many of the three need telling separately is
    // itself a difference between the two flavors.
    SettingsSection {
        width: parent.width
        glyph: Icons.cursor
        title: "Pointer"

        StepperRow {
            glyph: Icons.cursor
            label: "Cursor size"
            value: Config.cursorSize
            from: 16
            to: 48
            step: 4
            suffix: " px"
            onMoved: value => Config.setTweak("cursor-size", value)

            hint: "Applies to windows opened from now on. Ones already up "
                + "keep the size they started with — the pointer is chosen "
                + "by each client, not painted over the screen."
        }

        // FOLLOWS THE WALLPAPER UNLESS TOLD NOT TO. `cursor-match` runs at
        // the end of every wallpaper change and hands `cursor-theme` whichever
        // installed theme sits closest to the new accent, so the pointer comes
        // from the same palette as everything else on screen. It measures in
        // CIELAB rather than by hue, which is why a wallpaper that lands
        // between two blues does not pick the wrong one.
        //
        // NO PICKER BESIDE IT ANY MORE. There was one, and it was a ChoiceRow
        // -- segments, sized for the three or four options every other choice
        // on this page has. This machine installs a pack of them, and at that
        // count the segments are dots: a control you cannot read and cannot
        // aim at. The pointer is chosen by the wallpaper, so the row was
        // answering a question nobody was asking often enough to pay for it.
        // `desktop-tweak set cursor-theme` still picks one by hand, and still
        // turns the matching off by doing so.
        //
        // Gated on the theme count all the same: with nothing to choose
        // between, matching has no answer to give and the switch would be a
        // control over an empty set.
        ToggleRow {
            visible: root.cursorThemes.length > 1

            glyph: Icons.image
            label: "Match the wallpaper"
            checked: Config.cursorAuto
            onToggled: value => Config.setTweak("cursor-auto", value ? 1 : 0)
        }

    }

    SettingsSection {
        width: parent.width
        title: "Type"

        StepperRow {
            glyph: Icons.textSize
            label: "Interface size"
            value: Config.fontSize
            from: 8
            to: 16
            step: 1
            suffix: " pt"
            onMoved: value => Config.setFont(value, Config.fontFamily)

            hint: "Points, the same unit the terminal measures in — the two "
                + "move together. Icons and the logo scale with it."
        }

        // THE LIST IS SHORT ON PURPOSE AND IT IS NOT A TASTE DECISION. Every
        // icon in this shell is a Nerd Font codepoint drawn as text in
        // Theme.fontFamily. Offer a family without the glyph set and the bar,
        // the island and this window fill with tofu boxes -- including the
        // glyph on the button that would let you change it back.
        //
        // What is left is still a real choice: the terminal-shaped default,
        // the strictly monospaced variant, and the proportional one, which is
        // the interesting one for a window that is mostly prose.
        ChoiceRow {
            glyph: Icons.tune
            label: "Interface font"
            options: [
                { label: "Default", value: "JetBrainsMono Nerd Font" },
                { label: "Mono", value: "JetBrainsMono Nerd Font Mono" },
                { label: "Propo", value: "JetBrainsMono Nerd Font Propo" }
            ]
            value: Config.fontFamily
            onChosen: value => Config.setFont(Config.fontSize, value)

            hint: "Only Nerd Font variants are offered: every icon in this "
                + "shell is a glyph from this font, and a family without them "
                + "would leave empty boxes everywhere."
        }
    }

    // ---------------- One scheme, offered ----------------
    //
    // AN INLINE COMPONENT AND NOT A FILE IN components/, the same call the
    // recording page makes about its own PickRow: it is used once, on this
    // page, and the two are near enough alike that sharing them would mean a
    // component that knows about both PipeWire nodes and colour schemes. If a
    // third list of this shape ever appears, that is the moment to lift it out
    // -- not before.
    component SchemeRow: Rectangle {
        id: pick

        property string label: ""
        // The name the script takes. Muted, under the label.
        property string detail: ""
        property bool picked: false

        signal chosen

        width: parent ? parent.width : 320
        implicitHeight: Math.max(32, column.implicitHeight + 12)

        radius: Theme.groupRadius
        color: pickMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            id: pickGlyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.top: column.top
            anchors.topMargin: 1

            text: Icons.palette
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // The accent marks the one in use and nothing else, which is what
            // every other list in this window does.
            color: pick.picked ? Theme.primary : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Column {
            id: column

            anchors.left: pickGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: mark.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: pick.label
                elide: Text.ElideRight

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: pick.picked ? Font.Bold : Theme.fontWeight
                color: pick.picked ? Theme.primary : Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                width: parent.width
                visible: pick.detail !== ""

                text: pick.detail
                elide: Text.ElideRight

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Text {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            text: pick.picked ? "in use" : pickMouse.containsMouse ? "use" : ""
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        MouseArea {
            id: pickMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pick.chosen()
        }
    }

    // ---------------- A colour, typed ----------------
    //
    // The same bare TextInput in a pill the recording page's PathRow is, and
    // for the reason it gives: nothing in this shell imports QtQuick.Controls,
    // and one widget that did would arrive with its own palette and metrics.
    //
    // COMMITTED ON ENTER OR ON LEAVING THE FIELD, never per keystroke. Every
    // write here ends in a full palette re-render, and a colour committed
    // letter by letter would be six of them for `#7aa2f7`.
    //
    // THE SWATCH IS THE GLYPH. It sits where every other row on this page puts
    // an icon, and it is the only thing in this window that shows a colour
    // rather than being painted in one -- which is what a field of six hex
    // digits needs beside it to be readable at all. It follows what is being
    // typed rather than what is stored, so an unfinished value simply keeps
    // the last colour that parsed.
    component SeedRow: Item {
        id: seed

        property string label: ""
        // What the script has. Empty means nobody has ever picked one.
        property string stored: ""

        signal committed(string value)

        // The text being edited. It follows `stored` until somebody types,
        // which breaks the binding -- so onStoredChanged puts it back, and a
        // colour set from a terminal shows up here instead of leaving the
        // field on a value nothing uses.
        property string draft: seed.stored

        onStoredChanged: seed.draft = seed.stored

        // `#rrggbb`, and the `#` is optional exactly as it is on the command
        // line: it is what every colour picker copies with, and typing it is
        // the thing people forget. Empty is legal and means "leave it alone",
        // which is what an untouched field has to mean.
        readonly property string resolved: {
            const text = seed.draft.trim().replace(/^#/, "");
            return /^[0-9a-fA-F]{6}$/.test(text) ? `#${text.toLowerCase()}` : "";
        }

        readonly property bool valid: seed.draft.trim() === "" || seed.resolved !== ""

        function commit(): void {
            if (seed.resolved !== "" && seed.resolved !== seed.stored)
                seed.committed(seed.resolved);
        }

        width: parent ? parent.width : implicitWidth
        implicitWidth: 320
        implicitHeight: Theme.groupHeight + 30

        Row {
            id: labelRow

            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            spacing: Theme.itemSpacing

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter

                width: Theme.iconSize
                height: Theme.iconSize
                radius: width / 2

                color: seed.resolved !== "" ? seed.resolved : Theme.surfaceContainerHighest
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: seed.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Rectangle {
            anchors.top: labelRow.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.groupPadding
            anchors.rightMargin: Theme.groupPadding

            height: 28
            radius: height / 2

            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: !seed.valid ? Theme.critical
                : field.activeFocus ? Theme.primary : Theme.outlineVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.animDuration }
            }

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                text: seed.draft
                onTextEdited: seed.draft = text

                // Six hex digits are not a sentence: an autocapitalised first
                // letter is a colour that will not parse.
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurface
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                selectByMouse: true

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                onAccepted: seed.commit()

                // LEAVING THE FIELD COMMITS IT: this window has no Save button
                // and nothing else on this page has one either.
                onActiveFocusChanged: {
                    if (!field.activeFocus)
                        seed.commit();
                }

                // ESCAPE HAS TO BE SWALLOWED. The settings window's FocusScope
                // closes the whole window on Escape, so without accepting the
                // event, abandoning an edit would put the window away instead
                // of the edit.
                Keys.onEscapePressed: event => {
                    seed.draft = seed.stored;
                    event.accepted = true;
                }

                // TextInput has no placeholderText -- that belongs to
                // TextField, which is Controls. Drawn underneath instead.
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    visible: seed.draft === ""
                    text: "#7aa2f7"
                    width: parent.width

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    color: Theme.outline

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding + 12

            visible: !seed.valid
            text: "Six hex digits, with or without the #"
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            color: Theme.critical

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
