#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Clipboard Manager. This script uses cliphist, rofi, and wl-copy.
# Actions:
# CTRL Del to delete an entry
# ALT Del to wipe clipboard contents

# Deliberately not `set -e`: rofi exits non-zero for cancel/delete/wipe.
set -uo pipefail

# Variables
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
scripts_dir="$config_dir/hypr/scripts"
rofi_theme="$config_dir/hypr/rofi/config-clipboard.rasi"
msg='👀 **note**  CTRL DEL = cliphist del (entry)   or   ALT DEL - cliphist wipe (all)'

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a Clipboard "$*"
}

die() {
    notify "$*"
    printf '%s\n' "$*" >&2
    exit 1
}

# Fail loudly instead of opening an empty menu (or spinning on an unknown exit code)
for dep in cliphist rofi wl-copy; do
    command -v "$dep" >/dev/null 2>&1 || die "Clipboard manager: required command '$dep' is not installed."
done

# Close a previous instance of THIS menu only; never kill unrelated rofi windows
pkill -f "$(basename "$rofi_theme")" 2>/dev/null || true

# Refreshed once per invocation, not on every delete/wipe iteration below
"$scripts_dir/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true

# cliphist previews stored binaries as: [[ binary data 729 KiB png 1729x976 ]]
# Restore the matching MIME type so images keep pasting correctly.
entry_mime() {
    local entry="$1" ext=""
    if [[ "$entry" =~ \[\[\ binary\ data\ .*\ ([A-Za-z0-9]+)\ [0-9]+x[0-9]+\ \]\] ]]; then
        ext="${BASH_REMATCH[1],,}"
    fi
    case "$ext" in
        png) printf 'image/png' ;;
        jpg | jpeg) printf 'image/jpeg' ;;
        gif) printf 'image/gif' ;;
        webp) printf 'image/webp' ;;
        bmp) printf 'image/bmp' ;;
        tiff) printf 'image/tiff' ;;
        svg) printf 'image/svg+xml' ;;
        *) printf '' ;;
    esac
}

copy_entry() {
    local entry="$1" mime
    mime="$(entry_mime "$entry")"
    if [ -n "$mime" ]; then
        printf '%s' "$entry" | cliphist decode | wl-copy --type "$mime" ||
            notify "Clipboard manager: failed to restore entry."
    else
        printf '%s' "$entry" | cliphist decode | wl-copy ||
            notify "Clipboard manager: failed to restore entry."
    fi
}

while true; do
    result=$(
        rofi -i -dmenu \
            -no-custom \
            -kb-custom-1 "Control-Delete" \
            -kb-custom-2 "Alt-Delete" \
            -config "$rofi_theme" \
            -mesg "$msg" < <(cliphist list)
    )
    rofi_status=$?

    case "$rofi_status" in
        0) # an entry was chosen (empty only when the history is empty)
            [ -n "$result" ] || exit 0
            copy_entry "$result"
            exit 0
            ;;
        1) # cancelled (Escape, or Enter with no match thanks to -no-custom)
            exit 0
            ;;
        10) # delete one entry, then reopen the list
            cliphist delete <<<"$result"
            ;;
        11) # wipe everything, drop the live selection too, then reopen
            cliphist wipe
            wl-copy --clear 2>/dev/null || true
            ;;
        *)
            die "Clipboard manager: rofi exited unexpectedly ($rofi_status)."
            ;;
    esac
done
