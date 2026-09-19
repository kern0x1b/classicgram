import collections
import re

from tglint import tree

PROPERTY_RE = re.compile(r"@property\s*\(([^)]*)\)\s*[\w\s\*<>,]+?\**(\w+)\s*;")
METHOD_RE = re.compile(r"^[-+]\s*\([\w\s\*<>]+\)\s*(\w+)\s*;$")
SIGNATURE_RE = re.compile(r"^[-+]\s*\([\w\s\*<>]+\)\s*(\w+)\s*[;{]?\s*$")
GETTER_RE = re.compile(r"getter\s*=\s*(\w+)")
WORD_RE = re.compile(r"[A-Za-z_]\w*")


def main(args):
    known = tree.baseline(args[args.index("--baseline") + 1] if "--baseline" in args else None)
    words = collections.Counter()
    declarations = []
    methods = []
    signatures = collections.Counter()
    for path in tree.walk(tree.SRC, tree.IMPLEMENTATION_AND_HEADERS):
        text = tree.read(path)
        words.update(WORD_RE.findall(text))
        for line in text.split("\n"):
            signature = SIGNATURE_RE.match(line.strip())
            if signature:
                signatures[signature.group(1)] += 1
        if not path.endswith(".h"):
            continue
        for number, line in enumerate(text.split("\n"), 1):
            match = PROPERTY_RE.match(line.strip())
            if match:
                getter = GETTER_RE.search(match.group(1))
                declarations.append((path, number, match.group(2),
                                     getter.group(1) if getter else None))
                continue
            method = METHOD_RE.match(line.strip())
            if method:
                methods.append((path, number, method.group(1)))

    dead = []
    for path, number, name, getter in declarations:
        capitalised = name[0].upper() + name[1:]
        spellings = [name, "_" + name, "set" + capitalised]
        if getter:
            spellings.append(getter)
        if sum(words[spelling] for spelling in spellings) > 1:
            continue
        relative = tree.relative(path)
        if f"{relative} {name}" in known:
            continue
        dead.append((relative, number, name))

    for path, number, name in methods:
        if words[name] - signatures[name] > 0:
            continue
        relative = tree.relative(path)
        if f"{relative} {name}" in known:
            continue
        dead.append((relative, number, name))

    for path, number, name in dead:
        print(f"[NEW] {path}:{number} declares \"{name}\" and nothing ever calls, reads or writes it")
    if dead:
        print(f"lint-dead-declarations: {len(dead)} declaration(s) nothing uses")
        return 1
    print(f"lint-dead-declarations: every one of {len(declarations)} declared properties "
          f"and {len(methods)} argument-less methods is used")
    return 0
