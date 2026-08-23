// How genesis draws a chip. The public half -- what the three roles are, why
// `label` and `name` are two properties, and why the key role's padding and
// font come DOWN across the seam instead of being chosen here -- is
// components/Chip.qml, and the long note there is the one to read before
// touching any number in this file.
//
// TWO OF THE THREE ROLES ARE NOT BUTTONS, and that is the promise the facade
// cannot require. A Badge is a state word and a Key is a key cap; neither
// answers the pointer, neither shows a hand, and neither has a colour that
// changes because a pointer is over it. `filled: false` is NOT how you get
// there -- an outlined Button still lights up and still shows a hand -- which
// is exactly why the role exists. How the absence is kept is written out over
// the MouseArea at the foot of this file. See rule 7 in README.md in this
// directory, and InfoRow.qml for the same contract written out at length.
//
// THE KEY ROLE'S TWO NUMBERS ARE NOT THIS FILE'S TO CHOOSE. `row.padding` and
// `row.labelFont` arrive from the page, because the keybinds page sizes its
// gutter by adding chips up in arithmetic and the cheatsheet does the same. A
// theme that used its own padding or its own type size here would put the
// chords back over the right-hand edge, with nothing failing to load, nothing
// failing a test and nothing in a log. The whole of that argument is in the
// facade's header. What matters here is the shape of the sum: `padding` is the
// TOTAL added to the label, not a margin per side, and the label is drawn in
// `labelFont` exactly as handed over.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `Chip` here is the facade and not this
    // file.
    required property Chip row

    // ---------------- Which of the three ----------------
    //
    // Read once, into booleans with real types, so the twenty-odd reads below
    // are reads of a local `bool` rather than twenty string comparisons and
    // twenty chances to spell a role wrong. An unknown role is a Button; the
    // vocabulary is closed and the facade's header holds it.
    readonly property bool badge: root.row.role === "badge"
    readonly property bool key: root.row.role === "key"
    readonly property bool button: !root.badge && !root.key

    readonly property bool filled: root.row.filled

    // ---------------- The metrics ----------------
    //
    // The host's when the host gave one, this theme's otherwise. -1 and null
    // are the facade's two "unset" values; see its header, which says why the
    // font is a `var` and what it cost to find out.
    readonly property int pad: root.row.padding >= 0
        ? root.row.padding
        : root.badge ? 16 : Math.round(Theme.groupPadding * 2)

    readonly property bool hostFont: root.row.labelFont !== null

    // This theme's own face for each role, used when the host did not name one.
    // A Badge is bold and three points under the body text: it is a label on a
    // state, and at the body size a table of fifteen of them reads as fifteen
    // headings. A Key is a point and a half under, for the reason spelled out
    // where the chords are laid out -- a chip is a label on a key, not a
    // sentence, and at the same size the chords compete with the descriptions
    // instead of introducing them. A Button is two under and takes its weight
    // from whether it is the filled one.
    //
    // THROUGH THE GROUP PROPERTIES AND NOT Qt.font(), WHICH IS THE ONLY THING
    // ON THIS FILE'S SIDE OF THE SEAM THAT CAN LOSE THE KEY'S HALF POINT.
    // Qt.font() takes an INT point size. Measured offscreen against this
    // theme's own tokens: `Qt.font({pointSize: 11 - 1.5}).pointSize` comes back
    // 9, while the same expression written as `font.pointSize` -- the spelling
    // a FontMetrics uses, and a FontMetrics is exactly what every live key call
    // site hands down -- keeps 9.5. Written through Qt.font() this default drew
    // every cap around two pixels narrow, 4.09 at the widest and 32 px over one
    // chord of fifteen, against a caller's face measured on the same bench.
    //
    // That fault was LATENT rather than visible, and only because the three key
    // call sites -- KeybindsPage, InputPage and the cheatsheet through BindRow
    // -- all hand a face down, two of them after being bitten by this exact
    // rounding. A default that is wrong and never reached is a trap for the
    // next call site, so it is not a comment saying "keep these integral": the
    // spelling below CANNOT round, so a fractional size in any of the three
    // branches survives and the badge and button branches are free to stop
    // being integers.
    //
    // NOT `readonly`, which grouped syntax does not allow, and which is the one
    // thing given up here. Nothing writes it; the three lines below are the
    // only bindings on it, and they are live -- measured, a change to
    // Theme.fontSize or to the role moves all three the way the single Qt.font()
    // binding used to.
    property font ownFont
    ownFont.family: Theme.fontFamily
    ownFont.pointSize: root.badge ? Theme.fontSize - 3
        : root.key ? Theme.fontSize - 1.5
        : Theme.fontSize - 2
    ownFont.weight: root.badge ? Font.Bold
        : root.key ? Theme.fontWeight
        : root.filled ? Font.Bold : Theme.fontWeight

    // ---------------- What the facade reads back ----------------
    //
    // The width crosses the seam upwards here, which no other component in this
    // directory does. The facade's header sets out why rule 2 does not reach
    // this shape and why there is no other place the number could come from.
    implicitWidth: content.implicitWidth + root.pad
    implicitHeight: root.badge ? 20 : root.key ? 22 : 28

    radius: height / 2

    color: {
        if (root.badge)
            return Qt.alpha(root.row.tone, 0.16);

        if (root.key)
            return root.filled ? Theme.primaryContainer : Theme.surfaceContainerHighest;

        if (root.filled)
            return press.containsMouse ? Qt.lighter(root.row.accent, 1.15) : root.row.accent;

        return press.containsMouse ? Theme.surfaceContainerHigh : "transparent";
    }

    // The off state of a Button needs an edge: over the section's own surface an
    // unfilled pill of nearly the same tone reads as empty space rather than as
    // a control. A Badge is all edge -- that is what "tinted" means here -- and
    // a Key is a solid cap and has none.
    border.width: root.badge || (root.button && !root.filled) ? 1 : 0
    border.color: root.badge ? Qt.alpha(root.row.tone, 0.5) : Theme.outlineVariant

    // A Button's fill answers the pointer, so it moves at the interface's own
    // pace; the other two only ever change because the palette did, and
    // Theme's own roles are already animating underneath. Each role keeps the
    // duration its source had.
    Behavior on color {
        ColorAnimation { duration: root.button ? Theme.animDuration : Theme.recolorDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: root.button ? Theme.animDuration : Theme.recolorDuration }
    }

    // Dimmed rather than hidden: an action that vanishes takes the ones beside
    // it sideways, and the row of chips would rearrange itself every time a
    // draft became clean. Written against this item's own `enabled` and not
    // `row.enabled` -- Qt computes the effective value down the tree through
    // the facade's Loader to here, so a page that disables a chip reaches this
    // line with nothing forwarded by hand. See rule 6 in README.md.
    opacity: root.enabled ? 1 : 0.35

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDuration }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.button && root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize - 1
            color: root.filled ? root.row.accentText : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.row.chipText

            // THE HOST'S FONT WHOLE, when there is one, and not three
            // properties copied out of it one at a time. The keybinds page
            // measures its gutter with a FontMetrics and hands that
            // FontMetrics' own font over; taking it as one value is what makes
            // the measured chip and the drawn chip provably the same chip
            // rather than two files that happen to spell Theme.fontSize - 1.5
            // the same way today.
            font: root.hostFont ? root.row.labelFont : root.ownFont

            color: {
                if (root.badge)
                    return root.row.tone;

                if (root.key)
                    return root.filled ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant;

                return root.filled ? root.row.accentText : Theme.textOnSurfaceVariant;
            }

            Behavior on color {
                ColorAnimation { duration: root.button ? Theme.animDuration : Theme.recolorDuration }
            }
        }
    }

    // A BUTTON ANSWERS THE POINTER AND THE OTHER TWO DO NOTHING AT ALL, which
    // is the absence at the top of this file. It is three bindings on
    // `root.button` and not a `Loader { active: root.button }`, for the reason
    // written out at length over the same three lines in ListRow.qml in this
    // directory: everything inside a Loader's inline component is a nested
    // component, `root` is out of scope there, and rule 1's checking -- the
    // whole point of the typed `row` -- stops at its edge. Here the three lines
    // that decide whether this pill is a control are ordinary bindings, checked
    // and side by side:
    //
    //   enabled       false: the click cannot land and `activated` is never
    //                 emitted. Events pass through to whatever is behind.
    //   hoverEnabled  false: `containsMouse` stays false, so the fill and the
    //                 ink above stay where they are.
    //   cursorShape   the arrow, so there is nothing under the pointer saying
    //                 a state word or a key cap can be pressed.
    //
    // All three or none: a Badge that flipped one of them would read as
    // something to press, which is exactly what the role exists to prevent.
    MouseArea {
        id: press

        anchors.fill: parent

        // MouseArea.enabled is a flag of its own and does not follow the item
        // tree, so `root.enabled` is forwarded by hand here where the opacity
        // above is not. Rule 6 in README.md measures that and it is the
        // opposite of what it looks like.
        enabled: root.enabled && root.button

        hoverEnabled: root.button
        cursorShape: root.button ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: root.row.activated()
    }
}
