// The cheatsheet: every keybind that carries a description, by category.
//
// WHERE THE LIST COMES FROM, AND WHY IT CANNOT GO STALE
// `hyprctl binds`, asked fresh on every open. Not a list written here, and not
// hyprland.lua parsed by hand: the compositor is the only thing that knows
// what is bound RIGHT NOW, including whatever a reload changed a minute ago.
// Adding a bind to hyprland.lua with a description is the whole of what it
// takes to make it appear here.
//
// The one thing the compositor cannot tell us is what a bind DOES. The config
// is in Lua, so `hyprctl binds` reports every dispatcher as "__lua" with an
// opaque callback index for an argument -- useless as a label. The description
// is where the meaning lives, in the "Category: what it does" form, and the
// category before the colon is what groups the rows below.
//
// A BIND WITH NO DESCRIPTION IS INVISIBLE HERE, deliberately. That is the
// filter that keeps the sheet from listing ten identical rows for SUPER + 1
// through SUPER + 0, and it is why the loops in hyprland.lua describe only
// their first iteration.
//
// LAYOUT
// Three columns, filled shortest-first rather than in order, so they end at
// roughly the same height instead of leaving one long and two stubby. There
// is no scrolling: at 38 binds the tallest column is around a third of the
// screen, and the sheet would have to grow past twice its current size before
// height became a question worth solving.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: root

    // The ShellScreen this sheet belongs to, from Variants in shell.qml.
    required property var modelData

    readonly property int columnCount: 3
    readonly property int columnWidth: 540
    readonly property int columnGap: 30
    // The keys sit in a fixed-width gutter and are laid out RIGHT to left, so
    // the actual key is always the chip nearest its own description and every
    // description in a column starts at the same x. Measured against the
    // widest chord bound here, SUPER + SHIFT + Esc, with a little slack.
    readonly property int keyGutter: 150
    readonly property int cardPadding: 30

    // Parsed from hyprctl, see the Process at the bottom. Shape:
    //   [ { name: "Apps", binds: [ { keys: [...], text: "..." } ] } ]
    property var groups: []

    // The order categories are shown in: roughly how often you reach for them,
    // with the shell's own controls last. A category not named here still
    // appears -- at the end, in the order hyprctl reported it -- so a new one
    // is never silently dropped.
    readonly property var categoryOrder: [
        "Apps", "Windows", "Workspaces", "Capture", "Look", "Media", "Shell"
    ]

    // ---------------- Turning a bind into something readable ----------------

    // The X11 modifier bits. Hyprland reports the mask raw; only these four
    // are ever bound by hand, and the rest (caps, numlock) would be noise on a
    // chip even when set.
    function modifiers(mask: int): var {
        const out = [];
        if (mask & 64) out.push("SUPER");
        if (mask & 8)  out.push("ALT");
        if (mask & 4)  out.push("CTRL");
        if (mask & 1)  out.push("SHIFT");
        return out;
    }

    // Hyprland's key names are xkb keysyms and mouse codes. Left alone they
    // read like config, not like the key under your finger.
    readonly property var keyNames: ({
        "RETURN": "Enter",
        "SPACE": "Space",
        "ESCAPE": "Esc",
        "slash": "/",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "mouse_up": "Scroll ↑",
        "mouse_down": "Scroll ↓",
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic mute",
        "XF86AudioNext": "Next",
        "XF86AudioPrev": "Prev",
        "XF86AudioPlay": "Play",
        "XF86AudioPause": "Pause",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright −"
    })

    function keyName(key: string): string {
        // The fallback strips the XF86 prefix rather than printing it: an
        // unmapped media key reads better as "AudioStop" than as the whole
        // keysym, and this way a key we forgot still looks deliberate.
        return root.keyNames[key] ?? (key.startsWith("XF86") ? key.slice(4) : key);
    }

    // Shortest-first packing. Categories keep their order within a column, and
    // each goes to whichever column is currently shortest -- measured in rows
    // plus two for the heading, so a heading is not free.
    function pack(groups: var): var {
        const columns = [];
        const heights = [];

        for (let i = 0; i < root.columnCount; i++) {
            columns.push([]);
            heights.push(0);
        }

        for (const group of groups) {
            let shortest = 0;
            for (let i = 1; i < heights.length; i++)
                if (heights[i] < heights[shortest])
                    shortest = i;

            columns[shortest].push(group);
            heights[shortest] += group.binds.length + 2;
        }

        return columns;
    }

    readonly property var columns: root.pack(root.groups)

    screen: modelData
    visible: CheatsheetState.isOpen

    WlrLayershell.namespace: "quickshell-cheatsheet"
    // Overlay, like the power menu: this has to be readable over a fullscreen
    // window, which is exactly when you have forgotten the bind to get out of
    // one.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive so Escape reaches us at all. Static rather than flipped with
    // `isOpen`, the same as PowerMenu: `visible` tears the surface down, so
    // nothing holds the keyboard while the sheet is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring
    // all four edges stretches the layer surface instead, and then the size
    // the compositor picked is not one QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's reservation:
    // the sheet covers the bar rather than starting below it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    Connections {
        target: CheatsheetState

        function onIsOpenChanged(): void {
            if (!CheatsheetState.isOpen)
                return;

            // Re-read on every open. A config reload between two openings is
            // exactly the case a cached list would get wrong.
            //
            // Only where the compositor can be asked at all -- otherwise the
            // sheet says so instead, below, and running the query would just
            // spawn a process to fail.
            if (Compositor.can("bindsIntrospection"))
                binds.running = true;
            sheet.forceActiveFocus();
        }
    }

    Rectangle {
        id: sheet

        // Sized from the SCREEN, not from `parent`: the window's contentItem
        // stays 0x0 whatever the layer surface measures, so `anchors.fill`
        // would collapse to nothing. Same as PowerMenu.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // The shell's standard glass, and that is not decoration: the
        // blur-quickshell rule in hyprland.lua sets ignore_alpha just under
        // Theme.glassAlpha, so an alpha picked by hand here would fall out of
        // the blur entirely and the sheet would go from frosted wallpaper to a
        // flat tint over perfectly sharp windows.
        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        focus: true

        Keys.onEscapePressed: CheatsheetState.close()
        // The key that opened it also closes it, without the modifier: while
        // the sheet holds the keyboard, the SUPER + / bind still fires from
        // the compositor, but a bare / is the reflex once you are looking at
        // it.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question)
                CheatsheetState.close();
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. Below the card in the file, so the card
        // takes its own clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: CheatsheetState.close()
        }

        Rectangle {
            id: card

            anchors.centerIn: parent

            implicitWidth: layout.implicitWidth + root.cardPadding * 2
            implicitHeight: layout.implicitHeight + root.cardPadding * 2
            radius: Theme.cardRadius

            color: Theme.glass(Theme.surfaceContainer)

            // Opening move: a short rise into place. Small on purpose -- this
            // is a reference you want to be able to read, not an entrance.
            opacity: CheatsheetState.isOpen ? 1 : 0
            scale: CheatsheetState.isOpen ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            // Swallows clicks that would otherwise reach the dismiss area
            // behind the card.
            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: layout

                anchors.centerIn: parent
                spacing: 22

                // ---------------- Header ----------------
                Item {
                    width: layout.implicitWidth
                    height: title.implicitHeight

                    Row {
                        id: title

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.keyboard
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize + 4
                            color: Theme.primary

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Keybindings"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize + 4
                            font.weight: Font.Bold
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Esc to close"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Theme.fontWeight
                        color: Theme.outline

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                // ---------------- Nothing to list ----------------
                //
                // A sheet whose whole job is to explain the keys, opened on a
                // compositor that cannot be asked what is bound, must not come
                // up blank: an empty panel reads as a broken shell rather than
                // as a missing feature. It says which it is.
                Text {
                    visible: !Compositor.can("bindsIntrospection")
                    width: parent.width

                    text: "This compositor cannot report what is bound to what.\n\n"
                        + "The bindings are still there -- they are in the compositor's own\n"
                        + "configuration file, which is where they were written."
                    horizontalAlignment: Text.AlignHCenter

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Theme.fontWeight
                    color: Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                // ---------------- The columns ----------------
                Row {
                    visible: Compositor.can("bindsIntrospection")
                    spacing: root.columnGap

                    Repeater {
                        model: root.columns

                        Column {
                            id: column

                            required property var modelData

                            width: root.columnWidth
                            spacing: 18

                            Repeater {
                                model: column.modelData

                                Column {
                                    id: group

                                    required property var modelData

                                    width: column.width
                                    spacing: 6

                                    // ---- Category heading ----
                                    Row {
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Icons.category(group.modelData.name)
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.iconSize - 1
                                            color: Theme.primary

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.recolorDuration }
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: group.modelData.name
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.fontSize
                                            font.weight: Font.Bold
                                            // Letterspaced and in the accent:
                                            // the headings are signposts, and
                                            // at this size weight alone does
                                            // not separate them enough from
                                            // the rows under them.
                                            font.letterSpacing: 0.8
                                            color: Theme.primary

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.recolorDuration }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: column.width
                                        height: 1
                                        color: Theme.outlineVariant

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.recolorDuration }
                                        }
                                    }

                                    // ---- The binds ----
                                    Repeater {
                                        model: group.modelData.binds

                                        BindRow {
                                            required property var modelData

                                            width: column.width
                                            keys: modelData.keys
                                            label: modelData.text
                                            gutterWidth: root.keyGutter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: binds

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = JSON.parse(text || "[]");
                } catch (e) {
                    console.warn("Cheatsheet: could not parse hyprctl binds --", e.message);
                    return;
                }

                // Categories are collected in the order hyprctl reports them,
                // which is the order of hyprland.lua, and only then sorted
                // into categoryOrder. That is what gives an unlisted category
                // a stable place at the end instead of one that moves.
                const byName = {};
                const seen = [];

                for (const bind of parsed) {
                    if (!bind.has_description || !bind.description)
                        continue;

                    const colon = bind.description.indexOf(": ");
                    const name = colon < 0 ? "Other" : bind.description.slice(0, colon);
                    const text = colon < 0 ? bind.description : bind.description.slice(colon + 2);

                    if (!byName[name]) {
                        byName[name] = { name: name, binds: [] };
                        seen.push(name);
                    }

                    byName[name].binds.push({
                        keys: root.modifiers(bind.modmask).concat([root.keyName(bind.key)]),
                        text: text
                    });
                }

                seen.sort((a, b) => {
                    const ia = root.categoryOrder.indexOf(a);
                    const ib = root.categoryOrder.indexOf(b);
                    // Unlisted categories keep their arrival order, after the
                    // listed ones.
                    return (ia < 0 ? root.categoryOrder.length + seen.indexOf(a) : ia)
                         - (ib < 0 ? root.categoryOrder.length + seen.indexOf(b) : ib);
                });

                root.groups = seen.map(name => byName[name]);
            }
        }
    }
}
