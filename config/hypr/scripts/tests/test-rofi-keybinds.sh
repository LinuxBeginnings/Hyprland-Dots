#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Every rofi `-kb-*` value is parsed by libnkutils, which knows only the
#   modifiers shift, control, alt, super and hyper.
#
#   A name outside that list is not a harmless unknown. The parser reads it as
#   a second key and aborts with "cannot have two non-modifiers", so rofi shows
#   its startup error dialog instead of the menu. That is how `ClipManager.sh`
#   lost its wipe key: `Alt-Meta-Delete` named Meta, which libxkbcommon 1.8+
#   reports alongside Alt but rofi cannot spell (rofi issue #2095).
#
#   libnkutils separates modifiers with '+' or '-', but rejects both in one
#   binding ("you cannot mix syntaxes"), so that is rejected here as well.
# No `set -e`: the assertion helpers return non-zero on failure.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

readonly ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
# `release` is not a modifier but is legal in modifier position.
readonly MODIFIERS=' shift control alt super hyper release '
# -kb-custom-2 "Alt+Delete,Control+Shift+Delete" and the like.
readonly BINDING_RE='-kb-[a-z0-9-]+[[:space:]]+"[^"]*"'

# The scripts holding bindings. In a checkout that is every tracked script and
# theme; from an installed copy there is no git. Test files are skipped: they
# quote bindings in assertions, which are prose rather than keybindings.
list_files() {
  if [ -f "$ROOT/copy.sh" ] &&
    command -v git >/dev/null 2>&1 &&
    git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" ls-files '*.sh' '*.rasi' | sed "s|^|$ROOT/|" | grep -v '/tests/'
    return 0
  fi
  find "$ROOT/config" -type f \( -name '*.sh' -o -name '*.rasi' \) | grep -v '/tests/'
}

# check_value <binding list> - one line per problem found in the value.
check_value() {
  local value=$1 binding sep tok
  local -a combos tokens
  IFS=',' read -ra combos <<<"$value"
  for binding in "${combos[@]}"; do
    if [[ $binding == *+* && $binding == *-* ]]; then
      printf 'mixes + and - in "%s"\n' "$binding"
      continue
    fi
    if [[ $binding == *+* ]]; then
      sep='+'
    elif [[ $binding == *-* ]]; then
      sep='-'
    else
      continue # a bare keysym has no modifier to check
    fi
    tokens=()
    IFS="$sep" read -ra tokens <<<"$binding"
    if (( ${#tokens[@]} < 2 )); then
      printf 'empty modifier in "%s"\n' "$binding"
      continue
    fi
    local i last=$(( ${#tokens[@]} - 1 ))
    for (( i = 0; i < last; i++ )); do
      tok="${tokens[i],,}"
      if [[ $MODIFIERS != *" $tok "* ]]; then
        printf 'unknown modifier "%s" in "%s"\n' "${tokens[i]}" "$binding"
      fi
    done
    if [[ -z ${tokens[last]} ]]; then
      printf 'empty key in "%s"\n' "$binding"
    fi
  done
}

# scan_file <file> - file:line: problem for every bad binding in the file.
scan_file() {
  local file=$1 hit line match value problem
  while IFS= read -r hit; do
    line="${hit%%:*}"
    match="${hit#*:}"
    value="${match#*\"}"
    value="${value%\"}"
    while IFS= read -r problem; do
      printf '%s:%s: %s\n' "$file" "$line" "$problem"
    done < <(check_value "$value")
  done < <(grep -noE -- "$BINDING_RE" "$file" 2>/dev/null)
}

scan_root() {
  local root=$1 file found
  while IFS= read -r file; do
    found="$(scan_file "$file")"
    [ -n "$found" ] && printf '%s\n' "$found"
  done < <(find "$root" -type f \( -name '*.sh' -o -name '*.rasi' \) 2>/dev/null)
}

# A scan that matches nothing would pass every rule below for the wrong reason.
it "the scan finds the rofi bindings in the tree"
bindings=0
while IFS= read -r file; do
  n="$(grep -coE -- "$BINDING_RE" "$file" 2>/dev/null || true)"
  bindings=$(( bindings + ${n:-0} ))
done < <(list_files)
if (( bindings >= 5 )); then
  pass_msg
else
  fail "only $bindings bindings found; the scan is not looking at the tree"
fi

# The checker itself: Meta and a mixed separator must be reported, the two
# valid forms must not. Split literals keep this file out of its own scan.
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/s"
printf 'rofi -dmenu %s "Alt+Delete,Control+Shift+Delete"\n' '-kb-custom-2' >"$WORK/s/ok.sh"
printf 'rofi -dmenu %s "Alt-a"\n' '-kb-custom-1' >"$WORK/s/dash.sh"
printf 'rofi -dmenu %s "Alt+Meta+Delete"\n' '-kb-custom-2' >"$WORK/s/meta.sh"
printf 'rofi -dmenu %s "Control+Shift-Delete"\n' '-kb-custom-1' >"$WORK/s/mixed.sh"

it "the checker rejects Meta and mixed separators, and accepts valid forms"
out="$(scan_root "$WORK/s")"
if assert_contains "$out" 'meta.sh' 'Meta must be reported' &&
  assert_contains "$out" 'mixed.sh' 'mixing separators must be reported' &&
  assert_not_contains "$out" 'ok.sh' 'Alt+Delete,Control+Shift+Delete is valid' &&
  assert_not_contains "$out" 'dash.sh' 'the dash form alone is valid'; then
  pass_msg
fi

it "every rofi keybinding names only modifiers libnkutils knows"
out=""
while IFS= read -r file; do
  found="$(scan_file "$file")"
  [ -n "$found" ] && out+="$found"$'\n'
done < <(list_files)
if [ -z "$out" ]; then
  pass_msg
else
  fail "rofi cannot parse these bindings:"$'\n'"$out"
fi

summary "test-rofi-keybinds"
