#!/usr/bin/env python3
import os
import re
import sys

RAW_COLOUR = re.compile(
    r'\.(?:text|detailText)Label\.textColor\s*=\s*'
    r'(TGColourFromHex\([^)]*\)|\[UIColor \w+Color\]|\[UIColor colorWith[^;]{0,120}?\])')
ALLOWED = ("[UIColor whiteColor]", "[UIColor clearColor]")


def offenders_in(path, text):
    if path.replace(os.sep, "/").startswith("src/Theme/"):
        return []
    found = []
    for match in RAW_COLOUR.finditer(text):
        colour = match.group(1)
        if colour in ALLOWED:
            continue
        line = text[:match.start()].count("\n") + 1
        found.append((path, line,
                      "paints a row's text in a colour of its own (%s); the row colours of this "
                      "app are the theme's, so a change reaches every screen at once" % colour))
    return found


def self_test():
    path = "src/Screens/Settings/TGExampleViewController.m"
    assert offenders_in(path, '\tcell.textLabel.textColor = [UIColor blackColor];\n'), \
        "a raw black row title must be reported"
    assert offenders_in(path, '\tcell.detailTextLabel.textColor = TGColourFromHex(0x356596);\n'), \
        "a hex copy of a theme colour must be reported"
    assert not offenders_in(path,
                            '\tcell.textLabel.textColor = [[TGTheme shared] groupedTitleColour];\n'), \
        "the theme's own colour passes"
    assert not offenders_in(path, '\tcell.textLabel.textColor = [UIColor whiteColor];\n'), \
        "white over a highlighted plate is not a palette choice"
    assert offenders_in(path,
                        '\tcell.textLabel.textColor = [UIColor colorWithRed:0.8f green:0.2f '
                        'blue:0.2f alpha:1.0f];\n'), \
        "a colour spelled out in components is a palette choice too, and the fence missed those"
    assert not offenders_in("src/Theme/TGTheme.m",
                            '\tcell.textLabel.textColor = [UIColor blackColor];\n'), \
        "the theme itself is where a colour is allowed to be named"
    print("lint-row-colours: self-test passed")
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
            found += offenders_in(path, open(path, encoding="utf-8", errors="replace").read())
    if not found:
        print("lint-row-colours: every row's text takes its colour from the theme")
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-row-colours: %d row colour(s) written out by hand" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
