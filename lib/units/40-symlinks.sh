# shellcheck shell=bash
# stow: the configuration in $HOME as links back into this repository.
#
# This is the part that actually matters. Everything else here can be redone in
# one command afterwards; this is the one that makes the clone into a desktop,
# which is why nothing above it is allowed to end the run.

symlinks_meta() {
  echo "Symlinks"
  echo "stow links every package's files into \$HOME"
}

symlinks_requires() { echo packages; }
symlinks_available() { :; }

# --no-folding: real directories, linked file by file, instead of one link for
# a whole directory. That way an application writing a new file into
# ~/.config/something does not drop it inside the repository by accident.
symlinks_args() {
  printf '%s\n' --no-folding -v -t "$HOME" -d "$DOT"
}

# STOW'S OWN IGNORE LIST, the two entries of it this repository can produce.
# stow skips .gitignore anywhere and README/LICENSE/COPYING at a package's
# ROOT -- anchored, so bin/.local/share/cursor-match/LICENSE is stowed and
# should be. A walk that did not know this would report files as unlinked that
# stow was never going to link, on every single run.
symlinks_ignored() {
  local rel="$1"
  [[ ${rel##*/} == .gitignore ]] && return 0
  [[ $rel == README* || $rel == LICENSE* || $rel == COPYING ]] && return 0
  return 1
}

# ---------------------------------------------------------------------------
# READ-ONLY, AND NOT THROUGH `stow -n`. stow's dry run is the right tool for
# planning an install, but it wants the packages to be stowable right now and
# says nothing at all about the links that are already correct -- so it cannot
# answer "is this machine linked to this repository", which is the question.
# Walking the tree answers it, costs one find over ~165 files, and can tell the
# three outcomes apart.
#
# EVERYTHING IS DECIDED ON THE RESOLVED PATH and not on whether the destination
# is itself a symlink, which is the distinction the first version of this got
# wrong. ~/.config/MangoHud is one link standing for a whole directory -- stow
# folded it before --no-folding was in the arguments -- so the file inside it is
# a plain file by every test, reached through a link one level up. Asking
# `readlink -f` where the destination really lands covers folded directories,
# links to links, and the plain case, all with the same comparison.
symlinks_check() {
  local pkg src rel dst target note=""
  local missing=0 blocked=0 elsewhere=0

  for pkg in "${STOW_PACKAGES[@]}"; do
    [[ -d "$DOT/$pkg" ]] || continue
    while IFS= read -r src; do
      rel="${src#"$DOT/$pkg/"}"
      symlinks_ignored "$rel" && continue
      dst="$HOME/$rel"

      if [[ ! -e $dst && ! -L $dst ]]; then
        missing=$(( missing + 1 ))
        continue
      fi

      target="$(readlink -f "$dst" 2>/dev/null || true)"
      if [[ $target == "$(readlink -f "$src")" ]]; then
        continue
      fi

      # A DESTINATION THAT LANDS ON THE SAME FILE IN A DIFFERENT CLONE is its
      # own answer and not a conflict. It happens with a second checkout, with
      # a git worktree, and with the repo moved to another path -- the desktop
      # works, it is simply not this copy driving it, and calling that "in the
      # way" would send somebody deleting files that are perfectly fine.
      if [[ $target == */"$pkg"/"$rel" ]]; then
        elsewhere=$(( elsewhere + 1 ))
      else
        blocked=$(( blocked + 1 ))
      fi
    done < <(find "$DOT/$pkg" \( -type f -o -type l \))
  done

  # THE NOTE IS BUILT FROM WHATEVER IS NON-ZERO rather than from the first
  # branch that matches, because these three happen together: a machine linked
  # to another checkout, with one file added since it was last stowed and one
  # left over from before, has something to say about all three.
  (( blocked ))   && note+="${note:+, }$blocked in the way"
  (( missing ))   && note+="${note:+, }$missing not linked"
  (( elsewhere )) && note+="${note:+, }$elsewhere linked to another checkout"

  if (( blocked || elsewhere )); then
    echo "drift:$note"
  elif (( missing )); then
    echo "missing:$note"
  else
    echo ok
  fi
}

# ---------------------------------------------------------------------------
# EVERY FAILURE IN HERE STOPS THE RUN, and this is the unit the whole
# fatal/not-fatal distinction was drawn for.
#
# Nothing that this repository does survives it. ~/.config for the compositor,
# the bar, the terminal and the shell are links made here; so is
# ~/.local/bin, which is where every script the later units invoke lives.
# `palette` calls wallpaper-switch, `monitors` calls desktop-monitors,
# `services-user` enables unit files that only exist in ~/.config/systemd/user
# because stow put them there. Carrying on past a failed stow means running
# five more units that each discover the same missing directory in their own
# words -- which is what used to happen, and it produced a summary of five
# unrelated-looking failures with one cause.
#
# It is also the failure a person can actually fix: a file in the way, a
# missing package, a second checkout. Stopping while they are still at the
# keyboard is the difference between a two-minute fix and a machine that half
# works for a week.
#
# THE REASON SURVIVES NOW, WHICH IT DID NOT. Each branch below used to
# `return 1` and let unit_apply record the same "symlinks: did not finish" for
# all five, so the summary said nothing that the person could act on and the
# real message had scrolled away. fail_stop takes the reason and the way out
# together, and does not return.
symlinks_apply() {
  local stow_args=() stow_out conflicts=() unhandled=() backup

  command -v stow >/dev/null || fail_stop "symlinks" \
    "stow is not installed, so not one dotfile can be linked." \
    "sudo pacman -S --needed stow   -- or ./install.sh apply packages, which includes it"
  mapfile -t stow_args < <(symlinks_args)

  ui_say "   packages: ${STOW_PACKAGES[*]}"

  # Simulated first. stow plans the whole operation and aborts the LOT on the
  # first conflict, so a single pre-existing file means not one link gets made
  # -- and the usual culprit is there on any machine that has run Hyprland
  # once, because it writes a default config into ~/.config/hypr itself.
  #
  # -n also means the list below is complete: every conflict across every
  # package, found without having touched anything yet.
  #
  # THREE MESSAGES, NOT ONE. stow reports a conflict in one of several
  # wordings, and reading only the "cannot stow ... over existing target" one
  # -- a plain file in the way -- was a real hole: a dotfile that is already a
  # SYMLINK elsewhere (another clone of this repo at a different path, a
  # previous dotfiles manager) produces "existing target is not owned by stow"
  # instead, which matched nothing, so the script announced zero conflicts and
  # then died on the real run with "failed even after clearing the conflicts
  # above" -- a lie, and no way forward from it. All three wordings below name
  # a single file or link, which is what makes moving them safe. Anything else
  # stow may complain about is deliberately NOT guessed at: it is printed as it
  # came and the run stops.
  #
  # `|| true` because stow exits non-zero precisely when it has something to
  # report, which is the case this is here to handle.
  stow_out="$(stow "${stow_args[@]}" -n "${STOW_PACKAGES[@]}" 2>&1 || true)"
  mapfile -t conflicts < <(sed -n \
    -e 's/^.*cannot stow .* over existing target \(.*\) since .*$/\1/p' \
    -e 's/^.*existing target is not owned by stow: \(.*\)$/\1/p' \
    -e 's/^.*existing target is stowed to a different package: \(.*\) => .*$/\1/p' \
    <<<"$stow_out" | LC_ALL=C sort -u)
  mapfile -t unhandled < <(grep -E '^\s*\*' <<<"$stow_out" |
    grep -vE 'cannot stow .* over existing target .* since |existing target is (not owned by stow|stowed to a different package)' || true)

  if (( ${#unhandled[@]} )); then
    ui_bad "   stow reports something this will not touch on its own:"
    printf '   %s\n' "${unhandled[@]}"
    fail_stop "symlinks" \
      "stow reported something this will not guess at: ${unhandled[0]}" \
      "Read the stow output above, sort it out by hand, and run this again."
  fi

  if (( ${#conflicts[@]} )); then
    ui_bad "   ${#conflicts[@]} file(s) are in the way, and stow will not touch them:"
    printf '     ~/%s\n' "${conflicts[@]}"
    ui_say ""
    ui_say "   They can be MOVED (not deleted) into a timestamped folder, and the"
    ui_say "   repo's versions linked in their place. Nothing is overwritten and"
    ui_say "   you can put any of them back afterwards."
    ui_say ""
    ui_say "   The other way round is 'stow --adopt', which keeps YOUR files and"
    ui_say "   overwrites the repo's copies with them. This will not do that for"
    ui_say "   you: it edits the repo, and a git checkout is the way back."

    backup="$HOME/dotfiles-replaced-$(date +%Y%m%d-%H%M%S)"
    if ui_confirm "Move them to $backup and carry on?"; then
      # move_aside puts everything back on the first failed move and prints
      # both sides, so by the time it returns non-zero the filesystem is in
      # trouble and there is nothing left for this run to attempt.
      symlinks_move_aside "$backup" "${conflicts[@]}" || fail_stop "symlinks" \
        "the conflicting files could not be moved aside, so nothing was linked." \
        "Read the two lists printed above -- they are the exact state of $backup and of \$HOME -- and move the rest by hand."
    else
      # DECLINED IS STILL FATAL. It is a choice and not an accident, and the
      # answer is the same either way: no dotfile is linked, so every unit
      # after this one would be working on a machine that has none of this
      # repository on it. Saying "fine" and carrying on would be the installer
      # pretending the answer did not matter.
      fail_stop "symlinks" \
        "the ${#conflicts[@]} file(s) in the way were left alone, so nothing was linked." \
        "Move or delete them yourself -- they are listed above, under \$HOME -- and run this again, or answer yes to have them moved to a timestamped folder."
    fi
  fi

  if ! run stow "${stow_args[@]}" "${STOW_PACKAGES[@]}"; then
    fail_stop "symlinks" \
      "stow failed even with nothing in the way." \
      "Run it by hand to see what it says: stow ${stow_args[*]} ${STOW_PACKAGES[*]}"
  fi
  ui_did "   linked"
}

# ---------------------------------------------------------------------------
# MOVING THE CONFLICTS ASIDE, ALL OF THEM OR NONE.
#
# The loop this replaces was `mkdir -p; mv` per file with `set -e` over it. A
# single mv that failed -- a file on a read-only mount, one owned by root, a
# full disk -- left N files moved, the rest where they were, and no links
# created at all: a machine in neither state, and no record of which half had
# happened. Half a dotfiles directory is much worse than none.
#
# So the moves are undone on the first failure. If a move BACK fails too --
# which means the filesystem is genuinely in trouble -- the exact contents of
# both sides are printed, because at that point the only thing worth producing
# is an accurate list for a person to work from.
symlinks_move_aside() {
  local backup="$1"; shift
  local files=("$@") moved=() rel undo

  if (( ${DRY_RUN:-0} )); then
    ui_dim "   would move ${#files[@]} file(s) to $backup"
    return 0
  fi

  for rel in "${files[@]}"; do
    if mkdir -p "$backup/$(dirname "$rel")" && mv "$HOME/$rel" "$backup/$rel"; then
      moved+=("$rel")
      continue
    fi

    ui_bad "   could not move ~/$rel -- putting the other ${#moved[@]} back"
    for undo in "${moved[@]}"; do
      if ! mv "$backup/$undo" "$HOME/$undo"; then
        # THE WORST STATE THIS SCRIPT CAN REACH, and until now it produced one
        # red line and then let the run carry on into six more units. Files
        # that were in $HOME are under $backup, the rollback itself is failing,
        # and nothing is linked. There is no version of continuing that is not
        # making it worse, and the list printed above is the only record that
        # exists -- so the run ends here, with that list still the last thing
        # on screen.
        ui_bad "   AND COULD NOT PUT ~/$undo BACK. Nothing else will be touched."
        ui_say "   These are now under $backup and not in \$HOME:"
        printf '     %s\n' "${moved[@]}"
        fail_stop "symlinks" \
          "\$HOME/$undo could not be put back, so ${#moved[@]} of your file(s) are under $backup and not in \$HOME." \
          "Nothing else was touched and nothing was linked. Move the files listed above back yourself, work out why the filesystem refused -- full disk, read-only mount, ownership -- and run this again."
      fi
    done
    ui_say "   \$HOME is as it was. Nothing was linked."
    return 1
  done

  ui_did "   moved ${#files[@]} file(s) to $backup"
}


# ---------------------------------------------------------------------------
# AFTER THE LINKS, THE RELOADS.
#
# A unit file that arrived through stow is invisible to systemd until it is told
# to look again, and that is the exact shape of the bug `check` found on the
# machine this repository comes from: wallpaper-rotate.timer had never been
# linked, so `systemctl --user is-enabled` answered not-found and the wallpaper
# stopped rotating with nothing anywhere to say so.
#
# NOTHING ELSE IS RESTARTED, and that is a decision rather than an omission.
# Restarting Quickshell takes down the bar, the island and the notification
# daemon of the session the person is sitting in, and reloading the compositor
# re-reads a config they may be halfway through editing. Both are one command,
# both are in the README, and neither belongs to a step whose job was to make
# symlinks.
symlinks_post() {
  run systemctl --user daemon-reload 2>/dev/null || true

  ui_dim "   Nothing running picks new configuration up on its own:"
  if want_hyprland; then
    ui_dim "     hyprctl reload                                      # Hyprland"
  fi
  if want_niri; then
    ui_dim "     niri reloads on save                                # niri"
  fi
  ui_dim "     qs kill && qs -d -p ~/.config/quickshell/shell.qml  # Quickshell"
  return 0
}

unit_register symlinks
