"""Move an MP4/M4A file's index (the moov atom) in front of its media data, so a browser
can start playing it before the whole file has downloaded. Same idea as ffmpeg's
-movflags +faststart.

    python3 tools/faststart.py in.m4a out.m4a
"""
import shutil
import struct
import sys

# boxes that hold other boxes on the way down to the chunk-offset tables
CONTAINERS = {b'moov', b'trak', b'mdia', b'minf', b'stbl'}


def boxes(buf, start, end):
    i = start
    while i < end:
        size, kind = struct.unpack('>I4s', buf[i:i + 8])
        header = 8
        if size == 1:
            size = struct.unpack('>Q', buf[i + 8:i + 16])[0]
            header = 16
        elif size == 0:
            size = end - i
        yield kind, i, header, size
        i += size


def shift_offsets(buf, start, end, delta):
    """Add delta to every chunk offset (stco/co64) under buf[start:end]."""
    for kind, i, header, size in boxes(buf, start, end):
        if kind in CONTAINERS:
            shift_offsets(buf, i + header, i + size, delta)
        elif kind in (b'stco', b'co64'):
            fmt, width = ('>I', 4) if kind == b'stco' else ('>Q', 8)
            count = struct.unpack('>I', buf[i + header + 4:i + header + 8])[0]
            for k in range(count):
                p = i + header + 8 + width * k
                struct.pack_into(fmt, buf, p, struct.unpack(fmt, buf[p:p + width])[0] + delta)


def main(src, dst):
    buf = bytearray(open(src, 'rb').read())
    top = list(boxes(buf, 0, len(buf)))
    kinds = [kind for kind, *_ in top]
    if kinds.index(b'moov') < kinds.index(b'mdat'):
        shutil.copyfile(src, dst)
        print('already faststart')
        return
    _, mi, mh, ms = top[kinds.index(b'moov')]
    moov = bytearray(buf[mi:mi + ms])
    shift_offsets(moov, mh, ms, ms)   # the media data moves back by the size of the index
    out = bytearray()
    for kind, i, header, size in top:
        if kind == b'moov':
            continue
        if kind == b'mdat' and moov is not None:
            out += moov
            moov = None
        out += buf[i:i + size]
    open(dst, 'wb').write(out)
    print('moved index to the front:', [k.decode() for k, *_ in boxes(out, 0, len(out))])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
