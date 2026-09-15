#!/bin/bash
set -euo pipefail

OPENSSL_VERSION="1.1.1w"
OPENSSL_TAG="OpenSSL_1_1_1w"
OPENSSL_SHA256="cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${ROOT_DIR}/build/openssl-src"
OUT_DIR="${ROOT_DIR}/third_party/openssl/prebuilt"
TARBALL="${WORK_DIR}/openssl-${OPENSSL_VERSION}.tar.gz"
SRC_DIR="${WORK_DIR}/openssl-${OPENSSL_VERSION}"

for TOOL in curl tar make perl shasum lipo; do
  command -v "${TOOL}" >/dev/null 2>&1 || { echo "error: ${TOOL} not found on PATH" >&2; exit 1; }
done

XCODE_DEV="$(xcode-select -p 2>/dev/null || true)"
[ -n "${XCODE_DEV}" ] && [ -d "${XCODE_DEV}" ] || { echo "error: no Xcode command line tools found - run xcode-select --install" >&2; exit 1; }

TOOLCHAIN_BIN="${XCODE_DEV}/Toolchains/XcodeDefault.xctoolchain/usr/bin"
[ -x "${TOOLCHAIN_BIN}/cc" ] || { echo "error: ${TOOLCHAIN_BIN}/cc not found - Xcode.app is required, the standalone command line tools do not ship it" >&2; exit 1; }

SDK_PLATFORM_DIR="${XCODE_DEV}/Platforms/iPhoneOS.platform/Developer"
[ -d "${SDK_PLATFORM_DIR}/SDKs/iPhoneOS.sdk" ] || { echo "error: ${SDK_PLATFORM_DIR}/SDKs/iPhoneOS.sdk not found - install the iOS platform in Xcode" >&2; exit 1; }

mkdir -p "${WORK_DIR}"

if [ ! -f "${TARBALL}" ]; then
  echo "[+] downloading openssl-${OPENSSL_VERSION}"
  curl -fL --retry 3 -o "${TARBALL}" "https://github.com/openssl/openssl/releases/download/${OPENSSL_TAG}/openssl-${OPENSSL_VERSION}.tar.gz"
fi

echo "${OPENSSL_SHA256}  ${TARBALL}" | shasum -a 256 -c - || { echo "error: ${TARBALL} failed its checksum - delete it and re-run, or the pinned OPENSSL_SHA256 in this script is stale" >&2; exit 1; }

rm -rf "${SRC_DIR}"
tar -xzf "${TARBALL}" -C "${WORK_DIR}"

# Xcode 27's ld asserts on the named __nl_symbol_ptr atom OpenSSL's ARM asm emits
# for OPENSSL_armcap_P (it requires GOT atoms to be anonymous). Emit the same
# pointer as a plain __data word instead: identical load sequence, no GOT atom.
python3 - "${SRC_DIR}/crypto/perlasm/arm-xlate.pl" <<'XLATE'
import sys
p = sys.argv[1]
s = open(p).read()
old = ('\t$ret = ".comm\\t_$name,@args[1]\\n";\n'
       '\t$ret .= ".non_lazy_symbol_pointer\\n";\n'
       '\t$ret .= "$name:\\n";\n'
       '\t$ret .= ".indirect_symbol\\t_$name\\n";\n'
       '\t$ret .= ".long\\t0";\n')
new = ('\t$ret = ".comm\\t_$name,@args[1]\\n";\n'
       '\t$ret .= ".data\\n";\n'
       '\t$ret .= ".align\\t2\\n";\n'
       '\t$ret .= "$name:\\n";\n'
       '\t$ret .= ".long\\t_$name\\n";\n'
       '\t$ret .= ".text";\n')
if new in s:
    sys.exit(0)
if old not in s:
    sys.stderr.write("arm-xlate.pl: expected ios32 non-lazy block not found\n")
    sys.exit(1)
open(p, "w").write(s.replace(old, new, 1))
XLATE

build_one() {
  local CONFIG_TARGET="$1"
  local ARCH="$2"
  local MIN_VERSION="$3"
  local ARCH_DIR="${WORK_DIR}/${ARCH}"
  rm -rf "${ARCH_DIR}"
  cp -R "${SRC_DIR}" "${ARCH_DIR}"
  (
    cd "${ARCH_DIR}"
    export CROSS_COMPILE="${TOOLCHAIN_BIN}/"
    export CROSS_TOP="${SDK_PLATFORM_DIR}"
    export CROSS_SDK="iPhoneOS.sdk"
    ./Configure "${CONFIG_TARGET}" no-shared no-dso -mios-version-min="${MIN_VERSION}"
    make -j"$(sysctl -n hw.logicalcpu)" build_libs
  )
  [ -f "${ARCH_DIR}/libcrypto.a" ] || { echo "error: ${ARCH_DIR}/libcrypto.a was not produced" >&2; exit 1; }
  [ -f "${ARCH_DIR}/libssl.a" ] || { echo "error: ${ARCH_DIR}/libssl.a was not produced" >&2; exit 1; }
}

echo "[+] building armv7 (ios-cross)"
build_one ios-cross armv7 6.0
echo "[+] building arm64 (ios64-cross)"
build_one ios64-cross arm64 9.0

mkdir -p "${OUT_DIR}/lib"
lipo -create "${WORK_DIR}/armv7/libcrypto.a" "${WORK_DIR}/arm64/libcrypto.a" -output "${OUT_DIR}/lib/libcrypto-universal.a"
lipo -create "${WORK_DIR}/armv7/libssl.a" "${WORK_DIR}/arm64/libssl.a" -output "${OUT_DIR}/lib/libssl-universal.a"

rm -rf "${OUT_DIR}/include"
cp -R "${WORK_DIR}/armv7/include" "${OUT_DIR}/include"

echo "[+] ${OUT_DIR}/lib/libcrypto-universal.a"
lipo -info "${OUT_DIR}/lib/libcrypto-universal.a"
echo "[+] ${OUT_DIR}/lib/libssl-universal.a"
lipo -info "${OUT_DIR}/lib/libssl-universal.a"
echo "[+] next: scripts/build-openssl-libs.sh to populate build/armv7/libs and build/arm64/libs"
