#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
SETTER = re.compile(r'-\s*\(void\)set([A-Z]\w*):\s*\([^)]*\)\s*\w+\s*\{')


def body_after(text, start):
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
        i += 1
    return text[start:i]


def offenders():
    found = []
    for dirpath, _, filenames in os.walk(SRC):
        for name in filenames:
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8", errors="replace") as handle:
                text = handle.read()
            for match in SETTER.finditer(text):
                prop = match.group(1)
                lower = prop[0].lower() + prop[1:]
                body = body_after(text, match.end())
                assign = re.compile(r'self\.%s\s*=(?!=)' % re.escape(lower))
                if assign.search(body):
                    line = text[: match.start()].count("\n") + 1
                    found.append((os.path.relpath(path, ROOT), line, prop))
    return found


def main():
    found = offenders()
    if not found:
        print("lint-recursive-setters: no setter assigns through its own property")
        return 0

    print("lint-recursive-setters: %d setter(s) call themselves; each one ends the "
          "process with a stack overflow the first time it runs" % len(found))
    for path, line, prop in found:
        print("  %s:%d set%s: assigns self.%s%s"
              % (path, line, prop, prop[0].lower(), prop[1:]))
    return 1


if __name__ == "__main__":
    sys.exit(main())
