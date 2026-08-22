// Lua, for Copy config and nothing else.
//
// THE ONE PIECE OF COMPOSITOR-SPECIFIC TEXT LEFT ON THE DISPLAY PAGE, and it
// is only ever put on a clipboard. It is drawn where `monitorConfigCopy` says
// there is a hand-written config to paste it into, which today means Hyprland;
// see the header of DisplayPage.qml.
//
// ITS OWN FILE BECAUSE IT IS THE ODD ONE OUT. Everything else the page knows
// about a monitor is the same question on both compositors -- which is the
// argument the page's header makes at length -- and this is the exception that
// names a flavour in its own type name rather than hiding inside a page that
// claims not to have one. A second flavour, if one ever earns a Copy config
// chip, is a sibling of this file and not a branch inside it.

pragma Singleton

import QtQuick

QtObject {
    id: root

    // Descriptions come out of the monitor's EDID, which is a blob written by
    // a manufacturer. Nothing guarantees it has no quote or backslash in it,
    // and a Lua string that closes early would be a syntax error at best and
    // an hl.monitor call against the wrong output at worst.
    function luaString(value: string): string {
        return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    // The pasteable form: the layout ~/.config/hypr/outputs.lua uses, aligned
    // on the equals signs, with the monitor named above it the way the blocks
    // in that file already are. outputs.lua and not hyprland.lua: a monitor
    // description is per-unit data and the repository is public, so the
    // hand-written declaration lives untracked in $HOME.
    //
    // transform IS ALWAYS WRITTEN, even when it is 0 and even though the
    // existing block for the main monitor leaves it out. A generated block
    // that silently drops a field is how a rotation goes missing: paste this
    // over a rule that had transform = 3 and the omission is not a default, it
    // is a change nobody typed.
    function configBlock(mon: var, spec: var): string {
        return `-- ${Monitors.monitorTitle(mon)}\n`
            + `hl.monitor({\n`
            + `    output    = ${root.luaString(spec.output)},\n`
            + `    mode      = ${root.luaString(Monitors.modeArg(spec.mode))},\n`
            + `    position  = ${root.luaString(spec.position)},\n`
            + `    scale     = ${spec.scale},\n`
            + `    transform = ${spec.transform},\n`
            + `})\n`;
    }
}
