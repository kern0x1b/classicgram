import re

from tglint import grouped_classes
from tglint import tree

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
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "reaches for the settings tile itself; the one place that decides what a "
                      "grouped list stands on is TGGroupedListBackground"))
    if not skip_style_check and (not GROUPED.search(text) or PLAIN.search(text)):
        return found
    for match in LIST_COLOUR.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "stands a grouped list on the theme's plain list colour; a grouped list "
                      "stands on the settings tile through TGGroupedListBackground"))
    for match in PLAIN_HAIRLINE.finditer(text):
        line = tree.line_at(text, match.start())
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


def main(args):
    if "--self-test" in args:
        return self_test()
    found = grouped_classes.grouped_offenders(tree.root_argument(args), offenders_in)
    return tree.report("lint-grouped-background", found,
                       "every grouped list stands on the settings tile and is ruled with the "
                       "grouped hairline, and one place decides what the tile is",
                       "%d grouped list(s) out of the grouped look")
