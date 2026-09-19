import os
import re

from tglint import tree

PLACEHOLDER = re.compile(r'(\w[\w.]*)\.placeholder\s*=')
DECLARED = re.compile(r'UITextField\s*\*\s*_?(\w+)')
FROM_ALERT = re.compile(r'UITextField\s*\*\s*(\w+)\s*=\s*\[\s*\w+\s+textFieldAtIndex:')
ATTRIBUTED = re.compile(r'(\w[\w.]*)\.attributedPlaceholder\s*=')
STYLED = re.compile(r'TGStyle(?:TextField|TextFieldOverDarkness|SearchField)\(')
EXEMPT = ("src/Theme/", "src/Screens/Login/", "src/Screens/Search/",
          "src/Views/TGSearchBar", "src/Storage/TGPasscodeLock")


def exempt(path):
    normalised = path.replace(os.sep, "/")
    return any(part in normalised for part in EXEMPT)


def offenders_in(path, text):
    if exempt(path):
        return []
    found = []
    styled = STYLED.search(text) is not None
    for match in ATTRIBUTED.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "paints a placeholder of its own; the colour of a placeholder in this app is "
                      "decided once, in TGStyleTextField"))
    if styled:
        return found
    fields = set(DECLARED.findall(text)) - set(FROM_ALERT.findall(text))
    for match in PLACEHOLDER.finditer(text):
        receiver = match.group(1).split(".")[-1].lstrip("_")
        if receiver not in fields:
            continue
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "gives a field a placeholder and never styles it, so it keeps UIKit's pale "
                      "grey rather than the placeholder colour of the original"))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    declared = '\tUITextField *field = [[UITextField alloc] init];\n'
    assert offenders_in(path, declared + '\tfield.placeholder = TGL(@"A.B", @"Name");\n'), \
        "a placeholder that is never styled must be reported"
    assert not offenders_in(path, '\tself.searchBar.placeholder = TGL(@"A.B", @"Search");\n'), \
        "a search bar is not a text field and carries the bar's own chrome"
    assert not offenders_in(path,
                            declared + '\tfield.placeholder = TGL(@"A.B", @"Name");\n\tTGStyleTextField(field);\n'), \
        "a styled field passes"
    assert offenders_in(path,
                        '\tfield.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"x" '
                        'attributes:attributes];\n\tTGStyleTextField(field);\n'), \
        "a hand-painted placeholder is a defect even beside the shared style"
    assert not offenders_in(path,
                            '\tUITextField *field = [alert textFieldAtIndex:0];\n'
                            '\tfield.placeholder = TGL(@"A.B", @"Number");\n'), \
        "the field inside a system alert is the alert's own, not a field this app draws"
    assert not offenders_in("src/Screens/Login/TGLoginViewController+Chrome.m",
                            '\tfield.placeholder = @"Phone";\n'), \
        "the login screens carry their own chrome and are left alone"
    print("lint-text-field-style: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    found = []
    for path in tree.walk(tree.root_argument(args)):
        found += offenders_in(path, tree.read(path))
    return tree.report("lint-text-field-style", found,
                       "every field a screen puts a placeholder in is styled by TGStyleTextField",
                       "%d unstyled field(s)")
