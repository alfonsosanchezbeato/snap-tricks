#!/bin/sh
if [ $# -lt 2 ]
then
    echo "Usage:" "$0" "<snap-name> <channel(s)>"
    exit
fi

# TODO: start using
# curl -s -H 'Snap-Device-Series: 16' https://api.snapcraft.io/v2/snaps/info/<snap_name>

snap_name=$1
shift
for arch in amd64 arm64 i386 armhf
do
    for channel in "$@"
    do
        echo "$arch" in channel "$channel"
        curl -s -H "X-Ubuntu-Series: 16" -H "X-Ubuntu-Architecture: $arch" \
             https://search.apps.ubuntu.com/api/v1/snaps/details/"$snap_name"?channel="$channel" \
            | jq '.' | grep "last_updated\|\"version\":\|revision"
    done
done
