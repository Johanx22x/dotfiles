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
modules/notifications/NotificationDaemon.qml  the host's half: the daemon
                                              itself -- the bus name, the
                                              stack tags, what is claimed
modules/notifications/NotificationState.qml   the host's half again: the
                                              daemon's store, the mute, the
                                              IpcHandler
themes/genesis/notifications/                 this theme's half: the panel the
                                              cards are stacked in, the history
                                              panel, the DND pill
```

The card is not in that list any more: it is a shared component now, drawn at
`components/NotificationCard.qml` in here and specified by the facade of the
same name under the host's `components/`. The notification window still builds
it -- what moved is where it is drawn, not who stacks it.

The dependency only ever runs one way. A theme file imports `qs.modules.<name>`
to reach the state it draws; **no file under `modules/` imports anything under
`themes/`**, and **nothing in the tree instantiates a theme's types** -- not
even `shell.qml`, which loads its surfaces out of whatever directory
`Config.theme` points at. That asymmetry is the seam -- if it ever stops being
true, the split has stopped meaning anything.

`shell.qml` does *name* this directory, in nine import lines, and that is not
the same thing. The imports exist so Quickshell watches these files and an edit
in here reloads the shell; they build nothing. The header there says which half
is which.

A theme reaches its own parts by **relative path** and never by its own name:
`import "../island"`, not `import qs.themes.genesis.island`. It is a rule, and
now only a rule -- the module form does resolve again, and it was tried -- but
the relative form is what makes this directory copyable:

```sh
cd quickshell/.config/quickshell/themes
cp -r genesis tokyo             # a whole second theme, nothing to rename inside it
$EDITOR tokyo/manifest.json     # "name" and "title"
cd -; ./install.sh apply symlinks   # link the new directory into ~/.config
```

Then set `theme` to `tokyo` -- in the settings window, or in `config.json` --
and the shell draws the copy. Spell your own name in here and the copy draws the
original's island instead.

**The last command is not optional and it is the one that is easy to miss**, so
it has a section of its own further down: [Where the shell looks for
it](#where-the-shell-looks-for-it).

## WHAT IS DELIBERATELY NOT IN HERE

**`components/` USED TO BE THE FIRST ENTRY HERE**, on the argument that buttons,
rows, scrollbars, the popout and the focus grab are shared and stay shared, and
that giving a theme its own copy was a decision for its own change rather than a
side effect of the move. That change came: twenty of them are drawn in here now,
each one facing a host facade of the same name, and `components/README.md` in
this directory is where the split is argued and where the ones that did NOT
cross are named. The half that never moved is still the half that argument was
about -- the objects with nothing to draw, the windows, the grabs.

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
nothing on the host side imports is a module Quickshell's startup scan reaches
only by accident -- so `modules/Themes.qml` names it in `keptInScope` to keep
`qs.modules.bar` importable from in here whatever any theme happens to import.
The next host module that only a theme reaches for belongs on that line too.

## HOW A THEME IS LOADED

`manifest.json` is what makes a directory a theme. It is five keys today:

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
`title` is what the picker shows, in the Theme section of the appearance page.

`Config.theme` names the directory. `modules/Themes.qml` turns that name into
URLs and reads the manifest; `modules/ThemeSurface.qml` loads one file out of
the current theme; `shell.qml` builds seven of those and hands none of them a
theme name. The name can change while the shell is up: the surfaces are rebuilt
and the old ones destroyed, with no config reload -- true of a theme on
`shell.qml`'s import list and of one that is not. A theme whose manifest cannot
be read, or which claims an interface this shell does not speak, falls back to
the one that ships with it -- an empty desktop has no way back to the setting
that emptied it.

### Where the shell looks for it

`~/.config/quickshell/themes`, and **never this checkout**. Both compositors
start the shell with `qs -d --no-duplicate` and no `-p`, so
`Quickshell.shellDir` is `$XDG_CONFIG_HOME/quickshell`, which is stow's target;
Quickshell 0.3.1 does not resolve that path through the links inside it, and a
`shell.qml` reached through a symlink reports the link's own directory
(measured in a scratch home, not assumed).

`install.sh` stows `--no-folding`, which is deliberate and argued in
`lib/units/40-symlinks.sh`: `~/.config/quickshell/themes/` is a **real directory
holding one symlink per file**, rather than one link standing for the whole
tree. That is what keeps an application writing into `~/.config` from dropping a
file inside the repository -- and it is also why a directory that exists only in
the checkout does not exist for the shell. Nothing links to it, and nothing
will until `stow` runs again.

The failure that follows has no symptom at all. Reproduced in a scratch home,
with a second theme copied into the repository and not stowed:

* the theme picker lists **one** theme -- the catalogue `modules/Themes.qml`
  builds is `["genesis"]`, so there is not even a greyed-out row to carry a
  reason;
* setting `theme` to it by hand draws genesis and logs `Themes:
  /home/.../.config/quickshell/themes/probe/manifest.json cannot be read,
  falling back to genesis` -- the path, which is the only hint anywhere that
  the shell read somewhere else;
* `./install.sh check` says `missing  symlinks  Symlinks -- 30 not linked under
  ~/.config/quickshell/themes/probe`, which is the count of that directory and
  the directory itself;
* `./install.sh apply symlinks` links it, and the catalogue is
  `["genesis","probe"]`.

The third of those is the only one that names the problem, and that is not an
oversight in the other two: the installer is the only part of this that can see
the checkout and `$HOME` at once. The shell cannot. `Quickshell.shellPath` is
the whole of its map, nothing in Quickshell 0.3.1 resolves a symlink to find
the other end of one, and a picker that went looking would be spawning a process
on every start to describe a directory it will never load from. The header of
`modules/Themes.qml` is where that trade is written out.

**A theme copied into `~/.config/quickshell/themes/` instead** is the mirror
image: real files on the target side, so the shell lists it at once and `check`
says nothing about it, because no package claims that directory. It is also not
in the repository -- the next machine will not have it, and neither will this
one after a re-clone.

## THE HONEST LIMIT

**The manifest does not yet say what a theme provides.** The host builds the
same seven surfaces whatever the theme is, from a list of paths written in
`shell.qml`, so a theme without a cheatsheet has no way to say so and a theme
with a surface of its own has no way to offer one. `modules/Surfaces.qml` will
already take an extra member through `register()`; nothing hands it one.

**A theme is only watched if `shell.qml` names it.** Quickshell watches the
files it reached by following imports out of `shell.qml`, so the nine import
lines there are what make an edit in here reload the shell. A theme that is
linked into `~/.config/quickshell/themes` but not on that list still *runs* --
it is loaded by URL and `Config.theme` is all it needs -- but nothing watches
it, so editing it needs `qs kill && qs -d --no-duplicate` until its directories
are on that list. Add them when a theme joins the repository. The long note at
the top of `modules/Themes.qml` has the whole account.

A theme that is not linked there at all does not run and is not offered, which
is a different thing entirely and is [above](#where-the-shell-looks-for-it).

The imports do **not** make a broken theme everyone's problem, which is what it
looks like they would and is the reason it was measured instead of reasoned
about. QML compiles a type when something uses it, so importing a directory
lists its files without parsing them: a theme file that will not parse costs
nothing at all while another theme is drawing, and costs the widget that uses
it plus a warning while this one is. `tests/shell-load.sh` loads the whole tree
in CI, and it is worth knowing where its floor is -- it asserts on
`ReferenceError`, `TypeError`, `Unable to assign` and `is not a type`, none of
which a bare syntax error in a theme file produces.

**Fourteen of the shared components still have no theme half.** This paragraph
read "there is no facade in front of `components/`" and that is over: twenty of
them are drawn in here, each facing a facade, listed and argued in
`components/README.md` next door. What is left of the limit is the remainder --
a theme draws those fourteen exactly as the shell wrote them and cannot replace
them. Only `MenuView.qml` says in its own header why it did not cross; the
other thirteen never raised the question, and that silence is not a decision in
either direction.

**One thing used to sit on the wrong side, and this is what is left of the
entry that said so.** `notifications/Notifications.qml` owned
`org.freedesktop.Notifications` -- the bus name, the daemon, the whole reason
dunst is gone -- as well as being the window the cards are stacked in. Being
the daemon is a host job by every reading of the rule above, and this paragraph
said it was waiting because splitting it means moving a `NotificationServer`
and rewiring what claims a notification, which is logic and not a move.

**The second theme is what made the wait cost more than the move.** A theme
that had to carry the daemon would have had to carry the whole of it -- the bus
name, both stack-tag hints, the claim that makes a notification exist at all,
the do-not-disturb drop -- or ship a desktop with no notifications whatsoever
for as long as it was selected. That is not a thing to ask of a theme, and it
is the same argument that moved the card's spec out a change earlier. So the
daemon is `modules/notifications/NotificationDaemon.qml` now, armed from
`shell.qml` beside the services, and it hands a theme two properties: `tracked`
to put in a Repeater and `count` to size a window from. What this file builds
is the panel around them.

## WHY "genesis"

Because it is the first one, and because naming it after what it looks like
would have been a promise this repository cannot keep -- the colours are not the
theme's. `Theme.qml` reads them live out of `colors.json`, which matugen
rewrites on every wallpaper change, so genesis is already a different colour
today than it was yesterday and the same theme throughout. What a theme owns is
shape, layout and motion; the palette stays in the host.

**And the palette is no longer the wallpaper's alone**, which is the other
reason a colour name would have been a bad one. Only the accents follow the
image now; the surfaces, the text, the outlines and the two alert colours come
from the scheme `desktop-scheme` picks, through the same `colors.json`. So
genesis under Gruvbox and genesis under Tokyo Night are further apart than two
wallpapers ever made it, and both are still genesis.
