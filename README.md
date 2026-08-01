# dotfiles

Configuración de Arch Linux + Hyprland con paleta Material You generada desde
el wallpaper.

| | |
|---|---|
| Compositor | Hyprland 0.56, config en **Lua** (`hyprland.lua`, no `hyprland.conf`) |
| Barra | Waybar |
| Terminal | kitty + zsh + starship |
| Lanzador | wofi |
| Notificaciones | dunst |
| Color | matugen — Material You desde el fondo de pantalla |
| Arranque | GRUB + snapshots btrfs (snapper) |

La base de color es fija (Tokyo Night) y matugen solo aporta los **acentos**,
para que el contraste no dependa de qué fondo tengas puesto.

---

## Instalación

```sh
git clone https://github.com/Johanx22x/dotfiles.git ~/dotfiles
cd ~/dotfiles
./instalar.sh
```

El script es idempotente y va preguntando antes de cada bloque. Si prefieres ir
a mano, los pasos están abajo.

### A mano

```sh
# 1. Paquetes
sudo pacman -S --needed stow - < paquetes/pacman.txt

# 2. yay (si no lo tienes) y los de AUR
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay && (cd /tmp/yay && makepkg -si)
yay -S --needed - < paquetes/aur.txt

# 3. Enlazar la configuración
cd ~/dotfiles
stow zsh hypr waybar kitty wofi matugen shell qt gtk media kde openrgb systemd bin

# 4. Neovim (repo aparte)
git clone https://github.com/Johanx22x/nvim.git ~/.config/nvim

# 5. Generar la paleta — sin esto faltan colores y varias apps salen en gris
mkdir -p ~/Pictures/wallpapers   # y mete alguna imagen dentro
~/.local/bin/wallpaper-switch random
```

---

## Estructura

Cada directorio de primer nivel es un **paquete de stow**: replica dentro la
ruta que tendrá relativa a `$HOME`. Así `stow hypr` crea
`~/.config/hypr -> ~/dotfiles/hypr/.config/hypr`.

```
zsh/        .zshrc
hypr/       .config/hypr/            Hyprland (Lua) + hyprpaper
waybar/     .config/waybar/          barra
kitty/      .config/kitty/           terminal
wofi/       .config/wofi/            lanzador
matugen/    .config/matugen/         config + plantillas de color
shell/      .config/                 btop, starship, cship
qt/         .config/                 qt6ct, QtProject
gtk/        .config/                 gtk-3.0, gtk-4.0
media/      .config/                 mpv, haruna
kde/        .config/                 dolphinrc, gwenviewrc, kiorc, trashrc
openrgb/    .config/OpenRGB/         iluminación
systemd/    .config/systemd/user/    timer de rotación de wallpaper
bin/        .local/bin/              scripts propios
paquetes/   listas de pacman y AUR
sistema/    copias de /etc — referencia, NO se enlazan
```

## Qué NO está en el repo, y por qué

**Los colores generados.** matugen reescribe once ficheros cada vez que cambias
de fondo. El repo guarda las **plantillas**; el resultado está en `.gitignore`.
Tras clonar hay que ejecutar `wallpaper-switch` una vez o varias apps saldrán
en gris.

**`dunstrc` y `fastfetch/config.jsonc`** se generan *enteros* desde plantilla,
no solo sus colores. Por eso no tienen paquete stow propio.

**Neovim.** Ya vive en [su propio repo](https://github.com/Johanx22x/nvim).
Meterlo aquí lo convertiría en submódulo y complicaría el clonado.

**Los wallpapers** (47 MB, 9 imágenes). No son configuración y git no lleva bien
los binarios grandes.

**`cship`** es un binario compilado de 4 MB. Su configuración sí está, en
`shell/`.

**Todo lo que no es rice**: Brave, Discord, Firefox, GIMP, Steam,
`github-copilot` (este último **contiene credenciales**).

## `/etc` — se aplica a mano

`sistema/` son copias de referencia. **No las enlaces**: root no debería leer su
configuración desde un directorio en el que el usuario puede escribir.

| Fichero | Destino | Ojo con |
|---|---|---|
| `mkinitcpio.conf` | `/etc/mkinitcpio.conf` | sin hook `kms`; `MODULES=(nvidia …)` para KMS temprano |
| `linux.preset`, `linux-lts.preset` | `/etc/mkinitcpio.d/` | imagen clásica, no UKI |
| `default-grub` | `/etc/default/grub` | `GRUB_TOP_LEVEL` fija `vmlinuz-linux` como predeterminado |
| `fstab` | `/etc/fstab` | **los UUID son de esta máquina**; regenéralos |
| `reflector.conf` | `/etc/xdg/reflector/` | mirrors |

Después: `sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg`.

Detalle no obvio: **`/boot` es un directorio dentro del subvolumen `@`**, no la
ESP — la ESP se monta en `/efi`. Eso mete kernel e initramfs dentro de los
snapshots, que es lo que hace que un rollback devuelva un sistema coherente.

## Si tu usuario no se llama `johan`

Hay **38 rutas absolutas `/home/johan`** repartidas por 7 ficheros, sobre todo
en `matugen/config.toml` (22, una por `output_path`) y en los módulos
`custom/` de Waybar. matugen no expande `~` en `output_path`, así que ahí la
ruta absoluta es obligatoria.

```sh
grep -rl /home/johan ~/dotfiles | xargs sed -i "s|/home/johan|$HOME|g"
```

## Hardware

Está afinado para: i5-13600K, RTX 5070 (Blackwell, `nvidia-open-dkms`), 32 GB.
Dos monitores en la 5070 — DP-4 a 2560x1440@165 y HDMI-A-3 en vertical.

Los monitores se referencian **por descripción EDID**, no por nombre de puerto.
En otra máquina hay que ajustar el bloque de monitores de `hyprland.lua`.
