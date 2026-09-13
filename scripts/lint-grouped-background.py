#!/usr/bin/env python3
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tg_grouped_classes as grouped_classes

GROUPED = re.compile(r'UITableViewStyleGrouped')
PLAIN = re.compile(r'UITableViewStylePlain')
LIST_COLOUR = re.compile(
    r'(?:self\.)?tableView\.backgroundColor\s*=\s*\[\s*(?:\[TGTheme shared\]|theme)\s+listBackgroundColour\s*\]')
PLAIN_HAIRLINE = re.compile(
    r'separatorColor\s*=\s*\[\s*(?:\[TGTheme shared\]|theme)\s+separatorColour\s*\]')
OWN_TILE = re.compile(r'imageNamed:@"SettingsBackground(?:\.png)?"')


def offenders_in(path, text, skip_style_check=False):
    if path.endswith("TGListBackground.m"):
        return []
    found = []
    for match in OWN_TILE.finditer(text):
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "reaches for the settings tile itself; the one place that decides what a "
                      "grouped list stands on is TGGroupedListBackground"))
    if not skip_style_check and (not GROUPED.search(text) or PLAIN.search(text)):
        return found
    for match in LIST_COLOUR.finditer(text):
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "stands a grouped list on the theme's plain list colour; a grouped list "
                      "stands on the settings tile through TGGroupedListBackground"))
    for match in PLAIN_HAIRLINE.finditer(text):
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "rules a grouped list with the plain hairline; the grouped lists are ruled "
                      "in groupedSeparatorColour, which is the bluer line of the original"))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    grouped = '\tself = [super initWithStyle:UITableViewStyleGrouped];\n'
    assert offenders_in(path, grouped +
                        '\tself.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];\n'), \
        "a grouped list left on the plain list colour must be reported"
    assert offenders_in(path, grouped +
                        '\tself.tableView.backgroundColor = [theme listBackgroundColour];\n'), \
        "the shorthand through a local theme variable is the same defect"
    assert not offenders_in(path, grouped +
                            '\tself.tableView.backgroundColor = TGGroupedListBackground();\n'), \
        "the shared tile passes"
    assert not offenders_in("src/Screens/ChatList/TGChatListViewController.m",
                            '\tUITableView *table = [[UITableView alloc] initWithFrame:CGRectZero '
                            'style:UITableViewStylePlain];\n'
                            '\ttable.backgroundColor = [[TGTheme shared] listBackgroundColour];\n'), \
        "a plain list is white, as it always was"
    assert offenders_in(path, grouped +
                        '\tself.tableView.separatorColor = [[TGTheme shared] separatorColour];\n'), \
        "a grouped list ruled with the plain hairline must be reported"
    assert not offenders_in(path, grouped +
                            '\tself.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];\n'), \
        "the grouped hairline passes"
    assert offenders_in(path, '\tUIImage *tile = [UIImage imageNamed:@"SettingsBackground.png"];\n'), \
        "a screen building the tiled colour of its own must be reported"
    print("lint-grouped-background: self-test passed")
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
        print("lint-grouped-background: every grouped list stands on the settings tile and is ruled "
              "with the grouped hairline, and one place decides what the tile is")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-grouped-background: %d grouped list(s) out of the grouped look" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
