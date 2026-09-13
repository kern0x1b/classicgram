#!/bin/sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOKS_DIR=$(git -C "$ROOT" rev-parse --git-common-dir)/hooks

mkdir -p "$HOOKS_DIR"
for hook in "$ROOT"/scripts/git-hooks/*; do
	name=$(basename "$hook")
	cp "$hook" "$HOOKS_DIR/$name"
	chmod +x "$HOOKS_DIR/$name"
	echo "installed $HOOKS_DIR/$name"
done
