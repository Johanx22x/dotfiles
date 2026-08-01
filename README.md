<p align="center">
    <h1 align="center">dotfiles</h1>
</p>

<p align="center">
    Arch Linux + Hyprland, with a Material You accent palette generated from the wallpaper.
</p>

---

| | |
|---|---|
| Compositor | Hyprland 0.56, configured in **Lua** (`hyprland.lua`, not `hyprland.conf`) |
| Bar | Waybar |
| Terminal | kitty + zsh + starship |
| Launcher | wofi |
| Notifications | dunst |
| File managers | ranger (terminal) · Nautilus (GUI) |
| Color | matugen — Material You, extracted from the wallpaper |
| Boot | GRUB + btrfs snapshots (snapper) |

The base palette is fixed (Tokyo Night) and matugen only supplies the
**accents**, so contrast never depends on which wallpaper happens to be set.

---

## Install

```sh
git clone https://github.com/Johanx22x/dotfiles.git ~/dotfiles
cd ~/dotfiles
./instalar.sh
```

The script is idempotent and prompts before each block, so you can use it to
apply only part of it. To do it by hand:

```sh
# 1. Packages
sudo pacman -S --needed stow - < paquetes/pacman.txt

# 2. yay (if you don't have it) and the AUR packages
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay && (cd /tmp/yay && makepkg -si)
yay -S --needed - < paquetes/aur.txt

# 3. Symlink the configuration
cd ~/dotfiles
stow --no-folding zsh hypr waybar kitty wofi matugen shell qt gtk \
                  media kde openrgb systemd bin ranger

# 4. Neovim (separate repo)
git clone https://github.com/Johanx22x/nvim.git ~/.config/nvim

# 5. Generate the palette — without this several apps come up grey
mkdir -p ~/Pictures/wallpapers   # drop an image in there
~/.local/bin/wallpaper-switch random
```

`--no-folding` matters: it links file by file instead of linking whole
directories. That keeps `~/.config/hypr` a real directory, so matugen can write
`colors.lua` into it without the generated file landing inside the repo.

---

## Layout

Every top-level directory is a **stow package** and mirrors the path it will
have relative to `$HOME`. So `stow hypr` creates
`~/.config/hypr/hyprland.lua -> ~/dotfiles/hypr/.config/hypr/hyprland.lua`.

```
zsh/        .zshrc
hypr/       .config/hypr/            Hyprland (Lua) + gaming profile
waybar/     .config/waybar/          bar
kitty/      .config/kitty/           terminal
wofi/       .config/wofi/            launcher
matugen/    .config/matugen/         config + color templates
shell/      .config/                 btop, starship, cship
qt/         .config/qt6ct/           Qt platform theme
gtk/        .config/                 gtk-3.0, gtk-4.0
media/      .config/                 mpv, haruna
ranger/     .config/ranger/          terminal file manager
kde/        .config/                 gwenviewrc, kiorc, trashrc
openrgb/    .config/OpenRGB/         lighting
systemd/    .config/systemd/user/    wallpaper rotation timer
bin/        .local/bin/              own scripts
paquetes/   pacman and AUR package lists
sistema/    copies of /etc — reference only, NOT symlinked
```

## Theming, and where it stops working

matugen renders eleven files from the templates in
`matugen/.config/matugen/templates/`. GTK, Qt (through qt6ct), kitty, Waybar,
wofi, dunst, fastfetch and ranger all pick up the accent.

**KF6 apps are the exception, and it can't be fixed from here.**
`libKF6ColorScheme` listens on `QStyleHints::colorSchemeChanged`, sees the XDG
portal asking for dark mode, and applies its own internal BreezeDark *on top of*
whatever the platform theme set. Verified by putting an impossible red (255,0,0)
in `[Colors:Window]` and counting pixels: 0% red. That defeats, in order, the
`[Colors:*]` sections of `kdeglobals`, a custom `.colors` file in
`~/.local/share/color-schemes/`, `KDE_COLOR_SCHEME_PATH`,
`[UiSettings] ColorScheme=`, and the qt6ct palette.

The only thing that hands control back is `plasma-integration`, which drags in
`xdg-desktop-portal-kde` — a second portal competing with Hyprland's, putting
screen capture and recording at risk. Not worth it for a file manager. The fix
was to change the app instead: **Dolphin out, Nautilus in** (GTK4, themed by the
GTK template). Gwenview is the last KF6 app left and stays Breeze grey.

Qt6 apps that aren't KDE apps do get themed, through qt6ct.

**ranger** is a different case: it's curses, so it doesn't understand hex, only
indices into the 256-color palette. matugen writes just the accent as decimal
RGB and the colorscheme converts it to an index in Python at startup. Everything
else — background, text, directories, permissions — stays on the 16 ANSI colors
kitty already defines, so ranger inherits Tokyo Night for free.

## What is *not* in the repo, and why

**The generated colors.** matugen rewrites eleven files every time the wallpaper
changes. The repo tracks the **templates**; the output is in `.gitignore`. After
cloning you have to run `wallpaper-switch` once or several apps will be grey.

**`dunstrc` and `fastfetch/config.jsonc`** are generated *whole* from a
template, not just their colors. That's why they have no stow package of their
own.

**Neovim.** It lives in [its own repo](https://github.com/Johanx22x/nvim).
Vendoring it here would make it a submodule and complicate cloning.

**The wallpapers** (47 MB, 9 images). Not configuration, and git handles large
binaries poorly.

**`cship`** is a 4 MB compiled binary. Its configuration *is* here, under
`shell/`.

**Anything that isn't rice**: Brave, Discord, Firefox, GIMP, Steam, and
`github-copilot` — that last one **holds credentials**.

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

Then: `sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg`.

One non-obvious detail: **`/boot` is a directory inside the `@` subvolume**, not
the ESP — the ESP is mounted at `/efi`. That's what puts the kernel and
initramfs inside the snapshots, which is what makes a rollback produce a
coherent system.

## If your user isn't named `johan`

There are **38 absolute `/home/johan` paths** across 7 files, mostly in
`matugen/config.toml` (22 of them, one per `output_path`) and in Waybar's
`custom/` modules. matugen doesn't expand `~` in `output_path`, so the absolute
path is mandatory there.

```sh
grep -rl /home/johan ~/dotfiles | xargs sed -i "s|/home/johan|$HOME|g"
```

## Hardware

Tuned for an i5-13600K, an RTX 5070 (Blackwell, needs `nvidia-open-dkms`) and
32 GB of RAM. Two monitors on the 5070 — DP-4 at 2560x1440@165 and HDMI-A-3
rotated vertical.

Monitors are matched **by EDID description**, not by port name. On another
machine you'll need to adjust that block in `hyprland.lua`.
