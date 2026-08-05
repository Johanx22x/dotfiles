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

    // The namespace Hyprland matches on for the blur, see the
    // blur-quickshell rule in hyprland.lua.
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

    // Transparent window, opaque surface below: the alpha belongs to the
    // Rectangle so Hyprland's blur has something to work behind.
    color: "transparent"

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
    CornerWedge {
        anchors.left: parent.left
        anchors.top: surface.bottom
        corner: "topLeft"
        radius: Theme.barCornerRadius
        fillColor: surface.color
    }

    CornerWedge {
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
            }

            Group {
                anchors.verticalCenter: parent.verticalCenter

                Workspaces {
                    barScreen: bar.modelData
                }
            }

            ActiveWindow {
                anchors.verticalCenter: parent.verticalCenter

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

            Island {
                anchors.verticalCenter: parent.verticalCenter

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

                popout: barPopout
            }

            // Volume used to sit here. It moved into the island in the
            // centre, which is where a value that changes for two seconds and
            // then stops mattering belongs -- see modules/island.
            Group {
                anchors.verticalCenter: parent.verticalCenter

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
