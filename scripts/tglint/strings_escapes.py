import glob
import os
import re

from tglint import tree

DOUBLE_ESCAPE = re.compile(r'\\\\[nt]')


def main(args):
    tables = sorted(glob.glob(os.path.join(tree.LOCALIZATION, "*.lproj", "Localizable.strings")))
    offenders = []
    for path in tables:
        for number, line in enumerate(tree.read(path).split("\n"), 1):
            if DOUBLE_ESCAPE.search(line):
                offenders.append((tree.relative(path), number, line.strip()))
    for path, number, line in offenders:
        print(f"{path}:{number}: escaped escape prints literally: {line}")
    if offenders:
        print(f"lint-strings-escapes: {len(offenders)} line(s) print a literal backslash")
        return 1
    print(f"lint-strings-escapes: no literal \\n or \\t in {len(tables)} strings files")
    return 0
