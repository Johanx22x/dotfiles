// Everything the display page asks desktop-monitors, except the two questions
// that come with a countdown.
//
// THE LINE BETWEEN THIS FILE AND DisplayDraft.qml IS THE REVERT TIMER, and it
// is not "reads here, writes there". `forget` and `main` are writes and they
// live here, because what they leave behind is a SENTENCE to print and not a
// state anybody has to confirm: neither can black out a screen, so neither
// needs the ten seconds. `apply` and `set` are next door, with the timer, for
// exactly the reason the page's header gives.
//
// EVERYTHING HERE IS A READING AND IS READ BACK, never assumed from what was
// written. That is what makes a rejected apply visible -- Hyprland silently
// adjusting a scale it cannot honour shows up as the readings disagreeing with
// what was asked for, rather than as a page confidently displaying a number the
// compositor never accepted.
//
// A Scope and not an Item: it draws nothing, and an Item with no size would
// still be a child of the page's Column and would still cost a gap of
// Theme.groupSpacing between two sections.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Scope {
    id: root

    // ---------------- What the compositor said, last time it was asked ----------------
    //
    // IT IS A READING, NOT A CONTROL. Nothing on this page holds a monitor's
    // state of its own: the controls hold a DRAFT, and everything drawn as
    // fact comes from this array. That is what makes a rejected apply visible
    // -- Hyprland silently adjusting a scale it cannot honour shows up as the
    // readings disagreeing with what you asked for, rather than as a page
    // confidently displaying a number the compositor never accepted.
    property var monitors: []

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

    // ---------------- Reading the saved overrides ----------------

    // null and not undefined, so the delegates can compare against something.
    function savedOf(mon: var): var {
        return root.overrides[mon.description ?? ""] ?? null;
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

    // ---------------- Asking again ----------------

    // Everything a fresh look at the page wants. Guarded one at a time, so a
    // visit that lands while an answer is still on its way adds nothing.
    function refresh(): void {
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
    }

    // BOTH READINGS, because both can be behind: the compositor's if something
    // moved a monitor from elsewhere, and the saved list if a write landed
    // after the page last looked. This is what the Re-read chip is for, and it
    // is the way to catch up on either without closing the window.
    function reread(): void {
        monitorQuery.running = true;
        overrideQuery.running = true;
    }

    // After something applied a spec. Only the compositor's side: an apply
    // writes nothing, so the saved list cannot have moved.
    function reload(): void {
        if (!monitorQuery.running)
            monitorQuery.running = true;
    }

    // After something wrote one. See overrideSettle for why it waits.
    function settleOverrides(): void {
        overrideSettle.restart();
    }

    function dropForgetNotice(): void {
        root.forgetNotice = "";
        root.forgetNoticeFor = "";
    }

    // ---------------- What the page needs to ask about a running command ----------------
    //
    // Three bools rather than three ids reached into from outside. A chip that
    // greys itself out while a write is in flight should not have to know which
    // Process is doing it.

    readonly property bool busy: monitorQuery.running || overrideQuery.running
    readonly property bool forgetting: forgetter.running
    readonly property bool settingMain: mainSetter.running
}
