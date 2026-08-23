// THE CLOCK AND THE MONTH, WHICH IS THE BOTTOM HALF OF WIN+N.
//
// scratchpad/ref/notifcenter-calendar-empty.jpg is the whole of it: a large
// time WITH SECONDS, a weekday-and-date line under it, a collapse chevron hard
// right, then the month -- name and year at the left, two small chevrons at
// the right, two-letter weekday headers, out-of-month days dimmed, and today
// as a filled accent circle with DARK text in it. That last one looks wrong
// until you see the real thing: dark mode's accent is the light end of the
// ramp, so what sits on it is black.
//
// WHAT IS NOT HERE. The photograph has a focus-session row at the bottom --
// `-` / `30 mins` / `+` and a Focus button. This shell has no focus sessions,
// and a control that looks like one and starts nothing is worse than an
// honest gap.
//
// SECONDS COST A WAKEUP A SECOND, and it is why the SystemClock below is
// enabled only while this is on screen. The taskbar's clock is on Minutes for
// exactly this reason; a panel that is up for ten seconds at a time can afford
// what a bar that is up all day cannot.

import Quickshell
import QtQuick
import qs
import qs.themes.windows

Column {
    id: root

    readonly property int padding: Theme.notificationPadding

    // Which month is drawn, as an offset from the one today is in. Reset when
    // the panel closes, because it is built fresh every time it opens.
    property int monthOffset: 0

    property bool monthVisible: true

    // The first of the month being drawn. Day 1 of `today's month + offset` --
    // Date normalises the overflow, so December + 1 is next January.
    readonly property date firstDay: new Date(clock.date.getFullYear(),
                                              clock.date.getMonth() + root.monthOffset,
                                              1)

    // Where the grid starts: back up from the first of the month to the start
    // of its week, in the locale's own first day. Six rows of seven always,
    // so the panel does not change height between months.
    readonly property date gridStart: {
        const start = new Date(root.firstDay);
        const lead = (start.getDay() - Qt.locale().firstDayOfWeek + 7) % 7;
        start.setDate(start.getDate() - lead);
        return start;
    }

    readonly property int cell: Math.floor((root.width - root.padding * 2) / 7)

    spacing: 0

    SystemClock {
        id: clock

        enabled: true
        precision: SystemClock.Seconds
    }

    // ---------------- The time ----------------
    Item {
        width: parent.width
        height: time.implicitHeight + date.implicitHeight + root.padding

        Text {
            id: time

            anchors.left: parent.left
            anchors.leftMargin: root.padding
            anchors.top: parent.top

            text: Qt.formatDateTime(clock.date, Config.use24Hour ? "HH:mm:ss" : "h:mm:ss")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.titleSize
            color: Theme.textOnSurface
        }

        // The meridiem, small and on the big time's baseline, which is what
        // the photograph shows and what stops "AM" being as tall as the hour.
        Text {
            anchors.left: time.right
            anchors.leftMargin: Theme.groupSpacing
            anchors.baseline: time.baseline

            visible: !Config.use24Hour
            text: Qt.formatDateTime(clock.date, "AP")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.textOnSurface
        }

        Text {
            id: date

            anchors.left: parent.left
            anchors.leftMargin: root.padding
            anchors.top: time.bottom

            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.textOnSurfaceVariant
        }

        ChevronButton {
            anchors.right: parent.right
            anchors.rightMargin: root.padding
            anchors.top: parent.top

            content: Icons.chevronDown
            turn: root.monthVisible ? 0 : 180

            onActivated: root.monthVisible = !root.monthVisible
        }
    }

    // ---------------- The month ----------------
    Item {
        width: parent.width
        height: root.monthVisible ? Fluent.navItemHeight : 0

        visible: root.monthVisible

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.padding
            anchors.verticalCenter: parent.verticalCenter

            text: Qt.formatDate(root.firstDay, "MMMM yyyy")
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.padding
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            ChevronButton {
                content: Icons.chevronDown
                turn: 180

                onActivated: root.monthOffset -= 1
            }

            ChevronButton {
                content: Icons.chevronDown

                onActivated: root.monthOffset += 1
            }
        }
    }

    // The weekday headers. Two letters, which is what Windows shows and what
    // fits a cell this wide.
    Row {
        x: root.padding

        visible: root.monthVisible
        spacing: 0

        Repeater {
            model: 7

            Text {
                id: weekday

                required property int index

                width: root.cell
                height: root.cell

                text: Qt.locale().dayName((Qt.locale().firstDayOfWeek + weekday.index) % 7,
                                          Locale.ShortFormat).slice(0, 2)
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.outline
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Six rows of seven. Always six, so the panel does not jump a row's height
    // when the month changes.
    Grid {
        x: root.padding

        visible: root.monthVisible
        columns: 7
        rows: 6
        spacing: 0

        Repeater {
            model: 42

            Item {
                id: dayCell

                required property int index

                readonly property date day: {
                    const when = new Date(root.gridStart);
                    when.setDate(when.getDate() + dayCell.index);
                    return when;
                }

                readonly property bool inMonth: dayCell.day.getMonth() === root.firstDay.getMonth()

                readonly property bool today: dayCell.day.getFullYear() === clock.date.getFullYear()
                    && dayCell.day.getMonth() === clock.date.getMonth()
                    && dayCell.day.getDate() === clock.date.getDate()

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.centerIn: parent

                    width: Fluent.controlHeight
                    height: Fluent.controlHeight

                    radius: width / 2
                    visible: dayCell.today
                    color: Theme.primary
                }

                Text {
                    anchors.centerIn: parent

                    text: dayCell.day.getDate()
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    // Black on the accent circle. Dark mode's accent is the
                    // LIGHT shade of the ramp; this is not a mistake to fix.
                    color: {
                        if (dayCell.today)
                            return Theme.textOnPrimary;
                        return dayCell.inMonth ? Theme.textOnSurface : Theme.outline;
                    }
                }
            }
        }
    }

    // A bottom inset, so the grid does not sit on the panel's edge.
    Item {
        width: parent.width
        height: root.padding
    }

    // A 32px square -- ControlHeight, Microsoft's own -- with the glyph
    // centred in it. Bigger than the toast's header buttons because these are
    // the only way to move a month, and a 24px target for a control you aim at
    // repeatedly is a control you miss.
    component ChevronButton: Rectangle {
        id: chevron

        required property string content

        property int turn: 0

        readonly property bool hovered: pointer.containsMouse
        readonly property bool held: pointer.pressed

        signal activated

        width: Fluent.controlHeight
        height: Fluent.controlHeight

        radius: Fluent.controlRadius
        color: {
            if (chevron.held)
                return Fluent.fillPress;
            if (chevron.hovered)
                return Fluent.fillSubtleHover;
            return "transparent";
        }

        Text {
            anchors.centerIn: parent

            text: chevron.content
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
            rotation: chevron.turn
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            onClicked: chevron.activated()
        }
    }
}
