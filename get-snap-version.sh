#!/bin/bash -e

if [ $# -lt 1 ]; then
    echo "Usage:" "$0" "<snap-name>"
    exit
fi

snap_name=$1
curl -s -H 'Snap-Device-Series: 16' \
            https://api.snapcraft.io/v2/snaps/info/"$snap_name" |
    jq -r '."channel-map"[] | .channel.name
                              + "\t" + .channel.architecture
                              + "\t" + .version
                              + "\t" + (.revision | tostring)
                              + "\t" + .channel."released-at"'
