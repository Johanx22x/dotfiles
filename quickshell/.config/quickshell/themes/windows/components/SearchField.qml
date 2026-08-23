// THE SETTINGS SEARCH BOX, WHICH IS A BOX. Four-pixel corners, not the pill.
//
// This shell has two search fields and they are not the same shape in Windows.
// The one on the taskbar -- the one that opens the search flyout -- is a fully
// rounded pill, and themes/windows/launcher/Launcher.qml draws it that way.
// THIS one is `Find a setting` in the Settings window, and every photograph of
// it (ref/settings-system-sound-volumemixer.jpg, ref/settings-home-navpane.png)
// shows an ordinary 32px TextBox at ControlCornerRadius with a magnifier at its
// right end. Giving it the pill is the single most likely way to get this file
// wrong, which is why the sentence is at the top of it.
//
// THE STATES ARE MICROSOFT'S AND THEY ARE INSTANT.
// TextBox_themeresources.xaml:
//
//     TextControlBackground             ControlFillColorDefault     rest
//     TextControlBackgroundPointerOver   ControlFillColorSecondary   hover
//     TextControlBackgroundFocused       ControlFillColorInputActive focus
//
// -- which is the theme's three surface levels for the first two, and #B31E1E1E
// for the third: the fill does not brighten further when the field takes focus,
// it INVERTS to a near-opaque dark so that the accent underline is the brightest
// thing on the control. And the bottom border goes from one pixel of
// TextControlElevationBorderBrush's strong edge to two pixels of accent.
//
// Every one of those swaps is a `DiscreteObjectKeyFrame` at KeyTime 0. There is
// no `Behavior` in this file and there must not be one: a 150ms fade on a
// Windows control is the tell that gives a recreation away fastest, because
// every real control in the same session is swapping instantly beside it.
//
// ---------------------------------------------------------------------------
// AND IT IS A SLOT COMPONENT, WHICH IS WHY AN EMPTY VERSION OF THIS FILE IS NOT
// SAFE
// ---------------------------------------------------------------------------
//
// The facade owns the `TextInput` -- its `text` is a two-way alias four call
// sites read, and an alias cannot reach across a Loader -- and publishes it as
// a typed read-only property. The theme's job is to give it a parent:
//
//     data: [root.row.input]
//
// Leave that line out and the input has no parent, so its own
// `anchors.left: parent.left` resolves against null and the shell says
// `TypeError: Cannot read property 'left' of null` three times on every start.
// What it costs is written down in components/SearchField.qml: the text's font
// and colour are the facade's, and this theme cannot change them -- only where
// the input sits and what is drawn around it.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property SearchField row

    // Button, ComboBox and TextBox all sit at 32 in Windows. The facade floors
    // this at `Theme.groupHeight - 4`, which is the same 32 under this theme's
    // 48px bar -- they agree by arithmetic rather than by coincidence.
    implicitHeight: Fluent.controlHeight

    Rectangle {
        id: box

        anchors.fill: parent

        radius: Fluent.controlRadius
        antialiasing: true

        color: root.row.focused
            ? Qt.alpha(Theme.surface, 0.702)   // ControlFillColorInputActive #B31E1E1E
            : (pointer.containsMouse ? Fluent.fillHover : Fluent.fillRest)

        border.width: 1
        border.color: Theme.outlineVariant

        // THE BOTTOM EDGE IS THE ONE THAT CARRIES THE STATE.
        // TextControlElevationBorderBrush puts its strong stop at the BOTTOM --
        // the opposite end from the ControlElevationBorderBrush every button
        // uses -- so a resting field already has a brighter line under it than
        // around it. Focus turns that line accent and doubles it.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: box.radius / 2
            anchors.rightMargin: box.radius / 2

            height: root.row.focused ? Fluent.focusUnderline : 1

            color: root.row.focused ? Theme.primary : Theme.outline
        }
    }

    // Behind the slot, so a click on the text itself still reaches the input --
    // a TextInput takes focus on press by itself. This one is for the padding
    // and the glyph, where there is nothing to click and a field that ignored
    // the pointer would read as a label.
    MouseArea {
        id: pointer

        anchors.fill: parent

        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor

        onPressed: root.row.take()
    }

    Text {
        id: glass

        anchors.right: parent.right
        anchors.rightMargin: Fluent.fieldPaddingLeft
        anchors.verticalCenter: parent.verticalCenter

        // AT THE RIGHT END, which is where the Settings box has it and where
        // the search flyout's pill does not. Read off the photographs both
        // ways round.
        text: Icons.search
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        color: root.row.focused ? Theme.textOnSurface : Theme.textOnSurfaceVariant
    }

    // THE SLOT. TextControlThemePadding is 10,5,6,6; the 10 is `fieldPaddingLeft`.
    Item {
        anchors.left: parent.left
        anchors.leftMargin: Fluent.fieldPaddingLeft
        anchors.right: glass.left
        anchors.rightMargin: Theme.itemSpacing
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        data: [root.row.input]
    }
}
