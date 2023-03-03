#!/bin/sh -exu

arch=${1:-arm64}
image=${2:-server.img}

cd out-"$arch"-qemu-22

# Alternative bios:
# -bios /usr/share/AAVMF/AAVMF_CODE.fd
# Alternative bios (FDE not tested yet):
# -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd
qemu-system-aarch64 -machine virt -cpu cortex-a57 -smp 2 -m 4096 \
                        -bios u-boot.bin \
                        -netdev user,id=net0,hostfwd=tcp::8022-:22 \
                        -device virtio-net-pci,netdev=net0 \
                        -drive if=virtio,file="$image",format=raw \
                        -device virtio-gpu-pci \
                        -serial mon:stdio -semihosting
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
