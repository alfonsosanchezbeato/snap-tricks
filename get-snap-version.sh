#!/bin/sh
if [ $# -lt 2 ]
then
    echo "Usage:" $0 "<snap-name> <channel>"
    exit
fi

#for channel in edge beta candidate stable
for arch in amd64 arm64 i386 armhf
do
    for channel in $2
    do
        echo $arch in channel $channel
        curl -s -H "X-Ubuntu-Series: 16" -H "X-Ubuntu-Architecture: $arch" \
             https://search.apps.ubuntu.com/api/v1/snaps/details/$1?channel=$channel \
            | jq '.'
    done
done
