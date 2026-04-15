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
        local msg="\n=== Systemd Override for hyprpolkitagent ==="
        [[ $DRY_RUN -eq 0 ]] && echo -e "$msg" >&3
        echo -e "$msg"
        
        local out
        if systemctl --user is-enabled hyprpolkitagent.service >/dev/null 2>&1; then
            msg="[STATUS] hyprpolkitagent.service is currently enabled."
        else
            msg="[STATUS] hyprpolkitagent.service is NOT enabled. You may need to enable it."
        fi
        [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3
        echo "$msg"

        if [[ -f "$OVERRIDE_FILE" && $FORCE_OVERRIDE -eq 0 ]]; then
            msg="[INFO]   Override already exists at $OVERRIDE_FILE."
            [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
            msg="[ACTION] Use --force-override to overwrite it."
            [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
        else
            if [[ -f "$OVERRIDE_FILE" && $FORCE_OVERRIDE -eq 1 ]]; then
                msg="[CONFIRM] Force override requested. Overwriting existing override..."
                [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
            fi
            
            msg="[ACTION] Installing override to $OVERRIDE_FILE..."
            [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
            
            if [[ $DRY_RUN -eq 0 ]]; then
                # Capture dir creation
                if out=$(mkdir -p "$OVERRIDE_DIR" 2>&1); then
                    msg="  [OK] Created/verified directory $OVERRIDE_DIR."
                else
                    msg="  [ERROR] Failed to create directory $OVERRIDE_DIR.\n  Details: $out"
                fi
                echo -e "$msg" >&3; echo -e "$msg"
                
                # Capture file write
                if out=$(echo "$OVERRIDE_CONTENT" > "$OVERRIDE_FILE" 2>&1); then
                    msg="  [OK] Successfully wrote override file."
                else
                    msg="  [ERROR] Failed to write override file.\n  Details: $out"
                fi
                echo -e "$msg" >&3; echo -e "$msg"
                
                # Capture daemon-reload
                if out=$(systemctl --user daemon-reload 2>&1); then
                    msg="  [OK] Systemd daemon reloaded."
                else
                    msg="  [ERROR] Failed to reload systemd daemon.\n  Details: $out"
                fi
                echo -e "$msg" >&3; echo -e "$msg"
                
                # Capture restart
                if systemctl --user is-active --quiet hyprpolkitagent.service; then
                    msg="[ACTION] Restarting hyprpolkitagent.service..."
                    [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
                    
                    if out=$(systemctl --user restart hyprpolkitagent.service 2>&1); then
                        msg="  [OK] Service restarted successfully."
                    else
                        msg="  [ERROR] Failed to restart service.\n  Details: $out"
                    fi
                    echo -e "$msg" >&3; echo -e "$msg"
                else
                    msg="[INFO]   Service is not currently active, skipping restart step."
                    [[ $DRY_RUN -eq 0 ]] && echo "$msg" >&3; echo "$msg"
                fi
            else
                msg="[Dry Run] Would create $OVERRIDE_FILE and reload systemd daemon."
                echo "$msg"
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
    local polkit_procs
    polkit_procs=$(ps aux | grep -i '[p]olkit')
    if [[ -n "$polkit_procs" ]]; then
        echo "$polkit_procs" >&3
        
        # Check for conflicting agents
        local kde_agent_running=0
        local gnome_agent_running=0
        local hypr_agent_running=0
        
        if echo "$polkit_procs" | grep -q "polkit-kde-authentication-agent-1"; then
            kde_agent_running=1
        fi
        if echo "$polkit_procs" | grep -q "polkit-gnome-authentication-agent-1"; then
            gnome_agent_running=1
        fi
        if echo "$polkit_procs" | grep -q "hyprpolkitagent"; then
            hypr_agent_running=1
        fi
        
        if [[ $hypr_agent_running -eq 1 && ($kde_agent_running -eq 1 || $gnome_agent_running -eq 1) ]]; then
            echo -e "\n[!] CONFLICT DETECTED: Multiple polkit agents are running!" >&3
            echo "    Hyprpolkitagent is running alongside another desktop environment's agent." >&3
            echo "    Only ONE polkit agent can be registered at a time." >&3
            if [[ $kde_agent_running -eq 1 ]]; then
                echo "    -> Found KDE polkit agent. You may need to disable it in Hyprland by adding 'NotShowIn=Hyprland;' to its autostart .desktop file." >&3
            fi
            if [[ $gnome_agent_running -eq 1 ]]; then
                echo "    -> Found GNOME polkit agent. You may need to disable it in Hyprland." >&3
            fi
        elif [[ $kde_agent_running -eq 1 && $hypr_agent_running -eq 0 ]]; then
            echo -e "\n[!] WARNING: KDE polkit agent is running instead of hyprpolkitagent." >&3
            echo "    This can cause 'authentication agent already exists' errors if hyprpolkitagent tries to start later." >&3
        fi
    else
        echo "No polkit processes found running." >&3
    fi
    
    echo -e "\n=======================================" >&3
    echo -e "            Recent Logs" >&3
    echo -e "=======================================" >&3
    
    echo -e "\n--- Journalctl (polkit.service) [Last 50 entries, warnings/errors] ---" >&3
    journalctl -u polkit.service -n 50 --no-pager -p 4 >&3 2>&1 || echo "Could not fetch system polkit logs." >&3
    
    echo -e "\n--- Journalctl (hyprpolkitagent.service) [Last 50 entries] ---" >&3
    journalctl --user -u hyprpolkitagent.service -n 50 --no-pager >&3 2>&1 || echo "Could not fetch user hyprpolkitagent logs." >&3
}

# --- Modular Package Checking System ---
check_packages() {
    local check_cmd="$1"
    local install_msg="$2"
    shift 2
    local pkgs=("$@")
    
    local missing_pkgs=()
    for pkg in "${pkgs[@]}"; do
        local out
        if out=$(eval "$check_cmd \"$pkg\"" 2>/dev/null); then
            # Print the first line of output as the installed info
            echo "[INSTALLED] $(echo "$out" | head -n 1)" >&3
        else
            echo "[MISSING]   $pkg" >&3
            missing_pkgs+=("$pkg")
        fi
    done
    
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        echo -e "\nWARNING: The following packages are missing:" >&3
        for mpkg in "${missing_pkgs[@]}"; do
            echo "  - $mpkg" >&3
        done
        echo "$install_msg ${missing_pkgs[*]}" >&3
        return 1
    fi
    return 0
}
check_source_binaries() {
    local bin_dir="$1"
    shift
    local bins=("$@")
    local found_any=0
    
    echo -e "\n--- Source Builds (${bin_dir}) ---" >&3
    for bin in "${bins[@]}"; do
        if [[ -x "${bin_dir}/${bin}" ]]; then
            echo "[SOURCE]    ${bin_dir}/${bin}" >&3
            found_any=1
        else
            echo "[MISSING]   ${bin_dir}/${bin}" >&3
        fi
    done
    
    return $found_any
}

gather_arch_info() {
    echo -e "\n=======================================" >&3
    echo -e "        Package Info (Arch Linux)" >&3
    echo -e "=======================================" >&3
    
    # Essential packages required for polkit & related UI
    local pkgs=(
        "qt5-declarative"
        "qt5-quickcontrols2"
        "qt6-declarative"
        "hyprpolkitagent"
        "polkit"
    )
    
    local aur_pkgs=(
        "xfce-polkit"
    )
    
    local missing_any=0
    
    echo -e "\n--- Official Repositories ---" >&3
    check_packages "pacman -Q" "Install official packages by running: sudo pacman -S" "${pkgs[@]}" || missing_any=1
    
    echo -e "\n--- AUR ---" >&3
    check_packages "pacman -Q" "Install AUR packages by running: yay -S" "${aur_pkgs[@]}" || missing_any=1
    
    if [[ $missing_any -eq 0 ]]; then
        echo -e "\nSUCCESS: All expected packages are installed." >&3
    fi
}
gather_ubuntu_info() {
    echo -e "\n=======================================" >&3
    echo -e "        Package Info (Ubuntu/PPA)" >&3
    echo -e "=======================================" >&3
    
    # Essential packages required for polkit & related UI
    local pkgs=(
        "qml-module-qtqml"
        "qml-module-qtquick2"
        "qml-module-qtquick-controls"
        "qml-module-qtquick-controls2"
        "qml-module-qtquick-layouts"
        "qml6-module-qtqml"
        "qml6-module-qtquick"
        "qml6-module-qtquick-controls"
        "hyprpolkitagent"
        "polkit"
    )
    
    local extra_pkgs=(
        "xfce-polkit"
        "polkit-kde-agent-1"
        "mate-polkit"
    )
    
    local missing_any=0
    
    echo -e "\n--- Official Repositories / PPA ---" >&3
    check_packages "dpkg -s" "Install packages by running: sudo apt install" "${pkgs[@]}" || missing_any=1
    
    echo -e "\n--- Extra/Alternative ---" >&3
    check_packages "dpkg -s" "Install extra packages by running: sudo apt install" "${extra_pkgs[@]}" || missing_any=1
    echo "[INFO]   lxqt-polkit (optional) — large dependency set." >&3
    
    if [[ $missing_any -eq 0 ]]; then
        echo -e "\nSUCCESS: All expected packages are installed." >&3
    fi
}
gather_debian_info() {
    echo -e "\n=======================================" >&3
    echo -e "     Package Info (Debian/Ubuntu)" >&3
    echo -e "=======================================" >&3
    
    local source_bins=(
        "hyprpolkitagent"
    )
    
    local source_found=0
    if check_source_binaries "/usr/local/bin" "${source_bins[@]}"; then
        source_found=1
    fi
    
    # Essential packages required for polkit & related UI
    local pkgs=(
        "qml-module-qtqml"
        "qml-module-qtquick2"
        "qml-module-qtquick-controls"
        "qml-module-qtquick-controls2"
        "qml-module-qtquick-layouts"
        "qml6-module-qtqml"
        "qml6-module-qtquick"
        "qml6-module-qtquick-controls"
        "polkit"
    )
    
    local extra_pkgs=(
        "xfce4-polkit"
        "lxqt-policykit"
        "polkit-kde-agent-1"
        "mate-polkit"
    )
    
    local missing_any=0
    
    echo -e "\n--- Official Repositories ---" >&3
    if [[ $source_found -eq 0 ]]; then
        pkgs+=("hyprpolkitagent")
    else
        echo "[INFO]   hyprpolkitagent found in /usr/local/bin (source build). Skipping dpkg check for it." >&3
    fi
    check_packages "dpkg -s" "Install packages by running: sudo apt install" "${pkgs[@]}" || missing_any=1
    
    echo -e "\n--- Extra/Alternative ---" >&3
    check_packages "dpkg -s" "Install extra packages by running: sudo apt install" "${extra_pkgs[@]}" || missing_any=1
    
    if [[ $missing_any -eq 0 ]]; then
        echo -e "\nSUCCESS: All expected packages are installed." >&3
    fi
}

gather_fedora_info() {
    echo -e "\n=======================================" >&3
    echo -e "        Package Info (Fedora)" >&3
    echo -e "=======================================" >&3
    
    # Essential packages required for polkit & related UI
    local pkgs=(
        "qt5-qtdeclarative"
        "qt5-qtquickcontrols2"
        "qt6-qtdeclarative"
        "hyprpolkitagent"
        "polkit"
    )
    
    local extra_pkgs=(
        "xfce-polkit"
    )
    
    local missing_any=0
    
    echo -e "\n--- Official Repositories ---" >&3
    check_packages "rpm -q" "Install packages by running: sudo dnf install" "${pkgs[@]}" || missing_any=1
    
    echo -e "\n--- Extra/Alternative ---" >&3
    check_packages "rpm -q" "Install extra packages by running: sudo dnf install" "${extra_pkgs[@]}" || missing_any=1
    
    if [[ $missing_any -eq 0 ]]; then
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
    debian)
        gather_debian_info
        ;;
    ubuntu|pop|linuxmint)
        gather_ubuntu_info
        ;;
    fedora)
        gather_fedora_info
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
