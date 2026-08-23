// WHICH OF THE SHELL'S OWN SURFACES IS UP, AND THE ONE RULE THAT KEEPS IT TO ONE.
//
// THE MEMBERS, and the test for being one:
//
//   the launcher            LauncherState.isOpen
//   the power menu          PowerMenuState.isOpen
//   the cheatsheet          CheatsheetState.isOpen
//   the wallpaper carousel  WallpaperState.isOpen
//   the bar's popout        popoutOpen below, published by every Bar
//
// THE RULE: exactly one of those five is on screen at a time, and the one that
// stays is whichever went up last. It is symmetric on purpose -- see the two
// sections at the bottom of this header for why, and for the one surface that
// is deliberately not a member.
//
// FIVE IS WHAT THE HOST BRINGS, NOT WHAT THE RULE IS LIMITED TO. Those five
// exist whatever is drawing them: four are host state a theme renders and the
// fifth is reported by whatever draws a bar. A theme with a surface of its own
// -- something the host has never heard of, that still takes the screen and
// still has to yield it -- calls register() below and becomes a member on the
// same terms. Nothing does today: genesis draws these five and no others.
//
// THE FIRST FOUR ARE THE GRABBING SURFACES, and that is the whole membership
// test for them: a layer surface on the Overlay layer that asks for
// WlrKeyboardFocus.Exclusive. They are already gathered under that name
// elsewhere -- shell.qml builds all four from `Screens.grabScreens` and says
// "they all take an exclusive keyboard grab and the bar never does", and
// Screens.qml explains why one grab per session means one screen. Two of them
// up at once is two surfaces holding the keyboard and the one that answers is
// whichever the compositor happened to hand it to.
//
// IT IS NOT "COVERS THE BAR", which is the near miss worth naming because it
// looks like the same set and is not. The cheatsheet, the carousel and the
// power menu are the size of the screen; the LAUNCHER is not -- it hangs from
// the bar's underside with `margins.top: Theme.barHeight`, in exactly the place
// the dashboard hangs from, and leaves the bar clickable above it. Covering is
// what makes a sheet hide a panel; the grab is what makes it deaf. Only the
// grab is true of all four.
//
// THE POPOUT IS THE FIFTH AND TAKES NO GRAB AT ALL -- components/Popout.qml
// asks for WlrKeyboardFocus.None, and its header says why. It is a member for
// the two reasons a grab would have given it. The panels a key can summon into
// it, the dashboard and the notification history, hang from the same place the
// launcher does and neither is readable through the other. And everything it
// can show, those two included, sits on the Overlay layer with the sheets,
// where stacking is creation order -- which Popout.qml states in as many words
// is not something to rely on.
//
// THE SETTINGS WINDOW IS NOT A MEMBER. It is a FloatingWindow: an ordinary
// toplevel that the compositor stacks, focuses and closes like a terminal, with
// no grab and no claim on anything else here. Nothing may close it -- a window
// that disappeared because a key was pressed somewhere else is a window that
// loses work -- so it cannot take the symmetric rule. It still needs the
// popouts dismissed on its way up, for a mechanism that has nothing to do with
// grabs, and that is the one clause at the bottom of this file.
//
// WHY THE RULE IS HERE AND NOT IN THE SURFACES IT ARBITRATES. It used to be
// written one pair at a time: CheatsheetState closed four singletons,
// WallpaperState closed five, LauncherState closed itself off a report, Bar.qml
// closed its own popout for the launcher and for the settings window, and the
// power menu closed nothing whatsoever. Five files spelling out ten pairs, with
// holes in it -- SUPER + SHIFT + ESCAPE over an open launcher left two exclusive
// grabs up, and nothing anywhere put the popout away for the power menu. A mesh
// that has to be edited in n places when the n+1th surface arrives will be
// short a pair, and was.
//
// So the pairs are gone and this is the only file that knows the membership.
// Screens.qml already claimed this was true -- "one of them at a time, always"
// -- while no code implemented it; now one function does.
//
// WHY IT IS ARMED FROM shell.qml. A Quickshell singleton is not created until
// something asks for it, and an arbiter nobody reads is an arbiter that never
// hears a signal. The bars reach for `popoutOpen` and would build it in
// practice, but then the half of the rule that has nothing to do with bars
// would depend on one existing. See the Scope beside the others in shell.qml.

pragma Singleton

import Quickshell
// For Connections. A singleton that only declares properties does not need
// QtQuick; every handler below does.
import QtQuick
import qs.modules.cheatsheet
import qs.modules.island
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.powermenu
import qs.modules.settings
import qs.modules.wallpaper

Singleton {
    id: root

    // Read by shell.qml to bring this singleton into existence at startup --
    // see the last paragraph of the header.
    readonly property bool armed: true

    // WHETHER ANY POPOUT IS UP ON ANY BAR, published by Bar.qml. A REPORT and
    // not a request: assigning it closes nothing, and the only thing that
    // reaches a popout is the signal below.
    //
    // It has to be a report because there is one popout PER BAR and a singleton
    // cannot reach a window. A bar can see whether IT is showing something and
    // cannot see the other bars, so what arrives here is one bar's news about
    // something global: it can read false while another bar still has a panel
    // up. Everything acts on the RISING edge alone for that reason, and the next
    // opening raises the edge again.
    //
    // THIS WAS CALLED dashboardOpen AND LIVED ON LauncherState, and the name is
    // what went wrong: three files assigned it false believing that closed the
    // dashboard, and every one of them changed a mirror and left the panel on
    // screen. The one popout a bar owns also serves the tray menus and the
    // peripheral batteries, so it has always gone true for a tray icon as well.
    property bool popoutOpen: false

    // EVERY POPOUT ON EVERY BAR, CLOSE. The broadcast half of the rule, because
    // the receiver is per bar and this is not: each Bar connects its own popout
    // to this and closes it.
    //
    // IT IS NOT REDUNDANT WITH THE TWO DOORS called beside it in dismiss()
    // below, and the difference is the tray. closeDashboard() and
    // closeHistory() reach the two panels that have a singleton to be reached
    // through; a tray menu and the peripheral-battery detail have no state
    // outside the popout, no IpcHandler and no key, so nothing can name them.
    // They can still be up when a sheet arrives, and then they are exactly as
    // stuck as the panels were.
    signal dismissPopouts

    // Putting away everything the bars have hanging, whatever it is.
    //
    // THE DOORS FIRST, THEN THE SURFACE, and the order says which is the
    // mechanism. IslandState.dashboardScreen and NotificationState.historyScreen
    // name the bar their panel is drawn on; clearing the string is what makes
    // the panel go, and the popout closing is the consequence. Closing the
    // window alone would work today -- Island.qml and NotificationButton.qml
    // both clear their string when their popout stops showing their content --
    // but it would leave the global fact being cleared by a side effect of one
    // bar reacting, and a bar that is being torn down at that moment would leave
    // the string set. A set string is worse than a stale window: the
    // follow-the-focus rule retargets it on every pointer crossing and rebuilds
    // the panel on each monitor in turn, behind a sheet the user believes closed
    // everything. That is the bug those doors were added for.
    function dismiss(): void {
        IslandState.closeDashboard();
        NotificationState.closeHistory();
        root.dismissPopouts();
    }

    // THE MEMBERSHIP, AS A LIST RATHER THAN AS FIVE BRANCHES. Each member is a
    // name and the one thing that puts it away; keep() below walks them.
    //
    // WHY IT IS DATA NOW. These five come with the host and are the same five
    // whatever is drawing them -- the launcher, the power menu, the cheatsheet
    // and the carousel are host state that a theme renders, and the popout is
    // reported by whatever draws a bar. But a theme with a surface the host has
    // never heard of has nowhere to put it, and the header above is emphatic
    // that a membership edited in n places will be short a pair. So the five
    // stay here and anything else registers; the rule itself does not care
    // which list a member came from.
    readonly property var builtIn: [
        {
            name: "launcher",
            close: () => LauncherState.isOpen = false
        },
        {
            name: "powermenu",
            close: () => PowerMenuState.isOpen = false
        },
        {
            name: "cheatsheet",
            close: () => CheatsheetState.isOpen = false
        },
        {
            name: "wallpaper",
            close: () => WallpaperState.isOpen = false
        },
        {
            name: "popout",
            close: () => root.dismiss()
        }
    ]

    // What a theme has added. Empty for genesis, which draws the five above and
    // nothing else.
    property var registered: []

    readonly property var members: root.builtIn.concat(root.registered)

    // A SURFACE THE HOST DOES NOT KNOW ABOUT, JOINING THE RULE. `close` is
    // called with no arguments and has to put the surface away by itself.
    //
    // THE EDGE IS THE CALLER'S JOB, and that is the one asymmetry with the five
    // above. The built-in members have a singleton with an isOpen the
    // Connections at the bottom can watch; a theme's own surface has whatever
    // it has, so it announces itself by calling keep() with its own name when
    // it opens. That is the same call the five make, one layer up.
    //
    // AND IT MUST BE UNDONE. A theme is swapped out by destroying its surfaces
    // (see modules/ThemeSurface.qml), and a member left registered is a close()
    // closing over an object that no longer exists -- so whatever registers on
    // the way up unregisters on the way down.
    function register(name: string, close: var): void {
        root.unregister(name);
        root.registered = root.registered.concat([
            {
                name,
                close
            }
        ]);
    }

    function unregister(name: string): void {
        root.registered = root.registered.filter(member => member.name !== name);
    }

    // THE RULE ITSELF. One surface names itself; every other member goes.
    //
    // A STRING RATHER THAN AN OBJECT because one of the five -- the popout -- is
    // not a singleton and has no object to name. Every call is one of the five
    // lines at the bottom of this file, or a theme's own surface announcing
    // itself, so a misspelling is not a silent no-op hiding somewhere in the
    // tree: it means the surface closes itself the instant it opens, in front
    // of the person who pressed the key.
    function keep(surface: string): void {
        for (const member of root.members)
            if (member.name !== surface)
                member.close();
    }

    // The five call sites, in one place so the membership can be read off them.
    // Each acts on the RISING edge: a surface closing is not a claim on the
    // screen, and treating it as one would have every close reach into four
    // other files for nothing.
    //
    // NO REENTRANCY TO WORRY ABOUT, and it is worth saying why rather than
    // leaving it to be rediscovered. keep() only ever assigns FALSE, so every
    // change it causes is a falling edge, and every handler here ignores those.
    // One keypress therefore produces one pass.
    Connections {
        target: LauncherState

        function onIsOpenChanged(): void {
            if (LauncherState.isOpen)
                root.keep("launcher");
        }
    }

    Connections {
        target: PowerMenuState

        function onIsOpenChanged(): void {
            if (PowerMenuState.isOpen)
                root.keep("powermenu");
        }
    }

    Connections {
        target: CheatsheetState

        function onIsOpenChanged(): void {
            if (CheatsheetState.isOpen)
                root.keep("cheatsheet");
        }
    }

    Connections {
        target: WallpaperState

        function onIsOpenChanged(): void {
            if (WallpaperState.isOpen)
                root.keep("wallpaper");
        }
    }

    // The popout's own edge. What raised it is not asked and does not matter:
    // a tray icon clicked on the bar, SUPER + D, SUPER + SHIFT + N, the bell.
    // The launcher is the one member that leaves the bar clickable, so the
    // click is a real way in and not only a keybind.
    onPopoutOpenChanged: if (root.popoutOpen)
        root.keep("popout")

    // AND THE SETTINGS WINDOW, WHICH IS NOT A MEMBER AND IS NOT TIDINESS.
    //
    // One direction only: opening it dismisses the popouts, and nothing here
    // ever closes it. The header says why it cannot take the symmetric rule.
    //
    // THE MECHANISM IS THE POINTER AND NOT THE KEYBOARD, which is why this
    // clause could not be folded into keep() above and stay honest. On a
    // compositor with no focus-grab protocol -- niri, and anything that is not
    // Hyprland -- an open popout is backed by a transparent full-screen catcher
    // on the Top layer (components/FocusGrab.qml). Top is ABOVE every ordinary
    // window, so while that catcher is up the settings window is a window
    // nobody can click: the first press on it is spent putting the popout away
    // and the control under the pointer never hears about it.
    //
    // Nothing used to close the popout on the way there. The gear that opens
    // the window lives on the bar, and the bar is exactly the strip the catcher
    // leaves out of its input region so that moving between panels costs one
    // click -- so the press reached the gear, the window opened, and the catcher
    // stayed up over it. SUPER + C never touches the bar at all and left it up
    // the same way.
    Connections {
        target: SettingsState

        function onIsOpenChanged(): void {
            if (SettingsState.isOpen)
                root.dismiss();
        }
    }
}
