// A SETTINGS CARD WHOSE ANSWER IS ONE OF A SMALL CLOSED SET.
//
// SEGMENTS, AND THE SHAPE IS A REAL WINDOWS CONTROL. The facade leaves the
// choice between segments and a dropdown to the theme, and Settings itself
// uses a ComboBox for rows like these -- but a ComboBox is a POPUP, and a
// popup opened from inside a row that lives in a Flickable inside a
// FloatingWindow is a window-management problem rather than a drawing one. The
// segmented group is the other control Windows already has for a closed set:
// SelectorBar, which is the three-way view switcher at the top right of
// ref/settings-flyout-menu.jpg. Measured there: cells 32 tall inside a rounded
// group, the chosen one filled a step lighter, and a short accent bar centred
// under it a few pixels off the bottom edge.
//
// So selection here is an accent bar again, lying down: the same 16 by 3 at
// radius 2 the navigation rail stands on its end, and the same rule -- the
// chosen cell's fill is a step, the bar is what says which one it is.
//
// THE OPTIONS ARE UNPACKED THROUGH THE FACADE'S TWO FUNCTIONS. `row.valueOf()`
// and `row.labelOf()` are the API's contract about what a page may put in
// `options` -- a plain string, or an object with `label` and `value`, which is
// how the font picker stores a family and shows one word of it. A theme that
// unpacked them itself could get the pair the wrong way round and be wrong
// about which option is selected rather than about how it looks.
//
// THE HOISTED PROPERTY ABOVE THE REPEATER IS NOT A STYLE CHOICE. Inside a
// delegate every `row.something` is checked by nothing at all, so the value
// the delegate compares against is read once, up here, where it is typed.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property ChoiceRow row

    // UNPACKED UP HERE, ONCE, and the delegate below reads nothing but this.
    // Both halves of an option come out of the facade's own functions, and
    // both of the reads that would otherwise sit inside the Repeater -- the
    // option's value and the row's current one -- happen at this level, where
    // the linter can still see what they are. (Not spelling the linter's
    // name at the start of a comment word-for-word: it parses `qmllint` in a
    // comment as a directive, and this sentence became six unknown
    // categories.)
    readonly property var entries: (root.row.options ?? []).map(option => ({
        value: root.row.valueOf(option),
        label: root.row.labelOf(option),
        current: root.row.valueOf(option) === root.row.value
    }))

    // The emit, hoisted for the same reason: a signal called through `row`
    // from inside a delegate is checked by nothing at all.
    function choose(value: var): void {
        root.row.chosen(value);
    }

    implicitHeight: Math.max(Fluent.cardMinHeight, body.implicitHeight + 2 * Fluent.cardPadding)
        + 2 * Fluent.cardGapInset

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        color: pointer.containsMouse ? Fluent.fillHover : Fluent.fillRest

        Behavior on color {
            ColorAnimation { duration: Fluent.fasterMs }
        }

        // Hover only. The row has no answer of its own to give -- the cells do
        // -- so this lights the card up and takes nothing.
        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
        }

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.cardIconMax
            horizontalAlignment: Text.AlignHCenter

            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSize
            color: Theme.textOnSurface
        }

        Column {
            id: body

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding + (root.row.glyph !== "" ? Fluent.cardIconMax + Fluent.cardIconGap : 0)
            anchors.right: segments.left
            anchors.rightMargin: Fluent.cardActionGutter
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Text {
                width: parent.width

                text: root.row.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
            }

            Text {
                width: parent.width

                visible: root.row.hint !== ""
                text: root.row.hint
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        // ---------------- The segmented group ----------------
        Rectangle {
            id: segments

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: cells.implicitWidth + 2
            height: Fluent.controlHeight + 2
            radius: Fluent.controlRadius

            color: Qt.rgba(1, 1, 1, Fluent.elevationRest)

            Row {
                id: cells

                anchors.fill: parent
                anchors.margins: 1

                spacing: 0

                Repeater {
                    model: root.entries

                    Rectangle {
                        id: cell

                        required property var modelData

                        width: Math.max(word.implicitWidth + 2 * Fluent.controlPaddingH, Fluent.controlHeight)
                        height: Fluent.controlHeight
                        radius: Fluent.controlRadius - 1

                        color: {
                            if (touch.pressed)
                                return Fluent.fillPress;
                            if (cell.modelData.current || touch.containsMouse)
                                return Fluent.fillSubtleHover;
                            return "transparent";
                        }

                        Text {
                            id: word

                            anchors.centerIn: parent

                            text: cell.modelData.label
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.bodySize
                            color: Theme.textOnSurface
                        }

                        // The indicator, lying down under the chosen cell.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Fluent.indicatorRadius

                            width: Fluent.indicatorHeight
                            height: Fluent.indicatorWidth
                            radius: Fluent.indicatorRadius

                            visible: cell.modelData.current
                            color: Theme.primary
                        }

                        MouseArea {
                            id: touch

                            anchors.fill: parent
                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choose(cell.modelData.value)
                        }
                    }
                }
            }
        }
    }
}
