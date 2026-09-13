#!/usr/bin/env python3
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tg_grouped_classes as grouped_classes

GROUPED = re.compile(r'UITableViewStyleGrouped')
PLAIN = re.compile(r'UITableViewStylePlain')
CELL_STYLE = re.compile(r'initWithStyle:UITableViewCellStyle(\w+)')
TITLE_FONT = re.compile(r'\w[\w.]*\.textLabel\.font\s*=\s*\[UIFont systemFontOfSize:17\]')


def offenders_in(path, text, skip_style_check=False):
    if not skip_style_check and (not GROUPED.search(text) or PLAIN.search(text)):
        return []
    found = []
    for match in TITLE_FONT.finditer(text):
        styles = CELL_STYLE.findall(text[:match.start()])
        if styles and styles[-1] not in ("Default", "Value1"):
            continue
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "sets a grouped row's title in regular 17; the row of the 2013 client is "
                      "bold 17, and regular 17 is the iOS 7 look this app is not"))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    grouped = ('\tstyle:UITableViewStyleGrouped\n'
               '\tcell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 '
               'reuseIdentifier:@"row"];\n')
    assert offenders_in(path, grouped + '\tcell.textLabel.font = [UIFont systemFontOfSize:17];\n'), \
        "a regular 17 row title must be reported"
    assert not offenders_in(path, grouped + '\tcell.textLabel.font = [UIFont boldSystemFontOfSize:17];\n'), \
        "the bold 17 of the original passes"
    assert not offenders_in(path,
                            '\tstyle:UITableViewStyleGrouped\n'
                            '\tcell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle '
                            'reuseIdentifier:@"row"];\n'
                            '\tcell.textLabel.font = [UIFont systemFontOfSize:17];\n'), \
        "a two-line cell sizes its own text"
    assert not offenders_in("src/Screens/ChatList/TGChatListViewController.m",
                            '\tstyle:UITableViewStylePlain\n'
                            '\tcell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault '
                            'reuseIdentifier:@"row"];\n'
                            '\tcell.textLabel.font = [UIFont systemFontOfSize:17];\n'), \
        "a plain list is not the grouped settings look"
    print("lint-grouped-row-font: self-test passed")
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
        print("lint-grouped-row-font: every grouped row's title is the bold 17 of the original")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-grouped-row-font: %d row title(s) in regular 17" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
