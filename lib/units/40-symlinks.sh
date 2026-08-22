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
# THE LINKS A DELETED FILE LEAVES BEHIND, WHICH NOTHING HERE COULD SEE.
#
# stow makes one link per file and then forgets that link exists. Delete the
# file from the repository and every machine that pulls keeps the link,
# pointing at nothing, for ever: a re-stow only ever looks at the files a
# package HAS. The walk in symlinks_check starts from those same files, so it
# was blind in the same way -- measured on this machine on 2026-08-21, three
# files deleted that morning left three dangling links in ~/.config/quickshell
# and `check` answered `ok` with all three of them sitting there.
#
# IT IS NOT TIDINESS. Quickshell finds its own tree by scanning directories, so
# a dangling .qml inside it is opened on the next start and takes the desktop
# with it -- while the one command that is supposed to repair the configuration
# says everything is fine.
#
# WHY NOT `stow -R`, WHICH DOES CLEAR THEM. It does, and it is still not what
# this runs. Measured against stow 2.4.1, in a scratch target directory:
#
#   * -R REBUILDS EVERY FOLDED DIRECTORY. ~/.config/MangoHud is one link
#     standing for a whole directory -- stow folded it before --no-folding was
#     in the arguments -- and a restow of it prints `UNLINK: .config/MangoHud`,
#     then MKDIR, then a link per file. Plain stow leaves it completely alone.
#     That unlink is a gap in which the directory does not exist, which is the
#     exact event symlinks_post is written about: after one of those, Hyprland's
#     inotify fds hold zero watches for the rest of the session, silently.
#   * -R ONLY VISITS THE PACKAGES IT IS GIVEN, and recognises a link by the
#     package directory it points into. A link left by a package that is no
#     longer in STOW_PACKAGES -- the other compositor after a switch, a package
#     deleted from the repository outright -- survives an unstow untouched
#     (measured). This sweep starts from the target side instead, so it does
#     not care which package wrote a link or whether that package still exists.
#   * THE CONFLICT HANDLING BELOW READS STOW'S OUTPUT, and the three wordings
#     it knows all belong to the stow phase. -R adds an unstow phase with its
#     own, and `unhandled` is deliberately fatal.
#
# So the sweep is narrower than an unstow by design. It removes a link and
# never anything else, and only where all four of these hold:
#
#   1. It is a symlink. Never a regular file, never a directory.
#   2. It does not resolve.
#   3. Resolved, it lands INSIDE this repository. A broken link to anywhere
#      else was made by something else and is none of this script's business:
#      ~/.config/discord/SingletonLock and SingletonCookie are broken links by
#      design and so are Firefox's and Zen's `lock`, and all of them are left
#      exactly where they are.
#   4. The repository does not still have the file for that destination. A link
#      that is broken although its file is right there is a bad relative path
#      and not a deletion -- the walk in symlinks_check already counts it `in
#      the way`, and stow's conflict path below already offers to move it
#      aside. Deleting it here would destroy the evidence and fix nothing.
#
# WHERE IT LOOKS is only what the package list says stow writes into: the
# destination directory of each file of each package, one level deep each. A
# directory the repository no longer has any file in is looked into as well --
# deleting a whole directory of a package leaves exactly that, and the links in
# it are the same problem -- but only when it holds nothing except links and
# further directories. One regular file and the directory belongs to whoever
# wrote that file, which is what keeps this walk out of ~/.config/discord and
# the rest of $HOME.
#
# It prints one absolute path per line and writes nothing, so that _check can
# count what it prints and _apply can remove it and the two cannot disagree
# about what "stale" means.
# WHETHER A DIRECTORY THE REPOSITORY NO LONGER NAMES CAN BE ANYTHING BUT
# LEFTOVERS. It qualifies when every single entry in it is a symlink into this
# repository, or another directory of which the same is true, and there is at
# least one entry. That is what a package directory deleted whole looks like
# from the target side: stow put every link in it there, --no-folding means the
# directory itself is real, and nothing else ever wrote into it.
#
# IT IS THE SCOPE AND NOT THE SAFETY. Nothing is removed on the strength of
# this -- the four conditions in symlinks_stale decide that, one link at a time
# -- but a walk that entered any directory it found would be reading somebody's
# ~/Documents to answer a question about stow, and would also be treating a
# link a PERSON made to a file in this repository as one of stow's. So the
# first entry that is not stow-shaped ends it: ~/Documents on its first file,
# ~/.config/discord on settings.json, ~/.mozilla on a profile directory that
# holds one.
#
# MEASURED ON THE MACHINE THIS COMES FROM, the whole scan is 42 directories the
# packages name, 144 subdirectories of those looked at once each, and 2 of them
# entered -- ~/.config/borgmatic and ~/.config/systemd/user/timers.target.wants,
# both of which really do hold nothing but links into this repository. 208 links
# examined, 0.38 s, which is what it costs `check` and the menu on every run.
# Without the test it was 543 directories and 1.6 s, most of it spent reading
# ~/Documents, ~/Games and ~/Pictures to no purpose.
#
# THE SECOND OF THOSE TWO IS NOT STOW'S, and that is deliberate rather than
# overlooked. `systemctl --user enable` writes timers.target.wants/foo.timer
# pointing at ~/.config/systemd/user/foo.timer, which is itself a stow link into
# this repository, so deleting foo.timer from the repository leaves BOTH broken
# and both are removed in the same pass. That is what `systemctl disable` would
# have done; leaving it is a dangling enablement systemd complains about on
# every daemon-reload.
symlinks_orphan_dir() {
  local dir="$1" dot="$2" entry entries=0

  while IFS= read -r entry; do
    entries=$(( entries + 1 ))
    if [[ -L $entry ]]; then
      [[ "$(readlink -m "$entry" 2>/dev/null || true)" == "$dot"/* ]] || return 1
    elif [[ -d $entry ]]; then
      symlinks_orphan_dir "$entry" "$dot" || return 1
    else
      return 1
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)

  (( entries ))
}

symlinks_stale() {
  local dot pkg src rel dst dir sub link target i
  local -A managed=() expect=()
  local dirs=()

  # The comparison is against the RESOLVED repository path because that is what
  # readlink gives back for the link, and $DOT can perfectly well be reached
  # through a symlink -- /home/johan/dotfiles being one on a machine that keeps
  # the clone elsewhere. Both sides canonical or the prefix test silently never
  # matches and this whole sweep quietly does nothing.
  dot="$(readlink -f "$DOT" 2>/dev/null || printf '%s' "$DOT")"

  for pkg in "${STOW_PACKAGES[@]}"; do
    [[ -d "$DOT/$pkg" ]] || continue
    while IFS= read -r src; do
      rel="${src#"$DOT/$pkg/"}"
      symlinks_ignored "$rel" && continue
      dst="$HOME/$rel"
      expect["$dst"]=1
      dir="$HOME"
      [[ $rel == */* ]] && dir="$HOME/${rel%/*}"
      [[ -n ${managed[$dir]:-} ]] && continue
      managed["$dir"]=1
      # NOT THROUGH A SYMLINK. A destination directory that is itself a link is
      # a folded package directory, so what is on the other side of it is the
      # repository, and walking in there would be walking the repository's own
      # files. It also cannot hold a stale link: a file deleted from a folded
      # directory disappears from $HOME on its own.
      [[ -d $dir && ! -L $dir ]] && dirs+=("$dir")
    done < <(find "$DOT/$pkg" \( -type f -o -type l \))
  done

  # $HOME ITSELF IS ALWAYS ONE OF THEM, seeded rather than discovered. Every
  # package's root-level dotfiles land straight in it -- .zshrc, .gtkrc-2.0 --
  # so it is a directory stow writes into by definition; and it is the one the
  # loop above stops naming at exactly the wrong moment, because deleting the
  # last root-level file of every package is what both leaves the leftover link
  # AND takes $HOME out of the list of destinations. The walk below can rescue a
  # directory the repository has forgotten only when it can reach it from a
  # directory above, and there is nothing above this one.
  if [[ -z ${managed[$HOME]:-} ]]; then
    managed["$HOME"]=1
    dirs+=("$HOME")
  fi

  (( ${#dirs[@]} )) || return 0

  # Breadth-first, appending to the array being walked, so a package directory
  # deleted several levels deep is still reached: a directory that qualifies is
  # appended, and its own subdirectories are examined when the loop gets to it.
  for (( i = 0; i < ${#dirs[@]}; i++ )); do
    while IFS= read -r sub; do
      [[ -n ${managed[$sub]:-} ]] && continue
      managed["$sub"]=1
      # THE REPOSITORY IS NOT SOMEWHERE THIS LOOKS, and on this machine it is
      # sitting right there in $HOME. Nothing under it is a link stow made into
      # a target; a directory of links inside a package would qualify below on
      # its shape alone, and the one thing worse than a leftover link in $HOME
      # is a deleted file in the repository.
      [[ $sub == "$DOT" || $sub == "$DOT"/* || $sub == "$dot" || $sub == "$dot"/* ]] && continue
      symlinks_orphan_dir "$sub" "$dot" && dirs+=("$sub")
    done < <(find "${dirs[i]}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  done

  while IFS= read -r link; do
    [[ -L $link ]] || continue
    [[ -e $link ]] && continue
    [[ -n ${expect[$link]:-} ]] && continue
    # -m and not -f: -f gives back nothing at all when a directory in the
    # middle of the path is missing too, which is precisely what a deleted
    # package directory looks like, and an empty answer matches no prefix.
    target="$(readlink -m "$link" 2>/dev/null || true)"
    [[ $target == "$dot"/* ]] || continue
    printf '%s\n' "$link"
  done < <(find "${dirs[@]}" -maxdepth 1 -type l 2>/dev/null)
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
  local missing=0 blocked=0 elsewhere=0 stale=0
  local stale_links=()

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

  # The links a deleted file left behind are counted from the target side and
  # not from this walk, which cannot reach them -- see symlinks_stale.
  mapfile -t stale_links < <(symlinks_stale)
  stale=${#stale_links[@]}

  # THE NOTE IS BUILT FROM WHATEVER IS NON-ZERO rather than from the first
  # branch that matches, because these three happen together: a machine linked
  # to another checkout, with one file added since it was last stowed and one
  # left over from before, has something to say about all three.
  (( blocked ))   && note+="${note:+, }$blocked in the way"
  (( stale ))     && note+="${note:+, }$stale left by deleted files"
  (( missing ))   && note+="${note:+, }$missing not linked"
  (( elsewhere )) && note+="${note:+, }$elsewhere linked to another checkout"

  if (( blocked || elsewhere || stale )); then
    echo "drift:$note"
  elif (( missing )); then
    echo "missing:$note"
  else
    echo ok
  fi
}

# ---------------------------------------------------------------------------
# REMOVING THEM, AND NOTHING ELSE.
#
# NO QUESTION IS ASKED, unlike the conflicts further down, and the difference
# is what is at stake. A conflict is somebody's own file, which is why it is
# moved to a dated folder rather than deleted; every path here is a link this
# repository made to a file this repository no longer has. There is nothing in
# it to keep and nothing to put back -- what it named is gone from the
# repository, so re-creating it is not something anybody could want. Asking
# would also mean `update`, which exists to run unattended from a keybind,
# stopping on a question with nobody there to answer it.
#
# A FAILED REMOVAL IS NOT FATAL. Nothing after this needs them gone: stow links
# the rest of the tree either way and `check` goes on reporting them on every
# run until somebody looks. fail_stop here would take a working desktop away
# over a link that was already broken.
symlinks_sweep_stale() {
  local stale=() link

  mapfile -t stale < <(symlinks_stale)
  (( ${#stale[@]} )) || return 0

  ui_say "   ${#stale[@]} link(s) left behind by files this repository no longer has:"
  printf '     ~/%s\n' "${stale[@]#"$HOME"/}"

  if ! run rm -- "${stale[@]}"; then
    ui_warn "   some of them could not be removed -- check will keep saying so"
    return 0
  fi
  ui_did "   removed ${#stale[@]} link(s) that pointed at nothing"

  (( ${DRY_RUN:-0} )) && return 0
  for link in "${stale[@]}"; do
    symlinks_prune_empty "${link%/*}"
  done
}

# THE EMPTY DIRECTORIES, AND ONLY THE ONES THIS JUST EMPTIED.
#
# Deleting the last file of a directory from the repository leaves the
# directory itself in $HOME, and nothing else will ever take it away: stow
# removes the directories it empties when it unstows, and this never unstows.
# One is harmless; they accumulate, one per directory the repository has ever
# dropped, and a target tree full of them is a tree nobody can read to see what
# stow actually owns. So they are pruned, under four conditions that between
# them make it impossible to lose anything a person put there:
#
#   * The directory held a stale link this just removed. A directory this sweep
#     never touched is not a candidate at all, so an empty directory somebody
#     made themselves is never even looked at.
#   * `rmdir` and never `rm -r`: it refuses anything that is not empty. One
#     file or link left in there -- including one written between the unlink
#     above and this, which really does happen -- saves the whole directory.
#   * No package has that directory any more. If the repository still has it,
#     stow wants it and it would be back a second later.
#   * Under $HOME, and never $HOME itself.
#
# It walks upwards afterwards because a package directory deleted whole empties
# its parent as well, and stops at the first rmdir that refuses.
symlinks_prune_empty() {
  local dir="$1" rel pkg keep

  while [[ $dir == "$HOME"/?* ]]; do
    rel="${dir#"$HOME"/}"
    keep=0
    for pkg in "${STOW_PACKAGES[@]}"; do
      [[ -d "$DOT/$pkg/$rel" ]] && { keep=1; break; }
    done
    (( keep )) && return 0
    rmdir "$dir" 2>/dev/null || return 0
    ui_dim "   removed the empty ~/$rel"
    dir="${dir%/*}"
  done
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

  # BEFORE STOW RUNS, because a link pointing at a file the repository no
  # longer has is not a conflict and stow will never mention it: the simulation
  # below would report a clean tree and leave all of them exactly where they
  # are. See symlinks_stale for what it is willing to remove.
  symlinks_sweep_stale

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
# NOTHING ELSE IS RELOADED, and that is a decision rather than an omission.
# Reloading the compositor re-reads a config the person may be halfway through
# editing, and throws away everything desktop-tweak has pushed into it since
# login. Both lines below are one command, both are in the README, and neither
# belongs to a step whose job was to make symlinks.
#
# WHAT IS PRINTED FOR QUICKSHELL IS A RESTART, and it was briefly something
# else. A "nudge" -- create a file in ~/.config/quickshell, delete it again --
# was printed here for one commit on the strength of a report that it made the
# shell re-read the tree. It does not, in any state, and the version of these
# lines that said so was telling people to run a no-op. Quickshell reloads on
# the CONTENT of a watched .qml file changing, and a stow run that has just
# replaced inodes has left it watching nothing at all: measured, live file
# watches go from 122 to zero and no filesystem operation gets through, `stow
# -R` included. Restarting the process is the only thing that does.
#
# It is printed and not run, and that part has not changed: this unit is not
# where somebody's bar gets taken away. Note when running it by hand that a
# start is not free the way a reload is -- if the tree does not parse, `qs`
# exits 255 and there is no shell until it does.
#
# niri is not printed at all any more. It holds no inotify watch and polls its
# config every 500 ms instead, so it survives every shape of relink this unit
# can leave behind -- measured, including the remove-and-recreate that leaves
# Hyprland holding zero watches for the rest of the session. There is nothing
# for a person to run.
#
# Hyprland is printed for that last case and not because it cannot see a
# renamed file: it re-arms its watch on every event and picked up an `mv` over
# the config, a retargeted symlink and a `git checkout` unaided. What it does
# not survive is an unlink with a GAP before the file comes back -- after that
# its inotify fds hold zero watches for the rest of the session, silently, and
# only `hyprctl reload` brings them back. This unit is not the one that does
# that: measured, stow leaves a link that is already right completely alone,
# same inode and same ctime across re-runs, and nothing here passes -R or -D.
#
# STILL NOTHING DOES, AND THAT IS NOT AN OVERSIGHT. Clearing the links a deleted
# file leaves behind is the obvious reason to reach for -R, and it is done by a
# sweep of this unit's own instead -- see the header over symlinks_stale, which
# has the measurements against stow 2.4.1 that decided it. One of them is this
# very failure: -R unlinks and rebuilds every folded directory it finds.
#
# It is printed because it is cheap and the failure is permanent, not because
# it is known to be needed. `hyprctl reload` answers "ok" and exits 0 whatever
# it just read, and so does `hyprctl configerrors` -- the errors are the
# output, never the status.
symlinks_post() {
  run systemctl --user daemon-reload 2>/dev/null || true

  ui_dim "   Nothing running picks new configuration up on its own, except niri:"
  if want_hyprland; then
    ui_dim "     hyprctl reload && hyprctl configerrors   # Hyprland, if hypr/ moved"
  fi
  ui_dim "     qs kill && qs -d --no-duplicate           # Quickshell"
  return 0
}

unit_register symlinks
