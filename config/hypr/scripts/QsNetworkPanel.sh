#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Backend for the Quickshell network & bluetooth widget
# (~/.config/hypr/quickshell/network-widget) and its Waybar module
# (custom/qs-network).
#
# The QML panel never talks to NetworkManager or BlueZ directly: it runs
# this script and parses the tab separated snapshot below, and it calls the
# action subcommands for anything that changes state.
#
# Subcommands:
#   snapshot                        state for the QML panel (see below)
#   status                          Waybar JSON (text / tooltip / class)
#   toggle | open | close           show or hide the panel, starting it if needed
#   wifi on|off                     Wi-Fi radio
#   scan-wifi                       ask NetworkManager for a fresh scan
#   connect-wifi SSID [PASSWORD]    join a network
#   disconnect-wifi SSID            leave the network with that connection name
#   connect-device IFACE            bring a device (ethernet) up
#   disconnect-device IFACE         take a device (ethernet) down
#   bt-power on|off                 Bluetooth adapter power
#   bt-scan                         discover for a few seconds
#   bt connect|disconnect|pair MAC  manage one bluetooth device
#
# snapshot format, one record per line, tab separated, no tabs or newlines
# inside a value:
#   DEV      <iface> <type> <state> <connection> <ip> <prefix> <gateway> <dns> <mac>
#   WIFI     <ssid> <signal> <security> <in-use 0|1>
#   WIFI-ON  <0|1>
#   BT-ON    <0|1>
#   BT-SCAN  <0|1>
#   BT-CTL   <alias> <address>
#   BTDEV    <address> <name> <connected 0|1> <paired 0|1> <battery|-> <icon>
#   NOTE     <message>
#
# Output is read by QML and by Waybar, so it must stay silent on success and
# keep errors on stderr.

set -u

# The script lives next to the widget in both layouts:
#   <hypr>/scripts/QsNetworkPanel.sh      (repo: config/hypr/scripts)
#   <hypr>/quickshell/network-widget/    (repo: config/hypr/quickshell)
# Deriving the path from here keeps repo runs and installed runs identical.
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
widget_dir=$(CDPATH= cd -- "$script_dir/../quickshell/network-widget" 2>/dev/null && pwd) \
  || widget_dir="$script_dir/../quickshell/network-widget"
qs_target="network-widget"

have() { command -v "$1" >/dev/null 2>&1; }

# Drop characters that would break the tab separated record format.
san() { printf '%s' "${1:-}" | tr '\t\n\r' '   '; }

note() { printf 'NOTE\t%s\n' "$(san "$1")"; }

bt() {
  if have timeout; then
    timeout 6 bluetoothctl "$@" 2>/dev/null
  else
    bluetoothctl "$@" 2>/dev/null
  fi
}

wifi_glyph() {
  local signal="${1:-0}"
  if ((signal >= 80)); then
    printf '󰤨'
  elif ((signal >= 60)); then
    printf '󰤥'
  elif ((signal >= 40)); then
    printf '󰤢'
  elif ((signal >= 20)); then
    printf '󰤟'
  else
    printf '󰤯'
  fi
}

json_escape() {
  local text="${1:-}"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\t'/ }
  text=${text//$'\n'/ }
  printf '%s' "$text"
}

# Trim the padding nmcli puts after the colon in multiline mode.
trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "$value"
}

# ---------------------------------------------------------------- network --

emit_device() {
  local iface="$1" type="$2" state="$3" connection="$4"
  [[ -z $iface ]] && return 0
  case "$type" in
    ethernet | wifi) ;;
    *) return 0 ;;
  esac

  # Address, gateway, DNS and MAC are what the panel's info block shows.
  local ip="" prefix="" gateway="" dns="" mac=""
  if [[ $state == connected ]] && have nmcli; then
    local line key value address=""
    local -a dns_list=()
    while IFS= read -r line; do
      [[ -z $line ]] && continue
      key=${line%%:*}
      value=$(trim "${line#*:}")
      case "$key" in
        GENERAL.HWADDR) mac=$value ;;
        IP4.ADDRESS*) [[ -z $address ]] && address=$value ;;
        IP4.GATEWAY) gateway=$value ;;
        IP4.DNS*) dns_list+=("$value") ;;
      esac
    done < <(nmcli -m multiline --escape no \
      -f GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$iface" 2>/dev/null)

    if [[ -n $address ]]; then
      ip=${address%%/*}
      [[ $address == */* ]] && prefix=${address#*/}
    fi
    dns=$(IFS=,; printf '%s' "${dns_list[*]}")
  fi

  printf 'DEV\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(san "$iface")" "$(san "$type")" "$(san "$state")" \
    "$(san "$connection")" "$(san "$ip")" "$(san "$prefix")" \
    "$(san "$gateway")" "$(san "$dns")" "$(san "$mac")"
}

snapshot_network() {
  if ! have nmcli; then
    printf 'WIFI-ON\t0\n'
    note "NetworkManager (nmcli) is not installed"
    return 0
  fi

  if [[ $(nmcli radio wifi 2>/dev/null) == enabled ]]; then
    printf 'WIFI-ON\t1\n'
  else
    printf 'WIFI-ON\t0\n'
  fi

  local line key value
  local dev="" type="" state="" connection=""
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    key=${line%%:*}
    value=$(trim "${line#*:}")
    case "$key" in
      DEVICE)
        emit_device "$dev" "$type" "$state" "$connection"
        dev=$value
        type=""
        state=""
        connection=""
        ;;
      TYPE) type=$value ;;
      STATE) state=$value ;;
      CONNECTION) connection=$value ;;
    esac
  done < <(nmcli -m multiline --escape no \
    -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null)
  emit_device "$dev" "$type" "$state" "$connection"

  # Wi-Fi networks. nmcli lists one entry per BSSID, so duplicate SSIDs are
  # folded together, keeping the in-use entry and then the strongest signal.
  # The list is not fetched with --rescan no: NetworkManager's cached list
  # decays to just the active AP, which leaves the panel nearly empty.
  # scan-wifi asks for a rescan without waiting for it.
  local -a records=()
  local in_use="" ssid="" signal="" security="" seen=""
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    key=${line%%:*}
    value=$(trim "${line#*:}")
    case "$key" in
      IN-USE)
        if [[ -n $seen && -n $ssid && $ssid != "--" ]]; then
          records+=("${in_use:- }"$'\t'"$ssid"$'\t'"${signal:-0}"$'\t'"$security")
        fi
        seen=1
        in_use=$value
        ssid=""
        signal=""
        security=""
        ;;
      SSID) ssid=$value ;;
      SIGNAL) signal=$value ;;
      SECURITY) security=$value ;;
    esac
  done < <(nmcli -m multiline --escape no \
    -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null)

  if [[ -n $seen && -n $ssid && $ssid != "--" ]]; then
    records+=("${in_use:- }"$'\t'"$ssid"$'\t'"${signal:-0}"$'\t'"$security")
  fi

  if ((${#records[@]} > 0)); then
    printf '%s\n' "${records[@]}" |
      awk -F'\t' '
        {
          name = $2
          active = ($1 == "*") ? 1 : 0
          if (!(name in best) || active > seen_active[name] ||
              (active == seen_active[name] && $3 + 0 > seen_signal[name])) {
            best[name] = $0
            seen_active[name] = active
            seen_signal[name] = $3 + 0
          }
        }
        END { for (name in best) print best[name] }' |
      sort -t$'\t' -k1,1r -k3,3nr |
      while IFS=$'\t' read -r in_use ssid signal security; do
        local flag=0
        [[ $in_use == "*" ]] && flag=1
        printf 'WIFI\t%s\t%s\t%s\t%s\n' \
          "$(san "$ssid")" "${signal:-0}" "$(san "$security")" "$flag"
      done
  fi
}

# --------------------------------------------------------------- bluetooth --

snapshot_bluetooth() {
  if ! have bluetoothctl; then
    printf 'BT-ON\t0\nBT-SCAN\t0\nBT-CTL\t\t\n'
    note "bluetoothctl (bluez) is not installed"
    return 0
  fi

  local show powered=0 discovering=0 controller="" alias=""
  show=$(bt show)
  if [[ -z $show ]]; then
    printf 'BT-ON\t0\nBT-SCAN\t0\nBT-CTL\t\t\n'
    note "No Bluetooth adapter found"
    return 0
  fi

  local line trimmed
  while IFS= read -r line; do
    # Nested fields are tab indented; match on the trimmed line.
    trimmed=$(trim "$line")
    case "$trimmed" in
      Controller*) controller=$(printf '%s' "$trimmed" | awk '{print $2}') ;;
      "Powered:"*) [[ $(trim "${trimmed#*:}") == yes ]] && powered=1 ;;
      "Discovering:"*) [[ $(trim "${trimmed#*:}") == yes ]] && discovering=1 ;;
      "Alias:"*) alias=$(trim "${trimmed#*:}") ;;
    esac
  done <<<"$show"

  [[ -z $alias ]] && alias=$controller

  printf 'BT-ON\t%s\nBT-SCAN\t%s\nBT-CTL\t%s\t%s\n' \
    "$powered" "$discovering" "$(san "$alias")" "$(san "$controller")"

  local paired_list connected_list
  paired_list=$(bt devices Paired | awk '{print $2}')
  connected_list=$(bt devices Connected | awk '{print $2}')

  {
    local tag address name
    while read -r tag address name; do
      [[ -z ${address:-} ]] && continue
      local connected=0 paired=0 battery="-" icon=""
      grep -qxF "$address" <<<"$connected_list" && connected=1
      grep -qxF "$address" <<<"$paired_list" && paired=1

      # Battery is only reported for connected devices, so only they pay the
      # extra bluetoothctl round trip.
      if ((connected == 1)); then
        local info
        info=$(bt info "$address")
        [[ $(sed -n 's/^[[:space:]]*Paired: //p' <<<"$info" | head -n 1) == yes ]] && paired=1
        battery=$(sed -n 's/.*Battery Percentage:.*(\([0-9][0-9]*\)).*/\1/p' <<<"$info" | head -n 1)
        icon=$(sed -n 's/^[[:space:]]*Icon: //p' <<<"$info" | head -n 1)
        [[ -z $battery ]] && battery="-"
      fi

      printf 'BTDEV\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(san "$address")" "$(san "$name")" "$connected" "$paired" \
        "$(san "$battery")" "$(san "$icon")"
    done < <(bt devices)
  } | sort -t$'\t' -k4,4nr -k5,5nr -k3,3f
}

snapshot() {
  snapshot_network
  snapshot_bluetooth
}

# ------------------------------------------------------------------ waybar --

waybar_status() {
  local snapshot_text
  snapshot_text=$(snapshot)

  local eth="" wifi_ssid="" wifi_signal="0" wifi_on="0" bt_on="0"
  local -a bt_names=()
  local key f1 f2 f3 f4 f5 f6
  while IFS=$'\t' read -r key f1 f2 f3 f4 f5 f6; do
    case "$key" in
      DEV)
        if [[ $f2 == ethernet && $f3 == connected ]]; then
          eth=${f4:-$f1}
        fi
        ;;
      WIFI)
        if [[ $f4 == 1 ]]; then
          wifi_ssid=$f1
          wifi_signal=$f2
        fi
        ;;
      WIFI-ON) wifi_on=${f1:-0} ;;
      BT-ON) bt_on=${f1:-0} ;;
      BTDEV)
        if [[ $f3 == 1 ]]; then
          if [[ -n ${f5:-} && $f5 != "-" ]]; then
            bt_names+=("$f2 $f5%")
          else
            bt_names+=("$f2")
          fi
        fi
        ;;
    esac
  done <<<"$snapshot_text"

  local text class
  if [[ -n $eth ]]; then
    text="󰌘"
    class="ethernet"
  elif [[ -n $wifi_ssid ]]; then
    text=$(wifi_glyph "$wifi_signal")
    class="wifi"
  elif [[ $wifi_on == 1 ]]; then
    text="󰤮"
    class="disconnected"
  else
    text="󰤭"
    class="disconnected"
  fi

  local -a lines=()
  [[ -n $eth ]] && lines+=("Ethernet · $eth")
  if [[ -n $wifi_ssid ]]; then
    lines+=("Wi-Fi · $wifi_ssid (${wifi_signal}%)")
  elif [[ $wifi_on == 1 ]]; then
    lines+=("Wi-Fi · not connected")
  else
    lines+=("Wi-Fi · off")
  fi
  if ((bt_on == 1)); then
    if ((${#bt_names[@]} > 0)); then
      local name
      for name in "${bt_names[@]}"; do
        lines+=("Bluetooth · $name")
      done
    else
      lines+=("Bluetooth · on")
    fi
  else
    lines+=("Bluetooth · off")
  fi
  lines+=("Click to manage connections")

  local tooltip="" line
  for line in "${lines[@]}"; do
    tooltip+="${tooltip:+\\n}$(json_escape "$line")"
  done

  printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' \
    "$(json_escape "$text")" "$tooltip" "$class" "$class"
}

# ------------------------------------------------------------------- panel --

qs_ipc() { quickshell ipc -p "$widget_dir" call "$qs_target" "$@" >/dev/null 2>&1; }

notify() {
  have notify-send && notify-send -a "Network" "$1" "$2" >/dev/null 2>&1
  return 0
}

launch_panel() {
  if ! have quickshell; then
    notify "Network widget" "Quickshell is not installed."
    printf 'quickshell is not installed\n' >&2
    return 1
  fi
  quickshell -p "$widget_dir" --daemonize >/dev/null 2>&1
  local attempt
  for attempt in $(seq 1 50); do
    sleep 0.1
    qs_ipc isOpen && return 0
  done
  notify "Network widget" "Quickshell did not start. See 'quickshell -p $widget_dir'."
  printf 'quickshell did not start\n' >&2
  return 1
}

toggle_panel() {
  qs_ipc toggle && return 0
  launch_panel || return 1
  qs_ipc open
}

# ----------------------------------------------------------------- actions --

nm() { nmcli "$@"; }

case "${1:-snapshot}" in
  snapshot)
    snapshot
    ;;
  status)
    waybar_status
    ;;
  toggle)
    toggle_panel
    ;;
  open)
    qs_ipc open || { launch_panel && qs_ipc open; }
    ;;
  close)
    qs_ipc close
    ;;
  wifi)
    case "${2:-}" in
      on | off) nm radio wifi "$2" ;;
      *) printf 'usage: %s wifi on|off\n' "$0" >&2; exit 2 ;;
    esac
    ;;
  scan-wifi)
    have nmcli || exit 1
    nm device wifi rescan >/dev/null 2>&1 || true
    ;;
  connect-wifi)
    [[ $# -ge 2 && -n ${2:-} ]] || { printf 'usage: %s connect-wifi SSID [PASSWORD]\n' "$0" >&2; exit 2; }
    if [[ $# -ge 3 && -n ${3:-} ]]; then
      nm device wifi connect "$2" password "$3"
    else
      nm device wifi connect "$2"
    fi
    ;;
  disconnect-wifi)
    [[ -n ${2:-} ]] || { printf 'usage: %s disconnect-wifi SSID\n' "$0" >&2; exit 2; }
    nm connection down id "$2"
    ;;
  connect-device)
    [[ -n ${2:-} ]] || exit 2
    nm device connect "$2"
    ;;
  disconnect-device)
    [[ -n ${2:-} ]] || exit 2
    nm device disconnect "$2"
    ;;
  bt-power)
    case "${2:-}" in
      on | off) bluetoothctl power "$2" ;;
      *) printf 'usage: %s bt-power on|off\n' "$0" >&2; exit 2 ;;
    esac
    ;;
  bt-scan)
    have bluetoothctl || exit 1
    if bluetoothctl --help 2>&1 | grep -q -- '--timeout'; then
      nohup bluetoothctl --timeout 15 scan on >/dev/null 2>&1 &
    else
      nohup bluetoothctl scan on >/dev/null 2>&1 &
    fi
    ;;
  bt)
    case "${2:-}" in
      connect | disconnect | pair | trust | remove)
        [[ -n ${3:-} ]] || { printf 'usage: %s bt %s MAC\n' "$0" "$2" >&2; exit 2; }
        if [[ $2 == pair ]]; then
          bluetoothctl pair "$3" && bluetoothctl connect "$3"
        else
          bluetoothctl "$2" "$3"
        fi
        ;;
      *)
        printf 'usage: %s bt connect|disconnect|pair MAC\n' "$0" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    printf 'usage: %s [snapshot|status|toggle|open|close|wifi|scan-wifi|connect-wifi|disconnect-wifi|connect-device|disconnect-device|bt-power|bt-scan|bt]\n' "$0" >&2
    exit 2
    ;;
esac
