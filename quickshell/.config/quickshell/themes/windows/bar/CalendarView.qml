// The month: the flyout under the clock, and the card in the dashboard.
//
// TWO CALLERS, ONE FILE. Clock.qml opens this in the bar's popout the way
// Windows opens its calendar from the taskbar clock; island/Dashboard.qml draws
// the same component on a photograph and hands it a palette. That is why every
// colour in here is a PROPERTY with a Theme role as its default rather than a
// Theme role read in place -- see the block below -- and why the cell metrics
// are properties too: the dashboard sizes a card around them.
//
// Built by hand rather than with QtQuick.Controls' MonthGrid: the Controls
// version drags a style along and its delegates are themed through a different
// mechanism than the rest of this shell. A month is six rows of seven cells;
// doing it directly costs less than bending someone else's grid into the
// palette.
//
// WHAT THE REDRAW CHANGED, AND WHAT IT DELIBERATELY DID NOT.
//
//   THE HEADER READS LEFT TO RIGHT. Windows 11 puts the month and year at the
//   left of its calendar flyout and the two steppers at the right; genesis
//   centres the month with a stepper on each side. This is the layout with the
//   clearer reading order and it is the one Windows has.
//
//   THE STEPPERS ARE 4px RECTANGLES. They were circles. Every in-page control
//   in Windows 11 is ControlCornerRadius, which is 4, and the hover on them is
//   instantaneous like every other hover in this theme.
//
//   TODAY IS STILL A DISC. Windows 11's calendar marks today with an accent
//   circle, so this is one of the few places in the whole theme where a radius
//   of half the height is correct rather than a leftover pill.
//
//   THE CELLS DO NOT HIGHLIGHT ON HOVER. Windows' days are clickable -- they
//   open the day's agenda -- and ours are not, because this shell has no
//   calendar behind them. A hover fill on something that cannot be clicked is
//   an affordance promising a thing that is not there.
//
// Weeks start on Monday, which is what the locale here uses.
//
// THE WEEKDAY INITIALS ARE ENGLISH AND ARE WRITTEN OUT RATHER THAN ASKED FOR.
// They were L M X J V S D -- Spanish, hardcoded, and the only Spanish string
// left in the shell's interface. NOT DERIVED FROM THE LOCALE, deliberately:
// Qt.formatDate would hand back whatever LANG says, and the rule is that the
// interface is English, not that it follows the machine. The month name above
// the grid DOES go through Qt.formatDate and so does follow the locale.
//
// The repeated T and S are the standard compact English form: position carries
// what the letter cannot, which is the same bargain every seven-column calendar
// makes.

import QtQuick
import qs
import ".."

Column {
    id: root

    // ---- The colours, because the ground under this is not always ours ----
    //
    // The defaults are exactly the roles this file would read in place, so a
    // caller that says nothing gets the calendar the taskbar wants; the
    // dashboard overrides all six because a role derived from the wallpaper has
    // nothing to do with what is behind the type on a photograph.
    property color ink: Theme.textOnSurface
    property color inkMuted: Theme.textOnSurfaceVariant
    property color todayFill: Theme.primary

    // BLACK, AND IT LOOKS WRONG UNTIL YOU SEE IT BESIDE THE REAL THING.
    // TextOnAccentFillColorPrimary is #FF000000 in dark mode, because dark
    // mode's accent fill is SystemAccentColorLight2 -- the LIGHT shade of the
    // ramp. Theme.textOnPrimary carries it. Do not "fix" this to white.
    property color todayInk: Theme.textOnPrimary

    property color hoverWash: Theme.surfaceContainerHigh

    // WHAT THE STEPPERS LOOK LIKE WHEN NOBODY IS POINTING AT THEM. Transparent,
    // which is right on a flyout whose own edge says where the surface is; the
    // dashboard passes a fill, because on a photograph a control with no
    // resting surface is indistinguishable from a caption.
    property color restWash: "transparent"

    // ---- The cell ----
    //
    // The month is the tallest thing in the dashboard and therefore sets the
    // whole panel's height -- see the note on `bodyHeight` in Dashboard.qml --
    // so these stay where they are. Windows' own day cell is nearer 40 square;
    // growing them here would push a card in a file this one does not own.
    property int cellWidth: 30
    property int cellHeight: 26
    property int headerHeight: 30

    // Which month to show. Defaults to the current one; the steppers move it.
    property date shown: new Date()

    readonly property int year: root.shown.getFullYear()
    readonly property int month: root.shown.getMonth()

    readonly property var today: new Date()
    readonly property bool showingThisMonth: root.year === root.today.getFullYear()
        && root.month === root.today.getMonth()

    // Monday-first offset of the 1st: JS getDay() is Sunday-first.
    readonly property int leadingBlanks: {
        const first = new Date(root.year, root.month, 1).getDay();
        return (first + 6) % 7;
    }

    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()

    function shift(months: int): void {
        root.shown = new Date(root.year, root.month + months, 1);
    }

    spacing: Theme.itemSpacing

    // ---------------- Header ----------------
    Item {
        width: grid.width
        height: root.headerHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Semibold and NEVER Bold: that is Windows 11's typography rule in
            // as many words, and Fluent.strongWeight is where the theme keeps
            // the number.
            font.weight: Fluent.strongWeight
            color: root.ink
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Stepper {
                glyph: Icons.chevronLeft
                box: root.headerHeight
                ink: root.inkMuted
                rest: root.restWash
                wash: root.hoverWash
                onActivated: root.shift(-1)
            }

            Stepper {
                glyph: Icons.chevronRight
                box: root.headerHeight
                ink: root.inkMuted
                rest: root.restWash
                wash: root.hoverWash
                onActivated: root.shift(1)
            }
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
                font.pointSize: Fluent.captionSize
                font.weight: Fluent.normalWeight
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
            // Six weeks always: a month that needs five would make the flyout
            // change height from one month to the next.
            model: 42

            Item {
                id: cell

                required property int index

                readonly property int day: cell.index - root.leadingBlanks + 1
                readonly property bool inMonth: cell.day >= 1 && cell.day <= root.daysInMonth
                readonly property bool isToday: cell.inMonth
                    && root.showingThisMonth
                    && cell.day === root.today.getDate()

                implicitWidth: root.cellWidth
                implicitHeight: root.cellHeight

                Rectangle {
                    anchors.centerIn: parent

                    width: root.cellHeight - 2
                    height: root.cellHeight - 2
                    radius: height / 2

                    visible: cell.isToday
                    color: root.todayFill
                }

                Text {
                    anchors.centerIn: parent

                    visible: cell.inMonth
                    text: cell.day

                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: cell.isToday ? Fluent.strongWeight : Fluent.normalWeight
                    // Tabular figures, so the columns of a month line up with
                    // each other rather than with the width of their own digits.
                    font.features: ({ "tnum": 1 })
                    color: cell.isToday ? root.todayInk : root.ink
                }
            }
        }
    }

    // The two month steppers.
    //
    // IT WAS components/MenuRow.qml, which is the row a tray menu is built out
    // of and paints itself from Theme. Two of them here meant the only part of
    // this calendar that could not follow `ink` was the pair of steppers, and on
    // the dashboard's photographic ground that is the pair that would have
    // disappeared. One colour that answers the caller instead.
    component Stepper: Rectangle {
        id: stepper

        // EVERY COLOUR AND SIZE ARRIVES AS A PROPERTY rather than being read
        // off the outer `root`. An inline component is its own scope: an id
        // from the file around it resolves at runtime and is [unqualified] to
        // qmllint, which is the one shape almost every unqualified read in the
        // shipped theme has. Four bindings at the call site cost nothing and
        // the component becomes readable on its own terms.
        property string glyph: ""
        property int box: 30
        property color ink: "white"
        property color rest: "transparent"
        property color wash: "transparent"

        signal activated

        implicitWidth: stepper.box
        implicitHeight: stepper.box

        radius: Fluent.controlRadius
        color: stepperPointer.containsMouse ? stepper.wash : stepper.rest

        // NO `Behavior on color`. Fluent.hoverMs is 0 and it is 0 on purpose --
        // see TaskbarItem.qml, which carries the long version.

        Text {
            anchors.centerIn: parent

            text: stepper.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: stepper.ink
        }

        MouseArea {
            id: stepperPointer

            anchors.fill: parent
            hoverEnabled: true
            onClicked: stepper.activated()
        }
    }
}
