#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Logout helper for wlogout and keybind callers.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
LOG_FILE="${LOG_DIR}/hypr-logout.log"
if ! mkdir -p "$LOG_DIR" >/dev/null 2>&1; then
    LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-logout.log"
fi

log_msg() {
    printf "[%s] %s\n" "$(date +"%F %T")" "$1" >>"$LOG_FILE"
}

run_logged() {
    local label="$1"
    shift
    log_msg "RUN ${label}: $*"
    "$@" >>"$LOG_FILE" 2>&1
    local rc=$?
    log_msg "RC ${label}: ${rc}"
    return "$rc"
}
SESSION_USER="${USER:-$(id -un)}"
SESSION_HYPRLAND_PIDS="$(pgrep -xu "$SESSION_USER" -x Hyprland || true)"
SESSION_DM_SERVICE=""
IS_SDDM_SESSION=0

session_hyprland_running() {
    local pid
    if [ -n "$SESSION_HYPRLAND_PIDS" ]; then
        for pid in $SESSION_HYPRLAND_PIDS; do
            if kill -0 "$pid" >/dev/null 2>&1; then
                return 0
            fi
        done
        return 1
    fi
    pgrep -xu "$SESSION_USER" -x Hyprland >/dev/null 2>&1
}
logout_completed() {
    # Give the session up to 2 seconds to terminate after a successful command.
    for _ in {1..20}; do
        session_hyprland_running || return 0
        sleep 0.1
    done
    return 1
}
stop_proc() {
    local name="$1"
    pkill -u "$SESSION_USER" -x -TERM "$name" >/dev/null 2>&1 || true

    # Wait up to 1 second for graceful shutdown.
    for _ in {1..10}; do
        pgrep -xu "$SESSION_USER" -x "$name" >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    pkill -u "$SESSION_USER" -x -KILL "$name" >/dev/null 2>&1 || true
}

# Close wlogout if it is still visible.
stop_proc "wlogout"
HYPRCTL_BIN="$(command -v hyprctl || true)"
HYPRSHUTDOWN_BIN="$(command -v hyprshutdown || true)"
UWSM_BIN="$(command -v uwsm || true)"
LOGINCTL_BIN="$(command -v loginctl || true)"
if [ -n "$LOGINCTL_BIN" ] && [ -n "${XDG_SESSION_ID:-}" ]; then
    SESSION_DM_SERVICE="$("$LOGINCTL_BIN" show-session "$XDG_SESSION_ID" -p Service --value 2>/dev/null || true)"
    if [ "$SESSION_DM_SERVICE" = "sddm" ] || [ "$SESSION_DM_SERVICE" = "sddm-autologin" ]; then
        IS_SDDM_SESSION=1
    fi
fi

# Preferred path: synchronous hyprshutdown, so script does not silently succeed.
if [ -n "$HYPRSHUTDOWN_BIN" ]; then
    if run_logged "hyprshutdown-no-fork" "$HYPRSHUTDOWN_BIN" --no-fork; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprshutdown returned success but Hyprland is still running"
    fi
fi
# systemd session fallback.
if [ -n "$LOGINCTL_BIN" ] && [ -n "${XDG_SESSION_ID:-}" ]; then
    if [ "$IS_SDDM_SESSION" -eq 1 ]; then
        log_msg "Skipping loginctl terminate-session for SDDM-managed session (${SESSION_DM_SERVICE})"
    elif run_logged "loginctl-terminate-session" "$LOGINCTL_BIN" terminate-session "$XDG_SESSION_ID"; then
        if logout_completed; then
            exit 0
        fi
        log_msg "loginctl terminate-session returned success but Hyprland is still running"
    fi
fi

# Fallback: ask Hyprland to spawn hyprshutdown via a normal dispatch exec call.
if [ -n "$HYPRCTL_BIN" ] && [ -n "$HYPRSHUTDOWN_BIN" ]; then
    if run_logged \
        "hyprctl-dispatch-exec-hyprshutdown" \
        "$HYPRCTL_BIN" dispatch exec "hyprshutdown --no-fork"; then
        if logout_completed; then
            exit 0
        fi
        log_msg "hyprctl dispatched hyprshutdown but Hyprland is still running"
    fi
fi

# UWSM-managed session fallback (common on NixOS).
if [ -n "$UWSM_BIN" ] && [ "$IS_SDDM_SESSION" -eq 0 ]; then
    if run_logged "uwsm-stop" "$UWSM_BIN" stop; then
        if logout_completed; then
            exit 0
        fi
        log_msg "uwsm stop returned success but Hyprland is still running"
    fi
elif [ -n "$UWSM_BIN" ] && [ "$IS_SDDM_SESSION" -eq 1 ]; then
    log_msg "Skipping uwsm stop on SDDM-managed session to avoid delayed logout"
fi


# Last-resort Hyprland exit fallbacks.
if [ -n "$HYPRCTL_BIN" ]; then
    if [ "$IS_SDDM_SESSION" -eq 1 ]; then
        if run_logged "hyprctl-exit-1-sddm" "$HYPRCTL_BIN" dispatch exit 1; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit 1 (sddm) returned success but Hyprland is still running"
        fi
        if run_logged "hyprctl-exit-x-sddm" "$HYPRCTL_BIN" dispatch exit x; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit x (sddm) returned success but Hyprland is still running"
        fi
    else
        if run_logged "hyprctl-exit-1" "$HYPRCTL_BIN" dispatch exit 1; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit 1 returned success but Hyprland is still running"
        fi
        if run_logged "hyprctl-exit-0" "$HYPRCTL_BIN" dispatch exit 0; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit 0 returned success but Hyprland is still running"
        fi
        if run_logged "hyprctl-exit-x" "$HYPRCTL_BIN" dispatch exit x; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit x returned success but Hyprland is still running"
        fi
        if run_logged "hyprctl-exit-noarg" "$HYPRCTL_BIN" dispatch exit; then
            if logout_completed; then
                exit 0
            fi
            log_msg "hyprctl dispatch exit (no arg) returned success but Hyprland is still running"
        fi
    fi
fi

# Final process-level fallback.
if run_logged "pkill-hyprland-term" pkill -u "$SESSION_USER" -x -TERM Hyprland; then
    if logout_completed; then
        exit 0
    fi
    log_msg "SIGTERM sent to Hyprland but process is still running"
fi
if run_logged "pkill-hyprland-kill" pkill -u "$SESSION_USER" -x -KILL Hyprland; then
    exit 0
fi

log_msg "Logout failed: no method succeeded"

exit 1
