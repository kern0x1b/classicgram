import os
import re

from tglint import tree

FALLBACK = re.compile(r'\?:\s*@"([A-Z][A-Za-z]+(?: [A-Za-z]+)*)"')
ALLOWED_WORDS = {"YES", "NO", "OK", "GIF", "URL", "ID"}
UI_DIRS = ("Screens", "Views", "App", "Companions")


def offenders_in(path, text):
    found = []
    if not any(part in path.split(os.sep) for part in UI_DIRS):
        return found
    for index, line in enumerate(text.split("\n")):
        match = FALLBACK.search(line)
        if not match:
            continue
        if match.group(1) in ALLOWED_WORDS:
            continue
        if "TGL(" in line[:match.start()]:
            continue
        found.append((path, index + 1, match.group(1)))
    return found


def self_test():
    screen = "src/Screens/ChatList/TGChatListViewController.m"
    utility = "src/Utilities/TGDateUtils.mm"
    assert offenders_in(screen, '\tvc.chatTitle = name ?: @"Chat";\n'), \
        "a bare English fallback on a screen must be reported"
    assert not offenders_in(screen, '\tvc.chatTitle = name ?: TGL(@"ChatList.UnnamedChat", @"Chat");\n'), \
        "a translated fallback must pass"
    assert not offenders_in(utility, '\tNSString *text = value ?: @"Chat";\n'), \
        "a non-UI package is outside this rule"
    assert not offenders_in(screen, '\tNSString *answer = value ?: @"OK";\n'), \
        "a protocol word is not user-facing prose"
    assert not offenders_in(screen, '\tNSString *key = value ?: @"chat";\n'), \
        "a lowercase dictionary key is not user-facing prose"
    print("lint-english-fallbacks: self-test passed")
    return 0


def offenders(root):
    found = []
    for path in tree.walk(root, skip=()):
        found += offenders_in(path, tree.read(path))
    return found


def main(args):
    if "--self-test" in args:
        return self_test()
    found = [(path, line, 'falls back to the English "%s"' % text)
             for path, line, text in offenders(tree.root_argument(args))]
    return tree.report("lint-english-fallbacks", found,
                       "no screen falls back to an untranslated English word",
                       "%d untranslated fallback(s)")
