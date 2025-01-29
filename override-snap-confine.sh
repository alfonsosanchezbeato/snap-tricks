#!/bin/bash -ex

REMOTE_USER=ubuntu
TEST_SNAP=test-mountns
NEW_BINARY=snap-confine-debug
TARGET_BIN=/snap/snapd/current/usr/lib/snapd/snap-confine
SSH="ssh -p 8022 $REMOTE_USER@localhost"

ssh-keygen -f ~/.ssh/known_hosts -R "[localhost]:8022"

$SSH sudo umount $TARGET_BIN || true
$SSH sudo rm -f $NEW_BINARY
scp -P 8022 ~/go/src/github.com/snapcore/snapd/cmd/snap-confine/$NEW_BINARY $REMOTE_USER@localhost:

$SSH sudo chown root:root $NEW_BINARY
$SSH sudo chmod 4755 $NEW_BINARY
$SSH sudo mount --bind $NEW_BINARY $TARGET_BIN
# TODO check version
#$SSH sudo apparmor_parser -R /var/lib/snapd/apparmor/profiles/snap-confine.snapd.x2 || true

$SSH sudo /usr/lib/snapd/snap-discard-ns $TEST_SNAP

# Run on terminal
# SNAP_CONFINE_DEBUG=1 test-mountns
