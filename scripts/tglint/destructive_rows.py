import re

from tglint import tree

DESTRUCTIVE_LABEL = re.compile(
    r'\w+\.textLabel\.textColor\s*=\s*[^;]{0,200}?groupedDestructiveColour', re.S)
GROUPED = re.compile(r'UITableViewStyleGrouped')


VALUE_SHOWN = re.compile(r'\.detailTextLabel\.text\s*=\s*(?!nil|@"")')


def shows_a_value_near(text, position):
    window = text[max(0, position - 600):position + 600]
    return VALUE_SHOWN.search(window) is not None


def classes_in(text):
    return set(re.findall(r'^@implementation\s+(\w+)', text, re.M))


def offenders_in(path, text, grouped_classes=None):
    if not GROUPED.search(text):
        if grouped_classes is None or not (classes_in(text) & grouped_classes):
            return []
    found = []
    for match in DESTRUCTIVE_LABEL.finditer(text):
        if shows_a_value_near(text, match.start()):
            continue
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "paints a row's own label red; a destructive action in a grouped list is the "
                      "red plate through [TGIcons actionButtonInCell:...], not red text on a row"))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    grouped = '\tstyle:UITableViewStyleGrouped\n'
    assert offenders_in(path, grouped +
                        '\tcell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];\n'), \
        "a red row label must be reported"
    assert offenders_in(path, grouped +
                        '\tcell.textLabel.textColor = [theme groupedDestructiveColour];\n'), \
        "the shorthand through a local theme variable is the same defect"
    assert offenders_in(path, grouped +
                        '\tcell.textLabel.textColor = cancelling ? [[TGTheme shared] groupedActionColour]\n'
                        '\t\t\t\t\t\t\t\t\t\t\t\t : [[TGTheme shared] groupedDestructiveColour];\n'), \
        "a row that is red only in one of its two states is still a red row"
    assert not offenders_in(path, grouped +
                            '\t[TGIcons actionButtonInCell:cell title:title kind:TGActionButtonKindDestructive '
                            'target:self action:@selector(go)];\n'), \
        "the red plate passes"
    assert not offenders_in(path,
                            '\tstyle:UITableViewStylePlain\n'
                            '\tcell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];\n'), \
        "a plain list is not the grouped settings look and is left alone"
    assert not offenders_in(path, grouped +
                            '\tcell.detailTextLabel.text = action[@"value"];\n'
                            '\tcell.textLabel.textColor = [[TGTheme shared] groupedDestructiveColour];\n'), \
        "a row that carries a value on its right is a variant row, not a plate, and keeps red text"
    print("lint-destructive-rows: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    args = [a for a in args if not a.startswith("--")]
    root = args[0] if args else "src"
    baseline_path = args[1] if len(args) > 1 else "scripts/baselines/destructive-rows.txt"
    baseline = tree.baseline(baseline_path)
    texts = tree.texts(root)
    grouped_classes = set()
    for path, text in texts.items():
        if GROUPED.search(text):
            grouped_classes |= classes_in(text)
    found = []
    for path, text in sorted(texts.items()):
        if tree.slashed(path) in baseline:
            continue
        found += offenders_in(path, text, grouped_classes)
    return tree.report("lint-destructive-rows", found,
                       "every destructive action in a grouped list is the red plate, bar the "
                       "sections the baseline names",
                       "%d red row label(s)")
