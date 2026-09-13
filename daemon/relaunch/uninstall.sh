#!/bin/bash
# uninstall.sh - remove the telegramd watchdog from a device.
#
#   ./uninstall.sh [ssh-host]
#
# Leaves nothing behind except the two log files, which it also deletes.
# Nothing else on the device was ever modified: no system file is patched, no
# MobileSubstrate dylib is installed, and the app itself is untouched.

set -e

SSH_HOST="${1:-itgphone}"
SSH_OPTS="-o ConnectTimeout=8"

echo "[+] target: ${SSH_HOST}"
ssh ${SSH_OPTS} "${SSH_HOST}" '
	launchctl unload /Library/LaunchDaemons/com.kern0x1b.telegramd.plist 2>/dev/null
	rm -f /Library/LaunchDaemons/com.kern0x1b.telegramd.plist
	rm -f /usr/libexec/telegramd
	rm -f /etc/telegramd.conf
	rm -f /var/log/telegramd.log /var/log/telegramd.log.1
	rm -f /var/log/telegramd.out /var/log/telegramd.err
	launchctl list | grep telegramd && echo "[!] still listed - reboot to clear" || echo "[+] gone"
'
