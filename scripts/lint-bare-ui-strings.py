#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")

SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc", "Resources")

SINKS = (
    r"\.(?:text|title|placeholder|prompt)\s*=\s*",
    r"setTitle:",
    r"setText:",
    r"setPlaceholder:",
    r"initWithTitle:",
    r"otherButtonTitles:",
    r"cancelButtonTitle:",
    r"destructiveButtonTitle:",
    r"message:",
)
SINK_RE = re.compile(r"(?:" + r"|".join(SINKS) + r')@"((?:[^"\\]|\\.)*)"')
WORD_RE = re.compile(r"[A-Za-z]{2,}")


def looks_like_prose(text):
    if not WORD_RE.search(text):
        return False
    if " " in text.strip():
        return True
    return bool(re.match(r"^[A-Z][a-z]{2,}$", text))


def sources():
    for root, dirs, names in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(names):
            if name.endswith((".m", ".mm")):
                yield os.path.join(root, name)


def main():
    bare = []
    for path in sources():
        text = open(path, encoding="utf-8", errors="replace").read()
        relative = os.path.relpath(path, ROOT)
        for match in SINK_RE.finditer(text):
            literal = match.group(1)
            if not looks_like_prose(literal):
                continue
            bare.append((relative, text.count("\n", 0, match.start()) + 1, literal))

    for relative, line, literal in bare:
        print(f'[NEW] {relative}:{line} "{literal}" reaches the screen as an English literal; '
              f"wrap it in TGL with a Localizable.strings key")

    if bare:
        print(f"lint-bare-ui-strings: {len(bare)} unlocalized user-visible literal(s)")
        return 1
    print("lint-bare-ui-strings: every literal handed to a title, label, alert or sheet goes through TGL")
    return 0


if __name__ == "__main__":
    sys.exit(main())
