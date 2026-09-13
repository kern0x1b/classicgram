#!/usr/bin/env python3
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tg_grouped_classes as grouped_classes

GROUPED = re.compile(r'UITableViewStyleGrouped')
PLAIN = re.compile(r'UITableViewStylePlain')
CENTRED = re.compile(r'\w[\w.]*\.textLabel\.textAlignment\s*=\s*NSTextAlignmentCenter')
ACTION_COLOUR = re.compile(r'groupedActionColour|accentColour')


def offenders_in(path, text, skip_style_check=False):
    if not skip_style_check and (not GROUPED.search(text) or PLAIN.search(text)):
        return []
    found = []
    for match in CENTRED.finditer(text):
        window = text[max(0, match.start() - 400):match.start() + 400]
        if not ACTION_COLOUR.search(window):
            continue
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "centres a row's action in the middle of the row; the 2013 client either "
                      "stands such an action on a plate through [TGIcons actionButtonInCell:...] "
                      "or leaves it reading from the leading edge like every other row"))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    grouped = '\tstyle:UITableViewStyleGrouped\n'
    assert offenders_in(path, grouped +
                        '\tcell.textLabel.textAlignment = NSTextAlignmentCenter;\n'
                        '\tcell.textLabel.textColor = [[TGTheme shared] groupedActionColour];\n'), \
        "a centred blue row must be reported"
    assert not offenders_in(path, grouped +
                            '\tcell.textLabel.textAlignment = TGLocalizedLeadingTextAlignment();\n'
                            '\tcell.textLabel.textColor = [[TGTheme shared] groupedActionColour];\n'), \
        "an action reading from the leading edge passes"
    assert not offenders_in(path, grouped +
                            '\t[TGIcons actionButtonInCell:cell title:title kind:TGActionButtonKindNeutral '
                            'target:self action:@selector(go)];\n'), \
        "the plate passes"
    assert not offenders_in(path, grouped +
                            '\tcell.textLabel.textAlignment = NSTextAlignmentCenter;\n'
                            '\tcell.textLabel.textColor = [[TGTheme shared] secondaryTextColour];\n'), \
        "a centred line that is not an action - a status, an empty list - is not a button"
    print("lint-centred-action-rows: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    texts = grouped_classes.read_tree(root)
    grouped, plain = grouped_classes.style_by_class(texts)
    found = []
    for path, text in sorted(texts.items()):
        if not grouped_classes.file_is_grouped(text, grouped, plain):
            continue
        found += offenders_in(path, text, skip_style_check=True)
    if not found:
        print("lint-centred-action-rows: every action in a grouped list is a plate or reads from "
              "the leading edge")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-centred-action-rows: %d centred action row(s)" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
