#!/usr/bin/env python3
import sys, os, re

def strip(text):
    out = []
    i = 0
    n = len(text)
    state = None
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if state is None:
            if c == '"' or c == "'":
                state = c
                out.append(c)
                i += 1
                continue
            if c == '/' and nxt == '/':
                j = text.find('\n', i)
                i = n if j < 0 else j
                continue
            if c == '/' and nxt == '*':
                j = text.find('*/', i + 2)
                i = n if j < 0 else j + 2
                continue
            out.append(c)
            i += 1
            continue
        out.append(c)
        if c == '\\' and i + 1 < n:
            out.append(text[i + 1])
            i += 2
            continue
        if c == state:
            state = None
        i += 1
    text = ''.join(out)
    text = re.sub(r'[ \t]+\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'\{\n\n+', '{\n', text)
    text = re.sub(r'\n\n+\}', '\n}', text)
    return text.lstrip('\n')

def has_comment(text):
    return strip(text) != text

def main():
    check = '--check' in sys.argv
    paths = [a for a in sys.argv[1:] if not a.startswith('-')]
    if not paths:
        paths = ['src']
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                for name in names:
                    if name.endswith(('.m', '.h', '.c', '.mm')):
                        files.append(os.path.join(root, name))
        else:
            files.append(p)
    offenders = []
    for f in sorted(files):
        src = open(f, encoding='utf-8').read()
        out = strip(src)
        if out == src:
            continue
        offenders.append(f)
        if not check:
            open(f, 'w', encoding='utf-8').write(out)
    if check and offenders:
        for f in offenders:
            print('comment in', f)
        return 1
    if not check:
        print('stripped', len(offenders), 'files')
    return 0

if __name__ == '__main__':
    sys.exit(main())
