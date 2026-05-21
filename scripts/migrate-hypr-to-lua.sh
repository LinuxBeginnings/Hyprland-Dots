#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Opt-in helper for testing Hyprland's Lua config entrypoint.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_HYPR_DIR="$REPO_DIR/config/hypr"
DEST_HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
BACKUP_DIR="${DEST_HYPR_DIR}-backup-lua-$(date +%Y%m%d-%H%M%S)"
MIGRATION_TS="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
YES=0
REVERT=0

USER_CONFIGS_DIR="$DEST_HYPR_DIR/UserConfigs"
CONFIGS_DIR="$DEST_HYPR_DIR/configs"
LEGACY_CONFIGS_DIR_NAME="LegacyConfigs"
USER_WINDOW_RULES="$USER_CONFIGS_DIR/WindowRules.conf"
USER_KEYBINDS="$USER_CONFIGS_DIR/UserKeybinds.conf"
USER_ENV_VARS="$USER_CONFIGS_DIR/ENVariables.conf"
USER_STARTUP_APPS="$USER_CONFIGS_DIR/Startup_Apps.conf"
USER_SETTINGS="$USER_CONFIGS_DIR/UserSettings.conf"
USER_DECORATIONS="$USER_CONFIGS_DIR/UserDecorations.conf"
USER_ANIMATIONS="$USER_CONFIGS_DIR/UserAnimations.conf"
USER_LAPTOPS="$USER_CONFIGS_DIR/Laptops.conf"
USER_LAYER_RULES="$USER_CONFIGS_DIR/LayerRules.conf"
SYSTEM_WINDOW_RULES="$CONFIGS_DIR/WindowRules.conf"
SYSTEM_LAYER_RULES="$CONFIGS_DIR/LayerRules.conf"
SYSTEM_KEYBINDS="$CONFIGS_DIR/Keybinds.conf"
SYSTEM_ENV_VARS="$CONFIGS_DIR/ENVariables.conf"
SYSTEM_STARTUP_APPS="$CONFIGS_DIR/Startup_Apps.conf"
SYSTEM_SETTINGS="$CONFIGS_DIR/SystemSettings.conf"
SYSTEM_LAPTOPS="$CONFIGS_DIR/Laptops.conf"
USER_CONFIGS_LEGACY_ROOT="$USER_CONFIGS_DIR/$LEGACY_CONFIGS_DIR_NAME"
CONFIGS_LEGACY_ROOT="$CONFIGS_DIR/$LEGACY_CONFIGS_DIR_NAME"
USER_CONFIGS_LEGACY_DIR="$USER_CONFIGS_LEGACY_ROOT/$MIGRATION_TS"
CONFIGS_LEGACY_DIR="$CONFIGS_LEGACY_ROOT/$MIGRATION_TS"
USER_OVERRIDES_SHIM="$DEST_HYPR_DIR/lua/user_overrides.lua"
DEST_MONITORS_CONF="$DEST_HYPR_DIR/monitors.conf"
DEST_LUA_MONITORS="$DEST_HYPR_DIR/lua/monitors.lua"
DEST_WORKSPACES_CONF="$DEST_HYPR_DIR/workspaces.conf"
DEST_LUA_WORKSPACES="$DEST_HYPR_DIR/lua/workspaces.lua"
SOURCE_LUA_ENTRY_ENABLED="$SRC_HYPR_DIR/hyprland.lua"
SOURCE_LUA_ENTRY_DISABLED="$SRC_HYPR_DIR/hyprland.lua.disable"
DEST_LUA_ENTRY="$DEST_HYPR_DIR/hyprland.lua"
DEST_LUA_ENTRY_DISABLED="$DEST_HYPR_DIR/hyprland.lua.disable"
SOURCE_LUA_ENTRY=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--yes] [--dry-run] [--revert]

Copies the repo's Hyprland Lua entrypoint into:
  $DEST_HYPR_DIR

This preserves hyprland.conf as fallback and creates a full backup of the
current Hyprland config directory before changing files.

Options:
  -y, --yes      Run without confirmation prompts.
  -n, --dry-run  Show what would change without copying files.
  -r, --revert   Revert migration by restoring latest LegacyConfigs/<timestamp> .conf files.
  -h, --help     Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      YES=1
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -r|--revert)
      REVERT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ -f "$SOURCE_LUA_ENTRY_ENABLED" ]; then
  SOURCE_LUA_ENTRY="$SOURCE_LUA_ENTRY_ENABLED"
elif [ -f "$SOURCE_LUA_ENTRY_DISABLED" ]; then
  SOURCE_LUA_ENTRY="$SOURCE_LUA_ENTRY_DISABLED"
fi

if [ "$REVERT" -eq 0 ] && [ ! -d "$SRC_HYPR_DIR/lua" ]; then
  echo "[ERROR] Lua config source files were not found under $SRC_HYPR_DIR" >&2
  exit 1
fi

if [ "$REVERT" -eq 0 ] && [ -z "$SOURCE_LUA_ENTRY" ] && [ ! -f "$DEST_LUA_ENTRY" ] && [ ! -f "$DEST_LUA_ENTRY_DISABLED" ]; then
  echo "[ERROR] No Lua entrypoint was found at $SRC_HYPR_DIR/hyprland.lua(.disable) or $DEST_HYPR_DIR/hyprland.lua(.disable)" >&2
  exit 1
fi

if command -v Hyprland >/dev/null 2>&1; then
  HYPR_VERSION="$(Hyprland --version 2>/dev/null | sed -n '1p' || true)"
  echo "[INFO] Detected $HYPR_VERSION"
else
  echo "[WARN] Hyprland binary was not found in PATH; continuing because this may be an offline config migration."
fi

echo "[INFO] Source: $SRC_HYPR_DIR"
echo "[INFO] Target: $DEST_HYPR_DIR"
echo "[INFO] Backup: $BACKUP_DIR"
if [ "$REVERT" -eq 1 ]; then
  echo "[WARN] Revert mode: restores latest LegacyConfigs/<timestamp> .conf files in UserConfigs and configs."
else
  echo "[WARN] This enables Hyprland's Lua entrypoint for builds that support hyprland.lua."
  echo "[WARN] hyprland.conf remains in place as fallback; old .conf files move into LegacyConfigs/<timestamp>."
  echo "[INFO] hypridle.conf and hyprlock*.conf stay as native .conf files because Hypridle/Hyprlock do not use Hyprland's Lua API."
fi

restore_latest_conf_backup() {
  local target_dir="$1"
  local label="$2"
  local latest_archive=""
  local legacy_root="$target_dir/$LEGACY_CONFIGS_DIR_NAME"
  local moved=0
  local file
  local archives=()

  [ -d "$target_dir" ] || return 0

  if [ -d "$legacy_root" ]; then
    mapfile -t archives < <(find "$legacy_root" -mindepth 1 -maxdepth 1 -type d | sort)
  fi

  if [ "${#archives[@]}" -eq 0 ]; then
    mapfile -t archives < <(find "$target_dir" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | sort)
  fi

  [ "${#archives[@]}" -gt 0 ] || return 0
  latest_archive="${archives[${#archives[@]}-1]}"

  while IFS= read -r -d '' file; do
    cp -a "$file" "$target_dir/"
    moved=1
  done < <(find "$latest_archive" -maxdepth 1 -type f -name '*.conf' -print0)

  if [ "$moved" -eq 1 ]; then
    echo "[OK] Restored $label/*.conf from $latest_archive"
  else
    echo "[INFO] No .conf files found in latest archive for $label: $latest_archive"
  fi
}

if [ "$YES" -eq 0 ]; then
  if [ "$REVERT" -eq 1 ]; then
    printf "[ACTION] Continue and revert Lua migration using latest legacy archives? [y/N] "
  else
    printf "[ACTION] Continue with Lua config migration? [y/N] "
  fi
  read -r reply
  case "$reply" in
    [Yy]|[Yy][Ee][Ss])
      ;;
    *)
      echo "[INFO] Cancelled. No changes made."
      exit 0
      ;;
  esac
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$REVERT" -eq 1 ]; then
    if [ -f "$DEST_LUA_ENTRY" ]; then
      echo "[DRY-RUN] Would disable Lua entrypoint: $DEST_LUA_ENTRY -> $DEST_LUA_ENTRY_DISABLED"
    elif [ -f "$DEST_LUA_ENTRY_DISABLED" ]; then
      echo "[DRY-RUN] Lua entrypoint already disabled: $DEST_LUA_ENTRY_DISABLED"
    else
      echo "[DRY-RUN] No Lua entrypoint found to disable at: $DEST_LUA_ENTRY"
    fi
    echo "[DRY-RUN] Would restore latest LegacyConfigs/<timestamp> .conf files into:"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR"
    echo "[DRY-RUN]   - $CONFIGS_DIR"
  else
    echo "[DRY-RUN] Would create target directory if missing: $DEST_HYPR_DIR"
    if [ -d "$DEST_HYPR_DIR" ]; then
      echo "[DRY-RUN] Would copy backup: $DEST_HYPR_DIR -> $BACKUP_DIR"
    fi
    if [ -f "$DEST_LUA_ENTRY_DISABLED" ]; then
      echo "[DRY-RUN] Would enable Lua entrypoint: $DEST_LUA_ENTRY_DISABLED -> $DEST_LUA_ENTRY"
    elif [ -f "$DEST_LUA_ENTRY" ]; then
      echo "[DRY-RUN] Lua entrypoint already enabled: $DEST_LUA_ENTRY"
    elif [ -n "$SOURCE_LUA_ENTRY" ]; then
      echo "[DRY-RUN] Would install Lua entrypoint: $SOURCE_LUA_ENTRY -> $DEST_LUA_ENTRY"
    fi
    echo "[DRY-RUN] Would replace Lua module directory: $DEST_HYPR_DIR/lua"
    echo "[DRY-RUN] Would generate split configs/UserConfigs Lua overlays:"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_env.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_startup.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_window_rules.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_layer_rules.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_keybinds.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_settings.lua"
    echo "[DRY-RUN]   - $CONFIGS_DIR/system_laptops.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_env.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_startup.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_window_rules.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_layer_rules.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_keybinds.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_settings.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_decorations.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_animations.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_laptops.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_defaults.lua"
    echo "[DRY-RUN]   - $DEST_LUA_MONITORS (generated from $DEST_MONITORS_CONF)"
    echo "[DRY-RUN]   - $DEST_LUA_WORKSPACES (generated from $DEST_WORKSPACES_CONF)"
    if [ -d "$USER_CONFIGS_DIR" ]; then
      echo "[DRY-RUN] Would move UserConfigs/*.conf into: $USER_CONFIGS_LEGACY_DIR"
    fi
    if [ -d "$CONFIGS_DIR" ]; then
      echo "[DRY-RUN] Would move configs/*.conf into: $CONFIGS_LEGACY_DIR"
    fi
  fi
  exit 0
fi
if [ "$REVERT" -eq 1 ]; then
  if [ -f "$DEST_LUA_ENTRY" ]; then
    mv -f "$DEST_LUA_ENTRY" "$DEST_LUA_ENTRY_DISABLED"
    echo "[OK] Disabled Lua entrypoint: $DEST_LUA_ENTRY_DISABLED"
  elif [ -f "$DEST_LUA_ENTRY_DISABLED" ]; then
    echo "[INFO] Lua entrypoint already disabled: $DEST_LUA_ENTRY_DISABLED"
  else
    echo "[INFO] No Lua entrypoint found to disable at $DEST_LUA_ENTRY"
  fi
  restore_latest_conf_backup "$USER_CONFIGS_DIR" "$USER_CONFIGS_DIR"
  restore_latest_conf_backup "$CONFIGS_DIR" "$CONFIGS_DIR"
  echo "[OK] Revert complete."
  echo "[INFO] Restart Hyprland to load restored .conf files."
  exit 0
fi

mkdir -p "$DEST_HYPR_DIR"

if [ -d "$DEST_HYPR_DIR" ] && [ -n "$(find "$DEST_HYPR_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  cp -a "$DEST_HYPR_DIR" "$BACKUP_DIR"
  echo "[OK] Backup created at $BACKUP_DIR"
fi
if [ -f "$DEST_LUA_ENTRY_DISABLED" ]; then
  if [ -f "$DEST_LUA_ENTRY" ]; then
    rm -f "$DEST_LUA_ENTRY_DISABLED"
    echo "[INFO] Removed duplicate disabled entrypoint: $DEST_LUA_ENTRY_DISABLED"
  else
    mv "$DEST_LUA_ENTRY_DISABLED" "$DEST_LUA_ENTRY"
    echo "[OK] Enabled Lua entrypoint: $DEST_LUA_ENTRY"
  fi
elif [ -f "$DEST_LUA_ENTRY" ]; then
  echo "[INFO] Lua entrypoint already enabled: $DEST_LUA_ENTRY"
elif [ -n "$SOURCE_LUA_ENTRY" ]; then
  cp -f "$SOURCE_LUA_ENTRY" "$DEST_LUA_ENTRY"
  echo "[OK] Installed Lua entrypoint: $SOURCE_LUA_ENTRY -> $DEST_LUA_ENTRY"
else
  echo "[ERROR] Unable to locate a Lua entrypoint to enable." >&2
  exit 1
fi
rm -rf "$DEST_HYPR_DIR/lua"
cp -a "$SRC_HYPR_DIR/lua" "$DEST_HYPR_DIR/lua"
mkdir -p "$USER_CONFIGS_DIR" "$CONFIGS_DIR"
python3 - \
  "$CONFIGS_DIR" \
  "$USER_CONFIGS_DIR" \
  "$SYSTEM_WINDOW_RULES" \
  "$SYSTEM_LAYER_RULES" \
  "$SYSTEM_KEYBINDS" \
  "$SYSTEM_ENV_VARS" \
  "$SYSTEM_STARTUP_APPS" \
  "$SYSTEM_SETTINGS" \
  "$SYSTEM_LAPTOPS" \
  "$USER_WINDOW_RULES" \
  "$USER_LAYER_RULES" \
  "$USER_KEYBINDS" \
  "$USER_ENV_VARS" \
  "$USER_STARTUP_APPS" \
  "$USER_SETTINGS" \
  "$USER_DECORATIONS" \
  "$USER_ANIMATIONS" \
  "$USER_LAPTOPS" \
  "$USER_CONFIGS_DIR/01-UserDefaults.conf" \
  "$DEST_MONITORS_CONF" \
  "$DEST_LUA_MONITORS" \
  "$DEST_WORKSPACES_CONF" \
  "$DEST_LUA_WORKSPACES" <<'PY'
import os
import re
import sys
from pathlib import Path
HEADER = """-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
"""
system_configs_dir = Path(sys.argv[1])
user_configs_dir = Path(sys.argv[2])
system_window_rules_path = Path(sys.argv[3])
system_layer_rules_path = Path(sys.argv[4])
system_keybinds_path = Path(sys.argv[5])
system_env_path = Path(sys.argv[6])
system_startup_path = Path(sys.argv[7])
system_settings_path = Path(sys.argv[8])
system_laptops_path = Path(sys.argv[9])
window_rules_path = Path(sys.argv[10])
layer_rules_path = Path(sys.argv[11])
keybinds_path = Path(sys.argv[12])
env_path = Path(sys.argv[13])
startup_path = Path(sys.argv[14])
settings_path = Path(sys.argv[15])
decorations_path = Path(sys.argv[16])
animations_path = Path(sys.argv[17])
laptops_path = Path(sys.argv[18])
user_defaults_path = Path(sys.argv[19])
monitors_conf_path = Path(sys.argv[20])
monitors_lua_path = Path(sys.argv[21])
workspaces_conf_path = Path(sys.argv[22])
workspaces_lua_path = Path(sys.argv[23])

files_out = {
    "system_env": system_configs_dir / "system_env.lua",
    "system_startup": system_configs_dir / "system_startup.lua",
    "system_window_rules": system_configs_dir / "system_window_rules.lua",
    "system_layer_rules": system_configs_dir / "system_layer_rules.lua",
    "system_keybinds": system_configs_dir / "system_keybinds.lua",
    "system_settings": system_configs_dir / "system_settings.lua",
    "system_laptops": system_configs_dir / "system_laptops.lua",
    "env": user_configs_dir / "user_env.lua",
    "startup": user_configs_dir / "user_startup.lua",
    "window_rules": user_configs_dir / "user_window_rules.lua",
    "layer_rules": user_configs_dir / "user_layer_rules.lua",
    "keybinds": user_configs_dir / "user_keybinds.lua",
    "settings": user_configs_dir / "user_settings.lua",
    "decorations": user_configs_dir / "user_decorations.lua",
    "animations": user_configs_dir / "user_animations.lua",
    "laptops": user_configs_dir / "user_laptops.lua",
    "user_defaults": user_configs_dir / "user_defaults.lua",
    "monitors": monitors_lua_path,
    "workspaces": workspaces_lua_path,
}

def strip_comment(line):
    return line.split("#", 1)[0].strip()

def split_items(value):
    return [item.strip() for item in value.split(",") if item.strip()]

def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
def write_file(path, lines):
    content = "\n".join(lines).rstrip() + "\n"
    if not content.startswith(HEADER):
        content = HEADER + "\n" + content.lstrip("\n")
    path.write_text(content, encoding="utf-8")
    print(f"[OK] Wrote {path}")

def source_examples(path):
    if not path.exists():
        return []
    lines = []
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        lines.append(f"-- {stripped}")
    return lines
def latest_legacy_file(path):
    legacy_root = path.parent / "LegacyConfigs"
    if not legacy_root.is_dir():
        return None
    candidates = []
    for snapshot in sorted(legacy_root.iterdir()):
        if not snapshot.is_dir():
            continue
        candidate = snapshot / path.name
        if candidate.is_file():
            candidates.append(candidate)
    return candidates[-1] if candidates else None

def parse_env(path):
    entries = []
    source_path = path if path.exists() else latest_legacy_file(path)
    if source_path is None:
        return entries
    if source_path != path:
        print(f"[INFO] {path.name} not found at {path}; using legacy source {source_path}")
    for raw in source_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        comma_match = re.match(r"^env\s*=\s*([^,]+)\s*,\s*(.+)$", line)
        if comma_match:
            entries.append((comma_match.group(1).strip(), comma_match.group(2).strip()))
            continue
        equals_match = re.match(r"^env\s*=\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$", line)
        if equals_match:
            entries.append((equals_match.group(1).strip(), equals_match.group(2).strip()))
    return entries

def parse_startup(path, *, variables=None, visited=None):
    entries = []
    if not path.exists():
        return entries

    if variables is None:
        variables = {}
    if visited is None:
        visited = set()

    try:
        resolved = path.resolve()
    except FileNotFoundError:
        resolved = path

    if resolved in visited:
        return []
    visited.add(resolved)

    def expand(value):
        for _ in range(8):
            new_value = value
            for name, var_value in variables.items():
                new_value = new_value.replace(f"${name}", var_value)
            if new_value == value:
                break
            value = new_value
        return os.path.expandvars(value)

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue

        source_match = re.match(r"^source\s*=\s*(.+)$", line)
        if source_match:
            source_value = expand(source_match.group(1).strip())
            source_path = Path(source_value).expanduser()
            entries.extend(parse_startup(source_path, variables=variables, visited=visited))
            continue

        variable = re.match(r"^\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$", line)
        if variable:
            variables[variable.group(1)] = expand(variable.group(2).strip())
            continue

        match = re.match(r"^exec(?:-once)?\s*=\s*(.+)$", line)
        if match:
            entries.append(expand(match.group(1).strip()))

    return entries

MONITOR_DIRECTIVE_KEYS = {
    "mirror",
    "bitdepth",
    "transform",
    "cm",
    "icc",
    "vrr",
    "addreserved",
    "reserved",
    "supports_hdr",
    "supports_wide_color",
    "supportshdr",
    "supportswidecolor",
    "max_luminance",
    "max_avg_luminance",
    "min_luminance",
    "maxluminance",
    "maxavgluminance",
    "minluminance",
    "sdr_max_luminance",
    "sdr_min_luminance",
    "sdr_eotf",
    "sdrmaxluminance",
    "sdrminluminance",
    "sdreotf",
    "sdrbrightness",
    "sdrsaturation",
}

MONITOR_FIELD_MAP = {
    "addreserved": "reserved",
    "supportswidecolor": "supports_wide_color",
    "supportshdr": "supports_hdr",
    "maxluminance": "max_luminance",
    "maxavgluminance": "max_avg_luminance",
    "minluminance": "min_luminance",
    "sdrmaxluminance": "sdr_max_luminance",
    "sdrminluminance": "sdr_min_luminance",
    "sdreotf": "sdr_eotf",
}

def parse_monitors(path):
    entries = []
    if not path.exists():
        return entries

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^monitor\s*=\s*(.+)$", line)
        if not match:
            continue

        parts = [part.strip() for part in match.group(1).split(",")]
        if len(parts) < 2:
            continue

        spec = {"output": parts[0]}
        mode_or_directive = parts[1].lower().replace("-", "_")
        extras = []

        if mode_or_directive == "disable":
            spec["mode"] = "disable"
            entries.append(spec)
            continue

        if len(parts) >= 4 and mode_or_directive not in MONITOR_DIRECTIVE_KEYS:
            spec["mode"] = parts[1]
            if parts[2]:
                spec["position"] = parts[2]
            if parts[3]:
                spec["scale"] = parts[3]
            extras = parts[4:]
        else:
            extras = parts[1:]

        i = 0
        while i < len(extras):
            key = extras[i].strip().lower().replace("-", "_")
            if not key:
                i += 1
                continue
            field = MONITOR_FIELD_MAP.get(key, key)

            if field == "reserved" and i + 4 < len(extras):
                spec["reserved"] = [
                    extras[i + 1].strip(),
                    extras[i + 2].strip(),
                    extras[i + 3].strip(),
                    extras[i + 4].strip(),
                ]
                i += 5
                continue

            if i + 1 >= len(extras):
                i += 1
                continue

            value = extras[i + 1].strip()
            if value:
                spec[field] = value
            i += 2

        entries.append(spec)

    return entries
def parse_bool_word(value):
    lowered = value.strip().lower()
    if lowered in {"on", "true", "yes"}:
        return True
    if lowered in {"off", "false", "no"}:
        return False
    return None

WORKSPACE_FIELD_MAP = {
    "gapsin": "gaps_in",
    "gapsout": "gaps_out",
    "bordersize": "border_size",
    "on_created_empty": "on_created_empty",
    "layoutopt": "layout_opts",
    "layoutopts": "layout_opts",
}

WORKSPACE_INVERTED_BOOL_FIELDS = {
    "border": "no_border",
    "rounding": "no_rounding",
    "shadow": "no_shadow",
}

def parse_workspaces(path):
    entries = []
    if not path.exists():
        return entries

    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^workspace\s*=\s*(.+)$", line)
        if not match:
            continue

        parts = [part.strip() for part in match.group(1).split(",")]
        if not parts or not parts[0]:
            continue

        rule = {"workspace": parts[0]}
        for part in parts[1:]:
            if ":" not in part:
                continue
            key, value = part.split(":", 1)
            key = key.strip().lower().replace("-", "_")
            value = value.strip()
            if not key or value == "":
                continue

            if key in WORKSPACE_INVERTED_BOOL_FIELDS:
                bool_value = parse_bool_word(value)
                if bool_value is None:
                    continue
                rule[WORKSPACE_INVERTED_BOOL_FIELDS[key]] = not bool_value
                continue

            normalized = WORKSPACE_FIELD_MAP.get(key, key)
            bool_value = parse_bool_word(value)
            if bool_value is not None:
                rule[normalized] = bool_value
            else:
                rule[normalized] = value

        entries.append(rule)

    return entries

def emit_monitor(spec):
    lines = [
        "hl.monitor({",
        f"    output = {lua_string(spec.get('output', ''))},",
    ]

    if "mode" in spec:
        lines.append(f"    mode = {lua_string(spec['mode'])},")
    if "position" in spec:
        lines.append(f"    position = {lua_string(spec['position'])},")
    if "scale" in spec:
        lines.append(f"    scale = {lua_string(spec['scale'])},")
    if "mirror" in spec:
        lines.append(f"    mirror = {lua_string(spec['mirror'])},")

    for key in [
        "bitdepth",
        "transform",
        "vrr",
        "supports_hdr",
        "supports_wide_color",
        "max_luminance",
        "max_avg_luminance",
        "min_luminance",
        "sdr_max_luminance",
        "sdr_min_luminance",
        "sdrbrightness",
        "sdrsaturation",
    ]:
        if key in spec:
            lines.append(f"    {key} = {scalar(spec[key])},")

    for key in ["cm", "icc", "sdr_eotf"]:
        if key in spec:
            lines.append(f"    {key} = {lua_string(spec[key])},")

    if "reserved" in spec and len(spec["reserved"]) == 4:
        top, right, bottom, left = spec["reserved"]
        lines.extend([
            "    reserved = {",
            f"        top = {scalar(top)},",
            f"        right = {scalar(right)},",
            f"        bottom = {scalar(bottom)},",
            f"        left = {scalar(left)},",
            "    },",
        ])

    lines.append("})")
    return "\n".join(lines)

def emit_workspace_rule(spec):
    lines = [
        "hl.workspace_rule({",
        f"    workspace = {lua_string(spec['workspace'])},",
    ]
    for key, value in spec.items():
        if key == "workspace":
            continue
        if isinstance(value, bool):
            rendered = "true" if value else "false"
        else:
            text = str(value).strip()
            if re.fullmatch(r"[-+]?\d+(\.\d+)?", text):
                rendered = text
            else:
                rendered = lua_string(text)
        lines.append(f"    {key} = {rendered},")
    lines.append("})")
    return "\n".join(lines)
def unquote(value):
    value = value.strip()
    if len(value) >= 2 and (
        (value[0] == "\"" and value[-1] == "\"")
        or (value[0] == "'" and value[-1] == "'")
    ):
        return value[1:-1]
    return value

def resolve_shell_default(value):
    value = value.strip()
    match = re.fullmatch(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\:-([^}]*)\}", value)
    if match:
        env_value = os.getenv(match.group(1), "")
        return env_value if env_value else match.group(2)
    match = re.fullmatch(r"\$\{([A-Za-z_][A-Za-z0-9_]*)-([^}]*)\}", value)
    if match:
        env_value = os.getenv(match.group(1))
        return env_value if env_value is not None else match.group(2)
    match = re.fullmatch(r"\$([A-Za-z_][A-Za-z0-9_]*)", value)
    if match:
        return os.getenv(match.group(1), "")
    return value

def parse_user_defaults(path):
    defaults = {}
    if not path.exists():
        return defaults
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$", line)
        if not match:
            continue
        key = match.group(1)
        value = unquote(resolve_shell_default(match.group(2)))
        defaults[key] = value
    return defaults

def scalar(value, *, bool_words=True):
    value = value.strip()
    lower = value.lower()
    if bool_words and lower in {"on", "true", "1", "yes"}:
        return "true"
    if bool_words and lower in {"off", "false", "0", "no"}:
        return "false"
    if re.fullmatch(r"[-+]?\d+(\.\d+)?", value):
        return value
    return lua_string(value)

def normalize_field(name):
    aliases = {
        "floating": "float",
        "pinned": "pin",
        "fullscreenstate": "fullscreen_state",
        "initialclass": "initial_class",
        "initialtitle": "initial_title",
        "xdgtag": "xdg_tag",
        "onworkspace": "workspace",
        "ignorealpha": "ignore_alpha",
        "ignorezero": "ignore_zero",
        "noanim": "no_anim",
        "noblur": "no_blur",
        "noshadow": "no_shadow",
        "nofocus": "no_focus",
        "noinitialfocus": "no_initial_focus",
        "keepaspectratio": "keep_aspect_ratio",
        "idleinhibit": "idle_inhibit",
        "bordersize": "border_size",
        "bordercolor": "border_color",
        "roundingpower": "rounding_power",
        "allowsinput": "allows_input",
        "dimaround": "dim_around",
        "focusonactivate": "focus_on_activate",
        "nearestneighbor": "nearest_neighbor",
        "nofollowmouse": "no_follow_mouse",
        "noscreenshare": "no_screen_share",
        "novrr": "no_vrr",
        "forcergbx": "force_rgbx",
        "suppressevent": "suppress_event",
        "maxsize": "max_size",
        "minsize": "min_size",
        "persistentsize": "persistent_size",
        "nomaxsize": "no_max_size",
    }
    compact = name.strip().replace("-", "_")
    return aliases.get(compact.lower(), compact)

MATCH_BOOL_FIELDS = {
    "xwayland",
    "float",
    "fullscreen",
    "pin",
    "focus",
    "group",
    "modal",
}

def parse_rule_item(item, rule):
    if item.startswith("match:"):
        body = item[len("match:"):].strip()
        if "=" in body:
            key, value = body.split("=", 1)
        else:
            parts = body.split(None, 1)
            if len(parts) != 2:
                return
            key, value = parts
        key = normalize_field(key)
        rule.setdefault("match", {})[key] = scalar(value, bool_words=key in MATCH_BOOL_FIELDS)
        return

    parts = item.split(None, 1)
    key = normalize_field(parts[0])
    value = parts[1] if len(parts) > 1 else "on"
    rule[key] = scalar(value)

def parse_block(lines, start_index):
    rule_type = "window" if lines[start_index].strip().startswith("windowrule") else "layer"
    rule = {"match": {}}
    i = start_index + 1
    while i < len(lines):
        line = strip_comment(lines[i])
        if line == "}":
            break
        if line:
            if "=" in line:
                key, value = [part.strip() for part in line.split("=", 1)]
                if key.startswith("match:"):
                    match_key = normalize_field(key[len("match:"):])
                    rule["match"][match_key] = scalar(value, bool_words=match_key in MATCH_BOOL_FIELDS)
                elif key == "name":
                    rule["name"] = lua_string(value)
                else:
                    rule[normalize_field(key)] = scalar(value)
        i += 1
    return rule_type, rule, i

def parse_rules(path, prefix):
    if not path.exists():
        return []

    parsed = []
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    i = 0
    rule_index = 1
    layer_index = 1
    pending_name = None
    while i < len(lines):
        raw_line = lines[i]
        name_hint = re.match(r"^\s*#\s*name\s*[:=]\s*(.+?)\s*$", raw_line)
        if name_hint:
            pending_name = lua_string(name_hint.group(1).strip())
            i += 1
            continue

        line = strip_comment(raw_line)
        if not line:
            i += 1
            continue

        if re.match(r"^(windowrule|layerrule)\s*\{", line):
            rule_type, rule, i = parse_block(lines, i)
            if rule.get("match"):
                if "name" not in rule:
                    if pending_name is not None:
                        rule["name"] = pending_name
                    elif rule_type == "window":
                        rule["name"] = lua_string(f"{prefix}-windowrule-{rule_index:03d}")
                        rule_index += 1
                    else:
                        rule["name"] = lua_string(f"{prefix}-layerrule-{layer_index:03d}")
                        layer_index += 1
                pending_name = None
                parsed.append((rule_type, rule))
            i += 1
            continue

        match = re.match(r"^(windowrule|layerrule)\s*=\s*(.+)$", line)
        if match:
            rule_type = "window" if match.group(1) == "windowrule" else "layer"
            rule = {"match": {}}
            for item in split_items(match.group(2)):
                parse_rule_item(item, rule)
            if rule.get("match"):
                if "name" not in rule:
                    if pending_name is not None:
                        rule["name"] = pending_name
                    elif rule_type == "window":
                        rule["name"] = lua_string(f"{prefix}-windowrule-{rule_index:03d}")
                        rule_index += 1
                    else:
                        rule["name"] = lua_string(f"{prefix}-layerrule-{layer_index:03d}")
                        layer_index += 1
                pending_name = None
                parsed.append((rule_type, rule))
            else:
                pending_name = None
            i += 1
            continue

        pending_name = None
        i += 1
    return parsed

def emit_rule(rule_type, rule):
    fn = "apply_window_rule" if rule_type == "window" else "apply_layer_rule"
    lines = [f"{fn}({{"]
    if "name" in rule:
        lines.append(f"  name = {rule['name']},")
    if rule.get("match"):
        lines.append("  match = {")
        for key, value in rule["match"].items():
            lines.append(f"    {key} = {value},")
        lines.append("  },")
    for key, value in rule.items():
        if key in {"name", "match"}:
            continue
        lines.append(f"  {key} = {value},")
    lines.append("})")
    return "\n".join(lines)

def parse_keybinds(path, *, variables=None, visited=None):
    if not path.exists():
        return []

    if variables is None:
        variables = {}
    if visited is None:
        visited = set()

    try:
        resolved = path.resolve()
    except FileNotFoundError:
        resolved = path

    if resolved in visited:
        return []
    visited.add(resolved)

    converted = []

    def expand(value):
        for _ in range(8):
            new_value = value
            for name, var_value in variables.items():
                new_value = new_value.replace(f"${name}", var_value)
            if new_value == value:
                return new_value
            value = new_value
        return value

    for raw_line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw_line)
        if not line:
            continue

        source_match = re.match(r"^source\s*=\s*(.+)$", line)
        if source_match:
            source_value = expand(source_match.group(1).strip())
            source_value = os.path.expandvars(source_value)
            source_path = Path(source_value).expanduser()
            converted.extend(parse_keybinds(source_path, variables=variables, visited=visited))
            continue

        variable = re.match(r"^\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$", line)
        if variable:
            variables[variable.group(1)] = expand(variable.group(2).strip())
            continue

        unbind = re.match(r"^unbind\s*=\s*(.+)$", line)
        if unbind:
            parts = [expand(part.strip()) for part in unbind.group(1).split(",")]
            if len(parts) >= 2:
                converted.append(f"unbind({lua_string(parts[0])}, {lua_string(parts[1])})")
            continue

        bind = re.match(r"^(bind[a-z]*)\s*=\s*(.+)$", line)
        if bind:
            binder = bind.group(1)
            parts = [expand(part.strip()) for part in bind.group(2).split(",")]
            has_description = "d" in binder and binder != "bind"
            description = ""
            if has_description and len(parts) >= 4:
                mods, key = parts[0], parts[1]
                description = parts[2]
                dispatcher = parts[3]
                args = ", ".join(part for part in parts[4:] if part)
            elif len(parts) >= 3:
                mods, key = parts[0], parts[1]
                dispatcher = parts[2]
                args = ", ".join(part for part in parts[3:] if part)
            else:
                continue

            opts = []
            if description:
                opts.append(f"description = {lua_string(description)}")
            if "l" in binder:
                opts.append("locked = true")
            if "e" in binder or "r" in binder:
                opts.append("[\"repeat\"] = true")
            opts_text = ", { " + ", ".join(opts) + " }" if opts else ""

            if dispatcher == "exec":
                converted.append(f"bind({lua_string(mods)}, {lua_string(key)}, exec_cmd({lua_string(args)}){opts_text})")
            else:
                converted.append(f"bind({lua_string(mods)}, {lua_string(key)}, dispatch({lua_string(dispatcher)}, {lua_string(args)}){opts_text})")

    return converted

system_window_rules = [rule for rule in parse_rules(system_window_rules_path, "system-window") if rule[0] == "window"]
system_layer_rules = [rule for rule in parse_rules(system_layer_rules_path, "system-layer") if rule[0] == "layer"]
window_rules = [rule for rule in parse_rules(window_rules_path, "user-window") if rule[0] == "window"]
layer_rules = [rule for rule in parse_rules(layer_rules_path, "user-layer") if rule[0] == "layer"]
base_keybind_vars = {}
parse_keybinds(user_defaults_path, variables=base_keybind_vars)
system_keybinds = parse_keybinds(system_keybinds_path, variables=dict(base_keybind_vars))
keybinds = parse_keybinds(keybinds_path, variables=dict(base_keybind_vars))
system_env_entries = parse_env(system_env_path)
env_entries = parse_env(env_path)
system_startup_entries = parse_startup(system_startup_path, variables=dict(base_keybind_vars))
startup_entries = parse_startup(startup_path, variables=dict(base_keybind_vars))
monitor_entries = parse_monitors(monitors_conf_path)
workspace_entries = parse_workspaces(workspaces_conf_path)
parsed_user_defaults = parse_user_defaults(user_defaults_path)
resolved_edit = parsed_user_defaults.get("edit", os.getenv("EDITOR") or "nano")
resolved_visual = parsed_user_defaults.get("visual", os.getenv("VISUAL") or "")
resolved_term = parsed_user_defaults.get("term", "kitty")
resolved_files = parsed_user_defaults.get("files", "thunar")
resolved_search_engine = parsed_user_defaults.get(
    "Search_Engine",
    parsed_user_defaults.get("search_engine", "https://www.google.com/search?q={}"),
)

user_defaults_lines = [
    "-- User defaults overrides (auto-generated).",
    "-- Edit this file for terminal/editor/file-manager/search defaults in Lua mode.",
    "-- Example:",
    "-- KOOLDOTS_DEFAULTS.term = \"ghostty\"",
    "",
    "KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}",
    f"KOOLDOTS_DEFAULTS.edit = {lua_string(resolved_edit)}",
    f"KOOLDOTS_DEFAULTS.visual = {lua_string(resolved_visual)}",
    f"KOOLDOTS_DEFAULTS.term = {lua_string(resolved_term)}",
    f"KOOLDOTS_DEFAULTS.files = {lua_string(resolved_files)}",
    f"KOOLDOTS_DEFAULTS.search_engine = {lua_string(resolved_search_engine)}",
    f"KOOLDOTS_DEFAULTS.Search_Engine = {lua_string(resolved_search_engine)}",
]
write_file(files_out["user_defaults"], user_defaults_lines)

if monitor_entries:
    monitor_lines = [
        "-- Monitors migrated from monitors.conf (auto-generated).",
        "-- Edit monitors.conf and rerun scripts/migrate-hypr-to-lua.sh to regenerate this file.",
        "",
    ]
    for spec in monitor_entries:
        monitor_lines.append(emit_monitor(spec))
        monitor_lines.append("")
    write_file(files_out["monitors"], monitor_lines)
else:
    print(f"[INFO] No active monitor entries found in {monitors_conf_path}; keeping existing {files_out['monitors']}")
if workspace_entries:
    workspace_lines = [
        "-- Workspace rules migrated from workspaces.conf (auto-generated).",
        "-- Edit workspaces.conf and rerun scripts/migrate-hypr-to-lua.sh to regenerate this file.",
        "",
    ]
    for spec in workspace_entries:
        workspace_lines.append(emit_workspace_rule(spec))
        workspace_lines.append("")
    write_file(files_out["workspaces"], workspace_lines)
else:
    print(f"[INFO] No active workspace rules found in {workspaces_conf_path}; keeping existing {files_out['workspaces']}")
system_env_lines = [
    "-- System defaults migrated from configs/ENVariables.conf (auto-generated).",
    "-- Edit this file to keep your previous configs/ ENVariables customizations in Lua mode.",
    "-- Example:",
    "-- hl.env(\"QT_QPA_PLATFORMTHEME\", \"qt6ct\")",
    "",
]
if system_env_entries:
    system_env_lines.append("-- Converted from configs/ENVariables.conf")
    for key, value in system_env_entries:
        system_env_lines.append(f"hl.env({lua_string(key)}, {lua_string(value)})")
    write_file(files_out["system_env"], system_env_lines)
else:
    if files_out["system_env"].exists():
        print(f"[INFO] No active env entries found in {system_env_path}; keeping existing {files_out['system_env']}")
    else:
        system_env_lines.append("-- No active env entries were found in configs/ENVariables.conf.")
        write_file(files_out["system_env"], system_env_lines)

startup_readiness = (
    "runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}; "
    "export XDG_RUNTIME_DIR=\"$runtime\"; "
    "for _ in $(seq 1 200); do "
    "if [ -n \"$WAYLAND_DISPLAY\" ] && [ -S \"$runtime/$WAYLAND_DISPLAY\" ]; then break; fi; "
    "for sock in \"$runtime\"/wayland-[0-9]*; do [ -S \"$sock\" ] || continue; "
    "case \"$(basename \"$sock\")\" in *awww*) continue ;; esac; "
    "export WAYLAND_DISPLAY=\"$(basename \"$sock\")\"; break 2; done; "
    "sleep 0.1; done; "
    "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then "
    "hypr_sock=\"$runtime/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock\"; "
    "for _ in $(seq 1 200); do [ -S \"$hypr_sock\" ] && break; sleep 0.1; done; fi"
)

system_startup_lines = [
    "-- System defaults migrated from configs/Startup_Apps.conf (auto-generated).",
    "-- Add commands with exec_once(\"your command\")",
    "-- Example:",
    "-- exec_once(\"swaync\")",
    "",
    "local session = os.getenv(\"HYPRLAND_INSTANCE_SIGNATURE\") or \"default\"",
    "",
    "local function shell_quote(value)",
    "  return \"'\" .. tostring(value):gsub(\"'\", \"'\\\\''\") .. \"'\"",
    "end",
    "",
    "local function exec_once(cmd)",
    "  local key = cmd:gsub(\"[^%w_.-]\", \"_\"):sub(1, 80)",
    "  local marker = \"/tmp/hypr-lua-system-exec-once-\" .. session .. \"-\" .. key",
    "  local log = \"/tmp/hypr-lua-system-startup-\" .. key .. \".log\"",
    f"  local readiness = {lua_string(startup_readiness)}",
    "  local inner = readiness .. \"; \" .. cmd",
    "  local script = \"[ -e \" .. shell_quote(marker) .. \" ] || { touch \" .. shell_quote(marker) .. \" && sh -lc \" .. shell_quote(inner) .. \" >>\" .. shell_quote(log) .. \" 2>&1 & }\"",
    "  os.execute(\"sh -lc \" .. shell_quote(script))",
    "end",
    "",
]
if system_startup_entries:
    system_startup_lines.append("-- Converted from configs/Startup_Apps.conf")
    system_startup_lines.append("local startup_commands = {")
    for cmd in system_startup_entries:
        system_startup_lines.append(f"  {lua_string(cmd)},")
    system_startup_lines.extend([
        "}",
        "",
        "local function run_startup_commands()",
        "  for _, cmd in ipairs(startup_commands) do",
        "    exec_once(cmd)",
        "  end",
        "end",
        "",
        "if hl and hl.on then",
        "  hl.on(\"hyprland.start\", run_startup_commands)",
        "else",
        "  run_startup_commands()",
        "end",
    ])
    write_file(files_out["system_startup"], system_startup_lines)
else:
    if files_out["system_startup"].exists():
        print(f"[INFO] No active startup entries found in {system_startup_path}; keeping existing {files_out['system_startup']}")
    else:
        system_startup_lines.append("-- No active startup entries were found in configs/Startup_Apps.conf.")
        write_file(files_out["system_startup"], system_startup_lines)

system_window_lines = [
    "-- System defaults migrated from configs/WindowRules.conf (auto-generated).",
    "-- Add additional rules with apply_window_rule({...}).",
    "-- Example:",
    "-- apply_window_rule({",
    "--   name = \"My System Rule\",",
    "--   match = { class = \"^pavucontrol$\" },",
    "--   float = true,",
    "-- })",
    "",
    "local function apply_window_rule(rule)",
    "  if hl.window_rule then",
    "    hl.window_rule(rule)",
    "  end",
    "end",
    "",
]
if system_window_rules:
    system_window_lines.append("-- Converted from configs/WindowRules.conf")
    for rule_type, rule in system_window_rules:
        system_window_lines.append(emit_rule(rule_type, rule))
        system_window_lines.append("")
else:
    system_window_lines.append("-- No active window rules were found in configs/WindowRules.conf.")
write_file(files_out["system_window_rules"], system_window_lines)

system_layer_lines = [
    "-- System defaults migrated from configs/LayerRules.conf (auto-generated).",
    "-- Add additional rules with apply_layer_rule({...}).",
    "-- Example:",
    "-- apply_layer_rule({",
    "--   name = \"My Layer Rule\",",
    "--   match = { namespace = \"rofi\" },",
    "--   blur = true,",
    "-- })",
    "",
    "local function apply_layer_rule(rule)",
    "  if hl.layer_rule then",
    "    hl.layer_rule(rule)",
    "  end",
    "end",
    "",
]
if system_layer_rules:
    system_layer_lines.append("-- Converted from configs/LayerRules.conf")
    for rule_type, rule in system_layer_rules:
        system_layer_lines.append(emit_rule(rule_type, rule))
        system_layer_lines.append("")
else:
    system_layer_lines.append("-- No active layer rules were found in configs/LayerRules.conf.")
write_file(files_out["system_layer_rules"], system_layer_lines)

system_keybind_lines = [
    "-- System defaults migrated from configs/Keybinds.conf (auto-generated).",
    "-- Add keybinds with bind(\"MODS\", \"KEY\", fn, opts).",
    "-- Example:",
    "-- bind(\"SUPER\", \"Z\", exec_cmd(\"thunar\"), { description = \"Open file manager\" })",
    "",
    "local dsp = hl.dsp or hl",
    "local function resolve_cmd(cmd)",
    "  local defaults = rawget(_G, \"KOOLDOTS_DEFAULTS\") or {}",
    "  local resolved_term = defaults.term or os.getenv(\"TERMINAL\") or \"kitty\"",
    "  local resolved_files = defaults.files or \"thunar\"",
    "  local resolved_edit = defaults.edit or os.getenv(\"EDITOR\") or \"nano\"",
    "  cmd = tostring(cmd)",
    "  cmd = cmd:gsub(\"%$term\", resolved_term)",
    "  cmd = cmd:gsub(\"%$files\", resolved_files)",
    "  cmd = cmd:gsub(\"%$edit\", resolved_edit)",
    "  return cmd",
    "end",
    "",
    "local function exec_cmd(cmd)",
    "  local resolved = resolve_cmd(cmd)",
    "  if dsp and dsp.exec_cmd then",
    "    return dsp.exec_cmd(resolved)",
    "  end",
    "  return function() hl.exec_cmd(resolved) end",
    "end",
    "",
    "local function shell_quote(value)",
    "  return \"'\" .. tostring(value):gsub(\"'\", \"'\\\\''\") .. \"'\"",
    "end",
    "",
    "local function raw_dispatch_cmd(command)",
    "  if dsp and dsp.exec_raw then",
    "    return dsp.exec_raw(tostring(command))",
    "  end",
    "  local expression = \"hl.dsp.exec_raw(\" .. string.format(\"%q\", tostring(command)) .. \")\"",
    "  return exec_cmd(\"hyprctl dispatch \" .. shell_quote(expression))",
    "end",
    "",
    "local function trim(value)",
    "  return (value or \"\"):gsub(\"^%s+\", \"\"):gsub(\"%s+$\", \"\")",
    "end",
    "",
    "local function chord(mods, key)",
    "  mods = trim(mods):gsub(\"%s+\", \" + \")",
    "  key = trim(key)",
    "  if mods == \"\" then",
    "    return key",
    "  end",
    "  return mods .. \" + \" .. key",
    "end",
    "",
    "local function key_variants(key, mods)",
    "  key = trim(key):gsub(\"^xf86\", \"XF86\")",
    "  local key_aliases = {",
    "    XF86AudioPlayPause = \"XF86AudioPlay\",",
    "    XF86audiolowervolume = \"XF86AudioLowerVolume\",",
    "    XF86audiomute = \"XF86AudioMute\",",
    "    XF86audioraisevolume = \"XF86AudioRaiseVolume\",",
    "    XF86audiostop = \"XF86AudioStop\",",
    "  }",
    "  key = key_aliases[key] or key",
    "  local shifted_number_keys = {",
    "    [\"code:10\"] = \"exclam\",",
    "    [\"code:11\"] = \"at\",",
    "    [\"code:12\"] = \"numbersign\",",
    "    [\"code:13\"] = \"dollar\",",
    "    [\"code:14\"] = \"percent\",",
    "    [\"code:15\"] = \"asciicircum\",",
    "    [\"code:16\"] = \"ampersand\",",
    "    [\"code:17\"] = \"asterisk\",",
    "    [\"code:18\"] = \"parenleft\",",
    "    [\"code:19\"] = \"parenright\",",
    "  }",
    "  local number_keys = {",
    "    [\"code:10\"] = \"1\",",
    "    [\"code:11\"] = \"2\",",
    "    [\"code:12\"] = \"3\",",
    "    [\"code:13\"] = \"4\",",
    "    [\"code:14\"] = \"5\",",
    "    [\"code:15\"] = \"6\",",
    "    [\"code:16\"] = \"7\",",
    "    [\"code:17\"] = \"8\",",
    "    [\"code:18\"] = \"9\",",
    "    [\"code:19\"] = \"0\",",
    "  }",
    "  if mods:match(\"SHIFT\") and shifted_number_keys[key] then",
    "    local number_key = number_keys[key]",
    "    if number_key then",
    "      return { shifted_number_keys[key], number_key }",
    "    end",
    "    return { shifted_number_keys[key] }",
    "  end",
    "  if number_keys[key] then",
    "    return { number_keys[key] }",
    "  end",
    "  return { key }",
    "end",
    "",
    "local function workspace_value(value)",
    "  value = trim(value)",
    "  return tonumber(value) or value",
    "end",
    "",
    "local function direction(value)",
    "  local directions = {",
    "    l = \"left\",",
    "    r = \"right\",",
    "    u = \"up\",",
    "    d = \"down\",",
    "    left = \"left\",",
    "    right = \"right\",",
    "    up = \"up\",",
    "    down = \"down\",",
    "  }",
    "  return directions[trim(value)] or trim(value)",
    "end",
    "",
    "local function dispatch(name, args)",
    "  local window_api = (dsp and dsp.window) or hl.window or {}",
    "  name = trim(name)",
    "  args = trim(args)",
    "  if name == \"exec\" then",
    "    return exec_cmd(args)",
    "  end",
    "  if name == \"killactive\" and window_api.close then",
    "    return window_api.close()",
    "  end",
    "  if name == \"fullscreen\" and window_api.fullscreen then",
    "    if args == \"1\" then",
    "      return window_api.fullscreen({ mode = \"maximized\" })",
    "    end",
    "    return window_api.fullscreen({ mode = \"fullscreen\" })",
    "  end",
    "  if name == \"movefocus\" and dsp and dsp.focus then",
    "    return function()",
    "      local ok, dispatcher = pcall(dsp.focus, { direction = direction(args) })",
    "      if ok and dispatcher then",
    "        hl.dispatch(dispatcher)",
    "      end",
    "    end",
    "  end",
    "  if name == \"cyclenext\" then",
    "    if args == \"prev\" or args == \"b\" then",
    "      return exec_cmd(\"$HOME/.config/hypr/scripts/LuaCycleWindow.sh previous\")",
    "    end",
    "    return exec_cmd(\"$HOME/.config/hypr/scripts/LuaCycleWindow.sh next\")",
    "  end",
    "  if name == \"swapwindow\" then",
    "    local swap_direction = trim(args)",
    "    if swap_direction == \"\" then",
    "      return nil",
    "    end",
    "    return exec_cmd(\"$HOME/.config/hypr/scripts/LuaSwapWindow.sh \" .. swap_direction)",
    "  end",
    "  if name == \"workspace\" and dsp and dsp.focus then",
    "    return function() hl.dispatch(dsp.focus({ workspace = workspace_value(args) })) end",
    "  end",
    "  if name == \"movetoworkspace\" and window_api.move then",
    "    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args) })) end",
    "  end",
    "  if name == \"movetoworkspacesilent\" and window_api.move then",
    "    return function() hl.dispatch(window_api.move({ workspace = workspace_value(args), follow = false })) end",
    "  end",
    "  if name == \"togglefloating\" and window_api.float then",
    "    return function() hl.dispatch(window_api.float({ action = \"toggle\" })) end",
    "  end",
    "  if name == \"resizewindow\" and window_api.resize then",
    "    return window_api.resize()",
    "  end",
    "  if name == \"resizeactive\" and window_api.resize then",
    "    local x, y = args:match(\"^(%-?%d+)%s+(%-?%d+)$\")",
    "    if x and y then",
    "      return window_api.resize({ x = tonumber(x) or 0, y = tonumber(y) or 0, relative = true })",
    "    end",
    "  end",
    "  if name == \"movewindow\" and args == \"\" and window_api.drag then",
    "    return window_api.drag()",
    "  end",
    "  if args ~= \"\" then",
    "    return raw_dispatch_cmd(name .. \" \" .. args)",
    "  end",
    "  return raw_dispatch_cmd(name)",
    "end",
    "",
    "local function bind(mods, key, fn, opts)",
    "  local seen = {}",
    "  for _, key_variant in ipairs(key_variants(key, mods)) do",
    "    local key_chord = chord(mods, key_variant)",
    "    if not seen[key_chord] then",
    "      seen[key_chord] = true",
    "      if opts then",
    "        hl.bind(key_chord, fn, opts)",
    "      else",
    "        hl.bind(key_chord, fn)",
    "      end",
    "    end",
    "  end",
    "end",
    "",
    "local function unbind(mods, key)",
    "  if hl.unbind then",
    "    local seen = {}",
    "    for _, key_variant in ipairs(key_variants(key, mods)) do",
    "      local key_chord = chord(mods, key_variant)",
    "      if not seen[key_chord] then",
    "        seen[key_chord] = true",
    "        local ok = pcall(hl.unbind, mods, key_variant)",
    "        if not ok then",
    "          pcall(hl.unbind, key_chord)",
    "        end",
    "      end",
    "    end",
    "  end",
    "end",
    "",
]
if system_keybinds:
    system_keybind_lines.append("-- Converted from configs/Keybinds.conf")
    system_keybind_lines.extend(system_keybinds)
    write_file(files_out["system_keybinds"], system_keybind_lines)
else:
    if files_out["system_keybinds"].exists():
        print(f"[INFO] No active keybind entries found in {system_keybinds_path}; keeping existing {files_out['system_keybinds']}")
    else:
        system_keybind_lines.append("-- No active keybind entries were found in configs/Keybinds.conf.")
        write_file(files_out["system_keybinds"], system_keybind_lines)

for name, source in [
    ("system_settings", system_settings_path),
    ("system_laptops", system_laptops_path),
]:
    title = f"-- {name.replace('_', ' ').title()} (auto-generated)."
    lines = [
        title,
        "-- This file keeps migrated settings split from user overrides.",
        "-- Add only Lua entries here.",
        "-- Example:",
        "-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })",
        "",
    ]
    reference = source_examples(source)
    if reference:
        lines.extend([
            f"-- Source reference from {source.name} (hyprlang):",
            *reference,
        ])
    else:
        lines.append(f"-- No active entries were found in {source.name}.")
    write_file(files_out[name], lines)

env_lines = [
    "-- User ENV overrides (auto-generated).",
    "-- Add values using: hl.env(\"KEY\", \"VALUE\")",
    "-- Example:",
    "-- hl.env(\"MOZ_ENABLE_WAYLAND\", \"1\")",
    "",
]
if env_entries:
    env_lines.append("-- Converted from ENVariables.conf")
    for key, value in env_entries:
        env_lines.append(f"hl.env({lua_string(key)}, {lua_string(value)})")
    write_file(files_out["env"], env_lines)
else:
    if files_out["env"].exists():
        print(f"[INFO] No active env entries found in {env_path}; keeping existing {files_out['env']}")
    else:
        env_lines.extend([
            "-- No active env entries were found in ENVariables.conf.",
            "-- Uncomment and customize examples below:",
            "-- hl.env(\"GDK_SCALE\", \"1\")",
            "-- hl.env(\"QT_SCALE_FACTOR\", \"1\")",
        ])
        write_file(files_out["env"], env_lines)

startup_lines = [
    "-- User startup overrides (auto-generated).",
    "-- Add commands with exec_once(\"your command\")",
    "-- Example:",
    "-- exec_once(\"$HOME/.config/hypr/UserScripts/MyStartup.sh\")",
    "",
    "local user_startup_helper = nil",
    "do",
    "  local source = (debug.getinfo(1, \"S\") or {}).source or \"\"",
    "  local source_path = source:match(\"^@(.+)$\")",
    "  local source_dir = source_path and source_path:match(\"^(.*)/[^/]+$\") or nil",
    "  local home = os.getenv(\"HOME\") or \"\"",
    "  local candidate_paths = {",
    "    source_dir and (source_dir .. \"/../lua/user_startup_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/lua/user_startup_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/user_startup_helper.lua\") or nil,",
    "  }",
    "",
    "  local tried_paths = {}",
    "  for _, helper_path in ipairs(candidate_paths) do",
    "    if helper_path then",
    "      table.insert(tried_paths, helper_path)",
    "      local f = io.open(helper_path, \"r\")",
    "      if f then",
    "        f:close()",
    "        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)",
    "        if loaded_ok and type(loaded_helpers) == \"table\" and loaded_helpers.exec_once then",
    "          user_startup_helper = loaded_helpers",
    "          break",
    "        end",
    "      end",
    "    end",
    "  end",
    "",
    "  if not user_startup_helper then",
    "    error(\"Failed to load user_startup_helper.lua from: \" .. table.concat(tried_paths, \", \"))",
    "  end",
    "end",
    "local exec_once = user_startup_helper.exec_once",
    "",
]
if startup_entries:
    startup_lines.append("-- Converted from Startup_Apps.conf")
    startup_lines.append("local startup_commands = {")
    for cmd in startup_entries:
        startup_lines.append(f"  {lua_string(cmd)},")
    startup_lines.extend([
        "}",
        "",
        "local function run_startup_commands()",
        "  for _, cmd in ipairs(startup_commands) do",
        "    exec_once(cmd)",
        "  end",
        "end",
        "",
        "if hl and hl.on then",
        "  hl.on(\"hyprland.start\", run_startup_commands)",
        "else",
        "  run_startup_commands()",
        "end",
    ])
    write_file(files_out["startup"], startup_lines)
else:
    if files_out["startup"].exists():
        print(f"[INFO] No active startup entries found in {startup_path}; keeping existing {files_out['startup']}")
    else:
        startup_lines.extend([
            "-- No active startup entries were found in Startup_Apps.conf.",
            "-- exec_once(\"nm-applet --indicator\")",
        ])
        write_file(files_out["startup"], startup_lines)

window_lines = [
    "-- User window rule overrides (auto-generated).",
    "-- Add your own rules with apply_window_rule({...})",
    "-- Example:",
    "-- apply_window_rule({",
    "--   name = \"My Float Rule\",",
    "--   match = { class = \"^pavucontrol$\" },",
    "--   float = true,",
    "--   center = true,",
    "-- })",
    "",
    "local user_window_rules_helper = nil",
    "do",
    "  local source = (debug.getinfo(1, \"S\") or {}).source or \"\"",
    "  local source_path = source:match(\"^@(.+)$\")",
    "  local source_dir = source_path and source_path:match(\"^(.*)/[^/]+$\") or nil",
    "  local home = os.getenv(\"HOME\") or \"\"",
    "  local candidate_paths = {",
    "    source_dir and (source_dir .. \"/../lua/user_window_rules_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/lua/user_window_rules_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/user_window_rules_helper.lua\") or nil,",
    "  }",
    "",
    "  local tried_paths = {}",
    "  for _, helper_path in ipairs(candidate_paths) do",
    "    if helper_path then",
    "      table.insert(tried_paths, helper_path)",
    "      local f = io.open(helper_path, \"r\")",
    "      if f then",
    "        f:close()",
    "        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)",
    "        if loaded_ok and type(loaded_helpers) == \"table\" and loaded_helpers.apply_window_rule then",
    "          user_window_rules_helper = loaded_helpers",
    "          break",
    "        end",
    "      end",
    "    end",
    "  end",
    "",
    "  if not user_window_rules_helper then",
    "    error(\"Failed to load user_window_rules_helper.lua from: \" .. table.concat(tried_paths, \", \"))",
    "  end",
    "end",
    "local apply_window_rule = user_window_rules_helper.apply_window_rule",
    "",
]
if window_rules:
    window_lines.append("-- Converted from WindowRules.conf")
    for rule_type, rule in window_rules:
        window_lines.append(emit_rule(rule_type, rule))
        window_lines.append("")
else:
    window_lines.append("-- No active window rules were found in WindowRules.conf.")
write_file(files_out["window_rules"], window_lines)

layer_lines = [
    "-- User layer rule overrides (auto-generated).",
    "-- Add your own rules with apply_layer_rule({...})",
    "-- Example:",
    "-- apply_layer_rule({",
    "--   name = \"My Layer Rule\",",
    "--   match = { namespace = \"notifications\" },",
    "--   blur = true,",
    "-- })",
    "",
    "local user_layer_rules_helper = nil",
    "do",
    "  local source = (debug.getinfo(1, \"S\") or {}).source or \"\"",
    "  local source_path = source:match(\"^@(.+)$\")",
    "  local source_dir = source_path and source_path:match(\"^(.*)/[^/]+$\") or nil",
    "  local home = os.getenv(\"HOME\") or \"\"",
    "  local candidate_paths = {",
    "    source_dir and (source_dir .. \"/../lua/user_layer_rules_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/lua/user_layer_rules_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/user_layer_rules_helper.lua\") or nil,",
    "  }",
    "",
    "  local tried_paths = {}",
    "  for _, helper_path in ipairs(candidate_paths) do",
    "    if helper_path then",
    "      table.insert(tried_paths, helper_path)",
    "      local f = io.open(helper_path, \"r\")",
    "      if f then",
    "        f:close()",
    "        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)",
    "        if loaded_ok and type(loaded_helpers) == \"table\" and loaded_helpers.apply_layer_rule then",
    "          user_layer_rules_helper = loaded_helpers",
    "          break",
    "        end",
    "      end",
    "    end",
    "  end",
    "",
    "  if not user_layer_rules_helper then",
    "    error(\"Failed to load user_layer_rules_helper.lua from: \" .. table.concat(tried_paths, \", \"))",
    "  end",
    "end",
    "local apply_layer_rule = user_layer_rules_helper.apply_layer_rule",
    "",
]
if layer_rules:
    layer_lines.append("-- Converted from LayerRules.conf")
    for rule_type, rule in layer_rules:
        layer_lines.append(emit_rule(rule_type, rule))
        layer_lines.append("")
else:
    layer_lines.append("-- No active layer rules were found in LayerRules.conf.")
write_file(files_out["layer_rules"], layer_lines)

keybind_lines = [
    "-- User keybind overrides (auto-generated).",
    "-- Add keybinds with bind(\"MODS\", \"KEY\", fn, opts).",
    "-- Example:",
    "-- bind(\"SUPER\", \"Z\", exec_cmd(\"ghostty\"), { description = \"Launch ghostty\" })",
    "-- Helper functions live in ~/.config/hypr/lua/user_keybinds_helper.lua so they can be updated separately.",
    "local user_keybinds_helper = nil",
    "do",
    "  local source = (debug.getinfo(1, \"S\") or {}).source or \"\"",
    "  local source_path = source:match(\"^@(.+)$\")",
    "  local source_dir = source_path and source_path:match(\"^(.*)/[^/]+$\") or nil",
    "  local home = os.getenv(\"HOME\") or \"\"",
    "  local candidate_paths = {",
    "    source_dir and (source_dir .. \"/../lua/user_keybinds_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/lua/user_keybinds_helper.lua\") or nil,",
    "    home ~= \"\" and (home .. \"/.config/hypr/user_keybinds_helper.lua\") or nil,",
    "  }",
    "",
    "  local tried_paths = {}",
    "  for _, helper_path in ipairs(candidate_paths) do",
    "    if helper_path then",
    "      table.insert(tried_paths, helper_path)",
    "      local f = io.open(helper_path, \"r\")",
    "      if f then",
    "        f:close()",
    "        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)",
    "        if loaded_ok and type(loaded_helpers) == \"table\" and loaded_helpers.bind then",
    "          user_keybinds_helper = loaded_helpers",
    "          break",
    "        end",
    "      end",
    "    end",
    "  end",
    "",
    "  if not user_keybinds_helper then",
    "    error(\"Failed to load user_keybinds_helper.lua from: \" .. table.concat(tried_paths, \", \"))",
    "  end",
    "end",
    "local exec_cmd = user_keybinds_helper.exec_cmd",
    "local dispatch = user_keybinds_helper.dispatch",
    "local bind = user_keybinds_helper.bind",
    "local unbind = user_keybinds_helper.unbind",
    "",
]
if keybinds:
    keybind_lines.append("-- Converted from UserKeybinds.conf")
    keybind_lines.extend(keybinds)
    write_file(files_out["keybinds"], keybind_lines)
else:
    if files_out["keybinds"].exists():
        print(f"[INFO] No active keybind entries found in {keybinds_path}; keeping existing {files_out['keybinds']}")
    else:
        keybind_lines.extend([
            "-- No active keybind entries were found in UserKeybinds.conf.",
            "-- bind(\"SUPER\", \"Z\", exec_cmd(\"thunar\"), { description = \"Open file manager\" })",
        ])
        write_file(files_out["keybinds"], keybind_lines)

for name, source in [
    ("settings", settings_path),
    ("decorations", decorations_path),
    ("animations", animations_path),
    ("laptops", laptops_path),
]:
    title = f"-- User {name} overrides (auto-generated)."
    lines = [
        title,
        "-- This file is intentionally split from other user overrides.",
        "-- Add only user-specific Lua overrides here.",
        "-- Example:",
        "-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })",
        "",
    ]
    reference = source_examples(source)
    if name == "decorations":
        if reference or not files_out[name].exists():
            decoration_lines = [
                title,
                "-- This file is intentionally split from other user overrides.",
                "-- Add only user-specific Lua overrides here.",
                "-- Reads active border/shadow colors from wallust-hyprland.conf.",
                "",
                "local config_home = os.getenv(\"XDG_CONFIG_HOME\") or ((os.getenv(\"HOME\") or \"\") .. \"/.config\")",
                "local wallust_colors_file = config_home .. \"/hypr/wallust/wallust-hyprland.conf\"",
                "",
                "local user_decorations_helper = nil",
                "do",
                "  local source = (debug.getinfo(1, \"S\") or {}).source or \"\"",
                "  local source_path = source:match(\"^@(.+)$\")",
                "  local source_dir = source_path and source_path:match(\"^(.*)/[^/]+$\") or nil",
                "  local home = os.getenv(\"HOME\") or \"\"",
                "  local candidate_paths = {",
                "    source_dir and (source_dir .. \"/../lua/user_decorations_helper.lua\") or nil,",
                "    home ~= \"\" and (home .. \"/.config/hypr/lua/user_decorations_helper.lua\") or nil,",
                "    home ~= \"\" and (home .. \"/.config/hypr/user_decorations_helper.lua\") or nil,",
                "  }",
                "",
                "  local tried_paths = {}",
                "  for _, helper_path in ipairs(candidate_paths) do",
                "    if helper_path then",
                "      table.insert(tried_paths, helper_path)",
                "      local f = io.open(helper_path, \"r\")",
                "      if f then",
                "        f:close()",
                "        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)",
                "        if loaded_ok and type(loaded_helpers) == \"table\" and loaded_helpers.load_wallust_colors then",
                "          user_decorations_helper = loaded_helpers",
                "          break",
                "        end",
                "      end",
                "    end",
                "  end",
                "",
                "  if not user_decorations_helper then",
                "    error(\"Failed to load user_decorations_helper.lua from: \" .. table.concat(tried_paths, \", \"))",
                "  end",
                "end",
                "local load_wallust_colors = user_decorations_helper.load_wallust_colors",
                "",
                "local wallust = load_wallust_colors(wallust_colors_file)",
                "local active_border = wallust.color12 or \"rgba(8db4ffff)\"",
                "local inactive_border = wallust.color10 or \"rgba(5f6578ff)\"",
                "local group_border_active = wallust.color15 or \"rgba(ffffffff)\"",
                "local groupbar_active = wallust.color0 or \"rgba(0f111aff)\"",
                "",
                "hl.config({",
                "  general = {",
                "    border_size = 2,",
                "    gaps_in = 2,",
                "    gaps_out = 4,",
                "    col = {",
                "      active_border = active_border,",
                "      inactive_border = inactive_border,",
                "    },",
                "  },",
                "})",
                "",
                "hl.config({",
                "  decoration = {",
                "    rounding = 10,",
                "    active_opacity = 1.0,",
                "    inactive_opacity = 0.9,",
                "    fullscreen_opacity = 1.0,",
                "    dim_inactive = true,",
                "    dim_strength = 0.1,",
                "    dim_special = 0.8,",
                "    shadow = {",
                "      enabled = true,",
                "      range = 3,",
                "      render_power = 1,",
                "      color = active_border,",
                "      color_inactive = inactive_border,",
                "    },",
                "    blur = {",
                "      enabled = true,",
                "      size = 6,",
                "      passes = 3,",
                "      new_optimizations = true,",
                "      xray = true,",
                "      ignore_opacity = true,",
                "      special = true,",
                "      popups = true,",
                "    },",
                "  },",
                "})",
                "",
                "hl.config({",
                "  group = {",
                "    col = {",
                "      border_active = group_border_active,",
                "    },",
                "    groupbar = {",
                "      col = {",
                "        active = groupbar_active,",
                "      },",
                "    },",
                "  },",
                "})",
            ]
            if reference:
                decoration_lines.extend([
                    "",
                    f"-- Source reference from {source.name} (hyprlang):",
                    *reference,
                ])
            write_file(files_out[name], decoration_lines)
        else:
            print(f"[INFO] No active entries found in {source}; keeping existing {files_out[name]}")
        continue
    if reference:
        lines.extend([
            f"-- Source reference from {source.name} (hyprlang):",
            *reference,
        ])
        write_file(files_out[name], lines)
    else:
        if files_out[name].exists():
            print(f"[INFO] No active entries found in {source}; keeping existing {files_out[name]}")
        else:
            lines.append(f"-- No active entries were found in {source.name}.")
            write_file(files_out[name], lines)
PY

cat > "$USER_OVERRIDES_SHIM" <<'LUA'
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- Auto-generated by scripts/migrate-hypr-to-lua.sh.
-- Loads split system/user Lua files from ~/.config/hypr/configs and ~/.config/hypr/UserConfigs.
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local hyprDir = configHome .. "/hypr"
local systemDir = hyprDir .. "/configs"
local userDir = configHome .. "/hypr/UserConfigs"

local function load_optional(path)
  local ok, err = pcall(dofile, path)
  if ok then
    return true
  end
  if err and tostring(err):find("No such file or directory", 1, true) ~= nil then
    return false
  end
  print("[WARN] Unable to load user override file " .. path .. ": " .. tostring(err))
  return false
end

local system_files = {
  "system_env.lua",
  "system_startup.lua",
  "system_window_rules.lua",
  "system_layer_rules.lua",
  "system_keybinds.lua",
  "system_settings.lua",
  "system_laptops.lua",
}
for _, file in ipairs(system_files) do
  local primary = systemDir .. "/" .. file
  local legacy = userDir .. "/" .. file
  if not load_optional(primary) then
    load_optional(legacy)
  end
end
local loaded_user_split = false

local user_files = {
  "user_env.lua",
  "user_startup.lua",
  "user_window_rules.lua",
  "user_layer_rules.lua",
  "user_keybinds.lua",
  "user_settings.lua",
  "user_decorations.lua",
  "user_animations.lua",
  "user_laptops.lua",
}
for _, file in ipairs(user_files) do
  local path = userDir .. "/" .. file
  if load_optional(path) then
    loaded_user_split = true
  end
end
if not loaded_user_split then
  load_optional(userDir .. "/user_overrides.lua") -- backward compatibility with older single-file overrides
end
LUA

move_conf_files_to_legacy() {
  local source_dir="$1"
  local legacy_dir="$2"
  local label="$3"
  local moved=0
  local file

  [ -d "$source_dir" ] || return 0
  mkdir -p "$legacy_dir"

  while IFS= read -r -d '' file; do
    mv "$file" "$legacy_dir/"
    moved=1
  done < <(find "$source_dir" -maxdepth 1 -type f -name '*.conf' -print0)

  if [ "$moved" -eq 1 ]; then
    echo "[OK] Moved $label/*.conf -> $legacy_dir"
  fi
}
print_conversion_coverage_summary() {
  echo "[INFO] Migration coverage summary (Hyprland Lua mode):"
  cat <<SUMMARY
[INFO]   Converted .conf -> .lua:
[INFO]     - $DEST_MONITORS_CONF -> $DEST_LUA_MONITORS
[INFO]     - $DEST_WORKSPACES_CONF -> $DEST_LUA_WORKSPACES
[INFO]     - $SYSTEM_ENV_VARS -> $CONFIGS_DIR/system_env.lua
[INFO]     - $SYSTEM_STARTUP_APPS -> $CONFIGS_DIR/system_startup.lua
[INFO]     - $SYSTEM_WINDOW_RULES -> $CONFIGS_DIR/system_window_rules.lua
[INFO]     - $SYSTEM_LAYER_RULES -> $CONFIGS_DIR/system_layer_rules.lua
[INFO]     - $SYSTEM_KEYBINDS -> $CONFIGS_DIR/system_keybinds.lua
[INFO]     - $SYSTEM_SETTINGS -> $CONFIGS_DIR/system_settings.lua
[INFO]     - $SYSTEM_LAPTOPS -> $CONFIGS_DIR/system_laptops.lua
[INFO]     - $USER_ENV_VARS -> $USER_CONFIGS_DIR/user_env.lua
[INFO]     - $USER_STARTUP_APPS -> $USER_CONFIGS_DIR/user_startup.lua
[INFO]     - $USER_WINDOW_RULES -> $USER_CONFIGS_DIR/user_window_rules.lua
[INFO]     - $USER_LAYER_RULES -> $USER_CONFIGS_DIR/user_layer_rules.lua
[INFO]     - $USER_KEYBINDS -> $USER_CONFIGS_DIR/user_keybinds.lua
[INFO]     - $USER_SETTINGS -> $USER_CONFIGS_DIR/user_settings.lua
[INFO]     - $USER_DECORATIONS -> $USER_CONFIGS_DIR/user_decorations.lua
[INFO]     - $USER_ANIMATIONS -> $USER_CONFIGS_DIR/user_animations.lua
[INFO]     - $USER_LAPTOPS -> $USER_CONFIGS_DIR/user_laptops.lua
[INFO]     - $USER_CONFIGS_DIR/01-UserDefaults.conf -> $USER_CONFIGS_DIR/user_defaults.lua
[INFO]   Intentionally native/template .conf files:
[INFO]     - $DEST_HYPR_DIR/hypridle.conf
[INFO]     - $DEST_HYPR_DIR/hyprlock.conf, hyprlock-1080p.conf, hyprlock-2k.conf
[INFO]     - $DEST_HYPR_DIR/hyprland.conf (fallback/non-Lua entrypoint)
[INFO]     - $DEST_HYPR_DIR/Monitor_Profiles/*.conf and $DEST_HYPR_DIR/animations/*.conf (preset profiles)
[INFO]     - $USER_CONFIGS_DIR/LaptopDisplay.conf and $USER_CONFIGS_DIR/WorkSpaceRules.conf (legacy/helper files)
SUMMARY
}

move_conf_files_to_legacy "$USER_CONFIGS_DIR" "$USER_CONFIGS_LEGACY_DIR" "$USER_CONFIGS_DIR"
move_conf_files_to_legacy "$CONFIGS_DIR" "$CONFIGS_LEGACY_DIR" "$CONFIGS_DIR"
print_conversion_coverage_summary

echo "[OK] Lua Hyprland config copied."
echo "[INFO] Restart Hyprland to test Lua config pickup."
echo "[INFO] To rollback: $(basename "$0") --revert"
