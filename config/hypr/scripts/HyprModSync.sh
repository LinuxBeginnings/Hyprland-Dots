#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Synchronize HyprMod managed settings with KoolDots split configuration files.
#
# HyprMod writes all of its changes into a single managed file (hyprland-gui.lua),
# whereas KoolDots organizes user customizations in split files under UserConfigs/
# (monitors.lua, user_keybinds.lua, user_window_rules.lua, user_animations.lua,
# user_decorations.lua, user_settings.lua).
#
# This script bridges the two by:
#   1. Parsing ~/.config/hypr/UserConfigs/hyprmod.toml for path and target mappings.
#   2. Splitting HyprMod's managed settings into designated UserConfigs files inside
#      clearly delimited managed blocks (-- >>> HYPRMOD MANAGED BLOCK >>>).
#   3. Preserving all existing user code, helpers, and manual configurations outside
#      the managed blocks.
#   4. Compiling user overrides from split files into hyprland-gui.lua so HyprMod
#      recognizes them as owned/editable settings (eliminating lock icons).
#   5. Supporting automatic timestamp-based sync and continuous watch mode.

set -uo pipefail

# Ensure we use bash if invoking subshells
BASH_BIN="${BASH:-$(command -v bash 2>/dev/null || echo "/usr/bin/env bash")}"

show_help() {
  cat << 'EOF'
Usage: HyprModSync.sh [OPTIONS] [COMMAND]

Commands:
  sync              Automatic bidirectional sync based on mtimes (default)
  to-split          Export from HyprMod managed file to UserConfigs split files
  to-managed        Import from UserConfigs split files into HyprMod managed file
  watch             Run continuously, auto-syncing on changes
  status            Show configuration paths, target mappings, and sync state

Options:
  -c, --config <file>        Path to hyprmod.toml (default: ~/.config/hypr/UserConfigs/hyprmod.toml)
  -m, --managed-file <file>  Override path to HyprMod managed file (hyprland-gui.lua)
  -b, --base-dir <dir>       Override Hyprland config root directory (default: ~/.config/hypr)
  -f, --force                Force overwrite even if timestamps match
  -q, --quiet                Suppress non-error output
  -v, --verbose              Enable detailed logging
  -h, --help                 Display this help message

Examples:
  HyprModSync.sh                          # Automatically sync newer changes
  HyprModSync.sh to-split                 # Propagate HyprMod GUI edits to UserConfigs
  HyprModSync.sh to-managed               # Build hyprland-gui.lua from UserConfigs
  HyprModSync.sh watch                    # Watch and synchronize in background
EOF
}

# Run the python sync engine
exec python3 - "$@" << 'PY_EOF'
import sys
import os
import re
import time
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

# Try importing tomllib (Python 3.11+)
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib  # type: ignore
    except ImportError:
        tomllib = None

# Try importing hyprland_config
try:
    import hyprland_config
    from hyprland_config import Document, Keyword, Assignment, Rule, load_any, serialize_any, parse_string
    HAVE_HYPRLAND_CONFIG = True
except ImportError:
    HAVE_HYPRLAND_CONFIG = False

TAG_START = "-- >>> HYPRMOD MANAGED BLOCK >>>"
TAG_END = "-- <<< END HYPRMOD MANAGED BLOCK <<<"
BLOCK_HEADER = f"{TAG_START}\n-- Auto-synced with HyprMod - do not edit directly inside this block\n"
BLOCK_FOOTER = f"\n{TAG_END}\n"

APPEARANCE_SECTIONS = {"general", "decoration", "group", "dwindle", "master", "scrolling"}
SETTINGS_SECTIONS = {"input", "cursor", "misc", "gestures", "render", "debug", "xwayland", "opengl"}


def find_default_config(base_dir: Path) -> Optional[Path]:
    candidates = [
        base_dir / "UserConfigs" / "hyprmod.toml",
        base_dir / "hyprmod.toml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def read_toml_config(config_path: Optional[Path], base_dir_override: Optional[Path]) -> Tuple[Path, Path, Dict[str, str]]:
    default_base = base_dir_override or Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr"
    default_entry = Path("hyprland.lua")
    default_targets = {
        "monitors": "UserConfigs/monitors.lua",
        "binds": "UserConfigs/user_keybinds.lua",
        "rules": "UserConfigs/user_window_rules.lua",
        "animations": "UserConfigs/user_animations.lua",
        "appearance": "UserConfigs/user_decorations.lua",
        "settings": "UserConfigs/user_settings.lua",
    }

    if not config_path or not config_path.is_file() or tomllib is None:
        return default_base, default_entry, default_targets

    try:
        with open(config_path, "rb") as f:
            data = tomllib.load(f)
    except Exception as e:
        sys.stderr.write(f"Warning: Failed to parse {config_path}: {e}\n")
        return default_base, default_entry, default_targets

    paths_sec = data.get("paths", {})
    raw_base = paths_sec.get("base_dir")
    if base_dir_override:
        base_dir = base_dir_override
    elif raw_base:
        base_dir = Path(os.path.expanduser(raw_base))
    else:
        base_dir = default_base

    raw_entry = paths_sec.get("entrypoint", "hyprland.lua")
    entrypoint = Path(raw_entry)

    targets = dict(default_targets)
    toml_targets = data.get("targets", {})
    for k, v in toml_targets.items():
        targets[k] = str(v)

    # If settings is not explicitly set in toml, ensure it is mapped if user_settings.lua exists
    if "settings" not in toml_targets and (base_dir / "UserConfigs" / "user_settings.lua").is_file():
        targets["settings"] = "UserConfigs/user_settings.lua"

    return base_dir, entrypoint, targets


def resolve_managed_path(base_dir: Path, managed_override: Optional[Path]) -> Path:
    if managed_override:
        p = managed_override.expanduser()
        return p if p.is_absolute() else base_dir / p

    userconfigs_lua = base_dir / "UserConfigs" / "hyprland-gui.lua"
    if userconfigs_lua.is_file():
        return userconfigs_lua

    # Check GSettings only if base_dir is the default user hypr directory
    default_base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr"
    try:
        if base_dir.resolve() == default_base.resolve():
            from hyprmod.core import config as hm_config
            from hyprmod.core import settings as hm_settings
            hm_settings.apply_saved_config_path(hm_settings.open_settings())
            return hm_config.managed_path()
    except Exception:
        pass

    return base_dir / "hyprland-gui.lua"


def update_managed_block(file_content: str, block_content: str) -> str:
    pattern = re.compile(rf"{re.escape(TAG_START)}.*?{re.escape(TAG_END)}\n?", re.DOTALL)
    cleaned_block = block_content.strip()

    if cleaned_block:
        new_block = f"{BLOCK_HEADER}{cleaned_block}{BLOCK_FOOTER}"
        if pattern.search(file_content):
            return pattern.sub(new_block, file_content)
        else:
            sep = "\n\n" if file_content and not file_content.endswith("\n\n") else ""
            if file_content and not file_content.endswith("\n"):
                sep = "\n" + sep
            return file_content + sep + new_block
    else:
        return pattern.sub("", file_content)


def extract_managed_block(file_content: str) -> str:
    pattern = re.compile(rf"{re.escape(TAG_START)}\s*(?:--[^\n]*\n)?(.*?){re.escape(TAG_END)}", re.DOTALL)
    m = pattern.search(file_content)
    if m:
        return m.group(1).strip()
    return ""


def categorize_managed_document(doc: Any) -> Dict[str, List[Any]]:
    categories: Dict[str, List[Any]] = {
        "monitors": [],
        "binds": [],
        "rules": [],
        "animations": [],
        "appearance": [],
        "settings": [],
    }

    for line in doc.lines:
        if isinstance(line, Keyword):
            k = line.key
            if k == "monitor":
                categories["monitors"].append(line)
            elif k.startswith("bind") or k.startswith("unbind"):
                categories["binds"].append(line)
            elif k.startswith("windowrule") or k.startswith("layerrule"):
                categories["rules"].append(line)
            elif k.startswith("animation") or k.startswith("bezier"):
                categories["animations"].append(line)
            elif k in ("exec", "exec-once"):
                categories["settings"].append(line)
            elif k == "env":
                categories["settings"].append(line)
        elif isinstance(line, Rule):
            categories["rules"].append(line)
        elif isinstance(line, Assignment):
            sec = line.key.split(":")[0] if ":" in line.key else line.key.split(".")[0]
            if sec in APPEARANCE_SECTIONS:
                categories["appearance"].append(line)
            elif sec in SETTINGS_SECTIONS:
                categories["settings"].append(line)
            elif sec == "animations":
                categories["animations"].append(line)

    return categories


def serialize_category_lines(lines: List[Any], format_is_lua: bool = True) -> str:
    if not lines or not HAVE_HYPRLAND_CONFIG:
        return ""
    sub_doc = Document()
    for l in lines:
        sub_doc.lines.append(l)
    out_path = Path("chunk.lua" if format_is_lua else "chunk.conf")
    return serialize_any(sub_doc, out_path).strip()


def sync_to_split(managed_file: Path, base_dir: Path, targets: Dict[str, str], verbose: bool = False) -> bool:
    if not managed_file.is_file():
        if verbose:
            print(f"Managed file {managed_file} does not exist. Nothing to split.")
        return False

    raw_managed = managed_file.read_text(encoding="utf-8")
    if not raw_managed.strip():
        if verbose:
            print(f"Managed file {managed_file} is empty. Clearing managed blocks in targets.")
        for cat, rel_path in targets.items():
            target_path = base_dir / rel_path
            if target_path.is_file():
                content = target_path.read_text(encoding="utf-8")
                updated = update_managed_block(content, "")
                if updated != content:
                    target_path.write_text(updated, encoding="utf-8")
                    if verbose:
                        print(f"Cleared managed block in {target_path}")
        return True

    if not HAVE_HYPRLAND_CONFIG:
        sys.stderr.write("Error: hyprland_config Python module is required for config parsing.\n")
        return False

    try:
        doc = load_any(managed_file, lenient=True)
    except Exception as e:
        sys.stderr.write(f"Error parsing {managed_file}: {e}\n")
        return False

    categories = categorize_managed_document(doc)
    modified_any = False

    for cat, lines in categories.items():
        if cat not in targets:
            continue
        rel_target = targets[cat]
        target_path = base_dir / rel_target
        serialized_block = serialize_category_lines(lines, format_is_lua=managed_file.suffix == ".lua")

        if target_path.is_file():
            existing_content = target_path.read_text(encoding="utf-8")
        else:
            target_path.parent.mkdir(parents=True, exist_ok=True)
            existing_content = (
                "-- ==================================================\n"
                f"--  User override file for {cat}\n"
                "-- ==================================================\n"
            )

        new_content = update_managed_block(existing_content, serialized_block)
        if new_content != existing_content:
            target_path.write_text(new_content, encoding="utf-8")
            modified_any = True
            if verbose:
                item_count = len(lines)
                print(f"Synced {item_count} {cat} item{'s' if item_count != 1 else ''} to {target_path}")

    return modified_any


def sync_to_managed(managed_file: Path, base_dir: Path, targets: Dict[str, str], verbose: bool = False) -> bool:
    collected_blocks: List[str] = []

    for cat, rel_path in targets.items():
        target_path = base_dir / rel_path
        if not target_path.is_file():
            continue
        content = target_path.read_text(encoding="utf-8")
        block = extract_managed_block(content)
        if block:
            collected_blocks.append(f"-- [{cat}] from {rel_path}\n{block}")

    if not collected_blocks:
        # If no managed block tags exist yet, check if there are standalone user definitions in targets
        if verbose:
            print("No managed blocks found in targets. Compiling active blocks...")
        for cat, rel_path in targets.items():
            target_path = base_dir / rel_path
            if not target_path.is_file():
                continue
            if not HAVE_HYPRLAND_CONFIG:
                continue
            try:
                sub_doc = load_any(target_path, lenient=True)
                for line in sub_doc.lines:
                    if isinstance(line, (Keyword, Assignment, Rule)):
                        temp_doc = Document()
                        temp_doc.lines.append(line)
                        rendered = serialize_any(temp_doc, Path("temp.lua")).strip()
                        if rendered:
                            collected_blocks.append(rendered)
            except Exception:
                pass

    header = (
        "-- ==================================================\n"
        "--  HyprMod managed configuration\n"
        "--  Synchronized via HyprModSync.sh\n"
        "-- ==================================================\n\n"
    )
    new_managed_content = header + "\n\n".join(collected_blocks) + "\n" if collected_blocks else ""

    existing = managed_file.read_text(encoding="utf-8") if managed_file.is_file() else ""
    if new_managed_content != existing:
        managed_file.parent.mkdir(parents=True, exist_ok=True)
        managed_file.write_text(new_managed_content, encoding="utf-8")
        if verbose:
            print(f"Compiled {len(collected_blocks)} block(s) into managed file: {managed_file}")
        return True

    return False


def get_newest_split_mtime(base_dir: Path, targets: Dict[str, str]) -> float:
    newest = 0.0
    for rel_path in targets.values():
        p = base_dir / rel_path
        if p.is_file():
            m = p.stat().st_mtime
            if m > newest:
                newest = m
    return newest


def trigger_hyprland_reload(entrypoint: Path, verbose: bool = False):
    try:
        if entrypoint.is_file():
            entrypoint.touch()
            if verbose:
                print(f"Touched entrypoint {entrypoint} for autoreload")
            return
    except Exception:
        pass
    os.system("hyprctl reload >/dev/null 2>&1 || true")


def show_status(managed_file: Path, base_dir: Path, targets: Dict[str, str], config_path: Optional[Path]):
    print("=== HyprModSync Status ===")
    print(f"Base Directory:   {base_dir}")
    print(f"Config File:      {config_path if config_path and config_path.is_file() else 'None (using defaults)'}")
    print(f"Managed File:     {managed_file} ({'exists' if managed_file.is_file() else 'missing'})")
    if managed_file.is_file():
        print(f"Managed mtime:    {time.ctime(managed_file.stat().st_mtime)}")
        lines = managed_file.read_text(encoding='utf-8').splitlines()
        print(f"Managed Lines:    {len(lines)}")

    print("\nTargets:")
    newest_mtime = 0.0
    for cat, rel_path in targets.items():
        p = base_dir / rel_path
        exists = p.is_file()
        has_block = False
        mtime_str = "N/A"
        if exists:
            m = p.stat().st_mtime
            if m > newest_mtime:
                newest_mtime = m
            mtime_str = time.ctime(m)
            has_block = bool(extract_managed_block(p.read_text(encoding="utf-8")))
        status_label = "managed block present" if has_block else ("file exists" if exists else "missing")
        print(f"  - {cat:<12} -> {rel_path} [{status_label}, mtime: {mtime_str}]")

    managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
    print("\nSync State:")
    if not managed_file.is_file() and newest_mtime == 0.0:
        print("  No configuration files found.")
    elif not managed_file.is_file():
        print("  Managed file missing; run with `to-managed` to compile from split files.")
    elif abs(managed_mtime - newest_mtime) < 1.0:
        print("  In sync (timestamps align).")
    elif managed_mtime > newest_mtime:
        print("  Managed file is NEWER than split files (run `to-split` to propagate changes).")
    else:
        print("  Split files are NEWER than managed file (run `to-managed` to update HyprMod).")


def watch_loop(managed_file: Path, base_dir: Path, targets: Dict[str, str], entrypoint: Path, verbose: bool):
    print(f"Starting HyprModSync watch loop on {base_dir} (Ctrl+C to stop)...")
    last_managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
    last_split_mtime = get_newest_split_mtime(base_dir, targets)

    while True:
        try:
            time.sleep(1.0)
            cur_managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
            cur_split_mtime = get_newest_split_mtime(base_dir, targets)

            if cur_managed_mtime > last_managed_mtime and cur_managed_mtime > cur_split_mtime:
                if verbose:
                    print(f"[{time.strftime('%H:%M:%S')}] Detected update in {managed_file.name}, syncing to split files...")
                time.sleep(0.2)  # brief debounce
                if sync_to_split(managed_file, base_dir, targets, verbose=verbose):
                    trigger_hyprland_reload(entrypoint, verbose=verbose)
                last_managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
                last_split_mtime = get_newest_split_mtime(base_dir, targets)

            elif cur_split_mtime > last_split_mtime and cur_split_mtime > cur_managed_mtime:
                if verbose:
                    print(f"[{time.strftime('%H:%M:%S')}] Detected update in split files, syncing to managed file...")
                time.sleep(0.2)  # brief debounce
                if sync_to_managed(managed_file, base_dir, targets, verbose=verbose):
                    last_managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
                last_split_mtime = get_newest_split_mtime(base_dir, targets)

        except KeyboardInterrupt:
            print("\nWatch loop stopped.")
            break
        except Exception as e:
            sys.stderr.write(f"Watch error: {e}\n")


def main():
    parser = argparse.ArgumentParser(
        prog="HyprModSync.sh",
        description="Synchronize HyprMod managed file with split configuration files.",
    )
    parser.add_argument("command", nargs="?", default="sync", choices=["sync", "to-split", "to-managed", "watch", "status"])
    parser.add_argument("-c", "--config", help="Path to hyprmod.toml")
    parser.add_argument("-m", "--managed-file", help="Path to hyprland-gui.lua")
    parser.add_argument("-b", "--base-dir", help="Base hypr config directory")
    parser.add_argument("-f", "--force", action="store_true", help="Force sync regardless of timestamps")
    parser.add_argument("-q", "--quiet", action="store_true", help="Suppress informational messages")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()
    verbose = args.verbose and not args.quiet

    base_override = Path(args.base_dir).expanduser() if args.base_dir else None
    config_path = Path(args.config).expanduser() if args.config else None
    if not config_path:
        default_base = base_override or Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr"
        config_path = find_default_config(default_base)

    base_dir, entrypoint_rel, targets = read_toml_config(config_path, base_override)
    entrypoint = base_dir / entrypoint_rel
    managed_file = resolve_managed_path(base_dir, Path(args.managed_file) if args.managed_file else None)

    cmd = args.command

    if cmd == "status":
        show_status(managed_file, base_dir, targets, config_path)
        return

    if cmd == "watch":
        watch_loop(managed_file, base_dir, targets, entrypoint, verbose=not args.quiet)
        return

    if cmd == "to-split":
        changed = sync_to_split(managed_file, base_dir, targets, verbose=verbose)
        if changed:
            trigger_hyprland_reload(entrypoint, verbose=verbose)
            if not args.quiet:
                print("Successfully synchronized HyprMod managed file to UserConfigs split files.")
        else:
            if not args.quiet:
                print("Split files are already up to date.")
        return

    if cmd == "to-managed":
        changed = sync_to_managed(managed_file, base_dir, targets, verbose=verbose)
        if changed:
            if not args.quiet:
                print("Successfully compiled UserConfigs split files into HyprMod managed file.")
        else:
            if not args.quiet:
                print("HyprMod managed file is already up to date.")
        return

    # cmd == "sync"
    managed_mtime = managed_file.stat().st_mtime if managed_file.is_file() else 0.0
    split_mtime = get_newest_split_mtime(base_dir, targets)

    if not managed_file.is_file() or (split_mtime > managed_mtime and not args.force):
        if verbose:
            print("Split files are newer or managed file missing; syncing to managed...")
        changed = sync_to_managed(managed_file, base_dir, targets, verbose=verbose)
        if changed and not args.quiet:
            print("Synchronized split files to HyprMod managed file.")
    else:
        if verbose:
            print("Managed file is newer or force enabled; syncing to split files...")
        changed = sync_to_split(managed_file, base_dir, targets, verbose=verbose)
        if changed:
            trigger_hyprland_reload(entrypoint, verbose=verbose)
            if not args.quiet:
                print("Synchronized HyprMod managed file to UserConfigs split files.")
        elif not args.quiet:
            print("Configuration files are already synchronized.")


if __name__ == "__main__":
    main()
PY_EOF
