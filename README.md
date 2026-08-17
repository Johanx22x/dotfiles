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
`[multilib]` in `/etc/pacman.conf` first if you want the Steam packages.

## Install

```sh
git clone https://github.com/Johanx22x/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

It opens by asking which compositor this machine gets — Hyprland, niri, or both
— because that decides what gets installed and what gets linked. A bare Enter
takes Hyprland, which is the default and the one everything here was built
against. See [Compositors](#compositors) below.

Then six steps, each asking before it acts:

| | |
|---|---|
| **1 · Packages** | `packages/pacman.txt` and the chosen compositor's list, plus `packages/multilib.txt` if multilib is on |
| **2 · AUR** | builds `yay` if missing, then `packages/aur.txt` |
| **3 · Symlinks** | `stow` links the config into `$HOME` |
| **4 · Seeds** | copies `seeds/` where nothing exists yet — never overwrites |
| **5 · Neovim** | clones [Johanx22x/nvim](https://github.com/Johanx22x/nvim) into `~/.config/nvim` |
| **6 · Palette** | a first `wallpaper-switch random` so the generated colour files exist |

It refuses to run as root or off Arch, and skips a package it cannot find
instead of aborting the transaction. If files are already in the way, it lists
them and offers to move them to `~/dotfiles-replaced-<timestamp>` — it never
deletes and never adopts.

Then it asks whether this is a laptop (battery and brightness widgets, off by
default) and prints every attached monitor with the command that records it.

**Left to you:** the GPU driver, `/etc`, `chsh -s /usr/bin/zsh`, and the
monitors if the check listed one as unconfigured.

## Updating

```sh
cd ~/dotfiles && git pull
```

The config lives in `$HOME` as symlinks back into this repo, so a pull is
already live for every file that was linked before. Re-run `./install.sh` when a
release adds new files or packages — it is idempotent, and steps you do not want
can be answered no.

Nothing running picks the changes up on its own:

```sh
hyprctl reload                                        # Hyprland
                                                      # niri reloads on save
qs kill && qs -d -p ~/.config/quickshell/shell.qml    # Quickshell
```

`~/.config/nvim` is a separate repository and updates on its own.

## Compositors

Two flavors, chosen at install time and switched at the display manager. They
are not exclusive: answer **both** and each session appears separately in SDDM,
so one can be tried without dismantling the other.

| | Hyprland | niri |
|---|---|---|
| Model | dynamic tiling (dwindle) | scrollable tiling (columns) |
| Config | `hypr/` — Lua, `hyprctl reload` | `niri/` — KDL, reloads on save |
| Packages | `packages/hyprland.txt` | `packages/niri.txt` |
| Session | `uwsm` | `niri-session` |
| Portal | `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-gnome` |

**Every keybind is the same in both.** Four Hyprland actions have no niri
equivalent, so their chords were given to the nearest thing niri does rather
than left dead — pseudotile becomes cycling the preset column widths,
togglesplit becomes tabbed columns, pin becomes jumping between the floating and
tiled layers, and the magic scratchpad becomes a named workspace. What niri can
do and Hyprland cannot is bound on chords that were free: the overview, moving
and consuming columns, the ends of the strip, monitor focus. Each one is marked
in `niri/.config/niri/config.kdl`, which is where the reasoning lives.

**What the niri flavor does not do yet.** The shell comes up and everything that
does not need the compositor works — tray, clock, notifications, media, the
island — while four things go quiet, because they talk to Hyprland's IPC:
workspace pills, the active window title, click-outside-to-close on popouts, and
the cheatsheet. The wallpaper is set but its accent does not reach the focus
ring, and `night-light` needs wiring to `wlsunset` (`hyprsunset` drives a
Hyprland-only protocol and would run doing nothing).

## Layout

Every top-level directory is a stow package mirroring its path under `$HOME`, so
`stow hypr` links `~/.config/hypr/hyprland.lua` back into the repo.

```
zsh   hypr    niri        quickshell  kitty  matugen  shell
gtk   media   openrgb     systemd     bin    ranger   icons   zen
```

`bin/` holds the scripts that own everything the shell can change at runtime —
the wallpaper, the palette, the opacity, the monitors — so any of it can be
driven from a terminal and the settings window follows.

## Wallpapers and color

`wallpaper-switch` sets the wallpaper and runs matugen, which renders ten
untracked files for kitty, GTK 3/4, Hyprland, Qt, zathura, ranger, fastfetch,
Zen and the shell. The base palette is fixed (Tokyo Night) and matugen supplies
only the accents, so contrast never depends on which image is set.

A wallpaper can also be a video: `mp4` `webm` `mkv` play through mpvpaper with
hardware decoding, pausing when covered or when anything goes fullscreen, while
stills and animated GIFs go through awww.

```sh
wallpaper-switch next | prev | random | reapply
wallpaper-switch set ~/Pictures/Wallpapers/loop.mp4
wallpaper-switch dir pick            # move the collection somewhere else
```

## Per-machine

No tracked file names a home directory. What belongs to one machine stays out of
git: `hypr/monitors.lua`, written by `hypr-monitor` or the settings window, and
the state files under `~/.local/state` that the scripts and the shell share — so
a value set from a terminal moves the switch in the settings window, and back.

## Keybinds

`SUPER + /` opens the cheatsheet, which lists every binding that carries a
description — including itself.
