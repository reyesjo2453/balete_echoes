/**
 * Shared video-to-atlas animation pipeline (fal.ai).
 *
 * A character spec (see animate-renzo.ts / animate-aswang.ts) names base poses (`.cache/<key>/<base>.png`,
 * facing right on a plain background) and a list of clips. Per clip: Kling image-to-video, then selected
 * frames are cut out with rembg and packed into one atlas + JSON manifest in public/assets/sprites.
 * Everything is cached under `.cache/<key>`, so re-running only pays for missing work.
 *
 *   clips    image-to-video for every clip
 *   preview  contact sheets of the raw clips (5 fps, 13 tiles per row) for choosing frame windows
 *   sheet    extract frames, cut out, pack the atlas
 */
import { createRequire } from "node:module";
import { mkdir, readFile, writeFile, access } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { download, dataUri, falQueue, hasKey } from "./fal.ts";

const require = createRequire(import.meta.url);
const sharp = require("sharp") as typeof import("sharp");
const FFMPEG: string = require("ffmpeg-static");
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const OUT_DIR = resolve(ROOT, "public/assets/sprites");

export interface ClipSpec {
  name: string;
  prompt: string;
  /** Seconds window of the raw 5s video to sample. */
  from: number;
  to: number;
  /** Number of frames to sample evenly from the window. */
  frames: number;
  loop: boolean;
  fps: number;
  /** Animate on a 16:9 canvas (poses that extend far sideways, e.g. lying down). */
  wide?: boolean;
  /** Base pose name (default: the first in `bases`). */
  base?: string;
  /** Sample another clip's video instead of this clip's own (a second window onto the same footage). */
  source?: string;
  /** Re-centre every frame on the figure's own horizontal centre, for clips that travel (leaps). */
  trackX?: boolean;
  /** Play forward then backward instead of wrapping (for subtle idles that do not loop cleanly). */
  pingpong?: boolean;
}

export interface CharacterSpec {
  /** Cache folder (.cache/<key>) and output name (<key>_sheet.webp/.json). */
  key: string;
  /** Base pose names: .cache/<key>/<name>.png. */
  bases: string[];
  /** Appended to every clip prompt. */
  common: string;
  negative: string;
  clips: ClipSpec[];
  /** Atlas columns and cell width in px. */
  cols: number;
  cellW: number;
  /**
   * For dark characters on a white background: after cut-out, erase connected near-white regions at least
   * this many px² (removes smoke/smear effects and white left in gaps between limbs; teeth and eye
   * highlights are smaller and survive).
   */
  cleanWhite?: number;
  /** "fal" (rembg, default) or "local": key the white studio background out on this machine (free, no API). */
  cutout?: "fal" | "local";
  /** Min channel value (0-255) for a pixel to count as "white" in cleanWhite (default 160; use ~232 for pale characters). */
  whiteMin?: number;
  /** Half the cell width in standing heights (room for lunges and lying poses). */
  halfK: number;
}

const exists = (p: string) => access(p).then(() => true, () => false);

export async function clips(spec: CharacterSpec): Promise<void> {
  const CACHE = resolve(ROOT, ".cache", spec.key);
  const CLIPS = spec.clips;
  if (!hasKey()) throw new Error("FAL_KEY not set");
  const load = async (name: string) => {
    const img = sharp(resolve(CACHE, `${name}.png`)).flatten({ background: "#ffffff" });
    const tall = await img.clone().jpeg({ quality: 92 }).toBuffer();
    // 16:9 canvas with the figure at ~85% height, so wide poses are not cut by the frame edge.
    const fig = await img.clone().resize({ height: 920 }).png().toBuffer();
    const wide = await sharp({ create: { width: 1920, height: 1080, channels: 3, background: "#ffffff" } })
      .composite([{ input: fig, gravity: "center" }]).jpeg({ quality: 92 }).toBuffer();
    return { tall, wide };
  };
  const bases: Record<string, { tall: Buffer; wide: Buffer }> = {};
  for (const b of spec.bases) bases[b] = await load(b);
  await Promise.all(
    CLIPS.map(async (c) => {
      if (c.source) return;
      const file = resolve(CACHE, `${c.name}.mp4`);
      if (await exists(file)) return console.log(`[clips] ${c.name} cached`);
      console.log(`[clips] ${c.name} generating...`);
      const r = await falQueue<{ video: { url: string } }>("fal-ai/kling-video/v2.1/standard/image-to-video", {
        image_url: dataUri(c.wide ? bases[c.base ?? spec.bases[0]].wide : bases[c.base ?? spec.bases[0]].tall, "image/jpeg"),
        duration: "5",
        aspect_ratio: c.wide ? "16:9" : "9:16",
        cfg_scale: 0.6,
        prompt: `${c.prompt}, ${spec.common}`,
        negative_prompt: spec.negative,
      });
      await writeFile(file, await download(r.video.url));
      console.log(`[clips] ${c.name} saved`);
    })
  );
}

/** 4 fps contact sheet per raw clip, for choosing windows. */
export function preview(spec: CharacterSpec): void {
  const CACHE = resolve(ROOT, ".cache", spec.key);
  const CLIPS = spec.clips;
  for (const c of CLIPS.filter((k) => !k.source)) {
    const mp4 = resolve(CACHE, `${c.name}.mp4`);
    execFileSync(FFMPEG, ["-v", "error", "-y", "-i", mp4, "-vf", "fps=5,scale=200:-1,tile=13x2", "-frames:v", "1", resolve(CACHE, `${c.name}_sheet.png`)]);
  }
  console.log(`[preview] wrote .cache/${spec.key}/*_sheet.png (5 fps, 0.2s per tile)`);
}

async function cutout(png: Buffer): Promise<Buffer> {
  const r = await falQueue<{ image: { url: string } }>("fal-ai/imageutils/rembg", { image_url: dataUri(png, "image/png") }, () => undefined);
  return download(r.image.url);
}

/** Erase large connected near-white regions (alpha > 0) from an RGBA PNG. */
async function eraseWhiteRegions(png: Buffer, minArea: number, whiteMin = 160): Promise<Buffer> {
  const { data, info } = await sharp(png).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const n = w * h;
  const light = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
    const mn = Math.min(r, g, b);
    if (data[i * 4 + 3] > 0 && mn > whiteMin && Math.max(r, g, b) - mn < 45) light[i] = 1;
  }
  const seen = new Uint8Array(n);
  const stack = new Int32Array(n);
  const comp = new Int32Array(n);
  for (let s0 = 0; s0 < n; s0++) {
    if (!light[s0] || seen[s0]) continue;
    let sp = 0, cnt = 0;
    stack[sp++] = s0;
    seen[s0] = 1;
    while (sp > 0) {
      const i = stack[--sp];
      comp[cnt++] = i;
      const x = i % w;
      if (x > 0 && light[i - 1] && !seen[i - 1]) { seen[i - 1] = 1; stack[sp++] = i - 1; }
      if (x < w - 1 && light[i + 1] && !seen[i + 1]) { seen[i + 1] = 1; stack[sp++] = i + 1; }
      if (i >= w && light[i - w] && !seen[i - w]) { seen[i - w] = 1; stack[sp++] = i - w; }
      if (i < n - w && light[i + w] && !seen[i + w]) { seen[i + w] = 1; stack[sp++] = i + w; }
    }
    if (cnt >= minArea) for (let k = 0; k < cnt; k++) data[comp[k] * 4 + 3] = 0;
  }
  return sharp(data, { raw: { width: w, height: h, channels: 4 } }).png().toBuffer();
}

/**
 * Free local background removal for footage on a plain white background. Removes (1) near-white regions
 * that touch the border or are large, (2) the baked light-grey ground shadow, then softens the 2px edge
 * against white and un-mixes the colour so no white halo remains.
 */
async function localCutout(png: Buffer): Promise<Buffer> {
  const { data, info } = await sharp(png).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const n = w * h;
  const minc = new Uint8Array(n);
  const sat = new Uint8Array(n);
  let top = h, bottom = 0;
  for (let i = 0; i < n; i++) {
    const r = data[i * 3], g = data[i * 3 + 1], b = data[i * 3 + 2];
    const mn = Math.min(r, g, b);
    minc[i] = mn;
    sat[i] = Math.max(r, g, b) - mn;
    if (mn < 150) {
      const y = (i / w) | 0;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  const coreH = Math.max(1, bottom - top);
  const removed = new Uint8Array(n);
  const stack = new Int32Array(n);
  const comp = new Int32Array(n);
  const label = (test: (i: number) => boolean, keep: (cnt: number, touches: boolean, cy: number, bw: number, bh: number) => boolean) => {
    const seen = new Uint8Array(n);
    for (let s0 = 0; s0 < n; s0++) {
      if (seen[s0] || !test(s0)) continue;
      let sp = 0, cnt = 0, touches = false, sy = 0;
      let x0 = w, x1 = 0, y0 = h, y1 = 0;
      stack[sp++] = s0;
      seen[s0] = 1;
      while (sp > 0) {
        const i = stack[--sp];
        comp[cnt++] = i;
        const x = i % w, y = (i / w) | 0;
        sy += y;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
        if (x === 0 || y === 0 || x === w - 1 || y === h - 1) touches = true;
        if (x > 0 && !seen[i - 1] && test(i - 1)) { seen[i - 1] = 1; stack[sp++] = i - 1; }
        if (x < w - 1 && !seen[i + 1] && test(i + 1)) { seen[i + 1] = 1; stack[sp++] = i + 1; }
        if (y > 0 && !seen[i - w] && test(i - w)) { seen[i - w] = 1; stack[sp++] = i - w; }
        if (y < h - 1 && !seen[i + w] && test(i + w)) { seen[i + w] = 1; stack[sp++] = i + w; }
      }
      if (keep(cnt, touches, sy / cnt, x1 - x0 + 1, y1 - y0 + 1)) for (let k = 0; k < cnt; k++) removed[comp[k]] = 1;
    }
  };
  // 1) Studio white: anything touching the frame edge, or a large enclosed gap between limbs.
  label((i) => minc[i] >= 232 && sat[i] < 40, (cnt, touches) => touches || cnt >= 1200);
  // 2) Baked ground shadow: a light neutral-grey blob sitting at the feet.
  label(
    (i) => !removed[i] && minc[i] >= 135 && sat[i] < 38,
    (cnt, _t, cy, bw, bh) => cnt >= 700 && bw >= bh * 2.5 && cy >= bottom - coreH * 0.12
  );
  // 3) Soft edge: pixels within 2px of removed ones fade by how close to white they are.
  const near = new Uint8Array(n);
  for (let pass = 0; pass < 2; pass++) {
    const src = pass === 0 ? removed : near;
    const dst = new Uint8Array(src);
    for (let i = 0; i < n; i++) {
      if (src[i]) continue;
      const x = i % w;
      if ((x > 0 && src[i - 1]) || (x < w - 1 && src[i + 1]) || (i >= w && src[i - w]) || (i < n - w && src[i + w])) dst[i] = 1;
    }
    for (let i = 0; i < n; i++) if (dst[i] && !removed[i]) near[i] = 1;
  }
  const out = Buffer.alloc(n * 4);
  for (let i = 0; i < n; i++) {
    let a = removed[i] ? 0 : 1;
    if (a && near[i]) a = Math.min(1, Math.max(0, (250 - minc[i]) / 80));
    for (let c = 0; c < 3; c++) {
      let v = data[i * 3 + c];
      if (a > 0 && a < 1) v = Math.min(255, Math.max(0, (v - 255 * (1 - a)) / a)); // un-mix from white
      out[i * 4 + c] = v;
    }
    out[i * 4 + 3] = Math.round(a * 255);
  }
  return sharp(out, { raw: { width: w, height: h, channels: 4 } }).png().toBuffer();
}

async function mapLimit<T, R>(items: T[], n: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => { while (i < items.length) { const k = i++; out[k] = await fn(items[k]); } }));
  return out;
}

export async function sheet(spec: CharacterSpec): Promise<void> {
  const CACHE = resolve(ROOT, ".cache", spec.key);
  const CLIPS = spec.clips;
  if (spec.cutout !== "local" && !hasKey()) throw new Error("FAL_KEY not set");
  // 1) sample + cut out frames (cached per frame)
  type Frame = { clip: string; idx: number; buf: Buffer; box: { l: number; t: number; r: number; b: number } };
  const jobs: { c: ClipSpec; idx: number }[] = [];
  for (const c of CLIPS) for (let i = 0; i < c.frames; i++) jobs.push({ c, idx: i });
  const frames: Frame[] = await mapLimit(jobs, 6, async ({ c, idx }) => {
    const tag = `${c.name}_${idx}_${c.from}_${c.to}_${c.frames}`;
    const cut = resolve(CACHE, spec.cutout === "local" ? "frames_local" : "frames", `${tag}.png`);
    if (!(await exists(cut))) {
      const t = c.frames === 1 ? c.from : c.from + ((c.to - c.from) * idx) / (c.loop ? c.frames : c.frames - 1);
      const raw = execFileSync(FFMPEG, ["-v", "error", "-ss", t.toFixed(3), "-i", resolve(CACHE, `${c.source ?? c.name}.mp4`), "-frames:v", "1", "-f", "image2pipe", "-vcodec", "png", "-"], { maxBuffer: 1 << 26 });
      await mkdir(dirname(cut), { recursive: true });
      await writeFile(cut, spec.cutout === "local" ? await localCutout(raw) : await cutout(raw));
      console.log(`[sheet] cut ${tag}`);
    }
    let buf = await readFile(cut);
    if (spec.cleanWhite) buf = await eraseWhiteRegions(buf, spec.cleanWhite, spec.whiteMin);
    const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    let l = info.width, t = info.height, r = 0, b = 0;
    for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) if (data[(y * info.width + x) * 4 + 3] > 128) { if (x < l) l = x; if (x > r) r = x; if (y < t) t = y; if (y > b) b = y; }
    return { clip: c.name, idx, buf, box: { l, t, r, b } };
  });

  // 2) Normalise every clip to the same cell using ITS OWN standing pose (frame 0 of the video),
  //    so scale and the feet pivot match across portrait and 16:9 clips.
  const standing = new Map<string, { groundY: number; standH: number; cx: number }>();
  for (const c of CLIPS) {
    const raw = execFileSync(FFMPEG, ["-v", "error", "-ss", "0", "-i", resolve(CACHE, `${c.source ?? c.name}.mp4`), "-frames:v", "1", "-f", "image2pipe", "-vcodec", "png", "-"], { maxBuffer: 1 << 26 });
    const { data, info } = await sharp(raw).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    let l = info.width, t = info.height, r = 0, b = 0;
    for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
      const i = (y * info.width + x) * 3;
      if (Math.min(data[i], data[i + 1], data[i + 2]) < 225) { if (x < l) l = x; if (x > r) r = x; if (y < t) t = y; if (y > b) b = y; }
    }
    standing.set(c.name, { groundY: b, standH: b - t, cx: (l + r) / 2 });
    console.log("[sheet] standing", c.name, { l, t, r, b, w: info.width, h: info.height });
  }
  const TOP_K = 1.12; // cell top is this many standing heights above the ground line
  const BOT_K = 0.06;
  const HALF_K = spec.halfK; // half the cell width, in standing heights: room for a lunge or a lying body
  const CELL_W = spec.cellW;
  const CELL_H = Math.round((CELL_W * (TOP_K + BOT_K)) / (HALF_K * 2));
  const COLS = spec.cols;
  const rows = Math.ceil(frames.length / COLS);
  const PAD = 1600;

  const tiles = await Promise.all(
    frames.map(async (f, i) => {
      const st = standing.get(f.clip)!;
      const cw = Math.round(st.standH * HALF_K * 2);
      const ch = Math.round(st.standH * (TOP_K + BOT_K));
      let cx = st.cx;
      if (CLIPS.find((k) => k.name === f.clip)?.trackX) {
        // Smoothed horizontal centre of the figure itself (this frame and its neighbours in the clip).
        const mine = frames.filter((g) => g.clip === f.clip);
        const near = mine.filter((g) => Math.abs(g.idx - f.idx) <= 1);
        cx = near.reduce((a, g) => a + (g.box.l + g.box.r) / 2, 0) / near.length;
      }
      const left = Math.round(cx - cw / 2) + PAD;
      const top = Math.round(st.groundY - st.standH * TOP_K) + PAD;
      const padded = await sharp(f.buf)
        .ensureAlpha()
        .extend({ top: PAD, bottom: PAD, left: PAD, right: PAD, background: { r: 0, g: 0, b: 0, alpha: 0 } })
        .png()
        .toBuffer();
      const input = await sharp(padded)
        .extract({ left, top, width: cw, height: ch })
        .resize(CELL_W, CELL_H)
        .png()
        .toBuffer();
      return { input, left: (i % COLS) * CELL_W, top: Math.floor(i / COLS) * CELL_H };
    })
  );
  const atlas = sharp({ create: { width: COLS * CELL_W, height: rows * CELL_H, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } }).composite(tiles);
  await mkdir(OUT_DIR, { recursive: true });
  await atlas.clone().webp({ quality: 92, alphaQuality: 100 }).toFile(resolve(OUT_DIR, `${spec.key}_sheet.webp`));
  await atlas.clone().png({ compressionLevel: 9 }).toFile(resolve(CACHE, `${spec.key}_sheet.png`));

  // 3) manifest. `heightM` = metres the standing figure should be; the cell is scaled from that.
  const manifest = {
    image: `${spec.key}_sheet.webp`,
    cols: COLS, rows, cellW: CELL_W, cellH: CELL_H,
    /** fraction of the cell height the standing figure occupies */
    standFraction: 1 / (TOP_K + BOT_K),
    /** feet baseline as a fraction of cell height from the top */
    groundFraction: TOP_K / (TOP_K + BOT_K),
    clips: Object.fromEntries(
      CLIPS.map((c) => [c.name, { start: frames.findIndex((f) => f.clip === c.name), count: c.frames, fps: c.fps, loop: c.loop, pingpong: Boolean(c.pingpong) }])
    ),
  };
  await writeFile(resolve(OUT_DIR, `${spec.key}_sheet.json`), JSON.stringify(manifest, null, 2));
  console.log(`[sheet] wrote ${spec.key}_sheet.webp + .json`, manifest);
}

export async function runCli(spec: CharacterSpec): Promise<void> {
  const cmd = process.argv[2];
  if (cmd === "clips") await clips(spec);
  else if (cmd === "preview") preview(spec);
  else if (cmd === "sheet") await sheet(spec);
  else console.log(`usage: animate-${spec.key} <clips|preview|sheet>`);
}
