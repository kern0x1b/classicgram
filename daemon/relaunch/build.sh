#!/bin/bash
# build.sh - build the telegramd watchdog for armv7 (iPhone 4S / iOS 6).
#
# Output: out/telegramd, out/com.kern0x1b.telegramd.plist, out/telegramd.conf
# Nothing is copied to a device; see install.sh.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${SCRIPT_DIR}/out"

XCODE_DEV="$(xcode-select -p)"
SDK_PATH="${ROOT_DIR}/build/sdks/iPhoneOS12.4.sdk"
[ -d "${SDK_PATH}" ] || SDK_PATH="${XCODE_DEV}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
CLANG="${XCODE_DEV}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

mkdir -p "${OUT_DIR}"

echo "[+] telegramd (armv7)"
echo "    sdk : ${SDK_PATH}"

"${CLANG}" -arch armv7 -mthumb -Os \
	-isysroot "${SDK_PATH}" \
	-miphoneos-version-min=6.0 \
	-Wall -Wextra \
	-framework CoreFoundation \
	-o "${OUT_DIR}/telegramd" \
	"${SCRIPT_DIR}/src/telegramd.c"

if command -v ldid >/dev/null; then
	ldid -S"${SCRIPT_DIR}/entitlements.plist" "${OUT_DIR}/telegramd"
	echo "[+] signed with entitlements.plist"
else
	echo "[!] ldid not found - the binary is unsigned and will not run on the device"
fi

cp -f "${SCRIPT_DIR}/com.kern0x1b.telegramd.plist" "${OUT_DIR}/"
cp -f "${SCRIPT_DIR}/telegramd.conf" "${OUT_DIR}/"

echo ""
ls -l "${OUT_DIR}"
file "${OUT_DIR}/telegramd"
