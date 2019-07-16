#!/bin/bash -e

if [ $# -lt 1 ]; then
    echo "Usage:" "$0" "<snap-name>"
    exit
fi

snap_name=$1
snap_info=$(curl -s -H 'Snap-Device-Series: 16' \
            https://api.snapcraft.io/v2/snaps/info/"$snap_name")
num_channel=$(echo "$snap_info" | jq -r '."channel-map" | length')

for ((i = 0; i < "$num_channel"; ++i)); do
    echo "$snap_info" | jq -r '."channel-map"['$i'] | .channel.name
                                           + "\t" + .channel.architecture
                                           + "\t" + .version
                                           + "\t" + (.revision | tostring)
                                           + "\t" + .channel."released-at"'
done
