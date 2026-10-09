#!/usr/bin/env bash

# Usage examples:
#   ./setup-battery-threshold.sh 70 80
#   ./setup-battery-threshold.sh reset
#
set -euo pipefail

BATTERY_PATH="${BATTERY_PATH:-/sys/class/power_supply/BAT0}"
SERVICE_NAME="battery-charge-threshold.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
RESTORE_START_THRESHOLD=96
RESTORE_END_THRESHOLD=100
DISABLE_START_THRESHOLD=0
DISABLE_END_THRESHOLD=100
MODE="set"
START_THRESHOLD="${1:-70}"
END_THRESHOLD="${2:-80}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [START] [END]
       $(basename "$0") restore|reset
       $(basename "$0") disable|off

Examples:
  $(basename "$0")               # set 70/80
  $(basename "$0") 50 60         # set 50/60
  $(basename "$0") restore       # restore 96/100 and remove service
  $(basename "$0") disable       # disable thresholds (0/100), remove service, full charge

Environment variables:
  BATTERY_PATH=/sys/class/power_supply/BAT0
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

case "${1:-}" in
  restore|reset)
    if (( $# > 1 )); then
      echo "restore/reset does not take threshold arguments." >&2
      exit 1
    fi
    MODE="restore"
    START_THRESHOLD="$RESTORE_START_THRESHOLD"
    END_THRESHOLD="$RESTORE_END_THRESHOLD"
    ;;
  disable|off)
    if (( $# > 1 )); then
      echo "disable/off does not take threshold arguments." >&2
      exit 1
    fi
    MODE="disable"
    START_THRESHOLD="$DISABLE_START_THRESHOLD"
    END_THRESHOLD="$DISABLE_END_THRESHOLD"
    ;;
esac

if ! [[ "$START_THRESHOLD" =~ ^[0-9]+$ && "$END_THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "Thresholds must be integers." >&2
  exit 1
fi

if (( START_THRESHOLD < 0 || START_THRESHOLD > 100 || END_THRESHOLD < 0 || END_THRESHOLD > 100 )); then
  echo "Thresholds must be between 0 and 100." >&2
  exit 1
fi

if (( START_THRESHOLD > END_THRESHOLD )); then
  echo "START must be less than or equal to END." >&2
  exit 1
fi

if [[ ! -d "$BATTERY_PATH" ]]; then
  echo "Battery path not found: $BATTERY_PATH" >&2
  exit 1
fi

if [[ ! -e "$BATTERY_PATH/charge_control_end_threshold" ]]; then
  echo "This system does not expose battery charge threshold controls at $BATTERY_PATH." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required." >&2
  exit 1
fi

show_values() {
  for f in charge_control_start_threshold charge_control_end_threshold charge_start_threshold charge_stop_threshold charge_behaviour capacity status; do
    if [[ -e "$BATTERY_PATH/$f" ]]; then
      printf '%s=' "$f"
      cat "$BATTERY_PATH/$f"
    fi
  done
}

apply_thresholds() {
  # Drivers enforce start <= end after every write, so go through an
  # always-safe intermediate state: start=0 -> end -> start.
  if ! sudo sh -c "echo 0 > '$BATTERY_PATH/charge_control_start_threshold'" 2>/dev/null; then
    echo "Note: $BATTERY_PATH/charge_control_start_threshold not directly settable; using fallback." >&2
  fi

  if ! sudo sh -c "echo $END_THRESHOLD > '$BATTERY_PATH/charge_control_end_threshold'"; then
    return 1
  fi

  if ! sudo sh -c "echo $START_THRESHOLD > '$BATTERY_PATH/charge_control_start_threshold'" 2>/dev/null; then
    echo "Note: skipping charge_control_start_threshold (rejected by driver)." >&2
  fi

  if [[ -e "$BATTERY_PATH/charge_start_threshold" ]]; then
    sudo sh -c "echo 0 > '$BATTERY_PATH/charge_start_threshold'" 2>/dev/null || true
    sudo sh -c "echo $START_THRESHOLD > '$BATTERY_PATH/charge_start_threshold'" 2>/dev/null || true
  fi

  if [[ -e "$BATTERY_PATH/charge_stop_threshold" ]]; then
    sudo sh -c "echo $END_THRESHOLD > '$BATTERY_PATH/charge_stop_threshold'" 2>/dev/null || true
  fi
}

set_charge_behaviour_auto() {
  if [[ -e "$BATTERY_PATH/charge_behaviour" ]]; then
    sudo sh -c "echo auto > '$BATTERY_PATH/charge_behaviour'" 2>/dev/null || true
  fi
}

remove_service() {
  sudo systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true

  if [[ -e "$SERVICE_PATH" ]]; then
    sudo rm -f "$SERVICE_PATH"
  fi

  sudo systemctl daemon-reload
}

if ! apply_thresholds; then
  echo "Failed to apply thresholds to $BATTERY_PATH." >&2
  exit 1
fi

if [[ "$MODE" == "restore" || "$MODE" == "disable" ]]; then
  set_charge_behaviour_auto
  remove_service

  if [[ "$MODE" == "restore" ]]; then
    printf 'Restored thresholds to %s/%s and removed %s if present.\n' "$START_THRESHOLD" "$END_THRESHOLD" "$SERVICE_PATH"
  else
    printf 'Disabled thresholds with %s/%s, set charge behaviour to auto, and removed %s if present.\n' "$START_THRESHOLD" "$END_THRESHOLD" "$SERVICE_PATH"
  fi

  show_values
  exit 0
fi

TMP_SERVICE="$(mktemp)"
cat > "$TMP_SERVICE" <<EOF
[Unit]
Description=Set battery charge thresholds to ${START_THRESHOLD}/${END_THRESHOLD} on $(basename "$BATTERY_PATH")
ConditionPathExists=${BATTERY_PATH}/charge_control_end_threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 0 > ${BATTERY_PATH}/charge_control_start_threshold 2>/dev/null || true; echo ${END_THRESHOLD} > ${BATTERY_PATH}/charge_control_end_threshold; echo ${START_THRESHOLD} > ${BATTERY_PATH}/charge_control_start_threshold 2>/dev/null || true; [ -e ${BATTERY_PATH}/charge_start_threshold ] && { echo 0 > ${BATTERY_PATH}/charge_start_threshold 2>/dev/null || true; echo ${START_THRESHOLD} > ${BATTERY_PATH}/charge_start_threshold 2>/dev/null || true; } || true; [ -e ${BATTERY_PATH}/charge_stop_threshold ] && echo ${END_THRESHOLD} > ${BATTERY_PATH}/charge_stop_threshold 2>/dev/null || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo install -m 0644 "$TMP_SERVICE" "$SERVICE_PATH"
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"
rm -f "$TMP_SERVICE"

echo "Applied thresholds and installed service: $SERVICE_PATH"
show_values
