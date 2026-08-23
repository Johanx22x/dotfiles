# Colour schemes — the base palette, and the vocabulary that names it

A **scheme** is the fixed half of this desktop's colour: surfaces, text,
outlines, the sixteen ANSI slots, the alert colours. It does not come from the
wallpaper and it does not move when the wallpaper does. The other half — three
accents and the Material 3 roles around them — is derived from the image on
every change, and has been for as long as matugen has been in this repository.

Both halves reach the templates in one render. How, and why the two can never
tread on each other, is the whole of the next two sections.

**This file is authoritative.** Every role name a template may use is listed
here, and nothing else is a role. A template that invents a name renders a hex
that no scheme file supplies, matugen stops with `Value does not exist in the
context`, and nothing is written — so an invented name is not a cosmetic
mistake, it is a desktop that cannot re-theme itself. If a name you need is
missing, add it here first, add it to every `*.json` beside this file, and only
then use it.

---

## The files

```
schemes/README.md              this file: the vocabulary and the substitution worksheets
schemes/tokyo-night.json       the default scheme, taken from upstream (see "Tokyo Night is Night")
schemes/catppuccin-mocha.json  Catppuccin Mocha
schemes/gruvbox-dark.json      Gruvbox Dark Medium
schemes/windows-11-dark.json   Windows 11 Dark
```

`schemes/` is not a stow package — it holds no dotfile, so `install.sh` and
`tests/stow-conflicts.sh` both pass it over and nothing here is linked into
`~/.config`. The scheme files are read out of the checkout, through the same
`readlink -f "$0"` that finds `desktop-lib.sh`: they are repository content, not
machine state, and versioning them is the point.

`desktop-scheme` is the dial. `wallpaper-switch` asks it which file to hand
matugen. Neither of them knows a colour.

---

## The file format

```json
{
  "_meta": {
    "label": "Tokyo Night",
    "variant": "dark",
    "source": "where these values come from"
  },
  "colors": {
    "ui_bg": { "default": { "color": "#1a1b26" } }
  }
}
```

**`colors` is matugen's own shape and not a flat map.** `{"ui_bg": "#1a1b26"}`
fails; the `default` / `color` nesting is what matugen deserialises. `dark` and
`light` siblings of `default` are accepted and unused — every template in this
repository reads `.default`, and `matugen json --mode light` was measured to
change nothing because of it. A dark-only project needs `default` alone.

**Everything matugen must not read goes under `_meta`.** matugen puts every
top-level key of the file into the flat template context, so each new one is
another name that could collide with a role. One reserved key means one name to
keep clear instead of a growing list. Nothing reads `_meta` today except
`desktop-scheme list`, which prints `label`.

**The filename is the scheme's identity.** `tokyo-night.json` is the scheme
`tokyo-night`; there is no `name` field to disagree with it. `label` is for
human eyes and may be spelled however it likes.

**Keys are sorted, because `jq -S` sorted them.** `tests/scheme-roles.py`
re-runs `jq -S` and fails if the file is not already in that form, so the
layout is mechanical rather than maintained. The prefixes make that ordering
useful rather than arbitrary: `fb_`, `sem_`, `term_`, `ui_` sort together, so
alphabetical order *is* grouped order.

---

## How the two halves join

One matugen invocation, at `wallpaper-switch`'s "5. Regenerate the palette":

```sh
matugen "${ACCENT_ARGS[@]}" --mode dark --quiet \
    --import-json "$SCHEME_FILE"
```

`ACCENT_ARGS` is what `desktop-scheme accent-args` hands back, and it is the
words that open the command rather than a flag appended to it: `color hex
<snapped>` plus an `--import-json-string` carrying the wallpaper's path for the
`{{image}}` provenance line. It used to be `image "$PALETTE_SOURCE"` with
`--prefer saturation` here; the image is now read on that side instead, so that
its colour can be snapped onto the nearest colour the scheme itself publishes
before the render is seeded with it. The note above `accent_args` in
`desktop-scheme` is where that is argued.

`--import-json` merges the file into the render context that matugen has just
derived from the accent. The 50 Material 3 roles come from the wallpaper, the
78 roles named here come from the file, and every template sees all 128 at
once — measured by dumping one render's `.colors` and counting the keys. The
17 M3 roles section 1.5 names are the subset this repository ever consumed, and
only nine of them are still read out of the render: the eight surface, text and
outline names are keys the shell still receives under their M3 spelling, but
`quickshell-colors.json` fills them from `ui_*` now. 1.5 says which is which.

`.hex`, `.hex_stripped` and `.red` / `.green` / `.blue` are computed by
matugen from any hex it is given, so a scheme role supports exactly the filters
a derived one does — which is what `qt6ct-colors.conf` (ARGB), `hypr-colors.lua`
and `ranger-accent` (decimal channels) need.

**Measured, not assumed.** Both this and the obvious alternative — dump the
palette with `matugen image ... -j hex --dry-run`, merge it with `jq`, render
with `matugen json` — were run against all 56 still wallpapers in the
collection, rendering all eleven templates each time and diffing against what
the desktop generated then. 616 files per approach, byte for byte identical,
no exceptions. That count is the record of the measurement and not the size of
the tree: there are fourteen templates now, and the three that arrived since
render out of the same context as the other eleven. `--import-json` was taken
because it is one process instead of two, needs no intermediate file, and leaves
the fatal-or-not judgement at that call site exactly where it was.

**THE IMPORTED FILE WINS.** A scheme that spelled a role `primary` would
override the wallpaper's accent silently — measured: a scheme setting
`primary` to `#ff0000` renders `#ff0000` and the image's own accent is gone.
So the `ui_` / `term_` / `sem_` / `fb_` prefixes are not tidiness, they are the
only thing keeping a scheme out of the 17 names in section 1.5, and
`tests/scheme-roles.py` refuses a `colors` key that does not carry one.

That precedence was also going to be the door an accent axis walked through:
`desktop-scheme accent` was to say where the three accents come from, with
`scheme` and a hand-typed hex as further sources needing no new mechanism, only
three more entries in the imported JSON. **There is no such subcommand.** It was
built and removed, and the reasoning is in the note above `accent_args` in
`desktop-scheme`: the accent is the wallpaper's contribution while the scheme
says what the desktop is made of, so an accent the picture had no part in is a
second scheme sitting on top of the first. What the wallpaper picks is now
snapped onto the nearest colour the scheme publishes, which is the same wish —
a Gruvbox desktop wearing a Gruvbox accent — answered without a dial. The `fb_*`
roles stayed, for the different question a clone with no wallpaper yet asks.

**Every way of getting it wrong is fatal, and none of them writes a file.**
Measured against matugen 4.2.0: a missing file, malformed JSON, the wrong shape
and a role a template asks for but the scheme does not define all exit 1 with
nothing rendered. That is why the `|| die "matugen failed"` at that call site is
right, and the comment there explaining why it alone is fatal while everything
around it is `|| true` now covers the scheme file too.

**THAT GAP IS CLOSED.** It was: while the templates still carried the base as
hex literals, not one of them read a scheme role, so an incomplete or entirely
absent scheme file rendered eleven perfectly good files and said nothing. The
substitution in section 5 has happened — ten of the fourteen templates read
scheme roles now, and the four that do not (`hypr-colors.lua`,
`niri-colors.kdl`, `ranger-accent`, `zen-colors.css`) are the pure-accent ones
— so a missing role is a render that fails loudly, which is the enforcement the
first paragraph of this section describes. `tests/scheme-roles.py` is no longer
the only thing standing in the way; it stays because it catches the same fault
before a wallpaper change does, and on a machine with no wallpaper set at all.

---

## Decisions taken

The B0 survey left eight questions open. All eight are answered; where the
answer changes a rendered byte it is called out in the worksheet as well. Two
later entries — "Tokyo Night is Night" and the alert colours below it — did not
come from that survey but from checking the default scheme against upstream.

**zathura's on-accent colour is unified.** `zathurarc:39,55,57` used `#15161e`
where every other file in the desktop uses `#1a1b26` for the same job — text
drawn on top of an accent or a semantic fill. Nothing in the file explained the
difference and it reads as drift, so those three sites take the shared
`ui_on_accent` / `sem_on_warning` / `sem_on_critical` roles. Three rendered
values move by 5 levels. No fourth role.

**`sem_info` stays.** Neither Catppuccin nor Gruvbox publishes an "info"
colour, so it is filled by judgement in every scheme — but `cship.toml`'s ramp
is semantic, not terminal, and pointing it at `term_cyan` would make the
nominal end of a warn/critical ramp inherit whatever the ANSI palette happens
to hold.

**Tokyo Night is Night, and only Night.** `_meta.source` used to read
"tokyonight-night (storm-dark)", naming two variants at once, and the file was
mixed to match: `ui_bg_control #24283b` is Storm's `bg` and `ui_bevel_mid
#1f2335` is Storm's `bg_dark`, sitting inside a scheme whose background is
Night's `#1a1b26`. Night is what the background says and Night is what the file
now is, end to end. Upstream is `folke/tokyonight.nvim`:
`lua/tokyonight/colors/storm.lua` deep-extended by
`lua/tokyonight/colors/night.lua` for the palette, `lua/tokyonight/colors/
init.lua` for the tones the plugin derives (`black`, `bg_visual`, the
brightened terminal chromatics), and `extras/kitty/tokyonight_night.conf` for
the sixteen ANSI slots — cross-checked against the wezterm and ghostty extras,
which agree hex for hex. Sixteen roles moved; the other 58 were
already right. **Where a role has no upstream counterpart at all** — the Qt
palette slots, mostly — the rule is: take the published Night tone that fills
that rung of the ladder, and only where the ladder has no published tone
compute one with upstream's own `Util.blend` over the two neighbours the role
sits between. Two roles need the second half of that rule; see 4.1(c).

**Two alert colours are left where they are, and the reason is worth writing
down.** Upstream names its own semantic set in `colors/init.lua`:
`error = red1 #db4b4b`, `warning = yellow #e0af68`, `info = blue2 #0db9d7`,
`hint = teal`. `sem_warning` already matches. `sem_critical` (`red #f7768e`)
and `sem_info` (`cyan #7dcfff`) do not — but those are *editor diagnostic*
colours, and `sem_*` here paints GTK's `destructive_*`, Qt's `BrightText` and
a starship ramp, which are a different surface with a different job. Both
current values are genuine Night entries. The red also has a second argument:
`#db4b4b` grades 4.17:1 on `ui_bg` and 3.27:1 on `ui_bg_raised`, against
`#f7768e`'s 6.46:1 and 5.08:1 — adopting it would hand Tokyo Night the same
weak red Gruvbox already has. The cyan has no such argument (`#0db9d7` grades
7.27:1 and 5.72:1, both fine), so it rests on the surface distinction alone.
Left as they are, and recorded as an open question rather than settled by
taste.

**Catppuccin's `color15` is not a typo.** `subtext0 #a6adc8` is darker than
`color7`'s `subtext1 #bac2de`. Verified against the official `catppuccin/kitty`
mocha theme: that is their published mapping, and it ships as written.

Re-verified when `catppuccin-mocha.json` was written, and the answer holds —
`themes/mocha.conf` has `color7 #bac2de` / `color15 #a6adc8`, and its Whiskers
source `templates/kitty.tera` emits `subtext1` then `subtext0` deliberately
rather than by accident. `catppuccin/alacritty` inverts the pair the same way,
so it is the terminal-port convention and not a kitty quirk. **Upstream is not
self-consistent about it, though**, and a future scheme author will find the
contradiction: `catppuccin/palette`'s `palette.json` (`mocha.ansiColors`) and
the style guide's terminal table both assign `color7` → subtext0 and `color15`
→ subtext1, i.e. the other way round. The published *terminal themes* are the
authority here, because they are what a terminal actually ships. Same source
disagrees on the six bright chromatics — the style guide generates distinct
brighter variants where kitty and alacritty repeat the normal hex — and this
scheme follows kitty there too.

**Every scheme picks its own four surfaces.** The shell's Material 3 surface
ladder was one global mapping in `quickshell-colors.json` — `ui_bg` →
`ui_bg_raised` → `ui_bevel_midlight` → `ui_border` — which imposed Gruvbox's
grammar on all three and put Tokyo Night in tones Tokyo Night does not paint
surfaces with. It is four roles in the scheme file now (`ui_surface` and the
three containers, 1.1), derived per scheme from that project's own published UI
ports. The full derivation, the citations, the two judgement calls and the
regrade are in 4.4.

**No shadow-tint role.** The `rgba(0,0,0,·)` shades and scrims in both GTK
templates stay alpha-on-black. A warm scheme wanting brown shadows would need
`ui_shadow_tint`, and there is no evidence anyone does.

**The four single-consumer roles stay**, and so does `ui_bg_dim` as its own
name. `ui_bg_control`, `ui_selection_disabled`, `ui_doc_bg` and `ui_doc_fg`
each have exactly one reader, and each is a genuinely different meaning — see
the collision table. `ui_bg_dim` and `ui_bg_field` differ by one level in Tokyo
Night and by a mile in Catppuccin, which is the case a shared vocabulary exists
to serve.

**The join is `--import-json`**, decided above.

**`tests/theme-stub.qml` disagrees with `Theme.qml` at two fallbacks**
(`surfaceContainerHigh`, `outlineVariant`) and will drift further once those
become roles. Out of scope here; recorded in the worksheet at 5.10.

**Three literals outside the theming surface carry base tones and will look
foreign under a non-Tokyo-Night scheme**: `niri/.config/niri/config.kdl:560`
`backdrop-color "#11121a"`, `quickshell/.config/quickshell/themes/genesis/
island/Dashboard.qml:334` `inkInverse: "#12161f"`, and
`hypr/.config/hypr/hyprland.lua:348` `inactive_border = "rgba(595959aa)"`. The
first two are Tokyo-Night-family darks; the third is a neutral grey and
probably fine. Not in the worksheet, because they were not in the survey's
scope.

---

## What was counted

**This is the survey the substitution was planned from, and it describes the
tree as it stood then.** Every "in code" figure for a template is now zero:
section 5's worksheet has been applied, so those literals are
`{{colors.<role>...}}` today and only the comment-only ones remain. `Theme.qml`
is the one row that did not go to zero, and deliberately — its hexes are `??`
fallbacks behind the values it reads out of `colors.json`, which is what a
clone with no wallpaper yet draws with. Three templates that did not exist when
this was counted — `kitty-scheme.conf`, `zen-scheme.css` and `cship.toml`, the
last being `shell/.config/cship.toml` moved under `matugen/` — are absent from
the census for the same reason. The counts are left as they were measured: they
are what the plan was sized against, and re-running the count against a tree
that no longer has literals in it would say nothing.

Scope analysed (read-only, nothing in `/home/johan/dotfiles` was modified):

| file | hex occurrences | in code | in comments |
|---|---|---|---|
| `matugen/.config/matugen/templates/fastfetch-config.jsonc` | 1 | 1 | 0 |
| `matugen/.config/matugen/templates/gtk3-colors.css` | 48 | 44 | 4 |
| `matugen/.config/matugen/templates/gtk4-colors.css` | 46 | 36 | 10 |
| `matugen/.config/matugen/templates/kitty-colors.conf` | 5 | 5 | 0 |
| `matugen/.config/matugen/templates/qt6ct-colors.conf` | 74 | 55 | 19 |
| `matugen/.config/matugen/templates/zathurarc` | 19 | 19 | 0 |
| **templates subtotal** | **193** | **160** | **33** |
| `kitty/.config/kitty/kitty.conf` | 31 | 31 | 0 |
| `zen/.zen/rice/chrome/userChrome.css` | 9 | 3 | 6 |
| `shell/.config/cship.toml` | 13 | 13 | 0 |
| `quickshell/.config/quickshell/Theme.qml` | 21 | 21 | 0 |
| **grand total** | **267** | **228** | **39** |

Five templates carry no literal at all and need no work:
`hypr-colors.lua`, `niri-colors.kdl`, `quickshell-colors.json`,
`ranger-accent`, `zen-colors.css`.
`ranger/.config/ranger/colorschemes/tokyonight.py` also carries **no hex** —
it paints with ANSI indices only (`fg, bg = 0, ACCENT` at lines 113, 130, 134).
That makes it a *consumer* of `term_black`, not a site to substitute.

Distinct literals: **46** as written, **27** once the ARGB spellings of
qt6ct are folded onto their RGB base and the 7 comment-only literals are
dropped.


---

## 1. The role list

78 roles in four groups: **27 base**, **27 terminal**, **7 semantic**,
**17 accent fallbacks**. On top of those sit the 17 Material 3 roles the
templates already consume at runtime (section 1.5) — those come from the
wallpaper and are *not* in the scheme file.

**Naming rule:** every scheme role carries a group prefix (`ui_`, `term_`,
`sem_`, `fb_`). matugen's template context is a **flat** namespace, so an
unprefixed `surface` / `outline` / `outline_variant` in a scheme file would
collide with the identically-named Material 3 roles matugen derives from the
wallpaper. The prefixes make that collision impossible by construction.

### 1.1 base — surfaces, text, outlines

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | Windows 11 Dark | meaning | consumed at |
|---|---|---|---|---|---|---|
| `ui_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | `#202020` | Window / chrome background: the flat surface every app frame sits on. | gtk3 x9, gtk4 x8, zathura:28, zen-scheme.css x3, qt6ct idx10/17 |
| `ui_bg_dim` | `#16161e` | `#181825` | `#1d2021` | `#1c1c1c` | A quiet chrome strip that must recede behind ui_bg. | **nothing today** — the kitty tab bar reads `term_tab_bg` |
| `ui_bg_bar` | `#15161e` | `#181825` | `#3c3836` | `#272727` | Secondary bar / strip inside a window: statusbar, inputbar, notification, group header. | zathura:30,32,36,52 |
| `ui_bg_field` | `#15161e` | `#181825` | `#1d2021` | `#2d2d2d` | Background of an editable field or a scrolling list (Qt Base). | qt6ct idx9 x3 |
| `ui_bg_view` | `#0c0e14` | `#11111b` | `#1d2021` | `#242424` | The content pane, set one clear step away from ui_bg so content lifts off chrome. NOT necessarily darker -- see the ladder notes. | gtk3:83,145,162,173; gtk4:117 |
| `ui_bg_shadow` | `#0c0e14` | `#11111b` | `#1d2021` | `#0a0a0a` | Deepest tone of the palette; Qt bevel drop shadow. | qt6ct idx11 x3 |
| `ui_bg_alt_row` | `#1a1b26` | `#1e1e2e` | `#282828` | `#202020` | Alternating table row. Deliberately equal to ui_bg today (no stripe). | qt6ct idx16 x3 |
| `ui_bg_raised` | `#292e42` | `#313244` | `#3c3836` | `#2c2c2c` | Card / popover / tooltip / completion menu: a container floating above ui_bg. | gtk3:115,122,125; gtk4:176,183,186; zathura:34; qt6ct idx18 x3 |
| `ui_bg_button` | `#292e42` | `#313244` | `#3c3836` | `#2d2d2d` | Qt button face (QPalette::Button). | qt6ct idx1 x3 |
| `ui_bg_control` | `#222534` | `#313244` | `#3c3836` | `#323232` | A raised inline control (the Nautilus breadcrumb pill, linked button groups). | gtk4:451 |
| `ui_surface` | `#0c0e14` | `#11111b` | `#282828` | `#202020` | **Level 1 of the shell's surface ladder**: the ground a whole panel is drawn on — the bar, the launcher, the settings window, a popout, the notification stack. Each scheme picks its own four; the derivation and the citations are in 4.4. | quickshell-colors.json:11 |
| `ui_surface_container` | `#1a1b26` | `#1e1e2e` | `#3c3836` | `#2b2b2b` | **Level 2**: a card sitting on that panel — a notification, a settings section, the dashboard sheet. Borderless in this shell, so it has to stand off level 1 by tone alone. | quickshell-colors.json:12 |
| `ui_surface_container_high` | `#292e42` | `#313244` | `#504945` | `#333333` | **Level 3**: hover, and the pills the bar and the launcher draw at rest. 33 of its 46 readers are a hover or focus fill and 23 of those are literally `containsMouse ? this : "transparent"`, which is why every scheme's level 3 sits *above* its level 2 whatever its chrome does. | quickshell-colors.json:13 |
| `ui_surface_container_highest` | `#343a55` | `#585b70` | `#665c54` | `#454545` | **Level 4**: tooltips, slider rails, meter tracks, key chips, field fills, and 9 more hover fills. Must not be equal to `ui_border_dim` — every tooltip fills with level 4 and borders with `outline_variant`. | quickshell-colors.json:14 |
| `ui_bevel_dark` | `#15161e` | `#181825` | `#1d2021` | `#141414` | Qt 3D bevel, darkest shade (QPalette::Dark). | qt6ct idx4 x3 |
| `ui_bevel_mid` | `#1a1b26` | `#1e1e2e` | `#282828` | `#1c1c1c` | Qt 3D bevel, mid shade (QPalette::Mid). | qt6ct idx5 x3 |
| `ui_bevel_midlight` | `#353b55` | `#45475a` | `#504945` | `#2c2c2c` | Qt 3D bevel, light-mid shade (QPalette::Midlight). | qt6ct idx3 x3 |
| `ui_border` | `#414868` | `#585b70` | `#665c54` | `#414141` | Visible 1px divider or frame between surfaces; Qt bevel lit edge (QPalette::Light). | gtk3:88,130,166; gtk4:138,191; qt6ct idx2 x3, idx14/15 disabled |
| `ui_border_dim` | `#3b4261` | `#45475a` | `#504945` | `#2f2f2f` | A weaker divider: an unfocused window split. | **nothing today** — the unfocused split reads `term_border_inactive` |
| `ui_text` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#ffffff` | Primary text and icons on any ui_bg* surface. | gtk3 x12, gtk4 x9, zathura x6, qt6ct idx0/6/8/19, fastfetch:49 |
| `ui_text_variant` | `#a9b1d6` | `#bac2de` | `#d5c4a1` | `#cccccc` | Secondary / less important text that still has to be read. | cship.toml:63 |
| `ui_text_dim` | `#545c7e` | `#7f849c` | `#a89984` | `#717171` | Text of an inactive-but-clickable element. | **nothing today** — the inactive tab label reads `term_tab_inactive_fg` |
| `ui_text_muted` | `#565f89` | `#6c7086` | `#928374` | `#969696` | Disabled text, placeholder text, group headings -- present but not readable as content. | gtk3:172,174; zathura:37; qt6ct disabled idx0/6/7/8/13/19/20 |
| `ui_on_accent` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | Text/glyphs drawn ON TOP of a full-strength accent or semantic fill. Never a surface. | gtk3:204,208,212,216; gtk4:221,225,229,233; kitty-colors:19,28; kitty-scheme.conf:62; zathura:39 |
| `ui_doc_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | `#1c1c1c` | The page of a recoloured document (what zathura turns white paper into). | zathura:20 |
| `ui_doc_fg` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#e8e8e8` | The ink of a recoloured document. | zathura:21 |
| `ui_selection_disabled` | `#292e42` | `#313244` | `#504945` | `#3a3a3a` | Selection fill inside a DISABLED widget: present but must not shout. | qt6ct:64 idx12 |

**Three of these rows have no reader, and that is not an oversight.**
`ui_bg_dim`, `ui_border_dim` and `ui_text_dim` name the *general* "dimmed
chrome" idea; the only place the desktop currently expresses it is kitty, and
kitty got its own `term_` twins — `term_tab_bg`, `term_border_inactive`,
`term_tab_inactive_fg` — precisely so a scheme can dim a terminal tab bar
without dimming every strip on the desktop. The templates were written from
§5.3 and read the `term_` names, so `kitty-colors.conf:18,22,23` and
`kitty-scheme.conf:59,64,65,66` belong to those three and appear against them in
§1.2, not here. Verify with `grep -rn ui_bg_dim matugen/` — no hit.

The three `ui_*_dim` roles stay in the vocabulary anyway: every scheme already
fills them, dropping them would be a breaking change to all three files, and
the first non-terminal dimmed strip this desktop grows is the reader they were
named for.

### 1.2 terminal — the sixteen ANSI slots plus fg/bg/cursor/selection

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | Windows 11 Dark | meaning | consumed at |
|---|---|---|---|---|---|---|
| `term_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | `#0c0c0c` | Terminal background. | kitty-scheme.conf:49 |
| `term_fg` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#cccccc` | Default terminal text. | kitty-scheme.conf:48 |
| `term_cursor` | `#c0caf5` | `#f5e0dc` | `#ebdbb2` | `#ffffff` | Cursor block colour (fallback; matugen overrides with primary). | kitty-scheme.conf:53 |
| `term_cursor_text` | `#1a1b26` | `#1e1e2e` | `#282828` | `#0c0c0c` | The character under the cursor block. | kitty-scheme.conf:54 |
| `term_selection_bg` | `#283457` | `#585b70` | `#504945` | `#3a3d41` | Selection fill (fallback; matugen overrides with primary). | kitty-scheme.conf:51 |
| `term_selection_fg` | `#c0caf5` | `#1e1e2e` | `#282828` | `#ffffff` | Text inside the selection, over term_selection_bg. | kitty-scheme.conf:50 |
| `term_url` | `#73daca` | `#94e2d5` | `#8ec07c` | `#4cc2ff` | Underlined URL (fallback; matugen overrides with tertiary). | kitty-scheme.conf:56 |
| `term_border_inactive` | `#292e42` | `#45475a` | `#504945` | `#2f2f2f` | Border of an unfocused kitty split. | kitty-scheme.conf:59 (no longer = ui_border_dim: upstream publishes `inactive_border_color #292e42`) |
| `term_tab_bg` | `#16161e` | `#181825` | `#1d2021` | `#202020` | Tab bar background and inactive tab background. | kitty-colors:29, kitty-scheme.conf:65,66 |
| `term_tab_inactive_fg` | `#545c7e` | `#7f849c` | `#a89984` | `#969696` | Label of an inactive tab. | kitty-colors:30, kitty-scheme.conf:64 |
| `term_bell_border` | `#e0af68` | `#f9e2af` | `#fabd2f` | `#fce100` | Border flash when a window rings the bell. | kitty-scheme.conf:60 |
| `term_black` | `#15161e` | `#45475a` | `#282828` | `#0c0c0c` | ANSI slot color0. | kitty-scheme.conf:69; inherited by ranger, fzf (--color=16), and every TUI |
| `term_red` | `#f7768e` | `#f38ba8` | `#cc241d` | `#c50f1f` | ANSI slot color1. | kitty-scheme.conf:72; inherited by ranger, fzf (--color=16), and every TUI |
| `term_green` | `#9ece6a` | `#a6e3a1` | `#98971a` | `#13a10e` | ANSI slot color2. | kitty-scheme.conf:75; inherited by ranger, fzf (--color=16), and every TUI |
| `term_yellow` | `#e0af68` | `#f9e2af` | `#d79921` | `#c19c00` | ANSI slot color3. | kitty-scheme.conf:78; inherited by ranger, fzf (--color=16), and every TUI |
| `term_blue` | `#7aa2f7` | `#89b4fa` | `#458588` | `#0037da` | ANSI slot color4. | kitty-scheme.conf:81; inherited by ranger, fzf (--color=16), and every TUI |
| `term_magenta` | `#bb9af7` | `#f5c2e7` | `#b16286` | `#881798` | ANSI slot color5. | kitty-scheme.conf:84; inherited by ranger, fzf (--color=16), and every TUI |
| `term_cyan` | `#7dcfff` | `#94e2d5` | `#689d6a` | `#3a96dd` | ANSI slot color6. | kitty-scheme.conf:87; inherited by ranger, fzf (--color=16), and every TUI |
| `term_white` | `#a9b1d6` | `#bac2de` | `#a89984` | `#cccccc` | ANSI slot color7. | kitty-scheme.conf:90; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_black` | `#414868` | `#585b70` | `#928374` | `#767676` | ANSI slot color8. | kitty-scheme.conf:70; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_red` | `#ff899d` | `#f38ba8` | `#fb4934` | `#e74856` | ANSI slot color9. | kitty-scheme.conf:73; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_green` | `#9fe044` | `#a6e3a1` | `#b8bb26` | `#16c60c` | ANSI slot color10. | kitty-scheme.conf:76; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_yellow` | `#faba4a` | `#f9e2af` | `#fabd2f` | `#f9f1a5` | ANSI slot color11. | kitty-scheme.conf:79; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_blue` | `#8db0ff` | `#89b4fa` | `#83a598` | `#3b78ff` | ANSI slot color12. | kitty-scheme.conf:82; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_magenta` | `#c7a9ff` | `#f5c2e7` | `#d3869b` | `#b4009e` | ANSI slot color13. | kitty-scheme.conf:85; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_cyan` | `#a4daff` | `#94e2d5` | `#8ec07c` | `#61d6d6` | ANSI slot color14. | kitty-scheme.conf:88; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_white` | `#c0caf5` | `#a6adc8` | `#ebdbb2` | `#f2f2f2` | ANSI slot color15. | kitty-scheme.conf:91; inherited by ranger, fzf (--color=16), and every TUI |

**Tokyo Night's six bright chromatics are NOT repeats of the normal ones**, and
this table said they were until the file was checked against upstream. The
plugin derives them (`lua/tokyonight/colors/init.lua`, `colors.terminal`) with
`Util.brighten` — HSLuv lightness +5, saturation +20 — and publishes the result
in `extras/kitty/tokyonight_night.conf` as `color9`-`color14`. The repeats in
this repository came from `kitty.conf`'s own literals, which is a fact about
the desktop's history and not about the palette. `color0`/`color8` and
`color7`/`color15` are the exception: those four are `black`, `terminal_black`,
`fg_dark` and `fg`, four separate palette entries rather than a brightened pair.

**`term_selection_fg` got its reader**, and the one word it took is worth
keeping written down. `kitty-scheme.conf` painted `selection_foreground` from
`ui_on_accent`, which was right while that role tracked the on-accent colour
and stopped being right once `term_selection_fg` carried upstream's own
`selection_foreground` (`#c0caf5`, light text on the dark `bg_visual` fill).
The pair the template rendered — `ui_on_accent` `#1a1b26` on
`term_selection_bg` `#283457` — grades 1.40:1; the pair it renders now grades
7.57:1. It never showed on a working desktop, because `kitty-colors.conf`
overrides both halves with the wallpaper accent, which is exactly why a
measurement rather than a look is what found it. `ui_on_accent` keeps its other
reader in that file (`:62`, the active tab's label over an `fb_primary` fill:
6.79:1 Tokyo Night, 7.79:1 Catppuccin, 5.48:1 Gruvbox).

### 1.3 semantic

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | Windows 11 Dark | meaning | consumed at |
|---|---|---|---|---|---|---|
| `sem_warning` | `#e0af68` | `#f9e2af` | `#fabd2f` | `#fce100` | 'Watch out'. Never harmonised with the wallpaper. | gtk3:210,211; gtk4:227,228; zathura:54; Theme.qml:251; cship x6 |
| `sem_on_warning` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | Text on a sem_warning fill. | gtk3:212; gtk4:229; zathura:55 |
| `sem_critical` | `#f7768e` | `#f38ba8` | `#fb4934` | `#ff99a4` | 'Something is wrong'. Also GTK's destructive_* and error_*, and Qt BrightText. | gtk3:202,203,214,215; gtk4:219,220,231,232; zathura:56; qt6ct idx7; Theme.qml:252; cship x4 |
| `sem_on_critical` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | Text on a sem_critical fill. | gtk3:204,216; gtk4:221,233; zathura:57; Theme.qml:253 |
| `sem_success` | `#9ece6a` | `#a6e3a1` | `#b8bb26` | `#6ccb5f` | 'It worked'. | gtk3:206,207; gtk4:223,224 |
| `sem_on_success` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | Text on a sem_success fill. | gtk3:208; gtk4:225 |
| `sem_info` | `#7dcfff` | `#89dceb` | `#83a598` | `#4cc2ff` | Nominal / informational reading -- the low end of a warn/critical ramp. | cship.toml:44,55 |

GTK's `destructive_*` and `error_*` sets are the same colour in both templates
today; both map to `sem_critical` / `sem_on_critical`. There is no separate
`sem_error` role — adding one would let a scheme make "delete this" and "this
failed" different colours, which nothing currently wants.

### 1.4 accent fallback — the 17 Material 3 roles, pre-matugen

They were written as the shell's fallback for a fresh clone or a malformed
`colors.json`, and that is still what the `meaning` column below describes --
but it is no longer all they are, and it is not how the shell reads them. See
the two paragraphs under the table.

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | Windows 11 Dark | meaning | consumed at |
|---|---|---|---|---|---|---|
| `fb_surface` | `#1a1b26` | `#1e1e2e` | `#282828` | `#202020` | M3 surface fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:140 |
| `fb_surface_container` | `#292e42` | `#313244` | `#3c3836` | `#2b2b2b` | M3 surface_container fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:141 |
| `fb_surface_container_high` | `#353b55` | `#45475a` | `#504945` | `#333333` | M3 surface_container_high fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:142 |
| `fb_surface_container_highest` | `#414868` | `#585b70` | `#665c54` | `#454545` | M3 surface_container_highest fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:143 |
| `fb_on_surface` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#ffffff` | M3 on_surface fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:144 |
| `fb_on_surface_variant` | `#a9b1d6` | `#bac2de` | `#bdae93` | `#cccccc` | M3 on_surface_variant fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:145 |
| `fb_outline` | `#565f89` | `#6c7086` | `#7c6f64` | `#969696` | M3 outline fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:146 |
| `fb_outline_variant` | `#3b4261` | `#45475a` | `#504945` | `#2f2f2f` | M3 outline_variant fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:147 |
| `fb_primary` | `#7aa2f7` | `#89b4fa` | `#83a598` | `#4cc2ff` | M3 primary fallback, used only until matugen writes colors.json. | kitty-scheme.conf:58,63 (kitty's active border and tab); mirrored at Theme.qml:149 |
| `fb_on_primary` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | M3 on_primary fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:150 |
| `fb_primary_container` | `#3d59a1` | `#45475a` | `#458588` | `#0067c0` | M3 primary_container fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:151 |
| `fb_on_primary_container` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#ffffff` | M3 on_primary_container fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:152 |
| `fb_secondary` | `#bb9af7` | `#cba6f7` | `#d3869b` | `#3a96dd` | M3 secondary fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:154 |
| `fb_secondary_container` | `#414868` | `#585b70` | `#665c54` | `#003e92` | M3 secondary_container fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:155 |
| `fb_on_secondary_container` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | `#ffffff` | M3 on_secondary_container fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:156 |
| `fb_tertiary` | `#73daca` | `#f5c2e7` | `#fe8019` | `#61d6d6` | M3 tertiary fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:158 |
| `fb_on_tertiary` | `#1a1b26` | `#1e1e2e` | `#282828` | `#000000` | M3 on_tertiary fallback, used only until matugen writes colors.json. | **no reader** — mirrored as a `??` literal at Theme.qml:159 |

**ONE OF THE SEVENTEEN HAS A READER, and this paragraph used to claim all of
them did.** It did, for as long as `desktop-scheme accent` existed: that
setting built the matugen accent import out of this block, stripping the `fb_`
prefix and handing the seventeen over as the Material 3 roles, so on `accent
scheme` they were not a fallback at all but the live accent of the desktop.
That subcommand is gone — the argument is in the note above `accent_args` in
`desktop-scheme`, and what replaced it snaps the wallpaper's own colour onto
the scheme's twelve ANSI chromatics instead, which is a different set of roles.
So the block that fed it feeds nothing.

The exception is `fb_primary`, read by `kitty-scheme.conf:58,63`, where the
active border and the active tab want the scheme's own accent rather than the
wallpaper's — and by `scheme-accent.py`'s reasoning, though not its code: it is
the colour that argues the six bright chromatics into the candidate list, since
Gruvbox's `fb_primary #83a598` is one of them.

**The other sixteen stay, and they are not dead weight.** They are the
published answer to "what does this scheme look like before matugen has run",
which is the question `Theme.qml`'s `??` literals also answer — see the next
paragraph — and they are what a second reader of that question would read
rather than re-deriving. What they are NOT any more is consumed, and the column
above says so rather than pointing at a file that mirrors them.

**What does NOT read them is `Theme.qml`, and that is a decision rather than a
gap.** Its fallbacks stay literals because nothing hands this block to the
shell: `schemes/` lives in the checkout, not under `Quickshell.shellPath()`,
and the shell's only route to it is running `desktop-scheme list`
(`AppearancePage.qml:66`). A read would be that process or a path climbing out
of the shell root, both asynchronous, so a literal would still be needed
underneath each one. The rule written at `Theme.qml:96-122` is what keeps the
two sides honest instead: every `??` literal in that file must be a value of
`schemes/tokyo-night.json` — the `fb_*` role of the same name, or the `sem_*`
one for the three alerts — and tokyo-night is the right scheme to copy because
it is the one in force wherever the fallback can be seen (`desktop-scheme`
answers `DEFAULT_SCHEME` when its state file says nothing, and any other scheme
was selected through `desktop-scheme set`, which leaves a `colors.json`
behind). Two literals had drifted off that rule and were corrected with it:
`surface_container_high` read `#343a52` and `tertiary` read `#e0bbdd`, which is
in no scheme file and no Tokyo Night palette.

### 1.5 accent — the 17 Material 3 role NAMES, and the nine still filled from the wallpaper

**The heading used to say "the 17 the templates already consume", and the count
is now the wrong shape rather than the wrong number.** All seventeen names are
still live and the vocabulary still has to stay clear of every one of them —
that is what this section is for, and it is why the prefixes exist. What
changed is where eight of the values come from.

Rows 9 to 17 are the accent proper: matugen derives them from the wallpaper on
every change, and every template that reads a `{{colors.<name>}}` without a
prefix reads one of these nine.

Rows 1 to 8 are **surfaces, text and outlines, and they are the scheme's now.**
matugen still derives roles by those names — they are in the render, and a
template could still name one — but nothing does. `quickshell-colors.json`
emits the eight keys under their M3 spelling, because that is the vocabulary
`Theme.qml` reads, and fills each from a `ui_*` role: `ui_surface`,
`ui_surface_container`, `ui_surface_container_high`,
`ui_surface_container_highest`, `ui_text`, `ui_text_variant`, `ui_text_muted`,
`ui_border_dim`, in that order. The `template reference` column below names the
line that does the filling; the M3 name is what comes out the other side. Why
the shell stopped taking its surfaces from the image is argued in that file's
`_policy`, and the four-rung ladder those first four became is in 4.4.

The canonical list is `quickshell-colors.json:11-40`, and `Theme.qml:140-159`
declares exactly one reader per key:

| # | matugen role | template reference | read by |
|---|---|---|---|
| 1 | `surface` | `quickshell-colors.json:11` (from `ui_surface`) | `Theme.qml:140` |
| 2 | `surface_container` | `quickshell-colors.json:12` (from `ui_surface_container`) | `Theme.qml:141` |
| 3 | `surface_container_high` | `quickshell-colors.json:13` (from `ui_surface_container_high`) | `Theme.qml:142` |
| 4 | `surface_container_highest` | `quickshell-colors.json:14` (from `ui_surface_container_highest`) | `Theme.qml:143` |
| 5 | `on_surface` | `quickshell-colors.json:15` (from `ui_text`) | `Theme.qml:144` |
| 6 | `on_surface_variant` | `quickshell-colors.json:16` (from `ui_text_variant`) | `Theme.qml:145` |
| 7 | `outline` | `quickshell-colors.json:17` (from `ui_text_muted`) | `Theme.qml:146` |
| 8 | `outline_variant` | `quickshell-colors.json:18` (from `ui_border_dim`) | `Theme.qml:147` |
| 9 | `primary` | qs:30, gtk3:164,185,186, gtk4:202,203, qt6ct:57, kitty-colors:16,20,24,27, hypr:9, niri:41, ranger-accent:12, zen:28, zathura:38,49, fastfetch:41 | everything |
| 10 | `on_primary` | qs:31, gtk3:165,187, gtk4:204, qt6ct:57 | GTK, Qt, shell |
| 11 | `primary_container` | qs:32, qt6ct:70 | Qt inactive selection, shell |
| 12 | `on_primary_container` | qs:33, qt6ct:70 | Qt inactive selection, shell |
| 13 | `secondary` | qs:35, qt6ct:57,70 (LinkVisited) | Qt, shell |
| 14 | `secondary_container` | `quickshell-colors.json:36` | `Theme.qml:155` |
| 15 | `on_secondary_container` | `quickshell-colors.json:37` | `Theme.qml:156` |
| 16 | `tertiary` | qs:39, qt6ct:57,70 (Link), kitty-colors:22, hypr:10, niri:41, ranger-accent:13, zathura:48, fastfetch:42 | second accent everywhere |
| 17 | `on_tertiary` | `quickshell-colors.json:40` | `Theme.qml:159` |

M3's `error` / `on_error` are deliberately **not** passed through
(`quickshell-colors.json:42`): an alert tinted by the wallpaper loses the one
thing it carries. That is why `sem_*` exists — and now that the alerts are
`sem_warning` / `sem_critical` / `sem_on_critical` in that same file, the rule
is no longer "an alert is a literal" but "an alert is the scheme's".

---

## 2. The collision table

Same hex, different meanings. This is the part that decides the vocabulary.

**Every hex below is a literal that WAS in this repository's templates**, not a
claim about Tokyo Night. The distinction matters in 2.7, 2.8 and 2.9, where a
normal and a bright ANSI slot are counted as one colour: they shared a hex in
`kitty.conf`, and upstream publishes them apart (see the note under 1.2). The
collisions those rows argue for are still real — the vocabulary needs
`sem_warning` separate from `term_yellow` however Gruvbox or Tokyo Night
happens to fill them — but the count in the heading is a count of what was
written here, and it is now higher than one for the pairs concerned.

**AND "WAS" IS NOW THE WHOLE OF IT: not one of these hexes is still a literal
in a template.** The substitution in section 5 has happened, so every
occurrence counted in a heading below is a `{{colors.<role>}}` today and the
count is the record of the survey rather than something `grep` will agree with.
The `file:line` citations in the tables have been carried forward to where each
site now lives, because a site is a place in the desktop and it did not stop
existing; the totals have not, because a total is a measurement and re-running
it against a tree with no literals in it would only say zero. What each row is
evidence FOR — that one hex was doing four unrelated jobs and needed four names
— is exactly as true as it was, and is the reason the roles above exist.

### 2.1 `#1a1b26` — 46 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| window / chrome background | gtk3:58,86,89,109,111,119,147,160,171; gtk4:114,136,139,160,162,170,172,180; zathura:28; zen-scheme.css:33,34,35; qt6ct idx10 (`#ff1a1b26`, lines 57,64,70); kitty-scheme.conf:49 | `ui_bg` / `term_bg` / `fb_surface` |
| **text drawn ON TOP of an accent or semantic fill** | gtk3:204,208,212,216; gtk4:221,225,229,233; kitty-colors:19,28; kitty-scheme.conf:54,62; Theme.qml:150,159,253 | `ui_on_accent`, `sem_on_*`, `fb_on_primary`, `fb_on_tertiary`, `term_cursor_text` |
| alternating table row / Qt NoRole | qt6ct idx16 and idx17 (lines 51,58,64) | `ui_bg_alt_row` (idx16), `ui_bg` (idx17) |
| the page of a recoloured PDF | zathura:20 (`recolor-lightcolor`) | `ui_doc_bg` |

This is the headline collision. A scheme that wants deeper contrast under
alerts can set `sem_on_critical` to Catppuccin `crust` while leaving `ui_bg` at
`base`; today one hex forces them together. Note also that `term_bg` is split
out from `ui_bg` on purpose — a Gruvbox user conventionally runs the terminal at
`bg0_h`, one step under the desktop.

### 2.2 `#15161e` — 13 occurrences, **five** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| ANSI black (`color0`) | kitty-scheme.conf:69 | `term_black` |
| Qt `Base` — field and list background | qt6ct idx9 (`#ff15161e`, lines 51,58,64) | `ui_bg_field` |
| Qt `Dark` — bevel shading | qt6ct idx4 (lines 51,58,64) | `ui_bevel_dark` |
| secondary bar / strip | zathura:30,32,36,52 | `ui_bg_bar` |
| **text ON an accent or semantic fill** | zathura:39,55,57 | `ui_on_accent`, `sem_on_warning`, `sem_on_critical` |

The last row is a **live inconsistency**: everywhere else the on-accent colour
is `#1a1b26`, but zathura uses `#15161e`. Recommended split assigns those three
sites to the shared on-accent roles, which changes their rendered value by 5
levels. Deliberate unification; see **Decisions taken**.

`ui_bg_bar` vs `ui_bg_field` looks over-fine in Tokyo Night (both `#15161e`) but
earns its keep in Gruvbox, where the idiom is a **lighter** statusbar (`bg1`)
over a **darker** field (`bg0_h`). Keep them apart.

### 2.3 `#c0caf5` — 37 occurrences, **six** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| primary text on a surface | gtk3 x12, gtk4 x9, zathura:29,31,33,35,53, qt6ct idx0/6/8/19, fastfetch:49 | `ui_text` |
| ANSI bright white (`color15`) | kitty-scheme.conf:91 | `term_bright_white` |
| terminal cursor colour | kitty-scheme.conf:53 | `term_cursor` |
| text on a *container* accent | Theme.qml:152, Theme.qml:156 | `fb_on_primary_container`, `fb_on_secondary_container` |
| document ink | zathura:21 (`recolor-darkcolor`) | `ui_doc_fg` |
| placeholder text at 50% (`#80c0caf5`) | qt6ct idx20, lines 51,64 | `ui_text` with the alpha kept in the template |

Catppuccin makes the second row matter: its published `color15` is `subtext0`
(`#a6adc8`), which is *darker* than `color7`. Fusing `term_bright_white` into
`ui_text` would silently overrule the scheme's own terminal spec.

### 2.4 `#414868` — 9 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| divider / frame (GTK `borders`, `headerbar_border_color`, `unfocused_borders`) | gtk3:88,130,166; gtk4:138,191 | `ui_border` |
| Qt `Light` — lit edge of the bevel | qt6ct idx2 (lines 51,58,64) | `ui_border` |
| ANSI bright black (`color8`) | kitty-scheme.conf:70 | `term_bright_black` |
| M3 `surface_container_highest` and `secondary_container` | Theme.qml:143,155 | `fb_surface_container_highest`, `fb_secondary_container` |

Gruvbox proves this split is real: its `color8` is `gray #928374` while its
natural border step is `bg3 #665c54` — two clearly different colours that Tokyo
Night happens to spell the same.

The disabled Qt list (line 58) also uses `#ff414868` at idx14 and idx15 (Link
and LinkVisited, dimmed) — three further sites for `ui_border`.

### 2.5 `#565f89` — 5 occurrences, **two** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| disabled / placeholder / group-heading text | gtk3:172,174; zathura:37; qt6ct:64 idx0,6,7,8,13,19,20 | `ui_text_muted` |
| M3 `outline` | Theme.qml:146 | `fb_outline` |

Worth noting on its own: the desktop currently has **two different "outline"
colours** — GTK's `borders` at `#414868` and quickshell's M3 `outline` at
`#565f89`. Kept apart in the vocabulary (`ui_border` vs `fb_outline`) because
one belongs to the fixed base and the other is an M3 fallback, but a scheme
author should know they are meant to look like the same kind of line.

### 2.6 `#292e42` — 11 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| card / popover / tooltip / completion menu | gtk3:115,122,125; gtk4:176,183,186; zathura:34; qt6ct idx18 (lines 51,58,64) | `ui_bg_raised` |
| Qt `Button` face | qt6ct idx1 (lines 51,58,64) | `ui_bg_button` |
| **selection fill inside a disabled widget** | qt6ct:64 idx12 | `ui_selection_disabled` |
| M3 `surface_container` | Theme.qml:141 | `fb_surface_container` |

Row 3 is a fill, not a surface — it stands where the accent stands in the other
two colour groups. A scheme that wants a dimmed selection to keep a hint of hue
needs it separable.

### 2.7 `#e0af68` — 15 occurrences, **three** distinct meanings

`sem_warning` (gtk3:210,211; gtk4:227,228; zathura:54; Theme.qml:251; cship.toml
:45,:46,:57,:65,:74,:80) · `term_yellow` + `term_bright_yellow`
(kitty-scheme.conf:78,79) · `term_bell_border` (kitty-scheme.conf:60).

Gruvbox splits these: `sem_warning` and `term_bright_yellow` are `#fabd2f`, but
`term_yellow` is `#d79921`. Collapsing warning onto the ANSI slot would make it
a different colour depending on which of the two Gruvbox yellows was chosen.

### 2.8 `#f7768e` — 17 occurrences, **four** distinct meanings

`sem_critical` (gtk3:202,203,214,215; gtk4:219,220,231,232; zathura:56;
Theme.qml:252; cship.toml:47,59,67,76) · Qt `BrightText` (qt6ct idx7, lines 51,64)
· `term_red` and `term_bright_red` (kitty-scheme.conf:72,73). Same Gruvbox argument
as 2.7 (`#cc241d` vs `#fb4934`).

Qt `BrightText` is genuinely "the watch-out text colour", so mapping it to
`sem_critical` is correct rather than a compromise.

### 2.9 `#9ece6a` / `#7aa2f7` / `#bb9af7` / `#7dcfff`

| hex | meanings | roles |
|---|---|---|
| `#9ece6a` (6) | success fill (gtk3:206,207; gtk4:223,224); ANSI green pair (kitty-scheme.conf:75,76) | `sem_success`, `term_green`, `term_bright_green` |
| `#7aa2f7` (5) | accent fallback (kitty-scheme.conf:58,63; Theme.qml:149); ANSI blue pair (kitty-scheme.conf:81,82) | `fb_primary`, `term_blue`, `term_bright_blue` |
| `#bb9af7` (3) | ANSI magenta pair (kitty-scheme.conf:84,85); M3 secondary fallback (Theme.qml:154) | `term_magenta`, `term_bright_magenta`, `fb_secondary` |
| `#7dcfff` (4) | ANSI cyan pair (kitty-scheme.conf:87,88); cship "nominal" style (cship.toml:44,55) | `term_cyan`, `term_bright_cyan`, `sem_info` |

### 2.10 `#16161e` vs `#15161e` — one level apart, different roles

`#16161e` (kitty tab bar and inactive tab, `kitty-colors.conf:22`,
`kitty-scheme.conf:65,66`) and `#15161e` (fields, bars, ANSI black) differ by a
single level and are visually the same colour today. They stay separate
(`term_tab_bg` vs `ui_bg_field` / `ui_bg_bar` / `term_black`) because Catppuccin
would put the tab bar at `mantle` and ANSI black at `surface1` — nowhere near
each other.

### 2.11 Same role spelled differently — unify

* **ARGB vs RGB.** `qt6ct-colors.conf` writes `#AARRGGBB` with alpha first
  (documented at `qt6ct-colors.conf:15-17`). Every `#ffXXXXXX` is the same role
  as the bare `#XXXXXX`: `#ff1a1b26` (9) = `#1a1b26`, `#ffc0caf5` (8) =
  `#c0caf5`, `#ff292e42` (7), `#ff15161e` (6), `#ff565f89` (6), `#ff414868` (5),
  `#ff0d0e14` (3), `#ff1f2335` (3), `#ff363b54` (3), `#fff7768e` (2). Substitute
  as `#ff{{colors.<role>.default.hex_stripped}}`.
* **The two 50% entries.** `#80c0caf5` (idx20, lines 51 and 64) and `#80565f89`
  (idx20, line 58) are `ui_text` and `ui_text_muted` at half alpha. The alpha
  belongs in the template, not in a new role:
  `#80{{colors.ui_text.default.hex_stripped}}`.
* **`#0d0e14`, `#1f2335`, `#363b54`** exist in code *only* in ARGB form; their
  bare spellings at `qt6ct-colors.conf:41,35,33` are inside the index comment.
* **Duplicated pairs inside one block.** GTK defines `destructive_color` and
  `destructive_bg_color` (and the same for success / warning / error) as the
  same value — 8 pairs across the two templates. One role each; do not invent a
  `*_fg`-only variant.

### 2.12 Deliberately NOT a role

* `#000000` at `Theme.qml:462` (`screenBezel`). The comment at lines 428-432
  states the reason: it stands in for the panel bezel, and a bezel does not
  change colour with the theme. Leave hardcoded.
* `rgba(0,0,0,0.15|0.18|0.36|0.5)` shade and scrim values in both GTK
  templates (gtk3:90,113,117,128,129; gtk4:140,164,173,174,178,189,190) are
  alpha-on-black, not palette entries. Out of scope unless a scheme wants tinted
  shadows; see **Decisions taken**, which rules one out.
* The seven comment-only literals — `#101010`, `#171717` (x2), `#1b1b1b`,
  `#1c1c1c` (userChrome.css:87,88,98), `#28282c` (gtk3:96, gtk4:168),
  `#222226` / `#2e2e32` (gtk4:106) — document *upstream defaults being
  overridden*. They must stay as prose.

---

## 3. Scheme files

Was three filled JSON blocks in the working document. They are files now: the
`*.json` beside this README are the authority, and `desktop-scheme list` is how
you find out which exist. Section 4 is the record of what filling the
vocabulary taught: 4.1 to 4.4 are the three-scheme pass and are left in the
tense they were written in, and **4.5 is the fourth**, which is the one to read
beside them before writing a fifth. Where the fourth contradicts a verdict of
the first three, the note saying so is under the verdict rather than folded
into it.

---

## 4. Validation pass — filling the vocabulary four times

### 4.1 Roles that cannot be filled from a scheme's own palette

Four, in descending severity.

**(a) `fb_primary_container` / `fb_on_primary_container` — Catppuccin Mocha
cannot fill this.** Material 3 "container" roles are a *muted tint of the
accent*: Tokyo Night has `blue0 #3d59a1`, a genuine dark blue, and Gruvbox has
its dark/bright pairs (`#458588` under `#83a598`) so it fills cleanly too.
Catppuccin Mocha publishes no darkened variant of any accent — `sapphire` and
`lavender` are *brighter* neighbours, not darker ones. The fill above uses
`surface1 #45475a`, a neutral, which loses the hue. Visible where: qt6ct's
`inactive_colors` selection (`qt6ct-colors.conf:64`, "the selection drops to
primary_container so a glance tells you which window has focus") would go grey
instead of muted-blue, and quickshell's `primaryContainer` fallback the same.
Both are matugen-driven at runtime, so the fallback only shows on a fresh
clone — which is why this is reported rather than treated as a blocker.
The alternative is to invent a colour by darkening `blue`, which this vocabulary
rules out.

**(b) `ui_bg_shadow` — neither other scheme has a step below its darkest
surface.** Tokyo Night does: `bg_dark1 #0c0e14`, the one entry `night.lua` adds
that `storm.lua` does not already carry. It used to be filled with `#0d0e14`, a
near-miss of that published value with nothing behind it. Mocha bottoms out at `crust #11111b`, which is
already spent on `ui_bg_view`; Gruvbox bottoms out at `bg0_h #1d2021`, which is
spent on three roles at once. Both fills therefore repeat. The role is kept
because Qt's palette has a mandatory `Shadow` slot (`qt6ct-colors.conf:41`,
index 11) that must be *some* colour, but the vocabulary should document that
`ui_bg_shadow == ui_bg_view` is a legitimate fill, not a mistake. **All three
schemes now do it**, Tokyo Night included: below the window it publishes
`bg_dark #16161e`, `black #15161e` and `bg_dark1 #0c0e14` and nothing between
the last two, so the content pane and the Qt shadow share the floor.

**(c) `ui_bg_control` vs `ui_bg_raised` — a Tokyo-Night-only distinction.**
`#222534` (the Nautilus pill, `gtk4-colors.css:428`) sits deliberately between
`ui_bg #1a1b26` and `ui_bg_raised #292e42` — a step the gtk4 comment at
lines 408-424 argues for at length, and the one place in the base group where
Night publishes no tone at all, so it is `Util.blend(bg_highlight, 0.5, bg)`,
upstream's own mixing function on upstream's own two neighbours. It was
`#24283b` for a long time, which is **Storm's `bg`** — a colour from a
different variant of the theme. Mocha has nothing between `base #1e1e2e`
and `surface0 #313244`; Gruvbox has nothing between `bg0 #282828` and
`bg1 #3c3836`. Both fills collapse the pair onto one value. Verdict: the role
is too fine-grained for a general vocabulary but harmless — a scheme that
collapses it loses a distinction that is already near the threshold of
visibility.

**(d) `term_selection_bg` — Tokyo Night is the only one that publishes a
selection colour.** `bg_visual #283457` is a real Tokyo Night entry —
`Util.blend_bg(blue0, 0.4)` in `colors/init.lua`, published verbatim as
`selection_background` by the kitty, wezterm and ghostty extras. It was
`#33467c` here, which is the *old* upstream `bg_visual`: `colors.lua:141` at
tag `v1.0.0` reads `util.darken(colors.blue0, 0.7)`, which over Night's `bg` is
`#33467c` exactly. `v2.0.0` changed the factor to 0.4 and the answer to
`#283457`. This repository was carrying the v1 value. Catppuccin
and Gruvbox both leave selection to the terminal's own convention, so the fills
use a neutral surface step (`surface2` / `bg2`). That is a judgement call, not
an invented colour, and it barely matters: `kitty-colors.conf:13` overrides
`selection_background` with the wallpaper accent on every change, so the scheme
value is only seen before the first `wallpaper-switch`.

Everything else — all 27 base roles, all 27 terminal roles, all 7 semantic
roles, 15 of the 17 fallbacks — fills from published values in all three
palettes, with **two exceptions in Tokyo Night** where the palette has no tone
in the gap a Qt slot needs: `ui_bg_control` `#222534` and `ui_bevel_midlight`
`#353b55` (and `fb_surface_container_high`, which mirrors the latter). Both are
`Util.blend(x, 0.5, y)` — upstream's own mixing function — over the two
published neighbours the role sits between, so they are derived from the
palette rather than picked beside it. See "Tokyo Night is Night" below.

**The fourth scheme overturns three of these four, and confirms the fourth.**
Windows 11 Dark fills **(a)** properly — `SystemAccentColorDark1 #0067c0` and
`Dark2 #003e92` are genuine darkened variants of its accent, which is what an
M3 container role means and what Catppuccin could not supply. It fills **(b)**
properly too: `SolidBackgroundFillColorBaseAlt #0a0a0a` is a real step below
its darkest surface, so `ui_bg_shadow` does not have to repeat `ui_bg_view`.
And **(c)** is a real distinction for it as well — `ui_bg_control #323232` is
`ControlFillColorSecondary` and `ui_bg_raised #2c2c2c` is
`SolidBackgroundFillColorQuarternary`, two published constants rather than one
tone spent twice. Only **(d)** holds: Campbell publishes no selection colour
either, so `term_selection_bg` is a judgement fill in three schemes out of four.
The severity ordering in this section is therefore a fact about *those* three
palettes and not about the vocabulary. Details in 4.5.

### 4.2 Colours the palettes define that the vocabulary has no slot for

**Catppuccin Mocha.** Unused: `flamingo #f2cdcd`, `maroon #eba0ac`,
`peach #fab387`, `sapphire #74c7ec`, `lavender #b4befe`, `overlay2 #9399b2`.
Visible consequence: **none**. `peach` is the only one that stings — orange is
part of Catppuccin's identity — but ANSI has no orange slot and the three
accent positions come from the wallpaper, so there is nowhere it *could* go
without inventing a role no template reads. `rosewater #f5e0dc` is *not* in
this list: it is Catppuccin's published cursor colour and `term_cursor` exists
precisely so it can be used.

**Gruvbox Dark Medium.** Unused: `fg0 #fbf1c7`, `fg3 #bdae93` (used once, for
`fb_on_surface_variant`), the dark orange `#d65d0e`, and the `bg0_s #32302f`
soft variant. Visible consequence: **none**, with one caveat — Gruvbox's
orange pair is as much a signature as its aqua, and the only slot it reaches is
`fb_tertiary`. Since `tertiary` comes from the wallpaper in the live desktop,
a Gruvbox session would rarely show orange at all. That is a palette-identity
loss, not a functional gap, and fixing it would mean adding a role no template
consumes.

**Both.** Neither project publishes an "info" colour. `sem_info` is filled by
judgement in all three schemes (Tokyo Night `cyan`, Mocha `sky`, Gruvbox
`bright blue`). Settled under **Decisions taken**: the role stays.

**And the fourth scheme is the one that can cite it.** WinUI declares
`SystemFillColorAttentionBrush Color="{ThemeResource SystemAccentColorLight2}"`
in its dark dictionary, so Windows' informational colour *is* its accent and
`sem_info #4cc2ff` is a citation rather than a judgement. One scheme out of
four; the role stays for the same reason it stayed before.

### 4.3 Ladder depth: how the differences were resolved

| region | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | Windows 11 Dark | resolution |
|---|---|---|---|---|---|
| at or below the window | 4 steps: `0c0e14`, `15161e`, `16161e`, `1a1b26` | 3: `crust`, `mantle`, `base` | 2: `bg0_h`, `bg0` | 4: `0a0a0a`, `141414`, `1c1c1c`, `202020` | Keep 5 roles (`ui_bg_shadow`, `ui_bg_view`, `ui_bg_field`/`ui_bg_bar`/`ui_bevel_dark`, `ui_bg_dim`, `ui_bg`). All three repeat: Tokyo Night spends `bg_dark1` twice, Mocha repeats `mantle` 3x and `crust` 2x, Gruvbox repeats `bg0_h` 4x. Repeats are cheap; a missing name is not. |
| above the window | 2 published (`bg_highlight`, `terminal_black`) + 2 blended (`222534`, `353b55`) | 4: `surface0`, `surface1`, `surface2`, `overlay0` | 4: `bg1`, `bg2`, `bg3`, `bg4` | **11 distinct**, `242424` up to `454545` | Gruvbox and Mocha are the rich ones here; Tokyo Night publishes only two tones above the window and the other two are `Util.blend` midpoints of them. It is the *lower* half where the other two run out. |
| text ramp | 4: `c0caf5`, `a9b1d6`, `545c7e`, `565f89` | 5: `text`, `subtext1`, `subtext0`, `overlay1`, `overlay0` | 5: `fg1`, `fg2`, `fg3`, `fg4`, `gray` | 4, and they are one published ramp: `ffffff`, `cccccc`, `969696`, `717171` | Even, with one spare each. |
| ANSI 16 | **16 distinct** (the six bright chromatics are `Util.brighten` of the normals; `color8`/`color15` are `terminal_black` and `fg`, separate palette entries) | 10 distinct | **16 distinct** | **16 distinct** (Campbell) | Keep all 16 slots. Mocha is the one that fills slots with repeats; collapsing to 8 would flatten both Tokyo Night's brightened chromatics and Gruvbox's entire terminal identity. |

**One assumption the vocabulary deliberately does not bake in.** In Tokyo Night
the content view is *darker* than the window (`#0c0e14` under `#1a1b26`), and
`gtk4-colors.css:44-99` spends 50 lines defending that direction. Gruvbox's own
idiom is the opposite: `bg0` is the window and `bg1` is the *lighter* card. It
is still expressible — `bg0_h` is one step down — which is why the fill works,
but there is only one step of headroom. The role is therefore named
**`ui_bg_view`** and defined as "one clear step *away* from `ui_bg`", not
"sunken" or "darker". Consequence to record now: on **Gruvbox Dark Hard**
(`bg0 = #1d2021`) there is no darker step at all, and a hard-contrast scheme
would have to take `ui_bg_view` *lighter* than `ui_bg` — which the definition
allows and the name does not fight. Hard/soft variants are out of scope for the
first three schemes.

**Second assumption, kept on purpose.** `ui_bg_alt_row` equals `ui_bg` in all
three fills. Tokyo Night sets alternating table rows to the window colour, i.e.
no stripe (`qt6ct-colors.conf:46`), and reproducing "no stripe" faithfully
matters more than exercising the role. The role exists so a scheme *can*
disagree.

**Windows 11 Dark is the first scheme that is rich at BOTH ends**, which is why
its column is the one that reads oddly against the resolution column: that
column is the record of resolving a disagreement between three palettes and it
is left alone. Eleven separable tones above the window and four at or below it
mean the fourth scheme never has to repeat a value to fill a role — with the
three exceptions 4.5 names, and none of those is a repeat, they are values
Windows does not publish at all.

**What the counts above do NOT settle** is which four tones the shell's four
Material 3 surface levels take. That used to be decided here, once, for
everybody; it is decided per scheme now, in 4.4.

### 4.4 The shell's surface ladder: four roles, filled per scheme

`quickshell-colors.json` used to map M3's four surface levels with one global
rule — `ui_bg` → `ui_bg_raised` → `ui_bevel_midlight` → `ui_border` — and that
rule was reasoned for at length in the template itself. It got one thing right
and one thing wrong.

Right: **all three schemes really do have four separable tones above their
window, and only there**, which is what 4.3 counts. Below the window Tokyo
Night's four steps span 1.13:1 end to end and two of them (`#15161e`,
`#16161e`) differ by one bit of blue; Catppuccin's three span 1.22:1; Gruvbox's
two are not steps at all. No descending ladder survives in any scheme.

Wrong: the rule read **Qt bevel slots as if they were an elevation scale**, and
then handed Gruvbox's answer to the other two. Under Tokyo Night it painted the
shell in tones Tokyo Night does not use for surfaces at all — `ui_bevel_midlight
#353b55` is not upstream, it is the `Util.blend` this repository computed to
fill `QPalette::Midlight` (4.1(c)), and `ui_border #414868` is `terminal_black`,
which folke assigns to ANSI bright black and to dimmed foreground text and to no
surface anywhere in the theme. The shell rendered greys where Tokyo Night
renders blacks.

So the ladder became data: **`ui_surface`, `ui_surface_container`,
`ui_surface_container_high`, `ui_surface_container_highest`** (1.1), one set per
scheme, read straight through by `quickshell-colors.json:11-14`.

**What the shell paints with each level**, counted in the QML tree, because a
level's meaning is what its readers do with it and not what M3 calls it.

The `readers` column is the count as it stood when this was surveyed; the shell
has since split its shared widgets across the theme seam and today's exact-word
counts are 10, 6, **44** and **24**. The paths below have been carried forward
to where each site now lives — most of them are under `themes/genesis/`, which
is the half that draws — but the classification inside each cell was done by
hand, site by site, and has not been re-done. The proportions are what the
argument rests on, and nothing that moved changed a hover into a rest state.

| level | readers | what they are |
|---|---|---|
| `surface` | 10 | Every panel, always through `Theme.glass()`: `themes/genesis/bar/Bar.qml:197`, `themes/genesis/launcher/Launcher.qml:346`, `modules/settings/Settings.qml:116`, `themes/genesis/components/Popout.qml:78`, `themes/genesis/powermenu/PowerMenu.qml:190`, `themes/genesis/cheatsheet/Cheatsheet.qml:380`, `themes/genesis/notifications/Notifications.qml:314`, `themes/genesis/wallpaper/WallpaperCarousel.qml:428` |
| `surface_container` | 6 | The card on that panel: `themes/genesis/components/NotificationCard.qml:52` ("a step up the surface ladder from the panel behind it"), `themes/genesis/components/SettingsSection.qml:170`, `themes/genesis/island/Dashboard.qml:808`, `modules/settings/pages/UpdatesPage.qml:174`, `themes/genesis/cheatsheet/Cheatsheet.qml:432` (the one that is also a `Theme.glass()` call) |
| `surface_container_high` | 46 | **33 are a hover or focus fill, 23 of them literally `containsMouse ? this : "transparent"`.** The other 13 are at-rest fills: the bar's `components/Group.qml:31` pills — the one widget here with no theme half — `themes/genesis/bar/Bar.qml:395`, the launcher's search field `themes/genesis/launcher/Launcher.qml:374`, `themes/genesis/island/Island.qml:534-535`, `themes/genesis/powermenu/PowerMenu.qml:245`, `themes/genesis/components/NotificationCard.qml:95` |
| `surface_container_highest` | 25 | 9 more hover fills; the other 16 are `themes/genesis/components/Tooltip.qml:46`, the rail `components/VolumeSlider.qml:81` names and `themes/genesis/components/VolumeSlider.qml:55` draws, `themes/genesis/components/LevelMeter.qml:109` unlit ticks, the key chips — now one site, `themes/genesis/components/Chip.qml:95`, reached from `modules/settings/pages/KeybindsPage.qml:560` and `themes/genesis/components/BindRow.qml:90`, with `modules/settings/pages/InputPage.qml:488` still spelling the ternary inline — the field fills at `modules/settings/pages/NetworkPage.qml:685` / `modules/settings/pages/RecordingPage.qml:712`, and the island's `themes/genesis/island/ReplayControl.qml:64` / `themes/genesis/island/RecordControl.qml:47` rest states |

**Hence the one thing every scheme still agrees on: the ladder climbs.** Levels
3 and 4 are where this shell paints hover, and all three projects put their own
hover above their own ground — Tokyo Night's `CursorLine` is `bg_highlight`,
Catppuccin's `list.hoverBackground` is `surface0`, Gruvbox's `CursorLine` is
`bg1`. A descending ladder would turn every hover in the tree into a recess.
What the schemes disagree on is **where the ladder starts**, and that is the
datum the old rule had no way to express.

#### Tokyo Night — starts on the palette floor

Upstream is explicit, in `lua/tokyonight/colors/init.lua`: *"Popups and
statusline always get a dark background"*, `bg_popup = bg_dark`,
`bg_statusline = bg_dark`, and `styles.sidebars` / `styles.floats` both default
to `"dark"` in `lua/tokyonight/config.lua`. Chrome descends; state ascends.

| level | before | after | tone | where Tokyo Night uses it |
|---|---|---|---|---|
| `surface` | `#1a1b26` | **`#0c0e14`** | `bg_dark1` | The palette floor — the one entry `colors/night.lua` adds over `storm.lua`. **The one rung filled by position rather than by an upstream assignment**; see the note below. |
| `surface_container` | `#292e42` | **`#1a1b26`** | `bg` | `Normal`, `editor.background`, and — exactly the shell's case — the `normal` notification frame in `extras/dunst/tokyonight_night.dunstrc` |
| `surface_container_high` | `#353b55` | **`#292e42`** | `bg_highlight` | `CursorLine` / `CursorColumn`; kitty `inactive_tab_background`; yazi `hovered`; the menu-hover slot of `extras/slack`; dunst `critical` |
| `surface_container_highest` | `#414868` | **`#343a55`** | `blend_bg(fg_gutter, 0.8)` | `PmenuSel` and `PmenuMatchSel`; helix `ui.menu.selected`; **fuzzel `selection`**, i.e. the highlighted row of a launcher, which is what `Launcher.qml:546` paints from this level |

Both tones the old rule used are gone from the shell, and neither is a loss:
`#353b55` was never upstream, and upstream's real value for that rung is
`#343a55` — this repository was two levels off. `#414868` stays in the
vocabulary as `ui_border`, which is what it is.

**The judgement call, declared.** `bg_dark1 #0c0e14` is a published Night tone
but no highlight group in the theme uses it; grepping the repo's own resolved
dump (`extras/lua/tokyonight_night.lua`) finds it only on the palette line.
The tone upstream *does* paint panels with is `bg_dark #16161e` — and it sits
**2.5 L\* from `bg`**, which is how Tokyo Night itself separates a sidebar from
an editor. Tokyo Night can do that because it draws a border between them (VS
Code's `sideBar.border`); this shell's cards are borderless
(`themes/genesis/components/NotificationCard.qml:56-57` draws one only when the
notification is critical), so
tone is the only separator there is. `#16161e` at level 1 would have made every
card in the shell vanish into its panel. `#0c0e14` is the only Night tone that
leaves a full step under `bg`, and enkia's VS Code theme — which folke's README
names as the theme his port comes from — corroborates that Tokyo Night has an
overlay tier below the sidebar: `notifications.background` and
`peekViewResult.background` are `#101014`, within one L\* of it. That value is
not in folke's palette, and "Tokyo Night is Night, and only Night" under
**Decisions taken** is what keeps it out.

#### Catppuccin Mocha — the style guide names four tiers

`catppuccin/catppuccin`, `docs/style-guide.md`, "Background Colors" — four rows,
verbatim: `Background Pane` → `Base`; `Secondary Panes` → `Crust, Mantle`;
`Surface Elements` → `Surface 0, Surface 1, Surface 2`; `Overlays` → `Overlay 0,
Overlay 1, Overlay 2`. Chrome below base, elements above it. The ports agree:
`catppuccin/vscode` puts `activityBar` / `statusBar` / `titleBar` on `crust`,
`sideBar` on `mantle`, `editor` on `base`, and `list.hoverBackground` /
`list.activeSelectionBackground` on `surface0`; the KDE port puts
`[Colors:Window]` on mantle and `[Colors:View]` on base; `catppuccin/gtk` ships
`headerbar_bg_color` and `dialog_bg_color` as mantle with `window_bg_color` and
`card_bg_color` as base.

| level | before | after | tone | style-guide tier / port |
|---|---|---|---|---|
| `surface` | `#1e1e2e` | **`#11111b`** | `crust` | Secondary Panes; vscode `activityBar` / `statusBar` / `titleBar`, KDE `[WM] inactiveBackground` |
| `surface_container` | `#313244` | **`#1e1e2e`** | `base` | Background Pane; vscode `editor` / `menu` / `tab.active`, gtk `card_bg_color`, KDE `[Colors:View]` |
| `surface_container_high` | `#45475a` | **`#313244`** | `surface0` | Surface Elements; vscode `list.hoverBackground` (its comment: *"when hovering over the file tree"*), `list.activeSelectionBackground`, `input.background`, KDE `[Colors:Button]` |
| `surface_container_highest` | `#585b70` | **`#585b70`** | `surface2` | Surface Elements; vscode `menu.selectionBackground`, `dropdown.listBackground`, `panel.border`, `editorGroup.border` |

**Catppuccin has no Material 3 mapping of its own** — the org has no
`material` / `m3` / `compose` port, and `catppuccin/userstyles` PR #1833, "feat(lib):
introduce stub m3 color library", was closed unmerged with its own TODO still
reading *"Determine Catppuccin>Material3 color bindings"*. Three ports do consume
M3 role names and they contradict each other: `catppuccin/kvaesitso` and
`catppuccin/symfonium` ascend `crust → mantle → base → surface0`, while
`catppuccin/dankmaterialshell` runs the ladder backwards. Kvaesitso's is the only
four-step ascending ladder attested in the org — but its four tones are 3.4, 3.2
and 9.4 L\* apart, so two of its rungs would be invisible here. **The tier table
is the authority, not a port**, and one representative per tier is what this
ladder takes.

**The judgement call, declared.** Level 4 is `surface2` and not `surface1`, even
though `surface1` would be the even step. `surface1 #45475a` is also Catppuccin's
`ui_border_dim`, i.e. the shell's `outline_variant`, and
`themes/genesis/components/Tooltip.qml` fills with level 4 (`:46`) and borders
with `outlineVariant` (`:48`) — every tooltip's border would melt into its own
fill, in at least five places. Taking `surface2` instead costs an uneven top
rung (17.7 L\*) and **fixes** the reverse collision the old ladder had:
`outline_variant` no longer sits on `surface_container_high`, so the two borders
at `themes/genesis/components/SettingsSection.qml:110` and
`modules/settings/pages/UpdatesPage.qml:398` go from 1.00:1 to 1.38:1 under
Catppuccin. Both of those are the HOVER fill of a pill that is transparent at
rest, so the collision was only ever visible under the pointer.

#### Gruvbox Dark Medium — does not move

morhetz publishes no prose about which tone goes where, so the authority is
`colors/gruvbox.vim`'s own usage, and it is unambiguous. `Normal` is `bg0`;
`CursorLine`, `TabLine`, `SignColumn`, `ColorColumn`, `Folded`, `StatusLineNC`
and (in `ellisonleao/gruvbox.nvim`) `NormalFloat` are `bg1`; `Pmenu`,
`StatusLine` and `WildMenu` are `bg2`; `Visual` and `MatchParen` are `bg3`. The
VS Code port agrees where it fills at all — `tab.activeBackground` is `bg1`,
`list.hoverBackground` and `list.activeSelectionBackground` are `bg1` at 50%.

| level | before | after | tone | where Gruvbox uses it |
|---|---|---|---|---|
| `surface` | `#282828` | **`#282828`** | `bg0` | `Normal`, `editor.background`, every piece of VS Code chrome |
| `surface_container` | `#3c3836` | **`#3c3836`** | `bg1` | `CursorLine`, `TabLine`, `SignColumn`, `Folded`, `NormalFloat`, `tab.activeBackground` |
| `surface_container_high` | `#504945` | **`#504945`** | `bg2` | `Pmenu`, `StatusLine`, `WildMenu`, `scrollbarSlider` |
| `surface_container_highest` | `#665c54` | **`#665c54`** | `bg3` | `Visual`, `MatchParen` |

**Gruvbox is the scheme the old rule happened to fit**, which is why it was
never obvious the rule was a rule. It cannot start lower: `bg0_h #1d2021` and
`bg0_s #32302f` are alternative *values* for `bg0` selected by
`g:gruvbox_contrast_dark` (`colors/gruvbox.vim:89-91`, `:173-175`), never a
second surface, and 4.3 already records that Gruvbox has two steps at or below
its window rather than a ladder. Not one rendered byte moves under Gruvbox.
`sainnhe/gruvbox-material` does publish a `bg_dim #1b1b1b` below `bg0` and an
opt-in `float_style='dim'` — but that is a different palette (only `#282828` and
`#504945` survive from morhetz's) and adopting a tone from it would be the
Storm-inside-Night mistake again.

#### Windows 11 Dark — `x:Key="Default"` **is** the dark dictionary

The other three schemes are recreations of a palette a project published. This
one is read out of the source Windows itself ships:
`microsoft/microsoft-ui-xaml`, `controls/dev/CommonStyles/
Common_themeresources_any.xaml` (MIT). That file holds three
`ResourceDictionary` blocks — `x:Key="Default"`, `x:Key="Light"` and
`x:Key="HighContrast"` — and **`Default` is the DARK one**. It is not a
neutral base that `Light` and a missing `Dark` specialise; it is the dark
theme, and `Light` is the special case. `TextFillColorPrimary` is `#FFFFFF`
inside `Default` and `#E4000000` inside `Light`, which settles it in one line.
Reading `Default` as "the shared defaults" and then hunting for a `Dark` block
that does not exist is the classic Fluent recreation bug, and it produces a
palette that is half light theme. Every citation below is from that block and
from no other.

Windows has no "surface ladder" of its own to copy, because it does not
separate surfaces by tone the way this shell has to: it draws a 1px
`ControlStrokeColorDefault` line round almost everything and lets the tones sit
close. So the four rungs are chosen by **what the shell paints with each
level** — the classification at the top of 4.4 — and each one is filled with
the WinUI key that does that same job in Windows.

| level | before | after | tone | where Windows uses it |
|---|---|---|---|---|
| `surface` | — | **`#202020`** | `SolidBackgroundFillColorBase` | The window ground, and the **Mica fallback** — what a Mica window paints when transparency is off, on battery saver, or when it is deactivated. Every panel in this shell is a `Theme.glass()` call over the wallpaper, so the fallback of the Windows material that also samples the wallpaper is the right rung to stand on. |
| `surface_container` | — | **`#2b2b2b`** | `CardBackgroundFillColorDefault #0DFFFFFF`, flattened on level 1 | The fill of a Fluent **card** — literally the role level 2 has here (`NotificationCard.qml:52`, `SettingsSection.qml:170`, the dashboard sheet). |
| `surface_container_high` | — | **`#333333`** | `SolidBackgroundFillColorQuinary` | Windows' own fifth background tier, one step above the card. Level 3 is 33-of-46 a hover fill, and Windows brightens on hover (`ControlFillColorSecondary #15FFFFFF` over `ControlFillColorDefault #0FFFFFFF`) rather than dimming, so the direction is upstream's. |
| `surface_container_highest` | — | **`#454545`** | `ControlSolidFillColorDefault` | The one **opaque** control fill in the dictionary — the value Windows reaches for when a control cannot composite, which is exactly a tooltip, a slider rail or a key chip. **This is the one deviation from Windows verbatim; see below.** |

Rungs in L\*: **12.25 / 17.53 / 21.25 / 29.29 — 5.28, 3.71, 8.04.**

**The judgement call, declared: level 4 is `ControlSolidFillColorDefault
#454545` and not `SolidBackgroundFillColorSenary #373737`.** Senary is where
Windows' own background ramp ends, and Base → Quinary → Senary is the ladder a
faithful transcription would take. Its top rung is **1.82 L\***. That is fine
for Windows, which separates a tooltip from the surface under it with
`SurfaceStrokeColorFlyout` and a shadow rather than with tone; it is not fine
here, where level 4 is nine more hover fills on top of the tooltip and the
tooltip's own border is `outline_variant` (`Tooltip.qml:46` fills, `:48`
borders). A 1.82 L\* top rung would make every one of those a fill that does
not read as a fill. `#454545` is still a Windows constant out of the same
dictionary — it is not a lightened `#373737` — and taking it costs the ladder
its evenness (8.04 L\* against 3.71 below it) rather than its provenance. The
trade accepted: an uneven top rung, in exchange for level 4 being visible at
all.

**Second judgement call, declared: level 2 is the card fill flattened, not the
next background tier.** `SolidBackgroundFillColorTertiary #282828` is the tone
that sits between Base and Quinary in Windows' own ramp, and taking it would
give rungs of 3.86 / 5.14 / 8.04 — marginally more even than what is here. It
is not taken, because level 2's readers are cards and `Tertiary` is a
background tier, not a card: `CardBackgroundFillColorDefault` is the key whose
name and whose readers both say "card". The evenness argument is worth almost
nothing anyway — 3.86 against 3.71 — so it buys nothing and costs the one rung
in the ladder that can be justified by meaning rather than by position.

**And the narrow rung is declared rather than argued away.** 3.71 L\* between
levels 2 and 3 is **the narrowest rung of any scheme in this file**, under
Tokyo Night's 5.7. It is narrow because Windows is narrow there — its own
`Quarternary #2C2C2C` → `Quinary #333333` step is 3.25 L\* — and Windows can
afford that because a stroke does the separating. What makes it survive here is
that levels 2 and 3 almost never sit still next to each other: level 3 is a
hover, so it is a *change* under the pointer rather than a static boundary, and
a change of 3.71 L\* is visible where a border of 3.71 L\* would not be. If
this scheme ever reads flat, this rung is the first place to look, and the fix
is to move level 3 to `SolidBackgroundFillColorSenary #373737` (rungs 5.28,
5.54, 6.22) at the cost of losing Quinary's own hover meaning.

#### Measure the rungs in L\*, not in contrast ratio

A contrast ratio compresses badly at this end of the scale, and reading the four
levels through one would have rejected the right answer. The old ladder's
narrowest rung was **5.8 L\*** and scored 1.22:1; Tokyo Night's new narrowest is
**5.7 L\*** and scores 1.13:1 — the same step to an eye, two very different
numbers. In L\*:

| scheme | before | after |
|---|---|---|
| Tokyo Night | 10.1 / 19.3 / 25.4 / 31.2 — rungs 9.2, 6.1, 5.8 | **4.0 / 10.1 / 19.3 / 25.0** — rungs 6.1, 9.2, 5.7 |
| Catppuccin Mocha | 12.0 / 21.4 / 30.7 / 39.1 — rungs 9.4, 9.3, 8.5 | **5.4 / 12.0 / 21.4 / 39.1** — rungs 6.6, 9.4, 17.7 |
| Gruvbox Dark Medium | 16.1 / 23.9 / 31.6 / 39.8 — rungs 7.8, 7.7, 8.2 | unchanged |
| Windows 11 Dark | — | **12.3 / 17.5 / 21.3 / 29.3** — rungs 5.3, 3.7, 8.0 |

**Nothing collapses.** No scheme renders two levels the same hex. The closest
any two come is **Windows 11 Dark's 3.7 L\***, argued for in its own section
above; before that scheme arrived it was Tokyo Night's 5.7 L\*, which is the
step the old ladder already ran at.

#### What it does to the grading

Every pair was regraded: `on_surface`, `on_surface_variant` and `outline` on all
four levels; `warning`, `critical` and `outline_variant` on all four; and the
wallpaper-derived `primary` / `secondary` / `tertiary` on all four across all 58
still wallpapers in the collection. Because the ladders only go down, **no pair
in any scheme gets worse**, and two long-standing failures go away:

* Tokyo Night `on_surface_variant` on level 4 was the one text pair under 4.5:1
  in that scheme, at 4.23:1. It is now **5.28:1**. `critical` there goes
  3.38:1 → **4.22:1**, `warning` 4.47:1 → **5.58:1**, and the wallpaper accent
  5.23:1 → **6.53:1** at its worst over the 58 stills.
* Catppuccin gains on levels 1 to 3 (accent on level 3, 5.34:1 → 7.36:1) and
  loses nothing, because its level 4 did not move.

**Three failures are unchanged and none of them is the ladder's.** `outline`
(`ui_text_muted`) is painted as *text* in `SearchField.qml`, `AudioPage.qml` and
`KeybindsPage.qml` and was under 4.5:1 on every level of every scheme, before and
after — worst is Tokyo Night at 1.80:1 on level 4, best is Gruvbox at 4.02:1 on
level 1. **"Every scheme" stopped being true when the fourth arrived**; the
paragraph below this one is that scheme's row of the same table, and it is the
first to clear the bar anywhere. That is a role-choice question, not a ladder
question. `outline_variant`
is under 3:1 everywhere as well, but it is a divider *between two surfaces*
rather than a component boundary, and it improves under two of the three schemes
(above). And **Gruvbox's red is exactly as weak as it was** — `sem_critical
#fb4934` grades 2.56:1 on `bg2` and 1.89:1 on `bg3` — because Gruvbox's ladder
did not move. It is fixed in `schemes/gruvbox-dark.json` if it is worth fixing,
as the `_alerts` note in `quickshell-colors.json` already says.

**Windows 11 Dark grades better than all three on every text pair, and it still
has one deliberate gap.** `ui_text` (`on_surface`) never drops below **9.59:1**
across the four levels and `ui_text_variant` (`on_surface_variant`) never below
**5.97:1**, both comfortably the best in the file — the four-tone WinUI text
ramp in 4.5 is why. `ui_text_muted` (`outline`), the role the paragraph above
calls a standing failure, grades **5.51 / 4.79 / 4.27 / 3.24** on levels 1 to 4,
against a previous best of 4.02:1 anywhere in any scheme. Levels 1 and 2 pass
4.5:1; **levels 3 and 4 do not, and that is accepted rather than fixed.**

The reason it is accepted: levels 3 and 4 under this scheme are hover fills and
chip backings, not text grounds. Level 3's readers are 33-of-46 a hover or focus
fill and level 4's are the tooltip fill, slider rails, meter ticks and key chips
(4.4's reader table). Placeholder and group-heading text — what `ui_text_muted`
is *for* (1.1) — is drawn on levels 1 and 2, where it passes. Lifting
`ui_text_muted` to reach 4.5:1 on level 4 would mean abandoning
`TextFillColorTertiary`, i.e. abandoning the ramp that produced the two figures
above it, to fix a pair that is not drawn. Recorded as a known gap in the same
sense as the three above: measured, understood, and not a defect of the ladder.

**One terminal pair is worse than any of that, and it is Microsoft's.**
`term_blue #0037da` grades **2.38:1** on `term_bg #0c0c0c`. That is Campbell
exactly as Windows Terminal ships it — the ANSI blue a stock Windows console has
always drawn, unreadable as body text and famous for it. It is not introduced
here and it is not corrected here: correcting it would make the scheme a
Campbell-like palette rather than Campbell, and the sixteen slots are the one
part of this file that is verbatim upstream. `term_bright_blue #3b78ff` is the
readable one at 4.95:1, which is what a well-behaved TUI reaches for anyway.

---

### 4.5 Windows 11 Dark — where the other 74 roles come from

4.4 fills four roles. This is the rest of the file, and the reason it is
written out at this length is that it can be: every value below is either a
constant in a Microsoft source file or one arithmetic step from one, so a
reader can disagree with it by opening the source rather than by squinting at a
screenshot. Three values are neither, and they are named as such at the end.

#### The flattening rule, once

**Most of WinUI's dark tones are alpha over the window, not opaque hexes.**
`ControlFillColorDefault` is `#0FFFFFFF` — 6% white — and what reaches the eye
is that composited over whatever is behind it. This vocabulary has no alpha:
every role is `#rrggbb` and is painted directly. So the rule for this scheme,
applied once and never varied:

> An alpha constant becomes the colour it resolves to **over
> `SolidBackgroundFillColorBase #202020`**, the window ground, with the channel
> truncated rather than rounded.

`#202020` is the right ground because it is where the shell's own panels sit
(level 1 of 4.4) and because it is what Windows composites those fills over in
the overwhelming majority of cases. It is not always right — the same overlay
over a card resolves two levels higher — and the one place that matters is
`ui_border` / `ui_border_dim`, which is handled explicitly below rather than
fudged.

Worked once so the arithmetic is checkable: `TextFillColorSecondary #C5FFFFFF`
is α = 0xC5 = 197, so 197/255 × 255 + 58/255 × 32 = 197.0 + 7.28 = 204.28,
truncated to 204 = `0xCC`, giving **`#cccccc`**.

#### The base group

| role | value | WinUI dark key | note |
|---|---|---|---|
| `ui_bg`, `ui_bg_alt_row` | `#202020` | `SolidBackgroundFillColorBase` | The Mica fallback. `ui_bg_alt_row` equals `ui_bg` in all four schemes — no stripe, the assumption 4.3 records. |
| `ui_bg_dim`, `ui_bevel_mid`, `ui_doc_bg` | `#1c1c1c` | `SolidBackgroundFillColorSecondary` — and `CardStrokeColorDefaultSolid`, independently, at the same hex | The one tier below the window. |
| `ui_bg_shadow` | `#0a0a0a` | `SolidBackgroundFillColorBaseAlt` | The **Mica Alt** fallback, and the floor of the dictionary. |
| `ui_bg_view` | `#242424` | *computed* — see "Three values" below | |
| `ui_bevel_dark` | `#141414` | *computed* — see "Three values" below | |
| `ui_bg_bar` | `#272727` | `CardBackgroundFillColorSecondary #08FFFFFF` | The quieter of the two card fills: a strip inside a window rather than a card on it. |
| `ui_bg_button`, `ui_bg_field` | `#2d2d2d` | `ControlFillColorDefault #0FFFFFFF` | The **rest** fill of every Fluent control. A button face and a field face are the same colour in Windows, and this vocabulary keeps them apart only so a scheme *can* disagree. |
| `ui_bg_control` | `#323232` | `ControlFillColorSecondary #15FFFFFF` | The **hover** fill. `ui_bg_control` is "a raised inline control" (1.1), which is the one place in the base group that wants to sit above a button at rest — so the hover fill is the honest key, not a mistake. |
| `ui_bg_raised`, `ui_bevel_midlight` | `#2c2c2c` | `SolidBackgroundFillColorQuarternary` — and `LayerOnMicaBaseAltFillColorTertiary`, and the **acrylic tint** of `AcrylicBackgroundFillColorDefault`, all at the same hex | Card, popover, tooltip, completion menu. |
| `ui_border_dim` | `#2f2f2f` | `ControlStrokeColorDefault #12FFFFFF`, on `#202020` | |
| `ui_border` | `#414141` | `ControlStrokeColorDefault #12FFFFFF`, on **`#333333`** | **The same Windows stroke, resolved on two different grounds**, which is what it actually is: Windows draws one stroke colour and it lands lighter on a lighter control. `ui_border` is the visible frame and `ui_border_dim` the weaker one, so the pair is the stroke on level 3 and the stroke on level 1. This is the one place the flattening rule above is deliberately applied over something other than `#202020`, and it is the only way to get two border tones out of a dictionary that publishes one. |
| `ui_selection_disabled` | `#3a3a3a` | `LayerFillColorDefault #4C3A3A3A`, tint taken opaque | Worth its own line: that constant is a **30%-alpha mid grey**, not the alpha-white every neighbour is. Its tint colour is already the "present but not shouting" grey the role wants, so it is taken directly instead of flattened. |
| `ui_text` | `#ffffff` | `TextFillColorPrimary` | |
| `ui_text_variant` | `#cccccc` | `TextFillColorSecondary #C5FFFFFF` | |
| `ui_text_muted` | `#969696` | `TextFillColorTertiary #87FFFFFF` | |
| `ui_text_dim` | `#717171` | `TextFillColorDisabled #5DFFFFFF` | |
| `ui_on_accent` | `#000000` | `TextOnAccentFillColorPrimary` | **Black, and that is not a slip.** In dark mode Windows' accent fill is the *light* shade of the accent, so what goes on top of it is black. The other three schemes put their darkest surface here; this one puts pure black, because Windows does. |
| `ui_doc_fg` | `#e8e8e8` | *nothing* — see "Three values" below | |

The four text tones are one ramp — WinUI's own Primary / Secondary / Tertiary /
Disabled, in order — which is a tidier fill than any of the other three schemes
manage, and it is the reason the contrast table below is as clean as it is.

#### The semantic group

`sem_success`, `sem_warning` and `sem_critical` are **`SystemFillColorSuccess
#6CCB5F`, `SystemFillColorCaution #FCE100` and `SystemFillColorCritical
#FF99A4`**, verbatim, from the same block. The three `sem_on_*` are
`TextOnAccentFillColorPrimary #000000`, for the reason `ui_on_accent` is.

**`sem_info` is the one role 4.2 says is filled by judgement in every scheme,
and here it is not.** WinUI defines
`SystemFillColorAttentionBrush Color="{ThemeResource SystemAccentColorLight2}"`
in the dark dictionary: Windows' informational colour **is** the accent. So
`sem_info` is `#4cc2ff` by citation rather than by taste, and this is the first
scheme in the file that can say that.

#### The terminal group — Campbell, verbatim

The sixteen ANSI slots plus `term_bg`, `term_fg` and `term_cursor` are
**Campbell**, Windows Terminal's shipped default scheme:
`microsoft/terminal`, `src/cascadia/TerminalSettingsModel/defaults.json`, the
`"name": "Campbell"` block. Checked key for key against that file — nineteen
keys, all nineteen consumed here, none altered. Campbell is the right terminal
palette rather than an arbitrary one: it is what a stock Windows console shows,
which is the thing this scheme is a recreation of.

Campbell publishes nothing for the six roles kitty needs beyond a palette, so
those are filled from the WinUI side and say so:

| role | value | from |
|---|---|---|
| `term_tab_bg` | `#202020` | `SolidBackgroundFillColorBase` — the Terminal window's own chrome, not the console ground |
| `term_tab_inactive_fg` | `#969696` | `TextFillColorTertiary`, flattened |
| `term_border_inactive` | `#2f2f2f` | `ControlStrokeColorDefault`, flattened |
| `term_bell_border` | `#fce100` | `SystemFillColorCaution` |
| `term_url` | `#4cc2ff` | `SystemAccentColorLight2` — see the accent note below |
| `term_selection_bg` / `term_selection_fg` | `#3a3d41` / `#ffffff` | **judgement**, and 4.1(d)'s case exactly: Campbell's block has no `selectionBackground` key at all (verified — the schemes in that file that publish one show it, and Campbell does not). A cool neutral at L\* 25.6 is what stands there. It barely matters: `kitty-colors.conf:13` overrides `selection_background` with the wallpaper accent on every change. |

**One coincidence worth naming so nobody "fixes" it.** Campbell's `foreground`
and `white` are `#CCCCCC`, and `TextFillColorSecondary` flattened over
`#202020` is `#cccccc`. `term_fg`, `term_white` and `ui_text_variant` are
therefore the same hex from two entirely independent Microsoft sources. That is
the collision table's subject matter in miniature, and the three roles stay
apart.

#### The accent — and the one thing Microsoft does not publish

The `fb_*` block is Windows' accent, and the accent is where the citations stop
being citations.

`AccentFillColorDefaultBrush` in the dark dictionary is
`Color="{ThemeResource SystemAccentColorLight2}"` — a **runtime** lookup, not a
value. `microsoft-ui-xaml` contains no hex for any shade of the ramp, anywhere,
because the shades never exist in the XAML: WinUI forwards to
`IUISettings3::GetColorValue` and Windows answers. Microsoft was asked to
publish the derivation and declined —
`MicrosoftDocs/windows-uwp` issue #1673, closed as not planned — so there is no
documented Windows 11 default-accent hex to cite and this file must not pretend
otherwise.

What the three values here actually are: **a reading of a running Windows 11
(25H2, build 26200)** through
`Windows.UI.ViewManagement.UISettings.GetColorValue`, the same API WinUI itself
calls, corroborated twice on disk — `HKCU\Software\Microsoft\Windows\
CurrentVersion\Explorer\Accent!AccentPalette`, whose seven RGBA records read
`99EBFF 4CC2FF 0091F8 0078D4 0067C0 003E92 001A68` in Light3→Dark3 order, and
the same 32-byte record inside `uxtheme.dll`'s built-in accent palette table.
The `winaccent` project reads that same registry key and agrees. That is
strong evidence and it is still **a measurement of one machine, not a published
constant**, which is a different kind of fact from every other line in this
section.

| role | value | shade |
|---|---|---|
| `fb_primary` | `#4cc2ff` | `SystemAccentColorLight2` — what `AccentFillColorDefaultBrush` resolves to in dark |
| `fb_primary_container` | `#0067c0` | `SystemAccentColorDark1` |
| `fb_secondary_container` | `#003e92` | `SystemAccentColorDark2` |
| `fb_on_primary`, `fb_on_tertiary` | `#000000` | `TextOnAccentFillColorPrimary` |
| `fb_on_primary_container`, `fb_on_secondary_container` | `#ffffff` | `TextFillColorPrimary` |
| `fb_secondary`, `fb_tertiary` | `#3a96dd`, `#61d6d6` | Campbell `cyan` and `brightCyan` — **Windows publishes exactly one accent**, so a second and third have to come from somewhere, and the twelve Campbell chromatics are the set the live accent is drawn from too (below). Fallback and running desktop then speak the same twelve colours. |

The remaining eight `fb_*` mirror their `ui_*` twins, per 1.5's row order:
`fb_surface`…`fb_surface_container_highest` are 4.4's four rungs,
`fb_on_surface` is `ui_text`, `fb_on_surface_variant` is `ui_text_variant`,
`fb_outline` is `ui_text_muted` and `fb_outline_variant` is `ui_border_dim`.

**A declared choice inside the accent.** WinUI uses two accent tiers in dark:
`Light2 #4CC2FF` for *fills* (`AccentFillColorDefaultBrush`) and
`Light3 #99EBFF` for accent *text* (`AccentTextFillColorPrimaryBrush`). This
scheme uses Light2 everywhere, `term_url` and `sem_info` included, where a
strict transcription would put Light3 on those two. Taking both would introduce
a second accent tier into a vocabulary that has one slot for it, for the sake
of two roles. Light2 stands; the loss is that a Windows hyperlink is a shade
paler than this one.

#### What a wallpaper actually does to this scheme's accent

**None of the `fb_*` accents above is what the running desktop wears, and under
this scheme that is more surprising than under the other three.** The live
accent is snapped onto the nearest colour the scheme publishes, and the
candidate pool is fixed at **the twelve ANSI chromatics** — `CHROMATICS` in
`bin/.local/lib/scheme-accent.py:118-123`, `term_red` through
`term_bright_cyan`, and nothing else. So a wallpaper-derived accent under
Windows 11 Dark lands on a **Campbell** shade, never on `#4cc2ff`.

Measured against the script rather than reasoned about: the Windows 11 UI
accent itself, handed in as an extracted colour, snaps to `term_cyan #3a96dd`.
So does `#0078d4`, and so does a vivid `#0b87e2` out of a blue picture. The
full family the render is then seeded with is `primary #3a96dd`,
`secondary #e74856`, `tertiary #881798`.

**The behaviour is authentic and the shades are not.** Windows derives its own
accent from the wallpaper — that is exactly what `SystemAccentColor` is, and
why there is no hex to cite for it in the first place — so a desktop whose
accent moves with the picture is doing the Windows thing. What it wears while
doing it is a terminal palette, because that is the pool this repository's
snapper draws from. Recorded because the alternative reading — "the accent is
broken, it should be `#4cc2ff`" — is the one a future reader will arrive at,
and the answer is that `#4cc2ff` is the *fallback* (`fb_primary`, what a clone
with no wallpaper yet shows) and Campbell is the *palette*.

#### Three values with no Windows origin, named

Every other value in the file resolves to a constant. These do not, and the
file should say so rather than let a future reader assume they were cited:

* **`ui_bg_view #242424`.** The exact sRGB midpoint of
  `SolidBackgroundFillColorBase #202020` and `SolidBackgroundFillColorTertiary
  #282828` — (32 + 40) / 2 = 36 = `0x24` — and within 0.02 L\* of their L\*
  midpoint as well. 1.1 defines the role as "one clear step *away* from
  `ui_bg`", and Windows has no content-pane tone distinct from its window: a
  WinUI page and the window behind it are the same `#202020`. So the role is
  filled by splitting the one step Windows does publish. Same shape as Tokyo
  Night's two `Util.blend` fills in 4.1(c): derived from the palette, not
  picked beside it.
* **`ui_bevel_dark #141414`.** A step between `SolidBackgroundFillColorBaseAlt
  #0a0a0a` and `SolidBackgroundFillColorSecondary #1c1c1c`, sitting at L\* 6.32
  against their L\* midpoint of 6.50. Qt's `QPalette::Dark` slot must be *some*
  colour and Windows has no bevel — Fluent has no 3D bevel at all — so there is
  nothing to cite and the ladder position is the whole of the argument. Same
  category as 4.1(b)'s `ui_bg_shadow`: a mandatory Qt slot filled by position.
* **`ui_doc_fg #e8e8e8`.** The only value in the file with no derivation of any
  kind. The dark dictionary has no document token — no `Document*`, no
  `Reading*`, no `Page*` key exists in it — because a recoloured PDF is not a
  thing WinUI has an opinion about. `ui_text #ffffff` was available and is what
  every other scheme puts here; `#e8e8e8` (L\* 92.0) steps the ink down off
  pure white, which is a reader's judgement about a page of body text and not a
  fact about Windows. Change it to `#ffffff` if the distinction is not worth
  the unsourced value.

---

## 5. Per-file substitution worksheet

**THIS WORKSHEET HAS BEEN APPLIED, AND IT IS KEPT AS THE RECORD OF WHAT WAS
DONE RATHER THAN AS A LIST OF WHAT TO DO.** Every line number in it is a line
of the file *before* the substitution, which is what a worksheet's numbers have
to be, and none of them will resolve against the tree today: the literals they
name became `{{colors.<role>...}}` and the files moved on. Four headings name a
path that no longer holds the colours at all — 5.7's `kitty.conf` palette is
`matugen/.config/matugen/templates/kitty-scheme.conf` now, 5.8's three
userChrome surfaces are `zen-scheme.css`, 5.9's `shell/.config/cship.toml` is
`matugen/.config/matugen/templates/cship.toml`, and 5.10's `Theme.qml` was
answered by reading `colors.json` rather than by substitution. Sections 1.1 to
1.5 are where a citation you can follow lives; this section is where the
`literal -> role` decision for each site is written down, and that is what it
is still worth reading for.

One block per file. Each row is `line : literal -> role`. Every code occurrence
counted under **What was counted** above appears exactly once below.

Substitution syntax for a file that already is a matugen template:

* normal: `{{colors.<role>.default.hex}}`
* qt6ct ARGB: `#ff{{colors.<role>.default.hex_stripped}}`
* qt6ct 50%: `#80{{colors.<role>.default.hex_stripped}}`
* channels (zathura `rgba()`, ranger): `{{colors.<role>.default.red}}` etc.

The four files in 5.7-5.10 were **not** matugen templates when this was
written, and their rows are still `literal -> role`. Three of the four became
templates in the end — `kitty-scheme.conf`, `zen-scheme.css` and `cship.toml`,
each of them a new file rather than the old one turned into one, because the
half that is not a colour had to stay where the application reads it. The
fourth, `Theme.qml`, did not: the shell reads `colors.json`, so its literals
stayed as the `??` fallbacks section 1.4 describes.

### 5.1 `matugen/.config/matugen/templates/gtk3-colors.css` — 44 substitutions

```
 55 : #1a1b26 -> ui_bg                 window_bg_color
 56 : #c0caf5 -> ui_text               window_fg_color
 71 : #101119 -> ui_bg_view            view_bg_color
 72 : #c0caf5 -> ui_text               view_fg_color
 74 : #1a1b26 -> ui_bg                 headerbar_bg_color
 75 : #c0caf5 -> ui_text               headerbar_fg_color
 76 : #414868 -> ui_border             headerbar_border_color
 77 : #1a1b26 -> ui_bg                 headerbar_backdrop_color
 97 : #1a1b26 -> ui_bg                 sidebar_bg_color
 98 : #c0caf5 -> ui_text               sidebar_fg_color
 99 : #1a1b26 -> ui_bg                 sidebar_backdrop_color
103 : #292e42 -> ui_bg_raised          card_bg_color
104 : #c0caf5 -> ui_text               card_fg_color
107 : #1a1b26 -> ui_bg                 dialog_bg_color
108 : #c0caf5 -> ui_text               dialog_fg_color
110 : #292e42 -> ui_bg_raised          popover_bg_color
111 : #c0caf5 -> ui_text               popover_fg_color
113 : #292e42 -> ui_bg_raised          thumbnail_bg_color
114 : #c0caf5 -> ui_text               thumbnail_fg_color
118 : #414868 -> ui_border             borders
133 : #101119 -> ui_bg_view            content_view_bg
135 : #1a1b26 -> ui_bg                 panel_bg_color
136 : #c0caf5 -> ui_text               panel_fg_color
148 : #1a1b26 -> ui_bg                 theme_unfocused_bg_color
149 : #c0caf5 -> ui_text               theme_unfocused_fg_color
150 : #101119 -> ui_bg_view            theme_unfocused_base_color
151 : #c0caf5 -> ui_text               theme_unfocused_text_color
154 : #414868 -> ui_border             unfocused_borders
159 : #1a1b26 -> ui_bg                 insensitive_bg_color
160 : #565f89 -> ui_text_muted         insensitive_fg_color
161 : #101119 -> ui_bg_view            insensitive_base_color
162 : #565f89 -> ui_text_muted         unfocused_insensitive_color
185 : #f7768e -> sem_critical          destructive_color
186 : #f7768e -> sem_critical          destructive_bg_color
187 : #1a1b26 -> sem_on_critical       destructive_fg_color
189 : #9ece6a -> sem_success           success_color
190 : #9ece6a -> sem_success           success_bg_color
191 : #1a1b26 -> sem_on_success        success_fg_color
193 : #e0af68 -> sem_warning           warning_color
194 : #e0af68 -> sem_warning           warning_bg_color
195 : #1a1b26 -> sem_on_warning        warning_fg_color
197 : #f7768e -> sem_critical          error_color
198 : #f7768e -> sem_critical          error_bg_color
199 : #1a1b26 -> sem_on_critical       error_fg_color
```

DO NOT TOUCH (comment prose): line 60 (`#15161e`, `#101119`), line 66
(`#101119`), line 84 (`#28282c`). Lines 152, 153, 173, 174, 175 are already
matugen placeholders (`primary` / `on_primary`) — leave them alone.
`rgba(0,0,0,·)` at lines 78, 101, 105, 116, 117 and `transparent` at line 100
are out of scope.

### 5.2 `matugen/.config/matugen/templates/gtk4-colors.css` — 36 substitutions

```
100 : #1a1b26 -> ui_bg                 window_bg_color
101 : #c0caf5 -> ui_text               window_fg_color
103 : #101119 -> ui_bg_view            view_bg_color
104 : #c0caf5 -> ui_text               view_fg_color
122 : #1a1b26 -> ui_bg                 headerbar_bg_color
123 : #c0caf5 -> ui_text               headerbar_fg_color
124 : #414868 -> ui_border             headerbar_border_color
125 : #1a1b26 -> ui_bg                 headerbar_backdrop_color
146 : #1a1b26 -> ui_bg                 sidebar_bg_color
147 : #c0caf5 -> ui_text               sidebar_fg_color
148 : #1a1b26 -> ui_bg                 sidebar_backdrop_color
156 : #1a1b26 -> ui_bg                 secondary_sidebar_bg_color
157 : #c0caf5 -> ui_text               secondary_sidebar_fg_color
158 : #1a1b26 -> ui_bg                 secondary_sidebar_backdrop_color
162 : #292e42 -> ui_bg_raised          card_bg_color
163 : #c0caf5 -> ui_text               card_fg_color
166 : #1a1b26 -> ui_bg                 dialog_bg_color
167 : #c0caf5 -> ui_text               dialog_fg_color
169 : #292e42 -> ui_bg_raised          popover_bg_color
170 : #c0caf5 -> ui_text               popover_fg_color
172 : #292e42 -> ui_bg_raised          thumbnail_bg_color
173 : #c0caf5 -> ui_text               thumbnail_fg_color
177 : #414868 -> ui_border             borders
200 : #f7768e -> sem_critical          destructive_color
201 : #f7768e -> sem_critical          destructive_bg_color
202 : #1a1b26 -> sem_on_critical       destructive_fg_color
204 : #9ece6a -> sem_success           success_color
205 : #9ece6a -> sem_success           success_bg_color
206 : #1a1b26 -> sem_on_success        success_fg_color
208 : #e0af68 -> sem_warning           warning_color
209 : #e0af68 -> sem_warning           warning_bg_color
210 : #1a1b26 -> sem_on_warning        warning_fg_color
212 : #f7768e -> sem_critical          error_color
213 : #f7768e -> sem_critical          error_bg_color
214 : #1a1b26 -> sem_on_critical       error_fg_color
428 : #24283b -> ui_bg_control         window.view .content-pane .top-bar box.linked
```

DO NOT TOUCH (comment prose): lines 47, 48, 82, 83, 88, 98 (x2), 154, 418, 419.
Line 428 is the only literal inside the rules block; the `color-mix(... var(
--accent-bg-color) ...)` at lines 325 and 331 already tracks the accent and
needs no change.

### 5.3 `matugen/.config/matugen/templates/kitty-colors.conf` — 5 substitutions

```
12 : #1a1b26 -> ui_on_accent           selection_foreground (over the accent fill on line 13)
18 : #3b4261 -> term_border_inactive   inactive_border_color
21 : #1a1b26 -> ui_on_accent           active_tab_foreground (over the accent tab on line 20)
22 : #16161e -> term_tab_bg            inactive_tab_background
23 : #545c7e -> term_tab_inactive_fg   inactive_tab_foreground
```

Note lines 12 and 21 are `ui_on_accent`, **not** `term_bg`. The fill underneath
is the wallpaper accent in both cases.

### 5.4 `matugen/.config/matugen/templates/qt6ct-colors.conf` — 55 substitutions

Positional and unforgiving: 21 comma-separated colours per line, in
`QPalette::ColorRole` order, no names. Read the format note at lines 9-17
before editing. Indices 12-15 are already matugen placeholders on all three
lines; do not renumber anything.

**Line 51 `active_colors` — 17 substitutions** (indices 0-11, 16-20):

```
idx  0 : #ffc0caf5 -> ui_text              WindowText
idx  1 : #ff292e42 -> ui_bg_button         Button
idx  2 : #ff414868 -> ui_border            Light
idx  3 : #ff363b54 -> ui_bevel_midlight    Midlight
idx  4 : #ff15161e -> ui_bevel_dark        Dark
idx  5 : #ff1f2335 -> ui_bevel_mid         Mid
idx  6 : #ffc0caf5 -> ui_text              Text
idx  7 : #fff7768e -> sem_critical         BrightText
idx  8 : #ffc0caf5 -> ui_text              ButtonText
idx  9 : #ff15161e -> ui_bg_field          Base
idx 10 : #ff1a1b26 -> ui_bg                Window
idx 11 : #ff0d0e14 -> ui_bg_shadow         Shadow
idx 16 : #ff1a1b26 -> ui_bg_alt_row        AlternateBase
idx 17 : #ff1a1b26 -> ui_bg                NoRole
idx 18 : #ff292e42 -> ui_bg_raised         ToolTipBase
idx 19 : #ffc0caf5 -> ui_text              ToolTipText
idx 20 : #80c0caf5 -> ui_text  @ 50%       PlaceholderText  -> #80{{...hex_stripped}}
```

**Line 58 `disabled_colors` — 21 substitutions** (all indices are literals here):

```
idx  0 : #ff565f89 -> ui_text_muted        WindowText
idx  1 : #ff292e42 -> ui_bg_button         Button
idx  2 : #ff414868 -> ui_border            Light
idx  3 : #ff363b54 -> ui_bevel_midlight    Midlight
idx  4 : #ff15161e -> ui_bevel_dark        Dark
idx  5 : #ff1f2335 -> ui_bevel_mid         Mid
idx  6 : #ff565f89 -> ui_text_muted        Text
idx  7 : #ff565f89 -> ui_text_muted        BrightText (dimmed, NOT sem_critical)
idx  8 : #ff565f89 -> ui_text_muted        ButtonText
idx  9 : #ff15161e -> ui_bg_field          Base
idx 10 : #ff1a1b26 -> ui_bg                Window
idx 11 : #ff0d0e14 -> ui_bg_shadow         Shadow
idx 12 : #ff292e42 -> ui_selection_disabled  Highlight
idx 13 : #ff565f89 -> ui_text_muted        HighlightedText
idx 14 : #ff414868 -> ui_border            Link (dimmed)
idx 15 : #ff414868 -> ui_border            LinkVisited (dimmed)
idx 16 : #ff1a1b26 -> ui_bg_alt_row        AlternateBase
idx 17 : #ff1a1b26 -> ui_bg                NoRole
idx 18 : #ff292e42 -> ui_bg_raised         ToolTipBase
idx 19 : #ff565f89 -> ui_text_muted        ToolTipText
idx 20 : #80565f89 -> ui_text_muted @ 50%  PlaceholderText
```

**Line 64 `inactive_colors` — 17 substitutions** (indices 0-11, 16-20).
Enumerated in full rather than by reference, because "same as line 51" is
exactly the instruction that produces an off-by-one in a positional list:

```
idx  0 : #ffc0caf5 -> ui_text              WindowText
idx  1 : #ff292e42 -> ui_bg_button         Button
idx  2 : #ff414868 -> ui_border            Light
idx  3 : #ff363b54 -> ui_bevel_midlight    Midlight
idx  4 : #ff15161e -> ui_bevel_dark        Dark
idx  5 : #ff1f2335 -> ui_bevel_mid         Mid
idx  6 : #ffc0caf5 -> ui_text              Text
idx  7 : #fff7768e -> sem_critical         BrightText
idx  8 : #ffc0caf5 -> ui_text              ButtonText
idx  9 : #ff15161e -> ui_bg_field          Base
idx 10 : #ff1a1b26 -> ui_bg                Window
idx 11 : #ff0d0e14 -> ui_bg_shadow         Shadow
idx 16 : #ff1a1b26 -> ui_bg_alt_row        AlternateBase
idx 17 : #ff1a1b26 -> ui_bg                NoRole
idx 18 : #ff292e42 -> ui_bg_raised         ToolTipBase
idx 19 : #ffc0caf5 -> ui_text              ToolTipText
idx 20 : #80c0caf5 -> ui_text  @ 50%       PlaceholderText
```

The only difference from line 51 is at indices 12-13, which already hold
`primary_container` / `on_primary_container` placeholders instead of line 51's
`primary` / `on_primary`. Indices 14-15 (`tertiary` / `secondary`) are
identical on both lines.

Line 51 + line 58 + line 64 = 17 + 21 + 17 = **55 substitutions** in this file.

DO NOT TOUCH (comment prose): lines 30-41, 46-50 (the index legend), 53, 56.
Updating that legend is part of the job but it is prose, not substitution.

### 5.5 `matugen/.config/matugen/templates/zathurarc` — 19 substitutions

```
17 : #1a1b26 -> ui_doc_bg           recolor-lightcolor  (the PDF page)
18 : #c0caf5 -> ui_doc_fg           recolor-darkcolor   (the PDF ink)
25 : #1a1b26 -> ui_bg               default-bg
26 : #c0caf5 -> ui_text             default-fg
27 : #15161e -> ui_bg_bar           statusbar-bg
28 : #c0caf5 -> ui_text             statusbar-fg
29 : #15161e -> ui_bg_bar           inputbar-bg
30 : #c0caf5 -> ui_text             inputbar-fg
31 : #292e42 -> ui_bg_raised        completion-bg
32 : #c0caf5 -> ui_text             completion-fg
33 : #15161e -> ui_bg_bar           completion-group-bg
34 : #565f89 -> ui_text_muted       completion-group-fg
36 : #15161e -> ui_on_accent        completion-highlight-fg   ** VALUE CHANGES **
49 : #15161e -> ui_bg_bar           notification-bg
50 : #c0caf5 -> ui_text             notification-fg
51 : #e0af68 -> sem_warning         notification-warning-bg
52 : #15161e -> sem_on_warning      notification-warning-fg   ** VALUE CHANGES **
53 : #f7768e -> sem_critical        notification-error-bg
54 : #15161e -> sem_on_critical     notification-error-fg     ** VALUE CHANGES **
```

Three rows marked `** VALUE CHANGES **`: zathura is the only file that uses
`#15161e` as its on-accent colour; everywhere else it is `#1a1b26`. Applying
the shared role moves those three by 5 levels. Intentional unification, and
**decided**: apply it. See **Decisions taken** at the top of this file.

Lines 35, 45, 46 are already matugen placeholders (`primary`, `tertiary`, and
the `rgba()` channel form). Leave them.

### 5.6 `matugen/.config/matugen/templates/fastfetch-config.jsonc` — 1 substitution

```
46 : #c0caf5 -> ui_text             display.color.output
```

Lines 41 and 42 are already `primary` / `tertiary` placeholders.

### 5.7 `kitty/.config/kitty/kitty.conf` — 31 substitutions

Not a template today. The block is lines 105-148; the comment at 102-104 says
these are a fallback that `colors.conf` overrides, which is true only for
cursor, selection, tabs, URL and borders — the 16 ANSI slots and
foreground/background are *never* overridden and are what makes a terminal read
as Tokyo Night rather than Catppuccin.

```
105 : #c0caf5 -> term_fg                 foreground
106 : #1a1b26 -> term_bg                 background
107 : #1a1b26 -> ui_on_accent            selection_foreground
108 : #33467c -> term_selection_bg       selection_background
110 : #c0caf5 -> term_cursor             cursor
111 : #1a1b26 -> term_cursor_text        cursor_text_color
113 : #73daca -> term_url                url_color
115 : #7aa2f7 -> fb_primary              active_border_color
116 : #3b4261 -> term_border_inactive    inactive_border_color
117 : #e0af68 -> term_bell_border        bell_border_color
119 : #1a1b26 -> ui_on_accent            active_tab_foreground
120 : #7aa2f7 -> fb_primary              active_tab_background
121 : #545c7e -> term_tab_inactive_fg    inactive_tab_foreground
122 : #16161e -> term_tab_bg             inactive_tab_background
123 : #16161e -> term_tab_bg             tab_bar_background
126 : #15161e -> term_black              color0
127 : #414868 -> term_bright_black       color8
129 : #f7768e -> term_red                color1
130 : #f7768e -> term_bright_red         color9
132 : #9ece6a -> term_green              color2
133 : #9ece6a -> term_bright_green       color10
135 : #e0af68 -> term_yellow             color3
136 : #e0af68 -> term_bright_yellow      color11
138 : #7aa2f7 -> term_blue               color4
139 : #7aa2f7 -> term_bright_blue        color12
141 : #bb9af7 -> term_magenta            color5
142 : #bb9af7 -> term_bright_magenta     color13
144 : #7dcfff -> term_cyan               color6
145 : #7dcfff -> term_bright_cyan        color14
147 : #a9b1d6 -> term_white              color7
148 : #c0caf5 -> term_bright_white       color15
```

Downstream consumers of these 16 slots, which is why they matter more than
their line count suggests: `ranger/.config/ranger/colorschemes/tokyonight.py`
(paints with ANSI indices only; `fg, bg = 0, ACCENT` at lines 113, 130, 134
resolves to `term_black`), `zsh/.zshrc:85`
(`FZF_DEFAULT_OPTS='... --color=16'`), and every TUI in the session.

### 5.8 `zen/.zen/rice/chrome/userChrome.css` — 3 substitutions

```
90 : #1a1b26 -> ui_bg    --zen-branding-dark
91 : #1a1b26 -> ui_bg    --zen-main-browser-background
96 : #1a1b26 -> ui_bg    --zen-dialog-background
```

DO NOT TOUCH: lines 70, 71, 81 — those hexes are inside the comment and name
Zen's *own* defaults (`#101010`, `#171717`, `#1b1b1b`, `#1c1c1c`) that the three
lines above exist to override. The comment says "read cold next to the
blue-tinted `#1a1b26`"; that sentence needs rewriting in prose once `#1a1b26`
stops being fixed.

### 5.9 `shell/.config/cship.toml` — 13 substitutions

```
24 : #7dcfff -> sem_info        [cship.effort] style
25 : #e0af68 -> sem_warning     [cship.effort] high_style
26 : #e0af68 -> sem_warning     [cship.effort] xhigh_style   (bold)
27 : #f7768e -> sem_critical    [cship.effort] max_style     (bold)
35 : #7dcfff -> sem_info        [cship.context_bar] style
37 : #e0af68 -> sem_warning     [cship.context_bar] warn_style
39 : #f7768e -> sem_critical    [cship.context_bar] critical_style
43 : #a9b1d6 -> ui_text_variant [cship.cost] style
45 : #e0af68 -> sem_warning     [cship.cost] warn_style
47 : #f7768e -> sem_critical    [cship.cost] critical_style
54 : #e0af68 -> sem_warning     [cship.usage_limits] warn_style
56 : #f7768e -> sem_critical    [cship.usage_limits] critical_style
60 : #e0af68 -> sem_warning     [cship.peak_usage] style
```

Line 20 is `style = "bold cyan"` — a *named* ANSI colour, so it already follows
`term_cyan` and needs nothing. The header comment (lines 3-4) claims the file is
"Catppuccin Mocha palette copied as is"; it is not — every hex in it is Tokyo
Night. Correct the comment in the same change.

### 5.10 `quickshell/.config/quickshell/Theme.qml` — 20 substitutions

```
46 : #1a1b26 -> fb_surface                     surface
47 : #292e42 -> fb_surface_container           surfaceContainer
48 : #353b55 -> fb_surface_container_high      surfaceContainerHigh
49 : #414868 -> fb_surface_container_highest   surfaceContainerHighest
50 : #c0caf5 -> fb_on_surface                  textOnSurface
51 : #a9b1d6 -> fb_on_surface_variant          textOnSurfaceVariant
52 : #565f89 -> fb_outline                     outline
53 : #3b4261 -> fb_outline_variant             outlineVariant
55 : #7aa2f7 -> fb_primary                     primary
56 : #1a1b26 -> fb_on_primary                  textOnPrimary
57 : #3d59a1 -> fb_primary_container           primaryContainer
58 : #c0caf5 -> fb_on_primary_container        textOnPrimaryContainer
60 : #bb9af7 -> fb_secondary                   secondary
61 : #414868 -> fb_secondary_container         secondaryContainer
62 : #c0caf5 -> fb_on_secondary_container      textOnSecondaryContainer
64 : #73daca -> fb_tertiary                    tertiary
65 : #1a1b26 -> fb_on_tertiary                 textOnTertiary
73 : #e0af68 -> sem_warning                    warning
74 : #f7768e -> sem_critical                   critical
75 : #1a1b26 -> sem_on_critical                textOnCritical
```

**Line 255 `screenBezel: "#000000"` is the 21st literal and is NOT in this
list.** Leave it. The comment at lines 230-235 gives the reason: it stands in
for the panel bezel, which does not change colour with the theme.

`warning` and `critical` (73, 74) have no `on_` partner today —
`textOnCritical` exists but `textOnWarning` does not, so nothing can paint text
on the amber. `sem_on_warning` is defined in the vocabulary anyway because both
GTK templates and zathura consume it.

### 5.11 Reconciliation

| file | substitutions | left alone |
|---|---|---|
| gtk3-colors.css | 44 | 4 comment |
| gtk4-colors.css | 36 | 10 comment |
| kitty-colors.conf | 5 | 0 |
| qt6ct-colors.conf | 55 | 19 comment |
| zathurarc | 19 | 0 |
| fastfetch-config.jsonc | 1 | 0 |
| kitty.conf | 31 | 0 |
| userChrome.css | 3 | 6 comment |
| cship.toml | 13 | 0 |
| Theme.qml | 20 | 1 deliberate (`#000000`) |
| **total** | **227** | **40** |

227 + 40 = 267, the full hex census under **What was counted**.

---

## 6. Open questions

None left. All eight are answered under **Decisions taken** at the top of this
file, which is where a ninth belongs too.

---

## 7. Summary of what was counted

The counts are the survey's, in the past tense the rest of section 5 is in.
Only the two role figures describe the tree today.

* 267 hex literals in the ten files in scope; 228 in code, 39 in comments.
* 46 distinct literals as written; 27 distinct once ARGB spellings are folded
  and comment-only values dropped.
* 9 hexes carry more than one meaning; `#1a1b26` carries four, `#15161e` five,
  `#c0caf5` six, `#414868` four, `#292e42` four.
* **78 roles: 27 base, 27 terminal, 7 semantic, 17 accent fallbacks** — still
  true, and `tests/scheme-roles.py` is what keeps it so.
* **17 Material 3 accent role names**, of which nine are still wallpaper-derived
  and eight are filled from `ui_*` on the way into the shell (1.5).
* 227 substitutions across 10 files; 1 literal (`#000000`) deliberately kept.
  All 227 have been made.
* 4 roles cannot be filled from all three palettes without judgement; 1 of
  those (`fb_primary_container` on Catppuccin) has a visible consequence.
