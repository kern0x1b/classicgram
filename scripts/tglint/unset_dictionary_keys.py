import os
import re
import sys

from tglint import tree

READ = re.compile(r'(?<!@)\[\s*@"([a-z][A-Za-z0-9]*)"\s*\]')
FROM_JSON = re.compile(r'JSONObjectWithData')
WRITES = (
    re.compile(r'@"([a-z][A-Za-z0-9]*)"\s*:'),
    re.compile(r'\w\s*\[\s*@"([a-z][A-Za-z0-9]*)"\s*\]\s*='),
    re.compile(r'forKey:\s*@"([a-z][A-Za-z0-9]*)"'),
    re.compile(r',\s*@"([a-z][A-Za-z0-9]*)"'),
    re.compile(r'\(\s*\w+\s*,\s*@"([a-z][A-Za-z0-9]*)"'),
)
SKIP_FILES = ("TGLottieView",)


def installed_schema():
    import subprocess
    try:
        folder = subprocess.run(["xmake", "where", "-P", ".", "tdlib"], capture_output=True, text=True, check=True).stdout.strip().splitlines()[-1]
    except (OSError, subprocess.CalledProcessError, IndexError):
        sys.exit("lint-unset-dictionary-keys: no td_api.tl to check against; build once with xmake so the tdlib package is installed")
    return os.path.join(folder, "res", "td_api.tl")


def schema_fields(path):
    if not path:
        path = installed_schema()
    if not os.path.exists(path):
        return set()
    return set(re.findall(r'(\w+):[\w<>\.]+', tree.read(path)))


def scan(root, schema, baseline=frozenset()):
    written = set()
    read = {}
    for path in tree.walk(root, tree.IMPLEMENTATION_AND_HEADERS):
        name = os.path.basename(path)
        text = tree.read(path)
        for pattern in WRITES:
            written.update(pattern.findall(text))
        if not name.endswith(tree.IMPLEMENTATION):
            continue
        if any(part in name for part in SKIP_FILES):
            continue
        parses_json = FROM_JSON.search(text) is not None
        for match in READ.finditer(text):
            key = match.group(1)
            if key in schema or len(key) < 4 or key in baseline:
                continue
            if parses_json:
                continue
            read.setdefault(key, (path, tree.line_at(text, match.start())))
    return [(path, line, key) for key, (path, line) in sorted(read.items()) if key not in written]


def self_test():
    written = set()
    for pattern in WRITES:
        written.update(pattern.findall('@{@"alpha" : @1}\n out[@"beta"] = @2;\n'
                                       '[d setObject:@3 forKey:@"gamma"];\n'
                                       '[[NSMutableDictionary alloc] initWithObjectsAndKeys:@4, @"delta", nil];\n'
                                       'TGWLSetString(out, @"epsilon", raw);\n'))
    for key in ("alpha", "beta", "gamma", "delta", "epsilon"):
        assert key in written, "a key written as %s must count as written" % key
    assert READ.findall('x = row[@"zeta"];') == ["zeta"], "a plain read is a read"
    assert READ.findall('kinds = @[ @"eta" ];') == [], \
        "a one-element array literal is a value, not a key being read"
    print("lint-unset-dictionary-keys: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    args = [a for a in args if not a.startswith("--")]
    root = args[0] if args else "src"
    schema_path = args[1] if len(args) > 1 else None
    baseline_path = args[2] if len(args) > 2 else "scripts/baselines/unset-dictionary-keys.txt"
    keys = scan(root, schema_fields(schema_path), tree.baseline(baseline_path))
    found = [(path, line, 'reads @"%s", which nothing in the tree ever writes, so it is always nil'
              % key) for path, line, key in keys]
    return tree.report("lint-unset-dictionary-keys", found,
                       "every dictionary key a screen reads is written somewhere, bar the ones "
                       "the baseline names",
                       "%d key(s) read but never written")
