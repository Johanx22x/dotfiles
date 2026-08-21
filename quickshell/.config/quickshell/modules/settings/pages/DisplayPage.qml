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
    // NAMED monitorSource AND NOT source, WHICH IS NOT STYLE. The card below
    // takes a `source` property, and `source: source` written inside a Repeater
    // delegate resolves the right-hand side against the DELEGATE first: the
    // card's own property, bound to itself. Qt calls it a binding loop, leaves
    // the property null, and every reading on every card comes out blank while
    // the file that is wrong is this one. The same trap is waiting for `draft`.
    //
    // IT IS A READING, NOT A CONTROL. Nothing on this page holds a monitor's
    // state of its own: the controls hold a DRAFT, and everything drawn as
    // fact comes from `monitorSource.monitors`.
    MonitorSource {
        id: monitorSource
    }

    // ---------------- What would be, and the ten seconds to say so ----------------
    //
    // OUTSIDE THE CARDS AND NOT IN THEM, which is the whole reason it is an
    // object of its own -- see its header.
    DisplayDraft {
        id: displayDraft

        source: monitorSource
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
        monitorSource.refresh();

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
        monitorSource.dropForgetNotice();
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
            text: monitorSource.savedTo === ""
                ? "Kept changes are written to a generated file, read back on every reload."
                : `Kept changes are saved to ${monitorSource.savedTo} — generated, read back on every reload.`
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
            enabled: !monitorSource.busy
            // BOTH READINGS, because both can be behind: the compositor's if
            // something moved a monitor from elsewhere, and the saved list if a
            // write landed after the page last looked. This chip is the way to
            // catch up on either without closing the window.
            onActivated: monitorSource.reread()
        }
    }

    ArrangementSection {
        id: arrange

        width: root.width

        source: monitorSource
        revertAfter: root.revertAfter
        // The two provisional changes lock each other out, and this is one half
        // of that; `arrange.pending` on the cards below is the other.
        modePending: displayDraft.pendingName !== ""
    }

    NightLightSection {
        id: nightLight

        width: root.width
    }

    // ---------------- One section per connected monitor ----------------
    Repeater {
        model: monitorSource.monitors

        MonitorCard {
            required property var modelData

            width: root.width

            mon: modelData
            source: monitorSource
            draft: displayDraft
            // ANY provisional change locks a card, not only a mode one: an
            // arrangement is also waiting on a countdown and also about to be
            // undone, and stacking a mode change on top of one is the state
            // this lock exists to make impossible.
            arrangePending: arrange.pending
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
        visible: monitorSource.monitors.length === 0
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
