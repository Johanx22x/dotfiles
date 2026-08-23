// How the windows theme draws a hover note. The public half -- where the note
// goes, when it flips above the row instead of below it, and what a flipped one
// does to the stacking of everything between it and the viewport -- is
// components/Tooltip.qml, and none of that is drawing.
//
// FOUR AND NOT EIGHT, WHICH IS MICROSOFT'S OWN EXCEPTION. Every overlay in
// Windows 11 -- flyouts, menus, dialogs, windows -- takes OverlayCornerRadius,
// which is 8. The ToolTip does not: it is documented as taking
// ControlCornerRadius "due to its small size", and it is the only overlay that
// does. Fluent.tooltipRadius is that exception, named rather than left as a
// bare 4 so a reader can tell it from a mistake.
//
// OPAQUE, UNLIKE ALMOST EVERYTHING ELSE THIS SHELL DRAWS, and that is the
// promise this file inherited. A translucent note over a translucent window
// over a wallpaper is three layers of image behind two lines of small text, and
// the point of the thing is that it can be read at a glance. A theme that gives
// this a `Theme.glass(...)` colour has broken it in the exact way the component
// exists to prevent -- and here it would also break the shadow below, which is
// cast by a shape drawn UNDER this box and hidden by it.
//
// THE WIDTH IS DECIDED HERE AND THE FACADE READS IT BACK, which is the one
// place this component departs from rule 2 of the README in this directory. The
// facade's header says why: a note is placed by x and y in its parent's
// coordinates rather than laid out by a Column, so it has nowhere to get a
// width from except the text.
//
// AND IT MUST BE implicitHeight AND NOT height. The flip arithmetic upstairs
// reads `root.height`, and an Item's height follows its implicitHeight of its
// own accord; bound the other way round -- height from the Loader -- the first
// evaluation of that arithmetic would run against a note of no height and
// decide there was room below for something with no size. Neither number is
// derived from this item's own width or height, which the Loader assigns.
//
// NO FLOOR ON EITHER, because a note is exactly as big as its sentence. The
// facade floors nothing here either; it reads both numbers straight off the
// Loader.
//
// AND `maxWidth` IS THE CALLER'S, not this file's. Wide enough for a sentence
// over two or three lines; wider and the eye has to travel back across the row
// it is explaining.
//
// ---------------------------------------------------------------------------
// THE SHADOW, AND WHY IT IS A BLUR RATHER THAN MultiEffect's OWN SHADOW
// ---------------------------------------------------------------------------
//
// A Windows tooltip sits at elevation 16, which DropShadowRecipe.h turns into
// `0 4px 8px` of black at 26% -- Fluent.tooltipShadowY, tooltipShadowBlur and
// shadowOpacity.
//
// MultiEffect's `shadowEnabled` renders the SOURCE as well as the shadow, so
// using it would mean handing it this box and everything in it: the text would
// go through a texture, and an item used as a MultiEffect source in this tree
// is `visible: false` -- which is also how an item stops receiving input. The
// note takes no input, but the popouts and rows that host one do.
//
// So the shadow is cast from a shape of its own: a rounded rectangle the same
// size and radius as the box, never drawn directly, blurred and laid down
// first. The box is opaque and covers it exactly, so what is left visible is
// the eight pixels that spilled out past the edge -- which is what a shadow is.
// The pattern is the one components/CornerWedge.qml and island/Island.qml
// already use for a source item: `visible: false` with `layer.enabled: true`.

import QtQuick
import QtQuick.Effects
import qs
// Tooltip is components/Tooltip.qml -- the facade -- and not this file. The
// explicit import wins over the directory a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property Tooltip row

    // ToolTipBorderThemePadding is 8,5,8,7 -- wider than it is tall, and not
    // symmetrical top to bottom. The vertical pair is 12 together and is split
    // the way Microsoft splits it, five above and seven below.
    readonly property int padH: 8
    readonly property int padTop: 5
    readonly property int padBottom: 7

    implicitWidth: Math.min(label.implicitWidth + root.padH * 2, root.row.maxWidth)
    implicitHeight: label.implicitHeight + root.padTop + root.padBottom

    // ---------------- The shadow ----------------
    //
    // The shape it is cast from. Never seen: the box below is opaque and lies
    // exactly on top of it, so only what the blur pushed past the edges shows.
    Rectangle {
        id: shadowShape

        anchors.fill: parent
        radius: Fluent.tooltipRadius
        color: "black"
        antialiasing: true

        visible: false
        layer.enabled: true
    }

    MultiEffect {
        x: 0
        y: Fluent.tooltipShadowY
        width: root.width
        height: root.height

        source: shadowShape
        opacity: Fluent.shadowOpacity

        // autoPaddingEnabled grows this item beyond the geometry above so the
        // blur has somewhere to land. Nothing between here and the viewport
        // clips, so the eight pixels are real.
        blurEnabled: true
        blur: 1.0
        blurMax: Fluent.tooltipShadowBlur
    }

    // ---------------- The box ----------------
    //
    // Fill and stroke are the pair the scheme keeps apart on purpose:
    // surfaceContainerHighest is the note's ground and outlineVariant is its
    // edge, and windows-11-dark is required to give them different values for
    // exactly this reason.
    Rectangle {
        anchors.fill: parent

        radius: Fluent.tooltipRadius
        antialiasing: true
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outlineVariant

        // NO MouseArea, NO HoverHandler, NO cursorShape. A note appears because
        // something else is being hovered and goes away when it stops; it is
        // not a thing you point at. One that took the pointer would take it
        // away from the row underneath, which is the row whose hover is holding
        // the note up.
        //
        // Caption, which is what ToolTipContentThemeFontSize asks for: 12 at
        // Regular.
        //
        // NO EXPLICIT LINE HEIGHT, even though this is the one component here
        // that wraps and would use one. Fluent.captionLine is derived from
        // Theme.fontSize, which this shell hands to Text as a POINT size, while
        // lineHeight in FixedHeight mode is in PIXELS: the constant lands at
        // about the em box on this machine, so setting it would pull two lines
        // together rather than space them. The face's own metrics do it
        // instead, which is what Windows relies on as well.
        //
        // THE WIDTH IS THE TEXT'S AND NOT THE BOX'S, which is what keeps the
        // pair of implicit sizes above out of a loop: this reads maxWidth --
        // the caller's number -- rather than `root.width`, which the Loader
        // assigns from the very implicitWidth that is measured off this Text.
        Text {
            id: label

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.padH
            anchors.topMargin: root.padTop

            width: Math.min(label.implicitWidth, root.row.maxWidth - root.padH * 2)
            wrapMode: Text.WordWrap
            text: root.row.text
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }
    }
}
