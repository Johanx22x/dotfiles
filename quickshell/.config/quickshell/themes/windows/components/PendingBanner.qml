// How Windows draws a change that is about to undo itself: a cautionary frame,
// an hourglass, the question with the seconds counting down after it, and the
// two ways out. The public half -- why this is not a ConfirmButton, why the clock
// that counts the seconds is nowhere near this file, and why the arrangement's
// identical banner is NOT built from it -- is
// modules/settings/pages/display/PendingBanner.qml.
//
// THERE IS NO Timer IN THIS FILE AND THERE MUST NOT BE ONE. `row.seconds` is a
// READING. What counts it down lives in DisplayDraft.qml, bound to the pending
// state and not to anything's `visible`, because the whole point of a revert is
// that it fires whether or not anybody is still looking at this page -- and the
// case it exists for is the one where the screen went black and the page cannot
// be looked at. A Timer behind the seam is a Timer that stops existing when the
// theme is swapped: tests/shell-load.sh rewrites `theme` under a running shell
// and the surfaces are rebuilt in place, and doing that mid-countdown with the
// clock in here means the ten seconds simply never end.
//
// THE QUESTION ALREADY HAS ITS QUESTION MARK. `row.question` is the whole
// sentence up to and including it, and this file appends "Reverting in Ns" --
// the same ending at both call sites, so it is assembled once here rather than
// spelled out at each.
//
// THE COLOUR IS SystemFillColorCaution AND IT IS A STATE, NOT AN ERROR. Nothing
// has gone wrong: what is on screen is about to end by itself. Windows draws
// exactly this as an InfoBar at Severity=Warning -- a tinted backplate, a 1px
// stroke, ControlCornerRadius, a glyph and the two buttons on the right -- and
// that is the shape below.
//
// THE FRAME IS INSET FOUR PIXELS from the facade, which spans the card. The
// facade says the inset is the theme's, and it is here rather than in the width
// the card hands over so that a theme with a rounder card can pull it in
// further.
//
// "Keep" AND A SAVE GLYPH, because that one press does both things: it stops the
// countdown AND it is what writes the change to the generated file. A tick would
// say the change was merely accepted. The second chip does what the timer is
// about to do anyway, for when you can already see it is wrong and would rather
// not sit through the countdown.
//
// NEITHER CHIP DECIDES ANYTHING. `row.kept()` and `row.reverted()` are requests;
// what they mean -- a write, or a spec sent back to the compositor -- is the
// page's, and rule 4 is why it stayed there.

import QtQuick
import qs
import qs.components
// PendingBanner is modules/settings/pages/display/PendingBanner.qml -- the
// facade -- and not this file, even though a QML document implicitly imports its
// own directory. The explicit import wins.
import qs.modules.settings.pages.display
import ".."

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `PendingBanner` here is the facade and not this file.
    required property PendingBanner row

    // WHAT THE FACADE READS BACK. One band tall, always: the question and the
    // chips sit side by side, and the band is a Windows Button plus four pixels
    // of air either side of it. The facade floors at Theme.groupHeight, which is
    // 36 under this theme, so this reports the taller number and gets it.
    implicitHeight: Fluent.controlHeight + 8

    // AN Item ROOT WITH THE FRAME INSIDE IT, AND NOT AN ANCHORED Rectangle. The
    // facade's Loader anchor-fills the facade and assigns this item's width and
    // height directly, so a root that also anchored itself to its parent would be
    // two writers to the same two properties. The inset lives one level in, where
    // nothing is fighting it for the geometry.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        // In-page, so 4. Not Theme.groupRadius, which is `groupHeight / 2` and a
        // capsule.
        radius: Fluent.controlRadius

        color: Qt.alpha(Theme.warning, 0.16)
        border.width: 1
        border.color: Theme.warning

        // AN Item AND NOT A Row, so that the sentence has a WIDTH to elide
        // against. A Row hands every child the width it asks for, and `elide`
        // with no width does nothing at all -- the question would paint straight
        // through the two chips instead of stopping short of them. Anchored
        // between the glyph and the chips, the Text has a real bound and gives
        // way to them.
        Item {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.right: chips.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(question.implicitHeight, hourglass.implicitHeight)

            Text {
                id: hourglass

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: Icons.timerSand
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.warning
            }

            // Body Strong: an InfoBar's title is the one line on it with weight,
            // and this banner is a question somebody has a few seconds to answer.
            Text {
                id: question

                anchors.left: hourglass.right
                anchors.leftMargin: Theme.itemSpacing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: `${root.row.question} Reverting in ${root.row.seconds}s`
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.strongWeight
                color: Theme.textOnSurface
            }
        }

        Row {
            id: chips

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding - 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            // `label` AND NOT `name` FOR THESE TWO, which is the opposite of the
            // key caps and the state words. These are actions on a settings page
            // and the display page's other chips -- "Apply", "Keep", "90°" -- are
            // in the settings index today under `label`. Moving them to `name`
            // would quietly take them out of it.
            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Keep"
                glyph: Icons.contentSave
                filled: true
                onActivated: root.row.kept()
            }

            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert now"
                onActivated: root.row.reverted()
            }
        }
    }
}
