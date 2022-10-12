#!/bin/bash -eu

set -o pipefail

if [ $# -ne 1 ]; then
    printf "Usage: %s <image_file[.xz,gz]>\n" "$0"
    exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
    printf "Please run as root\n"
    exit 1
fi
image_p=$1

# Consider only removable devices
num_usb_drives=0
while read -r line; do
    if [ "$(cat "$line")" != 1 ]
    then continue
    fi
    # Check that size > 0 to avoid considering some special devices
    line=${line%/removable}
    if [ "$(cat "$line/size")" -eq 0 ]
    then continue
    fi
    num_usb_drives=$((num_usb_drives + 1))
    disk=/dev/${line##*/}
done < <(find /sys/devices/ -path '*/block/*/removable' | grep -v virtual)

if [ $num_usb_drives -lt 1 ]; then
    printf "ERROR: No USB drives to flash the image to\n"
    exit 1
fi
if [ $num_usb_drives -gt 1 ]; then
    printf "ERROR: More that one USB drive present in the system\n"
    exit 1
fi

while read -r line; do
    if [ "$(readlink -e "$line")" = "$disk" ]; then
        desc=${line##*/}
        break
    fi
done < <(find /dev/disk/by-id/ -type l)

read -r -p "Proceed to writing image to $desc ($disk) [y/N]? " line
if [[ ! $line =~ ^[Yy]$ ]]; then
    exit 1
fi

while read -r part; do
    umount "$part"
done < <(grep "^$disk" /proc/mounts | cut -d' ' -f1)

case "$(file --brief --mime-type "$image_p")" in
    "application/x-lzma")
        cat_cmd="lzcat" ;;
    "application/x-lz4")
        cat_cmd="lz4cat" ;;
    "application/x-xz")
        cat_cmd="xzcat" ;;
    "application/gzip")
        cat_cmd="zcat" ;;
    "application/zstd")
        cat_cmd="zstdcat" ;;
    *)
        cat_cmd="cat" ;;
esac

sync
printf "Writing to %s...\n" "$disk"
$cat_cmd "$image_p" > "$disk"
sync
