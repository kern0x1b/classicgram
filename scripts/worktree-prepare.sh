#!/bin/sh
set -e

worktree=$(git rev-parse --show-toplevel)
common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main=$(dirname "$common")

if [ "$worktree" = "$main" ]; then
	echo "worktree-prepare: this is the main checkout, nothing to copy"
	exit 0
fi

config_dir="$worktree/src/Resources/Config"
if [ -f "$main/src/Resources/Config/tg_config.h" ] && [ ! -f "$config_dir/tg_config.h" ]; then
	cp "$main/src/Resources/Config/tg_config.h" "$config_dir/tg_config.h"
	echo "worktree-prepare: copied src/Resources/Config/tg_config.h"
fi

echo "worktree-prepare: ready, run charon build"
