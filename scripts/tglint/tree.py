import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "src")
LOCALIZATION = os.path.join(SRC, "Resources", "Localization")
ENGLISH_STRINGS = os.path.join(LOCALIZATION, "en.lproj", "Localizable.strings")
IMPLEMENTATION = (".m", ".mm")
IMPLEMENTATION_AND_HEADERS = (".m", ".mm", ".h")
ALL_SOURCES = (".m", ".mm", ".h", ".c")
STRINGS_ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', re.M | re.S)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def walk(root, extensions=IMPLEMENTATION, skip=("Resources",)):
    if not os.path.isdir(root):
        raise SystemExit("source root not found: %s" % root)
    for base, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in skip)
        for name in sorted(names):
            if name.endswith(extensions):
                yield os.path.join(base, name)


def texts(root, extensions=IMPLEMENTATION, skip=("Resources",)):
    return {path: read(path) for path in walk(root, extensions, skip)}


def line_at(text, offset):
    return text.count("\n", 0, offset) + 1


def relative(path):
    return os.path.relpath(path, ROOT)


def slashed(path):
    return path.replace(os.sep, "/")


def strings_table(text):
    return {match.group(1): match.group(2) for match in STRINGS_ENTRY.finditer(text)}


def english_table():
    return strings_table(read(ENGLISH_STRINGS))


def baseline(path):
    if not path or not os.path.exists(path):
        return set()
    entries = set()
    for line in open(path, encoding="utf-8"):
        entry = line.split("#")[0].strip()
        if entry:
            entries.add(entry)
    return entries


def root_argument(args, default="src"):
    positional = [a for a in args if not a.startswith("--")]
    return positional[0] if positional else default


def report(name, found, clean, summary):
    if not found:
        print("%s: %s" % (name, clean))
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("%s: %s" % (name, summary % len(found)))
    return 1


def main_checkout():
    pointer_path = os.path.join(ROOT, ".git")
    if not os.path.isfile(pointer_path):
        return None
    pointer = open(pointer_path, encoding="utf-8").read().strip()
    if not pointer.startswith("gitdir:"):
        return None
    path = pointer.split(":", 1)[1].strip()
    if not os.path.isabs(path):
        path = os.path.join(ROOT, path)
    while path != os.path.dirname(path):
        if os.path.basename(path) == ".git":
            return os.path.dirname(path)
        path = os.path.dirname(path)
    return None


def td_api_scheme():
    for root in (ROOT, main_checkout()):
        if not root or not os.path.isfile(os.path.join(root, "xmake.lua")):
            continue
        try:
            answer = subprocess.run(["xmake", "where", "-P", root, "tdlib"],
                                    capture_output=True, text=True, check=False,
                                    stdin=subprocess.DEVNULL)
        except FileNotFoundError:
            return None
        lines = answer.stdout.strip().splitlines()
        if answer.returncode == 0 and lines:
            candidate = os.path.join(lines[-1].strip(), "res", "td_api.tl")
            if os.path.isfile(candidate):
                return candidate
    return None
