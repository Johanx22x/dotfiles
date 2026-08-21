#!/usr/bin/env bash
# Nothing in the backup configuration may be a secret.
#
# (Not `backup-secrets` as the first word of a shellcheck directive would be --
# see the note at the top of shell-lint.sh for why the tool's name is kept off
# line one.)
#
# THIS REPOSITORY IS PUBLIC, and that is the whole premise. borgmatic's config
# has two fields that are exactly the shape of a secret -- the passphrase and
# the repository path, which for a remote destination can carry a user, a host
# and in the wrong hands a credential -- and both of them are ordinary YAML
# strings that a person setting the backup up on a second machine will be
# tempted to just fill in. The tracked file reads them out of the environment
# instead, from an untracked ~/.config/borgmatic/local.env.
#
# WHAT MAKES THAT WORTH A CHECK RATHER THAN A COMMENT is that the mistake is
# not reversible. A passphrase pushed here is in the history, on GitHub, and in
# every clone and fork taken before anybody noticed; removing it in a later
# commit removes nothing. A red pull request is the last moment at which it can
# still be un-made, so that is where this sits.
#
# It is the second half of a pair. .gitignore stops the untracked file being
# added; this stops a literal being pasted into the tracked one. Neither
# catches the other's mistake.
#
# Deliberately no dependencies -- no PyYAML, no borgmatic, no network. The
# question is narrow enough for grep, the file is small and ours, and a check
# that needs a package installed is a check that gets skipped.
#
# Run it from anywhere:  tests/backup-secrets.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO/backup/.config/borgmatic/config.yaml"
PACKAGE="$REPO/backup"

failed=0
note() { echo "backup-secrets: $*"; }
fail() { echo "backup-secrets: FAIL $*" >&2; failed=1; }

# What an acceptable value looks like: borgmatic's own environment
# interpolation and nothing else. The braces are part of it -- borgmatic does
# not expand a bare $NAME, it leaves the literal characters in place, so
# `$BORG_PASSPHRASE` would be a config that tries to unlock the repository with
# the string "$BORG_PASSPHRASE".
INTERPOLATION='^"?\$\{[A-Za-z0-9_]+(:?-[^}]+)?\}"?$'

if [[ ! -f $CONFIG ]]; then
    echo "backup-secrets: $CONFIG is missing -- has the layout changed?" >&2
    exit 2
fi

# --- The fields that must never hold a literal -------------------------------
#
# Comment lines are dropped first: this file explains the ${BORG_REPO}
# arrangement at length, and a `#` line quoting a key name is prose rather than
# a setting.
#
# `path:` is checked as well as the two encryption fields, and it is checked
# for being an interpolation rather than for looking harmless. A local path
# gives away nothing, but it is also this machine's and belongs in local.env
# with the rest of what is this machine's -- and once one literal is accepted
# there, `ssh://user:token@host/./repo` is the next one somebody writes.
while IFS= read -r line; do
    [[ ${line#"${line%%[![:space:]]*}"} == '#'* ]] && continue

    case "$line" in
        *encryption_passphrase:*|*encryption_passcommand:*|*path:*) ;;
        *) continue ;;
    esac

    key="${line%%:*}";   key="${key#"${key%%[![:space:]]*}"}";   key="${key#- }"
    value="${line#*:}";  value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ $value =~ $INTERPOLATION ]]; then
        note "$key is \${...}, not a literal"
    else
        fail "$key holds a literal value. It must come from ~/.config/borgmatic/local.env as \${SOMETHING}, never from this file -- the repository is public."
    fi
done < "$CONFIG"

# --- Nothing that looks like key material anywhere in the package ------------
#
# The narrow test above only knows the three field names it was told about. A
# fourth one arrives the first time somebody adds a hook, so this is the coarse
# net underneath it: the openers of the PEM and OpenSSH key formats, and an
# assignment to any BORG_* variable, which is what local.env is made of and
# therefore what a copy-paste out of it looks like.
#
# `BORG_[A-Z_]*=` and not the bare name, so the prose in config.yaml -- which
# has to be able to say BORG_PASSPHRASE in order to explain it -- is not a
# finding.
if grep -rInE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|^[^#]*BORG_[A-Z_]+=' "$PACKAGE"; then
    fail "the lines above look like key material or a copy of local.env"
else
    note "no key material and no BORG_* assignment under backup/"
fi

# --- The untracked half is actually untracked --------------------------------
#
# Two different questions, and the second is the one that has ever gone wrong
# in a repository: `git check-ignore` says the rule exists, `git ls-files` says
# whether the file slipped in BEFORE the rule did -- because .gitignore has no
# effect on a path git is already tracking.
LOCAL_ENV=backup/.config/borgmatic/local.env
if git -C "$REPO" check-ignore -q "$LOCAL_ENV"; then
    note "$LOCAL_ENV is ignored"
else
    fail "$LOCAL_ENV is NOT in .gitignore"
fi

# Listed and then filtered, rather than handed to git as a `backup/**.env`
# pathspec: git's wildmatch gives `**` a directory meaning that makes such a
# pattern quietly match less than it looks like it does, and the package is a
# handful of files.
tracked="$(git -C "$REPO" ls-files -- backup | grep -E '\.env$' || true)"
if [[ -n $tracked ]]; then
    fail "these are tracked and must not be: $tracked"
else
    note "no .env file is tracked under backup/"
fi

if [[ $failed -eq 0 ]]; then
    note "the tracked backup configuration holds no secret"
fi
exit "$failed"
