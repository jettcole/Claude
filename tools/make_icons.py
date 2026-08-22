#!/usr/bin/env python3
"""Generate the Tallyroll app icons as PNGs (no third-party imaging libraries).

Draws a cash-register-green tile carrying a paper receipt with a torn bottom
edge, then box-filters a 4x supersample down to the target size.
"""
import struct
import zlib

SS = 4  # supersample factor

GREEN = (0x1F, 0x6B, 0x4F)
GREEN_DEEP = (0x14, 0x4C, 0x38)
PAPER = (0xF7, 0xF8, 0xF4)
RULE = (0xC2, 0xCE, 0xC5)
BRASS = (0x9A, 0x6F, 0x2E)


def rounded_rect(x, y, w, h, r):
    """Return a predicate telling whether a point falls inside a rounded rect."""
    def inside(px, py):
        if not (x <= px <= x + w and y <= py <= y + h):
            return False
        cx = min(max(px, x + r), x + w - r)
        cy = min(max(py, y + r), y + h - r)
        dx, dy = px - cx, py - cy
        return dx * dx + dy * dy <= r * r
    return inside


def blend(dst, src, alpha=1.0):
    return tuple(round(d + (s - d) * alpha) for d, s in zip(dst, src))


def render(size, bleed):
    """Render one icon. `bleed` fills the whole square (for maskable icons)."""
    n = size * SS
    px = [[GREEN for _ in range(n)] for _ in range(n)]

    tile = rounded_rect(0, 0, n - 1, n - 1, 0 if bleed else n * 0.22)
    # Vertical shade so the tile has a little depth rather than reading flat.
    for y in range(n):
        t = y / (n - 1)
        row_col = blend(GREEN, GREEN_DEEP, t * 0.55)
        row = px[y]
        for x in range(n):
            row[x] = row_col if tile(x, y) else (0, 0, 0, 0) if False else row_col
    if not bleed:
        for y in range(n):
            row = px[y]
            for x in range(n):
                if not tile(x, y):
                    row[x] = None  # transparent

    # Receipt body: a tall paper rectangle, inset from the tile.
    inset = n * (0.28 if bleed else 0.24)
    rx, rw = inset, n - inset * 2
    ry = n * (0.24 if bleed else 0.20)
    rh = n - ry - n * (0.26 if bleed else 0.22)
    paper = rounded_rect(rx, ry, rw, rh, n * 0.02)

    # Torn bottom edge: a zigzag whose teeth are carved out of the paper.
    teeth = 6
    tooth_w = rw / teeth
    tooth_h = n * 0.05
    tear_top = ry + rh - tooth_h

    def in_paper(x, y):
        if not paper(x, y):
            return False
        if y < tear_top:
            return True
        # Inside the tear band, keep only points below the zigzag baseline.
        local = (x - rx) % tooth_w
        peak = abs(local - tooth_w / 2) / (tooth_w / 2)  # 0 at centre, 1 at edges
        return y <= tear_top + tooth_h * peak

    for y in range(int(ry), min(n, int(ry + rh) + 2)):
        row = px[y]
        for x in range(int(rx), min(n, int(rx + rw) + 2)):
            if row[x] is not None and in_paper(x, y):
                row[x] = PAPER

    # Ruled lines on the receipt, plus a brass line standing in for the total.
    lines = [(0.30, 0.62, RULE), (0.44, 0.62, RULE), (0.58, 0.36, RULE), (0.72, 0.46, BRASS)]
    lh = max(1, int(n * 0.035))
    for frac, width, colour in lines:
        ly = int(ry + rh * frac)
        lx0 = int(rx + rw * 0.16)
        lx1 = int(lx0 + rw * width)
        for y in range(ly, min(n, ly + lh)):
            row = px[y]
            for x in range(lx0, min(n, lx1)):
                if row[x] is not None and in_paper(x, y):
                    row[x] = colour

    # Box-filter the supersample down to the requested size.
    out = bytearray()
    for y in range(size):
        out.append(0)  # PNG filter type 0
        for x in range(size):
            r = g = b = a = 0
            for sy in range(SS):
                for sx in range(SS):
                    p = px[y * SS + sy][x * SS + sx]
                    if p is None:
                        continue
                    r += p[0]; g += p[1]; b += p[2]; a += 255
            total = SS * SS
            if a == 0:
                out += bytes((0, 0, 0, 0))
            else:
                cov = a // total
                out += bytes((r * 255 // a, g * 255 // a, b * 255 // a, cov))
    return bytes(out)


def write_png(path, size, raw):
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(png)
    return len(png)


for size, bleed, name in [
    (180, False, "icons/apple-touch-icon.png"),
    (192, False, "icons/icon-192.png"),
    (512, False, "icons/icon-512.png"),
    (512, True, "icons/icon-maskable-512.png"),
]:
    n = write_png(name, size, render(size, bleed))
    print(f"{name}  {size}x{size}  {n:,} bytes")
