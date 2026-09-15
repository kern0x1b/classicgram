#!/bin/bash
set -uo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR" || exit 1

MODE="full"
case "${1:-}" in
	--changed) MODE="changed" ;;
	--full|"") MODE="full" ;;
	*)
		echo "usage: $0 [--changed|--full]" >&2
		exit 2
		;;
esac

WORK_DIR=$(mktemp -d)
CONFIG_HEADER="$ROOT_DIR/src/Resources/Config/tg_config.h"
CONFIG_EXAMPLE="$ROOT_DIR/src/Resources/Config/tg_config.h.example"
SYNTHESIZED_CONFIG=0

cleanup() {
	if [ "$SYNTHESIZED_CONFIG" = "1" ]; then
		rm -f "$CONFIG_HEADER"
		echo "lint-header-standalone: removed the placeholder src/Resources/Config/tg_config.h that this run synthesized."
	fi
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

PRINT_MK="$WORK_DIR/print.mk"
cat > "$PRINT_MK" <<EOF
THEOS_PROJECT_DIR := $ROOT_DIR
include $ROOT_DIR/Makefile
print-%:
	@echo '\$(\$*)'
EOF

CLANG="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
if [ ! -x "$CLANG" ]; then
	CLANG="$(xcrun -f clang 2>/dev/null || true)"
fi
if [ ! -x "$CLANG" ]; then
	CLANG="$(command -v clang || true)"
fi
SYSROOT=$(THEOS=${THEOS:-$HOME/theos} make -f "$PRINT_MK" print-SYSROOT 2>/dev/null | tail -1)
INCLUDES=$(THEOS=${THEOS:-$HOME/theos} make -f "$PRINT_MK" print-SRC_INCLUDES 2>/dev/null | tail -1)

if [ -z "$SYSROOT" ] || [ ! -d "$SYSROOT" ]; then
	SYSROOT="$ROOT_DIR/build/sdks/iPhoneOS12.4.sdk"
fi
if [ ! -d "$SYSROOT" ]; then
	SYSROOT="$ROOT_DIR/build/sdks/iPhoneOS9.3.sdk"
fi
OBJCFLAGS="-arch armv7 -mthumb -O0 -fsyntax-only -isysroot $SYSROOT -miphoneos-version-min=6.0 $INCLUDES -fobjc-arc -Wno-deprecated-declarations -Wno-macro-redefined"

if [ ! -x "$CLANG" ]; then
	echo "lint-header-standalone: no clang at $CLANG" >&2
	exit 1
fi
if [ ! -d "$SYSROOT" ]; then
	echo "lint-header-standalone: no iPhoneOS SDK under build/sdks" >&2
	exit 1
fi

if [ "$MODE" = "changed" ]; then
	HEADERS=()
	while IFS= read -r f; do
		case "$f" in
			src/*.h) HEADERS+=("$f") ;;
		esac
	done < <(git diff --cached --name-only --diff-filter=ACMR)
	if [ ${#HEADERS[@]} -eq 0 ]; then
		echo "lint-header-standalone: no staged headers under src/, nothing to check."
		exit 0
	fi
else
	HEADERS=()
	while IFS= read -r f; do
		HEADERS+=("$f")
	done < <(git ls-files 'src/*.h' | sort)
fi

NEEDS_CONFIG=0
for h in "${HEADERS[@]}"; do
	if [ "$h" = "src/Resources/Config/api_id.h" ]; then
		NEEDS_CONFIG=1
		break
	fi
done

if [ "$NEEDS_CONFIG" = "1" ] && [ ! -f "$CONFIG_HEADER" ]; then
	echo "lint-header-standalone: src/Resources/Config/tg_config.h is git-ignored and not present in this checkout."
	echo "lint-header-standalone: src/Resources/Config/api_id.h #includes it and cannot stand alone without it, so a placeholder is being copied from tg_config.h.example for the duration of this check."
	cp "$CONFIG_EXAMPLE" "$CONFIG_HEADER"
	SYNTHESIZED_CONFIG=1
fi

FAIL_DIR="$WORK_DIR/fails"
mkdir -p "$FAIL_DIR"

CHECK_HEADER="$WORK_DIR/check_header.sh"
cat > "$CHECK_HEADER" <<'EOF'
#!/bin/bash
h="$1"
slot="$2"
if ! out=$("$CLANG" -x objective-c-header -fsyntax-only $OBJCFLAGS "$h" 2>&1); then
	{
		printf 'FAIL\t%s\n' "$h"
		printf '%s\n' "$out"
	} > "$FAIL_DIR/$slot.txt"
fi
EOF
chmod +x "$CHECK_HEADER"

NPROC=$(sysctl -n hw.ncpu 2>/dev/null)
[ -n "$NPROC" ] || NPROC=4

export CLANG OBJCFLAGS FAIL_DIR

START_TS=$(date +%s)
SLOT=0
ARGS_FILE="$WORK_DIR/args.txt"
: > "$ARGS_FILE"
for h in "${HEADERS[@]}"; do
	SLOT=$((SLOT + 1))
	printf '%s\t%s\n' "$h" "$SLOT" >> "$ARGS_FILE"
done
xargs -P "$NPROC" -L 1 "$CHECK_HEADER" < "$ARGS_FILE"
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

FAILED_HEADERS=$(find "$FAIL_DIR" -name '*.txt' | wc -l | tr -d ' ')

echo "lint-header-standalone: checked ${#HEADERS[@]} header(s) in ${ELAPSED}s (mode: $MODE, $NPROC parallel jobs)"

if [ "$FAILED_HEADERS" -gt 0 ]; then
	echo ""
	echo "lint-header-standalone: $FAILED_HEADERS header(s) do not compile standalone:"
	echo ""
	for f in "$FAIL_DIR"/*.txt; do
		cat "$f"
	done
	echo "commit refused: a header above only compiles because whatever includes it first imports something it needs - add the missing #import to the header itself"
	exit 1
fi

exit 0
