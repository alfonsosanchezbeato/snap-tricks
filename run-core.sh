#!/bin/bash -ex

if [ $# -lt 1 ]; then
    printf "Usage: %s <image_file> <more_qemu_options>\n" "$(basename "$0")"
    exit 1
fi

img=$1
shift

# For older UC: driver cannot be virtio-blk-pci as kernels did not include
# that kernel module in the initramfs. Alternative: use "driver=ide-hd".
disk_driver=virtio-blk-pci
if sfdisk -d "$img" | grep 'name="writable"'
then disk_driver=ide-hd
fi

format=$(qemu-img info --output=json "$img" | jq -r .format)

/usr/bin/qemu-system-x86_64 -enable-kvm -smp 2 -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::31111-:31111 \
    -device virtio-net-pci,netdev=net0 \
    -drive file="$img",if=none,format="$format",id=disk1 \
    -device "$disk_driver",drive=disk1,bootindex=1 \
    -serial mon:stdio "$@"
