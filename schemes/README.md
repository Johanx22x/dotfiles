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

**Keys are sorted, because `jq -S` sorted them.** `tests/scheme-roles.sh`
re-runs `jq -S` and fails if the file is not already in that form, so the
layout is mechanical rather than maintained. The prefixes make that ordering
useful rather than arbitrary: `fb_`, `sem_`, `term_`, `ui_` sort together, so
alphabetical order *is* grouped order.

---

## How the two halves join

One matugen invocation, at `wallpaper-switch`'s "5. Regenerate the palette":

```sh
matugen image "$PALETTE_SOURCE" --mode dark --prefer saturation --quiet \
    --import-json "$SCHEME_FILE"
```

`--import-json` merges the file into the render context that matugen has just
derived from the image. The 17 Material 3 accent roles come from the wallpaper,
the 74 roles named here come from the file, and every template sees all 91 at
once. `.hex`, `.hex_stripped` and `.red` / `.green` / `.blue` are computed by
matugen from any hex it is given, so a scheme role supports exactly the filters
a derived one does — which is what `qt6ct-colors.conf` (ARGB), `hypr-colors.lua`
and `ranger-accent` (decimal channels) need.

**Measured, not assumed.** Both this and the obvious alternative — dump the
palette with `matugen image ... -j hex --dry-run`, merge it with `jq`, render
with `matugen json` — were run against all 56 still wallpapers in the
collection, rendering all eleven templates each time and diffing against what
the desktop generates today. 616 files per approach, byte for byte identical,
no exceptions. `--import-json` was taken because it is one process instead of
two, needs no intermediate file, and leaves the fatal-or-not judgement at that
call site exactly where it was.

**THE IMPORTED FILE WINS.** A scheme that spelled a role `primary` would
override the wallpaper's accent silently — measured: a scheme setting
`primary` to `#ff0000` renders `#ff0000` and the image's own accent is gone.
So the `ui_` / `term_` / `sem_` / `fb_` prefixes are not tidiness, they are the
only thing keeping a scheme out of the 17 names in section 1.5, and
`tests/scheme-roles.sh` refuses a `colors` key that does not carry one.

That precedence is also the door the accent axis walks through later.
`desktop-scheme accent` exists to say where the three accents come from, and
today only `wallpaper` is implemented — but `scheme` and a fixed hex need no new
mechanism at all, only three more entries in the imported JSON.

**Every way of getting it wrong is fatal, and none of them writes a file.**
Measured against matugen 4.2.0: a missing file, malformed JSON, the wrong shape
and a role a template asks for but the scheme does not define all exit 1 with
nothing rendered. That is why the `|| die "matugen failed"` at that call site is
right, and the comment there explaining why it alone is fatal while everything
around it is `|| true` now covers the scheme file too.

One gap, and it closes when the templates are substituted: **today no template
reads a scheme role**, so an incomplete or entirely absent scheme file renders
eleven perfectly good files and says nothing. `tests/scheme-roles.sh` is what
stands in the way until then, and it is why that check counts roles rather than
trusting a render to fail.

---

## Decisions taken

The B0 survey left eight questions open. All eight are answered; where the
answer changes a rendered byte it is called out in the worksheet as well. Two
later entries — "Tokyo Night is Night" and the alert colours below it — did not
come from that survey but from checking the default scheme against upstream.

**zathura's on-accent colour is unified.** `zathurarc:36,52,54` used `#15161e`
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
which agree hex for hex. Sixteen of the 74 roles moved; the other 58 were
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
`backdrop-color "#11121a"`, `quickshell/.config/quickshell/modules/island/
Dashboard.qml:331` `inkInverse: "#12161f"`, and
`hypr/.config/hypr/hyprland.lua:348` `inactive_border = "rgba(595959aa)"`. The
first two are Tokyo-Night-family darks; the third is a neutral grey and
probably fine. Not in the worksheet, because they were not in the survey's
scope.

---

## What was counted

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

74 roles in four groups: **23 base**, **27 terminal**, **7 semantic**,
**17 accent fallbacks**. On top of those sit the 17 Material 3 roles the
templates already consume at runtime (section 1.5) — those come from the
wallpaper and are *not* in the scheme file.

**Naming rule:** every scheme role carries a group prefix (`ui_`, `term_`,
`sem_`, `fb_`). matugen's template context is a **flat** namespace, so an
unprefixed `surface` / `outline` / `outline_variant` in a scheme file would
collide with the identically-named Material 3 roles matugen derives from the
wallpaper. The prefixes make that collision impossible by construction.

### 1.1 base — surfaces, text, outlines

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | meaning | consumed at |
|---|---|---|---|---|---|
| `ui_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | Window / chrome background: the flat surface every app frame sits on. | gtk3 x9, gtk4 x8, zathura:25, userChrome x3, qt6ct idx10/17 |
| `ui_bg_dim` | `#16161e` | `#181825` | `#1d2021` | A quiet chrome strip that must recede behind ui_bg. | **nothing today** — the kitty tab bar reads `term_tab_bg` |
| `ui_bg_bar` | `#15161e` | `#181825` | `#3c3836` | Secondary bar / strip inside a window: statusbar, inputbar, notification, group header. | zathura:27,29,33,49 |
| `ui_bg_field` | `#15161e` | `#181825` | `#1d2021` | Background of an editable field or a scrolling list (Qt Base). | qt6ct idx9 x3 |
| `ui_bg_view` | `#0c0e14` | `#11111b` | `#1d2021` | The content pane, set one clear step away from ui_bg so content lifts off chrome. NOT necessarily darker -- see the ladder notes. | gtk3:71,133,150,161; gtk4:103 |
| `ui_bg_shadow` | `#0c0e14` | `#11111b` | `#1d2021` | Deepest tone of the palette; Qt bevel drop shadow. | qt6ct idx11 x3 |
| `ui_bg_alt_row` | `#1a1b26` | `#1e1e2e` | `#282828` | Alternating table row. Deliberately equal to ui_bg today (no stripe). | qt6ct idx16 x3 |
| `ui_bg_raised` | `#292e42` | `#313244` | `#3c3836` | Card / popover / tooltip / completion menu: a container floating above ui_bg. | gtk3:103,110,113; gtk4:162,169,172; zathura:31; qt6ct idx18 x3 |
| `ui_bg_button` | `#292e42` | `#313244` | `#3c3836` | Qt button face (QPalette::Button). | qt6ct idx1 x3 |
| `ui_bg_control` | `#222534` | `#313244` | `#3c3836` | A raised inline control (the Nautilus breadcrumb pill, linked button groups). | gtk4:428 |
| `ui_bevel_dark` | `#15161e` | `#181825` | `#1d2021` | Qt 3D bevel, darkest shade (QPalette::Dark). | qt6ct idx4 x3 |
| `ui_bevel_mid` | `#1a1b26` | `#1e1e2e` | `#282828` | Qt 3D bevel, mid shade (QPalette::Mid). | qt6ct idx5 x3 |
| `ui_bevel_midlight` | `#353b55` | `#45475a` | `#504945` | Qt 3D bevel, light-mid shade (QPalette::Midlight). | qt6ct idx3 x3 |
| `ui_border` | `#414868` | `#585b70` | `#665c54` | Visible 1px divider or frame between surfaces; Qt bevel lit edge (QPalette::Light). | gtk3:76,118,154; gtk4:124,177; qt6ct idx2 x3, idx14/15 disabled |
| `ui_border_dim` | `#3b4261` | `#45475a` | `#504945` | A weaker divider: an unfocused window split. | **nothing today** — the unfocused split reads `term_border_inactive` |
| `ui_text` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | Primary text and icons on any ui_bg* surface. | gtk3 x12, gtk4 x9, zathura x6, qt6ct idx0/6/8/19, fastfetch:46 |
| `ui_text_variant` | `#a9b1d6` | `#bac2de` | `#d5c4a1` | Secondary / less important text that still has to be read. | cship:43 |
| `ui_text_dim` | `#545c7e` | `#7f849c` | `#a89984` | Text of an inactive-but-clickable element. | **nothing today** — the inactive tab label reads `term_tab_inactive_fg` |
| `ui_text_muted` | `#565f89` | `#6c7086` | `#928374` | Disabled text, placeholder text, group headings -- present but not readable as content. | gtk3:160,162; zathura:34; qt6ct disabled idx0/6/7/8/13/19/20 |
| `ui_on_accent` | `#1a1b26` | `#1e1e2e` | `#282828` | Text/glyphs drawn ON TOP of a full-strength accent or semantic fill. Never a surface. | gtk3:187,191,195,199; gtk4:202,206,210,214; kitty-colors:12,21; kitty.conf:107,119; zathura:36 |
| `ui_doc_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | The page of a recoloured document (what zathura turns white paper into). | zathura:17 |
| `ui_doc_fg` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | The ink of a recoloured document. | zathura:18 |
| `ui_selection_disabled` | `#292e42` | `#313244` | `#504945` | Selection fill inside a DISABLED widget: present but must not shout. | qt6ct:58 idx12 |

**Three of these rows have no reader, and that is not an oversight.**
`ui_bg_dim`, `ui_border_dim` and `ui_text_dim` name the *general* "dimmed
chrome" idea; the only place the desktop currently expresses it is kitty, and
kitty got its own `term_` twins — `term_tab_bg`, `term_border_inactive`,
`term_tab_inactive_fg` — precisely so a scheme can dim a terminal tab bar
without dimming every strip on the desktop. The templates were written from
§5.3 and read the `term_` names, so `kitty-colors.conf:18,22,23` and
`kitty.conf:116,121,122,123` belong to those three and appear against them in
§1.2, not here. Verify with `grep -rn ui_bg_dim matugen/` — no hit.

The three `ui_*_dim` roles stay in the vocabulary anyway: every scheme already
fills them, dropping them would be a breaking change to all three files, and
the first non-terminal dimmed strip this desktop grows is the reader they were
named for.

### 1.2 terminal — the sixteen ANSI slots plus fg/bg/cursor/selection

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | meaning | consumed at |
|---|---|---|---|---|---|
| `term_bg` | `#1a1b26` | `#1e1e2e` | `#282828` | Terminal background. | kitty.conf:106 |
| `term_fg` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | Default terminal text. | kitty.conf:105 |
| `term_cursor` | `#c0caf5` | `#f5e0dc` | `#ebdbb2` | Cursor block colour (fallback; matugen overrides with primary). | kitty.conf:110 |
| `term_cursor_text` | `#1a1b26` | `#1e1e2e` | `#282828` | The character under the cursor block. | kitty.conf:111 |
| `term_selection_bg` | `#283457` | `#585b70` | `#504945` | Selection fill (fallback; matugen overrides with primary). | kitty.conf:108 |
| `term_selection_fg` | `#c0caf5` | `#1e1e2e` | `#282828` | Text inside the selection, over term_selection_bg. | **nothing today** -- `kitty-scheme.conf:41` paints `selection_foreground` from `ui_on_accent` instead; see the note under this table |
| `term_url` | `#73daca` | `#94e2d5` | `#8ec07c` | Underlined URL (fallback; matugen overrides with tertiary). | kitty.conf:113 |
| `term_border_inactive` | `#292e42` | `#45475a` | `#504945` | Border of an unfocused kitty split. | kitty.conf:116 (no longer = ui_border_dim: upstream publishes `inactive_border_color #292e42`) |
| `term_tab_bg` | `#16161e` | `#181825` | `#1d2021` | Tab bar background and inactive tab background. | kitty-colors:22, kitty.conf:122,123 |
| `term_tab_inactive_fg` | `#545c7e` | `#7f849c` | `#a89984` | Label of an inactive tab. | kitty-colors:23, kitty.conf:121 |
| `term_bell_border` | `#e0af68` | `#f9e2af` | `#fabd2f` | Border flash when a window rings the bell. | kitty.conf:117 |
| `term_black` | `#15161e` | `#45475a` | `#282828` | ANSI slot color0. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_red` | `#f7768e` | `#f38ba8` | `#cc241d` | ANSI slot color1. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_green` | `#9ece6a` | `#a6e3a1` | `#98971a` | ANSI slot color2. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_yellow` | `#e0af68` | `#f9e2af` | `#d79921` | ANSI slot color3. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_blue` | `#7aa2f7` | `#89b4fa` | `#458588` | ANSI slot color4. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_magenta` | `#bb9af7` | `#f5c2e7` | `#b16286` | ANSI slot color5. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_cyan` | `#7dcfff` | `#94e2d5` | `#689d6a` | ANSI slot color6. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_white` | `#a9b1d6` | `#bac2de` | `#a89984` | ANSI slot color7. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_black` | `#414868` | `#585b70` | `#928374` | ANSI slot color8. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_red` | `#ff899d` | `#f38ba8` | `#fb4934` | ANSI slot color9. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_green` | `#9fe044` | `#a6e3a1` | `#b8bb26` | ANSI slot color10. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_yellow` | `#faba4a` | `#f9e2af` | `#fabd2f` | ANSI slot color11. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_blue` | `#8db0ff` | `#89b4fa` | `#83a598` | ANSI slot color12. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_magenta` | `#c7a9ff` | `#f5c2e7` | `#d3869b` | ANSI slot color13. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_cyan` | `#a4daff` | `#94e2d5` | `#8ec07c` | ANSI slot color14. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |
| `term_bright_white` | `#c0caf5` | `#a6adc8` | `#ebdbb2` | ANSI slot color15. | kitty.conf; inherited by ranger, fzf (--color=16), and every TUI |

**Tokyo Night's six bright chromatics are NOT repeats of the normal ones**, and
this table said they were until the file was checked against upstream. The
plugin derives them (`lua/tokyonight/colors/init.lua`, `colors.terminal`) with
`Util.brighten` — HSLuv lightness +5, saturation +20 — and publishes the result
in `extras/kitty/tokyonight_night.conf` as `color9`-`color14`. The repeats in
this repository came from `kitty.conf`'s own literals, which is a fact about
the desktop's history and not about the palette. `color0`/`color8` and
`color7`/`color15` are the exception: those four are `black`, `terminal_black`,
`fg_dark` and `fg`, four separate palette entries rather than a brightened pair.

**`term_selection_fg` has no reader**, because `kitty-scheme.conf:41` paints
`selection_foreground` from `ui_on_accent`. That was right while the role
tracked the on-accent colour; it is not right now that the role carries
upstream's own `selection_foreground` (`#c0caf5`, light text on the dark
`bg_visual` fill). The pair the template actually renders — `ui_on_accent`
`#1a1b26` on `term_selection_bg` `#283457` — grades 1.40:1, and only never
shows because `kitty-colors.conf` overrides both halves with the wallpaper
accent. Pointing that line at `term_selection_fg` would render 7.57:1 and is a
one-word change in a file this section does not own.

### 1.3 semantic

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | meaning | consumed at |
|---|---|---|---|---|---|
| `sem_warning` | `#e0af68` | `#f9e2af` | `#fabd2f` | 'Watch out'. Never harmonised with the wallpaper. | gtk3:193,194; gtk4:208,209; zathura:51; Theme.qml:73; cship x6 |
| `sem_on_warning` | `#1a1b26` | `#1e1e2e` | `#282828` | Text on a sem_warning fill. | gtk3:195; gtk4:210; zathura:52 |
| `sem_critical` | `#f7768e` | `#f38ba8` | `#fb4934` | 'Something is wrong'. Also GTK's destructive_* and error_*, and Qt BrightText. | gtk3:185,186,197,198; gtk4:200,201,212,213; zathura:53; qt6ct idx7; Theme.qml:74; cship x4 |
| `sem_on_critical` | `#1a1b26` | `#1e1e2e` | `#282828` | Text on a sem_critical fill. | gtk3:187,199; gtk4:202,214; zathura:54; Theme.qml:75 |
| `sem_success` | `#9ece6a` | `#a6e3a1` | `#b8bb26` | 'It worked'. | gtk3:189,190; gtk4:204,205 |
| `sem_on_success` | `#1a1b26` | `#1e1e2e` | `#282828` | Text on a sem_success fill. | gtk3:191; gtk4:206 |
| `sem_info` | `#7dcfff` | `#89dceb` | `#83a598` | Nominal / informational reading -- the low end of a warn/critical ramp. | cship:24,35 |

GTK's `destructive_*` and `error_*` sets are the same colour in both templates
today; both map to `sem_critical` / `sem_on_critical`. There is no separate
`sem_error` role — adding one would let a scheme make "delete this" and "this
failed" different colours, which nothing currently wants.

### 1.4 accent fallback — the 17 Material 3 roles, pre-matugen

These are only read on a fresh clone or a malformed `colors.json`
(`Theme.qml:283-292`). They still belong to the scheme: a Gruvbox desktop whose
shell boots Tokyo-Night-blue for a second is a visible defect.

| role | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | meaning | consumed at |
|---|---|---|---|---|---|
| `fb_surface` | `#1a1b26` | `#1e1e2e` | `#282828` | M3 surface fallback, used only until matugen writes colors.json. | Theme.qml:46 |
| `fb_surface_container` | `#292e42` | `#313244` | `#3c3836` | M3 surface_container fallback, used only until matugen writes colors.json. | Theme.qml:47 |
| `fb_surface_container_high` | `#353b55` | `#45475a` | `#504945` | M3 surface_container_high fallback, used only until matugen writes colors.json. | Theme.qml:48 |
| `fb_surface_container_highest` | `#414868` | `#585b70` | `#665c54` | M3 surface_container_highest fallback, used only until matugen writes colors.json. | Theme.qml:49 |
| `fb_on_surface` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | M3 on_surface fallback, used only until matugen writes colors.json. | Theme.qml:50 |
| `fb_on_surface_variant` | `#a9b1d6` | `#bac2de` | `#bdae93` | M3 on_surface_variant fallback, used only until matugen writes colors.json. | Theme.qml:51 |
| `fb_outline` | `#565f89` | `#6c7086` | `#7c6f64` | M3 outline fallback, used only until matugen writes colors.json. | Theme.qml:52 |
| `fb_outline_variant` | `#3b4261` | `#45475a` | `#504945` | M3 outline_variant fallback, used only until matugen writes colors.json. | Theme.qml:53 |
| `fb_primary` | `#7aa2f7` | `#89b4fa` | `#83a598` | M3 primary fallback, used only until matugen writes colors.json. | Theme.qml:55; kitty.conf:115,120 |
| `fb_on_primary` | `#1a1b26` | `#1e1e2e` | `#282828` | M3 on_primary fallback, used only until matugen writes colors.json. | Theme.qml:56 |
| `fb_primary_container` | `#3d59a1` | `#45475a` | `#458588` | M3 primary_container fallback, used only until matugen writes colors.json. | Theme.qml:57 |
| `fb_on_primary_container` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | M3 on_primary_container fallback, used only until matugen writes colors.json. | Theme.qml:58 |
| `fb_secondary` | `#bb9af7` | `#cba6f7` | `#d3869b` | M3 secondary fallback, used only until matugen writes colors.json. | Theme.qml:60 |
| `fb_secondary_container` | `#414868` | `#585b70` | `#665c54` | M3 secondary_container fallback, used only until matugen writes colors.json. | Theme.qml:61 |
| `fb_on_secondary_container` | `#c0caf5` | `#cdd6f4` | `#ebdbb2` | M3 on_secondary_container fallback, used only until matugen writes colors.json. | Theme.qml:62 |
| `fb_tertiary` | `#73daca` | `#f5c2e7` | `#fe8019` | M3 tertiary fallback, used only until matugen writes colors.json. | Theme.qml:64 |
| `fb_on_tertiary` | `#1a1b26` | `#1e1e2e` | `#282828` | M3 on_tertiary fallback, used only until matugen writes colors.json. | Theme.qml:65 |

**Sixteen of these seventeen are consumed by nothing, and the "consumed at"
column above is aspirational.** `Theme.qml:101-120` writes its fallbacks as
literals — `palette.surface_container_high ?? "#343a52"`, `palette.tertiary ??
"#e0bbdd"` — so what a fresh clone shows is not the scheme's `fb_*` block but a
hardcoded copy of Tokyo Night, whichever scheme is selected. That is exactly
the defect the block was added to fix, and it is still open: only `fb_primary`
has a real reader (`kitty-scheme.conf:47,52`). The two literals named above are
also the two `fb_*` values this scheme had to correct — `#e0bbdd` is not a
Tokyo Night colour at all — so closing the gap means changing both sides in one
step, on the QML side, which this file does not own.

### 1.5 accent — the 17 Material 3 roles the templates already consume

Not scheme roles: matugen derives these from the wallpaper on every change.
Listed because the vocabulary has to stay clear of their names, and because the
`fb_*` block above mirrors them one-for-one.

The canonical list is `quickshell-colors.json:7-26`, and `Theme.qml:46-65`
declares exactly one reader per key:

| # | matugen role | template reference | read by |
|---|---|---|---|
| 1 | `surface` | `{{colors.surface.default.hex}}` | `Theme.qml:46` |
| 2 | `surface_container` | `quickshell-colors.json:8` | `Theme.qml:47` |
| 3 | `surface_container_high` | `quickshell-colors.json:9` | `Theme.qml:48` |
| 4 | `surface_container_highest` | `quickshell-colors.json:10` | `Theme.qml:49` |
| 5 | `on_surface` | `quickshell-colors.json:11` | `Theme.qml:50` |
| 6 | `on_surface_variant` | `quickshell-colors.json:12` | `Theme.qml:51` |
| 7 | `outline` | `quickshell-colors.json:13` | `Theme.qml:52` |
| 8 | `outline_variant` | `quickshell-colors.json:14` | `Theme.qml:53` |
| 9 | `primary` | qs:16, gtk3:152,173,174, gtk4:188,189, qt6ct:51, kitty-colors:9,13,17,20, hypr:9, niri:41, ranger-accent:12, zen:27, zathura:35,46, fastfetch:41 | everything |
| 10 | `on_primary` | qs:17, gtk3:153,175, gtk4:190, qt6ct:51 | GTK, Qt, shell |
| 11 | `primary_container` | qs:18, qt6ct:64 | Qt inactive selection, shell |
| 12 | `on_primary_container` | qs:19, qt6ct:64 | Qt inactive selection, shell |
| 13 | `secondary` | qs:21, qt6ct:51,64 (LinkVisited) | Qt, shell |
| 14 | `secondary_container` | `quickshell-colors.json:22` | `Theme.qml:61` |
| 15 | `on_secondary_container` | `quickshell-colors.json:23` | `Theme.qml:62` |
| 16 | `tertiary` | qs:25, qt6ct:51,64 (Link), kitty-colors:15, hypr:10, niri:41, ranger-accent:13, zathura:45, fastfetch:42 | second accent everywhere |
| 17 | `on_tertiary` | `quickshell-colors.json:26` | `Theme.qml:65` |

M3's `error` / `on_error` are deliberately **not** passed through
(`quickshell-colors.json:28`): an alert tinted by the wallpaper loses the one
thing it carries. That is why `sem_*` exists.

---

## 2. The collision table

Same hex, different meanings. This is the part that decides the vocabulary.

**Every hex below is a literal that was in this repository's templates**, not a
claim about Tokyo Night. The distinction matters in 2.7, 2.8 and 2.9, where a
normal and a bright ANSI slot are counted as one colour: they shared a hex in
`kitty.conf`, and upstream publishes them apart (see the note under 1.2). The
collisions those rows argue for are still real — the vocabulary needs
`sem_warning` separate from `term_yellow` however Gruvbox or Tokyo Night
happens to fill them — but the count in the heading is a count of what was
written here, and it is now higher than one for the pairs concerned.

### 2.1 `#1a1b26` — 46 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| window / chrome background | gtk3:55,74,77,97,99,107,135,148,159; gtk4:100,122,125,146,148,156,158,166; zathura:25; userChrome:90,91,96; qt6ct idx10 (`#ff1a1b26`, lines 51,58,64); kitty.conf:106 | `ui_bg` / `term_bg` / `fb_surface` |
| **text drawn ON TOP of an accent or semantic fill** | gtk3:187,191,195,199; gtk4:202,206,210,214; kitty-colors:12,21; kitty.conf:107,111,119; Theme.qml:56,65,75 | `ui_on_accent`, `sem_on_*`, `fb_on_primary`, `fb_on_tertiary`, `term_cursor_text` |
| alternating table row / Qt NoRole | qt6ct idx16 and idx17 (lines 51,58,64) | `ui_bg_alt_row` (idx16), `ui_bg` (idx17) |
| the page of a recoloured PDF | zathura:17 (`recolor-lightcolor`) | `ui_doc_bg` |

This is the headline collision. A scheme that wants deeper contrast under
alerts can set `sem_on_critical` to Catppuccin `crust` while leaving `ui_bg` at
`base`; today one hex forces them together. Note also that `term_bg` is split
out from `ui_bg` on purpose — a Gruvbox user conventionally runs the terminal at
`bg0_h`, one step under the desktop.

### 2.2 `#15161e` — 13 occurrences, **five** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| ANSI black (`color0`) | kitty.conf:126 | `term_black` |
| Qt `Base` — field and list background | qt6ct idx9 (`#ff15161e`, lines 51,58,64) | `ui_bg_field` |
| Qt `Dark` — bevel shading | qt6ct idx4 (lines 51,58,64) | `ui_bevel_dark` |
| secondary bar / strip | zathura:27,29,33,49 | `ui_bg_bar` |
| **text ON an accent or semantic fill** | zathura:36,52,54 | `ui_on_accent`, `sem_on_warning`, `sem_on_critical` |

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
| primary text on a surface | gtk3 x12, gtk4 x9, zathura:26,28,30,32,50, qt6ct idx0/6/8/19, fastfetch:46 | `ui_text` |
| ANSI bright white (`color15`) | kitty.conf:148 | `term_bright_white` |
| terminal cursor colour | kitty.conf:110 | `term_cursor` |
| text on a *container* accent | Theme.qml:58, Theme.qml:62 | `fb_on_primary_container`, `fb_on_secondary_container` |
| document ink | zathura:18 (`recolor-darkcolor`) | `ui_doc_fg` |
| placeholder text at 50% (`#80c0caf5`) | qt6ct idx20, lines 51,64 | `ui_text` with the alpha kept in the template |

Catppuccin makes the second row matter: its published `color15` is `subtext0`
(`#a6adc8`), which is *darker* than `color7`. Fusing `term_bright_white` into
`ui_text` would silently overrule the scheme's own terminal spec.

### 2.4 `#414868` — 9 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| divider / frame (GTK `borders`, `headerbar_border_color`, `unfocused_borders`) | gtk3:76,118,154; gtk4:124,177 | `ui_border` |
| Qt `Light` — lit edge of the bevel | qt6ct idx2 (lines 51,58,64) | `ui_border` |
| ANSI bright black (`color8`) | kitty.conf:127 | `term_bright_black` |
| M3 `surface_container_highest` and `secondary_container` | Theme.qml:49,61 | `fb_surface_container_highest`, `fb_secondary_container` |

Gruvbox proves this split is real: its `color8` is `gray #928374` while its
natural border step is `bg3 #665c54` — two clearly different colours that Tokyo
Night happens to spell the same.

The disabled Qt list (line 58) also uses `#ff414868` at idx14 and idx15 (Link
and LinkVisited, dimmed) — three further sites for `ui_border`.

### 2.5 `#565f89` — 5 occurrences, **two** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| disabled / placeholder / group-heading text | gtk3:160,162; zathura:34; qt6ct:58 idx0,6,7,8,13,19,20 | `ui_text_muted` |
| M3 `outline` | Theme.qml:52 | `fb_outline` |

Worth noting on its own: the desktop currently has **two different "outline"
colours** — GTK's `borders` at `#414868` and quickshell's M3 `outline` at
`#565f89`. Kept apart in the vocabulary (`ui_border` vs `fb_outline`) because
one belongs to the fixed base and the other is an M3 fallback, but a scheme
author should know they are meant to look like the same kind of line.

### 2.6 `#292e42` — 11 occurrences, **four** distinct meanings

| meaning | sites | recommended role |
|---|---|---|
| card / popover / tooltip / completion menu | gtk3:103,110,113; gtk4:162,169,172; zathura:31; qt6ct idx18 (lines 51,58,64) | `ui_bg_raised` |
| Qt `Button` face | qt6ct idx1 (lines 51,58,64) | `ui_bg_button` |
| **selection fill inside a disabled widget** | qt6ct:58 idx12 | `ui_selection_disabled` |
| M3 `surface_container` | Theme.qml:47 | `fb_surface_container` |

Row 3 is a fill, not a surface — it stands where the accent stands in the other
two colour groups. A scheme that wants a dimmed selection to keep a hint of hue
needs it separable.

### 2.7 `#e0af68` — 15 occurrences, **three** distinct meanings

`sem_warning` (gtk3:193,194; gtk4:208,209; zathura:51; Theme.qml:73; cship
:25,:26,:37,:45,:54,:60) · `term_yellow` + `term_bright_yellow`
(kitty.conf:135,136) · `term_bell_border` (kitty.conf:117).

Gruvbox splits these: `sem_warning` and `term_bright_yellow` are `#fabd2f`, but
`term_yellow` is `#d79921`. Collapsing warning onto the ANSI slot would make it
a different colour depending on which of the two Gruvbox yellows was chosen.

### 2.8 `#f7768e` — 17 occurrences, **four** distinct meanings

`sem_critical` (gtk3:185,186,197,198; gtk4:200,201,212,213; zathura:53;
Theme.qml:74; cship:27,:39,:47,:56) · Qt `BrightText` (qt6ct idx7, lines 51,64)
· `term_red` and `term_bright_red` (kitty.conf:129,130). Same Gruvbox argument
as 2.7 (`#cc241d` vs `#fb4934`).

Qt `BrightText` is genuinely "the watch-out text colour", so mapping it to
`sem_critical` is correct rather than a compromise.

### 2.9 `#9ece6a` / `#7aa2f7` / `#bb9af7` / `#7dcfff`

| hex | meanings | roles |
|---|---|---|
| `#9ece6a` (6) | success fill (gtk3:189,190; gtk4:204,205); ANSI green pair (kitty.conf:132,133) | `sem_success`, `term_green`, `term_bright_green` |
| `#7aa2f7` (5) | accent fallback (kitty.conf:115,120; Theme.qml:55); ANSI blue pair (kitty.conf:138,139) | `fb_primary`, `term_blue`, `term_bright_blue` |
| `#bb9af7` (3) | ANSI magenta pair (kitty.conf:141,142); M3 secondary fallback (Theme.qml:60) | `term_magenta`, `term_bright_magenta`, `fb_secondary` |
| `#7dcfff` (4) | ANSI cyan pair (kitty.conf:144,145); cship "nominal" style (cship:24,35) | `term_cyan`, `term_bright_cyan`, `sem_info` |

### 2.10 `#16161e` vs `#15161e` — one level apart, different roles

`#16161e` (kitty tab bar and inactive tab, `kitty-colors.conf:22`,
`kitty.conf:122,123`) and `#15161e` (fields, bars, ANSI black) differ by a
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

* `#000000` at `Theme.qml:255` (`screenBezel`). The comment at lines 230-235
  states the reason: it stands in for the panel bezel, and a bezel does not
  change colour with the theme. Leave hardcoded.
* `rgba(0,0,0,0.15|0.18|0.36|0.5)` shade and scrim values in both GTK
  templates (gtk3:78,101,105,116,117; gtk4:126,150,159,160,164,175,176) are
  alpha-on-black, not palette entries. Out of scope unless a scheme wants tinted
  shadows; see **Decisions taken**, which rules one out.
* The seven comment-only literals — `#101010`, `#171717` (x2), `#1b1b1b`,
  `#1c1c1c` (userChrome.css:70,71,81), `#28282c` (gtk3:84, gtk4:154),
  `#222226` / `#2e2e32` (gtk4:98) — document *upstream defaults being
  overridden*. They must stay as prose.

---

## 3. Scheme files

Was three filled JSON blocks in the working document. They are files now: the
`*.json` beside this README are the authority, and `desktop-scheme list` is how
you find out which exist. Section 4 is the record of what filling the
vocabulary three times taught, and it is the thing to read before writing a
fourth.

---

## 4. Validation pass — filling the vocabulary three times

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

Everything else — all 23 base roles, all 27 terminal roles, all 7 semantic
roles, 15 of the 17 fallbacks — fills from published values in all three
palettes, with **two exceptions in Tokyo Night** where the palette has no tone
in the gap a Qt slot needs: `ui_bg_control` `#222534` and `ui_bevel_midlight`
`#353b55` (and `fb_surface_container_high`, which mirrors the latter). Both are
`Util.blend(x, 0.5, y)` — upstream's own mixing function — over the two
published neighbours the role sits between, so they are derived from the
palette rather than picked beside it. See "Tokyo Night is Night" below.

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

### 4.3 Ladder depth: how the differences were resolved

| region | Tokyo Night | Catppuccin Mocha | Gruvbox Dark Medium | resolution |
|---|---|---|---|---|
| at or below the window | 4 steps: `0c0e14`, `15161e`, `16161e`, `1a1b26` | 3: `crust`, `mantle`, `base` | 2: `bg0_h`, `bg0` | Keep 5 roles (`ui_bg_shadow`, `ui_bg_view`, `ui_bg_field`/`ui_bg_bar`/`ui_bevel_dark`, `ui_bg_dim`, `ui_bg`). All three repeat: Tokyo Night spends `bg_dark1` twice, Mocha repeats `mantle` 3x and `crust` 2x, Gruvbox repeats `bg0_h` 4x. Repeats are cheap; a missing name is not. |
| above the window | 2 published (`bg_highlight`, `terminal_black`) + 2 blended (`222534`, `353b55`) | 4: `surface0`, `surface1`, `surface2`, `overlay0` | 4: `bg1`, `bg2`, `bg3`, `bg4` | Gruvbox and Mocha are the rich ones here; Tokyo Night publishes only two tones above the window and the other two are `Util.blend` midpoints of them. It is the *lower* half where the other two run out. |
| text ramp | 4: `c0caf5`, `a9b1d6`, `545c7e`, `565f89` | 5: `text`, `subtext1`, `subtext0`, `overlay1`, `overlay0` | 5: `fg1`, `fg2`, `fg3`, `fg4`, `gray` | Even, with one spare each. |
| ANSI 16 | **16 distinct** (the six bright chromatics are `Util.brighten` of the normals; `color8`/`color15` are `terminal_black` and `fg`, separate palette entries) | 10 distinct | **16 distinct** | Keep all 16 slots. Mocha is the one that fills slots with repeats; collapsing to 8 would flatten both Tokyo Night's brightened chromatics and Gruvbox's entire terminal identity. |

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

---

## 5. Per-file substitution worksheet

One block per file. Each row is `line : literal -> role`. Every code occurrence
counted under **What was counted** above appears exactly once below.

Substitution syntax for a file that already is a matugen template:

* normal: `{{colors.<role>.default.hex}}`
* qt6ct ARGB: `#ff{{colors.<role>.default.hex_stripped}}`
* qt6ct 50%: `#80{{colors.<role>.default.hex_stripped}}`
* channels (zathura `rgba()`, ranger): `{{colors.<role>.default.red}}` etc.

The four files in 5.7-5.10 are **not** matugen templates today. Their rows are
still `literal -> role`. Three of the four are read directly by the
application and are not rendered at all today; making them matugen templates
is the job the worksheet leaves open, not something this file decides.

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
48 : #343a52 -> fb_surface_container_high      surfaceContainerHigh
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
64 : #e0bbdd -> fb_tertiary                    tertiary
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

* 267 hex literals in the ten files in scope; 228 in code, 39 in comments.
* 46 distinct literals as written; 27 distinct once ARGB spellings are folded
  and comment-only values dropped.
* 9 hexes carry more than one meaning; `#1a1b26` carries four, `#15161e` five,
  `#c0caf5` six, `#414868` four, `#292e42` four.
* 74 roles: 23 base, 27 terminal, 7 semantic, 17 accent fallbacks.
* 17 Material 3 accent roles stay wallpaper-derived and unchanged.
* 227 substitutions across 10 files; 1 literal (`#000000`) deliberately kept.
* 4 roles cannot be filled from all three palettes without judgement; 1 of
  those (`fb_primary_container` on Catppuccin) has a visible consequence.
