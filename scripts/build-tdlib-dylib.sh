#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TDLIB_SRC="${ROOT_DIR}/third_party/tdlib/td"
BUILD_DIR="${ROOT_DIR}/build/tdlib-dylib-armv7"
OUT_DIR="${ROOT_DIR}/build/armv7/tdlib/lib"

XCODE_DEV="$(xcode-select -p 2>/dev/null || true)"
[ -n "${XCODE_DEV}" ] && [ -d "${XCODE_DEV}" ] || { echo "[-] no Xcode command line tools found - run xcode-select --install"; exit 1; }
SDK_PATH="${ROOT_DIR}/build/sdks/iPhoneOS12.4.sdk"
[ -d "${SDK_PATH}" ] || SDK_PATH="${XCODE_DEV}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
[ -d "${SDK_PATH}" ] || { echo "[-] no iOS SDK found at ${SDK_PATH} - run scripts/fetch-ios-sdk.sh or install the iOS platform in Xcode"; exit 1; }
TOOLCHAIN="${XCODE_DEV}/Toolchains/XcodeDefault.xctoolchain/usr/bin"

XCODE_SDK="${XCODE_DEV}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
CXX_STDLIB_INC="-isystem ${XCODE_SDK}/usr/include/c++/v1"

[ -f "${TDLIB_SRC}/CMakeLists.txt" ] || { echo "[-] ${TDLIB_SRC} is empty - run git submodule update --init third_party/tdlib/td"; exit 1; }

for tool in cmake gperf ccache; do
	command -v "$tool" >/dev/null || { echo "[-] $tool not found (brew install $tool)"; exit 1; }
done

echo "[+] TDLib -> libtdjson.dylib (armv7)"
echo "    src : ${TDLIB_SRC}"
echo "    sdk : ${SDK_PATH}"

if [ ! -d "${ROOT_DIR}/third_party/tdlib/native-build" ]; then
	echo "[+] pregenerating sources"
	mkdir -p "${ROOT_DIR}/third_party/tdlib/native-build"
	cd "${ROOT_DIR}/third_party/tdlib/native-build"
	cmake -DTD_GENERATE_SOURCE_FILES=ON "${TDLIB_SRC}"
	cmake --build . --target prepare_cross_compiling
fi

if [ -f "${BUILD_DIR}/CMakeCache.txt" ]; then
	CACHED_SRC="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "${BUILD_DIR}/CMakeCache.txt")"
	if [ "${CACHED_SRC}" != "${TDLIB_SRC}" ]; then
		echo "[+] ${BUILD_DIR} was configured against ${CACHED_SRC}, source is now ${TDLIB_SRC} - wiping stale build dir"
		rm -rf "${BUILD_DIR}"
	fi
fi

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

COMPAT_O="${BUILD_DIR}/ios7_compat.o"
"${TOOLCHAIN}/clang" -arch armv7 -mthumb -Os -isysroot "${SDK_PATH}" \
	-miphoneos-version-min=6.0 -c "${ROOT_DIR}/third_party/tdlib/build/weak_import_shims.c" -o "${COMPAT_O}"
echo "[+] ios7 compat shims: ${COMPAT_O}"

cd "${BUILD_DIR}"

cmake "${TDLIB_SRC}" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DCMAKE_C_COMPILER="${TOOLCHAIN}/clang" \
	-DCMAKE_CXX_COMPILER="${TOOLCHAIN}/clang++" \
	-DCMAKE_SYSTEM_NAME=iOS \
	-DCMAKE_OSX_SYSROOT="${SDK_PATH}" \
	-DCMAKE_OSX_ARCHITECTURES="armv7" \
	-DCMAKE_OSX_DEPLOYMENT_TARGET=6.0 \
	-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
	-DATOMICS_FOUND=TRUE \
	-DATOMICS_LIBRARIES="" \
	-DCMAKE_C_FLAGS="-Wno-error -mthumb -Os -g -I${ROOT_DIR}/third_party/tdlib" \
	-DCMAKE_CXX_FLAGS="-Wno-error -mthumb -Os -g -I${ROOT_DIR}/third_party/tdlib ${CXX_STDLIB_INC}" \
	-DCMAKE_SHARED_LINKER_FLAGS="-install_name @executable_path/libtdjson.dylib ${COMPAT_O}" \
	-DOPENSSL_INCLUDE_DIR="${ROOT_DIR}/third_party/openssl/prebuilt/include" \
	-DOPENSSL_CRYPTO_LIBRARY="${ROOT_DIR}/build/armv7/libs/libcrypto.a" \
	-DOPENSSL_SSL_LIBRARY="${ROOT_DIR}/build/armv7/libs/libssl.a" \
	-DBUILD_SHARED_LIBS=ON \
	-DTD_ENABLE_LTO=OFF \
	-DCMAKE_POLICY_DEFAULT_CMP0074=NEW

find "${BUILD_DIR}" -name 'libtdjson*.dylib' -delete

cmake --build . --target tdjson -- -j"$(sysctl -n hw.logicalcpu)"

DYLIB="$(find "${BUILD_DIR}" -name 'libtdjson*.dylib' | head -1)"
[ -n "${DYLIB}" ] || { echo "[-] no dylib produced"; exit 1; }

cp -f "${DYLIB}" "${OUT_DIR}/libtdjson.dylib"
"${TOOLCHAIN}/dsymutil" "${OUT_DIR}/libtdjson.dylib" -o "${OUT_DIR}/libtdjson.dylib.dSYM" 2>&1 | tail -5 || true

install_name_tool -id "@executable_path/libtdjson.dylib" "${OUT_DIR}/libtdjson.dylib"

MACHOFIX="${ROOT_DIR}/build/tools/machofix"
[ -x "${MACHOFIX}" ] || cc -O2 -o "${MACHOFIX}" "${ROOT_DIR}/scripts/fix-armv7-macho.c"
"${MACHOFIX}" "${OUT_DIR}/libtdjson.dylib"
ldid -S "${OUT_DIR}/libtdjson.dylib" 2>/dev/null || true

echo ""
echo "[+] ${OUT_DIR}/libtdjson.dylib"
ls -lh "${OUT_DIR}/libtdjson.dylib"
otool -l "${OUT_DIR}/libtdjson.dylib" | grep -A2 LC_ID_DYLIB | head -3
echo "    __TEXT size (must stay under 16MB for armv7 thumb branches):"
otool -l "${OUT_DIR}/libtdjson.dylib" | awk '/segname __TEXT/{f=1} f&&/vmsize/{print "    "$2; exit}'
