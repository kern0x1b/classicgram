#!/usr/bin/env python3
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = os.path.join(ROOT, "src", "Resources", "Localization", "*.lproj", "Localizable.strings")
ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', re.M | re.S)
SPECIFIER = re.compile(
    r'%(?:(\d+)\$)?[-+ #0]*[0-9]*\.?[0-9]*(?:hh|h|ll|l|q|L|z|t|j)?([diouxXeEfgGaAcsp@%])')
FORMAT_CALL = re.compile(
    r'(?:stringWithFormat|initWithFormat|appendFormat|stringByAppendingFormat):\s*'
    r'TGL\(\s*@"((?:[^"\\]|\\.)*)"', re.S)


def table_from(text):
    return {m.group(1): m.group(2) for m in ENTRY.finditer(text)}


def placeholders(value):
    return collections.Counter(
        "positional" if m.group(1) else "plain"
        for m in SPECIFIER.finditer(value) if m.group(2) != "%")


def stray_per_cent(value):
    return "%" in SPECIFIER.sub("", value)


def mismatches_in(language, english, translated, format_keys):
    found = []
    for key, value in sorted(translated.items()):
        if key not in english or key not in format_keys:
            continue
        if key + "_1" in english or key + "_any" in english:
            continue
        if placeholders(english[key]) != placeholders(value):
            found.append((language, key,
                          "takes %s where English takes %s"
                          % (dict(placeholders(value)), dict(placeholders(english[key])))))
    return found


def stray_in(language, translated, format_keys):
    return [(language, key, "holds a per-cent sign that is not a placeholder, and this "
             "key is used as a format string")
            for key, value in sorted(translated.items())
            if key in format_keys and stray_per_cent(value)]


def format_keys_under(root):
    keys = set()
    for base, _, names in os.walk(root):
        if "Resources" in base.split(os.sep):
            continue
        for name in sorted(names):
            if not name.endswith((".m", ".mm")):
                continue
            body = open(os.path.join(base, name), encoding="utf-8", errors="replace").read()
            keys |= set(FORMAT_CALL.findall(body))
    return keys


def self_test():
    english = table_from('"A.Key" = "%1$@ joined %2$@";\n"B.Key" = "Uploading 0%";\n'
                         '"C.Key" = "%d left";\n"C.Key_1" = "%d left";\n"C.Key_any" = "%d left";\n')
    good = table_from('"A.Key" = "%2$@ trat %1$@ bei";\n')
    bad = table_from('"A.Key" = "jemand trat bei";\n')
    keys = {"A.Key", "B.Key", "C.Key"}
    assert not mismatches_in("de", english, good, keys), \
        "a translation may reorder positional placeholders"
    assert mismatches_in("de", english, bad, keys), \
        "a translation that drops a placeholder must be reported"
    assert not mismatches_in("de", english, bad, set()), \
        "a string nothing formats is prose, and prose may say what it likes"
    base_only = table_from('"C.Key" = "%d left";\n')
    assert not mismatches_in("de", english, base_only, keys), \
        "the documentation row of a plural family is not compared"
    assert stray_in("tr", table_from('"B.Key" = "%0 yükleniyor";\n'), {"B.Key"}), \
        "a per-cent sign in a string used as a format must be reported"
    assert not stray_in("tr", table_from('"B.Key" = "%0 yükleniyor";\n'), set()), \
        "and is only a problem where the string is formatted"
    assert not stray_in("de", table_from('"B.Key" = "40%% fertig";\n'), {"B.Key"}), \
        "an escaped per-cent sign is fine"
    print("lint-translation-placeholders: self-test passed")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    english_path = os.path.join(ROOT, "src", "Resources", "Localization", "en.lproj",
                                "Localizable.strings")
    english = table_from(open(english_path, encoding="utf-8").read())
    keys = format_keys_under(os.path.join(ROOT, "src"))

    found = []
    languages = 0
    for path in sorted(glob.glob(TABLES)):
        language = os.path.basename(os.path.dirname(path))
        if language == "en.lproj":
            continue
        languages += 1
        translated = table_from(open(path, encoding="utf-8").read())
        found += mismatches_in(language, english, translated, keys)
        found += stray_in(language, translated, keys)

    if not found:
        print("lint-translation-placeholders: in every one of %d translations, each string "
              "the app formats takes the arguments English takes" % languages)
        return 0
    for language, key, reason in found:
        print("%s %s %s" % (language, key, reason))
    print("lint-translation-placeholders: %d row(s) that would be formatted wrongly"
          % len(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
