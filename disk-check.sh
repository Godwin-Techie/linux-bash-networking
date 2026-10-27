#!/usr/bin/env bash

# Store logs beside this script, regardless of the directory it is run from.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/diagnostics.log"

# Create the log directory if this is the first run.
if ! mkdir -p -- "$LOG_DIR"; then
    printf 'Error: cannot create log directory: %s\n' "$LOG_DIR" >&2
    exit 1
fi

# Append a timestamped description of an operation to the shared log.
log_operation() {
    local description=$1
    local timestamp

    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z') || return 1
    printf '%s %s\n' "$timestamp" "$description" >> "$LOG_FILE"
}

# Report invalid arguments and use exit code 2 as required.
reject_input() {
    printf 'Error: %s\n' "$1" >&2

    if ! log_operation "Rejected disk check: $1"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
        exit 1
    fi

    exit 2
}

# Require a threshold and allow at most one optional path.
if (( $# < 1 || $# > 2 )); then
    reject_input "usage: ./disk-check.sh <threshold 1-100> [path]"
fi

threshold=$1
path=${2:-/}

# Reject non-numeric input before using the value in arithmetic.
if [[ ! $threshold =~ ^[0-9]+$ ]]; then
    reject_input "threshold must be an integer from 1 to 100"
fi

# Remove leading zeroes so values like 080 are treated as decimal 80.
while [[ ${#threshold} -gt 1 && ${threshold:0:1} == 0 ]]; do
    threshold=${threshold#0}
done

# Limit the value's length before arithmetic, preventing overflow.
if (( ${#threshold} > 3 )); then
    reject_input "threshold must be an integer from 1 to 100"
fi

threshold_value=$((10#$threshold))
if (( threshold_value < 1 || threshold_value > 100 )); then
    reject_input "threshold must be an integer from 1 to 100"
fi

# -P requests predictable output, and -- protects paths beginning with '-'.
if ! df_output=$(df -P -- "$path" 2>&1); then
    printf 'Error: could not read disk usage for path: %s\n' "$path" >&2
    printf '%s\n' "$df_output" >&2

    if ! log_operation "Disk check failed because disk usage could not be read"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
    fi

    exit 1
fi

# In df's final output row, the fifth column is the percentage used.
usage=$(awk 'END {
    if (NR >= 2) {
        gsub(/%/, "", $5)
        print $5
    }
}' <<< "$df_output")

if [[ ! $usage =~ ^[0-9]+$ ]]; then
    printf 'Error: could not parse disk usage for path: %s\n' "$path" >&2
    exit 1
fi

printf 'Disk usage for %s: %s%%\n' "$path" "$usage"
printf 'Threshold: %s%%\n' "$threshold_value"

if (( usage >= threshold_value )); then
    if ! log_operation "Disk usage reached or exceeded the threshold"; then
        printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
        exit 1
    fi

    printf 'Warning: disk usage has reached or exceeded the threshold.\n' >&2
    exit 1
fi

if ! log_operation "Disk usage is below the threshold"; then
    printf 'Error: could not write to log file: %s\n' "$LOG_FILE" >&2
    exit 1
fi
