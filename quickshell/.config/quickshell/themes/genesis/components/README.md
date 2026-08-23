# components, themed

The shared widgets, split in two. This directory is the half that draws.

`../README.md` says a theme owns shape, layout and motion, and ends by naming
what was deliberately left out of the split:

> **There is no facade in front of `components/`.** A theme draws with the
> shell's buttons, rows, scrollbars and popout, and cannot replace them.

That sentence is now mostly false, and this file is what replaced it.

**Twenty-five components have a theme half**, which is every `.qml` in this
directory:

```
ActionRow          BindRow            Chip               ChoiceRow
CornerWedge        InfoRow            LevelMeter         ListRow
MenuRow            NotificationCard   Popout             ScrollBar
SearchField        SettingsChrome     SettingsHeader     SettingsNavItem
SettingsResult     SettingsSection    StepperButton      StepperRow
StreamRow          ToggleRow          Tooltip            UserBlock
VolumeSlider
```

Count the files rather than trusting that number. It said nineteen and was
already wrong when it was written: `ScrollBar` crossed the seam in
"Let the theme draw the scrollbar" and the sentence was typed eleven minutes
later, in the next commit but one, without it. A count in prose beside a list
somebody appends to has nothing checking the two against each other --
`tests/theme-interface.py` prints the real number on every run, and that is the
one to believe.

**Fourteen under `components/` do not**, and only one of them says why in its
own header: `MenuView.qml`, because a component that is a delegate end to end
gets no checking from the seam and pays the full price of it. The other
thirteen never raise the question at all: two objects with nothing to draw, two
windows, two grabs, and seven widgets nobody has looked at yet. Do not read
that silence as a decision in either direction.

**`ScrollBar` used to be the second name in that paragraph**, and what moved is
worth a sentence rather than a quiet deletion. Its reason was that it is the
one component with a bench of its own -- `tests/scrollbar-target.py` -- and
that the bench could not follow it across the seam. The bench can, and does:
it builds the sandbox `qs.modules` and `qs.components` a split file needs and
points its `Themes` stub at the real `themes/genesis`, so the four pixels its
last assertion reads are the ones this directory paints. The whole of that is
written up in `components/ScrollBar.qml` under AND THE BENCH FOLLOWED IT
ACROSS. The reason was about a tool, and the tool changed.

Two of the twenty-five are worth knowing about before you copy anything:

- **`SettingsSection`'s facade is not under `components/`, and it is no longer
  the only one.** It is `modules/settings/SettingsSection.qml`, and its
  implementation is here anyway, because `shell.qml` imports this directory for
  the file watcher and that is what makes a theme file reload -- see the last
  section of this file. The seam does not care where a facade lives.

  Five more facades now live beside it: `SettingsChrome`, `SettingsHeader`,
  `SettingsNavItem`, `SettingsResult` and `UserBlock`, which between them are
  the whole of what the settings window used to draw. Their implementations are
  in here for the same reason, and their `row` declarations name types out of
  `qs.modules.settings` rather than `qs.components`. That import has one edge
  worth knowing: **two files in that directory are `pragma Singleton` and open
  `import Quickshell`**, and a composite singleton declared in a qmldir is
  created when a document importing the module is created -- which is fine in
  the shell and is why the two Python benches under `tests/` build that module
  with the singletons left out. Both say so where they do it.
- **`Popout`'s facade is a `PanelWindow` and not an `Item`.** Every other one
  is an Item. The diagram below is drawn from `ToggleRow` and does not
  represent that shape at all: a window's facade keeps a layer surface, a
  keyboard focus mode, an input mask and a screen-edge clamp, and hands the
  theme one rectangle to draw inside it. `components/ScreenCorner.qml` is the
  same shape taken to its end -- a window whose one drawn thing is a component
  that is itself split, so it has no theme file at all.

Everything below was measured on this machine against Qt 6.11.2 and Quickshell
0.3.1, under a headless labwc, with the real settings window open. Where a
number is quoted, it was read off a run.

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
lines and would cost the thing rule 1 below is about: a facade has to BE
the type its call sites name, with that type's properties on it, and a base
class that owned the Loader would still leave every property declaration in the
subclass. Sixteen lines against a second layer of indirection in the file
somebody opens to find out what `ToggleRow` is.

## THE SECOND MECHANISM: A SLOT, FOR AN OBJECT THE FACADE KEEPS

The sixteen lines above carry VALUES across the seam. Two components have to
carry an OBJECT, and they do it with a mechanism the ToggleRow shape does not
cover.

Both have a `default property alias` or something that behaves like one, and an
alias cannot reach across a Loader: it is resolved when the file is parsed, and
`drawing.item.rows` does not exist then.

- `modules/settings/SettingsSection.qml` owns the `Column` its pages fill --
  `default property alias content: rows.data`, which every settings page in the
  shell writes into.
- `components/SearchField.qml` owns its `TextInput`, because nine call sites
  read `input.text` and call `input.clear()` on it directly.

So the object stays on the facade, is published as a typed read-only property,
and the theme puts it where it wants it:

```qml
// components/SearchField.qml -- the facade keeps it
readonly property TextInput input: input

// themes/genesis/components/SearchField.qml -- the theme places it
Item {
    id: inputArea
    // ... anchors, margins, whatever shape this theme wants ...
    data: [root.row.input]
}
```

**The Loader call does not change.** It still passes `{ row: root }` and
nothing else -- checked in both files. The extra channel is not a bigger
`setSource` payload; it is a typed property read after `row` arrives, and one
`data:` line. The theme writes to its own item and reads the facade, which is
the ordinary direction and keeps rule 4 intact.

**WHAT IT COSTS, and both facades say it out loud where the cost falls.**
Whatever is inside the object is not the theme's:

> The spacing between rows is set below and a theme cannot pick another one --
> only where the column sits and what is drawn around it. It is the same trade
> `SearchField` makes with the input's font, and it is what keeping the alias
> costs. The margins around the column ARE the theme's: they are the slot's,
> not this Column's.
>
> -- `modules/settings/SettingsSection.qml:35-40`

> The text's own font and ink are set below, from `Theme`, and a theme cannot
> give this input a different size or colour -- only somewhere else to sit and
> something else around it.
>
> -- `components/SearchField.qml:58-65`

So: `SettingsSection`'s row spacing is 2 for every theme there will ever be,
and `SearchField`'s input is drawn at `Theme.fontSize` in `Theme.fontFamily`
for every theme there will ever be. That is the whole price of the alias, it is
paid per component rather than across the seam, and the day a theme genuinely
needs its own type in that input is the day this becomes a third channel --
not before.

**AND THE SLOT IS THE ONE THING A FACADE CANNOT REQUIRE.** A theme that leaves
the `data:` line out still loads and still draws: `SearchField` gets a pill
with its text lying across the whole width underneath the glyph, and
`SettingsSection` gets its rows at full width with no card behind them. There
is no property that could have been made `required` to prevent it, because the
slot is an item and not a value. It is rule 7 in a different costume.

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

#### AND IT STOPS AT THE EDGE OF A DELEGATE

The table above was measured on `ToggleRow`, which has no `Repeater`, no
`ListView` and no delegate of any kind. **Everything it claims is true at the
top level of a theme file and false inside a delegate**, which was found the
second and third times somebody split something and is the sharpest limit on
this rule.

Measured in `LevelMeter.qml` in this directory, `hotFrom` and `accent`
misspelt in BOTH places in the same run:

| where the misspelt `row.<name>` sits | what `tests/qml-lint.sh` said |
| --- | --- |
| top level of the theme file | `Member "hotFrmo" not found on type "LevelMeter" [missing-property]`, and the run went **19 -> 20 and failed** |
| inside the `Repeater` delegate | **nothing. No `missing-property`, and not even an `[unqualified]`.** |

qmllint stops at the outer component's `root` and does not follow through to
`.row.<name>`. The same thing was seen from the other side in `ChoiceRow`,
where the delegate reads came out as bare `[unqualified]` -- so the category
varies with the shape of the delegate and the protection does not: **inside a
delegate, `row.anything` is exactly as unchecked as `property var row` would
have made the whole file.**

It is not fixable from here. `pragma ComponentBehavior: Bound` is what would
make a delegate's outer scope resolvable, and `tests/qml-lint.sh`'s own header
rules it out for the tree.

So there are two things to do and they are both cheap:

- **Hoist.** Read the value once at the top level of the theme file, into a
  `readonly property` with a real type, and let the delegate bind to that local
  name. The read that crosses the seam is then a checked one and the delegate
  never touches `row` at all. `LevelMeter.qml` does this with `hotFrom` and
  `accent` and says so where it does it. This is not the mirroring rule 3
  forbids -- that ban is specifically `label`, `title` and `glyph`, because the
  settings search walks the tree looking for those three names and nothing
  walks for anything else.
- **Run it.** For whatever cannot be hoisted, the linter is not evidence. Open
  the thing and look at it, or measure it in a bench.

#### AND A `Loader`'s INLINE COMPONENT IS THE SAME EDGE, WEARING A DISGUISE

This one was found twice, independently, by `ListRow` and then by `Chip`, and
neither of them has a Repeater in the part of the file it is about.

Anything inside a `Loader { Component { ... } }` -- or a `sourceComponent` with
its body written in place -- is a NESTED COMPONENT. `root` is out of scope
there in exactly the way it is out of scope inside a delegate, and every read
of it comes back `[unqualified]`. So a theme file that wraps three lines in a
Loader to make them conditional has moved those three lines outside the
checking that the typed `row` exists to provide.

Both files reached the same answer and wrote it down: **use bindings, not a
Loader**, where the thing being decided is a handful of properties.
`themes/genesis/components/Chip.qml:184-202` is the clearest example -- the
three lines that decide whether a pill is a control at all are

```qml
enabled: root.enabled && root.button
hoverEnabled: root.button
cursorShape: root.button ? Qt.PointingHandCursor : Qt.ArrowCursor
```

side by side and checked, rather than a `Loader { active: root.button }` that
would have put all three somewhere nothing reads them.

There is a third face of the same edge and it is the one that costs a warning
rather than losing one: an unqualified read of a member whose TYPE Qt does not
expose declaratively costs an `[unresolved-type]` **per read**. The notification
card read `notification.actions` twice -- once for `visible`, once for the
Repeater's `model` -- and hoisting it into one `readonly property var actions`
took `tests/qml-lint.sh` from 307 to 306. The hoist that rule 1 asks for is not
only about checking; it is also about not asking the same unanswerable question
twice.

And when you are deciding whether a component needs a theme half at all, put
this on the scale: a component that is a delegate end to end -- `MenuView` is,
its rows come out of a `QsMenuOpener` -- gets no checking from the seam and
pays the full price of it. `components/MenuView.qml` was left whole partly for
this reason and its header sets out the rest.

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

#### THE RULE IS ABOUT A LOOP AND NOT ABOUT A WIDTH

Read literally, "never `implicitWidth`" is broken by six components on record,
and every one of them was right to. The reason in the paragraph above is a LOOP
-- a row fills its parent Column, a Column sizes itself to its widest child --
and none of the six is in that shape:

| | why the loop cannot form |
| --- | --- |
| `Chip` | it fills nothing. It is content-sized inside a Row that packs it, and how wide a word in a pill is, is a text metric -- which belongs to whoever chose the font |
| `MenuRow` | its parent Column has no width of its own. The width has to come from somewhere and the only somewhere is the row |
| `StepperButton` | it is not a row. Both directions are floored at 26 |
| `Tooltip` | a note has no column |
| `ScrollBar` | it is anchored, not packed. Its width is the number two call sites reserve their gutter FROM, so it is the thing others size against rather than the other way round |
| `Popout` | it is a window. What it reports is what the layer surface has to reserve, and a surface takes its size from its content or from nowhere |

So the test is not "is this a width" but **"is there a parent whose size
depends on mine?"** If there is, the width comes down and only down. If there
is not, say so in the file the way those six do, and report it.

#### THE EXCEPTION LIST IS THE SYMPTOM AND NOT THE RULE

That table said FOUR until somebody grepped the facades for
`drawing.implicitWidth` and found six. `ScrollBar` and `Popout` were on the
wrong side of it and nothing anywhere noticed -- not a check, not a lint, not a
review -- because a rule written as a list of names has no way to be wrong out
loud.

So the sentence in bold above IS the rule and the table is six worked examples
of it. One rule, one missing clause, and the clause is that sentence: six
components pass the same test for six spellings of one reason, and a seventh
will not need a new row.

**`CornerWedge` IS NOT ON THAT TABLE AND DOES NOT BELONG ON IT**, which is the
other half of the answer: what looks like one rule with a growing list is
partly a second rule wearing the same words. Its facade declares the box
(`radius` square) and never reads the Loader at all -- not the width, and not
the height either. The reason is not that no loop can form. It is that **the
theme is allowed to draw nothing at all**, and an empty `Item` reports zero: a
facade that took its size from that theme would collapse every fillet in the
shell the moment a theme declined to draw one, and a floor would not have
rescued it -- `Math.max(radius, drawing.implicitHeight)` is the same number and
says the theme has a say in it, which it does not. Note where that lands: it
constrains the HEIGHT as well, in the opposite direction from this rule's own
first sentence. Rule 2 says report your height; `CornerWedge` says report
nothing. Two rules cannot disagree about the same property and still be one
rule. It is stated where it belongs, under WHEN THE RIGHT IMPLEMENTATION IS
EMPTY, below.

**AND `implicitHeight` DOES NOT ALWAYS MEAN WHAT THE FIRST SENTENCE SAYS.**
`ScrollBar.qml` in this directory reports one and it is not how tall the bar
came out -- nothing lays a scrollbar out that way. It is THE SHORTEST TRACK THE
THUMB CAN LIVE IN, the floor the facade puts under a proportional thumb. Bind
it to `root.height` the way this rule reads and the thumb is floored at the
whole track and stops moving; that file says so in its own header. One
property, two meanings, and the seam cannot tell them apart. Read what the
facade does with the number before deciding what to put in it.

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

**AND IT HOLDS FOR STATE THE FACADE OWNS OUTRIGHT**, which is where the rule
first looked like it might not. A notification card is expanded or collapsed;
nothing outside it sets that, so there is no config to be a second writer to
and `row.expanded = !row.expanded` from the chevron would have been harmless
today. It is still not what `components/NotificationCard.qml` does. The clock
that decides when the notification leaves the screen is bound to `expanded`, on
the facade, with the timeout it counts -- so the facade exposes
`toggleExpanded()` and the theme calls it, and the value keeps exactly one
writer. The shape generalises: **if a theme has to change something, the facade
gives it a function**, whether the value ends up in a `Config` or stays on the
facade. `dismiss()` on the same file is the same move for a different reason --
there the function is also where the choice between `dismiss()` and `expire()`
lives, which is a fact about the notification protocol and not something a
theme should be answering.

### 5. `Theme` and `Icons` come from `import qs`, and only those

Design tokens are the host's and they are the same for every theme --
`../README.md` is explicit that the palette belongs to the wallpaper and stays
in the host, which is why this theme is not named after a colour. So a theme
implementation imports `qs` and reads `Theme.groupPadding`, `Theme.primary`,
`Icons.wifi` directly. Forty-eight of the fifty files under `themes/genesis`
already do.

The alternative -- everything arrives through `row` -- was considered and is
worse in a specific way: the facade would have to re-export a dozen tokens per
component, twenty times, and each of those is a place for the public API to
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
- `NotificationCard` -- **the whole card is the target, and what the click
  means is `dismiss()`.** There is no close button and there never was one. A
  theme that reached past the facade and called `expire()` on the notification
  instead would clear the screen in exactly the same way and tell the sending
  application the opposite thing -- and an application that thinks you never
  closed its notification sends it again.

When you split the next component, read its header, find the sentence that is a
promise about behaviour, and copy it into the theme file. That is not
documentation for its own sake -- it is the only place the promise can now live.

## WHEN THE RIGHT IMPLEMENTATION IS EMPTY

`themes/genesis/components/CornerWedge.qml` draws the concave fillet behind
every joint in this shell. A theme with square screen corners and a bar that
meets the screen edge at ninety degrees implements it as:

```qml
import QtQuick
import qs.components

Item {
    required property CornerWedge row
}
```

and that is not a stub, a placeholder or a file somebody forgot to finish. It
is the correct implementation of "this theme has no rounded corners", and it is
the first one in the tree for which an empty implementation is the right
answer. What follows is the rule that makes it safe, because it is not safe by
default.

**AN EMPTY IMPLEMENTATION REPORTS ZERO FOR EVERYTHING.** No `implicitHeight`,
no `implicitWidth`, no children, no colour. Rule 2 has the facade read a height
back off the Loader and floor it, and that floor is exactly what keeps an empty
theme from dropping a row out of its section. Where a floor is not enough, this
takes over -- and it is a rule of its own and not a third half of rule 2, for
the reason set out under THE EXCEPTION LIST IS THE SYMPTOM AND NOT THE RULE: it
tells a facade to report nothing where rule 2 tells it to report a height. Two
clauses:

1. **A component whose empty implementation is legitimate must not need
   anything back across the seam.** `CornerWedge`'s box is `radius` square and
   is declared on the FACADE for this reason and no other. Eleven wedges in
   this shell are placed by anchors against that box -- the bar's two, the
   launcher's two, the popout's two, the notification panel's one and the four
   screen corners -- and a box of zero moves every one of them. A floor would
   not have been enough here: `Math.max(radius, drawing.implicitHeight)` is the
   same number and says the theme has a say in it, which it does not.
2. **Everything the empty case still has to keep must be on the host side.**
   The four `ScreenCorner` windows go on existing whatever their wedge draws:
   they are still Top-layer layer surfaces, still `ExclusionMode.Ignore`, still
   `mask: Region {}`, and still `Theme.screenCornerRadius` square.

   Measured rather than argued. This theme's `CornerWedge.qml` was replaced by
   an empty implementation and the shell read back under a headless labwc:

   ```
   corner[topLeft]  window 10x10  anchors top,left   exclusion Ignore zone 0
                    mask empty=true   wedge 10x10 drawnChildren=0
   corner[topRight] window 10x10  anchors top,right  ... and so on, all four
   ```

   Every window, anchor, exclusion mode and mask identical to the run with the
   wedge drawing; the wedge itself still 10 by 10 with nothing under it. The
   cards and the cheatsheet rows in the same run came back byte for byte
   unchanged, which is the other half of the claim -- an empty implementation
   of one component does not disturb the rest. A shell that lays out
   identically with the drawing removed is what "the theme draws exactly one
   thing" means when it is true.

**AND IT IS NOT THE SAME AS A MISSING FILE.** There is no per-file fallback in
this directory -- the last section of this file says why -- so a theme that
ships no `CornerWedge.qml` at all gets a Loader in `Loader.Error` and one
Quickshell warning per wedge naming the path. Same pixels, and a log that says
somebody made a mistake. An Item that declares `row` and draws nothing is how
a theme says it meant it.

**AND IT STILL DECLARES `row`, WHICH IS NOT A FORMALITY.** The facade hands the
theme its `row` as an initial property of `setSource`, so an item that does not
declare one is an assignment with no target. Measured on the real shell under
headless labwc: a bare `Item {}` here loads, lays out, takes no input, moves no
geometry -- and logs `Cannot assign to non-existent property "row"` **fifteen
times per startup**, once per wedge in the tree. Declaring `row` takes it to
zero and moves nothing else. So rule 1 has no exception: an empty
implementation is an implementation, and it obeys the same contract as a full
one.

There is a **third** way a theme reports nothing, and `SettingsSection` found
it: its floor is not a number at all. A theme that never slots the column
leaves it anchored to the facade's own item, laying its rows out at full width
with no card behind them -- legible, and what a section with no card would look
like anyway. So when you ask what your component does with an empty
implementation, the answer is one of three: a floor takes over (`ToggleRow`),
the host kept the number (`CornerWedge`), or the content degrades to something
that still reads (`SettingsSection`). If it is none of those, the empty case is
not safe and the component is not one a theme may decline to draw.

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

   **A clean number is not a guarantee, and the point is to CHARACTERISE the
   drift rather than to collect a green tick.** `ListRow` was checked harder
   than that -- twenty before-and-after pairs grabbed under a headless run and
   compared pixel by pixel -- and nineteen came back byte for byte identical.
   The twentieth did not: a `PickRow` with an empty `detail`, where the glyph
   moves UP BY THREE PIXELS and nothing else on the row moves at all (121
   pixels differ, all of them inside the glyph's own box, x 12..26). That is
   worth more than twenty clean pairs would have been, because it is the only
   reason anybody knows the difference is three pixels of glyph and not
   something else.

   A root size is a coarse instrument. Where a component has internal geometry
   somebody could get wrong -- a chord of chips whose widths an arithmetic
   model elsewhere depends on, a card that grows when it is expanded -- walk
   the item tree and compare every leaf's position and size in the root's own
   coordinates, both ways. That is how the cheatsheet's key gutter was checked
   when `BindRow` was split -- 2, 3 and 4-chip chords, every chip's box, and
   the sheet's own `chipSpacing * (n - 1) + sum(advanceWidth + chipPadding)`
   model printed beside the width the chips actually came out:

   ```
   SUPER S              model  79.781   drawn  79.781   delta 0
   SUPER SHIFT S        model 137.766   drawn 137.766   delta 0
   SUPER CTRL SHIFT Left model 211.344  drawn 211.344   delta 0
   ```

   identical before and after, with the chip pill swapped for
   `components/Chip.qml` underneath. The index path in the walk moves -- there
   is a Loader and a theme item between the root and everything under it now --
   and nothing else does: every leaf's position, size, colour, text and font
   came back byte for byte.

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

**Editing a file in here DOES hot-reload the shell**, and that is not free.
Quickshell registers its watches during the startup scan, which only reaches a
directory it can follow an import to -- so `shell.qml` carries one static
import per theme directory purely to be watched, this one included. The import
is unused by design and qmllint is told so. Add a directory under a theme and
it is invisible to the watcher until its import is there: that is how this
very directory spent its first hours, silently unwatched, because it was
created after the imports were written.

**Nothing checks rule 3, rule 4 or rule 7.** A mirrored `label`, a write to
`row`, a MouseArea on `InfoRow`: all three load, all three pass every test in
`tests/`, and all three are wrong. `tests/wheel-and-click.py` is the shape of
the answer if one of them ever ships -- a bench per component, driving the real
thing and measuring what came out -- and none of them has earned one yet.
