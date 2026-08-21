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
    //
    // ext-background-effect: the client names the region behind it that should
    // be blurred, and both compositors here implement it -- niri since 26.04,
    // Hyprland since 0.56.0. It replaces the guessing a compositor has to do
    // from outside, which is what a layer-rule or a layerrule amounts to: they
    // are handed a rectangle and have to work out from the alpha in it which
    // pixels were meant.
    //
    // Deliberately NOT the whole window. It is a corner radius taller than the
    // bar, and that extra strip is the fillets -- mostly transparent, since a
    // fillet is what is left of a square after a quarter circle is taken out of
    // it. Blur the rectangle and the strip lights up across the full width of
    // the screen, just under the bar.
    //
    // So: the bar proper, plus each fillet in the shape the fillet is actually
    // drawn. See components/WedgeRegion.qml for how the second half is built
    // and what was checked on screen to trust it.
    //
    // AND THE RECTANGLE IS STILL FLUSH WITH THE PAINT, which the launcher, the
    // popouts and the notification panel are deliberately not: they stand a
    // pixel back so their rounded corners stop stepping, and the reason is in
    // WedgeRegion.qml. It does not apply here. `surface` has no corner radius
    // and it is anchored to three edges of the window with an integer height,
    // so every side of it lands on a whole pixel and a straight edge on a whole
    // pixel is rasterised exactly -- measured: no half-covered pixel anywhere
    // along one. Standing back would buy nothing and cost a line of unblurred
    // pixels the full width of the screen, right under the bar, which is very
    // nearly the artifact this region was written to remove. The two fillets
    // carry the inset because the two fillets are where the curve is.
    BackgroundEffect.blurRegion: Region {
        item: surface

        WedgeRegion { wedge: leftFillet }
        WedgeRegion { wedge: rightFillet }
    }

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
            // now also why a NEW bar starts without one -- see the seed in
            // Config's defaults. SUPER + D still opens the dashboard with the
            // island gone, which is the note on Config.barWidgets about why
            // this one may be switched off and the power button may not.
            //
            // THE TWO BADGES SURVIVE IT. They anchor to this Row's edges rather
            // than to the island, so with the island hidden the Row is zero
            // wide at the centre of the bar and they simply meet there, one on
            // each side -- still a pair, still centred, still saying what they
            // said.
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
        // Left and right of the island on purpose. Both are facts that have to
        // stay true on screen rather than take a turn in the island's one
        // slot, and putting them on opposite sides is what keeps them from
        // being read as the same kind of thing: one is something being done to
        // this desktop, the other something this desktop was told to do.
        DndIndicator {
            anchors.right: centre.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
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
            // you operate the shell" instead of two loose glyphs trailing off
            // the edge.
            //
            // The gap INSIDE this pill is groupSpacing, not the itemSpacing a
            // group normally uses. See PowerButton: nothing may sit one
            // slipped click from it, and sharing a background does not change
            // that.
            Group {
                anchors.verticalCenter: parent.verticalCenter

                spacing: Theme.groupSpacing

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
