// The month, for the clock's popout.
//
// Built by hand rather than with QtQuick.Controls' MonthGrid: the Controls
// version drags a style along and its delegates are themed through a
// different mechanism than the rest of this shell. A month is six rows of
// seven cells; doing it directly costs less than bending someone else's
// grid into the palette.
//
// Weeks start on Monday, which is what the locale here uses and what the
// clock's own "ddd, dd/MM" implies.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"

Column {
    id: root

    // Which month to show. Defaults to the current one; the arrows move it.
    property date shown: new Date()

    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()

    readonly property var today: new Date()
    readonly property bool showingThisMonth: year === today.getFullYear() && month === today.getMonth()

    // Monday-first offset of the 1st: JS getDay() is Sunday-first.
    readonly property int leadingBlanks: {
        const first = new Date(root.year, root.month, 1).getDay();
        return (first + 6) % 7;
    }

    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()

    function shift(months: int): void {
        shown = new Date(root.year, root.month + months, 1);
    }

    spacing: 8

    // ---------------- Header ----------------
    Item {
        width: grid.width
        height: Theme.groupHeight

        MenuRow {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            glyph: "‹"
            onActivated: root.shift(-1)
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurface
        }

        MenuRow {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "›"
            onActivated: root.shift(1)
        }
    }

    // ---------------- Weekday initials ----------------
    Row {
        Repeater {
            model: ["L", "M", "X", "J", "V", "S", "D"]

            Text {
                required property string modelData

                width: 34
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                font.weight: Font.Bold
                color: Theme.textOnSurfaceVariant
            }
        }
    }

    // ---------------- The days ----------------
    Grid {
        id: grid

        columns: 7
        spacing: 0

        Repeater {
            // Six weeks always: a month that needs five would make the popout
            // change height from one month to the next.
            model: 42

            Item {
                id: cell

                required property int index

                readonly property int day: cell.index - root.leadingBlanks + 1
                readonly property bool inMonth: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday: inMonth && root.showingThisMonth && day === root.today.getDate()

                implicitWidth: 34
                implicitHeight: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: height / 2
                    visible: cell.isToday
                    color: Theme.primary

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: cell.inMonth
                    text: cell.day
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: cell.isToday ? Font.Bold : Theme.fontWeight
                    color: cell.isToday ? Theme.textOnPrimary : Theme.textOnSurface
                }
            }
        }
    }
}
