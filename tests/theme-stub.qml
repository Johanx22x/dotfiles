// The design tokens wheel-and-click.qml's components ask for, and nothing else.
//
// The real one is quickshell/.config/quickshell/Theme.qml, and it cannot be
// used here: it opens with `import Quickshell` and `import Quickshell.Io`,
// reads the wallpaper's generated palette through a FileView, and none of that
// exists inside a plain QQuickView. Loading it would mean loading Quickshell,
// which would mean a compositor, which is the whole thing this bench avoids.
//
// NONE OF THESE NUMBERS ARE INVENTED. Every one is the value the real Theme
// computes on this machine, copied across so that the rail the bench builds is
// the size the rail actually is -- groupHeight is what makes fourteen entries
// 530 px tall against a 452 px viewport, which is the entire reason two of them
// are below the fold and the entire reason this bug was ever reported. A stub
// that guessed 40 here would still scroll and would be measuring a rail that
// does not exist.
//
//     itemSpacing 9, groupPadding 12          Theme.qml
//     groupHeight  barHeight - 12 = 48 - 12   Theme.qml
//     groupRadius  groupHeight / 2 = 18       Theme.qml
//     fontSize     Config.fontSize = 11       Config.qml, defaults
//     iconSize     fontSize + 2 = 13          Theme.qml
//     animDuration 220, recolorDuration 0     Theme.qml
//
// The colours are Tokyo Night literals rather than the wallpaper's, because
// nothing here is measured off a colour: they exist so the Rectangles have
// something to paint and so a missing property would show up as a warning
// rather than as a black rail. If a component ever starts deriving a SIZE from
// a colour, this comment is wrong and the stub needs the real palette.
//
// NOT A SINGLETON, and that is not a detail. This is handed to the engine as a
// root context property named "Theme" rather than registered as a type,
// because `import "root:/"` is Quickshell's own resolver and a plain engine
// resolves it to nothing -- see the long note in wheel-and-click.py. A context
// property is looked up exactly when a name is not a type, which is what makes
// `Theme.groupHeight` inside the real components resolve to this file.
import QtQuick

QtObject {
    readonly property int itemSpacing: 9
    readonly property int groupHeight: 36
    readonly property int groupRadius: 18
    readonly property int groupPadding: 12

    readonly property string fontFamily: "sans-serif"
    readonly property real fontSize: 11
    readonly property int fontWeight: Font.DemiBold
    readonly property real iconSize: 13

    readonly property int animDuration: 220
    readonly property int recolorDuration: 0

    readonly property color primary: "#7aa2f7"
    readonly property color outline: "#565f89"
    readonly property color outlineVariant: "#414868"
    readonly property color primaryContainer: "#3d59a1"
    readonly property color surfaceContainerHigh: "#24283b"
    readonly property color textOnPrimaryContainer: "#c0caf5"
    readonly property color textOnSurface: "#c0caf5"
    readonly property color textOnSurfaceVariant: "#a9b1d6"
}
