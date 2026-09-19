import re

from tglint import tree

SINKS = (
    r"\.(?:text|title|placeholder|prompt)\s*=\s*",
    r"setTitle:",
    r"setText:",
    r"setPlaceholder:",
    r"initWithTitle:",
    r"otherButtonTitles:",
    r"cancelButtonTitle:",
    r"destructiveButtonTitle:",
    r"message:",
)
SINK_RE = re.compile(r"(?:" + r"|".join(SINKS) + r')@"((?:[^"\\]|\\.)*)"')
WORD_RE = re.compile(r"[A-Za-z]{2,}")


def looks_like_prose(text):
    if not WORD_RE.search(text):
        return False
    if " " in text.strip():
        return True
    return bool(re.match(r"^[A-Z][a-z]{2,}$", text))


def main(args):
    bare = []
    for path in tree.walk(tree.SRC):
        text = tree.read(path)
        relative = tree.relative(path)
        for match in SINK_RE.finditer(text):
            literal = match.group(1)
            if not looks_like_prose(literal):
                continue
            bare.append((relative, tree.line_at(text, match.start()), literal))

    for relative, line, literal in bare:
        print(f'[NEW] {relative}:{line} "{literal}" reaches the screen as an English literal; '
              f"wrap it in TGL with a Localizable.strings key")

    if bare:
        print(f"lint-bare-ui-strings: {len(bare)} unlocalized user-visible literal(s)")
        return 1
    print("lint-bare-ui-strings: every literal handed to a title, label, alert or sheet goes through TGL")
    return 0
