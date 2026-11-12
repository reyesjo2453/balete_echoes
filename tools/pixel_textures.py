"""Pixel-art surface textures for the explore maps (floors, walls, wood), drawn procedurally so they tile exactly.

    python3 tools/pixel_textures.py        -> godot/assets/explore/tex_*.png

32 texture pixels = 1 metre, the same density as the 64-pixel character sprites, so floors, walls and people share
one pixel grid on screen.
"""
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "explore")


def jitter(c, r, amt):
    return tuple(max(0, min(255, v + r.randint(-amt, amt))) for v in c)


def floor_tiles(name, a, b, grout, tile=16, size=64, seed=1, noise=6):
    """Checkerboard vinyl or terrazzo tiles with a grout line and a few chips."""
    r = random.Random(seed)
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            tx, ty = x // tile, y // tile
            base = a if (tx + ty) % 2 == 0 else b
            c = jitter(base, r, noise)
            if x % tile == 0 or y % tile == 0:
                c = grout
            elif x % tile == 1 or y % tile == 1:
                c = tuple(min(255, v + 10) for v in c)  # bevel highlight
            px[x, y] = c
    for _ in range(size * size // 40):  # terrazzo chips
        x, y = r.randrange(size), r.randrange(size)
        if x % tile > 1 and y % tile > 1:
            px[x, y] = jitter((px[x, y][0] - 30, px[x, y][1] - 30, px[x, y][2] - 26), r, 8)
    im.save(os.path.join(OUT, name + ".png"))


def wall(name, plaster, wood, trim, size=(64, 96), wains=32, seed=2):
    """A wall 2 m wide x 3 m tall: plaster above, plank wainscot below, a trim rail and a dark baseboard."""
    r = random.Random(seed)
    w, h = size
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            fy = h - 1 - y  # height from the floor in texture pixels
            if fy < 3:
                c = (34, 24, 20)
            elif fy < wains:
                c = jitter(wood, r, 5)
                if x % 8 == 0:
                    c = tuple(v - 28 for v in wood)
                elif x % 8 == 1:
                    c = tuple(min(255, v + 12) for v in wood)
            elif fy < wains + 3:
                c = trim if fy != wains + 2 else tuple(min(255, v + 20) for v in trim)
            else:
                c = jitter(plaster, r, 4)
                if r.random() < 0.01:
                    c = tuple(v - 18 for v in plaster)  # water stains / dents
            px[x, y] = c
    # a damp stain creeping up from the wainscot
    for x in range(w):
        top = wains + 3 + int(6 + 4 * ((x * 7919) % 13) / 13)
        for fy in range(wains + 3, top):
            y = h - 1 - fy
            c = px[x, y]
            px[x, y] = (c[0] - 14, c[1] - 12, c[2] - 10)
    im.save(os.path.join(OUT, name + ".png"))


def planks(name, base, size=64, seed=3, plank=8):
    r = random.Random(seed)
    im = Image.new("RGB", (size, size))
    px = im.load()
    offs = [r.randrange(size) for _ in range(size // plank + 1)]
    for y in range(size):
        row = y // plank
        for x in range(size):
            c = jitter(base, r, 6)
            if y % plank == 0:
                c = tuple(v - 34 for v in base)
            elif (x + offs[row]) % 32 == 0:
                c = tuple(v - 26 for v in base)
            elif r.random() < 0.04:
                c = tuple(v - 12 for v in base)
            px[x, y] = c
    im.save(os.path.join(OUT, name + ".png"))


def concrete(name, base, size=64, seed=4, cracks=3):
    r = random.Random(seed)
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = jitter(base, r, 7)
    for _ in range(cracks):
        x, y = r.randrange(size), r.randrange(size)
        for _ in range(r.randint(10, 26)):
            px[x % size, y % size] = tuple(v - 30 for v in base)
            x += r.choice((-1, 0, 1, 1))
            y += r.choice((0, 1, 1))
    for _ in range(4):  # puddles
        cx, cy, rad = r.randrange(size), r.randrange(size), r.randint(3, 7)
        for y in range(cy - rad, cy + rad):
            for x in range(cx - rad * 2, cx + rad * 2):
                if ((x - cx) / 2) ** 2 + (y - cy) ** 2 < rad * rad:
                    c = px[x % size, y % size]
                    px[x % size, y % size] = (c[0] - 22, c[1] - 16, c[2] - 4)
    im.save(os.path.join(OUT, name + ".png"))


def water(name, seed=5, size=64):
    """Dark creek water with ripple glints and rust streaks; scrolled slowly in the engine."""
    r = random.Random(seed)
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = (26 + r.randint(-3, 3), 44 + r.randint(-3, 3), 52 + r.randint(-3, 3))
    for _ in range(40):
        x, y, n = r.randrange(size), r.randrange(size), r.randint(3, 9)
        for k in range(n):
            px[(x + k) % size, y] = (58, 86, 92) if k % 3 else (80, 110, 112)
    for _ in range(12):
        x, y = r.randrange(size), r.randrange(size)
        for k in range(r.randint(4, 10)):
            px[(x + k) % size, (y + k // 4) % size] = (70, 48, 36)
    im.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    floor_tiles("tex_parlor_floor", (176, 168, 146), (138, 146, 124), (82, 78, 68), noise=5)
    wall("tex_parlor_wall", (150, 172, 160), (96, 62, 40), (60, 40, 28), size=(64, 134))
    planks("tex_wood", (120, 80, 50))
    planks("tex_boardwalk", (92, 74, 58), seed=7, plank=16)
    concrete("tex_street", (62, 64, 70))
    concrete("tex_channel", (88, 90, 84), seed=11, cracks=6)
    water("tex_water")
    print("written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
