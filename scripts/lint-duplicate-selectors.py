#!/usr/bin/env python3
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
if not os.path.isdir(SRC):
    raise SystemExit(f"source root not found: {SRC}")

SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc")

GROUP_RE = re.compile(r'^([A-Za-z0-9_]+?)(?:\+[A-Za-z0-9_]+)?\.m$')
METHOD_START_RE = re.compile(r'^\s*[-+]\s*\(')
IMPLEMENTATION_RE = re.compile(r'^\s*@implementation\s+([A-Za-z0-9_]+)')
END_RE = re.compile(r'^\s*@end\b')
WHITESPACE_RE = re.compile(r'\s+')


def group_key(filename):
    match = GROUP_RE.match(filename)
    return match.group(1) if match else None


def signatures(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        lines = handle.read().split("\n")
    out = []
    current_class = None
    i = 0
    while i < len(lines):
        impl_match = IMPLEMENTATION_RE.match(lines[i])
        if impl_match:
            current_class = impl_match.group(1)
        elif END_RE.match(lines[i]):
            current_class = None
        elif current_class and METHOD_START_RE.match(lines[i]):
            j = i
            while '{' not in lines[j] and ';' not in lines[j] and j + 1 < len(lines):
                j += 1
            if '{' in lines[j]:
                joined = ' '.join(l.split('{')[0] for l in lines[i:j + 1])
                out.append((current_class, WHITESPACE_RE.sub(' ', joined).strip(), i + 1))
            i = j
        i += 1
    return out


def implementation_files():
    paths = []
    for dirpath, dirnames, filenames in os.walk(SRC):
        relparts = os.path.relpath(dirpath, SRC).split(os.sep)
        if any(part in SKIP_DIRS for part in relparts):
            dirnames[:] = []
            continue
        for name in sorted(filenames):
            if name.endswith(".m") or name.endswith(".mm"):
                paths.append(os.path.relpath(os.path.join(dirpath, name), ROOT))
    return paths


def find_duplicates():
    seen = {}
    for path in implementation_files():
        for class_name, sig, line in signatures(os.path.join(ROOT, path)):
            seen.setdefault((class_name, sig), []).append((path, line))
    duplicates = []
    for (class_name, sig), hits in sorted(seen.items()):
        if len(hits) > 1:
            duplicates.append((class_name, sig, hits))
    return duplicates


def self_test():
    import tempfile

    body = ("@implementation TGProbe\n"
            "- (void)twice {\n}\n"
            "- (void)twice {\n}\n"
            "- (void)once {\n}\n"
            "@end\n")
    clean = ("@implementation TGProbe\n"
             "- (void)once {\n}\n"
             "@end\n")
    with tempfile.TemporaryDirectory() as directory:
        path = os.path.join(directory, "TGSomethingElse.m")
        open(path, "w", encoding="utf-8").write(body)
        found = signatures(path)
        names = [sig for _, sig, _ in found]
        assert names.count("- (void)twice") == 2, \
            "a selector defined twice in one file must be seen twice, even when the file " \
            "is not named after the class"
        open(path, "w", encoding="utf-8").write(clean)
        found = signatures(path)
        assert len(found) == 1, "a class that defines each selector once has no duplicate"
        assert found[0][0] == "TGProbe", "the class is taken from @implementation, not the file name"
    print("lint-duplicate-selectors: self-test passed")
    return 0


def format_entry(class_name, sig):
    return "%s | %s" % (class_name, sig)


def load_baseline(path):
    if not os.path.isfile(path):
        return set()
    with open(path, encoding="utf-8") as handle:
        return {line.rstrip("\n") for line in handle if line.strip()}


def main():
    if "--self-test" in sys.argv:
        return self_test()
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--baseline",
        default=os.path.join(ROOT, "scripts", "baselines", "duplicate-selectors.txt"),
    )
    args = parser.parse_args()

    baseline = load_baseline(args.baseline)
    duplicates = find_duplicates()

    new_found = False
    for class_name, sig, hits in duplicates:
        entry = format_entry(class_name, sig)
        marker = "" if entry in baseline else " [NEW]"
        if marker:
            new_found = True
        print("%s%s" % (entry, marker))
        for path, line in hits:
            print("  %s:%d" % (path, line))

    if not duplicates:
        print("lint-duplicate-selectors: no class defines the same selector twice, "
              "wherever the parts of that class live")
        return 0

    if new_found:
        print("commit refused: a class implements the same selector twice; only one "
              "@implementation of a selector runs at "
              "runtime for a given class, so this always shadows the other "
              "(see the [NEW] lines above); a baseline entry may be added only "
              "for a deliberate case, such as an intentional +load-time swizzle")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
