// THE POWER FLYOUT.
//
// Windows has no full-screen power sheet, and the temptation to draw one is
// the whole reason this header is long. The nearest thing the real system
// ships is the MenuFlyout that opens off the power button at the bottom of
// Start -- a compact column of TEXT entries in an acrylic panel a couple of
// hundred pixels wide, over a dimmed desktop. So that is what this is: a menu,
// near the bottom left where the Start button lives, and nothing else. No
// cards, no glyphs, no per-action tint. The reference photographs are
// startmenu-classic-pinned-recommended.jpg for where the button is and
// contextmenu-explorer-dark.png for what a menu off it looks like -- the
// second is the one with the measurements in it, because the two are the same
// presenter.
//
// WHAT A PHOTOGRAPH SAYS THAT THE CONTROL DOCS DO NOT: the thing that lights
// up on hover is INSET from the panel's own edges. MenuFlyoutItem's LayoutRoot
// carries Margin="4,2,4,2", so there is a four-pixel strip of untouched
// acrylic down both sides of every highlight, and the entries sit on a 36px
// pitch rather than a 32px one. A menu whose highlight runs edge to edge is
// drawing a list box.
//
// THE ACTIONS ARE THE PART THAT IS NOT DRAWING. Compositor.logout(), then
// `systemctl reboot`, then `systemctl poweroff`, spawned as argument lists and
// never through a shell. That the shell's power actions are theme-side at all
// is a fact about where the seam was cut rather than a decision taken here,
// and getting one of them wrong is not a cosmetic bug -- they are carried over
// invocation for invocation and were diffed against the last drawing of this
// file rather than written from memory.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs
import qs.modules.powermenu
// The theme's own singleton, by MODULE and never `import ".."` -- through the
// relative form Fluent resolves to the type rather than to the instance and
// every number below silently reads undefined. See Fluent.qml's header.
import qs.themes.windows

PanelWindow {
    id: root

    // The ShellScreen this menu belongs to, from Variants in shell.qml.
    required property var modelData

    // ---------------- The presenter's own geometry ----------------
    //
    // MenuFlyoutItemMargin = 4,2,4,2 and MenuFlyoutPresenterThemePadding =
    // 0,2,0,2, both out of microsoft-ui-xaml
    // controls/dev/MenuFlyout/MenuFlyout_themeresources.xaml.
    //
    // HERE AND NOT IN Fluent.qml, on purpose. This is the only surface in the
    // theme that draws a menu presenter; the moment a second one does -- and
    // components/MenuRow.qml is the one that would -- these three move up and
    // the two files read the same numbers. Putting them there first would be
    // publishing an interface nobody is on the other end of yet.
    readonly property int itemInsetH: 4
    readonly property int itemInsetV: 2
    readonly property int presenterPadV: 2

    // The entries, in order of how much they cost you.
    //
    // `command` is handed to execDetached as a LIST, so nothing goes through a
    // shell that has no reason to be involved. "Sign out" is the one that is
    // not a command at all, because how a session ends depends on what is
    // drawing it -- each compositor backend asks its own first and falls back
    // to logind, which works on a compositor nothing here knows about.
    //
    // NO GLYPHS. MenuFlyoutItem has an icon column and Windows' power entries
    // leave it empty; MenuFlyoutItemForeground is TextFillColorPrimary in every
    // state, so a red "Shut down" would be a colour the real menu does not
    // contain.
    readonly property var actions: [
        {
            label: "Sign out",
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

    // Which entry the keyboard is on, -1 for none.
    //
    // NOTHING IS ARMED WHEN THE MENU OPENS, and that is a guard rather than a
    // detail: Enter on a menu that preselected its first entry is a sign-out
    // nobody asked for. The first arrow key is what selects. Windows' own
    // flyout preselects nothing either.
    property int selected: -1

    // Wraps at both ends. From -1 the list is entered from the end the key
    // points at: Down lands on the first entry, Up on the last.
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

    // Takes the ACTION and not its command, because one of the three is a call
    // into the compositor facade rather than a process to spawn.
    //
    // CLOSES FIRST. The menu should be off the screen before the session starts
    // coming down, or the last frame anybody sees is a half-dismissed sheet.
    function run(action: var): void {
        PowerMenuState.close();
        if (action.perform)
            action.perform();
        else
            Quickshell.execDetached(action.command);
    }

    // How much room the longest entry needs, measured in the face it is drawn
    // in. The font is READ here and not only inside the FontMetrics: a binding
    // re-runs when a property IT read changes, and advanceWidth() is a function
    // call, so without naming the font this would be measured once at whatever
    // type size the shell first came up at.
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
    // Overlay rather than Top: a session menu has to be reachable from over a
    // fullscreen window, which is the one place it really matters.
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, or the arrows, Enter and Escape never arrive: a layer surface
    // that does not hold the keyboard is not sent a keystroke at all. Stated
    // once and never flipped with `isOpen` -- `visible` tears the whole surface
    // down, so nothing is holding the keyboard while the menu is away.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Anchors say WHERE, implicitWidth/implicitHeight say HOW BIG. Anchoring
    // all four edges stretches the layer surface instead, and the size the
    // compositor then picked is not a size QML ever sees.
    anchors {
        top: true
        left: true
    }

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    // Never reserve space and never be pushed up by the taskbar's own
    // reservation: the dim covers the bar rather than stopping above it.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    // COVERING THE WHOLE SCREEN IS WHAT MAKES THE DISMISS EASY. A click
    // anywhere outside the menu lands on this surface, so there is no
    // HyprlandFocusGrab and none of the open-and-immediately-close trouble that
    // comes of asking the compositor to grab input on a surface that is not
    // mapped yet.

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

        // Sized from the SCREEN and not from `parent`: the window's contentItem
        // stays 0x0 whatever the layer surface measures, so `anchors.fill:
        // parent` collapses to nothing.
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        // SmokeFillColorDefault, and it is the one hex literal in this theme.
        //
        // #4D000000 is thirty per cent pure black -- no blur, no noise, no
        // tint. It is declared TWICE in microsoft-ui-xaml
        // controls/dev/CommonStyles/Common_themeresources_any.xaml, once in the
        // Default (dark) dictionary and once in the Light one, and the two are
        // byte for byte identical. It is the only Windows value that does not
        // theme, which is exactly why there is no scheme role for it and why
        // there should not be: a scheme names colours, and this is an amount of
        // black.
        //
        // AND IT IS UNDER THE BLUR THRESHOLD ON PURPOSE. hyprland.lua's
        // blur-quickshell rule ignores anything below 0.84 alpha and 0x4D is
        // 0.30, so the compositor leaves this fill out of the blur entirely:
        // what shows through is a dimmed but perfectly sharp desktop, which is
        // what Windows puts behind a light-dismiss layer.
        color: "#4D000000"

        // No Behavior on it. This is not a scheme role, so there is nothing for
        // a recolour to ride.

        focus: true

        Keys.onEscapePressed: PowerMenuState.close()
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        // The home row does the same two moves, since the rest of the session
        // is driven that way.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_K)
                root.move(-1);
            else if (event.key === Qt.Key_J)
                root.move(1);
            else
                return;

            event.accepted = true;
        }

        // The empty space dismisses. Declared BELOW the menu so the menu's own
        // MouseAreas take their clicks first.
        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenuState.close()
        }

        // ---------------- The flyout ----------------
        //
        // BOTTOM LEFT AND CLEAR OF THE TASKBAR. Windows opens this over the
        // power button at the bottom of Start, and Start is at the left end of
        // the bar. Theme.barHeight rather than a 48 written here: the token is
        // what moves if the taskbar is ever a different height.
        Item {
            id: flyout

            x: Theme.barPadding
            y: sheet.height - flyout.height - Theme.barHeight - Theme.barPadding

            // 4 + 11 + the longest label + 11 + 4: the item's own margin and the
            // item's padding on each side.
            //
            // FLOORED AT MenuFlyoutPresenterThemeMinWidth, and that floor is
            // doing real work here. "Sign out", "Restart" and "Shut down" are
            // short enough that the computed width came out around a hundred
            // pixels -- a menu barely wider than the three words in it, which
            // is not a shape Windows draws.
            width: Math.max(Fluent.menuMinWidth,
                            root.labelRoom + (Fluent.controlPaddingH + root.itemInsetH) * 2)

            // The presenter's 2px top and bottom, plus the first and last
            // item's own 2px margin, around the column of entries.
            height: entries.implicitHeight + (root.presenterPadV + root.itemInsetV) * 2

            // The panel. HIDDEN AND LAYERED because the MultiEffect beside it
            // is what puts it on the screen: an effect renders its source, so
            // drawing this as well would composite the same acrylic twice and
            // the menu would come out visibly more solid than every other
            // flyout in the shell.
            //
            // Fluent.acrylic() and not Theme.glass(): the bar carries the
            // wallpaper's colour and a flyout over the same wallpaper does not,
            // which is the one thing about this material that no document says
            // and every photograph shows.
            Rectangle {
                id: ground

                anchors.fill: parent
                radius: Fluent.overlayRadius
                color: Fluent.acrylic(Theme.surfaceContainer)
                antialiasing: true

                // MenuFlyoutPresenterBorderThemeThickness is 1 and its brush is
                // SurfaceStrokeColorFlyout, a BLACK overlay in dark mode. No
                // scheme role carries a black stroke, so this reads the divider
                // role -- the one role in the table that is a hairline over a
                // surface rather than a fill.
                border.width: 1
                border.color: Theme.outlineVariant

                visible: false
                layer.enabled: true
            }

            // The flyout shadow, from DropShadowRecipe.h by way of Fluent.qml:
            // elevation 16 at flyout depth, blurred by the elevation and
            // dropped by half of it, at the dark theme's 0.26.
            //
            // blurMax IS the radius in pixels and shadowBlur is the fraction of
            // it used, so 1.0 of Fluent.flyoutShadowBlur is the sixteen the
            // recipe asks for. The source's own alpha modulates the shadow, so
            // acrylic casts a slightly lighter one than an opaque panel would;
            // that is the material being honest, not a number to correct.
            MultiEffect {
                anchors.fill: ground

                source: ground
                shadowEnabled: true
                blurMax: Fluent.flyoutShadowBlur
                shadowBlur: 1.0
                shadowVerticalOffset: Fluent.flyoutShadowY
                shadowOpacity: Fluent.shadowOpacity
            }

            // The entries: a SIBLING of the effect rather than a child of the
            // panel, so they are drawn and take input as ordinary items instead
            // of being flattened into the texture above.
            Column {
                id: entries

                x: root.itemInsetH
                y: root.presenterPadV + root.itemInsetV
                width: flyout.width - root.itemInsetH * 2
                // 2 below one item and 2 above the next: MenuFlyoutItemMargin is
                // a margin and not a spacing, so the gap between two is twice it.
                spacing: root.itemInsetV * 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: entry

                        required property int index
                        required property var modelData

                        // Hover and keyboard selection are ONE state. There is a
                        // single "this is the one next" look and it does not
                        // matter which device armed it.
                        readonly property bool current: pointer.containsMouse
                            || root.selected === entry.index

                        // A read of `parent`, which the Column above gives an
                        // explicit width, rather than of an id from outside the
                        // delegate. Nothing binds the Column's width back to its
                        // contents, so there is no loop.
                        width: parent.width
                        height: Fluent.controlHeight
                        radius: Fluent.controlRadius

                        // MenuFlyoutItemBackground: SubtleFillColorTransparent at
                        // rest, Secondary on hover, Tertiary pressed. HOVER
                        // BRIGHTENS AND PRESS DIMS -- the pressed fill is the
                        // darker of the two, and having that backwards is the
                        // second-best tell that something is a recreation.
                        //
                        // AND NONE OF IT ANIMATES. Windows swaps the brush on a
                        // DiscreteObjectKeyFrame at time zero; Fluent.hoverMs is
                        // 0 and there is deliberately no Behavior here.
                        //
                        // Through Fluent.acrylic() rather than the bare role,
                        // because Windows' subtle fills are alpha overlays and
                        // the acrylic goes on showing through them. An opaque
                        // fill would punch a solid patch in the panel wherever
                        // the pointer happens to be.
                        color: pointer.pressed ? Fluent.acrylic(Fluent.fillPress)
                            : entry.current ? Fluent.acrylic(Fluent.fillSubtleHover)
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
                            // TextFillColorPrimary in every state, hover and
                            // pressed included.
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Pointing at an entry also arms it for the keyboard,
                            // so the two can never disagree about which one is
                            // next.
                            onEntered: root.selected = entry.index
                            onClicked: root.run(entry.modelData)
                        }
                    }
                }
            }
        }
    }
}
