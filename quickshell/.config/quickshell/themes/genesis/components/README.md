# components, themed

The shared widgets, split in two. This directory is the half that draws.

`../README.md` says a theme owns shape, layout and motion, and ends by naming
what was deliberately left out of the split:

> **There is no facade in front of `components/`.** A theme draws with the
> shell's buttons, rows, scrollbars and popout, and cannot replace them.

That sentence is now half true. `ToggleRow` and `InfoRow` are split; the other
twenty-odd are not. This file is how to split the rest, and why each part of
the shape is the shape it is. Everything below was measured on this machine
against Qt 6.11.2 and Quickshell 0.3.1, under a headless labwc, with the real
settings window open. Where a number is quoted, it was read off a run.

## THE SEAM, IN ONE SENTENCE

**The call site talks to the facade; the facade hands itself to the theme; the
theme reads it and draws.**

```
modules/settings/pages/NetworkPage.qml      the call site. Unchanged, and it
  ToggleRow { label: "Wi-Fi"; ... }         must stay unchanged: 10,100 lines
                                            of pages depend on today's API.

components/ToggleRow.qml                    the facade. Declares the API, owns
  Item { property string label; ... }       the width rule and the height
                                            floor, loads the theme's file.

themes/genesis/components/ToggleRow.qml     the implementation. Declares
  Rectangle { required property           `row`, reads it, draws.
      ToggleRow row; ... }
```

## THE MECHANISM, WHICH IS SIXTEEN LINES AND IS COPIED, NOT SHARED

Every facade ends with this and nothing else:

```qml
Loader {
    id: drawing

    anchors.fill: parent

    readonly property string drawingUrl: Themes.surface("components/ToggleRow.qml")

    function build(): void {
        if (String(drawing.source) === drawing.drawingUrl)
            return;

        drawing.setSource(drawing.drawingUrl, {
            row: root
        });
    }

    Component.onCompleted: drawing.build()
    onDrawingUrlChanged: drawing.build()
}
```

**`Themes.surface()` and never `Config.theme`.** `modules/Themes.qml` is the
only thing that turns a name into a path, and it is also what falls back to the
shipped theme when the configured one has no readable manifest. A facade that
built its own URL out of `Config.theme` would draw nothing for a theme the rest
of the shell had already given up on. This is the first component under
`components/` to `import qs.modules`; there is no cycle, nothing under
`modules/` imports `qs.components`.

**`setSource` with an initial property, not `onLoaded: item.row = root`.** Both
work. The difference is that an assignment in `onLoaded` happens after the
theme's object is built, so every binding in the theme file is evaluated once
against a `row` that is null and then again against the real one. As an initial
property it is there before the first evaluation. `modules/ThemeSurface.qml`
hands a surface its `modelData` the same way and its header has the longer
argument.

**The guard in `build()` is not defensive programming.** `setSource` is a call
and not a binding, so the Loader has to notice the URL changing for itself --
and the first read of `drawingUrl` emits its own change signal, so
`Component.onCompleted` plus `onDrawingUrlChanged` builds twice and throws the
first one away. Comparing against what is already loaded makes the pair
idempotent. At 28 rows in an open settings window that is 28 objects not built.

**It is copied into each facade rather than shared through a base type.** A
`ThemedComponent` base under `components/` would remove sixteen duplicated
lines and would cost the thing the next section is about: a facade has to BE
the type its call sites name, with that type's properties on it, and a base
class that owned the Loader would still leave every property declaration in the
subclass. Sixteen lines against a second layer of indirection in the file
somebody opens to find out what `ToggleRow` is.

## THE RULES A THEME IMPLEMENTATION LIVES BY

Seven, and each one is here because breaking it fails quietly.

### 1. Declare `row`, `required`, and TYPED

```qml
required property ToggleRow row
```

not `property var row`. The type is the only checking left in the file, and the
difference was measured both ways:

| `row` declared as | seven deliberate misspellings of `checked`/`glyph` |
| --- | --- |
| `property var row` | `tests/qml-lint.sh`: **307 warnings, none new. Green.** |
| `required property ToggleRow row` | **five `[missing-property]` findings, named by line** |

Before the split, `root.checked` was a read against a real `bool` on a real
type. `var` throws that away for every read in the file. The typed form gives
it back, and it costs one import.

`required` is what makes `row` a contract: the file cannot be built without
one, so there is no state in which the bindings read from null.

**`ToggleRow` in that declaration is `components/ToggleRow.qml`, not this
file**, even though this file has the same name and a QML document implicitly
imports its own directory. The explicit `import qs.components` wins. Do not
take that on trust when you split the next one -- it was checked in both places
and both agree: qmllint resolves it to the facade, and the shell builds 28 of
these rows against it under a headless compositor with no "not a type" and no
refused assignment. If you split a component whose name collides with a QtQuick
type, check it again before writing the file.

### 2. Report `implicitHeight`, and never `implicitWidth`

Height is the only measurement that crosses the seam upwards, because a row
that wraps text is a height only the theme can compute. Declare it on your
root; the facade reads it off the Loader and floors it.

Width goes the other way and only the other way. `components/ToggleRow.qml`
says why -- a Column sizes itself to its widest child, so a child sizing itself
to the Column is a loop -- and the facade already holds the whole rule:
`width: parent ? parent.width : implicitWidth`. Your root is `anchors.fill`ed
by the Loader and is handed that width. Do not bind anything upward.

**Never derive `implicitHeight` from your own `height`.** Your height comes
from the facade, whose height comes from your `implicitHeight`. That is a loop
and QML will say so, at runtime, once per row.

### 3. Do not re-declare `label`, `title` or `glyph`

This one is the coordinator's finding and it is the sharpest trap in the file,
because breaking it produces a settings window that works perfectly and a
search that is wrong.

`modules/settings/SettingsSearch.qml:70-98` builds the search index by walking
the live object tree. It duck-types -- a row is anything with a non-empty
string `label` (`:82`), a section is anything with a non-empty string `title`
and no `label` (`:79`), and the glyph is `child.glyph ?? ""` (`:90`) -- and the
recursion at `:96` is unconditional. **So it walks into the facade's Loader and
into your theme item.** Two things follow:

- **`label`, `title` and `glyph` stay on the facade.** A row whose label lived
  only on the theme item would be unfindable, with no warning at load.
- **Your root must not mirror them.** Read `row.label`; do not copy it into a
  `property string label` of your own for convenience.

Measured, on the real window, with the real search:

| theme's `ToggleRow` root | search "Wi-Fi" | "Bluetooth" | "Warm the screen" |
| --- | --- | --- | --- |
| as shipped | 1 hit | 1 exact, 3 results | 1 hit |
| plus `property string label: root.row.label` | **2 hits** | **2 exact, 6 results** | **2 hits** |

Every row twice, in a window that otherwise looks correct.

### 4. Read `row`; never write to it

`components/ToggleRow.qml` has carried the rule since before there were themes:
a row takes a value and emits a request to change it, so that `checked` follows
the config in one direction and the click asks the config to move in the other.
A theme implementation is inside that rule, not beside it:

- `row.checked` -- read it.
- `row.toggled(!row.checked)` -- call it.
- `row.checked = true` -- **never.** It is the same bug as a row writing to
  `Config`: a second writer to a value the same object also displays.
- `Config.setTweak(...)` from in here -- **never.** A theme does not know what
  a row is wired to. It does not know there is a `Config`.

### 5. `Theme` and `Icons` come from `import qs`, and only those

Design tokens are the host's and they are the same for every theme --
`../README.md` is explicit that the palette belongs to the wallpaper and stays
in the host, which is why this theme is not named after a colour. So a theme
implementation imports `qs` and reads `Theme.groupPadding`, `Theme.primary`,
`Icons.wifi` directly. Thirty-one of the thirty-two files under `themes/genesis`
already do.

The alternative -- everything arrives through `row` -- was considered and is
worse in a specific way: the facade would have to re-export a dozen tokens per
component, twenty-one times, and each of those is a place for the public API to
drift into carrying design.

So: **`row` carries what the call site said. `Theme` and `Icons` carry what the
host looks like. Nothing else crosses.** If you find yourself wanting a third
channel, that is a sign the thing you want is host state, and host state is
reached the way every other theme file reaches it -- `import qs.modules.<name>`
-- not through `row`.

### 6. `enabled` arrives by itself; the dim does not

Qt propagates `enabled` down the item tree as an effective value, through the
Loader and into your root. Six `ToggleRow` call sites set it and nothing in the
facade forwards it. So write the dim against your own root:

```qml
opacity: root.enabled ? 1 : 0.4
```

and not against `row.enabled`, which gives the same answer today and a wrong
one the moment anything between the page and here is disabled.

**But `MouseArea.enabled` is not the item's `enabled`.** This was measured and
it contradicts the obvious reading:

```
outer disabled:  outer=false  mid=false  rect=false  ma=true
```

`QQuickMouseArea` shadows the property with a flag of its own, so a MouseArea
under a disabled ancestor still reports `enabled: true`. It is nevertheless
dead -- event delivery stops at the disabled ancestor, and a click sent at that
point does not arrive (measured: the click counter does not move) -- but
**anything you bind to `mouse.enabled` will read the wrong value.** Keep
`enabled: root.enabled` on the MouseArea, which is what the pre-split file had
and what this one still has.

### 7. Keep the promise the facade's header makes

A facade can require properties. It cannot require behaviour, and every one of
these components has some behaviour in its header that only the theme can now
keep:

- `ToggleRow` -- **the whole row is the target, not the switch.** A theme that
  put the MouseArea on the 42-pixel track instead of the 320-pixel row would
  pass every check in `tests/`.
- `InfoRow` -- **there is nothing to click, and it must not look as though
  there is.** No `MouseArea`, no `HoverHandler`, no `TapHandler`, no
  `cursorShape`, and no colour that changes because a pointer is over it. This
  is the one component whose entire contract is an ABSENCE, and a facade has no
  way to require an absence: there is no signal to leave unconnected and no
  property to leave unread. `components/ActionRow.qml` exists precisely so that
  a reading with something to press is a different type; do not turn this one
  into that one.

When you split the next component, read its header, find the sentence that is a
promise about behaviour, and copy it into the theme file. That is not
documentation for its own sake -- it is the only place the promise can now live.

## HOW TO SPLIT THE NEXT ONE

1. **Find every call site and every property each one sets.** Not by reading;
   by extracting, because the one call site that sets something unexpected is
   the one that breaks. `ToggleRow` has 30 sites and exactly one of them sets
   `width`; `InfoRow` has 13 and three set `visible`. Both were found this way
   and neither was guessed:

   ```
   grep -rn "ChoiceRow {" --include='*.qml' quickshell/.config/quickshell/modules
   ```

   then read the block under each hit and list the top-level bindings.

2. **Decide the facade's base class by that list, not by the current root.**
   The rule that decided `ToggleRow`: *a property of the current root type is
   part of the public API if and only if a call site sets it.* `ToggleRow` was
   a `Rectangle`; no site set `color`, `radius` or `border`; all three are
   drawing; the facade is an `Item`. Apply the same test and expect a different
   answer sometimes -- `components/SectionNote.qml` has a `Text` root, and if
   pages set `text` or `wrapMode` on it then those are API and the facade
   cannot be a bare `Item`.

3. **Keep every property a call site sets, on the facade, spelled as it is
   today.** Including `signal` declarations. The pages do not change by one
   character; `git diff --stat modules/settings/` is the check.

4. **Move the drawing down, unchanged.** Rename `root.x` to `root.row.x` for
   the properties that moved to the facade, and change nothing else. A split
   that changes a pixel cannot be checked against the thing it replaced.

5. **Floor the height at whatever the component's `implicitHeight` was before
   the split, with the theme-dependent term taken out.** For both rows that is
   `Theme.groupHeight`; `InfoRow`'s pre-split
   `Math.max(Theme.groupHeight, column.implicitHeight + 14)` loses its second
   term because `column` moved. The floor covers the two ways a theme reports
   nothing: a file that did not load, and a root `Item` whose author forgot
   `implicitHeight`, which is 0 and would drop the row out of its section.

6. **Read the height through the Loader, not through `Loader.item`.** A Loader
   adopts the implicit size of what it loaded and keeps following it -- checked,
   not assumed: raising the loaded item's `implicitHeight` moves the Loader's in
   the same frame. `Loader.implicitHeight` is a real number on a real type;
   `Loader.item` is declared `QObject`, so `item.implicitHeight` costs one
   `[missing-property]` per facade and `tests/qml-lint.sh` gates on that
   category. Two facades, two warnings, one failed check -- which is how this
   was found.

7. **Run the checks, and run the split against the real window.** `qml-lint`,
   `qml-rules`, `shell-load`, `wheel-and-click.py`, `stow-conflicts`. Then open
   the real settings window in a sandbox and compare the geometry of one row
   both ways; both of these came out `620x36` and `620x69` against the pre-split
   files, which is the only evidence that says the move moved nothing.

## WHAT IT COSTS

Measured two ways, on this machine, against the real theme loader.

**Per row**, 400 rows built and laid out, best of five passes, facade against a
copy of the pre-split component in the same process:

```
ToggleRow   400 rows -- facade 28 ms, direct 16 ms
InfoRow     400 rows -- facade 65 ms, direct 56 ms
```

About 0.03 ms a row, or roughly 1.7x on the cheapest component in the tree. The
ratio looks bad and the number is what matters: a facade is a second object and
a Loader, and both are cheap next to the Texts and Rectangles under them --
which is why `InfoRow`, with more to draw, pays a smaller share.

**Per window**, the real settings window's first open, which builds fifteen
pages holding 28 `ToggleRow`s and 13 `InfoRow`s:

```
with the split      60 60 62 63 63 63 64 67 69 73 80          median 63 ms
before the split    53 55 57 59 60 60 61 61 63 66 67 71 114   median 61 ms
```

Two milliseconds apart, inside a spread that runs to 80 on one side and 114 on
the other. 41 rows at 0.03 ms is about 1.2 ms, which is the whole of the
difference and less than one sample of noise. **The split is not measurable in
the thing a person watches** -- and if a run ever says otherwise, look at the
spread before believing it. `Settings.qml` already documents that first open as
the moment the pages get built.

Sanity, from the same runs: the theme item's `row` is the facade
(`row === facade: true`), `enabled` reaches it (`themeItem.enabled=false`,
`opacity=0.4`), and a facade whose theme file has been deleted reports
`620x36` -- the floor -- rather than collapsing, while Quickshell logs
`No such file or directory` naming the missing path once per row.

## WHAT THIS DIRECTORY DOES NOT DO

**There is no per-file fallback.** `modules/Themes.qml` falls back to the
shipped theme when a MANIFEST cannot be read; nothing falls back when one FILE
inside a usable theme is missing. A theme that ships a `components/` directory
ships all of it or draws blank rows where it does not. That was a decision and
not an oversight: a per-file fallback would mean a theme could never remove a
component, would double the mechanism nineteen more agents have to copy, and
cannot be shared without a new file under `components/`. Revisit it when there
is a second real theme, which is the point at which the trade actually has two
sides.

**Editing a file in here does not hot-reload the shell.** Same reason as
everything else under `themes/` -- see the long note in `modules/Themes.qml`.
`qs kill && qs -d --no-duplicate`.

**Nothing checks rule 3, rule 4 or rule 7.** A mirrored `label`, a write to
`row`, a MouseArea on `InfoRow`: all three load, all three pass every test in
`tests/`, and all three are wrong. `tests/wheel-and-click.py` is the shape of
the answer if one of them ever ships -- a bench per component, driving the real
thing and measuring what came out -- and none of them has earned one yet.
