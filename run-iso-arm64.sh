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

# See also https://jimmyg.org/blog/2024/macos-qemu/index.html
qemu-system-aarch64 -machine virt -accel "$QEMU_ACCEL" -cpu "$QEMU_CPU" \
                        -smp "$QEMU_SMP" -m "$QEMU_MEM" \
                        -bios /opt/homebrew/Cellar/qemu/11.0.1/share/qemu/edk2-aarch64-code.fd \
                        -cdrom "$image" \
                        -netdev user,id=net0,hostfwd=tcp::8022-:22 \
                        -device virtio-net-pci,netdev=net0 \
                        -drive if=virtio,file="$disk",format=raw \
                        -device virtio-gpu-pci \
                        -device virtio-keyboard \
                        -device virtio-mouse \
                        -serial stdio
