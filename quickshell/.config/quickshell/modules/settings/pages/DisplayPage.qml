// The display page: what each monitor is, and the three things about it that
// are worth changing from a settings window.
//
// WHAT A CONFIRMED CHANGE IS WRITTEN INTO, because it is neither this file nor
// hyprland.lua. Hyprland is configured in Lua on this machine and `hyprctl
// reload` re-runs hyprland.lua, so everything this page eval'd used to be
// thrown away the moment it did -- the page could apply and hand over a block
// to paste, and nothing else. It no longer stops there. ~/.local/bin/hypr-
// monitor keeps a SECOND file, generated and untracked:
//
//     ~/.config/hypr/monitors.lua
//
// hyprland.lua ends its monitor section with a pcall(dofile) of it, so a
// reload re-runs the hand-written block and then these overrides on top, and
// later hl.monitor calls for the same output win. Measured, not assumed: an
// override set to 120 Hz on the secondary panel was still 120 Hz after
// `hyprctl reload`, and the hand-written block came through untouched.
//
// WHY IT STILL DOES NOT WRITE hyprland.lua. That file is a stow symlink into a
// git repo and nearly a thousand lines of hand-written commentary, in an order
// a person chose. A settings window that edited it would be a program
// rewriting prose it cannot read: the first change would move the monitor
// block, or drop the comment explaining why these monitors are matched by
// description and not by connector name, or both -- and the diff would land in
// git looking like something a human did. A generated file applied on top is
// the honest boundary. The shell owns monitors.lua; the person owns
// hyprland.lua, and Copy config is how a value crosses from one to the other
// by hand.
//
// HOW IT TALKS TO THE COMPOSITOR, and this is not the usual answer.
// `hyprctl keyword` does not work on this machine at all, and it fails in the
// worst possible way:
//
//     $ hyprctl keyword nonexistent:foo 1
//     keyword can't work with non-legacy parsers. Use eval.
//     $ echo $?
//     0
//
// It refuses, and it EXITS 0 WHILE REFUSING, so anything that checks the exit
// status is told the change went through. `hyprctl setprop` answers "unknown
// request". The one door that opens is `hyprctl eval '<lua>'`, where hl.monitor
// is the same live function the config calls -- checked, not assumed:
// `hyprctl repl 'return tostring(hl.monitor)'` answers "function: 0x...".
// That is why every apply below is a line of Lua rather than a keyword.
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
// WHAT IT DELIBERATELY WILL NOT DO: turn a monitor off. `hyprctl monitors -j`
// lists the enabled ones only, so a monitor disabled from here could not be
// listed again to be switched back on -- the revert timer would be the only
// way out of it, and a safety net is not a design. Position is read and shown
// but not edited for a related reason: moving one monitor rearranges the
// desktop under every window, and undoing that is a second monitor's problem.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Display"
    glyph: Icons.monitor
    keywords: ["monitor", "screen", "display", "resolution", "refresh", "hz",
        "scale", "scaling", "rotation", "rotate", "portrait", "landscape",
        "mode", "hyprland"]

    // ---------------- Glyphs that are not in Icons yet ----------------
    //
    // TEMPORARY, and they belong in Icons.qml -- they are here only because
    // that file is being edited elsewhere right now. Move them when it is
    // free; the codepoints should not change on the way.
    //
    // All of them were read out of the installed font's cmap rather than
    // looked up by name, which is the rule Icons.qml's own comments set after
    // two of its entries turned out to draw a bluetooth speaker and a shower
    // head:
    //
    //   python3 -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap()[0xF014D])"
    //
    // AND THAT CHECK CAUGHT A THIRD ONE. Icons.clipboard is 0xF0385, which its
    // comment calls nf-md-clipboard_text; in the font installed here 0xF0385
    // is md-MUSIC_BOX_OUTLINE. md-clipboard_text is 0xF014D. So the copy
    // action below uses the local one rather than Icons.clipboard, and the day
    // Icons.qml is free that entry needs correcting -- the launcher's
    // clipboard mode is drawing a music box today.
    readonly property string clipboardText: String.fromCodePoint(0xF014D)   // nf-md-clipboard_text
    readonly property string chevronLeft: String.fromCodePoint(0xF0141)     // nf-md-chevron_left
    readonly property string check: String.fromCodePoint(0xF012C)           // nf-md-check
    readonly property string screenRotation: String.fromCodePoint(0xF0475)  // nf-md-screen_rotation
    readonly property string relativeScale: String.fromCodePoint(0xF0452)   // nf-md-relative_scale
    readonly property string arrowExpand: String.fromCodePoint(0xF0616)     // nf-md-arrow_expand
    readonly property string timerSand: String.fromCodePoint(0xF051F)       // nf-md-timer_sand
    // For the Keep button, which used to carry a tick. A tick said "yes, this
    // is fine" and the button now also writes the change to disk, so it says so
    // -- read out of the cmap like the rest: 0xF0193 is md-content_save. The
    // undo of it did NOT need adding, because Icons.restore is already 0xF099B,
    // md-restore; the Forget chip uses that rather than an eighth local.
    readonly property string contentSave: String.fromCodePoint(0xF0193)     // nf-md-content_save

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
    // rewrites; this is a snapshot of the exact four values hyprctl was given,
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

    // ---------------- What is saved, as hypr-monitor reports it ----------------
    //
    // KEYED BY DESCRIPTION, not by connector name, because that is the key the
    // script and hyprland.lua both use: the EDID string, which does not change
    // when a kernel renames DP-4 to DP-3. Two identical panels would collide
    // here, and they would collide in hyprland.lua first -- this page does not
    // invent a way out of a limitation the config already has.
    //
    // A READING like `monitors`, and it is read back after every write rather
    // than assumed from what was written. The saved value and the live value
    // are different facts and the page shows both: they disagree the moment
    // anything changes a mode without saving it.
    property var overrides: ({})

    // The last thing `hypr-monitor forget` printed, and which monitor's row it
    // belongs under. Held rather than re-typed: the sentence about running
    // `hyprctl reload` is the script's, and a second copy of it in QML is a
    // copy that goes out of step.
    property string forgetNotice: ""
    property string forgetNoticeFor: ""

    // ---------------- Reading a monitor ----------------

    // The mode string in the form hl.monitor takes: "2560x1440@165.00", no
    // trailing "Hz". availableModes carries the Hz, so both sides are
    // normalised to this shape and only put back for display.
    function modeOf(mon: var): string {
        return `${mon.width}x${mon.height}@${(mon.refreshRate ?? 0).toFixed(2)}`;
    }

    function parseMode(mode: string): var {
        const parts = /^(\d+)x(\d+)@([\d.]+)$/.exec(mode);
        if (!parts)
            return { w: 0, h: 0, hz: 0 };
        return { w: parseInt(parts[1]), h: parseInt(parts[2]), hz: parseFloat(parts[3]) };
    }

    function modeLabel(mode: string): string {
        const m = root.parseMode(mode);
        // Whole refresh rates lose the decimals: "165 Hz" is what the monitor
        // is sold as, and "165.00 Hz" reads like a measurement of something.
        const hz = m.hz % 1 === 0 ? m.hz.toFixed(0) : m.hz.toFixed(2);
        return `${m.w} × ${m.h} · ${hz} Hz`;
    }

    // TWO THINGS HAPPEN HERE and both matter.
    //
    // The current mode is added if the list does not already contain it. It
    // normally does -- 165.00101 and 164.99899 both round to the 165.00 the
    // compositor prints in availableModes, which is why the rounding above is
    // to two places and not to one or to none -- but a monitor running a mode
    // that is not in its own EDID list would otherwise start the cycle
    // somewhere it was never at.
    //
    // And the list is sorted, because hyprctl reports it in EDID order, which
    // here starts the main panel at 59.95 Hz and buries 165 in the middle.
    // Stepping through that feels like the button is broken.
    function modeList(mon: var): var {
        const modes = (mon.availableModes ?? []).map(m => m.replace(/Hz$/, ""));
        const current = root.modeOf(mon);

        if (!modes.includes(current))
            modes.push(current);

        return modes.sort((a, b) => {
            const pa = root.parseMode(a);
            const pb = root.parseMode(b);
            if (pa.w * pa.h !== pb.w * pb.h)
                return pb.w * pb.h - pa.w * pa.h;
            return pb.hz - pa.hz;
        });
    }

    // The scales worth offering. Not a continuous range: Hyprland has to end
    // up with a whole number of pixels, and it rejects or quietly nudges a
    // scale that does not divide the mode cleanly. These are the quarters
    // everything else uses, and the live value is spliced in so a scale set
    // elsewhere (or resolved from `scale = "auto"` in the config) is where the
    // cycle starts rather than a value the list does not contain.
    function scaleList(mon: var): var {
        const scales = [1, 1.25, 1.5, 1.75, 2];
        const current = mon.scale ?? 1;

        if (!scales.some(s => Math.abs(s - current) < 0.001))
            scales.push(current);

        return scales.sort((a, b) => a - b);
    }

    // Hyprland's transform is an index, not an angle. 0-3 are the rotations
    // this page offers; 4-7 are the same rotations with the output flipped,
    // which nothing here sets but something else might have -- so they are
    // named rather than left to print as a bare number, and the segmented
    // control below simply shows nothing selected when the live value is one
    // of them.
    function transformLabel(transform: int): string {
        switch (transform) {
        case 0: return "0° · normal";
        case 1: return "90°";
        case 2: return "180°";
        case 3: return "270°";
        case 4: return "flipped";
        case 5: return "flipped · 90°";
        case 6: return "flipped · 180°";
        case 7: return "flipped · 270°";
        default: return `transform ${transform}`;
        }
    }

    // The make as a person would say it. hyprctl reports "GIGA-BYTE
    // TECHNOLOGY CO., LTD." in `make`, which is a legal entity and not a
    // heading. The description keeps its full form and gets a row of its own,
    // because THAT string is the monitor's identity as far as Hyprland is
    // concerned and nothing here should paraphrase it.
    function shortMake(mon: var): string {
        return (mon.make ?? "").split(",")[0].split(" ")[0];
    }

    function monitorTitle(mon: var): string {
        const name = `${root.shortMake(mon)} ${mon.model ?? ""}`.trim();
        return name || mon.description || mon.name || "Monitor";
    }

    // ---------------- Specs ----------------
    //
    // A spec is the four things hl.monitor is given. Position is carried
    // through untouched rather than left out: an hl.monitor call that omits it
    // is a call whose result depends on what Hyprland decides to do with an
    // unspecified field, and the one thing an apply here must not do is move a
    // monitor nobody asked to move.

    function specOf(mon: var): var {
        return {
            // desc: AND NOT THE CONNECTOR NAME, for the reason hyprland.lua's
            // own monitor block spells out: connector names are assigned by
            // the kernel and they change across kernels -- linux-lts to
            // mainline turned DP-4 into DP-3 here and every rule stopped
            // matching. The description comes from the EDID.
            output: `desc:${mon.description ?? ""}`,
            mode: root.modeOf(mon),
            position: `${mon.x}x${mon.y}`,
            scale: mon.scale ?? 1,
            transform: mon.transform ?? 0
        };
    }

    function draftOf(mon: var): var {
        return root.draft[mon.name] ?? root.specOf(mon);
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
        const b = root.specOf(mon);
        return a.mode !== b.mode
            || Math.abs(a.scale - b.scale) > 0.001
            || a.transform !== b.transform;
    }

    // ---------------- Reading the saved overrides ----------------

    // hypr-monitor prints for a person, not for a program. There is no --json
    // and asking for one would mean two output formats to keep in step for the
    // sake of one caller, so this parses the human one:
    //
    //     ASR PG32QF2B G5VL0A003533
    //         2560x1440@165 at 1080x240, scale 1.25, transform 0
    //
    // THE INDENTATION IS THE ONLY THING SEPARATING THE TWO LINES, and it holds
    // because a description can carry spaces and dots in the middle -- they all
    // do -- but never at the start. The empty case is one unindented sentence
    // with no values line under it; it is matched by name anyway rather than
    // left to fall out of the pairing, because a sentence silently becoming a
    // key with nothing under it is the kind of thing that stays wrong quietly.
    //
    // Anything that does not match is dropped rather than guessed at: a saved
    // override this cannot read is better absent from the page than shown as a
    // row of blanks with a Forget button beside it.
    function parseOverrides(text: string): var {
        const found = ({});
        let desc = "";

        for (const line of String(text).split("\n")) {
            if (line.trim() === "")
                continue;

            if (!line.startsWith(" ")) {
                desc = line.startsWith("No monitor overrides") ? "" : line;
                continue;
            }

            const parts = /^\s+(\S+) at (\S+), scale ([\d.]+), transform ([0-7])$/.exec(line);
            if (desc && parts) {
                found[desc] = {
                    mode: parts[1],
                    position: parts[2],
                    scale: parseFloat(parts[3]),
                    transform: parseInt(parts[4])
                };
            }

            // Consumed either way. A values line that did not parse must not
            // be allowed to pair with the NEXT monitor's description.
            desc = "";
        }

        return found;
    }

    // null and not undefined, so the delegates can compare against something.
    function savedOf(mon: var): var {
        return root.overrides[mon.description ?? ""] ?? null;
    }

    function savedLabel(saved: var): string {
        const m = root.parseMode(saved.mode);
        // hypr-monitor also accepts preferred, highrr and highres, which
        // nothing on this page can produce but a person running the script by
        // hand can. Printed verbatim in that case: modeLabel would render them
        // as "0 × 0 · 0 Hz", which is a lie about a value this page did not set.
        const mode = m.w > 0 ? root.modeLabel(saved.mode) : saved.mode;
        return `${mode} · scale ${saved.scale.toFixed(2)} · ${root.transformLabel(saved.transform)}`;
    }

    // ---------------- Lua ----------------

    // Descriptions come out of the monitor's EDID, which is a blob written by
    // a manufacturer. Nothing guarantees it has no quote or backslash in it,
    // and a Lua string that closes early would be a syntax error at best and
    // an hl.monitor call against the wrong output at worst.
    function luaString(value: string): string {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    // The mode as hl.monitor is given it, which is NOT quite the form used
    // everywhere else here. Internally a mode carries two decimals so it can
    // be compared against availableModes, where the compositor prints
    // "2560x1440@165.00Hz"; on the way out a whole refresh rate loses them
    // again, because "2560x1440@165" is the exact string the monitor block in
    // hyprland.lua already passes to this same function every time the config
    // is read. Whether the compositor's own two-decimal rendering would parse
    // as readily is likely and untested, and there is no reason to find out on
    // the call that can black out a screen. A fractional rate keeps its
    // decimals, since 59.95 has nowhere to round to.
    function luaMode(mode: string): string {
        const m = root.parseMode(mode);
        return `${m.w}x${m.h}@${m.hz % 1 === 0 ? m.hz.toFixed(0) : m.hz}`;
    }

    // JavaScript already prints 1 for 1.0 and 1.25 for 1.25, which is exactly
    // what Lua wants, so the number goes in unquoted and unformatted.
    function inlineLua(spec: var): string {
        return `hl.monitor({ output = ${root.luaString(spec.output)}`
            + `, mode = ${root.luaString(root.luaMode(spec.mode))}`
            + `, position = ${root.luaString(spec.position)}`
            + `, scale = ${spec.scale}`
            + `, transform = ${spec.transform} })`;
    }

    // The pasteable form: hyprland.lua's own layout, aligned on the equals
    // signs, with the monitor named above it the way the two blocks in that
    // file already are.
    //
    // transform IS ALWAYS WRITTEN, even when it is 0 and even though the
    // existing block for the main monitor leaves it out. A generated block
    // that silently drops a field is how a rotation goes missing: paste this
    // over a rule that had transform = 3 and the omission is not a default, it
    // is a change nobody typed.
    function configBlock(mon: var, spec: var): string {
        return `-- ${root.monitorTitle(mon)}\n`
            + `hl.monitor({\n`
            + `    output    = ${root.luaString(spec.output)},\n`
            + `    mode      = ${root.luaString(root.luaMode(spec.mode))},\n`
            + `    position  = ${root.luaString(spec.position)},\n`
            + `    scale     = ${spec.scale},\n`
            + `    transform = ${spec.transform},\n`
            + `})\n`;
    }

    // ---------------- Applying ----------------

    function applySpec(spec: var): void {
        // No guard against an overlapping run, and it does not need one: the
        // controls lock while a confirmation is pending, and the earliest a
        // revert can fire is a full second after the apply that started it.
        // hyprctl is long gone by then.
        applier.command = ["hyprctl", "eval", root.inlineLua(spec)];
        applier.running = true;
    }

    // Read the current spec BEFORE applying, because after the apply the
    // compositor no longer knows what it used to be and neither would we.
    function commit(mon: var): void {
        root.revertSpec = root.specOf(mon);
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
    // that lasts. `set` rewrites monitors.lua and hands the spec to the
    // compositor as well.
    function persist(spec: var): void {
        Quickshell.execDetached(["hypr-monitor", "set",
            // WITHOUT the `desc:` prefix. The script builds `desc:%s` itself
            // when it writes the Lua, so passing the prefixed form would save
            // an output called desc:desc:ASR ... -- a rule that matches nothing
            // and fails by doing nothing at all on the next reload.
            String(spec.output).replace(/^desc:/, ""),
            // The same string the eval used, for the reason luaMode exists:
            // "2560x1440@165" is what hyprland.lua already passes, and this is
            // not the call to find out whether the two-decimal form parses.
            root.luaMode(spec.mode),
            spec.position,
            // Lua and the script's own validation both want a bare decimal;
            // JavaScript prints 1 for 1 and 1.25 for 1.25, which is exactly it.
            String(spec.scale),
            String(spec.transform)]);

        overrideSettle.restart();
    }

    function keep(): void {
        // THE WRITE IS HERE AND NOT IN commit(), and that is the whole point of
        // the countdown existing. An apply is a question -- can you see this?
        // -- and only the answer is worth keeping. Writing on the apply instead
        // would put a mode into monitors.lua before anyone knew whether the
        // panel could show it, and monitors.lua is re-read on every reload and
        // every boot: a settings file that faithfully restores a black screen
        // is the exact failure this design exists to avoid. Nothing is written
        // when the countdown expires or Revert is pressed, which is the same
        // rule said the other way round.
        //
        // THE REDUNDANCY IS DELIBERATE AND IT IS A NO-OP. `hypr-monitor set`
        // applies the spec live as well as writing it, so the compositor is
        // told a second time what it is already doing -- same output, same
        // mode string, same position, scale and transform, because what is
        // persisted is the snapshot of what was eval'd ten seconds ago and not
        // a re-reading of anything. hl.monitor setting every field to the value
        // it already holds changes no pixels. Not worth a --no-apply flag on
        // the script: that would be a second code path through the one part of
        // this that must not be wrong, bought for nothing.
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
    // meant to: the script writes the file and says so, and going back to
    // whatever hyprland.lua declares takes a reload, which neither the script
    // nor this page can do on the user's behalf without moving a monitor
    // nobody asked to move.
    function forget(mon: var): void {
        forgetter.command = ["hypr-monitor", "forget", mon.description ?? ""];
        root.forgetNoticeFor = mon.name;
        root.forgetNotice = "";
        forgetter.running = true;
    }

    function copyConfig(mon: var): void {
        Quickshell.execDetached(["wl-copy", root.configBlock(mon, root.draftOf(mon))]);
        root.copiedFor = mon.name;
        copiedReset.restart();
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
        // hypr-monitor is a script precisely so it can be.
        if (!overrideQuery.running)
            overrideQuery.running = true;

        // Whether the night light daemon is up. Asked here rather than polled
        // or watched: the answer only changes when a package is installed or
        // a session restarts, and both of those end with a trip back to this
        // page. See the section at the bottom of this file.
        if (!sunsetProbe.running)
            sunsetProbe.running = true;

        // The forget advice belongs to the visit it was earned in. It says to
        // go and run `hyprctl reload`, and leaving the settings window is the
        // likeliest thing to have happened in order to do that.
        root.forgetNotice = "";
        root.forgetNoticeFor = "";
    }

    Process {
        id: monitorQuery

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn("DisplayPage: could not parse hyprctl monitors --", e.message);
                    return;
                }

                // Left to right, which is how they are arranged on the desk.
                // hyprctl reports them by internal id, and on this machine
                // that puts the side monitor first for no reason the person
                // reading the page can see.
                root.monitors = parsed.slice().sort((a, b) => a.x - b.x || a.y - b.y);
            }
        }
    }

    Process {
        id: overrideQuery

        // Bare, which is the script's `show`. It only prints.
        command: ["hypr-monitor"]

        stdout: StdioCollector {
            onStreamFinished: root.overrides = root.parseOverrides(text)
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

        // The reply is NOT what says it worked. hyprctl eval answers on stdout
        // and exits 0 for a Lua error as readily as for a success, so nothing
        // here branches on it -- it is printed so a broken call leaves a trace,
        // and the re-read below is what the page actually believes.
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("DisplayPage: hyprctl eval said --", text.trim());
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

    // ---------------- Pieces ----------------

    // One fact: what it is on the left, what it says on the right.
    component Reading: Item {
        id: reading

        property string label: ""
        property string value: ""
        // Defaults to the ordinary text colour; the focused row uses the
        // accent so the one monitor that has the keyboard can be found without
        // reading all six lines.
        property color tone: Theme.textOnSurface

        width: parent ? parent.width : 320
        implicitHeight: 24

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            text: reading.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            // Half the row at most, so a long description elides instead of
            // sliding under its own label.
            width: Math.min(implicitWidth, reading.width * 0.62)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle

            text: reading.value
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Theme.fontWeight
            color: reading.tone

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // A value picked by stepping through a list, in the shape of a settings
    // row. StepperRow itself does not fit: it holds an int over a numeric
    // range, and these are strings out of a list the compositor supplies.
    // Its buttons do fit, so those are reused rather than redrawn.
    component CycleRow: Rectangle {
        id: cycle

        property string glyph: ""
        property string label: ""
        property string value: ""

        signal stepped(int delta)

        width: parent ? parent.width : implicitWidth
        implicitWidth: 320
        implicitHeight: Theme.groupHeight

        radius: Theme.groupRadius
        color: cycleMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        opacity: cycle.enabled ? 1 : 0.4

        // Hover on the whole row, like StepperRow: the row is one object and
        // lights up as one. It takes no clicks -- there is no obvious single
        // action for "clicked the label", and inventing one (step forward?)
        // would be a control nobody asked for.
        MouseArea {
            id: cycleMouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: cycle.glyph !== ""
                text: cycle.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cycle.label
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
            anchors.rightMargin: Theme.groupPadding - 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StepperButton {
                anchors.verticalCenter: parent.verticalCenter
                symbol: root.chevronLeft
                enabled: cycle.enabled
                onTriggered: cycle.stepped(-1)
            }

            // FIXED WIDTH, for the reason StepperRow's number is: the buttons
            // sit either side of it, and without this they would jump every
            // time the text went from "800 × 600 · 60 Hz" to
            // "2560 × 1440 · 165 Hz".
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 168
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                text: cycle.value
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            StepperButton {
                anchors.verticalCenter: parent.verticalCenter
                symbol: Icons.chevronRight
                enabled: cycle.enabled
                onTriggered: cycle.stepped(1)
            }
        }
    }

    // The one button shape this page uses, for the segmented rotation control
    // and for every action. Filled means "this is the one" -- the selected
    // segment, or the action that carries the page's intent.
    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string glyph: ""
        property bool filled: false
        property color accent: Theme.primary
        // Set alongside `accent` whenever it is not the primary, because M3
        // guarantees contrast per PAIR and the pairs are the whole reason the
        // palette can follow the wallpaper. warning and critical pair with
        // textOnCritical, which is the same dark ink.
        property color accentText: Theme.textOnPrimary

        signal activated

        implicitWidth: chipRow.implicitWidth + Theme.groupPadding * 2
        implicitHeight: 28
        radius: height / 2

        color: chip.filled
            ? (chipMouse.containsMouse ? Qt.lighter(chip.accent, 1.15) : chip.accent)
            : (chipMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")

        border.width: chip.filled ? 0 : 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Behavior on border.color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // Dimmed rather than hidden: an action that vanishes takes the ones
        // beside it sideways, and the row would rearrange itself every time a
        // draft became clean.
        opacity: chip.enabled ? 1 : 0.35

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.glyph !== ""
                text: chip.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 1
                color: chip.filled ? chip.accentText : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                font.weight: chip.filled ? Font.Bold : Theme.fontWeight
                color: chip.filled ? chip.accentText : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: chip.enabled
            onClicked: chip.activated()
        }
    }

    // ---------------- Where a kept change goes ----------------
    //
    // ONE LINE AND NOT A PARAGRAPH. It is true of every control below it, so
    // it has to be said once, up here, and then never repeated on a row -- a
    // notice printed six times is a notice nobody reads. It used to say the
    // opposite ("this session only"), and the reason it no longer does is
    // monitors.lua; naming the file is the point of the line, because it is a
    // file the person can read, delete or keep out of git themselves. The
    // refresh beside it is the manual way to re-read; the page does it on its
    // own whenever it is opened and after every apply.
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
            // file is generated and stacks on top of the hand-written one.
            // A settings window is the last place that should be telling you
            // most of something.
            text: "Kept changes are saved to ~/.config/hypr/monitors.lua — generated, applied on top of hyprland.lua."
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
    SettingsSection {
        width: root.width
        glyph: Icons.nightLight
        title: "Night light"

        // FIRST, AND ONLY WHEN IT IS TRUE. Everything below this line is a
        // control that silently does nothing without the daemon, and a page
        // full of switches that do nothing is a worse bug than a missing
        // feature -- the user concludes the setting is broken rather than
        // absent.
        Text {
            visible: !root.sunsetRunning

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "hyprsunset is not running, so nothing below will reach the screen. "
                + "It is the daemon that owns the colour matrix; Hyprland only passes "
                + "messages to it. Start it with "
                + "`systemctl --user enable --now hyprsunset.service`."
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
            enabled: !NightLight.scheduled && root.sunsetRunning

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
            enabled: root.sunsetRunning
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
            enabled: root.sunsetRunning

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
            enabled: NightLight.scheduled && root.sunsetRunning

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
            enabled: NightLight.scheduled && root.sunsetRunning
            hint: "An end earlier than the start is the normal case, not a "
                + "mistake: 20:00 to 07:00 is the two ends of the day rather "
                + "than the middle of it, and that is what this reads it as."

            onMoved: value => NightLight.setTo(value)
        }
    }

    // Whether the daemon is up, asked when the page is looked at rather than
    // polled. The same argument the Wi-Fi scanner makes: every page in this
    // window is built and alive, so `visible` is the only honest signal that
    // somebody is reading this one.
    //
    // It is asked ONCE per visit and not watched, because the answer only
    // changes when a person installs a package or a session restarts -- and
    // both of those end with a trip back to this page.
    // Asked from the page's single onVisibleChanged handler further up, next
    // to the two hyprctl queries -- QML allows one handler per signal, and a
    // second `onVisibleChanged` here is not an override but an error.
    property bool sunsetRunning: true

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
            readonly property bool locked: root.pendingName !== ""
            // null when this monitor has nothing saved, which is the state
            // every monitor is in until somebody keeps a change.
            readonly property var saved: root.savedOf(card.mon)

            width: root.width
            glyph: Icons.monitor
            title: root.monitorTitle(card.mon)

            // ---------------- What it is ----------------
            Reading {
                label: "Connector"
                value: card.mon.name ?? ""
            }

            // The full EDID string, verbatim. Prefixed with `desc:` this is
            // what every rule in hyprland.lua matches on and what the Lua
            // below sends, so it is worth being able to read it off the screen
            // rather than out of `hyprctl monitors all -j`.
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
                value: root.transformLabel(card.mon.transform ?? 0)
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
                value: card.saved ? root.savedLabel(card.saved) : ""
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
                glyph: root.arrowExpand
                label: "Mode"
                value: root.modeLabel(card.spec.mode)
                enabled: !card.locked

                // WRAPS RATHER THAN CLAMPS. Nothing is applied by stepping --
                // this only moves a draft -- so running off the end costs
                // nothing, and the main panel offers 29 modes: a button that
                // goes dead at the top of that list is a control that looks
                // broken long before it is understood.
                onStepped: delta => {
                    const modes = root.modeList(card.mon);
                    const at = modes.indexOf(card.spec.mode);
                    const next = (at + delta + modes.length) % modes.length;
                    root.setDraft(card.mon, { mode: modes[next] });
                }
            }

            CycleRow {
                glyph: root.relativeScale
                label: "Scale"
                value: card.spec.scale.toFixed(2)
                enabled: !card.locked

                onStepped: delta => {
                    const scales = root.scaleList(card.mon);
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
                        text: root.screenRotation
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
                    // with different owners: Keep writes monitors.lua, which is
                    // generated and gitignored, and this puts the same block on
                    // the clipboard for hyprland.lua, which is hand-written and
                    // in git. Promoting a value from the first to the second is
                    // a thing to want, and it is not a thing a settings window
                    // should do by itself -- see the header.
                    //
                    // NOT gated on `dirty`, unlike the two above: copying the
                    // block for a monitor exactly as it is now is the whole
                    // point on the day you want to write the current setup
                    // into hyprland.lua without changing anything first.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: root.copiedFor === card.mon.name ? "Copied" : "Copy config"
                        glyph: root.copiedFor === card.mon.name ? root.check : root.clipboardText
                        onActivated: root.copyConfig(card.mon)
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

            // THE SCRIPT'S OWN WORDS, printed verbatim under the monitor they
            // were about. `forget` rewrites monitors.lua and deliberately
            // applies nothing, so at this instant the file and the screen
            // disagree and only a reload settles it -- which is precisely what
            // the line it prints says. Shown rather than paraphrased so there
            // is one copy of that sentence, in the script that knows it.
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
                        text: root.timerSand
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
                    // change to monitors.lua. A tick here would say the change
                    // was merely accepted.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Keep"
                        glyph: root.contentSave
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
    // hyprctl is asked when the page appears, so an empty list is either the
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

            text: "No monitors reported. `hyprctl monitors -j` lists the enabled ones only, "
                + "so a screen that is switched off in the compositor does not appear here."
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
        id: sunsetProbe

        command: ["pgrep", "-x", "hyprsunset"]
        // pgrep exits 1 when it matches nothing, which is the whole answer --
        // there is no output to collect.
        onExited: code => root.sunsetRunning = code === 0
    }
}
