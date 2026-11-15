#!/usr/bin/env python3
"""(3.126.0, asked 15-11-2026: "app updet krtana je kahi new updet aley tech fkt updet hoil … pratek weli full app download krayla ka
lawatoys") THE SMALL UPDATE: a file with only what changed between the app file of an earlier version and the new one.

  make  <old.apk> <new.apk> <out.patch>   – written by the release (.github/workflows/release.yml); needs "pip install bsdiff4"
  apply <old.apk> <patch> <out.apk>       – what the phone does (lib/core/apk_patch.dart), here to check every patch the release makes

The file: the 6 bytes "RCLP1\\n", then ONE zlib stream of
  int64 size of the new file, then until that many bytes are made:
  int64 x, int64 y, int64 z · x bytes (each ADDED to the byte of the old file at its place) · y bytes (new, as they are)
  – after it the place in the old file moves on by x + z. Every int64: little-endian, signed.
The new file made from it is byte for byte the released one (its SHA-256 is checked on the phone before it is installed)."""
import struct, sys, zlib

MAGIC = b'RCLP1\n'


def _off(b):  # bsdiff's own number: 8 bytes, the sign in the top bit
    v = int.from_bytes(b, 'little') & 0x7FFFFFFFFFFFFFFF
    return -v if b[7] & 0x80 else v


def make(old_path, new_path, out_path):
    import bsdiff4.core as core
    old, new = open(old_path, 'rb').read(), open(new_path, 'rb').read()
    control, diff, extra = core.diff(old, new)
    z = zlib.compressobj(9)
    out = [MAGIC, z.compress(struct.pack('<q', len(new)))]
    dp = ep = made = 0
    for i in range(0, len(control), 24):
        x, y, s = _off(control[i:i + 8]), _off(control[i + 8:i + 16]), _off(control[i + 16:i + 24])
        out.append(z.compress(struct.pack('<qqq', x, y, s)))
        out.append(z.compress(diff[dp:dp + x])); dp += x
        out.append(z.compress(extra[ep:ep + y])); ep += y
        made += x + y
    if made != len(new) or dp != len(diff) or ep != len(extra):
        raise SystemExit('the patch does not make the whole new file')
    out.append(z.flush())
    open(out_path, 'wb').write(b''.join(out))


def apply(old_path, patch_path, out_path):
    old, p = open(old_path, 'rb').read(), open(patch_path, 'rb').read()
    if p[:len(MAGIC)] != MAGIC:
        raise SystemExit('not a patch file')
    d = zlib.decompress(p[len(MAGIC):])
    size, i, op, out = struct.unpack_from('<q', d, 0)[0], 8, 0, bytearray()
    while len(out) < size:
        x, y, s = struct.unpack_from('<qqq', d, i); i += 24
        if x < 0 or y < 0 or op < 0 or op + x > len(old) or len(out) + x + y > size:
            raise SystemExit('the patch does not fit this file')
        a = int.from_bytes(d[i:i + x], 'little'); b = int.from_bytes(old[op:op + x], 'little')
        # byte-wise add without carry between bytes
        m = int.from_bytes(b'\x7f' * x, 'little')
        out += (((a & m) + (b & m)) ^ ((a ^ b) & ~m & ((1 << (8 * x)) - 1))).to_bytes(x, 'little') if x else b''
        i += x
        out += d[i:i + y]; i += y
        op += x + s
    open(out_path, 'wb').write(out)


if __name__ == '__main__':
    if len(sys.argv) != 5 or sys.argv[1] not in ('make', 'apply'):
        raise SystemExit(__doc__)
    (make if sys.argv[1] == 'make' else apply)(*sys.argv[2:])
