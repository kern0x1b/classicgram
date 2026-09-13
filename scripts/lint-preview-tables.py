#!/usr/bin/env python3
import os
import re
import sys

TABLE_MIN_KINDS = 5
CAPTION_RETURNED = re.compile(r"return[^;]*\bcaption\b[^;]*;", re.DOTALL)
RAW_CAPTION = re.compile(r'content\[@"caption"\]')
SHARED_TABLE = re.compile(r"TGMessage(Content)?KindLabel")
ENDS_EMPTY = re.compile(r'return @"";\s*\}\s*$')
DISAPPEARS = ("TGMediaContentDisappears", "TGMessageDisappears")
KIND = re.compile(r'isEqualToString:@"(message[A-Z]\w+)"')
FUNCTION_START = re.compile(r"^[-+A-Za-z_].*\{\s*$")


def functions(path):
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    index = 0
    while index < len(lines):
        if FUNCTION_START.match(lines[index]) and "@interface" not in lines[index]:
            depth = lines[index].count("{") - lines[index].count("}")
            end = index
            while depth > 0 and end + 1 < len(lines):
                end += 1
                depth += lines[end].count("{") - lines[end].count("}")
            yield index + 1, "\n".join(lines[index:end + 1])
            index = end
        index += 1


def offenders(root):
    found = []
    for base, dirs, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            for line, body in functions(path):
                kinds = set(KIND.findall(body))
                if len(kinds) < TABLE_MIN_KINDS:
                    continue
                if not CAPTION_RETURNED.search(body):
                    continue
                if not RAW_CAPTION.search(body):
                    continue
                if any(guard in body for guard in DISAPPEARS):
                    continue
                found.append((path, line, "returns a caption without asking whether it disappears"))
            for line, body in functions(path):
                kinds = set(KIND.findall(body))
                if len(kinds) < TABLE_MIN_KINDS:
                    continue
                if SHARED_TABLE.search(body):
                    continue
                if not ENDS_EMPTY.search(body):
                    continue
                found.append((path, line,
                    "names message kinds and answers an empty string for the rest, which "
                    "draws a row with nothing in it"))
    return found


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    found = offenders(root)
    if not found:
        print("lint-preview-tables: every preview that names message kinds falls through to the "
              "shared table and checks for disappearing media before it reads a caption")
        return 0
    for path, line, why in found:
        print("%s:%d %s" % (path, line, why))
    print("lint-preview-tables: %d preview(s) need attention" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
