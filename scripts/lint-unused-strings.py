#!/usr/bin/env python3
"""Localisation lint/extraction tool.

Two jobs, run over every .m file under src/ (nothing vendored lives there anymore):

1. Extract every already-migrated TGL(@"Key", @"Fallback") / TGLPlural(@"Key", count, @"Fallback")
   call site and cross-check its key against src/Resources/Localization/en.lproj/Localizable.strings, flagging
   any key used in code that the strings table does not define yet.

2. Flag candidate un-migrated string literals: plain @"..." literals passed to APIs that put text
   in front of the user (titles, messages, placeholders, button/cell text, alert/action-sheet copy),
   heuristically filtered to skip TDLib dictionary keys, @"@type" tags, format-only strings, class
   names and other non-UI literals.

Usage:
    scripts/lint-unused-strings.py                 summary counts per file
    scripts/lint-unused-strings.py --list          also print every candidate literal, file:line
    scripts/lint-unused-strings.py --missing-keys  print TGL() keys absent from Localizable.strings
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
STRINGS_FILE = os.path.join(ROOT, 'src', 'Resources', 'Localization', 'en.lproj', 'Localizable.strings')

TGL_FULL_CALL_RE = re.compile(r'\bTGL(?:Plural)?\(((?:[^()]|\([^()]*\))*)\)')
TGL_KEY_RE = re.compile(r'^\s*@"((?:[^"\\]|\\.)*)"')
TGL_ARGS_RE = re.compile(r'@"((?:[^"\\]|\\.)*)"')
LITERAL_RE = re.compile(r'@"((?:[^"\\]|\\.)*)"')

UI_SINK_RE = re.compile(
    r'\.text\s*=|\.attributedText\s*=|\.title\s*=|\.placeholder\s*=|\.message\s*=|'
    r'setTitle\s*:|initWithTitle\s*:|addButtonWithTitle\s*:|'
    r'otherButtonTitles\s*:|cancelButtonTitle\s*:|destructiveButtonTitle\s*:|'
    r'titleForRow\s*:|headerTitle\s*:|footerTitle\s*:|'
    r'\w*Titles?\s*:|'
    r'\bmessage\s*:|\bcaption\s*:|\bdetail\s*:|\btext\s*:|'
    r'\bplaceholder\s*:|\bhint\s*:|\bhintText\s*:|\bsubtitle\s*:|\bprompt\s*:'
)

NON_UI_LITERAL_RE = re.compile(
    r'^(@type|https?://|[A-Za-z0-9+/]{20,}={0,2}$|'
    r'[A-Za-z0-9_.-]+\.(png|jpg|jpeg|gif)$|'
    r'(mailto|tel):$|'
    r'[a-z][a-z0-9+.-]*:%|'
    r'[a-z0-9-]+\.[a-z]{2,3}/|'
    r'%[-+ #0]*[0-9]*\.?[0-9]*(hh|h|l|ll|q|L)?[a-zA-Z@]$)'
)

NON_UI_KEYWORD_RE = re.compile(
    r'\b(asset|imageNamed|plate|stretchableImageNamed)\s*:\s*$'
)


def iter_source_files():
    for dirpath, dirnames, filenames in os.walk(SRC):
        for name in filenames:
            if name.endswith('.m'):
                yield os.path.join(dirpath, name)


def load_strings_table():
    keys = set()
    if not os.path.exists(STRINGS_FILE):
        return keys
    with open(STRINGS_FILE, 'r', encoding='utf-8') as handle:
        for line in handle:
            match = re.match(r'\s*"((?:[^"\\]|\\.)*)"\s*=', line)
            if match:
                keys.add(match.group(1))
    return keys


def looks_like_ui_text(text):
    if len(text) < 2:
        return False
    unescaped = text.replace('\\n', '\n').replace('\\t', '\t')
    if not unescaped.strip():
        return False
    if not re.search(r'[A-Za-z]', unescaped.strip()):
        return False
    if text.startswith('%') and '%' in text[1:]:
        return False
    if re.match(r'^[a-z][a-zA-Z0-9]*$', text):
        return False
    if re.match(r'^[a-z_]+(\.[a-z_]+)*$', text):
        return False
    if re.match(r'^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$', text):
        return False
    if text.startswith('TG') or text.startswith('kTG'):
        return False
    if NON_UI_LITERAL_RE.match(text):
        return False
    return True


def scan_file(path):
    migrated_keys = []
    candidates = []
    key_fallbacks = []
    with open(path, 'r', encoding='utf-8', errors='replace') as handle:
        content = handle.read()

    def lineno_at(pos):
        return content.count('\n', 0, pos) + 1

    call_spans = []
    for match in TGL_FULL_CALL_RE.finditer(content):
        args = TGL_ARGS_RE.findall(match.group(1))
        lineno = lineno_at(match.start())
        if args:
            migrated_keys.append((lineno, args[0]))
            if len(args) >= 2:
                key_fallbacks.append((args[0], args[-1]))
        call_spans.append(match.span())

    def in_call(pos):
        return any(s <= pos < e for s, e in call_spans)

    for match in LITERAL_RE.finditer(content):
        if in_call(match.start()):
            continue
        text = match.group(1)
        if not looks_like_ui_text(text):
            continue
        preceding = content[max(0, match.start() - 40):match.start()]
        if NON_UI_KEYWORD_RE.search(preceding):
            continue
        line_start = content.rfind('\n', 0, match.start()) + 1
        prev_line_start = content.rfind('\n', 0, max(0, line_start - 1)) + 1 if line_start > 0 else 0
        line_end = content.find('\n', match.end())
        if line_end == -1:
            line_end = len(content)
        region = content[prev_line_start:line_end]
        if not UI_SINK_RE.search(region):
            continue
        candidates.append((lineno_at(match.start()), text))
    return migrated_keys, candidates, key_fallbacks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--missing-keys', action='store_true')
    parser.add_argument('--dump-strings', action='store_true')
    args = parser.parse_args()

    table_keys = load_strings_table()
    total_candidates = 0
    total_migrated = 0
    missing_keys = []
    per_file = []
    all_key_fallbacks = []

    for path in sorted(iter_source_files()):
        rel = os.path.relpath(path, ROOT)
        migrated, candidates, key_fallbacks = scan_file(path)
        total_migrated += len(migrated)
        total_candidates += len(candidates)
        all_key_fallbacks.extend(key_fallbacks)
        for lineno, key in migrated:
            if key not in table_keys:
                missing_keys.append((rel, lineno, key))
        if migrated or candidates:
            per_file.append((rel, len(migrated), len(candidates), candidates))

    if args.dump_strings:
        seen = {}
        for key, fallback in all_key_fallbacks:
            seen.setdefault(key, fallback)
        for key in sorted(seen):
            escaped = seen[key].replace('\\', '\\\\').replace('"', '\\"')
            print('"%s" = "%s";' % (key, escaped))
        return

    if args.missing_keys:
        for rel, lineno, key in missing_keys:
            print('%s:%d: TGL key not in Localizable.strings: %s' % (rel, lineno, key))
        print('%d missing key(s)' % len(missing_keys))
        return 1 if missing_keys else 0

    if args.list:
        for rel, migrated_count, candidate_count, candidates in per_file:
            for lineno, text in candidates:
                print('%s:%d: %s' % (rel, lineno, text))

    print('files scanned      : %d' % len(list(iter_source_files())))
    print('migrated TGL() uses : %d' % total_migrated)
    print('candidate literals  : %d (not yet migrated)' % total_candidates)
    print('TGL keys missing from Localizable.strings: %d' % len(missing_keys))

    print('')
    print('top files by remaining candidate count:')
    for rel, migrated_count, candidate_count, _ in sorted(per_file, key=lambda row: -row[2])[:20]:
        if candidate_count:
            print('  %-55s migrated=%-4d remaining=%-4d' % (rel, migrated_count, candidate_count))


if __name__ == '__main__':
    sys.exit(main())
