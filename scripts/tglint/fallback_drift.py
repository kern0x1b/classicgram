import re

from tglint import tree

CALL = re.compile(r'\bTGL\(\s*@"((?:[^"\\]|\\.)*)"\s*,\s*((?:@"(?:[^"\\]|\\.)*"\s*)+)\)', re.S)
PIECE = re.compile(r'@"((?:[^"\\]|\\.)*)"', re.S)


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
        line = tree.line_at(text, match.start())
        found.append((path, line, key, fallback, source_form(value)))
    return found


def self_test():
    table = tree.strings_table('"A.Key" = "Log Out";\n"B.Key" = "Tap here\nto sign in";\n')
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


def main(args):
    if "--self-test" in args:
        return self_test()
    root = tree.root_argument(args)
    table = tree.english_table()
    found = []
    for path in tree.walk(root, tree.IMPLEMENTATION_AND_HEADERS):
        found += offenders_in(path, tree.read(path), table)
    if not found:
        print("lint-fallback-drift: every TGL fallback says what the English table says")
        return 0
    for path, line, key, fallback, value in found:
        print('%s:%d %s\n    code : %s\n    table: %s' % (path, line, key, fallback, value))
    print("lint-fallback-drift: %d fallback(s) the table disagrees with" % len(found))
    return 1
