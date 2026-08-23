# theme-probe

The second implementation of the theme interface. It exists so that the claims
about the seam are checkable, and it is deliberately ugly so that nobody ever
mistakes it for a desktop.

Every component here is a flat rectangle in a colour nobody would choose --
magenta rows, cyan chips, a lime switch, a red one when it is off. No glass, no
rounding, no animation: `theme.json` sets `cardRadius`, `animDuration` and
`recolorDuration` to zero, and the corners are square.

## WHY IT EXISTS

`genesis` was the only theme, and one theme cannot answer any of these:

- **That the loader really swaps.** `themes/genesis/README.md` says the name
  can change while the shell is up, the surfaces are rebuilt and there is no
  config reload. That was measured once, by hand, before most of the surfaces
  existed. `tests/shell-load.sh`'s last phase now measures it every run, and
  the seven `console.log` lines below are what make it visible from outside the
  process. `modules/ThemeSurface.qml`'s header records the bug this would have
  caught: a `BoundComponent` cannot have its source set after creation, so the
  theme changed and *the old one stayed on screen*.
- **That nothing in the host secretly depends on genesis.** A file-presence
  check proves a theme is complete; only a second theme proves the host is
  neutral. `tests/shell-load.sh` starts the shell once per theme, and this one
  says which of its surfaces drew -- so a run that meant to be the probe and
  quietly fell back to genesis is a run with nothing in it.
- **That an empty implementation is legitimate.** `components/CornerWedge.qml`
  here is the one the rule was written about, and it now has a caller.

## WHERE IT LIVES, AND WHY NOT IN `themes/`

`modules/Themes.qml` can only load a theme out of
`Quickshell.shellPath("themes/<name>/")`, so a theme has to be under `themes/`
to run at all. This one is not, because anything under `themes/` is a theme a
picker may offer and this is not something anybody should be able to choose.

`tests/shell-load.sh` reconciles the two: it copies the whole shell tree into a
sandbox, drops this directory in as `themes/theme-probe`, runs against the copy
and throws it away. Nothing under the repository is opened for writing, and the
real `themes/` never has more than the real themes in it.

The directory is named `theme-probe` rather than `probe` so that the name it
takes inside `themes/` is the same string as the directory it came from, and
`manifest.json`'s `name` matches both -- `modules/Themes.qml` warns about a
theme carrying a manifest calling itself something else, and that warning
should keep meaning something.

## WHAT IT COVERS

- **All 36 files the host loads by path**: the seven surfaces `shell.qml`
  builds a `ThemeSurface` for, and the twenty-nine components with a facade
  -- five of which are the settings window's own chrome, whose facades live
  under `modules/settings/` rather than under `components/`.
  `tests/theme-interface.py` derives that list from the host's own call sites
  and fails naming whatever is missing, so this list cannot silently fall
  behind the interface.
- **An empty implementation with a caller.** `components/CornerWedge.qml` is
  `Item { required property CornerWedge row }` and nothing else, and
  `ScreenCorners.qml` still builds the four `ScreenCorner` windows so that the
  facade is really loaded. Without those four windows the empty file would be a
  file nothing reaches, which is the state the whole fixture exists to get out
  of.
- **`keptInScope`.** `bar/Bar.qml` reads `BatteryAlerts` through
  `import qs.modules.bar`. That module's only importer is a theme, and this
  theme is deliberately not on `shell.qml`'s import list -- so if
  `modules/Themes.qml`'s `keptInScope` line were deleted, genesis would still
  come up clean and this theme would die with "module qs.modules.bar is not
  installed". The comment there says the accident is the whole problem; this is
  the caller that makes it a check.
- **A swap.** Seven `Component.onCompleted: console.log("theme-probe drew ...")`
  lines, one per surface. They are the only reason a theme swap is observable
  from outside the process, and they are why this fixture prints anything at
  all. A real theme would not.
- **A pinned scheme, and it is the only one in the repository.**
  `manifest.json` here says `"palette": { "source": "pinned", "scheme":
  "gruvbox-dark" }`. `bin/.local/bin/desktop-scheme` keeps two keys instead of
  one -- `scheme` is what renders, `chosen` is what the person last picked --
  and its header says why: "A theme can PIN a scheme ... and leaving that theme
  has to put back whatever was there before". This fixture is the caller that
  earned the wiring: `Theme.qml` reads the declaration off the theme being
  drawn and `Config.qml`'s `pinScheme`/`unpinScheme` run the script, so
  entering this theme puts the whole desktop in Gruvbox and leaving it hands
  the person their own scheme back.

  `tests/scheme-pinning.sh` reads the scheme name out of this file, starts a
  real shell in a headless compositor, enters and leaves this theme by writing
  `theme` into the config.json that shell is watching, and asserts on the
  colour that reaches the rendered `colors.json` at each step -- not on the
  state file, which would pass while nothing at all happened. Change the name
  here and the check follows it; remove the pin and the check fails by name
  rather than passing with nothing to measure.

  **`palette.scheme` is the key, and `Theme.qml` is where that is stated.** Its
  palette section is the contract -- a scheme NAME, one of `desktop-scheme
  list`, never a path and never a colour -- and this file and the check are both
  readers of it. The other reading of "pinned", a theme carrying its own palette
  file that only the shell reads, is a design that was declined rather than
  deferred: it would leave a themed shell over a terminal wearing something
  else, and Theme.qml says so at the place the switch for it used to be.

- **The rules.** The seven in `themes/genesis/components/README.md`, kept where
  keeping them costs a line: the typed `row`, the hoists out of anything that
  would be a delegate, `implicitHeight` and never a width that could loop, no
  mirrored `label`/`title`/`glyph`, no write to `row`, `Theme` and `Icons` from
  `import qs` and nothing else, `opacity: root.enabled ? 1 : 0.4` against this
  item's own `enabled`, and the behavioural promises that only a theme file can
  keep -- the whole row is the target on `ToggleRow`, nothing is clickable on
  `InfoRow`, no `MouseArea` at all in `ScrollBar`, and a click on a
  notification card means `dismiss()`.

## WHAT IT DOES NOT COVER, AND SHOULD NOT BE READ AS COVERING

- **Loading this theme SPAWNS A PROCESS, which no other theme here does.** The
  pin is wired now, so a shell that draws this fixture runs `desktop-scheme pin
  gruvbox-dark` -- by name, through `$PATH`, which on the desktop this
  repository is for resolves to the real script and through it to a real matugen
  render over fourteen files. Anything that loads this fixture therefore has to
  put a stub on `$PATH` first: `tests/shell-load.sh` does, and says why at the
  line that does it, and `tests/scheme-pinning.sh` points `$PATH` at its own
  sandboxed copy of `bin/` instead. Measured on a cold start against a recording
  stub: exactly one call, `pin gruvbox-dark`, and no warning in the log.

  **The warning this theme used to produce is gone**, and that is the change
  rather than a regression: `Theme: theme-probe asks for a palette source called
  "pinned", which this shell does not know` was printed twice per
  `tests/shell-load.sh` run while the shell did not know the word. It does now.

- **It is not linted.** `tests/qml-lint.sh` and `tests/qml-rules.sh` both scope
  themselves to `quickshell/.config/quickshell`, so no linter reads these files
  and the typed `row` declarations buy nothing here that they buy in genesis.
  What reads them is `tests/shell-load.sh`, which RUNS them -- and only the
  ones a startup reaches.
- **Most of the components are never built by a headless startup.** The
  settings window's pages are behind `Loader { active: everOpened }`, so a run
  that opens nothing builds `SearchField` and `ScrollBar` (the settings window
  holds those eagerly) and the seven surfaces, and leaves most of
  `components/` unread on disk. A syntax error in `ToggleRow.qml` here is
  caught by nothing at all. That is the same limit `tests/shell-load.sh`'s
  header describes for the shell's own tree, and the answer to it is the same:
  a linter that reads every file whether or not anything runs it.
- **It runs no notification daemon.** `notifications/Notifications.qml` here
  deliberately ships no `NotificationServer`. See the header there: a second
  process claiming `org.freedesktop.Notifications` is a developer's own session
  losing its notifications. So this fixture does not prove that a theme *can*
  host the daemon.
- **It draws no bar widgets, no island and no popout content.** The bar is one
  strip with one line of text on it. `Config.barWidgetsByMonitor`, the widget
  set, the island and everything a popout puts inside itself are exercised by
  genesis and by nothing here.
- **It is not watched.** `shell.qml` carries one static import per theme
  directory purely so Quickshell's startup scan registers a file watch, and
  this fixture is outside that tree and off that list. Editing a file in here
  reloads nothing. That costs nothing at all, because this theme is only ever
  loaded out of a sandbox copy that is created and deleted inside one run of
  one check -- there is no running shell for a watch to reload. Adding it to
  that import list would be the wrong fix twice over: it would make `themes/`
  the place a fixture has to live, and it would put a deliberately ugly theme
  one setting away from a real desktop.

## WHAT KEEPS IT IN STEP, HONESTLY

Thirty-nine files that have to track an interface is a real cost, and it is
worth being exact about which parts of it are automatic and which are not.

**Automatic: that every file the host loads by path exists here.**
`tests/theme-interface.py` derives the list of 36 from `shell.qml` and from
every `Themes.surface("...")` call site, so a thirtieth component split
tomorrow makes this fixture incomplete tomorrow, by name, in CI. There is no
hand-written list to fall behind.

**Automatic: that what is here loads, and that the host is neutral.**
`tests/shell-load.sh` cold-starts the shell on this theme and fails on the same
six log strings it uses for the tree.

**Not automatic, and nobody should pretend otherwise: that these files still
draw the RIGHT thing.** A facade that renames `checked` to `on`, or moves a
value from `row` to a function, leaves this fixture loading perfectly and
drawing a row that reads a property nobody sets any more. Nothing here would
notice. `tests/qml-lint.sh` catches exactly that in genesis, through the typed
`row`, and it does not read this directory. So the answer today is that
somebody remembers -- that whoever splits or changes a component updates two
implementations rather than one, and finds out about the second one only when
they read the failure from `tests/theme-interface.py` or this paragraph.

That is the honest state of it. The cheapest thing that would fix it is
teaching `tests/qml-lint.sh` to lint a theme wherever it lives rather than only
under `quickshell/`; it was left out of the change that added this fixture
because that script builds a synthetic module tree of its own and extending it
is a change to the linter rather than to the fixture.
