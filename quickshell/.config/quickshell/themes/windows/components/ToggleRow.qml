// How genesis draws a settings toggle. The public half -- what the pages
// write, what `checked` means, why the whole row is the target -- is
// components/ToggleRow.qml, and this file is everything that was below those
// comments before the split, moved unchanged.
//
// THE ROOT IS A Rectangle AND THE FACADE'S IS AN Item, which is the shape this
// seam has: the base class is the theme's business. `radius` and the hover
// fill are the two reasons this was ever a Rectangle, and both are drawing.
//
// IT READS `row` AND NEVER WRITES TO IT. `row.checked` is the value the page
// handed down; the click calls `row.toggled(...)` to ask for a new one. See
// README.md in this directory for why writing `row.checked = value` here would
// be the same bug as writing to Config from inside a row.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // THE FACADE, HANDED IN BY ITS LOADER AS AN INITIAL PROPERTY, AND TYPED.
    //
    // `required` is what makes it a contract rather than a hope: this file
    // cannot be instantiated without one, so there is no state in which the
    // bindings below read from null.
    //
    // THE TYPE IS THE POINT, and it is worth the odd-looking import. Declared
    // `var`, every `row.checked` below is a read qmllint cannot check, and that
    // was measured rather than supposed: seven deliberate misspellings in this
    // file -- five of `checked`, two of `glyph` -- left tests/qml-lint.sh at
    // 307 warnings and green. Declared `ToggleRow`, the five misspellings of
    // `checked` are five [missing-property] findings naming their lines. That
    // is exactly what the split would otherwise have cost: reads that used to
    // be checked against a real property on a real type, silently becoming
    // reads nothing checks at all.
    //
    // `ToggleRow` HERE IS components/ToggleRow.qml, not this file, even though
    // this file has the same name and a QML document implicitly imports its own
    // directory. The explicit `import qs.components` wins, and that was
    // checked in both places rather than assumed: qmllint resolves it to the
    // facade, and the shell builds 28 of these rows against it under a
    // headless compositor with no "not a type" and no failed assignment.
    required property ToggleRow row

    // WHAT THE FACADE READS BACK, and the only thing that crosses the seam
    // upwards. A row of this theme is one line tall, always -- the facade
    // floors at the same number, so this is what it was before the split
    // rather than a second opinion about it.
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // THE DIM IS DRAWING AND IT LIVES HERE; `enabled` ITSELF DOES NOT.
    // `root.enabled` is Qt's effective-enabled, computed down the item tree
    // from the facade through its Loader to here, so a page that writes
    // `enabled: false` on a ToggleRow reaches this line with nothing forwarded
    // by hand. Reading `row.enabled` instead would give the same answer today
    // and a wrong one the moment anything between here and the page is
    // disabled.
    //
    // The MouseArea at the bottom is the exception and it still forwards by
    // hand, because `MouseArea.enabled` is a flag of its own and does not
    // follow the tree -- see rule 6 in README.md, where that is measured.
    opacity: root.enabled ? 1 : 0.4

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- The switch ----------------
    //
    // Hand-built rather than QtQuick.Controls' Switch: nothing else in this
    // shell imports Controls, and a Controls widget would arrive with its own
    // style, its own metrics and its own idea of the palette, none of which
    // are Theme's. Twenty lines is cheaper than reconciling that.
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        width: 42
        height: 22
        radius: height / 2

        color: root.row.checked ? Theme.primary : Theme.surfaceContainerHighest

        // The off state needs an edge: over the section's own surface an
        // unfilled track of nearly the same tone reads as empty space rather
        // than as a control that is switched off.
        border.width: root.row.checked ? 0 : 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Rectangle {
            id: knob

            width: 16
            height: 16
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter

            x: root.row.checked ? track.width - width - 3 : 3
            color: root.row.checked ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

            Behavior on x {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    // THE WHOLE ROW, and that is the promise the facade's header makes and
    // this file keeps. A theme that put this MouseArea on `track` instead
    // would still pass every check in tests/ and would shrink the target from
    // a 320-pixel row to a 42-pixel pill.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.row.toggled(!root.row.checked)
    }
}
