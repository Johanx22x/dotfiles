<p align="center">
    <h1 align="center">dotfiles</h1>
</p>

<p align="center">
    Arch Linux + Hyprland, with a Material You accent palette generated from the wallpaper.
</p>

---

| | |
|---|---|
| Compositor | Hyprland, configured in **Lua** (`hyprland.lua`, not `hyprland.conf`) |
| Bar | Waybar |
| Terminal | kitty + zsh + starship |
| Launcher | wofi |
| Notifications | dunst |
| Login | SDDM |
| Files | ranger · Nautilus |
| Images / video / PDF | Loupe · Celluloid · zathura |
| Color | matugen |
| Boot | GRUB + btrfs snapshots (snapper) |

The base palette is fixed (Tokyo Night) and matugen only supplies the
**accents**, so contrast never depends on which wallpaper happens to be set.

---

## Install

```sh
git clone https://github.com/Johanx22x/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Six steps, each one asking first, so you can apply only the parts you want. It
is idempotent — re-running it is safe.

1. **Absolute paths.** If your home isn't `/home/johan`, rewrites the paths in
   the repo to match. matugen doesn't expand `~` in `output_path`, so absolute
   paths are unavoidable there; the installer handles it, you don't.
2. **Packages** from `paquetes/pacman.txt`.
3. **AUR** — installs `yay` if missing, then `paquetes/aur.txt`.
4. **Symlinks** the config with stow, and enables the user systemd units.
5. **Neovim** — clones [its own repo](https://github.com/Johanx22x/nvim).
6. **Palette** — runs `wallpaper-switch` so the generated color files exist.

Left to do by hand afterwards: `/etc` (see below), the monitor block in
`hyprland.lua`, and `chsh -s /usr/bin/zsh`.

---

## Layout

Every top-level directory is a **stow package** and mirrors the path it will
have relative to `$HOME`. So `stow hypr` creates
`~/.config/hypr/hyprland.lua -> ~/dotfiles/hypr/.config/hypr/hyprland.lua`.

```
zsh/        .zshrc
hypr/       .config/hypr/            hyprland.lua + gaming.lua
waybar/     .config/waybar/          config.jsonc + style.css
kitty/      .config/kitty/
wofi/       .config/wofi/
matugen/    .config/matugen/         config.toml + 12 color templates
ranger/     .config/ranger/          rc.conf, scope.sh, tokyonight colorscheme
shell/      .config/                 btop, starship, cship
qt/         .config/qt6ct/           Qt platform theme
gtk/        .config/                 gtk-3.0, gtk-4.0 settings
media/      .config/mpv/
openrgb/    .config/OpenRGB/
xdg/        .config/mimeapps.list    default applications
systemd/    .config/systemd/user/    wallpaper rotation timer
icons/      .local/share/icons/      app icons that don't ship with their package
bin/        .local/bin/              10 scripts
paquetes/   pacman and AUR package lists
sistema/    copies of /etc — reference only, NOT symlinked
```

`--no-folding` matters and the installer uses it: it links file by file instead
of linking whole directories. That keeps `~/.config/hypr` a real directory, so
matugen can write `colors.lua` into it without the generated file landing
inside the repo.

The flip side: a **new** file you create under a stowed directory is not in the
repo. Move it into the package and re-run `stow --no-folding <package>`.

---

## Color

`wallpaper-switch` sets the wallpaper and runs matugen, which renders twelve
files from the templates in `matugen/.config/matugen/templates/`:

```
~/.config/waybar/colors.css        ~/.config/gtk-3.0/gtk.css
~/.config/waybar/colors.json       ~/.config/gtk-4.0/gtk.css
~/.config/kitty/colors.conf        ~/.config/qt6ct/colors/matugen.conf
~/.config/hypr/colors.lua          ~/.config/ranger/accent
~/.config/wofi/colors.css          ~/.config/dunst/dunstrc
~/.config/zathura/zathurarc        ~/.config/fastfetch/config.jsonc
```

**None of these are in the repo** — they change with every wallpaper. Edit the
template, then `wallpaper-switch reapply`. They all carry a
`GENERADO POR MATUGEN` header so you notice when you're in the wrong file.

`dunstrc`, `zathurarc` and `fastfetch/config.jsonc` are generated *whole*, not
just their colors: those three can't include a separate color file. So their
template is the entire configuration, and they have no stow package.

**ranger** is the odd one: it's curses, so it only understands 256-color
palette indices, not hex. matugen writes just the accent as decimal RGB and the
colorscheme converts it to an index in Python at startup. Everything else
inherits the 16 ANSI colors kitty already defines.

---

## `/etc` — applied by hand

`sistema/` holds reference copies. **Don't symlink them**: root shouldn't read
its configuration from a directory the user can write to.

| File | Goes to | Watch out |
|---|---|---|
| `mkinitcpio.conf` | `/etc/mkinitcpio.conf` | no `kms` hook; `MODULES=(nvidia …)` for early KMS |
| `linux.preset`, `linux-lts.preset` | `/etc/mkinitcpio.d/` | classic image, not a UKI |
| `default-grub` | `/etc/default/grub` | `GRUB_TOP_LEVEL` pins `vmlinuz-linux` as the default entry |
| `fstab` | `/etc/fstab` | **the UUIDs belong to this machine** — regenerate them |
| `reflector.conf` | `/etc/xdg/reflector/` | mirrors |
| `sddm-10-general.conf` | `/etc/sddm.conf.d/10-general.conf` | theme, cursor, numlock |
| `sddm-Xsetup` | `/usr/share/sddm/scripts/Xsetup` | rotates the vertical monitor at the login screen |

Then: `sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg`.

Two things that are easy to get wrong:

**`/boot` is a directory inside the `@` subvolume**, not the ESP — the ESP is
mounted at `/efi`. That's what puts the kernel and initramfs inside the
snapshots, which is what makes a rollback produce a coherent system.

**The SDDM greeter runs on Xorg**, which knows nothing about Hyprland's
`transform`. Without `Xsetup` the vertical monitor comes up sideways on the
login screen. It matches outputs by resolution, not by name, because the names
differ between Xorg and Hyprland and change between boots.

---

## What is *not* in the repo

**Neovim** — [its own repo](https://github.com/Johanx22x/nvim). Vendoring it
here would make it a submodule and complicate cloning.

**The wallpapers** (47 MB). Not configuration, and git handles large binaries
poorly.

**`cship`** is a compiled binary. Its configuration *is* here, under `shell/`.

**Application state** — Brave, Discord, Firefox, GIMP, Steam, and
`github-copilot` and `gh`, which **hold credentials**.

---

## Hardware

Tuned for an i5-13600K, an RTX 5070 (Blackwell, needs `nvidia-open-dkms`) and
32 GB of RAM. Two monitors on the 5070: one 2560x1440@165 and one 1080p rotated
vertical.

Monitors are matched **by EDID description**, not by port name — the kernel
reassigns names like `DP-3` and `HDMI-A-1` between boots. On another machine
you'll need to adjust that block in `hyprland.lua`.
