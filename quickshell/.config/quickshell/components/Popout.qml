// A panel that hangs from the bar and reads as part of it.
//
// It starts exactly at the bar's bottom edge, its top corners are square so
// there is no seam, and a CornerWedge on each side fills the junction with a
// concave fillet -- the same shape the bar uses where it meets the sides of
// the screen. The result is one continuous surface that grew downwards,
// rather than a floating menu that happens to be near the bar.
//
// One of these serves the whole bar: `anchorX` moves it under whichever
// widget was clicked and `contentComponent` swaps what it shows, so there is
// a single window to position and a single place where the merge is drawn.
//
// It closes on a click anywhere outside itself, through FocusGrab, which picks
// the best mechanism the running compositor offers -- an input grab where there
// is one, a transparent full-screen catcher where there is not.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: root

    required property var modelData

    // Centre of the widget that opened it, in screen coordinates. The bar
    // spans the full width from x = 0, so a widget's x inside the bar is
    // already a screen x.
    property real anchorX: 0

    property bool isOpen: false

    // What to show. Swapping the component is what makes one window serve
    // every widget; it is destroyed when closed, so a popout never keeps
    // stale state from the last time it was open.
    property Component contentComponent: null

    readonly property int fillet: Theme.barCornerRadius

    // How much of the panel is hidden ABOVE the top edge.
    //
    // Welded to the bar, the rectangle starts a corner radius higher than the
    // window so its top corners are cut off by the screen edge and only the
    // bottom two round. Detached there is nothing to hide under, so the slack
    // goes to zero and all four corners are drawn -- and the content, the
    // window height and the fillets all have to agree on which of the two it
    // currently is, or the panel gains a square bottom or uneven padding.
    readonly property int topSlack: root.barVisible ? Theme.cardRadius : 0


    // IS THE BAR ACTUALLY THERE?
    //
    // This panel is welded to the bar's underside: square top corners and a
    // concave fillet on each side. A fullscreen window covers the bar -- it is
    // on the Top layer and fullscreen windows draw over that -- so the weld
    // ends up joining the panel to nothing, and what is left is a card with
    // two square corners floating in the middle of a game.
    //
    // So when the bar is hidden the panel stops pretending: it detaches, drops
    // its fillets and rounds all four corners like the free-floating thing it
    // has become.
    // Answered through wlr-foreign-toplevel rather than through either
    // compositor's IPC, so it works the same on both -- see the note on
    // hasFullscreenOn in CompositorBackend.qml.
    readonly property bool barVisible: !Compositor.hasFullscreenOn(root.screen?.name ?? "")


    function openAt(x: real, component: Component): void {
        anchorX = x;
        contentComponent = component;
        isOpen = true;
    }

    function close(): void {
        isOpen = false;
        contentComponent = null;
    }

    // Opening the same popout twice in a row closes it, which is what a
    // click on the widget that owns it should do.
    function toggleAt(x: real, component: Component): void {
        if (isOpen && contentComponent === component)
            close();
        else
            openAt(x, component);
    }

    screen: modelData
    visible: isOpen

    WlrLayershell.namespace: "quickshell-popout"
    // Overlay, above the notification panel on Top. A menu is something the
    // user opened on purpose and is looking at right now; a notification
    // arrives on its own and can wait its turn. Stacking within one layer is
    // decided by creation order, which is not something to rely on, so the
    // two are kept in different layers instead.
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand and not Exclusive: the popout accepts a keystroke when it has
    // something to type into, without stealing the keyboard from the window
    // underneath the rest of the time.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        left: true
    }

    margins {
        // Flush with the bottom of the bar, or -- with no bar to be flush
        // with -- clear of the screen edge by the same gap windows get.
        top: root.barVisible ? Theme.barHeight : Theme.barCornerRadius
        // Centred under the widget, then kept inside the screen. Without the
        // clamp, a popout opened by the rightmost widget would hang off the
        // edge.
        left: {
            const half = root.implicitWidth / 2;
            const rightmost = (root.screen?.width ?? 0) - root.implicitWidth - Theme.barPadding;
            return Math.round(Math.max(Theme.barPadding, Math.min(root.anchorX - half, rightmost)));
        }
    }

    // THE WINDOW ONLY EVER GROWS, AND THAT IS THE POINT.
    //
    // Its size drives a Wayland LAYER SURFACE. Following the content meant a
    // surface reconfigure -- and a re-centre, since this window is centred on
    // its anchor -- every time the content changed size, and animating the
    // content meant sixty of them in a fifth of a second. That is what tore.
    //
    // So the window takes the largest size the content has ever needed and
    // keeps it. What the user sees changing is `panel` below, an ordinary
    // Rectangle inside a surface that is not moving; everywhere the panel is
    // not, the window is transparent and takes no input, because the mask
    // follows the panel rather than the window.
    //
    // The cost is a window that can be larger than what it draws. Nothing
    // reads it: it is transparent, click-through, and only ever as large as
    // something this popout genuinely showed at some point.
    property int reservedWidth: 0
    property int reservedHeight: 0

    // NOT reset on close. Releasing it there was tried and broke the popout
    // outright: the content is loaded lazily, so at the moment the window
    // becomes visible the reservation was still zero and the surface was
    // created with an invalid size it never recovered from. Keeping the
    // high-water mark for the session is also the point -- resizes stop
    // happening at all once each popout has been seen once.
    //
    // The floors are what make the first frame valid, before any content has
    // reported a size.
    implicitWidth: Math.max(root.reservedWidth, Theme.popoutMinWidth) + root.fillet * 2
    implicitHeight: Math.max(root.reservedHeight, Theme.popoutMinWidth) - root.topSlack

    color: "transparent"

    // Never reserve space and never be moved by the bar's reservation.
    exclusionMode: ExclusionMode.Ignore

    // Input stops at the panel: the fillets are decoration, and a click on
    // them belongs to the window underneath.
    mask: Region {
        item: panel
    }

    FocusGrab {
        window: root
        targetScreen: root.screen
        active: root.isOpen
        onDismissed: if (root.isOpen)
            root.close()
    }

    // The two fillets that weld the panel to the bar. Same colour as the
    // panel, and outside it so they are not clipped by its own rounding.
    CornerWedge {
        visible: root.barVisible

        // Anchored to the PANEL and not to the window: the window is now
        // larger than what is drawn, and a fillet at its edge would weld the
        // bar to thin air.
        anchors.right: panel.left
        anchors.top: parent.top
        corner: "topRight"
        radius: root.fillet
        fillColor: panel.color
    }

    CornerWedge {
        visible: root.barVisible

        anchors.left: panel.right
        anchors.top: parent.top
        corner: "topLeft"
        radius: root.fillet
        fillColor: panel.color
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter

        readonly property int targetWidth: Math.max(holder.implicitWidth + Theme.groupPadding * 2, Theme.popoutMinWidth)
        readonly property int targetHeight: holder.implicitHeight + Theme.groupPadding * 2 + root.topSlack

        onTargetWidthChanged: root.reservedWidth = Math.max(root.reservedWidth, targetWidth)
        onTargetHeightChanged: root.reservedHeight = Math.max(root.reservedHeight, targetHeight)
        Component.onCompleted: {
            root.reservedWidth = Math.max(root.reservedWidth, targetWidth);
            root.reservedHeight = Math.max(root.reservedHeight, targetHeight);
        }

        width: panel.targetWidth

        // Animated here and NOT on the window: this is a Rectangle inside a
        // surface that is not being reconfigured, so it can move freely.
        Behavior on width {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        // Grown UPWARDS by one radius and pushed the same amount above the
        // window, so its top corners round off outside the visible area and
        // the edge that meets the bar comes out straight.
        //
        // Why not topLeftRadius/topRightRadius at 0 and be done: Rectangle's
        // per-corner radius path is NOT antialiased -- `antialiasing: true`
        // makes no difference to it -- and the rounded corners come out as
        // 2-3px stair steps. A uniform `radius` is antialiased properly, so
        // the square edges are made by clipping rather than by geometry.
        // Grown upwards only while it is welded to the bar. Detached, the top
        // corners have to be visible, so the rectangle sits where it is drawn.
        y: -root.topSlack
        height: panel.targetHeight

        radius: Theme.cardRadius
        antialiasing: true

        color: Theme.glass(Theme.surface)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Item {
            id: holder

            // Centred on the visible area: the rectangle extends one radius
            // above the window, and centring on it would push the content up.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.topSlack + Theme.groupPadding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height

            Loader {
                active: root.isOpen
                sourceComponent: root.contentComponent
            }
        }
    }
}
