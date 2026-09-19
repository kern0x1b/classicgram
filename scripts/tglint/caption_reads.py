import os
import re

from tglint import tree

READ = re.compile(r'content\[@"caption"\]|\(\s*content\s*,\s*@"caption"\s*\)')
GUARDS = ("TGMediaContentDisappears", "TGMessageDisappears", "TGSavedPreview",
          "TGDisappearingMediaLabel", "TGSharedMediaShowsContent",
          "TGSharedMediaShowsMessage", '@"is_secret"')
ALLOWED = (
    os.path.join("src", "Wire", "Flatten", "TGFlattenMessageContent.m"),
    os.path.join("src", "Wire", "Flatten", "TGServiceNotificationAlert.m"),
)


def offenders_in(path, text):
    normalised = os.path.normpath(path)
    if normalised in ALLOWED:
        return []
    if any(guard in text for guard in GUARDS):
        return []
    found = []
    for match in READ.finditer(text):
        line = tree.line_at(text, match.start())
        found.append((path, line,
                      "reads a caption for display without ever asking whether the "
                      "content disappears"))
    return found


def self_test():
    screen = "src/Screens/Search/TGSearchViewController+ScopeBar.m"
    assert offenders_in(screen, '\tNSString *text = content[@"caption"][@"text"];\n'), \
        "a bare caption read must be reported"
    assert not offenders_in(
        screen,
        '\tif (TGMediaContentDisappears(content))\n\t\treturn label;\n'
        '\tNSString *text = content[@"caption"][@"text"];\n'), \
        "a file that asks the question first passes"
    assert not offenders_in(
        screen,
        '\tif ([content[@"is_secret"] boolValue])\n\t\treturn label;\n'
        '\tNSString *text = TGNotifString(content, @"caption");\n'), \
        "so does one that reads the push payload's own secret flag"
    assert not offenders_in(ALLOWED[0], '\tinfo[@"caption"] = content[@"caption"];\n'), \
        "the media-info builder hands the caption to a viewer that draws it once"
    assert not offenders_in(screen, '\trequest[@"caption"] = text;\n'), \
        "writing a caption into a request is not reading one"
    print("lint-caption-reads: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    found = []
    for path in tree.walk(tree.root_argument(args)):
        found += offenders_in(path, tree.read(path))
    return tree.report("lint-caption-reads", found,
                       "every caption shown to someone is checked for disappearing media first",
                       "%d unguarded caption read(s)")
