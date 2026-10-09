#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${VSCODE_CONFIG_DIR:-${HOME}/.config/Code}"
EXTENSIONS_DIR="${VSCODE_EXTENSIONS_DIR:-${HOME}/.vscode/extensions}"
RAMDISK_SIZE="${VSCODE_RAMDISK_SIZE:-512M}"
TMP_BASE="${VSCODE_TMPDIR:-/tmp}"
VSCODE_BIN="${VSCODE_BIN:-}"
DRY_RUN="${VSCODE_DRY_RUN:-0}"
RSYNC_EXCLUDES=(
    --exclude=Cache/
    --exclude=CachedData/
    --exclude=CachedExtensionVSIXs/
    --exclude=CachedExtensions/
    --exclude='Code Cache/'
    --exclude=CachedConfigurations/
    --exclude=logs/
    --exclude='Service Worker/'
    --exclude=GPUCache/
    --exclude=ShaderCache/
)
VSCODE_ARGS=()

usage() {
    cat <<'EOF'
Usage: vscode-usb.sh [options] [-- vscode-args...]

Run VS Code with user data copied to tmpfs, then sync it back on exit.

Options:
  --size SIZE            tmpfs size (default: VSCODE_RAMDISK_SIZE or 512M)
  --config-dir DIR       VS Code user-data source directory
  --extensions-dir DIR   VS Code extensions source directory
  --bin CMD              VS Code binary/command (auto-detected if omitted)
  --tmpdir DIR           Parent directory for the temporary mountpoint
  --dry-run              Show what would happen without changing anything
  -h, --help             Show this help

Environment:
  VSCODE_RAMDISK_SIZE
  VSCODE_CONFIG_DIR
  VSCODE_EXTENSIONS_DIR
  VSCODE_BIN
  VSCODE_TMPDIR
  VSCODE_DRY_RUN
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --size)
            [[ $# -ge 2 ]] || { echo "Error: --size requires a value." >&2; exit 1; }
            RAMDISK_SIZE="$2"
            shift 2
            ;;
        --config-dir)
            [[ $# -ge 2 ]] || { echo "Error: --config-dir requires a value." >&2; exit 1; }
            CONFIG_DIR="$2"
            shift 2
            ;;
        --extensions-dir)
            [[ $# -ge 2 ]] || { echo "Error: --extensions-dir requires a value." >&2; exit 1; }
            EXTENSIONS_DIR="$2"
            shift 2
            ;;
        --bin)
            [[ $# -ge 2 ]] || { echo "Error: --bin requires a value." >&2; exit 1; }
            VSCODE_BIN="$2"
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
            VSCODE_ARGS=("$@")
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

for cmd in sudo rsync mountpoint mount umount ps grep mktemp sleep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command is missing: $cmd" >&2
        exit 1
    fi
done

if [[ -z "$VSCODE_BIN" ]]; then
    VSCODE_BIN=$(command -v code 2>/dev/null || command -v code-oss 2>/dev/null || command -v codium 2>/dev/null || true)
fi

if [[ -z "$VSCODE_BIN" ]]; then
    echo "VS Code not found." >&2
    exit 1
fi

if [[ "$VSCODE_BIN" == */* ]]; then
    [[ -x "$VSCODE_BIN" ]] || { echo "Error: VS Code binary is not executable: $VSCODE_BIN" >&2; exit 1; }
else
    command -v "$VSCODE_BIN" >/dev/null 2>&1 || { echo "Error: VS Code binary not found: $VSCODE_BIN" >&2; exit 1; }
fi

mkdir -p "$CONFIG_DIR" "$EXTENSIONS_DIR"
[[ -d "$TMP_BASE" ]] || { echo "Error: tmpdir does not exist: $TMP_BASE" >&2; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run: would launch VS Code from tmpfs\n'
    printf '  binary: %s\n' "$VSCODE_BIN"
    printf '  config dir: %s\n' "$CONFIG_DIR"
    printf '  extensions dir: %s\n' "$EXTENSIONS_DIR"
    printf '  ramdisk size: %s\n' "$RAMDISK_SIZE"
    printf '  tmp base: %s\n' "$TMP_BASE"
    if ((${#VSCODE_ARGS[@]})); then
        printf '  vscode args:'
        printf ' %q' "${VSCODE_ARGS[@]}"
        printf '\n'
    else
        printf '  vscode args: (none)\n'
    fi
    printf '  excludes:'
    printf ' %q' "${RSYNC_EXCLUDES[@]}"
    printf '\n'
    exit 0
fi

RAM="$(mktemp -d "$TMP_BASE/vscode-usb-$(id -u)-XXXXXX")"
MOUNTED=0
PROFILE_READY=0

copy_profile_to_ram() {
    mkdir -p "$RAM/Code" "$RAM/extensions"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$CONFIG_DIR/" "$RAM/Code/"
    rsync -a --delete "$EXTENSIONS_DIR/" "$RAM/extensions/"
    PROFILE_READY=1
}

rsync_back() {
    [[ "$PROFILE_READY" -eq 1 ]] || return 0
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$RAM/Code/" "$CONFIG_DIR/"
    rsync -a --delete "$RAM/extensions/" "$EXTENSIONS_DIR/"
}

has_vscode_instance() {
    ps -u "$(id -u)" -o args= | grep -F -- "$RAM/Code" >/dev/null 2>&1
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

sudo mount -t tmpfs -o "size=$RAMDISK_SIZE,nodev,nosuid,mode=700" tmpfs "$RAM"
sudo chown "$(id -un):$(id -gn)" "$RAM"
MOUNTED=1

if ! mountpoint -q "$RAM"; then
    echo "Failed to mount tmpfs at $RAM" >&2
    exit 1
fi

copy_profile_to_ram

"$VSCODE_BIN" --user-data-dir "$RAM/Code" --extensions-dir "$RAM/extensions" --new-window "${VSCODE_ARGS[@]}" >/dev/null 2>&1 &
LAUNCH_PID=$!
INSTANCE_SEEN=0

for _ in {1..50}; do
    if has_vscode_instance; then
        INSTANCE_SEEN=1
        break
    fi

    sleep 0.2
done

if [[ "$INSTANCE_SEEN" -ne 1 ]]; then
    wait "$LAUNCH_PID" 2>/dev/null || true
    echo "VS Code failed to start with the RAM profile." >&2
    exit 1
fi

while has_vscode_instance; do
    sleep 2
done

wait "$LAUNCH_PID" 2>/dev/null || true
