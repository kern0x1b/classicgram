#!/usr/bin/env python3
import os
import re
import sys

LITERAL = re.compile(r'@"[^"\\]*\*\*[^"]*"')


def offenders(root):
    found = []
    for base, _, files in os.walk(root):
        for name in files:
            if not name.endswith((".m", ".mm", ".h")):
                continue
            path = os.path.join(base, name)
            with open(path, encoding="utf-8", errors="replace") as handle:
                for number, line in enumerate(handle, 1):
                    if LITERAL.search(line):
                        found.append((path, number, line.strip()))
    return found


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = offenders(root)
    if not found:
        print("lint-fallback-markdown: no ** markdown in any string literal in %s" % root)
        return 0
    for path, number, line in found:
        print("%s:%d carries ** markdown that nothing in this app renders" % (path, number))
        print("    %s" % line[:160])
    print("a plain UILabel, UIAlertView and TGSnackbar all print ** literally; write the "
          "fallback the way the string table ships it")
    return 1


if __name__ == "__main__":
    sys.exit(main())
