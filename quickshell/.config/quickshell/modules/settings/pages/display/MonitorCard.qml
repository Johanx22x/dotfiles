// One monitor, as a card: nine facts about it, a line, and the three things
// that can be changed about it -- then the row of actions, and the banner that
// replaces them while a change is waiting to be confirmed.
//
// EVERYTHING ABOVE THE LINE IS WHAT IS, EVERYTHING BELOW IT IS WHAT WOULD BE,
// and that separation is the card's whole shape. The facts come from
// `source`, which is a reading of the compositor and is never derived from
// what this card asked for; the controls move `draft`, which reaches the
// compositor only when Apply is pressed and reaches the disk only when Keep is.
//
// IT OWNS NO STATE, deliberately. Every property here is readonly and derived,
// because the Repeater above it replaces `source.monitors` whole on every
// re-read and destroys every card with it -- anything a card held would be
// gone the moment the page re-read the compositor, which is the very thing
// pressing Apply causes. See DisplayDraft.qml, which is where a half-made
// choice actually lives.

import QtQuick
import "root:/"
// SettingsSection lives two directories UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"

SettingsSection {
    id: root

    // The monitor this card is about. The Repeater hands it its modelData.
    required property var mon

    // The readings and the draft, both of which outlive this card: `monitors`
    // is replaced whole on every re-read and every card in the Repeater is
    // destroyed with it.
    required property MonitorSource source
    required property DisplayDraft draft

    // An arrangement is waiting to be confirmed. See `locked`.
    required property bool arrangePending

    readonly property var spec: root.draft.draftOf(root.mon)
    readonly property bool dirty: root.draft.isDirty(root.mon)
    readonly property bool pending: root.draft.pendingName === root.mon.name
    // Locked while ANY monitor is waiting to be confirmed, not only
    // this one. Stacking a second provisional change on top of one
    // that may be about to undo itself is a state with no honest way
    // back.
    //
    // ANY provisional change, not only a mode one: an arrangement is
    // also waiting on a countdown and also about to be undone, and
    // stacking a mode change on top of one is the state this lock
    // exists to make impossible.
    readonly property bool locked: root.draft.pendingName !== "" || root.arrangePending
    // null when this monitor has nothing saved, which is the state
    // every monitor is in until somebody keeps a change.
    readonly property var saved: root.source.savedOf(root.mon)

    readonly property bool isMain: root.source.isMainMonitor(root.mon)
    readonly property bool mainIsChosen: root.source.mainChosen(root.mon)

    glyph: Icons.monitor
    title: Monitors.monitorTitle(root.mon)

    // ---------------- What it is ----------------
    Reading {
        label: "Connector"
        value: root.mon.name ?? ""
    }

    // The full EDID string, verbatim, and it is worth being able to
    // read it off the screen rather than out of a terminal: it is the
    // name every rule in the compositor's own config matches on, and
    // the two compositors do not spell it the same way -- Hyprland
    // normalises the manufacturer and niri does not.
    //
    // Which is also why this row shows what THIS session reports and
    // never a string derived from the other one. `desktop-monitors list`
    // is the same answer in a terminal.
    Reading {
        label: "Description"
        value: root.mon.description ?? ""
    }

    Reading {
        label: "Resolution"
        value: `${root.mon.width} × ${root.mon.height}`
    }

    Reading {
        label: "Refresh"
        value: `${(root.mon.refreshRate ?? 0).toFixed(2)} Hz`
    }

    Reading {
        label: "Scale"
        value: (root.mon.scale ?? 1).toFixed(2)
    }

    Reading {
        label: "Rotation"
        value: Monitors.transformLabel(root.mon.transform ?? 0)
    }

    Reading {
        label: "Position"
        value: `${root.mon.x}, ${root.mon.y}`
    }

    Reading {
        label: "Focus"
        value: root.mon.focused ? "has the keyboard" : "—"
        tone: root.mon.focused ? Theme.primary : Theme.textOnSurfaceVariant
    }

    // WHERE THE SHELL LIVES, and it distinguishes chosen from worked
    // out. Both are "yes" to the question the bar answers, and they
    // behave differently the moment a monitor is unplugged or rotated:
    // an automatic pick moves, a chosen one waits for its screen to
    // come back. Somebody surprised by the bar moving is reading this
    // row to find out which of the two they have.
    Reading {
        label: "Main monitor"
        value: root.isMain ? (root.mainIsChosen ? "yes — chosen" : "yes — picked automatically") : "—"
        tone: root.isMain ? Theme.primary : Theme.textOnSurfaceVariant
    }

    // WHAT IS ON DISK, and it is a seventh fact about this monitor
    // rather than a repeat of the six above it. The two disagree
    // whenever something changed the mode since it was saved -- a
    // reload has not happened yet, or a rule elsewhere won -- and that
    // disagreement is the only thing on this page that can show it.
    // Absent, and not "none", when nothing is saved: a row saying "no
    // override" on all six monitors on a machine that has never used
    // this feature is six lines of nothing.
    Reading {
        visible: root.saved !== null
        label: "Saved override"
        value: root.saved ? Monitors.savedLabel(root.saved) : ""
    }

    // Separates the facts above from the draft below, because they
    // look alike and mean opposite things: everything over this line
    // is what IS, everything under it is what WOULD BE.
    Rectangle {
        width: parent.width - Theme.groupPadding * 2
        x: Theme.groupPadding
        height: 1
        color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- What it would be ----------------
    CycleRow {
        glyph: Glyphs.arrowExpand
        label: "Mode"
        value: Monitors.modeLabel(root.spec.mode)
        enabled: !root.locked

        // WRAPS RATHER THAN CLAMPS. Nothing is applied by stepping --
        // this only moves a draft -- so running off the end costs
        // nothing, and the main panel offers 29 modes: a button that
        // goes dead at the top of that list is a control that looks
        // broken long before it is understood.
        onStepped: delta => {
            const modes = Monitors.modeList(root.mon);
            const at = modes.indexOf(root.spec.mode);
            const next = (at + delta + modes.length) % modes.length;
            root.draft.setDraft(root.mon, { mode: modes[next] });
        }
    }

    CycleRow {
        glyph: Glyphs.relativeScale
        label: "Scale"
        value: root.spec.scale.toFixed(2)
        enabled: !root.locked

        onStepped: delta => {
            const scales = Monitors.scaleList(root.mon);
            let at = scales.findIndex(s => Math.abs(s - root.spec.scale) < 0.001);
            if (at < 0)
                at = 0;
            const next = (at + delta + scales.length) % scales.length;
            root.draft.setDraft(root.mon, { scale: scales[next] });
        }
    }

    // Rotation is a segmented control and not a cycle, because it has
    // four options that everyone already knows the names of and no
    // order worth stepping through -- going from 0° to 270° should be
    // one click, not three.
    Rectangle {
        width: parent.width
        implicitHeight: Theme.groupHeight
        radius: Theme.groupRadius
        color: "transparent"

        opacity: root.locked ? 0.4 : 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Glyphs.screenRotation
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Rotation"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Theme.fontWeight
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                // The four rotations, as index and label. 4-7 (the
                // flipped ones) are absent on purpose: nothing on this
                // desk wants a mirrored output, and a segmented
                // control with eight options is a list.
                model: [
                    { transform: 0, text: "0°" },
                    { transform: 1, text: "90°" },
                    { transform: 2, text: "180°" },
                    { transform: 3, text: "270°" }
                ]

                Chip {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData.text
                    // Nothing is selected when the live transform is a
                    // flipped one, which is honest: none of these four
                    // is what the monitor is doing.
                    filled: root.spec.transform === modelData.transform
                    enabled: !root.locked
                    onActivated: root.draft.setDraft(root.mon, { transform: modelData.transform })
                }
            }
        }
    }

    // ONLY WHEN IT IS ABOUT TO HAPPEN. See the header: Screens.qml
    // gives the bar to the largest landscape screen, so turning the
    // big monitor on its side moves the whole shell to the other one.
    // A permanent note saying so would be skipped by the third visit;
    // this one appears exactly when the draft would cause it.
    Text {
        visible: (root.spec.transform === 1 || root.spec.transform === 3)
            && (root.mon.transform ?? 0) !== 1 && (root.mon.transform ?? 0) !== 3

        x: Theme.groupPadding
        width: parent.width - Theme.groupPadding * 2
        bottomPadding: 6

        text: "Portrait makes this screen taller than it is wide. "
            + "The bar, the launcher and the notifications go to the largest landscape screen, "
            + "so they will move to the other monitor."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- Actions ----------------
    Item {
        width: parent.width
        implicitHeight: Theme.groupHeight
        visible: !root.pending

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Apply"
                glyph: Icons.monitor
                filled: true
                enabled: root.dirty && !root.locked
                onActivated: root.draft.commit(root.mon)
            }

            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Discard"
                glyph: Icons.close
                enabled: root.dirty && !root.locked
                onActivated: root.draft.clearDraft(root.mon.name)
            }

            // STILL HERE NOW THAT KEEPING WORKS, and it is not the
            // leftover of the days when it was the only way to make a
            // change last. The two destinations are different files
            // with different owners: Keep writes the generated file, and
            // this puts the same block on the clipboard for the
            // hand-written one, which is in git. Promoting a value from
            // the first to the second is a thing to want, and it is not
            // a thing a settings window should do by itself -- see the
            // header.
            //
            // NOT gated on `dirty`, unlike the two above: copying the
            // block for a monitor exactly as it is now is the whole
            // point on the day you want to write the current setup
            // into the tracked config without changing anything first.
            //
            // HIDDEN WHERE THERE IS NOWHERE TO PASTE IT. Under niri the
            // generated file is the ONLY declaration of an output, so
            // this block would have no destination -- and the one place
            // somebody would try, config.kdl, is the place that shadows
            // the generated file and kills this page. A chip that hands
            // you a footgun is worse than no chip.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                visible: Compositor.can("monitorConfigCopy")
                label: root.draft.copiedFor === root.mon.name ? "Copied" : "Copy config"
                glyph: root.draft.copiedFor === root.mon.name ? Glyphs.check : Icons.clipboard
                onActivated: root.draft.copyConfig(root.mon)
            }

            // Moving the shell here, or letting the rule pick again.
            // Hidden on a single-monitor machine: with one screen it is
            // already the main one and the chip could only re-state
            // that.
            //
            // NOT LOCKED BY `root.locked`, unlike the mode controls
            // next to it. That lock is about provisional changes a
            // countdown is about to undo, and this is not one of them:
            // nothing here can leave a screen black, so there is
            // nothing to confirm and nothing to revert.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                visible: Screens.all.length > 1
                label: root.mainIsChosen ? "Unset main" : "Make main"
                glyph: root.mainIsChosen ? Icons.restore : Icons.monitor
                enabled: !root.source.settingMain && (root.mainIsChosen || !root.isMain || Config.mainMonitor !== "")
                onActivated: root.mainIsChosen ? root.source.clearMain(root.mon) : root.source.makeMain(root.mon)
            }

            // HIDDEN AND NOT DIMMED, which is the one place this page
            // departs from the rule written on Chip. A disabled chip
            // says "not now"; this one would be saying "not until you
            // save something", which on a machine that never has is a
            // dead button beside three live ones forever. It is last in
            // the row, so its coming and going moves nothing that was
            // already there.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.saved !== null
                label: "Forget saved"
                glyph: Icons.restore
                enabled: !root.locked && !root.source.forgetting
                onActivated: root.source.forget(root.mon)
            }
        }
    }

    // What the main-monitor write left behind, in the script's words.
    // The shell half of that click is already visible -- the bar moved
    // as it was pressed -- so anything worth printing here is about the
    // compositor half, which is the half that may be waiting on a
    // reload.
    Text {
        visible: root.source.mainNoticeFor === root.mon.name && root.source.mainNotice !== ""

        x: Theme.groupPadding
        width: parent.width - Theme.groupPadding * 2
        bottomPadding: 6

        text: root.source.mainNotice
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // THE SCRIPT'S OWN WORDS, printed verbatim under the monitor they
    // were about. `forget` rewrites the generated file and deliberately
    // applies nothing, so at this instant the file and the screen
    // disagree -- and what settles them is not the same on both flavors.
    // Shown rather than paraphrased so there is one copy of that
    // sentence, in the script that knows it.
    Text {
        visible: root.source.forgetNoticeFor === root.mon.name && root.source.forgetNotice !== ""

        x: Theme.groupPadding
        width: parent.width - Theme.groupPadding * 2
        bottomPadding: 6

        text: root.source.forgetNotice
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        // Amber and not the ordinary muted grey, for the same reason
        // the portrait note is: this is not an error, it is a state
        // that ends when you do the thing it asks.
        color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- The way back ----------------
    //
    // WHY NOT ConfirmButton. That one arms on the first click and acts
    // on the second, so the dangerous thing happens only if you
    // confirm it -- which is the right shape for Reset and the wrong
    // shape here. The dangerous thing has ALREADY happened by the time
    // this row appears: the mode is live, and what the click buys is
    // permission to keep it -- and, since keep() writes, permission to
    // write it down. Silence has to undo, not do nothing. Its
    // countdown is also a border draining away with no number on it,
    // and the number is the one thing worth reading when you are
    // waiting to find out whether the screen comes back.
    Rectangle {
        width: parent.width - 8
        x: 4
        implicitHeight: Theme.groupHeight
        radius: Theme.groupRadius
        visible: root.pending

        // The shell's amber, the same one the Wi-Fi hardware-switch
        // line uses: this is not an error, it is a state that is about
        // to end by itself.
        color: Qt.alpha(Theme.warning, 0.16)
        border.width: 1
        border.color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Glyphs.timerSand
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.warning

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `Keep this display setting? Reverting in ${root.draft.secondsLeft}s`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding - 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            // "Keep" and a save glyph, because this one press does both
            // things: it stops the countdown AND it is what writes the
            // change to the generated file. A tick here would say the
            // change was merely accepted.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Keep"
                glyph: Glyphs.contentSave
                filled: true
                onActivated: root.draft.keep()
            }

            // The same thing the timer is about to do, for when you
            // can already see it is wrong and would rather not sit
            // through the countdown.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert now"
                onActivated: root.draft.revert()
            }
        }
    }
}
