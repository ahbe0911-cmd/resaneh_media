#!/usr/bin/env python3
"""Offline pure-standard-library placeholder creator for missing brand assets.

Real curated PNGs are included in this step's archive.  This fallback ensures
GitHub Actions does not fail before asset generation if a file was omitted.
"""
from __future__ import annotations
import pathlib
import shutil
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = ROOT / 'assets'


def png(path: pathlib.Path, size: int, background: tuple[int, int, int],
        foreground: tuple[int, int, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            dx = abs(x - size // 2)
            dy = abs(y - size // 2)
            square = dx < size * .28 and dy < size * .28
            inner = dx < size * .14 and dy < size * .14
            c = foreground if square and not inner else background
            raw.extend((*c, 255))
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack('!I', len(data)) + tag + data +
                struct.pack('!I', zlib.crc32(tag + data) & 0xffffffff))
    payload = (b'\x89PNG\r\n\x1a\n' +
               chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 6, 0, 0, 0)) +
               chunk(b'IDAT', zlib.compress(bytes(raw), level=7)) +
               chunk(b'IEND', b''))
    path.write_bytes(payload)


for name, bg, fg in (
    ('ketabkhaneh', (6, 78, 59), (230, 196, 119)),
    ('kafinet', (23, 37, 84), (80, 215, 235)),
):
    icon = BASE / 'icons' / f'{name}_icon.png'
    if not icon.is_file() or icon.stat().st_size == 0:
        png(icon, 512, bg, fg)
        print(f'Generated fallback placeholder: {icon}')
    for relative in (
        f'icons/{name}_adaptive_foreground.png',
        f'splash/{name}_splash.png',
    ):
        dst = BASE / relative
        if not dst.is_file() or dst.stat().st_size == 0:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(icon, dst)
            print(f'Generated fallback placeholder: {dst}')
print('Brand PNG assets verified.')
