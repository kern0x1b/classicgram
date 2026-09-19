import os
import re

from tglint import tree

WHITE_BACKGROUND = re.compile(
    r'self\.(?:view|tableView)\.backgroundColor\s*=\s*\[UIColor whiteColor\]')


def offenders_in(path, text, baseline):
    normalised = path.replace(os.sep, "/")
    if normalised in baseline:
        return []
    found = []
    for match in WHITE_BACKGROUND.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "paints a screen's own background white by hand; the colour a list stands "
                      "on is the theme's, so one change reaches every screen"))
    return found


def self_test():
    path = "src/Screens/Chat/TGExampleViewController.m"
    assert offenders_in(path, "\tself.view.backgroundColor = [UIColor whiteColor];\n", set()), \
        "a hand-painted white screen background must be reported"
    assert offenders_in(path, "\tself.tableView.backgroundColor = [UIColor whiteColor];\n", set()), \
        "and so must a hand-painted table background"
    assert not offenders_in(path,
                            "\tself.view.backgroundColor = [[TGTheme shared] listBackgroundColour];\n",
                            set()), \
        "the theme's colour passes"
    assert not offenders_in(path, "\tcell.backgroundColor = [UIColor whiteColor];\n", set()), \
        "a cell is not a screen background and has its own fence"
    assert not offenders_in(path, "\tself.view.backgroundColor = [UIColor whiteColor];\n",
                            {path}), \
        "a screen the baseline names is left alone"
    print("lint-screen-backgrounds: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    args = [a for a in args if not a.startswith("--")]
    root = args[0] if args else "src"
    baseline = tree.baseline(args[1] if len(args) > 1
                             else "scripts/baselines/screen-backgrounds.txt")
    found = []
    for path in tree.walk(root):
        found += offenders_in(path, tree.read(path), baseline)
    return tree.report("lint-screen-backgrounds", found,
                       "every screen takes its background from the theme, bar the ones the "
                       "baseline names",
                       "%d screen background(s) painted by hand")
