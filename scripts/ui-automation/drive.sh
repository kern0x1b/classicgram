#!/bin/zsh
# Drive the SpringBoard UI over SSH by injecting sbdriver.dylib into SpringBoard.
# Usage:
#   drive.sh <command> [out.png]
# Commands understood by sbdriver:
#   full                    unlock the device (passcode from $TG_DEVICE_PASSCODE) and reveal the home screen
#   tap X Y                 tap a UIControl at point X,Y (buttons, alert buttons, switches)
#   passcode NNNN           attemptDeviceUnlockWithPassword:lockViewOwner:
#   finish                  full controller-level unlock sequence (diagnostic)
# Notes:
#   - Coordinates are POINTS. iPad 2 is non-retina, so points == screenshot pixels (768x1024).
#   - First run in a session pushes the dylib; each call copies it to a unique path so the
#     constructor re-fires (dlopen of the same path would not re-run it).
IP=${IP:-${TG_DEVICE:?set TG_DEVICE}}
SSH=(sshpass -p "${TG_DEVICE_PASSWORD:?set TG_DEVICE_PASSWORD}" ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$IP)
SCP=(sshpass -p "${TG_DEVICE_PASSWORD:?set TG_DEVICE_PASSWORD}" scp -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
HERE=${0:A:h}
CMD="$1"
OUT="${2:-shot.png}"
"${SCP[@]}" "$HERE/sbdriver.dylib" root@$IP:/tmp/sbdriver.dylib >/dev/null 2>&1
SB=$("${SSH[@]}" "launchctl list | grep com.apple.SpringBoard" | grep -oE '^[0-9]+')
U="/tmp/sbdriver_$$_$RANDOM.dylib"
"${SSH[@]}" "printf '%s' \"$CMD\" > /tmp/sbcmd; cp /tmp/sbdriver.dylib $U; /tmp/undim >/dev/null 2>&1; /usr/bin/cynject $SB $U 2>&1; sleep 1; rm -f $U; echo '---OUT---'; cat /tmp/sbcmd.out 2>&1; /tmp/screenshot /tmp/shot.png >/dev/null 2>&1"
"${SCP[@]}" root@$IP:/tmp/shot.png "$HERE/$OUT" >/dev/null 2>&1 && echo "shot: $HERE/$OUT"
