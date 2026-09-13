#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$repo_root/build/host-tests"
binary_path="$build_dir/fuzz-flatten-message"
corpus_dir="$repo_root/tests/fuzz/corpus/flatten_message"

mkdir -p "$build_dir" "$corpus_dir"

fuzzer_clang="clang"
for candidate in /opt/homebrew/opt/llvm/bin/clang /opt/homebrew/Cellar/llvm/*/bin/clang; do
	if [ -x "$candidate" ]; then
		fuzzer_clang="$candidate"
		break
	fi
done

echo "run-fuzz-flatten-message: compiling libFuzzer harness for TGFlattenMessage with $fuzzer_clang, no iOS SDK involved"

"$fuzzer_clang" \
	-fobjc-arc \
	-fsanitize=fuzzer,address,undefined \
	-Wall \
	-Wno-unused-parameter \
	-I "$repo_root/src/Wire/Flatten" \
	-I "$repo_root/src/TDLibClient" \
	-framework Foundation \
	-framework CoreGraphics \
	"$repo_root/src/Wire/Flatten/TGFlattenMessage.m" \
	"$repo_root/tests/support/tg_flatten_message_fixture.m" \
	"$repo_root/tests/fuzz/tg_flatten_message_fuzz.m" \
	-o "$binary_path"

echo "run-fuzz-flatten-message: built $binary_path"
echo "run-fuzz-flatten-message: running against $corpus_dir (pass -max_total_time=N to bound a run)"

exec "$binary_path" "$corpus_dir" "$@"
