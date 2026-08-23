// How the windows theme draws a search box: Windows' TextBox, 32 tall at
// radius 4, with the magnifier on its left and a clear button on its right. The
// public half -- `text`, `clear()`, and the long note on why the TextInput
// stayed on the host side -- is components/SearchField.qml.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN. `inputArea` below has
// `data: [root.row.input]`, and appending the facade's TextInput to this item's
// own data list is what moves it here. The direction is the ordinary one --
// this file writes to its own item and reads the facade -- and the input's
// anchors are bound to `parent`, so they re-evaluate against this slot the
// moment it arrives.
//
// A THEME THAT LEAVES THAT LINE OUT still loads, still draws a pill, and has
// its text lying across the whole width underneath the glyph. There is no
// property the facade could have made `required` to prevent that: the slot is
// an item, not a value, and nothing on this side is obliged to declare one. It
// is rule 7 again -- a promise about behaviour that only the implementation can
// keep. components/SettingsSection.qml in this directory has the same line for
// the same reason and its header carries what happens without it.
//
// THE SLOT IS AS TALL AS THE PILL AND THE TEXT IS NOT. The input centres itself
// inside whatever it is given and keeps its own height, so anchoring this slot
// top-to-bottom is what puts the text on the field's line.
//
// AND THE CLICK TARGET IS THE WHOLE PILL, not the text. A field where only the
// glyph-to-clear strip answers a click is a field you have to aim at.
//
// ---------------------------------------------------------------------------
// FOCUS INVERTS THE FILL, AND IT DOES IT INSTANTLY
// ---------------------------------------------------------------------------
//
// This is the one control in Windows whose focused state goes DARKER rather
// than brighter. Rest is `ControlFillColorDefault` and hover is
// `ControlFillColorSecondary` -- both white overlays, both brightening, both
// the ordinary story -- and then focus swaps the whole brush for
// `ControlFillColorInputActive` #B31E1E1E, a near-opaque DARK. The field stops
// being a raised control and becomes a hole you are typing into. Getting that
// backwards -- brightening on focus, as most toolkits do -- is a bigger tell
// than any single wrong colour, because it happens under the pointer while you
// watch.
//
// The scheme has no role for a 70%-alpha #1E1E1E, so what stands in for it is
// `Theme.surface`, the ground itself: the darkest thing the palette has and the
// colour the near-opaque overlay is nearly opaque towards.
//
// AND THE BOTTOM EDGE BECOMES THE ACCENT. TextBox focus takes the border from
// 1,1,1,1 to 1,1,1,2 with the thick side in `AccentFillColorDefault`: an
// underline that is part of the box rather than a ring around it.
//
// ALL OF IT AT TIME ZERO. Microsoft's TextBox transitions are
// DiscreteObjectKeyFrame at KeyTime="0" -- fill, stroke and underline all swap
// in the same frame with nothing tweening. There is no `Behavior` in this file
// and there must not be one; Fluent.hoverMs is 0 for the same reason.

import QtQuick
import qs
// SearchField is components/SearchField.qml -- the facade -- and not this file.
// The explicit import wins over the directory a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property SearchField row

    // WHAT THE FACADE READS BACK. Button, ComboBox and TextBox are all 32 in
    // Windows and Fluent.controlHeight is the one place that says so. The
    // facade floors at Theme.groupHeight - 4, which is 32 under this theme's
    // 48px bar, so the two agree by arithmetic rather than by luck. Not derived
    // from this item's own height.
    implicitHeight: Fluent.controlHeight

    radius: Fluent.controlRadius
    antialiasing: true

    color: root.row.focused ? Theme.surface
        : mouse.containsMouse ? Fluent.fillHover
        : Fluent.fillRest

    border.width: 1
    border.color: Theme.outlineVariant

    // The thick edge of the 1,1,1,2 border. A Rectangle has one border width for
    // all four sides, so the accent underline is its own item lying along the
    // bottom -- inset by a pixel each side and given a capsule radius so its
    // ends follow the pill's own corner instead of poking out of it.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1
        anchors.rightMargin: 1

        visible: root.row.focused
        height: Fluent.focusUnderline
        radius: height / 2
        antialiasing: true
        color: Theme.primary
    }

    // THE WHOLE PILL TAKES THE CLICK, and take() is how it says so. That
    // function had no caller at all before the split -- see the facade -- and
    // this is now the only way a theme can put the keyboard into an input it
    // does not own.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: root.row.take()
    }

    // The magnifier, on the LEFT, which is where the Settings app's "Find a
    // setting" box puts it. TextControlThemePadding starts the content ten
    // pixels in.
    //
    // A 16px BOX and not type: Fluent.qml's rule is that sizes are absolute and
    // text is relative, and an icon is a box.
    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Fluent.fieldPaddingLeft
        anchors.verticalCenter: parent.verticalCenter

        text: Icons.search
        font.family: Theme.fontFamily
        font.pixelSize: Fluent.navIcon
        color: root.row.focused ? Theme.textOnSurface : Theme.textOnSurfaceVariant
    }

    // ---------------- Where the text goes ----------------
    //
    // An empty Item whose only job is to have a position. The line that matters
    // is `data`, and the top of this file has the account of it.
    //
    // The font, the size, the ink and the selection colours inside it are the
    // host's and this theme cannot change them -- that is what keeping the alias
    // costs, and the facade's header says so at the line that sets them.
    Item {
        id: inputArea

        anchors.left: glyph.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: clearButton.left
        anchors.rightMargin: Theme.itemSpacing
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        data: [root.row.input]
    }

    // ---------------- Clear ----------------
    //
    // Only there when it has something to do. A permanent clear button on an
    // empty field is a control that is disabled nine tenths of the time -- and
    // in Windows' own AutoSuggestBox it appears exactly when there is a query to
    // delete.
    //
    // A square backplate at the control radius, hovering and pressing the way
    // every other subtle button in this theme does: brighter under the pointer,
    // darker while held.
    Rectangle {
        id: clearButton

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: root.height - 8
        implicitHeight: root.height - 8
        width: implicitWidth
        height: implicitHeight

        visible: root.row.text !== ""
        radius: Fluent.controlRadius
        antialiasing: true

        color: clearMouse.pressed ? Fluent.fillPress
            : clearMouse.containsMouse ? Fluent.fillSubtleHover
            : "transparent"

        Text {
            anchors.centerIn: parent

            text: Icons.close
            font.family: Theme.fontFamily
            font.pixelSize: Fluent.checkGlyph
            color: Theme.textOnSurfaceVariant
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // CLEARED AND THEN GIVEN THE KEYBOARD BACK, both through the facade.
            // Pressing clear is not a way of leaving the field: the next thing
            // anyone does is type the search they meant.
            onClicked: {
                root.row.clear();
                root.row.take();
            }
        }
    }
}
