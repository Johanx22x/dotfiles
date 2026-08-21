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

# WHERE THE COLLECTION IS, ASKED RATHER THAN ASSUMED -- same reasoning as
# palette_outputs above. wallpaper-switch keeps the folder in a state file so it
# can be moved (`wallpaper-switch dir pick`, which the README documents), and a
# machine that has moved it would otherwise be told its wallpapers do not exist
# while they sit somewhere else entirely.
palette_dir() {
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-dir"
  if [[ -r $state ]]; then
    local dir; dir="$(<"$state")"
    [[ -n $dir ]] && { printf '%s\n' "$dir"; return 0; }
  fi
  printf '%s\n' "$HOME/Pictures/wallpapers"
}

# WHAT COUNTS AS A WALLPAPER, READ OUT OF THE SCRIPT THAT DECIDES IT. This used
# to be four extensions written out here, and it was wrong in both directions:
# it missed bmp and gif, which are stills, and it missed mp4, webm and mkv,
# which are live wallpapers played through mpvpaper. A collection of animated
# wallpapers read as an empty folder, and the step failed telling the user to
# drop in an image they already had.
palette_exts() {
  local ws="$DOT/bin/.local/bin/wallpaper-switch"
  [[ -r $ws ]] || { printf '%s\n' jpg jpeg png webp bmp gif mp4 webm mkv; return 0; }
  grep -oP '^(STILL|VIDEO)_EXT=\(\K[^)]+' "$ws" | tr ' ' '\n' | grep -v '^$'
}

palette_apply() {
  local dir; dir="$(palette_dir)"
  ui_say "   Needs at least one wallpaper in $dir."

  # Only ever create the DEFAULT. If a state file names somewhere else and that
  # place is gone, making it here would hide the real problem behind an empty
  # folder -- and on a case-sensitive filesystem it is how you end up with
  # Wallpapers and wallpapers side by side, one of them empty.
  [[ -e $dir ]] || run mkdir -p "$dir"

  local -a find_args=(); local ext first=1
  while IFS= read -r ext; do
    (( first )) || find_args+=(-o)
    find_args+=(-iname "*.$ext"); first=0
  done < <(palette_exts)

  if ! find -L "$dir" -maxdepth 2 -type f \( "${find_args[@]}" \) 2>/dev/null | grep -q .; then
    ui_bad "   No wallpapers in $dir."
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
