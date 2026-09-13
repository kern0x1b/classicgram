#!/usr/bin/env python3
import os
import re
import sys

IMPLEMENTATION = re.compile(r'^@implementation\s+(\w+)', re.M)
TITLE_FOR_FOOTER = re.compile(r'^- \(NSString \*\)tableView:\(UITableView \*\)tableView\s*\n?\s*titleForFooterInSection:', re.M)
TITLE_FOR_HEADER = re.compile(r'^- \(NSString \*\)tableView:\(UITableView \*\)tableView\s*\n?\s*titleForHeaderInSection:', re.M)
VIEW_FOR_FOOTER = re.compile(r'viewForFooterInSection:')
VIEW_FOR_HEADER = re.compile(r'viewForHeaderInSection:')
GROUPED = re.compile(r'UITableViewStyleGrouped')


def classes_in(text):
    return set(IMPLEMENTATION.findall(text))


def collect(root):
    texts = {}
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if name.endswith((".m", ".mm")):
                path = os.path.join(base, name)
                texts[path] = open(path, encoding="utf-8", errors="replace").read()
    return texts


def offenders_in_tree(texts):
    by_class = {}
    for path, text in texts.items():
        for name in classes_in(text):
            by_class.setdefault(name, []).append((path, text))
    found = []
    for path, text in sorted(texts.items()):
        names = classes_in(text)
        parts = [part for name in names for part in by_class.get(name, [])]
        if not any(GROUPED.search(body) for _, body in parts):
            continue
        whole = "\n".join(body for _, body in parts)
        for pattern, drawn, what in ((TITLE_FOR_FOOTER, VIEW_FOR_FOOTER, "footer"),
                                     (TITLE_FOR_HEADER, VIEW_FOR_HEADER, "heading")):
            match = pattern.search(text)
            if not match or drawn.search(whole):
                continue
            line = text[:match.start()].count("\n") + 1
            found.append((path, line,
                          "answers a grouped %s and leaves UIKit to draw it; the %s of this app "
                          "is drawn by the theme" % (what, what)))
    return found


def self_test():
    grouped = '@implementation TGExampleViewController\n\tstyle:UITableViewStyleGrouped\n'
    footer = '- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {\n\treturn @"x";\n}\n'
    drawn = '- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {\n\treturn nil;\n}\n'
    assert offenders_in_tree({"a.m": grouped + footer}), \
        "a grouped footer left to UIKit must be reported"
    assert not offenders_in_tree({"a.m": grouped + footer + drawn}), \
        "a footer the theme draws passes"
    assert not offenders_in_tree({"a.m": grouped + footer, "b.m": '@implementation TGExampleViewController (Rows)\n' + drawn}), \
        "a category of the same class counts as the same screen"
    assert not offenders_in_tree({"a.m": '@implementation TGExampleViewController\n\tstyle:UITableViewStylePlain\n' + footer}), \
        "a plain list keeps UIKit's own header and footer"
    print("lint-grouped-captions: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = offenders_in_tree(collect(root))
    if not found:
        print("lint-grouped-captions: every heading and footer over a grouped list is drawn by "
              "the theme")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-grouped-captions: %d caption(s) left to UIKit" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
