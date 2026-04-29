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
DRY_RUN=0
YES=0

USER_WINDOW_RULES="$DEST_HYPR_DIR/UserConfigs/WindowRules.conf"
USER_KEYBINDS="$DEST_HYPR_DIR/UserConfigs/UserKeybinds.conf"
USER_OVERRIDES_OUT="$DEST_HYPR_DIR/lua/user_overrides.lua"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--yes] [--dry-run]

Copies the repo's Hyprland Lua entrypoint into:
  $DEST_HYPR_DIR

This preserves hyprland.conf as fallback and creates a full backup of the
current Hyprland config directory before changing files.

Options:
  -y, --yes      Run without confirmation prompts.
  -n, --dry-run  Show what would change without copying files.
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

if [ ! -f "$SRC_HYPR_DIR/hyprland.lua" ] || [ ! -d "$SRC_HYPR_DIR/lua" ]; then
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
echo "[WARN] This enables Hyprland's Lua entrypoint for builds that support hyprland.lua."
echo "[WARN] hyprland.conf remains in place as fallback; rollback is removing or renaming $DEST_HYPR_DIR/hyprland.lua."

if [ "$YES" -eq 0 ]; then
  printf "[ACTION] Continue with Lua config migration? [y/N] "
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
  echo "[DRY-RUN] Would create target directory if missing: $DEST_HYPR_DIR"
  if [ -d "$DEST_HYPR_DIR" ]; then
    echo "[DRY-RUN] Would copy backup: $DEST_HYPR_DIR -> $BACKUP_DIR"
  fi
  echo "[DRY-RUN] Would copy: $SRC_HYPR_DIR/hyprland.lua -> $DEST_HYPR_DIR/hyprland.lua"
  echo "[DRY-RUN] Would replace Lua module directory: $DEST_HYPR_DIR/lua"
  if [ -f "$USER_WINDOW_RULES" ] || [ -f "$USER_KEYBINDS" ]; then
    echo "[DRY-RUN] Would convert found UserConfigs into: $USER_OVERRIDES_OUT"
    [ -f "$USER_WINDOW_RULES" ] && echo "[DRY-RUN]   - $USER_WINDOW_RULES"
    [ -f "$USER_KEYBINDS" ] && echo "[DRY-RUN]   - $USER_KEYBINDS"
  fi
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
if [ -f "$USER_WINDOW_RULES" ] || [ -f "$USER_KEYBINDS" ]; then
  python3 - "$USER_OVERRIDES_OUT" "$USER_WINDOW_RULES" "$USER_KEYBINDS" <<'PY'
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
window_rules_path = Path(sys.argv[2])
keybinds_path = Path(sys.argv[3])

def strip_comment(line):
    return line.split("#", 1)[0].strip()

def split_items(value):
    return [item.strip() for item in value.split(",") if item.strip()]

def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

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

def parse_rules(path):
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
                        rule["name"] = lua_string(f"user-windowrule-{rule_index:03d}")
                        rule_index += 1
                    else:
                        rule["name"] = lua_string(f"user-layerrule-{layer_index:03d}")
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
                    rule["name"] = lua_string(f"user-windowrule-{rule_index:03d}")
                    rule_index += 1
                else:
                    rule["name"] = lua_string(f"user-layerrule-{layer_index:03d}")
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

rules = parse_rules(window_rules_path)
keybinds = parse_keybinds(keybinds_path)

content = [
    "-- Auto-generated by scripts/migrate-hypr-to-lua.sh from UserConfigs.",
    "-- Edit the source files under UserConfigs and re-run the migration helper to regenerate.",
    "",
    "local dsp = hl.dsp or hl",
    "local window_api = (dsp and dsp.window) or hl.window or {}",
    "",
    "local function exec_cmd(cmd)",
    "  if dsp and dsp.exec_cmd then",
    "    return dsp.exec_cmd(cmd)",
    "  end",
    "  return function() hl.exec_cmd(cmd) end",
    "end",
    "",
    "local function exec_now(cmd)",
    "  if dsp and dsp.exec_cmd and hl.dispatch then",
    "    hl.dispatch(dsp.exec_cmd(cmd))",
    "  elseif hl.dispatch and hl.exec_cmd then",
    "    hl.dispatch(hl.exec_cmd(cmd))",
    "  elseif hl.exec_cmd then",
    "    hl.exec_cmd(cmd)",
    "  end",
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
    "  if name == \"fullscreen\" and window_api.fullscreen then",
    "    if args == \"1\" then",
    "      return exec_cmd((os.getenv(\"HOME\") or \"\") .. \"/.config/hypr/scripts/LuaFullscreenMaximized.sh\")",
    "    end",
    "    return window_api.fullscreen({ mode = \"fullscreen\" })",
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
    content.append("-- Converted from UserConfigs/WindowRules.conf")
    for rule_type, rule in rules:
        content.append(emit_rule(rule_type, rule))
        content.append("")

if keybinds:
    content.append("-- Converted from UserConfigs/UserKeybinds.conf")
    content.extend(keybinds)
    content.append("")

out_path.write_text("\n".join(content), encoding="utf-8")
print(f"[OK] UserConfigs converted into {out_path}")
PY
fi

echo "[OK] Lua Hyprland config copied."
echo "[INFO] Restart Hyprland to test Lua config pickup."
echo "[INFO] To rollback: mv '$DEST_HYPR_DIR/hyprland.lua' '$DEST_HYPR_DIR/hyprland.lua.disabled'"
