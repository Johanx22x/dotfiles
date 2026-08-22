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

    // Handed to the portable catcher: a rectangle of the screen it leaves
    // alone, so clicks there reach what is underneath instead of only
    // dismissing. Ignored where the compositor has a grab of its own, because
    // a grab covers everything by definition and cannot be given a hole.
    property rect passthrough: Qt.rect(0, 0, 0, 0)

    signal dismissed

    // Never draws anything itself; both implementations are windows or grabs.
    visible: false

    Loader {
        id: impl

        // Nothing is created while the popout is closed: a catcher that existed
        // all the time would eat every click on the desktop.
        active: root.active

        // SOURCE AND ITS INITIAL VALUES TOGETHER, WHICH IS THE WHOLE POINT.
        //
        // ClickCatcher declares `targetScreen` REQUIRED -- a window with no
        // screen is nothing anyone can place. A required property has to be
        // supplied at construction, and a `source` binding constructs with
        // nothing: the object then fails to build, `onLoaded` never runs, and
        // the assignment meant to fill the property never happens either.
        // Which is what used to happen on every compositor without a grab of
        // its own: the catcher never existed, so a popout could not be
        // dismissed by clicking outside it at all -- the only sign was one
        // "Required property targetScreen was not initialized" line in the log.
        //
        // setSource() takes the values with the url, so the catcher is built
        // with a screen already on it. Done as the grab turns on rather than at
        // startup, because that is when the screen is known and when the
        // compositor has been detected.
        onActiveChanged: {
            if (!active) {
                // Forgotten on the way out, or the next activation builds the
                // remembered source on its own -- before this handler runs --
                // and setSource then tears that item down to put an identical
                // one in its place. One layer surface created and destroyed for
                // nothing, every single time the popout opens.
                source = "";
                return;
            }

            // The two implementations do not share a shape -- one is a grab,
            // the other is a window -- so each is handed what it needs.
            if (Compositor.can("focusGrab"))
                setSource("HyprlandGrab.qml", { grabWindows: [root.window] });
            else
                setSource("ClickCatcher.qml", {
                    targetScreen: root.targetScreen,
                    passthrough: root.passthrough
                });
        }

        onLoaded: {
            // What each side has left to wire. The Hyprland grab follows
            // `active` for as long as it lives; the catcher is created and
            // destroyed with it instead, but its hole has to keep up with a
            // bar that can come and go under a fullscreen window.
            if (Compositor.can("focusGrab"))
                item.grabActive = Qt.binding(() => root.active);
            else
                item.passthrough = Qt.binding(() => root.passthrough);
            item.dismissed.connect(root.dismissed);
        }
    }
}
