#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Every script here has to run on NixOS as well as Debian.
#
#   NixOS ships no /bin/bash, so a `#!/bin/bash` shebang cannot resolve there.
#   `/usr/bin/env` is the one path it does provide, which is why the rule is
#   `#!/usr/bin/env bash`.
#
#   The same applies to an interpreter named inside a script rather than in the
#   shebang. `systemd-run` and `setsid` resolve their command against a
#   different PATH, so those have to name it absolutely as "$BASH" - which is
#   why Refresh.sh no longer passes /bin/bash to either.
#
#   A BOM is checked too: it sits before the shebang, so the kernel never sees
#   the `#!` and the script fails to execute at all.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

readonly WANT='#!/usr/bin/env bash'
readonly ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

# The scripts to check. In a checkout that is every tracked *.sh; from an
# installed copy, which has no git and no copy.sh, the scripts beside the tests.
list_scripts() {
  if [ -f "$ROOT/copy.sh" ] &&
    command -v git >/dev/null 2>&1 &&
    git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" ls-files '*.sh' | sed "s|^|$ROOT/|"
    return 0
  fi
  find "$SCRIPT_DIR" -name '*.sh' -type f
}

# offender <extended-regex> - file:line:content for every non-comment line of
# every script that matches. A comment naming /bin/bash is only prose.
offender() {
  local pat="$1" f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$f" ] || continue
    grep -nE -- "$pat" "$f" 2>/dev/null |
      grep -vE '^[0-9]+:[[:space:]]*#' |
      sed "s|^|$f:|"
  done < <(list_scripts)
}

# A scan that finds nothing would pass every rule below for the wrong reason.
it "the list of scripts to check is not empty"
count="$(list_scripts | grep -c . || true)"
if [ "${count:-0}" -ge 10 ]; then
  pass_msg
else
  fail "only ${count:-0} scripts found; the scan is not looking at the tree"
fi

it "every script starts with $WANT"
bad=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  [ "$(head -n1 "$f" 2>/dev/null)" = "$WANT" ] || bad="$bad $f"
done < <(list_scripts)
if [ -n "$bad" ]; then
  fail "wrong shebang:$bad"
else
  pass_msg
fi

it "no script names a shell by absolute path"
out="$(offender '(/bin|/usr/bin)/(ba|z|da|k)?sh([^[:alnum:]_]|$)' | head -20)"
if [ -z "$out" ]; then
  pass_msg
else
  fail "absolute shell path, use \"\$BASH\" instead:"$'\n'"$out"
fi

it "no script starts with a UTF-8 BOM"
bad=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  if head -c3 "$f" 2>/dev/null | od -An -tx1 | grep -q 'ef bb bf'; then
    bad="$bad $f"
  fi
done < <(list_scripts)
if [ -n "$bad" ]; then
  fail "a BOM would hide the shebang:$bad"
else
  pass_msg
fi

summary "test-shebangs"
