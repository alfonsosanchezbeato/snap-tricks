#!/bin/bash -ex

# Example usage:
# seed_initial_config xx/system-data/ user.assertion

seed_initial_config()
{
    system_data=$1
    user_assertion=$2

    # Migrate all systemd units from core snap into the writable area. This
    # would be normally done on firstboot by the initramfs but we can't rely
    # on that because we  are adding another file in there and that will
    # prevent the initramfs from transitioning any files.
    core_snap=$(find "$system_data"/var/lib/snapd/snaps -name "core_*.snap")
    tmp_core=$(mktemp -d)
    sudo mount "$core_snap" "$tmp_core"
    mkdir -p "$system_data"/etc/systemd
    cp -rav "$tmp_core"/etc/systemd/* \
       "$system_data"/etc/systemd/
    sudo umount "$tmp_core"
    rm -rf "$tmp_core"

    # system-user assertion which gives us our test:test user we use to
    # log into the system
    # NOTE Password field must be generated with
    # python3 -c 'import crypt; print(crypt.crypt("test", crypt.mksalt(crypt.METHOD_SHA512)))'
    # Password 1nd0reTest: $6$9Rj8XHZCQ4sxkKf7$p7aG7Jkd8WB1M5DcExdKwGdSFwX35kfksjhU2fSq/UeR7kWEySQgJLYFcZ/j10RAsSplAfggXgRJ39L9fzTdT.
    mkdir -p "$system_data"/var/lib/snapd/seed/assertions
    cp "$user_assertion" "$system_data"/var/lib/snapd/seed/assertions

    # Disable console-conf for the first boot
    mkdir -p "$system_data"/var/lib/console-conf/
    touch "$system_data"/var/lib/console-conf/complete

    # Create systemd service which is running on firstboot and sets up
    # various things for us.
    mkdir -p "$system_data"/etc/systemd/system || true
    cat << 'EOF' > "$system_data"/etc/systemd/system/devmode-firstboot.service
[Unit]
Description=Run devmode firstboot setup
After=snapd.service snapd.socket

[Service]
Type=oneshot
ExecStart=/writable/system-data/var/lib/devmode-firstboot/run.sh
RemainAfterExit=yes
TimeoutSec=3min
EOF

    mkdir -p "$system_data"/etc/systemd/system/multi-user.target.wants || true
    ln -sf /etc/systemd/system/devmode-firstboot.service \
       "$system_data"/etc/systemd/system/multi-user.target.wants/devmode-firstboot.service

    mkdir "$system_data"/var/lib/devmode-firstboot || true
    cat << 'EOF' > "$system_data"/var/lib/devmode-firstboot/00-snapd-config.yaml
network:
  version: 2
  ethernets:
    id0:
      match:
        name: en*
      dhcp4: true
    id1:
      match:
        name: eth*
      dhcp4: true
EOF

    cat << 'EOF' > "$system_data"/var/lib/devmode-firstboot/run.sh
#!/bin/sh

set -ex

# Don't start again if we're already done
if [ -e /writable/system-data/var/lib/devmode-firstboot/complete ] ; then
	exit 0
fi

echo "$(date -Iseconds --utc) Start devmode-firstboot"	| tee /dev/kmsg /dev/console

if [ "$(snap managed)" = "true" ]; then
	echo "System already managed, exiting"
	exit 0
fi

# no changes at all
until snap changes ; do
	echo "No changes yet, waiting"
	sleep 1
done

while snap changes | grep -qE '(Do|Doing) .*Initialize system state' ;	do
	echo "Initialize system state is in progress, waiting"
	sleep 1
done

# If we have the assertion, create the user
if [ -n "$(snap known system-user)" ]; then
	echo "Trying to create known user"
	snap create-user --known --sudoer
fi

echo "$(date -Iseconds --utc) devmode-firstboot: system user created" \
	| tee /dev/kmsg /dev/console

cp /writable/system-data/var/lib/devmode-firstboot/00-snapd-config.yaml \
	/writable/system-data/etc/netplan

# Apply network configuration
netplan generate
systemctl restart systemd-networkd.service

echo "$(date -Iseconds --utc) devmode-firstboot: network configuration applied" \
	| tee /dev/kmsg /dev/console

# Mark us done
touch /writable/system-data/var/lib/devmode-firstboot/complete
EOF

    chmod +x "$system_data"/var/lib/devmode-firstboot/run.sh
}

kpartx -asv vesta-300b-image.img
mkdir -p xx
mount /dev/dm-1 xx
seed_initial_config xx/system-data user.assertion
chown -R root:root xx/system-data
umount xx
kpartx -d vesta-300b-image.img
