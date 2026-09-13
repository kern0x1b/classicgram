#!/bin/bash
# install.sh - copy the telegramd watchdog onto a jailbroken device and load it.
#
#   ./install.sh [ssh-host]
#
# `ssh-host` defaults to `itgphone`, the same alias scripts/deploy-and-watch.sh uses; put
# the port, user, key and the legacy ssh-rsa algorithms in ~/.ssh/config.
#
# Installs exactly three files:
#   /usr/libexec/telegramd
#   /etc/telegramd.conf
#   /Library/LaunchDaemons/com.kern0x1b.telegramd.plist
#
# uninstall.sh removes all three and unloads the job.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/out"
SSH_HOST="${1:-itgphone}"
SSH_OPTS="-o ConnectTimeout=8"

[ -x "${OUT_DIR}/telegramd" ] || { echo "[-] run ./build.sh first"; exit 1; }

echo "[+] target: ${SSH_HOST}"
ssh ${SSH_OPTS} "${SSH_HOST}" true || { echo "[-] cannot reach ${SSH_HOST}"; exit 1; }

echo "[+] copying"
scp ${SSH_OPTS} "${OUT_DIR}/telegramd"                "${SSH_HOST}:/usr/libexec/telegramd"
scp ${SSH_OPTS} "${SCRIPT_DIR}/telegramd.conf"        "${SSH_HOST}:/etc/telegramd.conf"
scp ${SSH_OPTS} "${SCRIPT_DIR}/com.kern0x1b.telegramd.plist" \
	"${SSH_HOST}:/Library/LaunchDaemons/com.kern0x1b.telegramd.plist"

echo "[+] loading"
ssh ${SSH_OPTS} "${SSH_HOST}" '
	chown root:wheel /usr/libexec/telegramd /Library/LaunchDaemons/com.kern0x1b.telegramd.plist
	chmod 755 /usr/libexec/telegramd
	chmod 644 /Library/LaunchDaemons/com.kern0x1b.telegramd.plist /etc/telegramd.conf
	launchctl unload /Library/LaunchDaemons/com.kern0x1b.telegramd.plist 2>/dev/null
	launchctl load  /Library/LaunchDaemons/com.kern0x1b.telegramd.plist
	sleep 2
	launchctl list | grep telegramd || echo "(not listed)"
'

echo ""
echo "[+] done. Watch it with:"
echo "      ssh ${SSH_HOST} tail -f /var/log/telegramd.log"
