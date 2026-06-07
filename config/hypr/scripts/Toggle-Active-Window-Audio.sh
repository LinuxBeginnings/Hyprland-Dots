#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
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
  if printf '%s\n' "${missing[@]}" | grep -qx "pactl"; then
    notify-send -a "t1" -r 91190 -t 2000 -i "${swayIconDir}/volume-low.png" "ERROR: pactl not installed" "Install 'pactl' (pulseaudio-utils or pipewire-pulse)."
  fi
  echo "Missing required dependencies: \"${missing[*]}\""
  exit 1
fi

#// Parse .pid, .class, .title to __pid, __class, __title.
active_json="$(hyprctl -j activewindow 2>/dev/null || { echo -e "Did hyprctl fail to run? [EXIT-CODE:-1]"; exit 1; } )"
PID="$(jq -r '"\(.pid)\t\(.class)\t\(.title)"' <<< "${active_json}" || { echo -e "Did jq fail to run? [EXIT-CODE:-1]"; exit 1; } )"

IFS=$'\t' read -r __pid __class __title <<< "${PID}"

[[ -z "${__pid}" ]] && { echo -e "Could not resolve PID for focused window."; exit 1; }
sink_json="$(pactl -f json list sink-inputs 2>/dev/null | iconv -f utf-8 -t utf-8 -c || { echo -e "Did pactl or iconv fail to run? Required manual intervention."; exit 1; } )"
#// Collect all descendant PIDs for the active window (Chrome/Wayland audio often runs in child processes).
declare -A seen_pids=()
queue=("${__pid}")
all_pids=()
while ((${#queue[@]})); do
  pid="${queue[0]}"
  queue=("${queue[@]:1}")
  [[ -n "${seen_pids[$pid]:-}" ]] && continue
  seen_pids["$pid"]=1
  all_pids+=("$pid")
  mapfile -t children < <(pgrep -P "$pid" || true)
  for child in "${children[@]}"; do
    [[ -n "${seen_pids[$child]:-}" ]] || queue+=("$child")
  done
done
pidsJson="$(printf '%s\n' "${all_pids[@]}" | jq -s 'map(tonumber)')"

#// Check if any descendant PID matches application.process.id or else verify other statements.
mapfile -t sink_ids < <(jq -r --argjson pids "${pidsJson}" --arg class "${__class}" --arg title "${__title}" '
.[] |
  def norm(x): (x // "" | ascii_downcase | gsub("[-_~.]+";" ") | gsub("[^a-z0-9 ]+";" ") | gsub("[[:space:]]+";" ") | gsub("^ +| +$";""));
  def to_num(x): (try (x | tostring | tonumber) catch null);
  select(
  (to_num(.properties["application.process.id"]) as $p | $p != null and ($pids | index($p)))
  or
  (norm(.properties["application.name"]) | contains(norm($class)))
  or
  (norm(.properties["application.id"]) | contains(norm($class)))
  or
  (norm(.properties["application.process.binary"]) | contains(norm($class)))
  or
  (norm(.properties["media.name"]) | contains(norm($title)))
  ) | .index' <<< "${sink_json}"
)

if [[ "${#sink_ids[@]}" -eq 0 ]]; then
  mapfile -t fallback_pids < <(pgrep -x "${__class}" || true)
  if [[ "${#fallback_pids[@]}" -gt 0 ]]; then
    declare -A seen_fallback=()
    queue=("${fallback_pids[@]}")
    all_fallback=()
    while ((${#queue[@]})); do
      pid="${queue[0]}"
      queue=("${queue[@]:1}")
      [[ -n "${seen_fallback[$pid]:-}" ]] && continue
      seen_fallback["$pid"]=1
      all_fallback+=("$pid")
      mapfile -t children < <(pgrep -P "$pid" || true)
      for child in "${children[@]}"; do
        [[ -n "${seen_fallback[$child]:-}" ]] || queue+=("$child")
      done
    done
    fallbackJson="$(printf '%s\n' "${all_fallback[@]}" | jq -s 'map(tonumber)')"
    mapfile -t sink_ids < <( jq -r --argjson pids "${fallbackJson}" '.[] |
      def to_num(x): (try (x | tostring | tonumber) catch null);
      select((to_num(.properties["application.process.id"]) as $p | $p != null and ($pids | index($p)))) | .index' <<< "${sink_json}" )
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

changed=0
failed_ids=()
for id in "${sink_ids[@]}"; do
  if pactl set-sink-input-mute "$id" "$want_mute"; then
    changed=1
  else
    failed_ids+=("$id")
  fi
done

if [[ "$changed" -eq 0 ]]; then
  notify-send -a "t2" -r 91190 -t 1200 -i "${swayIconDir}/volume-low.png" "Failed to change sink input(s)" "${failed_ids[*]:-unknown}"
  exit 1
fi

#// Append pamixer to get a nice result. Pamixer is complete optional here.
if command -v pamixer >/dev/null; then
  sink_name="$(pamixer --get-default-sink 2>/dev/null | awk -F '"' 'END{print $(NF - 1)}' 2>/dev/null || true)"
  if [[ -n "${sink_name}" ]]; then
    notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}" "${sink_name}"
  else
    notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}"
  fi
else
  notify-send -a "t2" -r 91190 -t 800 -i "${swayIcon}" "${state_msg} ${__class}"
fi
