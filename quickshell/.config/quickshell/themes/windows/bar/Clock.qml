// The clock, in the corner, in two right-aligned lines.
//
// TWO LINES AND NOT ONE, which is the single most recognisable thing about the
// Windows taskbar's right-hand end: the time above the date, both right-aligned
// against the corner, both in Caption. Genesis's clock was one line with a
// glyph in front of each reading; the glyphs are gone, because Windows has none
// there and because two rows of 12px type in a 34px box leaves no room for them.
//
// TABULAR FIGURES. `font.features` asks OpenType for `tnum`, which makes every
// digit the same width, so the reading does not shuffle as the minutes tick.
// It matters more here than it did on one line: two stacked right-aligned rows
// are exactly where proportional digits show up as the columns disagreeing with
// each other. If the user's face has no `tnum` table the request is ignored and
// nothing breaks -- and the fallback is the same one genesis relied on, a fixed
// format string, which keeps the CHARACTER count constant even when the widths
// are not.
//
// IT IS A CONTROL AGAIN. Genesis's note says the clock is a reading with
// nothing behind it and that the calendar belongs in the dashboard. That is
// genesis's answer; Windows' is that the clock is the door to the calendar, so
// this one has its own hover fill like every other item in the corner and
// opens CalendarView underneath itself. The dashboard still draws its own
// month -- see island/Dashboard.qml, which instantiates the same file.
//
// precision: Minutes means the clock wakes up once a minute instead of once a
// second. There is no process, no interval and no script behind it.

import Quickshell
import QtQuick
import qs
import qs.components
import qs.themes.windows

TaskbarItem {
    id: root

    // The bar's shared popout, handed down by Bar.qml.
    required property Popout popout

    // OURS, both of them. The type ramp is Microsoft's -- Caption is 12 and
    // Fluent.captionSize carries it -- but the taskbar clock's line height and
    // its side padding are shell chrome and nobody publishes those. 15 is
    // Caption's 16 pulled in by one so two lines clear a 34px box with a
    // margin; 12 is measured off a screenshot.
    readonly property int clockLine: 15
    readonly property int padH: 12

    boxWidth: Math.max(time.implicitWidth, date.visible ? date.implicitWidth : 0)
        + root.padH * 2

    onActivated: root.popout.toggleAt(root.mapToItem(null, root.width / 2, 0).x, calendarComponent)

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: root.padH
        anchors.verticalCenter: parent.verticalCenter

        // A Column positions on the y axis only, so anchoring these two to its
        // right edge is what right-aligns them against each other. Without it
        // they would sit left-aligned inside a column as wide as the longer one.
        Text {
            id: time

            anchors.right: parent.right

            // "hh:mm AP" and not "h:mm AP": the reading has to keep a constant
            // width or everything to the left of the clock moves every time the
            // hour goes from 9 to 10.
            text: Qt.formatDateTime(clock.date, Config.use24Hour ? "HH:mm" : "hh:mm AP")

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            font.features: ({ "tnum": 1 })
            color: Theme.textOnSurface

            // Set explicitly, because Windows sets none: WinUI's text styles
            // carry family, size and weight and nothing else, and the published
            // line heights are what Segoe's own metrics happen to produce. With
            // any substitute face they have to be written down or the two rows
            // drift apart.
            lineHeightMode: Text.FixedHeight
            lineHeight: root.clockLine
        }

        // BOTH LINES IN THE PRIMARY INK. The date is not a caption under the
        // time; on the real taskbar they are the same colour and the same size,
        // and the hierarchy between them is which one is on top.
        Text {
            id: date

            anchors.right: parent.right

            visible: Config.showDate
            text: Qt.formatDateTime(clock.date, "dd/MM/yyyy")

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            font.features: ({ "tnum": 1 })
            color: Theme.textOnSurface

            lineHeightMode: Text.FixedHeight
            lineHeight: root.clockLine
        }
    }

    // THE FLYOUT. It is the same CalendarView the dashboard draws, and the
    // panel around it belongs to components/Popout.qml -- which anchors itself
    // to the top of the screen. With the taskbar at the bottom this opens at
    // the WRONG EDGE, and that is a host facade rather than anything this file
    // can reach. See the note over the Popout in Bar.qml.
    Component {
        id: calendarComponent

        CalendarView {}
    }
}
