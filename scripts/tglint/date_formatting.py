import re

from tglint import tree

ALLOWED = {
    "src/Utilities/TGDateUtils.mm",
    "src/Utilities/TGLocalization.m",
}

FORMATTER = re.compile(r"\[\[NSDateFormatter alloc\] init\]")
SHOWS_DATE = re.compile(r"(setDateFormat:|setDateStyle:|setTimeStyle:|\.dateFormat\s*=|\.dateStyle\s*=|\.timeStyle\s*=)")
LOCALE_ID = re.compile(r"initWithLocaleIdentifier:@\"(?!en_US_POSIX\")")


def offenders(root):
    found = []
    for path in tree.walk(root, skip=()):
        if path in ALLOWED:
            continue
        lines = tree.read(path).split("\n")
        for index, line in enumerate(lines):
            if LOCALE_ID.search(line):
                found.append((path, index + 1, "spells out a locale identifier"))
            if not FORMATTER.search(line):
                continue
            window = "\n".join(lines[index:index + 12])
            if SHOWS_DATE.search(window):
                found.append((path, index + 1, "formats a date without TGDateUtils"))
    return found


def main(args):
    return tree.report("lint-date-formatting", offenders(tree.root_argument(args)),
                       "every visible date goes through TGDateUtils",
                       "%d site(s) outside TGDateUtils")
