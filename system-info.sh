#!/usr/bin/env bash

# Display Linux system information collected at runtime.

# Read the operating system name from the standard Linux release file.
os_name="Linux"
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os_name=${PRETTY_NAME:-${NAME:-Linux}}
fi

# Read a CPU model from /proc; fall back to the machine architecture.
cpu_name=$(awk -F: '/^model name[[:space:]]*:/ {
    sub(/^[[:space:]]+/, "", $2)
    print $2
    exit
}' /proc/cpuinfo)

if [[ -z $cpu_name ]]; then
    cpu_name=$(uname -m)
fi

# Convert memory values from /proc/meminfo into a readable summary.
memory_summary=$(awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { available = $2 }
    END {
        if (total > 0) {
            printf "%.0f MiB used / %.0f MiB total", \
                (total - available) / 1024, total / 1024
        } else {
            print "Unavailable"
        }
    }
' /proc/meminfo)

# Prefer the friendly uptime format provided by the uptime command.
uptime_summary=$(uptime -p 2>/dev/null)
if [[ -z $uptime_summary ]]; then
    uptime_summary="Unavailable"
fi

# Print each value with a clear label.
printf 'Hostname: %s\n' "$(hostname)"
printf 'Current user: %s\n' "$(id -un)"
printf 'Date and time: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'Operating system: %s\n' "$os_name"
printf 'Kernel version: %s\n' "$(uname -r)"
printf 'Uptime: %s\n' "$uptime_summary"
printf 'CPU: %s\n' "$cpu_name"
printf 'Memory: %s\n' "$memory_summary"
printf 'Current working directory: %s\n' "$(pwd)"
