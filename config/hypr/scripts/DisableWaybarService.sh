#!/usr/bin/env bash
set -u
set -o pipefail

SERVICE_NAME="waybar.service"
ACTION=""
DRY_RUN=false
OPERATION_RESULT="not-run"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

ICON_OK="✅"
ICON_WARN="⚠️"
ICON_ERR="❌"
ICON_INFO="ℹ️"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Disable --user ${SERVICE_NAME} (default action), revert it, or check status.

Options:
  -h, --help      Show this help message and exit
  -r, --revert    Revert by enabling + starting --user ${SERVICE_NAME}
  -d, --dry-run   Print actions without changing anything
  -s, --status    Show current status of --user ${SERVICE_NAME}
EOF
}

info() {
    printf "${BLUE}${ICON_INFO} %s${NC}\n" "$1"
}

ok() {
    printf "${GREEN}${ICON_OK} %s${NC}\n" "$1"
}

warn() {
    printf "${YELLOW}${ICON_WARN} %s${NC}\n" "$1"
}

error() {
    printf "${RED}${ICON_ERR} %s${NC}\n" "$1" >&2
}

fail() {
    error "$1"
    exit 1
}

format_command() {
    printf "%q " "$@"
}

run_cmd() {
    if $DRY_RUN; then
        info "[dry-run] $(format_command "$@")"
        return 0
    fi
    "$@"
}

set_action() {
    local new_action="$1"
    if [[ -n "$ACTION" && "$ACTION" != "$new_action" ]]; then
        fail "Conflicting options: cannot combine '${ACTION}' with '${new_action}'."
    fi
    ACTION="$new_action"
}

require_systemctl() {
    command -v systemctl >/dev/null 2>&1 || fail "systemctl is required but was not found."
}

require_user_manager() {
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        fail "Cannot contact systemd user manager. Ensure your user systemd session is running."
    fi
}

service_load_state() {
    systemctl --user show --property=LoadState --value "${SERVICE_NAME}" 2>/dev/null || true
}

service_exists() {
    local load_state
    load_state="$(service_load_state)"
    [[ -n "${load_state}" && "${load_state}" != "not-found" ]]
}

require_service_exists() {
    if ! service_exists; then
        fail "--user ${SERVICE_NAME} was not found. Exiting."
    fi
}

get_enabled_state() {
    local state
    state="$(systemctl --user is-enabled "${SERVICE_NAME}" 2>/dev/null || true)"
    [[ -n "${state}" ]] || state="unknown"
    printf "%s" "${state}"
}

get_active_state() {
    local state
    state="$(systemctl --user is-active "${SERVICE_NAME}" 2>/dev/null || true)"
    [[ -n "${state}" ]] || state="unknown"
    printf "%s" "${state}"
}

print_state_line() {
    local label="$1"
    local state="$2"
    local color="${BLUE}"
    local icon="${ICON_INFO}"

    case "${state}" in
        loaded|enabled|active)
            color="${GREEN}"
            icon="${ICON_OK}"
            ;;
        activating|deactivating|reloading|inactive|disabled|static|indirect|masked)
            color="${YELLOW}"
            icon="${ICON_WARN}"
            ;;
        failed|not-found|unknown)
            color="${RED}"
            icon="${ICON_ERR}"
            ;;
    esac

    printf "  %-9s: %b%s %s%b\n" "${label}" "${color}" "${icon}" "${state}" "${NC}"
}

print_report() {
    local load_state enabled_state active_state dry_run_state result_color result_icon result_text

    load_state="$(service_load_state)"
    [[ -n "${load_state}" ]] || load_state="unknown"
    enabled_state="$(get_enabled_state)"
    active_state="$(get_active_state)"
    dry_run_state="no"
    $DRY_RUN && dry_run_state="yes"

    case "${OPERATION_RESULT}" in
        success)
            result_color="${GREEN}"
            result_icon="${ICON_OK}"
            result_text="success"
            ;;
        dry-run)
            result_color="${YELLOW}"
            result_icon="${ICON_WARN}"
            result_text="dry-run"
            ;;
        failed)
            result_color="${RED}"
            result_icon="${ICON_ERR}"
            result_text="failed"
            ;;
        *)
            result_color="${BLUE}"
            result_icon="${ICON_INFO}"
            result_text="not-run"
            ;;
    esac

    printf "\n${BLUE}${ICON_INFO} Report for --user %s${NC}\n" "${SERVICE_NAME}"
    print_state_line "LoadState" "${load_state}"
    print_state_line "Enabled" "${enabled_state}"
    print_state_line "Active" "${active_state}"
    printf "  %-9s: %s\n" "Dry-run" "${dry_run_state}"
    printf "  %-9s: %b%s %s%b\n" "Result" "${result_color}" "${result_icon}" "${result_text}" "${NC}"
}

perform_disable() {
    info "Disabling and stopping --user ${SERVICE_NAME}..."
    if run_cmd systemctl --user disable --now "${SERVICE_NAME}"; then
        if $DRY_RUN; then
            OPERATION_RESULT="dry-run"
            warn "Dry-run complete. No changes were made."
        else
            OPERATION_RESULT="success"
            ok "Disabled and stopped --user ${SERVICE_NAME}."
        fi
        return 0
    fi

    OPERATION_RESULT="failed"
    error "Failed to disable --user ${SERVICE_NAME}."
    return 1
}

perform_revert() {
    info "Reverting --user ${SERVICE_NAME} (unmask + enable + start)..."
    if ! run_cmd systemctl --user unmask "${SERVICE_NAME}"; then
        OPERATION_RESULT="failed"
        error "Failed to unmask --user ${SERVICE_NAME}."
        return 1
    fi
    if ! run_cmd systemctl --user enable --now "${SERVICE_NAME}"; then
        OPERATION_RESULT="failed"
        error "Failed to enable/start --user ${SERVICE_NAME}."
        return 1
    fi

    if $DRY_RUN; then
        OPERATION_RESULT="dry-run"
        warn "Dry-run complete. No changes were made."
    else
        OPERATION_RESULT="success"
        ok "Reverted successfully. --user ${SERVICE_NAME} is enabled and started."
    fi
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--revert)
            set_action "revert"
            ;;
        -d|--dry-run)
            DRY_RUN=true
            ;;
        -s|--status)
            set_action "status"
            ;;
        *)
            fail "Unknown option: $1 (use -h or --help)"
            ;;
    esac
    shift
done

[[ -n "${ACTION}" ]] || ACTION="disable"

require_systemctl
require_user_manager
require_service_exists

exit_code=0
case "${ACTION}" in
    disable)
        perform_disable || exit_code=1
        ;;
    revert)
        perform_revert || exit_code=1
        ;;
    status)
        OPERATION_RESULT="success"
        info "Status requested for --user ${SERVICE_NAME}."
        ;;
esac

print_report
exit "${exit_code}"