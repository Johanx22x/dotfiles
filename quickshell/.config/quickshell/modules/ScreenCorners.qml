// The four rounded corners of one monitor.
//
// Grouped here so shell.qml instantiates one thing per screen instead of
// four. Each corner is its own layer surface -- see components/ScreenCorner.qml
// for why the shape is a carved wedge and why it takes no input.

import QtQuick
import "root:/components"

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
}
