#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The originating request for this feature was that the display setup must
#   not be specific to one machine. This is the check that answers it, and the
#   one that stops a port name creeping back in during a later edit.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
S="$HERE/.."
PORT_RE='\b(eDP|LVDS|DSI|DP|HDMI-A|DVI-D|DVI-I)-[0-9]+'

for f in DisplayProfile.sh DisplayProfileMenu.sh DisplayProfileSetup.sh \
         MonitorWatcher.sh lib_display_store.sh; do
  it "no port name is hardcoded in $f"
  # Comments are stripped first: a port name in an explanatory comment is not a
  # machine-specific behaviour, and forbidding it would only hurt the docs.
  hit="$(sed 's/#.*$//' "$S/$f" | grep -nE "$PORT_RE" | head -3 || true)"
  if [[ -z $hit ]]; then pass_msg; else fail "$hit"; fi
done

it "the two-monitor vocabulary is gone from every script"
hit="$(grep -lE 'LAPTOP_OUTPUT|EXTERNAL_OUTPUT|EXTERNAL_EXPECTED|LABEL_HOME|LABEL_WORK' \
        "$S"/DisplayProfile.sh "$S"/DisplayProfileMenu.sh "$S"/DisplayProfileSetup.sh \
        "$S"/MonitorWatcher.sh "$S"/lib_display_store.sh 2>/dev/null || true)"
if [[ -z $hit ]]; then pass_msg; else fail "$hit"; fi

it "no script assumes a monitor may never be disabled"
hit="$(grep -nE 'never disable (eDP|the laptop)' "$S"/DisplayProfile.sh "$S"/MonitorWatcher.sh 2>/dev/null || true)"
if [[ -z $hit ]]; then pass_msg; else fail "$hit"; fi

# The store ships EMPTY in the repo, which is what the installer's add-only rule
# depends on. On an installed system it holds the user's own layouts, so "empty"
# is the wrong thing to assert there - only the shape is. scripts/lib_copy.sh is
# repo-side, so its presence is what says which of the two this is.
store="$S/../UserConfigs/display-layouts.json"
if [[ -f "$S/../../../scripts/lib_copy.sh" ]]; then
  it "the shipped store is an empty version 1 store"
  if jq -e '.version == 1 and (.fingerprints | length) == 0' "$store" >/dev/null 2>&1; then
    pass_msg
  else fail "$store is missing or not an empty v1 store"; fi
else
  it "the installed store is a version 1 store"
  if jq -e '.version == 1 and (.fingerprints | type) == "object"' "$store" >/dev/null 2>&1; then
    pass_msg
  else fail "$store is missing or not a v1 store"; fi
fi

it "every new script is executable"
bad=""
for f in DisplayProfile.sh DisplayProfileMenu.sh DisplayProfileSetup.sh MonitorWatcher.sh; do
  [[ -x "$S/$f" ]] || bad="$bad $f"
done
if [[ -z $bad ]]; then pass_msg; else fail "not executable:$bad"; fi

it "the library is sourced, not executed, so it needs no exec bit"
if [[ -x "$S/lib_display_store.sh" ]]; then
  fail "lib_display_store.sh should not be executable"
else pass_msg; fi

summary "test-no-hardcoded-outputs"
