#!/usr/bin/env python3
import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
CLIENT = os.path.join(SRC, "TDLibClient")
BASELINE = os.path.join(ROOT, "scripts", "baselines", "dead-client-api.txt")
DECLARATION = re.compile(r'^[-+]\s*\([^)]*\)\s*(\w+):', re.M)
SEND = re.compile(r'\b([A-Za-z_]\w*):')


def client_headers():
    names = []
    for base, _, files in os.walk(CLIENT):
        for name in sorted(files):
            if name.startswith("TGClient+") and name.endswith(".h"):
                names.append(os.path.join(base, name))
    return names


def declarations():
    found = {}
    for path in client_headers():
        text = open(path, encoding="utf-8", errors="replace").read()
        for match in DECLARATION.finditer(text):
            line = text[:match.start()].count("\n") + 1
            found.setdefault(match.group(1),
                             (os.path.relpath(path, ROOT), line))
    return found


def counts():
    sends = collections.Counter()
    defs = collections.Counter()
    for base, _, files in os.walk(SRC):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(files):
            if not name.endswith((".m", ".mm")):
                continue
            text = open(os.path.join(base, name), encoding="utf-8", errors="replace").read()
            for match in SEND.finditer(text):
                sends[match.group(1)] += 1
            for match in DECLARATION.finditer(text):
                defs[match.group(1)] += 1
    return sends, defs


def dead_families():
    sends, defs = counts()
    out = []
    for name, (path, line) in sorted(declarations().items()):
        if sends[name] - defs[name] <= 0:
            out.append((name, path, line))
    return out


def load_baseline():
    if not os.path.isfile(BASELINE):
        return set()
    return {line.strip() for line in open(BASELINE, encoding="utf-8") if line.strip()}


def main():
    if "--write-baseline" in sys.argv:
        names = [name for name, _, _ in dead_families()]
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        open(BASELINE, "w", encoding="utf-8").write("\n".join(names) + "\n")
        print("lint-dead-client-api: wrote %d name(s) to the baseline" % len(names))
        return 0

    baseline = load_baseline()
    dead = dead_families()
    fresh = [row for row in dead if row[0] not in baseline]
    for name, path, line in fresh:
        print("[NEW] %s:%d %s is declared on TGClient and nothing ever sends it" % (path, line, name))
    if fresh:
        print("lint-dead-client-api: %d new method(s) nothing calls; delete them rather than "
              "adding them to the baseline" % len(fresh))
        return 1
    print("lint-dead-client-api: no new dead client API (%d known, none added)" % len(dead))
    return 0


if __name__ == "__main__":
    sys.exit(main())
