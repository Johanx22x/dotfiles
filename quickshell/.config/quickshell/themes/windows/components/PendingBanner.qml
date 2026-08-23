// THE COUNTDOWN THAT REPLACES THE ACTIONS ROW WHILE A DISPLAY CHANGE IS
// WAITING TO BE CONFIRMED.
//
// Windows' name for this shape is an InfoBar: a framed strip inside the page,
// tinted with the colour of whatever it is saying, holding a glyph, one
// sentence and its buttons on a single line. The reference set has no InfoBar
// in it, so the frame is built out of the grammar the Settings shots do agree
// on -- ControlCornerRadius, a one-pixel stroke, no shadow, buttons at the
// right edge -- and the two numbers it needs beyond that are marked OURS where
// they live, under THE FRAMED STRIP in Fluent.qml.
//
// THE FOUR-PIXEL INSET IS THE HOST'S IDEA AND THE THEME'S TO DRAW. The facade
// spans the card and says so in its own header: the frame is pulled in from
// the card's edge here, because a theme with a different corner radius needs a
// different inset and nothing else on the page wants to know about it.
//
// ---------------------------------------------------------------------------
// NO TIMER IN THIS FILE, AND IT IS NOT AN OVERSIGHT
// ---------------------------------------------------------------------------
//
// `row.seconds` is A READING. What counts it down is in DisplayDraft.qml,
// bound to the pending state and not to anything's `visible`, because the
// whole point of a revert is that it fires whether or not anybody is still
// looking at this page -- and the case it exists for is the one where the
// screen went black and the page cannot be looked at.
//
// A Timer behind the seam is a Timer that stops existing when the theme is
// swapped. tests/shell-load.sh rewrites `theme` under a running shell and the
// surfaces are rebuilt in place; do that mid-countdown with the clock in here
// and the ten seconds simply never end, on a screen that may be showing
// nothing at all.
//
// THE SENTENCE IS TWO HALVES FROM TWO PLACES. `row.question` arrives complete,
// question mark and all, and the countdown is appended here -- because
// "Reverting in 7s" is the same clause at both call sites and only the
// question changes. ArrangementSection.qml writes the identical sentence for
// the banner it draws itself.
//
// BOTH CHIPS CARRY `label` AND NOT `name`, which is the opposite of what the
// key caps in BindRow.qml do and is right for the same reason. components/
// Chip.qml's header names these exact words -- "Apply", "Keep" -- as chips
// that are in the settings search index today and stay there under `label`.
// They are actions on a settings page; a key cap is not.

import QtQuick
import qs
import qs.themes.windows
import qs.components
import qs.modules.settings.pages.display

Item {
    id: root

    required property PendingBanner row

    // The card's edge is the facade's edge; the frame starts four pixels in.
    // See the header, and the facade's.
    readonly property int inset: 4

    implicitHeight: frame.implicitHeight + 2 * root.inset

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    Rectangle {
        id: frame

        anchors.fill: parent
        anchors.margins: root.inset

        radius: Fluent.controlRadius
        // The strip's own colour, at the tint an InfoBar carries it at: enough
        // to separate the strip from the card without turning the card amber.
        color: Qt.alpha(Theme.warning, Fluent.bannerTint)
        border.width: 1
        border.color: Theme.warning

        implicitHeight: Math.max(Fluent.controlHeight, actions.implicitHeight + 2 * Fluent.bannerPadding)

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Fluent.bannerPadding
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.timerSand
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.warning
        }

        // TWO TEXTS AND NOT ONE STRING, WHICH THE FIRST PHOTOGRAPH CORRECTED.
        // Written as one sentence with one elide, a card at the width the
        // settings window actually opens at cut it after "Reverting" -- the
        // countdown, which is the one thing on this strip worth reading while
        // you wait to find out whether the screen comes back, was the part
        // that fell off the end. So the QUESTION is the half that gives way
        // and the number never does.
        Text {
            id: question

            anchors.left: glyph.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: countdown.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.question
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Semibold and never Bold: the strip is already carrying the frame
            // and the colour, so the sentence only has to be the first thing
            // read inside it.
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        Text {
            id: countdown

            anchors.right: actions.left
            anchors.rightMargin: Fluent.cardActionGutter
            anchors.verticalCenter: parent.verticalCenter

            text: `Reverting in ${root.row.seconds}s`

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.rightMargin: Fluent.bannerPadding
            anchors.verticalCenter: parent.verticalCenter

            spacing: Theme.itemSpacing

            // KEEP IS THE FILLED ONE, and the pair is not symmetric on
            // purpose: keeping writes the change to disk and reverting is what
            // happens anyway if nobody touches either. The accent goes on the
            // one that needs a decision.
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
