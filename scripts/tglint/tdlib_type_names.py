import re

from tglint import tree

POSITIONS = (
    re.compile(r'@"@type"\s*:\s*@"([A-Za-z]\w*)"'),
    re.compile(r'\[@"@type"\]\s*=\s*@"([A-Za-z]\w*)"'),
    re.compile(r'\[@"@type"\]\s+isEqualToString:@"([A-Za-z]\w*)"'),
    re.compile(r'TGTDLibTypeOf\([^()]*(?:\([^()]*\))?[^()]*\)\s+isEqualToString:@"([A-Za-z]\w*)"'),
)


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
            line = tree.line_at(text, match.start())
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


def main(args):
    if "--self-test" in args:
        return self_test()
    scheme = tree.td_api_scheme()
    if not scheme:
        print("lint-tdlib-type-names: skipped, xmake where tdlib names no installed td_api.tl "
              "(xmake is not on PATH, or tdlib is not built yet)")
        return 0
    types = declared_types(tree.read(scheme))
    root = tree.root_argument(args, tree.SRC)
    found = []
    checked = 0
    for path in tree.walk(root):
        body = tree.read(path)
        checked += sum(len(pattern.findall(body)) for pattern in POSITIONS)
        found += offenders_in(path, body, types)
    return tree.report("lint-tdlib-type-names", found,
                       "all %d TDLib type names in the tree are real" % checked,
                       "%d name(s) td_api.tl does not declare")
