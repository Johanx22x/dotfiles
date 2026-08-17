// "Close when the user clicks anywhere else", however this compositor can.
//
// Drop one of these next to a layer surface, give it the window and a screen,
// and connect `dismissed`. Which mechanism does the work is decided here and
// nowhere else:
//
//   focusGrab capability   the compositor's own grab (Hyprland). The click that
//                          dismisses also reaches whatever was under it.
//   otherwise              a transparent full-screen surface underneath, which
//                          works anywhere and swallows that click.
//
// There is no generic protocol for this. Hyprland has hyprland-focus-grab-v1,
// nothing equivalent has been standardised, and niri implements none -- so the
// fallback is not a stopgap waiting for a better day, it is the portable answer
// and it is what a third compositor will get.
//
// LOADED BY URL, ON PURPOSE. `import Quickshell.Hyprland` binds that module to
// the compositor as soon as a file containing it is read, which is where the
// "does not support hyprland-toplevel-mapping-v1" warning in a niri session
// came from. A Loader with a `source` string does not resolve the file until it
// is actually needed, so the Hyprland import never happens anywhere else.

import Quickshell
import QtQuick
import "root:/"

Item {
    id: root

    // The surface being protected, and the screen it is on.
    required property var window
    required property var targetScreen

    // Only grabs while this is true.
    property bool active: false

    signal dismissed

    // Never draws anything itself; both implementations are windows or grabs.
    visible: false

    Loader {
        id: impl

        // Nothing is created while the popout is closed: a catcher that existed
        // all the time would eat every click on the desktop.
        active: root.active
        source: Compositor.can("focusGrab")
            ? "HyprlandGrab.qml"
            : "ClickCatcher.qml"

        onLoaded: {
            // The two implementations do not share a shape -- one is a grab,
            // the other is a window -- so the wiring happens here rather than
            // through a common base neither of them would fit.
            if (Compositor.can("focusGrab")) {
                item.grabWindows = [root.window];
                item.grabActive = Qt.binding(() => root.active);
            } else {
                item.targetScreen = root.targetScreen;
            }
            item.dismissed.connect(root.dismissed);
        }
    }
}
