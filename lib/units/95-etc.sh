# shellcheck shell=bash
# The system layer: system/ against the machine.
#
# system/ held eleven files with no mechanism at all -- no way to install one,
# no way to compare one, and a closing message in install.sh pointing at "the
# table in the README", which did not exist. So the files were copies of a
# machine at some past moment and nothing said which of the two had moved since.
#
# THE TABLE IN system/README.md IS THE INTERFACE. It is parsed, not decorated: a
# new file in system/ reaches this unit by getting a row, and one without a row
# is reported by name rather than quietly ignored. Documentation that the code
# reads cannot go out of date without something breaking, which is the only kind
# that stays true.
#
# NOTHING HERE IS EVER WRITTEN WITHOUT THE DIFF ON SCREEN FIRST. These are the
# files that decide whether a machine boots.

etc_meta() {
  echo "System files"
  echo "system/ against /etc, diffed and installed one at a time"
}

etc_requires() { :; }
etc_available() { :; }

etc_readme() { printf '%s\n' "$DOT/system/README.md"; }

# THE TABLE, as "<source>\t<destination>\t<mode>\t<kind>".
#
# The rows are the ones whose first cell is a backticked filename, which is what
# separates the file table from the two prose tables further down the same
# document. Cells are stripped of their backticks and their padding here, so the
# markdown can stay readable.
etc_rows() {
  local readme
  readme="$(etc_readme)"
  [[ -f $readme ]] || return 0

  sed -n 's/^| *`\([^`]*\)` *| *`\([^`]*\)` *| *`\([^`]*\)` *| *\([a-z]*\) *|.*$/\1\t\2\t\3\t\4/p' \
    "$readme"
}

# Files in system/ that the table does not mention. Loud rather than silent, for
# the same reason seeds/ is: a file nobody wired up is a mistake in this
# repository, and finding out about it by name is the difference between a
# five-second fix and a mystery.
etc_unlisted() {
  local src name listed
  listed="$(etc_rows | cut -f1)"
  for src in "$DOT"/system/*; do
    [[ -f $src ]] || continue
    name="$(basename "$src")"
    [[ $name == README.md ]] && continue
    grep -qxF -- "$name" <<<"$listed" || printf '%s\n' "$name"
  done
}

# ---------------------------------------------------------------------------
# READ-ONLY, AND HONEST ABOUT WHAT IT CANNOT READ.
#
# Every destination in the table happens to be world-readable on this machine,
# so the check answers in full without privileges -- but that is a property of
# these particular files and not a rule about /etc, so a target it cannot open
# is reported as needing root rather than guessed at or skipped.
etc_check() {
  local src dst mode kind drift=0 absent=0 unreadable=0 unlisted=0 total=0

  while IFS=$'\t' read -r src dst mode kind; do
    [[ -z $src ]] && continue

    # A recipe is a document about edits to somebody else's file. There is
    # nothing to diff and pretending otherwise would report permanent drift.
    [[ $kind == recipe ]] && continue

    total=$(( total + 1 ))

    if [[ ! -e $dst ]]; then
      absent=$(( absent + 1 ))
    elif [[ ! -r $dst ]]; then
      unreadable=$(( unreadable + 1 ))
    elif ! cmp -s "$DOT/system/$src" "$dst"; then
      drift=$(( drift + 1 ))
    fi
  done < <(etc_rows)

  unlisted="$(etc_unlisted | grep -c . || true)"

  (( total )) || { echo "na:system/README.md has no table this can read"; return 0; }

  if (( unreadable )); then
    echo "na:needs root to read $unreadable of $total"
  elif (( unlisted )); then
    echo "drift:$unlisted file(s) in system/ have no row in the table"
  elif (( drift || absent )); then
    echo "drift:$drift of $total differ, $absent not installed"
  else
    echo ok
  fi
}

# ---------------------------------------------------------------------------
# ONE FILE AT A TIME, DIFF FIRST, AND A QUESTION EACH.
#
# There is no "yes to all" here on purpose, and --yes does reach it -- but the
# diff is printed before the question either way, so a --yes run still leaves a
# record on screen of everything it changed. These are the files that decide
# whether a machine boots; a silent bulk copy over them is the one thing this
# unit exists to prevent.
etc_apply() {
  local src dst mode kind touched=()

  while IFS=$'\t' read -r src dst mode kind; do
    [[ -z $src ]] && continue

    case "$kind" in
      recipe)    etc_apply_recipe "$src" "$dst" ;;
      reference) etc_apply_reference "$src" "$dst" ;;
      copy)      etc_apply_copy "$src" "$dst" "$mode" && touched+=("$dst") ;;
      *)         ui_bad "   $src: unknown kind '$kind' in the table, skipped" ;;
    esac
  done < <(etc_rows)

  while IFS= read -r src; do
    [[ -z $src ]] && continue
    ui_bad "   system/$src has no row in system/README.md and was skipped"
  done < <(etc_unlisted)

  # Handed to _post through a file rather than a variable, because _post runs
  # after every unit in the run has finished and this array will be long gone.
  ETC_TOUCHED=("${touched[@]}")
  return 0
}

etc_apply_recipe() {
  local src="$1" dst="$2"
  ui_dim "   $dst is a recipe, not a copy -- read system/$src and run what it says"
}

# THE OTHER DIRECTION, and the only unit here that has one. `fstab` is a record
# of a machine rather than a thing to install: its UUIDs belong to the box this
# repository came from, and copying it onto another one produces something that
# does not boot. What IS worth doing is the reverse -- catching the repo's copy
# up with what the machine really has, which is a change git can show and undo.
etc_apply_reference() {
  local src="$1" dst="$2"

  [[ -r $dst ]] || { ui_dim "   $dst cannot be read without root, skipped"; return 0; }
  cmp -s "$DOT/system/$src" "$dst" && { ui_ok "   $dst matches system/$src"; return 0; }

  ui_warn "   $dst and system/$src differ, and this one is NEVER installed:"
  ui_say  "   it is a record of a machine, and its UUIDs are that machine's."
  echo
  diff -u "$DOT/system/$src" "$dst" | sed 's/^/     /' || true
  echo

  if ui_confirm "   Update system/$src FROM $dst? (a change to the repo, not the machine)" n; then
    run cp "$dst" "$DOT/system/$src"
    ui_did "   system/$src now matches this machine -- commit it or check it out"
  fi
}

# Returns 0 only when the file was actually written, which is what tells _post
# whether anything needs regenerating.
etc_apply_copy() {
  local src="$1" dst="$2" mode="$3"

  if [[ -e $dst ]]; then
    if [[ ! -r $dst ]]; then
      ui_dim "   $dst cannot be read without root, so it cannot be diffed. Skipped."
      return 1
    fi
    cmp -s "$DOT/system/$src" "$dst" && { ui_ok "   $dst is already this"; return 1; }
    ui_warn "   $dst differs from system/$src:"
    echo
    # LEFT IS THE MACHINE, RIGHT IS THE REPOSITORY, so a `+` line is what would
    # be added TO the machine. The other way round reads backwards at exactly
    # the moment it matters.
    diff -u "$dst" "$DOT/system/$src" | sed 's/^/     /' || true
    echo
  else
    ui_warn "   $dst does not exist yet; system/$src would create it."
  fi

  ui_confirm "   Install system/$src to $dst (mode $mode)?" n || {
    ui_dim "   left alone"
    return 1
  }

  # -D makes the parent directory, which /etc/sddm.conf.d needs on a machine
  # that has never had one.
  if run sudo install -Dm "$mode" "$DOT/system/$src" "$dst"; then
    ui_did "   installed $dst"
    return 0
  fi
  ui_bad "   could not install $dst"
  FAILED+=("etc: $dst could not be installed")
  return 1
}

# ---------------------------------------------------------------------------
# WHAT A FILE UNDER /etc DOES NOT DO BY ITSELF.
#
# mkinitcpio.conf and the two presets are inputs to a generator, and
# /etc/default/grub is an input to another one. Editing them changes nothing at
# all until the generator runs, and the failure mode is the worst kind: the file
# says what you meant, the machine behaves the way it did before, and nothing
# anywhere disagrees with you. That is a whole evening.
#
# So the regeneration is offered here, gated on the file that needs it having
# actually been written a moment ago -- and never run for a file that was left
# alone, because `mkinitcpio -P` is two minutes and a rewritten /boot.
ETC_TOUCHED=()

etc_post() {
  local dst initramfs=0 grub=0

  for dst in "${ETC_TOUCHED[@]}"; do
    case "$dst" in
      /etc/mkinitcpio.conf|/etc/mkinitcpio.d/*) initramfs=1 ;;
      /etc/default/grub)                        grub=1 ;;
    esac
  done

  if (( initramfs )); then
    ui_warn "   The initramfs is generated from what just changed, and is stale until"
    ui_say  "   it is rebuilt. This takes a couple of minutes and rewrites /boot."
    if ui_confirm "   Run 'sudo mkinitcpio -P' now?" n; then
      run sudo mkinitcpio -P || ui_bad "   mkinitcpio failed -- do NOT reboot until it succeeds"
    else
      ui_warn "   Remember: sudo mkinitcpio -P"
    fi
  fi

  if (( grub )); then
    ui_warn "   /boot/grub/grub.cfg is generated from /etc/default/grub and is stale."
    if ui_confirm "   Run 'sudo grub-mkconfig -o /boot/grub/grub.cfg' now?" n; then
      run sudo grub-mkconfig -o /boot/grub/grub.cfg \
        || ui_bad "   grub-mkconfig failed -- the old menu is still in place"
    else
      ui_warn "   Remember: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi
  fi

  # NEVER FATAL, by the contract every _post is held to: a reload that fails
  # must not undo a run that otherwise worked, and both of the commands above
  # can be re-run by hand from the message they leave behind.
  return 0
}

unit_register etc
