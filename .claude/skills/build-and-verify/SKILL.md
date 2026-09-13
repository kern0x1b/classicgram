---
name: build-and-verify
description: Use when building this project for armv7, setting up a new git worktree for it, reading a make failure, checking for duplicate method definitions after moving code between files, or running the layer/comment lint scripts. Covers the symlink discipline that keeps worktrees off the disk-fill path, and why a naive duplicate scan misses real duplicates.
---

# Build and verify

## Building for armv7

The build is [Theos](https://theos.dev); `$THEOS` must point at the checkout.

```
make FINALPACKAGE=1 stage
```

assembles `.theos/_/Applications/Telegram.app/Telegram`, stripped and signed — `make package
FINALPACKAGE=1` wraps the same bundle as a `.deb`, needed only for a real install-from-scratch.
Plain `make` builds the debug variant. `machofix` (built from
`scripts/fix-armv7-macho.c`) runs as part of the link step and restores Thumb bits the armv7 linker drops;
without that fixup the app compiles but dies immediately at launch on the device. A successful
build log contains a line like `machofix: Thumb bit restored`; its absence is a build that looks
green but ships a binary that cannot run — treat a build without that line as suspect even if
`make` exits 0.

## Reading make output correctly

`make` does not reliably print a line starting with `error:` when a build fails early (a missing
header, a bad `#import` path) — the failure can scroll by inside compiler output that doesn't
match a simple `grep error:`. After every build:

1. Confirm the binary exists: `ls -la .theos/_/Applications/Telegram.app/Telegram`.
2. Confirm it is **newer than your last edit** — `ccache`/`make` can otherwise report success while
   silently reusing a stale object file for an unrelated reason, leaving your change absent from
   the binary you're about to test. If in doubt, `touch <file>.m` to force recompilation and
   re-check the build log for that file's compile line.
3. Grep broadly, not just for `error:` — `grep -iE "error:|fixup error|Undefined symbols"` across
   the full build log catches linker failures too, which never contain the word "error" in some
   toolchains' phrasing.

## Worktrees: where they live, and how they end

**Always work in a dedicated `git worktree`, never the main checkout.**

Worktrees for this repository live under `.claude/worktree/` inside the checkout, one directory per
branch, and that path is gitignored:

```
git -C <repo> worktree add .claude/worktree/<branch> -b <branch> <base>
```

**A piece of work is not finished until it is in the main checkout's branch and its worktree is
gone.** Merge or fast-forward into the working branch, confirm the build there, then
`git worktree remove --force` every worktree you created and `git worktree prune`. Removing a
worktree loses nothing that was committed — the branch keeps the commits — but save any uncommitted
diff as a patch outside the repository first. Leaving finished work parked in a worktree means the
next person opens the repository and sees the old tree.

A `git worktree add` does not carry over untracked files. Several build inputs are large, untracked,
and shared identically across every worktree — copy them once and 190 worktrees fill the disk and
kill every shell, which has already happened on this project:

| Path | What it is | Symlink target |
|---|---|---|
| `third_party/tdlib/td` | The `third_party/tdlib/td` git submodule checkout | not auto-populated in a worktree at all; either `git submodule update --init` inside the worktree (cheap, it's source) or symlink the whole directory to the main checkout's if you don't need to touch TDLib itself |
| `third_party/openssl/prebuilt/lib` | Prebuilt `libcrypto-universal.a` / `libssl-universal.a` (~8 MB) | `ln -s <main checkout>/third_party/openssl/prebuilt/lib third_party/openssl/prebuilt/lib` |
| `build/sdks` | Extracted iOS SDK headers (~1.2 GB) | `ln -s <main checkout>/build/sdks build/sdks` |
| `build/armv7/libs` | Armv7-thinned `libcrypto.a`/`libssl.a` linked against directly (no `-L` for the prebuilt universal libs exists) | `ln -s <main checkout>/build/armv7/libs build/armv7/libs`, or the link fails with `library not found for -lcrypto` |
| `build/armv7/libvpx-obj` | Built `libvpx.a` — its own `configure` mis-resolves the SDK sysroot in a fresh worktree and fails with `Toolchain is unable to link executables` | `ln -s <main checkout>/build/armv7/libvpx-obj build/armv7/libvpx-obj` |

Set these up right after `git worktree add`, before the first build in that worktree. A worktree
that only edits source and never builds doesn't need any of them.

`scripts/worktree-prepare.sh`, run from inside the new worktree, does this automatically: it
symlinks `build/sdks` and `third_party/tdlib`, copies `build/armv7/libs` and `build/armv7/libvpx-obj`
(copies rather than symlinks those two, so a worktree's own build never writes into the main
checkout's object files), and copies `src/Resources/Config/tg_config.h`. It skips anything already
present, so it's safe to re-run. It does not touch `third_party/openssl/prebuilt/lib` — symlink that
one by hand per the table above if the worktree needs to link.

`src/Resources/Config/tg_config.h` is gitignored too and no worktree gets it from `git worktree
add`; copy it in from the main checkout or the build stops at the first include of it.

`.claude/clean.sh` prunes worktrees that are fully merged and have no uncommitted changes — safe to
run any time disk usage looks high; it does not touch a worktree with real work in progress. It is
a convenience, not a substitute for removing your own worktree when you are done with it.

The layer-lint baselines are tracked in the repository, under `scripts/baselines/`, so they exist in
every worktree. `../iTgLegacy-notes/` (design reference, planning docs, session logs) is gitignored
and therefore **does not exist in a fresh worktree at all** — it lives only in the original checkout.
Reference that one there directly (e.g. `../iTgLegacy/../iTgLegacy-notes/docs/…`) rather than
expecting a copy to appear in a new worktree.

## Duplicate-definition scan

A plain `grep '^- (' file.m | sort | uniq -d` only compares the **first line** of each method
signature. This codebase writes long selectors across multiple lines routinely (parameters each on
their own line, closing with `{` several lines down) — a scan that ignores this once missed seven
real duplicate method bodies left behind by a refactor, because the first lines differed enough to
look unique while the full joined selector was identical.

Join each signature to the line containing its `{` (or `;` for a bare declaration) before
comparing:

```python
import re, sys

def signatures(path):
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    out, i = [], 0
    while i < len(lines):
        if re.match(r'^[-+]\s*\(', lines[i]):
            j = i
            while '{' not in lines[j] and ';' not in lines[j] and j + 1 < len(lines):
                j += 1
            joined = ' '.join(l.split('{')[0].split(';')[0] for l in lines[i:j+1])
            out.append((re.sub(r'\s+', ' ', joined).strip(), i + 1))
            i = j
        i += 1
    return out

seen = {}
for path in sys.argv[1:]:
    for sig, lineno in signatures(path):
        seen.setdefault(sig, []).append((path, lineno))
for sig, hits in seen.items():
    if len(hits) > 1:
        print(sig)
        for p, l in hits:
            print(f"  {p}:{l}")
```

Run it across a class's primary file plus all of its category files together (they share one
`@implementation ClassName`, so a duplicate between them is a real duplicate, not an override):

```
python3 -c "$(cat above)" src/Screens/Chat/TGChatViewController.m src/Screens/Chat/TGChatViewController+*.m
```

Run this after any refactor that moves methods between files — a split, a merge, a category
extraction — before considering the refactor done.

## Layer linter

`scripts/lint-layer-imports.py` walks `src/` and checks three independent rules, each with its own
baseline:

- **`rank`** — a rank per top-level package (`Model` < `Layout`/`Theme`/`Utilities` < `Views` <
  `Media`/`Storage`/`Calls` < `Companions` < `App`, with everything under `Screens/` ranked above all
  of those), violated by any file that `#import`s a header from a strictly higher-ranked package.
  `TDLibClient` is deliberately not in this table — it is not part of the general layering, it is the
  wire boundary, and it is governed entirely by the `tdlib-schema` rule below instead. Folding it
  into the rank table is what let `Screens` import it as a "legal downward edge" before.
- **`screen-wall`** — a screen may not import a sibling screen (`src/Screens/<A>/` importing
  `src/Screens/<B>/`), regardless of rank. The old rank table gave every `Screens/*` package the same
  rank, so this whole class of import was invisible to it.
- **`tdlib-schema`** — only `src/TDLibClient/` itself may import a header that lives in
  `src/TDLibClient/`. Every other package, `Companions` included, must go through it rather than
  reaching in directly; today nothing does that mediation, so this baseline is the honest, un-gated
  size of that problem.

```
python3 scripts/lint-layer-imports.py \
  --baseline-rank scripts/baselines/layer-rank.txt \
  --baseline-screen-wall scripts/baselines/layer-screen-wall.txt \
  --baseline-tdlib-schema scripts/baselines/tdlib-schema.txt
```

Pass `--rule rank` (repeatable) to run a subset. Violations already in a rule's baseline file print
with no marker; anything new prints `[NEW]` and the script exits `1`. Only pre-existing violations
belong in a baseline — a change that adds a new violation should fix it, not extend the baseline file
to hide it.

## Comment check

`scripts/lint-source-comments.py` is a real tokenizer (it tracks string/char-literal state, so it will
not false-positive on a `telegramdev://` URL scheme string or an `http://` literal the way a plain
`//` grep would):

```
python3 scripts/lint-source-comments.py --check src
```

Exits `1` and prints every offending file if any `.m`/`.h`/`.c`/`.mm` file under the given path
contains a comment. Without `--check` it rewrites the files in place, stripping comments — do not
run it that way as a matter of course; this project's rule is that comments are never written in
the first place, not that they get silently stripped after the fact. Run it with `--check` after
any edit to confirm nothing slipped in.
