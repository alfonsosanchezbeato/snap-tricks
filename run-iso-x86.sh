#!/bin/sh -exu

if [ $# -ne 2 ]; then
    printf "Usage: %s <iso> <disk_file>\n" "$(basename "$0")"
    exit 1
fi
image=$1
disk=$2

# The DGX OS arm64 ISO ships a 64 KB-page kernel. On Apple Silicon, HVF exposes
# the host CPU granule support and that kernel can fail in the EFI stub with
# start_image() returned 0x8000000000000003. TCG's max CPU advertises the needed
# CPU features, but is slower. For non-64k kernels, override with:
# QEMU_ACCEL=hvf QEMU_CPU=host ./run-iso-arm64.sh <iso> <disk_file>
: "${QEMU_ACCEL:=tcg,thread=multi}"
# QEMU_CPU: use max or cortex-a57 on x86
: "${QEMU_CPU:=max}"
: "${QEMU_SMP:=2}"
: "${QEMU_MEM:=4096}"
: "${DISK_SIZE:=50G}"

rm -f "$disk"
truncate -s "$DISK_SIZE" "$disk"

disk_driver=virtio-blk-pci
firmware=/usr/share/OVMF/OVMF_CODE.fd
if [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ]; then
    firmware=/usr/share/OVMF/OVMF_CODE_4M.fd
fi

# See also https://jimmyg.org/blog/2024/macos-qemu/index.html
qemu-system-x86_64 -enable-kvm \
                        -smp "$QEMU_SMP" -m "$QEMU_MEM" \
                        -bios "$firmware" \
                        -cdrom "$image" \
                        -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::31111-:31111,hostname=qemu \
                        -device virtio-net-pci,netdev=net0 \
                        -drive file="$disk",if=none,format=raw,id=disk1 \
                        -device "$disk_driver",drive=disk1 \
                        -serial mon:stdio "$@"
