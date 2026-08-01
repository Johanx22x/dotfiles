#!/usr/bin/env bash
# Replica este setup en una maquina Arch limpia.
#
# Idempotente: se puede volver a lanzar. Pregunta antes de cada bloque, asi que
# se puede usar para aplicar solo una parte.
#
# NO toca /etc: eso se hace a mano, ver sistema/README y el README principal.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAQUETES=(zsh hypr waybar kitty wofi matugen shell qt gtk media kde openrgb systemd bin)

azul()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
rojo()  { printf '\033[1;31m%s\033[0m\n' "$*"; }

preguntar() {
  local r
  read -rp "$(printf '\033[1;33m%s\033[0m [s/N] ' "$1")" r
  [[ "$r" =~ ^[sSyY]$ ]]
}

[[ -f /etc/arch-release ]] || { rojo "Esto es para Arch Linux."; exit 1; }
[[ $EUID -eq 0 ]] && { rojo "No lo lances como root. Pide sudo cuando lo necesita."; exit 1; }

# ---------------------------------------------------------------------------
azul "== 1/5  Paquetes de los repos oficiales =="
echo "   $(wc -l < "$DOT/paquetes/pacman.txt") paquetes en paquetes/pacman.txt"
if preguntar "Instalarlos (mas stow)?"; then
  sudo pacman -S --needed --noconfirm stow
  # --needed salta los ya instalados; el < redirige la lista a stdin
  sudo pacman -S --needed - < "$DOT/paquetes/pacman.txt"
  verde "   hecho"
fi

# ---------------------------------------------------------------------------
azul "== 2/5  Paquetes de AUR =="
if preguntar "Instalar yay y los de paquetes/aur.txt?"; then
  if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm )
    rm -rf "$tmp"
  fi
  # yay se instala solo, quitarlo de la lista evita que intente reconstruirse
  grep -v '^yay$' "$DOT/paquetes/aur.txt" | yay -S --needed -
  verde "   hecho"
fi

# ---------------------------------------------------------------------------
azul "== 3/5  Enlazar la configuracion (stow) =="
echo "   paquetes: ${PAQUETES[*]}"
if preguntar "Enlazar?"; then
  command -v stow >/dev/null || { rojo "   falta stow"; exit 1; }
  # --no-folding: crea directorios reales y enlaza fichero a fichero, en vez
  # de enlazar el directorio entero. Asi una app que escriba un fichero nuevo
  # en ~/.config/algo no lo mete dentro del repo sin querer.
  if ! stow --no-folding -v -t "$HOME" -d "$DOT" "${PAQUETES[@]}"; then
    rojo "   stow encontro conflictos: ya existen esos ficheros."
    echo  "   Revisa que son y muevelos, o relanza con --adopt para que stow"
    echo  "   los absorba dentro del repo (OJO: eso sobrescribe lo del repo)."
    exit 1
  fi
  # Los enlaces de *.target.wants no se versionan (apuntan a rutas absolutas
  # del home original y colgarian con otro usuario). Se recrean aqui.
  systemctl --user daemon-reload
  systemctl --user enable --now wallpaper-rotate.timer
  systemctl --user enable --now hyprpolkitagent.service 2>/dev/null || true
  verde "   hecho"
fi

# ---------------------------------------------------------------------------
azul "== 4/5  Neovim (repo aparte) =="
if [[ -e "$HOME/.config/nvim" ]]; then
  echo "   ~/.config/nvim ya existe, no lo toco"
elif preguntar "Clonar Johanx22x/nvim en ~/.config/nvim?"; then
  git clone https://github.com/Johanx22x/nvim.git "$HOME/.config/nvim"
  verde "   hecho"
fi

# ---------------------------------------------------------------------------
azul "== 5/5  Generar la paleta de color =="
echo "   Sin esto faltan colors.css, colors.lua, gtk.css... y varias apps"
echo "   salen en gris. Necesita al menos una imagen en ~/Pictures/wallpapers."
if preguntar "Generarla ahora?"; then
  mkdir -p "$HOME/Pictures/wallpapers"
  if ! find -L "$HOME/Pictures/wallpapers" -maxdepth 2 -type f \
       \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
       | grep -q .; then
    rojo "   No hay imagenes en ~/Pictures/wallpapers."
    echo  "   Mete alguna y luego: wallpaper-switch random"
  else
    "$HOME/.local/bin/wallpaper-switch" random
    verde "   hecho"
  fi
fi

# ---------------------------------------------------------------------------
echo
verde "== Listo =="
cat <<'FIN'

Queda por hacer a mano:

  1. /etc  — ver sistema/ y la tabla del README. Los UUID del fstab son de la
             maquina original: NO lo copies tal cual.
  2. Monitores — hyprland.lua los referencia por descripcion EDID. En otro
             equipo hay que ajustar ese bloque.
  3. zsh como shell por defecto, si no lo es:
             chsh -s /usr/bin/zsh
FIN
