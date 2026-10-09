#!/usr/bin/env bash
set -euo pipefail

PCRS="${TPM2_PCRS:-0+7}"
WITH_PIN="${TPM2_PIN:-no}"

usage() {
    echo "Usage: $0 [--no-test]"
    echo "  TPM2_PCRS=0+7 $0      PCRs waehlen (Standard: 0+7)"
    echo "  TPM2_PIN=yes $0       zusaetzlich TPM-PIN verlangen"
    echo "  LUKS_PASSPHRASE=...   Passwort nicht interaktiv abfragen"
    echo "  --no-test             TPM2-Entsperr-Test ueberspringen"
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

if cryptsetup luksDump "$LUKS_DEV" 2>/dev/null | grep -q 'systemd-tpm2'; then
    echo "TPM2-Token ist bereits eingetragen. Keine Aktion noetig."
    exit 0
fi

args=(--tpm2-device=auto --tpm2-pcrs="$PCRS")
[[ "$WITH_PIN" == "yes" ]] && args+=(--tpm2-with-pin)

tmp=""
if [[ -n "${LUKS_PASSPHRASE:-}" ]]; then
    tmp=$(mktemp /run/tpm2-enroll.XXXXXX)
    chmod 600 "$tmp"
    printf '%s\n' "$LUKS_PASSPHRASE" > "$tmp"
    trap 'rm -f "$tmp"' EXIT
    args+=(--passphrase-file="$tmp")
fi

echo "==> Enrolle TPM2 (PCRs: $PCRS) ..."
systemd-cryptenroll "$LUKS_DEV" "${args[@]}"

if ! cryptsetup luksDump "$LUKS_DEV" 2>/dev/null | grep -q 'systemd-tpm2'; then
    echo "FEHLER: Token wurde nicht angelegt." >&2
    exit 1
fi

if [[ "${1:-}" != "--no-test" ]]; then
    if cryptsetup open --token-only --token-type systemd-tpm2 "$LUKS_DEV" tpm2-test 2>/dev/null; then
        cryptsetup close tpm2-test
        echo "==> TPM2-Entsperr-Test OK."
    else
        echo "WARNUNG: Test fehlgeschlagen. Passwort-Keyslot bleibt als Fallback."
    fi
fi

echo
echo "Fertig. Hinweise:"
echo "  * Passwort-Keyslot bleibt als Fallback erhalten (nicht loeschen!)."
echo "  * systemd-tpm2-setup*.service NICHT maskieren - wird fuer den SRK gebraucht."
echo "  * Nach BIOS-/Firmware-Update aendert sich PCR 0 -> Token neu enrollen."
