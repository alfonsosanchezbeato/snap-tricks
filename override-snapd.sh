#!/bin/bash -ex

# Example usage:
# enable_bootchart xx/system-data/

override_snapd()
{
    system_data=$1

    cp "$2" "$system_data"/

    # Create systemd service which is running on firstboot and sets up
    # various things for us.
    mkdir -p "$system_data"/etc/systemd/system/snapd.service.d/
    cat << 'EOF' > "$system_data"/etc/systemd/system/snapd.service.d/override.conf
[Service]
ExecStart=
ExecStart=/bin/sh -c 'mount --bind /writable/system-data/snapd /usr/lib/snapd/snapd; exec /usr/lib/snapd/snapd'
EOF

}

kpartx -asv vesta-300b-image.img
mkdir -p xx
mount /dev/dm-1 xx

override_snapd xx/system-data /home/abeato/go/src/github.com/snapcore/snapd/snapd

chown -R root:root xx/system-data
umount xx
kpartx -d vesta-300b-image.img
