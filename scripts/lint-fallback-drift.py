#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "src", "Resources", "Localization", "en.lproj",
                       "Localizable.strings")
ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', re.M | re.S)
CALL = re.compile(r'\bTGL\(\s*@"((?:[^"\\]|\\.)*)"\s*,\s*((?:@"(?:[^"\\]|\\.)*"\s*)+)\)', re.S)
PIECE = re.compile(r'@"((?:[^"\\]|\\.)*)"', re.S)


def table_from(text):
    return {m.group(1): m.group(2) for m in ENTRY.finditer(text)}


def source_form(value):
    return value.replace("\n", "\\n")


def offenders_in(path, text, table):
    found = []
    for match in CALL.finditer(text):
        key = match.group(1)
        fallback = "".join(PIECE.findall(match.group(2)))
        value = table.get(key)
        if value is None or source_form(value) == fallback:
            continue
        line = text[:match.start()].count("\n") + 1
        found.append((path, line, key, fallback, source_form(value)))
    return found


def self_test():
    table = table_from('"A.Key" = "Log Out";\n"B.Key" = "Tap here\nto sign in";\n')
    path = "src/Screens/Settings/TGSettingsViewController+Rows.m"
    assert offenders_in(path, '\tTGL(@"A.Key", @"Log out")\n', table), \
        "a fallback the table disagrees with must be reported"
    assert not offenders_in(path, '\tTGL(@"A.Key", @"Log Out")\n', table), \
        "the table's own words must pass"
    assert not offenders_in(path, '\tTGL(@"B.Key", @"Tap here\\nto sign in")\n', table), \
        "a table row broken over lines is the same string escaped"
    assert not offenders_in(path, '\tTGL(@"C.Key", @"Anything")\n', table), \
        "a key the table does not define yet is another rule's business"
    assert not offenders_in(path, '\tTGL(@"A.Key", @"Log "\n\t\t@"Out")\n', table), \
        "a fallback written as two literals is one string"
    assert offenders_in(path, '\tTGL(@"A.Key", @"Log "\n\t\t@"out")\n', table), \
        "and it is reported when the halves together disagree"
    print("lint-fallback-drift: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    table = table_from(open(STRINGS, encoding="utf-8").read())
    found = []
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm", ".h")):
                continue
            path = os.path.join(base, name)
            found += offenders_in(
                path, open(path, encoding="utf-8", errors="replace").read(), table)
    if not found:
        print("lint-fallback-drift: every TGL fallback says what the English table says")
        return 0
    for path, line, key, fallback, value in found:
        print('%s:%d %s\n    code : %s\n    table: %s' % (path, line, key, fallback, value))
    print("lint-fallback-drift: %d fallback(s) the table disagrees with" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
