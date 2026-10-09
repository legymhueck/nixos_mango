#!/usr/bin/env bash
set -euo pipefail

PROFILE_ROOT="${FIREFOX_PROFILE_ROOT:-${HOME}/.mozilla/firefox}"
SOURCE_PROFILE="${FIREFOX_SOURCE_PROFILE:-}"
RAMDISK_SIZE="${FIREFOX_RAMDISK_SIZE:-512M}"
TMP_BASE="${FIREFOX_TMPDIR:-/tmp}"
FIREFOX_BIN="${FIREFOX_BIN:-firefox}"
DRY_RUN="${FIREFOX_DRY_RUN:-0}"
DRY_RUN_NOTE=""
RSYNC_EXCLUDES=(
    --exclude=cache2/
    --exclude=startupCache/
    --exclude=thumbnails/
    --exclude=shader-cache/
    --exclude=crashes/
    --exclude=minidumps/
)
FIREFOX_ARGS=()

usage() {
    cat <<'EOF'
Usage: firefox-usb.sh [options] [-- firefox-args...]

Run Firefox with its profile copied to tmpfs, then sync it back on exit.

Options:
  --size SIZE           tmpfs size (default: FIREFOX_RAMDISK_SIZE or 512M)
  --profile-root DIR    Firefox profile root containing profiles.ini
  --source-profile DIR  Explicit Firefox profile directory to use
  --browser CMD         Firefox binary/command (default: FIREFOX_BIN or firefox)
  --tmpdir DIR          Parent directory for the temporary mountpoint
  --dry-run             Show what would happen without changing anything
  -h, --help            Show this help

Environment:
  FIREFOX_RAMDISK_SIZE
  FIREFOX_PROFILE_ROOT
  FIREFOX_SOURCE_PROFILE
  FIREFOX_BIN
  FIREFOX_TMPDIR
  FIREFOX_DRY_RUN
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --size)
            [[ $# -ge 2 ]] || { echo "Error: --size requires a value." >&2; exit 1; }
            RAMDISK_SIZE="$2"
            shift 2
            ;;
        --profile-root)
            [[ $# -ge 2 ]] || { echo "Error: --profile-root requires a value." >&2; exit 1; }
            PROFILE_ROOT="$2"
            shift 2
            ;;
        --source-profile)
            [[ $# -ge 2 ]] || { echo "Error: --source-profile requires a value." >&2; exit 1; }
            SOURCE_PROFILE="$2"
            shift 2
            ;;
        --browser)
            [[ $# -ge 2 ]] || { echo "Error: --browser requires a value." >&2; exit 1; }
            FIREFOX_BIN="$2"
            shift 2
            ;;
        --tmpdir)
            [[ $# -ge 2 ]] || { echo "Error: --tmpdir requires a value." >&2; exit 1; }
            TMP_BASE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            FIREFOX_ARGS=("$@")
            break
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script as root." >&2
    exit 1
fi

for cmd in sudo rsync mountpoint mount umount ps grep awk mktemp sleep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command is missing: $cmd" >&2
        exit 1
    fi
done

if [[ "$FIREFOX_BIN" == */* ]]; then
    [[ -x "$FIREFOX_BIN" ]] || { echo "Error: Firefox binary is not executable: $FIREFOX_BIN" >&2; exit 1; }
else
    command -v "$FIREFOX_BIN" >/dev/null 2>&1 || { echo "Error: Firefox binary not found: $FIREFOX_BIN" >&2; exit 1; }
fi

resolve_source_profile() {
    local profile_raw first_path

    if [[ -n "$SOURCE_PROFILE" ]]; then
        PROFILE_NAME="$(basename "$SOURCE_PROFILE")"
        SRC="$SOURCE_PROFILE"
        return 0
    fi

    if [[ ! -f "$PROFILE_ROOT/profiles.ini" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            PROFILE_NAME="<new-default-profile>"
            SRC="$PROFILE_ROOT/<new-default-profile>"
            DRY_RUN_NOTE="No Firefox profile exists yet; a default profile would be created first."
            return 0
        fi

        echo "No Firefox profile found, creating default profile..." >&2
        mkdir -p "$PROFILE_ROOT"
        "$FIREFOX_BIN" -CreateProfile default >/dev/null 2>&1
        if [[ ! -f "$PROFILE_ROOT/profiles.ini" ]]; then
            echo "Failed to create Firefox profile." >&2
            return 1
        fi
    fi

    profile_raw=$(awk -F= '
        /^\[Profile[0-9]+\]$/ {
            in_profile=1
            path=""
            def="0"
            rel="1"
            next
        }
        /^\[/ {
            if (in_profile && def=="1" && path!="") {
                print (rel=="1" ? "REL:" : "ABS:") path
                exit
            }
            in_profile=0
            next
        }
        in_profile && $1=="Path" { path=$2 }
        in_profile && $1=="Default" { def=$2 }
        in_profile && $1=="IsRelative" { rel=$2 }
        END {
            if (in_profile && def=="1" && path!="") {
                print (rel=="1" ? "REL:" : "ABS:") path
            }
        }
    ' "$PROFILE_ROOT/profiles.ini")

    if [[ -z "$profile_raw" ]]; then
        first_path=$(awk -F= '/^Path=/{print $2; exit}' "$PROFILE_ROOT/profiles.ini")
        if [[ -z "$first_path" ]]; then
            echo "No Firefox profile found." >&2
            return 1
        fi
        profile_raw="REL:$first_path"
    fi

    if [[ "$profile_raw" == REL:* ]]; then
        PROFILE_NAME="${profile_raw#REL:}"
        SRC="$PROFILE_ROOT/$PROFILE_NAME"
    else
        PROFILE_NAME="$(basename "${profile_raw#ABS:}")"
        SRC="${profile_raw#ABS:}"
    fi
}

resolve_source_profile

if [[ "$DRY_RUN" -ne 1 && ! -d "$SRC" ]]; then
    echo "Resolved Firefox profile path does not exist: $SRC" >&2
    exit 1
fi

[[ -d "$TMP_BASE" ]] || { echo "Error: tmpdir does not exist: $TMP_BASE" >&2; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run: would launch Firefox from tmpfs\n'
    printf '  browser: %s\n' "$FIREFOX_BIN"
    printf '  profile root: %s\n' "$PROFILE_ROOT"
    printf '  source profile: %s\n' "$SRC"
    printf '  ramdisk size: %s\n' "$RAMDISK_SIZE"
    printf '  tmp base: %s\n' "$TMP_BASE"
    if [[ -n "$DRY_RUN_NOTE" ]]; then
        printf '  note: %s\n' "$DRY_RUN_NOTE"
    fi
    if ((${#FIREFOX_ARGS[@]})); then
        printf '  firefox args:'
        printf ' %q' "${FIREFOX_ARGS[@]}"
        printf '\n'
    else
        printf '  firefox args: (none)\n'
    fi
    printf '  excludes:'
    printf ' %q' "${RSYNC_EXCLUDES[@]}"
    printf '\n'
    exit 0
fi

RAM="$(mktemp -d "$TMP_BASE/firefox-usb-$(id -u)-XXXXXX")"
MOUNTED=0
PROFILE_READY=0

copy_profile_to_ram() {
    mkdir -p "$RAM/$PROFILE_NAME"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$SRC/" "$RAM/$PROFILE_NAME/"
    PROFILE_READY=1
}

rsync_back() {
    [[ "$PROFILE_READY" -eq 1 ]] || return 0
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$RAM/$PROFILE_NAME/" "$SRC/"
}

has_firefox_instance() {
    ps -u "$(id -u)" -o args= | grep -F -- "$RAM/$PROFILE_NAME" >/dev/null 2>&1
}

cleanup() {
    local exit_status=$?
    local cleanup_status=0

    trap - EXIT INT TERM

    if [[ "$MOUNTED" -eq 1 ]] && mountpoint -q "$RAM"; then
        if [[ "$PROFILE_READY" -eq 1 ]]; then
            rsync_back || cleanup_status=$?
        fi
        sudo umount "$RAM" || cleanup_status=1
    fi

    rmdir "$RAM" 2>/dev/null || true

    if [[ "$cleanup_status" -ne 0 && "$exit_status" -eq 0 ]]; then
        exit_status=$cleanup_status
    fi

    exit "$exit_status"
}

trap cleanup EXIT INT TERM

sudo mount -t tmpfs -o "size=$RAMDISK_SIZE,nodev,nosuid,noexec,mode=700" tmpfs "$RAM"
sudo chown "$(id -un):$(id -gn)" "$RAM"
MOUNTED=1

if ! mountpoint -q "$RAM"; then
    echo "Failed to mount tmpfs at $RAM" >&2
    exit 1
fi

copy_profile_to_ram

"$FIREFOX_BIN" --no-remote --new-instance -profile "$RAM/$PROFILE_NAME" "${FIREFOX_ARGS[@]}" >/dev/null 2>&1 &
LAUNCH_PID=$!
INSTANCE_SEEN=0

for _ in {1..50}; do
    if has_firefox_instance; then
        INSTANCE_SEEN=1
        break
    fi

    sleep 0.2
done

if [[ "$INSTANCE_SEEN" -ne 1 ]]; then
    wait "$LAUNCH_PID" 2>/dev/null || true
    echo "Firefox failed to start with the RAM profile." >&2
    exit 1
fi

while has_firefox_instance; do
    sleep 2
done

wait "$LAUNCH_PID" 2>/dev/null || true
