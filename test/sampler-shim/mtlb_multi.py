#!/usr/bin/env python3
"""Pack an N-function MTLB metallib, reusing the single-function builder in
../../store/mtlb.py for the container layout and adding only what a second
function needs: its own bitcode blob, and an OFFT third-u64 pointing at it
relative to the header's bcOffset (which is how AIR::Library reads it).

usage: mtlb_multi.py <template.metallib> <out.metallib> name:type:file.bc ...
"""
import struct
import sys
import os

sys.path.insert(0, os.environ.get('MTLB_DIR', '/home/cristi/.local/share/agent-tmp/metal-gaps/store'))
import mtlb

TYPES = {'vertex': 0, 'fragment': 1, 'kernel': 2}


def wrap_bitcode(template, new_bitcode):
    """Wrap `new_bitcode` in the template's BitcodeWrapperHeader shape."""
    h = mtlb.parse(template)
    old = template[h['bcOffset']:h['bcOffset'] + h['funcs'][0]['bcSize']]
    if old[:4] != b'\xde\xc0\x17\x0b':
        raise SystemExit('template bitcode is not a BitcodeWrapperHeader')
    off = struct.unpack_from('<I', old, 8)[0]
    payload = new_bitcode
    if payload[:4] == b'\xde\xc0\x17\x0b':
        inner_off, inner_size = struct.unpack_from('<II', payload, 8)
        payload = payload[inner_off:inner_off + inner_size]
    hdr = bytearray(old[:off])
    struct.pack_into('<II', hdr, 8, off, len(payload))
    return bytes(hdr) + payload


def main():
    template = open(sys.argv[1], 'rb').read()
    out_path = sys.argv[2]
    specs = []
    for spec in sys.argv[3:]:
        name, kind, path = spec.split(':')
        specs.append((name, TYPES[kind], open(path, 'rb').read()))

    h = mtlb.parse(template)
    pub = template[h['pubMetaOffset']:h['pubMetaOffset'] + h['pubMetaSize']]
    priv = template[h['privMetaOffset']:h['privMetaOffset'] + h['privMetaSize']]

    blobs = [wrap_bitcode(template, bc) for _, _, bc in specs]

    group = bytearray()
    for i, ((name, ftype, _), blob) in enumerate(zip(specs, blobs)):
        g = bytearray()
        g += mtlb.tag(b'NAME', name.encode() + b'\0')
        g += mtlb.tag(b'TYPE', struct.pack('<B', ftype))
        g += mtlb.tag(b'MDSZ', struct.pack('<Q', len(blob)))
        g += mtlb.tag(b'OFFT', struct.pack('<QQQ', 0, 0, 0))  # patched below
        g += b'ENDT'
        group += struct.pack('<I', len(g) + 4) + bytes(g)
    func_list = bytearray(struct.pack('<I', len(specs)) + bytes(group))

    pub_off = 0x58 + len(func_list)
    priv_off = pub_off + len(pub)
    bc_off = priv_off + len(priv)
    bc_region = bytearray()
    blob_rel = []
    for blob in blobs:
        blob_rel.append(len(bc_region))
        bc_region += blob

    # OFFT's bitcode offset is relative to bcOffset, so patch each group in place.
    p = 4
    for rel in blob_rel:
        gsize = struct.unpack_from('<I', func_list, p)[0]
        g = bytearray(func_list[p:p + gsize])
        q = 4
        while True:
            tname = bytes(g[q:q + 4])
            if tname == b'ENDT':
                break
            tsize = struct.unpack_from('<H', g, q + 4)[0]
            if tname == b'OFFT':
                struct.pack_into('<Q', g, q + 6, 0)   # pubMeta
                struct.pack_into('<Q', g, q + 14, 0)  # privMeta
                struct.pack_into('<Q', g, q + 22, rel)  # bitcode
            q += 6 + tsize
        func_list[p:p + gsize] = g
        p += gsize

    header = bytearray(template[:0x58])
    struct.pack_into('<Q', header, 0x10, 0)          # fileSize
    struct.pack_into('<Q', header, 0x18, 0x58)       # funcListOffset
    struct.pack_into('<Q', header, 0x20, len(func_list))
    struct.pack_into('<Q', header, 0x28, pub_off)
    struct.pack_into('<Q', header, 0x30, len(pub))
    struct.pack_into('<Q', header, 0x38, priv_off)
    struct.pack_into('<Q', header, 0x40, len(priv))
    struct.pack_into('<Q', header, 0x48, bc_off)
    struct.pack_into('<Q', header, 0x50, len(bc_region))

    out = bytearray(header) + bytes(func_list) + pub + priv + bytes(bc_region)
    struct.pack_into('<Q', out, 0x10, len(out))
    open(out_path, 'wb').write(out)
    mtlb.dump(out_path)


if __name__ == '__main__':
    main()
