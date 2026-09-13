import struct, sys
from capstone import *
from capstone.arm import *
from objcdump import Image, classes, class_ro, ro_fields

im = None
SYMS = {}


def load_symtab(im):
    base = im.base
    if im.mappings:
        hdr = im.read(base, 28)
    else:
        hdr = im.m[0:28]
    magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags = struct.unpack('<IIIIIII', hdr)
    p = base + 28
    for _ in range(ncmds):
        if im.mappings:
            cmd, cmdsize = struct.unpack('<II', im.read(p, 8))
        else:
            cmd, cmdsize = struct.unpack_from('<II', im.m, p)
        if cmd == 0x2:
            if im.mappings:
                symoff, nsyms, stroff, strsize = struct.unpack('<IIII', im.read(p + 8, 16))
            else:
                symoff, nsyms, stroff, strsize = struct.unpack_from('<IIII', im.m, p + 8)
            for i in range(nsyms):
                o = symoff + i * 12
                try:
                    n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from('<IBBHI', im.m, o)
                except Exception:
                    break
                if n_value:
                    e = im.m.find(b'\x00', stroff + n_strx)
                    nm = im.m[stroff + n_strx:e].decode('utf-8', 'replace')
                    SYMS.setdefault(n_value & ~1, nm)
        p += cmdsize


def build_stubs(im):
    s = im.sect('__TEXT', '__symbol_stub4') or im.sect('__TEXT', '__picsymbolstub4')
    if not s:
        return
    # resolve lazily via indirect symbols is overkill; nothing here needs it


def annotate(addr):
    out = []
    for seg, name in [('__DATA', '__objc_selrefs')]:
        pass
    return out


def sect_range(seg, name):
    s = im.sect(seg, name)
    return s if s else (0, 0)


def resolve_literal(v):
    tags = []
    sa, ss = sect_range('__DATA', '__objc_selrefs')
    if sa and sa <= v < sa + ss:
        tags.append('sel:' + im.cstr(im.u32(v)))
    sa, ss = sect_range('__DATA', '__objc_classrefs')
    if sa and sa <= v < sa + ss:
        cls = im.u32(v)
        try:
            tags.append('class:' + ro_fields(im, class_ro(im, cls)[0])['name'])
        except Exception:
            tags.append('classref@%x' % cls)
    sa, ss = sect_range('__DATA', '__objc_superrefs')
    if sa and sa <= v < sa + ss:
        cls = im.u32(v)
        try:
            tags.append('super:' + ro_fields(im, class_ro(im, cls)[0])['name'])
        except Exception:
            pass
    sa, ss = sect_range('__DATA', '__cfstring')
    if sa and sa <= v < sa + ss:
        try:
            isa, flags, sp, ln = struct.unpack('<IIII', im.read(v, 16))
            tags.append('@"%s"' % im.cstr(sp))
        except Exception:
            pass
    for seg, nm in [('__TEXT', '__cstring'), ('__TEXT', '__const'), ('__DATA', '__data')]:
        sa, ss = sect_range(seg, nm)
        if sa and sa <= v < sa + ss and nm == '__cstring':
            tags.append('"%s"' % im.cstr(v))
    if v in SYMS:
        tags.append(SYMS[v])
    if (v & ~1) in SYMS:
        tags.append(SYMS[v & ~1])
    return ' ; '.join(tags)


def disas(start, count=400):
    md = Cs(CS_ARCH_ARM, CS_MODE_THUMB)
    md.detail = True
    data = im.read(start & ~1, count * 4)
    regs = {}
    lastsel = None
    for ins in md.disasm(data, start & ~1):
        line = '%08x  %-8s %s' % (ins.address, ins.mnemonic, ins.op_str)
        note = ''
        ops = ins.operands
        if ins.mnemonic.startswith('movw') and len(ops) == 2 and ops[1].type == ARM_OP_IMM:
            regs[ops[0].reg] = ops[1].imm & 0xffff
        elif ins.mnemonic.startswith('movt') and len(ops) == 2 and ops[1].type == ARM_OP_IMM:
            regs[ops[0].reg] = (regs.get(ops[0].reg, 0) & 0xffff) | ((ops[1].imm & 0xffff) << 16)
        elif ins.mnemonic == 'add' and len(ops) >= 2 and ops[-1].type == ARM_OP_REG and ops[-1].reg == ARM_REG_PC:
            r = ops[0].reg
            if r in regs:
                regs[r] = (regs[r] + ins.address + 4) & 0xffffffff
                note = 'ptr %08x %s' % (regs[r], resolve_literal(regs[r]))
        elif ins.mnemonic.startswith('ldr') and len(ops) == 2 and ops[1].type == ARM_OP_MEM:
            base = ops[1].mem.base
            disp = ops[1].mem.disp
            if base == ARM_REG_PC:
                v = ((ins.address + 4) & ~3) + disp
                try:
                    val = im.u32(v)
                    regs[ops[0].reg] = val
                    note = 'lit %08x %s' % (val, resolve_literal(val))
                except Exception:
                    pass
            elif base in regs and ops[0].reg != base:
                try:
                    val = im.u32(regs[base] + disp)
                    src = resolve_literal(regs[base] + disp)
                    regs[ops[0].reg] = val
                    note = '= %08x %s' % (val, src)
                except Exception:
                    regs.pop(ops[0].reg, None)
            elif base in regs:
                try:
                    src = resolve_literal(regs[base] + disp)
                    val = im.u32(regs[base] + disp)
                    regs[ops[0].reg] = val
                    note = '= %08x %s' % (val, src)
                except Exception:
                    regs.pop(ops[0].reg, None)
            else:
                regs.pop(ops[0].reg, None)
        elif ins.mnemonic in ('mov', 'movs') and len(ops) == 2 and ops[1].type == ARM_OP_REG:
            if ops[1].reg in regs:
                regs[ops[0].reg] = regs[ops[1].reg]
            else:
                regs.pop(ops[0].reg, None)
        elif ins.mnemonic in ('bl', 'blx') and ops and ops[0].type == ARM_OP_IMM:
            tgt = ops[0].imm
            nm = SYMS.get(tgt & ~1) or SYMS.get(tgt) or ''
            sel = regs.get(ARM_REG_R1)
            extra = ''
            if 'msgSend' in nm and sel:
                extra = '  [-> %s]' % resolve_literal(sel)
            note = 'call %08x %s%s' % (tgt, nm, extra)
        if note:
            line += '    ; ' + note
        print(line)
        if ins.mnemonic in ('pop',) and 'pc' in ins.op_str:
            break
        if ins.mnemonic == 'bx' and 'lr' in ins.op_str:
            break


if __name__ == '__main__':
    path = sys.argv[1]
    needle = sys.argv[2] if sys.argv[2] != '-' else None
    im = Image(path, needle)
    load_symtab(im)
    addr = int(sys.argv[3], 16)
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 400
    disas(addr, n)
