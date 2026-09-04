#!/usr/bin/env python3
"""Restore glyphs that Multiverse's bundled fonts are missing.

MV ships its own copies of seven FTL fonts, but they contain fewer glyphs
than vanilla: JustinFont10 has 193 entries where vanilla has 238. The
missing ones include every accented Latin character, so umlauts and
accents silently vanish in any text drawn with those fonts.

This copies the missing glyph bitmaps out of the vanilla atlas into free
space in MV's atlas and appends the table entries, so MV's own symbols
(scrap, drone parts) are kept. No drawing required, since the glyphs
already exist in vanilla.

Usage:
    python font_glyph_patch.py <input-dir> <output-dir>

<input-dir> holds pairs of files named van_<name>.font (extracted from
vanilla ftl.dat) and mv_<name>.font (taken from the MV mod archive).
Patched fonts are written to <output-dir> as <name>.font.

Extract vanilla fonts with any FTL dat unpacker, for example:
    ftlman extract <out> ftl.dat.vanilla

.font format (reverse engineered, FTL 1.6):
    0..3     "FONT"
    4        version
    5, 6     line height, ascent
    12, 13   glyph count (big endian u16)
    14, 15   record size (16)
    16..19   offset of the texture block (big endian u32)
    26..     glyph records, 16 bytes each:
             codepoint (BE u16), x (u16), y (u16), w (u8), h (u8),
             8 bytes of metrics copied through unchanged
    texture: "TEX\\n" plus a 32 byte header (width at 8, height at 10,
             data length at 20), then width*height bytes, 8 bit alpha
"""
import struct, sys, os, glob

# German umlauts first, so they are placed even if space runs out
PRIORITY = [0xC4, 0xD6, 0xDC, 0xE4, 0xF6, 0xFC, 0xDF]


def load(path):
    data = bytearray(open(path, 'rb').read())
    count = struct.unpack_from('>H', data, 12)[0]
    rsize = struct.unpack_from('>H', data, 14)[0]
    toff = struct.unpack_from('>I', data, 16)[0]
    records = {}
    for i in range(count):
        off = 26 + i * rsize
        cp = struct.unpack_from('>H', data, off)[0]
        records[cp] = bytes(data[off:off + rsize])
    header = bytes(data[toff:toff + 32])
    width = struct.unpack_from('>H', header, 8)[0]
    height = struct.unpack_from('>H', header, 10)[0]
    pixels = bytearray(data[toff + 32: toff + 32 + width * height])
    return dict(raw=data, rsize=rsize, records=records, theader=header,
                width=width, height=height, pixels=pixels)


def rect(record):
    x, y = struct.unpack_from('>HH', record, 2)
    return x, y, record[6], record[7]


def used_mask(font):
    mask = bytearray(font['width'] * font['height'])
    for record in font['records'].values():
        x, y, w, h = rect(record)
        for yy in range(y, min(y + h, font['height'])):
            row = yy * font['width']
            for xx in range(x, min(x + w, font['width'])):
                mask[row + xx] = 1
    return mask


def patch(vanilla_path, mv_path, out_path):
    van, mv = load(vanilla_path), load(mv_path)
    missing = [cp for cp in van['records'] if cp not in mv['records']]
    if not missing:
        open(out_path, 'wb').write(bytes(mv['raw']))
        return 0, 0, 'unchanged'
    if van['width'] != mv['width']:
        return 0, 0, 'atlas width differs, skipped'

    order = [c for c in PRIORITY if c in missing] + \
            sorted(c for c in missing if c not in PRIORITY)

    W, H = mv['width'], mv['height']
    note = 'ok'
    needed = sum((van['records'][c][7] + 1) * (van['records'][c][6] + 1)
                 for c in missing)
    free = sum(W for y in range(H)
               if not any(mv['pixels'][y * W + x] for x in range(W)))
    if free < needed * 1.6:                      # grow the atlas if it is tight
        H2 = H * 2
        mv['pixels'] += bytearray(W * (H2 - H))
        th = bytearray(mv['theader'])
        struct.pack_into('>H', th, 10, H2)
        struct.pack_into('>I', th, 20, W * H2)
        mv['theader'] = bytes(th)
        H = mv['height'] = H2
        note = f'atlas grown to {W}x{H2}'

    mask = used_mask(mv)
    first_free = 0
    for y in range(H):
        if any(mask[y * W + x] for x in range(W)):
            first_free = y + 1
    cx, cy, row_h = 0, first_free + 1, 0
    added = []
    for cp in order:
        record = bytearray(van['records'][cp])
        x, y, w, h = rect(record)
        if w == 0 or h == 0:                     # zero width glyph, no pixels
            added.append((cp, bytes(record)))
            continue
        if cx + w + 1 > W:
            cx, cy, row_h = 0, cy + row_h + 1, 0
        if cy + h >= H:
            break                                # out of room
        for yy in range(h):
            src = (y + yy) * van['width'] + x
            dst = (cy + yy) * W + cx
            mv['pixels'][dst:dst + w] = van['pixels'][src:src + w]
        struct.pack_into('>HH', record, 2, cx, cy)
        added.append((cp, bytes(record)))
        cx += w + 1
        row_h = max(row_h, h)

    table = dict(mv['records'])
    table.update(dict(added))
    blob = b''.join(table[cp] for cp in sorted(table))
    header = bytearray(mv['raw'][:26])
    struct.pack_into('>H', header, 12, len(table))
    end = 26 + len(blob)
    toff = (end + 31) // 32 * 32                 # texture is 32 byte aligned
    struct.pack_into('>I', header, 16, toff)
    out = bytearray(header) + blob + bytes(toff - end) + mv['theader'] + bytes(mv['pixels'])
    open(out_path, 'wb').write(bytes(out))
    return len(added), len(missing), note


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for mv_path in sorted(glob.glob(os.path.join(src, 'mv_*.font'))):
        name = os.path.basename(mv_path)[3:]
        van_path = os.path.join(src, 'van_' + name)
        if not os.path.exists(van_path):
            print(f'{name}: no vanilla counterpart, skipped')
            continue
        added, missing, note = patch(van_path, mv_path, os.path.join(dst, name))
        print(f'{name}: added {added}/{missing} glyphs, {note}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
