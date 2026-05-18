#!/bin/bash
# creates fcl appending DbService database configuration
# Usage: ./Production/Scripts/addDatabase.sh <input fcl path> <output fcl path> [db purpose] [db version]

input_path=${1}
output_path=${2}

if [ -z "$input_path" ] || [ -z "$output_path" ]; then
    echo "Usage: $0 <input fcl path> <output fcl path> [db purpose] [db version]" >&2
    exit 1
fi

if [ ! -f "$input_path" ]; then
    echo "Error: input file not found: $input_path" >&2
    exit 1
fi

if [ -z "$3" ]; then
    purpose="Sim_best"
    echo "No purpose provided, using default: $purpose"
else
    purpose="$3"
fi
if [ -z "$4" ]; then
    if ! dbversion=$(LatestDbVersion.sh "$purpose"); then
        echo "Error: failed to get latest DB version for purpose '$purpose'" >&2
        exit 1
    fi
    echo "No version provided, using latest: $dbversion"
else
    dbversion="$4"
fi

cat "$input_path" > "$output_path"
cat >> "$output_path" <<EOF
services.DbService.purpose: $purpose
services.DbService.version: $dbversion
services.DbService.verbose: 2
EOF
