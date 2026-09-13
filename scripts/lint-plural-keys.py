#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
STRINGS = os.path.join(SRC, "Resources", "Localization", "en.lproj", "Localizable.strings")

if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")
if not os.path.isfile(STRINGS):
    raise SystemExit(f"string table not found: {STRINGS}")

SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc", "Resources")

PLURAL_CALL_RE = re.compile(r'TGLPlural\(\s*@"([^"]+)"')
PLAIN_CALL_RE = re.compile(r'TGL\(\s*@"([^"]+(?:_1|_any))"')
ENTRY_RE = re.compile(r'^"([^"]+)"\s*=', re.M)


def sources():
    for root, dirs, names in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(names):
            if name.endswith((".m", ".mm")):
                yield os.path.join(root, name)


def main():
    table = open(STRINGS, encoding="utf-8", errors="replace").read()
    keys = set(ENTRY_RE.findall(table))

    missing = []
    plain = []
    for path in sources():
        text = open(path, encoding="utf-8", errors="replace").read()
        relative = os.path.relpath(path, ROOT)
        for match in PLURAL_CALL_RE.finditer(text):
            key = match.group(1)
            line = text.count("\n", 0, match.start()) + 1
            for suffix in ("_1", "_any"):
                if key + suffix not in keys:
                    missing.append((relative, line, key, suffix))
        for match in PLAIN_CALL_RE.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            plain.append((relative, line, match.group(1)))

    for relative, line, key, suffix in missing:
        print(f"[NEW] {relative}:{line} TGLPlural(@\"{key}\") has no \"{key}{suffix}\" entry, so every "
              f"language falls through to the call site's own text")
    for relative, line, key in plain:
        print(f"[NEW] {relative}:{line} TGL(@\"{key}\") reads a runtime plural form directly; use "
              f"TGLPlural on the base key instead")

    if missing or plain:
        print(f"lint-plural-keys: {len(missing)} missing plural entry/entries, "
              f"{len(plain)} plain lookup(s) of a plural form")
        return 1
    print("lint-plural-keys: every TGLPlural key has real _1 and _any entries, and no TGL reads a plural form")
    return 0


if __name__ == "__main__":
    sys.exit(main())
