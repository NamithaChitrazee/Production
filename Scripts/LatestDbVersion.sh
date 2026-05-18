#!/bin/bash
# Gets the latest database version for the given purpose

set -eu

purpose="${1:-Sim_best}"


if ! command -v dbTool &>/dev/null; then
    echo "Error: dbTool not found in PATH" >&2
    exit 1
fi

if ! output=$(dbTool print-version --purpose "$purpose" 2>&1); then
    echo "Error: dbTool failed:" >&2
    echo "$output" >&2
    exit 1
fi

last_line=$(echo "$output" | tail -1)

vmaj=$(echo "$last_line" | awk '{print $5}')
vmin=$(echo "$last_line" | awk '{print $6}')


if [[ -z "$vmaj" || -z "$vmin" ]]; then
    echo "Error: failed to parse version from dbTool output" >&2
    echo "Got line: '$last_line'" >&2
    exit 1
fi

echo "v${vmaj}_${vmin}"
