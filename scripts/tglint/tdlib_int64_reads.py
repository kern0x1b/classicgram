import os
import re

from tglint import tree

SCANNED = ("TDLibClient", "Wire")
ACCESSOR = re.compile(
    r"static\s+(?:int64_t|long long)\s+(\w+)\(id\s+\w+\)\s*\{(.*?)\n\}", re.S)


def offenders():
    found = []
    for scanned in SCANNED:
        for path in tree.walk(os.path.join(tree.SRC, scanned), ".m", skip=()):
            text = tree.read(path)
            for match in ACCESSOR.finditer(text):
                body = match.group(2)
                if "NSNumber" not in body:
                    continue
                if "NSString" in body or "TGTDLibInt64" in body:
                    continue
                found.append((tree.relative(path), tree.line_at(text, match.start()),
                              match.group(1)))
    return found


def main(args):
    found = offenders()
    for path, line, name in found:
        print(f"{path}:{line}: {name} reads an int64 as NSNumber only")
    if found:
        print("TDLib sends int64 fields as JSON strings and int53 fields as numbers, so an "
              "NSNumber-only reader silently returns 0 for every sticker set, gift, effect or "
              "custom emoji id; read them with TGTDLibInt64")
        return 1
    print("lint-tdlib-int64-reads: every int64 reader accepts the string TDLib sends")
    return 0
