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
# THE THREE DESTINATIONS THE MACHINE BOOTS FROM, in one predicate because two
# places need the same answer for two different reasons: etc_post uses it to
# decide whether a generator has to be re-run, and etc_apply_copy uses it to
# decide whether a failed write is worth stopping the whole run over. Keeping
# it in one function is what stops those two drifting apart the day a fourth
# file joins the list.
#
# What makes these three different from the other seven rows in the table is
# not that they are important -- bluetooth and sddm are important too -- but
# that getting them wrong is discovered at the NEXT BOOT, by which time nobody
# is at a keyboard and the machine may not offer one.
etc_boots_the_machine() {
  case "$1" in
    /etc/mkinitcpio.conf|/etc/mkinitcpio.d/*|/etc/default/grub) return 0 ;;
    *) return 1 ;;
  esac
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
      # A MISTAKE IN THIS REPOSITORY AND NOT ON THIS MACHINE, which is why it
      # is a note and not a stop: nothing was written, nothing is half done,
      # and the machine is exactly as it was. It is recorded rather than only
      # printed because the person who can fix it is the person reading the
      # summary, and the row is one word away from being right.
      *)         ui_bad "   $src: unknown kind '$kind' in the table, skipped"
                 fail_note "etc" "system/README.md gives system/$src the unknown kind '$kind', so it was skipped" \
                   "Change that row's fourth column to copy, reference or recipe" ;;
    esac
  done < <(etc_rows)

  while IFS= read -r src; do
    [[ -z $src ]] && continue
    ui_bad "   system/$src has no row in system/README.md and was skipped"
    # Same reasoning as the unknown kind above: a file nobody wired up is a
    # gap in the repository. Nothing on the machine is worse for it.
    fail_note "etc" "system/$src has no row in system/README.md, so it was skipped" \
      "Add a row for it to the table in system/README.md, then: ./install.sh apply etc"
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
    # A NOTE AND NOT A STOP, because this direction does not touch the machine
    # at all: it writes into the git working tree, where the way back is
    # `git checkout`. Tested rather than run bare for the reason seeds and
    # laptop are -- errexit is suspended inside an _apply, so an unguarded cp
    # that failed still printed "now matches this machine", which is the one
    # kind of failure no summary can classify because nothing recorded it.
    if run cp "$dst" "$DOT/system/$src"; then
      ui_did "   system/$src now matches this machine -- commit it or check it out"
    else
      ui_bad "   could not update system/$src"
      fail_note "etc" "system/$src could not be updated from $dst" \
        "Check the checkout is writable, then: cp $dst $DOT/system/$src"
    fi
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
  # THE ONLY WRITE IN THE WHOLE INSTALLER THAT LANDS IN /etc, and the severity
  # splits on what the destination is rather than on the unit.
  #
  # `install` copies onto the destination in place. A write that fails partway
  # -- a full /, a remount to read-only, a signal -- leaves a file that is
  # neither the old one nor the new one, and nothing here can tell which. For
  # /etc/bluetooth/main.conf that is a controller that misbehaves until
  # somebody looks. For /etc/mkinitcpio.conf or /etc/default/grub it is a
  # machine that may not boot, discovered at the next boot, with no shell to
  # fix it from -- so those three stop the run while there is still a working
  # session in front of the person, and the message says not to reboot before
  # the file has been looked at.
  ui_bad "   could not install $dst"
  if etc_boots_the_machine "$dst"; then
    fail_stop "etc" \
      "$dst could not be written, and it may now be neither the old file nor the new one. This is a file the machine boots from." \
      "Do NOT reboot yet. Compare it against the repository -- diff $dst $DOT/system/$src -- put it right, and if it changed run 'sudo mkinitcpio -P' (or grub-mkconfig) before rebooting."
  fi
  fail_note "etc" "$dst could not be written from system/$src" \
    "Check the diff printed above, then: sudo install -Dm $mode $DOT/system/$src $dst"
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
    etc_boots_the_machine "$dst" || continue
    case "$dst" in
      /etc/default/grub) grub=1 ;;
      *)                 initramfs=1 ;;
    esac
  done

  if (( initramfs )); then
    ui_warn "   The initramfs is generated from what just changed, and is stale until"
    ui_say  "   it is rebuilt. This takes a couple of minutes and rewrites /boot."
    if ui_confirm "   Run 'sudo mkinitcpio -P' now?" n; then
      # THE WORST OUTCOME IN THE WHOLE INSTALLER, and the one place a _post is
      # allowed to end the run. A failed mkinitcpio does not leave the old
      # initramfs alone: the preset writes each image as it goes, so /boot can
      # hold one that is half built for a kernel this machine is about to be
      # told to boot. The message it used to leave -- one red line saying do
      # not reboot -- was printed at the very end of a long run and then had
      # the hand-off paragraph printed underneath it.
      run sudo mkinitcpio -P || fail_stop "etc" \
        "mkinitcpio failed, so /boot may hold an initramfs that is half written. DO NOT REBOOT." \
        "Run 'sudo mkinitcpio -P' again and read what it says -- a missing firmware package or a module name in /etc/mkinitcpio.conf that no longer exists. Only reboot once it has finished cleanly."
    else
      # DECLINED IS A NOTE AND NOT A STOP: nothing was regenerated, so the old
      # initramfs is still whole and still what the machine boots. What is
      # wrong is only that the file no longer describes it, and the person
      # said so on purpose.
      ui_warn "   Remember: sudo mkinitcpio -P"
      fail_note "etc" "/etc/mkinitcpio.conf changed and the initramfs was not rebuilt, so the change is not in effect" \
        "sudo mkinitcpio -P"
    fi
  fi

  if (( grub )); then
    ui_warn "   /boot/grub/grub.cfg is generated from /etc/default/grub and is stale."
    if ui_confirm "   Run 'sudo grub-mkconfig -o /boot/grub/grub.cfg' now?" n; then
      # A NOTE, UNLIKE mkinitcpio, AND THE DIFFERENCE IS WHERE THE OUTPUT GOES.
      # grub-mkconfig writes to a temporary and moves it over grub.cfg only
      # once it has finished, so a failure leaves the previous menu intact and
      # bootable. The machine still boots exactly as it did this morning; what
      # is lost is the change.
      run sudo grub-mkconfig -o /boot/grub/grub.cfg \
        || fail_note "etc" "grub-mkconfig failed, so /boot/grub/grub.cfg is still the previous menu" \
             "sudo grub-mkconfig -o /boot/grub/grub.cfg   -- the machine boots as before until it succeeds"
    else
      ui_warn "   Remember: sudo grub-mkconfig -o /boot/grub/grub.cfg"
      fail_note "etc" "/etc/default/grub changed and the boot menu was not regenerated, so the change is not in effect" \
        "sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi
  fi

  # NOTHING BELOW HERE FAILS THE UNIT, which is the contract every _post is
  # held to -- but two of the branches above end the run themselves, and that
  # is a different thing. The contract says the RUNNER never treats a _post's
  # return value as fatal, because a reload on a machine with no session yet
  # must not undo a run that otherwise worked. It does not say a _post cannot
  # have found something a person has to deal with before touching the reboot
  # button. mkinitcpio is that case and it is the only one here.
  return 0
}

unit_register etc
