#!/bin/bash -e
# Converts a systemd journal in json format to something readable.
# Depends on jq being present on the system.

if [ $# -lt 1 ]; then
    printf "Usage: %s <journal_json_file>\n" "$0"
    exit 1
fi

jq -r '"\(.__REALTIME_TIMESTAMP), \(._SYSTEMD_UNIT), \(.MESSAGE)"' "$1" |
while read -r line; do
    t=${line%%,*}
    case $t in
        ''|*[!0-9]*)
            # Not a number
            printf "%s\n" "$line"
            ;;
        *)
            if [ ${#t} -gt 6 ]; then
                # Convert timestamp in microseconds to a readable date
                s=${t:0:${#t}-6}
                date_pr=$(date -d@"$s")
                us=${t: -6}
                printf "%s %sus,%s\n" "$date_pr" "$us" "${line#*,}"
            else
                printf "%s\n" "$line"
            fi
            ;;
    esac
done
