#!/usr/bin/env bash

XDG_CONFIG_HOME="$HOME/.config"
swayIconDir="${XDG_CONFIG_HOME}/swaync/icons"
#// Credits to sl1ng for the orginal script. Rewritten by Vyle.
#// We will NOT USE set -e -u -o pipefail for this script - Avoids rewriting!

ctlcheck=("pactl" "jq" "notify-send" "pamixer")
for i in "${!ctlcheck[@]}"; do
  if ! command -v "${ctlcheck[i]}" >/dev/null; then
    echo "${ctlcheck[i]} does not exist, require manual parsing!"
  fi
done

#// Parse .pid, .class, .title to __pid, __class, __title
PID=$(hyprctl -j activewindow 2>/dev/null | jq -r '"\(.pid) \(.class) \(.title)"' || exit 1)
read -r __pid __class __title <<< "${PID}"

[[ -z "${__pid}" ]] && { echo -e "Could not resolve PID for focused window."; exit 1; }

#// Check if the __pid matches application.process.id or else verify other statements.
mapfile -t sink_ids < <(pactl -f json list sink-inputs 2>/dev/null | iconv -f utf-8 -t utf-8 -c  | jq -r --arg pid "${__pid}" --arg class "${__class}" --arg title "${__title}" '
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
  ) | .index'
)

idsJson=$(printf '%s\n' "${sink_ids[@]}" | jq -s 'map(tonumber)')

#// Get the available option from pactl. (Yes|No)
want_mute=$(
  pactl -f json list sink-inputs | iconv -f utf-8 -t utf-8 -c | \
  jq -r --argjson ids "$idsJson" '
    [ .[] | select(.index as $i | $ids | index($i)) | .mute ] as $m |
    if all($m[]; . == true) then "no"
    else "yes"
    end
  '
)

#// Auto-Detect if the environment is on Hyprland or $HYPRLAND_INSTANCE_SIGNATURE.
if [[ ${#sink_ids[@]} -eq 0 ]]; then
  #// Create a Fallback_PID if nothing matches with hyprctl or pactl.
  fallback_pid=$(pgrep -x "${__class}" || true)

  if [[ -n "${fallback_pid}" ]]; then
    mapfile -t sink_ids < <( jq -r --arg pid "${fallback_pid}" '.[] | 
      select(.properties["application.process.id"] == $pid) | .index' <<< "$(pactl -f json list sink-inputs 2>/dev/null | iconv -f utf-8 -t utf-8 -c || exit 1)" ) 
  else
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE}" ]]; then
      notify-send -a "t1" -r 91190 -t 1200 -i "${swayIconDir}/volume-low.png" "No sink input for the active_window: ${__class}"
      echo "No sink input for focused window: ${__class}"
    else
      echo "No sink input for focused active_window ${__class}"
      exit 1
    fi
  fi
fi

if [[ "${want_mute}" == "no" ]]; then
  state_msg="Unmuted"
  swayIcon="${swayIconDir}/volume-high.png"
else
  state_msg="Muted"
  swayIcon="${swayIconDir}/volume-mute.png"
fi

for id in "${sink_ids[@]}"; do
  pactl set-sink-input-mute "$id" "$want_mute"
done

#// Append paxmier to get a nice result.
notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}" "$(pamixer --get-default-sink | awk -F '"' 'END{print $(NF - 1)}')"

