<div align="center">

# dotfiles

**Arch Linux · Hyprland or niri · Quickshell**

The accent palette is generated from the wallpaper.

<br>

<img src="assets/preview-1.png" width="49%" alt="Desktop on a pink wallpaper: fastfetch in kitty, the island open on its Performance tab, Neovim and zathura">
<img src="assets/preview-2.png" width="49%" alt="Desktop on a blue wallpaper: Celluloid, Zen, Nautilus and the settings window on its Display page">

<sub>Two wallpapers, one desktop. Every accent above comes from the image behind it.</sub>

<br>
<br>

| | |
|---|---|
| **Compositor** | Hyprland in Lua, or niri in KDL — same keybinds either way |
| **Shell** | Quickshell — bar, island, launcher, notifications, settings |
| **Terminal** | kitty · zsh · starship |
| **Editor** | Neovim |
| **Browser** | Zen |
| **Files** | Nautilus · ranger |
| **Media** | Celluloid · Loupe · zathura |
| **Color** | matugen |
| **Session** | SDDM · GRUB · btrfs snapshots with snapper |

</div>

---

## Requirements

Arch Linux or an Arch-based distribution, `git`, a user with `sudo`, and a
network connection. Everything else the installer offers to fetch. Enable
`[multilib]` in `/etc/pacman.conf` first if you want the Steam packages — the
installer says so by name when it finds one it cannot reach without it.

## Install

```sh
git clone https://github.com/Johanx22x/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

It opens with a table: every unit, what state this machine is in, and a tick
box. The boxes arrive ticked for everything that is missing or has drifted, so
on a clean machine the first Enter means "yes, set this up" and every Enter
afterwards means "catch up on what has changed". What you tick is remembered, so
the second run is shorter than the first.

The compositor is the one thing settled before the table, because it decides
what gets installed and what gets linked — and it is **detected** rather than
asked: whichever of Hyprland and niri is installed is the one this machine
chose. Only a machine with neither gets the question, where a bare Enter takes
Hyprland. `--compositor=hyprland|niri|both` overrides either way. See
[Compositors](#compositors) below.

| | |
|---|---|
| `packages` | `packages/required/*.txt` and the chosen compositor's list — repo or AUR, worked out per name |
| `optional` | `packages/optional/*.txt`: apps, gaming, neovim, hardware. Tick a pack, or open one and tick packages inside it |
| `gpu` | `packages/gpu/<vendor>.txt`, with the card read off the bus and `none` as a real answer |
| `aur-patched` | builds `packages/xwayland-satellite/`, which carries a fix niri needs for DaVinci Resolve |
| `symlinks` | `stow` links the config into `$HOME` |
| `seeds` | copies `seeds/` where nothing exists yet — never overwrites |
| `nvim` | clones [Johanx22x/nvim](https://github.com/Johanx22x/nvim) into `~/.config/nvim` |
| `cursors` | downloads the Material Bibata pack into `~/.icons`, checksummed before it is unpacked |
| `palette` | a first `wallpaper-switch random` so the generated colour files exist |
| `shell` | `chsh -s /usr/bin/zsh` |
| `services-user` | the wallpaper and battery timers, and the polkit agent |
| `services-system` | SDDM, NetworkManager, bluetooth, and the snapshot, mirror and cache timers |
| `laptop` | battery and brightness widgets — asked, because no detection can answer it |
| `monitors` | says whether every attached screen is recorded, and prints the command that records one |

It refuses to run as root or off Arch. A package it cannot install is reported
and does not take the rest of the run with it. If files are in the way of the
symlinks it lists them and offers to move them to
`~/dotfiles-replaced-<timestamp>` — all of them or none, never deleting and
never adopting.

**Left to you:** the monitor layout, if the table listed a screen as not
recorded. That is a decision about where the screens physically are, and
nothing here can guess it.

**And everything outside `$HOME`.** The installer does not touch `/etc`, and no
unit reads it, reports on it or writes to it. What this machine needs out there
is kept in `system/` as documentation and applied by hand — see
[`system/README.md`](system/README.md), which says what each file is for and
which of them are about **this** machine rather than about a setup.

## Checking

```sh
./install.sh check
```

The same table, read-only. It uses no `sudo`, writes nothing, and is safe to run
at any moment on a working machine — which is the point of it: the way a desktop
like this goes wrong is quietly. A file that stopped being linked because `stow`
was never re-run, a timer that has been reporting `not-found` for a month, a
package that left with a dependency. None of that has a symptom until the day it
does.

It exits 1 when a unit that applies to this machine is not `ok`, so it works
from a keybind or a script, and `--json` gives the same answer to something that
would rather read it than look at it.

```sh
./install.sh check --json | jq -r '.[] | select(.kind != "ok") | .id'
./install.sh apply symlinks        # repair one row of the table
```

`apply` does exactly the units you name and does **not** pull in what they
require — the point of it is fixing one thing. It says what is missing
underneath, and `--with-requires` chains them if that is what you meant.

Every mode says in its **exit status** whether it did what it was asked: zero
when everything worked, non-zero when anything at all did not, whether it ended
the run or only got a line in the summary. So `./install.sh update && hyprctl
reload` means what it looks like.

## Updating

```sh
cd ~/dotfiles && git pull
```

The config lives in `$HOME` as symlinks back into this repo, so a pull is
already live for every file that was linked before. What a pull cannot do on its
own is add a package, link a file that is new, or enable a unit that did not
exist yesterday:

```sh
git pull && ./install.sh update
```

`update` asks nothing. It reads what this machine said it wanted, applies
whatever of that is not already in place, and runs the reload hooks. **It does
not pull by itself** — this repo is worked on from several sessions at once, and
a `git pull` hidden inside a command that also installs things is a surprise at
the wrong moment. `--pull` is there for an unattended run and is `--ff-only`.

Only niri picks the changes up reliably on its own — it holds no inotify watch
and polls its config every 500 ms, so nothing a pull or a relink does to the
file gets past it. Hyprland manages too in every case that was tried, but its
watch dies for good, and silently, if the file is ever unlinked with a gap
before it comes back, so it is worth telling. The shell has to be told too:

```sh
hyprctl reload && hyprctl configerrors    # Hyprland, and only if hypr/ moved
qs kill && qs -d --no-duplicate           # Quickshell
```

The shell has to be **restarted and not reloaded**, and there is no gentler
option — this was measured, after a cleverer-looking one had already shipped
and turned out to be a no-op. Quickshell reloads when the *content* of a `.qml`
file it is watching changes, which is what makes editing one feel live. A
`git pull` does not change content, it replaces inodes, and the watches die
with them: live file watches go from 122 to **zero**, nothing is logged, and
after that no filesystem operation reaches the shell at all — not touching a
file, not `chmod`, not creating or deleting one in the watched directories, not
even `stow -R`. Starting the process again is the only thing that works, and
one successful load re-registers every watch.

Know the asymmetry before automating it: a *reload* that cannot parse the tree
leaves the shell up on the code it already had, while a *start* on that same
tree exits 255 and leaves no bar, no island and no launcher until it is fixed.

`hyprctl reload` always answers `ok` and exits 0 — and so does `hyprctl
configerrors`, on a syntax error, on an unknown key and on a clean config
alike. Neither status means anything; the errors are the output.

`~/.config/nvim` is a separate repository and updates on its own.

### Without a terminal

Everything above is the second time onward, which is exactly the part that was
tedious: none of it announces itself, so keeping a machine current meant
remembering to go and ask. The shell asks instead.

There is a widget on the bar — **Updates**, next to the gear — carrying the
number of units that are not `ok`, in the same colours the check table uses:
yellow for `missing`, red for `drift`. Clicking it opens the **Updates** page in
the settings window, which is the check table with a chip per row, the optional
packs as boxes you can open package by package, and a button.

It runs `./install.sh check --json` — the same read-only mode, taking the same
three seconds — and it does **not** run it on a timer. It checks once a quarter
of a minute into a session, when the machine comes back from suspend, when the
page is looked at, after it has applied anything, and whenever it is asked:

```sh
qs ipc call updates check     # look again now
qs ipc call updates status    # what it last found, as a sentence
qs ipc call updates open      # open the page
```

**It never runs anything as root.** The units that write into `$HOME` —
`symlinks`, `seeds`, `nvim`, `cursors`, `palette`, `services-user`, `laptop`,
`monitors` — run from the button, in your session, as you. The ones that install
packages or change your login shell open a terminal running the same command you
would have typed:

```sh
kitty --hold --directory ~/dotfiles -e ./install.sh apply packages
```

`pkexec` and the polkit agent are deliberately not used. They would run the
whole installer as root, and a `~/.config` owned by root is how a desktop stops
being editable by the person who owns it — which is why `install.sh` refuses to
run as root at all. Splitting privilege inside one process is worse than not
splitting it.

Ticking a pack writes the same `${XDG_STATE_HOME:-~/.local/state}/dotfiles-profile`
that `update` reads, so the window and the terminal are two ways of saying one
thing rather than two places to say it.

One thing it will not do: **a first install is still a terminal** — a fresh
clone has no desktop to draw on.

## Compositors

Two flavors, chosen at install time and switched at the display manager. They
are not exclusive: answer **both** and each session appears separately in SDDM,
so one can be tried without dismantling the other.

Built and tested against **Hyprland 0.56** and **niri 26.04**. Where a version
matters — and it does more than once, because both move fast — the config says
so next to the line that depends on it.

| | Hyprland | niri |
|---|---|---|
| Model | dynamic tiling (dwindle) | scrollable tiling (columns) |
| Config | `hypr/` — Lua, inotify + `hyprctl reload` | `niri/` — KDL, polls every 500 ms |
| Packages | `packages/compositor/hyprland.txt` | `packages/compositor/niri.txt` |
| Session | `uwsm` | `niri-session` |
| Portal | `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-gnome` |

| Workspaces | numbered, permanent | dynamic, renumbered as they empty |
| Blur | global, behind anything translucent | per window, asked for by a rule |
| Blue light | `hyprsunset` | `wl-gammarelay-rs` |

**Every keybind is the same in both.** Four Hyprland actions have no niri
equivalent, and rather than leave those chords dead each went to the nearest
thing niri actually does: pseudotile cycles the preset column widths,
togglesplit stacks the column as tabs, pin jumps between the floating and tiled
layers, and the magic scratchpad — niri has none, and faking one cost a
permanent workspace — became "back to the previous workspace".

What niri can do and Hyprland cannot is bound on chords that were free: the
overview on `SUPER + Tab`, moving and consuming columns, the ends of the strip,
monitor focus. Every one of those decisions is written next to the bind it
belongs to in `niri/.config/niri/config.kdl`.

**Workspaces behave differently and that is not configurable.** niri creates
them as you need them and renumbers when one empties, so `SUPER + 3` is the
third workspace *at that moment*. Ten named, permanent ones were built to fix
that and then taken out again: named workspaces exist whether or not anything is
on them, so the overview always showed ten slots with nine empty. The bar can
filter empties; the compositor's overview cannot. Stable numbers or an honest
overview — there is no third option, and the trade-off is written into the
config.

### Adding a third one

The shell never asks which compositor is running. It asks what the running one
**can do**, and draws accordingly — so a compositor that cannot report window
counts, or has no way to grab focus, is a supported case rather than a broken
one.

```
quickshell/Compositor.qml       the facade — the only file that knows there is
                                more than one
  compositor/
    CompositorBackend.qml       the contract: every property has an empty
                                default, every capability defaults to false
    HyprlandBackend.qml
    NiriBackend.qml
bin/compositor                  the same idea for shell scripts:
                                `compositor is niri`, `compositor can gamma`
```

A new backend is one file, one `Component` and one `case` in the detector.
Nothing else changes, because every consumer already handles the "cannot"
path — niri exercises it today. **An unknown compositor is supported too:** with
no match the plain contract loads, so the bar, clock, tray and notifications
come up while the compositor-dependent parts stay away, and the settings pages
that need one are not offered at all.

Anything answerable through a protocol everyone speaks lives in the base rather
than in a backend — fullscreen detection goes through
`wlr-foreign-toplevel`, and logout falls back to logind — so a new compositor
gets those for free.

**Settings reach both flavors through one script.** `desktop-tweak` — the old
`hypr-tweak`, renamed once it stopped being about one compositor — keeps a
single state file and writes an override layer per flavor: `tweaks.lua` for
Hyprland, `tweaks.kdl` for niri, both gitignored and both read last by their
config. Applying differs and nothing else does: Hyprland is told with `hyprctl
eval`, while niri watches the files it includes, so writing one is what applies
it.

`desktop-monitors` — the old `hypr-monitor` — does the same for the display page:
it lists what is connected in one shape whichever compositor answered, applies a
provisional change, and writes the confirmed one into `monitors.lua` or
`monitors.kdl`. The one thing that is **not** symmetric is what that file is.
Under Hyprland it is an override layer on top of the monitor block in
`hyprland.lua`; under niri it is the only declaration of any output there is,
because an `output` block in an included file is ignored when the including file
names the same monitor. So `config.kdl` declares none and includes the generated
file first — and the display page's *Copy config* chip, which hands you a block
to paste into the tracked config, is not offered there: pasting one in would
shadow the generated file for good.

The niri flavor gets a **second** generated file out of the same script and the
same choice, `main-monitor.kdl`, and it is second because the two want opposite
positions. It carries the main-monitor choice as `open-on-output` on the five
window rules that have to open there — games, Big Picture, the capture card,
RetroArch and Resolve — and a window rule has to be included *after* the rules it
overrides, where an output block has to come *first*. With no such file those
five rules carry no `open-on-output` and their windows open wherever niri
decides. Hyprland needs no equivalent: `monitors.lua` reassigns `MONITOR_MAIN`
and `gaming.lua` reads it afterwards.

### What niri cannot do

Not a to-do list — these were each tried, measured and written down:

| | |
|---|---|
| **Per-device input** | niri has none at all, so the DualSense touchpad quirk has no home. The equivalent is a libinput rule in `/etc`, which `install.sh` does not touch |
| **Window geometry** | `tile_pos_in_workspace_view` is null even for visible windows, so *record a window* cannot snap to one and falls back to a free drag |
| **Make main** | only moves the shell. Which monitor games open on is an `open-on-output` on their window rules, and a generated copy of that would go out of step |
| **Shared workspaces** | a workspace belongs to one monitor. Focusing one that lives on the other moves focus there, which is as close as it gets |

And for gaming, unchanged by any of this: niri has no explicit sync, no
tearing control, Steam Input does not move the cursor, and Alt+Tab shrinks
fullscreen Steam games. Those are upstream.

One mapping is close rather than exact: Hyprland has two gap values and niri
has one, so the inner gap maps directly and the outer becomes a strut.

## Layout

**Most** top-level directories are stow packages, mirroring their path under
`$HOME`, so `stow hypr` links `~/.config/hypr/hyprland.lua` back into the repo:

```
zsh   hypr    niri        quickshell  kitty   matugen  shell
gtk   media   openrgb     systemd     bin     ranger   icons   zen
gaming        backup
```

Six are not, and the difference matters:

| | |
|---|---|
| `seeds/` | **copied**, once, and never again — `seeds/README.md` opens by forbidding `stow seeds` in bold. These are the files applications rewrite, so a symlink into the repo would mean a dirty tree on every machine |
| `system/` | the `/etc` layer, which pacman owns and would leave `.pacnew` files beside. Copies and recipes, **documentation and applied by hand** — the installer has no unit for them, and half of them describe this one machine. See `system/README.md` |
| `packages/` | the package lists, grouped by what they are for |
| `lib/` | the installer's own code: the unit registry and one file per unit |
| `tests/` | the checks CI runs on every pull request |
| `assets/` | the screenshots at the top of this file |

`bin/` holds the scripts that own everything the shell can change at runtime —
the wallpaper, the palette, the opacity, the monitors — so any of it can be
driven from a terminal and the settings window follows. `bin/compositor` is how
those scripts find out what they are running under.

## Wallpapers and color

`wallpaper-switch` sets the wallpaper and runs matugen, which renders eleven
untracked files for kitty, GTK 3/4, Hyprland, **niri**, Qt, zathura, ranger,
fastfetch, Zen and the shell. The base palette is fixed (Tokyo Night) and
matugen supplies only the accents, so contrast never depends on which image is
set.

A wallpaper can also be a video: `mp4` `webm` `mkv` play through mpvpaper with
hardware decoding, pausing when covered or when anything goes fullscreen, while
stills and animated GIFs go through awww.

You pick one by looking at it. **SUPER + SHIFT + W** opens a fullscreen
carousel of the collection — five cards at a time, the middle one large and, if
it is a live wallpaper, playing. Enter applies, Escape leaves the desktop as it
was. The settings window keeps what is around the collection: which folder it
is, how often it rotates by itself, and which wallpaper is on the desktop now.

```sh
wallpaper-switch next | prev | random | reapply
wallpaper-switch set ~/Pictures/Wallpapers/loop.mp4
wallpaper-switch dir pick            # move the collection somewhere else
wallpaper-switch still               # freeze a live wallpaper where it is
wallpaper-switch thumbs              # rebuild the caches the carousel draws
```

Those caches are three, under `~/.cache`: a 960 px thumbnail of every
wallpaper, because decoding a 4K PNG to fill a card costs a fifth of a second;
a still frame of every video, because nothing else can draw one; and a short
960x540 copy of every video, which is what the carousel actually plays instead
of a 4K file. They are built in the background, skipped when they are already
newer than their source, and swept when a wallpaper goes away.

## Backups

`borg` for the archives and `borgmatic` for the policy around them, on a daily
user timer. What is saved is the irreplaceable and only that — `~/.ssh`,
`~/.gnupg`, `~/Projects`, `~/Documents`, `~/Pictures`, about 2.7 GB — because
everything else on this machine is a package, a lockfile or a download away
from coming back.

`backup/.config/borgmatic/config.yaml` is tracked and holds the whole policy:
the sources, the excludes, how long archives are kept and how often borg is
asked to verify itself. Every choice in it is commented with the measurement
behind it — `~/Projects` is 189,883 files, and 176,342 of those are inside a
`node_modules`, which is why one exclude line takes the nightly walk down to
13,541 files and 2.1 GB.

**The two values that belong to one machine are never committed.** Where the
archives go and what opens them live in `~/.config/borgmatic/local.env`, which
is gitignored, and the tracked config reads them as `${BORG_REPO}` and
`${BORG_PASSPHRASE}`. This repository is public, so `tests/backup-secrets.sh`
runs in CI and fails the pull request if either one is ever written out as a
literal.

```sh
backup            # what the last run did, and when the next one is
backup run        # create, prune and check now — what the timer calls
backup list       # the archives in the repository, newest last
backup restore    # print the recipe for getting a file back, run nothing
```

### Setting it up

Nothing starts by itself. These are the commands, in order, and they are the
only ones — after the last of them the machine backs itself up nightly.

```sh
# 1. The tools. ./install.sh apply optional, with the backup group ticked,
#    does the same thing.
sudo pacman -S --needed borg borgmatic

# 2. Link the configuration and the units. `backup` is not in the installer's
#    stow list yet, so it is linked by hand.
cd ~/dotfiles && stow --no-folding -t ~ backup systemd bin

# 3. This machine's own two values, with a fresh passphrase. Change the path
#    to wherever the archives should go — a second disk, an external drive.
install -d -m 700 ~/.config/borgmatic
install -m 600 /dev/null ~/.config/borgmatic/local.env   # mode first, contents after
printf 'BORG_REPO=%s\nBORG_PASSPHRASE=%s\n' \
    /mnt/datos-nvme/borg "$(openssl rand -base64 32)" \
    > ~/.config/borgmatic/local.env

# 4. READ IT NOW AND PUT THE PASSPHRASE SOMEWHERE THAT IS NOT THIS MACHINE.
#    A password manager, a piece of paper, anywhere else. Step 5 encrypts the
#    repository with it and there is no way back in without it — including,
#    and especially, on the day this machine is the thing that died.
cat ~/.config/borgmatic/local.env

# 5. Create the repository. `repokey` puts the encrypted key inside the
#    repository itself, so the passphrase from step 4 is the only thing that
#    has to survive independently — with `keyfile` the key would live in
#    ~/.config/borg/keys on this machine, and a dead disk would take the key
#    and the only copy of it at once.
BORG_REPO="$(sed -n 's/^BORG_REPO=//p' ~/.config/borgmatic/local.env)"
BORG_PASSPHRASE="$(sed -n 's/^BORG_PASSPHRASE=//p' ~/.config/borgmatic/local.env)"
export BORG_REPO BORG_PASSPHRASE
borgmatic repo-create --encryption repokey

# 6. The first backup, watched.
backup run

# 7. Nightly from here on.
systemctl --user daemon-reload
systemctl --user enable --now backup.timer
```

`backup.timer` is `OnCalendar=daily` with `Persistent=true`, so a machine that
is switched off at midnight is backed up as soon as it comes back rather than
skipped. It is a **user** timer, so it runs while somebody is logged in;
`loginctl enable-linger $USER` is what makes it run without a session, and is
only worth it on a machine that is left on and logged out.

### What this does and does not protect against

A copy on a disk inside this machine **does not** survive theft, fire or the
whole machine dying. What it does survive is the main NVMe failing and, far
more likely, deleting or overwriting something and noticing months later —
which is what the retention is sized for: two weeks of daily archives, two
months of weekly, a year of monthly.

The way out of that limitation is one entry, not a rewrite. borg pushes to a
remote over SSH, so a second line under `repositories:` —
`ssh://user@host/./name.borg` — adds an offsite copy with the same sources, the
same excludes and the same retention, sending only the chunks the far end does
not already have.

## Per-machine

No tracked file names a home directory, and none names a monitor either. What
belongs to one machine stays out of git: `hypr/monitors.lua`, `niri/monitors.kdl`
and `niri/main-monitor.kdl`, written by `desktop-monitors` or the settings
window, and the state files under `~/.local/state` that the scripts and the shell
share — so a value set from a terminal moves the switch in the
settings window, and back.

The installer keeps its own answers there too, in
`~/.local/state/dotfiles-profile`: which compositor, which GPU, which units this
machine wants and which optional packs. Same format as the rest — `key<TAB>value`
per line, sorted — so it diffs, greps and can be edited by hand. A package only
gets a line of its own when it disagrees with its group:

```
compositor        both
gpu.vendor        nvidia
group.gaming      1
pkg.gaming.steam  0
unit.optional     1
```

That is the file `update` reads. Delete it and the next `./install.sh` asks
again from what the machine looks like.

## Keybinds

`SUPER + /` opens the cheatsheet, which lists every binding that carries a
description — including itself.

## Credits

The mouse cursors are [Bibata](https://github.com/ful1e5/Bibata_Cursor), in the
Material 3 recolouring by
[SakibShahariar](https://github.com/SakibShahariar/material-bibata-cursor) —
28 themes, one per accent family, which is what lets the pointer follow the
wallpaper without rebuilding anything.
