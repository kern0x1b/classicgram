import mmap, struct, sys


class Image(object):
    def __init__(self, path, needle=None):
        self.f = open(path, 'rb')
        self.m = mmap.mmap(self.f.fileno(), 0, access=mmap.ACCESS_READ)
        m = self.m
        if m[:8] == b'dyld_v1 ':
            mappingOffset, mappingCount, imagesOffset, imagesCount = struct.unpack_from('<IIII', m, 0x10)
            self.mappings = []
            for i in range(mappingCount):
                off = mappingOffset + i * 32
                addr, size, foff, maxp, initp = struct.unpack_from('<QQQII', m, off)
                self.mappings.append((addr, size, foff))
            self.images = []
            for i in range(imagesCount):
                off = imagesOffset + i * 32
                addr, mtime, inode, pathoff, pad = struct.unpack_from('<QQQII', m, off)
                end = m.find(b'\x00', pathoff)
                self.images.append((addr, m[pathoff:end].decode()))
            base = None
            for addr, p in self.images:
                if needle in p:
                    base = addr
                    self.imagepath = p
                    break
            if base is None:
                raise KeyError(needle)
        else:
            self.mappings = None
            base = None
            self.imagepath = path
        self.base = base if base is not None else 0
        self._loadmacho()

    def off(self, vmaddr):
        if self.mappings:
            for addr, size, foff in self.mappings:
                if addr <= vmaddr < addr + size:
                    return foff + (vmaddr - addr)
            raise KeyError(hex(vmaddr))
        for segname, vmad, vmsize, fileoff in self.segs:
            if vmad <= vmaddr < vmad + vmsize:
                return fileoff + (vmaddr - vmad)
        raise KeyError(hex(vmaddr))

    def read(self, vmaddr, n):
        o = self.off(vmaddr)
        return self.m[o:o + n]

    def u32(self, vmaddr):
        return struct.unpack_from('<I', self.m, self.off(vmaddr))[0]

    def cstr(self, vmaddr):
        o = self.off(vmaddr)
        e = self.m.find(b'\x00', o)
        return self.m[o:e].decode('utf-8', 'replace')

    def _loadmacho(self):
        if self.mappings:
            hdr = self.read(self.base, 28)
        else:
            hdr = self.m[0:28]
        magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags = struct.unpack('<IIIIIII', hdr)
        assert magic == 0xfeedface, hex(magic)
        self.segs = []
        self.sections = {}
        p = self.base + 28
        for _ in range(ncmds):
            if self.mappings:
                cmd, cmdsize = struct.unpack('<II', self.read(p, 8))
                d = self.read(p, cmdsize)
            else:
                cmd, cmdsize = struct.unpack_from('<II', self.m, p)
                d = self.m[p:p + cmdsize]
            if cmd == 0x1:
                segname = d[8:24].rstrip(b'\x00').decode()
                vmaddr, vmsize, fileoff, filesize, maxp, initp, nsects, fl = struct.unpack_from('<IIIIIIII', d, 24)
                self.segs.append((segname, vmaddr, vmsize, fileoff))
                for i in range(nsects):
                    so = 56 + i * 68
                    sectname = d[so:so + 16].rstrip(b'\x00').decode()
                    sg = d[so + 16:so + 32].rstrip(b'\x00').decode()
                    saddr, ssize, soff = struct.unpack_from('<III', d, so + 32)
                    self.sections[(sg, sectname)] = (saddr, ssize)
            p += cmdsize

    def sect(self, seg, name):
        return self.sections.get((seg, name))


def class_ro(im, cls):
    isa, superclass, cache, vtable, data = struct.unpack('<IIIII', im.read(cls, 20))
    return data & ~3, superclass, isa


def ro_fields(im, ro):
    d = im.read(ro, 40)
    flags, start, size, ivarlayout, name = struct.unpack_from('<IIIII', d, 0)
    baseMethods, baseProtocols, ivars, weakIvarLayout, baseProperties = struct.unpack_from('<IIIII', d, 20)
    return dict(flags=flags, name=im.cstr(name), methods=baseMethods,
                protocols=baseProtocols, ivars=ivars, properties=baseProperties)


def methods(im, listaddr):
    res = []
    if not listaddr:
        return res
    entsize, count = struct.unpack('<II', im.read(listaddr, 8))
    entsize &= ~3
    for i in range(count):
        nm, types, imp = struct.unpack('<III', im.read(listaddr + 8 + i * entsize, 12))
        res.append((im.cstr(nm), im.cstr(types), imp))
    return res


def ivars(im, listaddr):
    res = []
    if not listaddr:
        return res
    entsize, count = struct.unpack('<II', im.read(listaddr, 8))
    for i in range(count):
        offp, nm, types, align, size = struct.unpack('<IIIII', im.read(listaddr + 8 + i * entsize, 20))
        off = im.u32(offp) if offp else -1
        res.append((im.cstr(nm), im.cstr(types), off))
    return res


def classes(im):
    out = []
    s = im.sect('__DATA', '__objc_classlist')
    if not s:
        return out
    addr, size = s
    for i in range(size // 4):
        cls = im.u32(addr + i * 4)
        ro, sup, isa = class_ro(im, cls)
        f = ro_fields(im, ro)
        out.append((f['name'], cls, sup, isa, ro))
    return out


def dump(im, pattern=None, methods_too=True):
    for name, cls, sup, isa, ro in sorted(classes(im)):
        if pattern and pattern.lower() not in name.lower():
            continue
        f = ro_fields(im, ro)
        try:
            supname = ro_fields(im, class_ro(im, sup)[0])['name'] if sup else '?'
        except Exception:
            supname = '?'
        print('@interface %s : %s' % (name, supname))
        for nm, ty, off in ivars(im, f['ivars']):
            print('   ivar %-40s %s @%d' % (nm, ty, off))
        if methods_too:
            mro = ro_fields(im, class_ro(im, isa)[0])
            for nm, ty, imp in methods(im, mro['methods']):
                print('   + %-60s %-20s 0x%x' % (nm, ty, imp))
            for nm, ty, imp in methods(im, f['methods']):
                print('   - %-60s %-20s 0x%x' % (nm, ty, imp))
        print('@end')


if __name__ == '__main__':
    path = sys.argv[1]
    needle = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != '-' else None
    pattern = sys.argv[3] if len(sys.argv) > 3 else None
    im = Image(path, needle)
    dump(im, pattern)
