#!/usr/bin/env bash

# Available layouts
#
# "smartgrid", "justified", "masonry", "bands", "hero", "spiral"
# "satellite", "staggered", "columnar", "vortex", "random"
#

default_layout="smartgrid"
layout_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/hyprview-layout.conf"
layout="${1:-}"
config_name="qs-hyprview"
config_path="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/${config_name}"

if [[ -z "$layout" ]]; then
  if [[ -f "$layout_config" && -r "$layout_config" ]]; then
    layout="$(sed -n '1p' "$layout_config" | tr -d '[:space:]')"
  else
    notify-send "Can't read hyprview-layout.conf, falling back to smartgrid"
  fi
fi

case "$layout" in
smartgrid | justified | masonry | bands | hero | spiral | satellite | staggered | columnar | vortex | random) ;;
*) layout="$default_layout" ;;
esac

if ! pgrep -u "${UID}" -f "qs .* -p ${config_path}($| )" >/dev/null 2>&1; then
  qs --log-rules "qt.qpa.wayland.textinput.warning=false" -p "${config_path}" >/dev/null 2>&1 &
  sleep 0.2
fi

if ! qs -c "${config_name}" ipc call expose toggle "${layout}" >/dev/null 2>&1; then
  sleep 0.3
  qs -c "${config_name}" ipc call expose toggle "${layout}"
fi
