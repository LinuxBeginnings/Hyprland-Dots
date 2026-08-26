#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# RainbowBorders-low-cpu.sh — low-overhead animated rainbow border for Hyprland
#
# Goal
#   Animate Hyprland's active border with a rotating rainbow gradient while
#   minimizing CPU usage on older systems by:
#     - Using a modest update rate (default 1.0s) and larger angle steps
#     - Avoiding subshell-heavy work inside the loop
#     - Using Hyprland's command socket via socat when available
#     - Quoting/validating inputs and suppressing noisy output
#     - Preventing multiple concurrent instances
#     - Optionally restoring the previous border value on exit
#
# Credits
#   Initial source/idea by: DemiGoD
#   Adaptation and optimization for low-CPU usage by: Hyprland-Dots maintainers
#
# Usage
#   You can customize behavior via environment variables when launching:
#     RB_INTERVAL    Float seconds between updates (default: 1.0)
#     RB_STEP_DEG    Integer degrees per tick        (default: 10)
#     RB_START_DEG   Integer starting angle          (default: 0)
#     RB_TARGET      Hypr option to update           (default: general:col.active_border)
#     RB_COLORS      Space-separated color list      (default: 10-color rainbow below)
#     RB_RESTORE     If "1", attempt to restore previous value on exit (loop mode; default: 1)
#     RB_LOCKFILE    Path to a PID lock file         (loop mode; default: /tmp/hypr-rainbowborders.lock)
#     RB_TRANSPORT   auto|socat|hyprctl              (default: auto)
#                      - socat: send each command via Hyprland's command socket
#                        using socat (one short-lived connection per tick)
#                      - hyprctl: spawn hyprctl each tick
#                      - auto: prefer socat if possible, otherwise hyprctl
#     RB_ONCE        1 to apply once and exit (no animation; default: 0)
#
#   Example (slower animation):
#     RB_INTERVAL=1.5 RB_STEP_DEG=12 ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/RainbowBorders-low-cpu.sh &
#
# Notes
#   - This focuses on the active border only. Animating inactive borders too
#     will increase updates and CPU usage.
#   - Higher RB_INTERVAL (e.g., 1.0–2.0s) and larger RB_STEP_DEG (10–20)
#     reduce per-second work substantially.

set -u

# Defaults (can be overridden by env vars)
RB_INTERVAL="${RB_INTERVAL:-1.0}"
RB_STEP_DEG="${RB_STEP_DEG:-10}"
RB_START_DEG="${RB_START_DEG:-0}"
RB_TARGET="${RB_TARGET:-general:col.active_border}"
RB_COLORS_DEFAULT="0xffff0000 0xffff8000 0xffffff00 0xff80ff00 0xff00ff00 0xff00ff80 0xff00ffff 0xff0080ff 0xff0000ff 0xff8000ff"
RB_COLORS="${RB_COLORS:-$RB_COLORS_DEFAULT}"
RB_RESTORE="${RB_RESTORE:-1}"
RB_LOCKFILE="${RB_LOCKFILE:-/tmp/hypr-rainbowborders.lock}"
RB_TRANSPORT="${RB_TRANSPORT:-auto}"
RB_ONCE="${RB_ONCE:-0}"

# ---------- helpers ----------
log() { printf '[RainbowBorders-low-cpu] %s\n' "$*" >&2; }

die() { log "ERROR: $*"; exit 1; }

usage() {
  cat <<'EOF'
Usage: RainbowBorders-low-cpu.sh [options]

Options:
  -h, --help     Show this help and exit
  --once, --run-once, -1
                 Apply the current gradient once and exit (no animation).
                 In this mode, RB_RESTORE is ignored (the color persists).

Environment overrides:
  RB_INTERVAL    Seconds between updates (default: 1.0)
  RB_STEP_DEG    Degrees per tick (default: 10)
  RB_START_DEG   Starting angle (default: 0)
  RB_TARGET      Hypr option to update (default: general:col.active_border)
  RB_COLORS      Space-separated colors (default: 10-color rainbow)
  RB_RESTORE     1 to restore previous value on exit (loop mode only; default: 1)
  RB_LOCKFILE    PID lock path (loop mode only; default: /tmp/hypr-rainbowborders.lock)
  RB_TRANSPORT   auto|socat|hyprctl (default: auto)
  RB_ONCE        1 for one-shot mode (same as --once)

Examples:
  Animate (light CPU):
    RB_INTERVAL=1.5 RB_STEP_DEG=12 ./RainbowBorders-low-cpu.sh &

  Set a static rainbow once (no animation):
    ./RainbowBorders-low-cpu.sh --once
EOF
}

is_float() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$|^\.[0-9]+$ ]]; }

is_int()   { [[ "$1" =~ ^[0-9]+$ ]]; }

# ---------- parse CLI flags ----------
while (( $# )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --once|--run-once|-1) RB_ONCE=1 ;;
    *) log "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

# ---------- validation ----------
if ! is_float "$RB_INTERVAL"; then
  log "WARN: RB_INTERVAL='$RB_INTERVAL' invalid; defaulting to 1.0"
  RB_INTERVAL="1.0"
fi
if ! is_int "$RB_STEP_DEG"; then
  log "WARN: RB_STEP_DEG='$RB_STEP_DEG' invalid; defaulting to 10"
  RB_STEP_DEG="10"
fi
if ! is_int "$RB_START_DEG"; then
  log "WARN: RB_START_DEG='$RB_START_DEG' invalid; defaulting to 0"
  RB_START_DEG="0"
fi

# ---------- single-instance lock (PID file) ----------
cleanup_lock() { [[ -f "$RB_LOCKFILE" ]] && rm -f "$RB_LOCKFILE"; }

if [[ "$RB_ONCE" != "1" ]]; then
  if [[ -f "$RB_LOCKFILE" ]]; then
    oldpid="$(cat "$RB_LOCKFILE" 2>/dev/null || true)"
    if [[ -n "${oldpid:-}" ]] && kill -0 "$oldpid" 2>/dev/null; then
      log "Another instance is running (pid=$oldpid). Exiting."
      exit 0
    else
      # Stale lock
      rm -f "$RB_LOCKFILE" || true
    fi
  fi
  printf '%d' "$$" >"$RB_LOCKFILE" 2>/dev/null || die "Cannot write lockfile $RB_LOCKFILE"
fi

# ---------- transport (socat vs hyprctl) ----------
RB_MODE=""
RB_SOCK=""

open_transport() {
  local want="$RB_TRANSPORT"
  local uid; uid=$(id -u 2>/dev/null || echo 0)
  local base="${XDG_RUNTIME_DIR:-/run/user/$uid}"
  local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  if [[ -n "$sig" ]]; then
    RB_SOCK="$base/hypr/$sig/.socket.sock"
  fi

  # Prefer socat if requested/allowed and socket is available
  if [[ "$want" == "socat" || "$want" == "auto" ]]; then
    if command -v socat >/dev/null 2>&1 && [[ -n "$RB_SOCK" && -S "$RB_SOCK" ]]; then
      RB_MODE="socat"
      return 0
    elif [[ "$want" == "socat" ]]; then
      die "RB_TRANSPORT=socat requested but 'socat' or Hyprland socket is unavailable"
    fi
  fi

  # Fallback to hyprctl: require presence and connectivity
  command -v hyprctl >/dev/null 2>&1 || die "hyprctl not found and socat transport unavailable"
  if ! hyprctl monitors >/dev/null 2>&1; then
    die "hyprctl cannot reach a running Hyprland instance"
  fi
  RB_MODE="hyprctl"
  return 0
}

open_transport || exit 1
log "Using transport: $RB_MODE"

# ---------- optional restore of previous border value ----------
PREV_VALUE=""
if [[ "$RB_RESTORE" == "1" && "$RB_ONCE" != "1" ]]; then
  if command -v hyprctl >/dev/null 2>&1; then
    # hyprctl getoption <opt> prints various formats; try common keys
    PREV_VALUE="$(hyprctl getoption "$RB_TARGET" 2>/dev/null \
                    | sed -n 's/^.*str:[[:space:]]\+//p; s/^.*string:[[:space:]]\+//p; s/^.*value:[[:space:]]\+//p' \
                    | tail -n1)"
  fi
fi

# Apply a border color value under conf or Lua Hyprland modes.
# Cache parser mode (keyword vs eval) to avoid double-process overhead per tick on Lua configs.
HYPR_DISPATCH_MODE=""

apply_border_value() {
  local option="$1"
  local value="$2"
  local out angle colors_str c lua_colors expr rc
  local -a colors=()

  # Fast path: if parser mode is already known to be keyword (legacy)
  if [[ "$HYPR_DISPATCH_MODE" == "keyword" ]]; then
    if out="$(hyprctl keyword "$option" $value 2>&1)"; then
      return 0
    fi
    HYPR_DISPATCH_MODE=""
  fi

  # Fast path: if parser mode is already known to be Lua eval
  if [[ "$HYPR_DISPATCH_MODE" == "eval" ]]; then
    angle="0"
    for c in $value; do
      if [[ "$c" =~ ^([0-9]+)deg$ ]]; then
        angle="${BASH_REMATCH[1]}"
      else
        colors+=("$c")
      fi
    done
    ((${#colors[@]} > 0)) || return 1

    lua_colors=""
    for c in "${colors[@]}"; do
      [[ -n "$lua_colors" ]] && lua_colors+=", "
      lua_colors+="\"${c}\""
    done

    case "$option" in
    general:col.active_border)
      expr="hl.config({ general = { col = { active_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
      ;;
    general:col.inactive_border)
      expr="hl.config({ general = { col = { inactive_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
      ;;
    *)
      return 1
      ;;
    esac

    if hyprctl eval "$expr" >/dev/null 2>&1; then
      return 0
    fi
    HYPR_DISPATCH_MODE=""
  fi

  # Auto-detection pass (runs on first tick or after fallback)
  out="$(hyprctl keyword "$option" $value 2>&1)"
  rc=$?
  if [[ $rc -eq 0 && "$out" != *"non-legacy parsers"* && "$out" != *"Use eval"* && "$out" != *"error"* && "$out" != *"invalid"* ]]; then
    HYPR_DISPATCH_MODE="keyword"
    return 0
  fi

  # Parse "c1 c2 ... Ndeg" or bare colors into Lua gradient table.
  angle="0"
  for c in $value; do
    if [[ "$c" =~ ^([0-9]+)deg$ ]]; then
      angle="${BASH_REMATCH[1]}"
    else
      colors+=("$c")
    fi
  done
  ((${#colors[@]} > 0)) || {
    log "WARN: cannot parse border value for Lua fallback: $value (keyword: $out)"
    return 1
  }

  lua_colors=""
  for c in "${colors[@]}"; do
    [[ -n "$lua_colors" ]] && lua_colors+=", "
    lua_colors+="\"${c}\""
  done

  case "$option" in
  general:col.active_border)
    expr="hl.config({ general = { col = { active_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
    ;;
  general:col.inactive_border)
    expr="hl.config({ general = { col = { inactive_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
    ;;
  *)
    log "WARN: unsupported option for Lua fallback: $option (keyword: $out)"
    return 1
    ;;
  esac

  if out="$(hyprctl eval "$expr" 2>&1)"; then
    HYPR_DISPATCH_MODE="eval"
    return 0
  fi
  log "WARN: failed to apply border via eval: $out"
  return 1
}

restore_previous() {
  if [[ "$RB_RESTORE" == "1" && -n "${PREV_VALUE:-}" ]]; then
    apply_border_value "$RB_TARGET" "$PREV_VALUE" >/dev/null 2>&1 || true
  fi
}

on_exit() {
  restore_previous
  cleanup_lock
}

# In loop mode, set traps for cleanup/restore
if [[ "$RB_ONCE" != "1" ]]; then
  trap on_exit INT TERM EXIT
fi

# ---------- main logic ----------
angle=$(( RB_START_DEG % 360 ))
STEP=$(( RB_STEP_DEG % 360 ))
(( STEP == 0 )) && STEP=10

write_border() {
  local a="$1"
  # Always go through apply_border_value so Lua config mode works.
  # (socat keyword transport is rejected under non-legacy/Lua parsers.)
  apply_border_value "$RB_TARGET" "$RB_COLORS ${a}deg" >/dev/null 2>&1 || true
}

if [[ "$RB_ONCE" == "1" ]]; then
  # Single write and exit; do not restore previous (intended to persist)
  write_border "$angle" || log "WARN: one-shot write failed"
  exit 0
fi

# Prime first write (avoid waiting one interval)
write_border "$angle" || log "WARN: initial write failed"

while :; do
  # Advance angle and write; failures are non-fatal to keep CPU use minimal
  angle=$(( (angle + STEP) % 360 ))
  write_border "$angle"
  sleep "$RB_INTERVAL"
done
