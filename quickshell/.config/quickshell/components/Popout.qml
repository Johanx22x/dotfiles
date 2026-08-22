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

    // Whether what is showing was ASKED FOR -- a keybind, an IPC call -- rather
    // than clicked on. Set by the two request functions below and cleared by
    // everything else; the only thing that reads it is the rule further down
    // that takes a requested panel away when this stops being the bar a request
    // means.
    property bool byRequest: false

    // IS THIS THE POPOUT A REQUEST MEANS?
    //
    // There is one of these per bar, which is right for a menu belonging to the
    // icon that was clicked and wrong for a panel summoned by a key: the
    // keybind reaches every bar at once, and every bar opening its own copy is
    // one panel drawn on every monitor. Screens.panelScreen names the single
    // bar that answers -- see the long note there for why it is grabScreens
    // that decides, so this and the launcher cannot land on different monitors.
    readonly property bool answersRequests: !!Screens.panelScreen
        && Screens.panelScreen.name === (root.screen?.name ?? "")

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
    // concave fillet on each side. With no bar to weld to, what is left is a
    // card with two square corners hanging off the top of the screen -- so it
    // stops pretending, detaches, drops its fillets and rounds all four corners
    // like the free-floating thing it has become.
    //
    // TWO WAYS FOR THE BAR NOT TO BE THERE, and only one of them used to be
    // checked. A fullscreen window covers it -- the bar is on the Top layer and
    // fullscreen draws over that -- but a monitor can also simply not HAVE one:
    // the bar is per screen and which screens carry it is a setting.
    //
    // Only testing for fullscreen meant that on a monitor without a bar this
    // panel still welded itself to one: square top corners and a fillet on each
    // side, joined to nothing, hanging off the top edge of the screen. Which is
    // exactly what it looked like.
    //
    // AND IT HAS TO BE A FULLSCREEN WINDOW YOU CAN ACTUALLY SEE. One left
    // fullscreen on a workspace that has been scrolled away from covers
    // nothing, and this panel detached for it anyway -- for as long as that
    // window lived, on every screen it had been on. What is fullscreen comes
    // from wlr-foreign-toplevel and reads the same on both flavors; whether it
    // is on screen cannot come from there at all. See the note over
    // fullscreenOutputs in CompositorBackend.qml.
    readonly property bool barVisible: Screens.hasBar(root.screen)
        && !Compositor.hasFullscreenOn(root.screen?.name ?? "")


    // THE CLICK DOORS. A click names the bar it landed on, so these open on
    // this popout and ask nobody: the tray menu belongs to the icon that was
    // clicked, on the monitor it was clicked on.
    function openAt(x: real, component: Component): void {
        anchorX = x;
        contentComponent = component;
        byRequest = false;
        isOpen = true;
    }

    function close(): void {
        isOpen = false;
        contentComponent = null;
        byRequest = false;
    }

    // Opening the same popout twice in a row closes it, which is what a
    // click on the widget that owns it should do.
    function toggleAt(x: real, component: Component): void {
        if (isOpen && contentComponent === component)
            close();
        else
            openAt(x, component);
    }

    // THE REQUEST DOORS -- what a keybind or an IPC call comes through, which
    // is every bar at once. Only the bar that answers opens anything.
    //
    // The other bars are not silent, they TIDY UP: one holding this same panel
    // puts it away, so a request can never leave two copies of one panel on two
    // monitors. That is the case where the panel was clicked open on one bar --
    // legitimately, a click names its own bar -- and the key is then pressed
    // while another bar has the focus.
    function requestOpenAt(x: real, component: Component): void {
        if (!root.answersRequests) {
            if (root.isOpen && root.contentComponent === component)
                root.close();
            return;
        }

        root.openAt(x, component);
        root.byRequest = true;
    }

    // Toggling closes wherever it is showing, answering bar or not: a key
    // pressed a second time has to put the panel away from any monitor, or the
    // fix for opening in the wrong place becomes a panel that cannot be closed.
    function requestToggleAt(x: real, component: Component): void {
        if (root.isOpen && root.contentComponent === component) {
            root.close();
            return;
        }

        root.requestOpenAt(x, component);
    }

    // THE FOCUS MOVES WHILE THE PANEL IS UP, and something has to happen. Three
    // answers were possible and this one CLOSES it.
    //
    // Following the focus is what the launcher does -- it is built from
    // Variants over grabScreens, so it is destroyed and rebuilt on the newly
    // focused monitor while its open flag rides across in a singleton. That is
    // right for a surface holding an exclusive keyboard grab, because nothing
    // else can be reached while it is up so the focus cannot wander by
    // accident. This panel holds no grab at all, and where the compositor
    // moves the focus with the pointer -- which is how this session is set up
    // -- following would mean the dashboard teleporting from one monitor to
    // the other as the pointer crossed between them.
    //
    // Staying put leaves a panel open on a monitor that no longer has the
    // focus, and leaves the keybind toggling against a copy the user is not
    // looking at.
    //
    // So it goes away, which is also what the very next click anywhere outside
    // it would have done through FocusGrab: leaving the screen is the same
    // intent arriving a moment earlier. Only what was REQUESTED is taken away
    // -- a tray menu that was clicked open belongs to its own bar and stays
    // there, which also keeps it alive on a bar whose monitor has no focused
    // window to give it the focus.
    onAnswersRequestsChanged: if (!root.answersRequests && root.byRequest)
        root.close()

    screen: modelData
    visible: isOpen

    WlrLayershell.namespace: "quickshell-popout"
    // Overlay, above the notification panel on Top. A menu is something the
    // user opened on purpose and is looking at right now; a notification
    // arrives on its own and can wait its turn. Stacking within one layer is
    // decided by creation order, which is not something to rely on, so the
    // two are kept in different layers instead.
    WlrLayershell.layer: WlrLayer.Overlay
    // NONE, AND THE REASON IS THE POINTER, NOT THE KEYBOARD.
    //
    // This asked for OnDemand so that a popout could accept a keystroke when
    // it had something to type into. Nothing in one ever has: no TextField, no
    // TextInput, no Keys handler and no activeFocus anywhere in the dashboard,
    // the tray menus or the notification history.
    //
    // What the focus did instead was cost clicks. Holding it means the
    // compositor takes it away the moment the pointer presses anything else --
    // and a client that loses keyboard focus mid-click cancels the press it
    // was holding, so the release never arrives and the widget under the
    // pointer never sees a click at all. Measured with a virtual pointer: with
    // OnDemand, one click in six on the power button did nothing whatsoever,
    // and the widget that owns the popout lost its release on three clicks out
    // of six. With None there is no focus to lose, no cancelled press, and no
    // dead click.
    //
    // Checked on both compositors rather than assumed, since this is the one
    // line of that work which applies to Hyprland as well: the same battery
    // run in a nested Hyprland 0.56.2 with this set to None and again with it
    // set back to OnDemand produced identical logs, so its focus grab does not
    // depend on the surface taking keyboard focus.
    //
    // Give this back the day something in here types, and give it back
    // narrowly -- bound to the content that needs it rather than to every
    // popout that opens.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

    // WHERE THE BLUR GOES, ASKED FOR BY THE SURFACE ITSELF.

    FocusGrab {
        window: root
        targetScreen: root.screen
        active: root.isOpen

        // THE BAR KEEPS ITS OWN CLICKS.
        //
        // This panel hangs off the bar and every widget that opens one lives
        // up there, so the click that moves from this panel to the next one
        // always lands on the bar. Left to the catcher, that click was spent
        // closing this panel and the next one needed a second -- the same two
        // clicks that opening and closing used to cost, moved somewhere else.
        //
        // The strip is the bar's own height, which is what this window is
        // already positioned against a few lines up, and it is only left out
        // while there is a bar there to receive it: with none -- no bar on
        // this screen, or a fullscreen window over it -- the hole would be a
        // dead patch of screen where clicks stopped dismissing for no visible
        // reason.
        passthrough: root.barVisible
            ? Qt.rect(0, 0, root.screen?.width ?? 0, Theme.barHeight)
            : Qt.rect(0, 0, 0, 0)

        onDismissed: if (root.isOpen)
            root.close()
    }

    // The two fillets that weld the panel to the bar. Same colour as the
    // panel, and outside it so they are not clipped by its own rounding.
    //
    // Named, because the blur region above is built from them: it reads each
    // one's `radius`, `corner`, `visible` and position rather than being told
    // any of it twice.
    CornerWedge {
        id: leftFillet

        visible: root.barVisible

        // Anchored to the PANEL and not to the window: the window is now
        // larger than what is drawn, and a fillet at its edge would weld the
        // bar to thin air. The blur region inherits that for free -- it reads
        // this item's x, which the anchor keeps on the panel's edge through
        // the width animation.
        anchors.right: panel.left
        anchors.top: parent.top
        corner: "topRight"
        radius: root.fillet
        fillColor: panel.color
    }

    CornerWedge {
        id: rightFillet

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
