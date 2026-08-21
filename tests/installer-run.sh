#!/usr/bin/env bash
# Does install.sh actually install? Nothing in this repository had ever asked.
#
# THE GAP THIS FILLS. Every other check in tests/ is about the repository's
# CONTENT -- that both compositors accept their configuration, that every
# package name still resolves, that stow could link the tree into an empty
# home. Not one of them runs install.sh. `check` is read-only and was gone over
# by hand; `apply`, `update` and the full run had never been executed by
# anybody, anywhere, except under --dry-run, which by design does nothing at
# all. The code that turns a clone into a desktop was the only code here with
# no evidence behind it, and the first real use of `check` turned up two bugs
# within minutes, which is the reason to expect more.
#
# A SANDBOX HOME, NOT $HOME. Everything install.sh writes into a home goes
# through $HOME and the XDG variables, and every one of those is read from the
# environment -- so pointing them at a temporary directory makes a real run
# harmless and repeatable, and lets this be run on a working machine rather
# than only in a container. That matters: a check that can only be run by
# pushing a branch is a check nobody runs before pushing.
#
# WHAT IS NOT SANDBOXED IS PACMAN. The packages step is real, it wants sudo,
# and it installs into the system -- there is no way to prove `apply` works
# while stubbing out the one thing it spends its time doing. So this refuses to
# start without INSTALLER_TEST_INSTALL=1 and says exactly what it will install
# rather than doing it by surprise.
#
# THE PACKAGE LISTS ARE SUBSTITUTED, AND THAT IS THE ONE COMPROMISE HERE.
# packages/required/ plus a compositor is well over a hundred names, four of
# them AUR builds behind a `yay` that has to compile itself from source first.
# Doing that on every pull request would take twenty minutes and would go red
# whenever an AUR package broke, which is a fact about the AUR and not about
# this repository. tests/package-lists.sh already asks whether those names
# exist. The question HERE is whether install.sh's own machinery works, so the
# run happens against a COPY of the tree whose package lists hold a handful of
# tiny packages.
#
# THE SUBSTITUTES ARE NOT ARBITRARY. The stand-in required list is exactly what
# the units downstream need -- stow for the symlinks, git for the Neovim clone,
# curl for the cursor pack -- so the dependency between the packages unit and
# everything after it is real rather than assumed: a packages step that quietly
# did nothing takes the rest of the run down with it, loudly. lib32-glibc is in
# there for [multilib]: without that repository enabled every lib32-* name
# looks like a package that exists nowhere, and this is the list that would say
# so. packages/xwayland-satellite/ is NOT substituted -- the aur-patched unit
# really builds it with makepkg, which is the only real compile in here and the
# only proof that unit works.
#
# WHICH UNITS CAN REACH `ok` WITH NOBODY LOGGED IN. packages, optional,
# aur-patched, symlinks, seeds, nvim, cursors and laptop all can, and every one
# of them is driven here for real -- `optional` included, with a pack that asks
# for a package nothing else in this file installs, so that what is proven is
# the installing and not only the bookkeeping around it. The rest are handled
# rather than ignored:
#
#   palette          wants matugen, a wallpaper daemon and a running compositor
#                    in order to generate eleven files from an image. Unticked
#                    in the profile below -- which is what the profile is FOR,
#                    and is the honest answer for a machine with no session.
#                    palette_apply is therefore not covered by this.
#   etc              writes system files and offers to run mkinitcpio and
#                    grub-mkconfig. Unticked, and deliberately: a container's
#                    /etc is not the /etc anybody boots, so "the commands did
#                    not error" is the most a green result could mean, and it
#                    would be bought by letting a test rewrite pacman.conf and
#                    fstab. There is an assertion below that it stayed out.
#   services-system  enables system units and would write into /etc for the
#                    same non-answer. Unticked.
#   gpu              installs a graphics driver. Unticked, because a driver for
#                    a card you do not have is not a harmless mistake and this
#                    is meant to be runnable on a real machine.
#   services-user    needs a running `systemd --user`, which a container does
#                    not have. It would say `na` there on its own, but it is
#                    unticked as well so this behaves the same on a real
#                    machine, where `systemctl --user enable --now` would reach
#                    out of the sandbox and into the session that is running.
#   shell            says `na` wherever zsh is not in /etc/shells, and its
#                    apply is `chsh`, which authenticates through PAM with a
#                    password no test has.
#   monitors         needs a compositor to ask over a socket, and prints
#                    commands rather than running them in any case.
#
# THE ASSERTION THAT MATTERS is that the second run finds nothing to do.
# "Re-runnable" is the promise every unit makes and the whole design rests on,
# and the only way to prove it is to do the work and then ask for it again --
# once through `update`, which is the mode meant for a keybind or a cron job
# with nobody watching, and once through the menu.
#
# Run it from anywhere:  INSTALLER_TEST_INSTALL=1 tests/installer-run.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# What the substitute lists ask pacman for. Small, in the official
# repositories, and dull enough that installing them on the machine running
# this is not an imposition.
readonly WANTED_PACKAGES="git stow curl tree lib32-glibc cowsay sl figlet"

if [[ ${INSTALLER_TEST_INSTALL:-0} != 1 ]]; then
    cat >&2 <<EOF
installer-run: this runs install.sh for real, which means sudo and pacman.

It writes only into a temporary home -- your own \$HOME is not touched, and
neither is /etc -- but the packages step cannot be faked, so it will install
these into the system:

  $WANTED_PACKAGES

and it will build packages/xwayland-satellite/ with makepkg, which pulls clang
and rust in as build dependencies and installs the result.

Set INSTALLER_TEST_INSTALL=1 to allow that.
EOF
    exit 2
fi

# ---------------------------------------------------------------------------
# Reporting. Collected rather than fatal, so one run says everything that is
# wrong instead of one thing per push -- the same reason the workflow puts
# `!cancelled()` on every step.
FAILURES=0
say()  { printf '\ninstaller-run: == %s ==\n' "$*"; }
pass() { printf 'installer-run:   ok    %s\n' "$*"; }
bad()  { printf 'installer-run:   FAIL  %s\n' "$*" >&2; FAILURES=$(( FAILURES + 1 )); }

# want <description> <command>...
#
# The command's own output is thrown away -- what is reported is the
# description, which says what was expected in words, and a failing `grep -q`
# printing nothing is exactly as informative as a failing `test -L`.
want() {
    local what="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$what"; else bad "$what"; fi
}

want_not() {
    local what="$1"; shift
    if "$@" >/dev/null 2>&1; then bad "$what"; else pass "$what"; fi
}

want_eq() {
    local what="$1" expected="$2" actual="$3"
    if [[ $expected == "$actual" ]]; then
        pass "$what"
    else
        bad "$what"
        printf 'installer-run:         expected: %s\n' "$expected" >&2
        printf 'installer-run:         got:      %s\n' "$actual" >&2
    fi
}

# ---------------------------------------------------------------------------
# THE SANDBOX. One temporary directory holding a home and a copy of the repo,
# removed on the way out however this ends.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

HOME_DIR="$SANDBOX/home"
MINI="$SANDBOX/repo"
mkdir -p "$HOME_DIR" "$MINI"

# A copy and not a checkout, so what is tested is the working tree as it stands
# -- including changes that have not been committed yet. .git goes because
# nothing install.sh does here looks at it, and because in a git worktree it is
# a file pointing somewhere outside the sandbox.
cp -a "$REPO/." "$MINI/"
rm -rf "$MINI/.git"

# The substitution. Every real list is removed rather than added to, so a name
# that is expensive to install cannot arrive here by being added upstream.
rm -f "$MINI"/packages/required/*.txt \
      "$MINI"/packages/compositor/*.txt \
      "$MINI"/packages/optional/*.txt

# The first line of a list is its one-line description -- pkg_list_summary
# reads it -- so these carry one too rather than being bare names.
cat > "$MINI/packages/required/ci.txt" <<'EOF'
# Stand-ins for the real required lists, see tests/installer-run.sh.
git
stow
curl
tree
lib32-glibc
EOF
printf '# Stand-in for the Hyprland list.\ncowsay\n' > "$MINI/packages/compositor/hyprland.txt"
printf '# Stand-in for the niri list.\nsl\n'          > "$MINI/packages/compositor/niri.txt"
# THE TICKED PACK ASKS FOR A PACKAGE NOTHING ELSE HERE INSTALLS, which is the
# only way this unit's own work gets covered. It used to ask for `tree`, which
# the required list above has already put in, so `pacman -S --needed` found
# nothing to do and returned before it could ask anything -- and it had to,
# because optional_apply called pkg_install from inside
#
#     while IFS= read -r group; do ... done < <(optional_groups)
#
# which put the LIST OF GROUP NAMES on pacman's stdin. pacman read `gaming` as
# the answer to "Proceed with installation? [Y/n]", took it for a no, and the
# groups it had swallowed never got their turn:
#
#     :: Proceed with installation? [Y/n] gaming
#        apps: pacman did not finish, see the output above
#
# optional_apply reads the group list into an array now, so the pack can name
# something that is genuinely missing and the assertion further down is that it
# arrived. figlet: 102 KiB, in extra, depends on glibc and sh.
printf '# Stand-in for the apps pack.\nfiglet\n'      > "$MINI/packages/optional/apps.txt"
printf '# Stand-in for the gaming pack.\nbc\n'        > "$MINI/packages/optional/gaming.txt"
printf '# Stand-in for the hardware pack.\nlolcat\n'  > "$MINI/packages/optional/hardware.txt"
printf '# Stand-in for the neovim pack.\ncowsay\n'    > "$MINI/packages/optional/neovim.txt"

PROFILE="$HOME_DIR/.local/state/dotfiles-profile"

# ---------------------------------------------------------------------------
# NOTHING ON STDIN, AND THAT IS THE POINT OF IT.
#
# This used to hand the run a megabyte of "y" so that pacman -- which had no
# --noconfirm and stops dead on ":: Proceed with installation? [Y/n]" with
# nothing to read -- could get through the packages step. lib/pkg.sh now passes
# --noconfirm whenever this script would not be able to relay an answer, so the
# crutch is gone and its absence is itself the check: every run below is given
# /dev/null, and anything that goes back to reading an answer off stdin gets end
# of file and fails here rather than on somebody's machine.
# EVERY XDG VARIABLE, NOT JUST THE ONE. install.sh reaches XDG_STATE_HOME by
# name and $HOME/.config by hand, and the machine running this may well have
# the others pointing somewhere real -- so all four are aimed at the sandbox,
# and the two "there is a compositor here" variables are removed, or a run on a
# live niri session would go and ask it about its monitors.
installer() {
    env -u NIRI_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$HOME_DIR" \
        XDG_CONFIG_HOME="$HOME_DIR/.config" \
        XDG_STATE_HOME="$HOME_DIR/.local/state" \
        XDG_DATA_HOME="$HOME_DIR/.local/share" \
        XDG_CACHE_HOME="$HOME_DIR/.cache" \
        NO_COLOR=1 \
        "$MINI/install.sh" "$@" </dev/null
}

# `check` asks nothing and must never need an answer, so it is given a stdin
# that has none. If it ever starts reading one, that is the bug, and this is
# what makes it visible instead of silently satisfied.
checker() {
    env -u NIRI_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$HOME_DIR" \
        XDG_CONFIG_HOME="$HOME_DIR/.config" \
        XDG_STATE_HOME="$HOME_DIR/.local/state" \
        XDG_DATA_HOME="$HOME_DIR/.local/share" \
        XDG_CACHE_HOME="$HOME_DIR/.cache" \
        NO_COLOR=1 \
        "$MINI/install.sh" check "$@" </dev/null
}

# ---------------------------------------------------------------------------
say "check, on a machine where nothing has been done"

# `check` answers 1 when an applicable unit is not ok, and on a bare home every
# one of them is. A `check` that came back happy HERE would mean it cannot tell
# the two states apart, which is the whole of its job.
bare_check="$SANDBOX/check-bare.txt"
if checker > "$bare_check" 2>&1; then
    bad "check exits non-zero on a machine that has had nothing done to it"
else
    pass "check exits non-zero on a machine that has had nothing done to it"
fi
sed 's/^/installer-run:   | /' "$bare_check"

want "check names every unit it knows" \
     grep -qE '^ +[a-z]+ +symlinks ' "$bare_check"

# --json is what anything other than a person is supposed to read, so it has to
# BE json -- and it is written by hand in lib/units.sh, which is exactly the
# kind of code that is one unescaped quote away from being unparseable.
json="$SANDBOX/check-bare.json"
checker --json > "$json" 2>/dev/null || true
want "check --json parses"    jq -e 'type == "array"' "$json"
want "check --json has units" jq -e 'length >= 10' "$json"

# ---------------------------------------------------------------------------
say "the profile it will be driven with"

# WRITTEN BEFORE THE FIRST RUN, because this is the only way to say "not on
# this machine" to a mode that has nobody to ask -- and it is also the
# profile's entire reason to exist, so seeding one and watching install.sh
# honour it IS the round trip. It is read back and compared further down.
#
# The four zeroes are the units listed at the top of this file as unsafe or
# meaningless to run here. unit.optional and group.apps are ticked on purpose
# rather than left alone: the optional groups are opt-in, so a run that said
# nothing about them would never reach tui_optional or optional_apply at all.
mkdir -p "$(dirname "$PROFILE")"
printf '%s\t%s\n' \
    unit.palette         0 \
    unit.gpu             0 \
    unit.services-user   0 \
    unit.services-system 0 \
    unit.etc             0 \
    unit.optional        1 \
    group.apps           1 \
    > "$PROFILE"
sed 's/^/installer-run:   | /' "$PROFILE"

# What /etc looks like before install.sh has been anywhere near it. pacman
# rewrites nothing in here on its own, so anything that moves was the etc unit
# getting in when it was told not to -- the one thing in this run that could
# damage the machine it is running on.
etc_before="$(sha256sum /etc/pacman.conf /etc/fstab 2>/dev/null || true)"

# ---------------------------------------------------------------------------
say "the first real run"

# --compositor=both is the answer nobody ever gives and therefore the one least
# likely to work: it links two compositors' configuration at once, installs
# both of their package lists, and is what brings the aur-patched unit into
# play, since xwayland-satellite is niri's X11 support and Hyprland has its
# own. tests/stow-conflicts.sh has already established that the two stow
# packages can coexist, so a failure here is install.sh's.
first="$SANDBOX/run-1.txt"
installer -y --compositor=both > "$first" 2>&1
sed 's/^/installer-run:   | /' "$first"

# THE EXIT STATUS IS NOT ASKED FOR HERE, AND THAT IS DELIBERATE. install.sh's
# apply and setup modes end on report_failures, which succeeds whether or not
# it had anything to report -- so a run in which four units failed still exits
# 0 and the status says nothing about it. (`update`, further down, is the one
# mode that does return a real status, and there it IS asked for.) What every
# mode prints is the "N thing(s) did not work" banner, so that is what is read.
want_not "the first run reports no failed units" \
         grep -q 'did not work' "$first"

want "the first run applies the packages unit"     grep -q '== Packages ==' "$first"
want "the first run applies the symlinks unit"     grep -q '== Symlinks ==' "$first"
want "the first run applies the seeds unit"        grep -q '== Seeds ==' "$first"
want "the first run runs the symlinks reload hook" \
     grep -q 'Nothing running picks new configuration up on its own' "$first"

# The units the profile said no to are not in the list the run announces, and
# nothing pulled them back in as a requirement of something else.
want_not "an unticked unit is not applied" grep -qE '^== (Colour palette|/etc) ==' "$first"

# ---------------------------------------------------------------------------
say "what the first run left on disk"

# The packages step really ran pacman, rather than printing what it would have
# run. `tree` is the cheapest name in the list and is in no container image.
want "pacman installed what the packages unit asked for"      pacman -Qq tree
# THE TICKED PACK, AND ONLY IT. The other three lists exist and hold names of
# their own; if the group half of the profile were being ignored, all four
# would be processed here and `bc` would be on the machine.
want "the ticked optional pack is the one that was processed" \
     grep -qF 'apps: 1 package(s)' "$first"
# AND IT REALLY INSTALLED IT. figlet is in no container image and in none of
# the required lists above, so the only thing that can have put it here is
# optional_apply -- which is the half of this unit that stood on nothing until
# pkg_install stopped sharing that loop's stdin.
want "the ticked optional pack really installed its package" pacman -Qq figlet
want_not "an optional pack nobody ticked was not processed" \
     grep -qF 'gaming: 1 package(s)' "$first"
want_not "the optional packs that were not ticked stayed out" pacman -Qq bc

# Both compositors' lists, because the answer was `both`.
want "the Hyprland list went in" pacman -Qq cowsay
want "the niri list went in"     pacman -Qq sl

# THE ONE REAL COMPILE. packages/xwayland-satellite/ is an Arch PKGBUILD plus a
# one-line upstream fix, versioned 0.8.2-1.1 so that a released fix replaces it
# on its own. The unit builds it with makepkg and installs the result, and this
# is the only thing that says that path works.
want "the patched AUR package was built and installed" pacman -Qq xwayland-satellite

# STOW REALLY LINKED, and the link really lands in the repository. A test that
# only asked whether the file exists would pass on a copy, which is the one
# outcome stow is there to avoid.
want "the ~/.zshrc link is a symlink"        test -L "$HOME_DIR/.zshrc"
want_eq "the ~/.zshrc link lands in the repo" \
        "$MINI/zsh/.zshrc" "$(readlink -f "$HOME_DIR/.zshrc" 2>/dev/null || true)"
want "the Hyprland configuration is linked"  test -L "$HOME_DIR/.config/hypr/hyprland.lua"
want "the niri configuration is linked"      test -L "$HOME_DIR/.config/niri/config.kdl"

# --no-folding is what keeps ~/.config/hypr a real directory instead of one
# link standing for the whole thing, and it is the difference between an
# application dropping a new file into $HOME and dropping it into the repo.
want "stow did not fold whole directories" test ! -L "$HOME_DIR/.config/hypr"

# A SEED IS A COPY AND MUST NOT BE A LINK. That is the rule seeds/README.md
# states in capitals, it is the reason those two files are not a stow package,
# and nothing had ever checked it.
want "the qt6ct seed is a real file, not a link" \
     test -f "$HOME_DIR/.config/qt6ct/qt6ct.conf" -a ! -L "$HOME_DIR/.config/qt6ct/qt6ct.conf"
want "the qt6ct seed is the repo's copy" \
     cmp -s "$MINI/seeds/qt6ct.conf" "$HOME_DIR/.config/qt6ct/qt6ct.conf"
want "the mimeapps seed is a real file, not a link" \
     test -f "$HOME_DIR/.config/mimeapps.list" -a ! -L "$HOME_DIR/.config/mimeapps.list"

want "the Neovim configuration was cloned" test -d "$HOME_DIR/.config/nvim/.git"

# The cursor pack is the one thing here that trusts a third party with write
# access to a home directory, and the sha256 pinned in the unit is what stands
# between a moved release asset and a tar running loose in $HOME. Getting this
# far means the download matched it.
want "the cursor pack unpacked into ~/.icons" \
     bash -c 'compgen -G "$1/.icons/Bibata-Material-*"' _ "$HOME_DIR"

# The laptop question was asked and answered -- with --yes, which means yes.
want "the laptop answer was written down" test -f "$HOME_DIR/.local/state/laptop-modules"
# `laptop-modules on` writes 1 and 0 rather than on and off -- the file is the
# same TSV the rest of the state directory uses, and 1 is what Quickshell reads
# out of it.
want "the laptop answer is the one --yes gives" \
     grep -qP '^battery\t1' "$HOME_DIR/.local/state/laptop-modules"

# AND NOTHING IN /etc MOVED. The etc unit rewrites pacman.conf and fstab and
# offers to run mkinitcpio and grub-mkconfig; it was told no, and this is the
# assertion that the answer was honoured rather than merely given.
want_eq "nothing wrote to /etc" \
        "$etc_before" "$(sha256sum /etc/pacman.conf /etc/fstab 2>/dev/null || true)"

# ---------------------------------------------------------------------------
say "the profile round trip"

# The TUI writes this file and `update` reads it. What comes back out has to be
# what went in, plus the compositor that was chosen on the command line.
sed 's/^/installer-run:   | /' "$PROFILE"

want "the profile was written" test -f "$PROFILE"
want_eq "the compositor chosen on the command line was remembered" \
        "both" "$(awk -F'\t' '$1 == "compositor" { print $2 }' "$PROFILE")"
want_eq "the unticked palette stayed unticked" \
        "0" "$(awk -F'\t' '$1 == "unit.palette" { print $2 }' "$PROFILE")"
want_eq "the unticked etc unit stayed unticked" \
        "0" "$(awk -F'\t' '$1 == "unit.etc" { print $2 }' "$PROFILE")"
want_eq "the ticked optional pack was recorded" \
        "1" "$(awk -F'\t' '$1 == "group.apps" { print $2 }' "$PROFILE")"
want_eq "the packs nobody ticked were recorded as a no" \
        "0" "$(awk -F'\t' '$1 == "group.gaming" { print $2 }' "$PROFILE")"

# Sorted with LC_ALL=C on the way out, so that two machines writing the same
# answers produce byte-identical files. An unsorted profile is a diff nobody
# can read.
want_eq "the profile is sorted" \
        "$(LC_ALL=C sort "$PROFILE")" "$(cat "$PROFILE")"

# ---------------------------------------------------------------------------
say "the compositor comes back out of the profile"

# compositor_resolve prefers the flag, then the profile, then whatever is
# installed. Nothing in this sandbox installs a compositor, so a `check` given
# no flag can only get `both` from the file that was just written.
resolved="$SANDBOX/check-resolve.txt"
checker > "$resolved" 2>&1 || true
want "check with no --compositor reads it from the profile" \
     grep -q '== check -- both ==' "$resolved"

# ---------------------------------------------------------------------------
say "update finds nothing to do"

# THIS IS THE ONE THAT MATTERS, and `update` is the mode to ask it with: it
# takes no questions whatever is on stdin, reads what the profile says this
# machine wants, applies what is both wanted and not already in place -- and
# unlike every other mode here it returns a real exit status, non-zero when
# anything failed, because it is the one meant to be run by something that will
# never read the output.
update="$SANDBOX/run-update.txt"
if installer update > "$update" 2>&1; then
    pass "update exits zero"
else
    bad "update exits zero"
fi
sed 's/^/installer-run:   | /' "$update"

want "update has nothing left to do"      grep -qF 'nothing to do' "$update"
want_not "update applies nothing"         grep -q '^== Packages ==' "$update"
want_not "update reports no failures"     grep -q 'did not work' "$update"

# ---------------------------------------------------------------------------
say "and so does a second trip through the menu"

# The other half of "re-runnable": `git pull && ./install.sh` is documented as
# the normal way to take an update, so the menu path has to reach the same
# conclusion -- the intersection of "ticked" and "not already in place" is
# empty, and it says so in one sentence rather than doing the lot again.
second="$SANDBOX/run-2.txt"
installer -y --compositor=both > "$second" 2>&1
sed 's/^/installer-run:   | /' "$second"

want "the second run has nothing left to do" \
     grep -qF 'Nothing to do: everything ticked is already in place.' "$second"
want_not "the second run applies nothing"     grep -q '^== Packages ==' "$second"
want_not "the second run reports no failures" grep -q 'did not work' "$second"

# And neither of them quietly rewrote the profile into something else.
want_eq "the profile is unchanged by running again" \
        "$(LC_ALL=C sort "$PROFILE")" "$(cat "$PROFILE")"

# ---------------------------------------------------------------------------
say "what check says once everything has been applied"

# EVERY UNIT'S FINAL STATE, PINNED BY NAME. A summary line would stay green
# while one unit quietly moved from ok to na, which is the kind of drift this
# mode exists to catch -- so each one is named and compared.
#
# palette is `missing` on purpose: it was never ticked, there is no session to
# generate a colour scheme in, and calling it fine would be a lie. gpu, shell,
# services-user, services-system, etc and monitors are left out of this list
# because their answer depends on the machine -- most of them say `na` in a
# container and something else on a desktop -- and pinning them would make this
# pass only in CI.
final="$SANDBOX/check-final.json"
checker --json > "$final" 2>/dev/null || true

for expectation in packages=ok optional=ok aur-patched=ok symlinks=ok seeds=ok \
                   nvim=ok cursors=ok laptop=ok palette=missing; do
    want_eq "check says ${expectation%%=*} is ${expectation#*=}" \
            "${expectation#*=}" \
            "$(jq -r --arg id "${expectation%%=*}" \
                  '.[] | select(.id == $id) | .kind' "$final")"
done

# ---------------------------------------------------------------------------
say "check writes nothing"

# The claim `check` is built around -- no sudo, no files, safe at any moment on
# a working machine -- put against a home that now has something in it to
# damage. ~/.icons and the Neovim clone are left out because hashing 845 MB of
# cursor bitmaps to learn nothing is not a trade worth making; everything
# install.sh itself wrote is in the rest.
snapshot() {
    find "$HOME_DIR/.config" "$HOME_DIR/.local" "$HOME_DIR/.zshrc" \
         -path "$HOME_DIR/.config/nvim" -prune -o -print0 2>/dev/null |
        LC_ALL=C sort -z |
        xargs -0 -r ls -ldn --time-style=+ |
        sha256sum
}
before="$(snapshot)"
checker        >/dev/null 2>&1 || true
checker --json >/dev/null 2>&1 || true
after="$(snapshot)"
want_eq "check left the home directory exactly as it found it" "$before" "$after"

# ---------------------------------------------------------------------------
say "apply repairs one unit"

# `apply <unit>` is the mode for the day one thing has gone wrong, and it had
# never been run either. Deleting a link and asking for it back is the smallest
# honest version of that.
rm -f "$HOME_DIR/.zshrc"
want_not "the link really is gone" test -e "$HOME_DIR/.zshrc"

repair="$SANDBOX/apply-symlinks.txt"
installer apply symlinks -y > "$repair" 2>&1
sed 's/^/installer-run:   | /' "$repair"

want "apply symlinks puts the link back"      test -L "$HOME_DIR/.zshrc"
want_not "apply symlinks reports no failures" grep -q 'did not work' "$repair"

# APPLY DOES NOT CHAIN, and that is the design: it is what somebody reaches for
# after reading one wrong row in the check table, and expanding `symlinks` into
# `packages` turned "relink one file" into an offer to reinstall the desktop.
want_not "apply on its own does not pull in what it requires" \
         grep -q 'with what they require' "$repair"

# --with-requires is the way back, and says so before it does it.
chained="$SANDBOX/apply-chained.txt"
installer apply seeds --with-requires -y > "$chained" 2>&1
want "--with-requires says what it pulled in" \
     grep -q 'with what they require:.*symlinks' "$chained"

# A unit id that does not exist is a typo, and a typo is worth exiting on.
if installer apply nosuchunit -y >/dev/null 2>&1; then
    bad "apply accepts a unit that does not exist"
else
    pass "apply refuses a unit that does not exist"
fi

# ---------------------------------------------------------------------------
say "--dry-run writes nothing either"

# The other half of the same promise: a mode that says what it would do has to
# not do it. Checked AFTER the sandbox has real content in it, because a dry
# run over an empty directory cannot get this wrong.
before="$(snapshot)"
installer apply symlinks seeds laptop -y -n >/dev/null 2>&1 || true
after="$(snapshot)"
want_eq "a dry run left the home directory exactly as it found it" "$before" "$after"

# ---------------------------------------------------------------------------
if (( FAILURES )); then
    printf '\ninstaller-run: %d assertion(s) failed\n' "$FAILURES" >&2
    exit 1
fi
echo
echo "installer-run: install.sh installs, and installs again to no effect"
