# ADR-0002 — Take the accent from the wallpaper through the scheme, and do not offer it as a setting

- **Status:** Accepted — and it reverses a design that had already shipped, which
  is most of why this document exists
- **Date:** 2026-08-22
- **Type:** Two-way door for the mechanism, one-way door for the control — a
  setting that is removed and then wanted back costs the state keys, the row and
  everybody who had set it

## Context

This desktop generates its colour from the wallpaper and has done since matugen
arrived. ADR-0001 split that into two halves: the accents follow the image, the
base comes from the scheme. **Only one half was ever true.**

matugen was handed the image and its answer went straight into the Material 3
derivation. A blue picture seeded the palette with `#0b87e2` — a sky blue that
no scheme in this repository publishes. On Gruvbox that put a colour Gruvbox
would never print next to Gruvbox's own surfaces, and the desktop read as two
palettes at once rather than one (`30a25a5`).

**And the first answer to that was the wrong answer, which is the part worth
recording.** A settings control was built offering *Accent from: Wallpaper /
Scheme / Custom*, with a hex field underneath — three sources, a state key each,
a command in `desktop-scheme`, and a segmented control on the appearance page
(`7567331`). It shipped.

It was built on a misdiagnosis. The complaint it was answering was that
*Catppuccin and Gruvbox felt like themselves while Tokyo Night looked like what
was already there*, and two separate faults were producing that, neither of them
"the accent is not configurable":

1. **The scheme was not a real Tokyo Night.** Every role in it had been
   reverse-engineered from the 193 hex literals scraped out of this repository's
   own templates, so the file recorded what the desktop had accumulated rather
   than what upstream publishes. Its own `_meta.source` said
   `"tokyonight-night (storm-dark)"` — two variants named at once — and the file
   was mixed to match. Sixteen roles were wrong, including all six bright
   terminal chromatics, which are `Util.brighten` of the normals upstream and
   were copies here, so colours 9–14 were the wrong colour in every TUI in the
   session (`241a104`).
2. **The accent had nothing to do with the scheme.** Tokyo Night's `fb_primary`
   is `#7aa2f7`; what actually rendered was `#a3c9fe`, out of the picture.

Fix those two and the complaint goes away. What the extra sources added was a
way to configure around the bug.

**What is not being decided here:** which colours a scheme publishes as
candidates (that is `scheme-accent.py`'s "WHICH COLOURS ARE CANDIDATES"), or
whether a scheme may be pinned by a theme (ADR-0003).

## Decision criteria

1. **The desktop reads as one palette** — measurable: sweep every rendered
   accent for a hex that belongs to no scheme file, over the whole collection
   under every scheme.
2. **A restrained palette produces a restrained desktop** — measurable: the
   lightness the accent lands at must differ between schemes, not converge.
3. **The wallpaper still chooses.** Two different pictures under one scheme must
   give two different accents, or the feature this repository opens with is gone.
4. **Every control on the appearance page answers a question somebody has.**
5. **A wrong answer is loud.** A colour that quietly fell back is worse than a
   failed render.

## Alternatives considered

### A. The wallpaper chooses *which*; the scheme decides *what* (chosen)

`desktop-scheme accent-args` asks matugen what colour the image is and nothing
else — a `-j hex --dry-run` that writes no file — snaps that colour onto the
nearest of the twelve chromatics the scheme publishes, and builds the nine
Material 3 accent roles the templates actually read out of the scheme's own
colours. matugen is *given* the family rather than asked for it, which works
because an imported role beats a derived one.

- **For:** meets criteria 1–3 by construction. Checked mechanically over 66
  wallpapers × 3 schemes: 198 accents, **none of them a colour outside the
  scheme file it came from**. A blue wallpaper gives `#458588` under Gruvbox,
  `#7aa2f7` under Tokyo Night, `#89b4fa` under Catppuccin.
- **Against:** the desktop now inherits a palette's own weaknesses (see
  Consequences). Two Python processes per wallpaper change, measured at 19 ms
  against the 491 ms the matugen dry-run already spends reading the image.
- **Cost:** one-off, `bin/.local/lib/scheme-accent.py` and a vendored CIEDE2000.
  Recurring: none — a new scheme needs no accent work beyond its twelve
  chromatics.

### B. Snap the accent, and let matugen derive the family from it

This was built and shipped first (`30a25a5`), and it is half of A. It is listed
separately because it *looks* like the whole fix and is not.

- **For:** one step, no new palette arithmetic, and it genuinely fixes "the
  accent is a colour the scheme does not contain".
- **Against:** it fixes which colour the accent is *derived from* and not what
  comes out. In `scheme-tonal-spot` dark mode matugen keeps the seed's **hue**
  and replaces its lightness and chroma with Material 3's own:

  ```
  seed #400000 -> primary #ffb4a8      seed #cc241d -> primary #ffb4a9
  seed #800000 -> primary #ffb4a8      seed #fb4934 -> primary #ffb4a8
  ```

  So Gruvbox's muted `#83a598` was snapped correctly and reached the screen as
  the mint `#87d6bc`. Measured over the 58 stills under all three schemes, every
  scheme landed its primary at L\* 80.0 — Tokyo Night 80.0, Catppuccin 80.1,
  Gruvbox 80.0 — because that is the tone M3 assigns regardless of the seed.
- **Why not:** it fails criterion 2. A restrained palette and a loud one produced
  equally loud accents, which is most of what made the schemes fail to feel like
  themselves in the first place.

### C. An accent axis with three sources — wallpaper, scheme, or a typed hex

The design that shipped and was removed.

- **For:** it is what a settings page usually offers, it costs nothing to look
  at, and one of its three answers (`scheme`) really does wire up the `fb_*`
  block that had no reader.
- **Against:** the accent is the wallpaper's contribution to the desktop — a
  blue picture giving a blue desktop. An accent the picture had no part in is a
  **second scheme sitting on top of the first**, which is a thing to configure
  rather than a thing to look at. And it papered over both real faults instead
  of naming either.
- **Why not:** criterion 4. Neither of the two extra sources was answering a
  question anybody had once the scheme was a real scheme and the accent stayed
  inside it.

### D. Do nothing — leave the accent free of the scheme

- **Cost of not deciding:** Gruvbox keeps wearing sky blue. The scheme feature
  from ADR-0001 half-works for ever, and nobody can say which half.
- **Why not:** criterion 1 is the whole point of having schemes at all.

## Decision

We take **A**, and we **remove C entirely rather than hiding it**.

Because the accent is not a setting: it is the one thing on this desktop that
answers to the picture, and the scheme is what decides which of its own colours
that answer is.

The removal was total, on purpose. Out of the page went the row, the hex field
and the note beside them; out of `desktop-scheme` went `accent`, `set_accent`,
`accent_source`, `accent_seed`, `normalise_hex`, `scheme_accent_payload`,
`DEFAULT_ACCENT` and `ACCENT_SOURCES`; out of `Config.qml` went `accentSource`,
`accentSeed` and `setAccent`. Nothing is hidden and no branch is left
unreachable (`7cdd332`).

`accent-args` stayed, and the division of labour is what earns it:
`desktop-scheme` is the side that knows what the scheme is, `wallpaper-switch`
is the side that knows which image to colour from — a video is coloured from a
cached frame, which is twenty lines over there. The `fb_*` roles stayed too;
they answer the different question a clone with no wallpaper yet asks.

## Consequences

**Positive.**

- The desktop is one palette. 198 rendered accents, no exceptions.
- The schemes are distinguishable at a glance, which was the original complaint.
- Nothing invents a colour. `primary` is the snapped colour unaltered; secondary
  and tertiary are the scheme's own chromatics a turn round the wheel from it;
  the containers and the `on_*` colours are the scheme's own surfaces and text,
  or a mix of two of them. Over 174 combinations and 1,566 role values there are
  no exceptions: 1,392 are published scheme colours and the remaining 174 are
  `primary_container`, each a mix of two published ones.
- The appearance page has one colour control instead of two, and the one it has
  is a list rather than a segmented row, because a scheme is a file dropped into
  a directory and that set is open by construction.

**Negative — stated plainly because it is real and it is not going away.**

- **Gruvbox's own mid-tone colours are low-contrast, and now that they reach the
  screen unaltered the desktop inherits that.** `primary` on `ui_surface` goes
  from 8.65:1 worst case to **2.69:1**, which is exactly what `term_red`
  `#cc241d` grades on `term_bg` `#282828` in a Gruvbox terminal. 37 of the 58
  wallpapers snap to one of those mid-tones. Material 3 never met this problem
  only because it lifted everything to L\* 80 first — and that lifting *is* the
  loudness being removed. This is the trade: a palette that is faithful, or a
  palette that is legible by construction. We take faithful, and
  `sem_*`/`ui_*` pairs keep the text readable.
- **`on_primary` had to stop being fixed.** The accent now moves across
  candidates from L\* 44 to L\* 91 and one dark answer cannot serve both ends,
  so it is chosen by measured contrast with a floor enforced in code and a loud
  failure under it.
- **Somebody who had used the accent picker has dead state.** `accent` and
  `accent-hex` are still written on such a machine; nothing reads them, and the
  first `set` after the removal drops them silently. A row nothing reads is
  worse than no row — `show` does not print it, so the only way to meet one is
  to open the file, where it looks like a setting that still works.
- **The distance metric is a judgement call**, and it is the one in this design.
  CIEDE2000 with the lightness term dropped (kL → ∞). Weighting lightness moves
  the pick into a different colour family 22 times over 174 pairs: 13 of them
  wrong — every burnt orange and warm brown lands on the palette's *pink* rather
  than its gold — 7 a toss-up, 2 better. A sunset giving a pink desktop is the
  failure this whole file is about, wearing the right palette instead of the
  wrong one.

**Risks and mitigation.**

- *Somebody asks for the accent picker back.* The answer is this document, and
  the honest test is whether they want a colour the picture had no part in or
  whether something else is broken — which is exactly what happened the first
  time.
- *A render that fails leaves every application holding the wrong colours.*
  Every step of `accent_args` is fatal, matching the `die` on the render itself.
  An accent that quietly fell back to the unsnapped image colour would be the
  same failure wearing the wrong palette instead of the old one.

**Work this generated.** The Tokyo Night scheme was rebuilt against upstream
role by role (`241a104`); the nine accent roles were counted rather than assumed
— every Material 3 accent role the fourteen templates actually reference, and no
others; the vendored CIEDE2000 moved out of the cursor matcher's data directory into
`bin/.local/lib/` with its licence beside it, because it has two callers now.

## What would reopen it

- **A light scheme, or one whose chromatics are all close together.** Snapping
  assumes twelve distinguishable candidates; Catppuccin Mocha already collapses
  to six distinct colours because it gives each bright variant the same value as
  its normal one.
- **matugen changing what it derives from a seed.** The whole of alternative B's
  failure is one behaviour of `scheme-tonal-spot` in dark mode. If an imported
  role ever stopped beating a derived one, the mechanism goes with it.
- **A wallpaper collection whose colours the schemes genuinely cannot serve** —
  measurable as a sweep where the snapped accent is the same colour for most of
  the collection, at which point "the wallpaper chooses" has stopped being true
  in practice.

## References

The algorithm, the candidate set, and the full 174-pair measurement of the
lightness term live in `bin/.local/lib/scheme-accent.py`'s docstring — including
the paragraph that says *read the next paragraph before the one after it*,
because the argument for dropping the term was replaced when its original
premise stopped being true. It is not restated here.

- `bin/.local/bin/desktop-scheme`, above `accent_args` — why the words that open
  the render are handed back rather than appended at the call site, why
  `color hex` needs the image re-imported as JSON, and why every step is fatal.
- `quickshell/.config/quickshell/modules/settings/pages/AppearancePage.qml`,
  above the Colour section — what came out of the page, and why the schemes are
  a list and not a `ChoiceRow`.
- `schemes/README.md` §1.4, §1.5 — the 17 accent-fallback roles and the nine M3
  names still filled from the wallpaper.

Commits, in the order they happened: `7567331` (the accent axis, built),
`241a104` (Tokyo Night becomes a real Night), `7cdd332` (the axis removed),
`30a25a5` (snapping), `9370caf` (the family, and the tonality).
