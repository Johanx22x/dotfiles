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
// Quickshell reloads when the CONTENT of a watched .qml file differs from the
// last generation that loaded successfully. Not on mtime -- touching a file
// does nothing -- and not on a rewrite with identical content. Measured, along
// with everything below it, in a headless compositor running these same files.
//
// It does NOT reload when a file is REPLACED: `git pull`, `git checkout`, an
// editor that writes a temp file and renames it. The watch was on the inode
// that got unlinked, so it dies, and nothing is logged when it does. After a
// pull the count of live file watches here goes from 122 to zero and NOTHING
// on the filesystem brings them back -- not touching, not chmod, not creating
// or deleting files in the watched directories, not `stow -R`. Only starting
// the process again, which then re-registers all 159 watches:
//
//   qs kill && qs -d --no-duplicate
//
// So editing works, and pulling needs the restart. Be aware of the asymmetry
// before automating either: a reload that cannot parse the tree leaves this
// process up on the code it already had, while a cold start on the same tree
// exits 255 and leaves no shell at all. The whole measurement is beside the
// update chain in modules/installer/InstallerState.qml.
//
// The wallpaper palette does NOT go through that path: it is read live from
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
import "modules/wallpaper"

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

    // THE MICROPHONE CLOSES ITSELF, and this line is what lets it, for the
    // same reason as the one above: nothing asks for Microphone until the
    // push-to-talk key is pressed, and by then it is far too late -- the whole
    // point is that the microphone was already shut when the session started.
    // With push-to-talk off this costs one singleton and changes nothing.
    Scope {
        Component.onCompleted: Microphone.armed
    }

    // THE BACKLIGHT IS WATCHED FROM LOGIN, and this line is what lets it, for
    // the third time and for the same reason. Nothing asks for Brightness until
    // the dashboard's slider is drawn, and the island cannot ask -- it only
    // reacts to what this singleton reports, so a watcher created on demand
    // would come into being already holding the value it was supposed to have
    // noticed changing. On a machine with no backlight it costs one process
    // spawn that prints nothing; see the header there.
    Scope {
        Component.onCompleted: Brightness.armed
    }

    // THE VOLUME AND THE NIGHT LIGHT ANSWER TO `qs ipc` FROM LOGIN, and these
    // two lines are what let them. An IpcHandler only answers once the object
    // holding it exists, so a target inside a singleton nobody has touched
    // reports "no such target" until something unrelated happens to reach for
    // it -- which for a shell full of lazily created singletons is a target
    // that works or does not depending on what you did earlier in the session.
    //
    // NightLight was worse off than that and this is not only about IPC. The
    // only thing referring to it was the Display page of the settings window,
    // and the pages are built behind `Loader { active: root.everOpened }`, so
    // the schedule it exists to run did not start until somebody opened
    // SUPER + C. On a session where nobody did, the evening never came on.
    Scope {
        Component.onCompleted: Volume.armed
    }

    Scope {
        Component.onCompleted: NightLight.armed
    }

    // THE COVER ART IS REMEMBERED FROM LOGIN, and this line is what lets it,
    // for the same reason as the four above. Track watches every MPRIS player
    // and keeps the last cover each one published, because Zen publishes an
    // artwork URL and then republishes its metadata without the key -- and
    // then STAYS that way, so a paused track reports no artwork at all while
    // the picture sits on disk.
    //
    // Nothing asks for Track until something draws a track, and everything
    // that draws one is built behind a Loader that is destroyed when it
    // closes. Left lazy, the singleton would come into being at the moment
    // the dashboard opened -- already too late to have seen the cover it was
    // supposed to remember, which was published while the panel was shut.
    Scope {
        Component.onCompleted: Track.armed
    }

    // A Bar on each screen that is meant to have one -- the main screen alone
    // until the Bar page says otherwise. See Screens.qml for how the main one
    // is chosen and why it is no longer a model name written out five times.
    //
    // THE ONLY SURFACE HERE THAT REPEATS, and the four below explain why: they
    // all take an exclusive keyboard grab and the bar never does. Each Bar gets
    // its own screen through `modelData` and reads its own widget set from it.
    Variants {
        model: Screens.barScreens

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
        model: Screens.grabScreens

        Launcher {}
    }

    // The power menu, on the same screen as the bar. Filtered to one monitor
    // deliberately: it is a single modal thing and a copy per screen would
    // mean two of them opening at once, both grabbing focus.
    Variants {
        model: Screens.grabScreens

        PowerMenu {}
    }

    // The wallpaper carousel, on the same screen as the bar. One monitor for
    // the same reason as the power menu: it takes an exclusive keyboard grab,
    // and two of them would be two sheets fighting over the keyboard.
    Variants {
        model: Screens.grabScreens

        WallpaperCarousel {}
    }

    // The keybind cheatsheet, on the same screen as the bar. One monitor for
    // the same reason as the power menu and the launcher: it takes an
    // exclusive keyboard grab, and two of them would be two surfaces fighting
    // over the keyboard.
    Variants {
        model: Screens.grabScreens

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
