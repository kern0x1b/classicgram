import struct, sys
from objcdump import Image

BIND_OPCODE_MASK = 0xF0
BIND_IMMEDIATE_MASK = 0x0F


def uleb(m, p):
    r = 0
    s = 0
    while True:
        b = m[p]
        p += 1
        r |= (b & 0x7f) << s
        if not (b & 0x80):
            break
        s += 7
    return r, p


def sleb(m, p):
    r = 0
    s = 0
    while True:
        b = m[p]
        p += 1
        r |= (b & 0x7f) << s
        s += 7
        if not (b & 0x80):
            if b & 0x40:
                r |= -(1 << s)
            break
    return r, p


def parse(im):
    out = {}
    p = im.base + 28
    magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags = struct.unpack_from('<IIIIIII', im.m, 0)
    infos = []
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', im.m, p)
        if cmd in (0x22, 0x80000022):
            d = struct.unpack_from('<10I', im.m, p + 8)
            rebase_off, rebase_size, bind_off, bind_size, weak_off, weak_size, lazy_off, lazy_size, exp_off, exp_size = d
            infos.append((bind_off, bind_size))
            infos.append((lazy_off, lazy_size))
            infos.append((weak_off, weak_size))
        p += cmdsize
    segs = [(s[1], s[2]) for s in im.segs]
    for off, size in infos:
        if not size:
            continue
        m = im.m
        p = off
        end = off + size
        segidx = 0
        segoff = 0
        sym = ''
        while p < end:
            b = m[p]
            p += 1
            op = b & BIND_OPCODE_MASK
            imm = b & BIND_IMMEDIATE_MASK
            if op == 0x00:
                pass
            elif op == 0x10:
                pass
            elif op == 0x20:
                _, p = uleb(m, p)
            elif op == 0x30:
                pass
            elif op == 0x40:
                e = m.find(b'\x00', p)
                sym = m[p:e].decode()
                p = e + 1
            elif op == 0x50:
                pass
            elif op == 0x60:
                _, p = sleb(m, p)
            elif op == 0x70:
                segidx = imm
                segoff, p = uleb(m, p)
            elif op == 0x80:
                d, p = uleb(m, p)
                segoff = (segoff + d) & 0xffffffff
            elif op == 0x90:
                out[(segs[segidx][0] + segoff) & 0xffffffff] = sym
                segoff = (segoff + 4) & 0xffffffff
            elif op == 0xA0:
                out[(segs[segidx][0] + segoff) & 0xffffffff] = sym
                d, p = uleb(m, p)
                segoff = (segoff + 4 + d) & 0xffffffff
            elif op == 0xB0:
                out[(segs[segidx][0] + segoff) & 0xffffffff] = sym
                segoff = (segoff + 4 + imm*4) & 0xffffffff
            elif op == 0xC0:
                cnt, p = uleb(m, p)
                skip, p = uleb(m, p)
                for _ in range(cnt):
                    out[(segs[segidx][0] + segoff) & 0xffffffff] = sym
                    segoff = (segoff + 4 + skip) & 0xffffffff
            else:
                break
    return out


if __name__ == '__main__':
    im = Image(sys.argv[1], None)
    b = parse(im)
    needle = sys.argv[2] if len(sys.argv) > 2 else None
    for a in sorted(b):
        if needle and needle not in b[a]:
            continue
        print('%08x %s' % (a, b[a]))
