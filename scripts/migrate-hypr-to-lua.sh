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
USER_WINDOW_RULES="$USER_CONFIGS_DIR/WindowRules.conf"
USER_KEYBINDS="$USER_CONFIGS_DIR/UserKeybinds.conf"
USER_ENV_VARS="$USER_CONFIGS_DIR/ENVariables.conf"
USER_STARTUP_APPS="$USER_CONFIGS_DIR/Startup_Apps.conf"
USER_SETTINGS="$USER_CONFIGS_DIR/UserSettings.conf"
USER_DECORATIONS="$USER_CONFIGS_DIR/UserDecorations.conf"
USER_ANIMATIONS="$USER_CONFIGS_DIR/UserAnimations.conf"
USER_LAPTOPS="$USER_CONFIGS_DIR/Laptops.conf"
SYSTEM_WINDOW_RULES="$CONFIGS_DIR/WindowRules.conf"
SYSTEM_KEYBINDS="$CONFIGS_DIR/Keybinds.conf"
SYSTEM_ENV_VARS="$CONFIGS_DIR/ENVariables.conf"
SYSTEM_STARTUP_APPS="$CONFIGS_DIR/Startup_Apps.conf"
SYSTEM_SETTINGS="$CONFIGS_DIR/SystemSettings.conf"
SYSTEM_LAPTOPS="$CONFIGS_DIR/Laptops.conf"
USER_CONFIGS_BACKUP_DIR="$USER_CONFIGS_DIR/backup-$MIGRATION_TS"
CONFIGS_BACKUP_DIR="$CONFIGS_DIR/backup-$MIGRATION_TS"
USER_OVERRIDES_SHIM="$DEST_HYPR_DIR/lua/user_overrides.lua"

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
  -r, --revert   Revert migration by restoring latest backup-*/.conf files.
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

if [ "$REVERT" -eq 0 ] && { [ ! -f "$SRC_HYPR_DIR/hyprland.lua" ] || [ ! -d "$SRC_HYPR_DIR/lua" ]; }; then
  echo "[ERROR] Lua config source files were not found under $SRC_HYPR_DIR" >&2
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
  echo "[WARN] Revert mode: restores latest backup-*/.conf files in UserConfigs and configs."
else
  echo "[WARN] This enables Hyprland's Lua entrypoint for builds that support hyprland.lua."
  echo "[WARN] hyprland.conf remains in place as fallback; rollback restores backup-*/.conf files."
fi

restore_latest_conf_backup() {
  local target_dir="$1"
  local label="$2"
  local latest_backup=""
  local moved=0
  local file
  local backups=()

  [ -d "$target_dir" ] || return 0

  mapfile -t backups < <(find "$target_dir" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | sort)
  [ "${#backups[@]}" -gt 0 ] || return 0
  latest_backup="${backups[${#backups[@]}-1]}"

  while IFS= read -r -d '' file; do
    mv "$file" "$target_dir/"
    moved=1
  done < <(find "$latest_backup" -maxdepth 1 -type f -name '*.conf' -print0)

  if [ "$moved" -eq 1 ]; then
    echo "[OK] Restored $label/*.conf from $latest_backup"
  else
    echo "[INFO] No .conf files found in latest backup for $label: $latest_backup"
  fi
}

if [ "$YES" -eq 0 ]; then
  if [ "$REVERT" -eq 1 ]; then
    printf "[ACTION] Continue and revert Lua migration using latest backups? [y/N] "
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
    echo "[DRY-RUN] Would disable Lua entrypoint: $DEST_HYPR_DIR/hyprland.lua -> $DEST_HYPR_DIR/hyprland.lua.disabled"
    echo "[DRY-RUN] Would restore latest backup-*/.conf files into:"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR"
    echo "[DRY-RUN]   - $CONFIGS_DIR"
  else
    echo "[DRY-RUN] Would create target directory if missing: $DEST_HYPR_DIR"
    if [ -d "$DEST_HYPR_DIR" ]; then
      echo "[DRY-RUN] Would copy backup: $DEST_HYPR_DIR -> $BACKUP_DIR"
    fi
    echo "[DRY-RUN] Would copy: $SRC_HYPR_DIR/hyprland.lua -> $DEST_HYPR_DIR/hyprland.lua"
    echo "[DRY-RUN] Would replace Lua module directory: $DEST_HYPR_DIR/lua"
    echo "[DRY-RUN] Would generate split UserConfigs Lua overlays:"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_env.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_startup.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_window_rules.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_keybinds.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_settings.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/system_laptops.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_env.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_startup.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_window_rules.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_keybinds.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_settings.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_decorations.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_animations.lua"
    echo "[DRY-RUN]   - $USER_CONFIGS_DIR/user_laptops.lua"
    if [ -d "$USER_CONFIGS_DIR" ]; then
      echo "[DRY-RUN] Would move UserConfigs/*.conf into: $USER_CONFIGS_BACKUP_DIR"
    fi
    if [ -d "$CONFIGS_DIR" ]; then
      echo "[DRY-RUN] Would move configs/*.conf into: $CONFIGS_BACKUP_DIR"
    fi
  fi
  exit 0
fi
if [ "$REVERT" -eq 1 ]; then
  if [ -f "$DEST_HYPR_DIR/hyprland.lua" ]; then
    mv "$DEST_HYPR_DIR/hyprland.lua" "$DEST_HYPR_DIR/hyprland.lua.disabled"
    echo "[OK] Disabled Lua entrypoint: $DEST_HYPR_DIR/hyprland.lua.disabled"
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

cp -f "$SRC_HYPR_DIR/hyprland.lua" "$DEST_HYPR_DIR/hyprland.lua"
rm -rf "$DEST_HYPR_DIR/lua"
cp -a "$SRC_HYPR_DIR/lua" "$DEST_HYPR_DIR/lua"
mkdir -p "$USER_CONFIGS_DIR" "$CONFIGS_DIR"
python3 - \
  "$USER_CONFIGS_DIR" \
  "$SYSTEM_WINDOW_RULES" \
  "$SYSTEM_KEYBINDS" \
  "$SYSTEM_ENV_VARS" \
  "$SYSTEM_STARTUP_APPS" \
  "$SYSTEM_SETTINGS" \
  "$SYSTEM_LAPTOPS" \
  "$USER_WINDOW_RULES" \
  "$USER_KEYBINDS" \
  "$USER_ENV_VARS" \
  "$USER_STARTUP_APPS" \
  "$USER_SETTINGS" \
  "$USER_DECORATIONS" \
  "$USER_ANIMATIONS" \
  "$USER_LAPTOPS" <<'PY'
import re
import sys
from pathlib import Path

user_configs_dir = Path(sys.argv[1])
system_window_rules_path = Path(sys.argv[2])
system_keybinds_path = Path(sys.argv[3])
system_env_path = Path(sys.argv[4])
system_startup_path = Path(sys.argv[5])
system_settings_path = Path(sys.argv[6])
system_laptops_path = Path(sys.argv[7])
window_rules_path = Path(sys.argv[8])
keybinds_path = Path(sys.argv[9])
env_path = Path(sys.argv[10])
startup_path = Path(sys.argv[11])
settings_path = Path(sys.argv[12])
decorations_path = Path(sys.argv[13])
animations_path = Path(sys.argv[14])
laptops_path = Path(sys.argv[15])

files_out = {
    "system_env": user_configs_dir / "system_env.lua",
    "system_startup": user_configs_dir / "system_startup.lua",
    "system_window_rules": user_configs_dir / "system_window_rules.lua",
    "system_keybinds": user_configs_dir / "system_keybinds.lua",
    "system_settings": user_configs_dir / "system_settings.lua",
    "system_laptops": user_configs_dir / "system_laptops.lua",
    "env": user_configs_dir / "user_env.lua",
    "startup": user_configs_dir / "user_startup.lua",
    "window_rules": user_configs_dir / "user_window_rules.lua",
    "keybinds": user_configs_dir / "user_keybinds.lua",
    "settings": user_configs_dir / "user_settings.lua",
    "decorations": user_configs_dir / "user_decorations.lua",
    "animations": user_configs_dir / "user_animations.lua",
    "laptops": user_configs_dir / "user_laptops.lua",
}

def strip_comment(line):
    return line.split("#", 1)[0].strip()

def split_items(value):
    return [item.strip() for item in value.split(",") if item.strip()]

def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
def write_file(path, lines):
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
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

def parse_env(path):
    entries = []
    if not path.exists():
        return entries
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^env\s*=\s*([^,]+)\s*,\s*(.+)$", line)
        if match:
            entries.append((match.group(1).strip(), match.group(2).strip()))
    return entries

def parse_startup(path):
    entries = []
    if not path.exists():
        return entries
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^exec(?:-once)?\s*=\s*(.+)$", line)
        if match:
            entries.append(match.group(1).strip())
    return entries

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
    while i < len(lines):
        line = strip_comment(lines[i])
        if not line:
            i += 1
            continue

        if re.match(r"^(windowrule|layerrule)\s*\{", line):
            rule_type, rule, i = parse_block(lines, i)
            if rule.get("match"):
                if "name" not in rule:
                    if rule_type == "window":
                        rule["name"] = lua_string(f"{prefix}-windowrule-{rule_index:03d}")
                        rule_index += 1
                    else:
                        rule["name"] = lua_string(f"{prefix}-layerrule-{layer_index:03d}")
                        layer_index += 1
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
                if rule_type == "window":
                    rule["name"] = lua_string(f"{prefix}-windowrule-{rule_index:03d}")
                    rule_index += 1
                else:
                    rule["name"] = lua_string(f"{prefix}-layerrule-{layer_index:03d}")
                    layer_index += 1
                parsed.append((rule_type, rule))
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

def parse_keybinds(path):
    if not path.exists():
        return []

    variables = {}
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
                opts.append("repeat = true")
            opts_text = ", { " + ", ".join(opts) + " }" if opts else ""

            if dispatcher == "exec":
                converted.append(f"bind({lua_string(mods)}, {lua_string(key)}, exec_cmd({lua_string(args)}){opts_text})")
            else:
                converted.append(f"bind({lua_string(mods)}, {lua_string(key)}, dispatch({lua_string(dispatcher)}, {lua_string(args)}){opts_text})")

    return converted

system_rules = parse_rules(system_window_rules_path, "system")
rules = parse_rules(window_rules_path, "user")
system_keybinds = parse_keybinds(system_keybinds_path)
keybinds = parse_keybinds(keybinds_path)
system_env_entries = parse_env(system_env_path)
env_entries = parse_env(env_path)
system_startup_entries = parse_startup(system_startup_path)
startup_entries = parse_startup(startup_path)

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
else:
    system_env_lines.append("-- No active env entries were found in configs/ENVariables.conf.")
write_file(files_out["system_env"], system_env_lines)

system_startup_lines = [
    "-- System defaults migrated from configs/Startup_Apps.conf (auto-generated).",
    "-- Add commands with exec_once(\"your command\")",
    "-- Example:",
    "-- exec_once(\"swaync\")",
    "",
    "local function shell_quote(value)",
    "  return \"'\" .. tostring(value):gsub(\"'\", \"'\\\\''\") .. \"'\"",
    "end",
    "",
    "local function exec_once(cmd)",
    "  local session = os.getenv(\"HYPRLAND_INSTANCE_SIGNATURE\") or \"default\"",
    "  local key = cmd:gsub(\"[^%w_.-]\", \"_\"):sub(1, 80)",
    "  local marker = \"/tmp/hypr-lua-system-exec-once-\" .. session .. \"-\" .. key",
    "  local script = \"[ -e \" .. shell_quote(marker) .. \" ] || { touch \" .. shell_quote(marker) .. \" && sh -lc \" .. shell_quote(cmd) .. \" >/dev/null 2>&1 & }\"",
    "  os.execute(\"sh -lc \" .. shell_quote(script))",
    "end",
    "",
]
if system_startup_entries:
    system_startup_lines.append("-- Converted from configs/Startup_Apps.conf")
    for cmd in system_startup_entries:
        system_startup_lines.append(f"exec_once({lua_string(cmd)})")
else:
    system_startup_lines.append("-- No active startup entries were found in configs/Startup_Apps.conf.")
write_file(files_out["system_startup"], system_startup_lines)

system_window_lines = [
    "-- System defaults migrated from configs/WindowRules.conf (auto-generated).",
    "-- Add additional rules with apply_window_rule({...}) / apply_layer_rule({...}).",
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
    "local function apply_layer_rule(rule)",
    "  if hl.layer_rule then",
    "    hl.layer_rule(rule)",
    "  end",
    "end",
    "",
]
if system_rules:
    system_window_lines.append("-- Converted from configs/WindowRules.conf")
    for rule_type, rule in system_rules:
        system_window_lines.append(emit_rule(rule_type, rule))
        system_window_lines.append("")
else:
    system_window_lines.append("-- No active window/layer rules were found in configs/WindowRules.conf.")
write_file(files_out["system_window_rules"], system_window_lines)

system_keybind_lines = [
    "-- System defaults migrated from configs/Keybinds.conf (auto-generated).",
    "-- Add keybinds with bind(\"MODS\", \"KEY\", fn, opts).",
    "-- Example:",
    "-- bind(\"SUPER\", \"Z\", exec_cmd(\"thunar\"), { description = \"Open file manager\" })",
    "",
    "local dsp = hl.dsp or hl",
    "",
    "local function exec_cmd(cmd)",
    "  if dsp and dsp.exec_cmd then",
    "    return dsp.exec_cmd(cmd)",
    "  end",
    "  return function() hl.exec_cmd(cmd) end",
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
    "local function key_variants(key)",
    "  key = trim(key)",
    "  return { key }",
    "end",
    "",
    "local function workspace_value(value)",
    "  value = trim(value)",
    "  return tonumber(value) or value",
    "end",
    "",
    "local function dispatch(name, args)",
    "  local window_api = (dsp and dsp.window) or hl.window or {}",
    "  name = trim(name)",
    "  args = trim(args)",
    "  if name == \"exec\" then",
    "    return exec_cmd(args)",
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
    "  if args ~= \"\" then",
    "    return exec_cmd(\"hyprctl dispatch \" .. name .. \" \" .. args)",
    "  end",
    "  return exec_cmd(\"hyprctl dispatch \" .. name)",
    "end",
    "",
    "local function bind(mods, key, fn, opts)",
    "  local seen = {}",
    "  for _, key_variant in ipairs(key_variants(key)) do",
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
    "    for _, key_variant in ipairs(key_variants(key)) do",
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
    "local function shell_quote(value)",
    "  return \"'\" .. tostring(value):gsub(\"'\", \"'\\\\''\") .. \"'\"",
    "end",
    "",
    "local function exec_once(cmd)",
    "  local session = os.getenv(\"HYPRLAND_INSTANCE_SIGNATURE\") or \"default\"",
    "  local key = cmd:gsub(\"[^%w_.-]\", \"_\"):sub(1, 80)",
    "  local marker = \"/tmp/hypr-lua-user-exec-once-\" .. session .. \"-\" .. key",
    "  local script = \"[ -e \" .. shell_quote(marker) .. \" ] || { touch \" .. shell_quote(marker) .. \" && sh -lc \" .. shell_quote(cmd) .. \" >/dev/null 2>&1 & }\"",
    "  os.execute(\"sh -lc \" .. shell_quote(script))",
    "end",
    "",
]
if startup_entries:
    startup_lines.append("-- Converted from Startup_Apps.conf")
    for cmd in startup_entries:
        startup_lines.append(f"exec_once({lua_string(cmd)})")
else:
    startup_lines.extend([
        "-- No active startup entries were found in Startup_Apps.conf.",
        "-- exec_once(\"nm-applet --indicator\")",
    ])
write_file(files_out["startup"], startup_lines)

window_lines = [
    "-- User window/layer rule overrides (auto-generated).",
    "-- Add your own rules with apply_window_rule({...}) / apply_layer_rule({...})",
    "-- Example:",
    "-- apply_window_rule({",
    "--   name = \"My Float Rule\",",
    "--   match = { class = \"^pavucontrol$\" },",
    "--   float = true,",
    "--   center = true,",
    "-- })",
    "",
    "local function apply_window_rule(rule)",
    "  if hl.window_rule then",
    "    hl.window_rule(rule)",
    "  end",
    "end",
    "",
    "local function apply_layer_rule(rule)",
    "  if hl.layer_rule then",
    "    hl.layer_rule(rule)",
    "  end",
    "end",
    "",
]
if rules:
    window_lines.append("-- Converted from WindowRules.conf")
    for rule_type, rule in rules:
        window_lines.append(emit_rule(rule_type, rule))
        window_lines.append("")
else:
    window_lines.append("-- No active window/layer rules were found in WindowRules.conf.")
write_file(files_out["window_rules"], window_lines)

keybind_lines = [
    "-- User keybind overrides (auto-generated).",
    "-- Add keybinds with bind(\"MODS\", \"KEY\", fn, opts).",
    "-- Example:",
    "-- bind(\"SUPER\", \"Z\", exec_cmd(\"ghostty\"), { description = \"Launch ghostty\" })",
    "",
    "local dsp = hl.dsp or hl",
    "",
    "local function exec_cmd(cmd)",
    "  if dsp and dsp.exec_cmd then",
    "    return dsp.exec_cmd(cmd)",
    "  end",
    "  return function() hl.exec_cmd(cmd) end",
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
    "local function key_variants(key)",
    "  key = trim(key)",
    "  return { key }",
    "end",
    "",
    "local function workspace_value(value)",
    "  value = trim(value)",
    "  return tonumber(value) or value",
    "end",
    "",
    "local function dispatch(name, args)",
    "  local window_api = (dsp and dsp.window) or hl.window or {}",
    "  name = trim(name)",
    "  args = trim(args)",
    "  if name == \"exec\" then",
    "    return exec_cmd(args)",
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
    "  if args ~= \"\" then",
    "    return exec_cmd(\"hyprctl dispatch \" .. name .. \" \" .. args)",
    "  end",
    "  return exec_cmd(\"hyprctl dispatch \" .. name)",
    "end",
    "",
    "local function bind(mods, key, fn, opts)",
    "  local seen = {}",
    "  for _, key_variant in ipairs(key_variants(key)) do",
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
    "    for _, key_variant in ipairs(key_variants(key)) do",
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
if keybinds:
    keybind_lines.append("-- Converted from UserKeybinds.conf")
    keybind_lines.extend(keybinds)
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
    if reference:
        lines.extend([
            f"-- Source reference from {source.name} (hyprlang):",
            *reference,
        ])
    else:
        lines.append(f"-- No active entries were found in {source.name}.")
    write_file(files_out[name], lines)
PY

cat > "$USER_OVERRIDES_SHIM" <<'LUA'
-- Auto-generated by scripts/migrate-hypr-to-lua.sh.
-- Loads split user-editable Lua files from ~/.config/hypr/UserConfigs.
local configHome = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local userDir = configHome .. "/hypr/UserConfigs"
local files = {
  "system_env.lua",
  "system_startup.lua",
  "system_window_rules.lua",
  "system_keybinds.lua",
  "system_settings.lua",
  "system_laptops.lua",
  "user_env.lua",
  "user_startup.lua",
  "user_window_rules.lua",
  "user_keybinds.lua",
  "user_settings.lua",
  "user_decorations.lua",
  "user_animations.lua",
  "user_laptops.lua",
  "user_overrides.lua", -- backward compatibility with older single-file overrides
}
for _, file in ipairs(files) do
  local path = userDir .. "/" .. file
  local ok, err = pcall(dofile, path)
  if not ok and err and tostring(err):find("No such file or directory", 1, true) == nil then
    print("[WARN] Unable to load user override file " .. path .. ": " .. tostring(err))
  end
end
LUA

backup_conf_files() {
  local source_dir="$1"
  local backup_dir="$2"
  local label="$3"
  local moved=0
  local file

  [ -d "$source_dir" ] || return 0

  while IFS= read -r -d '' file; do
    if [ "$moved" -eq 0 ]; then
      mkdir -p "$backup_dir"
    fi
    mv "$file" "$backup_dir/"
    moved=1
  done < <(find "$source_dir" -maxdepth 1 -type f -name '*.conf' -print0)

  if [ "$moved" -eq 1 ]; then
    echo "[OK] Moved $label/*.conf -> $backup_dir"
  fi
}

backup_conf_files "$USER_CONFIGS_DIR" "$USER_CONFIGS_BACKUP_DIR" "$USER_CONFIGS_DIR"
backup_conf_files "$CONFIGS_DIR" "$CONFIGS_BACKUP_DIR" "$CONFIGS_DIR"

echo "[OK] Lua Hyprland config copied."
echo "[INFO] Restart Hyprland to test Lua config pickup."
echo "[INFO] To rollback: $(basename "$0") --revert"
