#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Persist active monitor/workspace layout back into ~/.config/hypr/workspaces.conf.

set -u

quiet_mode=0
layout_override=""
workspace_override=""
monitor_override=""
workspaces_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/workspaces.conf"

usage() {
  cat <<'EOF'
Usage: PersistWorkspaceLayout.sh [--quiet] [--layout <layout>] [--workspace <selector>] [--monitor <monitor>] [--file <path>]
  --quiet              Suppress console notifications.
  --layout <layout>    Override layout (master|dwindle|scrolling|monocle).
  --workspace <sel>    Override workspace selector (e.g. 5, name:code, special:scratchpad).
  --monitor <name>     Override monitor name.
  --file <path>        Target workspace rules file (default: ~/.config/hypr/workspaces.conf).
EOF
}

normalize_layout() {
  case "$1" in
  master | dwindle | scrolling | monocle)
    printf '%s\n' "$1"
    ;;
  *)
    printf '\n'
    ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

get_active_workspace_json() {
  hyprctl -j activeworkspace 2>/dev/null || printf '{}'
}

get_workspace_selector() {
  local ws_json="$1"
  local ws_id ws_name

  ws_id="$(jq -r '.id // empty' <<<"$ws_json" 2>/dev/null || true)"
  ws_name="$(jq -r '.name // empty' <<<"$ws_json" 2>/dev/null || true)"

  if [[ "$ws_id" =~ ^[0-9]+$ ]] && ((ws_id > 0)); then
    printf '%s\n' "$ws_id"
    return 0
  fi

  if [[ -n "$ws_name" && "$ws_name" != "null" ]]; then
    if [[ "$ws_name" == name:* || "$ws_name" == special:* ]]; then
      printf '%s\n' "$ws_name"
    else
      printf 'name:%s\n' "$ws_name"
    fi
    return 0
  fi

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --quiet | --no-notify)
    quiet_mode=1
    shift
    ;;
  --layout)
    layout_override="${2:-}"
    shift 2
    ;;
  --workspace)
    workspace_override="${2:-}"
    shift 2
    ;;
  --monitor)
    monitor_override="${2:-}"
    shift 2
    ;;
  --file)
    workspaces_file="${2:-}"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

require_cmd hyprctl
require_cmd jq
require_cmd awk
require_cmd mktemp

ws_json="$(get_active_workspace_json)"
workspace_selector="${workspace_override:-$(get_workspace_selector "$ws_json" || true)}"
monitor_name="${monitor_override:-$(jq -r '.monitor // empty' <<<"$ws_json" 2>/dev/null || true)}"

if [[ -n "$layout_override" ]]; then
  layout_name="$(normalize_layout "$layout_override")"
else
  layout_name="$(jq -r '.tiledLayout // .tiled_layout // empty' <<<"$ws_json" 2>/dev/null || true)"
  layout_name="$(normalize_layout "$layout_name")"
  if [[ -z "$layout_name" ]]; then
    layout_name="$(hyprctl -j getoption general:layout 2>/dev/null | jq -r '.str // empty' 2>/dev/null || true)"
    layout_name="$(normalize_layout "$layout_name")"
  fi
fi

if [[ -z "$workspace_selector" || -z "$monitor_name" || -z "$layout_name" ]]; then
  echo "Unable to resolve workspace, monitor, or layout for persistence" >&2
  exit 1
fi

mkdir -p "$(dirname "$workspaces_file")"
touch "$workspaces_file"

tmp_file="$(mktemp "${workspaces_file}.XXXXXX")"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

awk \
  -v target_ws="$workspace_selector" \
  -v target_mon="$monitor_name" \
  -v target_layout="$layout_name" '
function trim(v) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
  return v
}
BEGIN {
  updated = 0
}
{
  line = $0
  content = line
  comment = ""
  hash_pos = index(line, "#")
  if (hash_pos > 0) {
    content = substr(line, 1, hash_pos - 1)
    comment = substr(line, hash_pos)
  }
  stripped = trim(content)
  indent_len = match(line, /[^[:space:]]/) - 1
  if (indent_len < 0) {
    indent_len = length(line)
  }
  indent = substr(line, 1, indent_len)

  if (stripped ~ /^workspace[[:space:]]*=/) {
    sub(/^workspace[[:space:]]*=[[:space:]]*/, "", stripped)
    token_count = split(stripped, tokens, /,/)
    ws = trim(tokens[1])
    mon = ""
    extras_count = 0
    delete extras

    for (i = 2; i <= token_count; i++) {
      token = trim(tokens[i])
      if (token == "") {
        continue
      }
      if (token ~ /^monitor:/) {
        mon = trim(substr(token, 9))
        continue
      }
      if (token ~ /^layout:/) {
        continue
      }
      extras[++extras_count] = token
    }

    if (ws == target_ws && mon == target_mon) {
      if (!updated) {
        rebuilt = indent "workspace = " ws ", monitor:" target_mon ", layout:" target_layout
        for (i = 1; i <= extras_count; i++) {
          rebuilt = rebuilt ", " extras[i]
        }
        if (comment != "") {
          rebuilt = rebuilt " " comment
        }
        print rebuilt
        updated = 1
      }
      next
    }
  }

  print line
}
END {
  if (!updated) {
    print "workspace = " target_ws ", monitor:" target_mon ", layout:" target_layout
  }
}
' "$workspaces_file" >"$tmp_file"

mv "$tmp_file" "$workspaces_file"
trap - EXIT

if [[ "$quiet_mode" -eq 0 ]]; then
  printf 'Saved workspace layout: %s @ %s -> %s\n' "$workspace_selector" "$monitor_name" "$layout_name"
fi
