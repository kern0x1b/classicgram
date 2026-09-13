#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="${TG_BUNDLE_ID:-com.kern0x1b.telegram}"
BUNDLE="$ROOT/.theos/_/Applications/Telegram.app"
LOGDIR="$ROOT/build/devlogs"
STAMP="$(date +%Y%m%d-%H%M%S)"

SECONDS_TO_LOG=60
FILTER="Telegram"
DO_BUILD=1
CHECK_ONLY=0
SHOT_ONLY=0

SSH_PORT="${TG_SSH_PORT:-2222}"
SSH_HOST="${TG_SSH_HOST:-itgphone}"
SSH_OPTS="-o ConnectTimeout=6 -o BatchMode=yes"

while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) DO_BUILD=0; shift ;;
		--seconds)  SECONDS_TO_LOG="$2"; shift 2 ;;
		--filter)   FILTER="$2"; shift 2 ;;
		--check)    CHECK_ONLY=1; shift ;;
		--shot)     SHOT_ONLY=1; shift ;;
		*) echo "unknown option: $1"; exit 2 ;;
	esac
done

mkdir -p "$LOGDIR"
say() { printf '\n=== %s\n' "$*"; }

wait_for_device() {
	local tries=0
	while [ $tries -lt 30 ]; do
		if idevice_id -l 2>/dev/null | grep -q .; then
			say "device: $(ideviceinfo -k DeviceName 2>/dev/null) / iOS $(ideviceinfo -k ProductVersion 2>/dev/null)"
			return 0
		fi
		tries=$((tries + 1))
		sleep 2
	done
	echo "NO DEVICE after 60s. Plug the iPhone in, unlock it, and trust this Mac." >&2
	return 1
}

build() {
	say "building armv7"
	if ! make -C "$ROOT" FINALPACKAGE=1 stage > "$LOGDIR/build-$STAMP.log" 2>&1; then
		echo "BUILD FAILED - see $LOGDIR/build-$STAMP.log" >&2
		grep -iE "error:|fixup error|Undefined symbols" "$LOGDIR/build-$STAMP.log" | head -20 >&2
		return 1
	fi
	if ! grep -q "machofix: Thumb bit restored" "$LOGDIR/build-$STAMP.log"; then
		echo "WARNING: machofix did not report restoring Thumb bits." >&2
		echo "The armv7 linker drops them; without the fixup the app dies at launch." >&2
	fi
	grep "machofix:" "$LOGDIR/build-$STAMP.log"
	return 0
}

install_ipa() {
	say "installing"
	[ -d "$BUNDLE" ] || { echo "no app bundle at $BUNDLE" >&2; return 1; }
	ssh ${SSH_OPTS} -p "$SSH_PORT" "root@$SSH_HOST" "killall -TERM Telegram 2>/dev/null; true"
	scp ${SSH_OPTS} -P "$SSH_PORT" "$BUNDLE/Telegram" "root@$SSH_HOST:/Applications/Telegram.app/Telegram"
}

ddi_mounted() { ideviceimagemounter -l 2>/dev/null | grep -qi "ImagePresent: true\|ImageSignature"; }

try_mount_ddi() {
	local d
	for d in "$HOME/DeviceSupport/7.1" "$HOME/DeviceSupport/7.1.2" \
	         /Applications/Xcode*.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/7.1; do
		if [ -f "$d/DeveloperDiskImage.dmg" ]; then
			say "mounting Developer Disk Image from $d"
			ideviceimagemounter "$d/DeveloperDiskImage.dmg" "$d/DeveloperDiskImage.dmg.signature" 2>&1 | tail -2
			return 0
		fi
	done
	return 1
}

launch_via_debugserver() {
	ddi_mounted || try_mount_ddi || return 1
	say "launching via idevicedebug"
	idevicedebug -d run "$BUNDLE_ID" > "$LOGDIR/stdout-$STAMP.log" 2>&1 &
	echo $! > "$LOGDIR/.debugpid"
	sleep 5
	grep -qi "Could not start com.apple.debugserver" "$LOGDIR/stdout-$STAMP.log" && return 1
	return 0
}

ssh_ready() {
	if ! ssh $SSH_OPTS "$SSH_HOST" true 2>/dev/null; then
		pkill -f "iproxy $SSH_PORT" 2>/dev/null
		iproxy "$SSH_PORT" 22 >/dev/null 2>&1 &
		echo $! > "$LOGDIR/.iproxypid"
		sleep 2
		ssh $SSH_OPTS "$SSH_HOST" true 2>/dev/null || return 1
	fi
	return 0
}

launch_via_ssh() {
	ssh_ready || return 1
	say "launching over SSH"
	ssh $SSH_OPTS "$SSH_HOST" "killall Telegram 2>/dev/null; true"
	sleep 2
	ssh $SSH_OPTS "$SSH_HOST" \
		"uiopen telegramdev:// 2>/dev/null || uiopen telegram:// 2>/dev/null || \
		 open $BUNDLE_ID 2>/dev/null || exit 7" && return 0
	echo "SSH works but no launcher binary found on the device." >&2
	echo "Install from Cydia: 'UIKit Tools' (com.saurik.uikittools) gives 'uiopen'." >&2
	return 1
}

launch() {
	launch_via_debugserver && { echo "launched via debugserver"; return 0; }
	launch_via_ssh        && { echo "launched via ssh"; return 0; }

	cat >&2 <<'EOF'

CANNOT LAUNCH THE APP REMOTELY. Everything else still ran.
Provide ONE of these, then this script becomes fully autonomous:

  A) Developer Disk Image for iOS 7.1
     Drop DeveloperDiskImage.dmg + .signature into ~/DeviceSupport/7.1/
     (archived in the community "iOS DeviceSupport" repositories)

  B) SSH on the jailbroken device
     Cydia -> OpenSSH, plus 'Open for iOS 11' (com.conradkramer.open)
     Then set up a key so ssh needs no password:
       ssh-copy-id -p 2222 root@localhost   (with iproxy 2222 22 running)

EOF
	return 1
}

collect() {
	say "capturing syslog for ${SECONDS_TO_LOG}s (filter: $FILTER)"
	timeout "$SECONDS_TO_LOG" idevicesyslog 2>&1 \
		| grep --line-buffered -iE "$FILTER" > "$LOGDIR/syslog-$STAMP.log"
	echo "$(wc -l < "$LOGDIR/syslog-$STAMP.log") lines -> $LOGDIR/syslog-$STAMP.log"

	say "crash reports"
	local cdir="$LOGDIR/crash-$STAMP"
	mkdir -p "$cdir"
	idevicecrashreport -e -k "$cdir" >/dev/null 2>&1
	local newest
	newest="$(ls -t "$cdir"/Telegram_*.ips 2>/dev/null | head -1)"
	if [ -n "$newest" ]; then
		echo "newest: $newest"
		sed -n '/Exception Type/,/^$/p' "$newest" | head -8
	else
		echo "none"
	fi
}

shot() {
	ssh_ready || { echo "no ssh, cannot take a screenshot" >&2; return 1; }
	ssh $SSH_OPTS "$SSH_HOST" "uiopen telegramdev://screenshot" || return 1
	sleep 3
	local remote
	remote="$(ssh $SSH_OPTS "$SSH_HOST" \
		'ls -t /var/mobile/Applications/*/Library/Caches/screen.png 2>/dev/null | head -1')"
	[ -n "$remote" ] || { echo "app did not write a screenshot" >&2; return 1; }

	local age
	age="$(ssh $SSH_OPTS "$SSH_HOST" \
		"expr \$(date +%s) - \$(date -r '$remote' +%s 2>/dev/null || echo 0)")"
	if [ -z "$age" ] || [ "$age" -gt 60 ]; then
		echo "stale screenshot: ${age}s old, so the app did not answer." >&2
		echo "It is probably not running - check the launch first." >&2
		return 1
	fi

	scp $SSH_OPTS "$SSH_HOST:$remote" "$LOGDIR/screen-$STAMP.png" >/dev/null 2>&1 \
		&& echo "$LOGDIR/screen-$STAMP.png"
}

summary() {
	say "summary"
	local f="$LOGDIR/syslog-$STAMP.log"
	[ -s "$f" ] || { echo "no app log captured"; return; }
	grep -m1 "start\.\.\."            "$f" && :
	grep -m1 "LibTg inited"           "$f" && :
	grep -m1 "have auth_key"          "$f" && :
	grep -m1 "NEED_TO_AUTHORIZE"      "$f" && :
	grep -m1 "AUTHORIZED"             "$f" && :
	grep -m1 "isOnLineAndAuthorized"  "$f" && :
	echo "--- errors:"
	grep -iE "error|can't|fail|RPC_ERROR" "$f" | sort | uniq -c | sort -rn | head -10
}

cleanup() {
	[ -f "$LOGDIR/.iproxypid" ] && kill "$(cat "$LOGDIR/.iproxypid")" 2>/dev/null
	[ -f "$LOGDIR/.debugpid" ]  && kill "$(cat "$LOGDIR/.debugpid")"  2>/dev/null
	rm -f "$LOGDIR/.iproxypid" "$LOGDIR/.debugpid"
}
trap cleanup EXIT

wait_for_device || exit 1

if [ "$SHOT_ONLY" = 1 ]; then
	shot
	exit $?
fi

if [ "$CHECK_ONLY" = 1 ]; then
	say "checking launch methods, changing nothing"
	if ddi_mounted || try_mount_ddi; then echo "A) debugserver: available"; else echo "A) debugserver: NOT available"; fi
	if ssh_ready; then echo "B) ssh: reachable"; else echo "B) ssh: NOT reachable"; fi
	exit 0
fi

[ "$DO_BUILD" = 1 ] && { build || exit 1; }
install_ipa || exit 1
launch || echo "(continuing without launch - app may already be running)"
collect
summary
