# genesis

The look this desktop has always had, under a name.

Nothing in here is new. Every file was moved out of `modules/` unchanged, and
the shell draws exactly what it drew before -- that is the whole point of the
move: a rename that changes no pixel is the only kind that can be checked
against the thing it replaced.

## THE SEAM, and it is one sentence

**The host composes and decides what exists; the theme draws it.**

The host is everything above `themes/`: `Config`, `Theme`, `Screens`,
`Compositor`, `Surfaces`, `Icons`, `ColorUtils`, the compositor backends, the
services (`Volume`, `Microphone`, `Brightness`, `NightLight`, `Track`), every
`*State` singleton, every `IpcHandler`, and all the *content* -- which rows a
settings page has, which widgets a bar carries, what the launcher offers when
you type `>`. It answers "what is there", "what is it doing" and "what happened".

A theme answers one question: what that looks like on screen.

## WHAT THAT LOOKS LIKE IN THE TREE

Most of the shell's parts are now in two halves that share a name, and reading
the two import lines in `bar/NotificationButton.qml` is the fastest way to see
it:

```
modules/notifications/NotificationState.qml   the host's half: the daemon's
                                              store, the mute, the IpcHandler
themes/genesis/notifications/                 this theme's half: the daemon
                                              window, the card, the history
                                              panel, the DND pill
```

The dependency only ever runs one way. A theme file imports `qs.modules.<name>`
to reach the state it draws; **no file under `modules/` imports anything under
`themes/`**, and **nothing in the tree names a theme at all** -- not even
`shell.qml`, which loads its surfaces out of whatever directory `Config.theme`
points at. That asymmetry is the seam -- if it ever stops being true, the split
has stopped meaning anything.

A theme reaches its own parts by **relative path** and never by its own name:
`import "../island"`, not `import qs.themes.genesis.island`. That is partly a
rule and mostly a fact -- a theme is loaded out of its directory rather than
imported as a module, so the module form would not resolve from in here -- and
it is what makes this directory copyable. `cp -r genesis tokyo`, edit
`manifest.json`, set `theme` to `tokyo`, and the shell draws the copy.

## WHAT IS DELIBERATELY NOT IN HERE

**`components/`.** Buttons, rows, scrollbars, the popout, the focus grab. They
are shared and they stay shared; giving a theme its own copy is a decision for
its own change, not a side effect of this one.

**`modules/settings/`, pages included.** A settings page is content: it is a
list of what can be changed, and every row of it is wired to a property
somewhere else. Its chrome is entangled with that list today and separating the
two is not a move, it is a rewrite.

**The singletons that measure or decide rather than draw.** `Spectrum` spawns
`cava` and publishes eighty numbers; `SystemStats` reads the machine;
`BatteryAlerts` holds the "already warned about this one" state that exists
precisely so two bars cannot warn twice; `Commands` is the list of what the
launcher can do. None of them puts a pixel anywhere, and each stayed in
`modules/` next to the state it belongs with.

`BatteryAlerts` is the one of those the host itself never touches, and a module
nothing on the host side imports is a module Quickshell's startup scan never
reaches -- so `modules/Themes.qml` names it in `keptInScope` to keep
`qs.modules.bar` importable from in here. The next host module that only a
theme reaches for belongs on that line too.

## HOW A THEME IS LOADED

`manifest.json` is what makes a directory a theme. It is three keys today:

```json
{
    "name": "genesis",
    "title": "Genesis",
    "interface": 1
}
```

`interface` is a promise about the seam -- what a theme is handed, what it is
expected to draw, where its files are looked for -- and the host refuses a
number it does not speak rather than half-drawing a theme written against an
older shape. `name` is a label; the directory is what the shell loads from.
`title` is what a picker would show, and nothing shows it yet.

`Config.theme` names the directory. `modules/Themes.qml` turns that name into
URLs and reads the manifest; `modules/ThemeSurface.qml` loads one file out of
the current theme; `shell.qml` builds seven of those and names no theme. The
name can change while the shell is up: the surfaces are rebuilt and the old
ones destroyed, with no config reload. A theme whose manifest cannot be read,
or which claims an interface this shell does not speak, falls back to the one
that ships with it -- an empty desktop has no way back to the setting that
emptied it.

## THE HONEST LIMIT

**The manifest does not yet say what a theme provides.** The host builds the
same seven surfaces whatever the theme is, from a list of paths written in
`shell.qml`, so a theme without a cheatsheet has no way to say so and a theme
with a surface of its own has no way to offer one. `modules/Surfaces.qml` will
already take an extra member through `register()`; nothing hands it one.

**Editing a theme no longer hot-reloads the shell.** Quickshell watches the
files it reached by following imports out of `shell.qml`, and nothing imports a
theme any more -- so a change under here needs
`qs kill && qs -d --no-duplicate` where a change under `modules/` still lands
by itself. It was measured three ways and it is the price of loading by name,
not of the primitive that does the loading; the long note at the top of
`modules/Themes.qml` has the whole account.

**There is no facade in front of `components/`.** A theme draws with the
shell's buttons, rows, scrollbars and popout, and cannot replace them.

**One thing sits on the wrong side and is left there.**
`notifications/Notifications.qml` owns `org.freedesktop.Notifications` -- the
bus name, the daemon, the whole reason dunst is gone -- as well as drawing the
cards. Being the daemon is a host job by every reading of the rule above.
Splitting it means moving a `NotificationServer` and rewiring what claims a
notification, which is logic and not a move, so it waits.

## WHY "genesis"

Because it is the first one, and because naming it after what it looks like
would have been a promise this repository cannot keep -- the colours are not the
theme's. `Theme.qml` reads them live out of `colors.json`, which matugen
rewrites on every wallpaper change, so genesis is already a different colour
today than it was yesterday and the same theme throughout. What a theme owns is
shape, layout and motion; the palette belongs to the wallpaper and stays in the
host.
