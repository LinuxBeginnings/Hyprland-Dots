#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Supervises the cliphist clipboard watcher (used by ClipManager.sh).
#
# A single watcher stores every offered type (text, images, uri-lists). cliphist
# documents this form: `wl-paste --watch cliphist store`. Running separate
# `--type text` / `--type image` watchers doubles the number of readers per
# selection change, which can drop entries, and stores duplicates for offers
# that carry both text and image.
#
# wl-paste also exits when it hits a transient error or the compositor restarts.
# Startup marks its commands as done on first launch, so a dead watcher was
# never restarted for the rest of the session. This supervisor brings it back
# and only gives up once the Wayland socket itself is gone (session ending).

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

log() {
    printf '[ClipboardWatcher] %s\n' "$*" >&2
}

for dep in wl-paste cliphist; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        log "'$dep' is not installed; clipboard history is disabled."
        exit 1
    fi
done

resolve_wayland_socket() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ]; then
        printf '%s' "$WAYLAND_DISPLAY"
        return 0
    fi
    for sock in "$runtime"/wayland-[0-9]*; do
        [ -S "$sock" ] || continue
        case "$(basename "$sock")" in
            *awww*) continue ;;
        esac
        printf '%s' "$(basename "$sock")"
        return 0
    done
    return 1
}

# Wait for the compositor socket (up to ~20s) so starting early does not
# permanently disable clipboard history for the session.
wayland_display=""
for _ in $(seq 1 200); do
    wayland_display="$(resolve_wayland_socket)" && break
    wayland_display=""
    sleep 0.1
done
if [ -z "$wayland_display" ]; then
    log "no Wayland socket in '$runtime'; clipboard history is disabled."
    exit 1
fi
export WAYLAND_DISPLAY="$wayland_display"

log "watching the clipboard on display '$WAYLAND_DISPLAY'."

while :; do
    wl-paste --watch cliphist store
    status=$?
    if ! resolve_wayland_socket >/dev/null; then
        log "Wayland socket '$WAYLAND_DISPLAY' is gone; stopping."
        exit 0
    fi
    log "wl-paste exited ($status); restarting."
    sleep 1
done
