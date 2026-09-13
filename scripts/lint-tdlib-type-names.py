#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEME_UNDER_ROOT = os.path.join("third_party", "tdlib", "td", "td", "generate", "scheme",
                                 "td_api.tl")
POSITIONS = (
    re.compile(r'@"@type"\s*:\s*@"([A-Za-z]\w*)"'),
    re.compile(r'\[@"@type"\]\s*=\s*@"([A-Za-z]\w*)"'),
    re.compile(r'\[@"@type"\]\s+isEqualToString:@"([A-Za-z]\w*)"'),
    re.compile(r'TGTDLibTypeOf\([^()]*(?:\([^()]*\))?[^()]*\)\s+isEqualToString:@"([A-Za-z]\w*)"'),
)


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


def scheme_path():
    here = os.path.join(ROOT, SCHEME_UNDER_ROOT)
    if os.path.isfile(here):
        return here
    checkout = main_checkout()
    if checkout:
        shared = os.path.join(checkout, SCHEME_UNDER_ROOT)
        if os.path.isfile(shared):
            return shared
    return here


def declared_types(text):
    names = set()
    for line in text.split("\n"):
        if "=" not in line or line.startswith("//"):
            continue
        match = re.match(r"^([a-zA-Z]\w*)\s", line)
        if match:
            names.add(match.group(1))
    return names


def offenders_in(path, text, types):
    found = []
    for pattern in POSITIONS:
        for match in pattern.finditer(text):
            name = match.group(1)
            if name in types:
                continue
            line = text[:match.start()].count("\n") + 1
            found.append((path, line,
                          '"%s" is not a type in td_api.tl, so this branch can never run'
                          % name))
    return found


def self_test():
    types = declared_types("messagePhoto photo:photo = MessageContent;\n"
                           "updateNewMessage message:message = Update;\n")
    path = "src/Wire/Flatten/TGFlattenMessage.m"
    assert not offenders_in(path, '\tif ([content[@"@type"] isEqualToString:@"messagePhoto"])\n',
                            types), "a real type passes"
    assert offenders_in(path, '\tif ([content[@"@type"] isEqualToString:@"messagePhotos"])\n',
                        types), "a misspelled type must be reported"
    assert offenders_in(path, '\trequest[@"@type"] = @"getChatHistoryy";\n', types), \
        "so must one written into a request"
    assert not offenders_in(path, '\tif ([kind isEqualToString:@"photo"])\n', types), \
        "a kind of our own is not a TDLib type"
    print("lint-tdlib-type-names: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    scheme = scheme_path()
    if not os.path.isfile(scheme):
        print("lint-tdlib-type-names: skipped, no td_api.tl at %s" % scheme)
        return 0
    types = declared_types(open(scheme, encoding="utf-8", errors="replace").read())
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "src")
    found = []
    checked = 0
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm")):
                continue
            path = os.path.join(base, name)
            body = open(path, encoding="utf-8", errors="replace").read()
            checked += sum(len(pattern.findall(body)) for pattern in POSITIONS)
            found += offenders_in(path, body, types)
    if not found:
        print("lint-tdlib-type-names: all %d TDLib type names in the tree are real" % checked)
        return 0
    for path, line, reason in found:
        print("%s:%d %s" % (path, line, reason))
    print("lint-tdlib-type-names: %d name(s) td_api.tl does not declare" % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
