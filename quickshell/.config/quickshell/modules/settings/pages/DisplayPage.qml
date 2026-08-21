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
    // fact comes from this array. That is what makes a rejected apply visible
    // -- Hyprland silently adjusting a scale it cannot honour shows up as the
    // readings disagreeing with what you asked for, rather than as a page
    // confidently displaying a number the compositor never accepted.
    property var monitors: []

    // ---------------- The draft, held HERE and keyed by connector ----------------
    //
    // AT PAGE LEVEL BECAUSE THE DELEGATES DIE. `monitors` is replaced whole on
    // every re-read, which destroys every section and everything inside one.
    // A half-made choice of mode living in the row would vanish the moment
    // anything re-read the compositor -- including the re-read that this
    // page's own apply triggers. Same reasoning as the password state in
    // NetworkPage.
    //
    // Keyed by connector name and not by index: the array is sorted by
    // position, so an index is not stable, and the name is at least stable for
    // as long as the page is open. (It is NOT stable across kernels, which is
    // exactly why the Lua below matches on desc: instead.)
    //
    // An entry exists only for a monitor someone has touched. Absent means
    // "whatever the compositor currently says", which is why `draftOf` falls
    // through to `specOf` rather than seeding the map up front: a seeded map
    // would go stale against the next re-read.
    property var draft: ({})

    // ---------------- The provisional apply ----------------
    //
    // One at a time, page-wide. Two monitors mid-revert at once is a state
    // nobody can reason about while looking at a black screen, and the
    // controls lock for as long as this is set.
    property string pendingName: ""
    property var revertSpec: null
    property int secondsLeft: 0

    // WHAT WAS ACTUALLY SENT, kept rather than re-derived from the draft when
    // the confirmation arrives. The draft is a live binding into a map the page
    // rewrites; this is a snapshot of the exact four values the script was given,
    // and it is the thing keep() writes to disk. Persisting anything else would
    // be persisting something nobody was shown.
    property var pendingSpec: null

    // Long enough to see that the desktop redrew and read the line asking, and
    // short enough to sit out with your eyes shut if it did not.
    readonly property int revertAfter: 10

    // The monitor whose Copy button was pressed, so the chip can say it
    // worked. wl-copy is fire-and-forget -- there is no completion to wait on
    // -- so this is optimistic by construction.
    property string copiedFor: ""

    // ---------------- What is saved, as desktop-monitors reports it ----------------
    //
    // KEYED BY DESCRIPTION, not by connector name, because that is the key the
    // script and both hand-written configs use: the EDID string, which does not
    // change when a kernel renames DP-4 to DP-3. Two identical panels would
    // collide here, and they would collide in the compositor's own config first
    // -- this page does not invent a way out of a limitation it already has.
    //
    // A READING like `monitors`, and it is read back after every write rather
    // than assumed from what was written. The saved value and the live value
    // are different facts and the page shows both: they disagree the moment
    // anything changes a mode without saving it.
    property var overrides: ({})

    // The last thing `desktop-monitors forget` printed, and which monitor's row
    // it belongs under. Held rather than re-typed: what is still left to happen
    // after a record is dropped differs per compositor, and that sentence is the
    // script's -- a second copy of it in QML is a copy that goes out of step.
    property string forgetNotice: ""
    property string forgetNoticeFor: ""

    function draftOf(mon: var): var {
        return root.draft[mon.name] ?? Monitors.specOf(mon);
    }

    function setDraft(mon: var, patch: var): void {
        // A NEW OBJECT, not a mutated one. Assigning into `root.draft` in
        // place changes nothing QML can see -- the property still points at
        // the same object, no change signal is emitted, and every binding
        // reading it keeps the old value. The page would take the click and
        // draw nothing.
        const next = Object.assign({}, root.draft);
        next[mon.name] = Object.assign({}, root.draftOf(mon), patch);
        root.draft = next;
    }

    function clearDraft(name: string): void {
        const next = Object.assign({}, root.draft);
        delete next[name];
        root.draft = next;
    }

    // Only the three editable fields. Position is in the spec but not in this
    // comparison, so a monitor that Hyprland moved for its own reasons does
    // not light up the Apply button.
    function isDirty(mon: var): bool {
        const a = root.draftOf(mon);
        const b = Monitors.specOf(mon);
        return a.mode !== b.mode
            || Math.abs(a.scale - b.scale) > 0.001
            || a.transform !== b.transform;
    }

    // ---------------- Reading the saved overrides ----------------

    // null and not undefined, so the delegates can compare against something.
    function savedOf(mon: var): var {
        return root.overrides[mon.description ?? ""] ?? null;
    }

    // ---------------- Applying ----------------

    function applySpec(spec: var): void {
        // No guard against an overlapping run, and it does not need one: the
        // controls lock while a confirmation is pending, and the earliest a
        // revert can fire is a full second after the apply that started it.
        // The script is long gone by then.
        //
        // `apply` AND NOT `set`: this writes nothing anywhere. Under niri that
        // is not merely the page's convention -- `niri msg output` is temporary
        // by design and says so in its own help, which is exactly the right
        // shape for a change that has ten seconds to be confirmed.
        applier.command = ["desktop-monitors", "apply"].concat(Monitors.specArgs(spec));
        applier.running = true;
    }

    // Read the current spec BEFORE applying, because after the apply the
    // compositor no longer knows what it used to be and neither would we.
    function commit(mon: var): void {
        root.revertSpec = Monitors.specOf(mon);
        root.pendingSpec = root.draftOf(mon);
        root.pendingName = mon.name;
        root.secondsLeft = root.revertAfter;
        // Any forget advice on screen describes the state before this apply,
        // and telling somebody to reload while a countdown is running would be
        // telling them to reload their way into the mode they are deciding
        // about.
        root.forgetNotice = "";
        root.forgetNoticeFor = "";
        root.applySpec(root.pendingSpec);
    }

    // Writing it down is a separate act from applying it, and this is the half
    // that lasts. `set` rewrites the generated file and hands the spec to the
    // compositor as well.
    function persist(spec: var): void {
        Quickshell.execDetached(["desktop-monitors", "set"].concat(Monitors.specArgs(spec)));
        overrideSettle.restart();
    }

    function keep(): void {
        // THE WRITE IS HERE AND NOT IN commit(), and that is the whole point of
        // the countdown existing. An apply is a question -- can you see this?
        // -- and only the answer is worth keeping. Writing on the apply instead
        // would put a mode into the generated file before anyone knew whether
        // the panel could show it, and that file is re-read on every reload and
        // every boot: a settings file that faithfully restores a black screen
        // is the exact failure this design exists to avoid. Nothing is written
        // when the countdown expires or Revert is pressed, which is the same
        // rule said the other way round.
        //
        // THE REDUNDANCY IS DELIBERATE AND IT IS A NO-OP. `desktop-monitors set`
        // applies the spec live as well as writing it, so the compositor is
        // told a second time what it is already doing -- same output, same
        // mode string, same position, scale and transform, because what is
        // persisted is the snapshot of what was applied ten seconds ago and not
        // a re-reading of anything. Setting every field to the value it already
        // holds changes no pixels. Not worth a --no-apply flag on the script:
        // that would be a second code path through the one part of this that
        // must not be wrong, bought for nothing.
        //
        // AND UNDER niri IT IS NOT EVEN REDUNDANT. A mode written into the
        // config file is not re-applied on a reload -- niri chooses a mode when
        // the connector comes up and does not revisit it -- so the live push is
        // what keeps the screen and the file agreeing until the next session.
        if (root.pendingSpec)
            root.persist(root.pendingSpec);

        // The draft goes with it: the live state is now what the draft said,
        // so keeping the entry would only be a copy of the readings waiting to
        // go stale.
        root.clearDraft(root.pendingName);
        root.pendingName = "";
        root.revertSpec = null;
        root.pendingSpec = null;
    }

    function revert(): void {
        if (root.revertSpec)
            root.applySpec(root.revertSpec);

        root.clearDraft(root.pendingName);
        root.pendingName = "";
        root.revertSpec = null;
        // Nothing was written, so there is nothing to take back -- this only
        // drops the snapshot that would have been.
        root.pendingSpec = null;
    }

    // Dropping a saved override. It does NOT put the screen back and it is not
    // meant to: the script writes the file and says what is left to happen,
    // which is not the same sentence on both flavors -- a reload under
    // Hyprland, nothing at all under niri except for the mode, which waits for
    // the next session. Neither the script nor this page settles it on the
    // user's behalf, because that would mean moving a monitor nobody asked to
    // move. Whatever it printed is shown verbatim under the card.
    function forget(mon: var): void {
        forgetter.command = ["desktop-monitors", "forget", mon.description ?? ""];
        root.forgetNoticeFor = mon.name;
        root.forgetNotice = "";
        forgetter.running = true;
    }

    function copyConfig(mon: var): void {
        Quickshell.execDetached(["wl-copy", HyprlandBlock.configBlock(mon, root.draftOf(mon))]);
        root.copiedFor = mon.name;
        copiedReset.restart();
    }

    // ---------------- Which monitor is the main one ----------------
    //
    // TWO SPELLINGS OF THE SAME MONITOR MEET HERE, and this page is the only
    // place that can introduce them. The shell keys its choice by model +
    // serial (Config.screenKey, off Quickshell's ShellScreen, which has no
    // description); Hyprland matches on the full EDID description, which is
    // what the compositor's config and desktop-monitors already use. Both are read
    // off the same monitor here, so neither side has to guess at the other's.
    //
    // The bridge between the two lists is the CONNECTOR, which is safe for
    // exactly this: it is unstable across kernel versions and perfectly stable
    // within one running session, and both lists are being read right now.
    // What gets STORED is the stable spelling on each side.
    function screenFor(mon: var): var {
        return Screens.all.find(screen => screen.name === (mon.name ?? "")) ?? null;
    }

    // Whether this is where the shell lives -- which is a different question
    // from whether it was CHOSEN. With nothing chosen, Screens.qml still picks
    // one, and saying "main: automatic" on it is the answer to the question
    // somebody opening this page is actually asking.
    function isMainMonitor(mon: var): bool {
        return Screens.mainName !== "" && Screens.mainName === (mon.name ?? "");
    }

    function mainChosen(mon: var): bool {
        const screen = root.screenFor(mon);
        return !!screen && Config.mainMonitor !== "" && Config.screenKey(screen) === Config.mainMonitor;
    }

    // BOTH SIDES IN ONE CLICK, because a main monitor the shell and the
    // compositor disagree about is worse than either answer on its own: the
    // bar would be on one screen and the game rules pointed at the other.
    //
    // The shell's half is immediate -- assigning the property moves the bar,
    // the launcher and the notifications as the bindings re-evaluate. The
    // compositor's half is the script's, and what it does and does not manage is
    // the script's sentence to write rather than this page's to guess at: under
    // Hyprland it rewrites the generated Lua and a reload moves the game rules,
    // and under niri it says plainly that it cannot move them at all, because
    // that would mean repeating the app-id regex those rules match on.
    function makeMain(mon: var): void {
        const screen = root.screenFor(mon);
        if (!screen)
            return;

        Config.mainMonitor = Config.screenKey(screen);

        mainSetter.command = ["desktop-monitors", "main", mon.description ?? ""];
        root.mainNoticeFor = mon.name;
        root.mainNotice = "";
        mainSetter.running = true;
    }

    // Back to Screens.qml's rule and to whatever the compositor's own config
    // says. Not the same as "no main monitor": there is always one, this only
    // stops it being pinned.
    function clearMain(mon: var): void {
        Config.mainMonitor = "";

        mainSetter.command = ["desktop-monitors", "main", "--clear"];
        root.mainNoticeFor = mon.name;
        root.mainNotice = "";
        mainSetter.running = true;
    }

    // The script's own words about what a reload will and will not change,
    // shown verbatim under the monitor they were about -- the same arrangement
    // as forgetNotice, and for the same reason: one copy of that sentence,
    // living in the script that knows it.
    property string mainNotice: ""
    property string mainNoticeFor: ""

    Process {
        id: mainSetter

        stdout: StdioCollector {
            onStreamFinished: root.mainNotice = text.trim()
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.mainNotice = text.trim();
            }
        }
    }

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

        if (!monitorQuery.running)
            monitorQuery.running = true;

        // Asked at the same moment and for the same reason: the file can have
        // been changed from a terminal since the page was last looked at --
        // desktop-monitors is a script precisely so it can be.
        if (!overrideQuery.running)
            overrideQuery.running = true;

        // WHERE that file is, asked ONCE and not on every visit: the answer
        // depends on which compositor is running, and that cannot change without
        // the shell being restarted with it.
        if (root.savedTo === "" && !fileQuery.running)
            fileQuery.running = true;

        // Which blue-light daemon, if any, this session has. Asked here rather
        // than polled or watched: the answer only changes when a package is
        // installed or a session restarts, and both of those end with a trip
        // back to this page. See the section at the bottom of this file.
        if (!nightLightProbe.running)
            nightLightProbe.running = true;

        // The forget advice belongs to the visit it was earned in. It says to
        // go and settle something outside this window, and leaving it is the
        // likeliest thing to have happened in order to do that.
        root.forgetNotice = "";
        root.forgetNoticeFor = "";
    }

    Process {
        id: monitorQuery

        // THE SHAPE THIS PAGE WAS WRITTEN AGAINST, whoever answered. The
        // script normalises: under Hyprland this is `hyprctl monitors -j`
        // passed through untouched, and under niri it is `niri msg -j outputs`
        // translated into the same fields -- an object keyed by connector name
        // turned into an array, refresh rates out of millihertz, a mode index
        // resolved into a mode, and the transform word turned back into the
        // wl_output number everything here counts in.
        command: ["desktop-monitors", "list", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn("DisplayPage: could not parse desktop-monitors list --", e.message);
                    return;
                }

                // Left to right, which is how they are arranged on the desk.
                // Neither compositor reports them that way -- Hyprland uses its
                // internal id and niri hands back an object -- and on this
                // machine either order puts the side monitor first for no reason
                // the person reading the page can see.
                root.monitors = parsed.slice().sort((a, b) => a.x - b.x || a.y - b.y);
            }
        }
    }

    Process {
        id: overrideQuery

        // Bare, which is the script's `show`. It only prints.
        command: ["desktop-monitors"]

        stdout: StdioCollector {
            onStreamFinished: root.overrides = Monitors.parseOverrides(text)
        }
    }

    Process {
        id: forgetter

        // A Process and not execDetached, unlike the write above, and the
        // difference is what the two calls leave behind. `set` leaves a file
        // and a compositor that already agree with what is on screen; `forget`
        // leaves them disagreeing on purpose, and the sentence explaining that
        // is the script's to write.
        stdout: StdioCollector {
            onStreamFinished: {
                root.forgetNotice = text.trim();
                overrideQuery.running = true;
            }
        }

        // The failure path prints in red and prints to stderr -- see `die`. An
        // empty notice under a chip that was just pressed says nothing at all,
        // so whatever it complained about is shown instead, with the colour
        // codes taken out: this is a Text item, not a terminal, and it would
        // draw them as literal "[1;31m".
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.replace(/\u001b\[[0-9;]*m/g, "").trim();
                if (message)
                    root.forgetNotice = message;
            }
        }
    }

    Process {
        id: applier

        // THE REPLY IS NOT WHAT SAYS IT WORKED, and that has not changed by
        // going through a script. `hyprctl eval` answers on stdout and exits 0
        // for a Lua error as readily as for a success, and under niri an apply
        // for a monitor that has just been unplugged is a sentence rather than a
        // failure. So nothing here branches on either stream -- they are printed
        // so a broken call leaves a trace, and the re-read below is what the page
        // actually believes.
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("DisplayPage: desktop-monitors apply said --", text.trim());
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.replace(/\u001b\[[0-9;]*m/g, "").trim();
                if (message)
                    console.warn("DisplayPage: desktop-monitors apply failed --", message);
            }
        }

        onExited: {
            if (!monitorQuery.running)
                monitorQuery.running = true;
        }
    }

    // THIS TIMER MUST SURVIVE THE PAGE BEING LOOKED AWAY FROM. It is bound to
    // `pendingName` and not to `visible`, because the case it exists for is
    // the one where the screen went black: nobody is looking at anything, the
    // window may well be behind whatever the compositor did, and the revert
    // still has to fire. A Timer is not an Item and does not stop when the
    // page it lives in is hidden.
    Timer {
        id: countdown

        interval: 1000
        repeat: true
        running: root.pendingName !== ""

        onTriggered: {
            root.secondsLeft--;
            if (root.secondsLeft <= 0)
                root.revert();
        }
    }

    Timer {
        id: copiedReset
        interval: 1600
        onTriggered: root.copiedFor = ""
    }

    // THE PRICE OF execDetached: it reports nothing back -- no exit code, no
    // completion -- so there is no signal to re-read the saved list on. Half a
    // second is far more than rewriting five lines of Lua takes, and the answer
    // is a genuine re-read rather than the spec that was sent, so the row can
    // still disagree with the page if the write went wrong. On the day it loses
    // that race, Re-read asks again.
    Timer {
        id: overrideSettle
        interval: 500
        onTriggered: overrideQuery.running = true
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
    // THE PATH IS ASKED FOR RATHER THAN WRITTEN DOWN, and that is the whole
    // reason there is a `file` subcommand at all. It is monitors.lua on one
    // flavor and monitors.kdl on another, and a settings window naming the wrong
    // file is worse than one naming none: somebody goes looking for it, does not
    // find it, and concludes the setting was never saved. Until the answer
    // arrives the line simply says less.
    property string savedTo: ""

    Process {
        id: fileQuery

        command: ["desktop-monitors", "file"]

        stdout: StdioCollector {
            onStreamFinished: root.savedTo = text.trim()
        }
    }

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
            text: root.savedTo === ""
                ? "Kept changes are written to a generated file, read back on every reload."
                : `Kept changes are saved to ${root.savedTo} — generated, read back on every reload.`
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
            enabled: !monitorQuery.running && !overrideQuery.running
            // BOTH READINGS, because both can be behind: the compositor's if
            // something moved a monitor from elsewhere, and the saved list if a
            // write landed after the page last looked. This chip is the way to
            // catch up on either without closing the window.
            onActivated: {
                monitorQuery.running = true;
                overrideQuery.running = true;
            }
        }
    }

    // ---------------- Night light ----------------
    //
    // ON THIS PAGE AND NOT ON APPEARANCE, which is where a colour setting
    // would normally go. What this changes is not how the shell is drawn --
    // it is a matrix applied to the whole output, below every window, by the
    // compositor. It belongs with the other things that are true of the
    // screen rather than with the things that are true of the desktop.
    //
    // The state and the schedule both live in NightLight.qml; this section
    // only draws them. See its header for why the schedule is the shell's job
    // and the filter is not.
    // ---------------- Arranging the monitors ----------------
    //
    // WHERE EACH SCREEN IS RELATIVE TO THE OTHERS, dragged on a map rather
    // than typed as coordinates. The header above used to refuse this outright,
    // on the grounds that moving one monitor rearranges the desktop under every
    // window and undoing that is a second monitor's problem -- and that
    // argument does not survive contact with the actual failure: a position is
    // not a mode. Every screen keeps drawing whatever happens, the mistake is
    // visible the moment the pointer refuses to cross where you expected, and
    // the countdown below undoes it in the same ten seconds a mode change
    // gets. What made it worth reversing is that this is precisely the setting
    // nobody can compute in their head: "1080x240" is a fact about a portrait
    // panel's height and half the difference between two monitors, and typing
    // it is not how anyone thinks about which screen is on the left.
    //
    // THE MAP IS THE DRAFT. Dragging writes logical coordinates into
    // arrangeDraft and nothing reaches the compositor until Apply, which is
    // the same shape the mode controls use -- and the reason the rectangles
    // move under the pointer while nothing on the desk does.
    //
    // SEPARATE PENDING STATE FROM THE MODE CHANGES, not a generalisation of
    // it. That state is one monitor, one spec, one revert, and it is the code
    // path that can leave somebody looking at a black screen; growing it into
    // a list to carry this feature would have put an arrangement's weight on
    // the one part of this page that must not be wrong. The two lock each
    // other out instead: this section is disabled while a mode is waiting to
    // be confirmed, and every monitor card is locked while an arrangement is.
    property var arrangeDraft: ({})

    // The specs that went out, with what they replaced, so the countdown has
    // something to put back. Null when nothing is provisional.
    property var arrangePending: null
    property int arrangeSeconds: 0

    // WHAT THE MONITOR TAKES UP ON THE DESKTOP, which is not `width` and
    // `height`. Those are the mode -- the pixels the panel is being driven at
    // -- and the desktop is laid out in logical pixels: the mode divided by
    // the scale, and then TURNED ON ITS SIDE for an odd transform. The
    // secondary panel here is a 1920x1080 mode at transform 3, which occupies
    // 1080x1920, and that 1080 is where the main monitor's x = 1080 comes
    // from. Get this wrong and every rectangle on the map is the right size
    // for a screen nobody has.
    function logicalSize(mon: var): var {
        const scale = (mon.scale ?? 1) || 1;
        const w = (mon.width ?? 0) / scale;
        const h = (mon.height ?? 0) / scale;

        return ((mon.transform ?? 0) % 2) === 1 ? { w: h, h: w } : { w: w, h: h };
    }

    function arrangedPosition(mon: var): var {
        return root.arrangeDraft[mon.name] ?? { x: mon.x ?? 0, y: mon.y ?? 0 };
    }

    // A NEW OBJECT, for the reason setDraft gives above: assigning into the
    // map in place emits no change signal and the map would move nothing.
    function setArranged(name: string, x: real, y: real): void {
        const next = Object.assign({}, root.arrangeDraft);
        next[name] = { x: Math.round(x), y: Math.round(y) };
        root.arrangeDraft = next;
    }

    readonly property bool arrangeDirty: {
        for (const mon of root.monitors) {
            const at = root.arrangedPosition(mon);
            if (at.x !== (mon.x ?? 0) || at.y !== (mon.y ?? 0))
                return true;
        }
        return false;
    }

    // Two screens claiming the same desktop coordinates. Neither compositor
    // refuses it and it is occasionally even deliberate, so this warns rather
    // than refuses -- but it is almost always a drag that was let go early, and the
    // symptom (a pointer that vanishes into a region drawn twice) is not one
    // anybody diagnoses from the desk.
    readonly property bool arrangeOverlaps: {
        const all = root.monitors;

        for (let i = 0; i < all.length; i++) {
            for (let j = i + 1; j < all.length; j++) {
                const a = root.arrangedPosition(all[i]);
                const as = root.logicalSize(all[i]);
                const b = root.arrangedPosition(all[j]);
                const bs = root.logicalSize(all[j]);

                if (a.x < b.x + bs.w && b.x < a.x + as.w
                    && a.y < b.y + bs.h && b.y < a.y + as.h)
                    return true;
            }
        }

        return false;
    }

    // Edge magnetism, and it is what makes this usable with a mouse: the
    // difference between "next to" and "next to, give or take four pixels" is
    // invisible on a map two hundred pixels wide and is a four-pixel dead
    // stripe the pointer cannot cross on the desk.
    //
    // Four candidates per axis per neighbour -- flush after it, flush before
    // it, and the two ways of lining up an edge -- and the nearest one inside
    // the tolerance wins. The tolerance is given in LOGICAL pixels by the
    // caller, converted from a distance in map pixels, so it means the same
    // thing on screen whatever the zoom.
    function snapPosition(mon: var, x: real, y: real, tolerance: real): var {
        const size = root.logicalSize(mon);

        let bestX = x;
        let bestY = y;
        let nearestX = tolerance;
        let nearestY = tolerance;

        for (const other of root.monitors) {
            if (other.name === mon.name)
                continue;

            const at = root.arrangedPosition(other);
            const os = root.logicalSize(other);

            for (const candidate of [at.x + os.w, at.x - size.w, at.x, at.x + os.w - size.w]) {
                const distance = Math.abs(candidate - x);
                if (distance < nearestX) {
                    nearestX = distance;
                    bestX = candidate;
                }
            }

            for (const candidate of [at.y + os.h, at.y - size.h, at.y, at.y + os.h - size.h]) {
                const distance = Math.abs(candidate - y);
                if (distance < nearestY) {
                    nearestY = distance;
                    bestY = candidate;
                }
            }
        }

        return { x: bestX, y: bestY };
    }

    // The whole layout pulled back so its top-left corner is 0,0.
    //
    // Both compositors take negative coordinates and this is not about either
    // refusing them. It is about the numbers a person reads afterwards: the
    // monitor block in the hand-written config, the Position row on every card
    // and every example in either wiki are written from an origin, and a desktop
    // whose left edge is at -1080 makes every one of those a subtraction. Run after each drag, so the
    // origin is a consequence of the arrangement rather than of which monitor
    // happened to be dragged.
    function normaliseArrangement(): void {
        let minX = Infinity;
        let minY = Infinity;

        for (const mon of root.monitors) {
            const at = root.arrangedPosition(mon);
            minX = Math.min(minX, at.x);
            minY = Math.min(minY, at.y);
        }

        if (!isFinite(minX) || !isFinite(minY) || (minX === 0 && minY === 0))
            return;

        const next = ({});
        for (const mon of root.monitors) {
            const at = root.arrangedPosition(mon);
            next[mon.name] = { x: at.x - minX, y: at.y - minY };
        }

        root.arrangeDraft = next;
    }

    // Only the ones that actually moved. Normalising can shift every monitor
    // at once, and it can equally shift them all back to where they already
    // were -- the compositor is told about the difference, not about the
    // operation.
    //
    // Built on specOf and NOT on draftOf: an unapplied mode sitting in the
    // other draft belongs to the button that was not pressed, and smuggling it
    // out with a position would apply a mode change nobody confirmed.
    function arrangementSpecs(): var {
        const specs = [];

        for (const mon of root.monitors) {
            const at = root.arrangedPosition(mon);
            if (at.x === (mon.x ?? 0) && at.y === (mon.y ?? 0))
                continue;

            specs.push({
                spec: Object.assign({}, Monitors.specOf(mon), { position: `${at.x}x${at.y}` }),
                revert: Monitors.specOf(mon)
            });
        }

        return specs;
    }

    // ONE CALL FOR THE WHOLE ARRANGEMENT, and this is not tidiness. Moving two
    // monitors in two commands means a moment where the first has moved and the
    // second has not, which for a layout that ends up correct is a flash of one
    // that overlaps -- and every window on the desktop is re-laid out for both
    // of them. So `apply` takes any number of specs, five arguments each, and
    // the script decides how atomic it can make them: Hyprland gets one eval
    // holding several hl.monitor calls, niri gets them back to back over its
    // socket, which is as close as it has.
    //
    // Named for what it does rather than for how it used to do it -- there is no
    // eval in this file any more.
    function applyArrangement_(specs: var): void {
        let args = ["desktop-monitors", "apply"];
        for (const spec of specs)
            args = args.concat(Monitors.specArgs(spec));

        arranger.command = args;
        arranger.running = true;
    }

    function applyArrangement(): void {
        const specs = root.arrangementSpecs();
        if (specs.length === 0)
            return;

        root.arrangePending = specs;
        root.arrangeSeconds = root.revertAfter;
        root.applyArrangement_(specs.map(entry => entry.spec));
    }

    function keepArrangement(): void {
        if (!root.arrangePending)
            return;

        // Written one at a time, waiting for each. `desktop-monitors set` reads
        // the whole state file, edits one record and writes it back, so two
        // copies started together would each save what they read before the
        // other wrote -- and the second monitor's position would land in a
        // file that had already forgotten the first's.
        root.persistQueue = root.arrangePending.map(entry => entry.spec);
        root.arrangePending = null;
        root.arrangeDraft = ({});
        root.pumpPersist();
    }

    function revertArrangement(): void {
        if (!root.arrangePending)
            return;

        const back = root.arrangePending.map(entry => entry.revert);
        root.arrangePending = null;
        root.arrangeDraft = ({});
        root.applyArrangement_(back);
    }

    property var persistQueue: []

    function pumpPersist(): void {
        if (persister.running)
            return;

        if (root.persistQueue.length === 0) {
            overrideSettle.restart();
            return;
        }

        const head = root.persistQueue[0];
        root.persistQueue = root.persistQueue.slice(1);

        persister.command = ["desktop-monitors", "set"].concat(Monitors.specArgs(head));
        persister.running = true;
    }

    Process {
        id: arranger

        onExited: {
            if (!monitorQuery.running)
                monitorQuery.running = true;
        }
    }

    // A Process and not execDetached, unlike the mode path's persist: this one
    // has a queue behind it and the next write cannot start until this one has
    // finished. See keepArrangement.
    Process {
        id: persister

        onExited: root.pumpPersist()
    }

    // Bound to the pending state and not to `visible`, for the reason the
    // other countdown gives: the whole point of a revert is that it fires
    // whether or not anybody is still looking at this page.
    Timer {
        id: arrangeCountdown

        interval: 1000
        repeat: true
        running: root.arrangePending !== null

        onTriggered: {
            root.arrangeSeconds--;
            if (root.arrangeSeconds <= 0)
                root.revertArrangement();
        }
    }

    SettingsSection {
        // Nothing to arrange with one screen: its position is 0,0 and the map
        // would be a single rectangle that cannot be dragged anywhere.
        visible: root.monitors.length > 1

        width: root.width
        glyph: Icons.monitor
        title: "Arrangement"

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Drag a screen to say where it sits. Edges snap to the "
                + "neighbours they are near, and nothing reaches the "
                + "compositor until Apply."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Rectangle {
            id: map

            // The margin around the desktop's own bounding box, in logical
            // pixels, so there is somewhere to drag a monitor TO. Without it
            // the map is exactly the size of the current layout and pulling a
            // screen out to the right walks it off the edge of its own canvas.
            readonly property int margin: 600

            // Frozen for the duration of a drag. The bounding box grows as a
            // monitor is pulled outwards, the scale would shrink to keep it in
            // view, and everything on the map -- including the rectangle under
            // the pointer -- would slide away from the mouse while it is being
            // held. One drag, one scale.
            property var frozen: null

            readonly property var bounds: {
                if (map.frozen)
                    return map.frozen;

                let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

                for (const mon of root.monitors) {
                    const at = root.arrangedPosition(mon);
                    const size = root.logicalSize(mon);
                    minX = Math.min(minX, at.x);
                    minY = Math.min(minY, at.y);
                    maxX = Math.max(maxX, at.x + size.w);
                    maxY = Math.max(maxY, at.y + size.h);
                }

                if (!isFinite(minX))
                    return { x: 0, y: 0, w: 1920, h: 1080 };

                return {
                    x: minX - map.margin,
                    y: minY - map.margin,
                    w: (maxX - minX) + map.margin * 2,
                    h: (maxY - minY) + map.margin * 2
                };
            }

            // Fit, never fill: the same number on both axes, or the desktop's
            // proportions would be a lie and a portrait monitor would draw as
            // a square.
            readonly property real factor: Math.min(map.width / map.bounds.w,
                                                    map.height / map.bounds.h)

            readonly property real offsetX: (map.width - map.bounds.w * map.factor) / 2
            readonly property real offsetY: (map.height - map.bounds.h * map.factor) / 2

            function toMapX(logical: real): real {
                return (logical - map.bounds.x) * map.factor + map.offsetX;
            }

            function toMapY(logical: real): real {
                return (logical - map.bounds.y) * map.factor + map.offsetY;
            }

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            height: 240

            radius: Theme.groupRadius
            color: Qt.alpha(Theme.surfaceContainerHighest, 0.4)

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            // Off to the pointer while a MODE change is waiting to be
            // confirmed. Two provisional changes to the same monitors, each
            // with its own countdown, is a state with no honest way back --
            // the same rule the cards apply to each other.
            opacity: root.pendingName !== "" ? 0.4 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Repeater {
                model: root.monitors

                delegate: Rectangle {
                    id: screen

                    required property var modelData

                    readonly property var at: root.arrangedPosition(screen.modelData)
                    readonly property var logical: root.logicalSize(screen.modelData)
                    readonly property bool moved: screen.at.x !== (screen.modelData.x ?? 0)
                        || screen.at.y !== (screen.modelData.y ?? 0)

                    x: map.toMapX(screen.at.x)
                    y: map.toMapY(screen.at.y)
                    width: Math.max(8, screen.logical.w * map.factor)
                    height: Math.max(8, screen.logical.h * map.factor)

                    radius: 6

                    // The one being dragged leads in the accent, the ones that
                    // have moved since the last apply are tinted, and the rest
                    // are plain. Three states because they answer three
                    // different questions, and the middle one is the only way
                    // to see what Apply is about to send.
                    color: dragArea.pressed || screen.moved
                        ? Qt.alpha(Theme.primary, 0.28)
                        : Theme.surfaceContainerHigh

                    border.width: screen.modelData.focused ? 2 : 1
                    border.color: dragArea.pressed || screen.moved
                        ? Theme.primary
                        : Theme.outlineVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screen.modelData.name ?? ""
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // The logical size and not the mode, because that is
                        // what the rectangle is drawn from: a rotated 1080p
                        // panel reads 1080 × 1920 here and the number matches
                        // the shape it is written on.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: screen.height > 44
                            text: `${Math.round(screen.logical.w)} × ${Math.round(screen.logical.h)}`
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 2
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }

                    // NO drag.target, which is the obvious way to write this
                    // and the wrong one here. Handing the rectangle to the
                    // dragger assigns straight to x and y, which DESTROYS the
                    // bindings above -- the map would then be showing a
                    // position the draft does not hold, and the next re-read
                    // would leave it there. The pointer is followed by hand
                    // instead and the answer goes into the draft, so the
                    // rectangle is always drawn from the model.
                    MouseArea {
                        id: dragArea

                        property real originX: 0
                        property real originY: 0
                        property real grabX: 0
                        property real grabY: 0

                        anchors.fill: parent
                        enabled: root.pendingName === "" && root.arrangePending === null
                        cursorShape: dragArea.enabled
                            ? (dragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                            : Qt.ArrowCursor

                        onPressed: mouse => {
                            const point = dragArea.mapToItem(map, mouse.x, mouse.y);
                            dragArea.grabX = point.x;
                            dragArea.grabY = point.y;
                            dragArea.originX = screen.at.x;
                            dragArea.originY = screen.at.y;
                            map.frozen = map.bounds;
                        }

                        onPositionChanged: mouse => {
                            if (!dragArea.pressed)
                                return;

                            // In MAP coordinates and not this item's: the item
                            // is what is moving, so a delta measured inside it
                            // is measured against a frame that has already
                            // shifted by the same amount -- the rectangle
                            // would crawl at half speed and then stop.
                            const point = dragArea.mapToItem(map, mouse.x, mouse.y);
                            const wantX = dragArea.originX + (point.x - dragArea.grabX) / map.factor;
                            const wantY = dragArea.originY + (point.y - dragArea.grabY) / map.factor;

                            // Twelve map pixels' worth, whatever that is in
                            // logical ones at this zoom.
                            const snapped = root.snapPosition(screen.modelData, wantX, wantY,
                                12 / map.factor);

                            root.setArranged(screen.modelData.name, snapped.x, snapped.y);
                        }

                        onReleased: {
                            root.normaliseArrangement();
                            map.frozen = null;
                        }

                        onCanceled: {
                            map.frozen = null;
                        }
                    }
                }
            }
        }

        Text {
            visible: root.arrangeOverlaps

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 6

            text: "Two screens are on top of each other. Neither compositor "
                + "refuses it, but the overlapping strip is drawn by both and "
                + "the pointer behaves as though one of them is not there."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The buttons, and the banner that replaces them once something is
        // provisional. Same grammar as the monitor cards below: Apply while
        // there is a difference, then a question with a countdown on it.
        Item {
            width: parent.width
            implicitHeight: 44
            visible: root.arrangeDirty || root.arrangePending !== null

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.itemSpacing

                visible: root.arrangePending !== null

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
                    text: `Keep this arrangement? Reverting in ${root.arrangeSeconds}s`
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

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending !== null
                    label: "Keep"
                    glyph: Glyphs.contentSave
                    filled: true
                    onActivated: root.keepArrangement()
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending !== null
                    label: "Revert now"
                    onActivated: root.revertArrangement()
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending === null
                    label: "Reset"
                    enabled: root.arrangeDirty
                    onActivated: root.arrangeDraft = ({})
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending === null
                    label: "Apply"
                    filled: true
                    enabled: root.arrangeDirty && root.pendingName === ""
                    onActivated: root.applyArrangement()
                }
            }
        }
    }

    SettingsSection {
        width: root.width
        glyph: Icons.nightLight
        title: "Night light"

        // FIRST, AND ONLY WHEN IT IS TRUE. Everything below this line is a
        // control that silently does nothing without a daemon, and a page full
        // of switches that do nothing is a worse bug than a missing feature --
        // the user concludes the setting is broken rather than absent.
        //
        // WHICH DAEMON IS NOT THIS PAGE'S BUSINESS, and that is why the sentence
        // is built around what the script answered rather than naming one.
        // `night-light` picks one per session -- hyprsunset under Hyprland,
        // wl-gammarelay-rs under niri -- and naming the wrong one is how a
        // person spends an evening trying to start a service that was never
        // going to help.
        Text {
            visible: !root.nightLightAvailable

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Nothing below will reach the screen: this session has no blue-light "
                + "daemon. Hyprland uses hyprsunset and niri uses wl-gammarelay-rs; "
                + "`night-light show` says which one it looked for and what it found."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.nightLight
            label: "Warm the screen"
            checked: NightLight.enabled
            // Off to the pointer while the schedule owns it. Not hidden: the
            // switch is still the clearest statement of whether the filter is
            // on right now, and watching it move at 20:00 is how you find out
            // the schedule works.
            enabled: !NightLight.scheduled && root.nightLightAvailable

            onToggled: value => NightLight.setEnabled(value)
        }

        Text {
            visible: NightLight.scheduled

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 4

            text: "The schedule below is driving this."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        StepperRow {
            glyph: Icons.palette
            label: "Temperature"
            value: NightLight.temperature
            from: NightLight.minTemperature
            to: NightLight.maxTemperature
            step: 100
            suffix: "K"
            enabled: root.nightLightAvailable
            hint: "Lower is warmer. 6000K is roughly daylight and is where the "
                + "screen sits with no filter at all, which is why the range "
                + "stops there — the top of the scale and the switch above "
                + "would otherwise mean the same thing."

            onMoved: value => NightLight.setTemperature(value)
        }

        ToggleRow {
            glyph: Icons.clock
            label: "Turn on automatically"
            checked: NightLight.scheduled
            enabled: root.nightLightAvailable

            onToggled: value => NightLight.setScheduled(value)
        }

        // HALF HOURS, and the value behind them is minutes since midnight --
        // see the note on `display` in StepperRow.qml. Anything finer is a
        // precision nobody has an opinion about: the difference between 20:15
        // and 20:30 for a blue light filter is not a difference.
        StepperRow {
            glyph: Icons.nightLight
            label: "From"
            value: NightLight.from
            from: 0
            to: 23 * 60 + 30
            step: 30
            display: NightLight.clockText(NightLight.from)
            enabled: NightLight.scheduled && root.nightLightAvailable

            onMoved: value => NightLight.setFrom(value)
        }

        StepperRow {
            glyph: Icons.clock
            label: "To"
            value: NightLight.to
            from: 0
            to: 23 * 60 + 30
            step: 30
            display: NightLight.clockText(NightLight.to)
            enabled: NightLight.scheduled && root.nightLightAvailable
            hint: "An end earlier than the start is the normal case, not a "
                + "mistake: 20:00 to 07:00 is the two ends of the day rather "
                + "than the middle of it, and that is what this reads it as."

            onMoved: value => NightLight.setTo(value)
        }
    }

    // Whether there is a daemon to talk to at all, asked when the page is looked
    // at rather than polled. The same argument the Wi-Fi scanner makes: every
    // page in this window is built and alive, so `visible` is the only honest
    // signal that somebody is reading this one.
    //
    // It is asked ONCE per visit and not watched, because the answer only
    // changes when a person installs a package or a session restarts -- and
    // both of those end with a trip back to this page. Asked from the page's
    // single onVisibleChanged handler further up, next to the monitor queries --
    // QML allows one handler per signal, and a second `onVisibleChanged` here is
    // not an override but an error.
    //
    // OPTIMISTIC UNTIL THE ANSWER ARRIVES, deliberately: the probe takes a
    // moment and controls that flash from dead to alive on every visit read as a
    // page that is broken and then recovers.
    property bool nightLightAvailable: true

    // ---------------- One section per connected monitor ----------------
    Repeater {
        model: root.monitors

        SettingsSection {
            id: card

            required property var modelData

            readonly property var mon: card.modelData
            readonly property var spec: root.draftOf(card.mon)
            readonly property bool dirty: root.isDirty(card.mon)
            readonly property bool pending: root.pendingName === card.mon.name
            // Locked while ANY monitor is waiting to be confirmed, not only
            // this one. Stacking a second provisional change on top of one
            // that may be about to undo itself is a state with no honest way
            // back.
            // ANY provisional change, not only a mode one: an arrangement is
            // also waiting on a countdown and also about to be undone, and
            // stacking a mode change on top of one is the state this lock
            // exists to make impossible.
            readonly property bool locked: root.pendingName !== "" || root.arrangePending !== null
            // null when this monitor has nothing saved, which is the state
            // every monitor is in until somebody keeps a change.
            readonly property var saved: root.savedOf(card.mon)

            readonly property bool isMain: root.isMainMonitor(card.mon)
            readonly property bool mainIsChosen: root.mainChosen(card.mon)

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
                    root.setDraft(card.mon, { mode: modes[next] });
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
                    root.setDraft(card.mon, { scale: scales[next] });
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
                            onActivated: root.setDraft(card.mon, { transform: modelData.transform })
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
                        onActivated: root.commit(card.mon)
                    }

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Discard"
                        glyph: Icons.close
                        enabled: card.dirty && !card.locked
                        onActivated: root.clearDraft(card.mon.name)
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
                        label: root.copiedFor === card.mon.name ? "Copied" : "Copy config"
                        glyph: root.copiedFor === card.mon.name ? Glyphs.check : Icons.clipboard
                        onActivated: root.copyConfig(card.mon)
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
                        enabled: !mainSetter.running && (card.mainIsChosen || !card.isMain || Config.mainMonitor !== "")
                        onActivated: card.mainIsChosen ? root.clearMain(card.mon) : root.makeMain(card.mon)
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
                        enabled: !card.locked && !forgetter.running
                        onActivated: root.forget(card.mon)
                    }
                }
            }

            // What the main-monitor write left behind, in the script's words.
            // The shell half of that click is already visible -- the bar moved
            // as it was pressed -- so anything worth printing here is about the
            // compositor half, which is the half that may be waiting on a
            // reload.
            Text {
                visible: root.mainNoticeFor === card.mon.name && root.mainNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: root.mainNotice
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
                visible: root.forgetNoticeFor === card.mon.name && root.forgetNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: root.forgetNotice
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
                        text: `Keep this display setting? Reverting in ${root.secondsLeft}s`
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
                        onActivated: root.keep()
                    }

                    // The same thing the timer is about to do, for when you
                    // can already see it is wrong and would rather not sit
                    // through the countdown.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Revert now"
                        onActivated: root.revert()
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
        visible: root.monitors.length === 0
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

    Process {
        id: nightLightProbe

        // THE SCRIPT IS ASKED, and not the process table. It used to be `pgrep
        // -x hyprsunset`, which is wrong twice over now: it names one flavor's
        // daemon, and the other one's cannot be pgrep'd at all -- the name
        // wl-gammarelay-rs is 16 characters, the kernel caps comm at 15, and
        // pgrep answers zero matches rather than an error. `night-light show`
        // already knows: it prints the backend it chose for this session and
        // whether that daemon is up.
        //
        // A BACKEND OF `none` IS THE ONLY HARD NO. Both daemons are started on
        // demand by the script, so "not running" is a state it fixes on the
        // first toggle rather than a reason to grey the controls out.
        command: ["night-light", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const backend = /^backend:\s+(\S+)$/m.exec(text);
                root.nightLightAvailable = !!backend && backend[1] !== "none";
            }
        }
    }
}
