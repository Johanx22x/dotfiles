// The month, for the dashboard.
//
// Built by hand rather than with QtQuick.Controls' MonthGrid: the Controls
// version drags a style along and its delegates are themed through a
// different mechanism than the rest of this shell. A month is six rows of
// seven cells; doing it directly costs less than bending someone else's
// grid into the palette.
//
// Weeks start on Monday, which is what the locale here uses and what the
// clock's own "ddd, dd/MM" implies.
//
// THE WEEKDAY INITIALS ARE ENGLISH AND ARE WRITTEN OUT RATHER THAN ASKED FOR.
// They were L M X J V S D -- Spanish, hardcoded, and the only Spanish string
// left in the shell's interface. Everything this repo produces goes in
// English, so they are M T W T F S S.
//
// NOT DERIVED FROM THE LOCALE, deliberately. Qt.formatDate would hand back
// whatever LANG says, which is en_US.UTF-8 on this machine today and is a
// setting somebody could change tomorrow -- and the rule is that the
// interface is English, not that it follows the machine. The month name above
// the grid DOES go through Qt.formatDate and so does follow the locale; that
// is left alone because it has always been correct here and changing it would
// be a second decision hiding inside this one.
//
// The repeated T and S are the standard compact English form: position
// carries what the letter cannot, which is the same bargain every seven-column
// calendar makes.

import Quickshell
import QtQuick
import "root:/"

Column {
    id: root

    // ---- The colours, because the ground under this is not always ours ----
    //
    // Every colour here used to be a Theme role read in place, which was
    // right while the calendar sat on a card in the wallpaper's palette. The
    // dashboard now draws it on a photograph -- see the header of
    // Dashboard.qml -- where a role derived from the wallpaper has nothing to
    // do with what is behind the type.
    //
    // The defaults are exactly the roles that were read here before, so a
    // caller that says nothing gets the calendar it had.
    property color ink: Theme.textOnSurface
    property color inkMuted: Theme.textOnSurfaceVariant
    property color todayFill: Theme.primary
    property color todayInk: Theme.textOnPrimary
    property color hoverWash: Theme.surfaceContainerHigh

    // WHAT THE ARROWS LOOK LIKE WHEN NOBODY IS POINTING AT THEM. Transparent
    // by default, which is right on a card whose own edge says where the
    // surface is; the dashboard passes a fill, because on a photograph a
    // control with no resting surface is indistinguishable from a caption.
    property color restWash: "transparent"

    // ---- The cell, and why it is smaller than it was ----
    //
    // The month is the tallest thing in the dashboard and therefore sets the
    // whole panel's height -- see the note on `bodyHeight` in Dashboard.qml.
    // It was 34 x 30 with a 36-pixel header, which came to 252 tall; at
    // 30 x 26 with a 30-pixel header it is 213, and the panel is 39 pixels
    // shorter for it. The type inside did not change, so the day numbers are
    // exactly as legible as they were; what went is padding around them.
    property int cellWidth: 30
    property int cellHeight: 26
    property int headerHeight: 30

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

    spacing: 6

    // ---------------- Header ----------------
    Item {
        width: grid.width
        height: root.headerHeight

        Arrow {
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
            color: root.ink
        }

        Arrow {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "›"
            onActivated: root.shift(1)
        }
    }

    // ---------------- Weekday initials ----------------
    Row {
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Text {
                required property string modelData

                width: root.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                font.weight: Font.Bold
                color: root.inkMuted
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

                implicitWidth: root.cellWidth
                implicitHeight: root.cellHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cellHeight - 2
                    height: root.cellHeight - 2
                    radius: height / 2
                    visible: cell.isToday
                    color: root.todayFill

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
                    color: cell.isToday ? root.todayInk : root.ink
                }
            }
        }
    }

    // The two month steppers.
    //
    // IT WAS components/MenuRow.qml, which is the row a tray menu is built
    // out of and paints itself from Theme. Two of them here meant the only
    // part of this calendar that could not follow `ink` was the pair of
    // arrows, and on the dashboard's photographic ground that is the pair
    // that would have disappeared. Same size and same hover wash, one colour
    // that answers the caller.
    component Arrow: Rectangle {
        id: arrow

        property string glyph: ""

        signal activated

        implicitWidth: root.headerHeight
        implicitHeight: root.headerHeight

        radius: height / 2
        color: arrowMouse.containsMouse ? root.hoverWash : root.restWash

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.inkMuted
        }

        MouseArea {
            id: arrowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.activated()
        }
    }
}
