# shellcheck shell=bash
# The generated colour files.
#
# Without them colors.css, colors.lua, gtk.css and eight others are missing and
# several applications come up grey. One `wallpaper-switch random` writes all of
# them, which is why this step is a single command and not a template engine.

palette_meta() {
  echo "Colour palette"
  echo "a first 'wallpaper-switch random' so the generated files exist"
}

# wallpaper-switch and the matugen config both arrive through stow.
palette_requires() { echo symlinks; }
palette_available() { :; }

# WHAT MATUGEN WRITES, READ OUT OF MATUGEN'S OWN CONFIG. There are eleven
# outputs and the list has grown twice; hard-coding it here would mean a check
# that passes on a machine missing the newest one, which is exactly the sort of
# quiet wrongness this mode exists to catch. `~` is expanded because matugen
# writes the paths with a tilde and nothing else expands it for us.
palette_outputs() {
  local conf="$DOT/matugen/.config/matugen/config.toml" path
  [[ -f $conf ]] || return 0
  while IFS= read -r path; do
    printf '%s\n' "${path/#\~/$HOME}"
  done < <(grep -oP "^output_path\s*=\s*'\K[^']+" "$conf")
}

palette_check() {
  local path total=0 missing=0

  while IFS= read -r path; do
    total=$(( total + 1 ))
    [[ -f $path ]] || missing=$(( missing + 1 ))
  done < <(palette_outputs)

  if (( total == 0 )); then
    echo "na:matugen's config has no outputs"
  elif (( missing )); then
    echo "missing:$missing of $total generated files"
  else
    echo ok
  fi
}

palette_apply() {
  ui_say "   Needs at least one image in ~/Pictures/wallpapers."
  run mkdir -p "$HOME/Pictures/wallpapers"

  if ! find -L "$HOME/Pictures/wallpapers" -maxdepth 2 -type f \
       \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
       | grep -q .; then
    ui_bad "   No images in ~/Pictures/wallpapers."
    ui_say "   Drop one in and then run: wallpaper-switch random"
    FAILED+=("palette: no wallpapers to generate it from")
    return 0
  fi

  # Checked rather than run blindly: a missing command is exit 127, and this
  # unit returning non-zero would be recorded as a failure when what actually
  # happened is that the symlinks step was skipped.
  if [[ ! -x "$HOME/.local/bin/wallpaper-switch" ]]; then
    ui_bad "   ~/.local/bin/wallpaper-switch is missing -- apply 'symlinks' first."
    FAILED+=("palette: wallpaper-switch is not linked")
    return 0
  fi

  # matugen, the wallpaper daemon and a running compositor all have to be there
  # for this to work. If one is not, say so and carry on: it is one command to
  # run again.
  if run "$HOME/.local/bin/wallpaper-switch" random; then
    ui_did "   generated"
  else
    ui_bad "   the palette could not be generated. Once logged in, run:"
    ui_say "     wallpaper-switch random"
    FAILED+=("palette: wallpaper-switch did not finish")
  fi
}

unit_register palette
