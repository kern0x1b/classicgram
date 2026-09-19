import re

from tglint import tree

CALL = re.compile(r'\bTGL\(\s*@"((?:[^"\\]|\\.)*)"')
SPECIFIER = re.compile(r'%(?:\d+\$)?[-+ #0]*[0-9]*\.?[0-9]*(?:ld|lld|d|@|s|f|u|C)')
FORMATTERS = ("stringWithFormat", "appendFormat", "initWithFormat",
              "localizedStringWithFormat", "stringByAppendingFormat")
COMPARISONS = ("==", "!=", "<=", ">=")
ESCAPE = re.compile(r'\\\\u[0-9a-fA-F]{4}')
FORMAT_CALL = re.compile(
    r'(?:stringWithFormat|initWithFormat|appendFormat|stringByAppendingFormat):\s*'
    r'TGL\(\s*@"((?:[^"\\]|\\.)*)"\s*,\s*@"(?:[^"\\]|\\.)*"\s*\)(\s*,)?', re.S)
PLURAL_AS_FORMAT = re.compile(
    r'(?:stringWithFormat|initWithFormat|appendFormat|stringByAppendingFormat):\s*TGLPlural\(', re.S)
ARGUMENT_SPECIFIER = re.compile(
    r'%(?:(\d+)\$)?[-+ #0]*[0-9]*\.?[0-9]*(?:hh|h|ll|l|q|L|z|t|j)?([diouxXeEfgGaAcsp@%])')


def specifier_count(value):
    plain = 0
    positional = 0
    for match in ARGUMENT_SPECIFIER.finditer(value):
        if match.group(2) == "%":
            continue
        if match.group(1):
            positional = max(positional, int(match.group(1)))
        else:
            plain += 1
    return max(plain, positional)


def argument_count(text, start, had_comma):
    depth = 0
    count = 1 if had_comma else 0
    index = start
    while index < len(text):
        character = text[index]
        if character in "([{":
            depth += 1
        elif character in ")}":
            depth -= 1
        elif character == "]":
            if depth == 0:
                break
            depth -= 1
        elif character == "," and depth == 0:
            count += 1
        index += 1
    return count


def arity_offenders_in(path, text, table):
    found = []
    for match in FORMAT_CALL.finditer(text):
        key = match.group(1)
        value = table.get(key)
        if value is None:
            continue
        wanted = specifier_count(value)
        passed = argument_count(text, match.end(), match.group(2) is not None)
        if wanted == passed:
            continue
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      '%s takes %d argument(s), the call passes %d'
                      % (key, wanted, passed)))
    for match in PLURAL_AS_FORMAT.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "a TGLPlural string already carries its count and must not be "
                      "formatted again"))
    return found


def kept_in_a_variable(before):
    for comparison in COMPARISONS:
        before = before.replace(comparison, "")
    return "=" in before


def statements(text):
    statement = []
    first = 1
    for index, line in enumerate(text.split("\n")):
        if not statement:
            first = index + 1
        statement.append(line)
        if ";" in line:
            yield first, "\n".join(statement)
            statement = []
    if statement:
        yield first, "\n".join(statement)


def offenders_in(path, text, table):
    found = []
    for line, statement in statements(text):
        if any(name in statement for name in FORMATTERS):
            continue
        for match in CALL.finditer(statement):
            key = match.group(1)
            value = table.get(key)
            if not value or not SPECIFIER.search(value):
                continue
            if kept_in_a_variable(statement[:match.start()]):
                continue
            found.append((path, line, key, value.split("\n")[0]))
    return found


def escapes_in(path, text):
    return [(path, index + 1, line.strip())
            for index, line in enumerate(text.split("\n")) if ESCAPE.search(line)]


def self_test():
    table = tree.strings_table('"A.Key" = "Delete %@?";\n"B.Key" = "Delete";\n')
    screen = "src/Screens/Stories/TGStoryListViewController.m"
    assert offenders_in(screen, '\tmessage:TGL(@"A.Key", @"Delete this?")\n;', table), \
        "a table string that needs an argument must be formatted"
    assert not offenders_in(
        screen,
        '\tmessage:[NSString stringWithFormat:TGL(@"A.Key", @"Delete %@?"), name];\n',
        table), "formatting it is what the rule asks for"
    assert not offenders_in(screen, '\tNSString *format = choice\n\t\t? TGL(@"A.Key", @"Delete %@?")\n\t\t: nil;\n',
                            table), "a format kept in a variable is formatted elsewhere"
    assert not offenders_in(screen,
                            '\tif (choice == 1)\n\t\tformat = TGL(@"A.Key", @"Delete %@?");\n',
                            table), "so is one assigned inside a branch"
    assert not offenders_in(screen, '\tmessage:TGL(@"B.Key", @"Delete");\n', table), \
        "a string with no specifier needs no argument"
    assert escapes_in("en.lproj/Localizable.strings", '"K" = "\\\\u00d7";\n'), \
        "a literal unicode escape in a strings value must be reported"
    arity_table = tree.strings_table('"C.Key" = "%1$@ gave %2$@ a gift";\n"D.Key" = "Deleted";\n')
    assert arity_offenders_in(screen,
                              '\t[NSString stringWithFormat:TGL(@"C.Key", @"x"), name];\n',
                              arity_table), "a call that passes too few arguments must be reported"
    assert not arity_offenders_in(
        screen, '\t[NSString stringWithFormat:TGL(@"C.Key", @"x"), name, gift];\n',
        arity_table), "the right number of arguments passes"
    assert arity_offenders_in(screen,
                              '\t[NSString stringWithFormat:TGL(@"D.Key", @"x"), name];\n',
                              arity_table), "so does an argument the string has no place for"
    assert arity_offenders_in(
        screen, '\ttitle = [NSString stringWithFormat:TGLPlural(@"E.Key", 2, @"%d", @"%d"), 2];\n',
        arity_table), "a plural string is already substituted and must not be formatted again"
    assert not escapes_in("en.lproj/Localizable.strings", '"K" = "×";\n'), \
        "the character itself is what the table should hold"
    print("lint-format-arguments: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    root = tree.root_argument(args)
    table = tree.english_table()
    found = []
    arity = []
    escapes = []
    for path in tree.walk(root):
        body = tree.read(path)
        found += offenders_in(path, body, table)
        arity += arity_offenders_in(path, body, table)
    for path in tree.walk(root, "Localizable.strings", skip=()):
        escapes += escapes_in(path, tree.read(path))
    for path, line, key, value in found:
        print('%s:%d shows "%s" unformatted: %s' % (path, line, key, value))
    for path, line, reason in arity:
        print("%s:%d %s" % (path, line, reason))
    for path, line, value in escapes:
        print("%s:%d holds a literal unicode escape: %s" % (path, line, value))
    if found or arity or escapes:
        print("lint-format-arguments: %d unformatted, %d miscounted, %d escaped"
              % (len(found), len(arity), len(escapes)))
        return 1
    print("lint-format-arguments: every table string that needs an argument gets one")
    return 0
