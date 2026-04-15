#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Polkit Diagnostic & Triage Script #

# Default values
OUTFILE="$HOME/Downloads/Polkit-diag.txt"
DRY_RUN=0
INSTALL_OVERRIDE=0
FORCE_OVERRIDE=0

# Systemd override details for hyprpolkitagent
OVERRIDE_DIR="$HOME/.config/systemd/user/hyprpolkitagent.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

OVERRIDE_CONTENT="[Unit]
After=
After=dbus.service graphical-session.target
PartOf=graphical-session.target

[Install]
WantedBy=graphical-session.target"

print_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]
Gather diagnostic information for polkit issues and optionally apply a systemd override.
This script is modular and extensible for different Linux distributions.

Options:
  -h, --help            Show this help message and exit
  -d, --dry-run         Run without making changes (output to stdout instead of file)
  --install-override    Install the systemd override for hyprpolkitagent if not already present
  --force-override      Overwrite the existing systemd override for hyprpolkitagent
  -o, --output FILE     Specify custom output file (default: $HOME/Downloads/Polkit-diag.txt)
EOF
}

setup_output() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "================================================="
        echo " [Dry Run] Diagnostics will be printed to stdout."
        echo "================================================="
        exec 3>&1
    else
        local outdir
        outdir=$(dirname "$OUTFILE")
        
        # Check and create directory if it doesn't exist
        if [[ ! -d "$outdir" ]]; then
            echo "Directory $outdir does not exist. Creating..."
            mkdir -p "$outdir"
        fi
        
        # Backup existing file
        if [[ -f "$OUTFILE" ]]; then
            local backup_file="${OUTFILE}.bak.$(date +%Y%m%d%H%M%S)"
            echo "Existing output file found. Backing up to: $backup_file"
            mv "$OUTFILE" "$backup_file"
        fi
        
        echo "Diagnostics will be saved to: $OUTFILE"
        exec 3> "$OUTFILE"
    fi
}

apply_override() {
    if [[ $INSTALL_OVERRIDE -eq 1 ]]; then
        echo -e "\n=== Systemd Override for hyprpolkitagent ===" >&3
        
        if systemctl --user is-enabled hyprpolkitagent.service >/dev/null 2>&1; then
            echo "hyprpolkitagent.service is currently enabled." >&3
        else
            echo "hyprpolkitagent.service is NOT enabled. You may need to enable it." >&3
        fi

        if [[ -f "$OVERRIDE_FILE" && $FORCE_OVERRIDE -eq 0 ]]; then
            echo "Override already exists at $OVERRIDE_FILE." >&3
            echo "Use --force-override to overwrite it." >&3
        else
            echo "Installing override to $OVERRIDE_FILE..." >&3
            if [[ $DRY_RUN -eq 0 ]]; then
                mkdir -p "$OVERRIDE_DIR"
                echo "$OVERRIDE_CONTENT" > "$OVERRIDE_FILE"
                systemctl --user daemon-reload
                echo "Systemd daemon reloaded." >&3
                
                # Optionally attempt to restart the service to apply changes
                if systemctl --user is-active --quiet hyprpolkitagent.service; then
                    echo "Restarting hyprpolkitagent.service..." >&3
                    systemctl --user restart hyprpolkitagent.service || echo "Failed to restart service." >&3
                fi
            else
                echo "[Dry Run] Would create $OVERRIDE_FILE and reload systemd daemon." >&3
            fi
        fi
    fi
}

gather_general_info() {
    echo -e "\n=======================================" >&3
    echo -e "       General System Information" >&3
    echo -e "=======================================" >&3
    echo "Date: $(date)" >&3
    echo -e "\n--- Kernel ---" >&3
    uname -a >&3
    
    echo -e "\n--- OS Release ---" >&3
    cat /etc/os-release >&3
    
    echo -e "\n=======================================" >&3
    echo -e "         Polkit Service Status" >&3
    echo -e "=======================================" >&3
    
    echo -e "\n--- System Polkit Service ---" >&3
    systemctl status polkit.service --no-pager >&3 2>&1 || true
    
    echo -e "\n--- User Hyprpolkitagent Service ---" >&3
    systemctl --user status hyprpolkitagent.service --no-pager >&3 2>&1 || true
    
    echo -e "\n--- Running Polkit Processes ---" >&3
    ps aux | grep -i '[p]olkit' >&3 || echo "No polkit processes found running." >&3
    
    echo -e "\n=======================================" >&3
    echo -e "            Recent Logs" >&3
    echo -e "=======================================" >&3
    
    echo -e "\n--- Journalctl (polkit.service) [Last 50 entries, warnings/errors] ---" >&3
    journalctl -u polkit.service -n 50 --no-pager -p 4 >&3 2>&1 || echo "Could not fetch system polkit logs." >&3
    
    echo -e "\n--- Journalctl (hyprpolkitagent.service) [Last 50 entries] ---" >&3
    journalctl --user -u hyprpolkitagent.service -n 50 --no-pager >&3 2>&1 || echo "Could not fetch user hyprpolkitagent logs." >&3
}

gather_arch_info() {
    echo -e "\n=======================================" >&3
    echo -e "        Package Info (Arch Linux)" >&3
    echo -e "=======================================" >&3
    
    # Essential packages required for polkit & related UI (from 01-hypr-pkgs.sh)
    local pkgs=(
        "qt5-declarative"
        "qt5-quickcontrols2"
        "qt6-declarative"
        "qt6-quickcontrols2"
        "hyprpolkitagent"
        "polkit"
        "xfce-polkit"
    )
    
    local missing_pkgs=()
    
    for pkg in "${pkgs[@]}"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            echo "[INSTALLED] $(pacman -Q "$pkg")" >&3
        else
            echo "[MISSING]   $pkg" >&3
            missing_pkgs+=("$pkg")
        fi
    done
    
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        echo -e "\nWARNING: The following required packages are missing:" >&3
        for mpkg in "${missing_pkgs[@]}"; do
            echo "  - $mpkg" >&3
        done
        echo "You can install them by running: sudo pacman -S ${missing_pkgs[*]}" >&3
    else
        echo -e "\nSUCCESS: All expected packages are installed." >&3
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS="unknown"
    fi
}

# ----------------------------------------------------------------------------
# Main Execution
# ----------------------------------------------------------------------------

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=1
            ;;
        --install-override)
            INSTALL_OVERRIDE=1
            ;;
        --force-override)
            FORCE_OVERRIDE=1
            INSTALL_OVERRIDE=1
            ;;
        -o|--output)
            if [[ -n "$2" && "$2" != -* ]]; then
                OUTFILE="$2"
                shift
            else
                echo "Error: Argument for $1 is missing" >&2
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_help
            exit 1
            ;;
    esac
    shift
done

setup_output

echo "Starting Polkit Diagnostic Script..." >&3

# Optional apply override logic
if [[ $INSTALL_OVERRIDE -eq 1 ]]; then
    apply_override
fi

# Gather general info
gather_general_info

# Gather OS-specific package info
detect_os
case "$OS" in
    arch|artix|manjaro|endeavouros|cachyos)
        gather_arch_info
        ;;
    debian|ubuntu|pop|linuxmint)
        echo -e "\n=======================================" >&3
        echo -e "        Package Info ($OS)" >&3
        echo -e "=======================================" >&3
        echo "Debian/Ubuntu-based package check is pending implementation." >&3
        ;;
    fedora)
        echo -e "\n=======================================" >&3
        echo -e "        Package Info ($OS)" >&3
        echo -e "=======================================" >&3
        echo "Fedora package check is pending implementation." >&3
        ;;
    opensuse*)
        echo -e "\n=======================================" >&3
        echo -e "        Package Info ($OS)" >&3
        echo -e "=======================================" >&3
        echo "OpenSUSE package check is pending implementation." >&3
        ;;
    nixos)
        echo -e "\n=======================================" >&3
        echo -e "        Package Info ($OS)" >&3
        echo -e "=======================================" >&3
        echo "NixOS configuration check is pending implementation." >&3
        ;;
    *)
        echo -e "\n=======================================" >&3
        echo -e "        Package Info" >&3
        echo -e "=======================================" >&3
        echo "Unknown or unsupported OS: $OS. Skipping package checks." >&3
        ;;
esac

echo -e "\nDiagnostics completed at $(date)" >&3

if [[ $DRY_RUN -eq 0 ]]; then
    echo "================================================="
    echo " Diagnostic gathering complete!"
    echo " Please review the output file: $OUTFILE"
    echo "================================================="
fi
