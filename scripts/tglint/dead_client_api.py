import collections
import os
import re

from tglint import tree

CLIENT = os.path.join(tree.SRC, "TDLibClient")
BASELINE = os.path.join(tree.ROOT, "scripts", "baselines", "dead-client-api.txt")
DECLARATION = re.compile(r'^[-+]\s*\([^)]*\)\s*(\w+):', re.M)
SEND = re.compile(r'\b([A-Za-z_]\w*):')


def client_headers():
    return [path for path in tree.walk(CLIENT, ".h", skip=())
            if os.path.basename(path).startswith("TGClient+")]


def declarations():
    found = {}
    for path in client_headers():
        text = tree.read(path)
        for match in DECLARATION.finditer(text):
            line = tree.line_at(text, match.start())
            found.setdefault(match.group(1),
                             (tree.relative(path), line))
    return found


def counts():
    sends = collections.Counter()
    defs = collections.Counter()
    for path in tree.walk(tree.SRC):
        text = tree.read(path)
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


def main(args):
    if "--write-baseline" in args:
        names = [name for name, _, _ in dead_families()]
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        open(BASELINE, "w", encoding="utf-8").write("\n".join(names) + "\n")
        print("lint-dead-client-api: wrote %d name(s) to the baseline" % len(names))
        return 0

    baseline = tree.baseline(BASELINE)
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
