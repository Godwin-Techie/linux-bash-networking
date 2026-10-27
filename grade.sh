#!/usr/bin/env bash

# Stop if a command in a pipeline fails.
set -o pipefail

# Resolve the project directory so checks work from any current directory.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

# Check the files required by the assignment.
required_files=(
    README.md
    system-info.sh
    disk-check.sh
    network-check.sh
    grade.sh
    logs/.gitkeep
)

for file in "${required_files[@]}"; do
    if [[ -f $SCRIPT_DIR/$file ]]; then
        pass "required file exists: $file"
    else
        fail "missing required file: $file"
    fi
done

# Check each script's Bash syntax and executable permission.
for script in system-info.sh disk-check.sh network-check.sh grade.sh; do
    if bash -n "$SCRIPT_DIR/$script"; then
        pass "Bash syntax: $script"
    else
        fail "Bash syntax: $script"
    fi

    if [[ -x $SCRIPT_DIR/$script ]]; then
        pass "executable permission: $script"
    else
        fail "not executable: $script"
    fi
done

# Run the system script and confirm that it prints the required information.
if system_output=$("$SCRIPT_DIR/system-info.sh" 2>&1); then
    for label in \
        "Hostname:" \
        "Current user:" \
        "Date and time:" \
        "Operating system:" \
        "Kernel version:" \
        "Uptime:" \
        "CPU:" \
        "Memory:" \
        "Current working directory:"
    do
        if grep -Fq "$label" <<< "$system_output"; then
            pass "system information includes $label"
        else
            fail "system information is missing $label"
        fi
    done
else
    fail "system-info.sh did not run successfully"
fi

# An invalid disk threshold must return exit code 2.
disk_status=0
"$SCRIPT_DIR/disk-check.sh" 0 >/dev/null 2>&1 || disk_status=$?

if (( disk_status == 2 )); then
    pass "disk-check rejects an invalid threshold with exit code 2"
else
    fail "disk-check returned $disk_status for an invalid threshold; expected 2"
fi

# An invalid hostname must be rejected with a non-zero status.
network_status=0
"$SCRIPT_DIR/network-check.sh" 'invalid host' >/dev/null 2>&1 || network_status=$?

if (( network_status != 0 )); then
    pass "network-check rejects an invalid hostname"
else
    fail "network-check accepted an invalid hostname"
fi

# Confirm that the scripts created timestamped log entries.
log_file="$SCRIPT_DIR/logs/diagnostics.log"
if [[ -s $log_file ]] &&
    grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4} ' "$log_file"
then
    pass "logs contain timestamped operation descriptions"
else
    fail "logs/diagnostics.log is missing or has no timestamped entries"
fi

# Check the minimum commit count and confirm there is a merge commit.
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    commit_count=$(git -C "$SCRIPT_DIR" rev-list --count HEAD 2>/dev/null || printf '0')

    if [[ $commit_count =~ ^[0-9]+$ ]] && (( commit_count >= 5 )); then
        pass "Git history contains at least five commits"
    else
        fail "Git history needs at least five commits; found ${commit_count:-0}"
    fi

    if git -C "$SCRIPT_DIR" log --merges -n 1 --format=%H HEAD 2>/dev/null | grep -q .; then
        pass "Git history contains a merge commit"
    else
        fail "Git history needs a merge commit from a feature branch"
    fi
else
    fail "project directory is not a Git repository"
fi

# Return failure if any check failed; otherwise report success.
if (( failures > 0 )); then
    printf '\nGrading checks found %d issue(s).\n' "$failures" >&2
    exit 1
fi

printf '\nAll grading checks passed.\n'
