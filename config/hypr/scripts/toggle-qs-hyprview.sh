#!/usr/bin/env bash

layout="${1:-smartgrid}"
config_name="qs-hyprview"
config_path="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/${config_name}"

if ! pgrep -u "${UID}" -f "qs .* -p ${config_path}($| )" >/dev/null 2>&1; then
    qs --log-rules "qt.qpa.wayland.textinput.warning=false" -p "${config_path}" >/dev/null 2>&1 &
    sleep 0.2
fi

if ! qs -c "${config_name}" ipc call expose toggle "${layout}" >/dev/null 2>&1; then
    sleep 0.3
    qs -c "${config_name}" ipc call expose toggle "${layout}"
fi
