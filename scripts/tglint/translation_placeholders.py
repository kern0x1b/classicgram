import collections
import glob
import os
import re

from tglint import tree

TABLES = os.path.join(tree.LOCALIZATION, "*.lproj", "Localizable.strings")
SPECIFIER = re.compile(
    r'%(?:(\d+)\$)?[-+ #0]*[0-9]*\.?[0-9]*(?:hh|h|ll|l|q|L|z|t|j)?([diouxXeEfgGaAcsp@%])')
FORMAT_CALL = re.compile(
    r'(?:stringWithFormat|initWithFormat|appendFormat|stringByAppendingFormat):\s*'
    r'TGL\(\s*@"((?:[^"\\]|\\.)*)"', re.S)


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
    for path in tree.walk(root):
        keys |= set(FORMAT_CALL.findall(tree.read(path)))
    return keys


def self_test():
    english = tree.strings_table('"A.Key" = "%1$@ joined %2$@";\n"B.Key" = "Uploading 0%";\n'
                         '"C.Key" = "%d left";\n"C.Key_1" = "%d left";\n"C.Key_any" = "%d left";\n')
    good = tree.strings_table('"A.Key" = "%2$@ trat %1$@ bei";\n')
    bad = tree.strings_table('"A.Key" = "jemand trat bei";\n')
    keys = {"A.Key", "B.Key", "C.Key"}
    assert not mismatches_in("de", english, good, keys), \
        "a translation may reorder positional placeholders"
    assert mismatches_in("de", english, bad, keys), \
        "a translation that drops a placeholder must be reported"
    assert not mismatches_in("de", english, bad, set()), \
        "a string nothing formats is prose, and prose may say what it likes"
    base_only = tree.strings_table('"C.Key" = "%d left";\n')
    assert not mismatches_in("de", english, base_only, keys), \
        "the documentation row of a plural family is not compared"
    assert stray_in("tr", tree.strings_table('"B.Key" = "%0 yükleniyor";\n'), {"B.Key"}), \
        "a per-cent sign in a string used as a format must be reported"
    assert not stray_in("tr", tree.strings_table('"B.Key" = "%0 yükleniyor";\n'), set()), \
        "and is only a problem where the string is formatted"
    assert not stray_in("de", tree.strings_table('"B.Key" = "40%% fertig";\n'), {"B.Key"}), \
        "an escaped per-cent sign is fine"
    print("lint-translation-placeholders: self-test passed")
    return 0


def main(args):
    if "--self-test" in args:
        return self_test()
    english = tree.english_table()
    keys = format_keys_under(tree.SRC)

    found = []
    languages = 0
    for path in sorted(glob.glob(TABLES)):
        language = os.path.basename(os.path.dirname(path))
        if language == "en.lproj":
            continue
        languages += 1
        translated = tree.strings_table(tree.read(path))
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
