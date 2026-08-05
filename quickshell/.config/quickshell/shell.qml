// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - entry point
// Docs: https://quickshell.org/docs/
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// This is the shell now: waybar, wofi and dunst are gone, and hyprland.lua
// starts it with `qs -d --no-duplicate`. It runs on the MAIN monitor; the
// portrait one keeps only the rounded corners.
//
//   qs                      foreground, logs on the terminal
//   qs -d                   detached
//
// Quickshell reloads the whole config as soon as a .qml file is saved. The
// wallpaper palette does NOT go through that path: it is read live from
// colors.json, see Theme.qml.

import Quickshell
import QtQml
import "root:/"
import "modules"
import "modules/bar"
import "modules/cheatsheet"
import "modules/notifications"
import "modules/launcher"
import "modules/powermenu"
import "modules/recorder"
import "modules/settings"

ShellRoot {
    // THE INSTANT REPLAY ARMS ITSELF, and this line is what lets it.
    //
    // A Quickshell singleton is not created until something asks for it, and
    // nothing asks for this one at startup: the island only reaches for it
    // when a clip has been saved, which cannot happen until it is running.
    // Without this the buffer would arm the first time it was already needed.
    Scope {
        Component.onCompleted: ReplayState.armed
    }

    // One Bar on the shell's main screen; see Screens.qml for how that one is
    // chosen and why it is no longer a model name written out five times.
    //
    // Variants is still what would make this scale to every monitor on the day
    // that is wanted: `model: Quickshell.screens` and each screen gets its own
    // bar with its own `modelData`. Workspaces.qml is already written for it.
    Variants {
        model: Screens.mainOnly

        Bar {}
    }

    // The notification daemon, on the same screen as the bar. It takes the
    // org.freedesktop.Notifications bus name, so dunst must not be running.
    Variants {
        model: Screens.mainOnly

        Notifications {}
    }

    // The launcher, on the same screen as the bar. One monitor only, like the
    // power menu: it takes an exclusive keyboard grab, and two of them would
    // be two surfaces fighting over the keyboard.
    Variants {
        model: Screens.mainOnly

        Launcher {}
    }

    // The power menu, on the same screen as the bar. Filtered to one monitor
    // deliberately: it is a single modal thing and a copy per screen would
    // mean two of them opening at once, both grabbing focus.
    Variants {
        model: Screens.mainOnly

        PowerMenu {}
    }

    // The keybind cheatsheet, on the same screen as the bar. One monitor for
    // the same reason as the power menu and the launcher: it takes an
    // exclusive keyboard grab, and two of them would be two surfaces fighting
    // over the keyboard.
    Variants {
        model: Screens.mainOnly

        Cheatsheet {}
    }

    // The settings window. NOT wrapped in Variants, and it is the only thing
    // here that is not: everything above is a layer surface, which belongs to
    // one screen and has to be told which. This is an ordinary window -- the
    // compositor decides where it opens, the same way it does for a terminal.
    Settings {}

    // Rounded display corners, on EVERY monitor -- they belong to the panel
    // edge, not to the bar, so they are not filtered by model.
    Variants {
        model: Quickshell.screens

        ScreenCorners {}
    }
}
