#!/usr/bin/env python3
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STRINGS = sorted(ROOT.glob("src/Resources/Localization/*.lproj/Localizable.strings"))
DOUBLE_ESCAPE = re.compile(r'\\\\[nt]')

def main():
    offenders = []
    for path in STRINGS:
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            if DOUBLE_ESCAPE.search(line):
                offenders.append((path.relative_to(ROOT), number, line.strip()))
    for path, number, line in offenders:
        print(f"{path}:{number}: escaped escape prints literally: {line}")
    if offenders:
        print(f"lint-strings-escapes: {len(offenders)} line(s) print a literal backslash")
        return 1
    print(f"lint-strings-escapes: no literal \\n or \\t in {len(STRINGS)} strings files")
    return 0

if __name__ == "__main__":
    sys.exit(main())
