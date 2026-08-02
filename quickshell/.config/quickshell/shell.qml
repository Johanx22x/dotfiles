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
import "modules"
import "modules/bar"
import "modules/notifications"
import "modules/launcher"
import "modules/powermenu"
import "modules/recorder"

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

    // One Bar per matching screen. Variants is what makes this scale to both
    // monitors on migration day: widen the filter and each screen gets its
    // own bar with its own `modelData`.
    //
    // The screen is matched by MODEL, not by connector name: "HDMI-A-1" is
    // assigned by the kernel and moves between kernel versions (same reason
    // waybar matches on description). Quickshell reports serialNumber empty
    // on both monitors here, so the model is the only stable handle -- it
    // would only be ambiguous with two identical monitors, which is not the
    // case: GS27FA (portrait) vs PG32QF2B (main).
    Variants {
        model: Quickshell.screens.filter(screen => screen.model === "PG32QF2B")

        Bar {}
    }

    // The notification daemon, on the same screen as the bar. It takes the
    // org.freedesktop.Notifications bus name, so dunst must not be running.
    Variants {
        model: Quickshell.screens.filter(screen => screen.model === "PG32QF2B")

        Notifications {}
    }

    // The launcher, on the same screen as the bar. One monitor only, like the
    // power menu: it takes an exclusive keyboard grab, and two of them would
    // be two surfaces fighting over the keyboard.
    Variants {
        model: Quickshell.screens.filter(screen => screen.model === "PG32QF2B")

        Launcher {}
    }

    // The power menu, on the same screen as the bar. Filtered to one monitor
    // deliberately: it is a single modal thing and a copy per screen would
    // mean two of them opening at once, both grabbing focus.
    Variants {
        model: Quickshell.screens.filter(screen => screen.model === "PG32QF2B")

        PowerMenu {}
    }

    // Rounded display corners, on EVERY monitor -- they belong to the panel
    // edge, not to the bar, so they are not filtered by model.
    Variants {
        model: Quickshell.screens

        ScreenCorners {}
    }
}
