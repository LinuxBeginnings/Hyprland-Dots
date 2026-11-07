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
#   BOXSTAT  <kind> <name> <cpu> <mem>
#   WIFI     <ssid> <signal> <security> <in-use 0|1>
#   WIFI-ON  <0|1>
#   BT-ON    <0|1>
#   BT-SCAN  <0|1>
#   BT-CTL   <alias> <address>
#   BTDEV    <address> <name> <connected 0|1> <paired 0|1> <battery|-> <icon>
#   NOTE     <message>
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

note() { printf 'NOTE\t%s\n' "$(san "$1")"; }
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

# ------------------------------------------------------------------ waybar --

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
      *) printf 'usage: %s container docker|podman start|stop|restart NAME\n' "$0" >&2; exit 2 ;;
    esac
    case "${3:-}" in
      start | stop | restart) ;;
      *) printf 'usage: %s container docker|podman start|stop|restart NAME\n' "$0" >&2; exit 2 ;;
    esac
    [[ -n ${4:-} ]] || { printf 'usage: %s container docker|podman start|stop|restart NAME\n' "$0" >&2; exit 2; }
    have "$2" || { printf '%s is not installed\n' "$2" >&2; exit 1; }
    timeout 60 "$2" "$3" "$4"
    ;;
  tailscale)
    have tailscale || { printf 'tailscale is not installed\n' >&2; exit 1; }
    case "${2:-}" in
      up | down) timeout 30 tailscale "$2" ;;
      exit-node)
        [[ -n ${3:-} ]] || { printf 'usage: %s tailscale exit-node NAME|none\n' "$0" >&2; exit 2; }
        if [[ $3 == none ]]; then
          timeout 30 tailscale set --exit-node=
        else
          timeout 30 tailscale set --exit-node="$3"
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
    printf 'usage: %s [snapshot|status|toggle|open|close|wifi|scan-wifi|connect-wifi|disconnect-wifi|connect-device|disconnect-device|bt-power|bt-scan|bt|container|tailscale]\n' "$0" >&2
    exit 2
    ;;
esac
