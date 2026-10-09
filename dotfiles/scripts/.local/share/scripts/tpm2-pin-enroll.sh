#!/usr/bin/env bash
set -euo pipefail

PCRS="${TPM2_PCRS:-0+7}"

usage() {
    echo "Usage: $0 [--no-test]"
    echo "  TPM2_PCRS=0+7 $0      PCRs waehlen (Standard: 0+7)"
    echo "  LUKS_PASSPHRASE=...   Passwort nicht interaktiv abfragen"
    echo "  --no-test             Entsperr-Test ueberspringen"
    echo "Richtet TPM2-Unlock MIT TPM-PIN ein (Mittelweg)."
    exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; fi

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

[[ -e /dev/tpmrm0 ]] || { echo "FEHLER: Kein TPM verfuegbar (/dev/tpmrm0)." >&2; exit 1; }

LUKS_DEV=""
map=$(findmnt -nr -o SOURCE / 2>/dev/null || true)
map=${map%%\[*} || true
case "$map" in
    /dev/mapper/*)
        LUKS_DEV=$(cryptsetup status "${map##*/}" 2>/dev/null | sed -n 's/^[[:space:]]*device:[[:space:]]*//p' || true)
        ;;
esac
if [[ -z "$LUKS_DEV" ]]; then
    LUKS_DEV=$(lsblk -nrpo NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1; exit}' || true)
fi
[[ -z "$LUKS_DEV" ]] && { echo "FEHLER: Kein LUKS-Geraet gefunden." >&2; exit 1; }
echo "==> LUKS-Geraet: $LUKS_DEV"

if cryptsetup luksDump "$LUKS_DEV" 2>/dev/null | grep -q 'systemd-tpm2\|systemd-fido2'; then
    echo "Es existiert bereits ein TPM2-/FIDO2-Token. Enroll uebersprungen."
    exit 0
fi

args=(--tpm2-device=auto --tpm2-pcrs="$PCRS" --tpm2-with-pin)

tmp=""
if [[ -n "${LUKS_PASSPHRASE:-}" ]]; then
    tmp=$(mktemp /run/tpm2-pin-enroll.XXXXXX)
    chmod 600 "$tmp"
    printf '%s\n' "$LUKS_PASSPHRASE" > "$tmp"
    trap 'rm -f "$tmp"' EXIT
    args+=(--passphrase-file="$tmp")
fi

echo "==> Enrolle TPM2 mit PIN (PCRs: $PCRS) ..."
echo "    Die PIN wird beim Booten abgefragt."
systemd-cryptenroll "$LUKS_DEV" "${args[@]}"

if ! cryptsetup luksDump "$LUKS_DEV" 2>/dev/null | grep -q 'systemd-tpm2'; then
    echo "FEHLER: Token wurde nicht angelegt." >&2
    exit 1
fi

if [[ "${1:-}" != "--no-test" ]]; then
    echo "==> Test: Entsperren per TPM2+PIN (PIN eingeben) ..."
    if cryptsetup open --token-only --token-type systemd-tpm2 "$LUKS_DEV" tpm2pin-test; then
        cryptsetup close tpm2pin-test
        echo "==> TPM2+PIN-Test OK."
    else
        echo "WARNUNG: Test fehlgeschlagen. Passwort-Keyslot bleibt als Fallback."
    fi
fi

echo
echo "Fertig. Hinweise:"
echo "  * Passwort-Keyslot bleibt als Fallback erhalten (nicht loeschen!)."
echo "  * Beim Boot wird die TPM-PIN abgefragt."
echo "  * Die PIN ist an dieses TPM gebunden (kein Ersatz fuer das Disk-Passwort)."
echo "  * systemd-tpm2-setup*.service NICHT maskieren."
echo "  * Nach BIOS-/Firmware-Update aendert sich PCR 0 -> Token neu enrollen."
