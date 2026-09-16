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

PROJECT="$ROOT_DIR/build/armv7/application"
if [ ! -f "$PROJECT/build.ninja" ]; then
	echo "lint-header-standalone: no application build tree at build/armv7/application - run 'charon build --variant armv7' first" >&2
	exit 1
fi

ninja -C "$PROJECT" -t commands > "$WORK_DIR/commands.txt" 2>/dev/null || {
	echo "lint-header-standalone: ninja could not list the application's compile commands" >&2
	exit 1
}

python3 - "$WORK_DIR/commands.txt" "$WORK_DIR" <<'PY' || exit 1
import shlex, sys
commands, out = sys.argv[1], sys.argv[2]
wanted = {".m": "objc", ".mm": "objcxx"}
found = {}
for line in open(commands, encoding="utf-8"):
    words = shlex.split(line)
    if not words or "-c" not in words:
        continue
    source = words[words.index("-c") + 1]
    language = next((name for suffix, name in wanted.items() if source.endswith(suffix)), None)
    if not language or language in found:
        continue
    flags, skip = [], False
    for word in words[1:]:
        if skip:
            skip = False
            continue
        if word in ("-o", "-c", "-MF", "-MT", "-MQ"):
            skip = True
            continue
        if word in ("-MD", "-MMD") or word == source:
            continue
        flags.append(word)
    found[language] = (words[0], flags)
    if len(found) == len(wanted):
        break
missing = [name for name in wanted.values() if name not in found]
if missing:
    sys.exit("lint-header-standalone: the build tree compiles no " + " or ".join(missing) + " source")
for language, (compiler, flags) in found.items():
    with open(f"{out}/{language}.flags", "w") as handle:
        handle.write(shlex.join(flags))
    with open(f"{out}/compiler", "w") as handle:
        handle.write(compiler)
PY

CLANG=$(cat "$WORK_DIR/compiler")
OBJC_FLAGS=$(cat "$WORK_DIR/objc.flags")
OBJCXX_FLAGS=$(cat "$WORK_DIR/objcxx.flags")

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
base="${h%.h}"
if [ -f "$base.mm" ] && [ ! -f "$base.m" ]; then
	language=objective-c++-header
	eval "flags=($OBJCXX_FLAGS)"
else
	language=objective-c-header
	eval "flags=($OBJC_FLAGS)"
fi
if ! out=$("$CLANG" -x "$language" -fsyntax-only "${flags[@]}" "$h" 2>&1); then
	{
		printf 'FAIL\t%s\n' "$h"
		printf '%s\n' "$out"
	} > "$FAIL_DIR/$slot.txt"
fi
EOF
chmod +x "$CHECK_HEADER"

NPROC=$(sysctl -n hw.ncpu 2>/dev/null)
[ -n "$NPROC" ] || NPROC=4

export CLANG OBJC_FLAGS OBJCXX_FLAGS FAIL_DIR

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

echo "lint-header-standalone: checked ${#HEADERS[@]} header(s) in ${ELAPSED}s (mode: $MODE, $NPROC parallel jobs, flags of build/armv7/application)"

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
