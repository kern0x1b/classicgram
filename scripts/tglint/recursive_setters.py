import re

from tglint import tree

SETTER = re.compile(r'-\s*\(void\)set([A-Z]\w*):\s*\([^)]*\)\s*\w+\s*\{')


def body_after(text, start):
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
        i += 1
    return text[start:i]


def offenders():
    found = []
    for path in tree.walk(tree.SRC, skip=()):
        text = tree.read(path)
        for match in SETTER.finditer(text):
            prop = match.group(1)
            lower = prop[0].lower() + prop[1:]
            body = body_after(text, match.end())
            assign = re.compile(r'self\.%s\s*=(?!=)' % re.escape(lower))
            if assign.search(body):
                found.append((tree.relative(path), tree.line_at(text, match.start()), prop))
    return found


def main(args):
    found = offenders()
    if not found:
        print("lint-recursive-setters: no setter assigns through its own property")
        return 0

    print("lint-recursive-setters: %d setter(s) call themselves; each one ends the "
          "process with a stack overflow the first time it runs" % len(found))
    for path, line, prop in found:
        print("  %s:%d set%s: assigns self.%s%s"
              % (path, line, prop, prop[0].lower(), prop[1:]))
    return 1
