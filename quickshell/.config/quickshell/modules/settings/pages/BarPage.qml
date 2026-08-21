// What the bar shows, one bar at a time.
//
// WHAT IS ON IT, NOT WHERE IT SITS. Which widget goes where is a set of
// decisions with reasons written next to them -- why the island is centred,
// why the power button is last, why the badges hang outside the centred row
// -- and turning those into a drag-and-drop layout editor would be offering
// to undo the design. Whether a widget is there at all is a different
// question, and one with no right answer: a tray is essential to somebody
// running Discord and clutter to somebody who is not.
//
// TWO OF THEM HAVE NO SWITCH, deliberately. The workspaces are how you know
// where you are; the power button is the only pointer-reachable way to end the
// session. A settings window able to hide the way out is one that can strand
// somebody.
//
// The island was a third until the bar could appear on more than one monitor.
// "This is how you know what the desktop is doing" argues for having an island,
// not for having one per screen, and SUPER + D opens the dashboard either way.
//
// ONE WIDGET LIST, AND A PICKER SAYING WHICH BAR IT IS DRAWN FOR. Every bar
// carries its own complete set of widgets -- see Config's widget section for
// the model and for what was given up to get it -- and this page draws that
// set ONCE, for whichever bar the picker has selected.
//
// IT WAS ONE SECTION PER BAR BEFORE THIS, stacked, each headed with the
// monitor's name and each ending in its own reset row. That shape was right
// about the thing it was built to fix -- a heading cannot be pointed at the
// wrong screen -- and wrong about its cost. Eight switches drawn twice is
// sixteen switches and two reset rows on a page whose entire subject is which
// widgets a bar has, and the second copy reads exactly like the first; four
// bars would have been thirty-two. Repetition is not legibility.
//
// SO WHY IS THIS NOT THE CONTROL THAT WAS REMOVED. The old ChoiceRow was
// labelled "These switches change" and offered "All" plus each monitor. It
// picked a SCOPE, which only existed because the storage underneath was a base
// plus exceptions and every switch therefore answered two questions at once:
// what this bar shows, and whether this bar has an opinion of its own. That
// model is gone and is not coming back. This picker answers one question --
// which of several independent bars you are looking at -- and there is no
// option under it that writes to more than one. The worst a mis-aimed click
// can do now is change one bar, which is visible the moment the picker is
// read and undone by clicking the switch again; "All" could move every bar at
// once and there was no way to tell from here that it had.
//
// The other half of the old complaint still stands and is answered rather than
// dismissed: the eight switches look identical whichever bar is selected, and
// the other screen is behind this window. So the selected segment is the one
// thing on the card carrying the accent, it names the monitor in the same
// spelling the Monitors section above uses, and the line under it says the
// switches belong to that bar alone.
//
// A ChoiceRow AND NOT A LIST OF ROWS, which is the opposite of what the
// recording page chose for its own monitor picker, and the difference is what
// is being listed. That one offers every connected screen and needs a second
// line on each to say the connector; this one offers only the screens that
// already carry a bar, which is at most one segment per monitor and usually
// two. ChoiceRow's own header puts its ceiling at about four options at this
// width: at 820px the card leaves roughly 540px of track, so four segments are
// about 133px each and "PG32QF2B (DP-3)" measures well inside that at the
// default font size. Four bars is the ceiling and it is a real one -- a long
// model name at a large interface font elides -- but four bars is also four
// monitors with a bar switched on apiece, and the segments are the smaller
// problem at that point.
//
// WHAT IT DOES NOT DO IS APPEAR WHEN THERE IS ONE BAR. A picker between one
// thing is the same furniture "All" was on a single-monitor machine, and
// putting that back in a new shape would be the worse version of the mistake:
// it would look like a working control. With one bar the section is exactly
// what it was -- a heading reading "Widgets" and the switches under it.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Bar"
    glyph: Icons.windowTiles
    keywords: ["bar", "clock", "time", "date", "panel", "24 hour",
        "widgets", "tray", "logo", "title", "battery", "hide",
        "laptop", "brightness", "backlight", "keyboard", "layout",
        "language", "indicator", "monitor", "monitors", "screen",
        "display", "second monitor", "per monitor", "reset", "defaults"]

    // How many of the connected monitors are carrying a bar. Used for two
    // things: to keep the last one from being switched off, and to decide
    // whether the picker below has anything to pick between.
    //
    // The last bar cannot be switched off because an empty selection means
    // "the main monitor" rather than "nowhere" (see Screens.barScreens), so
    // taking the last bar away would put the bar back on the main monitor
    // rather than leaving none -- a switch that turns itself back on.
    // Refusing the last one is the honest reading, and it keeps a settings
    // window from being the thing that hides the settings button.
    readonly property int barCount: Screens.barScreens.length

    function screenLabel(screen: var): string {
        return `${screen.model || screen.name}${screen.model ? ` (${screen.name})` : ""}`;
    }

    // ---------------- Which bar the widget switches are pointed at ----------------
    //
    // A SCREEN KEY AND NOT AN INDEX. Screens.barScreens is rebuilt whenever a
    // monitor is plugged, unplugged or given a bar, and an index into a list
    // that changes underneath is a pointer at whatever moved into that slot.
    // The key is what Config stores anyway, so it survives the list being
    // rebuilt and means the same thing on both sides.
    //
    // EMPTY IS THE NORMAL STATE, not an error: it means "nobody has picked",
    // and editScreen below answers it. Nothing writes it on load, so the page
    // has no opinion until somebody presses a segment.
    property string editing: ""

    // The bar being edited, resolved rather than stored, which is what makes
    // the switched-off case fall out instead of needing handling. Three steps,
    // in order:
    //
    //   1. The picked bar, if it is still one of the bars that exist.
    //   2. The main monitor's, otherwise. It is the bar that is always there
    //      -- Screens.barScreens falls back to the main screen when the stored
    //      list resolves to nothing -- and it is the screen the rest of the
    //      shell lives on, so it is the bar somebody who has not chosen almost
    //      certainly means.
    //   3. The first bar in connector order, if the main screen has none.
    //
    // Step 1 failing is not only somebody switching a bar off. A monitor
    // unplugged -- a laptop off its dock, a KVM on the other input -- takes
    // its bar out of the list too, and then `editing` still names it. That is
    // deliberate and it is the same judgement the display page makes about a
    // monitor it has a saved mode for: the choice stays put, the page falls
    // back to a bar that is actually there, and plugging the screen back in
    // returns the picker to where it was. Switching a bar OFF is the case
    // where the choice is genuinely revoked, and the Monitors section below
    // clears it there rather than leaving a hidden pointer at a bar that no
    // longer exists.
    readonly property var editScreen: {
        const screens = Screens.barScreens;
        if (screens.length === 0)
            return null;

        const picked = screens.find(screen => Config.screenKey(screen) === root.editing);
        if (picked)
            return picked;

        const main = screens.find(screen => Config.screenKey(screen) === Screens.mainKey);
        return main ?? screens[0];
    }

    // What every switch in the widgets section reads and writes. Null screens
    // give "" -- there is no screen at all, which is a shell with nothing on
    // it -- and Config handles that end: barWidget("") answers from the seed
    // and setBarWidget("") writes nothing.
    readonly property string editKey: Config.screenKey(root.editScreen)

    // Guarded, because screenLabel() reaches into the screen and the no-screen
    // case above hands back null.
    readonly property string editLabel: root.editScreen ? root.screenLabel(root.editScreen) : ""

    // ---------------- Monitors ----------------
    //
    // HIDDEN ON A SINGLE-MONITOR MACHINE, which is the one place in this window
    // where hiding a control is right: with one screen the only row here
    // answers a question that cannot come up -- where the bar goes -- and the
    // answer would be the same whatever you pressed.
    SettingsSection {
        width: parent.width
        visible: Screens.all.length > 1
        glyph: Icons.monitor
        title: "Monitors"

        Repeater {
            model: Screens.all

            ToggleRow {
                required property var modelData

                glyph: Icons.monitor
                label: `Bar on ${root.screenLabel(modelData)}`
                checked: Screens.hasBar(modelData)
                // The last remaining bar cannot be switched off; see barCount.
                enabled: !checked || root.barCount > 1
                onToggled: value => {
                    Config.setBarOnScreen(Config.screenKey(modelData), value, Screens.mainKey);

                    // Switching off the bar somebody is editing revokes the
                    // choice rather than parking it: see editScreen for why an
                    // unplugged monitor is treated the other way round. Without
                    // this the picker would fall back while the page is open
                    // and then silently jump back the moment the bar returned.
                    if (!value && Config.screenKey(modelData) === root.editing)
                        root.editing = "";
                }
            }
        }
    }

    // ---------------- The widgets, for one bar at a time ----------------
    SettingsSection {
        width: parent.width
        glyph: Icons.windowTiles

        // "Widgets", ALWAYS, AND NOT THE SELECTED MONITOR'S NAME. Two reasons,
        // and the second is the one that decided it.
        //
        // A heading is not where a control's value belongs: the picker is
        // inside the card with the switches it aims, where the eye already is.
        //
        // And SettingsSearch indexes a row under the `title` of the section it
        // was found in, so this string is half of every widget row's trail in
        // the search results. A title following the picker would make "Island"
        // read as "Bar > Widgets on GS27FA (HDMI-A-1)" or as
        // "Bar > Widgets on PG32QF2B (DP-3)" depending on which segment
        // happened to be pressed last -- a trail that changes under a row that
        // did not, and that names a monitor the row is not about. "Bar >
        // Widgets" is true whatever the picker says.
        //
        // The same walk is why this page's search results got shorter with
        // this change and not worse: the switches used to be indexed once per
        // bar, so "island" answered with two identical rows leading to the
        // same page, told apart only by a monitor name that the row you landed
        // on no longer showed. One list is one result.
        title: "Widgets"

        // The picker. See the header for why it is a ChoiceRow, why it is a
        // row inside the card rather than the heading, and why it is not the
        // scope selector that was removed.
        //
        // Screens.barScreens and not Config.barMonitors, so the fallbacks are
        // part of the answer -- an empty stored list means the main monitor,
        // and a list whose monitors are all unplugged falls back to it too. It
        // also means an unplugged monitor's segment simply goes, taking with
        // it the old problem of switches pointed at a screen that is not there.
        ChoiceRow {
            // Nothing to pick between with one bar; see the header.
            visible: root.barCount > 1

            glyph: Icons.monitor
            label: "Bar being edited"
            options: Screens.barScreens.map(screen => ({
                label: root.screenLabel(screen),
                value: Config.screenKey(screen)
            }))
            value: root.editKey
            onChosen: value => root.editing = value
        }

        // SAID OUT LOUD RATHER THAN LEFT TO BE INFERRED, because the shape of
        // this control is the shape of the one that used to mean something
        // else, and somebody who remembers "All" has every reason to read a
        // segmented picker over eight switches as a scope again. One line, and
        // only while there is more than one bar for it to be about.
        Text {
            visible: root.barCount > 1

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "Each bar keeps its own complete set, so these switches "
                + "change the bar named above and no other."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.arch
            label: "Distribution logo"
            checked: Config.barWidget(root.editKey, "logo")
            onToggled: value => Config.setBarWidget(root.editKey, "logo", value)
        }

        ToggleRow {
            glyph: Icons.window
            label: "Focused window title"
            checked: Config.barWidget(root.editKey, "activeWindow")
            onToggled: value => Config.setBarWidget(root.editKey, "activeWindow", value)
        }

        // The island, and this is the row the second bar is for: the pill in
        // the middle saying what is playing, what changed and what is being
        // captured. One of them is the desktop talking; two of them is the
        // same sentence twice -- which is why a new bar now starts without
        // one, and why this switch is the one most likely to be the reason
        // somebody opened this section.
        ToggleRow {
            glyph: Icons.widgets
            label: "Island"
            checked: Config.barWidget(root.editKey, "island")
            onToggled: value => Config.setBarWidget(root.editKey, "island", value)
        }

        // Same shape as the note under the settings button: a switch that can
        // hide a way in says where the other one is. The badges either side of
        // it stay -- they are anchored to the middle of the bar, not to the
        // island -- which is worth saying before somebody reads their staying
        // as the switch not having worked.
        Text {
            visible: !Config.barWidget(root.editKey, "island")

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "SUPER + D still opens the dashboard. The do-not-disturb "
                + "and capture badges stay: they belong to the middle of the "
                + "bar rather than to the island."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.apps
            label: "System tray"
            checked: Config.barWidget(root.editKey, "tray")
            onToggled: value => Config.setBarWidget(root.editKey, "tray", value)
        }

        ToggleRow {
            glyph: Icons.battery
            label: "Peripheral battery"
            checked: Config.barWidget(root.editKey, "battery")
            onToggled: value => Config.setBarWidget(root.editKey, "battery", value)
        }

        // The switch is here; WHICH layouts it cycles through is on the Input
        // page, next to everything else about the keyboard. Turning this off
        // does not turn the layouts off -- SUPER + K still works -- it only
        // takes the reading off the bar, which is what this page is about.
        //
        // With one layout configured the pill is hidden whatever this says.
        // The row stays, and the line under it explains why nothing appeared.
        ToggleRow {
            glyph: Icons.keyboard
            label: "Keyboard layout"
            checked: Config.barWidget(root.editKey, "keyboardLayout")
            onToggled: value => Config.setBarWidget(root.editKey, "keyboardLayout", value)
        }

        Text {
            visible: Config.barWidget(root.editKey, "keyboardLayout") && Config.keyboardLayouts.length < 2

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "Only one layout is configured, so there is nothing to "
                + "show and nothing to switch to. Add a second one under "
                + "Input and the indicator appears."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.clock
            label: "Clock"
            checked: Config.barWidget(root.editKey, "clock")
            onToggled: value => Config.setBarWidget(root.editKey, "clock", value)
        }

        ToggleRow {
            glyph: Icons.settings
            label: "Settings button"
            checked: Config.barWidget(root.editKey, "settingsButton")
            onToggled: value => Config.setBarWidget(root.editKey, "settingsButton", value)
        }

        // The one switch that can hide its own way back, so it says where the
        // other one is. SUPER + C is in the keybinds page too, but somebody
        // who has just made the gear disappear is looking at this row, not at
        // that page.
        //
        // "FROM THIS BAR" AND NOT "GONE", which is a word that changed meaning
        // when the sections became one. Under a heading reading "Widgets on
        // GS27FA (HDMI-A-1)" the sentence was scoped by what it sat under; in
        // a single card it reads as a statement about the desktop, and with
        // two bars it would be a false one -- the other screen still has its
        // gear. The line is otherwise the one that was here.
        Text {
            visible: !Config.barWidget(root.editKey, "settingsButton")

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "The gear is gone from this bar. SUPER + C still opens this window."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // REPURPOSED RATHER THAN REMOVED. This row used to read "This
        // monitor's exceptions / Drop them and follow All again", which was
        // the only way to get a screen back to inheriting once it had
        // disagreed. With nothing left to inherit from, the sentence has no
        // referent -- but the button still has a job, because eight
        // switches is enough that "put this bar back" is a thing to want
        // and clicking eight times is not it.
        //
        // Still only when there is something to undo, and it still says
        // what it would undo: a reset on a bar that already matches the
        // seed is a button that does nothing, and one that has been clicked
        // once with no visible result is one nobody trusts again. Bound to
        // the selected bar, so it appears and disappears as the picker moves
        // -- which is also the clearest possible statement that it is one
        // bar's reset and not the page's.
        //
        // IT NAMES THE MONITOR IN ITS SECOND LINE and not in its label. The
        // label is what SettingsSearch indexes and what a search result shows,
        // so a label following the picker would be a result whose text depends
        // on which segment was pressed last. The description is not indexed,
        // which makes it the right place for the one thing that has to be
        // unmistakable here: a button labelled "Reset" under a list that used
        // to be drawn once per bar must not be readable as resetting all of
        // them.
        //
        // A ROW AND NOT THE SECTION'S HEADING CHIP, which is where
        // SettingsSection's own header argues a section-wide action
        // belongs, and the argument is a good one -- a chip costs no
        // vertical space and does not look like a setting. It loses here on
        // two points now: a chip has nowhere to put the line underneath, and
        // that line is the whole explanation of what "reset" means and of
        // which bar it means it about. A chip in the heading of a section
        // titled "Widgets" would read as the page's reset, which is the one
        // reading it must not have.
        ActionRow {
            visible: !Config.barIsDefault(root.editKey)

            glyph: Icons.restore
            label: "This bar's widgets"
            description: root.barCount > 1
                ? `Back to the set a new bar starts with. ${root.editLabel} only — every other bar keeps what it has.`
                : "Back to the set a new bar starts with."
            actionText: "Reset"
            actionGlyph: Icons.restore
            onTriggered: Config.resetBar(root.editKey)
        }
    }

    // ---------------- Laptop ----------------
    //
    // A SECTION OF ITS OWN NOW, because these two are not per-bar and the
    // widgets above are. `laptop-modules` writes one answer for the MACHINE --
    // whether it has a battery and a backlight at all -- and repeating that
    // question once per monitor would be asking which screens the hardware is
    // attached to, which is not a question.
    //
    // SHOWN ON EVERY MACHINE, INCLUDING THE ONES THEY DO NOTHING ON, and
    // that is a deliberate exception to the rule the rest of this shell
    // follows about not drawing readings with nothing to say. install.sh
    // asks the question once at install time; without these rows the
    // answer would be unreachable forever after, and a feature nobody can
    // find is a feature that does not exist. They carry a line saying what
    // they need, so an inert switch on a desktop is explained rather than
    // mysterious.
    //
    // THE BRIGHTNESS ONE IS NOT A BAR WIDGET. It sits in the island's
    // dashboard next to the volume, where a value you set by feel belongs.
    // It is here because this is the page about what the shell shows, and
    // an "Island" page for one row would be worse than a slightly wide
    // reading of "Bar".
    SettingsSection {
        width: parent.width
        glyph: Icons.laptop
        title: "Laptop"

        ToggleRow {
            glyph: Icons.laptop
            label: "Laptop battery"
            checked: Config.laptopBattery
            onToggled: value => Config.setLaptopModule("battery", value)
        }

        ToggleRow {
            glyph: Icons.brightness
            label: "Brightness slider"
            checked: Config.laptopBrightness
            onToggled: value => Config.setLaptopModule("brightness", value)
        }

        Text {
            visible: Config.laptopBattery || Config.laptopBrightness

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "These two need the hardware as well as the switch: the "
                + "battery needs one UPower reports, and the slider needs a "
                + "backlight under /sys/class/backlight. On a machine without "
                + "them they stay hidden and leave no gap."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Clock ----------------
    //
    // ONE ANSWER FOR EVERY BAR, and the one place on this page where that is
    // still right. Whether a bar HAS a clock is per bar, above; whether a clock
    // is written in 24-hour time is about how this person reads a time, and two
    // clocks on two screens disagreeing about it would be a bug, not a setting.
    SettingsSection {
        width: parent.width
        glyph: Icons.clock
        title: "Clock"

        ToggleRow {
            glyph: Icons.clock
            label: "24-hour clock"
            checked: Config.use24Hour
            onToggled: value => Config.use24Hour = value
        }

        ToggleRow {
            glyph: Icons.calendar
            label: "Show the date"
            checked: Config.showDate
            onToggled: value => Config.showDate = value
        }
    }
}
