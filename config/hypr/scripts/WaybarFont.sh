#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Global Waybar font family and font size manager.
# Updates user_env.lua, synchronizes installed styles, and restarts Waybar.

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="${KOOLDOTS_HYPR_DIR:-$CONFIG_HOME/hypr}"
USER_ENV_LUA="${KOOLDOTS_USER_ENV_LUA:-$HYPR_DIR/UserConfigs/user_env.lua}"
WAYBAR_DIR="${KOOLDOTS_WAYBAR_DIR:-$HYPR_DIR/waybar}"
STYLES_DIR="${KOOLDOTS_STYLES_DIR:-$WAYBAR_DIR/style}"
SCRIPTS_DIR="${KOOLDOTS_SCRIPTS_DIR:-$HYPR_DIR/scripts}"

DEFAULT_FONT="JetBrainsMono Nerd Font"
DEFAULT_SIZE="14"

# Read active font override from user_env.lua
get_active_font() {
  local font=""
  if [[ -f "$USER_ENV_LUA" ]]; then
    font=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["'\''"]WAYBAR_FONT["'\''"][[:space:]]*,[[:space:]]*["'\''"]\([^"'\''"]*\)["'\''"].*$/\1/p' "$USER_ENV_LUA" | tail -n1)
  fi
  printf '%s' "${font:-}"
}

# Read active font size override from user_env.lua
get_active_size() {
  local size=""
  if [[ -f "$USER_ENV_LUA" ]]; then
    size=$(sed -n 's/^[[:space:]]*hl\.env([[:space:]]*["'\''"]WAYBAR_FONT_SIZE["'\''"][[:space:]]*,[[:space:]]*["'\''"]\([^"'\''"]*\)["'\''"].*$/\1/p' "$USER_ENV_LUA" | tail -n1)
    size=$(printf '%s' "$size" | tr -cd '0-9')
  fi
  printf '%s' "${size:-}"
}

# Read current font (override if active, else default)
get_current_font() {
  local active
  active=$(get_active_font)
  printf '%s\n' "${active:-$DEFAULT_FONT}"
}

# Read current size (override if active, else default)
get_current_size() {
  local active
  active=$(get_active_size)
  printf '%s\n' "${active:-$DEFAULT_SIZE}"
}

# Check if override is currently defined in user_env.lua
is_override_active() {
  local f s
  f=$(get_active_font)
  s=$(get_active_size)
  if [[ -n "$f" || -n "$s" ]]; then
    return 0
  fi
  return 1
}

# List available font families sorted uniquely
list_fonts() {
  if command -v fc-list >/dev/null 2>&1; then
    fc-list : family | tr ',' '\n' | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^[[:space:]]*$' | sort -u
  else
    printf '%s\n' "$DEFAULT_FONT"
  fi
}

# Update or insert variables in user_env.lua
write_user_env() {
  local font="${1:-}"
  local size="${2:-}"

  [[ -f "$USER_ENV_LUA" ]] || return 0

  if [[ -n "$font" ]]; then
    if grep -qE '^[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT["'\''"]' "$USER_ENV_LUA"; then
      sed -i -E "s/^[[:space:]]*hl\\.env\\([[:space:]]*[\"']WAYBAR_FONT[\"'].*/hl.env(\"WAYBAR_FONT\", \"${font}\")/" "$USER_ENV_LUA"
    elif grep -qE '^[[:space:]]*--[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT["'\''"]' "$USER_ENV_LUA"; then
      sed -i -E "s/^[[:space:]]*--[[:space:]]*hl\\.env\\([[:space:]]*[\"']WAYBAR_FONT[\"'].*/hl.env(\"WAYBAR_FONT\", \"${font}\")/" "$USER_ENV_LUA"
    else
      printf '\nhl.env("WAYBAR_FONT", "%s")\n' "$font" >> "$USER_ENV_LUA"
    fi
  fi

  if [[ -n "$size" ]]; then
    size=$(printf '%s' "$size" | tr -cd '0-9')
    if grep -qE '^[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT_SIZE["'\''"]' "$USER_ENV_LUA"; then
      sed -i -E "s/^[[:space:]]*hl\\.env\\([[:space:]]*[\"']WAYBAR_FONT_SIZE[\"'].*/hl.env(\"WAYBAR_FONT_SIZE\", \"${size}\")/" "$USER_ENV_LUA"
    elif grep -qE '^[[:space:]]*--[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT_SIZE["'\''"]' "$USER_ENV_LUA"; then
      sed -i -E "s/^[[:space:]]*--[[:space:]]*hl\\.env\\([[:space:]]*[\"']WAYBAR_FONT_SIZE[\"'].*/hl.env(\"WAYBAR_FONT_SIZE\", \"${size}\")/" "$USER_ENV_LUA"
    else
      printf '\nhl.env("WAYBAR_FONT_SIZE", "%s")\n' "$size" >> "$USER_ENV_LUA"
    fi
  fi
}

# Comment out overrides in user_env.lua
clear_user_env() {
  [[ -f "$USER_ENV_LUA" ]] || return 0
  sed -i -E 's/^[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT["'\''"]/-- hl.env("WAYBAR_FONT"/' "$USER_ENV_LUA"
  sed -i -E 's/^[[:space:]]*hl\.env\([[:space:]]*["'\''"]WAYBAR_FONT_SIZE["'\''"]/-- hl.env("WAYBAR_FONT_SIZE"/' "$USER_ENV_LUA"
}

# Export environment variables to session, systemd, and D-Bus
export_environment() {
  local font="${1:-}"
  local size="${2:-}"

  if [[ -n "$font" ]]; then
    export WAYBAR_FONT="$font"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user import-environment WAYBAR_FONT >/dev/null 2>&1 || true
    fi
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd WAYBAR_FONT >/dev/null 2>&1 || true
    fi
  fi

  if [[ -n "$size" ]]; then
    export WAYBAR_FONT_SIZE="$size"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user import-environment WAYBAR_FONT_SIZE >/dev/null 2>&1 || true
    fi
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd WAYBAR_FONT_SIZE >/dev/null 2>&1 || true
    fi
  fi
}

# Apply font and/or size to stylesheets
apply_stylesheets() {
  local font="${1:-}"
  local size="${2:-}"

  [[ -d "$STYLES_DIR" ]] || return 0
  [[ -n "$size" ]] && size=$(printf '%s' "$size" | tr -cd '0-9')

  # Collect all CSS files in style directory and top-level style.css (if regular file)
  local files=()
  while IFS= read -r -d '' css; do
    files+=("$css")
  done < <(find -L "$STYLES_DIR" -maxdepth 1 -type f -name '*.css' -print0 2>/dev/null || true)

  if [[ -f "$WAYBAR_DIR/style.css" && ! -L "$WAYBAR_DIR/style.css" ]]; then
    files+=("$WAYBAR_DIR/style.css")
  fi

  [[ ${#files[@]} -gt 0 ]] || return 0

  # Use Python for robust multi-line CSS manipulation if available
  if command -v python3 >/dev/null 2>&1; then
    python3 - "${font}" "${size}" "${files[@]}" <<'EOF'
import sys, re

target_font = sys.argv[1] if sys.argv[1] else None
target_size = sys.argv[2] if sys.argv[2] else None
files = sys.argv[3:]

for path in files:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        continue

    modified = False

    # 1. Update font-family and/or * font-size in universal selector * block
    def repl_star(match):
        block = match.group(0)
        if target_font:
            block = re.sub(
                r'\bfont-family\s*:\s*[^;]+;',
                f'font-family: "{target_font}";',
                block,
                flags=re.DOTALL
            )
        if target_size:
            block = re.sub(
                r'(\bfont-size\s*:\s*)[0-9]+px(;)?',
                rf'\g<1>{target_size}px\g<2>',
                block
            )
        return block

    new_content = re.sub(r'\*\s*\{[^}]+\}', repl_star, content)
    if new_content != content:
        content = new_content
        modified = True

    # 2. Update scaling comments and explicit font-size in window#waybar and tooltip
    if target_size:
        # Scaling comment pattern
        new_content, c1 = re.subn(
            r'(/\*\s*Waybar scaling:\s*adjust font-size to scale the bar\s*\*/\s*font-size\s*:\s*)[0-9]+px',
            rf'\g<1>{target_size}px',
            content
        )
        if c1 > 0:
            content = new_content
            modified = True

        # window#waybar blocks
        def repl_window(m):
            return re.sub(r'(\bfont-size\s*:\s*)[0-9]+px', rf'\g<1>{target_size}px', m.group(0))
        new_content, c2 = re.subn(r'window#waybar[^{]*\{[^}]+\}', repl_window, content)
        if c2 > 0:
            content = new_content
            modified = True

        # tooltip label blocks
        def repl_tooltip(m):
            return re.sub(r'(\bfont-size\s*:\s*)[0-9]+px', rf'\g<1>{target_size}px', m.group(0))
        new_content, c3 = re.subn(r'tooltip\s+label[^{]*\{[^}]+\}', repl_tooltip, content)
        if c3 > 0:
            content = new_content
            modified = True

    if modified:
        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
        except Exception:
            pass
EOF
  else
    # Fallback to sed if python3 is unavailable
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      if [[ -n "$font" ]]; then
        sed -i -E "s/^[[:space:]]*font-family:[[:space:]]*\"[^\"]+\";/  font-family: \"${font}\";/" "$f" 2>/dev/null || true
      fi
      if [[ -n "$size" ]]; then
        sed -i -E "s/([[:space:]]*font-size:[[:space:]]*)[0-9]+px;/\1${size}px;/" "$f" 2>/dev/null || true
      fi
    done
  fi
}

# Restart Waybar cleanly
restart_waybar() {
  if [[ -x "$SCRIPTS_DIR/Refresh.sh" ]]; then
    "$SCRIPTS_DIR/Refresh.sh" >/dev/null 2>&1 &
  elif [[ -x "$SCRIPTS_DIR/WaybarStartup.sh" ]]; then
    "$SCRIPTS_DIR/WaybarStartup.sh" --restart >/dev/null 2>&1 &
  elif command -v waybar >/dev/null 2>&1; then
    pkill -x waybar >/dev/null 2>&1 || true
    sleep 0.2
    waybar >/dev/null 2>&1 &
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args...]

Commands:
  get                       Print active or current font and size as JSON
  get-font                  Print active font name (or default)
  get-size                  Print active font size (or default)
  is-active                 Exit 0 if user_env.lua has overrides, 1 otherwise
  apply <font> <size> [--no-restart]
                            Apply font and/or size, update user_env.lua, and restart Waybar
  restore [--no-restart]    Restore default font and size, comment out user_env.lua overrides
  sync                      Sync user_env.lua overrides to stylesheets (used on updates)
  list-fonts                Print list of available font family names
EOF
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    get|status)
      local cur_f cur_s act_f act_s is_ovr
      cur_f=$(get_current_font)
      cur_s=$(get_current_size)
      act_f=$(get_active_font)
      act_s=$(get_active_size)
      is_ovr="false"
      if is_override_active; then is_ovr="true"; fi
      printf '{"font":"%s","size":"%s","override_active":%s,"default_font":"%s","default_size":"%s"}\n' \
        "$cur_f" "$cur_s" "$is_ovr" "$DEFAULT_FONT" "$DEFAULT_SIZE"
      ;;
    get-font)
      get_current_font
      ;;
    get-size)
      get_current_size
      ;;
    is-active)
      if is_override_active; then exit 0; else exit 1; fi
      ;;
    apply)
      local font="${1:-}"
      local size="${2:-}"
      local no_restart=0
      for arg in "$@"; do
        if [[ "$arg" == "--no-restart" ]]; then
          no_restart=1
        fi
      done

      # Strip --no-restart from font or size if passed as positional
      [[ "$font" == "--no-restart" ]] && font=""
      [[ "$size" == "--no-restart" ]] && size=""

      [[ -z "$font" ]] && font=$(get_current_font)
      [[ -z "$size" ]] && size=$(get_current_size)

      write_user_env "$font" "$size"
      export_environment "$font" "$size"
      apply_stylesheets "$font" "$size"

      if [[ "$no_restart" -eq 0 ]]; then
        restart_waybar
      fi
      ;;
    restore)
      local no_restart=0
      if [[ "${1:-}" == "--no-restart" ]]; then
        no_restart=1
      fi

      clear_user_env
      export_environment "$DEFAULT_FONT" "$DEFAULT_SIZE"
      apply_stylesheets "$DEFAULT_FONT" "$DEFAULT_SIZE"

      if [[ "$no_restart" -eq 0 ]]; then
        restart_waybar
      fi
      ;;
    sync)
      # Synchronize user_env.lua overrides if present
      local act_f act_s
      act_f=$(get_active_font)
      act_s=$(get_active_size)

      if [[ -n "$act_f" || -n "$act_s" ]]; then
        apply_stylesheets "${act_f:-}" "${act_s:-}"
        export_environment "${act_f:-}" "${act_s:-}"
      fi
      ;;
    list-fonts)
      list_fonts
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
