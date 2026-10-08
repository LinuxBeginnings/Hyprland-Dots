#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Three scripts that ship with these dots now ask DisplayProfile.sh which
#   Waybar config to run. Every one of them must still work on a machine where
#   that script does not exist, so what is tested here is the fallback
#   contract, not a full run of scripts that each do a great deal else.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

S="$HERE/.."
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/waybar" "$WORK/hypr/scripts"
printf '{}\n' >"$WORK/waybar/config"

# resolve_in <script> -> what kooldots_waybar_config prints, with
# XDG_CONFIG_HOME pointed at the sandbox so the controller it looks for is the
# fake one (or absent). The fallback directory is passed as an argument, the way
# every caller does it - the function no longer reads a variable that happens to
# be in scope.
resolve_in() {
  local script=$1 fn
  fn="$(sed -n '/^kooldots_waybar_config()/,/^}/p' -- "$S/$script")"
  [[ -n $fn ]] || { printf 'NO_FUNCTION\n'; return 0; }
  env XDG_CONFIG_HOME="$WORK" bash -c "
    set -uo pipefail
    $fn
    kooldots_waybar_config '$WORK/waybar'"
}

install_controller() {  # body
  cat >"$WORK/hypr/scripts/DisplayProfile.sh" <<EOS
#!/usr/bin/env bash
$1
EOS
  chmod +x "$WORK/hypr/scripts/DisplayProfile.sh"
}

for f in WaybarStartup.sh Refresh.sh; do
  it "$f has a kooldots_waybar_config function that uses the directory it is given"
  if sed -n '/^kooldots_waybar_config()/,/^}/p' -- "$S/$f" | grep -qE '\$fallback_dir'; then
    pass_msg
  else fail "the function is missing or does not use \$fallback_dir"; fi
done

it "every caller passes the fallback directory explicitly"
# Relying on bash's dynamic scoping to see the caller's `local waybar_dir` is
# what made the old fallback silently resolve to "/config" if it ever stopped
# being in scope.
bad=""
for f in WaybarStartup.sh Refresh.sh; do
  grep -qE 'kooldots_waybar_config "\$(WAYBAR_DIR|waybar_dir)"' "$S/$f" || bad="$bad $f"
done
if [[ -z $bad ]]; then pass_msg; else fail "a caller does not pass the directory:$bad"; fi

install_controller 'printf "%s\n" "/tmp/from-controller"'
: >"$WORK/waybar/from-controller" 2>/dev/null || true
install_controller "printf '%s\\n' '$WORK/waybar/from-controller'"
: >"$WORK/waybar/from-controller"
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f uses the path the controller prints" \
    "$WORK/waybar/from-controller" "$(resolve_in "$f")"
done

rm -f "$WORK/hypr/scripts/DisplayProfile.sh"
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f falls back when the controller is absent" \
    "$WORK/waybar/config" "$(resolve_in "$f")"
done

install_controller 'exit 1'
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f falls back when the controller fails" \
    "$WORK/waybar/config" "$(resolve_in "$f")"
done

install_controller 'printf "%s\n" "/no/such/file"'
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f falls back when the printed path does not exist" \
    "$WORK/waybar/config" "$(resolve_in "$f")"
done

install_controller 'printf "a log line\n/no/such/file\n"'
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f does not take a stray log line for a path" \
    "$WORK/waybar/config" "$(resolve_in "$f")"
done

install_controller 'printf "%s\n" ""'
for f in WaybarStartup.sh Refresh.sh; do
  assert_eq "$f falls back on empty output" \
    "$WORK/waybar/config" "$(resolve_in "$f")"
done

it "Refresh.sh no longer hardcodes the unrestricted config in its restart"
if grep -n 'restart_cmd' -A4 "$S/Refresh.sh" | grep -q -- '-c \\"\$waybar_dir/config\\"'; then
  fail "the restart still pins \$waybar_dir/config, undoing the per-layout restriction"
else pass_msg; fi

it "Refresh.sh's direct-launch branch uses the resolved path"
if grep -n 'restart_cmd' -A4 "$S/Refresh.sh" | grep -q 'kooldots_waybar_config\|waybar_cfg'; then
  pass_msg
else fail "the direct-launch branch does not use the resolved path"; fi

it "WaybarStartup.sh launches waybar with the resolved path"
if grep -nE '^\s+(\.)?waybar(-wrapped)? -c' "$S/WaybarStartup.sh" | grep -q 'WAYBAR_CONFIG_ARG'; then
  pass_msg
else fail "the launch does not use WAYBAR_CONFIG_ARG"; fi

it "WaybarStartup.sh resolves WAYBAR_CONFIG_ARG rather than pinning the plain config"
if grep -qE '^WAYBAR_CONFIG_ARG="\$WAYBAR_DIR/config"$' "$S/WaybarStartup.sh"; then
  fail "line 18 still pins the unrestricted config"
else pass_msg; fi

it "WaybarLayout.sh needs no resolver of its own: it delegates to Refresh.sh"
if sed -n '/^apply_config()/,/^}/p' "$S/WaybarLayout.sh" | grep -q 'Refresh.sh'; then
  pass_msg
else fail "apply_config no longer delegates, so it needs the resolver itself"; fi

# --- Quick Settings --------------------------------------------------------
it "Quick Settings routes nwg-displays through the pause file"
if grep -q 'kooldots-display-profiles' "$S/Kool_Quick_Settings.sh" \
   && grep -q 'pause' "$S/Kool_Quick_Settings.sh"; then pass_msg
else fail "no pause protocol around the GUI"; fi

it "Quick Settings points nwg-displays at the discard path"
assert_contains "$S/Kool_Quick_Settings.sh" 'nwg-monitors.discard.conf' \
  "the real monitors.conf is not written" && pass_msg

it "Quick Settings still tells the user to install nwg-displays when it is missing"
assert_contains "$S/Kool_Quick_Settings.sh" 'Install nwg-displays' \
  "the existing guard is preserved" && pass_msg

it "Quick Settings closes the lock descriptor on the GUI"
if grep -nE '^\s*nwg-displays ' "$S/Kool_Quick_Settings.sh" | grep -qv '9>&-'; then
  fail "the GUI launch does not close fd 9"
else pass_msg; fi

it "Quick Settings invites the user to save the arrangement"
assert_contains "$S/Kool_Quick_Settings.sh" 'Save current state' \
  "the user is told how to keep the drag" && pass_msg

it "every background spawn in WaybarStartup.sh closes the lock descriptor"
# It takes the shared Waybar lock on fd 9 and then spawns children. flock holds
# the lock until EVERY descriptor on that open file description is closed, so a
# long-running child that inherits fd 9 strands the lock and the next
# WaybarStartup.sh exits without starting a bar.
bad="$(sed 's/#.*$//' "$S/WaybarStartup.sh" | grep -nE '[^&|]& *$' | grep -v '9>&-' || true)"
if [[ -z $bad ]]; then pass_msg; else fail "spawn without 9>&-: $bad"; fi

it "the same holds for the other scripts that take a lock on fd 9"
bad=""
for f in Refresh.sh LidSwitch.sh; do
  grep -q 'exec 9>' "$S/$f" 2>/dev/null || continue
  hit="$(sed 's/#.*$//' "$S/$f" | grep -nE '[^&|]& *$' | grep -v '9>&-' || true)"
  [[ -n $hit ]] && bad="$bad $f:[$hit]"
done
if [[ -z $bad ]]; then pass_msg; else fail "$bad"; fi

# --- the installer must never overwrite a saved store ----------------------
# The repo ships an EMPTY display-layouts.json, so anything that copies the
# repo's UserConfigs over a live one destroys every saved layout. The installer
# is add-only; this check is what keeps it that way.
#
# lib_copy.sh is repo-side, so these two only mean anything in a checkout; this
# suite is also installed into ~/.config/hypr/scripts/tests.
LIB_COPY="$S/../../../scripts/lib_copy.sh"
if [[ -f $LIB_COPY ]]; then
  it "lib_copy.sh only ADDS UserConfigs files that are missing"
  blk="$(sed -n '/UserConfigs are protected/,/^      else$/p' "$LIB_COPY")"
  if printf '%s' "$blk" | grep -q 'if \[ ! -f "\$dst_file" \]'; then pass_msg
  else fail "the UserConfigs branch is no longer guarded by a not-exists test"; fi

  it "lib_copy.sh ships the layout store at all"
  assert_contains "$LIB_COPY" 'display-layouts.json' \
    "the store is included in the UserConfigs find" && pass_msg
else
  it "lib_copy.sh is not present here (repo-only checks)"
  pass_msg
fi

# --- nothing else changed in those files -----------------------------------
it "the upstream scripts are still valid bash"
bad=""
for f in WaybarStartup.sh Refresh.sh WaybarLayout.sh Kool_Quick_Settings.sh LidSwitch.sh; do
  bash -n "$S/$f" 2>/dev/null || bad="$bad $f"
done
if [[ -z $bad ]]; then pass_msg; else fail "syntax errors in:$bad"; fi

summary "test-upstream-fallbacks"
