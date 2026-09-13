#!/usr/bin/env python3
import os
import re
import sys

READ = re.compile(r'(?<!@)\[\s*@"([a-z][A-Za-z0-9]*)"\s*\]')
FROM_JSON = re.compile(r'JSONObjectWithData')
WRITES = (
    re.compile(r'@"([a-z][A-Za-z0-9]*)"\s*:'),
    re.compile(r'\w\s*\[\s*@"([a-z][A-Za-z0-9]*)"\s*\]\s*='),
    re.compile(r'forKey:\s*@"([a-z][A-Za-z0-9]*)"'),
    re.compile(r',\s*@"([a-z][A-Za-z0-9]*)"'),
    re.compile(r'\(\s*\w+\s*,\s*@"([a-z][A-Za-z0-9]*)"'),
)
SKIP_FILES = ("TGLottieView",)


def schema_fields(path):
    if not path or not os.path.exists(path):
        return set()
    return set(re.findall(r'(\w+):[\w<>\.]+', open(path, encoding="utf-8", errors="replace").read()))


def load_baseline(path):
    if not path or not os.path.exists(path):
        return set()
    return set(line.split("#")[0].strip() for line in open(path, encoding="utf-8")
               if line.split("#")[0].strip())


def scan(root, schema, baseline=frozenset()):
    written = set()
    read = {}
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm", ".h")):
                continue
            path = os.path.join(base, name)
            text = open(path, encoding="utf-8", errors="replace").read()
            for pattern in WRITES:
                written.update(pattern.findall(text))
            if not name.endswith((".m", ".mm")):
                continue
            if any(part in name for part in SKIP_FILES):
                continue
            parses_json = FROM_JSON.search(text) is not None
            for match in READ.finditer(text):
                key = match.group(1)
                if key in schema or len(key) < 4 or key in baseline:
                    continue
                if parses_json:
                    continue
                read.setdefault(key, (path, text[:match.start()].count("\n") + 1))
    return [(path, line, key) for key, (path, line) in sorted(read.items()) if key not in written]


def self_test():
    written = set()
    for pattern in WRITES:
        written.update(pattern.findall('@{@"alpha" : @1}\n out[@"beta"] = @2;\n'
                                       '[d setObject:@3 forKey:@"gamma"];\n'
                                       '[[NSMutableDictionary alloc] initWithObjectsAndKeys:@4, @"delta", nil];\n'
                                       'TGWLSetString(out, @"epsilon", raw);\n'))
    for key in ("alpha", "beta", "gamma", "delta", "epsilon"):
        assert key in written, "a key written as %s must count as written" % key
    assert READ.findall('x = row[@"zeta"];') == ["zeta"], "a plain read is a read"
    assert READ.findall('kinds = @[ @"eta" ];') == [], \
        "a one-element array literal is a value, not a key being read"
    print("lint-unset-dictionary-keys: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "src"
    schema_path = args[1] if len(args) > 1 else None
    baseline_path = args[2] if len(args) > 2 else "scripts/baselines/unset-dictionary-keys.txt"
    found = scan(root, schema_fields(schema_path), load_baseline(baseline_path))
    if not found:
        print("lint-unset-dictionary-keys: every dictionary key a screen reads is written "
              "somewhere, bar the ones the baseline names")
        return 0
    for path, line, key in found:
        print('%s:%d reads @"%s", which nothing in the tree ever writes, so it is always nil'
              % (path, line, key))
    print("lint-unset-dictionary-keys: %d key(s) read but never written" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
