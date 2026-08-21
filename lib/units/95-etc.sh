# shellcheck shell=bash
# The system layer: system/ against the machine, READ AND REPORTED, never
# written.
#
# system/ held eleven files with no mechanism at all -- no way to compare one,
# no way to see what had moved, and a closing message in install.sh pointing at
# "the table in the README", which did not exist. So the files were copies of a
# machine at some past moment and nothing said which of the two had drifted.
# That is what this unit is for, and it is all it is for.
#
# WHY IT NO LONGER INSTALLS ANYTHING, WHICH IT USED TO. Two reasons, and the
# first is not about risk at all.
#
# HALF OF THESE FILES ARE ABOUT ONE MACHINE. fstab names this box's UUIDs and
# its disks. default-grub points at a CyberGRUB-2077 theme that is not tracked
# anywhere in this repository. modprobe-nvidia-gaming.conf is for this GPU.
# sddm-Xsetup encodes where these particular monitors sit. Installing this
# machine's fstab onto another machine is not reproducing a setup; it is making
# that machine unbootable. An installer that offered to do it was offering the
# wrong thing, and no amount of confirming would have made it the right one.
#
# AND IT WAS THE ONE UNIT THAT COULD LEAVE A MACHINE UNABLE TO BOOT WITH NO
# TEST BEHIND IT. `sudo install -Dm` over /etc, then an offer to run
# `mkinitcpio -P` and `grub-mkconfig`. The container CI that runs every other
# unit for real cannot cover this one meaningfully: a container's /etc boots
# nobody, the initramfs would be built for a kernel that is not running, and
# grub-mkconfig would enumerate the runner's disks. "The commands did not
# error" is the most a green tick could ever have meant, and it would have been
# bought by letting a test rewrite pacman.conf and fstab on whatever machine it
# happened to be running on.
#
# WHAT IS KEPT IS THE HALF THAT EARNED ITS KEEP. The check is `cmp -s` and some
# counters, it needs no root, it writes nothing, and it has already found real
# things twice: the sddm-Xsetup fix that was written into the repository and
# never reached the machine, and default-grub naming a theme nothing tracks.
# `apply` now shows the diff and prints the exact command, which is the half a
# person actually needs, and stops.
#
# THE TABLE IN system/README.md IS THE INTERFACE. It is parsed, not decorated: a
# new file in system/ reaches this unit by getting a row, and one without a row
# is reported by name rather than quietly ignored. Documentation that the code
# reads cannot go out of date without something breaking, which is the only kind
# that stays true.

etc_meta() {
  echo "System files"
  echo "system/ against /etc, diffed and reported -- never written"
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
# COMMENTS OFF, SO THAT "IT DIFFERS" CAN MEAN TWO DIFFERENT THINGS.
#
# On the machine this repository comes from, six of the twelve comparable files
# differ from /etc only in the LANGUAGE OF THEIR COMMENTS: the copies here were
# translated to English at some point and /etc still holds the Spanish
# originals. A unit that answers "9 of 12 differ" every day for that is a unit
# whose answer stops being read, and then the two rows that differ in what the
# file actually does go past with the rest.
#
# The strip is the one pkg_read_list already uses on the package lists: a '#'
# and everything after it, trailing space, and blank lines.
#
# THE ONE WAY THIS CAN BE WRONG, said plainly. A '#' inside a quoted value --
# GRUB_CMDLINE_LINUX could hold one -- takes the rest of that line with it, on
# BOTH sides. So a real difference that lives only after such a '#' would be
# called cosmetic. It cannot go the other way, and nothing is hidden by it: the
# classification is a summary for the table, and `./install.sh apply etc` prints
# the whole diff, comments and all.
etc_strip_comments() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

etc_differs_in_content() {
  ! cmp -s <(etc_strip_comments "$1") <(etc_strip_comments "$2")
}

# ---------------------------------------------------------------------------
# READ-ONLY, AND HONEST ABOUT WHAT IT CANNOT READ.
#
# Every destination in the table happens to be world-readable on this machine,
# so the check answers in full without privileges -- but that is a property of
# these particular files and not a rule about /etc, so a target it cannot open
# is reported as needing root rather than guessed at or skipped.
#
# WHY A DIFFERENCE IS `na` AND NOT `drift`, which is the one decision in this
# function. `drift` means "look at this, and `./install.sh apply <unit>` is how
# it gets fixed" -- that is what mode_check prints under the table. This unit
# does not fix anything any more; a difference here is cleared by a person
# reading a diff and running a command, or by deciding the machine is right and
# the repository is stale. So a `drift` here would be a row that can never go
# green however many times it is applied, on a mode whose own comment says a
# doctor that always exits 1 is a doctor nobody runs twice. What the state says
# instead is "not this installer's to answer", and the note carries the counts.
#
# A FILE IN system/ WITH NO ROW IS STILL `drift`, because that one IS fixable
# and it is a mistake in this repository rather than a fact about a machine.
etc_check() {
  local src dst mode kind rows=() row summary="" part parts=()
  local total=0 absent=0 unreadable=0 content=0 cosmetic=0 record=0 unlisted=0

  mapfile -t rows < <(etc_rows)
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r src dst mode kind <<<"$row"
    [[ -z $src ]] && continue

    # A recipe is a document about edits to somebody else's file. There is
    # nothing to diff and pretending otherwise would report permanent drift.
    [[ $kind == recipe ]] && continue

    total=$(( total + 1 ))

    if [[ ! -e $dst ]]; then
      absent=$(( absent + 1 ))
    elif [[ ! -r $dst ]]; then
      unreadable=$(( unreadable + 1 ))
    elif cmp -s "$DOT/system/$src" "$dst"; then
      :
    elif [[ $kind == reference ]]; then
      # The other direction: this one is a record of a machine, so a difference
      # means the repository is behind, not that the machine is.
      record=$(( record + 1 ))
    elif etc_differs_in_content "$DOT/system/$src" "$dst"; then
      content=$(( content + 1 ))
    else
      cosmetic=$(( cosmetic + 1 ))
    fi
  done

  unlisted="$(etc_unlisted | grep -c . || true)"

  (( total )) || { echo "na:system/README.md has no table this can read"; return 0; }

  if (( unlisted )); then
    echo "drift:$unlisted file(s) in system/ have no row in the table"
    return 0
  fi

  # Ordered by how much they matter, so the front of a truncated line is the
  # part worth reading.
  (( content ))    && parts+=("$content of $total differ in content")
  (( absent ))     && parts+=("$absent not installed")
  (( record ))     && parts+=("$record record(s) behind this machine")
  (( unreadable )) && parts+=("$unreadable need root to read")
  (( cosmetic ))   && parts+=("$cosmetic differ only in comments")

  (( ${#parts[@]} )) || { echo ok; return 0; }

  for part in "${parts[@]}"; do summary+="${summary:+, }$part"; done
  echo "na:$summary -- ./install.sh apply etc shows them"
}

# ---------------------------------------------------------------------------
# THE THREE DESTINATIONS THE MACHINE BOOTS FROM. What makes these different
# from the other rows in the table is not that they are important -- bluetooth
# and sddm are important too -- but that getting them wrong is discovered at the
# NEXT BOOT, by which time nobody is at a keyboard and the machine may not offer
# one. Editing them changes nothing at all until a generator runs, so the
# instructions printed for these carry the generator's command too.
etc_boots_the_machine() {
  case "$1" in
    /etc/mkinitcpio.conf|/etc/mkinitcpio.d/*|/etc/default/grub) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# THE REPORT, WHICH IS WHAT `apply` IS FOR HERE.
#
# It shows every file that differs, with the diff, and prints the exact command
# that would install it. It runs none of them. That is the whole of it, and it
# is deliberately the same output whether it is run with --yes, with --dry-run
# or with neither -- there is no answer that makes this write anything, so there
# is no question to ask and nothing --yes could agree to.
#
# WHY THE UNIT IS NOT SIMPLY UNAVAILABLE. `_available` saying no would be the
# other way to make `apply etc` harmless, and it would take the check with it:
# unit_state asks _available first and its answer wins, so the comparison that
# has already found two real problems would never run again. The unit stays
# applicable and its apply prints.
etc_apply() {
  local rows=() unlisted=() row src dst mode kind pending=0

  # READ WHOLE FIRST, for the reason written out in optional_apply: a
  # redirection on a loop is a redirection on everything inside it.
  mapfile -t rows < <(etc_rows)
  mapfile -t unlisted < <(etc_unlisted)

  ui_dim "   Nothing here is written. /etc belongs to the machine and to pacman;"
  ui_dim "   what follows is the difference and the command, for you to run."
  echo

  for row in "${rows[@]}"; do
    IFS=$'\t' read -r src dst mode kind <<<"$row"
    [[ -z $src ]] && continue

    case "$kind" in
      recipe)    ui_dim "   $dst is a recipe, not a copy -- read system/$src and run what it says" ;;
      reference) etc_report_reference "$src" "$dst"        || pending=1 ;;
      copy)      etc_report_copy "$src" "$dst" "$mode"     || pending=1 ;;
      # A MISTAKE IN THIS REPOSITORY AND NOT ON THIS MACHINE, which is why it
      # is a note and not a stop: nothing was written, nothing is half done,
      # and the machine is exactly as it was. It is recorded rather than only
      # printed because the person who can fix it is the person reading the
      # summary, and the row is one word away from being right.
      *)         ui_bad "   $src: unknown kind '$kind' in the table, skipped"
                 fail_note "etc" "system/README.md gives system/$src the unknown kind '$kind', so it was skipped" \
                   "Change that row's fourth column to copy, reference or recipe" ;;
    esac
  done

  for src in "${unlisted[@]}"; do
    [[ -z $src ]] && continue
    ui_bad "   system/$src has no row in system/README.md and was skipped"
    # Same reasoning as the unknown kind above: a file nobody wired up is a
    # gap in the repository. Nothing on the machine is worse for it.
    fail_note "etc" "system/$src has no row in system/README.md, so it was skipped" \
      "Add a row for it to the table in system/README.md, then: ./install.sh apply etc"
  done

  echo
  if (( pending )); then
    ui_warn "   Nothing above was changed. Read each command before running it:"
    ui_warn "   several of these files describe THIS machine and belong to no"
    ui_warn "   other -- fstab's UUIDs, the GRUB theme, the monitor layout in"
    ui_warn "   the greeter. system/README.md says which is which."
  else
    ui_ok "   /etc matches system/ wherever this could read it."
  fi
  return 0
}

# Returns 0 when there is nothing for the reader to do, 1 when a command was
# printed -- which is what the closing paragraph above keys off.
etc_report_copy() {
  local src="$1" dst="$2" mode="$3"

  if [[ ! -e $dst ]]; then
    ui_warn "   $dst does not exist; system/$src would create it."
  elif [[ ! -r $dst ]]; then
    ui_dim "   $dst cannot be read without root, so it cannot be diffed."
    return 0
  elif cmp -s "$DOT/system/$src" "$dst"; then
    ui_ok "   $dst is already this"
    return 0
  elif etc_differs_in_content "$DOT/system/$src" "$dst"; then
    ui_warn "   $dst differs from system/$src:"
    echo
    # LEFT IS THE MACHINE, RIGHT IS THE REPOSITORY, so a `+` line is what would
    # be added TO the machine. The other way round reads backwards at exactly
    # the moment it matters.
    diff -u "$dst" "$DOT/system/$src" | sed 's/^/     /' || true
    echo
  else
    ui_dim "   $dst differs from system/$src only in its comments:"
    echo
    diff -u "$dst" "$DOT/system/$src" | sed 's/^/     /' || true
    echo
  fi

  ui_say "     sudo install -Dm $mode $DOT/system/$src $dst"
  # -D makes the parent directory, which /etc/sddm.conf.d needs on a machine
  # that has never had one.
  if etc_boots_the_machine "$dst"; then
    # The file is an input to a generator, and editing it changes nothing until
    # that generator runs. The failure mode is the worst kind: the file says
    # what you meant, the machine behaves as it did, and nothing disagrees with
    # you.
    if [[ $dst == /etc/default/grub ]]; then
      ui_say "     sudo grub-mkconfig -o /boot/grub/grub.cfg"
    else
      ui_say "     sudo mkinitcpio -P      # a couple of minutes, and rewrites /boot"
    fi
  fi
  echo
  return 1
}

# THE OTHER DIRECTION, and the only row here that has one. `fstab` is a record
# of a machine rather than a thing to install: its UUIDs belong to the box this
# repository came from, and copying it onto another one produces something that
# does not boot. What IS worth doing is the reverse -- catching the repo's copy
# up with what the machine really has, which is a change git can show and undo.
etc_report_reference() {
  local src="$1" dst="$2"

  [[ -r $dst ]] || { ui_dim "   $dst cannot be read without root, skipped"; return 0; }
  cmp -s "$DOT/system/$src" "$dst" && { ui_ok "   $dst matches system/$src"; return 0; }

  ui_warn "   $dst and system/$src differ, and this one is NEVER installed:"
  ui_say  "   it is a record of a machine, and its UUIDs are that machine's."
  echo
  diff -u "$DOT/system/$src" "$dst" | sed 's/^/     /' || true
  echo
  ui_say "   To catch the repository up with this machine -- a change to the repo"
  ui_say "   and not to the machine, which git can show and undo:"
  ui_say "     cp $dst $DOT/system/$src"
  echo
  return 1
}

unit_register etc
