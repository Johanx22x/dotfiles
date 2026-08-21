# shellcheck shell=bash
# =============================================================
#  desktop-lib.sh — the pieces every script in ~/.local/bin had its own copy of
#
#  Sourced, never run. There is no shebang and no `set -euo pipefail` here: the
#  options belong to the script, which sets them on its first line, and a
#  library that turned them on would be deciding for a caller that had already
#  decided.
#
#  FOUND NEXT TO THE SCRIPT THAT SOURCES IT, through the same resolved path
#  every one of them already uses for the `compositor` helper:
#
#      BIN_DIR="$(dirname "$(readlink -f "$0")")"
#      # shellcheck source=../lib/desktop-lib.sh
#      . "$BIN_DIR/../lib/desktop-lib.sh"
#
#  ~/.local/bin is on the PATH of a login shell and of very little else -- the
#  settings window in Quickshell inherits the compositor's environment, a
#  systemd --user unit gets neither, and install.sh calls these scripts by
#  absolute path with whatever PATH the person started it with. readlink
#  resolves the stow symlink back into the repository, so the library is found
#  whether the script was started from ~/.local/bin or straight out of the
#  checkout.
#
#
#  WHY WRITES GO THROUGH HERE, which is the reason this file exists at all.
#
#  Every state file in this layer used to be written with a plain `>` -- a
#  truncation, then a fill. Two things are wrong with that and both of them
#  have a name on this machine:
#
#    A READER CAN SEE THE GAP. `desktop-tweak` wrote its store with
#    `... | sort > "$STATE_FILE"`, and `sort` buffers its whole input before
#    emitting a byte, so between the truncation and the first write the file is
#    EMPTY -- while a FileView { watchChanges: true } in the shell is watching
#    it. The generated tweaks.lua and tweaks.kdl are worse: niri watches every
#    file it includes, so truncating one IS applying an empty config, for as
#    long as the gap lasts.
#
#    TWO WRITERS LOSE EACH OTHER'S WORK. Config.qml pushes a settled batch as
#    one `desktop-tweak set` process PER KEY, in a loop, all at once. Each of
#    them loads the whole store, changes its own key and saves the whole store
#    back, so whichever one loses the interleave writes a file that never had
#    the other's key in it. The key is not corrupted, it is simply gone, and
#    the settings window goes on showing the value it sent.
#
#  So: state is REPLACED, never truncated -- written to a temporary file and
#  moved over the old one -- and a read-modify-write holds an exclusive lock
#  for the whole of the read and the write.
#
#  THE TEMPORARY GOES IN THE DESTINATION'S OWN DIRECTORY. A bare `mktemp` lands
#  in $TMPDIR, and on this machine `findmnt -T /tmp` says tmpfs while
#  `findmnt -T "$HOME"` says btrfs on /dev/nvme0n1p2 -- two filesystems, so a
#  `mv` between them is a copy followed by an unlink and NOT the atomic rename
#  the pattern depends on. An interrupted copy is a truncated file, which is
#  the exact accident writing whole and moving is there to prevent.
#
#  READS TAKE NO LOCK, and that is not an oversight. `rename(2)` within a
#  filesystem is atomic: a reader opening the file gets either the whole of the
#  old one or the whole of the new one, never half of either. Locking a read
#  would only slow down `show` and the shell's FileView, neither of which can
#  see a partial file any more. The lock exists for the MODIFY in the middle of
#  a read-modify-write, which is the only thing atomicity does not solve.
#
#  THE LOCK IS A FILE OF ITS OWN, .<name>.lock beside the store, and it has to
#  be: an exclusive lock is held on an open file description, and the writer
#  replaces the store's INODE. A second process that had flocked the old inode
#  would be holding a lock on a file nothing points at any more, which is a
#  lock that excludes nobody.
# =============================================================

# Sourcing twice is not an error -- it is what happens the day one of these
# scripts grows a helper that sources this as well -- but redefining a readonly
# would be, so the second time through is a no-op.
if [[ -n ${DESKTOP_LIB:-} ]]; then
    return 0
fi
DESKTOP_LIB=1

# The name to put in front of a message and on a notification. Read from $0 and
# not written down per script, so `hypr-tweak`, which execs desktop-tweak, says
# the new name -- which is the whole point of that shim.
SELF="${0##*/}"

# Where this file is, resolved through the stow symlink, so `compositor` below
# can be found beside the scripts rather than on a PATH that may not have
# ~/.local/bin on it. BASH_SOURCE and not $0: the caller's $0 is the script,
# and this has to work the same when a script is invoked through one of the
# old-name shims.
DESKTOP_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# ---------------------------------------------------------------------------
# Saying something went wrong
# ---------------------------------------------------------------------------
# THE SYSTEM ANSI INDICES AND NOT A HEX COLOUR. These are the terminal's own
# red and yellow, so they follow whatever palette the terminal is wearing --
# which on this machine changes with the wallpaper. A hex colour would be one
# more thing that stops matching after the next `wallpaper-switch`.
#
# The four scripts that carried a copy of `die` all used exactly \033[1;31m,
# and `gaming-check` uses \033[1;33m for the same idea of a warning.
#
# NOT SUPPRESSED WHEN STDERR IS NOT A TERMINAL, which is deliberate: journalctl
# renders these, and a message that loses its colour on the way into the
# journal is a message that reads differently depending on where you find it.
readonly LIB_RED=$'\033[1;31m'
readonly LIB_YELLOW=$'\033[1;33m'
readonly LIB_RESET=$'\033[0m'

# A DESKTOP NOTIFICATION WHEN NOBODY IS LOOKING AT A TERMINAL, and only then.
#
# The two commonest callers of this layer are a systemd timer and a compositor
# keybind. Neither has a terminal, so `echo >&2` goes to the journal or to
# nowhere at all -- which is how a half-applied wallpaper became invisible: the
# rotation timer fired, awww left one output on the previous image,
# wallpaper-switch said so on stderr, and the only record of it was a line in
# `journalctl --user -u wallpaper-rotate` that nobody has a reason to read.
#
# When stderr IS a terminal the person is already looking at the message, and a
# popup repeating it would be noise -- so the test is on the terminal and not on
# whether a notification daemon happens to be up.
#
# x-dunst-stack-tag GROUPS THEM, and it is not decoration either. Config.qml
# pushes one `desktop-tweak set` process per changed key, all at once; a failure
# they share would otherwise be six identical popups. The shell reads that hint
# -- see extraHints in modules/notifications/Notifications.qml, which lists it
# by name -- and replaces the previous notification carrying the same tag.
#
# Silent about its own failure: no notify-send installed, no session bus, no
# daemon. A script must not fail because it could not complain.
lib_notify() {
    local urgency="$1" body="$2"

    [[ -t 2 ]] && return 0
    command -v notify-send >/dev/null 2>&1 || return 0

    notify-send \
        --app-name="$SELF" \
        --urgency="$urgency" \
        --hint="string:x-dunst-stack-tag:$SELF" \
        "$SELF" "$body" 2>/dev/null || true
}

# Stop, having said why. The prefix is the script's own name, which the four
# copies of this did not have and `wallpaper-switch`'s diverged fifth one did:
# in the journal and on a notification, a bare "Not a file: x" names nothing
# that could be looked at afterwards.
die() {
    printf '%s%s: %s%s\n' "$LIB_RED" "$SELF" "$*" "$LIB_RESET" >&2
    lib_notify critical "$*"
    exit 1
}

# Something is wrong and the run goes on anyway. The half-applied cases: a
# wallpaper that reached one output out of two, a daemon that would not stop.
warn() {
    printf '%s%s: %s%s\n' "$LIB_YELLOW" "$SELF" "$*" "$LIB_RESET" >&2
    lib_notify normal "$*"
}

# The running commentary of a command that is working -- what it touched and
# what still needs a restart. STDOUT, indented by two, because it belongs to
# the report the command is printing and not to its error stream.
note() {
    printf '  %s\n' "$*"
}

# ---------------------------------------------------------------------------
# Writing a file without ever showing half of it
# ---------------------------------------------------------------------------

# The lock beside a store. Hidden, because ~/.local/state is a directory a
# person occasionally lists and the lock is not a record of anything. Never
# deleted, not even by `clear`: the lock IS the file, so removing it while
# another process holds it would hand the next writer a different inode and a
# lock that excludes nobody.
lib_lock_path() {
    local path="$1"
    printf '%s/.%s.lock' "$(dirname "$path")" "${path##*/}"
}

# Replace $1 with what $2... writes to stdout. Nothing of the new file is
# visible under the old name until all of it is written, and a command that
# fails leaves the previous file exactly as it was.
#
# THE COMMAND'S STATUS IS CHECKED rather than trusted, and that is the half
# that a plain `{ ... } > file` cannot do at all: by the time a redirection has
# noticed the generator failed, the old file is already gone.
#
# The temporary inherits mktemp's 0600 rather than the umask's 0644. Everything
# written through here -- the state stores, the generated compositor includes,
# kitty's font and opacity fragments -- is read by this user and nobody else,
# so the stricter mode costs nothing and is one less thing to get wrong.
#
# The locals are prefixed for the reason wait_until's are: this calls back into
# the caller's own function, and bash's scoping means an unprefixed `path` or
# `dir` here would be the one the generator sees.
write_generated() {
    local _gen_path="$1"
    shift

    local _gen_dir _gen_tmp
    _gen_dir="$(dirname "$_gen_path")"
    mkdir -p "$_gen_dir"

    _gen_tmp="$(mktemp "$_gen_dir/.${_gen_path##*/}.XXXXXX")" || return 1

    if ! "$@" > "$_gen_tmp"; then
        rm -f "$_gen_tmp"
        return 1
    fi

    mv "$_gen_tmp" "$_gen_path"
}

# The same, for content that arrives on stdin, and holding the store's lock
# while it happens.
#
# The lock matters here and not in write_generated because the callers of this
# one are read-modify-write: `night-light temp` keeps the enabled flag it read a
# moment ago, `desktop-font <size>` keeps the family. A generated file is
# derived from a store that is already consistent, so two writers of one racing
# each other only decide which identical file wins.
state_write() {
    local path="$1"
    local dir status=0

    dir="$(dirname "$path")"
    mkdir -p "$dir"

    # A SUBSHELL SO THE LOCK CLOSES ITSELF. `9>` on a compound command opens the
    # descriptor for the length of it and closes it after, which releases the
    # lock -- no `exec 9>&-` to forget and no descriptor left open across the
    # rest of the script.
    (
        flock 9

        local tmp
        tmp="$(mktemp "$dir/.${path##*/}.XXXXXX")" || exit 1
        if ! cat > "$tmp"; then
            rm -f "$tmp"
            exit 1
        fi
        mv "$tmp" "$path"
    ) 9>"$(lib_lock_path "$path")" || status=$?

    return "$status"
}

# Run $2... holding the exclusive lock on $1's store, for a read-modify-write
# this file has no shape for. `desktop-monitors` is the caller and the only
# one: its rewrite is a `grep -v` of everything except one monitor, with its own
# careful handling of grep's exit 2, and folding that into state_set would mean
# a state_set that knows what a monitor record is.
#
# THE COMMAND RUNS IN A SUBSHELL, which the caller has to know two things
# about: a variable it sets does not come back, and `die` inside it ends the
# subshell rather than the script. The second one is harmless in practice --
# the message still reaches stderr, this returns non-zero, and the caller's
# `set -e` finishes the job -- but a caller that puts this inside an `if` gets
# a script that carries on after a die, which is not what die is for.
state_lock() {
    local _lock_path="$1"
    shift

    mkdir -p "$(dirname "$_lock_path")"
    ( flock 9; "$@" ) 9>"$(lib_lock_path "$_lock_path")"
}

# ---------------------------------------------------------------------------
# The tab-separated key/value store
# ---------------------------------------------------------------------------
# One key per line, a tab, the value, sorted -- so a diff of it is readable and
# the settings window can parse it by splitting on the first tab. It is the
# shape `desktop-tweak` and `laptop-modules` already had; what is new is that
# nothing writes it by truncation any more.

# Fill an associative array from a store. Named rather than printed, because
# every caller wants the whole thing at once and asking key by key would be one
# subshell per row.
#
# The array is EMPTIED FIRST. This is called again after a write, to pick up
# what another process put in the file while this one was between its load and
# its save, and a merge would keep a key that the other process had removed.
state_load() {
    local path="$1"
    local -n _state_ref="$2"
    local key value

    _state_ref=()
    [[ -r $path ]] || return 0

    while IFS=$'\t' read -r key value; do
        [[ -n ${key:-} ]] || continue
        _state_ref[$key]=$value
    done < "$path"
}

# The value of one key, or nothing at all -- so an absent key and a store that
# does not exist yet read the same, which is what every caller here wants.
#
# EXACT-FIELD COMPARISON IN AWK and not `grep "^$key\t"`: a key is a caller's
# string, and one carrying a regex metacharacter would otherwise match rows it
# has no business matching. `NF >= 2` is what keeps a hand-mangled line with no
# tab in it from being printed back as though it were a value; state_set is why
# a value can be taken as the whole of $2, since a tab in one is refused.
state_get() {
    local path="$1" key="$2"

    [[ -r $path ]] || return 0
    awk -F'\t' -v k="$key" 'NF >= 2 && $1 == k { print $2; exit }' "$path"
}

# THE ONE PLACE A KEY IS WRITTEN. Load, change one row, save -- all of it
# inside the lock, which is what makes six of these running at once end with
# six keys in the file instead of one.
#
# A TAB OR A NEWLINE IS REFUSED rather than written. Either one puts a row in
# the file that this reader and the QML one both split in the wrong place, and
# the damage is to the whole store rather than to the value that carried it.
# Nothing here has ever needed one: the free-text values are a cursor theme
# name and a keysym.
state_set() {
    local path="$1" key="$2" value="$3"

    [[ $key != *$'\t'* && $key != *$'\n'* ]] \
        || die "a key cannot contain a tab or a newline: '$key'"
    [[ $value != *$'\t'* && $value != *$'\n'* ]] \
        || die "a value cannot contain a tab or a newline: '$value'"

    lib_state_rewrite "$path" set "$key" "$value"
}

# Forget one key. Not the same as setting it to the empty string: every reader
# in this layer falls back to a default for a key that is absent, and an empty
# value is a value -- `desktop-tweak reset cursor-theme` has to mean "whatever
# the system already has" and not "the theme called nothing".
state_unset() {
    local path="$1" key="$2"

    lib_state_rewrite "$path" unset "$key"
}

# Every row except $3's, plus a new one when $2 is `set`. The mode is a word
# rather than "is there a fourth argument", because the fourth argument is
# routinely the empty string and that is a value like any other.
#
# Sorted with LC_ALL=C so the order does not move with the locale -- a store
# that reorders itself because a machine speaks a different language is a diff
# nobody asked for. `sort -o` over its own input is safe and documented: it
# reads the whole file before it writes any of it.
lib_state_rewrite() {
    local path="$1" mode="$2" key="$3" value="${4-}"
    local dir status=0

    dir="$(dirname "$path")"
    mkdir -p "$dir"

    (
        flock 9

        local tmp
        tmp="$(mktemp "$dir/.${path##*/}.XXXXXX")" || exit 1

        # THE READ IS INSIDE THE LOCK, and that is the entire point of the
        # lock. Reading the store outside it and writing inside would still
        # lose the other process's key -- it would just lose it slightly later.
        if [[ -r $path ]]; then
            awk -F'\t' -v k="$key" '$1 != k' "$path" > "$tmp" || { rm -f "$tmp"; exit 1; }
        fi

        if [[ $mode == set ]]; then
            printf '%s\t%s\n' "$key" "$value" >> "$tmp"
        fi

        LC_ALL=C sort -o "$tmp" "$tmp" || { rm -f "$tmp"; exit 1; }
        mv "$tmp" "$path"
    ) 9>"$(lib_lock_path "$path")" || status=$?

    return "$status"
}

# ---------------------------------------------------------------------------
# Waiting for something to become true
# ---------------------------------------------------------------------------
# Try $3... up to $1 times, sleeping $2 between attempts. Exits 0 the moment it
# succeeds and 1 having run out of attempts, so a caller reads as "wait for
# this, and here is what to do if it never happens".
#
# NO SLEEP AFTER THE LAST ATTEMPT. The eight hand-written copies of this loop
# all slept on their way out of the last iteration, which is up to four seconds
# of a wallpaper change spent waiting after the answer is already known to be
# no.
#
# The command is run through "$@", so a shell function is as good as a program
# -- which is what the callers here mostly pass, since the thing being waited
# for is usually a question only they can ask.
#
# THE LOCALS ARE PREFIXED BECAUSE BASH SCOPES DYNAMICALLY, and this is not
# hygiene, it is a hang that was measured while writing the harness for this
# file. A `local` is visible to everything the function calls, so a predicate
# that touched a variable of its own called `attempts` was assigning to THIS
# loop's bound: the predicate counted its own tries upwards, the bound moved
# with it, `i <= attempts` stayed true and wait_until never came back. Any name
# a caller might reasonably use is a name this function cannot have.
wait_until() {
    local _wait_attempts="$1" _wait_delay="$2"
    shift 2

    local _wait_i
    for (( _wait_i = 1; _wait_i <= _wait_attempts; _wait_i++ )); do
        "$@" && return 0
        if (( _wait_i < _wait_attempts )); then
            sleep "$_wait_delay"
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# The compositor helper
# ---------------------------------------------------------------------------
# Seven scripts carried the same two lines to find `compositor` beside
# themselves instead of on a PATH that may not have ~/.local/bin on it. The
# path is exported as well as wrapped, because two of them -- `gs` and
# `gaming-check` -- cannot call it directly: gs has to strip Steam's
# LD_LIBRARY_PATH off it first and gaming-check may be running as root and has
# to hand it back to the real user.
COMPOSITOR_BIN="$DESKTOP_LIB_DIR/../bin/compositor"

# shellcheck disable=SC2120  # a passthrough shim: most callers pass nothing,
# and the ones that ask `can` or `is` pass two words.
compositor() { "$COMPOSITOR_BIN" "$@"; }
