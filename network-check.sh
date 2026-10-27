#!/usr/bin/env bash

# Store logs beside this script so its location does not depend on
# the directory from which the user runs it.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/diagnostics.log"

# Create the shared log directory if it does not exist yet.
if ! mkdir -p -- "$LOG_DIR"; then
    printf 'Error: cannot create log directory: %s\n' "$LOG_DIR" >&2
    exit 1
fi

# Append a timestamped description of an operation to the log.
log_operation() {
    local description=$1
    local timestamp

    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z') || return 1
    printf '%s %s\n' "$timestamp" "$description" >> "$LOG_FILE"
}

# Invalid arguments normally return 2. If logging itself fails, report
# that operational failure and return 1 instead.
reject_input() {
    printf 'Error: %s\n' "$1" >&2

    if ! log_operation "Rejected network check: $1"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
        exit 1
    fi

    exit 2
}

# Require a host and permit only one optional port argument.
if (( $# < 1 || $# > 2 )); then
    reject_input "usage: ./network-check.sh <hostname-or-ip> [port]"
fi

host=$1

# Reject empty or excessively long host values before resolution.
if [[ -z $host || ${#host} -gt 253 ]]; then
    reject_input "host must be a non-empty hostname or IP address"
fi

# Validate IPv6 characters, or validate each DNS/IPv4-style label.
if [[ $host == *:* ]]; then
    if [[ ! $host =~ ^[A-Fa-f0-9:.]+$ ]]; then
        reject_input "host contains invalid IPv6 characters"
    fi
else
    if [[ ! $host =~ ^[A-Za-z0-9.-]+$ ]]; then
        reject_input "host contains invalid hostname characters"
    fi

    IFS='.' read -r -a labels <<< "$host"
    for label in "${labels[@]}"; do
        if [[ -z $label || ${#label} -gt 63 ||
              ! $label =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
            reject_input "host contains an invalid hostname label"
        fi
    done
fi

port=""
if (( $# == 2 )); then
    port=$2

    # Check the port's format before using it as a number.
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        reject_input "port must be an integer from 1 to 65535"
    fi

    # Strip leading zeroes, then bound the length to avoid arithmetic overflow.
    while [[ ${#port} -gt 1 && ${port:0:1} == 0 ]]; do
        port=${port#0}
    done

    if (( ${#port} > 5 )); then
        reject_input "port must be an integer from 1 to 65535"
    fi

    port_value=$((10#$port))
    if (( port_value < 1 || port_value > 65535 )); then
        reject_input "port must be an integer from 1 to 65535"
    fi
fi

# Resolve the host first so users can see which address was found.
if ! resolved_addresses=$(getent ahosts "$host" 2>/dev/null); then
    printf 'Error: could not resolve host: %s\n' "$host" >&2

    if ! log_operation "Could not resolve the supplied host"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
        exit 1
    fi

    exit 1
fi

resolved_address=$(awk 'NR == 1 { print $1; exit }' <<< "$resolved_addresses")
if [[ -z $resolved_address ]]; then
    printf 'Error: no address found for host: %s\n' "$host" >&2
    exit 1
fi

printf 'Host: %s\n' "$host"
printf 'Resolved address: %s\n' "$resolved_address"

# Track connectivity failures so the script can report all requested checks.
check_failed=0

if command -v ping >/dev/null 2>&1; then
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        printf 'Connectivity: reachable (ping succeeded)\n'
    else
        printf 'Connectivity: ping did not succeed\n' >&2
        check_failed=1
    fi
else
    printf 'Error: ping is not installed; cannot perform the connectivity check.\n' >&2
    check_failed=1
fi

# Show interface addresses when `ip` is available. The sysfs fallback
# still provides interface names and link state on minimal Linux systems.
printf 'Network interfaces:\n'
if command -v ip >/dev/null 2>&1; then
    if ! ip -brief address; then
        printf 'Error: could not read network interface information.\n' >&2
        check_failed=1
    fi
else
    found_interface=0

    for interface_path in /sys/class/net/*; do
        [[ -e $interface_path ]] || continue
        found_interface=1

        interface_name=${interface_path##*/}
        interface_state="unknown"
        if [[ -r $interface_path/operstate ]]; then
            read -r interface_state < "$interface_path/operstate" ||
                interface_state="unknown"
        fi

        printf '%s: %s\n' "$interface_name" "$interface_state"
    done

    if (( found_interface == 0 )); then
        printf 'Error: no network interface information is available.\n' >&2
        check_failed=1
    fi
fi

if [[ -n $port ]]; then
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$host" "$port_value" >/dev/null 2>&1; then
            printf 'TCP port %s: open\n' "$port_value"
        else
            printf 'TCP port %s: not reachable\n' "$port_value" >&2
            check_failed=1
        fi
    elif command -v timeout >/dev/null 2>&1; then
        # Bash provides /dev/tcp when built with network redirection support.
        if timeout 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ \
            "$host" "$port_value" 2>/dev/null; then
            printf 'TCP port %s: open\n' "$port_value"
        else
            printf 'TCP port %s: not reachable\n' "$port_value" >&2
            check_failed=1
        fi
    else
        printf 'Error: install netcat (nc) or timeout for TCP port checks.\n' >&2
        check_failed=1
    fi
fi

if (( check_failed != 0 )); then
    if ! log_operation "Network check reported a connectivity failure"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
        exit 1
    fi
    exit 1
fi

if ! log_operation "Network check succeeded"; then
    printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
    exit 1
fi
