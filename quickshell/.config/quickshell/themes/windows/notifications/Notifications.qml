// The panel the notifications are stacked in, top right.
//
// IT IS NOT THE DAEMON ANY MORE, and that is the one thing worth knowing before
// reading the rest. What owns org.freedesktop.Notifications -- the bus name,
// the stack tags, what the mute swallows, the claim that decides whether a
// notification exists at all -- is modules/notifications/NotificationDaemon.qml
// in the host, where there is one copy of it whatever happens to be drawing.
// This file reads two properties off it, `tracked` and `count`, and draws them.
// It used to be both halves, and ../README.md carried a paragraph saying that
// was the wrong side of the seam.
//
// SHAPE
// Not one floating card per notification: a single surface that hangs off
// the bar and grows as notifications arrive, with each notification a box
// inside it. It is flush with the bar's bottom edge and flush with the right
// side of the screen, so what it looks like is the bar bulging downwards --
// the same fillet that carries the bar into the sides of the screen carries
// it into this.
//
// WITH NO BAR UNDER IT that shape is wrong rather than merely unnecessary, so
// it comes apart: no fillet, no sheet behind the cards, corners kept. What is
// left is the notification and nothing else, which is roughly what dunst drew.
// See `undocked` -- it happens over a fullscreen window, and it happens on a
// main monitor that was never given a bar.
//
// The window takes input only where the panel is, so the area it spans while
// empty does not swallow clicks meant for the window underneath.

import Quickshell
import Quickshell.Wayland
// THE ONE LINE OF THE PROTOCOL STILL IN HERE, and it is a type name rather than
// a behaviour: the Repeater's delegate declares what a row of the model IS, so
// that the assignment to the card's `notification` is a checked one. A theme
// that would rather not name the type can write `var` there and drop this
// import. What it must not do is answer the bus.
import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.components
import qs.modules.notifications
import qs.modules.powermenu

PanelWindow {
    id: root

    required property var modelData

    readonly property int count: NotificationDaemon.count

    // Whether the bar is actually behind this panel right now.
    //
    // The whole shape below -- the fillet, the straight top edge, the
    // rectangle pushed up past the window -- assumes the bar is there to weld
    // to. A fullscreen window covers the Top layer, so it takes the bar away
    // while leaving this on Overlay, and the weld is left joining the panel to
    // nothing: a fillet hanging in mid air over the game.
    //
    // IS THE BAR ABSENT, for either of the two reasons it can be. A fullscreen
    // window covers it, and a monitor can also simply not carry one -- the bar
    // is per screen and which screens have it is a setting. Both mean this
    // panel has nothing to weld itself to.
    readonly property bool barCovered: !Screens.hasBar(root.modelData)
        || Compositor.hasFullscreenOn(root.modelData?.name ?? "")

    // NO BAR TO WELD TO, for either of the two reasons there can be one: it is
    // covered by a fullscreen window, or this monitor simply has no bar --
    // which became possible when the bar stopped being on every screen the
    // shell lives on. The shell's screen and the bar's screens are two
    // different lists now (see Screens.qml), and this panel follows the first
    // one: notifications belong on the monitor you are told to look at, which
    // is the main one, whether or not it happens to carry a bar.
    //
    // Everything below reads this rather than barCovered. The distinction the
    // drawing cares about is not WHY there is no bar, it is whether there is
    // one -- and a fillet welded to a bar that was never there looks exactly
    // as wrong as one welded to a bar a game is covering.
    readonly property bool undocked: root.barCovered || !Screens.hasBar(root.modelData)

    screen: modelData

    WlrLayershell.namespace: "quickshell-notifications"

    // Top normally, Overlay once the bar is covered.
    //
    // Top is the right home most of the time: it puts the tray menus and the
    // power menu -- both on Overlay -- ABOVE a notification. A menu was opened
    // deliberately and is being read; a notification arrives by itself and can
    // wait.
    //
    // But stacking against a fullscreen window turned out to depend on which
    // surface was mapped FIRST. A notification that arrived before the window
    // went fullscreen ended up underneath it, while one that arrived after came
    // out on top: the same panel behaving two ways depending on the order of
    // events. Moving to Overlay for as long as the bar is covered settles it,
    // and costs nothing -- over a fullscreen window there is no menu to lose
    // to anyway.
    WlrLayershell.layer: root.undocked ? WlrLayer.Overlay : WlrLayer.Top

    // BOTTOM RIGHT, ABOVE THE TASKBAR, AND WITH A GAP. Windows raises its
    // toasts from the corner nearest the clock, and they FLOAT: there is no
    // weld, no fillet and no shared edge with the taskbar, which is the same
    // arrangement the Start panel uses and the opposite of the one genesis
    // uses here. Genesis hangs this panel off the bar's underside and makes it
    // look like part of the bar; a gap on either side would break that. Here
    // the gap is the point.
    anchors {
        bottom: true
        right: true
    }

    margins {
        bottom: Theme.barHeight + root.floatGap
        right: root.floatGap
    }

    // OURS. Microsoft publishes nothing about toast placement; 12 is the gap
    // measured off the Start panel, reused here so the two surfaces sit the
    // same distance off the same edge.
    readonly property int floatGap: 12

    // What the panel actually shows, before the rectangle is grown past the
    // window edges to hide its other corners.
    readonly property int panelHeight: stack.implicitHeight + Theme.notificationPadding * 2

    // NO FILLET TO MAKE ROOM FOR. barCornerRadius is 0 under this theme, so
    // the term genesis adds here for the wedge to the left of the panel is
    // zero anyway; it is dropped rather than left as a zero nobody can read.
    implicitWidth: Theme.notificationWidth + Theme.notificationPadding * 2
    implicitHeight: root.panelHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    color: "transparent"

    // Nothing to show: no surface at all, rather than an invisible window
    // sitting over the corner of the screen.
    //
    // And nothing while the power menu is up. Both live on the Overlay layer,
    // so which one wins is down to the order the surfaces happened to be
    // created in -- not something to leave to chance when one of the two is a
    // modal sheet asking whether to end the session. A notification arriving
    // mid-decision is also exactly the wrong moment to be covering a button
    // labelled "Shut down". They are not lost: the panel comes back with them
    // still in it as soon as the menu closes.
    visible: root.count > 0 && !PowerMenuState.isOpen

    exclusionMode: ExclusionMode.Ignore

    // Input only where the panel is; the fillet is decoration.
    mask: Region {
        item: panel
    }

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    // Welds the panel to the bar on its open side: material ADDED outside the
    // panel, filling the angle. The bottom corners are the panel's own
    // rounding, which is the opposite operation.
    //
    // Named, because the blur region above is built from it: it reads this
    // item's `radius`, `corner` and `visible` rather than being told any of
    // it twice.
    CornerWedge {
        id: fillet

        anchors.left: parent.left
        anchors.top: parent.top
        corner: "topRight"
        radius: Theme.barCornerRadius
        fillColor: panel.color

        // Only when there is a bar to weld to. Over a fullscreen window this
        // fillet is a wedge of panel colour joined to nothing. The blur region
        // follows this same property, so an undocked panel does not leave a
        // frosted square hanging off its corner.
        visible: !root.undocked
    }


    // THE ROUNDING IS UNIFORM, AND THE SQUARE EDGES ARE CLIPPED AWAY.
    //
    // The obvious way to write this is bottomLeftRadius on its own with the
    // other three at zero. Do not: Rectangle's per-corner radius path is NOT
    // antialiased -- setting `antialiasing: true` changes nothing -- and the
    // curve comes out as 2-3px stair steps. Verified by swapping one for the
    // other and comparing the same corner: uniform `radius` gives a clean
    // one-pixel gradient, per-corner gives blocks.
    //
    // So the rectangle uses a plain `radius` and is pushed BEYOND the window
    // upwards, behind the bar. The window clips that, so the edge meeting the
    // bar comes out straight while BOTH bottom corners round normally.
    Rectangle {
        id: panel

        anchors.left: parent.left
        anchors.leftMargin: Theme.barCornerRadius
        anchors.right: parent.right
        anchors.top: parent.top
        // Pushed up behind the bar so the window clips its top corners
        // straight -- but only when the bar is there. Over a fullscreen window
        // it sits where it is and keeps all four corners, which is what a card
        // floating over a game should look like anyway.
        anchors.topMargin: root.undocked ? 0 : -Theme.barCornerRadius

        height: root.panelHeight + (root.undocked ? 0 : Theme.barCornerRadius)

        radius: Theme.barCornerRadius
        antialiasing: true

        // Nothing behind the cards once it has come away from the bar. The
        // sheet exists to make the panel read as the bar bulging downwards; 
        // with no bar there it is just a slab of glass floating over someone's
        // game, and NotificationCard already carries its own background and
        // rounding. Undocked, what is left is the notification and nothing
        // else -- which is what dunst looked like.
        color: root.undocked ? "transparent" : Theme.glass(Theme.surface)

        // The panel grows and shrinks as notifications come and go; animating
        // the height is what makes it read as one thing expanding rather than
        // as cards appearing out of nowhere.
        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }
    }

    // The content is positioned against the WINDOW, not against the rectangle
    // above: that one is deliberately larger than what is visible.
    Column {
        id: stack

        anchors.left: parent.left
        anchors.leftMargin: Theme.barCornerRadius + Theme.notificationPadding
        anchors.top: parent.top
        anchors.topMargin: Theme.notificationPadding

        spacing: Theme.notificationGap

        Repeater {
            model: NotificationDaemon.tracked

            NotificationCard {
                required property Notification modelData

                notification: modelData

                // Each card slides in from the right as it arrives.
                x: Theme.notificationWidth

                Component.onCompleted: x = 0

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
