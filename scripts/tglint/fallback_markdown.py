import re

from tglint import tree

LITERAL = re.compile(r'@"[^"\\]*\*\*[^"]*"')


def offenders(root):
    found = []
    for path in tree.walk(root, tree.IMPLEMENTATION_AND_HEADERS, skip=()):
        for number, line in enumerate(tree.read(path).split("\n"), 1):
            if LITERAL.search(line):
                found.append((path, number, line.strip()))
    return found


def main(args):
    root = tree.root_argument(args)
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
