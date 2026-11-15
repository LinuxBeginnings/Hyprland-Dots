#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Backend for the Quickshell network & bluetooth widget
# (~/.config/quickshell/network-widget) and its Waybar module
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
#   container docker|podman start|stop|restart|logs|shell NAME
#                                   manage one container; logs open in a
#                                   searchable viewer (a trailing `live`
#                                   follows the stream), shell in a terminal
#   container-engine on|off         start or stop the docker/podman daemon
#   tailscale-list-terminals        list installed terminal emulators
#   tailscale-list-keys             list discovered SSH private keys in ~/.ssh
#   tailscale-ssh-test ...          test SSH connection to a host
#   tailscale-ssh-connect ...       launch terminal connected to host via SSH
#   tailscale-save-host ...         save host profile in UserConfigs/tailscale-hosts.json
#   tailscale-export ...            export Tailscale host profiles to file
#   tailscale-import ...            import Tailscale host profiles from file
#   tailscale-logs [text|json]      read Tailscale SSH log
#   tailscale-log-save PATH         save log file to destination disk path
#
# snapshot format, one record per line, tab separated, no tabs or newlines
# inside a value:
#   DEV      <iface> <type> <state> <connection> <ip> <prefix> <gateway> <dns> <mac> <managed>
#   ADDR     <iface> <family> <address> <prefix> <scope>
#   LINK     <kind> <iface> <state>       kind: tailscale|docker|podman
#   FEATURE  <kind>                       tooling that is installed
#   TS-STATE <backend state>              Running, NeedsLogin, Stopped, ...
#   TSPEER   <name> <ip> <online 0|1> <os> <self 0|1>
#   TS-EXIT  <name> <ip> <selected 0|1>
#   BOX      <kind> <name> <state> <status> <runtime>
#   BOXENGINE <kind> <running 0|1>       daemon answers, not just installed
#   BOXSTAT  <kind> <name> <cpu> <mem>
#   WIFI     <ssid> <signal> <security> <in-use 0|1>
#   WIFI-ON  <0|1>
#   BT-ON    <0|1>
#   BT-SCAN  <0|1>
#   BT-CTL   <alias> <address>
#   BTDEV    <address> <name> <connected 0|1> <paired 0|1> <battery|-> <icon>
#   NOTE     <tab> <message>             hint for that tab, empty tab for any
#   ERR      <message>                     shown in the panel footer as an error
#
# Output is read by QML and by Waybar, so it must stay silent on success and
# keep errors on stderr.

set -u

# The widget sits two levels up from this script, under quickshell/:
#   <config>/hypr/scripts/QsNetworkPanel.sh    this script
#   <config>/quickshell/network-widget/        the widget
# Deriving it from here keeps a repo run and an installed run identical.
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
widget_dir=$(CDPATH= cd -- "$script_dir/../../quickshell/network-widget" 2>/dev/null && pwd) \
  || widget_dir="$script_dir/../../quickshell/network-widget"
qs_target="network-widget"

have() { command -v "$1" >/dev/null 2>&1; }

# Drop characters that would break the tab separated record format.
san() { printf '%s' "${1:-}" | tr '\t\n\r' '   '; }

# Single-quote a value for the shell command string handed to the terminal.
shell_quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

# The tag names the tab a hint belongs to, so the panel can keep a Bluetooth
# note out of the footer while another tab is open.
note() { printf 'NOTE\t%s\t%s\n' "$(san "${2:-}")" "$(san "$1")"; }
err() { printf 'ERR\t%s\n' "$(san "$1")"; }

# Incremented by emit_device so snapshot_network can tell whether nmcli gave it
# anything at all; when it did not, the kernel is asked instead.
devices_emitted=0

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

# resolv.conf is the DNS an interface is really using when another manager
# owns it and NetworkManager therefore knows no name servers for it.
resolv_dns() {
  [[ -r /etc/resolv.conf ]] || return 0
  awk '$1 == "nameserver" && NF >= 2 {
         printf "%s%s", (n++ ? "," : ""), $2
       }' /etc/resolv.conf
}

# The name servers systemd-resolved has for one link: "Link 2 (ens18): a b"
# becomes "a,b".
resolved_dns() {
  have resolvectl || return 0
  resolvectl dns "$1" 2>/dev/null |
    sed -n '1{s/^[^:]*://;s/^[[:space:]]*//;s/[[:space:]][[:space:]]*/,/g;p;q}'
}

# DNS for a link NetworkManager does not manage. resolv.conf is usually right,
# but systemd-resolved only leaves its stub there, so the real servers are
# asked of resolvectl when the stub is all resolv.conf holds.
link_dns() {
  local dns stub=0
  dns=$(resolv_dns)
  case ",$dns," in
    *",127.0.0.53,"* | *",127.0.0.54,"*) stub=1 ;;
  esac
  if ((stub == 1)) || [[ -z $dns ]]; then
    local resolved
    resolved=$(resolved_dns "$1")
    [[ -n $resolved ]] && dns=$resolved
  fi
  printf '%s' "$dns"
}

# Every address an interface carries, including aliases and secondary IPv6
# addresses. nmcli reports only the first IP4.ADDRESS, so `ip` is the source of
# truth here and the panel lists them all under the device.
emit_addresses() {
  local iface="$1"
  [[ -z $iface ]] && return 0
  have ip || return 0
  ip -o addr show dev "$iface" 2>/dev/null |
    awk -F'[ /]+' -v iface="$iface" '
      $3 == "inet" || $3 == "inet6" {
        scope = ""
        for (i = 4; i < NF; i++) if ($i == "scope") scope = $(i + 1)
        printf "ADDR\t%s\t%s\t%s\t%s\t%s\n", iface, $3, $4, $5, scope
      }'
  return 0
}

emit_device() {
  local iface="$1" type="$2" state="$3" connection="$4"
  [[ -z $iface ]] && return 0
  case "$type" in
    ethernet | wifi) ;;
    *) return 0 ;;
  esac

  devices_emitted=$((devices_emitted + 1))

  # nmcli prints "--" for a device with no active connection, but the panel
  # falls back to the interface name, so keep that field empty instead.
  [[ $connection == -- ]] && connection=""

  # Address, gateway, DNS and MAC are what the panel's info block shows.
  # nmcli is asked about every device, not only the connected ones: an
  # interface another manager owns (ifupdown in a VM image, say) is unmanaged
  # here, yet nmcli still knows its MAC and the addresses the kernel has on it.
  local ip="" prefix="" gateway="" dns="" mac=""
  if have nmcli; then
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

  # An interface another manager owns has no NetworkManager DNS, but
  # resolv.conf is what it is really resolving with.
  [[ -z $dns && $state == unmanaged ]] && dns=$(link_dns "$iface")

  # Unmanaged devices have no NetworkManager connection to bring up or down,
  # so the panel lists them read-only and the Waybar module still shows the
  # wired icon when they carry an address.
  local managed=1
  case "$state" in
    # "connected (externally)" means NetworkManager only sees configuration
    # applied by someone else, so it has no connection of its own to switch.
    unmanaged | "connected (externally)") managed=0 ;;
  esac

  printf 'DEV\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(san "$iface")" "$(san "$type")" "$(san "$state")" \
    "$(san "$connection")" "$(san "$ip")" "$(san "$prefix")" \
    "$(san "$gateway")" "$(san "$dns")" "$(san "$mac")" "$managed"

  # All addresses on the device, not just the primary one nmcli gave us.
  emit_addresses "$iface"
}

# Wired hardware straight from the kernel, for when nmcli is missing or has
# nothing to report. Only interfaces with a backing device are listed, which
# leaves out bridges, veth pairs and tunnels; wireless NICs are left to the
# Wi-Fi tab and need NetworkManager anyway.
snapshot_kernel_ethernet() {
  have ip || return 0
  local iface oper mac address gateway ip prefix
  while IFS= read -r iface; do
    [[ -z $iface || $iface == lo ]] && continue
    [[ -e /sys/class/net/$iface/device ]] || continue
    [[ -e /sys/class/net/$iface/wireless || -e /sys/class/net/$iface/phy80211 ]] && continue

    oper=$(link_state "$iface")
    mac=""
    [[ -r /sys/class/net/$iface/address ]] && mac=$(cat "/sys/class/net/$iface/address")

    address=""
    gateway=""
    if [[ -n $oper && $oper != down ]]; then
      address=$(ip -o -4 addr show dev "$iface" scope global 2>/dev/null |
        awk '{ print $4; exit }')
      gateway=$(ip -4 route show default dev "$iface" 2>/dev/null |
        awk '{ print $3; exit }')
    fi
    ip=""
    prefix=""
    if [[ -n $address ]]; then
      ip=${address%%/*}
      [[ $address == */* ]] && prefix=${address#*/}
    fi

    printf 'DEV\t%s\tethernet\t%s\t\t%s\t%s\t%s\t%s\t%s\t0\n' \
      "$(san "$iface")" "$(san "${oper:-unknown}")" "$(san "$ip")" \
      "$(san "$prefix")" "$(san "$gateway")" "$(san "$(link_dns "$iface")")" \
      "$(san "$mac")"
    emit_addresses "$iface"
  done < <(ip -o link show 2>/dev/null |
    awk -F': ' '{ split($2, name, "@"); print name[1] }')
  return 0
}

snapshot_network() {
  devices_emitted=0

  if ! have nmcli; then
    printf 'WIFI-ON\t0\n'
    snapshot_kernel_ethernet
    err "NetworkManager (nmcli) is not installed - showing kernel interfaces read-only"
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

  # nmcli reported no wired or wireless device at all (NetworkManager stopped,
  # or no device it manages): the kernel list keeps the Ethernet tab populated
  # instead of claiming there is no wired device.
  if ((devices_emitted == 0)); then
    snapshot_kernel_ethernet
    err "NetworkManager reported no devices - showing kernel interfaces read-only"
  fi

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
    note "bluetoothctl (bluez) is not installed" bluetooth
    return 0
  fi

  local show powered=0 discovering=0 controller="" alias=""
  show=$(bt show)
  if [[ -z $show ]]; then
    printf 'BT-ON\t0\nBT-SCAN\t0\nBT-CTL\t\t\n'
    note "No Bluetooth adapter found" bluetooth
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

# ------------------------------------------------------- virtual networks --

# Tailscale: the backend state and the tailnet peers, so the tab can list them
# next to the tunnel interface. Peers come from the plain status table: IP,
# hostname, user, OS, then the connection state.
snapshot_tailscale() {
  have tailscale || return 0

  local state
  state=$(timeout 4 tailscale status --json 2>/dev/null |
    sed -n 's/.*"BackendState":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [[ -n $state ]] && printf 'TS-STATE\t%s\n' "$(san "$state")"

  local auth_url
  if have jq; then
    auth_url=$(timeout 4 tailscale status --json 2>/dev/null | jq -r '.AuthURL // empty' 2>/dev/null)
  else
    auth_url=$(timeout 4 tailscale status --json 2>/dev/null |
      sed -n 's/.*"AuthURL":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  fi
  [[ -n $auth_url ]] && printf 'TS-AUTH\t%s\n' "$(san "$auth_url")"

  timeout 4 tailscale status 2>/dev/null |
    awk '
      $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
        online = 1
        for (i = 5; i <= NF; i++) if ($i ~ /^offline/) online = 0
        printf "TSPEER\t%s\t%s\t%s\t%s\t%s\n", $2, $1, online, $4,
          (NR == 1 ? 1 : 0)
      }'

  # Exit node candidates. jq is the only reliable way to read the peer list;
  # without it the tab simply leaves the section out.
  if have jq; then
    timeout 4 tailscale status --json 2>/dev/null |
      jq -r '.Peer[]? | select(.ExitNodeOption == true) |
        [.HostName, (.TailscaleIPs[0] // ""),
         (if .ExitNode then "1" else "0" end)] | @tsv' 2>/dev/null |
      while IFS=$'\t' read -r name ip selected; do
        [[ -z ${name:-} ]] && continue
        printf 'TS-EXIT\t%s\t%s\t%s\n' "$(san "$name")" "$(san "${ip:-}")" "${selected:-0}"
      done
  fi
  return 0
}

# Containers per engine, running or not, then the live resource use of the
# running ones. `|` is the delimiter: none of these fields contain a pipe, and
# both docker and podman render the same Go templates.
snapshot_containers() {
  local kind name state status runtime cpu mem
  for kind in docker podman; do
    have "$kind" || continue
    # `info` is the only call that answers only while the daemon runs, so the
    # tab's power switch reflects the engine rather than the binary.
    if timeout 3 "$kind" info >/dev/null 2>&1; then
      printf 'BOXENGINE\t%s\t1\n' "$kind"
    else
      printf 'BOXENGINE\t%s\t0\n' "$kind"
    fi
    timeout 4 "$kind" ps -a --format '{{.Names}}|{{.State}}|{{.Status}}' 2>/dev/null |
      while IFS='|' read -r name state status; do
        [[ -z ${name:-} ]] && continue
        if [[ $status == Up* ]]; then
          # "Up 2 hours (healthy)" -> "2 hours".
          runtime=${status#Up }
          runtime=${runtime%% (*}
        elif [[ $status == Exited* || $status == Dead* ]]; then
          # "Exited (0) 5 minutes ago" -> "5 minutes ago".
          runtime=$(printf '%s' "$status" |
            sed -E 's/^[^(]*\([^)]*\)[[:space:]]*//')
        else
          runtime=""
        fi
        printf 'BOX\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$(san "$name")" \
          "$(san "${state:-}")" "$(san "${status:-}")" "$(san "${runtime:-}")"
      done
    timeout 8 "$kind" stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}' 2>/dev/null |
      while IFS='|' read -r name cpu mem; do
        [[ -z ${name:-} ]] && continue
        printf 'BOXSTAT\t%s\t%s\t%s\t%s\n' "$kind" "$(san "$name")" \
          "$(san "${cpu:-}")" "$(san "${mem%% / *}")"
      done
  done
  return 0
}

# Tunnels and bridges report operstate "unknown", so fall back to the
# interface flags: IFF_UP means the link is up.
link_state() {
  local iface="$1" state flags
  state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
  if [[ -z $state || $state == unknown ]]; then
    flags=$(cat "/sys/class/net/$iface/flags" 2>/dev/null)
    flags=${flags#0x}
    if [[ -n $flags ]] && (((16#$flags & 0x1) == 1)); then
      state=up
    else
      state=${state:-unknown}
    fi
  fi
  printf '%s' "$state"
}

# Links NetworkManager does not manage: tailscale0, the docker bridges and the
# podman bridges. They are read from the kernel, so they appear whether or not
# their daemon happens to be running, together with every address they carry.
snapshot_extras() {
  local iface kind
  if have ip; then
    while IFS= read -r iface; do

      [[ -z $iface ]] && continue
      case "$iface" in
        tailscale*) kind=tailscale ;;
        docker* | br-*) kind=docker ;;
        podman* | cni-podman*) kind=podman ;;
        *) continue ;;
      esac
      printf 'LINK\t%s\t%s\t%s\n' "$kind" "$(san "$iface")" "$(san "$(link_state "$iface")")"
      emit_addresses "$iface"
    done < <(ip -o link show 2>/dev/null |
      awk -F': ' '{ split($2, name, "@"); print name[1] }')
  fi

  # Installed tooling keeps its tab available even when no link is up yet.
  have tailscale && printf 'FEATURE\ttailscale\n'
  have docker && printf 'FEATURE\tdocker\n'
  have podman && printf 'FEATURE\tpodman\n'

  snapshot_tailscale
  snapshot_containers

  return 0
}

snapshot() {
  snapshot_network
  snapshot_extras
  snapshot_bluetooth
}

# The subset the Waybar module renders: its icon and tooltip read the DEV, WIFI,
# WIFI-ON, BT-ON and BTDEV records only. Waybar runs `status` once a second, and
# the container and tailnet probes behind snapshot_extras are far too expensive
# at that rate for records nothing draws - `docker stats` alone takes a second
# or more.
snapshot_status() {
  snapshot_network
  snapshot_bluetooth
}

# -------------------------------------------------------- tailscale ssh --

ts_hosts_file() {
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s' "$cfg_home/hypr/UserConfigs/tailscale-hosts.json"
}

ts_log_file() {
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  printf '%s' "$state_home/hypr/tailscale-ssh.log"
}

log_ts_ssh_error() {
  local host="${1:-}" ip="${2:-}" port="${3:-22}" user="${4:-}" msg="${5:-}"
  local log_file
  log_file=$(ts_log_file)
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] [ERROR] Host: %s (%s:%s) User: %s - %s\n' \
    "$ts" "$host" "$ip" "$port" "$user" "$msg" >> "$log_file"

  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/error.png"
  if [[ ! -f "$icon" && -f "$script_dir/../../swaync/images/error.png" ]]; then
    icon="$script_dir/../../swaync/images/error.png"
  fi
  if have notify-send; then
    if [[ -f "$icon" ]]; then
      notify-send -u normal -i "$icon" "Tailscale SSH Error" "$host: $msg"
    else
      notify-send -u normal "Tailscale SSH Error" "$host: $msg"
    fi
  fi
}

log_ts_ssh_info() {
  local msg="${1:-}"
  local log_file
  log_file=$(ts_log_file)
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] [INFO] %s\n' "$ts" "$msg" >> "$log_file"
}

open_auth_url_if_found() {
  local output="${1:-}"
  local url
  url=$(printf '%s\n' "$output" | grep -Eo 'https://login\.tailscale\.com/[^[:space:]"'\''<>]+' | head -n 1)
  if [[ -z $url ]]; then
    url=$(printf '%s\n' "$output" | grep -Eo 'https://[^[:space:]"'\''<>]+\.tailscale\.com/[^[:space:]"'\''<>]+' | head -n 1)
  fi
  if [[ -n $url ]]; then
    if have xdg-open; then
      xdg-open "$url" >/dev/null 2>&1 &
    elif have gio; then
      gio open "$url" >/dev/null 2>&1 &
    fi
    local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/info.png"
    if have notify-send; then
      if [[ -f "$icon" ]]; then
        notify-send -u normal -i "$icon" "Tailscale Authentication" "Opened browser to authenticate:\n$url"
      else
        notify-send -u normal "Tailscale Authentication" "Opened browser to authenticate:\n$url"
      fi
    fi
    log_ts_ssh_info "Captured Tailscale authentication URL and opened browser: $url"
    return 0
  fi
  return 1
}

list_installed_terminals() {
  local -a candidates=(kitty ghostty alacritty foot wezterm konsole gnome-terminal xfce4-terminal ptyxis urxvt xterm warp-terminal)
  local -A seen=()
  local -a discovered=()
  local c

  # First check well-known terminals
  for c in "${candidates[@]}"; do
    if have "$c"; then
      discovered+=("$c")
      seen["$c"]=1
    fi
  done

  # Scan .desktop files for TerminalEmulator category
  local d_dirs=(
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    "/usr/local/share/applications"
    "/usr/share/applications"
    "/var/lib/flatpak/exports/share/applications"
  )
  local d
  for d in "${d_dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r f; do
      if grep -q -E "^Categories=.*TerminalEmulator" "$f" 2>/dev/null; then
        local exec_line bin next_arg
        exec_line=$(grep -E '^Exec=' "$f" 2>/dev/null | head -n1 | sed -e 's/^Exec=//' -e 's/ %[a-zA-Z]//g')
        read -r bin next_arg _ <<< "$exec_line"
        bin="$(basename "${bin//\"/}")"
        bin="${bin//\'/}"
        if [[ "$bin" == "env" && -n "${next_arg:-}" ]]; then
          bin="$(basename "${next_arg//\"/}")"
          bin="${bin//\'/}"
        fi
        [[ "$bin" == "env" ]] && continue
        if [[ -n "$bin" && -z "${seen[$bin]:-}" ]] && have "$bin"; then
          discovered+=("$bin")
          seen["$bin"]=1
        fi
      fi
    done < <(find "$d" -maxdepth 2 -name "*.desktop" 2>/dev/null)
  done

  printf '%s\n' "${discovered[@]}"
}

# Open a command string in the preferred terminal. LaunchTerminal.sh builds the
# per-terminal -e/-- form, so container logs and shells open the same way the
# Tailscale SSH connection does.
launch_in_terminal() {
  local term_cmd="${1:-}" payload="${2:-}"
  [[ -n $payload ]] || return 2
  local launch_script="$script_dir/LaunchTerminal.sh"
  if [[ ! -x $launch_script && -f $launch_script ]]; then
    launch_script="$script_dir/LaunchTerminal.sh"
  fi
  [[ -n $term_cmd ]] || term_cmd="${TERMINAL:-kitty}"
  if [[ -x $launch_script ]]; then
    "$launch_script" "$term_cmd" "$payload"
    return
  fi
  have "$term_cmd" || term_cmd=kitty
  "$term_cmd" -e sh -c "$payload" >/dev/null 2>&1 &
}

# The viewer chain for container logs: lnav knows the format and can search
# and filter it, the rest open the file as text. $EDITOR comes second so the
# user's own choice wins over the built-in fallbacks.
log_viewer_command() {
  local file="$1" editor_cmd="${EDITOR:-}" editor_bin="" q_file candidate
  q_file="$(shell_quote "$file")"

  if have lnav; then
    printf 'lnav %s' "$q_file"
    return 0
  fi

  if [[ -n $editor_cmd ]]; then
    editor_bin="${editor_cmd%% *}"
    editor_bin="${editor_bin#\"}"
    editor_bin="${editor_bin%\"}"
    editor_bin="${editor_bin#\'}"
    editor_bin="${editor_bin%\'}"
    if [[ -n $editor_bin ]] && have "$editor_bin"; then
      printf '%s %s' "$editor_cmd" "$q_file"
      return 0
    fi
  fi

  for candidate in emacs hx nano more; do
    have "$candidate" || continue
    if [[ $candidate == emacs ]]; then
      # -nw keeps it inside the terminal the payload was launched in.
      printf 'emacs -nw %s' "$q_file"
    else
      printf '%s %s' "$candidate" "$q_file"
    fi
    return 0
  done

  # Last resort: the window reports that `more` is missing rather than the
  # click doing nothing at all.
  printf 'more %s' "$q_file"
}

# One log file per container under the runtime directory, so a second click
# rewrites the same path instead of leaving copies behind.
container_log_file() {
  local kind="$1" name="$2" dir
  dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell-network-widget"
  mkdir -p "$dir" 2>/dev/null || dir="${TMPDIR:-/tmp}"
  printf '%s/%s-%s.log' "$dir" "$kind" "${name//[^A-Za-z0-9_.-]/_}"
}

list_ssh_keys() {
  local ssh_dir="$HOME/.ssh"
  [[ -d "$ssh_dir" ]] || return 0
  local -a keys=()
  local f fname
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    fname="$(basename "$f")"
    case "$fname" in
      *.pub|known_hosts*|config*|authorized_keys*) continue ;;
      *)
        if [[ -r "$f" ]]; then
          keys+=("$f")
        fi
        ;;
    esac
  done < <(find "$ssh_dir" -maxdepth 1 -type f 2>/dev/null | sort)
  printf '%s\n' "${keys[@]}"
}

tailscale_ssh_test() {
  local host="${1:-}" ip="${2:-}" port="${3:-22}" user="${4:-$USER}" auth_type="${5:-key}" key_path="${6:-}"
  [[ -n "$ip" ]] || { printf 'Missing IP address\n' >&2; exit 2; }
  port="${port:-22}"
  user="${user:-$USER}"

  # Expand tilde in key_path
  if [[ "$key_path" == "~"* ]]; then
    key_path="${HOME}${key_path#\~}"
  fi

  # 1. Port reachability check
  local reachable=0
  if have nc; then
    if nc -z -w 3 "$ip" "$port" 2>/dev/null; then
      reachable=1
    fi
  else
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$ip/$port" 2>/dev/null; then
      reachable=1
    fi
  fi

  if ((reachable == 0)); then
    local err_msg="Port $port is unreachable or connection timed out on $ip"
    log_ts_ssh_error "$host" "$ip" "$port" "$user" "$err_msg"
    printf '%s\n' "$err_msg" >&2
    exit 1
  fi

  # 2. Key authentication test if key auth is selected
  if [[ "$auth_type" == "key" ]]; then
    if [[ -z "$key_path" || ! -f "$key_path" ]]; then
      local err_msg="SSH key file not found: ${key_path:-(none)}"
      log_ts_ssh_error "$host" "$ip" "$port" "$user" "$err_msg"
      printf '%s\n' "$err_msg" >&2
      exit 1
    fi

    local ssh_out ssh_rc
    ssh_out=$(timeout 5 ssh -o BatchMode=yes \
      -o ConnectTimeout=3 \
      -o StrictHostKeyChecking=accept-new \
      -p "$port" -i "$key_path" "$user@$ip" true 2>&1)
    ssh_rc=$?
    if open_auth_url_if_found "$ssh_out"; then
      printf 'Authentication required: opened browser to authenticate\n'
      exit 0
    fi
    if [[ $ssh_rc -ne 0 ]]; then
      local err_msg="SSH authentication failed (exit $ssh_rc): ${ssh_out:-Permission denied}"
      log_ts_ssh_error "$host" "$ip" "$port" "$user" "$err_msg"
      printf '%s\n' "$err_msg" >&2
      exit 1
    fi
  fi

  log_ts_ssh_info "Connection test succeeded for $host ($ip:$port, auth: $auth_type)"
  printf 'OK\n'
  exit 0
}

tailscale_ssh_connect() {
  local host="${1:-}" ip="${2:-}" port="${3:-22}" user="${4:-$USER}" terminal="${5:-}" auth_type="${6:-key}" key_path="${7:-}"
  [[ -n "$ip" ]] || { printf 'Missing IP address\n' >&2; exit 2; }
  port="${port:-22}"
  user="${user:-$USER}"

  if [[ "$key_path" == "~"* ]]; then
    key_path="${HOME}${key_path#\~}"
  fi

  local ssh_cmd
  if [[ "$auth_type" == "key" && -n "$key_path" ]]; then
    ssh_cmd="ssh -p $port -i \"$key_path\" \"$user@$ip\""
  else
    ssh_cmd="ssh -p $port \"$user@$ip\""
  fi

  local launch_script="$script_dir/LaunchTerminal.sh"
  if [[ ! -x "$launch_script" && -f "$script_dir/LaunchTerminal.sh" ]]; then
    launch_script="$script_dir/LaunchTerminal.sh"
  fi

  local term_cmd="${terminal:-}"
  if [[ -z "$term_cmd" ]]; then
    term_cmd="${TERMINAL:-kitty}"
  fi

  if [[ -x "$launch_script" ]]; then
    if ! "$launch_script" "$term_cmd" "$ssh_cmd"; then
      local err_msg="Failed to launch terminal '$term_cmd' for $host"
      log_ts_ssh_error "$host" "$ip" "$port" "$user" "$err_msg"
      printf '%s\n' "$err_msg" >&2
      exit 1
    fi
  else
    if ! have "$term_cmd"; then
      term_cmd="kitty"
    fi
    "$term_cmd" -e sh -c "$ssh_cmd" >/dev/null 2>&1 &
  fi

  log_ts_ssh_info "Launched SSH connection to $host ($ip:$port) via $term_cmd"
  exit 0
}

tailscale_save_host() {
  local host_key="${1:-}" host_json="${2:-}"
  [[ -n "$host_key" && -n "$host_json" ]] || { printf 'usage: tailscale-save-host KEY JSON\n' >&2; exit 2; }
  local target_file
  target_file=$(ts_hosts_file)
  mkdir -p "$(dirname "$target_file")" 2>/dev/null || true

  if [[ ! -f "$target_file" ]]; then
    printf '{"version":1,"hosts":{}}\n' > "$target_file"
  fi

  if have jq; then
    local updated
    updated=$(jq --arg key "$host_key" --argjson data "$host_json" '.hosts[$key] = $data' "$target_file" 2>/dev/null)
    if [[ -n "$updated" ]]; then
      printf '%s\n' "$updated" > "$target_file"
      log_ts_ssh_info "Saved host configuration for $host_key"
      exit 0
    fi
  fi

  # Fallback to python3 if jq fails
  if have python3; then
    python3 -c "
import json, sys
fpath = '$target_file'
try:
    with open(fpath, 'r') as fp:
        doc = json.load(fp)
except Exception:
    doc = {'version': 1, 'hosts': {}}
if 'hosts' not in doc:
    doc['hosts'] = {}
doc['hosts']['$host_key'] = json.loads(sys.argv[1])
with open(fpath, 'w') as fp:
    json.dump(doc, fp, indent=2)
" "$host_json"
    log_ts_ssh_info "Saved host configuration for $host_key"
    exit 0
  fi

  printf 'Unable to save host configuration: jq or python3 required\n' >&2
  exit 1
}

tailscale_export_config() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/tailscale-hosts-export.json"
  fi
  if [[ "$target" == "~"* ]]; then
    target="${HOME}${target#\~}"
  fi

  local src
  src=$(ts_hosts_file)
  if [[ ! -f "$src" ]]; then
    printf '{"version":1,"hosts":{}}\n' > "$src"
  fi

  mkdir -p "$(dirname "$target")" 2>/dev/null || true
  cp -f "$src" "$target"
  log_ts_ssh_info "Exported Tailscale host configuration to $target"

  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
  if have notify-send; then
    if [[ -f "$icon" ]]; then
      notify-send -u low -i "$icon" "Tailscale Config" "Exported configuration to $(basename "$target")"
    else
      notify-send -u low "Tailscale Config" "Exported configuration to $(basename "$target")"
    fi
  fi
  printf '%s\n' "$target"
  exit 0
}

tailscale_import_config() {
  local source="${1:-}"
  [[ -n "$source" ]] || { printf 'Missing source configuration file\n' >&2; exit 2; }
  if [[ "$source" == "~"* ]]; then
    source="${HOME}${source#\~}"
  fi

  if [[ ! -f "$source" ]]; then
    local err_msg="Import file does not exist: $source"
    log_ts_ssh_error "import" "-" "-" "-" "$err_msg"
    printf '%s\n' "$err_msg" >&2
    exit 1
  fi

  local valid=0
  if have jq; then
    jq -e '.hosts' "$source" >/dev/null 2>&1 && valid=1
  elif have python3; then
    python3 -c "import json; d = json.load(open('$source')); assert 'hosts' in d" >/dev/null 2>&1 && valid=1
  fi

  if ((valid == 0)); then
    local err_msg="Invalid configuration file format (missing 'hosts' dictionary)"
    log_ts_ssh_error "import" "-" "-" "-" "$err_msg"
    printf '%s\n' "$err_msg" >&2
    exit 1
  fi

  local target
  target=$(ts_hosts_file)
  mkdir -p "$(dirname "$target")" 2>/dev/null || true
  if [[ ! -f "$target" ]]; then
    printf '{"version":1,"hosts":{}}\n' > "$target"
  fi

  # Merge source into target
  if have jq; then
    local merged
    merged=$(jq -s '.[0] * .[1]' "$target" "$source" 2>/dev/null)
    if [[ -n "$merged" ]]; then
      printf '%s\n' "$merged" > "$target"
    fi
  elif have python3; then
    python3 -c "
import json
with open('$target', 'r') as fp:
    base = json.load(fp)
with open('$source', 'r') as fp:
    incoming = json.load(fp)
if 'hosts' not in base: base['hosts'] = {}
base['hosts'].update(incoming.get('hosts', {}))
with open('$target', 'w') as fp:
    json.dump(base, fp, indent=2)
"
  fi

  log_ts_ssh_info "Imported Tailscale host configuration from $source"
  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
  if have notify-send; then
    if [[ -f "$icon" ]]; then
      notify-send -u low -i "$icon" "Tailscale Config" "Imported configuration successfully"
    else
      notify-send -u low "Tailscale Config" "Imported configuration successfully"
    fi
  fi
  printf 'OK\n'
  exit 0
}

tailscale_read_logs() {
  local format="${1:-text}"
  local log_file
  log_file=$(ts_log_file)
  if [[ ! -f "$log_file" ]]; then
    if [[ "$format" == "json" ]]; then
      printf '[]\n'
    else
      printf 'No logs recorded yet.\n'
    fi
    exit 0
  fi

  if [[ "$format" == "json" ]]; then
    if have jq; then
      awk '
        match($0, /^\[([0-9: -]+)\] \[([A-Z]+)\] (.*)$/, arr) {
          msg = arr[3]
          gsub(/"/, "\\\"", msg)
          printf "{\"timestamp\":\"%s\",\"level\":\"%s\",\"message\":\"%s\"}\n", arr[1], arr[2], msg
        }' "$log_file" | jq -s '.'
    else
      python3 -c "
import json, re
res = []
pattern = re.compile(r'^\[(.*?)\] \[(.*?)\] (.*)$')
try:
    with open('$log_file') as fp:
        for line in fp:
            m = pattern.match(line.strip())
            if m:
                res.append({'timestamp': m.group(1), 'level': m.group(2), 'message': m.group(3)})
except Exception:
    pass
print(json.dumps(res))
"
    fi
  else
    tail -n 120 "$log_file"
  fi
  exit 0
}

tailscale_save_logs_to_disk() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    target="$HOME/tailscale-ssh-$(date +%Y%m%d-%H%M%S).log"
  fi
  if [[ "$target" == "~"* ]]; then
    target="${HOME}${target#\~}"
  fi

  local log_file
  log_file=$(ts_log_file)
  if [[ ! -f "$log_file" ]]; then
    printf 'No logs recorded yet\n' >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target")" 2>/dev/null || true
  cp -f "$log_file" "$target"
  log_ts_ssh_info "Saved Tailscale SSH log to $target"

  local icon="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/ja.png"
  if have notify-send; then
    if [[ -f "$icon" ]]; then
      notify-send -u low -i "$icon" "Tailscale Logs" "Saved log to $(basename "$target")"
    else
      notify-send -u low "Tailscale Logs" "Saved log to $(basename "$target")"
    fi
  fi
  printf '%s\n' "$target"
  exit 0
}

# -------------------------------------------------------- main router --

waybar_status() {
  local snapshot_text
  snapshot_text=$(snapshot_status)

  local eth="" wifi_ssid="" wifi_signal="0" wifi_on="0" bt_on="0"
  local -a bt_names=()
  local key f1 f2 f3 f4 f5 f6
  while IFS=$'\t' read -r key f1 f2 f3 f4 f5 f6; do
    case "$key" in
      DEV)
        # A wired device counts when NetworkManager calls it connected, or when
        # it carries an address but is managed elsewhere (ifupdown in some VM
        # images, or the kernel fallback when nmcli is unavailable), so the
        # module shows the wired icon there too.
        if [[ $f2 == ethernet ]] && { [[ $f3 == connected* ]] || [[ -n ${f5:-} ]]; }; then
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
  if ! have nmcli; then
    lines+=("NetworkManager (nmcli) is not installed")
  fi
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

# One desktop notification per session while NetworkManager is missing, so
# opening the panel repeatedly does not spam the desktop.
warn_missing_nm() {
  have nmcli && return 0
  have notify-send || return 0
  local stamp="${XDG_RUNTIME_DIR:-/tmp}/qs-network-widget-no-nm"
  [[ -e $stamp ]] && return 0
  : >"$stamp" 2>/dev/null
  notify "Network widget" \
    "NetworkManager (nmcli) is not installed. Wired devices are shown from the kernel, read-only."
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
    qs_ipc ready && return 0
  done
  notify "Network widget" "Quickshell did not start. See 'quickshell -p $widget_dir'."
  printf 'quickshell did not start\n' >&2
  return 1
}

toggle_panel() {
  warn_missing_nm
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
    warn_missing_nm
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
  container)
    case "${2:-}" in
      docker | podman) ;;
      *) printf 'usage: %s container docker|podman start|stop|restart|logs|shell NAME\n' "$0" >&2; exit 2 ;;
    esac
    case "${3:-}" in
      start | stop | restart | logs | shell) ;;
      *) printf 'usage: %s container docker|podman start|stop|restart|logs|shell NAME\n' "$0" >&2; exit 2 ;;
    esac
    [[ -n ${4:-} ]] || { printf 'usage: %s container docker|podman start|stop|restart|logs|shell NAME\n' "$0" >&2; exit 2; }
    have "$2" || { printf '%s is not installed\n' "$2" >&2; exit 1; }
    case "$3" in
      start | stop | restart) timeout 60 "$2" "$3" "$4" ;;
      # Logs are captured to a file first: a viewer can search and filter it,
      # a bare stream cannot. The shell stays interactive.
      logs)
        log_file="$(container_log_file "$2" "$4")"
        tail_lines="${QS_CONTAINER_LOG_LINES:-2000}"
        if [[ ${5:-} == live ]]; then
          # Live mode follows the stream instead of a snapshot. lnav reads the
          # pipe, so quitting it ends the engine's stream with it.
          if have lnav; then
            launch_in_terminal "" "$2 logs --tail $tail_lines -f $(shell_quote "$4") | lnav"
          else
            launch_in_terminal "" "$2 logs --tail $tail_lines -f $(shell_quote "$4")"
          fi
        else
          timeout 60 "$2" logs --tail "$tail_lines" "$4" >"$log_file" 2>&1
          launch_in_terminal "" "$(log_viewer_command "$log_file")"
        fi
        ;;
      # bash where the image has it, sh otherwise: slim images ship only sh,
      # and a plain `exec bash` would leave the window on a not-found error.
      shell)
        shell_cmd='exec bash 2>/dev/null || exec sh'
        launch_in_terminal "${5:-}" "$2 exec -it $(shell_quote "$4") sh -c $(shell_quote "$shell_cmd")"
        ;;
    esac
    ;;
  container-engine)
    case "${2:-}" in
      docker | podman) ;;
      *) printf 'usage: %s container-engine docker|podman on|off\n' "$0" >&2; exit 2 ;;
    esac
    case "${3:-}" in
      on | off) ;;
      *) printf 'usage: %s container-engine docker|podman on|off\n' "$0" >&2; exit 2 ;;
    esac
    have "$2" || { printf '%s is not installed\n' "$2" >&2; exit 1; }
    engine_unit=$2
    [[ $2 == podman ]] && engine_unit=podman.socket
    engine_verb=start
    [[ $3 == off ]] && engine_verb=stop
    # Rootless engines are user units; a root daemon needs root. Try the user
    # unit first so a rootless install never prompts for a password.
    if systemctl --user "$engine_verb" "$engine_unit" >/dev/null 2>&1; then
      :
    elif have pkexec; then
      pkexec systemctl "$engine_verb" "$engine_unit"
    elif sudo -n true 2>/dev/null; then
      sudo -n systemctl "$engine_verb" "$engine_unit"
    else
      printf 'root privileges are required to %s %s\n' "$engine_verb" "$engine_unit" >&2
      exit 1
    fi
    ;;
  tailscale)
    have tailscale || { printf 'tailscale is not installed\n' >&2; exit 1; }
    case "${2:-}" in
      up | down)
        local out rc
        out=$(timeout 30 tailscale "$2" 2>&1)
        rc=$?
        open_auth_url_if_found "$out" || true
        if [[ $rc -ne 0 && ($out == *"Access denied"* || $out == *"sudo tailscale"*) ]]; then
          if have pkexec; then
            out=$(timeout 30 pkexec tailscale set --operator="$USER" 2>&1) && \
            out=$(timeout 30 tailscale "$2" 2>&1)
            rc=$?
            open_auth_url_if_found "$out" || true
            if [[ $rc -ne 0 ]]; then
              out=$(timeout 30 pkexec tailscale "$2" 2>&1)
              rc=$?
              open_auth_url_if_found "$out" || true
            fi
          elif sudo -n true 2>/dev/null; then
            sudo tailscale set --operator="$USER" 2>/dev/null || true
            out=$(timeout 30 sudo tailscale "$2" 2>&1)
            rc=$?
            open_auth_url_if_found "$out" || true
          fi
        fi
        if [[ $rc -ne 0 ]]; then
          printf '%s\n' "$out" >&2
          exit $rc
        fi
        ;;
      exit-node)
        [[ -n ${3:-} ]] || { printf 'usage: %s tailscale exit-node NAME|none\n' "$0" >&2; exit 2; }
        local arg
        if [[ $3 == none ]]; then
          arg="--exit-node="
        else
          arg="--exit-node=$3"
        fi
        local out rc
        out=$(timeout 30 tailscale set "$arg" 2>&1)
        rc=$?
        if [[ $rc -ne 0 && ($out == *"Access denied"* || $out == *"sudo tailscale"*) ]]; then
          if have pkexec; then
            out=$(timeout 30 pkexec tailscale set "$arg" 2>&1)
            rc=$?
          elif sudo -n true 2>/dev/null; then
            out=$(timeout 30 sudo tailscale set "$arg" 2>&1)
            rc=$?
          fi
        fi
        if [[ $rc -ne 0 ]]; then
          printf '%s\n' "$out" >&2
          exit $rc
        fi
        ;;
      suggest)
        # The command only prints prose, so the suggestion is matched against
        # the exit node names and addresses we already know about.
        have jq || { printf 'jq is required for exit node suggestions\n' >&2; exit 1; }
        suggestion=$(timeout 15 tailscale exit-node suggest 2>&1) || true
        name=$(timeout 10 tailscale status --json 2>/dev/null |
          jq -r '.Peer[]? | select(.ExitNodeOption == true) |
            [.HostName, (.TailscaleIPs[0] // "")] | @tsv' 2>/dev/null |
          while IFS=$'\t' read -r host ip; do
            [[ -n ${host:-} ]] || continue
            if [[ $suggestion == *"$host"* ]] || [[ -n ${ip:-} && $suggestion == *"$ip"* ]]; then
              printf '%s\n' "$host"
              break
            fi
          done)
        [[ -n $name ]] || { printf 'No exit node suggestion is available\n' >&2; exit 1; }
        timeout 30 tailscale set --exit-node="$name"
        ;;
      *)
        printf 'usage: %s tailscale up|down|exit-node NAME|none|suggest\n' "$0" >&2
        exit 2
        ;;
    esac
    ;;
  tailscale-list-terminals)
    list_installed_terminals
    ;;
  tailscale-list-keys)
    list_ssh_keys
    ;;
  tailscale-ssh-test)
    shift
    tailscale_ssh_test "$@"
    ;;
  tailscale-ssh-connect)
    shift
    tailscale_ssh_connect "$@"
    ;;
  tailscale-save-host)
    shift
    tailscale_save_host "$@"
    ;;
  tailscale-export)
    shift
    tailscale_export_config "${1:-}"
    ;;
  tailscale-import)
    shift
    tailscale_import_config "${1:-}"
    ;;
  tailscale-logs)
    shift
    tailscale_read_logs "${1:-text}"
    ;;
  tailscale-log-save)
    shift
    tailscale_save_logs_to_disk "${1:-}"
    ;;
  tailscale-open-url)
    shift
    [[ -n ${1:-} ]] || exit 2
    if have xdg-open; then
      xdg-open "$1" >/dev/null 2>&1 &
    elif have gio; then
      gio open "$1" >/dev/null 2>&1 &
    fi
    exit 0
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
    printf 'usage: %s [snapshot|status|toggle|open|close|wifi|scan-wifi|connect-wifi|disconnect-wifi|connect-device|disconnect-device|bt-power|bt-scan|bt|container|container-engine|tailscale|tailscale-list-terminals|tailscale-list-keys|tailscale-ssh-test|tailscale-ssh-connect|tailscale-save-host|tailscale-export|tailscale-import|tailscale-logs|tailscale-log-save|tailscale-open-url]\n' "$0" >&2
    exit 2
    ;;
esac
