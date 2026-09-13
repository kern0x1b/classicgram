#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")

SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc")

INTERFACE_RE = re.compile(r'^@(interface|protocol)\b')
END_RE = re.compile(r'^@end\b')
DECLARATION_RE = re.compile(r'^[-+]\s*\(')
WHITESPACE_RE = re.compile(r'\s+')


def headers():
    for root, dirs, names in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(names):
            if name.endswith(".h"):
                yield os.path.join(root, name)


def blocks(lines):
    spans = []
    start = None
    for index, line in enumerate(lines):
        if INTERFACE_RE.match(line):
            start = index
        elif END_RE.match(line) and start is not None:
            spans.append((start, index))
            start = None
    return spans


def declarations(lines, low, high):
    found = []
    index = low
    while index < high:
        if DECLARATION_RE.match(lines[index]):
            end = index
            while ";" not in lines[end] and end + 1 < high:
                end += 1
            joined = " ".join(lines[index:end + 1])
            found.append((index + 1, WHITESPACE_RE.sub(" ", joined).strip()))
            index = end
        index += 1
    return found


def main():
    offenders = []
    for header in headers():
        lines = open(header, encoding="utf-8", errors="replace").read().split("\n")
        for low, high in blocks(lines):
            seen = {}
            for line_number, text in declarations(lines, low, high):
                if text in seen:
                    offenders.append((header, seen[text], line_number, text))
                else:
                    seen[text] = line_number
    if offenders:
        for header, first, repeat, text in offenders:
            relative = os.path.relpath(header, ROOT)
            print(f"[NEW] {relative}:{repeat} repeats the declaration first made at line {first}: {text}")
        print(f"lint-duplicate-declarations: {len(offenders)} duplicate declaration(s)")
        return 1
    print("lint-duplicate-declarations: no interface declares the same method twice")
    return 0


if __name__ == "__main__":
    sys.exit(main())
