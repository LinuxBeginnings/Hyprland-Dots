#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Patch: stop the network and bluetooth tray applets on an existing install.
#
# `custom/qs-network` (config/quickshell/network-widget) now owns Wi-Fi,
# ethernet and bluetooth - connect, disconnect, scan, pair and power. The two
# tray applets it replaced only duplicate that:
#
#   * blueman-applet exports a StatusNotifierItem, so Waybar's `tray` module
#     draws a bluetooth icon that offers nothing the widget does not.
#   * nm-applet does the same for wired and wireless links.
#
# The shipped template has both entries commented out and lua/startup.lua has
# nm-applet commented out, but an install made by an earlier installer can carry
# a live `"blueman-applet",` in UserConfigs/user_startup.lua: enable_blueman()
# uncommented the shipped entry (or added one) whenever blueman was present.
# copy.sh only ADDS missing UserConfigs files, so that line survives every
# upgrade. This patch is what comments it back out.
#
# Only live entries are touched: a table entry, or a top-level exec_once() call.
# The commented examples in the template header are inert already and stay
# exactly as shipped. The file is rewritten in place one line at a time, so
# indentation, comments and the rest of the table are preserved.
#
# A running applet keeps its icon until it exits, so the applets this patch
# disables are stopped as well. That is what removes the icon during the upgrade
# instead of at the next login.

# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TARGET="$(patch_hypr_dir)/UserConfigs/user_startup.lua"

# A live table entry: optional indent, then a quoted command that starts with one
# of the applet names, its arguments, the closing quote and the comma.
ENTRY='^[[:space:]]*"(nm-applet|blueman-applet)([[:space:]][^"]*)?",'
# The same command written as a live call instead of a table entry.
CALL='^[[:space:]]*exec_once[(]"(nm-applet|blueman-applet)([[:space:]][^"]*)?"[)]'

if [ ! -f "$TARGET" ]; then
  patch_log "UserConfigs/user_startup.lua is absent; nothing to disable"
  exit 0
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch-93.XXXXXX")" || exit 1
matches="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch-93-seen.XXXXXX")" || {
  rm -f "$tmp"
  exit 1
}

# Comment each live line, keeping its indentation, and record the original line
# so the applets that were disabled can be stopped below.
awk -v entry="$ENTRY" -v call="$CALL" -v seen="$matches" '
  {
    if ($0 ~ entry || $0 ~ call) {
      match($0, /^[[:space:]]*/)
      indent = substr($0, 1, RLENGTH)
      print indent "-- " substr($0, RLENGTH + 1)
      print $0 > seen
      found++
      next
    }
    print
  }
  END { exit (found > 0 ? 0 : 2) }
' "$TARGET" >"$tmp"
status=$?

if [ "$status" -eq 0 ]; then
  cat "$tmp" >"$TARGET"
  patch_log "commented out the network tray applets in UserConfigs/user_startup.lua"
  patch_log "  custom/qs-network already covers Wi-Fi, ethernet and bluetooth"
  applets="$(grep -oE '(nm-applet|blueman-applet)' "$matches" 2>/dev/null | sort -u)"
  while IFS= read -r applet; do
    [ -n "$applet" ] || continue
    command -v pgrep >/dev/null 2>&1 || continue
    command -v pkill >/dev/null 2>&1 || continue
    # -x matches the process name; a shebang script can instead report its
    # interpreter, so fall back to the executable path in the command line.
    if pgrep -x "$applet" >/dev/null 2>&1 && pkill -x "$applet" 2>/dev/null; then
      patch_log "  stopped the running $applet; its tray icon is gone"
    elif pgrep -f "(^|/)$applet([[:space:]]|$)" >/dev/null 2>&1 \
      && pkill -f "(^|/)$applet([[:space:]]|$)" 2>/dev/null; then
      patch_log "  stopped the running $applet; its tray icon is gone"
    fi
  done <<<"$applets"
elif [ "$status" -eq 2 ]; then
  patch_log "UserConfigs/user_startup.lua starts no network tray applet; nothing to do"
else
  patch_log "UserConfigs/user_startup.lua could not be rewritten; left unchanged"
fi

rm -f "$tmp" "$matches"

exit 0
