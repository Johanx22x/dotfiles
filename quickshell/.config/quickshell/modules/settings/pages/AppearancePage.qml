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
        "theme", "tokyo night", "catppuccin", "gruvbox"]

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
    // ONE CONTROL, AND IT USED TO BE TWO. Beside this list there was an
    // "Accent from" row -- wallpaper, scheme, or a colour typed into a field
    // underneath -- and it is gone rather than hidden. The accent is the
    // wallpaper's contribution to the desktop, a blue picture giving a blue
    // desktop; the scheme is what the desktop is MADE of. Neither of the other
    // two sources was answering a question anybody had. What came out with it
    // is in bin/desktop-scheme, above `accent_args`.
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
                picked: Config.scheme === modelData.name

                // THE ROW THAT WAS CLICKED IS THE ROW THAT SAYS SO. A spinner
                // at the top of the section would be true and useless: it
                // cannot answer the only question there is while the desktop is
                // mid-change, which is whether it took the one that was pressed.
                applying: Config.schemeApplying === modelData.name

                // AND EVERY ROW GOES QUIET, not only that one. Applying ends in
                // `wallpaper-switch reapply` -- a full matugen render over
                // fourteen files and several applications signalled afterwards
                // -- so there is a second or more in which three clicks in a row
                // are three renders writing the same files, with the last to
                // FINISH winning rather than the last to be asked for.
                // Config.setScheme refuses the second one as well; this is what
                // makes the refusal visible instead of silent. `enabled` is
                // Item's own, so it reaches the MouseArea below it without
                // being passed: no hover highlight, no "use", no click.
                enabled: Config.schemeApplying === ""

                onChosen: Config.setScheme(modelData.name)
            }
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
        property bool picked: false
        // This row's scheme is the one being applied right now. NOT the
        // opposite of `picked` and not exclusive with it: `desktop-scheme`
        // writes its state file before it starts the render, so a row becomes
        // the one in use a moment before it stops being the one being applied.
        property bool applying: false

        signal chosen

        width: parent ? parent.width : 320
        implicitHeight: Math.max(32, schemeLabel.implicitHeight + 12)

        radius: Theme.groupRadius
        color: pickMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        // THE ROWS THAT ARE NOT HAPPENING STEP BACK, and the one that is stays
        // where it was. Disabling on its own is invisible until the pointer is
        // over a row and nothing lights up, which is feedback that arrives
        // after the click rather than before it.
        opacity: pick.enabled || pick.applying ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            id: pickGlyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

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

        // THE NAME, AND NOTHING UNDER IT. There was a second line here
        // carrying the scheme's identifier -- `tokyo-night` beneath `Tokyo
        // Night` -- and it was a filename shown to somebody choosing a colour.
        // The identifier has not gone anywhere: it is still what
        // `desktop-scheme <name>` takes in a terminal and schemes/README.md
        // still documents it. A settings window is not where it belongs.
        Text {
            id: schemeLabel

            anchors.left: pickGlyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: mark.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

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

        // WIDE ENOUGH FOR THE LONGEST OF THE WORDS, always, so the name beside
        // it is not re-elided at the instant of the click -- the same call
        // WallpaperPage.qml's "Change" chip makes and for the same reason: this
        // is right-anchored, so growing eats leftwards into the label.
        TextMetrics {
            id: markMetrics

            font: mark.font
            text: "Applying…"
        }

        Text {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            width: markMetrics.width
            horizontalAlignment: Text.AlignRight

            // APPLYING BEATS IN USE while both are true, because it is the one
            // about to stop being true. `use` is only the hover affordance, and
            // it disappears on its own: a disabled row takes no hover events.
            text: pick.applying ? markMetrics.text
                : pick.picked ? "in use"
                : pickMouse.containsMouse ? "use" : ""
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: pick.applying ? Theme.primary : Theme.outline

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
}
