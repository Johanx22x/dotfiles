// How a monitor is spelled, and nothing about how one is driven.
//
// Every function here is PURE: it takes a monitor object or a spec and returns
// a value. Nothing reads a property, nothing starts a process, nothing knows
// that a settings page exists. That is the whole reason this is a separate
// file -- the display page's other parts all disagree about what is a fact and
// what is a draft, and this one is neither.
//
// A singleton and not a JavaScript resource, which is the shape Fuzzy.qml
// already set for pure helpers in this shell. The QML function signatures are
// the reason: `modeOf(mon: var): string` coerces its return the way the page
// has always relied on, and a .js file would silently drop every annotation on
// the way past.

pragma Singleton

import QtQuick

QtObject {
    id: root

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
    // And the list is sorted, because it comes back in EDID order, which
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

    // A transform is an INDEX, not an angle, and that is the wl_output enum
    // rather than any one compositor's idea: 0 normal, 1 through 3 the
    // counter-clockwise rotations, 4 through 7 the same with the output
    // flipped. Hyprland speaks it in numbers and niri in words ("270",
    // "flipped-90"), and desktop-monitors translates -- which is why this page
    // never sees a word.
    //
    // 0-3 are the rotations this page offers. 4-7 are named rather than left to
    // print as a bare number, because nothing here sets them but something else
    // might have; the segmented control below simply shows nothing selected
    // when the live value is one of them.
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

    // The make as a person would say it. Both compositors report "GIGA-BYTE
    // TECHNOLOGY CO., LTD." in `make`, which is a legal entity and not a
    // heading. The description keeps its full form and gets a row of its own,
    // because THAT string is the monitor's identity as far as the compositor is
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
    // A spec is the four things desktop-monitors is given for one monitor.
    // Position is carried through untouched rather than left out: a spec that
    // omits it is one whose result depends on what the compositor decides to do
    // with an unspecified field, and the one thing an apply here must not do is
    // move a monitor nobody asked to move.

    function specOf(mon: var): var {
        return {
            // THE DESCRIPTION AND NOT THE CONNECTOR NAME, for the reason both
            // configs spell out at the top: connector names are assigned by the
            // kernel and they change across kernels -- linux-lts to mainline
            // turned DP-4 into DP-3 here and every rule stopped matching. The
            // description comes from the EDID.
            //
            // Carried WITH the `desc:` prefix because Copy config's Lua wants
            // it, and stripped again by specArgs on the way to the script,
            // which builds its own. Passing the prefixed form through would
            // record an output called desc:desc:ASR ..., a rule that matches
            // nothing while looking almost right in every message that echoes
            // it.
            output: `desc:${mon.description ?? ""}`,
            mode: root.modeOf(mon),
            position: `${mon.x}x${mon.y}`,
            scale: mon.scale ?? 1,
            transform: mon.transform ?? 0
        };
    }

    // ---------------- Talking to the script ----------------

    // A spec as the five arguments desktop-monitors takes, in order. Every call
    // that reaches the script goes through this, so there is one place where
    // the shape of that command line is decided.
    function specArgs(spec: var): var {
        return [
            // WITHOUT the `desc:` prefix -- see specOf. The script builds it
            // itself when it writes Lua and does not want it at all when it
            // writes KDL.
            String(spec.output).replace(/^desc:/, ""),
            root.modeArg(spec.mode),
            spec.position,
            // The script's validation wants a bare decimal, and JavaScript
            // prints 1 for 1 and 1.25 for 1.25, which is exactly it.
            String(spec.scale),
            String(spec.transform)
        ];
    }

    // The mode as the script is given it, which is NOT quite the form used
    // everywhere else here. Internally a mode carries two decimals so it can
    // be compared against availableModes, where both compositors are made to
    // print "2560x1440@165.00Hz"; on the way out a whole refresh rate loses
    // them again, because "2560x1440@165" is the exact string the monitor block
    // in hyprland.lua already passes every time the config is read.
    //
    // NOTHING DOWNSTREAM NEEDS THE PRECISION, and that is worth knowing before
    // anybody tries to add it back. The rates in this house are all fractional
    // -- 165.001 on one panel and 164.999 on the other -- so an exact match
    // could never have worked from a two-decimal reading anyway. Hyprland
    // resolves the nearest itself, and desktop-monitors resolves it against the
    // live mode list before writing KDL. A fractional rate keeps its decimals,
    // since 59.95 has nowhere to round to.
    function modeArg(mode: string): string {
        const m = root.parseMode(mode);
        return `${m.w}x${m.h}@${m.hz % 1 === 0 ? m.hz.toFixed(0) : m.hz}`;
    }

    // ---------------- Reading the saved overrides ----------------

    // desktop-monitors prints for a person, not for a program. There is no --json
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

            // THE vrr TAIL IS OPTIONAL AND IS NOT CAPTURED, which is the whole
            // of this page's relationship with that field. A record can carry a
            // variable-refresh-rate mode -- niri's output blocks moved into the
            // generated file and brought it with them -- and nothing here sets
            // it, reads it or shows it. What matters is that a record which HAS
            // one still parses: without the tail this regex fails, the line is
            // dropped, and the monitor silently loses its Saved override row
            // and its Forget chip.
            const parts = /^\s+(\S+) at (\S+), scale ([\d.]+), transform ([0-7])(?:, vrr \S+)?$/.exec(line);
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

    function savedLabel(saved: var): string {
        const m = root.parseMode(saved.mode);
        // desktop-monitors also accepts preferred, highrr and highres, which
        // nothing on this page can produce but a person running the script by
        // hand can. Printed verbatim in that case: modeLabel would render them
        // as "0 × 0 · 0 Hz", which is a lie about a value this page did not set.
        const mode = m.w > 0 ? root.modeLabel(saved.mode) : saved.mode;
        return `${mode} · scale ${saved.scale.toFixed(2)} · ${root.transformLabel(saved.transform)}`;
    }
}
