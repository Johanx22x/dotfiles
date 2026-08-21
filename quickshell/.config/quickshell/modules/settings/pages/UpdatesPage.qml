// What ./install.sh check found, and the one button that catches this machine
// up on the half of it that needs no password.
//
// THE TABLE IS A REPORT AND NOT A SET OF INTENTIONS, which is the decision
// that shapes this page. The terminal menu has a box beside every unit,
// because a run there is a plan being made -- its own comment opens with "THE
// BOX AND THE WORK ARE NOT THE SAME QUESTION". Here the two questions are
// separated by being in different sections instead of by a note explaining
// them: the units are a reading of the machine, the packs below are the
// choices, and nothing in the first list is a control.
//
// The profile is still obeyed. A unit turned off in the terminal menu stays
// off here -- it is simply not something this window offers to turn off, and a
// row that reports a state is not the place to change what a machine wants.
//
// WHY THERE ARE TWO BUTTONS AND NOT ONE. The privilege rule lives in
// InstallerState and its long note is there; what shows up on this page is its
// consequence. Units that write into $HOME run here, in this session, as the
// person sitting at it. Units that install packages or change a login shell
// need a password, and a password needs somewhere to be typed -- so those open
// a terminal running the same command a person would have typed themselves.
// One button that did both would have to pick one of those two worlds, and
// either choice is a lie about half the list.
//
// WHAT THIS PAGE CANNOT DO, said on it rather than only here: a first install
// is still a terminal. A fresh clone has no desktop to draw this on. That is
// not the case anybody was complaining about -- the complaint was about the
// second time onward, and every time after that -- but a page offering to set
// a machine up would be promising something it cannot reach.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/installer"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Updates"
    glyph: Icons.update
    keywords: ["update", "updates", "install", "installer", "packages",
        "optional", "packs", "gaming", "apps", "neovim", "hardware",
        "symlinks", "stow", "drift", "check", "behind", "out of date",
        "profile", "sudo", "terminal"]

    // WHERE THIS PAGE LANDED IN THE RAIL, told to the singleton so the bar
    // widget can open it. The index is assigned by the window on the way past
    // and cannot be known before that -- pages that do not apply to this
    // machine are left out entirely, so the number moves with the compositor.
    // Nothing writes it down; this reports it.
    onIndexChanged: InstallerState.registerPage(root.index)

    // onScreen and not visible: `visible` stays true for the whole session
    // once this page is the selected one, window shut or not. See the long
    // note in SettingsPage.qml -- three pages recorded from the microphone for
    // hours because of that distinction.
    onOnScreenChanged: {
        if (root.onScreen)
            InstallerState.checkIfStale();
    }

    // ---------------- Vocabulary ----------------

    // The state word, in the colour the CLI's table gives it. It is the WORD
    // and not an icon on purpose: `missing` and `drift` are the engine's own
    // vocabulary, they appear in the check table, in the README and in this
    // repository's commit messages, and a page that renamed them into pictures
    // would be a fourth vocabulary for the same four answers.
    component StateChip: Rectangle {
        id: chip

        property string kind: ""

        readonly property color tone: {
            switch (chip.kind) {
            case "ok":      return Theme.primary;
            case "missing": return Theme.warning;
            case "drift":   return Theme.critical;
            default:        return Theme.textOnSurfaceVariant;
            }
        }

        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: 20
        radius: height / 2

        color: Qt.alpha(chip.tone, 0.16)
        border.width: 1
        border.color: Qt.alpha(chip.tone, 0.5)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Text {
            id: chipText

            anchors.centerIn: parent

            // "n/a" and not "na": the CLI prints a column, this prints a word
            // in a sentence, and the four letters of "na" read as an
            // abbreviation nobody expands the first time.
            text: chip.kind === "na" ? "n/a" : chip.kind
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            font.weight: Font.Bold
            color: chip.tone

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // One row of the check table: the state, the unit's own title, and the
    // note the unit wrote about itself. Shaped like an InfoRow because it is
    // one -- no hover, no cursor, nothing to click -- with the chip taking the
    // place the glyph would have had.
    component UnitRow: Item {
        id: unitRow

        required property var modelData

        width: parent ? parent.width : 320
        implicitHeight: Math.max(Theme.groupHeight, unitColumn.implicitHeight + 14)

        StateChip {
            id: rowChip

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.top: unitColumn.top
            anchors.topMargin: 2

            kind: unitRow.modelData.kind ?? ""
        }

        Column {
            id: unitColumn

            anchors.left: rowChip.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            spacing: 3

            Text {
                width: parent.width

                // The title and the id together, because they are for two
                // different readers of the same row: the title is what it is,
                // the id is what you type after `./install.sh apply` when you
                // want to do something about it.
                text: `${unitRow.modelData.title}  ·  ${unitRow.modelData.id}`
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                width: parent.width

                visible: text !== ""
                // The unit's own sentence, unedited. Nothing on this page
                // rewrites it: it was written by the code that found the
                // problem, which is the only thing that knows what it is.
                text: unitRow.modelData.note ?? ""
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }
    }

    // One package inside an opened pack. Deliberately small -- half the height
    // of a ToggleRow -- because a pack can hold ninety of these and a list of
    // ninety full rows is a page nobody scrolls to the end of.
    component PkgRow: Rectangle {
        id: pkgRow

        required property string group
        required property string name

        readonly property bool wanted: InstallerState.pkgWanted(pkgRow.group, pkgRow.name)

        width: parent ? parent.width : 320
        implicitHeight: 26
        radius: height / 2

        color: pkgMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: pkgRow.wanted ? Icons.checkboxOn : Icons.checkboxOff
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: pkgRow.wanted ? Theme.primary : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: pkgRow.name
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: pkgRow.wanted ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        MouseArea {
            id: pkgMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: InstallerState.setPkgWanted(pkgRow.group, pkgRow.name, !pkgRow.wanted)
        }
    }

    // ---------------- What the machine says ----------------

    SettingsSection {
        width: parent.width
        glyph: Icons.update
        title: "This machine"

        // The action belongs to the section and not to a row of its own: a
        // button filed among readings becomes a reading that answers to a
        // click, which is the thing InfoRow exists to prevent.
        actionText: InstallerState.checking ? "Checking…" : "Check again"
        actionGlyph: Icons.refresh
        onActionTriggered: InstallerState.check()

        InfoRow {
            glyph: Icons.update
            label: {
                if (!InstallerState.repoKnown)
                    return "No clone found";
                if (InstallerState.checkError !== "")
                    return "The check did not finish";
                if (!InstallerState.ready)
                    return "Not checked yet";
                if (InstallerState.outstanding === 0)
                    return "Everything applicable is in place";

                return InstallerState.outstanding === 1
                    ? "1 unit needs attention"
                    : `${InstallerState.outstanding} units need attention`;
            }

            description: {
                if (!InstallerState.repoKnown)
                    return "This shell was started from a path with no "
                        + "install.sh above it, so there is nothing here to "
                        + "drive. Everything else in this window still works.";

                if (InstallerState.checkError !== "")
                    return InstallerState.checkError;

                // The command, always, because it is the point: this page and
                // that line are the same act, and somebody who would rather
                // type it should be told what to type rather than left to
                // guess that this window has a CLI behind it.
                const when = InstallerState.checkedAt === 0
                    ? "It has not run yet in this session."
                    : `Last read at ${Qt.formatTime(new Date(InstallerState.checkedAt), "HH:mm:ss")}.`;

                return `${when} ./install.sh check says the same thing in a `
                    + "terminal, and takes about three seconds either way — "
                    + "which is why nothing here runs it on a timer.";
            }
        }
    }

    // ---------------- The table ----------------

    SettingsSection {
        width: parent.width
        glyph: Icons.packages
        title: "What the check found"

        Repeater {
            model: InstallerState.units

            UnitRow {
                width: parent.width
            }
        }

        // The empty state, which is also the first fifteen seconds of every
        // session: the check has not run yet and there is nothing to draw.
        Text {
            visible: !InstallerState.ready

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 6
            bottomPadding: 6

            text: InstallerState.repoKnown
                ? "Nothing read yet. The first check of a session runs a "
                  + "quarter of a minute in, so that it is not competing with "
                  + "the desktop coming up."
                : "There is nothing to read: no clone was found above this "
                  + "shell's own files."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Doing something about it ----------------

    SettingsSection {
        width: parent.width
        glyph: Icons.terminal
        title: "Bringing it up to date"

        InfoRow {
            glyph: Icons.update
            label: "Two halves, and only one of them belongs in this window"
            description: "The units that write into your home directory run "
                + "here, as you. The ones that install packages or change your "
                + "login shell need a password, so they open a terminal "
                + "running the same command — this shell never asks for one "
                + "and never runs anything as root."
        }

        ActionRow {
            glyph: Icons.update
            label: "Catch up on what needs no password"
            description: InstallerState.runnableNow.length === 0
                ? "Nothing outstanding on this side."
                : `./install.sh apply ${InstallerState.runnableNow.join(" ")}`

            actionText: InstallerState.applying ? "Running…" : "Apply"
            actionEnabled: !InstallerState.applying && InstallerState.runnableNow.length > 0
            onTriggered: InstallerState.applyHere()
        }

        ActionRow {
            glyph: Icons.terminal
            label: "Hand the rest to a terminal"
            description: InstallerState.runnableInTerminal.length === 0
                ? "Nothing outstanding needs a password."
                : `./install.sh apply ${InstallerState.runnableInTerminal.join(" ")}`

            actionText: "Open a terminal"
            actionGlyph: Icons.terminal
            actionEnabled: InstallerState.runnableInTerminal.length > 0
            onTriggered: InstallerState.handOff(InstallerState.runnableInTerminal)
        }

        // WHAT IT SAID, IN THE WINDOW THAT ASKED. A settings page that runs a
        // command and shows only whether it worked is a page somebody has to
        // leave in order to find out what happened -- and what happened is
        // often the whole answer: which package would not build, which file
        // was in the way.
        //
        // Capped and scrollable rather than allowed to push the rest of the
        // page off the bottom. A stow run over fifteen packages prints more
        // lines than this window is tall.
        ScrollList {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2

            // Height and not `visible`, which that component's own header
            // forbids in bold: hiding a Flickable hides its delegates, an
            // invisible child contributes nothing, and the list is then held
            // shut forever.
            height: InstallerState.log === "" ? 0 : Math.min(logText.implicitHeight + 12, 220)
            contentHeight: logText.implicitHeight + 12

            Text {
                id: logText

                width: parent.width

                text: InstallerState.log
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 3
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }
    }

    // ---------------- The packs ----------------

    SettingsSection {
        width: parent.width
        glyph: Icons.packages
        title: "Optional packs"

        InfoRow {
            glyph: Icons.packages
            label: "Opt in by the pack, or by the name"
            description: "Nothing in these lists is needed for the desktop to "
                + "work, which is the whole line between packages/required and "
                + "packages/optional. A pack is one box; opening one is for "
                + "the case no set of packs somebody else drew can cover — "
                + "\"gaming, but not Steam\"."
        }

        Repeater {
            model: InstallerState.groups

            // A pack, its switch, and the drill-down under it. The two
            // controls are deliberately separate targets: the row turns the
            // pack on, the line under it opens the list. One control doing
            // both would mean every glance inside a pack changed what this
            // machine wants.
            Column {
                id: pack

                required property var modelData

                property bool open: false

                width: parent.width
                spacing: 0

                // A gap under each pack, so that a closed one is a block and
                // not a run of three lines butting into the next pack's
                // switch. Padding on the Column rather than spacing between
                // its children: the summary and the drill-down line belong
                // tight against the switch they are about.
                bottomPadding: 8

                ToggleRow {
                    width: parent.width

                    glyph: Icons.packages
                    // "1 packages" is the kind of thing that makes a window
                    // look generated. `laptop` holds exactly one.
                    label: pack.modelData.packages.length === 1
                        ? `${pack.modelData.name} — 1 package`
                        : `${pack.modelData.name} — ${pack.modelData.packages.length} packages`
                    checked: InstallerState.groupWanted(pack.modelData.name)
                    onToggled: value => InstallerState.setGroupWanted(pack.modelData.name, value)
                }

                // The pack's own first line of its own file, which is where
                // its description belongs: one copy of that sentence, living
                // in the list it describes. See pkg_list_summary.
                Text {
                    x: Theme.groupPadding
                    width: parent.width - Theme.groupPadding * 2

                    visible: text !== ""
                    text: pack.modelData.summary ?? ""
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 2
                    color: Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                Item {
                    width: parent.width
                    implicitHeight: 28

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.groupPadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            text: pack.open ? Icons.chevronDown : Icons.chevronRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            color: drillMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            // The count is the reason to open it: a pack whose
                            // packages all agree with it needs no visit, and a
                            // pack that disagrees is exactly the one somebody
                            // wants to look at.
                            text: {
                                const chosen = InstallerState.pkgWantedCount(pack.modelData);
                                const total = pack.modelData.packages.length;

                                if (pack.open)
                                    return "Close";

                                return chosen === total ? "All of them — pick them one at a time"
                                    : chosen === 0 ? "None of them — pick them one at a time"
                                    : `${chosen} of ${total} — pick them one at a time`;
                            }
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 2
                            color: drillMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }
                    }

                    MouseArea {
                        id: drillMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pack.open = !pack.open
                    }
                }

                // Capped, because `apps` and `gaming` are longer than this
                // window is tall. ScrollList swallows the wheel while it can
                // still move, so scrolling a pack does not drag the page out
                // from under it.
                ScrollList {
                    x: Theme.groupPadding
                    width: parent.width - Theme.groupPadding * 2

                    height: pack.open ? Math.min(pkgColumn.implicitHeight, 210) : 0
                    contentHeight: pkgColumn.implicitHeight

                    Column {
                        id: pkgColumn

                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: pack.open ? pack.modelData.packages : []

                            PkgRow {
                                required property string modelData

                                width: parent.width
                                group: pack.modelData.name
                                name: modelData
                            }
                        }
                    }
                }
            }
        }

        // THE ONE COMBINATION THAT LOOKS LIKE A BUG AND IS NOT. The packs are
        // installed by the `optional` unit, and a unit can be turned off in
        // the terminal menu -- at which point ticking a pack here writes a
        // preference that `update` will read and then skip. Nothing else on
        // this page would say so.
        Text {
            visible: !InstallerState.unitWanted("optional")

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 6
            bottomPadding: 6

            text: "The `optional` unit is switched off in the profile, so "
                + "nothing here will be installed until it is switched back "
                + "on — run ./install.sh and tick it."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- What this page does not do ----------------

    SettingsSection {
        width: parent.width
        glyph: Icons.info
        title: "Limits"

        InfoRow {
            glyph: Icons.terminal
            label: "A first install is still a terminal"
            description: "A fresh clone has no desktop to draw this on. Clone "
                + "the repo, run ./install.sh, and every time after that is "
                + "what this page is for."
        }

        InfoRow {
            glyph: Icons.info
            label: "The etc unit reports and never writes"
            description: "system/ is diffed against /etc and the differences "
                + "are printed with the command that would close them. Half "
                + "those files describe one machine and pacman owns the rest, "
                + "so nothing here offers to apply it."
        }

        InfoRow {
            glyph: Icons.update
            label: "The profile is the same file the terminal reads"
            description: "Ticking a pack here writes " + Config.stateDir
                + "/dotfiles-profile, which is what ./install.sh update reads. "
                + "The window and the terminal are two ways of saying the same "
                + "thing, not two places to say it."
        }
    }
}
