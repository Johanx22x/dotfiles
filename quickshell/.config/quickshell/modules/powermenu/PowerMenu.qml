// The power menu: a fullscreen sheet with one card per session action.
//
// It replaces the wofi script that used to live in ~/.local/bin, and keeps
// its shape -- a dimmed screen with a row of cards, each a large glyph over a
// label. What does NOT come across is everything that script needed to
// achieve that shape from outside the shell: measuring the monitor,
// compensating for the bar's exclusive zone by deliberately asking for a
// surface TALLER than the screen, generating a per-monitor stylesheet because
// CSS takes no variables, and padding every label to nine characters so a
// Nerd Font glyph would centre over it. A layer surface the size of the
// screen is the whole of that here.
//
// WHY FULLSCREEN IS THE EASY ONE
// Covering the screen means the sheet itself catches a click anywhere outside
// the cards, and that is what dismisses it. No HyprlandFocusGrab, and so none
// of the open-and-immediately-close trouble that comes with asking the
// compositor for an input grab on a surface that is not mapped yet.
//
// FOCUS
// The menu takes the keyboard while it is open -- Exclusive, not None -- and
// that is not free: the window underneath goes deaf for as long as the menu
// is up. It is the price of arrow keys and Enter, because a layer surface
// that does not hold the keyboard is never sent a keystroke to begin with.
// There are three ways out and all of them are one gesture: Escape, a click
// on the empty space, or SUPER + SHIFT + ESCAPE again.
//
// WHAT PROTECTS AGAINST AN ACCIDENTAL SHUTDOWN
// The old menu put "Cancel" first because wofi preselects its first entry and
// a stray Enter would otherwise fire it. This one starts with NOTHING
// selected -- `selected` is -1, not 0 -- so Enter on a freshly opened menu
// has nothing to activate. The first arrow key is what selects, which makes
// arming an action deliberate. That is also why the Cancel card is gone: it
// was a button whose job is already done three times over.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: root

    // The ShellScreen this menu belongs to, from Variants in shell.qml.
    required property var modelData

    // One card. Wider than it is tall, so a row of them reads as a row and
    // not as a strip of buttons.
    readonly property int cardWidth: 220
    readonly property int cardHeight: 180
    readonly property int cardGap: 20

    // The entries, in order of how much they cost you: log out, then restart,
    // then the one that leaves the machine off.
    //
    // `command` is passed to execDetached as a list, never a string, so
    // nothing goes through a shell that does not need one.
    readonly property var actions: [
        {
            glyph: Icons.logout,
            label: "Log out",
            accent: Theme.warning,
            // The ONE action that is not a command, because the right way to
            // end a session depends on what is drawing it: each compositor
            // backend asks its own first and falls back to logind, which works
            // even on a compositor nothing here knows about.
            perform: () => Compositor.logout()
        },
        {
            glyph: Icons.restart,
            label: "Restart",
            accent: Theme.critical,
            command: ["systemctl", "reboot"]
        },
        {
            glyph: Icons.power,
            label: "Shut down",
            accent: Theme.critical,
            command: ["systemctl", "poweroff"]
        }
    ]

    // Which entry the keyboard is on. -1 means none, which is the state every
    // open starts in; see the note above.
    property int selected: -1

    // Wraps at both ends, and the first press from -1 enters the row from the
    // side the key points at: Right lands on the first card, Left on the last.
    function move(delta: int): void {
        const count = root.actions.length;
        if (root.selected < 0)
            root.selected = delta > 0 ? 0 : count - 1;
        else
            root.selected = (root.selected + delta + count) % count;
    }

    function activate(): void {
        if (root.selected >= 0)
            root.run(root.actions[root.selected]);
    }

    // Close first: the menu should be gone before the compositor starts
    // tearing the session down, or the last frame on screen is a
    // half-dismissed sheet.
    // Takes the ACTION rather than its command: one of them is a call into the
    // compositor facade instead of a process to spawn.
    function run(action: var): void {
        PowerMenuState.close();
        if (action.perform)
            action.perform();
        else
            Quickshell.execDetached(action.command);
    }

    screen: modelData
    visible: PowerMenuState.isOpen

    WlrLayershell.namespace: "quickshell-powermenu"
    // Overlay and not Top: this covers the bar and a fullscreen window alike,
    // which is the one place a session menu has to be reachable from.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, so the arrows, Enter and Escape reach us at all -- a layer
    // surface that does not hold the keyboard is never sent a keystroke.
    //
    // STATIC, not `isOpen ? Exclusive : None`. Every working PanelWindow in
    // this shell states this once and never changes it (components/Popout.qml
    // is the closest cousin), and flipping it live is what a closed menu does
    // not need anyway: `visible` already tears the whole surface down, so
    // nothing is holding the keyboard while the menu is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Pinned to the top left and sized to the whole screen. Anchors say
    // WHERE, implicitWidth/implicitHeight say HOW BIG -- the split every
    // other PanelWindow in this shell uses (components/ScreenCorner.qml,
    // modules/notifications). Anchoring all four edges stretches the layer
    // surface instead, and then the size the compositor picked is not a size
    // QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and -- the part that mattered to the old script --
    // never be pushed down by the bar's own reservation. The sheet covers the
    // bar rather than starting below it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    // Every open starts with nothing armed, and the sheet has to be told to
    // take focus: the surface holding the keyboard is not the same thing as
    // an item inside it being the one that receives the keys.
    Connections {
        target: PowerMenuState

        function onIsOpenChanged(): void {
            root.selected = -1;
            if (PowerMenuState.isOpen)
                sheet.forceActiveFocus();
        }
    }

    Rectangle {
        id: sheet

        // Sized from the SCREEN and not from `parent`. See the note on the
        // anchors above: the window's contentItem stays 0x0 no matter what
        // the layer surface measures, so `anchors.fill: parent` collapses to
        // nothing. The screen is the one measurement that is always right.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // The same glass as every other surface in the shell, and that is not
        // a stylistic choice -- it is the only alpha that gets blurred.
        //
        // The blur-quickshell rule in hyprland.lua sets ignore_alpha to 0.84,
        // just under Theme.glassAlpha (0.85), so that the antialiased edge of
        // a rounded corner is left out of the blur and stops bleeding past the
        // curve. Anything BELOW that threshold is left out too. A hand-picked
        // 0.55 here therefore fell out of the blur entirely and the sheet went
        // from frosted wallpaper to a dark tint over perfectly sharp windows.
        //
        // If this ever needs to be lighter, the threshold in hyprland.lua
        // moves with it. The two numbers are tied.
        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        focus: true

        Keys.onEscapePressed: PowerMenuState.close()
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        // Home row for the same two moves, since the rest of the session is
        // driven that way.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_H)
                root.move(-1);
            else if (event.key === Qt.Key_L)
                root.move(1);
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. It sits BELOW the cards in the file, so
        // the cards' own MouseAreas take their clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenuState.close()
        }

        Row {
            anchors.centerIn: parent
            spacing: root.cardGap

            Repeater {
                model: root.actions

                Rectangle {
                    id: card

                    required property int index
                    required property var modelData

                    // Hover and keyboard selection are the same state on
                    // purpose: there is one "this is the one" look, and it
                    // does not matter which device armed it.
                    readonly property bool active: mouse.containsMouse || root.selected === card.index

                    implicitWidth: root.cardWidth
                    implicitHeight: root.cardHeight
                    radius: Theme.cardRadius

                    color: card.active ? Qt.alpha(card.modelData.accent, 0.22) : Theme.glass(Theme.surfaceContainerHigh)

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.glyph
                            font.family: Theme.fontFamily
                            // Large enough to be the thing you aim at. The
                            // old menu used 48pt for the same reason, and it
                            // is the one number worth carrying over from it.
                            font.pointSize: 40
                            // The glyph moves with the card rather than
                            // sitting static over a shifting background.
                            color: card.active ? card.modelData.accent : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.label
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Font.Bold
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Pointing at a card also arms it for the keyboard,
                        // so the two never disagree about which one is next.
                        onEntered: root.selected = card.index
                        onClicked: root.run(card.modelData)
                    }
                }
            }
        }
    }
}
