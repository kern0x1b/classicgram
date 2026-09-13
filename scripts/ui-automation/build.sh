#!/bin/zsh
# Builds sbdriver.dylib (armv7, iOS 6) - a cynject-loadable SpringBoard driver.
set -e
HERE=${0:A:h}
ROOT=${HERE}/../..
DEV=$(xcode-select -p)
CLANG="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
SDK=${SDK:-$ROOT/build/sdks/iPhoneOS12.4.sdk}
"$CLANG" -arch armv7 -isysroot "$SDK" -miphoneos-version-min=6.0 -O2 -fno-objc-arc -fobjc-exceptions \
  -dynamiclib -framework Foundation -framework UIKit -framework CoreGraphics \
  -o "$HERE/sbdriver.dylib" "$HERE/sbdriver.m" 2>&1 | grep -vi "tbd\|simulator" || true
ldid -S "$HERE/sbdriver.dylib"
echo "built $HERE/sbdriver.dylib"
