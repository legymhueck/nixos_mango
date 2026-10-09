#!/usr/bin/env bash
set -euo pipefail

LUKS_DEV="${1:-${LUKS_DEV:-}}"
FIDO2_DEVICE="${FIDO2_DEVICE:-auto}"
INSTALL_LIBFIDO2="${INSTALL_LIBFIDO2:-auto}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [luks-device]

Enroll a YubiKey/FIDO2 token for a LUKS volume.

Examples:
  $(basename "$0") /dev/nvme0n1p2
  LUKS_DEV=/dev/sda3 $(basename "$0")
  FIDO2_DEVICE=/dev/hidraw0 $(basename "$0") /dev/nvme0n1p2

Environment:
  LUKS_DEV          LUKS device to enroll
  FIDO2_DEVICE      FIDO2 token path or 'auto' (default: auto)
  INSTALL_LIBFIDO2  auto|yes|no (default: auto)
EOF
}

auto_detect_luks() {
    local root_source candidate

    root_source="$(findmnt -no SOURCE / 2>/dev/null || true)"
    case "$root_source" in
        /dev/mapper/*)
            candidate="$(cryptsetup status "${root_source##*/}" 2>/dev/null | sed -n 's/^[[:space:]]*device:[[:space:]]*//p' | head -n1 || true)"
            if [[ -n "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
            ;;
        /dev/*)
            if sudo cryptsetup isLuks "$root_source" >/dev/null 2>&1; then
                printf '%s\n' "$root_source"
                return 0
            fi
            ;;
    esac

    mapfile -t luks_devs < <(lsblk -nrpo NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1}')
    if (( ${#luks_devs[@]} == 1 )); then
        printf '%s\n' "${luks_devs[0]}"
        return 0
    fi

    if (( ${#luks_devs[@]} > 1 )); then
        echo "Error: multiple LUKS devices found; specify one explicitly:" >&2
        printf '  %s\n' "${luks_devs[@]}" >&2
        return 1
    fi

    echo "Error: no LUKS device found." >&2
    return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

for cmd in sudo cryptsetup systemd-cryptenroll lsblk findmnt sed; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

if [[ -z "$LUKS_DEV" ]]; then
    LUKS_DEV="$(auto_detect_luks)"
fi

if ! sudo cryptsetup isLuks "$LUKS_DEV" >/dev/null 2>&1; then
    echo "Error: device does not appear to be a LUKS volume: $LUKS_DEV" >&2
    exit 1
fi

if [[ "$INSTALL_LIBFIDO2" == "yes" ]]; then
    if command -v pacman >/dev/null 2>&1; then
        echo "Installing libfido2..."
        sudo pacman -S --needed --noconfirm libfido2
    elif [[ -e /etc/NIXOS ]]; then
        echo "Install libfido2 declaratively with NixOS, then rerun this script." >&2
        exit 1
    else
        echo "Automatic libfido2 installation is only supported on Arch Linux." >&2
        exit 1
    fi
elif [[ "$INSTALL_LIBFIDO2" == "auto" ]] && command -v pacman >/dev/null 2>&1; then
    echo "Installing libfido2..."
    sudo pacman -S --needed --noconfirm libfido2
fi

echo "Detected encrypted device: $LUKS_DEV"
echo "Enrolling YubiKey via FIDO2..."
echo "Touch your YubiKey when prompted."
sudo systemd-cryptenroll --fido2-device="$FIDO2_DEVICE" "$LUKS_DEV"

echo
echo "Done. Verify your crypttab or initramfs setup if this device is unlocked during boot."
