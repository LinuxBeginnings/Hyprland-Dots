#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Regenerate ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/configs/system_settings.lua from SystemSettings.conf.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
HYPR_DIR="${CONFIG_HOME}/hypr"
CONFIGS_DIR="${HYPR_DIR}/configs"
LEGACY_DIR="${CONFIGS_DIR}/LegacyConfigs"
SYSTEM_SETTINGS_CONF="${CONFIGS_DIR}/SystemSettings.conf"
SYSTEM_SETTINGS_LUA="${CONFIGS_DIR}/system_settings.lua"

python3 - <<'PY'
from pathlib import Path
import os
import re

HEADER = """-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
"""

config_home = Path(os.getenv("XDG_CONFIG_HOME") or (Path.home() / ".config"))
hypr_dir = config_home / "hypr"
configs_dir = hypr_dir / "configs"
legacy_dir = configs_dir / "LegacyConfigs"
system_settings_path = configs_dir / "SystemSettings.conf"
output_path = configs_dir / "system_settings.lua"

def strip_comment(line: str) -> str:
    return line.split("#", 1)[0].strip()

def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

def scalar(value: str, *, bool_words: bool = True) -> str:
    value = value.strip()
    lower = value.lower()
    if bool_words and lower in {"on", "true", "yes"}:
        return "true"
    if bool_words and lower in {"off", "false", "no"}:
        return "false"
    if re.fullmatch(r"[-+]?\d+(\.\d+)?", value):
        return value
    return lua_string(value)

def render_table(value, indent=4):
    lines = []
    for key, child in value.items():
        if isinstance(child, dict):
            lines.append(" " * indent + f"{key} = {{")
            lines.extend(render_table(child, indent + 2))
            lines.append(" " * indent + "},")
        else:
            lines.append(" " * indent + f"{key} = {scalar(str(child))},")
    return lines

def latest_legacy_file(path: Path):
    if not legacy_dir.is_dir():
        return None
    candidates = []
    for snapshot in sorted(legacy_dir.iterdir()):
        if not snapshot.is_dir():
            continue
        candidate = snapshot / path.name
        if candidate.is_file():
            candidates.append(candidate)
    return candidates[-1] if candidates else None

def parse_hyprlang_sections(path: Path):
    sections = {}
    if path is None or not path.exists():
        return sections
    stack = [sections]
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        if line.startswith("source"):
            continue
        if line.endswith("{"):
            name = line[:-1].strip().replace("-", "_")
            if not name or name.startswith("$"):
                continue
            current = stack[-1]
            target = current.setdefault(name, {})
            stack.append(target)
            continue
        if line == "}":
            if len(stack) > 1:
                stack.pop()
            continue
        if "=" in line:
            key, value = [part.strip() for part in line.split("=", 1)]
            if not key or key.startswith("$"):
                continue
            key = key.replace("-", "_")
            container = stack[-1]
            parts = [part.replace("-", "_") for part in key.split(".") if part]
            for part in parts[:-1]:
                container = container.setdefault(part, {})
            container[parts[-1]] = value
    return sections

def parse_scripts_dir(path: Path):
    if path is None or not path.exists():
        return None
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^\$scriptsDir\s*=\s*(.+)$", line)
        if match:
            value = match.group(1).strip().strip('"').strip("'")
            return value
    return None

def parse_gestures(path: Path):
    simple = []
    complex_entries = []
    if path is None or not path.exists():
        return simple, complex_entries
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = strip_comment(raw)
        if not line:
            continue
        match = re.match(r"^gesture\s*=\s*(.+)$", line)
        if not match:
            continue
        payload = match.group(1).strip()
        parts = [part.strip() for part in payload.split(",")]
        if len(parts) >= 3 and parts[2] == "workspace":
            try:
                fingers = int(parts[0])
            except ValueError:
                complex_entries.append(payload)
                continue
            simple.append({"fingers": fingers, "direction": parts[1], "action": "workspace"})
        else:
            complex_entries.append(payload)
    return simple, complex_entries

source_path = system_settings_path if system_settings_path.exists() else latest_legacy_file(system_settings_path)

lines = [
    "-- System Settings (auto-generated).",
    "-- This file keeps migrated settings split from user overrides.",
    "-- Add only Lua entries here.",
    "-- Example:",
    "-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })",
    "",
]

if source_path is None:
    lines.append("-- No active entries were found in SystemSettings.conf.")
else:
    scripts_dir = parse_scripts_dir(source_path)
    if scripts_dir:
        lines.append(f"local scriptsDir = {lua_string(scripts_dir)}")
        lines.append("")

    sections = parse_hyprlang_sections(source_path)
    gestures_section = sections.pop("gestures", None)
    if gestures_section and "gesture" in gestures_section:
        gestures_section.pop("gesture", None)

    ordered_sections = [
        "dwindle",
        "master",
        "scrolling",
        "general",
        "input",
        "gestures",
        "misc",
        "binds",
        "xwayland",
        "render",
        "cursor",
    ]
    for section in ordered_sections:
        if section == "gestures":
            data = gestures_section
        elif section == "misc":
            data = sections.get(section) or {}
            if "force_default_wallpaper" not in data:
                data["force_default_wallpaper"] = "false"
        else:
            data = sections.get(section)
        if not data:
            continue
        lines.append("hl.config({")
        lines.append(f"  {section} = {{")
        lines.extend(render_table(data, indent=4))
        lines.append("  },")
        lines.append("})")
        lines.append("")

    simple_gestures, complex_gestures = parse_gestures(source_path)
    for spec in simple_gestures:
        lines.extend([
            "hl.gesture({",
            f"  fingers = {spec['fingers']},",
            f"  direction = {lua_string(spec['direction'])},",
            f"  action = {lua_string(spec['action'])},",
            "})",
            "",
        ])

    if complex_gestures:
        lines.append("-- Complex dispatcher gestures from SystemSettings.conf are pending explicit Lua API parity:")
        for entry in complex_gestures:
            lines.append(f"-- gesture = {entry}")
        lines.append("")

content = "\n".join(lines).rstrip() + "\n"
if not content.startswith(HEADER):
    content = HEADER + "\n" + content.lstrip("\n")
output_path.write_text(content, encoding="utf-8")
print(f"[OK] Wrote {output_path}")
PY
