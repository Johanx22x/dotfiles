// The display page: what each monitor is, and the three things about it that
// are worth changing from a settings window.
//
// IT TALKS TO ONE SCRIPT AND TO NOTHING ELSE. Every list, every apply and every
// write below goes through ~/.local/bin/desktop-monitors, and there is not a
// single `hyprctl` or `niri msg` left in this file. That is the whole reason
// this page works on both compositors: what a monitor is set to is the same
// question everywhere, and only the config language and the socket differ --
// which is exactly what that script exists to absorb. A third flavor is four
// branches in it and nothing at all here.
//
//     desktop-monitors list --json      what is connected, in one shape
//     desktop-monitors apply <spec>...  live, provisional, written nowhere
//     desktop-monitors set <spec>       live AND recorded
//     desktop-monitors forget <desc>    drop the record
//     desktop-monitors main <desc>      which monitor games open on
//     desktop-monitors file             where the record is kept
//
// WHAT A CONFIRMED CHANGE IS WRITTEN INTO, because it is not this file and it
// is not the compositor's hand-written config either. The script keeps a
// SECOND file, generated and untracked -- monitors.lua under Hyprland,
// monitors.kdl under niri -- and the page names it in the line under the title
// rather than hard-coding it, because the two flavors do not agree on it and
// asking is cheaper than being wrong.
//
// THE TWO FLAVORS DO NOT AGREE ON WHAT THAT FILE *IS*, EITHER, and it shows up
// on this page in exactly one place. Under Hyprland the generated file is an
// override layer: hyprland.lua declares the monitors by hand, dofile()s the
// generated one after them, and a later hl.monitor for the same output wins --
// so Copy config exists, to promote a value the shell worked out into the file
// a person maintains. Under niri there is no layering to be had (an `output`
// block in an include is ignored when the main config names the same monitor,
// measured), so the generated file is the only declaration there is and a block
// pasted into config.kdl would shadow this page for good. Hence
// `monitorConfigCopy`: the chip is drawn where it means something.
//
// WHY IT DOES NOT WRITE THE HAND-WRITTEN CONFIG ITSELF. That file is a stow
// symlink into a git repo and a thousand lines of hand-written commentary, in
// an order a person chose. A settings window that edited it would be a program
// rewriting prose it cannot read: the first change would move the monitor
// block, or drop the comment explaining why these monitors are matched by
// description and not by connector name, or both -- and the diff would land in
// git looking like something a human did. A generated file is the honest
// boundary. The shell owns that one; the person owns theirs.
//
// THE REVERT TIMER IS THE POINT OF THIS PAGE, not a nicety on top of it. A
// mode the panel cannot display leaves a black screen, and the window holding
// the undo button is on that screen. So an apply is provisional: the spec that
// was live is kept, a countdown starts, and unless it is confirmed the
// compositor is put back where it was. The confirmation is the thing you have
// to do; doing nothing is safe. That is the opposite way round from every
// other button in this shell, and it is deliberate.
//
// AND THE CONFIRMATION IS ALSO THE WRITE. Nothing reaches monitors.lua until
// somebody has said they can see the result -- see keep(), which is where that
// argument is made in full.
//
// THE BAR MOVES WHEN THE BIG MONITOR GOES PORTRAIT, and it looks exactly like
// a bug the first time. Screens.qml picks the shell's screen as the largest
// LANDSCAPE one, so rotating the main panel hands the bar, the launcher, the
// notifications and this window's own sibling surfaces to the other monitor.
// Correct behaviour, badly surprising -- so the rotation control says so
// before you press it, and only when it applies.
//
// WHAT IT DELIBERATELY WILL NOT DO: turn a monitor off. `desktop-monitors list`
// reports the monitors that are actually being driven, on both flavors, so a
// monitor disabled from here could not be listed again to be switched back on
// -- the revert timer would be the only way out of it, and a safety net is not
// a design.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"
// The parts this page is composed of, for the same reason: they live one
// directory DOWN.
import "root:/modules/settings/pages/display"

SettingsPage {
    id: root

    // Every control here writes a monitor layout into the compositor. Where it
    // cannot be driven, the page is not offered rather than shown dead.
    available: Compositor.can("monitorConfig")

    title: "Display"
    glyph: Icons.monitor
    keywords: ["monitor", "screen", "display", "resolution", "refresh", "hz",
        "scale", "scaling", "rotation", "rotate", "portrait", "landscape",
        "mode", "hyprland", "niri"]

    // ---------------- What the compositor said, last time it was asked ----------------
    //
    // IT IS A READING, NOT A CONTROL. Nothing on this page holds a monitor's
    // state of its own: the controls hold a DRAFT, and everything drawn as
    // fact comes from `source.monitors`.
    MonitorSource {
        id: source
    }

    // ---------------- What would be, and the ten seconds to say so ----------------
    //
    // OUTSIDE THE CARDS AND NOT IN THEM, which is the whole reason it is an
    // object of its own -- see its header.
    DisplayDraft {
        id: draft

        source: source
        revertAfter: root.revertAfter
    }

    // Long enough to see that the desktop redrew and read the line asking, and
    // short enough to sit out with your eyes shut if it did not. Read by both
    // countdowns on this page -- the mode one next door and the arrangement's
    // further down -- which is why it is here and not inside either.
    readonly property int revertAfter: 10

    // ---------------- Re-reading ----------------
    //
    // THE PAGE'S OWN `visible`, which is the only honest signal here: the
    // settings window builds every page at startup and keeps them all alive,
    // showing one at a time. Component.onCompleted fires once, for a page
    // nobody is looking at, and the window being open says nothing -- nine
    // other pages are open too.
    onVisibleChanged: {
        if (!root.visible)
            return;

        // The compositor's list, the saved list, and -- once per session --
        // where the saved list is kept. See MonitorSource.refresh, which holds
        // the guards and the reason for each of the three.
        source.refresh();

        // Which blue-light daemon, if any, this session has. Asked here rather
        // than polled or watched: the answer only changes when a package is
        // installed or a session restarts, and both of those end with a trip
        // back to this page. See NightLightSection.qml, which owns the probe
        // and has no `visible` of its own worth gating on -- QML allows one
        // onVisibleChanged handler per object and this page's is here.
        nightLight.probe();

        // The forget advice belongs to the visit it was earned in. It says to
        // go and settle something outside this window, and leaving it is the
        // likeliest thing to have happened in order to do that.
        source.dropForgetNotice();
    }

    // ---------------- Where a kept change goes ----------------
    //
    // ONE LINE AND NOT A PARAGRAPH. It is true of every control below it, so
    // it has to be said once, up here, and then never repeated on a row -- a
    // notice printed six times is a notice nobody reads. It used to say the
    // opposite ("this session only"), and the reason it no longer does is the
    // generated file; naming it is the point of the line, because it is a file
    // the person can read, delete or keep out of git themselves. The refresh
    // beside it is the manual way to re-read; the page does it on its own
    // whenever it is opened and after every apply.
    //
    Item {
        width: parent.width
        // Grows with the notice rather than clipping it, since the sentence
        // takes two lines at this window's default width and one at a wider
        // one.
        implicitHeight: Math.max(30, notice.implicitHeight + 10)

        Text {
            id: notice

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.right: rereadChip.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            // WRAPS, and does not elide. It elided at first and the window
            // is not wide enough for the sentence, so what reached the screen
            // was "Kept changes are saved to ~/.config/hypr/monitors.lua — ge…"
            // -- the half that says WHERE, cut before the half that says the
            // file is generated. A settings window is the last place that
            // should be telling you most of something.
            text: source.savedTo === ""
                ? "Kept changes are written to a generated file, read back on every reload."
                : `Kept changes are saved to ${source.savedTo} — generated, read back on every reload.`
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Chip {
            id: rereadChip

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            label: "Re-read"
            glyph: Icons.refresh
            enabled: !source.busy
            // BOTH READINGS, because both can be behind: the compositor's if
            // something moved a monitor from elsewhere, and the saved list if a
            // write landed after the page last looked. This chip is the way to
            // catch up on either without closing the window.
            onActivated: source.reread()
        }
    }

    ArrangementSection {
        id: arrange

        width: root.width

        source: source
        revertAfter: root.revertAfter
        // The two provisional changes lock each other out, and this is one half
        // of that; `arrange.pending` on the cards below is the other.
        modePending: draft.pendingName !== ""
    }

    NightLightSection {
        id: nightLight

        width: root.width
    }

    // ---------------- One section per connected monitor ----------------
    Repeater {
        model: source.monitors

        SettingsSection {
            id: card

            required property var modelData

            readonly property var mon: card.modelData
            readonly property var spec: draft.draftOf(card.mon)
            readonly property bool dirty: draft.isDirty(card.mon)
            readonly property bool pending: draft.pendingName === card.mon.name
            // Locked while ANY monitor is waiting to be confirmed, not only
            // this one. Stacking a second provisional change on top of one
            // that may be about to undo itself is a state with no honest way
            // back.
            // ANY provisional change, not only a mode one: an arrangement is
            // also waiting on a countdown and also about to be undone, and
            // stacking a mode change on top of one is the state this lock
            // exists to make impossible.
            readonly property bool locked: draft.pendingName !== "" || arrange.pending
            // null when this monitor has nothing saved, which is the state
            // every monitor is in until somebody keeps a change.
            readonly property var saved: source.savedOf(card.mon)

            readonly property bool isMain: source.isMainMonitor(card.mon)
            readonly property bool mainIsChosen: source.mainChosen(card.mon)

            width: root.width
            glyph: Icons.monitor
            title: Monitors.monitorTitle(card.mon)

            // ---------------- What it is ----------------
            Reading {
                label: "Connector"
                value: card.mon.name ?? ""
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
                value: card.mon.description ?? ""
            }

            Reading {
                label: "Resolution"
                value: `${card.mon.width} × ${card.mon.height}`
            }

            Reading {
                label: "Refresh"
                value: `${(card.mon.refreshRate ?? 0).toFixed(2)} Hz`
            }

            Reading {
                label: "Scale"
                value: (card.mon.scale ?? 1).toFixed(2)
            }

            Reading {
                label: "Rotation"
                value: Monitors.transformLabel(card.mon.transform ?? 0)
            }

            Reading {
                label: "Position"
                value: `${card.mon.x}, ${card.mon.y}`
            }

            Reading {
                label: "Focus"
                value: card.mon.focused ? "has the keyboard" : "—"
                tone: card.mon.focused ? Theme.primary : Theme.textOnSurfaceVariant
            }

            // WHERE THE SHELL LIVES, and it distinguishes chosen from worked
            // out. Both are "yes" to the question the bar answers, and they
            // behave differently the moment a monitor is unplugged or rotated:
            // an automatic pick moves, a chosen one waits for its screen to
            // come back. Somebody surprised by the bar moving is reading this
            // row to find out which of the two they have.
            Reading {
                label: "Main monitor"
                value: card.isMain ? (card.mainIsChosen ? "yes — chosen" : "yes — picked automatically") : "—"
                tone: card.isMain ? Theme.primary : Theme.textOnSurfaceVariant
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
                visible: card.saved !== null
                label: "Saved override"
                value: card.saved ? Monitors.savedLabel(card.saved) : ""
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
                value: Monitors.modeLabel(card.spec.mode)
                enabled: !card.locked

                // WRAPS RATHER THAN CLAMPS. Nothing is applied by stepping --
                // this only moves a draft -- so running off the end costs
                // nothing, and the main panel offers 29 modes: a button that
                // goes dead at the top of that list is a control that looks
                // broken long before it is understood.
                onStepped: delta => {
                    const modes = Monitors.modeList(card.mon);
                    const at = modes.indexOf(card.spec.mode);
                    const next = (at + delta + modes.length) % modes.length;
                    draft.setDraft(card.mon, { mode: modes[next] });
                }
            }

            CycleRow {
                glyph: Glyphs.relativeScale
                label: "Scale"
                value: card.spec.scale.toFixed(2)
                enabled: !card.locked

                onStepped: delta => {
                    const scales = Monitors.scaleList(card.mon);
                    let at = scales.findIndex(s => Math.abs(s - card.spec.scale) < 0.001);
                    if (at < 0)
                        at = 0;
                    const next = (at + delta + scales.length) % scales.length;
                    draft.setDraft(card.mon, { scale: scales[next] });
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

                opacity: card.locked ? 0.4 : 1

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
                            filled: card.spec.transform === modelData.transform
                            enabled: !card.locked
                            onActivated: draft.setDraft(card.mon, { transform: modelData.transform })
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
                visible: (card.spec.transform === 1 || card.spec.transform === 3)
                    && (card.mon.transform ?? 0) !== 1 && (card.mon.transform ?? 0) !== 3

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
                visible: !card.pending

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
                        enabled: card.dirty && !card.locked
                        onActivated: draft.commit(card.mon)
                    }

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Discard"
                        glyph: Icons.close
                        enabled: card.dirty && !card.locked
                        onActivated: draft.clearDraft(card.mon.name)
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
                        label: draft.copiedFor === card.mon.name ? "Copied" : "Copy config"
                        glyph: draft.copiedFor === card.mon.name ? Glyphs.check : Icons.clipboard
                        onActivated: draft.copyConfig(card.mon)
                    }

                    // Moving the shell here, or letting the rule pick again.
                    // Hidden on a single-monitor machine: with one screen it is
                    // already the main one and the chip could only re-state
                    // that.
                    //
                    // NOT LOCKED BY `card.locked`, unlike the mode controls
                    // next to it. That lock is about provisional changes a
                    // countdown is about to undo, and this is not one of them:
                    // nothing here can leave a screen black, so there is
                    // nothing to confirm and nothing to revert.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Screens.all.length > 1
                        label: card.mainIsChosen ? "Unset main" : "Make main"
                        glyph: card.mainIsChosen ? Icons.restore : Icons.monitor
                        enabled: !source.settingMain && (card.mainIsChosen || !card.isMain || Config.mainMonitor !== "")
                        onActivated: card.mainIsChosen ? source.clearMain(card.mon) : source.makeMain(card.mon)
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
                        visible: card.saved !== null
                        label: "Forget saved"
                        glyph: Icons.restore
                        enabled: !card.locked && !source.forgetting
                        onActivated: source.forget(card.mon)
                    }
                }
            }

            // What the main-monitor write left behind, in the script's words.
            // The shell half of that click is already visible -- the bar moved
            // as it was pressed -- so anything worth printing here is about the
            // compositor half, which is the half that may be waiting on a
            // reload.
            Text {
                visible: source.mainNoticeFor === card.mon.name && source.mainNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: source.mainNotice
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
                visible: source.forgetNoticeFor === card.mon.name && source.forgetNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: source.forgetNotice
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
                visible: card.pending

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
                        text: `Keep this display setting? Reverting in ${draft.secondsLeft}s`
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
                        onActivated: draft.keep()
                    }

                    // The same thing the timer is about to do, for when you
                    // can already see it is wrong and would rather not sit
                    // through the countdown.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Revert now"
                        onActivated: draft.revert()
                    }
                }
            }
        }
    }

    // ---------------- Nothing plugged in, or nothing read yet ----------------
    //
    // The script is asked when the page appears, so an empty list is either the
    // few milliseconds before the first answer or a genuinely empty reply.
    // Both are covered by one line: a page that draws nothing at all reads as
    // a page that failed to load.
    SettingsSection {
        width: root.width
        visible: source.monitors.length === 0
        glyph: Icons.monitor
        title: "Monitors"

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 4

            text: "No monitors reported. `desktop-monitors list` reports the ones actually "
                + "being driven, so a screen that is switched off in the compositor does "
                + "not appear here."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
