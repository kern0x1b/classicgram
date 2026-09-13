#!/usr/bin/env python3
import os
import re
import sys

ALLOWED = {
    "src/Utilities/TGDateUtils.mm",
    "src/Utilities/TGLocalization.m",
}

FORMATTER = re.compile(r"\[\[NSDateFormatter alloc\] init\]")
SHOWS_DATE = re.compile(r"(setDateFormat:|setDateStyle:|setTimeStyle:|\.dateFormat\s*=|\.dateStyle\s*=|\.timeStyle\s*=)")
LOCALE_ID = re.compile(r"initWithLocaleIdentifier:@\"(?!en_US_POSIX\")")


def offenders(root):
    found = []
    for base, dirs, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            if path in ALLOWED:
                continue
            text = open(path, encoding="utf-8", errors="replace").read()
            lines = text.split("\n")
            for index, line in enumerate(lines):
                if LOCALE_ID.search(line):
                    found.append((path, index + 1, "spells out a locale identifier"))
                if not FORMATTER.search(line):
                    continue
                window = "\n".join(lines[index:index + 12])
                if SHOWS_DATE.search(window):
                    found.append((path, index + 1, "formats a date without TGDateUtils"))
    return found


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = offenders(root)
    if not found:
        print("lint-date-formatting: every visible date goes through TGDateUtils")
        return 0
    for path, line, why in found:
        print("%s:%d %s" % (path, line, why))
    print("lint-date-formatting: %d site(s) outside TGDateUtils" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
