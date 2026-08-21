# shellcheck shell=bash
# Seeds: the files that CANNOT be symlinks, because the applications that own
# them rewrite them.
#
# qt6ct rewrites qt6ct.conf in full on every save -- it has already eaten the
# nine-line comment above color_scheme_path, URL-encoding it into one line, and
# it keeps the settings window's geometry in there -- and mimeapps.list is
# rewritten by anything that claims a default handler. Linked into the repo
# that meant a permanently dirty tree on every machine and a collision on every
# pull. So they are copied ONCE and belong to the machine afterwards. See
# seeds/README.md.

# Where each seed goes. A destination cannot be derived from a seed's name --
# qt6ct.conf sits a directory deeper than mimeapps.list -- so there is a list,
# and a list is a thing to forget.
#
# WHICH IS WHY EVERYTHING BELOW LOOPS OVER THE DIRECTORY AND NOT OVER THIS.
# Dropping a third file into seeds/ used to copy nothing at all: the loop
# iterated the pairs, so an unlisted seed was not skipped with a warning, it was
# never looked at. Now the directory decides what gets considered and this only
# decides where it lands, so the failure is a message instead of a silence.
#
# The other way out would be to mirror $HOME inside seeds/ and derive the
# destination from the path, the way every stow package does. Rejected on
# purpose: it would make `stow seeds` -- the one thing seeds/README.md forbids
# in capitals -- produce a working set of symlinks instead of obvious garbage,
# and the whole point of a seed is that it must not be a link.
declare -A SEED_DEST=(
  ["qt6ct.conf"]="$HOME/.config/qt6ct/qt6ct.conf"
  ["mimeapps.list"]="$HOME/.config/mimeapps.list"
)

seeds_meta() {
  echo "Seeds"
  echo "copies seeds/ where nothing exists yet -- never overwrites"
}

# After the symlinks, deliberately: stow is what creates ~/.config, and a
# destination must not be a link before anything is written to it.
seeds_requires() { echo symlinks; }
seeds_available() { :; }

# Every file in seeds/ that is a seed, one basename per line. README.md is the
# directory's own documentation, not a seed.
seeds_names() {
  local src name
  for src in "$DOT"/seeds/*; do
    [[ -f $src ]] || continue
    name="$(basename "$src")"
    [[ $name == README.md ]] && continue
    printf '%s\n' "$name"
  done
}

seeds_check() {
  local name dst missing=0 unmapped=0 dangling=0

  while IFS= read -r name; do
    dst="${SEED_DEST[$name]:-}"
    if [[ -z $dst ]]; then
      unmapped=$(( unmapped + 1 ))
    elif [[ -L $dst && ! -e $dst ]]; then
      dangling=$(( dangling + 1 ))
    elif [[ ! -e $dst && ! -L $dst ]]; then
      missing=$(( missing + 1 ))
    fi
  done < <(seeds_names)

  # A DANGLING LINK IS DRIFT AND NOT A MISSING FILE, because it is the one case
  # that cannot be fixed by copying: -e follows the link, so a dangling one
  # reads as "nothing there", GNU cp then refuses with "not writing through
  # dangling symlink", and under `set -e` that used to take the rest of the run
  # with it -- over a link that one `rm` clears.
  if (( dangling )); then
    echo "drift:$dangling seed destination(s) are dangling symlinks"
  elif (( unmapped )); then
    echo "drift:$unmapped file(s) in seeds/ have no destination"
  elif (( missing )); then
    echo "missing:$missing seed(s)"
  else
    echo ok
  fi
}

seeds_apply() {
  local name src dst seeded=0 names=() unmapped=()

  mapfile -t names < <(seeds_names)
  for name in "${names[@]}"; do
    src="$DOT/seeds/$name"
    dst="${SEED_DEST[$name]:-}"

    if [[ -z $dst ]]; then
      unmapped+=("$name")
      continue
    fi

    if [[ -L $dst && ! -e $dst ]]; then
      ui_bad "   $dst is a dangling symlink"
      ui_say "     It pointed at the repo copy that is now a seed. Delete it and"
      ui_say "     run this step again; it is not removed for you, in case you made it."
    elif [[ -e $dst || -L $dst ]]; then
      ui_say "   $dst already exists, left alone"
    else
      run mkdir -p "$(dirname "$dst")"
      run cp "$src" "$dst"
      ui_did "   seeded $dst"
      seeded=$(( seeded + 1 ))
    fi
  done

  ui_did "   $seeded file(s) copied"

  # Loud rather than fatal. A seed with nowhere to go is a mistake in this
  # repository, not in the machine being set up, and stopping the install over
  # it would punish the wrong person -- but saying nothing is how it went
  # unnoticed in the first place.
  if (( ${#unmapped[@]} )); then
    ui_bad "   ${#unmapped[@]} file(s) in seeds/ have no destination and were skipped:"
    printf '     %s\n' "${unmapped[@]}"
    ui_say "     Add them to SEED_DEST in this unit, and to the table in seeds/README.md."
  fi

  # qt6ct's colour scheme lands in ~/.config/qt6ct/colors/, which nothing else
  # creates any more: qt6ct stopped being a stow package when its config became
  # a seed, and the seed only makes the directory its own file sits in.
  #
  # matugen does create missing parents, so this is insurance rather than a fix
  # -- but it is insurance against a silent one. A palette that fails to write
  # leaves Qt applications on the factory grey with nothing on screen to say
  # why, which is a long way to walk back from.
  run mkdir -p "$HOME/.config/qt6ct/colors"
}

unit_register seeds
