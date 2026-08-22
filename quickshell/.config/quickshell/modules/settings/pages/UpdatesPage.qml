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
// WHAT THIS PAGE CANNOT DO, and why it no longer says so on itself. A first
// install is still a terminal: a fresh clone has no desktop to draw this on.
// That is not the case anybody was complaining about -- the complaint was
// about the second time onward, and every time after that -- but a page
// offering to set a machine up would be promising something it cannot reach.
// That used to be a "Limits" section at the bottom, three paragraphs of it,
// and it was cut: nobody who is looking at this page needs to be told what a
// page they cannot see cannot do. The README states it where somebody with no
// desktop yet can actually read it, which is a terminal.
//
// THE PROSE THAT WAS ON THIS PAGE IS NOW IN THESE COMMENTS, which is the other
// half of the same cut. Every paragraph below explaining a boundary -- the
// privilege split, what a pack is, what the profile is -- was once drawn on
// screen. The reasoning is worth keeping and the wall of text was not, so it
// moved to where the person who needs it is already reading.

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
        if (root.onScreen) {
            InstallerState.checkIfStale();
            InstallerState.measureOriginIfStale();
        }
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

                // THE TITLE ALONE. The row used to carry the unit's id after
                // it -- `GPU driver · gpu`, `User services · services-user` --
                // on the argument that the id is what you type after
                // `./install.sh apply`, so it had to be somewhere.
                //
                // It did not have to be here. Printing it on every row made a
                // reading table carry a second column of command arguments
                // for a reader who, by definition, has already left this page
                // for a terminal; the dot and the word after it were on
                // fifteen rows to serve the one visit in twenty where
                // somebody wanted them. A first pass suppressed only the ids
                // that repeated their own title, which fixed `Seeds · seeds`
                // and left every other row still trailing a word that the
                // title had already said in full.
                //
                // WHERE THE ID STILL SURFACES, and it is not a quieter copy of
                // this: the two hand-off rows below print the exact command
                // they are about to run, ids and all, and that is the moment
                // somebody actually needs to read one. The id belongs next to
                // the command, not next to the state.
                text: unitRow.modelData.title ?? ""
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

    // THE ANSWER, AND THE ONE CONTROL THAT ASKS FOR IT AGAIN. Everything
    // below this is detail: which units, which packs, what to press. This is
    // the sentence somebody opened the page to read, so it is the largest
    // thing on it.
    //
    // IT IS NOT A SettingsSection, on purpose. That component is a heading
    // over a card of like things, and there is only one thing here -- filed
    // inside it, the verdict became an InfoRow label, the same size as every
    // reading in the window, under a heading ("This machine") that named the
    // page a second time. A header stops being a header when it is shaped
    // like the list underneath it.
    //
    // NOTHING RUNS THE CHECK ON A TIMER, which is why this button exists at
    // all rather than a timestamp. `./install.sh check` costs about three
    // seconds whether it is run from here or typed, and a machine that falls
    // behind a few times a week does not repay spending them on a poll. It
    // runs when this page comes on screen -- see onOnScreenChanged above --
    // and when somebody presses this.
    Rectangle {
        id: verdictCard

        // The colour rule is StateChip's, which is the CLI table's: `ok` is
        // the accent, `missing` is yellow, `drift` is red, because something
        // that is there and wrong outranks something not there yet. The bar
        // widget spends its one colour the same way. Three frontends over one
        // engine should not disagree about what a state looks like.
        readonly property color tone: {
            if (!InstallerState.repoKnown || InstallerState.checkError !== "")
                return Theme.critical;
            if (!InstallerState.ready)
                return Theme.textOnSurfaceVariant;
            if (InstallerState.outstanding === 0)
                return Theme.primary;

            return InstallerState.worst === "drift" ? Theme.critical : Theme.warning;
        }

        // The second line is empty in every ordinary state -- up to date, n
        // units outstanding, not checked yet -- and the card is the height of
        // its one sentence. It fills only when something has gone wrong that
        // the verdict cannot carry on its own, and losing the reason a check
        // failed to a redesign would be trading an answer for a tidy box.
        readonly property string detail: {
            if (!InstallerState.repoKnown)
                return "This shell was started from a path with no install.sh "
                    + "above it, so there is nothing here to drive. Everything "
                    + "else in this window still works.";

            return InstallerState.checkError;
        }

        width: parent.width
        implicitHeight: Math.max(88, verdictColumn.implicitHeight + Theme.groupPadding * 2.5)

        radius: Theme.cardRadius
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        // A band of the verdict's own colour down the leading edge, clipped
        // to the card's rounded corner by a second rectangle over its inner
        // side. It is the only thing on the page that is coloured at full
        // strength, and it is what makes this read as a header at a glance
        // from across the room rather than as one more card.
        Rectangle {
            id: toneBand

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: 4
            radius: verdictCard.radius
            color: verdictCard.tone
            opacity: InstallerState.checking ? 0.35 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: parent.width / 2
                color: parent.color
            }
        }

        Text {
            id: verdictGlyph

            anchors.left: toneBand.right
            anchors.leftMargin: Theme.groupPadding * 1.5
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.update
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize * 1.9
            color: verdictCard.tone

            // Dimmed while the check is running, which is this shell's way of
            // saying "busy". There is no spinner anywhere in it, and adding
            // one for a three-second command would be a component nothing
            // else uses -- the bar widget dims the same glyph for the same
            // three seconds.
            opacity: InstallerState.checking ? 0.45 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }
        }

        Column {
            id: verdictColumn

            anchors.left: verdictGlyph.right
            anchors.leftMargin: Theme.groupPadding
            anchors.right: checkButton.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            spacing: 4

            Text {
                width: parent.width

                text: {
                    if (!InstallerState.repoKnown)
                        return "No clone found";
                    if (InstallerState.checkError !== "")
                        return "The check did not finish";
                    if (!InstallerState.ready)
                        return "Not checked yet";

                    // "Up to date" and not "everything applicable is in
                    // place", which is what this line used to say. The
                    // qualifier was earning its keep against the `na` rows --
                    // a desktop is not broken for not being a laptop -- but
                    // those rows are three centimetres below this sentence
                    // with their own word on them, and a headline is not the
                    // place to litigate its own footnotes.
                    if (InstallerState.outstanding === 0)
                        return "Up to date";

                    return InstallerState.outstanding === 1
                        ? "1 unit needs attention"
                        : `${InstallerState.outstanding} units need attention`;
                }
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 3
                font.weight: Font.Bold
                color: verdictCard.tone

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            // THE SECOND DISTANCE, AND THE REASON THIS HEADER HAS A THIRD
            // LINE AFTER ALL. "Up to date" above means this machine matches
            // the checkout on disk. It says nothing about whether the checkout
            // still matches origin, and that gap is a real one somebody walked
            // into: merge two pull requests, press Check again, watch nothing
            // happen -- correctly, because nothing on this machine had
            // changed. A page called Updates that can only answer one of the
            // two questions people mean by the word has to say which one.
            Text {
                width: parent.width

                visible: text !== ""
                text: {
                    switch (InstallerState.originState) {
                    case "synced":
                        return "Up to date with origin";
                    case "behind":
                        return InstallerState.behindOrigin === 1
                            ? "1 commit behind origin"
                            : `${InstallerState.behindOrigin} commits behind origin`;
                    // Ahead is not a problem and is not offered a fix. It is
                    // this repository's ordinary state between opening a pull
                    // request and its merge, and a page that nagged about it
                    // would be nagging about work in progress.
                    case "ahead":
                        return InstallerState.aheadOfOrigin === 1
                            ? "1 commit ahead of origin — nothing to pull"
                            : `${InstallerState.aheadOfOrigin} commits ahead of origin — nothing to pull`;
                    case "diverged":
                        return `${InstallerState.behindOrigin} behind and `
                            + `${InstallerState.aheadOfOrigin} ahead — a pull will not `
                            + "fast-forward until that is sorted out";
                    case "detached":
                        return "Detached HEAD — no branch here to pull into";
                    case "no-upstream":
                        return "This branch tracks nothing, so there is no origin to compare with";
                    case "unreachable":
                        return "Could not reach origin, so the distance to it is unknown";
                    default:
                        return "";
                    }
                }
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                // Yellow for the two states a person can do something about,
                // and `missing`'s yellow rather than a colour of its own:
                // being behind origin is the same kind of news as a unit not
                // being installed yet.
                color: InstallerState.originState === "behind"
                    || InstallerState.originState === "diverged"
                    ? Theme.warning : Theme.textOnSurfaceVariant
                opacity: InstallerState.measuring ? 0.45 : 1

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                width: parent.width

                visible: text !== ""
                text: verdictCard.detail
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // The pill SettingsSection puts on a heading, borrowed rather than
        // inherited: this card has no heading to hang one on, and a check
        // button that did not look like every other section action in the
        // window would be a new kind of control for an old kind of job.
        Rectangle {
            id: checkButton

            readonly property bool armed: InstallerState.repoKnown
                && !InstallerState.checking && !InstallerState.measuring

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding * 1.5
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: checkRow.implicitWidth + Theme.groupPadding * 1.6
            implicitHeight: Theme.groupHeight - 8
            radius: height / 2

            opacity: checkButton.armed ? 1 : 0.5
            color: checkMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Row {
                id: checkRow

                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: Icons.refresh
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize - 2
                    color: checkMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    // "Check again" is a lie the first time, and the first
                    // time is the whole of every session until this runs.
                    text: InstallerState.checking || InstallerState.measuring ? "Checking…"
                        : InstallerState.ready ? "Check again"
                        : "Check now"
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 2
                    font.weight: Theme.fontWeight
                    color: checkMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }
            }

            MouseArea {
                id: checkMouse

                anchors.fill: parent
                enabled: checkButton.armed
                hoverEnabled: checkButton.armed
                cursorShape: Qt.PointingHandCursor

                // ONE PRESS ANSWERS BOTH QUESTIONS. Somebody who merges
                // something and comes here to press this means "is there
                // anything new", not "re-run one of the two commands that
                // could tell me". Leaving the fetch on a button of its own
                // would be handing them the distinction as homework.
                onClicked: {
                    InstallerState.check();
                    InstallerState.measureOrigin();
                }
            }
        }
    }

    // ---------------- The table ----------------

    // A ROW EXPLAINS ITSELF IN ITS OWN WORDS, which is why nothing here adds
    // to it. Every unit writes its own note and this page prints that note
    // unedited: the code that found the problem is the only thing that knows
    // what the problem is.
    //
    // This section briefly carried a paragraph about `etc`, the one unit that
    // reported and never wrote -- always `na`, never outstanding, absent from
    // both apply lists. That unit has since been dropped and system/ is
    // documentation now, so the paragraph went with it. It is left recorded
    // here only because "why is there a row nothing offers to fix" is a
    // reasonable question to have about this table, and the answer today is
    // that there is no such row.
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

        // THE SPLIT IS IN THE TWO LABELS AND NOT IN A NOTE ABOVE THEM. There
        // was a paragraph here saying that units writing into $HOME run in
        // this session and units needing a password open a terminal, that
        // this shell never asks for a password and never runs anything as
        // root. All of that is still true and none of it needed a paragraph:
        // two buttons that say "what needs no password" and "what needs a
        // password" draw the same line in eight words, and the reason the
        // line exists at all is at the top of this file under WHY THERE ARE
        // TWO BUTTONS AND NOT ONE.
        //
        // The guarantee that went with it -- no password is ever typed into
        // this shell and nothing here runs as root -- is not a claim a label
        // can carry, and it is not this page's to make either: it falls out
        // of the privilege split in InstallerState, whose own note lists the
        // six units and the grep that found them.
        // THE ONE SOMEBODY ASKED FOR. The complaint that started all of this
        // was having to reproduce the whole sequence by hand every time an
        // update landed -- read the README, remember the pull, remember which
        // mode of the installer was the right one. This is that sequence,
        // behind one press.
        //
        // IT IS FIRST because it is the outer of the two loops: taking what
        // origin has can change what the units below are even measured
        // against, so a person working down this section in order does the
        // thing that moves the checkout before the things that move the
        // machine. The whole reasoning for why it must run in a terminal, why
        // it is `update --pull`, and what waits for what afterwards is in
        // InstallerState beside the script it builds.
        ActionRow {
            glyph: Icons.terminal
            label: "Take what origin has"
            description: {
                switch (InstallerState.originState) {
                case "synced":
                    return "Nothing to pull — this checkout matches origin.";
                case "ahead":
                    return "Nothing to pull — this checkout is ahead of origin.";
                case "detached":
                    return "There is no branch checked out to pull into.";
                case "no-upstream":
                    return "This branch tracks no remote branch.";
                default:
                    // The command, as it will appear in that terminal, for the
                    // same reason the two rows below print theirs: somebody
                    // who would rather type it should not have to guess what
                    // this window is about to run on their behalf.
                    return "./install.sh update --pull, then a reload of the "
                        + "compositor and a restart of this shell.";
                }
            }

            actionText: "Open a terminal"
            actionGlyph: Icons.terminal
            // Offered in every state except the two where there is provably
            // nothing to fetch. `diverged` is deliberately still offered: the
            // pull will refuse, and it will say why in a terminal that stays
            // open, which is a better answer than a button greyed out for
            // reasons the page would then have to explain.
            actionEnabled: InstallerState.repoKnown
                && InstallerState.originState !== "synced"
                && InstallerState.originState !== "ahead"
                && InstallerState.originState !== "detached"
                && InstallerState.originState !== "no-upstream"
            onTriggered: InstallerState.takeUpdate()
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
            label: "Hand what needs a password to a terminal"
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

    // ONE PROFILE, TWO WAYS OF WRITING IT. Ticking a pack here writes
    // ${XDG_STATE_HOME}/dotfiles-profile, which is the same file
    // `./install.sh update` reads and the terminal menu writes. The window
    // and the terminal are two ways of saying the same thing, not two places
    // to say it -- which is the reason nothing on this page keeps a
    // preference of its own, and the reason a pack ticked here is still
    // ticked at a terminal tomorrow.
    SettingsSection {
        width: parent.width
        glyph: Icons.packages
        title: "Optional packs"

        // WHAT "OPTIONAL" MEANS HERE, which was a note on the page and is a
        // comment now. Nothing in these lists is needed for the desktop to
        // come up: that is the whole line between packages/required and
        // packages/optional, and it is the reason this section is a set of
        // choices while the table above is a reading.
        //
        // WHY A PACK OPENS. A pack is one box and most people will only ever
        // want the box. The drill-down is for the case no set of packs
        // somebody else drew can cover -- "gaming, but not Steam" -- and it
        // is a second control precisely so that looking inside a pack is not
        // the same act as turning it on.
        //
        // Neither of those needed saying on screen. The section is titled
        // "Optional packs", every pack carries its own summary from its own
        // list file, and the drill-down line says what it does in the words
        // "pick them one at a time".
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

}
