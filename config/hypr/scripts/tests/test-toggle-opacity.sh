#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Verifies ToggleOpacity.sh opacity cycle logic:
#   - 100% on first toggle
#   - 5% decrement per subsequent toggle down to 5%
#   - Wraps back to 100% and repeats cycle
#   - Stepping up/down (--inc / --dec) respecting bounds [0.05, 1.00]

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

readonly SCRIPT="$SCRIPT_DIR/ToggleOpacity.sh"

setup_mock_env() {
  TEST_TMP="$(mktemp -d)"
  MOCK_BIN="$TEST_TMP/bin"
  mkdir -p "$MOCK_BIN"

  export CALL_LOG="$TEST_TMP/calls.log"
  : > "$CALL_LOG"

  export MOCK_WINDOW_JSON="$TEST_TMP/window.json"
  export MOCK_PROP_OPACITY="$TEST_TMP/prop_opacity"
  export MOCK_PROP_OPAQUE="$TEST_TMP/prop_opaque"
  export MOCK_ACTIVE_OPACITY="$TEST_TMP/active_opacity"

  cat > "$MOCK_BIN/hyprctl" <<'EOS'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >> "${CALL_LOG:-/dev/null}"

if [[ ${1:-} == "activewindow" && ${2:-} == "-j" ]]; then
  if [[ -f "${MOCK_WINDOW_JSON:-}" ]]; then
    cat "$MOCK_WINDOW_JSON"
  else
    printf '{}\n'
  fi
  exit 0
fi

if [[ ${1:-} == "getprop" && ${2:-} == "active" ]]; then
  prop="${3:-}"
  if [[ "$prop" == "opacity" ]]; then
    if [[ -f "${MOCK_PROP_OPACITY:-}" ]]; then
      cat "$MOCK_PROP_OPACITY"
    else
      echo "1.00"
    fi
    exit 0
  elif [[ "$prop" == "opaque" ]]; then
    if [[ -f "${MOCK_PROP_OPAQUE:-}" ]]; then
      cat "$MOCK_PROP_OPAQUE"
    else
      echo "false"
    fi
    exit 0
  fi
  exit 1
fi

if [[ ${1:-} == "-j" && ${2:-} == "getoption" && ${3:-} == "decoration:active_opacity" ]]; then
  val="1.0"
  if [[ -f "${MOCK_ACTIVE_OPACITY:-}" ]]; then val="$(cat "$MOCK_ACTIVE_OPACITY")"; fi
  printf '{"float": %s}\n' "$val"
  exit 0
fi

if [[ ${1:-} == "getoption" && ${2:-} == "decoration:active_opacity" ]]; then
  val="1.0"
  if [[ -f "${MOCK_ACTIVE_OPACITY:-}" ]]; then val="$(cat "$MOCK_ACTIVE_OPACITY")"; fi
  printf 'float: %s\n' "$val"
  exit 0
fi

if [[ ${1:-} == "eval" ]]; then
  lua_expr="${2:-}"
  # Emulate set_prop opacity
  if [[ "$lua_expr" =~ prop[[:space:]]*=[[[:space:]]*\'opacity\',[[:space:]]*value[[:space:]]*=[[:space:]]*\'([^\']+)\' ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}" > "$MOCK_PROP_OPACITY"
  fi
  # Emulate set_prop opaque
  if [[ "$lua_expr" =~ prop[[:space:]]*=[[[:space:]]*\'opaque\',[[:space:]]*value[[:space:]]*=[[:space:]]*\'([^\']+)\' ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}" > "$MOCK_PROP_OPAQUE"
  fi
  # Emulate window tag
  if [[ "$lua_expr" =~ tag[[:space:]]*=[[[:space:]]*\'([^\']+)\' ]]; then
    tag="${BASH_REMATCH[1]}"
    if [[ -f "${MOCK_WINDOW_JSON:-}" ]]; then
      jq --arg t "$tag" '.tags = ((.tags // []) + [$t] | unique)' "$MOCK_WINDOW_JSON" > "$MOCK_WINDOW_JSON.tmp" && mv "$MOCK_WINDOW_JSON.tmp" "$MOCK_WINDOW_JSON"
    fi
  fi
  # Emulate active_opacity
  if [[ "$lua_expr" =~ active_opacity[[:space:]]*=[[[:space:]]*([0-9.]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}" > "$MOCK_ACTIVE_OPACITY"
  fi
  printf 'ok\n'
  exit 0
fi

exit 0
EOS
  chmod +x "$MOCK_BIN/hyprctl"

  # Fake notify-send
  cat > "$MOCK_BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "${CALL_LOG:-/dev/null}"
exit 0
EOS
  chmod +x "$MOCK_BIN/notify-send"

  export PATH="$MOCK_BIN:$PATH"
  export HYPRLAND_INSTANCE_SIGNATURE="test_$$"
}

cleanup_mock_env() {
  if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP"
  fi
  rm -f "/tmp/.hypr_toggle_opacity_test_$$.lock"
}

trap cleanup_mock_env EXIT

setup_mock_env

# ---------------------------------------------------------------------------
# Test 1: Untouched window with default opacity (e.g. 0.94)
# First toggle should set 100% opacity, opaque=true, and tag opacity_toggled.
# ---------------------------------------------------------------------------
printf '{"class":"kitty","tags":["terminal"],"address":"0x1234"}\n' > "$MOCK_WINDOW_JSON"
printf '0.94\n' > "$MOCK_PROP_OPACITY"
printf 'false\n' > "$MOCK_PROP_OPAQUE"
printf '0.94\n' > "$MOCK_ACTIVE_OPACITY"

bash "$SCRIPT" --toggle

assert_eq "first toggle sets opacity to 1.00 1.00" "1.00 1.00" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "first toggle sets opaque to true" "true" "$(cat "$MOCK_PROP_OPAQUE")"
assert_eq "first toggle sets active_opacity config to 1.00" "1.00" "$(cat "$MOCK_ACTIVE_OPACITY")"
assert_contains "$MOCK_WINDOW_JSON" "opacity_toggled" "first toggle tags the window"

# ---------------------------------------------------------------------------
# Test 2: Subsequent toggle from 100% should step down 5% to 95%
# ---------------------------------------------------------------------------
bash "$SCRIPT" --toggle

assert_eq "subsequent toggle from 100% steps to 0.95" "0.95 0.95" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "subsequent toggle sets opaque to false" "false" "$(cat "$MOCK_PROP_OPAQUE")"
assert_eq "subsequent toggle sets active_opacity config to 0.95" "0.95" "$(cat "$MOCK_ACTIVE_OPACITY")"

# ---------------------------------------------------------------------------
# Test 3: Subsequent toggle from 95% should step down to 90%
# ---------------------------------------------------------------------------
bash "$SCRIPT" --toggle

assert_eq "subsequent toggle from 95% steps to 0.90" "0.90 0.90" "$(cat "$MOCK_PROP_OPACITY")"

# ---------------------------------------------------------------------------
# Test 4: Full cycle down to 5% (0.05)
# ---------------------------------------------------------------------------
# Currently at 0.90. Step down remaining steps to 0.05:
# 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5
for expected in 0.85 0.80 0.75 0.70 0.65 0.60 0.55 0.50 0.45 0.40 0.35 0.30 0.25 0.20 0.15 0.10 0.05; do
  bash "$SCRIPT" --toggle
  assert_eq "cycle steps down to $expected" "$expected $expected" "$(cat "$MOCK_PROP_OPACITY")"
done

# ---------------------------------------------------------------------------
# Test 5: From 5%, toggle wraps back to 100% (1.00, opaque true)
# ---------------------------------------------------------------------------
bash "$SCRIPT" --toggle

assert_eq "toggle wraps from 5% back to 100%" "1.00 1.00" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "wrap to 100% sets opaque to true" "true" "$(cat "$MOCK_PROP_OPAQUE")"

# ---------------------------------------------------------------------------
# Test 6: From wrapped 100%, next toggle steps down to 95%
# ---------------------------------------------------------------------------
bash "$SCRIPT" --toggle

assert_eq "repeat cycle steps from wrapped 100% to 95%" "0.95 0.95" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "repeat cycle sets opaque to false" "false" "$(cat "$MOCK_PROP_OPAQUE")"

# ---------------------------------------------------------------------------
# Test 7: Untouched window with 1.00 active_opacity but opaque=false (e.g. Chrome)
# First toggle should set 100% (opaque true).
# ---------------------------------------------------------------------------
printf '{"class":"google-chrome","tags":["browser*"],"address":"0x5678"}\n' > "$MOCK_WINDOW_JSON"
printf '1.00\n' > "$MOCK_PROP_OPACITY"
printf 'false\n' > "$MOCK_PROP_OPAQUE"
printf '1.0\n' > "$MOCK_ACTIVE_OPACITY"

bash "$SCRIPT" --toggle

assert_eq "untouched chrome first toggle sets 1.00" "1.00 1.00" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "untouched chrome first toggle sets opaque true" "true" "$(cat "$MOCK_PROP_OPAQUE")"

bash "$SCRIPT" --toggle
assert_eq "subsequent toggle on chrome steps to 0.95" "0.95 0.95" "$(cat "$MOCK_PROP_OPACITY")"

# ---------------------------------------------------------------------------
# Test 8: --dec can step down to 0.05
# ---------------------------------------------------------------------------
printf '0.10\n' > "$MOCK_PROP_OPACITY"
printf 'false\n' > "$MOCK_PROP_OPAQUE"
printf '0.10\n' > "$MOCK_ACTIVE_OPACITY"

bash "$SCRIPT" --dec
assert_eq "--dec from 0.10 reaches 0.05" "0.05 0.05" "$(cat "$MOCK_PROP_OPACITY")"

bash "$SCRIPT" --dec
assert_eq "--dec is clamped at MIN_OPACITY 0.05" "0.05 0.05" "$(cat "$MOCK_PROP_OPACITY")"

# ---------------------------------------------------------------------------
# Test 9: --inc can step up to 1.00
# ---------------------------------------------------------------------------
printf '0.95\n' > "$MOCK_PROP_OPACITY"
printf 'false\n' > "$MOCK_PROP_OPAQUE"
printf '0.95\n' > "$MOCK_ACTIVE_OPACITY"

bash "$SCRIPT" --inc
assert_eq "--inc from 0.95 reaches 1.00" "1.00 1.00" "$(cat "$MOCK_PROP_OPACITY")"
assert_eq "--inc reaching 1.00 sets opaque true" "true" "$(cat "$MOCK_PROP_OPAQUE")"

summary "test-toggle-opacity"
