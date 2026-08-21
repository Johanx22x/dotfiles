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
symlinks_apply() {
  local stow_args=() stow_out conflicts=() unhandled=() backup

  command -v stow >/dev/null || {
    ui_bad "   stow is not installed, so nothing can be linked"
    return 1
  }
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
    ui_say "   Sort it out by hand and run this again."
    return 1
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
      symlinks_move_aside "$backup" "${conflicts[@]}" || return 1
    else
      ui_bad "   nothing linked. Move them by hand and run this again."
      return 1
    fi
  fi

  if ! run stow "${stow_args[@]}" "${STOW_PACKAGES[@]}"; then
    ui_bad "   stow failed even after clearing the conflicts above."
    return 1
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
        ui_bad "   AND COULD NOT PUT ~/$undo BACK. Nothing else will be touched."
        ui_say "   These are now under $backup and not in \$HOME:"
        printf '     %s\n' "${moved[@]}"
        return 1
      fi
    done
    ui_say "   \$HOME is as it was. Nothing was linked."
    return 1
  done

  ui_did "   moved ${#files[@]} file(s) to $backup"
}

unit_register symlinks
