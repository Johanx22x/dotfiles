# shellcheck shell=bash
# The optional package groups: apps, gaming, neovim, hardware.
#
# OPT-IN, AND SKIPPABLE WHOLE. The line between packages/required/ and
# packages/optional/ is one question -- does the desktop still work without it
# -- and everything on this side of that line can be left out and added later
# with `./install.sh apply optional`.
#
# TWO LEVELS OF CHOICE, BOTH REMEMBERED. A group ticks as one box, which is what
# anybody actually wants: "gaming, yes". Opening a group and ticking packages
# inside it is there for the case that is not covered by any set of groups
# somebody else drew -- "gaming, but not Steam". The profile holds both, and the
# rule between them is that a package with no line of its own follows its group.
#
# WHICH IS WHAT MAKES THE FILE SHORT AND THE UPGRADE WORK. Ticking a pack costs
# one line instead of twelve, and a package added to a list in a later release
# reaches every machine that ticked the group without anybody re-opening a menu.

optional_meta() {
  echo "Optional packages"
  echo "apps, gaming, neovim and hardware -- opt in by the pack or by the name"
}

optional_requires() { echo packages; }
optional_available() { :; }

# The group names, one per line, from the directory rather than from a list --
# so a fifth file in packages/optional/ appears in the menu on its own.
optional_groups() {
  local list
  for list in "$DOT"/packages/optional/*.txt; do
    [[ -f $list ]] || continue
    basename "$list" .txt
  done
}

optional_list() { printf '%s\n' "$DOT/packages/optional/$1.txt"; }

# Every package this machine has asked for, across every group. This is the one
# function that reads the group/package rule, and everything else -- the check,
# the apply, the menu's defaults -- goes through it.
optional_wanted() {
  local group pkg
  while IFS= read -r group; do
    while IFS= read -r pkg; do
      state_pkg_wanted "$group" "$pkg" && printf '%s\n' "$pkg"
    done < <(pkg_read_list "$(optional_list "$group")")
  done < <(optional_groups)
}

optional_wanted_in() {
  local group="$1" pkg
  while IFS= read -r pkg; do
    state_pkg_wanted "$group" "$pkg" && printf '%s\n' "$pkg"
  done < <(pkg_read_list "$(optional_list "$group")")
}

optional_check() {
  local names=() missing=()
  mapfile -t names < <(optional_wanted)

  # NOTHING TICKED IS NOT THE SAME AS NOTHING MISSING. A machine that has never
  # been asked and a machine that said no to all four look identical from here,
  # and neither of them has a problem -- so this is `na` rather than `ok`, and
  # says which of the two it is by saying nothing was chosen.
  if (( ${#names[@]} == 0 )); then
    echo "na:no optional group has been chosen"
    return 0
  fi

  mapfile -t missing < <(pkg_missing "${names[@]}")
  if (( ${#missing[@]} )); then
    echo "missing:${#missing[@]} of ${#names[@]} optional packages"
  else
    echo ok
  fi
}

# INSTALLED GROUP BY GROUP RATHER THAN ALL AT ONCE, so that a failure names the
# pack it came from. "gaming failed" is a sentence somebody can act on;
# "optional failed" across four unrelated groups is not.
optional_apply() {
  local group groups=() names=() any=0

  # READ WHOLE FIRST, AND THIS IS THE BUG THAT PAID FOR THE LINE. The obvious
  # shape here is `while IFS= read -r group; do ... done < <(optional_groups)`,
  # and it puts THE LIST OF GROUP NAMES on the stdin of everything in the loop
  # body -- pacman included. pacman ends its transaction with ":: Proceed with
  # installation? [Y/n]", reads the next group name as the answer, and the log
  # said so plainly:
  #
  #     :: Proceed with installation? [Y/n] gaming
  #        apps: pacman did not finish, see the output above
  #
  # It answers "gaming", takes that for a no and gives up -- and the groups it
  # swallowed never get their turn either, because the loop's own `read` finds
  # end of file. That happened on a terminal exactly as much as in a script:
  # the redirection is on the loop, not on the terminal. So the optional
  # packages -- the whole reason this unit exists -- could not install anything
  # this machine did not already have.
  #
  # An array costs four group names' worth of memory and leaves the run's own
  # stdin where every unit expects it.
  mapfile -t groups < <(optional_groups)

  for group in "${groups[@]}"; do
    mapfile -t names < <(optional_wanted_in "$group")
    (( ${#names[@]} )) || continue
    any=1
    ui_say "   $group: ${#names[@]} package(s)"
    # A NOTE, WHICH IS THE WHOLE POINT OF THIS DIRECTORY. The header of this
    # file draws the line: everything on this side of it "can be left out and
    # added later". The desktop comes up without GIMP, without Steam, without
    # the Neovim group. A group that failed is named, with the packages in it,
    # and the run carries on to the units that matter.
    pkg_install note optional "$group" "${names[@]}"
  done

  if (( ! any )); then
    ui_say "   No optional group is ticked. Run ./install.sh to pick some."
  fi
}

unit_register optional
