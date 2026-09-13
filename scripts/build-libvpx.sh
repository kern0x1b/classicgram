#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
arch="${1:-armv7}"
obj_dir="$root/build/$arch/libvpx-obj"
lib="$obj_dir/libvpx.a"

if [ -f "$lib" ]; then
	exit 0
fi

src_dir="$root/third_party/libvpx"
sdk="$root/build/sdks/iPhoneOS12.4.sdk"
[ -d "$sdk" ] || sdk="$root/build/sdks/iPhoneOS9.3.sdk"
[ -d "$sdk" ] || sdk="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
clang="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

if [ -f "$obj_dir/libs-$arch-darwin-gcc.mk" ] &&
	! grep -q "SRC_PATH_BARE=$src_dir\$" "$obj_dir/libs-$arch-darwin-gcc.mk"; then
	echo "[+] $obj_dir was configured against a different libvpx source path - wiping"
	rm -rf "$obj_dir"
fi

mkdir -p "$obj_dir"
cd "$obj_dir"
if [ ! -f Makefile ]; then
	CC="$clang" CXX="${clang}++" \
	CFLAGS="-arch $arch -miphoneos-version-min=6.0 -isysroot $sdk" \
	CXXFLAGS="-arch $arch -miphoneos-version-min=6.0 -isysroot $sdk" \
	LDFLAGS="-arch $arch -miphoneos-version-min=6.0 -isysroot $sdk" \
	TGVPX_SDK_PATH="$sdk" \
	"$src_dir/configure" --target=$arch-darwin-gcc --enable-neon \
		--disable-examples --disable-docs --disable-unit-tests \
		--enable-static --disable-shared --disable-vp9 --enable-vp8 \
		--enable-realtime-only --disable-runtime-cpu-detect
fi
make -j"$(sysctl -n hw.ncpu)"
