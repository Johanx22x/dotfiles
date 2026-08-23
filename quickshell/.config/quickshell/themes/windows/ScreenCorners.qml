// The four corners of one monitor -- and under this theme they are square.
//
// WINDOWS ROUNDS WINDOWS, NOT THE SCREEN. Nothing in the shell rounds a
// display edge either once windows/theme.json sets screenCornerRadius to 0,
// and that one number reaches every part of the surface without this file
// having to say anything:
//
//   components/ScreenCorner.qml:62-63   implicitWidth and implicitHeight are
//                                       Theme.screenCornerRadius, so each of
//                                       the four layer surfaces asks for 0x0
//   components/ScreenCorner.qml:65      color: "transparent"
//   components/ScreenCorner.qml:68      mask: Region {} -- no input anywhere
//   components/ScreenCorner.qml:72      exclusionMode: ExclusionMode.Ignore
//   components/ScreenCorner.qml:80      the wedge is handed radius 0, and this
//                                       theme's components/CornerWedge.qml is
//                                       the empty implementation besides
//
// So the four windows go on existing, reserve nothing, take no input and draw
// nothing visible -- which is the case ScreenCorner.qml's own header describes
// ("a theme that wants square screen corners says so in three lines there ...
// and these four windows go on existing"), and the case the null-implementation
// rule in components/README.md exists for.
//
// SO THIS FILE IS GENESIS'S, UNCHANGED BELOW THIS COMMENT, and that is the
// finding rather than an omission. It names four corners and hands each of them
// the screen it belongs to; there is not a radius, a colour or a curve in it.
// A theme with square corners has nothing to say here that theme.json has not
// already said one directory up.
//
// WHAT A READING OF THE SOURCE CANNOT SETTLE, written down rather than assumed:
// whether a layer surface that asks for 0x0 maps at that size or is clamped by
// Qt to 1x1. Either answer puts nothing on screen -- the mask is empty and the
// colour transparent -- so it is not a difference this theme can see, but it
// was not verified under a compositor and should not be reported as if it were.

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
}
