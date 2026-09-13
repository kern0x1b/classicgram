#!/bin/sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
OUTDIR="$HERE/out"
STAGE="$HERE/work/deb"
TEMPLATES="$HERE/package"

DYLIB_SRC="$OUTDIR/TelegramSystemCall.dylib"
FILTER_SRC="$TEMPLATES/TelegramSystemCall.plist"

PKGDIRNAME=telegramsystemcall
PKGDIR="/var/lib/$PKGDIRNAME"
SUBDIR="/Library/MobileSubstrate/DynamicLibraries"
DYLIB="$SUBDIR/TelegramSystemCall.dylib"
FILTER="$SUBDIR/TelegramSystemCall.plist"

PACKAGE=${TELEGRAMSYSTEMCALL_PACKAGE:-com.kern0x1b.telegramsystemcall}
NAME=${TELEGRAMSYSTEMCALL_NAME:-Telegram System Call UI}
APPNAME=${TELEGRAMSYSTEMCALL_APPNAME:-Telegram}
AUTHOR=${TELEGRAMSYSTEMCALL_AUTHOR:-kern0x1b <kern0x1b@users.noreply.github.com>}
MAINTAINER=${TELEGRAMSYSTEMCALL_MAINTAINER:-$AUTHOR}

die() { echo "mkdeb: $*" >&2; exit 1; }

command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb not found (brew install dpkg)"
command -v python3 >/dev/null 2>&1 || die "python3 not found"
for f in "$DYLIB_SRC" "$FILTER_SRC"; do
    [ -f "$f" ] || die "$f missing -- run: make"
done

command -v otool >/dev/null 2>&1 && {
    otool -h "$DYLIB_SRC" >/dev/null 2>&1 || die "$DYLIB_SRC is not a Mach-O file"
    lipo -info "$DYLIB_SRC" | grep -q armv7 || die "$DYLIB_SRC has no armv7 slice"
    otool -L "$DYLIB_SRC" | grep -q UIKit && die "$DYLIB_SRC links UIKit; it must not"
    otool -L "$DYLIB_SRC" | grep -q substrate && die "$DYLIB_SRC links substrate; it must not"
} || true

python3 -c 'import plistlib,sys; plistlib.load(open(sys.argv[1],"rb"))' "$FILTER_SRC" \
    || die "$FILTER_SRC is not a readable plist"

if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
    EPOCH=$SOURCE_DATE_EPOCH
else
    EPOCH=$(python3 -c 'import calendar,time; t=time.gmtime(); print(calendar.timegm((t.tm_year,t.tm_mon,t.tm_mday,0,0,0,0,0,0)))')
fi
export SOURCE_DATE_EPOCH=$EPOCH
BUILD_DATE=$(python3 -c "import time,sys; print(time.strftime('%Y%m%d', time.gmtime(int(sys.argv[1]))))" "$EPOCH")
TOUCH_STAMP=$(python3 -c "import time,sys; print(time.strftime('%Y%m%d%H%M.%S', time.gmtime(int(sys.argv[1]))))" "$EPOCH")

VERSION=${TELEGRAMSYSTEMCALL_VERSION:-1.0-$BUILD_DATE}
DEB="$OUTDIR/${PACKAGE}_${VERSION}_iphoneos-arm.deb"

kb() { python3 -c 'import os,sys; print((os.path.getsize(sys.argv[1])+1023)//1024)' "$1"; }
INSTALLED_SIZE=$(( $(kb "$DYLIB_SRC") + $(kb "$FILTER_SRC") + 2 ))

echo "mkdeb: $PACKAGE $VERSION"
echo "  payload   $DYLIB, $FILTER, $PKGDIR"
echo "  epoch     $EPOCH ($BUILD_DATE, UTC)"

rm -rf "$STAGE"
ROOT="$STAGE/root"
mkdir -p "$ROOT/DEBIAN" "$ROOT$PKGDIR" "$ROOT$SUBDIR"

COPYFILE_DISABLE=1
export COPYFILE_DISABLE
cp "$DYLIB_SRC" "$ROOT$DYLIB"
cp "$FILTER_SRC" "$ROOT$FILTER"
cp "$TEMPLATES/respring" "$ROOT$PKGDIR/respring"

esc() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

subst() {
    sed \
        -e "s|@PACKAGE@|$(esc "$PACKAGE")|g" \
        -e "s|@NAME@|$(esc "$NAME")|g" \
        -e "s|@APPNAME@|$(esc "$APPNAME")|g" \
        -e "s|@VERSION@|$(esc "$VERSION")|g" \
        -e "s|@AUTHOR@|$(esc "$AUTHOR")|g" \
        -e "s|@MAINTAINER@|$(esc "$MAINTAINER")|g" \
        -e "s|@INSTALLED_SIZE@|$INSTALLED_SIZE|g" \
        -e "s|@PKGDIR@|$(esc "$PKGDIR")|g" \
        -e "s|@DYLIB@|$(esc "$DYLIB")|g" \
        -e "s|@FILTER@|$(esc "$FILTER")|g" \
        "$1"
}

subst "$TEMPLATES/control.in" > "$ROOT/DEBIAN/control"

for s in postinst postrm; do
    subst "$TEMPLATES/$s" > "$ROOT/DEBIAN/$s"
    chmod 755 "$ROOT/DEBIAN/$s"
    sh -n "$ROOT/DEBIAN/$s" || die "$s is not valid shell"
done
grep -q '@[A-Z_]*@' "$ROOT/DEBIAN"/* && die "unsubstituted placeholder left in DEBIAN/" || true

md5here() {
    if command -v md5 >/dev/null 2>&1; then md5 -q "$1"; else md5sum "$1" | cut -d' ' -f1; fi
}
: > "$ROOT/DEBIAN/md5sums"
( cd "$ROOT" && find . -type f -not -path './DEBIAN/*' | sed 's|^\./||' | sort ) | while read -r rel; do
    echo "$(md5here "$ROOT/$rel")  $rel" >> "$ROOT/DEBIAN/md5sums"
done

chmod 755 "$ROOT$PKGDIR/respring"
chmod 644 "$ROOT$DYLIB" "$ROOT$FILTER" "$ROOT/DEBIAN/control" "$ROOT/DEBIAN/md5sums"
find "$ROOT" -type d -exec chmod 755 {} +

command -v xattr >/dev/null 2>&1 && xattr -cr "$ROOT" 2>/dev/null || true
find "$ROOT" -name '._*' -delete 2>/dev/null || true
find "$ROOT" -exec touch -h -t "$TOUCH_STAMP" {} +

mkdir -p "$OUTDIR"
rm -f "$DEB"
dpkg-deb --root-owner-group --uniform-compression -Zgzip -z9 --build "$ROOT" "$DEB" >/dev/null

echo ""
dpkg-deb --info "$DEB" | sed -n '1,3p'
echo "  $DEB"
python3 -c '
import hashlib, os, sys
p = sys.argv[1]
h = hashlib.sha256(open(p, "rb").read()).hexdigest()
print("  %.2f MB  sha256 %s" % (os.path.getsize(p) / 1048576.0, h))
' "$DEB"
