#!/usr/bin/env bash
set -euo pipefail

PCRS="${TPM2_PCRS:-0+7}"
FIDO2_DEVICE="${FIDO2_DEVICE:-auto}"
REBUILD="${REBUILD:-ask}"

usage() {
    echo "Usage: $0 [--no-test] [--rebuild]"
    echo "  TPM2_PCRS=0+7 $0      PCRs waehlen (Standard: 0+7)"
    echo "  FIDO2_DEVICE=...      Yubikey-Pfad/Seriennummer statt auto"
    echo "  LUKS_PASSPHRASE=...   Passwort nicht interaktiv abfragen"
    echo "  --no-test             Entsperr-Test ueberspringen"
    echo "  --rebuild             Initramfs ohne Rueckfrage neu bauen"
    echo "Richtet FIDO2-Yubikey + TPM2 (kombiniert) ein (staerkster Schutz)."
    exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; fi

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

[[ -e /dev/tpmrm0 ]] || { echo "FEHLER: Kein TPM verfuegbar (/dev/tpmrm0)." >&2; exit 1; }
[[ -e /usr/lib/cryptsetup/libcryptsetup-token-systemd-fido2.so ]] || { echo "FEHLER: fido2-cryptsetup-Plugin fehlt (libfido2 installieren)." >&2; exit 1; }

if ! fido2-token -L 2>/dev/null | grep -q .; then
    echo "FEHLER: Kein FIDO2-Token (Yubikey) gefunden." >&2
    exit 1
fi

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

args=(--fido2-device="$FIDO2_DEVICE" --tpm2-device=auto --tpm2-pcrs="$PCRS")

tmp=""
if [[ -n "${LUKS_PASSPHRASE:-}" ]]; then
    tmp=$(mktemp /run/fido2-enroll.XXXXXX)
    chmod 600 "$tmp"
    printf '%s\n' "$LUKS_PASSPHRASE" > "$tmp"
    trap 'rm -f "$tmp"' EXIT
    args+=(--passphrase-file="$tmp")
fi

echo "==> Enrolle Yubikey + TPM2 (PCRs: $PCRS) ..."
echo "    Yubikey ggf. beruehren. Bei aktivierter UV wird deren PIN abgefragt."
systemd-cryptenroll "$LUKS_DEV" "${args[@]}"

if ! cryptsetup luksDump "$LUKS_DEV" 2>/dev/null | grep -q 'systemd-fido2'; then
    echo "FEHLER: Token wurde nicht angelegt." >&2
    exit 1
fi

echo "==> Pruefe Initramfs auf fido2-Unterstuetzung ..."
need_rebuild=0
for img in /boot/initramfs-*.img; do
    [[ -e "$img" ]] || continue
    if ! lsinitcpio "$img" 2>/dev/null | grep -q 'cryptsetup-token-systemd-fido2'; then
        echo "    $img: fido2-Plugin fehlt."
        need_rebuild=1
    fi
done
if [[ $need_rebuild -eq 1 ]]; then
    if [[ "$REBUILD" == "ask" ]]; then
        read -r -p "Initramfs neu bauen (mkinitcpio -P)? [y/N] " ans
        [[ "${ans,,}" == "y" ]] && REBUILD=yes
    fi
    if [[ "$REBUILD" == "yes" ]]; then
        mkinitcpio -P
    else
        echo "WARNUNG: Bitte spaeter 'sudo mkinitcpio -P' ausfuehren, sonst schlaegt der Unlock im Initrd fehl."
    fi
fi

if [[ "${1:-}" != "--no-test" ]]; then
    echo "==> Test: Entsperren per Yubikey+TPM2 (Touch/PIN) ..."
    if cryptsetup open --token-only --token-type systemd-fido2 "$LUKS_DEV" fido2-test; then
        cryptsetup close fido2-test
        echo "==> FIDO2+TPM2-Test OK."
    else
        echo "WARNUNG: Test fehlgeschlagen. Passwort-Keyslot bleibt als Fallback."
    fi
fi

echo
echo "Fertig. Hinweise:"
echo "  * Beim Boot ist die Yubikey noetig (Touch, ggf. FIDO2-PIN bei UV)."
echo "  * Passwort-Keyslot bleibt als Fallback erhalten (nicht loeschen!)."
echo "  * Zweite Yubikey zusaetzlich enrollen: systemd-cryptenroll $LUKS_DEV --fido2-device=... --tpm2-device=auto"
echo "  * systemd-tpm2-setup*.service NICHT maskieren."
echo "  * Nach BIOS-/Firmware-Update aendert sich PCR 0 -> neu enrollen."
