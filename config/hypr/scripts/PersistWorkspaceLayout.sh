#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Persist the active workspace's layout into UserConfigs/workspaces.lua, the file
# lua/workspaces.lua loads on every config load. There is no hyprlang
# workspaces.conf any more: nothing reads one, so writing it only ever made a
# change look saved while nothing applied it.
#
# The rule written here names the workspace and the layout, never the monitor. A
# layout belongs to the workspace, not to the display it happened to be on, and
# binding the monitor here is what used to pin each workspace to whichever
# display it was on when its layout last changed - and to contradict the
# workspace -> display bindings in the same file (issue #162).

set -u

quiet_mode=0
layout_override=""
workspace_override=""
monitor_override=""
lua_workspaces_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/workspaces.lua"

usage() {
  cat <<'EOF'
Usage: PersistWorkspaceLayout.sh [--quiet] [--layout <layout>] [--workspace <selector>] [--monitor <monitor>] [--lua-file <path>]
  --quiet              Suppress console notifications.
  --layout <layout>    Override layout (master|dwindle|scrolling|monocle).
  --workspace <sel>    Override workspace selector (e.g. 5, name:code, special:scratchpad).
  --monitor <name>     Override monitor name. Reported only; the rule never binds it.
  --lua-file <path>    Target Lua workspace rules file (default: ~/.config/hypr/UserConfigs/workspaces.lua).
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
  --lua-file)
    lua_workspaces_file="${2:-}"
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

update_lua_workspaces() {
  local target_ws="$1"
  local target_layout="$2"
  local lua_file="$3"

  mkdir -p "$(dirname "$lua_file")"

  python3 - "$lua_file" "$target_ws" "$target_layout" <<'PY'
import sys
import re
from pathlib import Path

lua_path = Path(sys.argv[1])
target_ws = sys.argv[2].strip()
target_layout = sys.argv[3].strip()

header = """-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User workspace rules for Lua workflow.
-- PersistWorkspaceLayout.sh writes workspace layout rules into this file, and
-- DisplayProfile.sh imports nwg-displays' Workspace -> Output assignments here.
-- Keep custom hl.workspace_rule(...) entries here so upgrades preserve them.

"""

content = ""
if lua_path.exists():
    try:
        content = lua_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        content = ""

if not content.strip():
    content = header

pattern = re.compile(
    r'hl\.workspace_rule\(\s*\{([^}]+)\}\s*\)',
    re.MULTILINE | re.DOTALL
)


def strip_comments(src):
    """Blank out Lua comments, keeping every offset.

    The shipped template's examples are commented-out rules, and one of them is
    for workspace 1 - exactly the workspace a user is most likely to change the
    layout of. Matching those would edit a comment instead of recording the
    layout, so the same text is matched again with the comments blanked and a
    rule that lands inside one is left alone. Same idea as
    dp_lua_has_monitor_call.
    """
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        if src.startswith("--[[", i):
            end = src.find("]]", i + 4)
            end = n if end < 0 else end + 2
            for k in range(i, end):
                if out[k] != "\n":
                    out[k] = " "
            i = end
        elif src.startswith("--", i):
            end = src.find("\n", i)
            end = n if end < 0 else end
            for k in range(i, end):
                out[k] = " "
            i = end
        else:
            i += 1
    return "".join(out)


code = strip_comments(content)


def parse_rule_table(table_body):
    params = {}
    for entry in re.finditer(r'([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*("[^"]*"|\'[^\']*\'|[^\s,]+)', table_body):
        k = entry.group(1).strip()
        v = entry.group(2).strip().strip('"\'')
        params[k] = v
    return params

updated = False
pinned = ""

# A rule the nwg-displays import wrote carries a trailing marker naming the fields
# it owns: `-- nwg-displays: monitor,default`, from DisplayProfile.sh's
# import-nwg-workspaces verb. Those fields are not this script's to touch - the
# importer gives them back and writes them again on its next run, so taking one
# here would only lose the binding until then. The literal is a contract between
# the two scripts and is named in both.
IMPORT_MARKER = "nwg-displays"


def imported_fields(match):
    tail = match.string[match.end():]
    end = tail.find("\n")
    if end >= 0:
        tail = tail[:end]
    found = re.match(
        r'[ \t]*--[ \t]*' + re.escape(IMPORT_MARKER) + r'\s*:\s*([A-Za-z_, ]*)', tail
    )
    if not found:
        return set()
    return {field.strip() for field in found.group(1).split(",") if field.strip()}


def replace_rule(match):
    global updated, pinned
    if not code[match.start():match.end()].strip():
        # Commented out: an example the user has not enabled.
        return match.group(0)
    body = match.group(1)
    params = parse_rule_table(body)
    if params.get("workspace") != target_ws:
        return match.group(0)
    updated = True
    new_body = body
    # Rules written by an earlier version of this script bound the monitor too.
    # That pin is given up here, so the workspace stops being tied to the display
    # it was on when its layout was last changed. A monitor the import owns is
    # left alone: see IMPORT_MARKER above.
    if "monitor" in params and "monitor" not in imported_fields(match):
        pinned = params["monitor"]
        # `(\s*,)?` and not `\s*,?`: the whitespace is only part of the match when
        # a comma really follows, so a monitor that is the last field leaves the
        # space that belongs before the closing brace alone.
        new_body = re.sub(r'\s*monitor\s*=\s*("[^"]*"|\'[^\']*\'|[^\s,}]+)(\s*,)?', '', new_body, count=1)
        # A monitor that was the last field leaves the comma that separated it.
        # Only that comma goes; the body's own trailing space is what sits before
        # the closing brace.
        trimmed = new_body.rstrip()
        if trimmed.endswith(","):
            new_body = trimmed[:-1] + new_body[len(trimmed):]
    if re.search(r'\blayout\s*=', new_body):
        new_body = re.sub(r'(\blayout\s*=\s*)("[^"]*"|\'[^\']*\'|[^\s,}]+)', r'\1"' + target_layout + '"', new_body, count=1)
    else:
        # The trailing space is the one that belongs before the closing brace.
        new_body = new_body.rstrip() + f', layout = "{target_layout}" '
    return f"hl.workspace_rule({{{new_body}}})"

new_content = pattern.sub(replace_rule, content)

if not updated:
    new_rule = f'hl.workspace_rule({{ workspace = "{target_ws}", layout = "{target_layout}" }})\n'
    if not new_content.endswith("\n"):
        new_content += "\n"
    new_content += new_rule

lua_path.write_text(new_content, encoding="utf-8")

if pinned:
    print(
        f"workspace {target_ws} no longer binds monitor {pinned}: a layout rule"
        " never does, and the pin contradicted the workspace -> display bindings"
        " in this file",
        file=sys.stderr,
    )
PY
}

# Always update Lua workspace rules in UserConfigs/workspaces.lua
if command -v python3 >/dev/null 2>&1; then
  update_lua_workspaces "$workspace_selector" "$layout_name" "$lua_workspaces_file"
fi

if [[ "$quiet_mode" -eq 0 ]]; then
  printf 'Saved workspace layout: %s @ %s -> %s\n' "$workspace_selector" "$monitor_name" "$layout_name"
fi
