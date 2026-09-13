#!/usr/bin/env python3
import os
import re
import sys

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
        line = text[:match.start()].count("\n") + 1
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


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = []
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            found += offenders_in(
                path, open(path, encoding="utf-8", errors="replace").read())
    if not found:
        print("lint-caption-reads: every caption shown to someone is checked for "
              "disappearing media first")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-caption-reads: %d unguarded caption read(s)" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
