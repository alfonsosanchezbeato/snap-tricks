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
if [ ! -f OVMF_VARS.ms.fd ]; then
    printf "Please copy around UEFI vars file\n"
    exit 1
fi

sb_bios=/usr/share/OVMF/OVMF_CODE.secboot.fd

/usr/bin/qemu-system-x86_64 -enable-kvm -smp 2 -m 4096 \
	-machine q35 \
	-cpu host \
	-global ICH9-LPC.disable_s3=1 \
	-drive file=$sb_bios,if=pflash,format=raw,unit=0,readonly=on \
	-drive file=OVMF_VARS.ms.fd,if=pflash,format=raw,unit=1 \
	-netdev user,id=net0,hostfwd=tcp::8022-:22 \
	-device virtio-net-pci,netdev=net0 \
	-chardev socket,id=chrtpm,path=/var/snap/test-snapd-swtpm/current/swtpm-sock \
	-tpmdev emulator,id=tpm0,chardev=chrtpm \
	-device tpm-tis,tpmdev=tpm0 \
	-drive "file=$1",if=none,format=raw,id=disk1 \
	-device virtio-blk-pci,drive=disk1,bootindex=1 \
	-serial mon:stdio
