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
// that got unlinked, so it dies, and nothing is logged when it does. A running
// shell holds 152 watches inside this tree -- one per .qml file, 126 of them,
// plus 26 on the directories that hold them -- and a pull takes every FILE
// watch to zero. The directory watches survive and do not help: nothing on the
// filesystem re-arms a file watch from them, not touching, not chmod, not
// creating or deleting files in the watched directories, not `stow -R`. Only
// starting the process again, which registers all 152 afresh:
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
import qs.modules
import qs.modules.notifications
import qs.modules.recorder
import qs.modules.settings
// EVERYTHING ABOVE IS THE HOST: the arbiter, the state singletons, the
// services and the settings window -- everything that decides what exists.
// What DRAWS is a directory under themes/, and nothing below instantiates a
// type out of one: the surfaces are `ThemeSurface`, loaded out of the current
// theme by path at runtime. Config.theme is the name, modules/Themes.qml turns
// it into URLs, modules/ThemeSurface.qml is what loads one, and the README
// beside a theme is the account of what a theme may and may not be.
//
// SO THE LINES BELOW DECLARE WHICH THEMES EXIST, AND Config.theme DECIDES
// WHICH ONE RUNS. They are the two halves of a sentence and neither is the
// other: nothing here builds a genesis type, and setting Config.theme to
// something else swaps every surface without touching this file.
//
// THEY ARE HERE FOR THE WATCHES. The scan that registers Quickshell's file
// watches is the same one that follows the imports out of this file, so a
// directory nothing imports is a directory nothing watches -- and between the
// commit that moved the theme out of modules/ and this one, editing any of the
// 32 files under themes/ reloaded nothing at all. A static import restores the
// watch even though the file is still loaded dynamically, because the import
// exists for the SCAN and not for instantiation. Measured on this tree in a
// headless compositor: 112 watched files and directories without these lines
// and 152 with them, and an edit in each of the eight directories below now
// reloads where none of them did before.
//
// AND IT DOES NOT MAKE A BROKEN THEME FATAL, which is the thing worth knowing
// before adding a line here, because it is what you would expect and it is not
// what happens. QML compiles a type when something USES it, so importing a
// directory lists its files without parsing them. Measured with a line of
// garbage appended to themes/genesis/bar/Clock.qml -- the same line
// tests/shell-load.sh describes breaking Config.qml with -- and probe as the
// active theme: the cold start printed "Configuration Loaded" and logged
// nothing at all, byte for byte the same result as the same tree with these
// imports removed. A broken file in the theme that IS drawing costs the widget
// that uses it and a "Syntax error" warning, exactly as it did before. The
// only cold start that still exits 255 is a broken SINGLETON in the host
// chain, which is what the paragraph above is about.
//
// NO CURLY BRACE ANYWHERE IN THIS HEADER, and that is why the paragraph above
// describes the broken line instead of quoting it. A brace in a comment before
// the imports ends the import list as far as Quickshell's scanner is
// concerned: the ENGINE still reads every line below and resolves them, so the
// file loads and then dies with "module qs.themes.genesis is not installed"
// for all eight at once -- an error about the imports that is really about a
// comment thirty lines above them. It cost a run here. modules/Themes.qml
// carries the same warning over its own header for the same reason and a
// different symptom.
//
// A THEME NOT LISTED HERE STILL RUNS. It is loaded by URL, so `cp -r genesis
// tokyo` and a Config.theme of "tokyo" draws the copy with no line added --
// measured, with no config reload. What it gives up is the watch, and the host
// modules that only it imports (see keptInScope in modules/Themes.qml). A
// theme that lives in this repository belongs on the list; one dropped into
// themes/ by hand does not have to be.
//
// AND qmllint IS RIGHT THAT THEY ARE UNUSED, which is why it is silenced for
// these eight lines and only these eight. "Unused" is the point: an import
// nothing instantiates is exactly what a theme's directories are here for, so
// the finding is correct and the code is deliberate. Silenced here rather than
// budgeted in tests/qml-lint.sh because that budget is per category across the
// whole tree, and a budget of eight would hide the ninth unused import
// wherever it appeared.
//qmllint disable unused-imports
import qs.themes.genesis
import qs.themes.genesis.bar
import qs.themes.genesis.cheatsheet
import qs.themes.genesis.components
import qs.themes.genesis.island
import qs.themes.genesis.launcher
import qs.themes.genesis.notifications
import qs.themes.genesis.powermenu
import qs.themes.genesis.wallpaper
//qmllint enable unused-imports

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

    // THE NOTIFICATION DAEMON ANSWERS THE BUS FROM LOGIN, and this line is what
    // lets it, for the same reason as the five above and with more riding on it
    // than any of them. modules/notifications/NotificationDaemon.qml owns
    // org.freedesktop.Notifications, and the only thing that would ever ask for
    // it is the surface that draws the cards -- so the bus name would be claimed
    // by whichever theme happened to draw a notification panel, and a theme that
    // drew none would leave it unclaimed for dunst to be D-Bus activated into.
    // That is what living inside a theme file cost, and this line is what ends
    // it: the daemon is up because the shell is up.
    Scope {
        Component.onCompleted: NotificationDaemon.armed
    }

    // THE ONE-SURFACE-AT-A-TIME RULE IS AWAKE FROM LOGIN, and this line is what
    // lets it, for the same reason as the five above. modules/Surfaces.qml is an
    // arbiter: it listens to the singletons behind the launcher, the power menu,
    // the cheatsheet, the carousel and the bars' popouts, and closes whichever
    // of them did not just ask for the screen. Nothing READS it except the bars,
    // so left lazy it would come into being the first time a bar was built and
    // the half of the rule that has nothing to do with bars would silently
    // depend on there being one.
    Scope {
        Component.onCompleted: Surfaces.armed
    }

    // EVERY SURFACE BELOW IS THE SAME SHAPE, and the shape is the seam. This
    // file says WHAT exists and on which screens; the `file` is a path inside
    // whatever theme is current and is the only thing that changes between
    // them. A theme that draws a bar differently changes nothing here; a theme
    // that has no bar at all cannot say so yet -- the list of surfaces is
    // written out below rather than read off the theme's manifest.

    // A Bar on each screen that is meant to have one -- the main screen alone
    // until the Bar page says otherwise. See Screens.qml for how the main one
    // is chosen and why it is no longer a model name written out five times.
    //
    // THE ONLY SURFACE HERE THAT REPEATS, and the four below explain why: they
    // all take an exclusive keyboard grab and the bar never does. Each Bar gets
    // its own screen through `modelData` and reads its own widget set from it.
    Variants {
        model: Screens.barScreens

        ThemeSurface {
            file: "bar/Bar.qml"
        }
    }

    // The notification panel, on the same screen as the bar. NOT the daemon --
    // that is the singleton armed above, which owns the bus name whether or not
    // this surface, or a theme's replacement for it, ever draws a card. dunst
    // must still not be running; that is the singleton's business now rather
    // than this line's.
    Variants {
        model: Screens.mainOnly

        ThemeSurface {
            file: "notifications/Notifications.qml"
        }
    }

    // The launcher, on the same screen as the bar. One monitor only, like the
    // power menu: it takes an exclusive keyboard grab, and two of them would
    // be two surfaces fighting over the keyboard.
    Variants {
        model: Screens.grabScreens

        ThemeSurface {
            file: "launcher/Launcher.qml"
        }
    }

    // The power menu, on the same screen as the bar. Filtered to one monitor
    // deliberately: it is a single modal thing and a copy per screen would
    // mean two of them opening at once, both grabbing focus.
    Variants {
        model: Screens.grabScreens

        ThemeSurface {
            file: "powermenu/PowerMenu.qml"
        }
    }

    // The wallpaper carousel, on the same screen as the bar. One monitor for
    // the same reason as the power menu: it takes an exclusive keyboard grab,
    // and two of them would be two sheets fighting over the keyboard.
    Variants {
        model: Screens.grabScreens

        ThemeSurface {
            file: "wallpaper/WallpaperCarousel.qml"
        }
    }

    // The keybind cheatsheet, on the same screen as the bar. One monitor for
    // the same reason as the power menu and the launcher: it takes an
    // exclusive keyboard grab, and two of them would be two surfaces fighting
    // over the keyboard.
    Variants {
        model: Screens.grabScreens

        ThemeSurface {
            file: "cheatsheet/Cheatsheet.qml"
        }
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

        ThemeSurface {
            file: "ScreenCorners.qml"
        }
    }
}
