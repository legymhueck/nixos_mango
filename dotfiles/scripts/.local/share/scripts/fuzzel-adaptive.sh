#!/usr/bin/env bash
set -euo pipefail

# Tunables
PERCENT_OF_OUTPUT_WIDTH="${FUZZEL_WIDTH_PERCENT:-35}"
CHAR_PIXEL_WIDTH="${FUZZEL_CHAR_PX:-11}"
MIN_WIDTH_CHARS="${FUZZEL_MIN_WIDTH:-45}"
MAX_WIDTH_CHARS="${FUZZEL_MAX_WIDTH:-120}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [fuzzel-args...]

Launch fuzzel with an adaptive width based on the current output width.
Detection order: niri -> hyprctl -> swaymsg -> wlr-randr -> fallback 1920px
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

get_output_width_px() {
  if command -v niri >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local niri_json focused first
    niri_json="$(niri msg -j outputs 2>/dev/null || true)"
    if [[ -n "$niri_json" ]]; then
      focused="$(jq -r '.[] | select(.is_focused == true) | .current_mode.width // empty' <<<"$niri_json" | head -n1)"
      if [[ -n "$focused" ]]; then
        echo "$focused"
        return
      fi
      first="$(jq -r '.[] | .current_mode.width // empty' <<<"$niri_json" | head -n1)"
      if [[ -n "$first" ]]; then
        echo "$first"
        return
      fi
    fi
  fi

  if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local hypr_json hypr_width
    hypr_json="$(hyprctl -j monitors 2>/dev/null || true)"
    if [[ -n "$hypr_json" ]]; then
      hypr_width="$(jq -r '(.[] | select(.focused == true) | .width // empty), (.[] | .width // empty)' <<<"$hypr_json" | head -n1)"
      if [[ -n "$hypr_width" ]]; then
        echo "$hypr_width"
        return
      fi
    fi
  fi

  if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local sway_json sway_width
    sway_json="$(swaymsg -t get_outputs -r 2>/dev/null || true)"
    if [[ -n "$sway_json" ]]; then
      sway_width="$(jq -r '(.[] | select(.focused == true) | .current_mode.width // empty), (.[] | .current_mode.width // empty)' <<<"$sway_json" | head -n1)"
      if [[ -n "$sway_width" ]]; then
        echo "$sway_width"
        return
      fi
    fi
  fi

  if command -v wlr-randr >/dev/null 2>&1; then
    wlr-randr 2>/dev/null | awk '
      /^[^[:space:]]/ { out=$1; sub(":$", "", out) }
      /current[[:space:]]+[0-9]+x[0-9]+/ {
        if (match($0, /current[[:space:]]+([0-9]+)x([0-9]+)/, m)) {
          print m[1]
          exit
        }
      }
    '
    return
  fi

  echo 1920
}

clamp() {
  local value="$1" min="$2" max="$3"
  if (( value < min )); then
    echo "$min"
  elif (( value > max )); then
    echo "$max"
  else
    echo "$value"
  fi
}

output_width_px="$(get_output_width_px)"
target_px=$(( output_width_px * PERCENT_OF_OUTPUT_WIDTH / 100 ))
target_chars=$(( target_px / CHAR_PIXEL_WIDTH ))
target_chars="$(clamp "$target_chars" "$MIN_WIDTH_CHARS" "$MAX_WIDTH_CHARS")"

exec fuzzel --width "$target_chars" "$@"
