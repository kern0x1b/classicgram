#!/usr/bin/env python3
import os
import re
import sys

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
    for base, dirs, files in os.walk(root):
        if not any(part in base.split(os.sep) for part in UI_DIRS):
            continue
        for name in sorted(files):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            found += offenders_in(
                path, open(path, encoding="utf-8", errors="replace").read())
    return found


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = offenders(root)
    if not found:
        print("lint-english-fallbacks: no screen falls back to an untranslated English word")
        return 0
    for path, line, text in found:
        print('%s:%d falls back to the English "%s"' % (path, line, text))
    print("lint-english-fallbacks: %d untranslated fallback(s)" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
