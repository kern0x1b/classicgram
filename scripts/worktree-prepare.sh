#!/bin/sh
set -e

worktree=$(git rev-parse --show-toplevel)
common=$(cd "$(git rev-parse --git-common-dir)" && pwd)
main=$(dirname "$common")

if [ "$worktree" = "$main" ]; then
	echo "worktree-prepare: this is the main checkout, nothing to link"
	exit 0
fi

mkdir -p "$worktree/build/armv7"

for shared in sdks tdlib; do
	if [ -d "$main/build/$shared" ] && [ ! -e "$worktree/build/$shared" ]; then
		ln -s "$main/build/$shared" "$worktree/build/$shared"
		echo "worktree-prepare: linked build/$shared"
	fi
done

if [ -d "$main/build/armv7/libs" ] && [ ! -d "$worktree/build/armv7/libs" ]; then
	cp -R "$main/build/armv7/libs" "$worktree/build/armv7/libs"
	echo "worktree-prepare: copied build/armv7/libs"
fi

if [ -f "$main/build/armv7/libvpx-obj/libvpx.a" ] && [ ! -f "$worktree/build/armv7/libvpx-obj/libvpx.a" ]; then
	cp -R "$main/build/armv7/libvpx-obj" "$worktree/build/armv7/libvpx-obj"
	config="$worktree/build/armv7/libvpx-obj/libs-armv7-darwin-gcc.mk"
	if [ -f "$config" ]; then
		sed -i '' "s|SRC_PATH_BARE=.*|SRC_PATH_BARE=$worktree/third_party/libvpx|" "$config"
	fi
	echo "worktree-prepare: copied the prebuilt libvpx"
fi

config_dir="$worktree/src/Resources/Config"
if [ -f "$main/src/Resources/Config/tg_config.h" ] && [ ! -f "$config_dir/tg_config.h" ]; then
	cp "$main/src/Resources/Config/tg_config.h" "$config_dir/tg_config.h"
	echo "worktree-prepare: copied src/Resources/Config/tg_config.h"
fi

echo "worktree-prepare: ready, run make FINALPACKAGE=1"
