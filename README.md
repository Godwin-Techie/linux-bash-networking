# Linux, Bash & Networking

A Bash-based Linux diagnostic toolkit. It displays system information, checks disk usage, and tests basic network connectivity. The scripts collect information from the machine at runtime.

## Requirements

- Linux with Bash
- Standard Linux utilities: `awk`, `date`, `df`, `getent`, `hostname`, and `uname`
- `ping` for the network connectivity test
- `ip` for detailed network interface information; the network script can fall back to `/sys/class/net`
- `nc` or `timeout` for the optional TCP port check

Some utilities may already be installed on your Linux distribution. No cloud account or deployment is required.

## Setup

From the repository root, make the scripts executable:

```bash
chmod +x grade.sh system-info.sh disk-check.sh network-check.sh
```

## Usage

Display system information:

```bash
./system-info.sh
```

Check disk usage. The threshold is required; the path is optional and defaults to `/`:

```bash
./disk-check.sh 80
./disk-check.sh 90 /var
```

Resolve and check a host, optionally checking a TCP port:

```bash
./network-check.sh localhost
./network-check.sh example.com 443
```

A host can resolve successfully without responding to ping. The network script reports the connectivity result separately. A failed ping or TCP check returns a non-zero status.

## Exit codes

- `0` - the operation succeeded; disk usage is below the threshold.
- `1` - an operational or connectivity failure occurred, or disk usage reached or exceeded its threshold.
- `2` - the supplied arguments are invalid.

## Logging

`disk-check.sh` and `network-check.sh` append timestamped operation descriptions to `logs/diagnostics.log`. The scripts create the log directory when needed. `logs/.gitkeep` preserves the directory in Git.

## Testing

Check Bash syntax:

```bash
bash -n system-info.sh disk-check.sh network-check.sh
```

Run the scripts:

```bash
./system-info.sh
./disk-check.sh 100 /
./network-check.sh localhost
```

Try invalid input and check the returned exit code:

```bash
./disk-check.sh 0
printf 'Exit code: %s\n' "$?"
```

Run the local grader:

```bash
./grade.sh
```

The grader checks project files, script syntax and permissions, system information output, invalid input handling, timestamped logs, and Git history.

## Git and submission

Keep this assignment in its own GitHub repository. The assignment requires at least five meaningful commits and a feature branch merged into `main` or `master`. The grader checks for a Git repository, at least five commits, and a merge commit.

Before submitting, clone your repository into a clean location and test it there. Do not commit passwords, tokens, private keys, or other secrets.
