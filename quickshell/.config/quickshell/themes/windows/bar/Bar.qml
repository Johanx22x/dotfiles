// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// The Windows 11 taskbar
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// One layer surface across the BOTTOM of the screen, 48 tall, square, edge to
// edge. Nothing in the host says where a bar goes: the anchors, the layer, the
// exclusive zone, the input region and the namespace are all declared here, so
// moving the bar from the top of the screen to the bottom is a change to this
// file and to nothing else.
//
// WHAT WAS OVERRIDDEN FROM GENESIS'S BAR, AND WHY. Genesis's version of this
// file argues four things at length. Three of them are answered differently
// here and the fourth is kept verbatim:
//
//   THE ANCHOR IS `bottom`. Genesis's reasoning about the exclusive zone
//   survives intact -- a zone is only defined for a surface anchored to an edge
//   (optionally plus both its sides) -- and bottom+left+right satisfies it
//   exactly as top+left+right did.
//
//   THERE IS NO FILLET STRIP. Genesis makes the window taller than the bar so
//   the corner fillets that carry it into the sides of the screen live inside
//   the same surface and get the same blur. Under this theme
//   Theme.screenCornerRadius is 0, because WINDOWS ROUNDS WINDOWS AND NOT THE
//   SCREEN, so Theme.barCornerRadius is 0, CornerWedge is the empty
//   implementation and there is nothing to carry. The window is the bar.
//
//   THERE IS NO `mask`. It follows from the line above. Genesis masks input to
//   the bar proper so that clicks on the transparent fillet strip fall through
//   to the window underneath; with no strip, the window and the bar are the
//   same rectangle and a mask naming it would be a line that changes nothing.
//   Windows' taskbar takes every click inside its own rectangle.
//
//   `ExclusionMode.Normal` IS KEPT, and its reason is now a different one.
//   Genesis needs it because Auto would reserve the fillet strip as well and
//   push windows down by a mostly transparent band. Here Auto would reserve the
//   same 48. It stays Normal because the reservation is then WRITTEN DOWN
//   rather than derived from whatever this window's height happens to be, and
//   the day somebody gives the taskbar a shadow or a drop strip the number does
//   not silently follow it.
//
// THE NAMESPACE IS NOT NEGOTIABLE. `quickshell-bar` is what the blur rule in
// hypr/.config/hypr/hyprland.lua matches on -- `hl.layer_rule` named
// "blur-quickshell" -- and niri blurs globally. A surface under a name that
// rule does not know is not left unblurred: it falls through to the global
// blur, which has different parameters and no xray, and comes out visibly
// blurrier than the bar it is supposed to be part of.
//
// THE THREE ZONES, AND THE MIDDLE ONE IS CENTRED ON THE SCREEN.
//
//   LEFT      what this desktop is doing, and only when it was asked for.
//   CENTRE    Start and the app buttons, centred on the SCREEN and not on
//             whatever space the other two zones left over. That is the whole
//             point of Windows 11's taskbar and it is one anchor.
//   RIGHT     the taskbar corner: the status glyphs, the tray, the clock.
//
// WHAT LIVES WHERE IS STILL Config's ANSWER AND NOT THIS FILE'S. Every
// `bar.widget(...)` gate below is the same gate genesis had, reading the same
// per-monitor set out of Config. A theme decides how a widget is DRAWN and
// where in the sentence it falls; it does not get to decide that a switch the
// settings window offers does nothing.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.modules
// A THEME REACHES ITS OWN PARTS BY RELATIVE PATH AND NEVER BY ITS OWN NAME.
// It is loaded out of its directory rather than imported as a module -- see
// modules/Themes.qml -- so `import qs.themes.<name>.island` would not resolve
// from in here even if it were written, and a directory that never spells its
// own name is one `cp -r` away from being a second theme.
import "../island"
import "../notifications"

PanelWindow {
    id: bar

    // The ShellScreen this bar belongs to, from Variants in shell.qml.
    required property var modelData

    screen: modelData

    // WHICH BAR THIS IS, in the spelling Config stores each bar's widgets
    // under. There can be one of these per monitor, and each reads its own
    // complete set -- see the widget section in Config.qml.
    //
    // A FUNCTION USED INSIDE `visible:` BINDINGS, which is reactive and not a
    // one-off read: the engine records every QML property touched while a
    // binding evaluates, including inside the functions it calls, and the map
    // this reads through is a property on Config. Flipping a switch re-runs
    // these.
    readonly property string screenKey: Config.screenKey(bar.modelData)

    function widget(name: string): bool {
        return Config.barWidget(bar.screenKey, name);
    }

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    // Transparent window, translucent surface inside it: the alpha belongs to
    // the Rectangle so the blur has something to work behind.
    color: "transparent"

    // One popout for the whole bar: it moves under whichever widget was
    // clicked and swaps its content, instead of every widget owning a window.
    //
    // WHERE IT COMES OUT IS NOT THIS FILE'S TO SAY, AND TODAY THAT IS WRONG.
    // components/Popout.qml anchors itself to the TOP of the screen and offsets
    // by `Theme.barHeight` (its `margins.top`, and the passthrough strip in its
    // grab does the same), which was the whole truth while every theme put its
    // bar up there. With the taskbar at the bottom the tray menus, the
    // notification history, the peripheral-battery detail and the calendar all
    // still open flush against the TOP edge, detached from the thing that
    // opened them. It is a host facade and not a theme file, so it is reported
    // rather than worked around here: a bar that quietly stopped using the
    // shared popout would take the tray menus and the history out with it.
    //
    // The id is NOT `popout`: in `Tray { popout: popout }` the right-hand side
    // resolves to the Tray's own property of that name before the outer id, and
    // the widget gets handed undefined.
    Popout {
        id: barPopout

        modelData: bar.modelData
    }

    // THIS FILE REPORTS AND OBEYS; IT DOES NOT DECIDE. Which of the shell's own
    // surfaces may be on screen together is one rule in one file,
    // modules/Surfaces.qml. What is left here is the two lines a singleton
    // cannot write itself, because a popout is per bar and a singleton is not.
    //
    // AN ASSIGNMENT AND NOT A Binding, because this file is INSTANTIATED ONCE
    // PER BAR: a `Binding { target: Surfaces }` written here is one binding per
    // bar onto one property of a singleton, and a property holds one binding --
    // whichever bar was built last would own it and the rest would write
    // nowhere.
    Connections {
        target: barPopout

        function onIsOpenChanged(): void {
            Surfaces.popoutOpen = barPopout.isOpen;
        }
    }

    // The other half: the broadcast that puts this bar's popout away, whatever
    // it is showing and whichever surface asked for the screen.
    Connections {
        target: Surfaces

        function onDismissPopouts(): void {
            barPopout.close();
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent

        color: Theme.glass(Theme.surface)

        // NO `Behavior on color`. Theme.recolorDuration is 0 under this theme
        // -- the palette is pinned, so there is no wallpaper recolour to ride
        // -- and an animation of zero length is a moving part that does not
        // move.

        // THE BAR'S OWN EMPTY SPACE STILL PUTS A POPOUT AWAY.
        //
        // A popout leaves the bar's strip out of its click catcher on purpose,
        // so that moving from one of its panels to the next costs one click
        // rather than two. The gaps between the widgets are not widgets though,
        // and a click there was a click outside the panel like any other.
        //
        // FIRST among the children, and that is load-bearing: a later sibling
        // is offered input before an earlier one, so every widget declared below
        // still takes its own clicks and only what none of them wanted reaches
        // this.
        MouseArea {
            anchors.fill: parent
            // hoverEnabled, and it earns its place: without it the press that
            // follows a click somewhere else on the bar was not delivered to
            // this item at all -- nothing fired and the popout stayed up.
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: barPopout.close()
        }

        // THE ONE STROKE, ALONG THE EDGE THAT FACES THE DESKTOP.
        //
        // OURS. A `Rectangle#BackgroundStroke` exists in the taskbar's own XAML
        // -- a Windhawk dump names it -- and no value for it is published
        // anywhere. Theme.outlineVariant is DividerStrokeColorDefault
        // (#15FFFFFF over the base), which is what Windows uses for every other
        // hairline that separates one surface from the next, so it is the
        // defensible guess rather than a measurement.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            height: 1
            color: Theme.outlineVariant
        }

        // ================= LEFT =================
        //
        // EMPTY ON A STOCK WINDOWS 11 TASKBAR, and empty here too unless a
        // switch says otherwise. What lands in it is what this desktop has that
        // Windows does not: the island's narration of what is playing, and the
        // focused window's title.
        //
        // Every direct child anchors its own vertical centre. A Row positions on
        // the x axis only and leaves children at y = 0, so items of different
        // heights would line up by their tops.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            // THE ISLAND IS NOT A WINDOWS IDEA AND IT IS STILL HERE.
            //
            // It came out of the centre, because the centre now belongs to
            // Start and the app buttons and because a narrator that grows and
            // shrinks would push them off the middle of the screen every time
            // a track changed -- the exact failure genesis's own notes about
            // the badges are about.
            //
            // It was not DELETED, and that is the seam talking rather than
            // taste: bar/Bar.qml is the only thing in the shell that
            // instantiates island/Island.qml, so a theme that stopped drawing
            // it would not be styling the island differently, it would be
            // removing the surface. `island` is a switch the settings window
            // offers and it defaults to on.
            Island {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("island")
                popout: barPopout
            }

            // WINDOWS' TASKBAR SHOWS NO WINDOW TITLE, and this is still drawn.
            //
            // Dropping it from the layout was the other option and it is the
            // worse one: `activeWindow` is a per-monitor switch that Config
            // seeds ON, so a theme that ignored it would give the Bar page a
            // toggle that flips, saves, and changes nothing on screen -- which
            // is this repository's oldest failure mode wearing a new hat.
            //
            // So it moved instead of going away. It is a left-zone item rather
            // than a centre one, drawn the way Windows' own taskbar draws a
            // labelled button: 16px icon, one line of body text, no backplate
            // and no click. Somebody who wants the stock taskbar switches it
            // off and the left of the bar is empty, which is the real answer.
            ActiveWindow {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("activeWindow")
                barScreen: bar.modelData
            }
        }

        // ================= CENTRE =================
        //
        // CENTRED ON THE SCREEN AND NOT ON WHAT IS LEFT OVER. One anchor to the
        // surface's own horizontal centre does it; putting these in the same Row
        // as the zones either side would centre them in the gap instead, and the
        // middle of the taskbar would move every time the clock got a digit
        // wider.
        //
        // START SITS WITH THE APP BUTTONS rather than at the corner, which is
        // the one thing everybody noticed about Windows 11 on the day it
        // shipped. Logo.qml's own note argues that the corner is the one target
        // a pointer cannot overshoot and that a launcher deserves it; that
        // argument is genesis's and it is not wrong, it is simply not what this
        // taskbar does.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Logo {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("logo")
            }

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter

                barScreen: bar.modelData
            }
        }

        // ================= RIGHT: THE TASKBAR CORNER =================
        //
        // Reading outwards from the middle of the bar: what is being done to
        // this desktop, then what other applications are saying, then what the
        // machine is, then the shell's own doors, then the time, and the
        // notification centre in the corner itself. That is Windows' own order
        // and it is also the order of how much any of it changes.
        //
        // EACH ITEM IS ITS OWN HIT TARGET with its own hover fill -- there is no
        // pill around groups of them, because Windows has no such pill. See
        // TaskbarItem.qml for the box they all share.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            // Do not disturb, and screen capture somebody else started. Both
            // are things being done to this desktop right now, which is what
            // the corner of a Windows taskbar is for -- the screen-sharing
            // indicator lives in exactly this spot on the real thing.
            //
            // WHO SAYS THE MUTE IS ON, decided here because this is the only
            // place that can see both of them: the bell at the far end draws
            // bellOff in the accent while the mute is on, so this badge would
            // be the same bar saying it twice. Switch the bell off and the badge
            // comes back whole -- a mute whose only trace is a number is bad, a
            // mute with no trace at all is worse.
            DndIndicator {
                anchors.verticalCenter: parent.verticalCenter

                active: !bar.widget("notifications")

                barScreen: bar.modelData
            }

            // This is for capture the shell did NOT start: a Discord share, a
            // call, OBS. A recording started from the dashboard is a different
            // thing and shows in the island itself, with a stop button.
            CaptureIndicator {
                anchors.verticalCenter: parent.verticalCenter
            }

            // The notification area proper: other applications' icons, in one
            // strip that washes as a unit.
            Tray {
                id: tray

                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("tray") && tray.hasItems
                popout: barPopout
            }

            // The machine's own battery, on laptops. Its own target rather than
            // sharing the peripherals': they answer different questions -- "go
            // and charge that thing" against "save your work".
            SystemBattery {
                anchors.verticalCenter: parent.verticalCenter
            }

            PeripheralBattery {
                id: peripheralBattery

                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("battery") && peripheralBattery.hasAny
                popout: barPopout
            }

            // The keyboard layout, between the readings and the doors, which is
            // where Windows puts the input-language indicator too. Hidden with
            // one layout configured: a control that cannot change anything,
            // reporting a fact that cannot change either.
            KeyboardLayout {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("keyboardLayout") && Config.keyboardLayouts.length > 1
            }

            // THE SHELL'S OWN THREE DOORS. On Windows these would be somebody
            // else's tray icons, which is exactly what they are here: this
            // shell's icons in this shell's notification area.
            UpdatesButton {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("updates")
            }

            SettingsButton {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("settingsButton")
            }

            // NOT LAST ANY MORE, AND THAT IS THIS BUTTON'S OWN RULE BEING KEPT
            // RATHER THAN BROKEN. PowerButton.qml asks that nothing sit one
            // slipped click from it. On genesis's bar the far end was the safe
            // place for that, because the far end was the end of a row of
            // controls; on a bottom bar the far end is the BOTTOM-RIGHT CORNER
            // OF THE SCREEN -- the one target on a screen a pointer cannot
            // overshoot, which is the same fact Logo.qml spends a paragraph on
            // from the other side. Putting the one control that can end the
            // session there would be handing it the easiest click on the
            // desktop. The clock and the notification centre take that corner
            // instead, where an overshoot costs a calendar.
            PowerButton {
                anchors.verticalCenter: parent.verticalCenter
            }

            Clock {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("clock")
                popout: barPopout
            }

            // The notification centre, in the corner, which is where Windows
            // has kept it since Windows 10.
            NotificationButton {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("notifications")
                popout: barPopout
            }
        }
    }
}
