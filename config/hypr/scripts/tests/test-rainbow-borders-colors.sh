#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Pins the palette parser in UserScripts/RainbowBorders.bak.sh to the format
#   wallust actually writes.
#
#   Wallust emits `rgb(RRGGBB)` - six hex digits, no commas - which is the form
#   lua/user_decorations_helper.lua parses. The script's awk only knew `0x...`,
#   `#RRGGBB` and `rgb(r,g,b)`, so it matched nothing, left WALLUST_COLORS
#   empty, and took the "no colours" branch that silently switches EFFECT_TYPE
#   to `rainbow`. Wallust Color and Gradient Flow therefore rendered exactly
#   what Original Rainbow renders, with no error anywhere.
#
#   The script is driven with a fake hyprctl that records the Lua expression it
#   is asked to evaluate and answers exactly `ok` - the only reply the script
#   accepts as an applied write. No compositor is involved.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../../UserScripts/RainbowBorders.bak.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
CONF="$CFG/hypr/wallust/wallust-hyprland.conf"
EVAL_LOG="$WORK/eval.log"
export EVAL_LOG

mkdir -p "$CFG/hypr/wallust" "$BIN"

# The script evaluates one hl.config() expression per run and treats only `ok`
# as success, so the fake has to answer that for `eval` and nothing else.
cat >"$BIN/hyprctl" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$EVAL_LOG"
if [[ ${1:-} == "eval" ]]; then printf 'ok\n'; exit 0; fi
exit 0
EOS
chmod +x "$BIN"/*

# Colour 0..15 is written as rgb(00000N), so every expected value is
# 0xff00000N and a stray palette entry is easy to spot in the expression.
write_conf() {
  local format=$1 i n line
  : >"$CONF"
  for i in $(seq 0 15); do
    n="$(printf '%x' "$i")"
    case "$format" in
    rgb_hex) line="\$color$i = rgb(00000$n)" ;;
    rgb_csv) line="\$color$i = rgb(0, 0, $i)" ;;
    hash) line="\$color$i = #00000$n" ;;
    esac
    printf '%s\n' "$line" >>"$CONF"
  done
}

# run_effect <wallust_random|gradient_flow|rainbow> - one run of the script.
# The effect is written into a copy so the repo file is never edited.
run_effect() {
  : >"$EVAL_LOG"
  cp "$SCRIPT" "$WORK/rb.sh"
  sed -i "s/^EFFECT_TYPE=.*/EFFECT_TYPE=\"$1\"/" "$WORK/rb.sh"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" \
    timeout 30 bash "$WORK/rb.sh" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the format wallust actually writes ------------------------------------
it "gradient_flow reads the rgb(RRGGBB) palette"
write_conf rgb_hex
run_effect gradient_flow
assert_contains "$EVAL_LOG" '0xff00000f' "the glow colour (color15) came from the palette"
assert_contains "$EVAL_LOG" '0xff00000a' "the base colour (color10) came from the palette"
assert_not_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was not used"

it "wallust_random reads the rgb(RRGGBB) palette"
write_conf rgb_hex
run_effect wallust_random
assert_contains "$EVAL_LOG" '0xff0000' "the colours came from the palette"
assert_not_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was not used"

# --- the other formats the parser claims to accept -------------------------
it "gradient_flow still reads a comma-separated rgb() palette"
write_conf rgb_csv
run_effect gradient_flow
assert_contains "$EVAL_LOG" '0xff00000f' "the glow colour came from the palette"
assert_not_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was not used"

it "gradient_flow still reads a #RRGGBB palette"
write_conf hash
run_effect gradient_flow
assert_contains "$EVAL_LOG" '0xff00000f' "the glow colour came from the palette"
assert_not_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was not used"

# --- rainbow is untouched by any of this -----------------------------------
it "rainbow still writes the fixed palette"
write_conf rgb_hex
run_effect rainbow
assert_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was used"

# --- an unreadable palette still degrades instead of writing nothing -------
it "an unreadable palette falls back to the rainbow"
: >"$CONF"
run_effect gradient_flow
assert_contains "$EVAL_LOG" '0xffff0000' "the rainbow palette was used"

summary "test-rainbow-borders-colors"
