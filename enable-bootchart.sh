#!/bin/bash -ex

# Example usage:
# enable_bootchart xx/system-data/

enable_bootchart()
{
    system_data=$1

    # Create systemd service which is running on firstboot and sets up
    # various things for us.
    mkdir -p "$system_data"/etc/systemd/system/systemd-bootchart.service.d/
    cat << 'EOF' > "$system_data"/etc/systemd/system/systemd-bootchart.service.d/override.conf
[Service]
ExecStart=
ExecStart=/lib/systemd/systemd-bootchart -r -C --no-filter --sample 16500 -o /writable/system-data/etc/
EOF

    mkdir -p "$system_data"/etc/systemd/system/sysinit.target.wants/
    ln -sf /lib/systemd/system/systemd-bootchart.service \
       "$system_data"/etc/systemd/system/sysinit.target.wants/systemd-bootchart.service
}

kpartx -asv vesta-300b-image.img
mkdir -p xx
mount /dev/dm-1 xx

enable_bootchart xx/system-data

chown -R root:root xx/system-data
umount xx
kpartx -d vesta-300b-image.img
