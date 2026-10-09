#!/usr/bin/env bash
#
# safe-system-clean.sh
#
# A conservative cleanup helper. It previews the selected operations by default.
# It uses the system's own cleanup tools and never recursively deletes /tmp,
# /var/cache, ~/.cache, /var/log, /var/lib, or the whole home directory.
#
# Run as your normal user. Run with --apply to make changes.

set -Eeuo pipefail

PROGRAM=${0##*/}

APPLY=0
ASSUME_YES=0
DO_TEMP=1
DO_PACKAGES=0
DO_LOGS=0
DO_TRASH=0
LOG_DAYS=14

usage() {
    cat <<EOF
Usage: $0 [options]

The default is a dry run. No cleanup is performed unless --apply is given.

Options:
  --apply             Perform the selected cleanup operations
  --yes               Do not ask for the final confirmation (use with --apply)
  --no-temp           Skip systemd temporary-file cleanup
  --packages          Clear the distro's downloaded-package cache
  --logs              Vacuum journal entries older than LOG_DAYS
  --days N            Journal retention period in days (default: 14)
  --empty-trash       Permanently empty the current user's Trash
  -h, --help          Show this help

Examples:
  $0
  $0 --apply
  $0 --packages --logs --days 30
  $0 --apply --packages --logs --days 30

--empty-trash is irreversible. Review 'trash-list' before using it.
EOF
}

while (($#)); do
    case "$1" in
        --apply)
            APPLY=1
            ;;
        --yes)
            ASSUME_YES=1
            ;;
        --no-temp)
            DO_TEMP=0
            ;;
        --packages)
            DO_PACKAGES=1
            ;;
        --logs)
            DO_LOGS=1
            ;;
        --days)
            shift
            LOG_DAYS=${1:?--days requires a number}
            ;;
        --empty-trash)
            DO_TRASH=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ ! $LOG_DAYS =~ ^[1-9][0-9]*$ ]]; then
    echo "--days must be a positive integer" >&2
    exit 2
fi

if (( ASSUME_YES && ! APPLY )); then
    echo "--yes requires --apply" >&2
    exit 2
fi

# Never empty root's Trash accidentally. A normal user must run this script
# when --empty-trash is requested.
if (( DO_TRASH && EUID == 0 )); then
    echo "Do not run --empty-trash as root; run it as your normal user." >&2
    exit 1
fi

if (( APPLY )); then
    if (( EUID == 0 )); then
        ROOT=()
    else
        if ! command -v sudo >/dev/null 2>&1; then
            echo "sudo is required for system cleanup" >&2
            exit 127
        fi
        ROOT=(sudo)
    fi
else
    # This is only used for displaying commands in dry-run mode.
    if (( EUID == 0 )); then
        ROOT=()
    else
        ROOT=(sudo)
    fi
fi

print_command() {
    local label=$1
    shift
    printf '%s:' "$label"
    printf ' %q' "$@"
    printf '\n'
}

run_as_user() {
    if (( APPLY )); then
        print_command 'Running' "$@"
        "$@"
    else
        print_command 'Would run' "$@"
    fi
}

run_as_root() {
    if (( APPLY )); then
        print_command 'Running with root privileges' "${ROOT[@]}" "$@"
        "${ROOT[@]}" "$@"
    else
        print_command 'Would run with root privileges' "${ROOT[@]}" "$@"
    fi
}

report_space() {
    printf '\nFilesystem usage:\n'
    df -h / 2>/dev/null || true

    local cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
    if [[ -d $cache_home ]]; then
        printf '\nLargest user-cache directories (%s):\n' "$cache_home"
        du -xhd1 -- "$cache_home" 2>/dev/null | sort -h | tail -n 20 || true
    fi
}

print_plan() {
    printf '\nSelected operations:\n'
    if (( DO_TEMP )); then
        printf '  - systemd temporary-file cleanup\n'
    fi
    if (( DO_PACKAGES )); then
        printf '  - package-manager download-cache cleanup\n'
    fi
    if (( DO_LOGS )); then
        printf '  - journal vacuum older than %s days\n' "$LOG_DAYS"
    fi
    if (( DO_TRASH )); then
        printf '  - permanently empty the current user Trash\n'
    fi
}

if ! (( APPLY )); then
    printf 'DRY RUN: no files will be changed.\n'
    print_plan
    report_space
    printf '\nUse --apply after reviewing the plan.\n'
    exit 0
fi

print_plan

if (( ! ASSUME_YES )); then
    if [[ ! -t 0 ]]; then
        echo "Refusing to run without confirmation in a non-interactive shell; use --yes if intentional." >&2
        exit 1
    fi

    read -r -p "Proceed? [y/N] " answer
    if [[ $answer != [yY] ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

if (( DO_TEMP )); then
    if command -v systemd-tmpfiles >/dev/null 2>&1; then
        run_as_root systemd-tmpfiles --clean
    else
        echo "systemd-tmpfiles is unavailable; temporary-file cleanup skipped." >&2
    fi
fi

if (( DO_PACKAGES )); then
    if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get clean
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf clean all
    elif command -v dnf5 >/dev/null 2>&1; then
        run_as_root dnf5 clean all
    elif command -v pacman >/dev/null 2>&1; then
        run_as_root pacman -Sc
    elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper clean --all
    elif command -v apk >/dev/null 2>&1; then
        run_as_root apk cache clean
    else
        echo "No supported package manager found; package-cache cleanup skipped." >&2
    fi
fi

if (( DO_LOGS )); then
    if command -v journalctl >/dev/null 2>&1; then
        run_as_root journalctl --vacuum-time="${LOG_DAYS}d"
    else
        echo "journalctl is unavailable; journal cleanup skipped." >&2
    fi
fi

if (( DO_TRASH )); then
    if command -v trash-empty >/dev/null 2>&1; then
        if (( ASSUME_YES )); then
            run_as_user trash-empty --force
        else
            # trash-cli provides its own confirmation prompt.
            run_as_user trash-empty
        fi
    else
        echo "trash-empty is unavailable; Trash cleanup skipped." >&2
    fi
fi

printf '\nCleanup completed. Check free space with: df -h /\n'
