#!/bin/sh -ex

# Root, but just due to permissions of swtpm-sock... I think
if [ "$(id -u)" -ne 0 ]; then
    printf "Please run as root\n"
    exit 1
fi
if [ $# -ne 1 ]; then
    printf "Usage: %s <image_file>\n" "$(basename "$0")"
    exit 1
fi
if [ ! -f AAVMF_VARS.ms.fd ]; then
    printf "Please copy around UEFI vars file\n"
fi

sb_bios=/usr/share/AAVMF/AAVMF_CODE.fd
tpm_sock=/var/snap/test-snapd-swtpm/current/swtpm-sock

# Re: random numbers, see https://bugzilla.redhat.com/show_bug.cgi?id=1579518

qemu-system-aarch64 -machine virt -cpu cortex-a57 -smp 2 -m 4096 \
 	-drive file=$sb_bios,if=pflash,format=raw,unit=0,readonly=on \
 	-drive file=AAVMF_VARS.ms.fd,if=pflash,format=raw,unit=1 \
        -netdev user,id=net0,hostfwd=tcp::8022-:22 \
        -device virtio-net-pci,netdev=net0 \
 	-drive "file=$1",if=none,format=raw,id=disk1 \
 	-device virtio-blk-pci,drive=disk1,bootindex=1 \
        -chardev socket,id=chrtpm,path=$tpm_sock \
	-tpmdev emulator,id=tpm0,chardev=chrtpm \
	-device tpm-tis-device,tpmdev=tpm0 \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-pci,rng=rng0,id=rng-device0 \
        -device virtio-gpu-pci \
        -serial mon:stdio -semihosting
