#!/usr/bin/env bash
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
swayIconDir="${XDG_CONFIG_HOME}/swaync/icons"

#// Credits to sl1ng for the orginal script. Rewritten by Vyle.
ctlcheck=("pactl" "jq" "notify-send" "awk" "pgrep" "hyprctl" "iconv")
missing=()

for ctl in "${ctlcheck[@]}"; do
  command -v "${ctl}" >/dev/null || missing+=("${ctl}")
done

if (( ${#missing[@]} )) 2>/dev/null; then
  echo "Missing required dependencies: \"${missing[*]}\""
  exit 1
fi

#// Parse .pid, .class, .title to __pid, __class, __title.
active_json="$(hyprctl -j activewindow 2>/dev/null || { echo -e "Did hyprctl fail to run? [EXIT-CODE:-1]"; exit 1; } )"
PID="$(jq -r '"\(.pid)\t\(.class)\t\(.title)"' <<< "${active_json}" || { echo -e "Did jq fail to run? [EXIT-CODE:-1]"; exit 1; } )"

IFS=$'\t' read -r __pid __class __title <<< "${PID}"

[[ -z "${__pid}" ]] && { echo -e "Could not resolve PID for focused window."; exit 1; }
sink_json="$(pactl -f json list sink-inputs 2>/dev/null | iconv -f utf-8 -t utf-8 -c || { echo -e "Did pactl or iconv fail to run? Required manual intervention."; exit 1; } )"

#// Check if the __pid matches application.process.id or else verify other statements.
mapfile -t sink_ids < <(jq -r --arg pid "${__pid}" --arg class "${__class}" --arg title "${__title}" '
.[] |
 def lc(x): (x // "" | ascii_downcase);
  def normalize(x): x | gsub("[-_~.]+";" ") ;
  select(
  (.properties["application.process.id"] // "") == $pid
  or
  (lc(.properties["application.name"]) | contains(lc($class)))
  or
  (lc(.properties["application.id"]) | contains(lc($class)))
  or
  (lc(.properties["application.process.binary"]) | contains(lc($class)))
  or
  ((normalize(lc(.properties["media.name"])) | test(normalize(lc($title)))))
  ) | .index' <<< "${sink_json}"
)

if [[ "${#sink_ids[@]}" -eq 0 ]]; then
  fallback_pid="$(pgrep -x "${__class}" | head -n 1 || true)"
  if [[ -n "${fallback_pid}" ]]; then
    mapfile -t sink_ids < <( jq -r --arg pid "${fallback_pid}" '.[] | 
      select(.properties["application.process.id"] == $pid) | .index' <<< "${sink_json}" )
  fi
fi

#// Auto-Detect if the environment is on Hyprland or $HYPRLAND_INSTANCE_SIGNATURE.
if [[ ${#sink_ids[@]} -eq 0 ]]; then
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE}" ]]; then
    # Even if the fallback_pid remains empty, we will dispatch exit code based on $HYPRLAND_INSTANCE_SIGNATURE.
    notify-send -a "t1" -r 91190 -t 1200 -i "${swayIconDir}/volume-low.png" "No sink input for the active_window: ${__class}"
    echo "No sink input for focused window: ${__class}"
    exit 1
  else
    echo "No sink input for focused active_window ${__class}"
    exit 1
  fi
fi

idsJson=$(printf '%s\n' "${sink_ids[@]}" | jq -s 'map(tonumber)')

#// Get the available option from pactl. 
want_mute=$(jq -r --argjson ids "$idsJson" '
    [ .[] | select(.index as $i | $ids | index($i)) | .mute ] as $m |
    if all($m[]; . == true) then "no"
    else "yes"
    end' <<< "${sink_json}"
)

if [[ "${want_mute}" == "no" ]]; then
  state_msg="Unmuted"
  swayIcon="${swayIconDir}/volume-high.png"
else
  state_msg="Muted"
  swayIcon="${swayIconDir}/volume-mute.png"
fi

[[ -f "${swayIcon}" ]] || echo -e "Missing swaync icons."

for id in "${sink_ids[@]}"; do
  pactl set-sink-input-mute "$id" "$want_mute"
done

#// Append pamixer to get a nice result. Pamixer is complete optional here.
if command -v pamixer >/dev/null; then
  notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}" "$(pamixer --get-default-sink | awk -F '"' 'END{print $(NF - 1)}')"
else
  notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}"
fi
