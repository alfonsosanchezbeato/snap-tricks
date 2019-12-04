#!/bin/bash -e

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
            # Convert timestamp to a readable date
            s=${t:0:${#t}-6}
            date_pr=$(date -d@"$s")
            ms=${t: -6}
            printf "%s %sms,%s\n" "$date_pr" "$ms" "${line#*,}"
            ;;
    esac
done
