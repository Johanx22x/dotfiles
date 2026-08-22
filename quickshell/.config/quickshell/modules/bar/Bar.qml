// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// The bar: one continuous surface, flush against the top edge
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// One layer surface spanning the full width, no margin and no rounded
// corners. Being anchored to top+left+right is also what lets it reserve its
// own space: the exclusive zone is only defined for a surface anchored to an
// edge (optionally plus both its sides), which is why the earlier
// island-per-widget layout needed a separate 1px surface just to make the
// reservation. One bar, one anchor, no workaround.
//
// ORDER OF THE WIDGETS
// Left to right, reading like a sentence: where am I (OS, workspace), what
// am I looking at (window), what is playing, and then the state of the
// machine -- ending with the clock and the connectivity indicators at the
// far edge, the things you glance at rather than read.
//
// Groups (components/Group.qml) mark what belongs together. Lone indicators
// sit directly on the bar, or it turns into a fence of pills.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/island"
import "root:/modules/launcher"
import "root:/modules/notifications"
import "root:/modules/settings"

PanelWindow {
    id: bar

    // The ShellScreen this bar belongs to, from Variants in shell.qml.
    required property var modelData

    screen: modelData

    // WHICH BAR THIS IS, in the spelling Config stores each bar's widgets
    // under. There can be one of these per monitor, and each reads its own
    // complete set: there is no longer a base above them that a monitor
    // disagrees with, so this key is the whole of the question -- see the
    // widget section in Config.qml for why the base went.
    //
    // A FUNCTION USED INSIDE `visible:` BINDINGS, which is reactive and not a
    // one-off read: the engine records every QML property touched while a
    // binding evaluates, including inside the functions it calls, and the map
    // this reads through is a property on Config. Flipping a switch re-runs
    // these. That is also why Config assigns barWidgetsByMonitor whole instead
    // of writing into the object it already holds -- a mutation in place
    // changes nothing the engine is watching.
    readonly property string screenKey: Config.screenKey(bar.modelData)

    function widget(name: string): bool {
        return Config.barWidget(bar.screenKey, name);
    }

    // The namespace Hyprland matches on to pick the blur's PARAMETERS -- see
    // the blur-quickshell rule in hyprland.lua. WHERE the blur goes is asked
    // for by this surface, a few lines down, and reads the same under both
    // compositors.
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        left: true
        right: true
    }

    // Taller than the bar itself: the extra strip at the bottom is where the
    // corner fillets live, so they are part of the same surface and get the
    // same blur as the bar rather than being separate windows.
    implicitHeight: Theme.barHeight + Theme.barCornerRadius

    // Normal and not Auto: Auto would reserve the whole surface, fillets
    // included, and push windows down by a strip that is mostly transparent.
    // Only the bar proper is reserved; Hyprland's gaps_out adds the usual
    // 20px below that.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    // Input stops at the bar. The fillet strip is decoration: clicks there
    // go through to whatever window is underneath.
    mask: Region {
        item: surface
    }

    // Transparent window, translucent surface below: the alpha belongs to the
    // Rectangle so the blur has something to work behind.
    color: "transparent"

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    // One popout for the whole bar: it moves under whichever widget was
    // clicked and swaps its content, instead of every widget owning a window.
    // See components/Popout.qml.
    //
    // The id is NOT `popout`: in `Tray { popout: popout }` the right-hand
    // side resolves to the Tray's own property of that name before the outer
    // id, and the widget gets handed undefined.
    Popout {
        id: barPopout

        modelData: bar.modelData
    }

    // The island's dashboard and the launcher hang from the same place and
    // cannot both be up. The rule itself lives in LauncherState; these two
    // are the wiring, and they are here because this is the only file that
    // can see both the popout and that singleton.
    Binding {
        target: LauncherState
        property: "dashboardOpen"
        value: barPopout.isOpen
    }

    Connections {
        target: LauncherState

        function onIsOpenChanged(): void {
            if (LauncherState.isOpen)
                barPopout.close();
        }
    }

    // AND THE SETTINGS WINDOW, WHICH IS NOT TIDINESS BUT CLICKS.
    //
    // On a compositor with no focus-grab protocol -- niri, and anything that
    // is not Hyprland -- an open popout is backed by a transparent
    // full-screen surface on the Top layer that swallows the first click
    // landing anywhere outside the panel. Top is ABOVE every ordinary
    // window, so while that catcher is up the settings window is a window
    // nobody can click: the first press on it is spent putting the popout
    // away, and the control under the pointer never hears about it at all.
    //
    // Nothing used to close the popout on the way there. The gear that opens
    // the window lives on the bar, and the bar is exactly the strip the
    // catcher leaves out of its input region so that moving between panels
    // costs one click -- so the press reached the gear, the window opened,
    // and the catcher stayed up over it. The keybind never touches the bar
    // at all and left it up the same way.
    //
    // Closed from here and not from the button: SUPER + C goes through this
    // singleton and through no widget, and this is the file that can see
    // both it and the popout -- the same argument as the launcher above.
    Connections {
        target: SettingsState

        function onIsOpenChanged(): void {
            if (SettingsState.isOpen)
                barPopout.close();
        }
    }

    // The fillets that carry the bar down into the sides of the screen. Same
    // colour as the bar, and outside `surface` so they are not clipped by it.
    //
    // Named, because the blur region above is built from them: it reads each
    // one's `radius` and `corner` rather than being told those numbers a
    // second time.
    CornerWedge {
        id: leftFillet

        anchors.left: parent.left
        anchors.top: surface.bottom
        corner: "topLeft"
        radius: Theme.barCornerRadius
        fillColor: surface.color
    }

    CornerWedge {
        id: rightFillet

        anchors.right: parent.right
        anchors.top: surface.bottom
        corner: "topRight"
        radius: Theme.barCornerRadius
        fillColor: surface.color
    }

    Rectangle {
        id: surface

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.barHeight

        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        // THE BAR'S OWN EMPTY SPACE STILL PUTS A POPOUT AWAY.
        //
        // A popout leaves this strip out of its click catcher on purpose, so
        // that moving from one of its panels to the next costs one click
        // rather than two. The gaps between the widgets are not widgets
        // though, and a click there was a click outside the panel like any
        // other -- without this it would land on the bar and do nothing at
        // all, which is the one thing the hole would have made worse.
        //
        // FIRST among the children, and that is load-bearing: a later sibling
        // is offered input before an earlier one, so every widget declared
        // below still takes its own clicks and only what none of them wanted
        // reaches this. The island's catch-all is placed by the same rule.
        MouseArea {
            anchors.fill: parent
            // hoverEnabled, and it earns its place: without it the press
            // that follows a click somewhere else on the bar was not
            // delivered to this item at all -- nothing fired and the popout
            // stayed up. Measured three times out of three each way.
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: barPopout.close()
        }

        // Every direct child of these Rows anchors its own vertical centre.
        // A Row positions on the x axis only and leaves children at y = 0, so
        // items of different heights -- a 30px button next to a 28px group
        // next to full-height text -- would line up by their tops.
        //
        // ================= LEFT =================
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.groupSpacing

            Logo {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("logo")
            }

            Group {
                anchors.verticalCenter: parent.verticalCenter

                Workspaces {
                    barScreen: bar.modelData
                }
            }

            ActiveWindow {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("activeWindow")
                barScreen: bar.modelData
            }
        }

        // ================= CENTRE =================
        // The island. It replaces the Media widget that used to sit here and
        // subsumes it: media is one of the things the island can be about, not
        // a widget of its own. See modules/island.
        Row {
            id: centre

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            // Switchable per bar, which is what it is for: a second island on
            // a second bar narrates the same desktop twice. That argument is
            // why this one may be switched off and the power button may not,
            // and SUPER + D still opens the dashboard with the island gone.
            // It is NOT why a new bar starts with one or without: a new bar
            // starts WITH it, because the same seed serves the first bar and
            // the first bar is the one a fresh clone comes up with. The whole
            // trade is written out over the seed in Config's defaults.
            //
            // THE BADGES SURVIVE IT. They anchor to this Row's edges rather
            // than to the island, so with the island hidden the Row is zero
            // wide at the centre of the bar and they simply meet there, one on
            // each side -- still centred, still saying what they said. On most
            // bars only the capture badge is ever drawn: the do-not-disturb one
            // below stands in for a bell this bar does not have.
            Island {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("island")
                popout: barPopout
            }
        }

        // The do-not-disturb badge, on the island's LEFT edge and outside the
        // centred Row for the same reason as the capture badge below: inside
        // it, the Row would grow when the badge appeared and the centre of the
        // bar would shift because you muted your notifications.
        //
        // Left and right of the island on purpose, on the bars that draw both.
        // Both are facts that have to stay true on screen rather than take a
        // turn in the island's one slot, and putting them on opposite sides is
        // what keeps them from being read as the same kind of thing: one is
        // something being done to this desktop, the other something this
        // desktop was told to do.
        DndIndicator {
            anchors.right: centre.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            // WHO SAYS THE MUTE IS ON, decided here because this is the only
            // place that can see both of them.
            //
            // The bell at the right end draws bellOff in the accent while the
            // mute is on, and carries NotificationState.unread on the door you
            // pay that debt through. That is one control saying the whole
            // thing, so wherever it is drawn this badge would be the same bar
            // saying it again from the middle -- which is what it used to do,
            // with the two of them splitting the sentence between opposite
            // ends of one bar.
            //
            // Switch the bell off on this bar and the badge comes back whole,
            // glyph and count together. It is not decoration there: the mute
            // outlives a shell reload (see NotificationState), so a bar with
            // nothing saying it would be a bar that is silently muted. A mute
            // whose only trace is a number is bad; a mute with no trace at all
            // is worse.
            //
            // This was `showCount` and gated only the number, back when the
            // badge drew the glyph on every bar regardless.
            active: !bar.widget("notifications")
        }

        // The screen-capture badge, anchored to the island's right edge and
        // deliberately OUTSIDE the centred Row above.
        //
        // Inside it, the Row would grow when the badge appeared and the island
        // would slide left to keep the pair centred -- the centre of the bar
        // shifting because something started capturing. Anchored out here the
        // island never moves and the badge grows out beside it.
        //
        // This is for capture the shell did NOT start: a Discord share, a
        // call, OBS. A recording started from the dashboard is a different
        // thing and shows in the island itself, with a stop button.
        CaptureIndicator {
            anchors.left: centre.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
        }

        // ================= RIGHT =================
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.barPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.groupSpacing

            Tray {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("tray")
                popout: barPopout
            }

            // Whatever wireless thing has a battery, when there is one. It
            // sits before the clock rather than after: everything to the
            // right of here is either the time or a control, and a reading
            // dropped among the controls reads as one of them.
            // The machine's own battery, on laptops. Its own pill rather than
            // sharing the peripherals' one: they answer different questions --
            // "go and charge that thing" against "save your work" -- and a
            // shared pill would read as one list of interchangeable numbers.
            Group {
                anchors.verticalCenter: parent.verticalCenter
                visible: systemBattery.present

                SystemBattery {
                    id: systemBattery

                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Group {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.widget("battery") && peripheralBattery.hasAny

                // The pill itself carries the warning when there is only one
                // thing to warn about -- see alertingAlone in the widget. The
                // fallback repeats Group's own default because assigning here
                // replaces its binding rather than adding to it.
                color: peripheralBattery.alertingAlone
                    ? Qt.alpha(Theme.critical, 0.18)
                    : Theme.glass(Theme.surfaceContainerHigh)

                PeripheralBattery {
                    id: peripheralBattery

                    anchors.verticalCenter: parent.verticalCenter

                    popout: barPopout
                }
            }

            // The keyboard layout, between the readings and the clock.
            //
            // ITS OWN PILL, and the position is the argument: it is not one of
            // the readings before it -- it is a mode, and the only widget on
            // this side that answers to a click other than the shell's own
            // controls at the far end. Sharing the batteries' pill would file
            // it as another number about the hardware; joining the controls
            // pill would file it as part of the shell. It is neither, so it
            // stands between them.
            //
            // Hidden with one layout configured: see the widget's own note.
            Group {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("keyboardLayout") && Config.keyboardLayouts.length > 1

                KeyboardLayout {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Volume used to sit here. It moved into the island in the
            // centre, which is where a value that changes for two seconds and
            // then stops mattering belongs -- see modules/island.
            Group {
                anchors.verticalCenter: parent.verticalCenter

                visible: bar.widget("clock")

                Clock {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // The shell's own controls, in a pill of their own. They are not
            // readings like the groups before them, and that is the point of
            // putting them together: one pill at the end says "this is where
            // you operate the shell" instead of three loose glyphs trailing
            // off the edge.
            //
            // The gap INSIDE this pill is groupSpacing, not the itemSpacing a
            // group normally uses. See PowerButton: nothing may sit one
            // slipped click from it, and sharing a background does not change
            // that. The bell gets the same gap for free, which is more air
            // than it strictly needs and cheaper than a second rule.
            Group {
                anchors.verticalCenter: parent.verticalCenter

                spacing: Theme.groupSpacing

                // FIRST IN THE PILL, so the two ends of it stay where they
                // were: the gear keeps its neighbour and the power button
                // keeps having nothing after it. The notification history
                // opens from here -- see NotificationButton for why the list
                // stopped being a tab of the dashboard in the middle.
                NotificationButton {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: bar.widget("notifications")
                    popout: barPopout
                }

                // BETWEEN THE BELL AND THE GEAR, which is where it belongs
                // among the three doors in this pill: the bell is about what
                // the desktop has said, this is about what the machine is, the
                // gear is about everything else. It also puts the flag next to
                // the window it opens.
                UpdatesButton {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: bar.widget("updates")
                }

                SettingsButton {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: bar.widget("settingsButton")
                }

                // LAST, and it stays last. The bar ends in the one control
                // that can end the session, with nothing after it to reach
                // past.
                PowerButton {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
