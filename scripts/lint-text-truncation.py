#!/usr/bin/env python3
import os
import re
import sys

OWNER = os.path.join("src", "Utilities", "TGStringTruncation.m")
HAND_ROLLED = re.compile(r"rangeOfComposedCharacterSequenceAtIndex:\s*0\s*\]")
FIXED_CUT = re.compile(r"substringToIndex:\s*[0-9]+\s*\]")
UI_DIRS = ("Screens", "Views")
ASCII_ONLY = (
    os.path.join("src", "Screens", "Chat", "TGTranslationLanguageCode.m"),
    os.path.join("src", "Screens", "Login", "TGLoginViewController+Input.m"),
)


def offenders_in(path, text):
    found = []
    normalised = os.path.normpath(path)
    if normalised == OWNER:
        return found
    parts = normalised.split(os.sep)
    for index, line in enumerate(text.split("\n")):
        if HAND_ROLLED.search(line):
            found.append((path, index + 1,
                          "takes a first character by hand instead of calling TGStringTruncation"))
            continue
        if not FIXED_CUT.search(line):
            continue
        if not any(part in parts for part in UI_DIRS):
            continue
        if normalised in ASCII_ONLY:
            continue
        found.append((path, index + 1,
                      "cuts visible text at a fixed unit, which can halve a surrogate pair"))
    return found


def self_test():
    view = "src/Views/TGStickerPanelView+Tabs.m"
    assert offenders_in(view, "\treturn [[title substringToIndex:3] uppercaseString];\n"), \
        "a fixed cut of visible text must be reported"
    assert not offenders_in(view, "\treturn [TGSafeSubstringToIndex(title, 3) uppercaseString];\n"), \
        "the shared helper must pass"
    assert offenders_in("src/Wire/Flatten/TGFlattenPremium.m",
                        "\tNSRange first = [tag rangeOfComposedCharacterSequenceAtIndex:0];\n"), \
        "a hand-rolled first character must be reported anywhere in src"
    assert not offenders_in(OWNER,
                            "\tNSRange first = [string rangeOfComposedCharacterSequenceAtIndex:0];\n"), \
        "the helper itself is where that call belongs"
    assert not offenders_in("src/Views/TGStickerPanelView+Tabs.m",
                            "\tNSRange last = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];\n"), \
        "a backspace over the last character is a different job"
    assert not offenders_in("src/TDLibClient/TGClient+Bots.m",
                            "\tname = [name substringToIndex:4];\n"), \
        "a wire-format cut outside the screens is not visible text"
    print("lint-text-truncation: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = []
    for base, _, names in os.walk(root):
        for name in sorted(names):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            found += offenders_in(
                path, open(path, encoding="utf-8", errors="replace").read())
    if not found:
        print("lint-text-truncation: every string is cut through TGStringTruncation")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-text-truncation: %d hand-rolled cut(s)" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
