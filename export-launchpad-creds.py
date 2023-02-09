#!/usr/bin/python3
# This script exports launchpad credentials to a file, unencrypted.

import sys
from launchpadlib.launchpad import Launchpad

def no_credential():
    print("Can't proceed without Launchpad credential.")
    sys.exit()


launchpad = Launchpad.login_with(
    'launchpad-trigger', 'production', version='devel',
    credentials_file='lpcreds',
    credential_save_failed=no_credential)
