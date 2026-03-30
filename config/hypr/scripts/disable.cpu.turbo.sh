#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    exec sudo -- "$0" "$@"
  fi
}

write_sysfs() {
  local path="$1"
  local value="$2"
  if [[ -w "$path" ]]; then
    printf '%s' "$value" >"$path"
    return 0
  fi
  return 1
}

require_root "$@"

changed=0

# Intel P-State turbo control
if [[ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
  if write_sysfs /sys/devices/system/cpu/intel_pstate/no_turbo 1; then
    changed=1
  fi
fi

# Generic cpufreq boost control (AMD/Intel)
if [[ -e /sys/devices/system/cpu/cpufreq/boost ]]; then
  if write_sysfs /sys/devices/system/cpu/cpufreq/boost 0; then
    changed=1
  fi
fi

# Prefer a quieter governor if available
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  if [[ -w "$gov" ]]; then
    current=$(cat "$gov")
    if [[ "$current" != "powersave" ]] && grep -q powersave "${gov%/*}/scaling_available_governors"; then
      printf '%s' powersave >"$gov"
      changed=1
    fi
  fi
done

# Lower energy/performance preference if supported
for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
  if [[ -w "$epp" ]]; then
    printf '%s' power >"$epp" 2>/dev/null || true
    changed=1
  fi
done

if [[ $changed -eq 1 ]]; then
  echo "CPU turbo/boost disabled and power-saving preferences applied."
  exit 0
fi

echo "No writable turbo/boost controls found. Check kernel driver support."
exit 1
