#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Rofi menu for Managing User Defaults (SUPER SHIFT E -> Manage User Defaults)

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
USER_CONFIGS="$HYPR_DIR/UserConfigs"
USER_DEFAULTS_LUA="$USER_CONFIGS/user_defaults.lua"
SYSTEM_DEFAULTS_LUA="$HYPR_DIR/lua/user_defaults.lua"

# Fallback paths for repository development or test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SYSTEM_DEFAULTS_LUA" && -f "$SCRIPT_DIR/../lua/user_defaults.lua" ]]; then
  SYSTEM_DEFAULTS_LUA="$SCRIPT_DIR/../lua/user_defaults.lua"
fi
if [[ ! -f "$USER_DEFAULTS_LUA" && -f "$SCRIPT_DIR/../UserConfigs/user_defaults.lua" && ! -d "$USER_CONFIGS" ]]; then
  USER_CONFIGS="$SCRIPT_DIR/../UserConfigs"
  USER_DEFAULTS_LUA="$USER_CONFIGS/user_defaults.lua"
fi

# Rofi theme and images
rofi_theme="$HYPR_DIR/rofi/config-user-defaults.rasi"
if [[ ! -f "$rofi_theme" && -f "$SCRIPT_DIR/../rofi/config-user-defaults.rasi" ]]; then
  rofi_theme="$SCRIPT_DIR/../rofi/config-user-defaults.rasi"
fi
if [[ ! -f "$rofi_theme" ]]; then
  rofi_theme="$HYPR_DIR/rofi/config-edit.rasi"
fi

iDIR="$CONFIG_HOME/swaync/images"
if [[ ! -d "$iDIR" && -d "$SCRIPT_DIR/../../swaync/images" ]]; then
  iDIR="$SCRIPT_DIR/../../swaync/images"
fi

wallpaper_link_script="$HYPR_DIR/scripts/RofiFocusedWallpaperLink.sh"
if [[ ! -x "$wallpaper_link_script" && -f "$SCRIPT_DIR/RofiFocusedWallpaperLink.sh" ]]; then
  wallpaper_link_script="$SCRIPT_DIR/RofiFocusedWallpaperLink.sh"
fi

notify_success() {
  local msg="$1"
  if [[ -f "$iDIR/ja.png" ]]; then
    notify-send -u low -i "$iDIR/ja.png" "User Defaults" "$msg"
  else
    notify-send -u low "User Defaults" "$msg"
  fi
}

notify_error() {
  local msg="$1"
  if [[ -f "$iDIR/error.png" ]]; then
    notify-send -u normal -i "$iDIR/error.png" "E-R-R-O-R" "$msg"
  else
    notify-send -u normal "E-R-R-O-R" "$msg"
  fi
}

# Read active override from UserConfigs/user_defaults.lua
get_user_override() {
  local key="$1"
  [[ -f "$USER_DEFAULTS_LUA" ]] || return 0
  if [[ "$key" == "search_engine" ]]; then
    sed -nE 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''][[:space:]]*(;?([[:space:]]*--.*)?)?$/\2/p' "$USER_DEFAULTS_LUA" | tail -n1
  else
    sed -nE 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.'"$key"'[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''][[:space:]]*(;?([[:space:]]*--.*)?)?$/\1/p' "$USER_DEFAULTS_LUA" | tail -n1
  fi
}

# Read base system default
get_system_default() {
  local key="$1"
  local val=""
  if [[ -f "$SYSTEM_DEFAULTS_LUA" ]]; then
    val=$(sed -nE 's/^[[:space:]]*KOOLDOTS_DEFAULTS\.'"$key"'[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''][[:space:]]*(;?([[:space:]]*--.*)?)?$/\1/p' "$SYSTEM_DEFAULTS_LUA" | tail -n1)
  fi

  if [[ -z "$val" ]]; then
    case "$key" in
      edit)
        val="${EDITOR:-nano}"
        ;;
      visual)
        val="${VISUAL:-}"
        ;;
      term)
        val="kitty"
        ;;
      files)
        val="thunar"
        ;;
      search_engine)
        val="https://www.google.com/search?q={}"
        ;;
    esac
  fi
  printf '%s' "$val"
}

# Effective value currently in use
get_effective_value() {
  local key="$1"
  local override
  override="$(get_user_override "$key")"
  if [[ -n "$override" ]]; then
    printf '%s' "$override"
  else
    get_system_default "$key"
  fi
}

# Set/update override in UserConfigs/user_defaults.lua
set_user_override() {
  local key="$1"
  local val="$2"
  mkdir -p "$USER_CONFIGS"
  if [[ ! -f "$USER_DEFAULTS_LUA" ]]; then
    cat << 'EOF' > "$USER_DEFAULTS_LUA"
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User defaults overrides template.
-- This file is sourced by lua/user_defaults.lua.

KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}
EOF
  fi

  if [[ "$key" == "search_engine" ]]; then
    if grep -qE "^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=" "$USER_DEFAULTS_LUA"; then
      sed -i -E "s|^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=.*$|KOOLDOTS_DEFAULTS.search_engine = \"${val}\"|" "$USER_DEFAULTS_LUA"
    else
      printf 'KOOLDOTS_DEFAULTS.search_engine = "%s"\n' "$val" >> "$USER_DEFAULTS_LUA"
    fi
  else
    if grep -qE "^[[:space:]]*KOOLDOTS_DEFAULTS\.${key}[[:space:]]*=" "$USER_DEFAULTS_LUA"; then
      sed -i -E "s|^[[:space:]]*KOOLDOTS_DEFAULTS\.${key}[[:space:]]*=.*$|KOOLDOTS_DEFAULTS.${key} = \"${val}\"|" "$USER_DEFAULTS_LUA"
    else
      printf 'KOOLDOTS_DEFAULTS.%s = "%s"\n' "$key" "$val" >> "$USER_DEFAULTS_LUA"
    fi
  fi
}

# Remove single field override
restore_single_default() {
  local key="$1"
  local friendly_name="$2"
  if [[ -f "$USER_DEFAULTS_LUA" ]]; then
    if [[ "$key" == "search_engine" ]]; then
      sed -i -E "/^[[:space:]]*KOOLDOTS_DEFAULTS\.(search_engine|Search_Engine)[[:space:]]*=/d" "$USER_DEFAULTS_LUA"
    else
      sed -i -E "/^[[:space:]]*KOOLDOTS_DEFAULTS\.${key}[[:space:]]*=/d" "$USER_DEFAULTS_LUA"
    fi
  fi
  local def_val
  def_val="$(get_system_default "$key")"
  [[ -z "$def_val" ]] && def_val="(none)"
  notify_success "$friendly_name restored to default ($def_val)."
}

# Global restore defaults: removes SPECIFIC custom entries only
restore_all_defaults() {
  if [[ -f "$USER_DEFAULTS_LUA" ]]; then
    sed -i -E "/^[[:space:]]*KOOLDOTS_DEFAULTS\.(edit|visual|term|files|search_engine|Search_Engine)[[:space:]]*=/d" "$USER_DEFAULTS_LUA"
  fi
  notify_success "All user defaults restored to system defaults."
}

# Validate command binary exists in PATH
validate_command() {
  local cmd="$1"
  cmd=$(echo "$cmd" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [[ -z "$cmd" ]] && return 1

  local bin
  read -r bin _ <<< "$cmd"
  bin="${bin%\"}"
  bin="${bin#\"}"
  bin="${bin%\'}"
  bin="${bin#\'}"

  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Resolve search engine string/shorthand/URL to template URL
resolve_search_engine_url() {
  local input="$1"
  input=$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local lower
  lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

  # 1. Preset names and known exceptions
  case "$lower" in
    duckduckgo|ddg|"duckduckgo.com"|*"duckduckgo.com"|*"duckduckgo.com/")
      printf '%s' "https://duckduckgo.com/?q={}"
      return 0
      ;;
    startpage|"startpage.com"|*"startpage.com"|*"startpage.com/")
      printf '%s' "https://www.startpage.com/sp/search?query={}"
      return 0
      ;;
    google|"google.com"|*"google.com"|*"google.com/")
      printf '%s' "https://www.google.com/search?q={}"
      return 0
      ;;
    bing|"bing.com"|*"bing.com"|*"bing.com/")
      printf '%s' "https://www.bing.com/search?q={}"
      return 0
      ;;
    brave|"brave.com"|*"brave.com"|*"brave.com/")
      printf '%s' "https://search.brave.com/search?q={}"
      return 0
      ;;
    ecosia|"ecosia.org"|*"ecosia.org"|*"ecosia.org/")
      printf '%s' "https://www.ecosia.org/search?q={}"
      return 0
      ;;
    kagi|"kagi.com"|*"kagi.com"|*"kagi.com/")
      printf '%s' "https://kagi.com/search?q={}"
      return 0
      ;;
    yahoo|"yahoo.com"|*"yahoo.com"|*"yahoo.com/")
      printf '%s' "https://search.yahoo.com/search?q={}"
      return 0
      ;;
    qwant|"qwant.com"|*"qwant.com"|*"qwant.com/")
      printf '%s' "https://www.qwant.com/?q={}"
      return 0
      ;;
  esac

  local url="$input"
  if [[ ! "$url" =~ ^https?:// ]]; then
    if [[ "$url" != *"."* ]]; then
      url="https://www.${url}.com"
    else
      url="https://${url}"
    fi
  fi

  # Check exceptions within URL
  if [[ "$url" =~ https?://([^/]+\.)?duckduckgo\.com ]]; then
    if [[ "$url" != *"{}"* ]]; then
      printf '%s' "https://duckduckgo.com/?q={}"
      return 0
    fi
  elif [[ "$url" =~ https?://([^/]+\.)?startpage\.com ]]; then
    if [[ "$url" != *"{}"* ]]; then
      printf '%s' "https://www.startpage.com/sp/search?query={}"
      return 0
    fi
  fi

  # If template is already present
  if [[ "$url" == *"{}"* ]]; then
    printf '%s' "$url"
    return 0
  fi

  # If ends with query assignment like ?q= or ?query=
  if [[ "$url" =~ (\?|&)(q|query)=$ ]]; then
    printf '%s' "${url}{}"
    return 0
  fi

  # Majority of sites use /search?q={}
  url="${url%/}"
  printf '%s' "${url}/search?q={}"
  return 0
}

# Validate formatted URL and check domain resolution
validate_search_engine_url() {
  local url="$1"
  # Valid URL structure
  if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
    return 1
  fi
  # Must contain {} placeholder
  if [[ "$url" != *"{}"* ]]; then
    return 1
  fi

  # Extract host
  local host=""
  if [[ "$url" =~ ^https?://([^/:]+) ]]; then
    host="${BASH_REMATCH[1]}"
  else
    return 1
  fi

  # If network connectivity exists, verify host can be resolved
  if getent ahosts 1.1.1.1 >/dev/null 2>&1 || getent ahosts google.com >/dev/null 2>&1; then
    if ! getent ahosts "$host" >/dev/null 2>&1; then
      return 2
    fi
  fi

  return 0
}

# Run rofi with current theme and wallpaper link
run_rofi() {
  local mesg="$1"
  local extra_theme_str="$2"
  shift 2

  if [[ -x "$wallpaper_link_script" ]]; then
    "$wallpaper_link_script" >/dev/null 2>&1 || true
  fi

  local cmd=(rofi -i -dmenu)
  if [[ -f "$rofi_theme" && -f "$CONFIG_HOME/hypr/rofi/config.rasi" ]]; then
    cmd+=(-config "$rofi_theme")
  fi
  if [[ -n "$mesg" ]]; then
    cmd+=(-mesg "$mesg")
  fi
  if [[ -n "$extra_theme_str" ]]; then
    cmd+=(-theme-str "$extra_theme_str")
  fi

  "${cmd[@]}" "$@"
}

# Submenu to edit a command-based field
edit_command_field() {
  local key="$1"
  local friendly_name="$2"
  local current_val
  current_val="$(get_effective_value "$key")"
  [[ -z "$current_val" ]] && current_val="(none)"

  local -a options=()
  options+=("🔄 Restore Default")

  if [[ "$key" == "visual" ]]; then
    options+=("None / Clear (empty)")
  fi

  local -a candidates=()
  case "$key" in
    term)
      candidates=(kitty ghostty alacritty foot wezterm urxvt xterm)
      ;;
    edit)
      candidates=(nvim vim nano hx helix micro emacs)
      ;;
    visual)
      candidates=(code vscodium kate gedit subl emacs)
      ;;
    files)
      candidates=(thunar nautilus dolphin nemo pcmanfm yazi ranger)
      ;;
  esac

  for c in "${candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1 && [[ "$c" != "$current_val" ]]; then
      options+=("$c")
    fi
  done

  options+=("✏️  Enter custom value...")

  local choice
  choice=$(printf '%s\n' "${options[@]}" | run_rofi "$friendly_name | Current: $current_val" "listview { lines: 6; }")
  [[ -z "$choice" ]] && return 0

  if [[ "$choice" == "🔄 Restore Default"* ]]; then
    restore_single_default "$key" "$friendly_name"
    return 0
  fi

  if [[ "$key" == "visual" && "$choice" == "None / Clear (empty)" ]]; then
    set_user_override "$key" ""
    notify_success "$friendly_name set to none."
    return 0
  fi

  local new_cmd="$choice"
  if [[ "$choice" == "✏️  Enter custom value..." ]]; then
    new_cmd=$(printf '' | run_rofi "Enter executable name for $friendly_name:" "" -p "$friendly_name")
    [[ -z "$new_cmd" ]] && return 0
  fi

  # For visual, empty is allowed
  if [[ "$key" == "visual" && ("$new_cmd" == "none" || "$new_cmd" == "clear" || "$new_cmd" == "empty") ]]; then
    set_user_override "$key" ""
    notify_success "$friendly_name set to none."
    return 0
  fi

  if ! validate_command "$new_cmd"; then
    local bin
    read -r bin _ <<< "$new_cmd"
    notify_error "'$bin' is not installed or misspelled. Value was not updated."
    return 1
  fi

  set_user_override "$key" "$new_cmd"
  notify_success "$friendly_name set to '$new_cmd'."
  return 0
}

# Submenu to edit Search Engine
edit_search_engine_field() {
  local current_val
  current_val="$(get_effective_value "search_engine")"

  local -a options=(
    "🔄 Restore Default"
    "DuckDuckGo (https://duckduckgo.com/?q={})"
    "StartPage (https://www.startpage.com/sp/search?query={})"
    "Google (https://www.google.com/search?q={})"
    "Brave (https://search.brave.com/search?q={})"
    "Bing (https://www.bing.com/search?q={})"
    "Ecosia (https://www.ecosia.org/search?q={})"
    "Kagi (https://kagi.com/search?q={})"
    "Yahoo (https://search.yahoo.com/search?q={})"
    "Qwant (https://www.qwant.com/?q={})"
    "✏️  Enter custom search engine or URL..."
  )

  local choice
  choice=$(printf '%s\n' "${options[@]}" | run_rofi "Default Search Engine | Current: $current_val" "listview { lines: 8; }")
  [[ -z "$choice" ]] && return 0

  if [[ "$choice" == "🔄 Restore Default"* ]]; then
    restore_single_default "search_engine" "Default Search Engine"
    return 0
  fi

  local raw_input="$choice"
  if [[ "$choice" == "✏️  Enter custom search engine or URL..." ]]; then
    raw_input=$(printf '' | run_rofi "Enter name (e.g. duckduckgo) or URL with {}:" "" -p "Search Engine")
    [[ -z "$raw_input" ]] && return 0
  elif [[ "$choice" =~ ^([A-Za-z0-9]+)[[:space:]]*\( ]]; then
    raw_input="${BASH_REMATCH[1]}"
  fi

  local resolved_url
  resolved_url="$(resolve_search_engine_url "$raw_input")"

  validate_search_engine_url "$resolved_url"
  local val_res=$?
  if [[ $val_res -eq 1 ]]; then
    notify_error "Invalid URL format. URL must include search template query with {} (e.g. /search?q={})."
    return 1
  elif [[ $val_res -eq 2 ]]; then
    local host=""
    [[ "$resolved_url" =~ ^https?://([^/:]+) ]] && host="${BASH_REMATCH[1]}"
    notify_error "Host '$host' could not be resolved. Please check spelling or connectivity."
    return 1
  fi

  set_user_override "search_engine" "$resolved_url"
  notify_success "Default Search Engine set to '$resolved_url'."
  return 0
}

# Main menu loop
main_menu() {
  while true; do
    local edit_val visual_val term_val files_val search_val
    edit_val="$(get_effective_value "edit")"
    visual_val="$(get_effective_value "visual")"
    [[ -z "$visual_val" ]] && visual_val="(none)"
    term_val="$(get_effective_value "term")"
    files_val="$(get_effective_value "files")"
    search_val="$(get_effective_value "search_engine")"

    local -a menu_items=(
      "$(printf '%-24s %s' "Text Editor:" "$edit_val")"
      "$(printf '%-24s %s' "GUI editor:" "$visual_val")"
      "$(printf '%-24s %s' "Terminal:" "$term_val")"
      "$(printf '%-24s %s' "File Manager:" "$files_val")"
      "$(printf '%-24s %s' "Default Search Engine:" "$search_val")"
      "Restore defaults"
    )

    local choice
    choice=$(printf '%s\n' "${menu_items[@]}" | run_rofi "Select item to edit or restore defaults" "listview { lines: 6; }")
    [[ -z "$choice" ]] && break

    case "$choice" in
      "Text Editor:"*)
        edit_command_field "edit" "Text Editor"
        ;;
      "GUI editor:"*)
        edit_command_field "visual" "GUI editor"
        ;;
      "Terminal:"*)
        edit_command_field "term" "Terminal"
        ;;
      "File Manager:"*)
        edit_command_field "files" "File Manager"
        ;;
      "Default Search Engine:"*)
        edit_search_engine_field
        ;;
      "Restore defaults"*)
        restore_all_defaults
        ;;
      *)
        break
        ;;
    esac
  done
}

# If rofi is already running, terminate previous instance
if pidof rofi >/dev/null 2>&1; then
  pkill -x rofi
fi

main_menu
