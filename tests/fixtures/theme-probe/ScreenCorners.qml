// The four corners of one monitor, as the probe has them: SQUARE.
//
// THE FOUR WINDOWS ARE STILL BUILT, and that is the point of this file. It
// would be shorter to write `Item { required property var modelData }` and
// have no corners at all -- nothing host-side depends on those windows
// existing -- but then components/CornerWedge.qml would never be loaded and
// the empty implementation next to it in components/ would be a file with no
// caller, which is the one thing this fixture exists to stop.
//
// components/ScreenCorner.qml is the HOST's, and it is the shape taken to its
// end: a window whose one drawn thing is a component that is itself split. It
// keeps the layer surface, the Top layer, the corner-derived anchors, the
// empty input mask, ExclusionMode.Ignore and the Theme.screenCornerRadius box.
// What a theme draws is whatever goes inside that box, and this one draws
// nothing -- see components/CornerWedge.qml here for why that is an answer and
// not an omission.

import QtQuick
import qs.components

Item {
    id: root

    // The ShellScreen these corners belong to, from Variants in shell.qml.
    required property var modelData

    ScreenCorner {
        modelData: root.modelData
        corner: "topLeft"
    }

    ScreenCorner {
        modelData: root.modelData
        corner: "topRight"
    }

    ScreenCorner {
        modelData: root.modelData
        corner: "bottomLeft"
    }

    ScreenCorner {
        modelData: root.modelData
        corner: "bottomRight"
    }

    // THE LINE tests/shell-load.sh WATCHES FOR, and the only reason this
    // fixture prints anything at all. A theme swap rebuilds the surfaces
    // inside a running engine: nothing is written, nothing exits, and
    // "Configuration Loaded" is not printed a second time -- so from outside
    // the process there is no evidence it happened. Seven of these are.
    Component.onCompleted: console.log("theme-probe drew ScreenCorners.qml")
}
