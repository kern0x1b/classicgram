---
name: shell-macos
description: Use when writing a shell one-liner, a sed command, an SSH invocation, or anything with a glob on this Mac (zsh, BSD tools). Covers three traps that have each produced a wrong result that looked like it worked.
---

# Shell and macOS tool traps

This Mac's default shell is **zsh**, and its `sed`/`find`/etc. are **BSD**, not GNU — code that
assumes bash word-splitting or GNU sed extensions fails in ways that don't always look like an
error.

## BSD sed has no `0,/re/` addressing

GNU sed's `0,/pattern/{s/.../.../}` (act on only the first match, not every match) is silently
**ignored** by BSD sed on macOS — it does not error, it just applies the substitution to every
matching line instead of only the first, which is a wrong result that looks like success. For
inserting or replacing at a single specific location in a file, use Python instead of trying to
craft a portable sed:

```python
python3 - <<'EOF'
path = "file.m"
text = open(path).read()
text = text.replace(old_snippet, new_snippet, 1)
open(path, "w").write(text)
EOF
```

The `Edit` tool already does exact-match single replacement correctly — reach for a raw `sed`
one-liner only for genuinely simple, whole-file, every-occurrence changes.

## zsh does not word-split

Building a command into a variable and reusing it breaks silently in zsh, because unquoted `$VAR`
is **not** re-split on spaces the way it is in bash:

```zsh
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@1.2.3.4"
$SSH "some command"     # fails: "file name too long" or similar — zsh passes $SSH as ONE argument
```

Write the full literal command inline at every call site instead of caching it in a variable:

```zsh
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@1.2.3.4 "some command"
```

This applies to every device SSH command in this project (see the `device-deploy` skill) — the
option string is long and repetitive, and the temptation to cache it into a variable is exactly
what breaks.

## zsh treats an empty glob as an error

`rm -f build/*.o` errors with `no matches found` in zsh (not "0 files removed") when the glob
matches nothing, unlike bash's default. `.claude/clean.sh` sets `setopt NULL_GLOB` at the top of
the script for exactly this reason — a glob that matches nothing then expands to zero words
instead of erroring. Either set `NULL_GLOB` in a script that may run against an empty directory,
or guard the glob with an existence check first:

```zsh
setopt NULL_GLOB
for f in build/*.o; do rm -f "$f"; done
```
