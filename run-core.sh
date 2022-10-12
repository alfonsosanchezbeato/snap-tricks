#!/bin/bash -ex

if [ $# -lt 1 ]; then
    printf "Usage: %s <image_file> <more_qemu_options>\n" "$(basename "$0")"
    exit 1
fi

img=$1
shift

/usr/bin/qemu-system-x86_64 -enable-kvm -smp 2 -m 4096 \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::31111-:31111 \
    -device virtio-net-pci,netdev=net0 \
    -drive if=virtio,file="$img",format=raw \
    -serial mon:stdio "$@"
