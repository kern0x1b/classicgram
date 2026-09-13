#!/usr/bin/env python3
import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc", "Resources")
PROPERTY_RE = re.compile(r"@property\s*\(([^)]*)\)\s*[\w\s\*<>,]+?\**(\w+)\s*;")
METHOD_RE = re.compile(r"^[-+]\s*\([\w\s\*<>]+\)\s*(\w+)\s*;$")
SIGNATURE_RE = re.compile(r"^[-+]\s*\([\w\s\*<>]+\)\s*(\w+)\s*[;{]?\s*$")
GETTER_RE = re.compile(r"getter\s*=\s*(\w+)")
WORD_RE = re.compile(r"[A-Za-z_]\w*")


def sources():
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if name.endswith((".m", ".mm", ".h")):
                yield os.path.join(root, name)


def baseline(path):
    if not path or not os.path.isfile(path):
        return set()
    entries = set()
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            entries.add(line)
    return entries


def main():
    known = baseline(sys.argv[sys.argv.index("--baseline") + 1]
                     if "--baseline" in sys.argv else None)
    words = collections.Counter()
    declarations = []
    methods = []
    signatures = collections.Counter()
    for path in sources():
        text = open(path, encoding="utf-8", errors="replace").read()
        words.update(WORD_RE.findall(text))
        for line in text.split("\n"):
            signature = SIGNATURE_RE.match(line.strip())
            if signature:
                signatures[signature.group(1)] += 1
        if not path.endswith(".h"):
            continue
        for number, line in enumerate(text.split("\n"), 1):
            match = PROPERTY_RE.match(line.strip())
            if match:
                getter = GETTER_RE.search(match.group(1))
                declarations.append((path, number, match.group(2),
                                     getter.group(1) if getter else None))
                continue
            method = METHOD_RE.match(line.strip())
            if method:
                methods.append((path, number, method.group(1)))

    dead = []
    for path, number, name, getter in declarations:
        capitalised = name[0].upper() + name[1:]
        spellings = [name, "_" + name, "set" + capitalised]
        if getter:
            spellings.append(getter)
        if sum(words[spelling] for spelling in spellings) > 1:
            continue
        relative = os.path.relpath(path, ROOT)
        if f"{relative} {name}" in known:
            continue
        dead.append((relative, number, name))

    for path, number, name in methods:
        if words[name] - signatures[name] > 0:
            continue
        relative = os.path.relpath(path, ROOT)
        if f"{relative} {name}" in known:
            continue
        dead.append((relative, number, name))

    for path, number, name in dead:
        print(f"[NEW] {path}:{number} declares \"{name}\" and nothing ever calls, reads or writes it")
    if dead:
        print(f"lint-dead-declarations: {len(dead)} declaration(s) nothing uses")
        return 1
    print(f"lint-dead-declarations: every one of {len(declarations)} declared properties "
          f"and {len(methods)} argument-less methods is used")
    return 0


if __name__ == "__main__":
    sys.exit(main())
