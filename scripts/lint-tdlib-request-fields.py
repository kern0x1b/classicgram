#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
SCHEME_UNDER_ROOT = os.path.join("third_party", "tdlib", "td", "td", "generate", "scheme",
                                 "td_api.tl")


def main_checkout():
    common = os.path.join(ROOT, ".git")
    if os.path.isfile(common):
        pointer = open(common, encoding="utf-8").read().strip()
        if pointer.startswith("gitdir:"):
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


SCHEME = scheme_path()

SKIP_DIRS = ("libvpx", "libtgvoip", "opus", "opusenc", "opusfile", "ogg", "quirc", "Resources")

TYPE_LINE_RE = re.compile(r"^([a-zA-Z]\w*)((?:\s+\w+:[\w<>\.]+)*)\s*=\s*[\w<>]+;")
FIELD_RE = re.compile(r"(\w+):[\w<>\.]+")
LITERAL_TYPE_RE = re.compile(r'@"@type"\s*:\s*@"(\w+)"')
MUTABLE_TYPE_RE = re.compile(r'(\w+)\[@"@type"\]\s*=\s*@"(\w+)"')
METHOD_START_RE = re.compile(r"^[-+]\s*\(")


def schema():
    if not os.path.isfile(SCHEME):
        print(f"lint-tdlib-request-fields: skipped, no td_api.tl at {SCHEME} "
              f"(the tdlib submodule is not checked out in this tree)")
        sys.exit(0)
    functions = {}
    names = set()
    in_functions = False
    for line in open(SCHEME, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.strip() == "---functions---":
            in_functions = True
            continue
        if not line or line.startswith("//") or line.startswith("@"):
            continue
        match = TYPE_LINE_RE.match(line)
        if not match:
            continue
        names.add(match.group(1))
        if in_functions:
            functions[match.group(1)] = set(FIELD_RE.findall(match.group(2)))
    return functions, names


def sources():
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if name.endswith((".m", ".mm")):
                yield os.path.join(root, name)


def enclosing_dictionary(text, position):
    depth = 0
    index = position
    while index > 0:
        character = text[index]
        if character == "}":
            depth += 1
        elif character == "{":
            if depth == 0:
                return index if text[index - 1] == "@" else None
            depth -= 1
        index -= 1
    return None


def top_level_keys(text, open_brace):
    keys = []
    depth = 0
    index = open_brace + 1
    end = len(text)
    while index < end:
        character = text[index]
        if character == "{":
            depth += 1
        elif character == "}":
            if depth == 0:
                break
            depth -= 1
        elif character == '"' and depth == 0 and text[index - 1] == "@":
            closing = text.find('"', index + 1)
            if closing < 0:
                break
            key = text[index + 1:closing]
            after = closing + 1
            while after < end and text[after] in " \t\n":
                after += 1
            if after < end and text[after] == ":":
                keys.append(key)
            index = closing
        index += 1
    return keys


def line_of(text, position):
    return text.count("\n", 0, position) + 1


def main():
    functions, names = schema()
    unknown_types = []
    unknown_fields = []

    for path in sources():
        text = open(path, encoding="utf-8", errors="replace").read()
        relative = os.path.relpath(path, ROOT)

        for match in re.finditer(r'@"@type"\]?\s*[:=]\s*@"(\w+)"', text):
            if match.group(1) not in names:
                unknown_types.append((relative, line_of(text, match.start()), match.group(1)))

        for match in LITERAL_TYPE_RE.finditer(text):
            name = match.group(1)
            if name not in functions:
                continue
            brace = enclosing_dictionary(text, match.start())
            if brace is None:
                continue
            keys = set(top_level_keys(text, brace)) - {"@type"}
            for key in sorted(keys - functions[name]):
                unknown_fields.append((relative, line_of(text, match.start()), name, key))

        lines = text.split("\n")
        starts = [i for i, line in enumerate(lines) if METHOD_START_RE.match(line)]
        starts.append(len(lines))
        for first, last in zip(starts, starts[1:]):
            body = "\n".join(lines[first:last])
            for match in MUTABLE_TYPE_RE.finditer(body):
                variable, name = match.group(1), match.group(2)
                if name not in functions:
                    continue
                keys = set(re.findall(re.escape(variable) + r'\[@"(\w+)"\]\s*=', body)) - {"@type"}
                for key in sorted(keys - functions[name]):
                    unknown_fields.append((relative, first + 1 + body.count("\n", 0, match.start()),
                                           name, key))

    for relative, line, name in unknown_types:
        print(f'[NEW] {relative}:{line} "{name}" is not a type in td_api.tl, so TDLib answers this '
              f"request with an error instead of doing it")
    for relative, line, name, key in sorted(set(unknown_fields)):
        print(f'[NEW] {relative}:{line} {name} has no field "{key}"; TDLib ignores it, so whatever '
              f"that value was meant to carry never reaches the server")

    if unknown_types or unknown_fields:
        print(f"lint-tdlib-request-fields: {len(unknown_types)} unknown type(s), "
              f"{len(set(unknown_fields))} unknown field(s)")
        return 1
    print("lint-tdlib-request-fields: every request names a real td_api function and only its own fields")
    return 0


if __name__ == "__main__":
    sys.exit(main())
