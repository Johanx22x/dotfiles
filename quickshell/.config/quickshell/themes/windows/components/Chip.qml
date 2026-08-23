// A WORD IN A PILL -- WHICH UNDER THIS THEME IS A BUTTON, A BADGE OR A KEY CAP.
//
// THE BUTTON ROLE IS WINDOWS' BUTTON. 32 tall, radius 4, 11 of padding at each
// end, the fill a step lighter than what it sits on, and the elevation border
// over it: dim above, bright below, flat while it is held. The same shape
// ActionRow's button draws, and its header carries the long note about why the
// border is a rectangle with the fill inset inside it rather than a
// Rectangle's own border.
//
// `filled` IS AN ACCENT BUTTON, which Windows draws with black text on it --
// dark mode's accent is the LIGHT shade of the ramp, so Theme.textOnPrimary is
// #000000 and that is correct rather than inverted.
//
// THE BADGE ROLE IS NOT A BUTTON AND MUST NOT BEHAVE LIKE ONE: no hit target
// at all, and no hover. It is a state word, and `filled: false` is not the
// same thing -- an outlined button still lights up. That is rule 7 kept in the
// only file that can keep it.
//
// AND NOTHING IN HERE SETS A CURSOR. Windows draws the arrow over every
// control it has; the pointing hand belongs to a hyperlink and to the web, and
// putting one on a button is one of the tells that says a window was drawn by
// somebody who had not looked at one.
//
// THE KEY CAP TAKES ITS PADDING AND ITS FACE FROM THE HOST, and this is the
// one place in the directory where layout crosses the seam downwards. The
// keybinds page and the cheatsheet compute the width of their key gutter by
// ADDING CHIPS UP -- advanceWidth(label) + padding, per cap -- so a theme
// drawing the cap with its own numbers would put every chord back over the
// edge of the page with nothing failing anywhere. `padding` is the TOTAL added
// to the label and not a margin per side, because that is what the model that
// measured it means by it.
//
// AND THE FACE IS BUILT WITH GROUPED WRITES, NEVER Qt.font(). Qt.font() rounds
// what it is given -- Qt.font({pointSize: 9.5}).pointSize comes back 9 -- so a
// chip built that way is measured at one size and drawn at another, which is
// exactly the silent drift the host handing its font down exists to prevent.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property Chip row

    readonly property bool badge: root.row.role === "badge"
    readonly property bool cap: root.row.role === "key"

    // The host's total, halved onto each end, or this theme's own. See the
    // header: -1 means "yours".
    readonly property real sidePadding: root.row.padding >= 0
        ? root.row.padding / 2
        : Fluent.controlPaddingH

    readonly property bool lit: !root.badge && (pointer.containsMouse || pointer.pressed)

    // NO ROOM ADDED FOR THE BORDER. The key gutter's model is
    // advanceWidth(label) + padding and nothing else, so the pill is exactly
    // that wide and the one-pixel border is drawn INSIDE it.
    implicitWidth: face.implicitWidth + 2 * root.sidePadding
    implicitHeight: root.cap || root.badge ? Fluent.chipHeight : Fluent.controlHeight

    Rectangle {
        id: pill

        anchors.fill: parent

        radius: Fluent.controlRadius
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        // The border. A badge takes a flat stroke and never the lit one: it is
        // not a control and has no elevation to claim.
        // Dim above, bright below -- and both stops at the dim value for a
        // badge, which has no elevation to claim, and for a pill being held,
        // where Windows drops the lit border to a flat stroke.
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, Fluent.elevationRest)
            }
            GradientStop {
                position: 1
                color: root.badge || pointer.pressed
                    ? Qt.rgba(1, 1, 1, Fluent.elevationRest)
                    : Qt.rgba(1, 1, 1, Fluent.elevationTop)
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1

            radius: Fluent.controlRadius - 1
            color: {
                if (root.row.filled)
                    return pointer.pressed
                        ? Qt.alpha(root.row.accent, 0.8)
                        : root.row.accent;
                if (pointer.pressed)
                    return Fluent.fillPress;
                if (root.lit)
                    return Theme.surfaceContainerHigh;
                return Theme.surfaceContainerHighest;
            }

            Row {
                id: face

                anchors.centerIn: parent

                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: root.row.glyph !== ""
                    text: root.row.glyph
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.glyphSmallSize
                    color: root.row.filled ? root.row.accentText : Theme.textOnSurface
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: root.row.chipText !== ""
                    text: root.row.chipText

                    // GROUPED WRITES, and every one of them answers the same
                    // question twice: the host's face when there is one, this
                    // theme's when there is not.
                    font.family: root.row.labelFont ? root.row.labelFont.family : Theme.fontFamily
                    font.pointSize: root.row.labelFont
                        ? root.row.labelFont.pointSize
                        : (root.cap || root.badge ? Fluent.captionSize : Fluent.bodySize)
                    font.weight: root.row.labelFont ? root.row.labelFont.weight : Fluent.normalWeight

                    color: {
                        if (root.row.filled)
                            return root.row.accentText;
                        if (root.badge || root.cap)
                            return root.row.tone;
                        return Theme.textOnSurface;
                    }
                }
            }
        }
    }

    // A BADGE TAKES NO INPUT AT ALL. See the header.
    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true

        enabled: !root.badge && root.row.enabled
        visible: !root.badge

        onClicked: root.row.activated()
    }
}
