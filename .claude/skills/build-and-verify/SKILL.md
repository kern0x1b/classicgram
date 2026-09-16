---
name: build-and-verify
description: Use when building this project with charon, setting up a new git worktree for it, reading a build failure, checking for duplicate method definitions after moving code between files, or running the layer/comment lint scripts. Covers what the build's binary checks refuse, and why a naive duplicate scan misses real duplicates.
---

# Build and verify

## Building

The build is Charon, reading `charon.toml`:

```
charon build                      # build/universal/Telegram.app: armv7 + arm64, merged and signed
charon build --variant armv7      # build/armv7/Telegram.app alone
charon build --variant harness    # armv7 with the telegramdev:// debug harness, for device testing
```

Every dependency comes from the Conan cache through `recipes/`; the SDK, the armv7 linker, `ldid`
and the C++ runtime come from the `apple-ios` platform's packages, so nothing outside the checkout
and `~/.conan2` is needed. `export LLVM_PREFIX="$(brew --prefix llvm)"` once per shell, before the
first build on a machine: the ld64 package reads it when it has to be built from source.

A build that exits 0 is one whose binary checks passed. Charon refuses, naming the file:

- an object or archive member recording a minimum iOS version other than the variant's;
- a rebased code pointer whose Thumb bit disagrees with the function it names;
- a `__PAGEZERO` wrong for the architecture;
- a bundled binary that loads a library the bundle carries from anywhere else;
- a signature that does not carry a declared entitlement.

There is no fixup step after the link any more; if one of these fails, the input is wrong.

## Reading a build failure

Charon prints the failing command's own output. After every build:

1. Confirm the bundle is newer than your last edit: `ls -la build/universal/Telegram.app/Telegram`.
   `ccache` can report success while reusing a stale object; if in doubt, `touch <file>.m` and look
   for that file's compile line.
2. Grep the whole log broadly - `grep -iE "error:|refus|Undefined symbols"` - since a check's
   refusal and a linker failure do not always contain `error:`.

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

A `git worktree add` does not carry over untracked files. The one a build needs is
`src/Resources/Config/tg_config.h`; `scripts/worktree-prepare.sh`, run from inside the new
worktree, copies it from the main checkout and skips it if it is already there. Everything else a
build uses lives in Conan's cache (`~/.conan2`), which every worktree on the machine shares, so a
first build in a new worktree reuses what was already built instead of rebuilding it.

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
