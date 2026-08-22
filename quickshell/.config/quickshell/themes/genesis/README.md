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
`themes/`**, and the only place in the entire tree that names a theme is
`shell.qml`, where the surfaces are instantiated. That asymmetry is the seam --
if it ever stops being true, the split has stopped meaning anything.

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

## THE HONEST LIMIT

**There is no theme mechanism yet.** This is a directory with a rule about what
may go in it, not a plug-in system: nothing loads a theme by name, there is no
manifest, no `Loader`, no facade in front of `components/`. `shell.qml` imports
`qs.themes.genesis.*` the same way it used to import `qs.modules.*`, so a second
theme today would mean editing `shell.qml`, which is not what "swappable" means.

That is on purpose. The mechanism is worth building against a boundary that has
already been drawn and checked; drawing the boundary and building the machinery
in one go would have meant neither could be verified without the other.

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
