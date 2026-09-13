import os
import re

IMPLEMENTATION = re.compile(r'^@implementation\s+(\w+)', re.M)
GROUPED = re.compile(r'UITableViewStyleGrouped')
PLAIN = re.compile(r'UITableViewStylePlain')
OWN_GROUPED = re.compile(
    r'\[(?:self|super) initWithStyle:UITableViewStyleGrouped\]'
    r'|(?:self\.tableView|_tableView|self\.table|_table)\s*=\s*\[[^;]{0,200}?UITableViewStyleGrouped',
    re.S)
OWN_PLAIN = re.compile(
    r'\[(?:self|super) initWithStyle:UITableViewStylePlain\]'
    r'|(?:self\.tableView|_tableView|self\.table|_table)\s*=\s*\[[^;]{0,200}?UITableViewStylePlain',
    re.S)


def read_tree(root):
    texts = {}
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if name.endswith((".m", ".mm")):
                path = os.path.join(base, name)
                texts[path] = open(path, encoding="utf-8", errors="replace").read()
    return texts


def classes_in(text):
    return set(IMPLEMENTATION.findall(text))


def style_by_class(texts):
    grouped, plain = set(), set()
    for text in texts.values():
        names = classes_in(text)
        if OWN_GROUPED.search(text):
            grouped |= names
        if OWN_PLAIN.search(text):
            plain |= names
    return grouped, plain


def file_is_grouped(text, grouped, plain):
    names = classes_in(text)
    if OWN_GROUPED.search(text) and not OWN_PLAIN.search(text):
        return True
    if not names:
        return False
    return bool(names & grouped) and not (names & plain)


def self_test():
    own = ('@implementation TGExample\n'
           '- (id)init { return [self initWithStyle:UITableViewStyleGrouped]; }\n')
    other = ('@implementation TGOther (Actions)\n'
             'TGInfo *info = [[TGInfo alloc] initWithStyle:UITableViewStyleGrouped];\n')
    plainer = ('@implementation TGPlain\n'
               '- (id)init { return [super initWithStyle:UITableViewStylePlain]; }\n')
    texts = {"a.m": own, "b.m": other, "c.m": plainer}
    grouped, plain = style_by_class(texts)
    assert "TGExample" in grouped, "a class that builds its own grouped table counts as grouped"
    assert "TGOther" not in grouped, \
        "a class that merely builds someone else's grouped screen does not count as grouped"
    assert "TGPlain" in plain, "a class that builds a plain table counts as plain"
    assert file_is_grouped("@implementation TGExample (Cells)\n", grouped, plain), \
        "a category of a grouped class is grouped, which is the point of this helper"
    assert not file_is_grouped("@implementation TGPlain (Cells)\n", grouped, plain), \
        "and a category of a plain class is not"
    print("tg_grouped_classes: self-test passed")
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(self_test())
