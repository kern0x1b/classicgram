#!/usr/bin/env python3
import os
import re
import sys

WHITE_BACKGROUND = re.compile(
    r'self\.(?:view|tableView)\.backgroundColor\s*=\s*\[UIColor whiteColor\]')


def load_baseline(path):
    if not path or not os.path.exists(path):
        return set()
    return set(line.split("#")[0].strip() for line in open(path, encoding="utf-8")
               if line.split("#")[0].strip())


def offenders_in(path, text, baseline):
    normalised = path.replace(os.sep, "/")
    if normalised in baseline:
        return []
    found = []
    for match in WHITE_BACKGROUND.finditer(text):
        line = text[:match.start()].count("\n") + 1
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


def main():
    if "--self-test" in sys.argv:
        return self_test()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "src"
    baseline = load_baseline(args[1] if len(args) > 1
                             else "scripts/baselines/screen-backgrounds.txt")
    found = []
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            found += offenders_in(path, open(path, encoding="utf-8", errors="replace").read(),
                                  baseline)
    if not found:
        print("lint-screen-backgrounds: every screen takes its background from the theme, bar the "
              "ones the baseline names")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-screen-backgrounds: %d screen background(s) painted by hand" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
