"""HD-2D asset polishing tools for Balete Echoes.

1. Cuts & processes the generated Kardo 4x3 walk strip onto a clean 12-frame horizontal strip
   (godot/assets/explore/kardo_walk.png) matching teo_walk.png's direction order (down, right, up x 4)
   at 132px height with zero magenta fringe.
2. Implements AdvMAME Scale2x / Scale3x pixel-art upscaling (preserving crisp dark outlines and
   diagonal pixel smoothing without blurry bilinear haze) + hard-alpha edge cleanup.
3. Cuts HD vehicles (van.png, truck.png) if a sheet is passed.
4. Writes godot/data/sprite_scales.json so StageBattle keeps world-space heights 100% unchanged
   while rendering 3x sharper HD-2D battle sprites.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
EXPLORE = os.path.join(ROOT, "godot", "assets", "explore")
PORTRAITS = os.path.join(ROOT, "godot", "assets", "portraits_px")
SCALES_PATH = os.path.join(ROOT, "godot", "data", "sprite_scales.json")


def key(rgb: Image.Image) -> Image.Image:
    LO, HI = 95.0, 200.0
    MAGENTA = np.array([248.0, 5.0, 248.0], np.float32)
    a = np.asarray(rgb).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    d = 255.0 - np.minimum(r, b) + g
    al = np.clip((d - LO) / (HI - LO), 0.0, 1.0)
    safe = np.maximum(al, 0.05)[..., None]
    f = np.clip((a - (1.0 - al)[..., None] * MAGENTA) / safe, 0.0, 255.0)
    m = np.minimum(f[..., 0], f[..., 2])
    spill = np.clip(m - f[..., 1], 0.0, None) * 0.92
    f[..., 0] -= spill
    f[..., 2] -= spill
    al[al < 0.04] = 0.0
    return Image.fromarray(np.dstack([np.clip(f, 0, 255), al * 255.0]).astype(np.uint8), "RGBA")


def trim(im: Image.Image) -> Image.Image:
    a = np.asarray(im)[..., 3] > 25
    ys, xs = np.where(a)
    if len(ys) == 0:
        return im
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def scale2x_rgba(im: Image.Image) -> Image.Image:
    """AdvMAME Scale2x (EPX) on premultiplied-safe RGBA + crisp diagonal handling."""
    arr = np.asarray(im.convert("RGBA"))
    h, w, _ = arr.shape
    pad = np.pad(arr, ((1, 1), (1, 1), (0, 0)), mode="edge")
    # Center P and 4 cardinal neighbors A(top), B(right), C(left), D(bottom)
    P = pad[1:-1, 1:-1]
    A = pad[0:-2, 1:-1]
    B = pad[1:-1, 2:]
    C = pad[1:-1, 0:-2]
    D = pad[2:, 1:-1]

    def eq(x, y):
        # Match pixels within tiny color/alpha tolerance for minor quantization differences
        diff = np.abs(x.astype(np.int16) - y.astype(np.int16)).max(axis=-1)
        return diff <= 8

    ab = ~eq(A, B)
    cd = ~eq(C, D)
    ac = ~eq(A, C)
    bd = ~eq(B, D)

    # Classic EPX rule only corners when 3 distinct neighbors don't form uniform block
    cond_valid = (~eq(C, B)) & (~eq(A, D))
    e0 = np.where((cond_valid & eq(C, A))[..., None], C, P)
    e1 = np.where((cond_valid & eq(A, B))[..., None], B, P)
    e2 = np.where((cond_valid & eq(D, C))[..., None], C, P)
    e3 = np.where((cond_valid & eq(B, D))[..., None], B, P)

    out = np.zeros((h * 2, w * 2, 4), dtype=np.uint8)
    out[0::2, 0::2] = e0
    out[0::2, 1::2] = e1
    out[1::2, 0::2] = e2
    out[1::2, 1::2] = e3
    # Keep alpha binary crisp where originally opaque
    return Image.fromarray(out, "RGBA")


def scale3x_rgba(im: Image.Image) -> Image.Image:
    """AdvMAME Scale3x pixel-art upscaler for crisp 3x HD-2D sprite edges."""
    arr = np.asarray(im.convert("RGBA"))
    h, w, _ = arr.shape
    pad = np.pad(arr, ((1, 1), (1, 1), (0, 0)), mode="edge")
    A = pad[0:-2, 0:-2]
    B = pad[0:-2, 1:-1]
    C = pad[0:-2, 2:]
    D = pad[1:-1, 0:-2]
    E = pad[1:-1, 1:-1]
    F = pad[1:-1, 2:]
    G = pad[2:, 0:-2]
    H = pad[2:, 1:-1]
    I = pad[2:, 2:]

    def eq(x, y):
        return np.abs(x.astype(np.int16) - y.astype(np.int16)).max(axis=-1) <= 10

    valid = (~eq(B, H)) & (~eq(D, F))
    e0 = np.where((valid & eq(D, B))[..., None], D, E)
    e1 = np.where((valid & ((eq(D, B) & ~eq(E, C)) | (eq(B, F) & ~eq(E, A))))[..., None], B, E)
    e2 = np.where((valid & eq(B, F))[..., None], F, E)
    e3 = np.where((valid & ((eq(D, B) & ~eq(E, G)) | (eq(D, H) & ~eq(E, A))))[..., None], D, E)
    e4 = E
    e5 = np.where((valid & ((eq(B, F) & ~eq(E, I)) | (eq(H, F) & ~eq(E, C))))[..., None], F, E)
    e6 = np.where((valid & eq(D, H))[..., None], D, E)
    e7 = np.where((valid & ((eq(D, H) & ~eq(E, I)) | (eq(H, F) & ~eq(E, G))))[..., None], H, E)
    e8 = np.where((valid & eq(H, F))[..., None], F, E)

    out = np.zeros((h * 3, w * 3, 4), dtype=np.uint8)
    out[0::3, 0::3] = e0
    out[0::3, 1::3] = e1
    out[0::3, 2::3] = e2
    out[1::3, 0::3] = e3
    out[1::3, 1::3] = e4
    out[1::3, 2::3] = e5
    out[2::3, 0::3] = e6
    out[2::3, 1::3] = e7
    out[2::3, 2::3] = e8
    return Image.fromarray(out, "RGBA")


def head_cx(im: Image.Image) -> float:
    a = np.asarray(im)[..., 3] > 30
    top = a[: max(1, im.height // 4)]
    xs = np.where(top.any(axis=0))[0]
    return float(xs.min() + xs.max()) / 2.0 if len(xs) else im.width / 2.0


def despill_magenta_edges(im: Image.Image) -> Image.Image:
    """Strict cleanup of JPEG/AI magenta border pixels on keyed sprite."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    # Any semi-transparent or edge pixel that is strongly magenta gets killed or despilled
    mag_score = np.minimum(r, b) - g
    edge = (al > 0) & (al < 220) & (mag_score > 18)
    al[edge] = 0.0
    # Despill residual purple tint on outer opaque pixels
    opaque = al >= 220
    spill = np.where(opaque & (mag_score > 14), mag_score * 0.85, 0.0)
    r = np.clip(r - spill, 0, 255)
    b = np.clip(b - spill, 0, 255)
    al = np.where(al >= 120, 255.0, 0.0)
    return Image.fromarray(np.dstack([r, g, b, al]).astype(np.uint8), "RGBA")


def build_kardo_walk(sheet_path: str, target_h: int = 128) -> str:
    im = Image.open(sheet_path).convert("RGB")
    cw, ch = im.width // 4, im.height // 3
    figs = []
    for r in range(3):
        for c in range(4):
            cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            cut = despill_magenta_edges(trim(key(cell)))
            figs.append(cut)
    tallest = max(f.height for f in figs)
    s = target_h / float(tallest)
    scaled = [f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.NEAREST if s >= 1 else Image.LANCZOS) for f in figs]
    # Keep alpha crisp after resize
    cleaned = []
    for f in scaled:
        cleaned.append(despill_magenta_edges(f))
    cell_w = max(f.width for f in cleaned) + 12
    cell_w += cell_w % 2
    cell_h = target_h + 4
    strip = Image.new("RGBA", (cell_w * 12, cell_h), (0, 0, 0, 0))
    for i, f in enumerate(cleaned):
        hx = head_cx(f)
        x = round(cell_w / 2.0 - hx)
        x = max(0, min(cell_w - f.width, x))
        strip.paste(f, (i * cell_w + x, cell_h - 2 - f.height), f)
    out_path = os.path.join(EXPLORE, "kardo_walk.png")
    strip.save(out_path, optimize=True)
    print(f"wrote {out_path} ({strip.size}, cell={cell_w}x{cell_h})")
    return out_path


def cut_van_from_sheet(sheet_path: str) -> None:
    im = Image.open(sheet_path).convert("RGB")
    mid = im.width // 2 - 24
    van_raw = despill_magenta_edges(trim(key(im.crop((0, 0, mid, im.height)))))
    van_raw = van_raw.transpose(Image.FLIP_LEFT_RIGHT)  # match original facing right
    w = max(1, round(van_raw.width * (160.0 / float(van_raw.height))))
    van_hd = despill_magenta_edges(van_raw.resize((w, 160), Image.LANCZOS))
    van_hd.save(os.path.join(EXPLORE, "van.png"), optimize=True)
    print(f"wrote HD van.png {van_hd.size}")


def cut_truck(truck_path: str) -> None:
    im = Image.open(truck_path).convert("RGB")
    truck_raw = despill_magenta_edges(trim(key(im)))
    w = max(1, round(truck_raw.width * (240.0 / float(truck_raw.height))))
    truck_hd = despill_magenta_edges(truck_raw.resize((w, 240), Image.LANCZOS))
    truck_hd.save(os.path.join(EXPLORE, "truck.png"), optimize=True)
    print(f"wrote HD truck.png {truck_hd.size}")


def polish_hd_sprites() -> None:
    """Upscales walk strip, battle sprites, key props, and dialogue portraits with Scale2x/Scale3x."""
    scales = {}
    if os.path.exists(SCALES_PATH):
        with open(SCALES_PATH) as f:
            scales = json.load(f)

    # 1. teo_walk.png: 12-frame strip -> Scale2x preserves exact per-frame baseline & centering!
    teo_p = os.path.join(EXPLORE, "teo_walk.png")
    teo_im = Image.open(teo_p).convert("RGBA")
    if teo_im.height < 100:
        teo_hd = scale2x_rgba(teo_im)
        teo_hd.save(teo_p, optimize=True)
        print(f"upscaled teo_walk.png {teo_im.size} -> {teo_hd.size}")

    # 2. Battle character/boss sprites: Scale3x when still at original small (<150px) pixel height
    battle_prefixes = ["teob_", "kardob_", "pidob_", "lolab_", "aswang_", "hound_", "mag_", "unsent_", "lberto_", "lunod_"]
    for fn in sorted(os.listdir(EXPLORE)):
        if not fn.endswith(".png"):
            continue
        if not any(fn.startswith(p) for p in battle_prefixes):
            continue
        stem = fn[:-4]
        p = os.path.join(EXPLORE, fn)
        im = Image.open(p).convert("RGBA")
        if im.height < 150:
            hd = scale3x_rgba(im)
            hd.save(p, optimize=True)
            scales[stem] = 3.0
            print(f"upscaled {fn} {im.size} -> {hd.size}")
        elif stem not in scales:
            scales[stem] = 3.0

    # 3. Explore key cast & props (ExploreMap scales by target meter h / tex.get_height(), so no manifest needed)
    explore_targets = [
        "kardo.png", "kardo_b.png", "kardo_sleep.png",
        "ising.png", "ising_b.png", "ising_sleep.png", "ising_sleep_b.png", "ising_stair.png",
        "obet.png", "obet_b.png", "domeng.png", "domeng_b.png", "nena.png", "nena_b.png",
        "berto.png", "berto_b.png", "balut.png", "balut_b.png", "trike.png", "kid.png", "kid_b.png",
        "tess.png", "tess_b.png", "celso.png", "celso_b.png", "guard.png", "guard_b.png",
        "cards_a.png", "cards_a_b.png", "cards_b.png", "cards_b_b.png",
        "balete.png", "parlor_front.png", "casket.png", "altar.png", "hiraya_sign.png",
        "tricycle.png", "pumphouse.png", "teo_kneel.png", "teo_stair.png", "salonga.png", "truck.png",
    ]
    for fn in explore_targets:
        p = os.path.join(EXPLORE, fn)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        if im.height < 160 and im.width < 220:
            hd = scale3x_rgba(im)
            hd.save(p, optimize=True)
            print(f"upscaled prop/cast {fn} {im.size} -> {hd.size}")

    # 4. Portraits (portraits_px/*.png): 88x88 -> 264x264 via Scale3x
    for fn in sorted(os.listdir(PORTRAITS)):
        if not fn.endswith(".png"):
            continue
        p = os.path.join(PORTRAITS, fn)
        im = Image.open(p).convert("RGBA")
        if im.height < 150:
            hd = scale3x_rgba(im)
            hd.save(p, optimize=True)
            print(f"upscaled portrait {fn} {im.size} -> {hd.size}")

    with open(SCALES_PATH, "w") as f:
        json.dump(scales, f, indent=1, sort_keys=True)
    print(f"saved {len(scales)} battle sprite scales to {SCALES_PATH}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "polish"
    if cmd == "kardo":
        build_kardo_walk(sys.argv[2])
    elif cmd == "van":
        cut_van_from_sheet(sys.argv[2])
    elif cmd == "polish":
        polish_hd_sprites()
    elif cmd == "all":
        build_kardo_walk(sys.argv[2])
        cut_van_from_sheet(sys.argv[3])
        polish_hd_sprites()
