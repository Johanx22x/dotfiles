// THE TOASTS, BOTTOM RIGHT, ABOVE THE TASKBAR AND CLEAR OF IT.
//
// scratchpad/ref/toast-bottom-right.jpg is the whole brief for this file: the
// card floats with a real margin from the right screen edge and from the top
// of the taskbar, touching neither. No weld, no fillet, no shared edge -- a
// Windows toast is a small window that happens to be in the corner, not a
// growth off the bar.
//
// HOW IT CLEARS THE TASKBAR IS THE COMPOSITOR'S JOB AND NOT A SUBTRACTION.
// ExclusionMode.Normal with a zone of zero means "reserve nothing, respect
// what others reserved", so the bottom edge of this window is already the top
// edge of the taskbar and the margin below is the gap in the photograph. The
// arithmetic version -- anchor to the screen edge and subtract Theme.barHeight
// -- is the same picture until the bar is hidden, on another screen, or under
// a fullscreen window, and then it is a toast floating 48px up over nothing.
//
// NEWEST NEAREST THE TASKBAR. The model arrives in arrival order and the
// column is anchored by its bottom edge, so a new card appears at the bottom
// and the stack grows upward. There is no photograph of more than one toast at
// a time in the reference set -- Windows shows one at a time and queues the
// rest -- so the direction is OURS, chosen to match the corner they come from.
//
// The namespace is not decorative: Hyprland's blur-quickshell layer rule
// matches on it, and a namespace that is not on that list falls through to the
// global blur with different parameters and no xray.
//
// NO DROP SHADOW, and it is a real difference from the photograph. Windows
// puts a soft shadow under the card; drawing one here means a MultiEffect over
// a source rectangle that is then covered by an acrylic card, which composites
// the card over the shadow's own black instead of over the wallpaper and
// throws away the transparency this theme is built on. A shadow that costs the
// acrylic is a worse likeness than no shadow.

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.components
import qs.modules
import qs.modules.notifications
import qs.themes.windows

PanelWindow {
    id: root

    required property var modelData

    // THE SAME GAP EVERY FLYOUT UNDER THIS THEME LEAVES, and it is
    // components/Popout.qml's number rather than one of this file's:
    // Fluent.flyoutInset is the twelve that holds Quick Settings and the
    // notification centre off the taskbar and off the screen edge. Measured
    // off toast-minimal-outlook.png at 1:1 a toast sits about seventeen
    // pixels in, which is the same gap to within the error of reading it off
    // a photograph -- and a second constant four pixels away from an existing
    // one is how a theme drifts.
    readonly property int edgeGap: Fluent.flyoutInset

    screen: modelData

    // NOT WHILE A FLYOUT IS UP ON THIS SCREEN. With the notification centre
    // open, Windows raises no toast at all: the notification lands directly
    // in the centre's list, which this shell already does for free -- the
    // centre's list is bound to NotificationState.history and history takes
    // every arrival as it happens. What this shell did WRONG was raise the
    // toast anyway, on the Top layer, under a popout on Overlay: half a card
    // sticking out from behind the panel, reported by Johan as exactly that.
    //
    // The rule covers EVERY flyout of this bar's, not only the centre,
    // because they all hang over the same corner the toasts rise from --
    // Quick Settings and the tray flyouts included. Whether real Windows
    // suppresses a toast while Quick Settings is open is not something a
    // screenshot can settle after the fact, and it is not worth a wrong
    // guess: a suppressed toast still lands in history and still puts its
    // count on the clock's unread badge, and half a toast behind a panel is
    // worse on this desktop than a deferred one whichever way Windows calls
    // it.
    //
    // The window and not the cards, so the suppressed toast keeps its timer:
    // one with time left when the flyout closes shows for the remainder,
    // which is the closest a surface that cannot replay can come to not
    // having hidden it.
    visible: NotificationDaemon.count > 0
        && !(Surfaces.popoutScreens[root.modelData?.name ?? ""] ?? false)

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Top

    // Toasts never take the keyboard. A card that stole focus would take it
    // from whatever was being typed into.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
        right: true
    }

    implicitWidth: Theme.notificationWidth + root.edgeGap * 2
    implicitHeight: stack.implicitHeight + root.edgeGap * 2

    color: "transparent"

    // Reserve nothing, respect the taskbar's reservation. See the header.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    // Only the cards take input. Without this the whole corner of the screen
    // is a dead patch for as long as a toast is up, including the part of it
    // that is transparent.
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.edgeGap

        width: Theme.notificationWidth
        spacing: Theme.notificationGap

        Repeater {
            model: NotificationDaemon.tracked

            NotificationCard {
                id: card

                // Typed and hoisted: inside a delegate an untyped read is
                // checked by nothing at all.
                required property Notification modelData

                notification: card.modelData

                // The entrance. OURS -- the reference set is still
                // photographs, so nothing in it can say how a toast moves --
                // and deliberately small: one of Windows' three durations, its
                // one easing spline, and a slide short enough to read as the
                // card arriving rather than as an animation being played.
                //
                // A Translate and not `y`: the Column owns y, and a card that
                // animated its own would fight the layout every time the stack
                // changed length.
                opacity: 0
                transform: Translate {
                    id: entrance

                    y: Theme.notificationIconSize

                    // An interceptor, so it needs no default property to live
                    // in -- which a Transform does not have.
                    Behavior on y {
                        NumberAnimation {
                            duration: Fluent.normalMs
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Fluent.easeOut
                        }
                    }
                }

                Component.onCompleted: {
                    card.opacity = 1;
                    entrance.y = 0;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Fluent.normalMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Fluent.easeOut
                    }
                }
            }
        }
    }
}
