import re

from tglint import tree

ASSIGNMENT = re.compile(
    r'navigationItem\.(?:left|right)BarButtonItems?\s*=\s*(.{0,400}?);', re.S)
SYSTEM_BUTTON = re.compile(r'buttonWithType:UIButtonType(?:System|RoundedRect)')
SYSTEM_ITEM = re.compile(r'\[\s*UIBarButtonItem\s+alloc\s*\]\s*init(?:WithTitle|WithBarButtonSystemItem)')
ALLOWED = ("TGIcons", "initWithCustomView")


def offenders_in(path, text):
    found = []
    for match in SYSTEM_BUTTON.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "builds a system button; on the iOS 6 SDK that is the grey rounded "
                      "rectangle, and this app draws its own plate through TGIcons"))
    for match in ASSIGNMENT.finditer(text):
        body = match.group(1)
        if not SYSTEM_ITEM.search(body):
            continue
        if any(name in body for name in ALLOWED):
            continue
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "puts a system bar button in the navigation bar; this app draws its "
                      "own plate through TGIcons"))
    return found


def self_test():
    path = "src/Screens/Chat/TGQuotePickerViewController.m"
    assert offenders_in(path,
                        '\tself.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]\n'
                        '\t\tinitWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(go)];\n'), \
        "a system bar button in the navigation bar must be reported"
    assert not offenders_in(path,
                            '\tself.navigationItem.rightBarButtonItem =\n'
                            '\t\t[TGIcons headerBarButtonItemWithTitle:@"Done" bold:YES target:self action:@selector(go)];\n'), \
        "the shared plate passes"
    assert not offenders_in(path,
                            '\tself.navigationItem.leftBarButtonItem =\n'
                            '\t\t[[UIBarButtonItem alloc] initWithCustomView:view];\n'), \
        "a custom view is the app drawing its own button"
    assert not offenders_in(path,
                            '\tbar.items = @[ [[UIBarButtonItem alloc] '
                            'initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(go)] ];\n'), \
        "a toolbar over a picker is system chrome and is left alone"
    assert offenders_in(path, '\tUIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];\n'), \
        "a system button inside a screen must be reported too"
    assert not offenders_in(path, '\tUIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];\n'), \
        "a custom button is the app drawing its own"
    print("lint-navbar-buttons: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    found = []
    for path in tree.walk(tree.root_argument(args)):
        found += offenders_in(path, tree.read(path))
    return tree.report("lint-navbar-buttons", found,
                       "every button in a navigation bar and every button in a screen is drawn by "
                       "this app",
                       "%d system button(s) in a navigation bar")
