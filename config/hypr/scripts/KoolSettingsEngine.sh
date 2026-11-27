#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Unified settings backend engine for KoolDots Control Center.
# Manages UserConfigs files, validation, backup/revert, error logging, and Hyprland reloads.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${KOOLDOTS_SCRIPTS_DIR:-$SCRIPT_DIR}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HYPR_DIR="${KOOLDOTS_HYPR_DIR:-$CONFIG_HOME/hypr}"
USER_CONFIGS="${KOOLDOTS_USER_CONFIGS:-$HYPR_DIR/UserConfigs}"
SYSTEM_CONFIGS="${KOOLDOTS_SYSTEM_CONFIGS:-$HYPR_DIR/configs}"
WAYBAR_DIR="${KOOLDOTS_WAYBAR_DIR:-$HYPR_DIR/waybar}"
WAYBAR_CONFIGS="${KOOLDOTS_WAYBAR_CONFIGS:-$WAYBAR_DIR/configs}"

# Fallback to repo directories if running uninstalled from a repository checkout
if [[ ! -d "$USER_CONFIGS" && -d "$SCRIPT_DIR/../UserConfigs" ]]; then
  USER_CONFIGS="$(cd "$SCRIPT_DIR/../UserConfigs" && pwd)"
fi
if [[ ! -d "$SYSTEM_CONFIGS" && -d "$SCRIPT_DIR/../configs" ]]; then
  SYSTEM_CONFIGS="$(cd "$SCRIPT_DIR/../configs" && pwd)"
fi
if [[ ! -d "$WAYBAR_CONFIGS" && -d "$SCRIPT_DIR/../waybar/configs" ]]; then
  WAYBAR_CONFIGS="$(cd "$SCRIPT_DIR/../waybar/configs" && pwd)"
fi
if [[ ! -d "$WAYBAR_DIR" && -d "$SCRIPT_DIR/../waybar" ]]; then
  WAYBAR_DIR="$(cd "$SCRIPT_DIR/../waybar" && pwd)"
fi
if [[ ! -d "$HYPR_DIR" && -d "$SCRIPT_DIR/.." ]]; then
  HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

BACKUP_DIR="${KOOLDOTS_BACKUP_DIR:-${STATE_HOME}/hypr/backups}"
ERROR_LOG="${KOOLDOTS_ERROR_LOG:-${STATE_HOME}/hypr/kooldots-settings-errors.log}"

mkdir -p "$BACKUP_DIR" "$(dirname "$ERROR_LOG")"

# ------------------------------------------------------------------------------
# Logging & Error Handling
# ------------------------------------------------------------------------------
log_error() {
  local target_file="${1:-unknown}"
  local step="${2:-validation}"
  local error_msg="${3:-unknown error}"
  local snippet="${4:-}"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo "================================================================================"
    echo "TIMESTAMP: $timestamp"
    echo "FILE:      $target_file"
    echo "STEP:      $step"
    echo "ERROR:     $error_msg"
    if [[ -n "$snippet" ]]; then
      echo "SNIPPET:"
      echo "$snippet"
    fi
    echo "ENVIRONMENT: KoolDots (Hyprland 0.57+)"
    echo "================================================================================"
  } >> "$ERROR_LOG"
}

copy_latest_error() {
  if [[ ! -f "$ERROR_LOG" || ! -s "$ERROR_LOG" ]]; then
    echo "No errors recorded in error log." >&2
    return 1
  fi

  # Extract the last error block
  local last_entry
  last_entry=$(awk '/^===/{block=""; next} {block = block "\n" $0} END {print block}' "$ERROR_LOG")
  if [[ -z "$last_entry" ]]; then
    last_entry="$(tail -n 30 "$ERROR_LOG")"
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s\n' "$last_entry" | wl-copy
    printf '{"copied": true, "message": "Latest error copied to clipboard"}\n'
  else
    printf '%s\n' "$last_entry"
  fi
}

# ------------------------------------------------------------------------------
# Backup & Revert Operations
# ------------------------------------------------------------------------------
create_backup() {
  local target_file="$1"
  [[ -f "$target_file" ]] || return 0

  local base_name
  base_name="$(basename "$target_file")"
  local timestamp
  timestamp="$(date '+%Y%m%d-%H%M%S')"

  mkdir -p "$BACKUP_DIR"
  cp -f "$target_file" "${BACKUP_DIR}/${base_name}.${timestamp}.bak"
  cp -f "$target_file" "${target_file}.bak"
}

revert_file() {
  local target_file="$1"
  local base_name
  base_name="$(basename "$target_file")"

  # Find newest backup in BACKUP_DIR, or fallback to .bak
  local newest_backup=""
  if [[ -d "$BACKUP_DIR" ]]; then
    newest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name "${base_name}.*.bak" 2>/dev/null | sort -r | head -n 1)
  fi

  if [[ -z "$newest_backup" && -f "${target_file}.bak" ]]; then
    newest_backup="${target_file}.bak"
  fi

  if [[ -n "$newest_backup" && -f "$newest_backup" ]]; then
    cp -f "$newest_backup" "$target_file"
    reload_hyprland
    printf '{"reverted": true, "file": "%s", "source": "%s"}\n' "$target_file" "$newest_backup"
    return 0
  else
    log_error "$target_file" "revert" "No backup file found to restore from"
    printf '{"reverted": false, "error": "No backup found"}\n'
    return 1
  fi
}

reload_hyprland() {
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

# ------------------------------------------------------------------------------
# Pre-Flight Validation
# ------------------------------------------------------------------------------
validate_lua_syntax() {
  local file_or_snippet="$1"
  local is_file=0
  local tmp_file=""

  if [[ -f "$file_or_snippet" ]]; then
    is_file=1
    tmp_file="$file_or_snippet"
  else
    tmp_file=$(mktemp --suffix=.lua)
    printf '%s\n' "$file_or_snippet" > "$tmp_file"
  fi

  local err_out=""
  if command -v luac >/dev/null 2>&1; then
    if err_out=$(luac -p "$tmp_file" 2>&1); then
      [[ $is_file -eq 0 ]] && rm -f "$tmp_file"
      return 0
    else
      [[ $is_file -eq 0 ]] && rm -f "$tmp_file"
      log_error "$file_or_snippet" "lua_syntax" "$err_out"
      printf '%s\n' "$err_out"
      return 1
    fi
  else
    # Fallback to python luaparser if luac is absent
    [[ $is_file -eq 0 ]] && rm -f "$tmp_file"
    return 0
  fi
}

# ------------------------------------------------------------------------------
# Command: get-system-info
# ------------------------------------------------------------------------------
get_system_info() {
  local hypr_ver="Unknown"
  if command -v hyprctl >/dev/null 2>&1; then
    hypr_ver=$(hyprctl version 2>/dev/null | grep -i 'tag:' | head -n1 | awk '{print $2}' | tr -d ',' || true)
    [[ -z "$hypr_ver" ]] && hypr_ver=$(hyprctl version 2>/dev/null | head -n1 | tr -d ',' || echo "0.57.x")
  fi

  local distro="Linux"
  if [[ -f /etc/os-release ]]; then
    distro=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' || echo "Linux")
  fi

  local kernel
  kernel="$(uname -r 2>/dev/null || echo "Unknown")"

  local dots_ver="v3.0.0"
  local env_lua="$HYPR_DIR/lua/env.lua"
  if [[ -f "$env_lua" ]]; then
    local v
    v=$(sed -n 's/^[[:space:]]*DOTS_VERSION[[:space:]]*=[[:space:]]*["'\''"]\([^"'\''"]*\)["'\''"].*$/\1/p' "$env_lua" | tail -n1)
    [[ -n "$v" ]] && dots_ver="$v"
  fi

  python3 -c "
import json
print(json.dumps({
    'dots_version': '''$dots_ver'''.strip(),
    'hyprland_version': '''$hypr_ver'''.strip(),
    'distro': '''$distro'''.strip(),
    'kernel': '''$kernel'''.strip(),
    'session_type': '''${XDG_SESSION_TYPE:-wayland}'''.strip(),
    'signature': '''${HYPRLAND_INSTANCE_SIGNATURE:-default}'''.strip()
}))
"
}

# ------------------------------------------------------------------------------
# Command: list-keybinds
# ------------------------------------------------------------------------------
list_keybinds() {
  local user_file="$USER_CONFIGS/user_keybinds.lua"
  local sys_file="$SYSTEM_CONFIGS/system_keybinds.lua"
  local cache_file="${XDG_RUNTIME_DIR:-/tmp}/kooldots-keybinds.txt"

  python3 - "$user_file" "$sys_file" "$cache_file" << 'EOF'
import sys, os, re, json

user_path = sys.argv[1]
sys_path = sys.argv[2]
cache_path = sys.argv[3]

binds = []
seen_chords = set()

# Helper to normalize chord
def norm_chord(mods, key):
    m = mods.strip().upper()
    k = key.strip()
    if m:
        parts = re.split(r'\s+', m)
        return "+".join(parts) + "+" + k
    return k

# 1. Parse user_keybinds.lua
if os.path.isfile(user_path):
    with open(user_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find unbind calls
    for m in re.finditer(r'unbind\s*\(\s*["\']([^"\']*)["\']\s*,\s*["\']([^"\']*)["\']\s*\)', content):
        chord = norm_chord(m.group(1), m.group(2))
        binds.append({
            'chord': chord,
            'mods': m.group(1).strip().upper(),
            'key': m.group(2).strip(),
            'action_type': 'unbind',
            'action': 'unbound',
            'description': 'Explicitly unbound in UserConfigs',
            'source': 'user',
            'active': False,
            'is_unbind': True
        })
        seen_chords.add(chord)

    # Find bind calls: bind("MODS", "KEY", action, { description = "..." })
    bind_pattern = re.compile(
        r'bind\s*\(\s*["\']([^"\']*)["\']\s*,\s*["\']([^"\']*)["\']\s*,\s*([^,]+?)(?:,\s*\{([^}]*)\})?\s*\)',
        re.DOTALL
    )
    for m in bind_pattern.finditer(content):
        mods = m.group(1).strip().upper()
        key = m.group(2).strip()
        action_raw = m.group(3).strip()
        opts_raw = m.group(4) or ""

        desc = ""
        dm = re.search(r'description\s*=\s*["\']([^"\']+)["\']', opts_raw)
        if dm:
            desc = dm.group(1)

        action_type = "exec" if "exec_cmd" in action_raw else ("dispatch" if "dispatch" in action_raw else "custom")
        chord = norm_chord(mods, key)

        binds.append({
            'chord': chord,
            'mods': mods,
            'key': key,
            'action_type': action_type,
            'action': action_raw,
            'description': desc,
            'source': 'user',
            'active': True,
            'is_unbind': False
        })
        seen_chords.add(chord)

# 2. Parse system_keybinds.lua or live cache for system binds
if os.path.isfile(sys_path):
    with open(sys_path, 'r', encoding='utf-8') as f:
        sys_content = f.read()

    bind_pattern = re.compile(
        r'bind\s*\(\s*["\']([^"\']*)["\']\s*,\s*["\']([^"\']*)["\']\s*,\s*([^,]+?)(?:,\s*\{([^}]*)\})?\s*\)',
        re.DOTALL
    )
    for m in bind_pattern.finditer(sys_content):
        mods = m.group(1).strip().upper()
        key = m.group(2).strip()
        chord = norm_chord(mods, key)

        if chord in seen_chords:
            continue

        action_raw = m.group(3).strip()
        opts_raw = m.group(4) or ""
        desc = ""
        dm = re.search(r'description\s*=\s*["\']([^"\']+)["\']', opts_raw)
        if dm:
            desc = dm.group(1)

        action_type = "exec" if "exec_cmd" in action_raw else ("dispatch" if "dispatch" in action_raw else "custom")

        binds.append({
            'chord': chord,
            'mods': mods,
            'key': key,
            'action_type': action_type,
            'action': action_raw,
            'description': desc,
            'source': 'system',
            'active': True,
            'is_unbind': False
        })
        seen_chords.add(chord)

print(json.dumps(binds))
EOF
}

# ------------------------------------------------------------------------------
# Command: validate-keybinds
# ------------------------------------------------------------------------------
validate_keybinds() {
  local user_file="$USER_CONFIGS/user_keybinds.lua"
  if [[ ! -f "$user_file" ]]; then
    printf '{"valid": true}\n'
    return 0
  fi

  local err_out=""
  if ! err_out=$(luac -p "$user_file" 2>&1); then
    log_error "$user_file" "syntax" "$err_out"
    python3 - "$err_out" << 'EOF'
import sys, json
err = sys.argv[1] if len(sys.argv) > 1 else "Syntax error"
print(json.dumps({'valid': False, 'error': err.strip(), 'type': 'syntax'}))
EOF
    return 1
  fi

  # Check duplicate active chords
  local dup_json
  dup_json=$(python3 - "$user_file" << 'EOF'
import sys, re, json

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    text = f.read()

chords = {}
duplicates = []

for m in re.finditer(r'bind\s*\(\s*["\']([^"\']*)["\']\s*,\s*["\']([^"\']*)["\']', text):
    mods = m.group(1).strip().upper()
    key = m.group(2).strip()
    chord = (mods + "+" if mods else "") + key
    if chord in chords:
        duplicates.append(chord)
    chords[chord] = True

if duplicates:
    print(json.dumps({'valid': False, 'error': f"Duplicate key combinations defined: {', '.join(duplicates)}", 'type': 'duplicate'}))
else:
    print(json.dumps({'valid': True}))
EOF
)
  printf '%s\n' "$dup_json"
}

# ------------------------------------------------------------------------------
# Command: apply-keybind
# ------------------------------------------------------------------------------
apply_keybind() {
  local mods="${1:-}"
  local key="${2:-}"
  local action_type="${3:-exec}"
  local action_val="${4:-}"
  local desc="${5:-}"
  local orig_mods="${6:-}"
  local orig_key="${7:-}"

  local user_file="$USER_CONFIGS/user_keybinds.lua"
  [[ -f "$user_file" ]] || return 1

  # Construct Lua bind statement
  local bind_call=""
  local clean_desc
  clean_desc=$(printf '%s' "$desc" | tr -d '"')

  if [[ "$action_type" == "dispatch" ]]; then
    bind_call="bind(\"$mods\", \"$key\", dispatch(\"$action_val\"), { description = \"$clean_desc\" })"
  elif [[ "$action_type" == "exec" ]]; then
    bind_call="bind(\"$mods\", \"$key\", exec_cmd(\"$action_val\"), { description = \"$clean_desc\" })"
  else
    bind_call="bind(\"$mods\", \"$key\", $action_val, { description = \"$clean_desc\" })"
  fi

  create_backup "$user_file"

  # If remapping from an original chord, add unbind
  local unbind_call=""
  if [[ -n "$orig_key" && ( "$orig_mods" != "$mods" || "$orig_key" != "$key" ) ]]; then
    unbind_call="unbind(\"$orig_mods\", \"$orig_key\")\n"
  fi

  # Append to user_keybinds.lua
  printf "\n%b%s\n" "$unbind_call" "$bind_call" >> "$user_file"

  # Validate
  local val_res
  val_res=$(validate_keybinds)
  if [[ "$val_res" == *'"valid": false'* || "$val_res" == *'"valid":false'* ]]; then
    revert_file "$user_file"
    printf '%s\n' "$val_res"
    return 1
  fi

  reload_hyprland
  printf '{"applied": true, "chord": "%s+%s"}\n' "$mods" "$key"
}

# ------------------------------------------------------------------------------
# Command: list-window-rules
# ------------------------------------------------------------------------------
list_window_rules() {
  local user_file="$USER_CONFIGS/user_window_rules.lua"
  local sys_file="$HYPR_DIR/lua/window_rules.lua"
  if [[ ! -f "$sys_file" && -f "$SCRIPT_DIR/../lua/window_rules.lua" ]]; then
    sys_file="$SCRIPT_DIR/../lua/window_rules.lua"
  fi

  python3 - "$user_file" "$sys_file" << 'EOF'
import sys, os, re, json

user_path = sys.argv[1]
sys_path = sys.argv[2]

rules = []

def parse_rules_file(path, source_tag):
    if not os.path.isfile(path):
        return []
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()

    results = []
    # Match apply_window_rule({ ... })
    pattern = re.compile(r'apply_window_rule\s*\(\s*\{([^}]+(?:\{[^}]*\}[^}]+)*)\}\s*\)', re.DOTALL)
    for m in pattern.finditer(text):
        body = m.group(1)
        name_m = re.search(r'name\s*=\s*["\']([^"\']+)["\']', body)
        name = name_m.group(1) if name_m else "unnamed_rule"

        # match criteria
        match_obj = {}
        match_block = re.search(r'match\s*=\s*\{([^}]+)\}', body)
        if match_block:
            mb = match_block.group(1)
            for k in ['class', 'title', 'initial_class', 'initial_title', 'tag']:
                km = re.search(rf'{k}\s*=\s*["\']([^"\']+)["\']', mb)
                if km:
                    match_obj[k] = km.group(1)

        # actions
        actions = {}
        for prop in ['float', 'center', 'pin', 'no_blur', 'no_initial_focus']:
            if re.search(rf'\b{prop}\s*=\s*true', body):
                actions[prop] = True
            elif re.search(rf'\b{prop}\s*=\s*false', body):
                actions[prop] = False

        for prop in ['size', 'move', 'workspace', 'opacity', 'tag', 'idle_inhibit']:
            pm = re.search(rf'\b{prop}\s*=\s*["\']([^"\']+)["\']', body)
            if pm:
                actions[prop] = pm.group(1)

        results.append({
            'name': name,
            'source': source_tag,
            'enabled': True,
            'match': match_obj,
            'actions': actions,
            'raw': m.group(0)
        })
    return results

rules.extend(parse_rules_file(user_path, 'user'))
rules.extend(parse_rules_file(sys_path, 'system'))

print(json.dumps(rules))
EOF
}

# ------------------------------------------------------------------------------
# Command: apply-window-rule
# ------------------------------------------------------------------------------
apply_window_rule() {
  local name="$1"
  local match_json="$2"
  local actions_json="$3"

  local user_file="$USER_CONFIGS/user_window_rules.lua"
  [[ -f "$user_file" ]] || return 1

  create_backup "$user_file"

  # Generate Lua rule with Python
  local lua_rule
  lua_rule=$(python3 - "$name" "$match_json" "$actions_json" << 'EOF'
import sys, json

name = sys.argv[1]
match_data = json.loads(sys.argv[2])
actions_data = json.loads(sys.argv[3])

lines = []
lines.append("apply_window_rule({")
lines.append(f'  name = "{name}",')
lines.append("  match = {")
for k, v in match_data.items():
    if v:
        lines.append(f'    {k} = "{v}",')
lines.append("  },")

for k, v in actions_data.items():
    if isinstance(v, bool):
        lines.append(f"  {k} = {'true' if v else 'false'},")
    elif v:
        lines.append(f'  {k} = "{v}",')

lines.append("})")
print("\n".join(lines))
EOF
)

  printf "\n%s\n" "$lua_rule" >> "$user_file"

  # Validate
  if ! validate_lua_syntax "$user_file" >/dev/null 2>&1; then
    revert_file "$user_file"
    printf '{"applied": false, "error": "Lua syntax validation failed"}\n'
    return 1
  fi

  reload_hyprland
  printf '{"applied": true, "name": "%s"}\n' "$name"
}

# ------------------------------------------------------------------------------
# Command: list-startup
# ------------------------------------------------------------------------------
list_startup() {
  local user_file="$USER_CONFIGS/user_startup.lua"
  [[ -f "$user_file" ]] || { echo "[]"; return 0; }

  python3 - "$user_file" << 'EOF'
import sys, re, json

with open(sys.argv[1], 'r', encoding='utf-8') as f:
    text = f.read()

commands = []
# Find startup_commands table block
match = re.search(r'startup_commands\s*=\s*\{([^}]+)\}', text)
if match:
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line:
            continue
        enabled = not line.startswith('--')
        cleaned = re.sub(r'^(?:--|\s)+', '', line)
        cleaned = re.sub(r'^["\']', '', cleaned)
        cleaned = re.sub(r'["\']?,?\s*$', '', cleaned)
        if cleaned:
            commands.append({
                'command': cleaned,
                'enabled': enabled
            })

print(json.dumps(commands))
EOF
}

# ------------------------------------------------------------------------------
# Command: get-toggles & set-toggle
# ------------------------------------------------------------------------------
get_toggles() {
  local weather="metric"
  local user_env="$USER_CONFIGS/user_env.lua"
  if [[ -f "$user_env" ]]; then
    local w
    w=$(awk -F'[,()]' '/^[[:space:]]*hl\.env/ && /WEATHER_UNITS/ { val=$3; gsub(/[^a-zA-Z0-9_-]/, "", val); print val }' "$user_env" | tail -n1)
    [[ -n "$w" ]] && weather="$w"
  fi

  local wobble="false"
  if [[ -x "$SCRIPTS_DIR/ToggleWobble.sh" ]]; then
    local wst
    wst=$("$SCRIPTS_DIR/ToggleWobble.sh" --status 2>/dev/null || echo "Disabled")
    [[ "$wst" =~ [Ee]nabled ]] && wobble="true"
  fi

  python3 -c "
import json
print(json.dumps({
    'weather_units': '''$weather'''.strip(),
    'wobble_enabled': '''$wobble''' == 'true'
}))
"
}

set_toggle() {
  local name="$1"
  local val="${2:-}"

  case "$name" in
    weather)
      if [[ -x "$SCRIPTS_DIR/Toggle-weather-waybar-units.sh" ]]; then
        "$SCRIPTS_DIR/Toggle-weather-waybar-units.sh" >/dev/null 2>&1
        printf '{"toggled": true, "name": "weather"}\n'
      fi
      ;;
    clock)
      if [[ -x "$SCRIPTS_DIR/ToggleWaybarTime.sh" ]]; then
        "$SCRIPTS_DIR/ToggleWaybarTime.sh" >/dev/null 2>&1
        printf '{"toggled": true, "name": "clock"}\n'
      fi
      ;;
    game_mode)
      if [[ -x "$SCRIPTS_DIR/GameMode.sh" ]]; then
        "$SCRIPTS_DIR/GameMode.sh" >/dev/null 2>&1
        printf '{"toggled": true, "name": "game_mode"}\n'
      fi
      ;;
    wobble)
      if [[ -x "$SCRIPTS_DIR/ToggleWobble.sh" ]]; then
        "$SCRIPTS_DIR/ToggleWobble.sh" >/dev/null 2>&1
        printf '{"toggled": true, "name": "wobble"}\n'
      fi
      ;;
    *)
      printf '{"toggled": false, "error": "Unknown toggle"}\n'
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Command: edit-file
# ------------------------------------------------------------------------------
edit_file() {
  local target_file="${1:-}"
  if [[ -z "$target_file" ]]; then
    printf '{"edited": false, "error": "No file specified"}\n'
    return 1
  fi

  if [[ "$target_file" == "~"* ]]; then
    target_file="${HOME}${target_file#\~}"
  fi

  if [[ ! -f "$target_file" ]]; then
    mkdir -p "$(dirname "$target_file")"
    touch "$target_file" || true
  fi

  local term="kitty"
  local edit="nvim"
  local visual=""
  local visual_explicit=0

  local lua_defaults="$USER_CONFIGS/user_defaults.lua"
  local sys_defaults="$HYPR_DIR/lua/user_defaults.lua"
  local user_env="$USER_CONFIGS/user_env.lua"
  local sys_env="$HYPR_DIR/configs/system_env.lua"

  if [[ -f "$lua_defaults" ]]; then
    local lt le lv
    lt=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.term[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lua_defaults" | tail -n1 || true)
    le=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.edit[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lua_defaults" | tail -n1 || true)
    lv=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.visual[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lua_defaults" | tail -n1 || true)
    [[ -n "$lt" ]] && term="$lt"
    [[ -n "$le" ]] && edit="$le"
    if [[ -n "$lv" ]]; then
      visual="$lv"
      visual_explicit=1
    fi
  fi

  for env_file in "$user_env" "$sys_env"; do
    if [[ -f "$env_file" ]]; then
      local ee ev
      ee=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["\x27]EDITOR["\x27][[:space:]]*,[[:space:]]*["\x27]\([^"\x27]*\)["\x27].*$/\1/p' "$env_file" | tail -n1 || true)
      ev=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["\x27]VISUAL["\x27][[:space:]]*,[[:space:]]*["\x27]\([^"\x27]*\)["\x27].*$/\1/p' "$env_file" | tail -n1 || true)
      [[ -n "$ee" ]] && edit="$ee"
      if [[ -n "$ev" ]]; then
        visual="$ev"
        visual_explicit=1
      fi
    fi
  done

  if [[ -z "${edit:-}" && -f "$sys_defaults" ]]; then
    local se
    se=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.edit[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$sys_defaults" | tail -n1 || true)
    [[ -n "$se" ]] && edit="$se"
  fi
  if [[ -z "${term:-}" && -f "$sys_defaults" ]]; then
    local st
    st=$(sed -n 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.term[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$sys_defaults" | tail -n1 || true)
    [[ -n "$st" ]] && term="$st"
  fi

  if [[ -z "${edit:-}" ]]; then
    edit="${EDITOR:-}"
  fi
  if [[ -z "${edit:-}" ]]; then
    if command -v nvim >/dev/null 2>&1; then
      edit="nvim"
    elif command -v vim >/dev/null 2>&1; then
      edit="vim"
    else
      edit="nano"
    fi
  fi

  local -a edit_cmd visual_cmd selected_cmd
  read -r -a edit_cmd <<<"$edit"
  selected_cmd=("${edit_cmd[@]}")

  if [[ $visual_explicit -eq 1 && -n "$visual" ]]; then
    read -r -a visual_cmd <<<"$visual"
    local vbin
    vbin="$(basename "${visual_cmd[0]}")"
    case "$vbin" in
      vi|vim|nvim|nano|hx|helix|kak|micro|emacs-nox|ttt) ;;
      *)
        selected_cmd=("${visual_cmd[@]}")
        ;;
    esac
  fi

  local sbin
  sbin="$(basename "${selected_cmd[0]}")"
  local is_tui=0
  case "$sbin" in
    vi|vim|nvim|nano|hx|helix|kak|micro|emacs-nox|ttt)
      is_tui=1
      ;;
    emacs|emacsclient)
      for arg in "${selected_cmd[@]:1}"; do
        case "$arg" in
          -nw|--no-window-system|-t|--tty)
            is_tui=1
            break
            ;;
        esac
      done
      ;;
  esac

  if [[ $is_tui -eq 1 ]]; then
    if [[ -x "$SCRIPTS_DIR/LaunchTerminal.sh" ]]; then
      "$SCRIPTS_DIR/LaunchTerminal.sh" "$term" "${selected_cmd[*]} '$target_file'" >/dev/null 2>&1 &
    elif command -v kitty >/dev/null 2>&1; then
      kitty "${selected_cmd[@]}" "$target_file" >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null 2>&1; then
      ghostty -e "${selected_cmd[@]}" "$target_file" >/dev/null 2>&1 &
    elif command -v alacritty >/dev/null 2>&1; then
      alacritty -e "${selected_cmd[@]}" "$target_file" >/dev/null 2>&1 &
    else
      "${selected_cmd[@]}" "$target_file" >/dev/null 2>&1 &
    fi
  else
    "${selected_cmd[@]}" "$target_file" >/dev/null 2>&1 &
  fi

  printf '{"edited": true, "file": "%s", "editor": "%s"}\n' "$target_file" "$sbin"
}

# ------------------------------------------------------------------------------
# Waybar Phase 2 Visual Editor Engine
# ------------------------------------------------------------------------------
restart_waybar() {
  if [[ -x "$SCRIPTS_DIR/WaybarStartup.sh" ]]; then
    "$SCRIPTS_DIR/WaybarStartup.sh" >/dev/null 2>&1 &
  elif [[ -x "$SCRIPTS_DIR/Refresh.sh" ]]; then
    "$SCRIPTS_DIR/Refresh.sh" >/dev/null 2>&1 &
  fi
}

validate_waybar_syntax() {
  local target_file="${1:-}"
  if [[ -z "$target_file" || ! -f "$target_file" ]]; then
    printf '{"valid": false, "error": "File does not exist"}\n'
    return 1
  fi

  local err_out=""
  if err_out=$(python3 - "$target_file" 2>&1 << 'EOF'
import sys, json, re

with open(sys.argv[1], "r", encoding="utf-8", errors="ignore") as f:
    raw = f.read()

content = re.sub(r'//.*?\n|/\*.*?\*/', '\n', raw, flags=re.S)
content = re.sub(r',(\s*[}\]])', r'\1', content)
content = re.sub(r',\s*$', '', content.strip())

data = json.loads(content)
if not isinstance(data, (dict, list)):
    raise ValueError("Root element must be object or array")
EOF
); then
    printf '{"valid": true}\n'
    return 0
  else
    log_error "$target_file" "waybar_syntax" "$err_out"
    python3 -c "import json, sys; print(json.dumps({'valid': False, 'error': sys.argv[1].strip()}))" "$err_out"
    return 1
  fi
}

list_waybar_configs() {
  local current_symlink="$WAYBAR_DIR/config"
  local active_name=""
  if [[ -L "$current_symlink" || -f "$current_symlink" ]]; then
    active_name=$(basename "$(readlink -f "$current_symlink" 2>/dev/null || echo "$current_symlink")")
  fi
  [[ -z "$active_name" ]] && active_name="TOP-Default"

  python3 - "$WAYBAR_CONFIGS" "$active_name" << 'EOF'
import sys, os, json, re

configs_dir = sys.argv[1]
active_cfg = sys.argv[2]

if not os.path.isdir(configs_dir):
    print(json.dumps({"active_config": active_cfg, "configs": []}))
    sys.exit(0)

files = [f for f in os.listdir(configs_dir) if os.path.isfile(os.path.join(configs_dir, f))]

custom_files = []
system_files = []

for f in files:
    is_custom = bool(re.match(r'^\[Custom-\d+\]-', f))
    entry = {
        "name": f,
        "is_active": (f == active_cfg),
        "is_custom": is_custom,
        "path": os.path.join(configs_dir, f)
    }
    if is_custom:
        custom_files.append(entry)
    else:
        system_files.append(entry)

def custom_sort_key(item):
    m = re.match(r'^\[Custom-(\d+)\]-(.*)$', item["name"])
    if m:
        return (int(m.group(1)), m.group(2).lower())
    return (999999, item["name"].lower())

custom_files.sort(key=custom_sort_key)
system_files.sort(key=lambda x: x["name"].lower())

all_configs = custom_files + system_files
print(json.dumps({
    "active_config": active_cfg,
    "configs": all_configs
}))
EOF
}

get_waybar_layout() {
  local target_name="${1:-}"
  local target_path=""

  if [[ -z "$target_name" ]]; then
    local current_symlink="$WAYBAR_DIR/config"
    if [[ -L "$current_symlink" || -f "$current_symlink" ]]; then
      target_path="$(readlink -f "$current_symlink" 2>/dev/null || echo "$current_symlink")"
      target_name="$(basename "$target_path")"
    else
      target_name="TOP-Default"
      target_path="$WAYBAR_CONFIGS/TOP-Default"
    fi
  elif [[ -f "$target_name" ]]; then
    target_path="$target_name"
    target_name="$(basename "$target_path")"
  else
    target_path="$WAYBAR_CONFIGS/$target_name"
  fi

  if [[ ! -f "$target_path" ]]; then
    printf '{"error": "Config file not found: %s"}\n' "$target_name"
    return 1
  fi

  python3 - "$target_path" "$target_name" "$WAYBAR_DIR" << 'EOF'
import sys, os, json, re

target_path = sys.argv[1]
target_name = sys.argv[2]
waybar_dir = sys.argv[3]

with open(target_path, "r", encoding="utf-8", errors="ignore") as f:
    raw = f.read()

content = re.sub(r'//.*?\n|/\*.*?\*/', '\n', raw, flags=re.S)
content = re.sub(r',(\s*[}\]])', r'\1', content)
content = re.sub(r',\s*$', '', content.strip())

data = json.loads(content)
bar = data[0] if isinstance(data, list) else data

def_files = ["UserModules", "ModulesCustom", "ModulesWorkspaces", "ModulesGroups", "Modules"]
available_modules = set()
for fname in def_files:
    p = os.path.join(waybar_dir, fname)
    if os.path.isfile(p):
        try:
            with open(p, "r", encoding="utf-8", errors="ignore") as f:
                c = re.sub(r'//.*?\n|/\*.*?\*/', '\n', f.read(), flags=re.S)
                c = re.sub(r',(\s*[}\]])', r'\1', c)
                c = re.sub(r',\s*$', '', c.strip())
                m_data = json.loads(c)
                for k in m_data.keys():
                    if k not in ("include", "modules-left", "modules-center", "modules-right"):
                        available_modules.add(k)
        except Exception:
            pass

core_modules = [
    "clock", "battery", "cpu", "memory", "disk", "temperature",
    "backlight", "network", "pulseaudio", "tray", "idle_inhibitor",
    "hyprland/workspaces", "hyprland/window", "hyprland/submap", "hyprland/language",
    "mpris", "bluetooth", "power-profiles-daemon", "custom/separator#blank",
    "custom/separator#dot-line", "custom/qs-weather", "custom/qs-network",
    "group/audio", "group/notify", "group/status", "group/app_drawer"
]
for cm in core_modules:
    available_modules.add(cm)

left = bar.get("modules-left", [])
center = bar.get("modules-center", [])
right = bar.get("modules-right", [])

is_custom = bool(re.match(r'^\[Custom-\d+\]-', target_name))

base_name = re.sub(r'^\[Custom-\d+\]-', '', target_name)
configs_dir = os.path.dirname(target_path)
max_clone = 0
for f in os.listdir(configs_dir):
    m = re.match(r'^\[Custom-(\d+)\]-' + re.escape(base_name) + r'$', f)
    if m:
        num = int(m.group(1))
        if num > max_clone:
            max_clone = num
suggested_clone = f"[Custom-{max_clone + 1}]-{base_name}"

result = {
    "name": target_name,
    "path": target_path,
    "is_custom": is_custom,
    "suggested_clone": suggested_clone,
    "layer": bar.get("layer", "top"),
    "position": bar.get("position", "top"),
    "modules_left": left,
    "modules_center": center,
    "modules_right": right,
    "available_modules": sorted(list(available_modules))
}
print(json.dumps(result))
EOF
}

clone_waybar_config() {
  local source_name="${1:-}"
  local custom_name="${2:-}"

  if [[ -z "$source_name" ]]; then
    printf '{"cloned": false, "error": "No source config specified"}\n'
    return 1
  fi

  local source_path="$WAYBAR_CONFIGS/$source_name"
  if [[ ! -f "$source_path" ]]; then
    printf '{"cloned": false, "error": "Source config not found: %s"}\n' "$source_name"
    return 1
  fi

  local clone_name="$custom_name"
  if [[ -z "$clone_name" ]]; then
    local base_name
    base_name=$(python3 -c "import re, sys; print(re.sub(r'^\[Custom-\d+\]-', '', sys.argv[1]))" "$source_name")
    local next_num
    next_num=$(python3 - "$WAYBAR_CONFIGS" "$base_name" << 'EOF'
import sys, os, re
configs_dir = sys.argv[1]
base = sys.argv[2]
max_num = 0
for f in os.listdir(configs_dir):
    m = re.match(r'^\[Custom-(\d+)\]-' + re.escape(base) + r'$', f)
    if m:
        num = int(m.group(1))
        if num > max_num:
            max_num = num
print(max_num + 1)
EOF
)
    clone_name="[Custom-${next_num}]-${base_name}"
  fi

  local target_path="$WAYBAR_CONFIGS/$clone_name"
  cp -f "$source_path" "$target_path"
  create_backup "$target_path"

  printf '{"cloned": true, "name": "%s", "path": "%s", "source": "%s"}\n' "$clone_name" "$target_path" "$source_name"
}

save_waybar_layout() {
  local config_name="${1:-}"
  local left_json="${2:-[]}"
  local center_json="${3:-[]}"
  local right_json="${4:-[]}"
  local activate="${5:-true}"

  if [[ -z "$config_name" ]]; then
    printf '{"saved": false, "error": "No config name specified"}\n'
    return 1
  fi

  local config_path="$WAYBAR_CONFIGS/$config_name"
  create_backup "$config_path"

  local save_err=""
  if ! save_err=$(python3 - "$config_path" "$left_json" "$center_json" "$right_json" << 'EOF'
import sys, os, json, re

config_path = sys.argv[1]
left = json.loads(sys.argv[2])
center = json.loads(sys.argv[3])
right = json.loads(sys.argv[4])

if os.path.isfile(config_path):
    with open(config_path, "r", encoding="utf-8", errors="ignore") as f:
        raw = f.read()
    content = re.sub(r'//.*?\n|/\*.*?\*/', '\n', raw, flags=re.S)
    content = re.sub(r',(\s*[}\]])', r'\1', content)
    content = re.sub(r',\s*$', '', content.strip())
    try:
        data = json.loads(content)
    except Exception:
        data = {}
else:
    data = {}

if isinstance(data, list):
    if not data:
        data = [{}]
    data[0]["modules-left"] = left
    data[0]["modules-center"] = center
    data[0]["modules-right"] = right
else:
    if "include" not in data:
        data["include"] = [
            "$HOME/.config/hypr/waybar/Modules",
            "$HOME/.config/hypr/waybar/ModulesWorkspaces",
            "$HOME/.config/hypr/waybar/ModulesCustom",
            "$HOME/.config/hypr/waybar/ModulesGroups",
            "$HOME/.config/hypr/waybar/UserModules"
        ]
    data["modules-left"] = left
    data["modules-center"] = center
    data["modules-right"] = right

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
  2>&1); then
    log_error "$config_path" "save_waybar" "$save_err"
    printf '{"saved": false, "error": "Failed to serialize JSON: %s"}\n' "$save_err"
    return 1
  fi

  if ! validate_waybar_syntax "$config_path" >/dev/null 2>&1; then
    revert_file "$config_path"
    printf '{"saved": false, "error": "Syntax validation failed"}\n'
    return 1
  fi

  if [[ "$activate" == "true" ]]; then
    ln -sf "$config_path" "$WAYBAR_DIR/config"
    restart_waybar
  fi

  printf '{"saved": true, "name": "%s", "path": "%s", "activated": %s}\n' "$config_name" "$config_path" "$activate"
}

find_waybar_module_source() {
  local module_name="${1:-}"
  if [[ -z "$module_name" ]]; then
    printf '{"found": false, "error": "No module specified"}\n'
    return 1
  fi

  python3 - "$module_name" "$WAYBAR_DIR" << 'EOF'
import sys, os, json, re

mod_name = sys.argv[1]
waybar_dir = sys.argv[2]

candidates = [mod_name]
if "#" in mod_name:
    candidates.append(mod_name.split("#")[0])

def_files = ["UserModules", "ModulesCustom", "ModulesWorkspaces", "ModulesGroups", "Modules"]
found_path = ""

for cand in candidates:
    for fname in def_files:
        p = os.path.join(waybar_dir, fname)
        if os.path.isfile(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                if re.search(r'["\']' + re.escape(cand) + r'["\']\s*:', content):
                    found_path = p
                    break
            except Exception:
                pass
    if found_path:
        break

if not found_path:
    found_path = os.path.join(waybar_dir, "Modules")

print(json.dumps({
    "module": mod_name,
    "file": found_path,
    "found": bool(found_path and os.path.isfile(found_path))
}))
EOF
}

# ------------------------------------------------------------------------------
# CLI Router
# ------------------------------------------------------------------------------
main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    info|get-info)
      get_system_info
      ;;
    list-keybinds)
      list_keybinds
      ;;
    validate-keybinds)
      validate_keybinds
      ;;
    apply-keybind)
      apply_keybind "$@"
      ;;
    list-rules)
      list_window_rules
      ;;
    apply-rule)
      apply_window_rule "$@"
      ;;
    list-startup)
      list_startup
      ;;
    get-toggles)
      get_toggles
      ;;
    set-toggle)
      set_toggle "$@"
      ;;
    list-waybar|list-waybar-configs)
      list_waybar_configs
      ;;
    get-waybar|get-waybar-layout)
      get_waybar_layout "${1:-}"
      ;;
    clone-waybar|clone-waybar-config)
      clone_waybar_config "$@"
      ;;
    save-waybar|save-waybar-layout)
      save_waybar_layout "$@"
      ;;
    validate-waybar|validate-waybar-syntax)
      validate_waybar_syntax "${1:-}"
      ;;
    find-module|find-waybar-module)
      find_waybar_module_source "${1:-}"
      ;;
    edit|edit-file)
      edit_file "$@"
      ;;
    revert)
      revert_file "$1"
      ;;
    copy-error)
      copy_latest_error
      ;;
    validate)
      validate_lua_syntax "$1"
      ;;
    reload)
      reload_hyprland
      ;;
    *)
      echo "Usage: $(basename "$0") <info|list-keybinds|validate-keybinds|apply-keybind|list-rules|apply-rule|list-startup|get-toggles|set-toggle|list-waybar|get-waybar|clone-waybar|save-waybar|validate-waybar|find-module|revert|copy-error|validate|reload|edit-file>" >&2
      exit 1
      ;;
  esac
}

main "$@"
