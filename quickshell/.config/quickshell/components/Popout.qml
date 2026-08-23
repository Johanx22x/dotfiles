// A panel that hangs from the bar and reads as part of it.
// THIS IS THE HALF THE BAR SEES; the rectangle, the fillets that weld it to
// the bar and the inset around its content are in
// themes/<theme>/components/Popout.qml.
//
// ALMOST NOTHING HERE IS DRAWING, and the reason is that this is a WINDOW.
// Everything below is a fact about a Wayland layer surface, about the
// compositor, or about what a click does -- the namespace, the layer, the
// keyboard focus, the anchors, the screen-edge clamp, the exclusion mode, the
// input mask, the size the surface has reserved and the grab that dismisses
// it. A theme draws inside the window; it does not get to reconfigure it.
//
// It starts exactly at the bar's bottom edge, its top corners are square so
// there is no seam, and a CornerWedge on each side fills the junction with a
// concave fillet -- the same shape the bar uses where it meets the sides of
// the screen. The result is one continuous surface that grew downwards,
// rather than a floating menu that happens to be near the bar. That is a
// promise about shape and it now lives in the theme file, which is the only
// place that can keep it.
//
// One of these serves the whole bar: `anchorX` moves it under whichever
// widget was clicked and `contentComponent` swaps what it shows, so there is
// a single window to position and a single place where the merge is drawn.
//
// It closes on a click anywhere outside itself, through FocusGrab, which picks
// the best mechanism the running compositor offers -- an input grab where there
// is one, a transparent full-screen catcher where there is not.
//
// AND IT CLOSES WHEN THE SHELL RAISES A SURFACE OF ITS OWN, which is the case
// no click covers: the launcher, the power menu, the cheatsheet and the
// carousel all arrive by keybind without a pointer going anywhere, and the
// settings window arrives by a click ON the bar, which is the one strip the
// catcher deliberately leaves alone. That rule is modules/Surfaces.qml and the
// bar hands it this window; see the Connections there.
//
// IT REACHES A TRAY MENU TOO, and that is the point of dismissing the WINDOW
// rather than the panels inside it. The dashboard and the notification history
// have singletons that can be told to let go, so they could be closed by name.
// A tray menu and the peripheral-battery detail have no state outside this
// window, no IpcHandler and no key -- nothing can name them, and nothing can
// reopen one behind a sheet -- but one that was ALREADY up when the sheet
// arrives is left on the Overlay layer with it, where stacking is creation
// order, which is exactly what the note further down says not to rely on.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.modules

PanelWindow {
    id: root

    required property var modelData

    // Centre of the widget that opened it, in screen coordinates. The bar
    // spans the full width from x = 0, so a widget's x inside the bar is
    // already a screen x.
    property real anchorX: 0

    property bool isOpen: false

    // WHICH BAR SHOWS A PANEL THAT WAS ASKED FOR IS NOT DECIDED HERE, and it
    // was worth trying before giving up on it. There is one of these per bar,
    // and a popout can see whether IT is showing something -- it cannot see
    // that the dashboard is up on the popout of another bar, which is exactly
    // what has to be known to move a panel from one monitor to another rather
    // than open a second copy of it.
    //
    // So the panels that a keybind can summon keep their up-or-down, and the
    // bar they are drawn on, in their own singleton -- IslandState for the
    // dashboard, NotificationState for the history -- and this window is left
    // as what it always was: a surface that shows what it is told to show. The
    // same shape the launcher has, where LauncherState.isOpen outlives the
    // window that Variants destroys and rebuilds on the newly focused monitor.
    //
    // What to show. Swapping the component is what makes one window serve
    // every widget; it is destroyed when closed, so a popout never keeps
    // stale state from the last time it was open. The theme loads it, which is
    // the whole of what crosses the seam in that direction.
    property Component contentComponent: null

    // HOW FAR OUTSIDE THE PANEL THE WELD REACHES, and it stays on this side
    // even though the theme is what draws it. It is the window that has to be
    // wide enough to hold a fillet on each side of the panel, and the window
    // is this file's. A theme that draws no fillets gets a window two radii
    // wider than what it painted, which costs nothing: everywhere the panel is
    // not, the window is transparent and takes no input.
    readonly property int fillet: Theme.barCornerRadius

    // How much of the panel is hidden ABOVE the top edge.
    //
    // Welded to the bar, the rectangle starts a corner radius higher than the
    // window so its top corners are cut off by the screen edge and only the
    // bottom two round. Detached there is nothing to hide under, so the slack
    // goes to zero and all four corners are drawn -- and the content, the
    // window height and the fillets all have to agree on which of the two it
    // currently is, or the panel gains a square bottom or uneven padding.
    //
    // The theme reads it for exactly that reason. It is not a style token: it
    // is a number this window's own height is computed from, and both ends
    // have to use the same one.
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
    //
    // A FACT ABOUT THE COMPOSITOR AND NOT ABOUT STYLE, which is why a theme
    // reads it rather than deciding it.
    readonly property bool barVisible: Screens.hasBar(root.screen)
        && !Compositor.hasFullscreenOn(root.screen?.name ?? "")


    // These open on THIS popout and ask nobody. For a menu that was clicked
    // that is the whole of the rule -- a tray menu belongs to the icon that was
    // pressed, on the monitor it was pressed on -- and for a panel that follows
    // the focus it is the bottom half of one: the singleton says which bar, the
    // widget on that bar calls these.
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
    //
    // THE SHEETS ARE ON THIS LAYER, and they are not separated the same way
    // because they must not be: a fullscreen sheet has to cover this window,
    // and one layer up would be one layer nothing else could reach past. What
    // keeps them apart is time rather than depth -- they are never both up, by
    // the rule in modules/Surfaces.qml -- so the creation order between them is
    // never asked.
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
    // keeps it. What the user sees changing is the panel the theme draws, an
    // ordinary Rectangle inside a surface that is not moving; everywhere the
    // panel is not, the window is transparent and takes no input, because the
    // mask follows the panel rather than the window.
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
    //
    // AND THE HIGH-WATER MARK TRACKS THE THEME'S IMPLICIT SIZE AND NOT ITS
    // WIDTH, which is the difference between one reconfigure and sixty. The
    // implicit size is where the panel is GOING; `drawing.width` is where it
    // is on this frame of the animation, and reserving off that would raise
    // the mark on every frame -- which is exactly the tearing the mark exists
    // to prevent, arrived at from the other direction.
    implicitWidth: Math.max(root.reservedWidth, Theme.popoutMinWidth) + root.fillet * 2
    implicitHeight: Math.max(root.reservedHeight, Theme.popoutMinWidth) - root.topSlack

    color: "transparent"

    // Never reserve space and never be moved by the bar's reservation.
    exclusionMode: ExclusionMode.Ignore

    // Input stops at the panel: the fillets are decoration, and a click on
    // them belongs to the window underneath.
    //
    // THE LOADER IS THE PANEL, which is what makes this line still true after
    // the split. It is sized to what the theme reports and sits where the
    // rectangle used to sit, so masking it masks the panel -- and it is a real
    // Item on a real type, where `Loader.item` is declared QObject and would
    // cost an `[incompatible-type]` on this very assignment.
    mask: Region {
        item: drawing
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

    // ---------------- The panel, which the theme draws ----------------
    //
    // Placed exactly where the rectangle used to be: centred in the window,
    // and grown UPWARDS by the slack so its top corners round off outside the
    // visible area and the edge that meets the bar comes out straight.
    //
    // THE TWO Behaviors ARE ON THIS SIDE AND THAT IS DELIBERATE, because three
    // things have to read one geometry: the mask above, the reservation below,
    // and the fillets the theme anchors to this item's edges. Animated in the
    // theme's own file instead, the panel would be somewhere the mask was not
    // for the length of every resize, and a click near its edge would fall
    // through to the window underneath. The duration is the host's token
    // either way.
    //
    // Animating a Rectangle inside the surface and NOT the surface: the window
    // is not being reconfigured while this moves, which is the whole of the
    // note above.
    Loader {
        id: drawing

        anchors.horizontalCenter: parent.horizontalCenter
        y: -root.topSlack

        width: drawing.implicitWidth
        height: drawing.implicitHeight

        Behavior on width {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
        }

        onImplicitWidthChanged: root.reservedWidth = Math.max(root.reservedWidth, drawing.implicitWidth)
        onImplicitHeightChanged: root.reservedHeight = Math.max(root.reservedHeight, drawing.implicitHeight)

        readonly property string drawingUrl: Themes.surface("components/Popout.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: {
            drawing.build();
            // The theme's first report can land while this Loader is being
            // built, before the two handlers above are connected. Seeding the
            // mark here is what the Rectangle's own Component.onCompleted used
            // to do, and for the same reason.
            root.reservedWidth = Math.max(root.reservedWidth, drawing.implicitWidth);
            root.reservedHeight = Math.max(root.reservedHeight, drawing.implicitHeight);
        }

        onDrawingUrlChanged: drawing.build()
    }
}
