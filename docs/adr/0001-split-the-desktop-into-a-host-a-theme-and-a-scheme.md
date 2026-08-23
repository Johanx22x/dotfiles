# ADR-0001 — Split the desktop into a host, a theme and a scheme

- **Status:** Accepted
- **Date:** 2026-08-22
- **Type:** One-way door (the seam is cheap to draw once and expensive to erase
  after anything has been written against it)

## Context

Two things had grown together in this repository and neither could be changed
without changing the other.

**The shell was one tree.** `quickshell/.config/quickshell/` held the daemon
that owns `org.freedesktop.Notifications`, the code that spawns `cava`, the
list of what the launcher can do, *and* every rectangle, radius and animation
on screen, with nothing saying which was which. Changing what the desktop
looked like meant editing files that also decided what it did.

**The base palette was 227 hex literals across ten files** (`2c0a6ca`). Tokyo
Night was not a choice this repository had made once; it was a value written
out by hand 227 times. `qt6ct-colors.conf` alone carried 74 literals, 55 of
them inside three positional `QPalette` lines where a dropped comma shifts the
whole palette and Qt raises nothing (`040c7dd`). "Change the colour of the
desktop" was a search-and-replace across two GTK stylesheets, a Qt palette, a
terminal config, a PDF reader and a prompt, with no mechanism anywhere to say
whether the result was still one palette.

The two problems look unrelated and are the same problem: **no layer of this
desktop had a name, so no layer could be swapped.**

The constraints were real and are worth stating, because they rule out the
tidy answers:

- Quickshell reloads the *entire* config when any `.qml` file changes. Anything
  that regenerates QML restarts the shell — state lost, no way to animate
  (`Theme.qml`, "WHY colors.json AND NOT A GENERATED .qml").
- The colours are already regenerated on every wallpaper change by matugen, and
  that has to keep working.
- Nothing here may become a plug-in system with a loader, a registry and a
  version negotiation. This is a dotfiles repository maintained by one person.

**What is not being decided here:** where the accent comes from (ADR-0002), what
a theme's manifest may pin (ADR-0003), which schemes ship, or what the component
interface is — that last one is derived rather than decided, and the derivation
is argued in `tests/theme-interface.py`.

## Decision criteria

Fixed before the alternatives were compared.

1. **A change of look is not a change of behaviour** — measurable: a pure move
   must leave the rendered tree byte-identical, and `tests/qml-lint.sh` must
   report the same warning count in the same categories.
2. **One dial moves the whole desktop** — measurable: after setting it, the
   shell, the terminal, GTK, Qt and zathura all show the new base. A dial that
   moves the shell alone fails.
3. **A second implementation costs no edit to the entry point** — measurable:
   `cp -r`, edit one file, link it, and it draws, with `shell.qml` untouched.
4. **A failure is visible** — measurable: a theme that cannot be drawn is
   reported somewhere a person will look, not silently replaced.
5. **Runtime cost is not paid by the person watching** — measurable in
   milliseconds at startup and at a swap.

## Alternatives considered

### A. Three layers — a host, a theme, and a scheme (chosen)

The host composes and decides what exists; the theme draws it; the scheme says
what colour everything is, across the whole machine.

- **For:** each criterion falls out of the split rather than being engineered
  for. The host keeps the behaviour a theme could get *wrong* rather than merely
  draw differently — `StepperRow.nudge()`'s clamping, `ChoiceRow.valueOf()`'s
  option contract, `ScrollBar`'s two grab margins, the notification spec's
  `-1` and `0` — so a bad theme is an ugly desktop and never a broken one. The
  scheme is a file matugen already knows how to merge, so one render feeds all
  fourteen generated files and the shell at once.
- **Against:** three vocabularies instead of one, and a contrast guarantee
  traded for a contrast *measurement* — see Consequences.
- **Cost:** one-off, the move (32 files, `47056c9`), the vocabulary
  (78 roles, `schemes/README.md`), and twenty component splits. Recurring:
  a new shared widget is now two files and a rule, and a new scheme is 78
  values that must be checked by hand.

### B. Two layers — the theme owns its colours too

The obvious shape, and the one a theme system usually has.

- **For:** one concept fewer. A theme would be self-contained: drop in a
  directory and the desktop is that theme, palette included.
- **Against:** it produces a themed shell over a terminal wearing something
  else. The palette this shell reads would be the one thing on the desktop that
  the scheme did not decide, and a desktop where the shell and the terminal
  disagree is not a look.
- **Why not:** this was not merely rejected in the abstract — it has a name and
  a declined design. `fixed` (a theme carrying its own palette file that only
  the shell reads) was **declined rather than deferred**, and `Theme.qml`'s
  palette section says so where the manifest key is defined. See ADR-0003 for
  what happened when that declined design was half-remembered.

### C. One layer, with the scheme applied to the shell only

Where the work actually was for one commit, and it is worth recording as a
rejected state rather than an oversight.

- **For:** the shell is the part this repository draws, and the M3 roles it
  reads are derived per wallpaper with a *guaranteed* contrast for each role
  pair — a strictly stronger promise than any hand-written palette gives.
- **Against:** measured, and the measurement is what killed it. Rendered from
  one wallpaper under all three schemes, GTK, qt6ct and zathura tracked
  `#1a1b26` / `#1e1e2e` / `#282828` while the shell sat on the same near-black
  in every one (`9289d0d`). Choosing a scheme re-themed the whole desktop
  *except* the part this repository draws.
- **Why not:** it fails criterion 2 outright, and the guarantee it was
  protecting was worth more than a base nobody could ever change — not more
  than the base the user picked.

### D. Do nothing

- **Cost of not deciding:** the desktop stays one look. Every colour question
  stays a ten-file edit, and every drawing question stays entangled with a
  behaviour question.
- **Why not:** the repository had already accumulated 227 literals and a
  `_meta.source` reading `"tokyonight-night (storm-dark)"` — two upstream
  variants mixed in one file — which is what happens when a palette is
  maintained by hand across ten files and nothing can check it (`241a104`).

## Decision

We take **A**.

Because the two problems were one problem — nothing had a name, so nothing
could be swapped — and because criterion 2 can only be met by a layer that
lives *outside* the shell, which is what makes the scheme a third thing rather
than a property of the theme.

The boundaries, stated once:

| layer | owns | lives in | changed by |
|---|---|---|---|
| **host** | what exists, what it is doing, what happened | everything above `themes/` | code |
| **theme** | shape, layout, motion | `quickshell/.config/quickshell/themes/<name>/` | `Config.theme` |
| **scheme** | every colour that is not an accent, on every application | `schemes/<name>.json` | `desktop-scheme` |

Two asymmetries hold the seam up, and if either stops being true the split has
stopped meaning anything:

- **The dependency runs one way.** A theme imports `qs.modules.<name>` to reach
  the state it draws; nothing under `modules/` imports anything under `themes/`,
  and nothing in the tree instantiates a theme's types.
- **The theme never owns a colour.** `Theme.qml` reads the palette out of the
  generated `colors.json`, so genesis under Gruvbox and genesis under Tokyo
  Night are further apart than two wallpapers ever made it, and both are still
  genesis.

## Consequences

**Positive.**

- One dial. `desktop-scheme gruvbox-dark` ends in `wallpaper-switch reapply`,
  fourteen files are rendered from one matugen invocation, and kitty, GTK, Qt,
  zathura, Zen, fastfetch, the prompt, both compositors and the shell all move
  together.
- A second theme is `cp -r`. Measured: the shell swaps its seven surfaces with
  no config reload, and startup did not move (521–576 ms before, 520–538 ms
  after, `c2e5793`).
- Things became themeable that could never have had a facade.
  `components/SectionNote.qml` is a `Text` whose defaults are a font size, a
  palette role and a padding, all read off `Theme`; a `Loader` cannot re-base a
  `Text`, so no facade can ever be put in front of it — and it follows the theme
  anyway, without knowing a theme exists, because those numbers are the theme's
  now.
- The vocabulary made the desktop checkable. `tests/scheme-roles.py` holds three
  scheme files against the 78 roles `schemes/README.md` defines, and
  `tests/theme-interface.py` derives what a theme must implement from the host's
  own call sites rather than from a list somebody maintains.

**Negative — the trade-off accepted with both eyes open.**

- **A guarantee became a measurement.** Material 3 guarantees the contrast of
  each role *pair* whatever the wallpaper is. The scheme's pairs are checked
  once, by hand, when the scheme is written. That is a weaker promise, and it is
  why the "use roles in pairs" rule matters *more* now than it did: a guaranteed
  pair tolerates being taken apart and a measured one does not, because nothing
  recomputes it when a wallpaper lands (`Theme.qml`, "SO THE RULE SURVIVES AND
  ITS GUARANTEE DID NOT").
- **Contrast fell, everywhere, and that is the price of a palette a person
  picked over one an algorithm computed.** M3 was maximising against a
  near-black it had chosen itself. `on_surface_variant` lands at 3.77 on
  Catppuccin's top container and 3.80 on Gruvbox — above AA-large, below AA
  (`9289d0d`).
- **A theme is 27 files the host loads by path, with no per-file fallback.** A
  theme missing one gets a `Loader.Error` and one warning per use, and the shell
  comes up green. `tests/theme-interface.py` exists because nothing else in the
  tree asks.
- **Fourteen shared components still have no theme half**, and only
  `MenuView.qml` says why in its own header. That silence is not a decision in
  either direction.

**Risks and mitigation.**

- *The seam erodes quietly.* Mitigated by three checks that find themes for
  themselves — `qml-lint.sh` (per-scope warning budgets, so an unbudgeted theme
  is compared against zero), `qml-rules.sh`, and `theme-interface.py` (a theme
  is any directory with a `manifest.json`, discovered through `git ls-files`).
- *A dropped-in theme does not appear and nothing says why.* Real, and Johan hit
  it. The shell cannot see the checkout —
  `Quickshell.shellDir` is stow's target and Quickshell 0.3.1 does not resolve
  a path through the links inside it — so the installer is the only thing that
  can see both ends. `./install.sh check` names the directory and the file
  count; `apply symlinks` fixes it. Written up in
  `themes/genesis/README.md`, "Where the shell looks for it".
- *A scheme that is wrong renders nothing rather than something wrong.* matugen
  writes **none** of the fourteen files when one role fails to resolve. That is
  the right failure mode and it is why the vocabulary is tracked and checked.

**Work this generated.** Twenty components split into facade and implementation
(`themes/genesis/components/README.md` is the method and the measurements); ten
templates rewritten to read roles; the shell's four surface levels re-derived
per scheme; a second theme built as a test fixture so that every claim about the
seam stopped being a claim about genesis.

## What would reopen it

- **A second theme never arriving.** The fixture proves the host is neutral, but
  a seam with one real implementation is a seam maintained on faith. If a year
  passes with genesis as the only theme anyone draws, the twenty facades are
  cost without return and the split should shrink back to the ones that earn it.
- **Quickshell resolving symlinks**, or gaining a way to describe a directory it
  does not load from. That would remove the one failure a person actually hits
  and change what the installer has to carry.
- **A scheme the vocabulary cannot express.** The 78 roles were derived from
  three dark palettes. A light scheme, or one with a genuinely different surface
  structure, is the case that would test whether the vocabulary is a description
  or a straitjacket — `schemes/README.md` §4.1 already lists the roles that
  cannot be filled from a scheme's own palette.

## References

Decisions recorded next to the code, which is where the detail belongs:

- `quickshell/.config/quickshell/themes/genesis/README.md` — the seam in one
  sentence, what deliberately did not move, and how a theme is loaded.
- `quickshell/.config/quickshell/themes/genesis/components/README.md` — the
  facade mechanism, the seven rules a theme implementation lives by, the split
  costs (about 0.03 ms a row), and how to split the next one.
- `quickshell/.config/quickshell/Theme.qml` — the two colour axes, which eight
  M3 names come from the scheme and which nine come from the wallpaper, and why
  the palette and the tokens are JSON rather than generated QML.
- `matugen/.config/matugen/config.toml` — the same policy from the other side,
  the 128 roles a render offers, and why an alert is never harmonised.
- `schemes/README.md` — the authority on all 78 roles. §4.4 carries the surface
  ladder in full: one global mapping, reasoned for at length, overturned by
  counting what the shell actually paints with each level (46 readers of
  `surface_container_high`, 33 of them hover or focus fills), with the complete
  regrade. That decision has a home and is not restated here.
- `tests/theme-interface.py` — why the component interface is *derived* from the
  host's call sites rather than written down, with the counter-example that
  settled it (a hand-written list that was one component short before it was a
  day old).

Commits: `47056c9` (the move), `2c0a6ca` (the scheme mechanism), `c2e5793`
(loading by name), `9289d0d` (the shell follows the scheme), `af15d18` (the
theme declares its palette and tokens), `379867a` (the ladder per scheme),
`004e093` (the first two facades), `494a0ff` (a second theme proves the seam).
