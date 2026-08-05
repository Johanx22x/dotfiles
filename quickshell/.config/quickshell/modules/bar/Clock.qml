// Clock. Compact and icon-led: a glyph introduces each reading and the
// numbers carry it, with no separator and no words.
//
// What went away from the old "HH:mm  ·  ddd, dd/MM" label:
//
//   - The weekday. It was the widest part of the label, the only part that
//     changed width from one day to the next, and the one thing nobody
//     actually reads off a bar -- the date already says it.
//   - The middle dot. Two glyphs already mark where one reading ends and the
//     next begins; a separator on top of that is a third mark doing the same
//     job.
//
// Both readings are fixed-width ("HH:mm", "dd/MM"), so the group holds a
// constant size as the clock ticks.
//
// IT IS A READING, NOT A CONTROL. Clicking it used to open a month calendar
// in the bar's popout. That moved to the dashboard, which is where a calendar
// belongs: a thing you go to and read, not a thing that springs out of the
// corner of the screen when you meant to check the time. The clock is now the
// only widget on the bar with nothing behind it, which is the point.
//
// precision: Minutes means the clock wakes up once a minute instead of once
// a second. This is the kind of thing that made the shell worth swapping:
// there is no process, no interval and no script behind it.

import Quickshell
import QtQuick
import "root:/"

Item {
    id: root

    // The gap between a glyph and the number it introduces. Tighter than
    // Theme.itemSpacing on purpose: the icon and its number are one reading,
    // and they have to bind more closely to each other than the time binds to
    // the date.
    readonly property int glyphGap: 5

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.groupHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.itemSpacing

        // ---------------- Time ----------------
        Row {
            spacing: root.glyphGap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.clock
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                // The glyphs stay muted and the numbers lead: the accent is
                // spoken for elsewhere on the bar (the logo, today's date,
                // the active workspace) and a third claim on it would flatten
                // the hierarchy.
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // "hh:mm AP" and not "h:mm AP": the reading has to keep a
                // constant width or the group either side of it moves every
                // time the hour goes from 9 to 10. A leading zero on a
                // 12-hour clock is unusual, and it is the price of a bar that
                // does not twitch.
                text: Qt.formatDateTime(clock.date, Config.use24Hour ? "HH:mm" : "hh:mm AP")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // ---------------- Date ----------------
        //
        // Hidden as a whole -- glyph and number together. Hiding only the
        // number would leave a calendar icon introducing nothing.
        Row {
            visible: Config.showDate
            spacing: root.glyphGap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.calendar
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "dd/MM")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                // One step down from the time: same reading, lesser urgency.
                font.weight: Theme.fontWeight
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }
    }

}
