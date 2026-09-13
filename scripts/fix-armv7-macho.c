#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define MH_MAGIC        0xfeedfaceu
#define LC_SEGMENT      0x1
#define LC_DYLD_INFO_ONLY 0x80000022u
#define LC_MAIN         0x80000028u
#define LC_VERSION_MIN_IPHONEOS 0x25

#define REBASE_OPCODE_MASK 0xF0
#define REBASE_IMM_MASK    0x0F
#define REBASE_DONE                             0x00
#define REBASE_SET_TYPE_IMM                     0x10
#define REBASE_SET_SEGMENT_AND_OFFSET_ULEB      0x20
#define REBASE_ADD_ADDR_ULEB                    0x30
#define REBASE_ADD_ADDR_IMM_SCALED              0x40
#define REBASE_DO_REBASE_IMM_TIMES              0x50
#define REBASE_DO_REBASE_ULEB_TIMES             0x60
#define REBASE_DO_REBASE_ADD_ADDR_ULEB          0x70
#define REBASE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB 0x80

#define MAX_SEGS 16

struct seg { uint32_t vmaddr, vmsize, fileoff, filesize; char name[17]; };

static uint8_t *buf;
static long     buflen;
static struct seg segs[MAX_SEGS];
static int      nsegs;
static uint32_t text_lo, text_hi;
static long     patched_ptrs;

static uint32_t rd32(long off) { uint32_t v; memcpy(&v, buf + off, 4); return v; }
static void     wr32(long off, uint32_t v) { memcpy(buf + off, &v, 4); }

static uint64_t uleb(const uint8_t **p, const uint8_t *end)
{
	uint64_t r = 0; int s = 0;
	while (*p < end) {
		uint8_t b = *(*p)++;
		r |= (uint64_t)(b & 0x7f) << s;
		s += 7;
		if (!(b & 0x80)) break;
	}
	return r;
}

static long vm2off(uint32_t vmaddr)
{
	for (int i = 0; i < nsegs; i++) {
		if (segs[i].filesize == 0) continue;
		if (vmaddr >= segs[i].vmaddr && vmaddr < segs[i].vmaddr + segs[i].filesize)
			return (long)segs[i].fileoff + (vmaddr - segs[i].vmaddr);
	}
	return -1;
}

static void fix_slot(uint32_t vmaddr)
{
	long off = vm2off(vmaddr);
	if (off < 0 || off + 4 > buflen) return;

	uint32_t v = rd32(off);
	if (v & 1) return;
	if (v < text_lo || v >= text_hi) return;

	wr32(off, v | 1);
	patched_ptrs++;
}

static void walk_rebases(const uint8_t *p, const uint8_t *end)
{
	uint32_t addr = 0;
	int seg = -1;

	while (p < end) {
		uint8_t op = *p++;
		uint8_t imm = op & REBASE_IMM_MASK;

		switch (op & REBASE_OPCODE_MASK) {
		case REBASE_DONE:
			return;
		case REBASE_SET_TYPE_IMM:
			break;
		case REBASE_SET_SEGMENT_AND_OFFSET_ULEB:
			seg = imm;
			if (seg >= nsegs) return;
			addr = segs[seg].vmaddr + (uint32_t)uleb(&p, end);
			break;
		case REBASE_ADD_ADDR_ULEB:
			addr += (uint32_t)uleb(&p, end);
			break;
		case REBASE_ADD_ADDR_IMM_SCALED:
			addr += imm * 4;
			break;
		case REBASE_DO_REBASE_IMM_TIMES:
			for (int i = 0; i < imm; i++) { fix_slot(addr); addr += 4; }
			break;
		case REBASE_DO_REBASE_ULEB_TIMES: {
			uint64_t n = uleb(&p, end);
			for (uint64_t i = 0; i < n; i++) { fix_slot(addr); addr += 4; }
			break;
		}
		case REBASE_DO_REBASE_ADD_ADDR_ULEB:
			fix_slot(addr);
			addr += 4 + (uint32_t)uleb(&p, end);
			break;
		case REBASE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB: {
			uint64_t n = uleb(&p, end);
			uint64_t skip = uleb(&p, end);
			for (uint64_t i = 0; i < n; i++) { fix_slot(addr); addr += 4 + (uint32_t)skip; }
			break;
		}
		default:
			fprintf(stderr, "machofix: unknown rebase opcode 0x%02x\n", op);
			return;
		}
	}
}

int main(int argc, char **argv)
{
	if (argc < 2) { fprintf(stderr, "usage: %s <binary>\n", argv[0]); return 2; }

	FILE *f = fopen(argv[1], "r+b");
	if (!f) { perror(argv[1]); return 1; }
	fseek(f, 0, SEEK_END); buflen = ftell(f); fseek(f, 0, SEEK_SET);
	buf = malloc(buflen);
	if (!buf || fread(buf, 1, buflen, f) != (size_t)buflen) {
		fprintf(stderr, "machofix: cannot read %s\n", argv[1]); return 1;
	}

	if (rd32(0) != MH_MAGIC) {
		fprintf(stderr, "machofix: not a 32-bit little-endian Mach-O, skipping\n");
		fclose(f); return 0;
	}

	uint32_t ncmds = rd32(16);
	long pagezero_vmsize_off = -1, entryoff_off = -1;
	long rebase_off = 0, rebase_size = 0;

	long off = 28;
	for (uint32_t i = 0; i < ncmds && off + 8 <= buflen; i++) {
		uint32_t cmd = rd32(off), cmdsize = rd32(off + 4);
		if (cmdsize < 8) break;

		if (cmd == LC_SEGMENT && nsegs < MAX_SEGS) {
			struct seg *s = &segs[nsegs++];
			memcpy(s->name, buf + off + 8, 16); s->name[16] = 0;
			s->vmaddr   = rd32(off + 24);
			s->vmsize   = rd32(off + 28);
			s->fileoff  = rd32(off + 32);
			s->filesize = rd32(off + 36);

			if (!strcmp(s->name, "__PAGEZERO"))
				pagezero_vmsize_off = off + 28;

			uint32_t nsects = rd32(off + 48);
			long soff = off + 56;
			for (uint32_t k = 0; k < nsects; k++, soff += 68) {
				if (!memcmp(buf + soff, "__text\0", 7) &&
				    !memcmp(buf + soff + 16, "__TEXT\0", 7)) {
					text_lo = rd32(soff + 32);
					text_hi = text_lo + rd32(soff + 36);
				}
			}
		} else if (cmd == LC_MAIN) {
			entryoff_off = off + 8;
		} else if (cmd == LC_VERSION_MIN_IPHONEOS) {
			uint32_t sdk = rd32(off + 12);
			if (sdk < 0x00070000) {
				wr32(off + 12, 0x00070000);
				printf("machofix: LC_VERSION_MIN sdk %u.%u -> 7.0\n",
						sdk >> 16, (sdk >> 8) & 0xff);
			}
		} else if (cmd == LC_DYLD_INFO_ONLY) {
			rebase_off  = rd32(off + 8);
			rebase_size = rd32(off + 12);
		}
		off += cmdsize;
	}

	if (!text_hi) { fprintf(stderr, "machofix: no (__TEXT,__text) section\n"); return 1; }

	if (pagezero_vmsize_off >= 0) {
		uint32_t old = rd32(pagezero_vmsize_off);
		if (old != 0x1000) {
			wr32(pagezero_vmsize_off, 0x1000);
			printf("machofix: __PAGEZERO vmsize 0x%x -> 0x1000\n", old);
		}
	}

	if (entryoff_off >= 0) {
		uint32_t lo = rd32(entryoff_off);
		if (!(lo & 1)) {
			wr32(entryoff_off, lo | 1);
			printf("machofix: LC_MAIN entryoff 0x%x -> 0x%x (Thumb)\n", lo, lo | 1);
		}
	}

	if (rebase_size)
		walk_rebases(buf + rebase_off, buf + rebase_off + rebase_size);
	printf("machofix: Thumb bit restored on %ld pointers into __TEXT,__text\n", patched_ptrs);

	fseek(f, 0, SEEK_SET);
	if (fwrite(buf, 1, buflen, f) != (size_t)buflen) {
		fprintf(stderr, "machofix: write failed\n"); return 1;
	}
	fclose(f);
	return 0;
}
