import struct, sys
from capstone import *
from capstone.arm import *
from objcdump import Image, classes, class_ro, ro_fields


def find_cstring(im, needle):
    b = needle.encode()
    hits = []
    for seg, nm in [('__TEXT', '__cstring'), ('__TEXT', '__const'), ('__DATA', '__data'),
                    ('__TEXT', '__ustring'), ('__TEXT', '__objc_methname')]:
        s = im.sect(seg, nm)
        if not s:
            continue
        addr, size = s
        off = im.off(addr)
        blob = im.m[off:off + size]
        i = 0
        while True:
            i = blob.find(b, i)
            if i < 0:
                break
            hits.append(addr + i)
            i += 1
    return hits


def cfstrings_for(im, straddr):
    out = []
    s = im.sect('__DATA', '__cfstring')
    if not s:
        return out
    addr, size = s
    for i in range(0, size, 16):
        try:
            isa, flags, sp, ln = struct.unpack('<IIII', im.read(addr + i, 16))
        except Exception:
            continue
        if sp in straddr:
            out.append(addr + i)
    return out


def method_index(im):
    idx = []
    for name, cls, sup, isa, ro in classes(im):
        f = ro_fields(im, ro)
        from objcdump import methods
        for nm, ty, imp in methods(im, f['methods']):
            idx.append((imp & ~1, '-[%s %s]' % (name, nm)))
        try:
            mro = ro_fields(im, class_ro(im, isa)[0])
            for nm, ty, imp in methods(im, mro['methods']):
                idx.append((imp & ~1, '+[%s %s]' % (name, nm)))
        except Exception:
            pass
    idx.sort()
    return idx


def owner(idx, addr):
    import bisect
    i = bisect.bisect_right([a for a, _ in idx], addr) - 1
    if i < 0:
        return '?'
    return idx[i][1]


def disasm_all(md, data, addr):
    pos = 0
    while pos < len(data):
        last = pos
        for ins in md.disasm(data[pos:], addr + pos):
            yield ins
            last = ins.address - addr + ins.size
        if last <= pos:
            pos += 2
        else:
            pos = last + 2


def scan(im, targets):
    md = Cs(CS_ARCH_ARM, CS_MODE_THUMB)
    md.detail = True
    addr, size = im.sect('__TEXT', '__text')
    off = im.off(addr)
    data = im.m[off:off + size]
    idx = method_index(im)
    hits = set()
    regs = {}
    for ins in disasm_all(md, data, addr):
        ops = ins.operands
        if ins.mnemonic.startswith('movw') and len(ops) == 2 and ops[1].type == ARM_OP_IMM:
            regs[ops[0].reg] = ops[1].imm & 0xffff
        elif ins.mnemonic.startswith('movt') and len(ops) == 2 and ops[1].type == ARM_OP_IMM:
            regs[ops[0].reg] = (regs.get(ops[0].reg, 0) & 0xffff) | ((ops[1].imm & 0xffff) << 16)
        elif ins.mnemonic == 'add' and len(ops) >= 2 and ops[-1].type == ARM_OP_REG and ops[-1].reg == ARM_REG_PC:
            r = ops[0].reg
            if r in regs:
                v = (regs[r] + ins.address + 4) & 0xffffffff
                regs[r] = v
                if v in targets:
                    hits.add((owner(idx, ins.address), '%08x' % ins.address, '%08x' % v))
        elif ins.mnemonic.startswith('ldr') and len(ops) == 2 and ops[1].type == ARM_OP_MEM:
            if ops[1].mem.base == ARM_REG_PC:
                v = ((ins.address + 4) & ~3) + ops[1].mem.disp
                try:
                    val = im.u32(v)
                    regs[ops[0].reg] = val
                    if val in targets:
                        hits.add((owner(idx, ins.address), '%08x' % ins.address, '%08x' % val))
                except Exception:
                    pass
    return hits


if __name__ == '__main__':
    im = Image(sys.argv[1], None)
    needle = sys.argv[2]
    straddr = set(find_cstring(im, needle))
    cfs = set(cfstrings_for(im, straddr))
    print('cstring at', [hex(a) for a in straddr], 'cfstring at', [hex(a) for a in cfs])
    targets = straddr | cfs
    for h in sorted(scan(im, targets)):
        print(h)
