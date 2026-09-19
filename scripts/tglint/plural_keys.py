import re

from tglint import tree

PLURAL_CALL_RE = re.compile(r'TGLPlural\(\s*@"([^"]+)"')
PLAIN_CALL_RE = re.compile(r'TGL\(\s*@"([^"]+(?:_1|_any))"')
ENTRY_RE = re.compile(r'^"([^"]+)"\s*=', re.M)


def main(args):
    table = tree.read(tree.ENGLISH_STRINGS)
    keys = set(ENTRY_RE.findall(table))

    missing = []
    plain = []
    for path in tree.walk(tree.SRC):
        text = tree.read(path)
        relative = tree.relative(path)
        for match in PLURAL_CALL_RE.finditer(text):
            key = match.group(1)
            line = tree.line_at(text, match.start())
            for suffix in ("_1", "_any"):
                if key + suffix not in keys:
                    missing.append((relative, line, key, suffix))
        for match in PLAIN_CALL_RE.finditer(text):
            line = tree.line_at(text, match.start())
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
