// How Windows draws a chip. The public half -- what the three roles are, why
// `label` and `name` are two properties, and why the key role's padding and
// font come DOWN across the seam instead of being chosen here -- is
// components/Chip.qml, and the long note there is the one to read before
// touching any number in this file.
//
// UNDER WINDOWS A CHIP IS A 4-RADIUS PILL AND NOT A CAPSULE. ControlCornerRadius
// is 4 and there is no third radius in the system: in-page elements are 4,
// overlays are 8, and a `height / 2` capsule is genesis's shape, not this one.
//
// TWO OF THE THREE ROLES ARE NOT BUTTONS, and that is the promise the facade
// cannot require. A Badge is a state word and a Key is a key cap; neither
// answers the pointer, neither shows a hand, and neither has a colour that
// changes because a pointer is over it. `filled: false` is NOT how you get
// there -- an outlined Button still lights up and still shows a hand -- which
// is exactly why the role exists. How the absence is kept is written out over
// the MouseArea at the foot of this file. See rule 7 in README.md in
// themes/genesis/components/, and InfoRow.qml for the same contract at length.
//
// THE KEY ROLE'S TWO NUMBERS ARE NOT THIS FILE'S TO CHOOSE. `row.padding` and
// `row.labelFont` arrive from the page, because the keybinds page sizes its
// gutter by adding chips up in arithmetic and the cheatsheet does the same. A
// theme that used its own padding or its own type size here would put the
// chords back over the right-hand edge, with nothing failing to load, nothing
// failing a test and nothing in a log. The whole of that argument is in the
// facade's header. What matters here is the shape of the sum: `padding` is the
// TOTAL added to the label, not a margin per side, and the label is drawn in
// `labelFont` exactly as handed over. `-1` and an unset font are the facade's
// two "unset" values and they mean "use your own"; the three defaults below are
// what "your own" is.
//
// NOTHING FADES. Windows swaps a control's brush on a DiscreteObjectKeyFrame at
// time zero -- Fluent.hoverMs is 0 and it is 0 on purpose -- so there is no
// `Behavior on color` anywhere in this file. A 150ms hover fade is the tell
// that gives a recreation away faster than any wrong colour. The palette's own
// changes are covered by Theme.recolorDuration, which this theme sets to 0 for
// the same reason.

import QtQuick
import qs
import qs.components
import ".."

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed
    // rather than `var`, and why `Chip` here is the facade and not this file.
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
    // The host's when the host gave one, this theme's otherwise.
    //
    // A Button's own padding is Windows': ButtonPadding is 11 per side, and the
    // facade's number is a TOTAL, so it is doubled here. The other two are OURS
    // -- Microsoft publishes no badge and no key cap -- and they are the
    // fallback rather than the answer: every live key call site hands its own
    // number down, because the gutter it measured has to be the gutter that is
    // drawn.
    readonly property int pad: root.row.padding >= 0
        ? root.row.padding
        : root.button ? Fluent.controlPaddingH * 2 : 16

    readonly property bool hostFont: root.row.labelFont !== null

    // This theme's own face for each role, used when the host did not name one.
    //
    // A Button is Body, and NORMAL WEIGHT EVEN WHEN IT IS THE FILLED ONE. That
    // is the Windows rule and it is the opposite of what genesis did here:
    // Windows 11's typography says Semibold for emphasis and never Bold, and an
    // AccentButton does not emphasise its label at all -- the accent FILL is
    // what carries it. A Badge is Caption and Semibold, because a state word is
    // a label on a state and at Body size a table of fifteen of them reads as
    // fifteen headings. A Key is Caption at normal weight: a cap is a label on a
    // key, not a sentence.
    //
    // THROUGH THE GROUP PROPERTIES AND NOT Qt.font(), WHICH IS THE ONLY THING
    // ON THIS FILE'S SIDE OF THE SEAM THAT CAN LOSE A FRACTIONAL POINT SIZE.
    // Qt.font() takes an INT point size, so `Qt.font({pointSize: 11 - 1.5})`
    // comes back 9 while `font.pointSize` -- the spelling a FontMetrics uses,
    // and a FontMetrics is what every live key call site hands down -- keeps
    // 9.5. Measured in genesis's copy of this file, which was written through
    // Qt.font() and drew every cap around two pixels narrow, 32 px over one
    // chord of fifteen. Fluent's ramp is expressed as offsets from the user's
    // own size and captionSize is `Theme.fontSize - 2`, an integer today and
    // not guaranteed to stay one; the spelling below cannot round either way.
    //
    // NOT `readonly`, which grouped syntax does not allow, and which is the one
    // thing given up here. Nothing writes it; the three lines below are the
    // only bindings on it and they are live.
    property font ownFont
    ownFont.family: Theme.fontFamily
    ownFont.pointSize: root.button ? Fluent.bodySize : Fluent.captionSize
    ownFont.weight: root.badge ? Fluent.strongWeight : Fluent.normalWeight

    // ---------------- What the facade reads back ----------------
    //
    // BOTH DIRECTIONS, which no other component in this directory does. The
    // facade's header sets out why rule 2's loop cannot form here and why there
    // is no other place the width could come from: a chip fills nothing, it is
    // content-sized inside a Row that packs it, and how wide a word in a pill is
    // is a text metric.
    implicitWidth: content.implicitWidth + root.pad

    // A Button is a Button: Windows puts Button, ComboBox and TextBox all at 32.
    // The other two are OURS, and they are deliberately not 32 -- a state word
    // and a key cap sit INSIDE lines of running text and a 32-tall pill in a
    // 20-tall line is a control, which is exactly what those two roles are not.
    readonly property int badgeHeight: 20
    readonly property int keyHeight: 22

    implicitHeight: root.button ? Fluent.controlHeight
        : root.badge ? root.badgeHeight : root.keyHeight

    // Dimmed rather than hidden: an action that vanishes takes the ones beside
    // it sideways, and the row of chips would rearrange itself every time a
    // draft became clean. Written against this item's own `enabled` and not
    // `row.enabled` -- Qt computes the effective value down the tree through the
    // facade's Loader to here, so a page that disables a chip reaches this line
    // with nothing forwarded by hand. See rule 6 in README.md.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // ---------------- The fill ----------------
    //
    // HOVER BRIGHTENS AND PRESS DIMS, which is the second-best tell after
    // animating the hover, and the two ramps do it differently.
    //
    // On an ACCENT surface hover and press are opacity multipliers on the same
    // colour -- x0.9 and x0.8 -- and never a different colour.
    //
    // Off it, the fill swaps between scheme levels. Fluent names them:
    // fillRest is ControlFillColorDefault, fillHover is ControlFillColorSecondary
    // and fillPress is the level below rest.
    //
    // A BADGE AND A KEY DO NOT MOVE AT ALL. `press.containsMouse` cannot become
    // true for either -- hoverEnabled is false at the foot of this file -- so
    // these branches are constants for two of the three roles by construction
    // rather than by a second condition.
    readonly property color fillColor: {
        if (root.badge)
            return Qt.alpha(root.row.tone, 0.16);

        if (root.key)
            return root.filled ? Theme.primary : Theme.surfaceContainerHighest;

        if (root.filled)
            return press.pressed ? Qt.alpha(root.row.accent, 0.8)
                : press.containsMouse ? Qt.alpha(root.row.accent, 0.9)
                : root.row.accent;

        return press.pressed ? Fluent.fillPress
            : press.containsMouse ? Fluent.fillHover
            : Fluent.fillRest;
    }

    // ---------------- The lit edge ----------------
    //
    // ControlElevationBorderBrush: a 1px vertical gradient in ABSOLUTE mapping
    // over 3px, brighter at the TOP in dark mode. Absolute mapping is why the
    // brighter stroke occupies the top ~1px whatever the control's height is,
    // and it is why the stops below are divided by this item's height -- a QML
    // gradient is proportional and Windows' is not.
    //
    // ONLY A BUTTON HAS ONE. A Badge is a tint and a Key is a solid cap; both
    // are readings, and the lit edge is what says "control".
    //
    // THE ACCENT VARIANT IS FLIPPED AND DARKER AT THE BOTTOM, on purpose, so an
    // accent button gets a dark bottom edge while the neutral button beside it
    // has a light top one. They disagree in Windows and copying one onto the
    // other is the mistake. Fluent publishes one number for it --
    // accentEdgeBottom, black -- and nothing for the top of that gradient, so
    // the top of the accent edge is left CLEAR rather than invented.
    //
    // PRESSED DROPS THE GRADIENT TO A FLAT STROKE. That, and no movement at all,
    // is what reads as "pushed in": nothing here moves by a pixel when pressed.
    readonly property bool lit: root.button

    // The 3px the gradient is mapped over, and the 0.33 stop inside it, as
    // fractions of the chip's height.
    //
    // AGAINST `implicitHeight` AND NOT `height`, which matters for one frame and
    // would otherwise be a rendering fault rather than a layout one: `height` is
    // 0 until the Loader hands this item the facade's size, and a span of 1
    // there would put the four GradientStops below out of ascending order.
    // implicitHeight is a constant expression on this item and is never 0. This
    // is not rule 2's loop in reverse -- nothing here feeds implicitHeight, it
    // only reads it.
    readonly property real edgeSpan: Math.min(1, Fluent.elevationSpan / root.implicitHeight)
    readonly property real edgeStop: root.edgeSpan * Fluent.elevationStop

    Rectangle {
        id: edge

        anchors.fill: parent
        visible: root.lit
        radius: Fluent.controlRadius

        gradient: Gradient {
            // Two stops for the lit part and two for the flat remainder: the
            // brush is constant before 0.33 of the span and constant after the
            // end of it, and only the third of a gradient in between actually
            // graduates.
            GradientStop {
                position: 0
                color: root.filled ? "transparent"
                    : Qt.rgba(1, 1, 1, press.pressed ? Fluent.elevationRest : Fluent.elevationTop)
            }

            GradientStop {
                position: root.edgeStop
                color: root.filled ? "transparent"
                    : Qt.rgba(1, 1, 1, press.pressed ? Fluent.elevationRest : Fluent.elevationTop)
            }

            GradientStop {
                position: root.filled ? 1 - root.edgeSpan : root.edgeSpan
                color: root.filled ? "transparent" : Qt.rgba(1, 1, 1, Fluent.elevationRest)
            }

            GradientStop {
                position: 1
                color: root.filled ? Qt.rgba(0, 0, 0, Fluent.accentEdgeBottom)
                    : Qt.rgba(1, 1, 1, Fluent.elevationRest)
            }
        }
    }

    // The fill sits one pixel inside the edge, which is where the 7 that people
    // measure off screenshots comes from: a 4px outer arc minus the 1px border
    // inside it is a 3px inner arc, and there is no third radius in the system.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.lit ? 1 : 0
        radius: root.lit ? Fluent.controlRadius - 1 : Fluent.controlRadius
        color: root.fillColor
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
            color: root.filled ? root.row.accentText : Theme.textOnSurface
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.chipText

            // THE HOST'S FONT WHOLE, when there is one, and not three properties
            // copied out of it one at a time. The keybinds page measures its
            // gutter with a FontMetrics and hands that FontMetrics' own font
            // over; taking it as one value is what makes the measured chip and
            // the drawn chip provably the same chip rather than two files that
            // happen to spell the same offset the same way today.
            font: root.hostFont ? root.row.labelFont : root.ownFont

            // TEXT ON AN ACCENT FILL IS BLACK IN DARK MODE, and it looks wrong
            // until you see it beside the real thing: dark mode's accent is the
            // LIGHT shade of the accent ramp, so its ink is
            // TextOnAccentFillColorPrimary #FF000000. Do not "fix" it to white.
            // Theme.textOnPrimary is that colour and row.accentText defaults to
            // it.
            color: {
                if (root.badge)
                    return root.row.tone;

                if (root.key)
                    return root.filled ? Theme.textOnPrimary : Theme.textOnSurface;

                return root.filled ? root.row.accentText : Theme.textOnSurface;
            }
        }
    }

    // A BUTTON ANSWERS THE POINTER AND THE OTHER TWO DO NOTHING AT ALL, which is
    // the absence at the top of this file. It is three bindings on `root.button`
    // and not a `Loader { active: root.button }`, and that is the one decision
    // here worth arguing with: everything inside a Loader's inline component is
    // a NESTED component, `root` is out of scope there, and every read of it
    // comes back `[unqualified]` -- so rule 1's checking, the whole point of the
    // typed `row`, stops at its edge. Written like this the three lines that
    // decide whether this pill is a control at all are ordinary bindings,
    // checked, and side by side:
    //
    //   enabled       false: the click cannot land and `activated` is never
    //                 emitted. Events pass through to whatever is behind.
    //   hoverEnabled  false: `containsMouse` stays false, so the fill and the
    //                 ink above stay where they are.
    //   cursorShape   the arrow, so there is nothing under the pointer saying a
    //                 state word or a key cap can be pressed.
    //
    // All three or none: a Badge that flipped one of them would read as
    // something to press, which is exactly what the role exists to prevent.
    MouseArea {
        id: press

        anchors.fill: parent

        // MouseArea.enabled is a flag of its own and does not follow the item
        // tree, so `root.enabled` is forwarded by hand here where the opacity
        // above is not. Rule 6 in README.md measures that and it is the opposite
        // of what it looks like.
        enabled: root.enabled && root.button

        hoverEnabled: root.button
        cursorShape: root.button ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: root.row.activated()
    }
}
