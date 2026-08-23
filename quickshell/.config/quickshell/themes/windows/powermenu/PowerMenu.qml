// The power menu: the small flyout off the Start button, over a dimmed screen.
//
// WINDOWS HAS NO FULL-SCREEN POWER SHEET. genesis draws one -- a row of large
// cards filling the monitor -- and that is a real shape, it is just not this
// one. The nearest thing Windows 11 actually ships is the MenuFlyout that opens
// off the power button at the bottom of Start: a compact list of text entries
// in an acrylic panel a couple of hundred pixels wide, sitting just above the
// taskbar at the left of the screen. So that is what this draws, and the three
// cards, their glyphs and their per-action accent tints went with the shape
// they belonged to.
//
// WHAT IS NOT DRAWING AND MUST SURVIVE ANY REDRAW. The action list is
// theme-side -- Compositor.logout(), systemctl reboot, systemctl poweroff --
// which is a fact about where the seam was cut rather than a decision made
// here, and it is carried across from genesis unchanged, invocation for
// invocation. Getting a power action wrong is not a cosmetic bug.
//
// THE DIM IS NOT GLASS. Every other overlay in this shell fills itself with
// Theme.glass() so the compositor blurs what is behind it; this one must not,
// because Windows' scrim is a plain fill and nothing else. See the note on
// SmokeFillColorDefault below for the value and for why it is the one colour
// this theme writes down.
//
// WHY COVERING THE SCREEN IS STILL THE EASY ONE, and it is the one thing about
// genesis's arrangement that survives the change of shape. The surface is the
// size of the monitor, so it catches a click anywhere outside the menu and that
// is what dismisses it. No HyprlandFocusGrab, and so none of the
// open-and-immediately-close trouble that comes with asking the compositor for
// an input grab on a surface that is not mapped yet.
//
// FOCUS
// The menu takes the keyboard while it is open -- Exclusive, not None -- and
// that is not free: the window underneath goes deaf for as long as the menu is
// up. It is the price of arrow keys and Enter, because a layer surface that
// does not hold the keyboard is never sent a keystroke to begin with. There are
// three ways out and all of them are one gesture: Escape, a click on the empty
// space, or SUPER + SHIFT + ESCAPE again.
//
// WHAT PROTECTS AGAINST AN ACCIDENTAL SHUTDOWN
// The menu starts with NOTHING selected -- `selected` is -1, not 0 -- so Enter
// on a freshly opened menu has nothing to activate. The first arrow key is what
// selects, which makes arming an action deliberate. Windows' own flyout has the
// same property for a different reason: it preselects nothing either.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs
import qs.modules.powermenu
// Fluent lives one directory up, and without this line the failure is at
// runtime, per read: "ReferenceError: Fluent is not defined".
import qs.themes.windows

PanelWindow {
    id: root

    // The ShellScreen this menu belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- The menu's geometry ----------------
    //
    // MenuFlyoutItemMargin = 4,2,4,2 and MenuFlyoutPresenterThemePadding =
    // 0,2,0,2, both read out of microsoft-ui-xaml
    // controls/dev/MenuFlyout/MenuFlyout_themeresources.xaml. They are declared
    // here rather than in Fluent.qml because this is the only surface in the
    // theme that draws a menu; the moment a second one does, they move up.
    //
    // The margin is what insets the highlight from the panel's own edges: the
    // thing that lights up on hover is the item's LayoutRoot, and the template
    // gives that a 4px margin left and right. A menu whose highlight runs edge
    // to edge is drawing a list box, not a Windows menu.
    readonly property int itemInsetH: 4
    readonly property int itemInsetV: 2
    readonly property int presenterPadV: 2

    // The entries, in order of how much they cost you: log out, then restart,
    // then the one that leaves the machine off.
    //
    // `command` is passed to execDetached as a list, never a string, so nothing
    // goes through a shell that does not need one.
    //
    // NO GLYPH AND NO ACCENT any more. Windows' power flyout is text and
    // nothing else -- MenuFlyoutItem's icon column is optional and the shell's
    // power entries do not use it -- and MenuFlyoutItemForeground is
    // TextFillColorPrimary for every state, so a red "Shut down" would be a
    // colour Windows does not put there.
    readonly property var actions: [
        {
            label: "Sign out",
            // The ONE action that is not a command, because the right way to
            // end a session depends on what is drawing it: each compositor
            // backend asks its own first and falls back to logind, which works
            // even on a compositor nothing here knows about.
            perform: () => Compositor.logout()
        },
        {
            label: "Restart",
            command: ["systemctl", "reboot"]
        },
        {
            label: "Shut down",
            command: ["systemctl", "poweroff"]
        }
    ]

    // Which entry the keyboard is on. -1 means none, which is the state every
    // open starts in; see the note above.
    property int selected: -1

    // Wraps at both ends, and the first press from -1 enters the list from the
    // end the key points at: Down lands on the first entry, Up on the last.
    // Up and down rather than left and right, because the entries are now a
    // column.
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

    // Close first: the menu should be gone before the compositor starts tearing
    // the session down, or the last frame on screen is a half-dismissed sheet.
    // Takes the ACTION rather than its command: one of them is a call into the
    // compositor facade instead of a process to spawn.
    function run(action: var): void {
        PowerMenuState.close();
        if (action.perform)
            action.perform();
        else
            Quickshell.execDetached(action.command);
    }

    // The widest label decides the width, the same way a MenuFlyout sizes
    // itself to its longest entry. Measured off the face the entries are drawn
    // in -- see the cheatsheet's chipMetrics for why the font is READ here
    // rather than only inside the FontMetrics: advanceWidth() is a function
    // call, so without naming the font this would be measured once, at whatever
    // size the shell first started at.
    readonly property int labelRoom: {
        if (labelMetrics.font.family === "" || labelMetrics.font.pointSize <= 0)
            return 0;

        let widest = 0;
        for (const action of root.actions)
            widest = Math.max(widest, labelMetrics.advanceWidth(action.label));

        return Math.ceil(widest);
    }

    FontMetrics {
        id: labelMetrics

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
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

    // Pinned to the top left and sized to the whole screen. Anchors say WHERE,
    // implicitWidth/implicitHeight say HOW BIG -- the split every other
    // PanelWindow in this shell uses (components/ScreenCorner.qml,
    // themes/windows/notifications). Anchoring all four edges stretches the
    // layer surface instead, and then the size the compositor picked is not a
    // size QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space, and never be pushed down by the bar's own
    // reservation. The sheet covers the taskbar rather than starting above it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    // Every open starts with nothing armed, and the sheet has to be told to
    // take focus: the surface holding the keyboard is not the same thing as an
    // item inside it being the one that receives the keys.
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
        // anchors above: the window's contentItem stays 0x0 no matter what the
        // layer surface measures, so `anchors.fill: parent` collapses to
        // nothing. The screen is the one measurement that is always right.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // SmokeFillColorDefault, and it is the one hex literal in this theme.
        //
        // #4D000000 is 30% pure black -- no blur, no noise, no tint, a plain
        // fill. It is declared TWICE in microsoft-ui-xaml
        // controls/dev/CommonStyles/Common_themeresources_any.xaml, at line 59
        // in the Default (= dark) dictionary and at line 263 in the Light one,
        // and the two are byte for byte the same. It is the only Windows value
        // that does not theme, so there is no scheme role for it and there
        // should not be one: a scheme names colours, and this is an amount of
        // black rather than a colour.
        //
        // AND IT IS BELOW THE BLUR THRESHOLD ON PURPOSE. The blur-quickshell
        // rule in hyprland.lua ignores anything under 0.84 alpha, and 0x4D is
        // 0.30, so the compositor leaves this fill out of the blur entirely and
        // what shows through is a dimmed but perfectly sharp desktop. That is
        // exactly what Windows does behind a light-dismiss layer, and it is the
        // opposite of what genesis wants here -- genesis's sheet is glass and
        // has to stay above the threshold to get blurred at all.
        color: "#4D000000"

        // No Behavior: this colour never changes. It is not a scheme role, so
        // there is nothing for a recolour to ride.

        focus: true

        Keys.onEscapePressed: PowerMenuState.close()
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        // Home row for the same two moves, since the rest of the session is
        // driven that way.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_K)
                root.move(-1);
            else if (event.key === Qt.Key_J)
                root.move(1);
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. It sits BELOW the menu in the file, so the
        // menu's own MouseAreas take their clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenuState.close()
        }

        // ---------------- The flyout ----------------
        //
        // BOTTOM LEFT, CLEAR OF THE TASKBAR. Windows opens this menu directly
        // over the power button at the bottom of Start, which is at the left of
        // the taskbar; the offset is the taskbar's own height so the panel sits
        // just above it rather than under it. Theme.barHeight and not a 48
        // written here -- the token is what moves if the taskbar is ever a
        // different height.
        Item {
            id: flyout

            x: Theme.barPadding
            y: sheet.height - flyout.height - Theme.barHeight - Theme.barPadding

            // 4 + 11 + label + 11 + 4: the item margin and the item padding on
            // each side of the widest entry. MenuFlyoutItemThemePadding is
            // 11,8,11,9 and Fluent.controlPaddingH is the 11 of it.
            // Floored at MenuFlyoutPresenterThemeMinWidth. "Sign out",
            // "Restart" and "Shut down" are short enough that the computed
            // width came out around a hundred pixels -- a menu barely wider
            // than the words in it, which is not a shape Windows draws.
            width: Math.max(Fluent.menuMinWidth,
                            root.labelRoom + (Fluent.controlPaddingH + root.itemInsetH) * 2)

            // The presenter's own 2px top and bottom, plus the first and last
            // item's 2px margin, around a column of 32px entries.
            height: entries.implicitHeight
                + (root.presenterPadV + root.itemInsetV) * 2

            // The panel itself. HIDDEN AND LAYERED because the MultiEffect
            // beside it is what draws it: an effect renders its source, so
            // drawing this as well would composite the same glass twice and the
            // panel would come out noticeably more solid than every other
            // surface in the shell. The same arrangement genesis's CornerWedge
            // uses, and for the same reason.
            //
            // ACRYLIC, WHICH IS A COLOUR HERE AND A BLUR IN THE COMPOSITOR.
            // AcrylicBackgroundFillColorDefault is tint #2C2C2C at 15% over a
            // 96% luminosity layer, and windows-11-dark's surface_container is
            // #2b2b2b -- one value off Microsoft's tint, which is what that
            // rung of the ladder was composited to be. The blur is the
            // compositor's, delivered by the blur-quickshell rule keyed on this
            // surface's namespace, and Theme.glass() is the only alpha that
            // rule does not ignore.
            Rectangle {
                id: ground

                anchors.fill: parent
                radius: Fluent.overlayRadius
                color: Theme.glass(Theme.surfaceContainer)
                antialiasing: true

                // MenuFlyoutPresenterBorderThemeThickness is 1 and the brush is
                // SurfaceStrokeColorFlyout, which is a BLACK overlay in dark
                // mode. No scheme role carries a black stroke, so this reads the
                // divider role -- the one role in the table that is a hairline
                // over a surface rather than a fill.
                border.width: 1
                border.color: Theme.outlineVariant

                visible: false
                layer.enabled: true
            }

            // The flyout shadow, from DropShadowRecipe.h by way of Fluent.qml:
            // elevation 16 at flyout depth, blurred by the elevation and offset
            // down by half of it, at the dark theme's 0.26.
            //
            // blurMax IS the blur radius in pixels and shadowBlur is the
            // fraction of it that is used, so 1.0 of Fluent.flyoutShadowBlur is
            // the 16 the recipe asks for. The source's own alpha modulates the
            // shadow, so glass at 0.85 casts a slightly lighter shadow than an
            // opaque panel would; that is the material being honest rather than
            // a number to correct.
            MultiEffect {
                anchors.fill: ground

                source: ground
                shadowEnabled: true
                blurMax: Fluent.flyoutShadowBlur
                shadowBlur: 1.0
                shadowVerticalOffset: Fluent.flyoutShadowY
                shadowOpacity: Fluent.shadowOpacity
            }

            // The entries. A sibling of the effect above rather than a child of
            // the panel, so that they are drawn and take input as ordinary
            // items instead of being flattened into a texture.
            Column {
                id: entries

                x: root.itemInsetH
                y: root.presenterPadV + root.itemInsetV
                width: flyout.width - root.itemInsetH * 2
                // 2 below one item and 2 above the next: MenuFlyoutItemMargin
                // is a margin, not a spacing, so the gap is twice it.
                spacing: root.itemInsetV * 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: entry

                        required property int index
                        required property var modelData

                        // Hover and keyboard selection are the same state on
                        // purpose: there is one "this is the one" look and it
                        // does not matter which device armed it.
                        readonly property bool current: mouse.containsMouse
                            || root.selected === entry.index

                        // From the Column, which is given an explicit width
                        // above -- so this is a read of `parent` rather than of
                        // an id outside the delegate, and there is no loop
                        // because nothing binds the Column's width back to its
                        // contents.
                        width: parent.width
                        height: Fluent.controlHeight
                        radius: Fluent.controlRadius

                        // MenuFlyoutItemBackground is SubtleFillColorTransparent
                        // at rest, Secondary on hover and Tertiary pressed --
                        // which is to say HOVER BRIGHTENS AND PRESS DIMS, the
                        // pressed fill being the darker of the two.
                        //
                        // AND NONE OF IT ANIMATES. Windows swaps the brush on a
                        // DiscreteObjectKeyFrame at time zero; Fluent.hoverMs is
                        // 0 and there is deliberately no Behavior here. A fade
                        // on hover is the tell that gives a recreation away
                        // faster than any wrong colour.
                        //
                        // THROUGH Theme.glass() AND NOT THE BARE ROLE, which
                        // Fluent.fillSubtleHover and fillPress are. Windows'
                        // subtle fills are alpha overlays and the acrylic goes
                        // on showing through them; an opaque fill here would
                        // punch a solid, unblurred patch in the panel wherever
                        // the pointer is. The two stack to 0.98 rather than
                        // 0.85, which is still above the compositor's threshold
                        // and reads as the highlight being a touch more solid
                        // than the panel -- the same arrangement every glass
                        // surface in this shell already uses for a card.
                        color: mouse.pressed ? Theme.glass(Fluent.fillPress)
                            : entry.current ? Theme.glass(Fluent.fillSubtleHover)
                            : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Fluent.controlPaddingH
                            anchors.right: parent.right
                            anchors.rightMargin: Fluent.controlPaddingH
                            anchors.verticalCenter: parent.verticalCenter

                            text: entry.modelData.label
                            elide: Text.ElideRight

                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.bodySize
                            font.weight: Fluent.normalWeight
                            // MenuFlyoutItemForeground is TextFillColorPrimary
                            // in every state, hover and pressed included.
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Pointing at an entry also arms it for the
                            // keyboard, so the two never disagree about which
                            // one is next.
                            onEntered: root.selected = entry.index
                            onClicked: root.run(entry.modelData)
                        }
                    }
                }
            }
        }
    }
}
