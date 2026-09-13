import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCANNED = ("src/TDLibClient", "src/Wire")
ACCESSOR = re.compile(
    r"static\s+(?:int64_t|long long)\s+(\w+)\(id\s+\w+\)\s*\{(.*?)\n\}", re.S)


def offenders():
    found = []
    for scanned in SCANNED:
        for base, _, files in os.walk(os.path.join(ROOT, scanned)):
            for name in files:
                if not name.endswith(".m"):
                    continue
                path = os.path.join(base, name)
                text = open(path, encoding="utf-8", errors="replace").read()
                for match in ACCESSOR.finditer(text):
                    body = match.group(2)
                    if "NSNumber" not in body:
                        continue
                    if "NSString" in body or "TGTDLibInt64" in body:
                        continue
                    line = text[:match.start()].count("\n") + 1
                    found.append((os.path.relpath(path, ROOT), line, match.group(1)))
    return found


def main():
    found = offenders()
    for path, line, name in found:
        print(f"{path}:{line}: {name} reads an int64 as NSNumber only")
    if found:
        print("TDLib sends int64 fields as JSON strings and int53 fields as numbers, so an "
              "NSNumber-only reader silently returns 0 for every sticker set, gift, effect or "
              "custom emoji id; read them with TGTDLibInt64")
        sys.exit(1)
    print("lint-tdlib-int64-reads: every int64 reader accepts the string TDLib sends")


if __name__ == "__main__":
    main()
