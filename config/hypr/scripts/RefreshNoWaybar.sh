#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

# Modified version of Refresh.sh but waybar wont refresh
# Used by automatic wallpaper change
# Modified inorder to refresh rofi background, Wallust, SwayNC only

SCRIPTSDIR=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

# Kill already running processes
_ps=(rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
pkill qs && qs --log-rules "$QS_TEXTINPUT_LOG_RULE" &


# reload swaync
(swaync-client -R -rs --skip-wait >/dev/null 2>&1 &)

# Re-apply the selected Rainbow Borders mode. The single implementation lives
# in RainbowBordersStartup.sh so this script, Refresh.sh and the wallpaper pass
# cannot drift apart.
sleep 1
if [ -x "${SCRIPTSDIR}/RainbowBordersStartup.sh" ]; then
  "${SCRIPTSDIR}/RainbowBordersStartup.sh" >/dev/null 2>&1 || true
fi

exit 0
