import re

from tglint import grouped_classes
from tglint import tree

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
        line = tree.line_at(text, match.start())
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


def main(args):
    if "--self-test" in args:
        return self_test()
    found = grouped_classes.grouped_offenders(tree.root_argument(args), offenders_in)
    return tree.report("lint-centred-action-rows", found,
                       "every action in a grouped list is a plate or reads from the leading edge",
                       "%d centred action row(s)")
