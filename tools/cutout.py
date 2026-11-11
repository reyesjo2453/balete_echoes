"""Cut sprites out of an OpenArt sheet drawn on flat magenta (#FF00FF).

    python3 tools/cutout.py SHEET.png COLS ROWS OUT_DIR name1 name2 ... [--height H]

Each cell (left to right, top row first) is keyed: the magenta is unmixed from soft edges and despilled, specks and
slivers of the neighbouring cell are dropped, and the figure is trimmed to its bounding box. With --height, every
cell is scaled by one shared factor so the tallest figure is H pixels tall (poses keep the same size relative to each
other). A name of "-" skips that cell. This is the same keying the battle poses went through.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

LO, HI = 95.0, 200.0
MAGENTA = np.array([248, 5, 248], np.float32)


def key(rgb):
    a = np.asarray(rgb).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    d = 255 - np.minimum(r, b) + g
    al = np.clip((d - LO) / (HI - LO), 0, 1)
    safe = np.maximum(al, 0.05)[..., None]
    f = np.clip((a - (1 - al)[..., None] * MAGENTA) / safe, 0, 255)
    m = np.minimum(f[..., 0], f[..., 2])
    spill = np.clip(m - f[..., 1], 0, None) * 0.92
    f[..., 0] -= spill
    f[..., 2] -= spill
    al[al < 0.04] = 0
    # keep the main figure (grown so drips and mist stay attached); drop blobs bleeding in from the cell border
    solid = al > 0.1
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=22))
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        main = int(np.argmax(sizes)) + 1
        keep = lab == main
        for i in range(1, n + 1):
            if i == main:
                continue
            m = lab == i
            touches = m[0].any() or m[-1].any() or m[:, 0].any() or m[:, -1].any()
            if not touches and sizes[i - 1] > 0.02 * sizes[main - 1]:
                keep |= m
        al[~keep] = 0
    return Image.fromarray(np.dstack([f, al * 255]).astype(np.uint8), "RGBA")


def trim(im):
    a = np.asarray(im)[..., 3] > 25
    ys, xs = np.where(a)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main(argv):
    height = None
    if "--height" in argv:
        i = argv.index("--height")
        height = int(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    sheet, cols, rows, out, names = argv[0], int(argv[1]), int(argv[2]), argv[3], argv[4:]
    im = Image.open(sheet).convert("RGB")
    cw, ch = im.width // cols, im.height // rows
    figs = {}
    for idx, name in enumerate(names):
        if name == "-":
            continue
        c, r = idx % cols, idx // cols
        figs[name] = trim(key(im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))))
    s = height / max(f.height for f in figs.values()) if height else 1.0
    os.makedirs(out, exist_ok=True)
    for name, f in figs.items():
        if s != 1.0:
            f = f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.LANCZOS)
        f.save(os.path.join(out, name + ".png"), optimize=True)
        print(name, f.size)


if __name__ == "__main__":
    main(sys.argv[1:])
