#!/bin/bash -ex

# deps: nproc, kernel build deps, gcc-aarch64-linux-gnu, llvm, wget, apt, dpkg,
# dracut-install, lz4, sbsign
# ubuntu-core-initramfs deps

# Dowloads the ubuntu-core-initramfs deb package
# $1: temporal directory, must be absolute
# $2: dpkg architecture for the package
# $3: release
download_core_initrd()
{
    local tmp_d=$1
    local dpkg_arch=$2
    local release=$3
    local apt_d=$tmp_d/apt
    local sources_p=$apt_d/ppa.list
    local stage_d=$apt_d/stage
    local status_p=$stage_d/status
    mkdir -p "$stage_d"
    touch "$status_p"
    # TODO try [signed-by=...]
    cat > "$sources_p" <<EOF
deb https://ppa.launchpadcontent.net/snappy-dev/image/ubuntu $release main
EOF
    local apt_options=(
        "-o" "APT::Architecture=$dpkg_arch"
        "-o" "APT::Get::AllowUnauthenticated=true"
        "-o" "Acquire::AllowInsecureRepositories=true"
	"-o" "Dir::Etc=$apt_d"
	"-o" "Dir::Etc::sourcelist=$sources_p"
        "-o" "Dir::Cache=$stage_d/var/cache/apt"
        "-o" "Dir::State=$stage_d"
	"-o" "Dir::State::status=$status_p"
        "-o" "pkgCacheGen::Essential=none")
    apt update "${apt_options[@]}"
    apt download "${apt_options[@]}" ubuntu-core-initramfs
}

tmp_d=$(mktemp -d)

finish()
{
    rm -rf "$tmp_d"
}
trap finish EXIT

# Build branch is lf-5.15.y
config_f=imx_v8_defconfig
config_p=arch/arm64/configs/$config_f
kernel_d=linux-imx
install_d=$PWD/install
dpkg_arch=arm64
series=jammy

# Build kernel

cd $kernel_d
printf "%s\n" CONFIG_SECURITY_APPARMOR=y \
       CONFIG_STRICT_DEVMEM=y \
       CONFIG_DEFAULT_SECURITY_APPARMOR=y \
       CONFIG_CC_STACKPROTECTOR=y \
       CONFIG_CC_STACKPROTECTOR_STRONG=y \
       CONFIG_DEBUG_RODATA=y \
       CONFIG_DEBUG_SET_MODULE_RONX=y \
       CONFIG_ENCRYPTED_KEYS=y \
       CONFIG_DEVPTS_MULTIPLE_INSTANCES=y \
       CONFIG_AUTOFS4_FS=y \
       CONFIG_VIRTIO_BLK=y \
       CONFIG_SECURITY_SELINUX=n \
       CONFIG_INITRAMFS_COMPRESSION_LZ4=y \
       CONFIG_INITRAMFS_COMPRESSION_ZSTD=y \
       CONFIG_SYN_COOKIES=y \
       CONFIG_SQUASHFS_XATTR=y \
       CONFIG_SQUASHFS_XZ=y \
       CONFIG_BPF=y \
       CONFIG_ARCH_WANT_DEFAULT_BPF_JIT=y \
       CONFIG_BPF_SYSCALL=y \
       CONFIG_BPF_JIT=y \
       CONFIG_BPF_JIT_ALWAYS_ON=y \
       CONFIG_BPF_JIT_DEFAULT_ON=y \
       CONFIG_BPF_LSM=y \
       CONFIG_CGROUP_BPF=y \
       CONFIG_BPFILTER=y \
       CONFIG_BPF_STREAM_PARSER=y \
       CONFIG_LWTUNNEL_BPF=y \
       CONFIG_BPF_EVENTS=y \
       CONFIG_BPF_KPROBE_OVERRIDE=y \
       >> $config_p

make_vars=(ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)
make "${make_vars[@]}" $config_f
make "${make_vars[@]}" -j"$(nproc)" Image modules dtbs
rm -rf "$install_d"
mkdir -p "$install_d"
make "${make_vars[@]}" \
     CONFIG_PREFIX="$install_d" \
     INSTALL_PATH="$install_d" \
     INSTALL_MOD_PATH="$install_d" \
     INSTALL_DTBS_PATH="$install_d" \
     install modules_install dtbs_install
mv "$install_d"/lib/modules/ "$install_d"/
rmdir "$install_d"/lib
cd -

# firmware is the same package for all archs
apt download linux-firmware
dpkg -x linux-firmware_*_all.deb "$install_d"
mv "$install_d"/lib/firmware/ "$install_d"/
rmdir "$install_d"/lib

# Build initramfs

download_core_initrd "$tmp_d" "$dpkg_arch" "$series"
initrd_d=$tmp_d/initrd
dpkg -x ubuntu-core-initramfs_*.deb "$initrd_d"

kernelver=$(find "$install_d"/modules/* -maxdepth 0)
kernelver=$(basename "$kernelver")
ubuntu_core_initramfs="$initrd_d"/usr/bin/ubuntu-core-initramfs
"$ubuntu_core_initramfs" create-initrd \
                         --kernelver="$kernelver" \
                         --kerneldir "$install_d"/modules/"$kernelver" \
                         --firmwaredir "$install_d"/firmware \
                         --skeleton "$initrd_d"/usr/lib/ubuntu-core-initramfs \
                         --output initrd.img

# We need this inside the dir specified by --root
cp initrd.img* "$initrd_d"
cp "$install_d"/vmlinuz-"$kernelver" "$initrd_d"
stub_p=$(find "$initrd_d"/usr/lib/ubuntu-core-initramfs/efi/ \
              -maxdepth 1 -name 'linux*.efi.stub' -printf "%f\n")
"$ubuntu_core_initramfs" create-efi \
                         --kernelver="$kernelver" \
                         --root "$initrd_d" \
                         --stub usr/lib/ubuntu-core-initramfs/efi/"$stub_p" \
                         --initrd initrd.img \
                         --kernel vmlinuz \
                         --output kernel.efi

cp "$initrd_d"/kernel.efi-"$kernelver" "$install_d"/kernel.efi
rm "$install_d"/vmlinuz-"$kernelver"

mkdir -p "$install_d"/meta
cat <<EOF > "$install_d"/meta/snap.yaml
name: imx-kernel
version: 5.15.5
summary: imx linux kernel
description: The imx Ubuntu kernel package as a snap
architectures:
- arm64
confinement: strict
grade: stable
type: kernel
EOF

snap pack "$install_d"
