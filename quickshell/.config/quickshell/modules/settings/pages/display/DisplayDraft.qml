// The half of the display page that is a QUESTION rather than an answer: what
// each monitor WOULD be, what was actually sent to the compositor, and the ten
// seconds somebody has to say they can still see the screen.
//
// AT PAGE LEVEL AND NOT IN THE CARDS, which is why this is an object of its own
// and not state inside a delegate. `source.monitors` is replaced whole on every
// re-read, which destroys every card and everything inside one. A half-made
// choice of mode living in the row would vanish the moment anything re-read the
// compositor -- including the re-read that this page's own apply triggers. Same
// reasoning as the password state in NetworkPage.
//
// THE REVERT TIMER IS THE POINT OF IT, not a nicety on top. A mode the panel
// cannot display leaves a black screen, and the window holding the undo button
// is on that screen. So an apply is provisional: the spec that was live is
// kept, a countdown starts, and unless it is confirmed the compositor is put
// back where it was. The confirmation is the thing you have to do; doing
// nothing is safe. That is the opposite way round from every other button in
// this shell, and it is deliberate.
//
// IT HOLDS A MonitorSource RATHER THAN SIGNALLING AT ONE, and that is the
// honest shape: every one of the three things this file does to the compositor
// has to be followed by a re-read, because what the compositor DID with the
// spec is a different fact from what it was asked for. Wiring that back through
// the page as three signals would put four lines between each cause and its
// effect and leave the comment explaining it in a third place.
//
// A Scope and not an Item, for the reason MonitorSource gives.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Scope {
    id: root

    // Where the readings come from, and where every change made here has to be
    // read back afterwards.
    required property MonitorSource source

    // How long a provisional change has to be confirmed. The page sets it,
    // because the arrangement's countdown is the same number and neither of
    // them owns it.
    required property int revertAfter

    // ---------------- The draft, keyed by connector ----------------
    //
    // Keyed by connector name and not by index: the array is sorted by
    // position, so an index is not stable, and the name is at least stable for
    // as long as the page is open. (It is NOT stable across kernels, which is
    // exactly why HyprlandBlock.qml's Lua matches on desc: instead.)
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

    // The monitor whose Copy button was pressed, so the chip can say it
    // worked. wl-copy is fire-and-forget -- there is no completion to wait on
    // -- so this is optimistic by construction.
    property string copiedFor: ""

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
        root.source.dropForgetNotice();
        root.applySpec(root.pendingSpec);
    }

    // Writing it down is a separate act from applying it, and this is the half
    // that lasts. `set` rewrites the generated file and hands the spec to the
    // compositor as well.
    function persist(spec: var): void {
        Quickshell.execDetached(["desktop-monitors", "set"].concat(Monitors.specArgs(spec)));
        root.source.settleOverrides();
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

    function copyConfig(mon: var): void {
        Quickshell.execDetached(["wl-copy", HyprlandBlock.configBlock(mon, root.draftOf(mon))]);
        root.copiedFor = mon.name;
        copiedReset.restart();
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

        onExited: root.source.reload()
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
}
