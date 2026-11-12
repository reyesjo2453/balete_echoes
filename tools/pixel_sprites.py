"""Turn an OpenArt pixel-art sheet (drawn large, on flat magenta) into true low-resolution sprites.

    python3 tools/pixel_sprites.py walk SHEET OUT_PNG --height 64
        A 4x3 walk sheet (rows: toward the viewer, to the right, away; 4 frames each) becomes one strip of 12 frames,
        every frame in the same cell, feet on the bottom row and the head centred, so the walk never jitters.
    python3 tools/pixel_sprites.py cells SHEET COLS ROWS OUT_DIR name1 name2 ... --height H
        Every named cell becomes its own sprite (one shared scale, so relative sizes hold). "-" skips a cell.

Keying is tools/cutout.py's; the figure is then box-downsampled to the target height, alpha is made hard (pixel art
has no soft edges) and colours are reduced to a small palette.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from cutout import key, trim  # noqa: E402


def cells(path, cols, rows):
    im = Image.open(path).convert("RGB")
    cw, ch = im.width // cols, im.height // rows
    for r in range(rows):
        for c in range(cols):
            yield key(im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)))


def pixelize(im, scale, colors=40):
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    a = np.asarray(im).astype(np.float32)
    # premultiply so magenta-free colour is averaged only where the figure is
    rgb = a[..., :3] * (a[..., 3:4] / 255.0)
    pre = Image.fromarray(np.dstack([rgb, a[..., 3]]).astype(np.uint8), "RGBA").resize((w, h), Image.BOX)
    p = np.asarray(pre).astype(np.float32)
    al = p[..., 3]
    rgb = np.where(al[..., None] > 0, p[..., :3] / np.maximum(al[..., None], 1) * 255.0, 0)
    hard = (al > 110).astype(np.uint8) * 255
    out = Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), hard]), "RGBA")
    q = out.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    return Image.fromarray(np.dstack([np.asarray(q), hard]), "RGBA")


def head_cx(im):
    a = np.asarray(im)[..., 3] > 25
    top = a[: max(1, im.height // 4)]
    xs = np.where(top.any(axis=0))[0]
    return (xs.min() + xs.max()) / 2.0 if len(xs) else im.width / 2.0


def walk(sheet, out, height):
    figs = [trim(f) for f in cells(sheet, 4, 3)]
    tallest = max(f.height for f in figs)
    s = height / tallest
    small = [pixelize(f, s) for f in figs]
    cw = max(f.width for f in small) + 6
    cw += cw % 2
    ch = height + 2
    strip = Image.new("RGBA", (cw * 12, ch), (0, 0, 0, 0))
    for i, f in enumerate(small):
        hx = head_cx(f)
        x = round(cw / 2 - hx)
        x = max(0, min(cw - f.width, x))
        strip.paste(f, (i * cw + x, ch - 1 - f.height), f)
    strip.save(out, optimize=True)
    print(out, "frame", cw, "x", ch)


def named(sheet, cols, rows, outdir, names, height):
    figs = {}
    for name, f in zip(names, cells(sheet, cols, rows)):
        if name != "-":
            figs[name] = trim(f)
    s = height / max(f.height for f in figs.values())
    os.makedirs(outdir, exist_ok=True)
    for name, f in figs.items():
        p = pixelize(f, s)
        p = p.crop(p.getbbox())
        p.save(os.path.join(outdir, name + ".png"), optimize=True)
        print(name, p.size)


def main(argv):
    height = 64
    if "--height" in argv:
        i = argv.index("--height")
        height = int(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    if argv[0] == "walk":
        walk(argv[1], argv[2], height)
    else:
        named(argv[1], int(argv[2]), int(argv[3]), argv[4], argv[5:], height)


if __name__ == "__main__":
    main(sys.argv[1:])
