#!/bin/sh -exu

if [ $# -lt 1 ]; then
    printf "Usage: %s <image_file> <more_qemu_options>\n" "$(basename "$0")"
    exit 1
fi
image=$1
shift

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
: "${QEMU_PORT:=8022}"

# Alternative bios (AAVMF on Ubuntu, homebrew on MacOS):
# -bios /usr/share/AAVMF/AAVMF_CODE.fd
# -bios /opt/homebrew/Cellar/qemu/11.0.1/share/qemu/edk2-aarch64-code.fd
# -bios u-boot.bin
# Alternative bios (FDE not tested yet):
# -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd
# See also https://jimmyg.org/blog/2024/macos-qemu/index.html
qemu-system-aarch64 -machine virt  -accel "$QEMU_ACCEL" -cpu "$QEMU_CPU" \
                        -smp "$QEMU_SMP" -m "$QEMU_MEM" \
                        -bios /opt/homebrew/Cellar/qemu/11.0.1/share/qemu/edk2-aarch64-code.fd \
                        -netdev user,id=net0,hostfwd=tcp::"$QEMU_PORT"-:22 \
                        -device virtio-net-pci,netdev=net0 \
                        -drive if=virtio,file="$image",format=raw \
                        -device virtio-gpu-pci \
                        -device virtio-keyboard \
                        -device virtio-mouse \
                        -serial stdio "$@"
exit 0

# It does not look like u-boot is able to load from LINUX_EFI_INITRD_MEDIA_GUID device path
# Not proper support for LoadFile2 protocol?

if [ "$arch" = armhf ]; then
    qemu-system-arm -machine virt -cpu cortex-a15 -smp 2 -m 2048 \
                    -bios u-boot-32.bin \
                    -netdev user,id=net0,hostfwd=tcp::8022-:22 \
                    -device virtio-net-pci,netdev=net0 \
                    -drive if=virtio,file="$image",format=raw \
                    -serial mon:stdio -semihosting
else
    qemu-system-aarch64 -machine virt -cpu cortex-a57 -smp 2 -m 4096 \
                        -bios u-boot.bin \
                        -netdev user,id=net0,hostfwd=tcp::8022-:22 \
                        -device virtio-net-pci,netdev=net0 \
                        -drive if=virtio,file="$image",format=raw \
                        -serial mon:stdio -semihosting
fi

cd -
