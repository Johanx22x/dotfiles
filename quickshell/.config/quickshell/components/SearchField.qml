// A search box: a glyph, a text input, and a clear button once there is
// something to clear. THIS IS THE HALF THE PAGES SEE; the pill, the glyph and
// the clear button are in themes/<theme>/components/SearchField.qml.
//
// TextInput and not TextField: TextField is QtQuick.Controls, which nothing
// in this shell imports, and it would arrive with its own background, its own
// padding and its own idea of the palette. The pill is drawn the same way
// every other pill here is.
//
// The launcher has its own input rather than this one, and that is not an
// oversight: the launcher's field is the whole interface, sized and animated
// with the sheet it lives in. This is a control that sits in a corner of a
// window. Merging them would mean one component with two layouts.
//
// ---------------------------------------------------------------------------
// THE INPUT DID NOT MOVE, AND THAT IS THE WHOLE DESIGN OF THIS SPLIT
// ---------------------------------------------------------------------------
//
// Every other facade in components/ owns properties and nothing else. This one
// owns an OBJECT, and it has to, for a reason that shows up the moment you try
// it the other way:
//
//     property alias text: input.text
//
// An alias binds a name on this type to a property of an object IN THIS
// DOCUMENT. There are nine call sites on the other side of it -- `text` is
// read at Settings.qml:600 and :626 and at KeybindsPage.qml:389 and :815, and
// clear() is called at Settings.qml:93, :188, :281 and :606 and at
// KeybindsPage.qml:586 -- and a Loader cannot host an alias target, so an
// input that lived in the theme's file would take all nine with it. The
// obvious repair is worse than the disease: a plain `property string text`
// that the theme's TextInput writes back into is a second writer to a value
// the same object displays, which is the bug rule 4 of
// themes/genesis/components/README.md is about, and binding a TextInput's
// `text` to it destroys that binding the first time somebody types.
//
// AND IT IS THE RIGHT PLACE ANYWAY. Look at what is on the input: `onAccepted`
// and `Keys.onEscapePressed`, which are this component's two signals; the text
// itself, which is its state; the selection. That is behaviour from top to
// bottom, and the only reason it ever looked like drawing is that it is a
// thing you can see.
//
// SO THE THEME POSITIONS AN OBJECT IT DOES NOT OWN, which is the one mechanism
// in this directory that ToggleRow's does not cover. It does it by putting
// `row.input` in the `data` of whatever item it wants the text to sit in --
// the theme writes to its own item and reads the facade, which is the ordinary
// direction. Reparenting re-evaluates the anchors below, because they are
// bound to `parent` and `parent` is what changed.
//
// THAT IT SURVIVES A THEME CHANGE WAS MEASURED, NOT ASSUMED, because the
// obvious worry is that the input is destroyed with the theme item it was
// slotted into -- setSource deletes the old one. It is not: ownership stayed
// with this document, the visual parent is all that moved. Swapped between two
// themes with different slot geometry and back again, the input was alive each
// time, took the new slot's width and height, and still held what had been
// typed into it.
//
// WHAT A THEME CANNOT CHANGE, said out loud because it is the price. The
// text's own font and ink are set below, from Theme, and a theme cannot give
// this input a different size or colour -- only somewhere else to sit and
// something else around it. Rule 5 is the justification and not an excuse:
// those are host tokens, the same for every theme, and the placeholder is
// aligned by sharing the input's own font rather than by two files agreeing.
// If a theme ever needs its own type here, that is the day this becomes a
// third channel and not before.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property alias text: input.text
    property string placeholder: "Search"

    // Focus lands here without a click, for the window that opens ready to be
    // typed into. Off by default: a field that steals focus is wrong far more
    // often than it is right.
    //
    // NO PAGE HAS EVER READ THIS, and take() below has never been called
    // either -- both were written for a window that would open onto a search
    // and no such window was built. They are not dead any more: the split gave
    // them the only caller they were ever going to have, which is the theme.
    // It draws the focus ring off `focused` and answers a click on the pill
    // with take(), and neither of those has another way to reach an input the
    // theme does not own.
    property alias focused: input.activeFocus

    signal accepted
    signal escaped

    // Theme.groupHeight - 4 is what this field was before the split, and the
    // floor covers the two ways a theme reports nothing. See ToggleRow's
    // header for both, and for why this reads the Loader rather than
    // `Loader.item`.
    implicitHeight: Math.max(Theme.groupHeight - 4, drawing.implicitHeight)

    function clear(): void {
        input.text = "";
    }

    function take(): void {
        input.forceActiveFocus();
    }

    // ---------------- The input, which the theme places ----------------
    //
    // Exposed so the theme can put it somewhere. It is `readonly` because the
    // theme's business with it is to hold it, not to swap it, and a page has
    // no business with it at all -- `text`, `clear()`, `take()` and `focused`
    // above are the whole of what a call site is meant to touch.
    readonly property TextInput input: input

    TextInput {
        id: input

        // LEFT AND RIGHT TO THE PARENT, VERTICALLY CENTRED IN IT, and every
        // one of those reads `parent` on purpose. The theme reparents this
        // into its own slot, and anchors bound to `parent` follow it there;
        // anchors bound to a named item could not, because the item they
        // would have to name is in the other file.
        //
        // The height is left to the text, as it always was, and the slot is
        // as tall as the pill -- so the text sits on the same line it sat on
        // before the split, and a theme that gives the slot a different height
        // moves it without having to know that this is how.
        //
        // A theme that never slots it leaves it filling the width of the
        // whole facade. That is not a state worth guarding against: it is
        // legible, it is what a missing pill would look like anyway, and
        // Quickshell has already named the file that did not load.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurface
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.textOnPrimaryContainer
        clip: true

        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()

        // THE PLACEHOLDER TRAVELS WITH THE INPUT, and it is here rather than
        // in the theme for one concrete reason: `font: input.font` is what
        // guarantees the two sit on the same baseline and start at the same
        // pixel. Drawn by the theme instead, it would be two files reading the
        // same tokens and agreeing by luck, and the day one of them wanted a
        // different size the placeholder would jump when you started typing.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            font: input.font
            color: Theme.outline
        }
    }

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    //
    // DECLARED AFTER THE INPUT AND IT DOES NOT MATTER, which is worth a line
    // because it looks as though it should: a later sibling paints over an
    // earlier one, so this Loader is above the input for exactly as long as it
    // takes the theme to take the input into its own tree. After that the
    // input is inside what is painting, not under it.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SearchField.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
