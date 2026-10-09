#!/usr/bin/env bash
#
# ssh_ready — get git working with your GitHub key at the start of every lesson.
#
# HOW TO USE (read the three steps once):
#
#   1. FIRST LESSON ONLY: right-click this file -> Edit, and set your details
#      in the "Your details" section below.
#
#   2. Make sure your private key is at the KEY_PATH you set (for example
#      U:\Documents\ssh\id_ed25519). You already pasted the matching PUBLIC
#      key into GitHub — that part only needs to happen once.
#
#   3. EVERY LESSON, open Git Bash in the folder where this file lives and type:
#
#          . ssh_ready.sh
#
#      The dot-space at the start matters! It "sources" the script, which is
#      what keeps the SSH agent alive for the whole lesson, so git never asks
#      for a password again.
#
# If your key has a passphrase, you'll be asked for it once per lesson.
# If you didn't set one, there will be no prompt at all.

# ── Your details ───────────────────────────────────────────────
KEY_PATH="/u/Documents/ssh/id_ed25519"   # your private key on U:
GIT_NAME=""                              # e.g. "Ada Lovelace" (optional)
GIT_EMAIL=""                             # e.g. "ada@school.org" (optional)
KNOWN_HOSTS="/u/Documents/ssh/known_hosts"
# ───────────────────────────────────────────────────────────────

_ssh_ready_help() {
    cat <<EOF
Usage: source $(basename "$0")

Load an SSH key into ssh-agent for the current shell and verify GitHub access.
This script is meant to be sourced, not executed.
EOF
}

_ssh_ready_main() {
    if [[ ! -f "$KEY_PATH" ]]; then
        echo "Error: no key found at $KEY_PATH" >&2
        echo "Fix the KEY_PATH line in the 'Your details' section of ssh_ready.sh." >&2
        return 1
    fi

    if [[ -n "$GIT_NAME" ]]; then
        export GIT_AUTHOR_NAME="$GIT_NAME" GIT_COMMITTER_NAME="$GIT_NAME"
    fi
    if [[ -n "$GIT_EMAIL" ]]; then
        export GIT_AUTHOR_EMAIL="$GIT_EMAIL" GIT_COMMITTER_EMAIL="$GIT_EMAIL"
    fi

    if ! ssh-add -l >/dev/null 2>&1; then
        eval "$(ssh-agent -s 2>/dev/null)"
    fi

    ssh-add "$KEY_PATH"

    export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=\"$KNOWN_HOSTS\" -o StrictHostKeyChecking=accept-new"

    if ssh -o UserKnownHostsFile="$KNOWN_HOSTS" -o StrictHostKeyChecking=accept-new \
            -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo
        echo "SSH ready — you can clone, pull and push."
    else
        echo
        echo "Warning: could not confirm GitHub access." >&2
        echo "Check your public key is added under GitHub -> Settings -> SSH and GPG keys." >&2
        return 1
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    _ssh_ready_help
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 0
    else
        return 0
    fi
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Please SOURCE this script instead of running it:" >&2
    echo "    . $0" >&2
    exit 1
fi

_ssh_ready_main "$@"
_rc=$?
unset -f _ssh_ready_main _ssh_ready_help
return "$_rc"
