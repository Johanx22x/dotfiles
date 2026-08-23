# ADR-0003 — Give a word that crosses a language boundary one stated definition, and put a check on the round trip

- **Status:** Accepted
- **Date:** 2026-08-22
- **Type:** Two-way door for the feature, one-way door for the precedent — this
  is the shape every later cross-boundary contract in this repository will copy

## Context

A theme is a look for the desktop, and this repository already had the machinery
for a theme to say *"I am Gruvbox"*: since its first version `desktop-scheme` has
kept two keys instead of one — `scheme` is what renders, `chosen` is what the
person last picked freely — precisely so that a theme could take the desktop's
colour for as long as it is on and give it back on the way out (`2c0a6ca`).

Nothing used them. The script's own header ended *"Nothing pins anything today
and the keys cost two lines"*, and that is the state the feature sat in: a code
path with no caller, a key with no writer, and a name — **`pinned`** — with no
definition anywhere.

**Then it got two definitions, and each end built the one it was reading.**

- `Theme.qml` called `palette.source: "pinned"` *"one more case returning a path
  inside the theme directory"* — a theme carrying its own palette file that only
  the shell reads. It kept a switch open in `palettePath` for it.
- `desktop-scheme` called `pin` *"set it WITHOUT changing the user's choice"* —
  the theme naming a scheme the whole desktop then wears.

These are not two readings of one design. They are **two different features**,
one of which had already been **declined** — a theme carrying its own palette
produces a Windows-looking shell over a Catppuccin terminal, and the palette the
shell reads would be the one thing on the desktop the scheme did not decide
(that design has a name, `fixed`, and it was declined rather than deferred). The
approved design was the other one. Both were built, under one word, by two
people reading two different files (`c006b18`).

The cause is not carelessness. **The definition was in neither file that either
end was reading.** A bash script and a QML singleton exchange a string through a
JSON manifest; there is no compiler, no type, and no import between them that
could have made the disagreement visible. What existed instead was a manifest
key documented in two headers that had never been read against each other.

**What is not being decided here:** whether a theme may declare things about
itself at all — the manifest already carries `interface`, `name`, `title`,
`palette` and `font`, and `font.source: "theme"` was built on the same shape
(`ea89463`) — nor where the colour comes from (ADR-0002), nor what a theme owns
(ADR-0001).

## Decision criteria

1. **One reader cannot disagree with the other about what a word means** —
   measurable: there is exactly one place a person is sent to, and both ends
   point at it.
2. **The check exercises the contract end to end**, not each half separately —
   measurable: a mutant in either end fails the run.
3. **The invariant is enforced in code, not documented** — measurable: the
   states the prose forbids must be unrepresentable.
4. **A fresh machine is not a special case.** Whatever the design is, it has to
   hold on a clone where nothing has been chosen yet.
5. **A failure names the thing that failed.**

## Alternatives considered

### A. One definition, stated at the declaring end, with a round-trip check (chosen)

`pinned` means: *the theme names a scheme, and the whole desktop wears it while
that theme is drawn.* The definition, the key (`palette.scheme`), and — as
importantly — **what the word does not mean** live in one place,
`Theme.qml`'s palette section, which is the file that reads the declaration.
`desktop-scheme`'s header points back at it. `palettePath` loses the switch that
was kept open for the design nobody built.

- **For:** the declaring end is the natural owner — it is where the manifest is
  parsed, so a person reading the key at all is reading the definition. The
  check drives the whole round trip through a real shell.
- **Against:** the definition lives in a QML file, which is not where somebody
  editing a bash script would look first. Mitigated by the pointer, and the
  pointer is load-bearing rather than decorative.
- **Cost:** one-off, the correction and a re-aimed check. Recurring: every new
  cross-boundary word costs one stated owner and one round-trip check.

### B. Define it in a third place — a shared document

- **For:** neutral ground, and a reader of either end has one obvious address.
- **Against:** a document with no reader goes stale exactly like the two headers
  that produced this defect, and nothing in the tree would fail when it did. It
  also adds a hop: the person reading `palette.source` in a manifest has to be
  told to go somewhere else before they learn anything.
- **Why not:** criterion 1 is about a *reader* not disagreeing, and a third
  document has no reader. This repository's whole documentation discipline is
  that a decision lives next to the code that depends on it.

### C. Build both, under two names — `pinned` and `fixed`

- **For:** nobody's work is thrown away, and the seam for `fixed` already
  existed (`palettePath` with one case in it).
- **Against:** `fixed` was declined on its merits, not deferred, and shipping a
  declined design because it happened to get written is how a repository
  accumulates features nobody wants. A switch with one case, kept open for a
  design nobody is building, is a decision that looks like a placeholder.
- **Why not:** the argument against `fixed` did not change; only the confusion
  did.

### D. Do nothing — leave the two keys with no caller

- **Cost of not deciding:** the two-key design in `desktop-scheme` stays a
  claim. It was written for a caller that did not exist, and a design nothing
  exercises is a design nobody has checked. The fresh-install bug below is the
  proof: it had been sitting in `chosen()` since the keys were written and
  nothing could have found it.
- **Why not:** the fixture that pins is what gave the path a caller, and the
  caller is what found the bug.

## Decision

We take **A**.

Because a word that crosses a language boundary has no mechanism to keep its two
ends honest, so it has to be given one on purpose: a single stated owner, and a
check that walks the whole round trip rather than each half.

Three things follow from it, and each is a rule and not an implementation
detail:

1. **The definition names what the word does *not* mean.** `Theme.qml`'s palette
   section carries the declined `fixed` design as history, because the two are
   easy to confuse and the record of *why* one was refused is what stops it
   being rebuilt.
2. **The shell is the thing that pins.** `Theme.pinnedScheme` moving from `""`
   to a name is entering a pinning theme; moving back is leaving it. On the
   change, never on a timer or a poll — which is why a login lands on the
   theme's scheme rather than on whatever the last session left, and why a swap
   straight from one pinning theme to another is one call rather than an unpin
   and a pin with a render in between.
3. **The invariant is code.** `paletteSource` is only ever `"pinned"` when
   `pinnedScheme` holds a name a theme actually wrote; `adoptPalette()`
   guarantees it, which is what lets the handler underneath be a plain
   "empty or not" test. Same shape as `adoptFont` for a family.

## Consequences

**Positive.**

- One word, one meaning, one address, and both ends point at it.
- `tests/scheme-pinning.sh` was **re-aimed rather than extended**, and the change
  of aim is the interesting part. It used to drive `pin` and `unpin` itself and
  carry a tripwire watching for the wiring to arrive; it now starts a real shell
  in a headless compositor and enters and leaves the theme by writing `theme`
  into the `config.json` that shell is watching — and the tripwire points the
  other way, failing if the shell ever *stops* being the thing that pins.
- It asserts on the colour that lands in the rendered `colors.json` rather than
  on the state file, and deletes that file before every transition, so a step
  that records a name and renders nothing fails instead of passing against the
  previous step's output. Three mutants are caught: an `unpin` that goes back to
  what renders instead of to what was chosen, a `pin` that never re-renders, and
  the fresh-install case.
- **A real bug was found only because the path got a caller.** A pin on a
  machine that had never picked a scheme destroyed the thing the second key
  exists to protect: `chosen()` fell back to `current()`, so the pin recorded
  *itself* as the person's own choice and `unpin` had nothing to go back to — on
  every fresh clone, because the store does not exist until somebody picks
  something. It falls back to `DEFAULT_SCHEME` instead, and that is not a guess:
  `set` has written both keys since the script's first version, so a `scheme`
  with no `chosen` can only have come from a pin.

**Negative — trade-off accepted.**

- **The definition lives in a QML file** and the script points at it. Somebody
  working in bash reads a pointer before they read a definition. The alternative
  was a third document that nothing fails on.
- **A pin can outlive the theme that set it.** A pinning theme that stops being
  *drawn* while the shell is not running leaves the pin standing in the store,
  because there is no transition for the shell to see. The desktop then wears
  the departed theme's scheme until something moves it, and `desktop-scheme set`
  is what moves it. Written down where the transition is, and not fixed:
  fixing it would mean the shell reconciling state at startup against a theme
  that no longer exists.
- **A theme pinning a scheme this machine does not have is refused at the far
  end, not at the near one.** `desktop-scheme` has no file for the name, writes
  nothing and dies; because its stderr is a pipe when the shell spawns it,
  `lib_notify` turns that into a notification naming the script and the name it
  would not take. Checking it in the shell would mean running
  `desktop-scheme list` — a process, and a second opinion about a directory the
  script owns.

**Risks and mitigation.**

- *The pointer rots.* `tests/scheme-pinning.sh` fails if `Theme.qml` stops naming
  `"pinned"` outside a comment, or if nothing under `quickshell/` spawns the
  script. The tripwire is the mitigation, and it is aimed at the contract rather
  than at either half of it.
- *The next cross-boundary word repeats this.* The mitigation is this document:
  the rule is "one stated owner at the declaring end, and a check on the round
  trip", and `font.source` already follows it.

**Work this generated.** `tests/fixtures/theme-probe` pins `gruvbox-dark`, which
is what gave the path a caller; `Config.qml` grew `pinScheme` and `unpinScheme`
beside `setScheme`, sharing its process and its guard so the shell still has one
seam into the script; `tests/shell-load.sh` had to stub `desktop-scheme` on
`$PATH`, which is not tidiness — loading the probe spawns it by name, and on this
desktop the name resolves to the real script and through it to a real matugen
render.

## What would reopen it

- **A second theme wanting to pin something that is not a scheme** — a cursor
  pack, a font stack, an opacity. At that point `palette.source` is the wrong
  shape and the manifest wants a general "what this theme takes over" section,
  which is a different decision.
- **`fixed` becoming defensible.** It would take a reason the shell may hold a
  palette the rest of the desktop does not, and today there is none. If one
  arrives, this ADR is where to say what changed.
- **A third reader of the manifest.** Two ends can be kept honest by one stated
  owner and a round-trip check. Three is where a schema starts to earn itself.

## References

The contract itself — what `pinned` means, what it does not mean, the key name,
the transition, and the idempotence at the far end — is written at
`quickshell/.config/quickshell/Theme.qml`, in the section headed *"What the theme
declares about the palette"*. That is the single place by design and it is not
restated here.

- `bin/.local/bin/desktop-scheme` — the two-key store (`scheme` vs `chosen`),
  why `set`, `pin` and `unpin` write what they write, and the `chosen()`
  fallback with the measurement of the bug it fixes.
- `quickshell/.config/quickshell/Config.qml` — `pinScheme` / `unpinScheme`, and
  why they are two functions rather than one with a flag.
- `tests/scheme-pinning.sh` — the round trip through a real shell, the three
  mutants, and the sandbox that keeps it off the machine it runs on.
- `tests/fixtures/theme-probe/manifest.json` — the only pinning theme in the
  repository.

Commits: `2c0a6ca` (the two keys, written for a caller that did not exist),
`b080a46` (the fixture gives the path a caller, and a round trip to prove it),
`c006b18` (`pinned` means one thing).
